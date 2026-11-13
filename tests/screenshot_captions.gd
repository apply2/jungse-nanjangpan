extends SceneTree
## 자막(배경 없는 잠깐 뜨는 글자) 읽힘 확인 사진 → tests/screenshots/cap_<tag>_<배경>_<가로>.png
##   배경 3곳: sky(밝은 하늘) · ground(흙길·모래 바닥) · wall(어두운 성벽)
##   <배경>.png = 배너(큰 문구+작은 줄)·조준점 아래 자막·데미지 숫자(보통·헤드샷·처치·춤춰라!·삑!)·아이템 안내 줄·무적 남은 시간
##   <배경>_death.png = 사망 자막
## 화면이 있어야 함: godot --path . --resolution 1280x720 -s tests/screenshot_captions.gd -- tag=after
##                  (1920x1080도 같은 식으로)

var G: Node
var M: Node
var tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	G = root.get_node("GameData")
	G.save_enabled = false
	G.ai_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.third_person = false
	G.chosen_cls = "barbarian"
	G.mode = "ffa"
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await frames(40)
	var p = M.player
	var H = M.hud
	var A := 46.0  # world_builder.ARENA_HALF (성벽)
	var spots := {
		"sky": [Vector3(10, 0.3, 20), 0.6, 1.2],
		"ground": [Vector3(0, 0.3, 9), 0.0, -1.2],
		"wall": [Vector3(8, 0.3, -A + 4.5), 0.0, 0.25],
	}
	for name: String in spots:
		var s: Array = spots[name]
		H.player = p
		p.global_position = s[0]
		p.velocity = Vector3.ZERO
		p.yaw = s[1]
		p.pitch = s[2]
		p.star_t = 4.0
		await frames(10)
		H.clear()
		H.banner("라운드 2", "거점이 열렸습니다! · 블루 1 : 0 레드")
		H.pop_msg("처치! 멍청한 봇")
		var cam: Camera3D = p.cam
		var f := -cam.global_transform.basis.z
		var r := cam.global_transform.basis.x
		var u := cam.global_transform.basis.y
		var at := cam.global_position + f * 4.0
		H.spawn_num(at - r * 1.6 + u * 0.2, "10", "")
		H.spawn_num(at - r * 0.8 - u * 0.5, "45", "head")
		H.spawn_num(at + r * 0.9 - u * 0.4, "처치!", "kill")
		H.spawn_num(at + r * 1.7 + u * 0.3, "춤춰라!", "dance")
		H.spawn_num(at + r * 1.2 - u * 1.0, "삑!", "squeak")
		H.spawn_num(at - r * 1.7 - u * 1.0, "8", "dot")
		H._info.sniper.text = "대물 저격총 23m · 31초 남음"
		await frames(16)
		H.player = null  # 여기서 멈춤 (애니메이션·사망 숨김이 안 돌게)
		await _save(name)
		# 사망 자막은 따로 (실제로는 배너와 같이 안 뜸)
		H.clear()
		H._info.sniper.text = ""
		H._death_by.text = "[center][color=%s]%s[/color]에게 당했다[/center]" % [str(G.MODES.control.teams.red.ink), "멍청한 봇"]
		H._death_sub.text = "석궁 · 헤드샷 · 3초 뒤 부활"
		H._death.visible = true
		await frames(4)
		H._death.position.x = (H._death.get_parent_area_size().x - H._death.size.x) / 2
		await _save(name + "_death")
		H._death.visible = false
	quit()


func _save(name: String) -> void:
	await frames(3)
	var img := root.get_texture().get_image()
	var path := "res://tests/screenshots/cap_%s_%s_%d.png" % [tag, name, img.get_width()]
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
