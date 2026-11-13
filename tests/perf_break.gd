extends SceneTree
## 드로우콜이 어디서 나오나: 쟁탈전 봇 경기에서 하나씩 끄고 드로우콜·프레임 시간 차이를 잰다 (화면 필요)
##   godot --path . --resolution 1280x720 -s tests/perf_break.gd

var main: Node
var G: Node


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = true
	G.chosen_cls = "archer"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func meas(label: String) -> void:
	await frames(20)
	var n := 0
	var draw := 0.0
	var prims := 0.0
	var t0 := Time.get_ticks_usec()
	while n < 180:
		await process_frame
		n += 1
		draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("BRK %-28s draw=%5.0f prims=%7.0f ms=%.2f" % [label, draw / n, prims / n, ms])


func _all(node: Node, out: Array) -> void:
	for c in node.get_children():
		out.append(c)
		_all(c, out)


func _run() -> void:
	await frames(5)
	# 메뉴
	await meas("menu")
	var crowd = main.find_child("*Crowd*", true, false)
	print("menu crowd node: ", crowd)
	for mode: String in ["control", "ffa"]:
		G.mode = mode
		main.start_match()
		await frames(10)
		var p = main.get_node("Player")
		p.invuln = 1e9
		# 같은 장면: 나는 정해진 자리, 봇은 앞에 줄 세움 (3~24m), 멈춤 (그리기는 계속)
		G.ai_enabled = false
		var spot: Vector3 = Vector3(0, 0, 30) if mode == "control" else Vector3(0, 0, 30)
		p.spawn_at(spot)
		p.yaw = 0.0
		p.pitch = -0.05
		p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
		var i := 0
		for e in main.get_node("Combat").ents:
			if e == p:
				continue
			e.spawn_at(spot + Vector3((i % 3 - 1) * 2.5, 0, -3.0 - i * 2.5))
			e.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
			e.yaw = PI
			i += 1
		await frames(30)
		paused = true
		await meas(mode + " base")
		main.sun.shadow_enabled = false
		await meas(mode + " -shadow")
		main.sun.shadow_enabled = true
		var w = main.get_node("Combat").world
		for mmi in w.grass_nodes:
			mmi.visible = false
		await meas(mode + " -grass")
		for mmi in w.grass_nodes:
			mmi.visible = true
		for nd in w.clutter_nodes:
			nd.visible = false
		await meas(mode + " -clutter")
		for nd in w.clutter_nodes:
			nd.visible = true
		var ents: Array = main.get_node("Combat").ents
		for e in ents:
			if e.model:
				e.model.visible = false
		await meas(mode + " -characters")
		for e in ents:
			if e.model:
				e.model.visible = true
		main.hud.visible = false
		await meas(mode + " -hud(+viewmodel)")
		main.hud.visible = true
		# 맵 전체 끄면 남는 것
		w.visible = false
		await meas(mode + " -world")
		w.visible = true
		# 노드 종류별 개수
		var all: Array = []
		_all(w, all)
		var mi := 0
		var mm := 0
		var vis_mi := 0
		for nd in all:
			if nd is MultiMeshInstance3D:
				mm += 1
			elif nd is MeshInstance3D:
				mi += 1
				if nd.is_visible_in_tree():
					vis_mi += 1
		print("BRK %s world: MeshInstance3D=%d (보이는 %d) MultiMesh=%d nodes=%d" % [mode, mi, vis_mi, mm, all.size()])
		var call: Array = []
		_all(main.get_node("Combat"), call)
		var cmi := 0
		for nd in call:
			if nd is MeshInstance3D and nd.is_visible_in_tree():
				cmi += 1
		print("BRK %s combat 아래 보이는 MeshInstance3D=%d" % [mode, cmi])
		paused = false
		main.go_menu("main")
		await frames(5)
	quit()
