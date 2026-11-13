extends SceneTree
## 경기 중 HUD에서 보이는 CanvasItem을 종류별로 세고, 무리별로 끄며 드로우콜 차이를 잰다 (화면 필요)
var main: Node
func _initialize() -> void:
	var G = root.get_node("GameData")
	G.save_enabled = false; G.hitstop_enabled = false; G.third_person = true; G.chosen_cls = "archer"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	G.mode = "control"
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	_run()
func frames(n: int) -> void:
	for i in n: await process_frame
func draws() -> float:
	await frames(10)
	var s := 0.0
	for i in 60:
		await process_frame
		s += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return s / 60
func _all(n: Node, out: Array) -> void:
	for c in n.get_children():
		out.append(c); _all(c, out)
func _run() -> void:
	await frames(5)
	root.get_node("GameData").ai_enabled = false
	main.start_match()
	await frames(60)
	paused = true
	var hud: CanvasLayer = main.hud
	var all := []
	_all(hud, all)
	var cnt := {}
	for n in all:
		if n is CanvasItem and n.is_visible_in_tree():
			var k: String = n.get_class() + ("(" + n.get_script().get_global_name() + ")" if n.get_script() and n.get_script().get_global_name() != "" else "")
			cnt[k] = cnt.get(k, 0) + 1
	print("HUDN ", cnt)
	var base: float = await draws()
	print("HUDD base %.0f" % base)
	# 맨 위 자식마다 끄고 차이
	var tops := []
	for c in hud.get_children():
		if c is CanvasItem and c.visible:
			tops.append(c)
	for c in tops:
		var kids := []
		_all(c, kids)
		var vis := 0
		for k in kids:
			if k is CanvasItem and k.is_visible_in_tree(): vis += 1
		c.visible = false
		var d: float = await draws()
		c.visible = true
		print("HUDD -%s(%s, 보이는 자식 %d) %.0f → 줄어듦 %.0f" % [c.name, c.get_class(), vis, d, base - d])
	# 두 번째 층 (가장 큰 것 안쪽)
	for c in tops:
		for c2 in c.get_children():
			if c2 is CanvasItem and c2.is_visible_in_tree():
				c2.visible = false
				var d: float = await draws()
				c2.visible = true
				if base - d >= 5:
					print("HUDD   -%s/%s(%s) 줄어듦 %.0f" % [c.name, c2.name, c2.get_class(), base - d])
					var sub := []
					_all(c2, sub)
					var desc := []
					for s in [c2] + sub:
						if s is CanvasItem and s.is_visible_in_tree():
							var sc = s.get_script()
							desc.append("%s%s%s" % [s.get_class(), ("[" + str(sc.resource_path).get_file() + "]") if sc else "", (" '" + s.text.left(12) + "'") if "text" in s else ""])
					print("HUDD      ", desc)
					# 셋째 층
					for c3 in c2.get_children():
						if c3 is CanvasItem and c3.is_visible_in_tree():
							c3.visible = false
							var d3: float = await draws()
							c3.visible = true
							print("HUDD        -%s(%s) 줄어듦 %.0f" % [c3.name, c3.get_class(), base - d3])
	quit()
