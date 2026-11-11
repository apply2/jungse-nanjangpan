extends SceneTree
## 3인칭 손에 든 무기 크기 비교 사진 → tests/screenshots/held_<tag>_4m.png · _8m · _20m (병과 5 + 저격총·AK·닭·말, 3×3 격자)
## + 내 캐릭터 어깨 너머 화면 held_<tag>_self.png, 그리고 내 무기가 조준점 둘레(화면 높이 10%)를 가리는지 숫자로 출력.
## 화면이 있어야 함 (headless 아님): godot --path . --resolution 1280x720 -s tests/screenshot_held.gd -- tag=after

var G: Node
var M: Node
var tag := "after"

const SUBJECTS := [["barbarian", ""], ["archer", ""], ["crossbow", ""], ["cleric", ""], ["bard", ""],
	["archer", "sniper"], ["archer", "ak"], ["archer", "chicken"], ["archer", "horse"]]
const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.ai_enabled = false
	G.mode = "ffa"
	G.third_person = true
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


## 사진 찍을 자리: 피사체 오른쪽 앞 대각선 20m까지 막힌 데가 없는 평평한 곳
func _spot(c) -> Vector3:
	var d := Vector3(1, 0, -1).normalized()
	for z in range(-30, 31, 6):
		for x in range(-30, 31, 6):
			var gy: float = c.ground_below(Vector3(x, 2.0, z))
			if absf(gy) > 0.3:
				continue
			var p := Vector3(x, gy + 1.3, z)
			if c.world_ray(p, d * 21.0 + Vector3(0, 0.6, 0)) >= 1.0 and c.world_ray(p + Vector3(0, 1.5, 0), d * 21.0) >= 1.0:
				return Vector3(x, gy, z)
	return Vector3(0, 0, 20)


func _pose(e, cls: String, item: String, at: Vector3) -> void:
	if e.mounted > 0:
		M.combat.items.dismount(e)
	e.next_cls = cls
	e.spawn_at(at)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = 0.0   # -Z를 봄 → 오른손은 +X 쪽
	e.pitch = 0.0
	match item:
		"sniper":
			e.has_sniper = true
			e.ammo = 5
			e.wep = "sniper"
		"ak":
			e.has_ak = true
			e.ak_ammo = 25
			e.wep = "ak"
		"chicken":
			e.has_chicken = true
			e.wep = "chicken"
		"horse":
			M.combat.items.mount(e)
			e.mounted = 9999.0


func _run() -> void:
	await frames(20)
	var p = M.player
	var subj = null
	for e in M.combat.ents:
		if e != p:
			if subj == null:
				subj = e
			else:
				e.spawn_at(Vector3(300, -80, 300))
				e.alive = false
				e.process_mode = Node.PROCESS_MODE_DISABLED
	M.hud.visible = false
	var spot := _spot(M.combat)
	print("자리 ", spot)
	p.spawn_at(Vector3(300, -60, 300))
	p.alive = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screenshots"))
	var dir := Vector3(1, 0, -1).normalized()  # 피사체 오른쪽 앞에서 봄 (오른손 무기가 보이게)
	for dist in [4.0, 8.0, 20.0]:
		var sheet: Image = null
		for i in SUBJECTS.size():
			var s: Array = SUBJECTS[i]
			_pose(subj, s[0], s[1], spot)
			await frames(25)
			var look := spot + Vector3(0, 1.6 if s[1] == "horse" else 1.1, 0)
			cam.look_at_from_position(look + dir * dist + Vector3(0, 0.5, 0), look)
			cam.fov = 60.0 if dist < 10 else 30.0  # 20m는 망원으로 (그대로면 점처럼 작음)
			await frames(4)
			var img := root.get_texture().get_image()
			var w := img.get_width() / 3
			var h := img.get_height() / 3
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			if sheet == null:
				sheet = Image.create(w * 3, h * 3, false, img.get_format())
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
		sheet.save_png("res://tests/screenshots/held_%s_%dm.png" % [tag, int(dist)])
	# ── 내 캐릭터 어깨 너머: 무기가 조준점 둘레를 가리나 ──
	cam.current = false
	subj.spawn_at(Vector3(300, -80, 300))
	subj.alive = false
	p.process_mode = Node.PROCESS_MODE_INHERIT
	M.hud.visible = true
	var worst := {}
	var shots: Array[Image] = []
	for s: Array in SUBJECTS:
		if s[1] == "horse":
			continue
		var key: String = s[1] if s[1] != "" else str(s[0])
		for pitch in [-0.5, 0.0, 0.5]:
			_pose(p, s[0], s[1], spot)
			p.pitch = pitch
			p.cam.current = true
			await frames(30)
			var cover := _cover(p)
			worst[key] = maxf(float(worst.get(key, 0.0)), cover)
			if pitch == 0.0:
				var img := root.get_texture().get_image()
				img.resize(img.get_width() / 3, img.get_height() / 3, Image.INTERPOLATE_BILINEAR)
				shots.append(img)
	var w2 := shots[0].get_width()
	var h2 := shots[0].get_height()
	var sh := Image.create(w2 * 3, h2 * 3, false, shots[0].get_format())
	for i in shots.size():
		sh.blit_rect(shots[i], Rect2i(0, 0, w2, h2), Vector2i((i % 3) * w2, (i / 3) * h2))
	sh.save_png("res://tests/screenshots/held_%s_self.png" % tag)
	for k: String in worst:
		print("조준점 가림 %-9s %.0f%% (조준점 둘레 반지름 화면 높이 10%% 원 안에 들어온 무기 점 비율, 고개 위·가운데·아래 중 최대)" % [k, float(worst[k]) * 100.0])
	quit(0)


## 들고 있는 무기 메시 꼭짓점(AABB 8점 + 가운데) 중 화면 가운데 원(반지름 = 화면 높이 10%) 안에 들어오는 비율
func _cover(p) -> float:
	var m = p.model
	if m == null:
		return 0.0
	var w: Node3D = m.weapons.get(p.wep)
	if p.mounted > 0 and p.horse.has("lance"):
		w = p.horse.lance
	if w == null:
		return 0.0
	var vp := root.get_visible_rect().size
	var c := vp / 2
	var r := vp.y * 0.1
	var n := 0
	var inside := 0
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var gi := mi as MeshInstance3D
		var bb := gi.get_aabb()
		var pts := [bb.get_center()]
		for k in 8:
			pts.append(bb.get_endpoint(k))
		for q: Vector3 in pts:
			var wp: Vector3 = gi.global_transform * q
			if p.cam.is_position_behind(wp):
				continue
			n += 1
			if p.cam.unproject_position(wp).distance_to(c) < r:
				inside += 1
	return float(inside) / maxf(1.0, float(n))
