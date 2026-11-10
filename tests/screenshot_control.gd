extends SceneTree
## 쟁탈전 맵을 위에서 내려다본 사진 → tests/screenshots/control_top.png (+ 비스듬한 사진 control_tilt.png)
## 화면이 있어야 함 (headless 아님): godot --path . --resolution 1400x760 -s tests/screenshot_control.gd
## 갈래 길 지점 = 노랑(시장 골목)·흰색(큰길)·주황(성벽 길) 공, 감시 지점 = 하늘색, 스폰 = 팀 색

var W


func _initialize() -> void:
	_run()


func _ball(pos: Vector3, col: Color, r := 0.8) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	m.mesh = s
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = col
	m.material_override = mt
	m.position = pos + Vector3(0, 0.6, 0)
	root.add_child(m)


func _run() -> void:
	var G := root.get_node("GameData")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = G.col(G.C.sky)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.look_at_from_position(Vector3(35, 70, 22), Vector3.ZERO)
	W = load("res://scripts/maps/map_control.gd").new()
	root.add_child(W)
	await process_frame
	W.set_cap_look(Color.WHITE, Color(0.24, 0.43, 0.84), 0.35, Color.WHITE, 0.0)  # 블루가 35% 점령 중
	var lane_cols := [Color(1, 0.9, 0.2), Color.WHITE, Color(1, 0.55, 0.15)]
	for team: String in ["blue", "red"]:
		var tc: Color = G.col(G.team_hex(team, "body"))
		var lanes: Array = W.lane_points(team)
		for i in lanes.size():
			for q: Vector3 in lanes[i]:
				_ball(q, lane_cols[i])
		for q: Vector3 in W.watch_spots(team):
			_ball(q, Color(0.4, 0.85, 1.0), 0.6)
		for q: Vector3 in W.spawn_spots(team):
			_ball(q, tc, 0.6)
	for q: Vector3 in W.item_spots():
		_ball(q, Color(1, 0.2, 0.9), 0.7)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 70.0
	cam.near = 1.0
	cam.far = 200.0
	root.add_child(cam)
	# 위에서 내려다봄: 화면 가로 = z (왼쪽 블루 +z, 오른쪽 레드 -z), 화면 위 = -x (신전 폐허), 아래 = +x (성벽·감시탑)
	cam.look_at_from_position(Vector3(0, 80, 0), Vector3.ZERO, Vector3(-1, 0, 0))
	cam.current = true
	for i in 30:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	var img := root.get_texture().get_image()
	img.save_png("res://tests/screenshots/control_top.png")
	# 비스듬히 (블루 스폰 쪽 위에서 거점을 봄)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60
	cam.look_at_from_position(Vector3(34, 38, 62), Vector3(0, 0, 4))
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png("res://tests/screenshots/control_tilt.png")
	print("SAVED")
	quit()
