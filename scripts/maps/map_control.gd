class_name MapControl
extends WorldBuilder
## 쟁탈전 맵 "성곽 우물 광장" (사용자 요청 — HTML에 없음). 64m × 128m, 바깥은 높이 6m 성벽.
## z = 0 기준 거울 대칭: 블루 절반(남쪽, z+)만 _half(side)로 짓고 side = -1로 한 번 더 불러 레드 절반(북쪽, z-)을 만든다.
##   → 모든 상자는 z ≥ 0 쪽 좌표로 적고 z에 side를 곱한다. 가운데(z = 0)에 걸친 것도 반씩 나눠 지으면 저절로 대칭.
##   왼쪽(x-)·오른쪽(x+)은 두 팀이 똑같은 지형이라 공평하다.
## 블루 쪽 (z+, 남쪽에서 북쪽으로):
##   스폰룸 z 52~64 (지붕, 출구 3개: x -7 / 0(정문 4m) / +7) → 집결 마당 z 38~52 (낮은 엄폐물)
##   → 3갈래 z 12~38: 왼쪽 시장 골목(x -30~-16, 꺾이는 좁은 길) / 가운데 큰길(x -8~8, 수레·상자·낮은 벽) / 오른쪽 성벽 길(위 x 25~31 높이 3, 아래 x 16~25)
##     (갈래를 가르는 집 블록 x -16~-8, 8~16 · z 14~34)
##   → 중앙 광장 z -12~12: 거점(0,0) 반지름 7 돌 단상 + 우물 + 낮은 벽 4개, 감시탑 고지(x 20~30, 높이 3, 아래 아치 통로),
##     신전 폐허(x -32~-14)
## 충돌은 WorldBuilder처럼 상자(aabbs + StaticBody3D). 봇 길 찾기용 내비 메시는 지은 뒤 런타임에 굽는다 (bake_nav).
## 스폰룸 문엔 적에게만 막히는 투명 벽 (충돌 층: 블루 문 = 3번 층(값 4), 레드 문 = 4번 층(값 8)).

const BARRIER_LAYER := {"blue": 4, "red": 8}  # 이 팀의 스폰룸 문 (상대 팀 캐릭터의 mask에 넣는다)
const SIDE := {"blue": 1.0, "red": -1.0}

var cap_pos := Vector3(0, 0.5, 0)   # 거점 가운데 (단상 위)
var nav_region: NavigationRegion3D
var _barriers: StaticBody3D
# 거점 표시 (Control 모드가 색·게이지를 바꿈)
var cap_rim: Node3D           # 네모 테두리 (막대 4개, 재질 _rim_mat 하나)
var _rim_mat: StandardMaterial3D
var cap_fill: MeshInstance3D
var cap_pillar: MeshInstance3D
var cap_flag: MeshInstance3D
var cap_flag_pole_y := 0.0
var _barrier_meshes: Array[MeshInstance3D] = []


func _init() -> void:
	map_id = "control"
	half_x = 31.4
	half_z = 63.4


# ── 데이터 (블루 기준 — 레드는 z를 뒤집음) ──────────────────────
static func side_of(team: String) -> float:
	return float(SIDE.get(team, 1.0))


static func flip(p: Vector3, team: String) -> Vector3:
	return Vector3(p.x, p.y, p.z * side_of(team))


## 팀 스폰룸 안쪽 (회복·공격 금지 판정)
static func spawn_room(team: String) -> AABB:
	var s := side_of(team)
	return AABB(Vector3(-10, -1, 52.6 if s > 0 else -64), Vector3(20, 6, 11.4))


## 스폰 위치 5개 (거점을 바라보게 — yaw는 spawn_yaw)
static func spawn_spots(team: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector3 in [Vector3(-6, 0, 58.5), Vector3(-3, 0, 61), Vector3(0, 0, 57.5), Vector3(3, 0, 61), Vector3(6, 0, 58.5)]:
		out.append(flip(p, team))
	return out


static func spawn_yaw(team: String) -> float:
	return 0.0 if side_of(team) > 0 else PI  # yaw 0 = -z(북쪽)를 봄


## 스폰룸 문 앞 (스폰킬 금지 판정 기준)
static func door_pos(team: String) -> Vector3:
	return flip(Vector3(0, 0, 51), team)


## 3갈래 길: 갈래마다 지나갈 점 (왼쪽 시장 골목 / 가운데 큰길 / 오른쪽 성벽 길 위)
static func lane_points(team: String) -> Array:
	var L := [
		[Vector3(-19.5, 0, 33), Vector3(-26, 0, 19), Vector3(-24, 0, 9)],  # 시장 골목 → 신전 폐허
		[Vector3(0, 0, 34), Vector3(0, 0, 14)],                             # 큰길
		[Vector3(28, 3, 30), Vector3(28, 3, 14), Vector3(25, 3, 5)],        # 성벽 길 위 → 감시탑
	]
	var out := []
	for lane: Array in L:
		out.append(lane.map(func(p: Vector3) -> Vector3: return flip(p, team)))
	return out


## 궁수·석궁병이 거점을 지켜보는 자리 (팀마다)
static func watch_spots(team: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector3 in [Vector3(25, 3, 3.5), Vector3(28, 3, 12), Vector3(-2, 0, 13.5), Vector3(-18, 0, 7), Vector3(5.5, 0, 12.5)]:
		out.append(flip(p, team))
	return out


func item_spots() -> Array:
	return [Vector3(-26, 0, 0), Vector3(25, 3, 0), Vector3(-12, 0, 0), Vector3(12, 0, 0)]


func horse_spots() -> Array:
	return [Vector3(-21, 0, 44), Vector3(-21, 0, -44)]  # 양 팀 집결 마당 옆 (동시에)


func chicken_spots() -> Array:
	return [Vector3(-26, 0, 28), Vector3(-26, 0, -28), Vector3(-22, 0, 2)]


## 닭·봇이 돌아다닐 곳: 시장 골목·신전 폐허·광장
func random_point() -> Vector3:
	var areas := [AABB(Vector3(-29, 0, -36), Vector3(12, 0, 72)), AABB(Vector3(-13, 0, -11), Vector3(30, 0, 22))]
	for n in 40:
		var a: AABB = areas[_rng.randi() % areas.size()]
		var p := Vector3(_rng.randf_range(a.position.x, a.end.x), 0, _rng.randf_range(a.position.z, a.end.z))
		if not overlaps_any(p, 0.8, 1.9) and p.distance_to(cap_pos) > 2.5:
			return p
	return Vector3(-12, 0, 8)


# ── 짓기 ─────────────────────────────────────────────────────
## 블루 절반의 상자를 side(1 블루 / -1 레드)로 뒤집어 놓음. z와 d는 z ≥ 0 쪽 값
func hb(side: float, x: float, y: float, z: float, w: float, h: float, d: float, hex: int, collide := true, shadow := true, style := "") -> void:
	box(x, y, z * side, w, h, d, hex, collide, shadow, style)


## 충돌만 (hb와 같은 상자 — 겉모양은 따로 그림: 성벽)
func hcb(side: float, x: float, y: float, z: float, w: float, h: float, d: float) -> void:
	col_box(x, y, z * side, w, h, d)


## 현수막: 블루 절반(z+)은 파랑, 레드 절반은 빨강
func banner_cols(pos: Vector3) -> Array:
	var team := "blue" if pos.z > 0 else "red"
	return [GameData.team_hex(team, "body"), GameData.team_hex(team, "pale")]


func build() -> void:
	var C: Dictionary = GameData.C
	# 땅 (보이는 판 + 두꺼운 충돌 상자)
	ground_plane(Vector2(240, 300))
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(200, 2, 260)
	gcs.shape = gbs
	gcs.position = Vector3(0, -1, 0)
	body.add_child(gcs)
	for side: float in [1.0, -1.0]:
		_half(side)
	# 거점 단상(정사각형)·우물 겉모양 (충돌은 _half가 절반씩)
	var ch := float(GameData.MODES.control.cap_half)
	box(0, 0, 0, ch * 2, 0.5, ch * 2, C.stone, false, true, "castle_stone")
	box(0, 0.5, 0, ch * 2 - 1.2, 0.01, ch * 2 - 1.2, C.stone2, false, false, "castle_stone")
	_no_grass.append(Rect2(-ch, -ch, ch * 2, ch * 2))
	mesh(_cyl, C.brick, Vector3(0, 0.5 + 0.6, 0), Vector3(1.3, 1.2, 1.3), true, null, "brick")
	mesh(_cyl, 0x2c4a6b, Vector3(0, 1.71, 0), Vector3(1.0, 0.02, 1.0), false)  # 우물 물
	box(0, 1.7, 0, 0.18, 5.2, 0.18, C.wood_dark, false)  # 깃대
	_well_roof()
	# 바깥 언덕·구름
	for n in 18:
		var a := float(n) / 18.0 * TAU
		mesh(_sph, C.grass_dark if n % 2 else 0x7cc357, Vector3(sin(a) * 70, -2, cos(a) * 110),
			Vector3(_rng.randf_range(18, 30), _rng.randf_range(6, 14), _rng.randf_range(18, 30)), false)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color.WHITE
	cloud_mat.emission_enabled = true
	cloud_mat.emission = GameData.col(0x6f7f8f)
	for n in 8:
		var g := Node3D.new()
		add_child(g)
		var puffs := []
		for j in 4:
			puffs.append([_sph, Color.WHITE, Transform3D(Basis.from_scale(Vector3(_rng.randf_range(4, 7), _rng.randf_range(2.5, 4), _rng.randf_range(4, 6))), Vector3(j * 4 - 6, 0, 0))])
		var s := MeshInstance3D.new()
		s.mesh = Meshes.merge(puffs)
		s.material_override = cloud_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(s)
		g.position = Vector3(_rng.randf_range(-140, 140), _rng.randf_range(55, 75), _rng.randf_range(-160, 160))
		_clouds.append(g)


## 한쪽 절반 (side 1 = 블루 남쪽, -1 = 레드 북쪽)
func _half(side: float) -> void:
	var C: Dictionary = GameData.C
	var team := "blue" if side > 0 else "red"
	var tc := GameData.team_hex(team, "body")
	var ta := GameData.team_hex(team, "accent")
	# 흙길
	path_rect(0, 25 * side, 10, 26)                                     # 큰길 (땅 셰이더)
	path_rect(-23, 25 * side, 8, 26)                                    # 시장 골목 바닥
	path_rect(0, 45 * side, 40, 14)                                     # 집결 마당
	hb(side, 0, 0, 6, 60, 0.015, 12, 0xd8c79a, false, false, "castle_stone")  # 광장 돌바닥
	_no_grass.append(Rect2(-30, 0.0 if side > 0 else -12.0, 60, 12))
	var room := spawn_room(team)
	_no_grass.append(Rect2(room.position.x, room.position.z, room.size.x, room.size.z))
	# ── 바깥 성벽 (높이 6) ──
	hcb(side, -33, 0, 32.5, 2, 6, 65)   # 충돌은 원래 상자 그대로, 겉모양은 castle_wall (버팀벽·띠돌·횃불·현수막)
	hcb(side, 33, 0, 32.5, 2, 6, 65)
	hcb(side, 0, 0, 65, 68, 6, 2)
	castle_wall(Vector3(-32, 0, 32 * side), Vector3(1, 0, 0), 64, 6, 2, C.stone, 30)
	castle_wall(Vector3(32, 0, 32 * side), Vector3(-1, 0, 0), 64, 6, 2, C.stone, 30)
	castle_wall(Vector3(0, 0, 64 * side), Vector3(0, 0, -side), 64, 6, 2, C.stone, 30)
	var i := 1.5
	while i < 64:
		hb(side, -33, 6, i, 2, 0.8, 1.4, C.stone2, false, true, "castle_stone")
		hb(side, 33, 6, i, 2, 0.8, 1.4, C.stone2, false, true, "castle_stone")
		i += 3.0
	# ── 스폰룸 (x -10~10, z 52~64, 높이 5, 지붕) ──
	hb(side, -10.3, 0, 58.3, 0.6, 5, 11.4, C.stone2, true, true, "castle_stone")
	hb(side, 10.3, 0, 58.3, 0.6, 5, 11.4, C.stone2, true, true, "castle_stone")
	for seg: Array in [[-10.6, -8.25], [-5.75, -2.0], [2.0, 5.75], [8.25, 10.6]]:  # 북쪽 벽: 출구 3개 사이
		var x0: float = seg[0]
		var x1: float = seg[1]
		hb(side, (x0 + x1) / 2, 0, 52.3, x1 - x0, 5, 0.6, C.stone2, true, true, "castle_stone")
	for door: Array in [[-7.0, 2.5], [0.0, 4.0], [7.0, 2.5]]:  # 문 위 상인방
		hb(side, door[0], 3.0, 52.3, door[1], 2.0, 0.6, C.stone_dark, true, true, "castle_stone")
	hb(side, 0, 5, 58.3, 21.8, 0.5, 12.4, tc)                          # 팀 색 지붕
	hb(side, 0, 5.5, 58.3, 14, 1.2, 6, tc, false)
	for x: float in [-4.0, 4.0]:                                         # 문 위 팀 깃발 (걸개)
		hb(side, x, 1.8, 51.95, 1.6, 2.6, 0.1, tc, false, false)
		hb(side, x, 2.6, 51.9, 0.5, 0.5, 0.06, ta, false, false)
	hb(side, 0, 0.0, 63.5, 18, 0.02, 0.8, ta, false, false)
	# ── 집결 마당 (z 38~52): 낮은 엄폐물 ──
	for hay: Array in [[-14.0, 44.0], [13.0, 47.0], [-4.5, 47.5], [6.0, 41.0]]:
		hb(side, hay[0], 0, hay[1], 2.4, 1.0, 1.3, C.hay, true, true, "hay")
	crate_h(side, -7.0, 41.5, 1.2, 1)
	crate_h(side, 15.5, 41.0, 1.1, 2)
	crate_h(side, -22.0, 49.0, 1.2, 2)
	# ── 갈래를 가르는 집 블록 (못 올라감) ──
	for x: float in [-12.0, 12.0]:
		hb(side, x, 0, 24, 8, 5.5, 20, C.plaster, true, true, "plaster")
		hb(side, x, 5.25, 24, 8.2, 0.3, 20.2, C.wood_dark, false, true, "wood_plank")
		_corner_posts(x, 24 * side, 8, 20, 5.5)
		# 큰길 쪽 면에 문, 나머지 면은 창문 자동 (나무 골조)
		house_faces(x, 24 * side, 8, 20, 5.5, false, [-7.0, -3.5, 3.5, 7.0], 3 if x > 0 else 2)
		roof(Vector3(x, 7.0, 24 * side), Vector3(4.6 * 1.414, 3, 10.6 * 1.414), C.roof_slate if x < 0 else C.roof_brown)  # 팀 색과 헷갈리지 않게
		eaves(x, 24 * side, 5.5, 4.6, 10.6)
		chimney(x, 24 * side, 8, 20, 5.5)
	# ── 왼쪽 시장 골목 (x -30~-16): 블록 두 개로 꺾이는 좁은 길 ──
	hb(side, -26.5, 0, 30.5, 7, 4.5, 7, C.brick, true, true, "brick")      # 위쪽 블록 = 벽돌집 (길은 오른쪽 x -23~-16)
	quoins(-26.5, 30.5 * side, 7, 7, 4.5, 0.4)
	house_faces(-26.5, 30.5 * side, 7, 7, 4.5, true, [-2.2, 2.2], 2)
	roof(Vector3(-26.5, 6.0, 30.5 * side), Vector3(4 * 1.414, 3, 4 * 1.414), C.roof_brown)
	eaves(-26.5, 30.5 * side, 4.5, 4, 4)
	chimney(-26.5, 30.5 * side, 7, 7, 4.5)
	hb(side, -19, 0, 18.5, 6, 4.5, 5, C.plaster, true, true, "plaster")        # 아래쪽 블록 (길은 왼쪽 x -30~-22)
	hb(side, -19, 4.25, 18.5, 6.1, 0.3, 5.1, C.wood_dark, false, true, "wood_plank")
	_corner_posts(-19, 18.5 * side, 6, 5, 4.5)
	house_faces(-19, 18.5 * side, 6, 5, 4.5, false, [-1.8, 1.8], 3)
	roof(Vector3(-19, 6.0, 18.5 * side), Vector3(3.5 * 1.414, 3, 3 * 1.414), C.roof_slate)
	eaves(-19, 18.5 * side, 4.5, 3.5, 3)
	hb(side, -29.0, 0, 36.5, 2.0, 1.0, 1.2, C.hay, true, true, "hay")
	stall_h(side, -18.2, 28.0, C.hay)
	stall_h(side, -27.8, 22.5, 0x7fc35a)
	crate_h(side, -21.0, 24.0, 1.0, 2)
	crate_h(side, -24.0, 14.0, 1.1, 1)
	hb(side, -28.5, 0, 16.0, 2.2, 1.0, 1.2, C.hay, true, true, "hay")
	# ── 가운데 큰길 (x -8~8): 부서진 수레·상자 더미·낮은 벽 ──
	hb(side, 3, 0, 24, 2.6, 1.1, 1.5, C.wood, true, true, "wood_plank")
	hb(side, 3, 1.1, 24, 2.8, 0.15, 1.7, C.wood_dark, false, true, "wood_plank")
	for wz: float in [23.2, 24.8]:
		hb(side, 1.6, 0, wz, 0.25, 0.9, 0.9, C.wood_dark, false, true, "wood_plank_v")
	crate_h(side, -4, 18, 1.2, 2)
	crate_h(side, -5.2, 19.0, 1.0, 1)
	hb(side, 0, 0, 30, 4, 1.1, 0.6, C.stone, true, true, "castle_stone")
	# ── 오른쪽 성벽 길: 높이 3 성벽 위 산책로 (x 25~31) + 아래 지면 통로 (x 16~25) ──
	hb(side, 28.5, 0, 21, 7, 3, 26, C.stone, true, true, "castle_stone")            # x 25~32, z 8~34 (감시탑과 이어짐)
	for k in 6:                                          # 집결 마당 쪽 계단 (z 34 → 38)
		var h := 3.0 - 0.5 * (k + 1)
		if h > 0:
			hb(side, 28.5, 0, 34.35 + 0.7 * k, 7, h, 0.7, C.stone2, true, true, "castle_stone")
	for zz: float in [14.0, 20.0, 26.0, 32.0]:          # 총안 몇 개 (안쪽 가장자리)
		hb(side, 25.3, 3, zz, 0.6, 1.0, 1.6, C.stone2, true, true, "castle_stone")
	# ── 감시탑 고지 (x 20~30, z -8~8, 높이 3) + 아래 아치 통로 (z -3~3) ──
	hb(side, 26, 0, 5.5, 12, 3, 5, C.stone, true, true, "castle_stone")              # x 20~32, z 3~8 꽉 찬 부분
	hb(side, 26, 2.4, 1.5, 12, 0.6, 3, C.stone, true, true, "castle_stone")          # z 0~3 아치 지붕 (밑으로 지나감)
	hb(side, 26, 3, 7.7, 12, 0.8, 0.6, C.stone2, true, true, "castle_stone")         # 난간
	quoin_corner(20, 8 * side, -1, side, 3, 0.5)   # 감시탑·성벽 길 모서리 돌
	quoin_corner(20, 3 * side, -1, -side, 2.4, 0.5)
	quoin_corner(25, 34 * side, -1, side, 3, 0.5)
	for k in 5:                                          # 광장 쪽 계단 (x 20 → 15.5, z 4~8)
		var h := 3.0 - 0.5 * (k + 1)
		hb(side, 19.55 - 0.9 * k, 0, 6, 0.9, h, 4, C.stone2, true, true, "castle_stone")
	# ── 중앙 광장: 거점 단상(정사각형 18m)·우물·낮은 벽 4개 ──
	var ch := float(GameData.MODES.control.cap_half)
	hc(side, 0, 0, ch / 2, ch * 2, 0.5, ch)  # 단상 절반 (충돌만 — 겉은 build)
	hc(side, 0, 0.5, 0.6, 2.4, 1.2, 1.2)  # 우물 (충돌만 — 겉은 build의 원기둥)
	for x: float in [-4.8, 4.8]:          # 낮은 벽: 대각선 네 곳
		hb(side, x, 0.5, 4.8, 3, 1.0, 0.6, C.stone2, true, true, "castle_stone")
	# ── 신전 폐허 (x -32~-14): 기둥·아치·무너진 벽 ──
	for pp: Array in [[-28.0, 3.0], [-22.0, 3.0], [-16.5, 3.0], [-28.0, 9.0], [-16.5, 9.5]]:
		hb(side, pp[0], 0, pp[1], 0.9, 4.0, 0.9, C.marble, true, true, "castle_stone")   # 대리석 기둥
	hb(side, -22, 4.0, 9.0, 6.0, 0.7, 0.9, C.marble, true, true, "castle_stone")    # 아치 (기둥 둘 + 윗돌)
	hb(side, -25, 0, 9.0, 0.9, 4.0, 0.9, C.marble, true, true, "castle_stone")
	hb(side, -19.5, 0, 6.5, 4.0, 1.4, 0.6, C.stone2, true, true, "castle_stone")     # 무너진 벽
	hb(side, -27.0, 0, 6.0, 0.6, 1.2, 3.0, C.stone2, true, true, "castle_stone")
	hb(side, -24.5, 0, 0.6, 2.0, 0.7, 1.2, C.stone_dark, true, true, "castle_stone")
	for pp: Array in [[-28.0, 3.0], [-22.0, 3.0], [-16.5, 3.0], [-28.0, 9.0], [-16.5, 9.5], [-25.0, 9.0]]:  # 기둥 받침·머리 (충돌 없음, 5cm)
		for yy: float in [0.0, 3.75]:
			hb(side, pp[0], yy, pp[1], 1.0, 0.25, 1.0, C.quoin, false, true, "castle_stone")
	tree(-28.0, 44 * side, 1.0)
	tree(28.0, 44 * side, 0.9)


## 충돌 상자만 (보이지 않음)
func hc(side: float, x: float, y: float, z: float, w: float, h: float, d: float) -> void:
	var zc := z * side
	add_col(x - w / 2.0, y, zc - d / 2.0, x + w / 2.0, y + h, zc + d / 2.0)


func crate_h(side: float, x: float, z: float, s: float, st: int) -> void:
	crate(x, z * side, s, st)


func stall_h(side: float, x: float, z: float, cloth: int) -> void:
	stall(x, z * side, cloth)


## 나무 골조 집 네 모서리 기둥 (충돌 없음)
func _corner_posts(x: float, z: float, w: float, d: float, h: float) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(x + sx * (w / 2), 0, z + sz * (d / 2), 0.35, h, 0.35, GameData.C.wood_dark, false, true, "wood_plank_v")


## 우물 지붕: 기둥 둘·가로대·작은 박공 지붕(기와)·도르래·밧줄·두레박 (충돌 없음 — 우물 충돌은 그대로)
func _well_roof() -> void:
	var C: Dictionary = GameData.C
	for sx: float in [-1.0, 1.0]:
		box(sx * 1.15, 1.7, 0, 0.14, 2.1, 0.14, C.beam, false, true, "wood_plank_v")
	box(0, 3.45, 0, 2.5, 0.12, 0.12, C.beam, false, true, "wood_plank")
	var slope := atan2(0.55, 0.85)
	for sz: float in [-1.0, 1.0]:
		var rm := mesh(_box, C.roof_brown, Vector3(0, 3.95, sz * 0.43), Vector3(2.8, 0.08, 1.1), true, null, "roof_tiles")
		rm.rotation.x = sz * slope
	box(0, 4.18, 0, 2.9, 0.1, 0.12, C.beam, false, true, "wood_plank")  # 용마루
	var pul := mesh(_cyl, C.wood_dark, Vector3(0.5, 3.3, 0), Vector3(0.13, 0.1, 0.13), true)
	pul.rotation.z = PI / 2
	box(0.5, 2.15, 0.06, 0.025, 1.1, 0.025, C.rope, false, false)
	mesh(_cyl, C.wood, Vector3(0.5, 2.05, 0.06), Vector3(0.15, 0.22, 0.15), true, null, "wood_plank_v")
	mesh(_cyl, C.iron, Vector3(0.5, 2.1, 0.06), Vector3(0.155, 0.04, 0.155), false)


## 합친 뒤에 붙임: 스폰룸 문 막(적만 막힘), 거점 바닥 고리·게이지·빛기둥·깃발
func _build_live() -> void:
	_barriers = StaticBody3D.new()
	_barriers.name = "TeamBarriers"
	_barriers.collision_layer = 0
	_barriers.collision_mask = 0
	add_child(_barriers)
	for team: String in ["blue", "red"]:
		var s := side_of(team)
		var col := GameData.col(GameData.team_hex(team, "accent"))
		for door: Array in [[-7.0, 2.5], [0.0, 4.0], [7.0, 2.5]]:
			var b := StaticBody3D.new()
			b.collision_layer = BARRIER_LAYER[team]
			b.collision_mask = 0
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(door[1], 3.0, 0.6)
			cs.shape = bs
			b.add_child(cs)
			b.position = Vector3(door[0], 1.5, 52.3 * s)
			_barriers.add_child(b)
			var mt := StandardMaterial3D.new()
			mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mt.cull_mode = BaseMaterial3D.CULL_DISABLED
			mt.albedo_color = Color(col, float(GameData.MODES.control.barrier_alpha))
			var m := MeshInstance3D.new()
			m.mesh = Meshes.box()
			m.scale = Vector3(door[1], 3.0, 0.05)
			m.material_override = mt
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position = b.position
			add_child(m)
			_barrier_meshes.append(m)
	# 거점 바닥 테두리 (주인 색) + 안쪽 게이지 링 (시계 방향으로 차오름) + 빛기둥 + 깃발
	var ch := float(GameData.MODES.control.cap_half)
	cap_rim = Node3D.new()
	cap_rim.position = Vector3(0, 0.53, 0)
	add_child(cap_rim)
	_rim_mat = _glow_mat(Color.WHITE, 0.85)
	for e: Array in [[0.0, -ch, ch * 2 + 0.5, 0.5], [0.0, ch, ch * 2 + 0.5, 0.5], [-ch, 0.0, 0.5, ch * 2 + 0.5], [ch, 0.0, 0.5, ch * 2 + 0.5]]:
		var bar := MeshInstance3D.new()
		bar.mesh = Meshes.box()
		bar.scale = Vector3(e[2], 0.04, e[3])
		bar.position = Vector3(e[0], 0, e[1])
		bar.material_override = _rim_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cap_rim.add_child(bar)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float progress = 0.0;
void fragment() {
	// 네모 판 UV: 가운데 (0.5, 0.5). 테두리 안쪽 띠가 북쪽(-z)에서 시작해 위에서 볼 때 시계 방향으로 참
	vec2 d = UV - vec2(0.5);
	float r = max(abs(d.x), abs(d.y)) * 2.0;
	float a = atan(d.x, -d.y);
	if (a < 0.0) a += 6.2831853;
	if (r < 0.86 || r > 0.93 || a > progress * 6.2831853) discard;
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	cap_fill = MeshInstance3D.new()
	cap_fill.mesh = pm
	cap_fill.scale = Vector3.ONE * ch
	cap_fill.position = Vector3(0, 0.54, 0)
	cap_fill.material_override = sm
	cap_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap_fill)
	cap_pillar = MeshInstance3D.new()
	cap_pillar.mesh = Meshes.tube(1.3, 50.0)
	cap_pillar.position = Vector3(0, 25.5, 0)
	var pmt := _glow_mat(Color.WHITE, 0.14)
	pmt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmt.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	pmt.disable_fog = true
	cap_pillar.material_override = pmt
	cap_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap_pillar)
	cap_flag = MeshInstance3D.new()
	cap_flag.mesh = Meshes.box()
	cap_flag.scale = Vector3(1.6, 0.95, 0.06)
	cap_flag_pole_y = 6.4
	cap_flag.position = Vector3(0.9, cap_flag_pole_y, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color.WHITE
	cap_flag.material_override = fm
	add_child(cap_flag)
	_bake_nav()


static func _glow_mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c, a)
	return m


## 거점 표시 바꾸기: rim = 테두리 색, fill = 게이지 색·진행(0~1), flag_up = 깃발 높이(0~1)
func set_cap_look(rim: Color, fill: Color, progress: float, flag_col: Color, flag_up: float) -> void:
	_rim_mat.albedo_color = Color(rim, 0.85)
	var sm := cap_fill.material_override as ShaderMaterial
	sm.set_shader_parameter("col", Color(fill, 0.95))
	sm.set_shader_parameter("progress", clampf(progress, 0, 1))
	(cap_pillar.material_override as StandardMaterial3D).albedo_color = Color(rim, 0.14)
	(cap_flag.material_override as StandardMaterial3D).albedo_color = flag_col
	cap_flag.position.y = lerpf(2.6, cap_flag_pole_y, clampf(flag_up, 0, 1))


## 봇 길 찾기용 내비 메시: 월드 충돌 상자(1번 층)에서 굽는다. 스폰룸 문 막은 안 넣음 (적은 거기로 안 감)
func _bake_nav() -> void:
	var M: Dictionary = GameData.MODES.control
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = M.nav_cell
	nm.cell_height = M.nav_cell_h
	nm.agent_radius = M.nav_agent_r
	nm.agent_height = M.nav_agent_h
	nm.agent_max_climb = M.nav_climb
	nm.agent_max_slope = M.nav_slope
	nm.filter_baking_aabb = AABB(Vector3(-32, -0.5, -64), Vector3(64, 8, 128))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, body)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	var map := nav_region.get_navigation_map()  # 맵 칸 크기를 내비 메시와 맞춤
	NavigationServer3D.map_set_cell_size(map, nm.cell_size)
	NavigationServer3D.map_set_cell_height(map, nm.cell_height)


func nav_map() -> RID:
	return nav_region.get_navigation_map() if nav_region and nav_region.is_inside_tree() else RID()


## 내비 경로 (없으면 빈 배열)
func nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var m := nav_map()
	if not m.is_valid():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(m, from, to, true)


func _build_spawns() -> void:
	spawn_points.clear()
	for team: String in ["blue", "red"]:
		spawn_points.append_array(spawn_spots(team))
