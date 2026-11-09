class_name WorldBuilder
extends Node3D
## 맵 생성 — HTML buildWorld() / house() / crate() / stall() / tree() 를 그대로 옮긴 것.
## Three.js와 Godot은 좌표계가 같다 (Y가 위, -Z가 앞, 오른손 좌표계) → 숫자를 그대로 쓰면 된다.
## 충돌은 StaticBody3D 하나에 BoxShape3D를 여러 개 붙인다.
## 같은 상자들을 aabbs 배열에도 담아두는데, 스폰 지점 검사·봇 시야 검사 같은 가벼운 계산에 쓴다.

const ARENA_HALF := 46.0  # 성벽 위치 (HTML의 A)

var body: StaticBody3D
var aabbs: Array[AABB] = []
var spawn_points: Array[Vector3] = []

var _box := BoxMesh.new()
var _sph := SphereMesh.new()
var _cyl := CylinderMesh.new()
var _cone := CylinderMesh.new()
var _roof := CylinderMesh.new()
var _clouds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_box.size = Vector3.ONE
	_sph.radius = 1.0
	_sph.height = 2.0
	_sph.radial_segments = 20
	_sph.rings = 14
	_cyl.top_radius = 1.0
	_cyl.bottom_radius = 1.0
	_cyl.height = 1.0
	_cyl.radial_segments = 14
	_cone.top_radius = 0.0
	_cone.bottom_radius = 1.0
	_cone.height = 1.0
	_cone.radial_segments = 14
	_roof.top_radius = 0.0
	_roof.bottom_radius = 1.0
	_roof.height = 1.0
	_roof.radial_segments = 4
	body = StaticBody3D.new()
	body.name = "Colliders"
	add_child(body)
	build()
	_build_spawns()


func _process(dt: float) -> void:
	for c in _clouds:
		c.position.x += dt * 1.2
		if c.position.x > 160.0:
			c.position.x = -160.0


# ── 기본 도구 ────────────────────────────────────────────────
func mesh(m: Mesh, hex: int, pos: Vector3, scl: Vector3, shadow := true, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = GameData.mat(hex)
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func add_col(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> void:
	var a := AABB(Vector3(x0, y0, z0), Vector3(x1 - x0, y1 - y0, z1 - z0))
	aabbs.append(a)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = a.size
	cs.shape = bs
	cs.position = a.get_center()
	body.add_child(cs)


## HTML box(x,y,z,w,h,d,color,collide,shadow): y는 바닥 높이, 상자는 그 위로 h만큼
func box(x: float, y: float, z: float, w: float, h: float, d: float, hex: int, collide := true, shadow := true) -> MeshInstance3D:
	var m := mesh(_box, hex, Vector3(x, y + h / 2.0, z), Vector3(w, h, d), shadow)
	if collide:
		add_col(x - w / 2.0, y, z - d / 2.0, x + w / 2.0, y + h, z + d / 2.0)
	return m


## 사각뿔 지붕. Three.js에선 지오메트리를 45° 돌려 구웠으므로, 여기선 부모가 크기를 맡고 자식이 회전한다.
func roof(pos: Vector3, scl: Vector3, hex: int) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.scale = scl
	add_child(holder)
	var mi := mesh(_roof, hex, Vector3.ZERO, Vector3.ONE, true, holder)
	mi.rotation.y = PI / 4.0


func overlaps_any(p: Vector3, r: float, h: float) -> bool:
	for a in aabbs:
		if p.x + r > a.position.x and p.x - r < a.end.x and p.z + r > a.position.z and p.z - r < a.end.z \
				and p.y + h > a.position.y and p.y < a.end.y:
			return true
	return false


# ── 맵 ───────────────────────────────────────────────────────
func build() -> void:
	var C: Dictionary = GameData.C
	# 땅 (보이는 판 + 아래쪽 두꺼운 충돌 상자)
	var ground := PlaneMesh.new()
	ground.size = Vector2(320, 320)
	mesh(ground, C.grass, Vector3.ZERO, Vector3.ONE, false)
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(400, 2, 400)
	gcs.shape = gbs
	gcs.position = Vector3(0, -1, 0)
	body.add_child(gcs)

	# 흙길
	box(0, 0, 0, 5, 0.02, 88, C.path, false, false)
	box(0, 0, 0, 88, 0.02, 5, C.path, false, false)
	box(0, 0, 0, 24, 0.015, 24, 0xd4b273, false, false)
	var A := ARENA_HALF
	# 성벽과 총안
	box(0, 0, -A, 2 * A + 2, 5, 2, C.stone)
	box(0, 0, A, 2 * A + 2, 5, 2, C.stone)
	box(-A, 0, 0, 2, 5, 2 * A, C.stone)
	box(A, 0, 0, 2, 5, 2 * A, C.stone)
	var i := -A + 2
	while i <= A - 2:
		box(i, 5, -A, 1.4, 0.9, 2, C.stone2, false)
		box(i, 5, A, 1.4, 0.9, 2, C.stone2, false)
		box(-A, 5, i, 2, 0.9, 1.4, C.stone2, false)
		box(A, 5, i, 2, 0.9, 1.4, C.stone2, false)
		i += 3
	# 네 모서리 탑
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(sx * A, 0, sz * A, 8, 9, 8, C.stone2)
			roof(Vector3(sx * A, 9 + 2.1, sz * A), Vector3(6.4, 4.2, 6.4), C.roof_r if sx * sz > 0 else C.roof_b)
	# 중앙 단상과 계단 (계단 한 칸 0.5m → STEP_H로 걸어 올라감)
	box(0, 0, 0, 14, 2, 14, C.stone)
	box(0, 2, 0, 14.4, 0.25, 14.4, C.stone2, false)
	for s in range(1, 4):
		var h := 2.0 - 0.5 * s
		var o := 7.0 + s - 0.5
		box(0, 0, -o, 4, h, 1, C.stone2)
		box(0, 0, o, 4, h, 1, C.stone2)
		box(-o, 0, 0, 1, h, 4, C.stone2)
		box(o, 0, 0, 1, h, 4, C.stone2)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(sx * 6.2, 2, sz * 6.2, 1.4, 1.1, 1.4, C.stone_dark)
			box(sx * 6.2, 2, sz * 3.6, 0.8, 0.8, 2.4, C.stone2)
			box(sx * 3.6, 2, sz * 6.2, 2.4, 0.8, 0.8, C.stone2)
	# 깃대 + 펄럭이는 깃발
	mesh(_cyl, C.wood_dark, Vector3(0, 5.5, 0), Vector3(0.1, 7, 0.1))
	add_col(-0.2, 2, -0.2, 0.2, 9, 0.2)
	_build_flag(C.gold)
	# 집
	house(-28, -16, 9, 7, 5, C.roof_r)
	house(-16, -31, 7, 9, 4.5, C.roof_b)
	house(16, 31, 7, 9, 5, C.roof_r)
	house(32, -28, 8, 6, 4.5, C.roof_b)
	house(-32, 28, 6, 8, 4.5, C.roof_r)
	house(28, 14, 8, 8, 3.9, -1)  # 지붕 없는 집 (옥상에 올라갈 수 있음)
	crate(23.25, 16.6, 1.4, 1)
	crate(23.25, 15.1, 1.4, 2)
	# 무너진 벽 (엄폐물)
	for wv in [[-12, 10, 6, 1.5, 1], [12, -10, 6, 1.5, 1], [-21, 0, 1, 1.8, 7], [21, 2, 1, 1.8, 7], [0, 22, 8, 1.4, 1],
			[0, -22, 8, 1.4, 1], [-30, -2, 4, 1.2, 1], [33, -6, 1, 1.4, 4], [-6, 34, 1, 1.6, 5], [8, -34, 5, 1.5, 1]]:
		var x: float = wv[0]
		var z: float = wv[1]
		var w: float = wv[2]
		var h: float = wv[3]
		var d: float = wv[4]
		box(x, 0, z, w, h, d, C.stone2)
		box(x + (w * 0.2 if w > d else 0.0), h, z + (d * 0.2 if d > w else 0.0),
			w * 0.4 if w > d else (w if d > w else 0.6), 0.5, d * 0.4 if d > w else (d if w > d else 0.6), C.stone_dark)
	# 울타리 (rot=1이면 X 방향)
	for fv in [[-36, 8, 8, 0], [36, 24, 8, 0], [-10, -38, 8, 1], [24, 40, 6, 1], [-26, 12, 6, 1]]:
		var x: float = fv[0]
		var z: float = fv[1]
		var ln: float = fv[2]
		if fv[3] == 1:
			box(x, 0.55, z, ln, 0.12, 0.12, C.wood, false)
			box(x, 0.95, z, ln, 0.12, 0.12, C.wood, false)
			add_col(x - ln / 2, 0, z - 0.12, x + ln / 2, 1.1, z + 0.12)
			var k := 0.0
			while k <= ln:
				box(x - ln / 2 + k, 0, z, 0.2, 1.2, 0.2, C.wood_dark, false)
				k += 2
		else:
			box(x, 0.55, z, 0.12, 0.12, ln, C.wood, false)
			box(x, 0.95, z, 0.12, 0.12, ln, C.wood, false)
			add_col(x - 0.12, 0, z - ln / 2, x + 0.12, 1.1, z + ln / 2)
			var k := 0.0
			while k <= ln:
				box(x, 0, z - ln / 2 + k, 0.2, 1.2, 0.2, C.wood_dark, false)
				k += 2
	# 상자
	for cv in [[-8, -14, 1.3, 1], [-6.6, -14, 1.3, 2], [-7.3, -12.7, 1.3, 1], [10, 16, 1.4, 1], [11.4, 16.4, 1.2, 1],
			[36, 0, 1.4, 2], [-36, -5, 1.4, 1], [14, -38, 1.3, 1], [-14, 38, 1.3, 2], [37, 36, 1.4, 1], [-38, -36, 1.4, 1],
			[16, -14, 1.2, 1], [-15, 14, 1.2, 1]]:
		crate(cv[0], cv[1], cv[2], cv[3])
	# 건초 더미 (r=1이면 Z 방향으로 누움)
	for hv in [[-24, -6, 0], [-22.3, -6, 0], [26, -10, 1], [6, 26, 0], [-4, -28, 1], [30, 32, 0]]:
		var x: float = hv[0]
		var z: float = hv[1]
		var hm := mesh(_cyl, C.hay, Vector3(x, 0.7, z), Vector3(0.7, 1.6, 0.7))
		if hv[2] == 1:
			hm.rotation = Vector3(PI / 2, 0, 0)
			add_col(x - 0.7, 0, z - 0.8, x + 0.7, 1.4, z + 0.8)
		else:
			hm.rotation = Vector3(0, 0, PI / 2)
			add_col(x - 0.8, 0, z - 0.7, x + 0.8, 1.4, z + 0.7)
	# 시장 좌판
	stall(-12, -4, C.roof_r)
	stall(12, 5, C.roof_b)
	# 나무
	for tv in [[-38, -20, 1], [-40, 14, 1.2], [38, -14, 1.1], [40, 22, 0.9], [-22, 40, 1.1], [8, 40, 1], [22, -40, 1.2],
			[-4, -41, 0.9], [-28, -38, 1], [30, -2, 0.8], [-40, 40, 1], [40, -40, 1]]:
		tree(tv[0], tv[1], tv[2])
	# 바깥 언덕
	for n in 22:
		var a := float(n) / 22.0 * TAU
		var r := _rng.randf_range(95, 130)
		mesh(_sph, C.grass_dark if n % 2 else 0x7cc357, Vector3(sin(a) * r, -2, cos(a) * r),
			Vector3(_rng.randf_range(18, 30), _rng.randf_range(6, 14), _rng.randf_range(18, 30)), false)
	# 구름
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color.WHITE
	cloud_mat.emission_enabled = true
	cloud_mat.emission = GameData.col(0x6f7f8f)
	cloud_mat.roughness = 1.0
	for n in 9:
		var g := Node3D.new()
		add_child(g)
		for j in 4:
			var s := MeshInstance3D.new()
			s.mesh = _sph
			s.material_override = cloud_mat
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s.scale = Vector3(_rng.randf_range(4, 7), _rng.randf_range(2.5, 4), _rng.randf_range(4, 6))
			s.position = Vector3(j * 4 - 6, _rng.randf_range(-1, 1), _rng.randf_range(-2, 2))
			g.add_child(s)
		g.position = Vector3(_rng.randf_range(-140, 140), _rng.randf_range(55, 75), _rng.randf_range(-140, 140))
		_clouds.append(g)


func house(x: float, z: float, w: float, d: float, h: float, roof_hex: int) -> void:
	var C: Dictionary = GameData.C
	box(x, 0, z, w, h, d, C.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(x + sx * (w / 2), 0, z + sz * (d / 2), 0.35, h, 0.35, C.wood_dark, false)
	box(x, h - 0.25, z, w + 0.1, 0.3, d + 0.1, C.wood_dark, false)
	box(x, 0, z + d / 2 + 0.03, 1.2, 2.1, 0.08, C.wood_dark, false)
	for sx in [-1, 1]:
		box(x + sx * w * 0.28, h * 0.5, z + d / 2 + 0.03, 0.8, 0.8, 0.08, 0x3d4b6b, false)
	if roof_hex >= 0:
		roof(Vector3(x, h + 1.5, z), Vector3((w / 2 + 0.5) * 1.414, 3, (d / 2 + 0.5) * 1.414), roof_hex)
	else:  # 옥상 난간
		box(x, h, z - d / 2 + 0.15, w, 0.6, 0.3, C.wood_dark)
		box(x, h, z + d / 2 - 0.15, w, 0.6, 0.3, C.wood_dark)
		box(x + w / 2 - 0.15, h, z, 0.3, 0.6, d, C.wood_dark)
		box(x - w / 2 + 0.15, h, z - d / 4 - 0.3, 0.3, 0.6, d / 2 - 0.6, C.wood_dark)


func crate(x: float, z: float, s: float, st: int) -> void:
	var C: Dictionary = GameData.C
	for n in st:
		box(x, n * s, z, s, s, s, C.wood_dark if n % 2 else C.wood)
		box(x, n * s + s * 0.42, z, s + 0.04, s * 0.16, s + 0.04, C.wood if n % 2 else C.wood_dark, false)


func stall(x: float, z: float, cloth: int) -> void:
	var C: Dictionary = GameData.C
	box(x, 0, z, 3.2, 0.9, 1.4, C.wood)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(x + sx * 1.6, 0, z + sz * 0.8, 0.15, 2.4, 0.15, C.wood_dark, false)
	box(x, 2.4, z, 3.6, 0.12, 2, cloth, false)
	box(x, 2.4, z - 1, 3.6, 0.4, 0.05, C.cloth, false)
	var fruits := [0xe25a3c, 0xf2b33d, 0x7fc35a, 0xb05bd1]
	for n in 4:
		mesh(_sph, fruits[n], Vector3(x - 1 + n * 0.66, 1.05, z), Vector3.ONE * 0.16)


func tree(x: float, z: float, s: float) -> void:
	var C: Dictionary = GameData.C
	mesh(_cyl, C.trunk, Vector3(x, 1.5 * s, z), Vector3(0.28 * s, 3 * s, 0.28 * s))
	add_col(x - 0.35 * s, 0, z - 0.35 * s, x + 0.35 * s, 3 * s, z + 0.35 * s)
	for lv in [[0, 3.6, 0, 1.7, C.leaf], [0.9, 3.0, 0.4, 1.2, C.leaf2], [-0.8, 3.1, -0.3, 1.25, C.leaf2], [0.1, 4.6, 0.1, 1.1, C.leaf2]]:
		mesh(_sph, lv[4], Vector3(x + lv[0] * s, lv[1] * s, z + lv[2] * s), Vector3.ONE * lv[3] * s)


func _build_flag(hex: int) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 1.4)
	pm.orientation = PlaneMesh.FACE_Z
	pm.subdivide_width = 12
	pm.subdivide_depth = 4
	pm.center_offset = Vector3(1.2, 0, 0)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color;
void vertex() {
	float x = VERTEX.x;
	VERTEX.z += sin(x * 2.2 - TIME * 5.0) * 0.18 * (x / 2.4);
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("albedo", GameData.col(hex))
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	mi.position = Vector3(0.1, 8.1, 0)
	add_child(mi)


func _build_spawns() -> void:
	for n in 16:
		var a := float(n) / 16.0 * TAU + 0.1
		for r in [38.0, 25.0, 15.0]:
			var p := Vector3(sin(a) * r, 0, cos(a) * r)
			if not overlaps_any(p, 0.8, 1.9):
				spawn_points.append(p)


func random_point() -> Vector3:
	for n in 30:
		var p := Vector3(_rng.randf_range(-38, 38), 0, _rng.randf_range(-38, 38))
		if not overlaps_any(p, 0.8, 1.9):
			return p
	return Vector3(0, 0, 20)
