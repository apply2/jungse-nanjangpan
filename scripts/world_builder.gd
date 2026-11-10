class_name WorldBuilder
extends Node3D
## 맵 생성 — HTML buildWorld() / house() / crate() / stall() / tree() 를 그대로 옮긴 것.
## Three.js와 Godot은 좌표계가 같다 (Y가 위, -Z가 앞, 오른손 좌표계) → 숫자를 그대로 쓰면 된다.
## 충돌은 StaticBody3D 하나에 BoxShape3D를 여러 개 붙인다.
## 같은 상자들을 aabbs 배열에도 담아두는데, 스폰 지점 검사·봇 시야 검사 같은 가벼운 계산에 쓴다.
##
## 맵 꾸미기 (사용자 요청): 겉모양만 바꾸고 충돌·엄폐물·스폰·아이템 자리는 그대로다.
##   - box(…, style)로 무늬 재질을 고른다 (MatStyles, shaders/, 수치는 GameData.MAT_STYLES). 기본 ""은 예전처럼 단색.
##   - 장식(기둥·들보·창문·횃불·덩굴…)은 전부 충돌 없음. 벽에서 10cm 넘게 안 튀어나온다 (성벽은 castle_wall 설명 참고).
##   - 잔디·들꽃·자갈은 MultiMesh (_build_scatter). 배치는 고정 시드(DECO.seed)라 누구 컴퓨터에서나 같다.
##   - 그래픽 품질(GameData.GFX)에 따라 잔디 개수·작은 소품(clutter)을 바꾼다 (apply_gfx).

const ARENA_HALF := 46.0  # 성벽 위치 (HTML의 A)

var body: StaticBody3D
var aabbs: Array[AABB] = []
var spawn_points: Array[Vector3] = []
var half_x: float = GameData.ARENA   # 이동 가능 범위 (±). 쟁탈전 맵은 따로 정함
var half_z: float = GameData.ARENA
var map_id := "ffa"


## 특수 아이템이 나오는 자리 (맵마다 다름 — 개인전은 GameData 그대로)
func item_spots() -> Array:
	return GameData.SNIPER_SPOTS


func horse_spots() -> Array:
	return GameData.HORSE_SPOTS


func chicken_spots() -> Array:
	return GameData.ITEM.chicken_spots

var _box := BoxMesh.new()
var _sph := SphereMesh.new()
var _sph_lo := SphereMesh.new()  # 장식용 (꽃·불꽃·자갈) 낮은 다각형 구
var _cyl := CylinderMesh.new()
var _cone := CylinderMesh.new()
var _roof := CylinderMesh.new()
var _clouds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()

# ── 꾸미기 ──
var _drng := RandomNumberGenerator.new()  # 장식 배치 (고정 시드 — 친구대전에서도 같은 모양)
var _clutter := false                     # true인 동안 만드는 조각 = 작은 소품 (품질 '낮음'이면 숨김)
var clutter_nodes: Array[Node3D] = []     # 작은 소품을 합친 메시·들꽃·자갈
var grass_nodes: Array[MultiMeshInstance3D] = []
var scatter_items := {}                   # "Grass"·"Flowers"·"Pebbles" → [[Transform3D(월드), Color], …] (테스트용 — 헤드리스는 MultiMesh 값을 못 읽음)
var _paths: Array[Vector4] = []           # 흙길 (가운데 x, 가운데 z, 반폭 x, 반폭 z) — 땅 셰이더 마스크
var _no_grass: Array[Rect2] = []          # 잔디 안 나는 곳 (돌바닥·스폰룸)
var _ground: MeshInstance3D
var _bays: Array = []                     # 성벽 버팀벽 사이 칸 [들인 면 위 가운데, 안쪽 법선] — 횃불·현수막 자리
var _wall_bases: Array = []               # 성벽 밑 [안쪽 면 가운데, 법선, 반길이] — 들꽃·자갈


func _ready() -> void:
	_box.size = Vector3.ONE
	_sph.radius = 1.0
	_sph.height = 2.0
	_sph.radial_segments = 20
	_sph.rings = 14
	_sph_lo.radius = 1.0
	_sph_lo.height = 2.0
	_sph_lo.radial_segments = 8
	_sph_lo.rings = 4
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
	_drng.seed = int(GameData.DECO.seed)
	body = StaticBody3D.new()
	body.name = "Colliders"
	add_child(body)
	build()
	_wall_props()
	_build_scatter()
	if _ground:
		_ground.material_override = MatStyles.ground(_paths)
	_merge_static()
	_build_live()
	_build_spawns()
	apply_gfx()
	GameData.gfx_changed.connect(apply_gfx)


## 합치기(_merge_static) 뒤에 붙이는, 움직이거나 색이 바뀌는 조각 (쟁탈전 맵의 거점 표시 등). 개인전 맵은 없음
func _build_live() -> void:
	pass


func _process(dt: float) -> void:
	for c in _clouds:
		c.position.x += dt * 1.2
		if c.position.x > 160.0:
			c.position.x = -160.0


## 그래픽 품질 적용 (GameData.gfx_changed): 잔디 개수, 작은 소품 보이기
func apply_gfx() -> void:
	var g := GameData.gfx()
	var ratio: float = g.grass
	for mmi in grass_nodes:
		var n := int(round(mmi.multimesh.instance_count * ratio))
		mmi.multimesh.visible_instance_count = n
		mmi.visible = n > 0
	for nd in clutter_nodes:
		nd.visible = bool(g.clutter)


# ── 기본 도구 ────────────────────────────────────────────────
## style: 무늬 재질 (GameData.MAT_STYLES의 키, ""이면 단색). 합칠 때 같은 style끼리 묶인다
func mesh(m: Mesh, hex: int, pos: Vector3, scl: Vector3, shadow := true, parent: Node3D = null, style := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = GameData.mat(hex)
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if style != "":
		mi.set_meta("style", style)
	if _clutter:
		mi.set_meta("clutter", true)
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


## HTML box(x,y,z,w,h,d,color,collide,shadow): y는 바닥 높이, 상자는 그 위로 h만큼. style은 무늬 재질
func box(x: float, y: float, z: float, w: float, h: float, d: float, hex: int, collide := true, shadow := true, style := "") -> MeshInstance3D:
	var m := mesh(_box, hex, Vector3(x, y + h / 2.0, z), Vector3(w, h, d), shadow, null, style)
	if collide:
		col_box(x, y, z, w, h, d)
	return m


## box()와 같은 충돌 상자만 (겉모양은 따로 그릴 때 — 성벽)
func col_box(x: float, y: float, z: float, w: float, h: float, d: float) -> void:
	add_col(x - w / 2.0, y, z - d / 2.0, x + w / 2.0, y + h, z + d / 2.0)


## 사각뿔 지붕. Three.js에선 지오메트리를 45° 돌려 구웠으므로, 여기선 부모가 크기를 맡고 자식이 회전한다.
func roof(pos: Vector3, scl: Vector3, hex: int, style := "roof_tiles") -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.scale = scl
	add_child(holder)
	var mi := mesh(_roof, hex, Vector3.ZERO, Vector3.ONE, true, holder, style)
	mi.rotation.y = PI / 4.0


## 흙길 (땅 셰이더가 그림 — 상자를 깔지 않음). w·d는 전체 폭
func path_rect(cx: float, cz: float, w: float, d: float) -> void:
	_paths.append(Vector4(cx, cz, w / 2.0, d / 2.0))


## 땅 판 (잔디 + 흙길 셰이더 — 재질은 길을 다 모은 뒤 _ready에서 붙임)
func ground_plane(size: Vector2) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	_ground.mesh = pm
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)


## 최적화(10단계): 움직이지 않는 맵 조각을 (무늬 재질, 그림자, 작은 소품) 묶음마다 하나로 합친다.
## 색은 정점 색으로 넣어 재질 하나로 그린다 → 그리기 호출이 수백 번에서 열몇 번으로 준다 (웹에서 특히 중요).
## 구름(움직임)과 깃발(셰이더)은 그대로 둔다.
func _merge_static() -> void:
	var groups := {}
	var cloud_set := {}
	for c in _clouds:
		cloud_set[c] = true
	for mi in _static_meshes(self, cloud_set):
		var sm := mi.material_override as StandardMaterial3D
		var st: String = mi.get_meta("style", "")
		var sh := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cl: bool = mi.get_meta("clutter", false)
		var key := "%s|%d|%d" % [st, int(sh), int(cl)]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append([mi, sm.albedo_color, _local_xform(mi)])
	var keys := groups.keys()
	keys.sort()
	for key: String in keys:
		var bits := key.split("|")
		var st := bits[0]
		var shadow := bits[1] == "1"
		var cl := bits[2] == "1"
		var out := MeshInstance3D.new()
		out.name = ("Static" if shadow else "StaticNoShadow") + ("_" + st if st != "" else "") + ("_clutter" if cl else "")
		out.mesh = Meshes.merge((groups[key] as Array).map(func(it: Array) -> Array: return [(it[0] as MeshInstance3D).mesh, it[1], it[2]]))
		out.material_override = Meshes.vertex_color_mat() if st == "" else MatStyles.get_mat(st)
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(out)
		if cl:
			clutter_nodes.append(out)
	for key: String in keys:
		for it: Array in groups[key]:
			var mi: MeshInstance3D = it[0]
			var par := mi.get_parent()
			mi.free()
			if par != self and par.get_child_count() == 0:  # 지붕 받침 노드
				par.free()


func _static_meshes(n: Node, skip: Dictionary) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if skip.has(c) or c == body:
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is StandardMaterial3D:
			out.append(c)
		out.append_array(_static_meshes(c, skip))
	return out


## World 기준 변환 (부모 노드를 따라 올라가며 곱함)
func _local_xform(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != self:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


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
	ground_plane(Vector2(320, 320))
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(400, 2, 400)
	gcs.shape = gbs
	gcs.position = Vector3(0, -1, 0)
	body.add_child(gcs)

	# 흙길 (땅 셰이더 마스크)
	path_rect(0, 0, 5, 88)
	path_rect(0, 0, 88, 5)
	path_rect(0, 0, 24, 24)
	var A := ARENA_HALF
	# 성벽과 총안 (충돌은 원래 상자 그대로, 겉모양은 castle_wall)
	col_box(0, 0, -A, 2 * A + 2, 5, 2)
	col_box(0, 0, A, 2 * A + 2, 5, 2)
	col_box(-A, 0, 0, 2, 5, 2 * A)
	col_box(A, 0, 0, 2, 5, 2 * A)
	castle_wall(Vector3(0, 0, -A + 1), Vector3(0, 0, 1), 2 * A + 2, 5, 2, C.stone, A - 5)
	castle_wall(Vector3(0, 0, A - 1), Vector3(0, 0, -1), 2 * A + 2, 5, 2, C.stone, A - 5)
	castle_wall(Vector3(-A + 1, 0, 0), Vector3(1, 0, 0), 2 * A, 5, 2, C.stone, A - 5)
	castle_wall(Vector3(A - 1, 0, 0), Vector3(-1, 0, 0), 2 * A, 5, 2, C.stone, A - 5)
	var i := -A + 2
	while i <= A - 2:
		box(i, 5, -A, 1.4, 0.9, 2, C.stone2, false, true, "castle_stone")
		box(i, 5, A, 1.4, 0.9, 2, C.stone2, false, true, "castle_stone")
		box(-A, 5, i, 2, 0.9, 1.4, C.stone2, false, true, "castle_stone")
		box(A, 5, i, 2, 0.9, 1.4, C.stone2, false, true, "castle_stone")
		i += 3
	# 네 모서리 탑
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(sx * A, 0, sz * A, 8, 9, 8, C.stone2, true, true, "castle_stone")
			roof(Vector3(sx * A, 9 + 2.1, sz * A), Vector3(6.4, 4.2, 6.4), C.roof_r if sx * sz > 0 else C.roof_b)
			tower_deco(sx * A, sz * A, 8, 8, 9)
	# 중앙 단상과 계단 (계단 한 칸 0.5m → STEP_H로 걸어 올라감)
	box(0, 0, 0, 14, 2, 14, C.stone, true, true, "castle_stone")
	box(0, 2, 0, 14.4, 0.25, 14.4, C.stone2, false, true, "castle_stone")
	for s in range(1, 4):
		var h := 2.0 - 0.5 * s
		var o := 7.0 + s - 0.5
		box(0, 0, -o, 4, h, 1, C.stone2, true, true, "castle_stone")
		box(0, 0, o, 4, h, 1, C.stone2, true, true, "castle_stone")
		box(-o, 0, 0, 1, h, 4, C.stone2, true, true, "castle_stone")
		box(o, 0, 0, 1, h, 4, C.stone2, true, true, "castle_stone")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(sx * 6.2, 2, sz * 6.2, 1.4, 1.1, 1.4, C.stone_dark, true, true, "castle_stone")
			box(sx * 6.2, 2, sz * 3.6, 0.8, 0.8, 2.4, C.stone2, true, true, "castle_stone")
			box(sx * 3.6, 2, sz * 6.2, 2.4, 0.8, 0.8, C.stone2, true, true, "castle_stone")
	# 깃대 + 펄럭이는 깃발
	mesh(_cyl, C.wood_dark, Vector3(0, 5.5, 0), Vector3(0.1, 7, 0.1))
	add_col(-0.2, 2, -0.2, 0.2, 9, 0.2)
	_build_flag(C.gold)
	# 집 (파란 지붕 = 벽돌집, 빨간 지붕·옥상 = 나무 골조 집)
	house(-28, -16, 9, 7, 5, C.roof_r)
	house(-16, -31, 7, 9, 4.5, C.roof_b, true)
	house(16, 31, 7, 9, 5, C.roof_r)
	house(32, -28, 8, 6, 4.5, C.roof_b, true)
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
		box(x, 0, z, w, h, d, C.stone2, true, true, "castle_stone")
		box(x + (w * 0.2 if w > d else 0.0), h, z + (d * 0.2 if d > w else 0.0),
			w * 0.4 if w > d else (w if d > w else 0.6), 0.5, d * 0.4 if d > w else (d if w > d else 0.6), C.stone_dark, true, true, "castle_stone")
	# 울타리 (rot=1이면 X 방향)
	for fv in [[-36, 8, 8, 0], [36, 24, 8, 0], [-10, -38, 8, 1], [24, 40, 6, 1], [-26, 12, 6, 1]]:
		var x: float = fv[0]
		var z: float = fv[1]
		var ln: float = fv[2]
		if fv[3] == 1:
			box(x, 0.55, z, ln, 0.12, 0.12, C.wood, false, true, "wood_plank")
			box(x, 0.95, z, ln, 0.12, 0.12, C.wood, false, true, "wood_plank")
			add_col(x - ln / 2, 0, z - 0.12, x + ln / 2, 1.1, z + 0.12)
			var k := 0.0
			while k <= ln:
				box(x - ln / 2 + k, 0, z, 0.2, 1.2, 0.2, C.wood_dark, false, true, "wood_plank_v")
				k += 2
		else:
			box(x, 0.55, z, 0.12, 0.12, ln, C.wood, false, true, "wood_plank")
			box(x, 0.95, z, 0.12, 0.12, ln, C.wood, false, true, "wood_plank")
			add_col(x - 0.12, 0, z - ln / 2, x + 0.12, 1.1, z + ln / 2)
			var k := 0.0
			while k <= ln:
				box(x, 0, z - ln / 2 + k, 0.2, 1.2, 0.2, C.wood_dark, false, true, "wood_plank_v")
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
		var hm := mesh(_cyl, C.hay, Vector3(x, 0.7, z), Vector3(0.7, 1.6, 0.7), true, null, "hay")
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
		var puffs := []  # 구름 하나 = 공 4개를 합친 메시 하나 (10단계 최적화)
		for j in 4:
			var scl := Vector3(_rng.randf_range(4, 7), _rng.randf_range(2.5, 4), _rng.randf_range(4, 6))
			var pos := Vector3(j * 4 - 6, _rng.randf_range(-1, 1), _rng.randf_range(-2, 2))
			puffs.append([_sph, Color.WHITE, Transform3D(Basis.from_scale(scl), pos)])
		var s := MeshInstance3D.new()
		s.mesh = Meshes.merge(puffs)
		s.material_override = cloud_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(s)
		g.position = Vector3(_rng.randf_range(-140, 140), _rng.randf_range(55, 75), _rng.randf_range(-140, 140))
		_clouds.append(g)


## 집. brick = 벽돌집 (모서리 돌·창턱·아치돌), 아니면 나무 골조 집 (기둥·들보·가새)
func house(x: float, z: float, w: float, d: float, h: float, roof_hex: int, brick := false) -> void:
	var C: Dictionary = GameData.C
	box(x, 0, z, w, h, d, C.brick if brick else C.plaster, true, true, "brick" if brick else "plaster")
	if brick:
		quoins(x, z, w, d, h - 0.25, 0.4)
	else:
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				box(x + sx * (w / 2), 0, z + sz * (d / 2), 0.35, h, 0.35, C.wood_dark, false, true, "wood_plank_v")
	box(x, h - 0.25, z, w + 0.1, 0.3, d + 0.1, C.wood_dark, false, true, "wood_plank")
	house_faces(x, z, w, d, h, brick, [-w * 0.28, w * 0.28], 0)
	if roof_hex >= 0:
		roof(Vector3(x, h + 1.5, z), Vector3((w / 2 + 0.5) * 1.414, 3, (d / 2 + 0.5) * 1.414), roof_hex)
		eaves(x, z, h, w / 2 + 0.5, d / 2 + 0.5)
		chimney(x, z, w, d, h)
	else:  # 옥상 난간
		box(x, h, z - d / 2 + 0.15, w, 0.6, 0.3, C.wood_dark, true, true, "wood_plank")
		box(x, h, z + d / 2 - 0.15, w, 0.6, 0.3, C.wood_dark, true, true, "wood_plank")
		box(x + w / 2 - 0.15, h, z, 0.3, 0.6, d, C.wood_dark, true, true, "wood_plank")
		box(x - w / 2 + 0.15, h, z - d / 4 - 0.3, 0.3, 0.6, d / 2 - 0.6, C.wood_dark, true, true, "wood_plank")


func crate(x: float, z: float, s: float, st: int) -> void:
	var C: Dictionary = GameData.C
	for n in st:
		box(x, n * s, z, s, s, s, C.wood_dark if n % 2 else C.wood, true, true, "wood_plank")
		box(x, n * s + s * 0.42, z, s + 0.04, s * 0.16, s + 0.04, C.wood if n % 2 else C.wood_dark, false, true, "wood_plank")
		for sx in [-1, 1]:  # 쇠 모서리 띠
			for sz in [-1, 1]:
				box(x + sx * (s / 2 - 0.02), n * s, z + sz * (s / 2 - 0.02), 0.08, s, 0.08, C.iron, false, false)


func stall(x: float, z: float, cloth: int) -> void:
	var C: Dictionary = GameData.C
	box(x, 0, z, 3.2, 0.9, 1.4, C.wood, true, true, "wood_plank")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(x + sx * 1.6, 0, z + sz * 0.8, 0.15, 2.4, 0.15, C.wood_dark, false, true, "wood_plank_v")
	box(x, 2.4, z, 3.6, 0.12, 2, cloth, false, true, "cloth_stripe")
	box(x, 2.4, z - 1, 3.6, 0.4, 0.05, C.cloth, false, true, "cloth_stripe")
	var fruits := [0xe25a3c, 0xf2b33d, 0x7fc35a, 0xb05bd1]
	for n in 4:
		mesh(_sph, fruits[n], Vector3(x - 1 + n * 0.66, 1.05, z), Vector3.ONE * 0.16)


func tree(x: float, z: float, s: float) -> void:
	var C: Dictionary = GameData.C
	mesh(_cyl, C.trunk, Vector3(x, 1.5 * s, z), Vector3(0.28 * s, 3 * s, 0.28 * s), true, null, "bark")
	add_col(x - 0.35 * s, 0, z - 0.35 * s, x + 0.35 * s, 3 * s, z + 0.35 * s)
	var lj: float = GameData.DECO.leaf_jitter
	for lv in [[0, 3.6, 0, 1.7, C.leaf], [0.9, 3.0, 0.4, 1.2, C.leaf2], [-0.8, 3.1, -0.3, 1.25, C.leaf2], [0.1, 4.6, 0.1, 1.1, C.leaf2]]:
		mesh(_sph, _jit(lv[4], lj), Vector3(x + lv[0] * s, lv[1] * s, z + lv[2] * s), Vector3.ONE * lv[3] * s)


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


# ── 장식 도구 (전부 충돌 없음) ───────────────────────────────
## 색 밝기를 ±amt 흔든 색 (고정 시드)
func _jit(hex: int, amt: float) -> int:
	var c := GameData.col(hex)
	var k := 1.0 + _drng.randf_range(-amt, amt)
	c = Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


## 벽면 장식 상자. c = 벽면 위 한 점(바닥 높이), n = 벽 밖(보는 쪽) 법선, u = 면을 따라 (t = UP × n, 밖에서 보면 오른쪽),
## y = 아래 끝 높이, sz = (가로, 세로, 두께), off = 벽면에서 띄운 거리(+ 밖), rot = 면 안에서 돌림
func fbox(c: Vector3, n: Vector3, u: float, y: float, sz: Vector3, hex: int, style := "", off := 0.0, rot := 0.0, shadow := false) -> MeshInstance3D:
	var t := Vector3.UP.cross(n)
	var b := Basis(t, Vector3.UP, n)
	if rot != 0.0:
		b = b * Basis(Vector3(0, 0, 1), rot)
	var pos := c + t * u + Vector3.UP * (y + sz.y / 2.0) + n * (off + sz.z / 2.0)
	var mi := mesh(_box, hex, pos, Vector3.ONE, shadow, null, style)
	mi.transform = Transform3D(b * Basis.from_scale(sz), pos)
	return mi


## 벽면 위 작은 공 (꽃·문고리)
func fsph(c: Vector3, n: Vector3, u: float, y: float, r: float, hex: int, off := 0.0) -> MeshInstance3D:
	var t := Vector3.UP.cross(n)
	return mesh(_sph_lo, hex, c + t * u + Vector3.UP * y + n * off, Vector3.ONE * r, false)


## 상자 집의 네 면: [면 가운데(바닥), 밖 법선, 면 길이]. 0 = +z(앞), 1 = -z, 2 = +x, 3 = -x
func _faces(x: float, z: float, w: float, d: float) -> Array:
	return [[Vector3(x, 0, z + d / 2), Vector3(0, 0, 1), w], [Vector3(x, 0, z - d / 2), Vector3(0, 0, -1), w],
		[Vector3(x + w / 2, 0, z), Vector3(1, 0, 0), d], [Vector3(x - w / 2, 0, z), Vector3(-1, 0, 0), d]]


## 집 네 면의 창문·문·골조. front_wins = 문 있는 면(door_face)의 창문 자리 u, 다른 면은 길이에 맞춰 자동.
## door_face = -1이면 문 없음. 창문 아래 끝 높이 = h × 0.5
func house_faces(x: float, z: float, w: float, d: float, h: float, brick: bool, front_wins: Array, door_face: int, skip_faces: Array = []) -> void:
	var fs := _faces(x, z, w, d)
	for fi in 4:
		if skip_faces.has(fi):
			continue
		var c: Vector3 = fs[fi][0]
		var n: Vector3 = fs[fi][1]
		var L: float = fs[fi][2]
		var wins: Array = []
		if fi == door_face:
			wins = front_wins
		else:
			var cnt := clampi(int(L / 3.2), 1, 6)
			for k in cnt:
				wins.append(-L / 2 + (k + 0.5) * L / cnt)
		var wy := h * 0.5
		var holes: Array = []  # 가새를 안 넣을 곳 [u0, u1, y0, y1]
		for u: float in wins:
			_window(c, n, u, wy, 0.8, 0.8, brick)
			holes.append([u - 0.9, u + 0.9, wy - 0.3, wy + 0.9])
		if fi == door_face:
			_door(c, n, 0.0, brick)
			holes.append([-0.75, 0.75, 0.0, 2.3])
		if not brick:
			_timber(c, n, L, h, wy, holes)


## 나무 골조: 밑 들보·창 아래 들보·기둥(post_gap마다)·칸마다 가새(/ \ X 무작위). 처마 들보는 house()의 윗 띠
func _timber(c: Vector3, n: Vector3, L: float, h: float, wy: float, holes: Array) -> void:
	var D: Dictionary = GameData.DECO
	var C: Dictionary = GameData.C
	var pw: float = D.post_w
	var bh: float = D.beam_h
	var out: float = D.out
	var in_l := L - 0.35              # 모서리 기둥(0.35) 사이
	var top := h - 0.25               # 처마 들보 아래
	var mid := wy - 0.3 - bh          # 창 아래 들보 (아래 끝)
	fbox(c, n, 0, 0.0, Vector3(in_l, 0.22, out), C.beam, "wood_plank")
	fbox(c, n, 0, mid, Vector3(in_l, bh, out), C.beam, "wood_plank")
	var cuts: Array[float] = [-in_l / 2]
	var cnt := maxi(2, roundi(L / float(D.post_gap)))
	for k in range(1, cnt):
		var u := -L / 2 + k * L / cnt
		var blocked := false
		for hl: Array in holes:
			if u > float(hl[0]) - pw and u < float(hl[1]) + pw:
				blocked = true
		if blocked:
			continue
		fbox(c, n, u, 0.22, Vector3(pw, top - 0.22, out), C.beam, "wood_plank_v")
		cuts.append(u)
	cuts.append(in_l / 2)
	# 가새: 아래 칸(0.22 ~ mid), 위 칸(mid+bh ~ top)
	for tier: Array in [[0.22, mid], [mid + bh, top]]:
		var y0: float = tier[0]
		var y1: float = tier[1]
		if y1 - y0 < 0.5:
			continue
		for k in cuts.size() - 1:
			var ua := cuts[k] + pw / 2
			var ub := cuts[k + 1] - pw / 2
			if ub - ua < 0.5:
				continue
			var blocked := false
			for hl: Array in holes:
				if ua < float(hl[1]) and ub > float(hl[0]) and y0 < float(hl[3]) and y1 > float(hl[2]):
					blocked = true
			var r := _drng.randf()
			if blocked or r > 0.75:
				continue
			var dx := ub - ua
			var dy := y1 - y0
			var ln := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var cu := (ua + ub) / 2
			var cy := (y0 + y1) / 2 - bh / 2
			if r < 0.3 or r >= 0.6:
				fbox(c, n, cu, cy, Vector3(ln, bh, out), C.beam, "wood_plank", 0.0, ang)
			if r >= 0.3:
				fbox(c, n, cu, cy, Vector3(ln, bh, out * 0.8), C.beam, "wood_plank", 0.0, -ang)


## 창문: 유리·나무 틀·십자 창살, 열린 덧문 둘, 꽃 상자(빨강·노랑 꽃 3~4송이). 벽돌집은 창턱 + 위에 아치돌
func _window(c: Vector3, n: Vector3, u: float, y0: float, ww: float, wh: float, brick: bool) -> void:
	var C: Dictionary = GameData.C
	fbox(c, n, u, y0, Vector3(ww, wh, 0.04), C.glass)
	for s: float in [-1.0, 1.0]:
		fbox(c, n, u + s * (ww / 2 + 0.04), y0 - 0.04, Vector3(0.08, wh + 0.08, 0.08), C.beam, "wood_plank_v")
	fbox(c, n, u, y0 + wh, Vector3(ww + 0.16, 0.08, 0.08), C.beam, "wood_plank")
	fbox(c, n, u, y0 - 0.08, Vector3(ww + 0.16, 0.08, 0.08), C.beam, "wood_plank")
	fbox(c, n, u, y0, Vector3(0.04, wh, 0.06), C.beam)
	fbox(c, n, u, y0 + wh / 2 - 0.02, Vector3(ww, 0.04, 0.06), C.beam)
	var fb_y := y0 - 0.28
	if brick:
		fbox(c, n, u, y0 - 0.18, Vector3(ww + 0.34, 0.1, 0.09), C.quoin)  # 창턱
		for k in 5:  # 아치돌
			var a := PI * (k + 0.5) / 5.0
			var r := ww / 2 + 0.14
			fbox(c, n, u + cos(a) * r, y0 + wh + sin(a) * r * 0.55 - 0.1, Vector3(0.16, 0.24, 0.07), C.quoin, "", 0.0, a - PI / 2)
		fb_y = y0 - 0.38
	_clutter = true
	var sc: int = C.shutter_g if _drng.randf() < 0.5 else C.shutter_b
	for s: float in [-1.0, 1.0]:  # 열린 덧문
		fbox(c, n, u + s * (ww / 2 + 0.1 + ww * 0.25), y0, Vector3(ww * 0.5, wh, 0.04), sc, "wood_plank_v")
	if not brick or _drng.randf() < 0.5:
		fbox(c, n, u, fb_y, Vector3(ww + 0.1, 0.18, 0.09), C.flower_box, "wood_plank")
		var nf := 3 + _drng.randi() % 2
		for k in nf:
			var fu := u - ww / 2 + 0.1 + (ww - 0.2) * (k + 0.5) / nf + _drng.randf_range(-0.04, 0.04)
			fsph(c, n, fu, fb_y + 0.22 + _drng.randf_range(0, 0.04), 0.06, C.flower_r if _drng.randf() < 0.5 else C.flower_y, 0.045)
	_clutter = false


## 문: 판자 문·나무 틀·쇠 경첩·검은 손잡이 (벽돌집은 위에 아치돌)
func _door(c: Vector3, n: Vector3, u: float, brick: bool) -> void:
	var C: Dictionary = GameData.C
	fbox(c, n, u, 0, Vector3(1.1, 2.05, 0.05), C.wood, "wood_plank_v")
	for s: float in [-1.0, 1.0]:
		fbox(c, n, u + s * 0.61, 0, Vector3(0.12, 2.17, 0.09), C.beam, "wood_plank_v")
	fbox(c, n, u, 2.05, Vector3(1.34, 0.14, 0.09), C.beam, "wood_plank")
	for y: float in [0.4, 1.55]:
		fbox(c, n, u - 0.18, y, Vector3(0.6, 0.06, 0.065), C.iron)
	fsph(c, n, u + 0.38, 1.0, 0.045, C.knob, 0.055)
	if brick:
		for k in 7:
			var a := PI * (k + 0.5) / 7.0
			fbox(c, n, u + cos(a) * 0.82, 2.0 + sin(a) * 0.5, Vector3(0.18, 0.26, 0.07), C.quoin, "", 0.0, a - PI / 2)


## 모서리 돌 (벽돌집·탑): 줄마다 긴 돌/짧은 돌이 번갈아 두 면에 걸침. 벽에서 out만큼 튀어나옴
func quoins(x: float, z: float, w: float, d: float, h: float, blk: float, out := 0.05) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			quoin_corner(x + sx * w / 2, z + sz * d / 2, sx, sz, h, blk, out)


## 모서리 하나 (cx, cz = 모서리, sx·sz = 모서리가 바깥으로 향한 방향 ±1)
func quoin_corner(cx: float, cz: float, sx: float, sz: float, h: float, blk: float, out := 0.05) -> void:
	var C: Dictionary = GameData.C
	for k in int(h / blk):
		var la := blk * (1.6 if k % 2 == 0 else 0.9)
		var lb := blk * (0.9 if k % 2 == 0 else 1.6)
		var y := k * blk + 0.02
		box(cx + sx * (out - la) / 2, y, cz + sz * out / 2, la + out, blk - 0.04, out, C.quoin, false, false)
		box(cx + sx * out / 2, y, cz + sz * (out - lb) / 2, out, blk - 0.04, lb + out, C.quoin, false, false)


## 처마: 지붕 가장자리 밑 판자 띠 (rx·rz = 지붕 반폭)
func eaves(x: float, z: float, h: float, rx: float, rz: float) -> void:
	var C: Dictionary = GameData.C
	for s: float in [-1.0, 1.0]:
		box(x, h - 0.16, z + s * rz, rx * 2 + 0.1, 0.16, 0.1, C.beam, false, false, "wood_plank")
		box(x + s * rx, h - 0.16, z, 0.1, 0.16, rz * 2 + 0.1, C.beam, false, false, "wood_plank")


## 굴뚝 (몇몇 집만 — DECO.chimney_chance)
func chimney(x: float, z: float, w: float, d: float, h: float) -> void:
	if _drng.randf() >= float(GameData.DECO.chimney_chance):
		return
	var C: Dictionary = GameData.C
	var cx := x + w * 0.22
	var cz := z - d * 0.2
	box(cx, h - 0.4, cz, 0.7, 3.6, 0.7, C.brick, false, true, "brick")
	box(cx, h + 3.2, cz, 0.86, 0.16, 0.86, C.quoin, false, true)


## 탑 꾸밈: 모서리 돌, 지붕 밑 띠돌, 면마다 좁은 화살 구멍 둘
func tower_deco(x: float, z: float, w: float, d: float, h: float) -> void:
	var C: Dictionary = GameData.C
	quoins(x, z, w, d, h, 0.6, 0.06)
	for f: Array in _faces(x, z, w, d):
		fbox(f[0], f[1], 0, h - 0.6, Vector3(f[2], 0.22, 0.08), C.stone2, "castle_stone")
		for y: float in [3.0, 6.0]:
			fbox(f[0], f[1], 0, y, Vector3(0.14, 1.0, 0.02), C.slit)


## 성벽 겉모양 (충돌은 col_box로 따로 — 원래 상자 그대로).
## c = 경기장 쪽 충돌 면의 가운데(바닥), n = 경기장 쪽 법선, L = 길이, h = 높이, th = 두께, use = 버팀벽 놓을 범위(±).
## 버팀벽이 0.5m(DECO.recess) 튀어나와 보이게, 몸통 안쪽 면을 0.5m 들여 그린다 → 버팀벽 앞면 = 원래 충돌 면.
## 꼭대기 흉벽(DECO.parapet)은 원래 두께, 그 밑에 띠돌과 받침돌. 들인 칸(bay)엔 화살 구멍·덩굴, 나중에 횃불·현수막.
func castle_wall(c: Vector3, n: Vector3, L: float, h: float, th: float, hex: int, use: float) -> void:
	var D: Dictionary = GameData.DECO
	var C: Dictionary = GameData.C
	var r: float = D.recess
	var par: float = D.parapet
	var gap: float = D.buttress_gap
	var bw: float = D.buttress_w
	var t := Vector3.UP.cross(n)
	fbox(c, n, 0, 0, Vector3(L + th * 2, h - par, th - r), hex, "castle_stone", -th, 0.0, true)
	fbox(c, n, 0, h - par, Vector3(L + th * 2, par, th), hex, "castle_stone", -th, 0.0, true)
	fbox(c, n, 0, h - par - 0.18, Vector3(L, 0.18, 0.08), C.stone2, "castle_stone")  # 띠돌
	var nb := int(floor(use * 2.0 / gap)) + 1
	var us: Array[float] = []
	for k in nb:
		us.append((k - (nb - 1) / 2.0) * gap)
	for u in us:
		fbox(c, n, u, 0, Vector3(bw, h - par - 0.18, r), C.stone2, "castle_stone", -r, 0.0, true)
		fbox(c, n, u, 0, Vector3(bw + 0.16, 0.35, r + 0.08), C.stone2, "castle_stone", -r)  # 밑동
	# 받침돌 (흉벽 밑, 들인 칸에)
	var cu := -use
	while cu <= use:
		var near := false
		for u in us:
			if absf(cu - u) < bw / 2 + 0.3:
				near = true
		if not near:
			fbox(c, n, cu, h - par - 0.5, Vector3(0.3, 0.32, r), C.stone2, "castle_stone", -r)
		cu += 1.5
	var face := c - n * r  # 들인 면
	_wall_bases.append([c, n, use])
	for k in us.size() - 1:
		var bu := (us[k] + us[k + 1]) / 2
		var half := gap / 2 - bw / 2
		_bays.append([face + t * bu, n])
		for su: float in [-half * 0.55, half * 0.55]:  # 화살 구멍
			fbox(face, n, bu + su, h - par - 2.4, Vector3(0.12, 0.95, 0.02), C.slit)
		# 덩굴 (작은 소품): 칸의 한쪽 아래에서 위로 덩어리
		if _drng.randf() < 0.6:
			_clutter = true
			var iu := bu + (half * 0.6 if _drng.randf() < 0.5 else -half * 0.6) + _drng.randf_range(-0.6, 0.6)
			var climb := _drng.randf_range(1.0, 2.6)
			for j in _drng.randi_range(7, 13):
				var yy := pow(_drng.randf(), 1.6) * climb
				var spread := 0.7 * (1.0 - yy / (climb + 0.5))
				fbox(face, n, iu + _drng.randf_range(-spread, spread), yy, Vector3(_drng.randf_range(0.25, 0.6), _drng.randf_range(0.2, 0.45), 0.03),
					C.ivy if _drng.randf() < 0.5 else C.ivy2, "", 0.005 * j, _drng.randf_range(-0.4, 0.4))
			_clutter = false


## 현수막 색 [바탕, 무늬] (pos = 걸리는 곳). 개인전은 금색, 쟁탈전은 팀 색 (MapControl이 바꿈)
func banner_cols(_pos: Vector3) -> Array:
	return [GameData.C.gold, GameData.C.beam]


## 성벽 칸에 횃불(DECO.torches개, 고르게)과 현수막(banner_every칸마다). 들인 칸(0.5m) 안에 들어가 충돌 면 밖으로 안 나옴
func _wall_props() -> void:
	# 앞이 막힌 칸(성벽 길·감시탑에 묻힌 곳)은 뺀다
	_bays = _bays.filter(func(b: Array) -> bool:
		var front: Vector3 = b[0] + b[1] * (float(GameData.DECO.recess) + 0.4)
		return not overlaps_any(front + Vector3.UP * 0.5, 0.2, 3.0))
	if _bays.is_empty():
		return
	var D: Dictionary = GameData.DECO
	var C: Dictionary = GameData.C
	var nt := mini(int(D.torches), _bays.size())
	var torch_at := {}
	for k in nt:
		torch_at[int(floor((k + 0.5) * _bays.size() / float(nt)))] = true
	_clutter = true
	for i in _bays.size():
		var p: Vector3 = _bays[i][0]
		var n: Vector3 = _bays[i][1]
		if torch_at.has(i):
			fbox(p, n, 0, 2.05, Vector3(0.2, 0.45, 0.03), C.iron)
			fbox(p, n, 0, 2.28, Vector3(0.07, 0.07, 0.3), C.iron)
			var tp := p + n * 0.3
			mesh(_cyl, C.wood_dark, tp + Vector3.UP * 2.25, Vector3(0.04, 0.32, 0.04), false)
			mesh(_cyl, C.torch_cup, tp + Vector3.UP * 2.45, Vector3(0.11, 0.16, 0.11), false)
			mesh(_sph_lo, C.flame, tp + Vector3.UP * 2.66, Vector3(0.11, 0.2, 0.11), false, null, "flame")
			mesh(_sph_lo, C.flame_core, tp + Vector3.UP * 2.62 + n * 0.02, Vector3(0.065, 0.12, 0.065), false, null, "flame")
		elif i % int(D.banner_every) == 0:
			var bc := banner_cols(p)
			fbox(p, n, 0, 3.95, Vector3(1.4, 0.07, 0.07), C.beam, "", 0.06)
			fbox(p, n, 0, 1.45, Vector3(1.1, 2.5, 0.03), bc[0], "", 0.1)
			fbox(p, n, 0, 1.6, Vector3(1.1, 0.16, 0.035), bc[1], "", 0.1)
			fbox(p, n, 0, 3.6, Vector3(1.1, 0.1, 0.035), bc[1], "", 0.1)
			fbox(p, n, 0, 2.35, Vector3(0.5, 0.5, 0.035), bc[1], "", 0.1, PI / 4)
			for s: float in [-0.35, 0.0, 0.35]:  # 밑 술 (뾰족)
				fbox(p, n, s, 1.3, Vector3(0.2, 0.2, 0.03), bc[0], "", 0.1, PI / 4)
	_clutter = false


# ── 땅: 잔디·들꽃·자갈 (MultiMesh, 고정 시드) ─────────────────
## 잔디 포기 메시: 가는 잎 3장을 부채꼴로 (높이 1 — 포기마다 DECO.grass_h로 줄임). 바람은 grass_blade 셰이더
static func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0 + 0.3
		var dv := Vector3(cos(a), 0, sin(a))
		var lean := Vector3(-sin(a), 0, cos(a)) * (0.22 if k % 2 == 0 else -0.22)
		var b0 := -dv * 0.04
		var b1 := dv * 0.04
		var t0 := lean + Vector3.UP - dv * 0.008
		var t1 := lean + Vector3.UP + dv * 0.008
		for v in [b0, b1, t1, b0, t1, t0]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	return st.commit()


## 들꽃 메시: 가는 줄기 + 꽃송이 (높이 약 1 — DECO.flower_h로 줄임). 색은 인스턴스 색 (줄기는 초록을 곱함)
func _flower_mesh() -> ArrayMesh:
	return Meshes.merge([[_box, Color(0.45, 0.65, 0.35), Transform3D(Basis.from_scale(Vector3(0.06, 0.9, 0.06)), Vector3(0, 0.45, 0))],
		[_sph_lo, Color.WHITE, Transform3D(Basis.from_scale(Vector3(0.22, 0.14, 0.22)), Vector3(0, 0.95, 0))]])


## 이 자리에 잔디·꽃을 놓아도 되나 (충돌 상자·흙길·돌바닥·맵 밖이 아님). cand = 검사할 상자들
func _ground_free(p: Vector3, m: float, cand: Array, path_m: float) -> bool:
	if absf(p.x) > half_x - 0.3 or absf(p.z) > half_z - 0.3:
		return false
	for a: AABB in cand:
		if a.position.y < 0.3 and p.x > a.position.x - m and p.x < a.end.x + m and p.z > a.position.z - m and p.z < a.end.z + m:
			return false
	for r in _paths:
		if absf(p.x - r.x) < r.z + path_m and absf(p.z - r.y) < r.w + path_m:
			return false
	for q in _no_grass:
		if q.grow(m).has_point(Vector2(p.x, p.z)):
			return false
	return true


func _build_scatter() -> void:
	var D: Dictionary = GameData.DECO
	var cs: float = D.grass_chunk
	var gh: float = D.grass_h
	var gcols: Array[Color] = []
	for hx: int in D.grass_cols:
		gcols.append(GameData.col(hx))
	var fcols: Array = D.flower_cols
	var grass: Array = []
	var flowers: Array = []
	var pebbles: Array = []
	# 잔디 (덩어리마다 그 근처 상자만 검사)
	var x0 := -half_x
	while x0 < half_x:
		var z0 := -half_z
		while z0 < half_z:
			var x1 := minf(x0 + cs, half_x)
			var z1 := minf(z0 + cs, half_z)
			var cand: Array = []
			for a in aabbs:
				if a.position.x < x1 + 1 and a.end.x > x0 - 1 and a.position.z < z1 + 1 and a.end.z > z0 - 1:
					cand.append(a)
			var cnt := int((x1 - x0) * (z1 - z0) * float(D.grass_density))
			for k in cnt:
				var p := Vector3(_drng.randf_range(x0, x1), 0, _drng.randf_range(z0, z1))
				var yaw := _drng.randf() * TAU
				var s := _drng.randf_range(0.65, 1.0)
				var ci := _drng.randi() % gcols.size()
				var fl := _drng.randf() < float(D.flower_ratio)
				if not _ground_free(p, 0.15, cand, 0.25):
					continue
				if fl:
					flowers.append(_flower_item(p, fcols))
				else:
					var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s * 1.1, gh * s, s * 1.1))
					grass.append([Transform3D(b, p), gcols[ci] * _drng.randf_range(0.9, 1.08)])
			z0 += cs
		x0 += cs
	# 흙길 가장자리·성벽 밑: 자갈과 들꽃
	var step := 1.0 / float(D.pebble_per_m)
	var edges: Array = []  # [시작, 방향, 길이, 밖 법선]
	for r in _paths:
		for s: float in [-1.0, 1.0]:
			edges.append([Vector3(r.x - r.z, 0, r.y + s * r.w), Vector3(1, 0, 0), r.z * 2, Vector3(0, 0, s)])
			edges.append([Vector3(r.x + s * r.z, 0, r.y - r.w), Vector3(0, 0, 1), r.w * 2, Vector3(s, 0, 0)])
	for wb: Array in _wall_bases:
		var c: Vector3 = wb[0]
		var n: Vector3 = wb[1]
		var t := Vector3.UP.cross(n)
		edges.append([c - t * float(wb[2]), t, float(wb[2]) * 2, n])
	for e: Array in edges:
		var o: Vector3 = e[0]
		var dv: Vector3 = e[1]
		var ln: float = e[2]
		var nv: Vector3 = e[3]
		var u := _drng.randf() * step
		while u < ln:
			var p := o + dv * u + nv * _drng.randf_range(0.2, 0.8)
			var kind := _drng.randf()
			u += step * _drng.randf_range(0.6, 1.4)
			if not _ground_free(p, 0.1, aabbs, 0.05):
				continue
			if kind < 0.6:
				for j in _drng.randi_range(1, 3):
					var q := p + Vector3(_drng.randf_range(-0.3, 0.3), 0, _drng.randf_range(-0.3, 0.3))
					var sc := _drng.randf_range(0.07, 0.17)
					var b := Basis(Vector3.UP, _drng.randf() * TAU) * Basis.from_scale(Vector3(sc * 1.3, sc * 0.4, sc))
					var pc := GameData.col(_jit(D.pebble_col, 0.15))
					if _ground_free(q, 0.1, aabbs, 0.0):
						pebbles.append([Transform3D(b, q), pc])
			else:
				for j in _drng.randi_range(2, 4):
					var q := p + Vector3(_drng.randf_range(-0.35, 0.35), 0, _drng.randf_range(-0.35, 0.35))
					var it := _flower_item(q, fcols)
					if _ground_free(q, 0.1, aabbs, 0.05):
						flowers.append(it)
	var range_end: float = D.grass_range
	_scatter("Grass", _blade_mesh(), MatStyles.get_mat("grass_blade"), grass, range_end, true)
	_scatter("Flowers", _flower_mesh(), MatStyles.get_mat("grass_blade", {"sway": 0.12}), flowers, range_end, false)
	_scatter("Pebbles", Meshes.merge([[_sph_lo, Color.WHITE, Transform3D()]]), Meshes.vertex_color_mat(), pebbles, range_end, false)


func _flower_item(p: Vector3, fcols: Array) -> Array:
	var h: float = float(GameData.DECO.flower_h) * _drng.randf_range(0.7, 1.15)
	var b := Basis(Vector3.UP, _drng.randf() * TAU) * Basis.from_scale(Vector3(h, h, h))
	return [Transform3D(b, p), GameData.col(fcols[_drng.randi() % fcols.size()])]


## 항목 [Transform3D, Color]을 grass_chunk 크기 덩어리마다 MultiMesh 하나로 (멀면 덩어리째 숨김, 그림자 없음)
func _scatter(nm: String, m: Mesh, mat: Material, items: Array, range_end: float, is_grass: bool) -> void:
	var cs: float = GameData.DECO.grass_chunk
	scatter_items[nm] = items
	var buckets := {}
	for it: Array in items:
		var p: Vector3 = (it[0] as Transform3D).origin
		var key := Vector2i(floori(p.x / cs), floori(p.z / cs))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(it)
	var keys := buckets.keys()
	keys.sort()
	for key: Vector2i in keys:
		var arr: Array = buckets[key]
		var center := Vector3((key.x + 0.5) * cs, 0, (key.y + 0.5) * cs)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m
		mm.instance_count = arr.size()
		for i in arr.size():
			var xf: Transform3D = arr[i][0]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - center))
			mm.set_instance_color(i, arr[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [nm, key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = center
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = 2.0
		add_child(mmi)
		if is_grass:
			grass_nodes.append(mmi)
		else:
			clutter_nodes.append(mmi)
