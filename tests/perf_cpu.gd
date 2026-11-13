extends SceneTree
## CPU(스크립트) 비용: 헤드리스로 봇 경기를 돌리며 물리 프레임 한 번에 드는 시간을 잰다 (그리기 없음).
## 시스템별로 하나씩 꺼 보며 차이도 잰다 (봇 AI / 투사체·전투 / 아이템).
##   godot --headless --path . -s tests/perf_cpu.gd -- secs=8
## 결과: "CPU ..." 줄 (ms = 물리 프레임 한 번 평균, p99 = 느린 1%)

var main: Node
var G: Node
var secs := 8.0
var _t0 := 0
var _last := 0.0  # 마지막 물리 프레임에서 스크립트(_physics_process 전부)에 든 ms


## 물리 프레임 맨 처음·맨 끝에 도는 표시 노드 (process_physics_priority) — 그 사이 = 모든 노드의 _physics_process
class Mark extends Node:
	var cb: Callable
	func _physics_process(_dt: float) -> void:
		cb.call()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs="):
			secs = float(a.substr(5))
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = true
	G.chosen_cls = "archer"
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var a := Mark.new()
	a.process_physics_priority = -100000
	a.cb = func() -> void: _t0 = Time.get_ticks_usec()
	root.add_child(a)
	var b := Mark.new()
	b.process_physics_priority = 100000
	b.cb = func() -> void: _last = (Time.get_ticks_usec() - _t0) / 1000.0
	root.add_child(b)
	_run()


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## 물리 프레임마다 Performance.TIME_PHYSICS_PROCESS(스크립트 _physics_process + 물리 엔진)
func meas(label: String) -> void:
	await frames(30)
	var ts: Array[float] = []
	var proc := 0.0
	var t0 := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		await physics_frame
		ts.append(_last)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	ts.sort()
	var s := 0.0
	for t in ts:
		s += t
	print("CPU %-26s script=%.3fms p99=%.3fms process=%.3fms (프레임 %d)" % [label, s / ts.size(), ts[int(ts.size() * 0.99)], proc / ts.size(), ts.size()])


func _run() -> void:
	await frames(5)
	await meas("menu (봇 7 구경)")
	for mode: String in ["ffa", "control"]:
		G.mode = mode
		main.start_match()
		await frames(10)
		main.get_node("Player").invuln = 1e9
		G.ai_enabled = true
		await meas(mode + " 경기")
		G.ai_enabled = false
		await meas(mode + " 봇 AI 끔")
		G.ai_enabled = true
		main.go_menu("main")
		await frames(5)
	quit()
