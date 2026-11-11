class_name Fx
extends Node3D
## 맞은 효과 — HTML puff() / ring() / chunks() / updateFx() 이식.
## 효과는 화면 프레임마다 움직이므로 물리 보간을 끈다. 히트스톱(Engine.time_scale) 중엔 같이 느려진다.
## 데미지 숫자는 2D라서 Hud.spawn_num()이 맡는다.

var _fx: Array[Dictionary] = []
## 다 쓴 효과 노드는 지우지 않고 종류별로 모아 두었다가 재질째 다시 쓴다 (최적화).
## 같은 설정의 재질이 하나도 안 남으면 엔진이 그 셰이더를 지우고, 다음 효과가 나올 때 다시 컴파일하느라 화면이 멈춘다.
var _pool := {"tracer": [], "puff": [], "ring": [], "chunk": []}
## 종류마다 재질 하나를 늘 붙들어 둔다 — 시작할 때 이걸로 셰이더를 미리 데운다 (ShaderWarm)
var keep_mats: Array[Material] = [_glow_mat("tracer"), _glow_mat("puff"), _glow_mat("ring")]


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## 쉬는 노드를 꺼내 쓴다 (없으면 새로 만듦). 재질은 노드를 만들 때 한 번만 (chunk는 색마다 같이 쓰는 GameData.mat을 쓸 때 건다)
func _take(type: String, mesh: Mesh, pos: Vector3, scl: float) -> MeshInstance3D:
	var idle: Array = _pool[type]
	var m: MeshInstance3D
	if idle.is_empty():
		m = MeshInstance3D.new()
		m.mesh = mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if type != "chunk":
			m.material_override = _glow_mat(type)
		add_child(m)
	else:
		m = idle.pop_back()
		m.visible = true
	m.transform = Transform3D(Basis.from_scale(Vector3.ONE * scl), pos)
	return m


func _release(f: Dictionary) -> void:
	var m: MeshInstance3D = f.m
	m.visible = false
	(_pool[f.type] as Array).append(m)


## 빛나는 반투명 재질 (노드마다 하나 — 흐려지는 정도가 다 달라서). 색·투명도는 쓸 때 _tint로 정한다
static func _glow_mat(type: String) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if type == "tracer":
		mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	elif type == "ring":
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		mt.disable_fog = true
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mt.billboard_keep_scale = true
		mt.render_priority = 5
	return mt


static func _tint(m: MeshInstance3D, hex: int, opacity: float) -> void:
	(m.material_override as StandardMaterial3D).albedo_color = Color(GameData.col(hex), opacity)


## 총알 자국 빛줄기 a→b (HTML tracer: 저격총 굵기 0.04·0.9초 / akTracer: 0.012·0.1초). 가늘어지며 사라짐
func tracer(a: Vector3, b: Vector3, hex := 0xffe08a, width := 0.04, life := 0.9, opacity := 0.95) -> void:
	var m := _take("tracer", Meshes.cyl(), Vector3.ZERO, 1.0)
	_tint(m, hex, opacity)
	WeaponModels.stick(m, a, b, width)
	_fx.append({"m": m, "life": life, "max": life, "type": "tracer", "tw": width, "op": opacity, "a": a, "b": b})


## 뭉게 연기 n개 (반투명 구가 부풀면서 사라짐)
func puff(pos: Vector3, hex: int, size: float, n: int) -> void:
	for i in n:
		var s := size * randf_range(0.6, 1.1)
		var m := _take("puff", Meshes.puff(), pos, s)
		_tint(m, hex, 0.85)
		var v := Vector3(randf_range(-1, 1), randf_range(0.4, 1.8), randf_range(-1, 1)) * 1.6
		_fx.append({"m": m, "v": v, "life": 0.45, "max": 0.45, "s": s, "type": "puff"})


## 카메라를 보는 고리가 퍼지면서 사라짐
func ring(pos: Vector3, hex: int, size: float, life: float) -> void:
	var m := _take("ring", Meshes.ring(), pos, 0.05)
	_tint(m, hex, 0.9)
	_fx.append({"m": m, "life": life, "max": life, "ring": size, "type": "ring"})


## 네모 조각 n개가 dir 쪽으로 튀고, 빙글빙글 돌다 바닥(y=0)에서 통통 튐
func chunks(pos: Vector3, hex: int, dir: Vector3, n: int, power: float) -> void:
	var mt := GameData.mat(hex)
	for i in n:
		var s := randf_range(0.05, 0.11)
		var m := _take("chunk", Meshes.box(), pos, s)
		m.material_override = mt
		var v := Vector3(randf_range(-1, 1), randf_range(0.4, 1.4), randf_range(-1, 1)) * (power * 0.6) + dir * (power * randf_range(0.3, 0.9))
		var life := randf_range(0.6, 0.95)
		_fx.append({"m": m, "v": v, "life": life, "max": life, "chunk": s, "type": "chunk",
			"spin": Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))})


func _process(dt: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		var f := _fx[i]
		var m: MeshInstance3D = f.m
		f.life -= dt
		var k := maxf(0.0, f.life / f.max)
		match f.type:
			"tracer":
				(m.material_override as StandardMaterial3D).albedo_color.a = k * f.op
				var tw: float = f.tw
				WeaponModels.stick(m, f.a, f.b, tw * k + (0.003 if tw < 0.03 else 0.005))
			"ring":
				var t := 1.0 - k
				m.scale = Vector3.ONE * (0.05 + f.ring * (1.0 - (1.0 - t) * (1.0 - t)))
				(m.material_override as StandardMaterial3D).albedo_color.a = k * 0.9
			"chunk":
				var v: Vector3 = f.v
				var c: float = f.chunk
				v.y -= GameData.GRAV * dt
				m.position += v * dt
				if m.position.y < c:
					m.position.y = c
					v.y *= -0.35
					v.x *= 0.6
					v.z *= 0.6
				f.v = v
				m.rotation.x += f.spin.x * dt
				m.rotation.y += f.spin.y * dt
				m.scale = Vector3.ONE * c * minf(1.0, k * 3)
			_:
				var v: Vector3 = f.v
				m.position += v * dt
				v.y -= 3 * dt
				f.v = v
				m.scale = Vector3.ONE * f.s * (1 + (1 - k) * 1.4)
				(m.material_override as StandardMaterial3D).albedo_color.a = k * 0.85
		if f.life <= 0:
			_release(f)
			_fx.remove_at(i)


## 매치 시작·메뉴로 갈 때 남은 효과를 전부 지운다 (HTML clearMatchObjects)
func clear() -> void:
	for f in _fx:
		_release(f)
	_fx.clear()


func count() -> int:
	return _fx.size()
