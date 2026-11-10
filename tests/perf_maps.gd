extends SceneTree
## 맵 꾸미기 전/후 비교: 같은 카메라 5곳 스크린샷 + 봇 경기 30초 평균 FPS·드로우콜.
## 화면이 있어야 함 (headless 아님). vsync를 끄고 잰다.
##   godot --path . --resolution 1280x720 -s tests/perf_maps.gd -- tag=after quality=normal secs=30
## 결과: tests/screenshots/deco_<tag>_<map>_<곳>.png, 콘솔에 "PERF ..." 줄

var main: Node
var G: Node
var tag := "now"
var quality := ""
var secs := 30.0

const SHOTS := {
	"ffa": [
		["spawn", Vector3(0, 1.8, 38), Vector3(0, 1.5, 20)],
		["point", Vector3(12, 6, 13), Vector3(0, 2, 0)],
		["alley", Vector3(-20, 1.8, -24), Vector3(-28, 2.5, -16)],
		["wall", Vector3(30, 2.2, 38), Vector3(42, 3, 46)],
		["top", Vector3(0, 75, 34), Vector3(0, 0, 2)],
	],
	"control": [
		["spawn", Vector3(0, 1.8, 50.5), Vector3(0, 1.5, 32)],
		["point", Vector3(13, 6, 14), Vector3(0, 0.5, 0)],
		["alley", Vector3(-19.5, 1.8, 37), Vector3(-26, 1.8, 20)],
		["wall", Vector3(21, 2.2, 38), Vector3(30, 2.5, 22)],
		["top", Vector3(0, 82, 40), Vector3(0, 0, 4)],
	],
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"tag": tag = kv[1]
				"quality": quality = kv[1]
				"secs": secs = float(kv[1])
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = true
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	if quality != "" and "gfx_quality" in G:
		G.set("gfx_quality", quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await frames(5)
	if G.has_method("apply_gfx"):
		G.apply_gfx()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	var results := []
	for map: String in ["ffa", "control"]:
		G.mode = map
		G.ai_enabled = false
		main.start_match()
		await frames(10)
		var p = main.get_node("Player")
		p.invuln = 1e9
		main.hud.visible = false
		var cam := Camera3D.new()
		cam.fov = 70
		cam.far = 400
		root.add_child(cam)
		for s: Array in SHOTS[map]:
			cam.look_at_from_position(s[1], s[2], Vector3(-1, 0, 0) if s[0] == "top" and map == "control" else Vector3.UP)
			cam.current = true
			await frames(12)
			root.get_texture().get_image().save_png("res://tests/screenshots/deco_%s_%s_%s.png" % [tag, map, s[0]])
		cam.queue_free()
		p.cam.current = true
		main.hud.visible = true
		# 성능: 봇 AI 켜고 secs초 (내 캐릭터는 무적으로 서 있음)
		G.ai_enabled = true
		await frames(30)
		var n := 0
		var draw_sum := 0.0
		var prim_sum := 0.0
		var t0 := Time.get_ticks_usec()
		while (Time.get_ticks_usec() - t0) / 1e6 < secs:
			await process_frame
			n += 1
			draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prim_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var el := (Time.get_ticks_usec() - t0) / 1e6
		var bots: int = main.get_node("Combat").ents.size() - 1
		var line := "PERF tag=%s map=%s bots=%d fps=%.1f draw=%.0f prims=%.0f" % [tag, map, bots, n / el, draw_sum / n, prim_sum / n]
		print(line)
		results.append(line)
		main.go_menu("main")
		await frames(5)
	var f := FileAccess.open("res://tests/screenshots/perf_%s.txt" % tag, FileAccess.WRITE)
	f.store_string("\n".join(results) + "\n")
	f.close()
	quit()
