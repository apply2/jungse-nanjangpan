extends SceneTree
## 캐릭터 하나가 몇 조각(드로우콜)·몇 삼각형인지 병과별로 (화면 필요)
##   godot --path . --resolution 640x360 -s tests/perf_model.gd
func _initialize() -> void:
	_run()
func _tris(n: Node, acc: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh and n.is_visible_in_tree():
		acc.n += 1
		var t := 0
		for s in n.mesh.get_surface_count():
			var a: Array = n.mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx else a[Mesh.ARRAY_VERTEX].size()) / 3
		acc.t += t
		var key: String = n.mesh.get_class() + ("" if n.mesh.resource_name == "" else ":" + n.mesh.resource_name)
		acc.big.append([t, str(n.get_path()).get_file(), key])
	for c in n.get_children():
		_tris(c, acc)
func _run() -> void:
	await process_frame
	var G = root.get_node("GameData")
	var DM = load("res://scripts/derp_model.gd")
	for cls in G.CLASSES:
		var m = DM.new(cls, "")
		root.add_child(m)
		await process_frame
		await process_frame
		var acc := {"n": 0, "t": 0, "big": []}
		_tris(m, acc)
		acc.big.sort_custom(func(a, b): return a[0] > b[0])
		print("MODEL %-9s 조각=%d 삼각형=%d  큰 것: %s" % [cls, acc.n, acc.t, str(acc.big.slice(0, 6))])
		m.queue_free()
	quit()
