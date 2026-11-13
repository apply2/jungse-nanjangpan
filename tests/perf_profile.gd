extends SceneTree
## 성능 프로파일: 봇 경기를 secs초 돌리며 평균 FPS·1% 최저·프레임 시간·CPU(process/physics)·드로우콜·노드 수를 잰다.
## 화면이 있어야 함 (headless면 그리기 값이 0). vsync 끄고 잰다.
##   godot --path . --resolution 1280x720 -s tests/perf_profile.gd -- tag=before secs=20
## 결과: 콘솔 "PROF ..." 줄 + tests/screenshots/prof_<tag>.txt

var main: Node
var G: Node
var tag := "now"
var secs := 20.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"tag": tag = kv[1]
				"secs": secs = float(kv[1])
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = true
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _measure(label: String) -> String:
	var n := 0
	var ft: Array[float] = []
	var proc := 0.0
	var phys := 0.0
	var draw := 0.0
	var prims := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		await process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
		n += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var el := (Time.get_ticks_usec() - t0) / 1e6
	ft.sort()
	var p99: float = ft[int(ft.size() * 0.99)]
	var p999: float = ft[mini(ft.size() - 1, int(ft.size() * 0.999))]
	return "PROF tag=%s %s fps=%.0f avg_ms=%.2f p99_ms=%.2f max_ms=%.2f proc_ms=%.2f phys_ms=%.2f draw=%.0f prims=%.0f nodes=%d objs=%d" % [
		tag, label, n / el, el * 1000.0 / n, p99, p999, proc / n, phys / n, draw / n, prims / n,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)]


func _run() -> void:
	await frames(5)
	var results := []
	# 메뉴 (봇 구경)
	await frames(60)
	results.append(await _measure("scene=menu"))
	print(results[-1])
	for map: String in ["ffa", "control"]:
		G.mode = map
		main.start_match()
		await frames(10)
		var p = main.get_node("Player")
		p.invuln = 1e9
		G.ai_enabled = true
		await frames(60)
		results.append(await _measure("scene=" + map))
		print(results[-1])
		main.go_menu("main")
		await frames(5)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	var f := FileAccess.open("res://tests/screenshots/prof_%s.txt" % tag, FileAccess.WRITE)
	f.store_string("\n".join(results) + "\n")
	f.close()
	quit()
