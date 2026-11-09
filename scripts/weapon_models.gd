class_name WeaponModels
extends RefCounted
## 무기·화살 모양 — HTML makeArrow() / makeWeapon() / arcMesh() / stick().
## 캐릭터 손(DerpModel), 1인칭 화면(ViewModel), 날아가는 화살(Combat)이 같이 쓴다.
## mat: 색(0xRRGGBB) → 머티리얼. 캐릭터는 맞으면 번쩍이려고 자기 머티리얼을 넘긴다.


static func _default_mat(hex: int) -> Material:
	return GameData.mat(hex)


static func part(m: Mesh, mat: Material, pos: Vector3, scl: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


## 원기둥 m을 a→b 사이에 굵기 r로 걸친다 (활시위) — HTML stick()
static func stick(m: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 1e-4:
		L = 1e-4
		d = Vector3.UP * L
	var dn := d / L
	var q := Quaternion(Vector3.UP, dn) if dn.dot(Vector3.UP) > -0.9999 else Quaternion(Vector3.RIGHT, PI)
	m.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(r, L, r)), (a + b) * 0.5)


## 활대 — HTML arcMesh(R, tube, arc, color, center). 가운데가 center 각도(0 = +X)를 향한다.
static func arc_group(R: float, tube: float, arc: float, mat: Material, center: float, parent: Node3D) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var mi := part(Meshes.arc(R, tube, arc), mat, Vector3.ZERO, Vector3.ONE, g)
	mi.rotation.z = center - arc / 2.0
	return g


## 화살(bow)·석궁 볼트(crossbow). 촉이 원점, +Z를 향한다 — HTML makeArrow()
static func make_arrow(kind: String, mat: Callable = _default_mat) -> Node3D:
	var A: Dictionary = GameData.ARROWS[kind]
	var length: float = A.len
	var r: float = A.r
	var tr: float = A.tip
	var g := Node3D.new()
	var sh := part(Meshes.cyl(), mat.call(A.shaft), Vector3(0, 0, -length / 2.0), Vector3(r, length, r), g)
	sh.rotation.x = PI / 2
	var tip := part(Meshes.cone(), mat.call(GameData.ARROW_TIP), Vector3(0, 0, -0.05), Vector3(tr, 0.1, tr), g)
	tip.rotation.x = PI / 2
	for i in 2:
		var f := part(Meshes.box(), mat.call(A.fletch), Vector3(0, 0, -length + 0.09), Vector3(0.006, 0.07, 0.14), g)
		f.rotation.z = i * PI / 2
	return g


## 3인칭 캐릭터 손에 든 활 — HTML makeWeapon('bow')
static func make_bow(parent: Node3D, mat: Callable = _default_mat) -> void:
	var R := 0.42
	var A := 1.7
	var a := arc_group(R, 0.022, A, mat.call(GameData.BOW_WOOD), 0.0, parent)
	a.rotation.y = -PI / 2
	a.position.z = -R + 0.05
	var tz := -R + 0.05 + R * cos(A / 2)
	var ty := R * sin(A / 2)
	var s := part(Meshes.cyl(), mat.call(GameData.BOW_STRING), Vector3.ZERO, Vector3.ONE, parent)
	stick(s, Vector3(0, ty, tz), Vector3(0, -ty, tz), 0.006)


## 3인칭 캐릭터 손에 든 석궁 — HTML makeWeapon('crossbow'). 개머리가 손, 활대가 앞(+Z)
static func make_crossbow(parent: Node3D, mat: Callable = _default_mat) -> void:
	part(Meshes.box(), mat.call(GameData.C.wood), Vector3(0, 0, 0.05), Vector3(0.07, 0.08, 0.62), parent)
	var p := arc_group(0.28, 0.02, 1.9, mat.call(GameData.XBOW_PROD), PI / 2, parent)
	p.rotation.x = PI / 2
	p.position = Vector3(0, 0.03, 0.08)


static var _glass: StandardMaterial3D


## 성수병 유리 (반투명 하늘색, 은은하게 빛남)
static func glass_mat() -> StandardMaterial3D:
	if _glass == null:
		var H: Dictionary = GameData.HOLY
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(GameData.col(H.glass), H.glass_alpha)
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.roughness = 1.0
		_glass.metallic_specular = 0.0
		_glass.emission_enabled = true
		_glass.emission = GameData.col(H.glass_emit)
	return _glass


## 성수병: 둥근 몸통 + 목 + 코르크 + 앞면 금 십자가. 바닥이 원점 근처, 위가 +Y — HTML makeWeapon('holy')
static func make_holy(parent: Node3D, mat: Callable = _default_mat) -> Node3D:
	var H: Dictionary = GameData.HOLY
	var g := Node3D.new()
	parent.add_child(g)
	part(Meshes.sph(), glass_mat(), Vector3.ZERO, Vector3(0.09, 0.1, 0.09), g)
	part(Meshes.cyl(), glass_mat(), Vector3(0, 0.11, 0), Vector3(0.032, 0.08, 0.032), g)
	part(Meshes.cyl(), mat.call(H.cork), Vector3(0, 0.165, 0), Vector3(0.036, 0.045, 0.036), g)
	part(Meshes.box(), mat.call(H.cross), Vector3(0, 0, 0.09), Vector3(0.018, 0.075, 0.012), g)
	part(Meshes.box(), mat.call(H.cross), Vector3(0, 0.014, 0.09), Vector3(0.052, 0.018, 0.012), g)
	return g


## 석궁 장전 진행도 0(막 쏨)→1(장전 끝) — HTML의 1-e.cd/WEAPONS.crossbow.cd
static func xbow_progress(cd: float) -> float:
	return clampf(1.0 - cd / float(GameData.WEAPONS.crossbow.cd), 0, 1) if cd > 0 else 1.0


## +Z가 dir을 향하는 회전 — HTML quaternion.setFromUnitVectors(Z, dir)
static func face(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if d.dot(Vector3.BACK) < -0.9999:
		return Basis(Vector3.UP, PI)
	return Basis(Quaternion(Vector3.BACK, d))


# ── 7단계 특수 아이템 모양 ───────────────────────────────────
static func _rx(m: Node3D, x: float) -> Node3D:
	m.rotation.x = x
	return m


## 대물 저격총 (총구 = +Z) — HTML makeWeapon('sniper')
static func make_sniper(parent: Node3D, mat: Callable = _default_mat) -> void:
	_rx(part(Meshes.cyl(), mat.call(0x2c2f35), Vector3(0, 0, 0.45), Vector3(0.03, 1.1, 0.03), parent), PI / 2)
	part(Meshes.box(), mat.call(0x3a3e46), Vector3(0, 0, -0.05), Vector3(0.08, 0.12, 0.42), parent)
	part(Meshes.box(), mat.call(GameData.C.wood_dark), Vector3(0, -0.02, -0.4), Vector3(0.07, 0.14, 0.32), parent)
	_rx(part(Meshes.cyl(), mat.call(0x15171c), Vector3(0, 0.1, 0.02), Vector3(0.04, 0.32, 0.04), parent), PI / 2)
	part(Meshes.box(), mat.call(0x15171c), Vector3(0, 0, 1.0), Vector3(0.08, 0.06, 0.1), parent)


## AK-47 (총구 = +Z) — HTML makeWeapon('ak')
static func make_ak(parent: Node3D, mat: Callable = _default_mat) -> void:
	var M: Material = mat.call(0x34373d)
	var Wd: Material = mat.call(0x9a5a2a)
	part(Meshes.box(), M, Vector3.ZERO, Vector3(0.07, 0.1, 0.42), parent)
	part(Meshes.box(), Wd, Vector3(0, -0.005, 0.3), Vector3(0.075, 0.08, 0.22), parent)
	_rx(part(Meshes.cyl(), M, Vector3(0, 0.015, 0.55), Vector3(0.022, 0.36, 0.022), parent), PI / 2)
	part(Meshes.box(), M, Vector3(0, 0.05, 0.68), Vector3(0.02, 0.06, 0.02), parent)
	part(Meshes.box(), Wd, Vector3(0, -0.03, -0.34), Vector3(0.06, 0.12, 0.3), parent)
	_rx(part(Meshes.box(), mat.call(0x2a2c31), Vector3(0, -0.14, 0.1), Vector3(0.05, 0.22, 0.08), parent), -0.35)
	part(Meshes.box(), Wd, Vector3(0, -0.09, -0.12), Vector3(0.05, 0.11, 0.06), parent)


## 닭 (+Z를 봄, 발이 원점) — HTML makeChicken(). {g, hd, wings}
static func make_chicken(mat: Callable = _default_mat) -> Dictionary:
	var g := Node3D.new()
	var W: Material = mat.call(0xfafaf2)
	part(Meshes.sph(), W, Vector3(0, 0.32, 0), Vector3(0.2, 0.19, 0.27), g)
	var hd := Node3D.new()
	hd.position = Vector3(0, 0.52, 0.2)
	g.add_child(hd)
	part(Meshes.sph(), W, Vector3.ZERO, Vector3(0.11, 0.12, 0.11), hd)
	for i in 3:  # 볏
		part(Meshes.sph(), mat.call(0xe0302a), Vector3(0, 0.11 + (0.02 if i == 1 else 0.0), -0.04 + i * 0.04), Vector3(0.035, 0.05, 0.035), hd)
	_rx(part(Meshes.cone(), mat.call(0xf2b632), Vector3(0, -0.01, 0.13), Vector3(0.035, 0.09, 0.03), hd), PI / 2)  # 부리
	part(Meshes.sph(), mat.call(0xe0302a), Vector3(0, -0.07, 0.1), Vector3(0.025, 0.045, 0.02), hd)  # 턱볏
	for sx in [1, -1]:
		part(Meshes.sph(), mat.call(0x111111), Vector3(sx * 0.08, 0.03, 0.07), Vector3(0.022, 0.022, 0.012), hd)
	var wings: Array[Node3D] = []
	for sx in [1, -1]:
		var wg := Node3D.new()
		wg.position = Vector3(sx * 0.18, 0.38, 0)
		g.add_child(wg)
		part(Meshes.sph(), mat.call(0xeeeee2), Vector3(sx * 0.02, -0.08, 0), Vector3(0.04, 0.13, 0.18), wg)
		wings.append(wg)
	for i in 3:  # 꽁지
		_rx(part(Meshes.sph(), mat.call(0x333333 if i == 1 else 0xfafaf2), Vector3((i - 1) * 0.06, 0.45, -0.25), Vector3(0.04, 0.13, 0.04), g), -0.7)
	for sx in [1, -1]:
		part(Meshes.cyl(), mat.call(0xf2b632), Vector3(sx * 0.07, 0.08, 0.02), Vector3(0.018, 0.16, 0.018), g)
	return {"g": g, "hd": hd, "wings": wings}


## 기사의 말 (+Z를 봄). with_lance면 등에 마상창 — HTML makeHorse(). {g, body, hd, tail, legs, lance, phase}
static func make_horse(with_lance: bool) -> Dictionary:
	var B := GameData.mat(0x8a5a32)
	var D := GameData.mat(0x3e2615)
	var Wt := GameData.mat(0xf4efe2)
	var g := Node3D.new()
	var body := Node3D.new()
	g.add_child(body)
	part(Meshes.sph(), B, Vector3(0, 1.05, 0), Vector3(0.42, 0.42, 0.95), body)
	var nk := part(Meshes.cyl(), B, Vector3.ZERO, Vector3.ONE, body)
	stick(nk, Vector3(0, 1.2, 0.65), Vector3(0, 1.85, 1.0), 0.2)
	_rx(part(Meshes.box(), D, Vector3(0, 1.62, 0.75), Vector3(0.08, 0.75, 0.14), body), 0.5)  # 갈기
	var hd := Node3D.new()
	hd.position = Vector3(0, 1.9, 1.12)
	hd.rotation.x = 0.55
	body.add_child(hd)
	part(Meshes.box(), B, Vector3(0, 0, 0.12), Vector3(0.26, 0.28, 0.55), hd)
	part(Meshes.box(), Wt, Vector3(0, 0.145, 0.15), Vector3(0.08, 0.02, 0.4), hd)
	for sx in [1, -1]:
		part(Meshes.sph(), GameData.mat(0x2a1a10), Vector3(sx * 0.07, -0.05, 0.4), Vector3(0.05, 0.04, 0.02), hd)  # 콧구멍
		var ear := part(Meshes.cone(), B, Vector3(sx * 0.09, 0.2, -0.08), Vector3(0.045, 0.14, 0.03), hd)
		ear.rotation.z = -sx * 0.2
		var ew := part(Meshes.sph(), GameData.mat(0xffffff), Vector3(sx * 0.14, 0.06, 0.05), Vector3.ONE * 0.065, hd)
		ew.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ep := part(Meshes.sph(), GameData.mat(0x111111), Vector3(sx * 0.19, 0.06 + randf_range(-0.02, 0.02), 0.08), Vector3.ONE * 0.03, hd)
		ep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tail := _rx(part(Meshes.cone(), D, Vector3(0, 1.0, -1.05), Vector3(0.09, 0.6, 0.09), body), -2.5)
	part(Meshes.box(), GameData.mat(0xb8322a), Vector3(0, 1.45, -0.05), Vector3(0.62, 0.1, 0.6), body)  # 안장
	part(Meshes.box(), GameData.mat(0xf3b33d), Vector3(0, 1.4, -0.05), Vector3(0.64, 0.03, 0.62), body)
	for sx in [1, -1]:
		part(Meshes.box(), GameData.mat(0xb8322a), Vector3(sx * 0.42, 1.05, -0.05), Vector3(0.03, 0.45, 0.75), body)
	var legs: Array[Node3D] = []
	for xz in [Vector2(0.22, 0.55), Vector2(-0.22, 0.55), Vector2(0.22, -0.55), Vector2(-0.22, -0.55)]:
		var lg := Node3D.new()
		lg.position = Vector3(xz.x, 0.85, xz.y)
		g.add_child(lg)
		part(Meshes.cyl(), B, Vector3(0, -0.4, 0), Vector3(0.075, 0.8, 0.075), lg)
		part(Meshes.cyl(), D, Vector3(0, -0.8, 0), Vector3(0.09, 0.1, 0.09), lg)
		legs.append(lg)
	var lance: Node3D = null
	if with_lance:
		lance = Node3D.new()
		lance.rotation_order = EULER_ORDER_XYZ
		lance.position = Vector3(-0.42, 1.95, 0.1)
		g.add_child(lance)
		for i in 6:  # 빨강·흰색 줄무늬 창대
			var r := 0.045 - i * 0.005
			_rx(part(Meshes.cyl(), GameData.mat(0xf4efe2 if i % 2 else 0xb8322a), Vector3(0, 0, 0.25 + i * 0.5), Vector3(r, 0.5, r), lance), PI / 2)
		_rx(part(Meshes.cone(), GameData.mat(0xaab3bd), Vector3(0, 0, 3.15), Vector3(0.03, 0.3, 0.03), lance), PI / 2)
		_rx(part(Meshes.cone(), GameData.mat(0xaab3bd), Vector3(0, 0, 0.35), Vector3(0.16, 0.3, 0.16), lance), PI / 2)  # 손잡이 덮개
		lance.rotation = Vector3(0.14, 0.12, 0)
	return {"g": g, "body": body, "hd": hd, "tail": tail, "legs": legs, "lance": lance, "phase": 0.0}


## 말 걸음 — HTML animHorse(h, sp, dt). sp = 수평 속도
static func anim_horse(h: Dictionary, sp: float, dt: float) -> void:
	var k := clampf(sp / 6.0, 0, 1)
	h.phase += dt * (4 + sp * 1.3)
	var ph: float = h.phase
	var off := [0.0, 0.6, PI, PI + 0.6]
	var legs: Array = h.legs
	for i in 4:
		(legs[i] as Node3D).rotation.x = sin(ph + off[i]) * 0.9 * k + sin(ph * 0.5 + i) * 0.05 * (1 - k)
	var body: Node3D = h.body
	body.position.y = absf(sin(ph)) * 0.12 * k
	body.rotation.x = sin(ph) * 0.05 * k
	(h.hd as Node3D).rotation.x = 0.55 + sin(ph + 1) * 0.15 * k + sin(ph * 0.3) * 0.1 * (1 - k)
	(h.tail as Node3D).rotation.x = -2.5 + sin(ph * 1.3) * 0.3
	if h.lance:
		(h.lance as Node3D).rotation.x = 0.14 + sin(ph) * 0.03 * k


## 닭 날개 퍼덕·머리 까딱 (돌아다니는 닭, 손에 든 닭) — HTML updateChickens 일부
static func anim_chicken(c: Dictionary, t: float, flap: float, fast: bool, hs: float, idle: bool) -> void:
	var wings: Array = c.wings
	for k in 2:
		(wings[k] as Node3D).rotation.z = (-1.0 if k else 1.0) * (0.2 + absf(sin(t * (30.0 if fast else 8.0))) * 1.1 * flap)
	var hd: Node3D = c.hd
	hd.position.z = 0.2 + sin(t * (14.0 if hs > 0.3 else 3.0)) * 0.04
	hd.rotation.x = maxf(0.0, sin(t * 2.3)) * 0.5 * (1.0 if idle else 0.3)
