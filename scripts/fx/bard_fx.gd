class_name BardFx
extends Node3D
## 음유시인 트럼펫 공격 이펙트 (CLAUDE.md "음유시인 명세 → 공격 이펙트"). 수치는 GameData.WEAPONS.trumpet.fx.
## 보기만 한다 — 판정(원뿔·피해·춤)엔 영향이 없다. 친구대전에서도 네트워크로 보내지 않고,
## 동기화된 "연주 중"·"춤" 상태(playing·dance_t)를 보고 각자 화면에서 만든다.
##
## 그리기 호출을 아끼려고 음표·색종이는 MultiMesh 풀에 모아 한 번에 그린다 (웹이라 GPUParticles 안 씀).
##   _fly  날아가는 음표 (♪ → _mm_one, ♫ → _mm_two). 한 명당 per_bard개, 전체 max개
##   _deco 작은·큰 음표 (틱 음표, 팡파레 음표, 맞고 튕기는 음표) + 매 프레임 상태로 그리는 음표 (춤 게이지·춤·면역) → _mm_deco
##   _bits 색종이 → _mm_bits
##   _objs 드문 것은 노드 하나씩: 음파 고리(풀), 팡파레 원판, 사라지는 디스코 조명, 삑사리 음표, 땀방울
##   디스코 조명은 춤추는 동안 캐릭터별 상태(_st)에 붙어 있다.
## 이벤트 진입점: tick_hit(트럼펫 틱 피해) · fanfare · fanfare_hit · squeak · gasp — Trumpet(trumpet.gd)이 부른다.
## 연주 음표·음파·춤 연출은 _process가 캐릭터 상태를 보고 스스로 만든다.

var combat: Combat
var _fly: Array[Dictionary] = []
var _deco: Array[Dictionary] = []
var _bits: Array[Dictionary] = []
var _objs: Array[Dictionary] = []
var _wave_pool: Array[MeshInstance3D] = []
var _st := {}            # 캐릭터 instance_id → {e, note_t, wave_t, dancing, disco, swap, ci}
var _snotes: Array = []  # 이번 프레임 상태 음표 [Transform3D, Color]
var _mm_one: MultiMeshInstance3D
var _mm_two: MultiMeshInstance3D
var _mm_deco: MultiMeshInstance3D
var _mm_bits: MultiMeshInstance3D
var _t := 0.0

static var _meshes := {}


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	_mm_one = _mm(note_mesh("one"), int(FX.max))
	_mm_two = _mm(note_mesh("two"), int(FX.max))
	_mm_deco = _mm(note_mesh("one"), int(FX.deco_max))
	_mm_bits = _mm(Meshes.box(), int(FX.bits_max))


# ── 모양 ─────────────────────────────────────────────────────
static func _xf(pos: Vector3, scl: Vector3, rz := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0, 0, rz)) * Basis.from_scale(scl), pos)


## 음표 메시 (기본 도형: 구 머리 + 상자 기둥 + 상자 깃발). "one" ♪ · "two" ♫(기둥 둘을 가로대로) · "squeak" 기둥이 꺾인 ♪
## 정점 색은 흰색 — 색은 MultiMesh 인스턴스 색이나 재질 색으로 칠한다.
static func note_mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var W := Color.WHITE
	var s := Meshes.sph()
	var b := Meshes.box()
	var it := []
	match kind:
		"one":
			it.append([s, W, _xf(Vector3(-0.04, -0.12, 0), Vector3(0.075, 0.058, 0.05), 0.45)])
			it.append([b, W, _xf(Vector3(0.026, 0.0, 0), Vector3(0.02, 0.25, 0.02))])
			it.append([b, W, _xf(Vector3(0.062, 0.095, 0), Vector3(0.075, 0.034, 0.02), -0.6)])
		"two":
			for x: float in [-0.1, 0.08]:
				it.append([s, W, _xf(Vector3(x, -0.12, 0), Vector3(0.075, 0.058, 0.05), 0.45)])
				it.append([b, W, _xf(Vector3(x + 0.066, 0.0, 0), Vector3(0.02, 0.25, 0.02))])
			it.append([b, W, _xf(Vector3(0.056, 0.118, 0), Vector3(0.2, 0.038, 0.02), 0.08)])
		"squeak":  # 찌그러진 음표: 머리는 납작, 기둥은 중간에서 꺾이고 깃발은 축 처짐
			it.append([s, W, _xf(Vector3(-0.04, -0.12, 0), Vector3(0.085, 0.045, 0.05), 0.2)])
			it.append([b, W, _xf(Vector3(0.026, -0.06, 0), Vector3(0.02, 0.13, 0.02))])
			it.append([b, W, _xf(Vector3(-0.025, 0.04, 0), Vector3(0.02, 0.13, 0.02), 0.9)])
			it.append([b, W, _xf(Vector3(-0.08, 0.05, 0), Vector3(0.06, 0.03, 0.02), 1.7)])
	var m := Meshes.merge(it)
	_meshes[kind] = m
	return m


## 음표용 재질: 그림자 없음, 무광 unshaded, 정점(인스턴스) 색 + 반투명
static func note_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _flat_mat(hex: int, alpha: float, add := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(GameData.col(hex), alpha)
	return m


func _mm(mesh: Mesh, n: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-400, -60, -400), Vector3(800, 200, 800))  # 매 프레임 범위 다시 계산 안 함
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = note_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _glow(hex: int, a := 1.0) -> Color:
	var g: float = GameData.WEAPONS.trumpet.fx.glow
	var c := GameData.col(hex)
	return Color(c.r * g, c.g * g, c.b * g, a)


func _rand_col(key := "colors") -> int:
	var cols: Array = GameData.WEAPONS.trumpet.fx[key]
	return cols[randi() % cols.size()]


static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-4:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))


static func _ease_back(k: float) -> float:  # 0→1, 살짝 넘쳤다 돌아옴 (톡 튀어나옴)
	var c := 1.70158
	var x := k - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x


# ── 위치 ─────────────────────────────────────────────────────
## 내 화면이 1인칭인 내 캐릭터인가 (그러면 내 몸 둘레 효과는 안 그리고, 음표는 카메라 앞에서 만든다)
func _fp(e: PlayerController) -> bool:
	return e.is_local and e.alive and not combat.tp_on()


func _pos(e: PlayerController) -> Vector3:
	return e.get_global_transform_interpolated().origin


func _head(e: PlayerController) -> Vector3:
	return e.head_c() - e.global_position + _pos(e)


## 나팔 끝 (모델 트럼펫 그룹의 나팔 테두리). 모델이 없으면 눈앞
func bell(e: PlayerController) -> Vector3:
	var m = e.model
	if m and m.is_inside_tree() and (m.weapons as Dictionary).has("trumpet"):
		var w: Node3D = m.weapons.trumpet
		return w.global_transform * Vector3(0, 0, 0.56)
	return e.eye_pos() + e.aim_dir() * 0.7


func _cam_pos(e: PlayerController) -> Vector3:
	return e.cam.global_position if e.cam else e.eye_pos()


## 조준점 둘레 비워 둘 각도 (화면 높이의 fp_clear 반지름)
func _clear_angle(e: PlayerController) -> float:
	var fov := deg_to_rad(e.cam.fov if e.cam else 85.0)
	return atan(2.0 * float(GameData.WEAPONS.trumpet.fx.fp_clear) * tan(fov * 0.5))


# ── 매 프레임 ────────────────────────────────────────────────
func _process(dt: float) -> void:
	if not combat:
		return
	_t += dt
	_snotes.clear()
	for e in combat.ents:
		_update_ent(e, dt)
	_drop_gone()
	_update_fly(dt)
	_update_deco(dt)
	_update_bits(dt)
	_update_objs(dt)


func _update_ent(e: PlayerController, dt: float) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var W: Dictionary = GameData.WEAPONS.trumpet
	var id := e.get_instance_id()
	if not _st.has(id):
		_st[id] = {"e": e, "note_t": 0.0, "wave_t": 0.0, "dancing": false, "disco": null, "swap": 0.0, "ci": 0}
	var s: Dictionary = _st[id]
	# 1·2. 연주 중: 음표 + 음파 고리
	if e.alive and e.playing:
		s.note_t -= dt
		var n := 0
		while s.note_t <= 0 and n < 3:
			s.note_t += float(FX.note_every)
			_spawn_fly(e)
			n += 1
		s.note_t = maxf(s.note_t, -0.2)
		s.wave_t -= dt
		if s.wave_t <= 0:
			s.wave_t += float(W.tick)
			_spawn_wave(e)
	else:
		s.note_t = 0.0
		s.wave_t = 0.0
	# 3. 춤 시작·끝 (dance_t는 친구대전에서도 동기화됨)
	var dancing: bool = e.alive and e.dance_t > 0
	if dancing and not s.dancing:
		_dance_start(e, s)
	elif not dancing and s.dancing:
		_dance_end(s)
	s.dancing = dancing
	if not e.alive:
		return
	var hide := _fp(e)
	if dancing:
		var dm: MeshInstance3D = s.disco
		if dm:
			dm.visible = not hide
			s.swap -= dt
			if s.swap <= 0:
				s.swap = float(FX.disco_swap)
				var cols: Array = FX.disco_cols
				s.ci = (int(s.ci) + 1) % cols.size()
				(dm.material_override as StandardMaterial3D).albedo_color = Color(GameData.col(cols[s.ci]), float(FX.disco_alpha))
			dm.global_transform = Transform3D(Basis(Vector3.UP, _t * 1.5) * Basis.from_scale(
				Vector3(FX.disco_r, FX.disco_top, FX.disco_r)), _pos(e) + Vector3(0, float(FX.disco_top) * 0.5, 0))
		if not hide:
			_orbit(e, int(FX.dance_n), float(FX.dance_r), float(FX.dance_h), float(FX.dance_spin), float(FX.dance_size))
	elif not hide and not e.is_remote:  # 춤 게이지·면역은 판정하는 쪽(내 컴퓨터)만 안다
		if e.dance_immune > 0:
			var h := _head(e) + Vector3(0, 0.6 + sin(_t * 2.0) * 0.04, 0)
			_snotes.append([Transform3D(Basis.from_euler(Vector3(0, _t * 0.8, float(FX.immune_tilt))) * Basis.from_scale(Vector3.ONE * float(FX.immune_size)), h),
				_glow(FX.immune_col, 0.85)])
		else:
			var lv := Trumpet.heard_sum(e) / float(GameData.DANCE.need)
			if lv > 0.001:
				_orbit(e, clampi(ceili(lv * 3.0 - 0.001), 1, 3), float(FX.gauge_r), float(FX.gauge_h), float(FX.gauge_spin), float(FX.gauge_size))


## 머리 둘레를 도는 음표 n개 (춤 게이지·춤)
func _orbit(e: PlayerController, n: int, r: float, h: float, spin: float, size: float) -> void:
	var cols: Array = GameData.WEAPONS.trumpet.fx.colors
	var c := _head(e)
	for i in n:
		var a := _t * spin + i * TAU / 3.0
		var p := c + Vector3(cos(a) * r, h + sin(_t * 4.0 + i) * 0.05, sin(a) * r)
		_snotes.append([Transform3D(Basis.from_euler(Vector3(0, -a + PI / 2, sin(_t * 6.0 + i) * 0.25)) * Basis.from_scale(Vector3.ONE * size), p),
			_glow(cols[i % cols.size()])])


## 지워진 캐릭터(나간 친구)의 상태 정리
func _drop_gone() -> void:
	for id in _st.keys():
		var s: Dictionary = _st[id]
		var e = s.e
		if not is_instance_valid(e) or not combat.ents.has(e):
			if s.disco:
				(s.disco as Node).queue_free()
			_st.erase(id)


# ── 1. 날아가는 음표 ─────────────────────────────────────────
func _spawn_fly(e: PlayerController) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var W: Dictionary = GameData.WEAPONS.trumpet
	var fp := _fp(e)
	var aim := e.aim_dir()
	var half := deg_to_rad(float(W.half_angle))
	var r0 := aim.cross(Vector3.UP)
	r0 = r0.normalized() if r0.length_squared() > 1e-4 else Vector3.RIGHT
	var u0 := r0.cross(aim).normalized()
	var th := half * sqrt(randf())  # 원뿔 안에 고르게 퍼뜨림 → 음표가 퍼지는 모양 = 공격 범위
	if fp:  # 조준점 둘레는 비켜 감
		th = clampf(maxf(th, _clear_angle(e) + 0.06), 0.0, half)
	var ph := randf() * TAU
	var radial := r0 * cos(ph) + u0 * sin(ph)
	var d := (aim * cos(th) + radial * sin(th)).normalized()
	var side: Vector3
	if fp:  # 1인칭: 원 둘레 방향으로만 꿀렁 (가운데로 안 들어옴)
		side = d.cross(radial).normalized()
	else:
		side = d.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 1e-4 else Vector3.RIGHT
	var o := _cam_pos(e) + d * float(FX.fp_start) if fp else bell(e)
	var rng := float(W.range)
	var t := combat.world_ray(o, d * rng)
	var id := e.get_instance_id()
	var own := 0
	var first := -1
	for i in _fly.size():
		if _fly[i].who == id:
			own += 1
			if first < 0:
				first = i
	if own >= int(FX.per_bard):
		_fly.remove_at(first)
	elif _fly.size() >= int(FX.max):
		_fly.remove_at(0)
	_fly.append({"who": id, "o": o, "d": d, "side": side, "s": 0.0, "maxs": rng * minf(t, 1.0), "wall": t < 1.0,
		"age": 0.0, "two": randf() < float(FX.double), "col": _glow(_rand_col(), float(FX.fp_alpha) if fp else 1.0),
		"ph": randf() * TAU, "spin": randf_range(-1.0, 1.0) * float(FX.spin), "bounce": -1.0, "pos": o, "v": Vector3.ZERO})


func _fly_pos(f: Dictionary) -> Vector3:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var s: float = f.s
	var wob := sin(float(f.ph) + float(f.age) * TAU * float(FX.wobble_hz)) * float(FX.wobble) * minf(1.0, s / 2.0)
	return (f.o as Vector3) + (f.d as Vector3) * s + (f.side as Vector3) * wob


func _update_fly(dt: float) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var rng := float(GameData.WEAPONS.trumpet.range)
	var ff := float(FX.fade_from)
	var mm1 := _mm_one.multimesh
	var mm2 := _mm_two.multimesh
	var n1 := 0
	var n2 := 0
	for i in range(_fly.size() - 1, -1, -1):
		var f := _fly[i]
		f.age += dt
		var sc := float(FX.size)
		var col: Color = f.col
		var pos: Vector3
		if f.bounce >= 0:  # 벽에 맞고 작게 튕김
			f.bounce += dt
			var k := 1.0 - float(f.bounce) / float(FX.bounce_t)
			if k <= 0:
				_fly.remove_at(i)
				continue
			var v: Vector3 = f.v
			v.y -= GameData.GRAV * dt
			f.v = v
			f.pos += v * dt
			pos = f.pos
			sc *= k
		else:
			f.s += float(FX.speed) * dt
			if f.s >= f.maxs:
				if not f.wall:  # 사거리 끝 (이미 흐려져 있음)
					_fly.remove_at(i)
					continue
				f.s = f.maxs
				f.bounce = 0.0
				f.pos = _fly_pos(f) - (f.d as Vector3) * 0.08
				f.v = -(f.d as Vector3) * float(FX.bounce_v) + Vector3.UP * float(FX.bounce_v) * 0.6
			pos = _fly_pos(f)
			if f.s > ff * rng:
				col.a *= clampf(1.0 - (float(f.s) - ff * rng) / ((1.0 - ff) * rng), 0.0, 1.0)
			if f.age < FX.pop_t:
				sc *= maxf(0.0, _ease_back(float(f.age) / float(FX.pop_t)))
		var xf := Transform3D(Basis.from_euler(Vector3(0, float(f.ph) + float(f.age) * float(f.spin), sin(float(f.age) * 6.0 + float(f.ph)) * 0.3)) * Basis.from_scale(Vector3.ONE * sc), pos)
		if f.two:
			mm2.set_instance_transform(n2, xf)
			mm2.set_instance_color(n2, col)
			n2 += 1
		else:
			mm1.set_instance_transform(n1, xf)
			mm1.set_instance_color(n1, col)
			n1 += 1
	mm1.visible_instance_count = n1
	mm2.visible_instance_count = n2


# ── 2. 음파 고리 (판정 주기마다) ─────────────────────────────
func _spawn_wave(e: PlayerController) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var fp := _fp(e)
	var aim := e.aim_dir()
	var m: MeshInstance3D
	if _wave_pool.is_empty():
		m = _node(Meshes.flat_ring(float(FX.wave_inner)), _flat_mat(FX.wave_col, 0.0, true))
	else:
		m = _wave_pool.pop_back()
		m.visible = true
	var o := _cam_pos(e) + aim * float(FX.fp_start) if fp else bell(e)
	var life := float(FX.wave_life)
	_objs.append({"type": "wave", "m": m, "o": o, "d": aim, "life": life, "max": life,
		"a": float(FX.wave_alpha) * (float(FX.fp_alpha) if fp else 1.0)})
	if combat.mp():  # 친구 캐릭터는 그쪽 컴퓨터가 판정 → 내 화면엔 보이는 것만 (틱 음표)
		var W: Dictionary = GameData.WEAPONS.trumpet
		for v in combat.ents:
			if v.is_remote and v != e and v.alive and Trumpet.reaches(combat, e, v, W.range, W.half_angle):
				tick_hit(v)


# ── 3. 맞은 적 ───────────────────────────────────────────────
## 트럼펫 틱 피해를 받음: 머리 위로 작은 음표가 톡 (피해 숫자는 Combat.impact_fx가 dot으로 띄움)
func tick_hit(v: PlayerController) -> void:
	if _fp(v):
		return
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	_add_deco(_head(v) + Vector3(randf_range(-0.15, 0.15), 0.35, randf_range(-0.15, 0.15)), Vector3(0, FX.pop_up, 0), 0.0,
		float(FX.pop_life), float(FX.pop_size), _glow(_rand_col()))


func _dance_start(e: PlayerController, s: Dictionary) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var dm := _node(Meshes.cone(), _flat_mat(FX.disco_cols[0], float(FX.disco_alpha), true))
	s.disco = dm
	s.swap = float(FX.disco_swap)
	s.ci = 0
	if _fp(e):  # 내가 1인칭으로 춤에 걸림: 화면 테두리 효과는 HUD가 (내 머리 둘레는 안 그림)
		dm.visible = false
		return
	var h := _head(e)
	confetti(h + Vector3(0, 0.3, 0), int(FX.confetti), 4.5)
	combat.num.emit(h + Vector3(0, 0.2, 0), String(FX.dance_text), "dance")


func _dance_end(s: Dictionary) -> void:
	var dm: MeshInstance3D = s.disco
	s.disco = null
	if not dm:
		return
	var life := float(GameData.WEAPONS.trumpet.fx.disco_out)
	_objs.append({"type": "disco", "m": dm, "life": life, "max": life, "xf": dm.global_transform})


# ── 4. 팡파레 ────────────────────────────────────────────────
func fanfare(e: PlayerController) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var fp := _fp(e)
	var aim := e.aim_dir()
	var flat := Vector3(aim.x, 0, aim.z)
	flat = flat.normalized() if flat.length_squared() > 1e-4 else Vector3(0, 0, -1)
	var o := _cam_pos(e) + aim * 0.8 if fp else bell(e)
	# 납작한 원판 충격파: 발밑 땅 위에 깔려 퍼짐 (눈높이면 옆에서 볼 때 선으로만 보여서)
	var c := _pos(e) + flat * 0.6
	c.y = combat.ground_below(c + Vector3(0, 1.0, 0)) + 0.06
	var disc := _node(Meshes.disc(), _flat_mat(FX.wave_col, float(FX.fan_alpha), true))
	var rim := _node(Meshes.flat_ring(0.85), _flat_mat(0xf3b33d, 0.9, true))
	var life := float(FX.fan_t)
	_objs.append({"type": "fan", "m": disc, "m2": rim, "c": c, "life": life, "max": life})
	# 큰 음표가 부채꼴로
	var half := deg_to_rad(float(GameData.WEAPONS.fanfare.half_angle))
	var n := int(FX.fan_notes)
	for i in n:
		var a := lerpf(-half, half, (i + 0.5) / n) + randf_range(-0.08, 0.08)
		var d := (flat.rotated(Vector3.UP, a) + Vector3.UP * randf_range(0.1, 0.45)).normalized()
		_add_deco(o, d * float(FX.fan_note_speed) * randf_range(0.8, 1.1), 4.0, 0.55, float(FX.fan_note_size),
			_glow(_rand_col(), float(FX.fp_alpha) if fp else 1.0))
	confetti(o, int(FX.fan_confetti), 5.0)
	combat.fx.puff(_pos(e) + flat * 1.0 + Vector3(0, 0.1, 0), int(FX.fan_dust), 0.3, 6)
	if e.is_local and fp:
		e.shake = maxf(e.shake, float(FX.fan_shake))


## 팡파레에 맞은 적: 몸에서 큰 음표 하나가 튕겨 나옴 (넉백 효과는 Combat.impact_fx 그대로)
func fanfare_hit(v: PlayerController, dir: Vector3) -> void:
	if _fp(v):
		return
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	_add_deco(_pos(v) + Vector3(0, 1.1, 0), dir * 4.5 + Vector3.UP * 4.0, GameData.GRAV, 0.8, float(FX.fan_hit_size), _glow(_rand_col()))


# ── 5. 삑사리 ────────────────────────────────────────────────
func squeak(e: PlayerController) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var fp := _fp(e)
	var aim := e.aim_dir()
	var o := _cam_pos(e) + aim * 0.9 - Vector3(0, 0.12, 0) if fp else bell(e)
	var mt := note_mat()
	mt.albedo_color = GameData.col(FX.squeak_col)
	var m := _node(note_mesh("squeak"), mt)
	m.global_position = o
	var life := float(FX.squeak_life)
	_objs.append({"type": "squeak", "m": m, "v": aim * 1.0 + Vector3.UP * 0.9, "life": life, "max": life, "ry": randf() * TAU})
	combat.fx.puff(o, 0x9a9a9a, 0.08, 3)
	combat.num.emit(o, String(FX.squeak_text), "squeak")


# ── 6. 숨 참 ─────────────────────────────────────────────────
func gasp(e: PlayerController) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	if e.model:
		e.model.deflate()
	if _fp(e):
		return
	var h := _head(e)
	var aim := e.aim_dir()
	var flat := Vector3(aim.x, 0, aim.z).normalized()
	var right := flat.cross(Vector3.UP)
	for i in int(FX.sweat):
		var sx := (i - (int(FX.sweat) - 1) * 0.5)
		var m := _node(Meshes.sph(), _flat_mat(FX.sweat_col, 0.9))
		m.global_position = h + right * sx * 0.18 + Vector3(0, 0.18, 0)
		_objs.append({"type": "drop", "m": m, "v": right * sx * 1.6 + Vector3(0, 2.6, 0) - flat * 0.5,
			"life": 0.55, "max": 0.55})
	combat.fx.puff(h + flat * 0.3 - Vector3(0, 0.12, 0), int(FX.steam_col), 0.1, 4)


# ── 풀: 작은 음표 (_deco) ────────────────────────────────────
func _add_deco(pos: Vector3, v: Vector3, g: float, life: float, size: float, col: Color) -> void:
	if _deco.size() >= int(GameData.WEAPONS.trumpet.fx.deco_max):
		_deco.remove_at(0)
	_deco.append({"pos": pos, "v": v, "g": g, "life": life, "max": life, "size": size, "col": col,
		"ry": randf() * TAU, "spin": randf_range(-6.0, 6.0)})


func _update_deco(dt: float) -> void:
	var mm := _mm_deco.multimesh
	var cap := mm.instance_count
	var n := 0
	for i in range(_deco.size() - 1, -1, -1):
		var d := _deco[i]
		d.life -= dt
		if d.life <= 0:
			_deco.remove_at(i)
			continue
		var v: Vector3 = d.v
		v.y -= float(d.g) * dt
		d.v = v
		d.pos += v * dt
		var age := float(d.max) - float(d.life)
		var k := float(d.life) / float(d.max)
		var sc := float(d.size) * (maxf(0.0, _ease_back(age / 0.08)) if age < 0.08 else 1.0)
		var col: Color = d.col
		col.a *= minf(1.0, k / 0.4)
		if n < cap:
			mm.set_instance_transform(n, Transform3D(Basis.from_euler(Vector3(0, float(d.ry) + age * float(d.spin), 0)) * Basis.from_scale(Vector3.ONE * sc), d.pos))
			mm.set_instance_color(n, col)
			n += 1
	for sn: Array in _snotes:
		if n >= cap:
			break
		mm.set_instance_transform(n, sn[0])
		mm.set_instance_color(n, sn[1])
		n += 1
	mm.visible_instance_count = n


# ── 풀: 색종이 (_bits) ───────────────────────────────────────
func confetti(pos: Vector3, n: int, power: float) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var floor_y := combat.ground_below(pos) if combat else 0.0
	for i in n:
		if _bits.size() >= int(FX.bits_max):
			_bits.remove_at(0)
		var life := randf_range(0.9, 1.3)
		_bits.append({"pos": pos, "v": Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)) * power,
			"life": life, "max": life, "rot": Vector3(randf() * TAU, randf() * TAU, 0),
			"spin": Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)),
			"col": _glow(_rand_col("confetti_cols")), "size": randf_range(0.06, 0.1), "floor": floor_y})


func _update_bits(dt: float) -> void:
	var mm := _mm_bits.multimesh
	var n := 0
	for i in range(_bits.size() - 1, -1, -1):
		var b := _bits[i]
		b.life -= dt
		if b.life <= 0:
			_bits.remove_at(i)
			continue
		var v: Vector3 = b.v
		v.y -= GameData.GRAV * 0.55 * dt  # 종이라 천천히 떨어짐
		v *= 1.0 - minf(1.0, dt * 1.8)
		var p: Vector3 = b.pos + v * dt
		if p.y < float(b.floor) + 0.02:
			p.y = float(b.floor) + 0.02
			v = Vector3.ZERO
		b.v = v
		b.pos = p
		if v != Vector3.ZERO:
			b.rot += (b.spin as Vector3) * dt
		var s: float = b.size
		var col: Color = b.col
		col.a = minf(1.0, float(b.life) / 0.3)
		mm.set_instance_transform(n, Transform3D(Basis.from_euler(b.rot) * Basis.from_scale(Vector3(s, s * 0.15, s * 0.7)), p))
		mm.set_instance_color(n, col)
		n += 1
	mm.visible_instance_count = n


# ── 드문 것: 노드 하나씩 ─────────────────────────────────────
func _update_objs(dt: float) -> void:
	var FX: Dictionary = GameData.WEAPONS.trumpet.fx
	var rng := float(GameData.WEAPONS.trumpet.range)
	var tan_h := tan(deg_to_rad(float(GameData.WEAPONS.trumpet.half_angle)))
	for i in range(_objs.size() - 1, -1, -1):
		var o := _objs[i]
		o.life -= dt
		var m: MeshInstance3D = o.m
		var t := clampf(1.0 - float(o.life) / float(o.max), 0.0, 1.0)
		if o.life <= 0:
			if o.type == "wave":  # 음파 고리는 다시 씀
				m.visible = false
				_wave_pool.append(m)
			else:
				m.queue_free()
				if o.has("m2"):
					(o.m2 as Node).queue_free()
			_objs.remove_at(i)
			continue
		match o.type:
			"wave":  # 조준 방향으로 퍼져 나가며 원뿔 폭만큼 커짐 (12m 지점 반지름 = 12·tan25° ≈ 5.6m)
				var e := 1.0 - (1.0 - t) * (1.0 - t)
				var s := rng * e
				var r := maxf(0.12, s * tan_h)
				m.global_transform = Transform3D(_basis_y(o.d) * Basis.from_scale(Vector3(r, 1, r)), (o.o as Vector3) + (o.d as Vector3) * s)
				(m.material_override as StandardMaterial3D).albedo_color.a = float(o.a) * (1.0 - t)
			"fan":
				var r := maxf(0.05, float(FX.fan_r) * (1.0 - (1.0 - t) * (1.0 - t)))
				var xf := Transform3D(Basis.from_scale(Vector3(r, 1, r)), o.c)
				m.global_transform = xf
				(o.m2 as MeshInstance3D).global_transform = xf
				(m.material_override as StandardMaterial3D).albedo_color.a = float(FX.fan_alpha) * (1.0 - t)
				((o.m2 as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - t)
			"disco":  # 춤이 끝나면 조명이 위로 빨려 올라감
				var xf: Transform3D = o.xf
				var k := t * t
				m.global_transform = Transform3D(xf.basis * Basis.from_scale(Vector3(1.0 - k, 1.0 - k * 0.7, 1.0 - k)), xf.origin + Vector3(0, k * 3.0, 0))
				(m.material_override as StandardMaterial3D).albedo_color.a = float(FX.disco_alpha) * (1.0 - t)
			"squeak":  # 비틀거리며 떨어짐
				var v: Vector3 = o.v
				v.y -= 5.0 * dt
				o.v = v
				m.global_position += v * dt
				m.rotation = Vector3(0, float(o.ry), sin(t * 14.0) * 0.5 * (1.0 - t * 0.5))
				m.scale = Vector3.ONE * 1.2
				(m.material_override as StandardMaterial3D).albedo_color.a = minf(1.0, (1.0 - t) / 0.3)
			"drop":
				var v: Vector3 = o.v
				v.y -= GameData.GRAV * dt
				o.v = v
				m.global_position += v * dt
				m.scale = Vector3(0.045, 0.065, 0.045) * minf(1.0, (1.0 - t) / 0.3)


# ── 정리·확인 ────────────────────────────────────────────────
## 매치 시작·메뉴로 갈 때 전부 지운다 (Combat.clear_match_objects)
func clear() -> void:
	for o in _objs:
		if o.type == "wave":
			(o.m as MeshInstance3D).visible = false
			_wave_pool.append(o.m)
		else:
			(o.m as Node).queue_free()
			if o.has("m2"):
				(o.m2 as Node).queue_free()
	_objs.clear()
	for s: Dictionary in _st.values():
		if s.disco:
			(s.disco as Node).queue_free()
	_st.clear()
	_fly.clear()
	_deco.clear()
	_bits.clear()
	for mi in [_mm_one, _mm_two, _mm_deco, _mm_bits]:
		(mi as MultiMeshInstance3D).multimesh.visible_instance_count = 0


func fly_count(e: PlayerController = null) -> int:
	if e == null:
		return _fly.size()
	var id := e.get_instance_id()
	return _fly.filter(func(f: Dictionary) -> bool: return f.who == id).size()


## 지금 살아 있는 효과 수 {fly, deco, bits, objs, discos, nodes(풀 노드 제외 자식 수)}
func counts() -> Dictionary:
	var discos := 0
	for s: Dictionary in _st.values():
		if s.disco:
			discos += 1
	return {"fly": _fly.size(), "deco": _deco.size(), "bits": _bits.size(), "objs": _objs.size(), "discos": discos,
		"nodes": get_child_count() - 4 - _wave_pool.size(), "drawn": _mm_one.multimesh.visible_instance_count + _mm_two.multimesh.visible_instance_count}
