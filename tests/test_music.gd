extends SceneTree
## 배경음악·볼륨 설정 자동 테스트: 병과 → 곡 고르기, 같은 그룹이면 이어서, 메뉴 곡, 버스 구조, 루프,
## 설정 저장 → 불러오기, 볼륨 → 버스 dB·음소거, 설정 패널 슬라이더.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_music.gd

var main: Node
var G
var M
var fails := 0
var frame := 0
var step_i := 0
var t0 := 0


func _initialize() -> void:
	G = root.get_node("GameData")
	M = root.get_node("Music")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.ai_enabled = false
	G.chosen_cls = "archer"
	G.difficulty = "normal"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func _physics_process(_dt: float) -> bool:
	frame += 1
	_run()
	return false


func _run() -> void:
	var el := frame - t0
	var p = main.get_node("Player")
	match step_i:
		0:
			if frame == 3:
				check("병과 → 곡: 음유시인", M.track_for("bard", true) == "match_bard")
				check("병과 → 곡: 궁수", M.track_for("archer", true) == "match")
				check("병과 → 곡: 야만인·석궁병·성직자", M.track_for("barbarian", true) == "match" and M.track_for("crossbow", true) == "match" and M.track_for("cleric", true) == "match")
				check("메뉴면 menu", M.track_for("bard", false) == "menu")
				check("메뉴에서 시작", M.key == "menu", M.key)
				check("버스 Music·SFX", AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0)
				check("BGM은 Music 버스", M._p[0].bus == &"Music" and M._p[1].bus == &"Music")
				var sfx = root.get_node("Sfx")
				check("효과음은 SFX 버스", sfx._pool.is_empty() or sfx._pool[0].bus == &"SFX")
				for k: String in ["match", "match_bard", "menu"]:
					check("BGM 키 " + k, G.BGM.has(k) and ResourceLoader.exists(G.BGM[k]))
				main.start_match()
				t0 = frame
				step_i += 1
		1:
			if el == 5:
				check("경기: 궁수면 match", M.key == "match", M.key)
				check("메뉴 곡과 같은 파일이면 다시 안 틂", M.current_path() == G.BGM.match)
				var s: AudioStream = M._p[M._active].stream
				check("루프 켜짐", s != null and bool(s.get("loop")))
				p.set_class("bard")  # 리스폰 때 병과가 바뀐 것처럼
				t0 = frame
				step_i += 1
		2:
			if el == 1:
				check("음유시인 → match_bard", M.key == "match_bard" and M.current_path() == G.BGM.match_bard, M.key)
			if el == 120:  # 1.5초 크로스페이드가 끝남
				var a: int = M._active
				check("크로스페이드 끝: 새 곡 1, 옛 곡 멈춤", is_equal_approx(M._gain[a], 1.0) and not M._p[1 - a].playing, "%.2f / %.2f" % [M._gain[a], M._gain[1 - a]])
				p.set_class("archer")
				t0 = frame
				step_i += 1
		3:
			if el == 30:  # 크로스페이드 중간
				var a: int = M._active
				check("다시 일반 곡 → 크로스페이드 중", M.key == "match" and M._gain[a] > 0.1 and M._gain[a] < 0.9 and M._gain[1 - a] > 0.1, "%.2f / %.2f" % [M._gain[a], M._gain[1 - a]])
			if el == 120:
				var a: int = M._active
				var pos: float = M._p[a].get_playback_position()
				step_i += 1
				t0 = frame
				p.set_class("crossbow")  # 같은 그룹 (궁수 → 석궁병)
				check("같은 그룹이면 그대로 이어서", M._active == a and M.key == "match" and M._p[a].playing, "pos %.2f" % pos)
		4:
			if el == 10:
				main.go_menu("main")
				check("메뉴로: menu (같은 파일이라 이어서)", M.key == "menu" and M.current_path() == G.BGM.menu)
				M.stop_bgm(0.5)
				t0 = frame
				step_i += 1
		5:
			if el == 40:
				check("stop_bgm: 멈춤", M.key == "" and not M._p[0].playing and not M._p[1].playing)
				M.play_bgm("menu", 0.1)
				_settings()
				print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
				quit(1 if fails > 0 else 0)


func _settings() -> void:
	var old_path: String = G.settings_path
	G.settings_path = "user://test_settings.cfg"
	G.save_enabled = true
	check("기본 볼륨 80/70/80", is_equal_approx(G.VOL_DEFAULT.master, 0.8) and is_equal_approx(G.VOL_DEFAULT.music, 0.7) and is_equal_approx(G.VOL_DEFAULT.sfx, 0.8))
	G.set_volume("master", 0.55)
	G.set_volume("music", 0.0)
	G.set_volume("sfx", 0.3)
	G.mouse_sens = 2.3
	G.third_person = false
	G.save_settings()
	G.set_volume("master", 1.0)
	G.set_volume("music", 1.0)
	G.set_volume("sfx", 1.0)
	G.mouse_sens = 1.0
	G.third_person = true
	G.load_settings()
	G.apply_volumes()
	check("저장 → 불러오기: 볼륨", is_equal_approx(G.volumes.master, 0.55) and is_equal_approx(G.volumes.music, 0.0) and is_equal_approx(G.volumes.sfx, 0.3), str(G.volumes))
	check("저장 → 불러오기: 감도·시점", is_equal_approx(G.mouse_sens, 2.3) and not G.third_person)
	var mi := AudioServer.get_bus_index("Master")
	var mu := AudioServer.get_bus_index("Music")
	var sf := AudioServer.get_bus_index("SFX")
	check("볼륨 → 버스 dB", is_equal_approx(AudioServer.get_bus_volume_db(mi), linear_to_db(0.55)) and is_equal_approx(AudioServer.get_bus_volume_db(sf), linear_to_db(0.3)))
	check("0%면 음소거", AudioServer.is_bus_mute(mu) and not AudioServer.is_bus_mute(mi))
	# 설정 패널: 슬라이더를 움직이면 바로 반영·저장
	var panel = load("res://scenes/ui/settings_panel.tscn").instantiate()
	root.add_child(panel)
	check("패널 볼륨 슬라이더 3개", panel._vol.size() == 3)
	check("패널이 불러온 값 표시", is_equal_approx(panel._vol.master.s.value, 55.0) and panel._vol.master.o.text == "55%", panel._vol.master.o.text)
	panel._vol.music.s.value = 40.0
	check("슬라이더 → 바로 버스", is_equal_approx(G.volumes.music, 0.4) and not AudioServer.is_bus_mute(mu) and is_equal_approx(AudioServer.get_bus_volume_db(mu), linear_to_db(0.4)))
	G.volumes.music = 1.0
	G.load_settings()
	check("슬라이더 값도 저장됨", is_equal_approx(G.volumes.music, 0.4))
	panel.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.settings_path))
	G.settings_path = old_path
	G.save_enabled = false
