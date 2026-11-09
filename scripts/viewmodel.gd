class_name ViewModel
extends TextureRect
## 1인칭 손·무기 화면 — HTML vmScene / vmCam / buildVM() / updateVM() 이식.
## HTML처럼 따로 된 장면(조명 포함)을 시야각 60 카메라로 찍어서 화면 위에 덮는다.
## 그래서 벽에 붙어도 무기가 벽을 뚫고 들어가지 않는다. 1인칭이고 살아 있을 때만 보인다.
## 돌멩이·활·석궁·성수·대물 저격총·AK-47·닭·마상창(말 머리 포함). 스코프를 보면 숨는다.

var player: PlayerController

var _vp: SubViewport
var _root: Node3D
var _star_mat: StandardMaterial3D  # 황금 붕어빵 무적: 손·무기에 덮어씌우는 금색 ↔ 흰색
var _star_geos: Array = []
var _star_on := false
var _vm := {}        # 무기 키 → 노드
var _stone_rock: Node3D
var _bow := {}       # s1, s2, arrow, hand, tz, ty
var _xb := {}        # xs1, xs2, bolt, ptz, ptx, ph, last
var _holy_fl: Node3D # 손에 든 성수병
var _ak_fl: MeshInstance3D  # AK 총구 불꽃
var _ak_ads := 0.0          # AK 정조준 정도 0~1
var _chicken := {}          # 손에 든 닭 모양 {g, hd, wings}
var _horse_head: Node3D     # 마상창 아래 보이는 말 머리
var _tr: Node3D             # 트럼펫 (나팔이 화면 오른쪽 아래에 보임)
const TR_POS := Vector3(0.2, -0.24, -0.34)
var _bob := 0.0
var _sway := Vector2.ZERO  # 마우스를 움직이면 손이 살짝 늦게 따라옴 (HTML swayX/swayY)

const SKIN := 0xf2c7a0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	texture = _vp.get_texture()
	var cam := Camera3D.new()
	cam.fov = GameData.VM_FOV
	cam.near = 0.01
	cam.far = 10.0
	_vp.add_child(cam)
	# HemisphereLight(ffffff / 6d8a55, 0.95) + 해 0.6 — 본 화면과 같은 비율로 근사
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = GameData.col(0xb6c5aa)
	env.ambient_light_energy = 0.58
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = GameData.col(0xfff0d0)
	sun.light_energy = 0.54
	_vp.add_child(sun)
	sun.look_at_from_position(Vector3(1, 2, 1.5), Vector3.ZERO)
	_root = Node3D.new()
	_root.rotation_order = EULER_ORDER_XYZ  # Three 기본 회전 순서
	_vp.add_child(_root)
	_build()


func _part(m: Mesh, hex: int, scl: Vector3, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	return WeaponModels.part(m, GameData.mat(hex), pos, scl, parent)


func _group(key: String, pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.rotation_order = EULER_ORDER_XYZ
	g.position = pos
	g.visible = false
	_root.add_child(g)
	_vm[key] = g
	return g


## HTML buildVM()
func _build() -> void:
	# 돌멩이
	var st := _group("stone", Vector3(0.27, -0.27, -0.58))
	_part(Meshes.sph(), SKIN, Vector3(0.11, 0.09, 0.13), Vector3.ZERO, st)
	_stone_rock = _part(Meshes.stone(), GameData.WEAPONS.stone.color, Vector3.ONE * 0.085, Vector3(0, 0.09, -0.02), st)
	# 활: 왼손이 활 한가운데를 쥐고, 시위는 화면 쪽(+Z)으로 당겨진다
	var bw := _group("bow", Vector3(0.4, -0.17, -0.66))
	bw.rotation = Vector3(0, 0.06, 0.16)
	var R := 0.36
	var A := 1.7
	var limb := WeaponModels.arc_group(R, 0.018, A, GameData.mat(GameData.BOW_WOOD), 0.0, bw)
	limb.rotation.y = PI / 2
	limb.position.z = R
	_part(Meshes.sph(), SKIN, Vector3(0.045, 0.06, 0.045), Vector3.ZERO, bw)
	var s1 := _part(Meshes.cyl(), GameData.BOW_STRING, Vector3.ONE, Vector3.ZERO, bw)
	var s2 := _part(Meshes.cyl(), GameData.BOW_STRING, Vector3.ONE, Vector3.ZERO, bw)
	var arrow := WeaponModels.make_arrow("bow")
	arrow.rotation.y = PI
	bw.add_child(arrow)
	var hand := _part(Meshes.sph(), SKIN, Vector3.ONE * 0.035, Vector3.ZERO, bw)
	_bow = {"s1": s1, "s2": s2, "arrow": arrow, "hand": hand, "tz": R - R * cos(A / 2), "ty": R * sin(A / 2)}
	# 석궁: 개머리를 오른손, 앞쪽을 왼손이 받친다. 활대는 앞(-Z)으로 휘어 있다
	var xb := _group("crossbow", Vector3(0.16, -0.17, -0.4))
	_part(Meshes.box(), GameData.C.wood, Vector3(0.07, 0.08, 0.62), Vector3(0, 0, -0.11), xb)
	var pr := WeaponModels.arc_group(0.26, 0.018, 1.9, GameData.mat(GameData.XBOW_PROD), PI / 2, xb)
	pr.rotation.x = -PI / 2
	pr.position = Vector3(0, 0.03, -0.16)
	var xs1 := _part(Meshes.cyl(), GameData.BOW_STRING, Vector3.ONE, Vector3.ZERO, xb)
	var xs2 := _part(Meshes.cyl(), GameData.BOW_STRING, Vector3.ONE, Vector3.ZERO, xb)
	var bolt := WeaponModels.make_arrow("crossbow")
	bolt.rotation_order = EULER_ORDER_XYZ
	bolt.rotation.y = PI
	bolt.position = Vector3(0, 0.055, -0.44)
	xb.add_child(bolt)
	_part(Meshes.sph(), SKIN, Vector3(0.06, 0.06, 0.07), Vector3(0, -0.06, 0.08), xb)
	_part(Meshes.sph(), SKIN, Vector3(0.06, 0.055, 0.07), Vector3(-0.05, -0.04, -0.3), xb)
	_part(Meshes.box(), GameData.XBOW_NUT, Vector3(0.05, 0.03, 0.05), Vector3(0, 0.05, -0.03), xb)  # 걸쇠(넛)
	var stp := _part(Meshes.arc(0.055, 0.008, TAU), GameData.XBOW_PROD, Vector3.ONE, Vector3(0, -0.01, -0.48), xb)  # 발걸이
	stp.rotation.y = PI / 2
	var ph := _part(Meshes.sph(), SKIN, Vector3(0.05, 0.045, 0.06), Vector3.ZERO, xb)  # 시위 당기는 손 / 볼트 든 손
	ph.visible = false
	# 성수: 오른손에 병을 살짝 기울여 쥠
	var hw := _group("holy", Vector3(0.3, -0.27, -0.62))
	_part(Meshes.sph(), SKIN, Vector3(0.075, 0.07, 0.09), Vector3(0, -0.03, 0.02), hw)
	var flh := Node3D.new()
	flh.rotation_order = EULER_ORDER_XYZ
	flh.scale = Vector3.ONE * 0.62
	flh.position = Vector3(0, 0.05, -0.01)
	flh.rotation.z = 0.25
	hw.add_child(flh)
	WeaponModels.make_holy(flh)
	_holy_fl = flh
	_xb = {"xs1": xs1, "xs2": xs2, "bolt": bolt, "ptz": -0.16 - 0.26 * cos(0.95), "ptx": 0.26 * sin(0.95), "ph": ph, "last": 1.0}
	# 트럼펫 (4.5단계): 입에 댄 금관이 앞으로 뻗고, 나팔 끝이 오른쪽 아래에 보인다
	var tw := _group("trumpet", TR_POS)
	tw.rotation = Vector3(-0.05, -0.1, 0)
	tw.scale = Vector3.ONE * 0.8
	_tr = Node3D.new()
	_tr.rotation.y = PI  # 나팔(+Z)이 화면 안쪽(-Z)으로
	tw.add_child(_tr)
	WeaponModels.make_trumpet(_tr)
	_part(Meshes.sph(), SKIN, Vector3(0.055, 0.05, 0.065), Vector3(-0.01, -0.03, -0.17), tw)
	_part(Meshes.sph(), SKIN, Vector3(0.05, 0.045, 0.06), Vector3(0.02, -0.07, -0.3), tw)
	_build_items()


## 황금 붕어빵 무적이면 1인칭 손·무기도 금색 ↔ 흰색으로 번쩍 (StarFx.flash_color와 같은 박자)
func _star_flash(e: PlayerController) -> void:
	var c := StarFx.flash_color(e.star_t, Time.get_ticks_msec() / 1000.0)
	var on := c.a > 0
	if not on and not _star_on:
		return
	if not _star_mat:
		_star_mat = StandardMaterial3D.new()
		_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_star_geos = _root.find_children("*", "GeometryInstance3D", true, false)
	_star_mat.albedo_color = c
	if on != _star_on:
		for g in _star_geos:
			if is_instance_valid(g):
				g.material_overlay = _star_mat if on else null
	_star_on = on


func _rx(m: Node3D, x: float) -> Node3D:
	m.rotation.x = x
	return m


## HTML buildVM()의 저격총·AK·닭·마상창
func _build_items() -> void:
	# 대물 저격총
	var sn := _group("sniper", Vector3(0.2, -0.2, -0.42))
	_rx(_part(Meshes.cyl(), 0x2c2f35, Vector3(0.028, 1.0, 0.028), Vector3(0, 0.01, -0.62), sn), PI / 2)
	_part(Meshes.box(), 0x3a3e46, Vector3(0.08, 0.11, 0.42), Vector3(0, 0, -0.08), sn)
	_part(Meshes.box(), GameData.C.wood_dark, Vector3(0.07, 0.13, 0.3), Vector3(0, -0.02, 0.24), sn)
	_rx(_part(Meshes.cyl(), 0x15171c, Vector3(0.026, 0.3, 0.026), Vector3(0, 0.085, -0.1), sn), PI / 2)
	_part(Meshes.box(), 0x15171c, Vector3(0.08, 0.06, 0.1), Vector3(0, 0.01, -1.12), sn)
	_part(Meshes.sph(), SKIN, Vector3(0.06, 0.06, 0.07), Vector3(0, -0.07, 0.06), sn)
	_part(Meshes.sph(), SKIN, Vector3(0.06, 0.055, 0.07), Vector3(-0.04, -0.05, -0.36), sn)
	# AK-47
	var ak := _group("ak", Vector3(0.2, -0.2, -0.5))
	ak.scale = Vector3.ONE * 0.72
	_part(Meshes.box(), 0x34373d, Vector3(0.07, 0.1, 0.4), Vector3(0, 0, -0.05), ak)
	_part(Meshes.box(), 0x9a5a2a, Vector3(0.075, 0.08, 0.22), Vector3(0, -0.005, -0.36), ak)
	_rx(_part(Meshes.cyl(), 0x34373d, Vector3(0.02, 0.34, 0.02), Vector3(0, 0.015, -0.62), ak), PI / 2)
	_part(Meshes.box(), 0x34373d, Vector3(0.02, 0.05, 0.02), Vector3(0, 0.055, -0.76), ak)
	_part(Meshes.box(), 0x34373d, Vector3(0.05, 0.025, 0.03), Vector3(0, 0.06, -0.04), ak)
	_part(Meshes.box(), 0x9a5a2a, Vector3(0.06, 0.12, 0.3), Vector3(0, -0.03, 0.3), ak)
	_rx(_part(Meshes.box(), 0x2a2c31, Vector3(0.05, 0.22, 0.08), Vector3(0, -0.14, -0.12), ak), 0.35)
	_part(Meshes.sph(), SKIN, Vector3(0.06, 0.06, 0.07), Vector3(0, -0.08, 0.1), ak)
	_part(Meshes.sph(), SKIN, Vector3(0.06, 0.055, 0.07), Vector3(-0.035, -0.06, -0.36), ak)
	var flm := StandardMaterial3D.new()
	flm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	flm.albedo_color = Color(GameData.col(0xffd27a), 0.0)
	_ak_fl = WeaponModels.part(Meshes.sph(), flm, Vector3(0, 0.015, -0.86), Vector3(0.07, 0.07, 0.12), ak)
	# 닭: 두 손으로 붙잡고 있음
	var ck := _group("chicken", Vector3(0.2, -0.33, -0.72))
	_chicken = WeaponModels.make_chicken()
	var cg: Node3D = _chicken.g
	cg.scale = Vector3.ONE * 0.36
	cg.rotation.y = PI * 0.85
	ck.add_child(cg)
	_part(Meshes.sph(), SKIN, Vector3(0.05, 0.045, 0.055), Vector3(0.09, 0.11, 0.02), ck)
	_part(Meshes.sph(), SKIN, Vector3(0.05, 0.045, 0.055), Vector3(-0.08, 0.11, 0.03), ck)
	# 마상창 + 아래쪽 말 머리
	var ln := _group("lance", Vector3(0.22, -0.22, -0.2))
	for i in 6:
		var r := 0.05 - i * 0.006
		_rx(_part(Meshes.cyl(), 0xf4efe2 if i % 2 else 0xb8322a, Vector3(r, 0.55, r), Vector3(0, 0, -0.2 - i * 0.55), ln), PI / 2)
	_rx(_part(Meshes.cone(), 0xaab3bd, Vector3(0.11, 0.22, 0.11), Vector3(0, 0, -0.95), ln), -PI / 2)
	_rx(_part(Meshes.cone(), 0xaab3bd, Vector3(0.035, 0.3, 0.035), Vector3(0, 0, -3.5), ln), -PI / 2)
	_part(Meshes.sph(), SKIN, Vector3(0.07, 0.065, 0.08), Vector3(0, -0.04, 0.02), ln)
	ln.rotation.y = 0.1
	var hh := Node3D.new()
	hh.position = Vector3(-0.22, -0.62, -1.0)
	ln.add_child(hh)
	_part(Meshes.box(), 0x8a5a32, Vector3(0.3, 0.3, 0.9), Vector3.ZERO, hh)
	_part(Meshes.box(), 0x3e2615, Vector3(0.08, 0.18, 0.8), Vector3(0, 0.2, 0.05), hh)
	for sx in [1, -1]:
		_part(Meshes.cone(), 0x8a5a32, Vector3(0.05, 0.16, 0.035), Vector3(sx * 0.1, 0.22, -0.32), hh)
	_horse_head = hh


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_sway += event.relative


static func ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## HTML updateVM()
func _process(dt: float) -> void:
	var e := player
	visible = e != null and e.alive and not GameData.third_person and not e.is_scoped()
	if not e or not e.alive:
		return
	var win := get_window().size
	if _vp.size != win:
		_vp.size = win
	_star_flash(e)
	var w := e.wep
	for k: String in _vm:
		(_vm[k] as Node3D).visible = k == w
	_ak_ads += ((1.0 if w == "ak" and e.aim_held and e.swap_t <= 0 else 0.0) - _ak_ads) * minf(1.0, dt * 1000.0 / 130.0 * 1.6)
	e.ak_flash = maxf(0.0, e.ak_flash - dt * 14)
	var hs := Vector2(e.velocity.x, e.velocity.z).length()
	var k := clampf(hs / 8.0, 0.0, 1.2) if e.grounded else 0.2
	_bob += dt * hs * 1.4
	_sway += -_sway * minf(1.0, dt * 10)
	e.vm_kick = maxf(0.0, e.vm_kick - dt * (e.vm_kick * 6 + 1))
	var vr := e.v_rec  # 스프링은 player.gd가 돌린다 (카메라도 같이 씀)
	var sw := sin(e.swap_t / 0.45 * PI) * 0.35 if e.swap_t > 0 else 0.0
	var sl := e.sliding
	_root.position = Vector3(
		sin(_bob) * 0.012 * k - _sway.x * 0.0005,
		absf(cos(_bob)) * 0.014 * k + _sway.y * 0.0004 - sw - (0.04 if sl else 0.0) + vr * 0.015,
		e.vm_kick * 0.09 + vr * 0.11)
	_root.rotation = Vector3(e.vm_kick * 0.25 + vr * 0.32, _sway.x * 0.0006,
		(0.18 if sl else 0.0) + sin(_bob) * 0.01 * k + vr * 0.06)
	var vfa := e.fall_amt()  # 넘어지면 손이 아래로 쓰러짐
	_root.position.y -= vfa * 0.35
	_root.rotation.z += vfa * 0.9
	match w:
		"stone":
			var t := e.fire_anim
			var g: Node3D = _vm.stone
			g.position.z = -0.58 - sin(t * PI) * 0.18
			g.position.y = -0.27 + sin(t * PI) * 0.08
			_stone_rock.visible = t < 0.15 or t > 0.85 or e.cd <= 0
		"bow":
			_update_bow(e, vr)
		"crossbow":
			_update_crossbow(e)
		"ak":  # 우클릭하면 가운데로 끌어와 정조준, 쏘면 총구 불꽃
			var A := _ak_ads
			var g: Node3D = _vm.ak
			g.position = Vector3(0.21 * (1 - A), -0.22 + 0.166 * A, -0.5 - 0.14 * A)
			g.rotation = Vector3(0.03 * (1 - A), 0.05 * (1 - A), 0)
			(_ak_fl.material_override as StandardMaterial3D).albedo_color.a = e.ak_flash * 0.95
			_ak_fl.rotation.z = randf() * TAU
		"lance":  # 달리면 창과 말 머리가 출렁
			var sp := Vector2(e.velocity.x, e.velocity.z).length()
			var tt := Time.get_ticks_msec() / 1000.0
			var kk := clampf(sp / 8.0, 0, 1)
			(_vm.lance as Node3D).position.y = -0.22 + absf(sin(tt * 11)) * 0.03 * kk
			_horse_head.position.y = -0.62 + sin(tt * 11) * 0.04 * kk
			_horse_head.rotation.x = sin(tt * 11 + 1) * 0.12 * kk
		"chicken":  # 손에 든 닭이 퍼덕거리며 두리번
			var tt := Time.get_ticks_msec() / 1000.0
			var wings: Array = _chicken.wings
			for kq in 2:
				(wings[kq] as Node3D).rotation.z = (-1.0 if kq else 1.0) * (0.3 + absf(sin(tt * 24)) * 1.0)
			(_chicken.hd as Node3D).rotation.y = sin(tt * 5) * 0.6
			(_vm.chicken as Node3D).position.y = -0.33 + sin(tt * 13) * 0.01
		"trumpet":  # 불면 나팔이 떨리고, 팡파레를 불면 앞으로 튕김. 숨이 차면 아래로 처짐
			var g: Node3D = _vm.trumpet
			var shake := 0.004 if e.playing else 0.0
			var fan := sin(e.fire_anim * PI)
			g.position = TR_POS + Vector3(randf_range(-1, 1) * shake, randf_range(-1, 1) * shake - (0.08 if e.gasp_t > 0 else 0.0), -fan * 0.08)
			_tr.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * 40.0) * 0.02 if e.playing else 0.0
		"holy":  # 던지면 앞으로 뻗고, 빈손이면 아래로 내려 새 병을 꺼냄
			var t := e.fire_anim
			var g: Node3D = _vm.holy
			var empty := e.charges <= 0
			var refill := 1.0 if empty else (clampf(e.cd / 0.4, 0, 1) if e.cd > 0 else 0.0)
			g.position.z = -0.62 - sin(t * PI) * 0.2
			g.position.y = -0.27 + sin(t * PI) * 0.1 - refill * 0.16
			_holy_fl.visible = t > 0.55 or (not empty and (e.cd <= 0 or e.cd < 0.3))
			_holy_fl.rotation.y += dt * 1.2  # HTML은 화면 프레임마다 0.02


func _update_bow(e: PlayerController, vr: float) -> void:
	var u := _bow
	var g: Node3D = _vm.bow
	var tz: float = u.tz
	var ty: float = u.ty
	var pull := e.charge / float(GameData.WEAPONS.bow.full) if e.charging else 0.0
	var ft := (1.0 - e.fire_anim) / 3.0  # 놓은 직후 시위가 부르르 떤다
	var vib := sin(ft * 95) * exp(-ft * 16) * 0.035 if not e.charging and e.fire_anim > 0 else 0.0
	var nz := tz + 0.17 * ease_out(pull) + vib
	WeaponModels.stick(u.s1, Vector3(0, ty, tz), Vector3(0, 0, nz), 0.0045)
	WeaponModels.stick(u.s2, Vector3(0, 0, nz), Vector3(0, -ty, tz), 0.0045)
	var arrow: Node3D = u.arrow
	arrow.visible = e.cd <= 0  # 다음 화살 거는 동안은 빈 활
	arrow.position = Vector3(0, 0, nz - 0.75)
	var hand: Node3D = u.hand
	hand.position = Vector3(0, 0, nz + 0.03)
	hand.visible = e.charging
	g.position.z = -0.66 + pull * 0.03
	g.rotation.z = 0.16 - pull * 0.06 + vr * 0.25
	g.rotation.y = 0.06 - vr * 0.12
	# 오래 버티면 손이 덜덜
	var B: Dictionary = GameData.WEAPONS.bow
	var j := minf(1.0, (e.hold_t - float(B.sway_start)) / 2.0) * 0.014 if e.hold_t > float(B.sway_start) else 0.0
	g.position.x = 0.4 + randf_range(-j, j)
	g.position.y = -0.17 + randf_range(-j, j)


## 석궁 장전 모션 — 진행도 0→1: 세우기 → 시위 당기기(세 번 끊어서) → 걸쇠 → 볼트 끼우기 → 조준 자세.
## 아래로 내리면 화면을 가려서 위로 들리게 바꾼 HTML 버전 그대로.
func _update_crossbow(e: PlayerController) -> void:
	var u := _xb
	var g: Node3D = _vm.crossbow
	var ptz: float = u.ptz
	var ptx: float = u.ptx
	var pr := WeaponModels.xbow_progress(e.cd)
	var seg := func(a: float, b: float) -> float: return clampf((pr - a) / (b - a), 0, 1)
	var low: float = smooth(seg.call(0.05, 0.17)) * (1.0 - smooth(seg.call(0.86, 0.97)))
	var tilt: float = 0.6 * smooth(seg.call(0.05, 0.17)) - 0.35 * smooth(seg.call(0.63, 0.7)) - 0.25 * smooth(seg.call(0.86, 0.97))
	var draw: float = seg.call(0.18, 0.62)
	var jerk := 1.0 if draw >= 1 else (floorf(draw * 3) + smooth(fmod(draw * 3, 1.0))) / 3.0
	var ft := (1.0 - e.fire_anim) / 3.0  # 쏜 직후 시위 떨림
	var xv := sin(ft * 90) * exp(-ft * 14) * 0.04 if e.fire_anim > 0 and pr < 0.1 else 0.0
	var nz := (-0.04 if e.cd <= 0 else ptz + (-0.04 - ptz) * jerk) + xv
	WeaponModels.stick(u.xs1, Vector3(ptx, 0.03, ptz), Vector3(0, 0.03, nz), 0.004)
	WeaponModels.stick(u.xs2, Vector3(0, 0.03, nz), Vector3(-ptx, 0.03, ptz), 0.004)
	g.position = Vector3(0.16 - 0.06 * low, -0.17 - 0.07 * low, -0.4 - 0.03 * low)
	g.rotation = Vector3(tilt - sin(float(seg.call(0.95, 1.0)) * PI) * 0.05, 0.22 * low, 0.22 * low)
	if draw > 0 and draw < 1:  # 힘주느라 덜덜
		var sh := (1.0 - fmod(draw * 3, 1.0)) * 0.007
		g.position.x += randf_range(-sh, sh)
		g.position.y += randf_range(-sh, sh)
	# 볼트: 오른쪽 아래에서 꺼내 홈 뒤쪽에 얹고 앞으로 밀어 넣기
	var bA: float = smooth(seg.call(0.68, 0.76))
	var bB: float = smooth(seg.call(0.76, 0.86))
	var bolt: Node3D = u.bolt
	if e.cd <= 0:
		bolt.visible = true
		bolt.position = Vector3(0, 0.055, -0.44)
		bolt.rotation = Vector3(0, PI, 0)
	elif pr >= 0.68:
		bolt.visible = true
		bolt.position = Vector3(0.3 * (1 - bA), -0.3 + (0.37 - 0.015 * bA) * bA, 0.15 - 0.34 * bA - 0.25 * bB)
		bolt.rotation = Vector3(0.6 * (1 - bA), PI + 0.8 * (1 - bA), 0.3 * (1 - bA))
	else:
		bolt.visible = false
	# 시위 당기는 손 / 볼트 든 손
	var ph: Node3D = u.ph
	if pr < 0.64 and draw > 0 and e.cd > 0:
		ph.visible = true
		ph.position = Vector3(0, 0.04, nz + 0.035)
	elif pr >= 0.68 and pr < 0.88 and e.cd > 0:
		ph.visible = true
		ph.position = bolt.position + Vector3(0, -0.01, 0.46)
	else:
		ph.visible = false
	# 소리: 끙차(세 번) · 톱니 딸깍(9번) · 걸쇠 철컥(0.63) · 볼트 착(0.86). 지난 프레임과 이번 사이에 지나간 순간에 낸다
	var L: float = u.last
	var cross := func(th: float) -> bool: return L < th and pr >= th
	for k in 3:
		if cross.call(0.18 + 0.44 * k / 3.0 + 0.005):
			Sfx.play("strain")
	for k in range(1, 10):
		if cross.call(0.18 + 0.44 * k / 9.0):
			Sfx.play("ratchet")
	if cross.call(0.63):
		Sfx.play("reload")
	if cross.call(0.86):
		Sfx.play("seat")
	u.last = pr
