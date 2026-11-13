class_name StarFx
extends Node3D
## 황금 붕어빵 무적 연출 (마리오카트 스타 느낌) — Combat 아래 StarFx 노드. 보기만 함 (판정과 무관).
## 수치는 GameData.STAR_FX. 무적 여부는 PlayerController.star_t (친구 캐릭터는 상태 비트로 받음).
##   1. 몸 번쩍임: 무적인 캐릭터의 모든 조각에 material_overlay로 금색 ↔ 흰색을 덮어씌운다 (초당 8번).
##      재질은 캐릭터마다 하나씩 따로 만든다 (GameData.mat()은 모두가 같이 써서 건드리면 안 됨). 끝나면 overlay만 치운다.
##      끝나기 1초 전부터는 초당 16번 + 중간중간 꺼짐 (곧 끝난다는 신호).
##   2. 반짝이: 몸 둘레에서 별(얇은 상자 두 개 십자)이 튀어나와 위로 날아가며 사라짐. 움직이면 발밑에 금가루 꼬리.
##      MultiMesh 하나에 모아 그리기 한 번.
##   3. 금빛: OmniLight3D (반경 4m). 웹 Compatibility는 빛 개수가 적어서 카메라에서 가까운 2명만.
## 1인칭 화면(비네트·테두리 반짝이)은 hud.gd StarEdge, 뷰모델 번쩍임은 viewmodel.gd가 flash_color()로 한다.

var combat: Combat

var _mm: MultiMeshInstance3D
var _parts: Array[Dictionary] = []   # {p, v, life, max, size, col, rot, spin, up}
var _st := {}                        # 캐릭터 → {model, geos, mat, spark, trail}
var _lights: Array[OmniLight3D] = []
var _clock := 0.0
## 몸 번쩍임 재질 하나를 늘 붙들어 둔다 — 무적이 끝날 때마다 셰이더가 지워져 다음에 다시 컴파일되지 않게, 시작할 때 미리 데우게 (ShaderWarm)
var keep_mats: Array[Material] = [_overlay_mat()]

static var _star_mesh: ArrayMesh


## 지금 번쩍임 색 (a = 0이면 이번 순간은 꺼짐). left = 남은 무적 시간
static func flash_color(left: float, clock: float) -> Color:
	var F: Dictionary = GameData.STAR_FX
	if left <= 0:
		return Color(0, 0, 0, 0)
	var ending := left < float(F.end_t)
	var hz: float = F.end_hz if ending else F.flash_hz
	var ph := int(floor(clock * hz))
	if ending and ph % 3 == 2:  # 끝나갈 땐 세 번에 한 번 꺼짐
		return Color(0, 0, 0, 0)
	var c := GameData.col(F.gold if ph % 2 == 0 else F.white)
	c.a = F.overlay_a
	return c


## 별 모양 반짝이: 얇은 상자 두 개를 십자로 (+ 작은 대각선 둘). 정점 색은 흰색 — 색은 인스턴스 색으로
static func star_mesh() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var b := Meshes.box()
	var W := Color.WHITE
	var it := [
		[b, W, Transform3D(Basis().scaled(Vector3(1.0, 0.16, 0.16)), Vector3.ZERO)],
		[b, W, Transform3D(Basis().scaled(Vector3(0.16, 1.0, 0.16)), Vector3.ZERO)],
		[b, W, Transform3D(Basis(Vector3(0, 0, 1), PI / 4).scaled_local(Vector3(0.5, 0.1, 0.1)), Vector3.ZERO)],
		[b, W, Transform3D(Basis(Vector3(0, 0, 1), -PI / 4).scaled_local(Vector3(0.5, 0.1, 0.1)), Vector3.ZERO)],
	]
	_star_mesh = Meshes.merge(it)
	return _star_mesh


static func spark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_fog = true
	return m


## 몸에 덮어씌우는 번쩍임 재질 (캐릭터마다 하나)
static func _overlay_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 빛 상관없이 밝게 = 발광
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	return m


func _ready() -> void:
	var F: Dictionary = GameData.STAR_FX
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = star_mesh()
	mm.instance_count = int(F.pool)
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-400, -60, -400), Vector3(800, 200, 800))
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.material_override = spark_mat()
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)
	for i in int(F.light_max):
		var l := OmniLight3D.new()
		l.light_color = GameData.col(F.gold)
		l.omni_range = F.light_range
		l.light_energy = F.light_energy
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)


## 새 경기·메뉴: 다 치움
func clear() -> void:
	for e in _st.keys():
		if is_instance_valid(e):
			_unflash(e)
	_st.clear()
	_parts.clear()
	_mm.multimesh.visible_instance_count = 0
	for l in _lights:
		l.visible = false


func _process(dt: float) -> void:
	if not combat:
		return
	_clock += dt
	var stars: Array[PlayerController] = []
	for e in combat.ents:
		if e.alive and e.star_t > 0:
			stars.append(e)
	# 무적이 끝난 캐릭터는 원래대로
	for e in _st.keys():
		if not is_instance_valid(e) or not stars.has(e):
			_unflash(e)
			_st.erase(e)
	for e in stars:
		_update_ent(e, dt)
	_update_parts(dt)
	_update_lights(stars)


func _update_ent(e: PlayerController, dt: float) -> void:
	var F: Dictionary = GameData.STAR_FX
	var s: Dictionary = _st.get(e, {})
	if s.is_empty():
		s = {"model": null, "geos": [], "mat": _overlay_mat(), "spark": 0.0, "trail": 0.0}
		_st[e] = s
	if s.model != e.model:  # 병과가 바뀌어 몸을 새로 만들었으면 조각 목록도 다시
		_unflash(e)
		s.model = e.model
		s.geos = e.model.find_children("*", "GeometryInstance3D", true, false) if e.model else []
	var c := flash_color(e.star_t, _clock)
	var mat: StandardMaterial3D = s.mat
	mat.albedo_color = c
	var on := c.a > 0
	for g in s.geos:
		if is_instance_valid(g):
			g.material_overlay = mat if on else null
	# 반짝이 (1인칭인 나는 내 몸 둘레엔 안 뿌림 — 화면은 HUD가 맡음)
	if e.is_local and not combat.tp_on():
		return
	var base := e.global_position + Vector3(0, e.mount_h, 0)
	s.spark -= dt
	while s.spark <= 0:
		s.spark += float(F.spark_every)
		var a := randf_range(0, TAU)
		var r := randf_range(0.2, float(F.spark_r))
		var p := base + Vector3(cos(a) * r, randf_range(0.15, 1.9), sin(a) * r)
		var out := Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 0.9)
		_add(p, out + Vector3(0, float(F.spark_up) * randf_range(0.6, 1.3), 0), F.spark_life, float(F.spark_size) * randf_range(0.7, 1.3))
	var hs := Vector2(e.velocity.x, e.velocity.z).length()
	if hs > float(F.trail_speed):
		s.trail -= dt
		while s.trail <= 0:
			s.trail += float(F.trail_every)
			var p := base + Vector3(randf_range(-0.3, 0.3), randf_range(0.05, 0.6), randf_range(-0.3, 0.3))
			_add(p, Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.4), randf_range(-0.2, 0.2)), F.trail_life, float(F.trail_size) * randf_range(0.6, 1.4))


func _unflash(e: PlayerController) -> void:
	var s: Dictionary = _st.get(e, {})
	for g in s.get("geos", []):
		if is_instance_valid(g):
			g.material_overlay = null


func _add(p: Vector3, v: Vector3, life: float, size: float) -> void:
	var F: Dictionary = GameData.STAR_FX
	if _parts.size() >= int(F.pool):
		_parts.pop_front()
	_parts.append({"p": p, "v": v, "life": life, "max": life, "size": size,
		"col": GameData.col(F.gold if randf() < 0.65 else F.white), "rot": randf_range(0, TAU), "spin": randf_range(-6, 6)})


func _update_parts(dt: float) -> void:
	var mm := _mm.multimesh
	var i := 0
	while i < _parts.size():
		var q: Dictionary = _parts[i]
		q.life -= dt
		if q.life <= 0:
			_parts.remove_at(i)
			continue
		q.p += (q.v as Vector3) * dt
		q.v *= 1.0 - minf(1.0, dt * 1.5)
		q.rot += float(q.spin) * dt
		i += 1
	var n := _parts.size()
	for k in n:
		var q: Dictionary = _parts[k]
		var t: float = q.life / q.max
		var pop := minf(1.0, (1.0 - t) * 8.0)            # 톡 커졌다가
		var sc: float = q.size * pop * (0.4 + 0.6 * t)   # 작아지며 사라짐
		mm.set_instance_transform(k, Transform3D(Basis(Vector3(0, 0, 1), q.rot).scaled(Vector3.ONE * maxf(sc, 0.001)), q.p))
		var c: Color = q.col
		c.a = t
		mm.set_instance_color(k, c)
	mm.visible_instance_count = n


func _update_lights(stars: Array[PlayerController]) -> void:
	var F: Dictionary = GameData.STAR_FX
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position if cam else Vector3.ZERO
	var sorted := stars.duplicate()
	sorted.sort_custom(func(a: PlayerController, b: PlayerController) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	for i in _lights.size():
		var l := _lights[i]
		l.visible = i < sorted.size()
		if l.visible:
			var e: PlayerController = sorted[i]
			l.global_position = e.global_position + Vector3(0, e.mount_h + 1.1, 0)
			l.light_energy = float(F.light_energy) * (0.8 + 0.2 * sin(_clock * 9.0 + i))


## 테스트용
func spark_count() -> int:
	return _parts.size()


func lit_count() -> int:
	return _lights.filter(func(l: OmniLight3D) -> bool: return l.visible).size()
