extends SceneTree
## 프레임 튐(끊김) 측정: 봇 경기 secs초 동안 프레임 시간을 전부 기록해 평균 FPS·1% low·최악 프레임을 낸다.
## perf_maps.gd와 같은 조건(3인칭, 보통 난이도, 궁수, vsync 끔)이지만 사진은 안 찍는다 (파일을 만들지 않음).
## 화면이 있어야 함 (headless 아님). 소리는 끈다 (믹싱은 그대로 돎).
##   godot --path . --resolution 1280x720 -s tests/perf_hitch.gd -- tag=now quality=normal secs=30
##   drive=stand(기본, 내 캐릭터는 무적으로 서 있음) / bot(내 캐릭터도 봇 AI가 조종 — 죽고 부활하고 쏨)
##   view=tp(기본) / fp(1인칭 — 뷰모델 포함)   maps=ffa,control   top=12(느린 프레임 몇 개를 자세히 찍나)   seed=숫자(봇 무작위)
## 결과: 콘솔에 "HITCH ..." 한 줄씩 + 느린 프레임 목록 "  SPIKE ..."
##   p99·low1 = 느린 쪽 1% 프레임, over16 = 16.7ms(60Hz 한 프레임)를 넘긴 프레임 수
##   SPIKE 줄의 script·draw·physics·other = 그 프레임 안에서 _process / 그리기 / 물리 / 그 밖(창 이벤트)에 쓴 ms + 그때 생긴 사건
##   STARTUP·MATCHSTART = 시작·경기 시작 직후 걸린 시간 (재는 구간에는 안 들어감)

var main: Node
var G: Node
var tag := "now"
var quality := "normal"
var secs := 30.0
var maps: PackedStringArray = ["ffa", "control"]
var drive := "stand"
var view := "tp"
var top := 12
var rseed := 20261111
# 프레임 안 구간 시각 (usec): 물리 시작 · 화면 프레임 시작 · 그리기 시작 · 그리기 끝
var _t_phys := 0
var _t_pre := 0
var _t_post := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"tag": tag = kv[1]
				"quality": quality = kv[1]
				"secs": secs = float(kv[1])
				"maps": maps = kv[1].split(",")
				"drive": drive = kv[1]
				"view": view = kv[1]
				"top": top = int(kv[1])
				"seed": rseed = int(kv[1])
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = view != "fp"
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	G.set("gfx_quality", quality)
	seed(rseed)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


## 그리기 튐의 원인을 짚으려고 보는 상태 값들
func _state(combat: Node) -> Dictionary:
	var it = combat.items
	var st := {"sniper": it.sniper.active, "ak": it.ak.active, "fish": it.fish.active, "horse": it.horse.active or it.horse_b.active,
		"chickens": it.chickens.size(), "ragdolls": combat.ragdolls.size(), "helms": combat.loose_helms.size(),
		"stars": 0, "playing": 0, "dancing": 0, "mounted": 0, "guns": 0, "bardfx": combat.bard_fx._objs.size()}
	for e in combat.ents:
		if e.alive:
			st.stars += int(e.star_t > 0)
			st.playing += int(e.playing)
			st.dancing += int(e.dance_t > 0)
			st.mounted += int(e.mounted > 0)
			st.guns += int(e.has_sniper or e.has_ak)
	var h = main.hud
	st["hurt"] = h._hurt > 0.0
	st["dirs"] = h._dirs.items.size()
	st["feed"] = h._feed_items.size()
	st["nums"] = h._nums.size()
	st["death"] = h._death.visible
	st["scope"] = h._scope.visible
	st["dance_edge"] = h._dance.visible
	st["star_edge"] = h._star.visible
	st["pop"] = h._pop_t < 1.0
	st["hitmark"] = h._hitmark.visible
	st["board"] = h._board.visible
	st["wep"] = main.player.wep
	if combat.mode:
		st["phase"] = combat.mode.phase
		st["holder"] = combat.mode.holder
		st["cap"] = combat.mode.cap_team
	return st


func _run() -> void:
	var ts := Time.get_ticks_msec()
	await frames(12)
	print("STARTUP tag=%s 첫 12프레임 = %dms (맵·메뉴 첫 그리기 + 셰이더 컴파일)" % [tag, Time.get_ticks_msec() - ts])
	physics_frame.connect(func() -> void:
		if _t_phys == 0:
			_t_phys = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _t_post = Time.get_ticks_usec())
	for map: String in maps:
		G.mode = map
		G.ai_enabled = false
		ts = Time.get_ticks_msec()
		main.start_match()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # 재는 동안 마우스를 가두지 않는다
		await frames(10)
		print("MATCHSTART tag=%s map=%s 경기 시작 뒤 10프레임 = %dms" % [tag, map, Time.get_ticks_msec() - ts])
		var p = main.get_node("Player")
		var combat = main.get_node("Combat")
		if drive == "bot":
			p.ai = load("res://scripts/bot_ai.gd").new()
			p.ai.reset(combat.world.random_point())
		else:
			p.invuln = 1e9
		G.ai_enabled = true
		await frames(30)
		var dts := PackedFloat32Array()
		var rows: Array = []  # [ms, t, 스크립트(_process) ms, 그리기 ms, 물리 ms, 그 밖 ms, 사건] — 지난 화면 프레임 시작 → 이번 시작
		var seg := [0.0, 0.0, 0.0, 0.0]  # 구간별 합
		var draw_sum := 0.0
		var prim_sum := 0.0
		var paused := 0
		var alive := {}
		for e in combat.ents:
			alive[e] = e.alive
		var st0 := _state(combat)
		var ev0 := ""
		var fx_n := 0
		var proj_n := 0
		var zone_n := 0
		var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_t_phys = 0
		var t0 := Time.get_ticks_usec()
		var prev := t0
		while (prev - t0) / 1e6 < secs:
			await process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - prev) / 1000.0
			var prev0 := prev
			prev = now
			if main.state != "playing":  # 창이 포커스를 잃으면 일시정지됨 → 풀고 그 프레임은 뺀다
				paused += 1
				main.resume_game()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_t_phys = 0
				continue
			dts.append(ms)
			draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prim_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			var ev := ""
			for e in combat.ents:
				if e.alive != alive.get(e, e.alive):
					alive[e] = e.alive
					ev += (" +spawn:" if e.alive else " -death:") + str(e.cls)
			# 이번 프레임에 새로 생긴 효과·투사체 (그리기 튐이 무엇과 같이 나오는지 보려고)
			var fxl: Array = combat.fx._fx
			if fxl.size() > fx_n:
				var kinds := {}
				for i in range(fx_n, fxl.size()):
					kinds[fxl[i].type] = int(kinds.get(fxl[i].type, 0)) + 1
				ev += " fx" + str(kinds)
			fx_n = fxl.size()
			if combat.projectiles.size() > proj_n:
				ev += " proj:" + str(combat.projectiles[-1].kind)
			proj_n = combat.projectiles.size()
			if combat.zones.size() > zone_n:
				ev += " zone"
			zone_n = combat.zones.size()
			# 아이템·무적·연주·춤·래그돌·쟁탈전 단계가 바뀌었나
			var st := _state(combat)
			for k: String in st:
				if st[k] != st0.get(k):
					ev += " %s=%s" % [k, st[k]]
			st0 = st
			var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			if absf(nodes - nodes0) >= 20:
				ev += " nodes%+d" % int(nodes - nodes0)
			nodes0 = nodes
			# 지난 프레임: [시작 prev0] _process → [_t_pre] 그리기·화면 넘김 → [_t_post] 입력·기타 → [_t_phys] 물리 → [now]
			var a := (_t_pre - prev0) / 1000.0
			var b := (_t_post - _t_pre) / 1000.0
			var c := ((now - _t_phys) / 1000.0) if _t_phys > 0 else 0.0
			var d := ms - a - b - c
			seg[0] += a
			seg[1] += b
			seg[2] += c
			seg[3] += d
			# 그리기는 지난 프레임 상태를 그린 것이라 지난 프레임 사건도 같이 적는다
			rows.append([ms, (now - t0) / 1e6, a, b, c, d, ev0 + " |" + ev])
			ev0 = ev
			_t_phys = 0
		var n := dts.size()
		var el := 0.0
		for v in dts:
			el += v
		var sorted := dts.duplicate()
		sorted.sort()
		var k1 := maxi(1, n / 100)
		var k01 := maxi(1, n / 1000)
		var s1 := 0.0
		for i in k1:
			s1 += sorted[n - 1 - i]
		var s01 := 0.0
		for i in k01:
			s01 += sorted[n - 1 - i]
		var over8 := 0
		var over16 := 0
		var over33 := 0
		for v in dts:
			if v > 8.34: over8 += 1
			if v > 16.67: over16 += 1
			if v > 33.34: over33 += 1
		print("HITCH tag=%s map=%s drive=%s view=%s bots=%d frames=%d fps=%.1f avg=%.2fms p50=%.2f p99=%.2f p999=%.2f max=%.2f low1=%.1ffps(%.2fms) low01=%.1ffps(%.2fms) over8=%d over16=%d over33=%d draw=%.0f prims=%.0f paused=%d" % [
			tag, map, drive, view, combat.ents.size() - 1, n, n / (el / 1000.0), el / n,
			sorted[n / 2], sorted[mini(n - 1, int(n * 0.99))], sorted[mini(n - 1, int(n * 0.999))], sorted[n - 1],
			1000.0 / (s1 / k1), s1 / k1, 1000.0 / (s01 / k01), s01 / k01, over8, over16, over33, draw_sum / n, prim_sum / n, paused])
		print("  SEG avg per frame: script=%.3fms draw=%.3fms physics=%.3fms other=%.3fms" % [seg[0] / n, seg[1] / n, seg[2] / n, seg[3] / n])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for i in mini(top, rows.size()):
			var r: Array = rows[i]
			print("  SPIKE %.2fms t=%.2fs script=%.2f draw=%.2f physics=%.2f other=%.2f%s" % r)
		main.go_menu("main")
		await frames(5)
	quit()
