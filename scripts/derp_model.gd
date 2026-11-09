class_name DerpModel
extends Node3D
## TABS 느낌의 흐물흐물 캐릭터 — HTML makeModel() + animModel()의 기본 몸체를 옮긴 것.
## 모델은 +Z를 본다 (눈이 +Z 쪽). 그래서 몸통 yaw는 플레이어 yaw + PI.
## 병과별 의상: 야만인 표범 가죽·덥수룩 머리·수염·해골 투구, 궁수 브리간딘·화살통·샐릿,
## 석궁병 서코트·등에 멘 파비스 방패·철모·사슬 목가리개, 성직자 사제복·영대·밧줄 띠·주교 모자.
## mk = 래그돌이 쓰는 몸의 점 8개 (HTML m.mk).

var cls := "archer"
var upper: Node3D
var body: Node3D
var neck: Node3D
var head: Node3D
var helm: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_r: Node3D  # 무기를 붙일 자리
var weapons := {}   # 무기 키 → 손에 든 무기 노드 (든 것만 보임)
var pupils: Array = []  # [{m: MeshInstance3D, r: float}]
var mk := {}            # 래그돌 점: head·shL·shR·pelvis·handL·handR·footL·footR
var part_count := 0     # 합치기 전 메시 수 (테스트용 — 의상이 다 만들어졌는지)
# 음유시인 (4.5단계)
var cheeks: Array[Node3D] = []  # 볼 (연주하면 빵빵해짐 — 합치지 않음)
var _cheek_k := 1.0
var _deflate := 0.0             # 숨이 차서 볼 바람 빠지는 중 (남은 초)
var _deflate_from := 1.0
var _spin := 0.0                # 춤: 한 바퀴 도는 진행도 (0이면 안 돔)
var _spin_wait := 0.0
var voice: Node = null          # 트럼펫 멜로디 (TrumpetVoice, 소리가 켜져 있을 때만)

# 애니메이션 상태 (HTML 엔티티의 wob/nk/eye 필드)
var phase := 0.0
var t := 0.0
var seed_off := randf() * 10.0
var wob := Vector2.ZERO
var wob_v := Vector2.ZERO
var nk := Vector2.ZERO
var nk_v := Vector2.ZERO
var lean_x := 0.0
var prev_vel := Vector2.ZERO
var eye_t := 0.0
var eye := Vector2.ZERO
var eye_target := Vector2.ZERO
var eye_cross := false

# 맞으면 번쩍이려고 모델마다 머티리얼을 따로 가진다 (HTML m.mats). 투구 것은 따로 모아서 떨어질 때 뺀다.
var _mats := {}
var _helm_mats := {}
var _in_helm := false
var _fl := false

var _sph := SphereMesh.new()
var _cyl := CylinderMesh.new()
var _cone := CylinderMesh.new()
var _box := BoxMesh.new()
var _skirt := CylinderMesh.new()  # HTML skirtGeo (위 0.36, 아래 0.5, 높이 0.55)

const STEEL := 0xaab3bd
const STEEL_D := 0x7d858f


func _init(class_key := "archer") -> void:
	cls = class_key
	_sph.radius = 1.0
	_sph.height = 2.0
	_sph.radial_segments = 16
	_sph.rings = 10
	_cyl.top_radius = 1.0
	_cyl.bottom_radius = 1.0
	_cyl.height = 1.0
	_cyl.radial_segments = 12
	_cone.top_radius = 0.0
	_cone.bottom_radius = 1.0
	_cone.height = 1.0
	_cone.radial_segments = 12
	_box.size = Vector3.ONE
	_skirt.top_radius = 0.36
	_skirt.bottom_radius = 0.5
	_skirt.height = 0.55
	_skirt.radial_segments = 18
	_build()
	_merge(self)
	if GameData.CLASSES[cls].weapon == "trumpet" and Sfx.enabled:
		voice = TrumpetVoice.new()
		add_child(voice)


## 최적화(10단계): 같은 관절에 붙은 움직이지 않는 조각들을 메시 하나로 합친다 (캐릭터 하나 70~100번 → 20번 안팎).
## 눈동자(굴러다님)와 무기(바꿔 들고 따로 움직임)는 그대로 둔다. 번쩍임은 합친 재질도 같이 바뀐다.
func _merge(n: Node3D) -> void:
	part_count = _count_meshes(n)
	var skip := {}
	for pp: Dictionary in pupils:
		skip[pp.m] = true
	for c in cheeks:
		skip[c] = true
	for w: Node3D in weapons.values():
		skip[w] = true
	_merge_node(n, skip)


static func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c


func _merge_node(n: Node3D, skip: Dictionary) -> void:
	var groups := {true: [], false: []}
	for c in n.get_children():
		if skip.has(c):
			continue
		if c is MeshInstance3D and c.get_child_count() == 0 and (c as MeshInstance3D).material_override is StandardMaterial3D:
			var mi := c as MeshInstance3D
			groups[mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF].append(mi)
		elif c is Node3D:
			_merge_node(c, skip)
	var in_helm := helm != null and (n == helm or helm.is_ancestor_of(n))
	for shadow: bool in [true, false]:
		var list: Array = groups[shadow]
		if list.size() < 2:
			continue
		var items := []
		for mi: MeshInstance3D in list:
			items.append([mi.mesh, (mi.material_override as StandardMaterial3D).albedo_color, mi.transform])
		var out := MeshInstance3D.new()
		out.mesh = Meshes.merge(items)
		out.material_override = _vc_mat(in_helm)
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(out)
		for mi: MeshInstance3D in list:
			mi.free()


## 합친 조각용 정점 색 재질 (모델마다 하나, 투구는 따로 — 번쩍임용 emission은 _mat과 같게)
func _vc_mat(in_helm: bool) -> StandardMaterial3D:
	var cache := _helm_mats if in_helm else _mats
	if not cache.has("vc"):
		var m := Meshes.vertex_color_mat()
		m.emission_enabled = true
		m.emission = Color.BLACK
		cache["vc"] = m
	return cache["vc"]


func _part(m: Mesh, hex: int, pos: Vector3, scl: Vector3, parent: Node3D, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(hex)
	mi.position = pos
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mat(hex: int) -> StandardMaterial3D:
	var cache := _helm_mats if _in_helm else _mats
	if not cache.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = GameData.col(hex)
		m.roughness = 1.0
		m.metallic_specular = 0.0
		m.emission_enabled = true  # 켜둔 채 검정으로 두고 색만 바꾼다 (켰다 껐다 하면 셰이더를 새로 만든다)
		m.emission = Color.BLACK
		cache[hex] = m
	return cache[hex]


func _set_emission(cache: Dictionary, c: Color) -> void:
	for m: StandardMaterial3D in cache.values():
		m.emission = c


## 번쩍일 머티리얼 전부 (투구가 붙어 있으면 투구 것도) — 래그돌이 가져간다
func all_mats() -> Array:
	var a: Array = _mats.values()
	if helm:
		a.append_array(_helm_mats.values())
	return a


## Three.js 기본 회전 순서(XYZ)로 돌리기 — 두 축 이상 돌린 조각에 쓴다
func _rot(mi: Node3D, r: Vector3) -> Node3D:
	mi.rotation_order = EULER_ORDER_XYZ
	mi.rotation = r
	return mi


## 투구를 몸에서 떼어 돌려준다 (Combat.knock_helmet이 월드로 옮겨 날린다)
func detach_helm() -> Node3D:
	var h := helm
	helm = null
	_set_emission(_helm_mats, Color.BLACK)
	return h


func _group(pos: Vector3, parent: Node3D) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	parent.add_child(g)
	return g


func _build() -> void:
	var K: Dictionary = GameData.CLASSES[cls]
	var skin: int = GameData.C.skin
	upper = _group(Vector3.ZERO, self)
	body = _group(Vector3(0, 0.95, 0), upper)
	_part(_sph, K.color, Vector3.ZERO, Vector3(0.46, 0.52, 0.42), body)
	if cls == "archer" or cls == "crossbow":  # 허리띠 + 금 버클
		_part(_cyl, 0x5b3a22, Vector3(0, -0.2, 0), Vector3(0.435, 0.07, 0.395), body)
		_part(_box, GameData.C.gold, Vector3(0, -0.2, 0.39), Vector3(0.09, 0.07, 0.03), body)
	_build_outfit()
	neck = _group(Vector3(0, 1.3, 0), upper)
	if cls == "cleric":
		_build_robe()
	head = _group(Vector3(0, 0.36, 0), neck)
	head.scale = Vector3.ONE * 1.12
	_part(_sph, skin, Vector3.ZERO, Vector3(0.3, 0.28, 0.29), head)
	# 짝짝이 왕눈
	var eye_r := [randf_range(0.095, 0.11), randf_range(0.068, 0.082)]
	if randf() < 0.5:
		eye_r.reverse()
	for idx in 2:
		var sx := 1.0 if idx == 0 else -1.0
		var er: float = eye_r[idx]
		var eg := _group(Vector3(sx * 0.12, randf_range(-0.025, 0.025) if idx == 1 else 0.0, 0.235), head)
		_part(_sph, 0xffffff, Vector3.ZERO, Vector3.ONE * er, eg, false)
		var pu := _part(_sph, 0x15151b, Vector3(0, 0, er * 0.8), Vector3(er * 0.45, er * 0.45, er * 0.3), eg, false)
		pupils.append({"m": pu, "r": er})
	_part(_sph, 0xe8b28a, Vector3(0, -0.075, 0.29), Vector3(0.06, 0.05, 0.065), head)
	var mouth := _part(_sph, 0x6b2a2a, Vector3(randf_range(-0.03, 0.04), -0.165, 0.245), Vector3(0.08, 0.035, 0.03), head, false)
	mouth.rotation.z = randf_range(-0.3, 0.3)
	var tongue: MeshInstance3D = null
	if randf() < 0.6:  # 혀 빼꼼
		tongue = _part(_sph, 0xe86f86, mouth.position + Vector3(0.015, -0.03, 0.01), Vector3(0.035, 0.045, 0.022), head, false)
	helm = _group(Vector3.ZERO, head)
	_in_helm = true
	_build_helm()
	_in_helm = false
	_build_head_extras(mouth, tongue)
	# 국수 팔
	arm_l = _make_arm(1.0, K)
	arm_r = _make_arm(-1.0, K)
	hand_r = _group(Vector3(0, -0.44, 0), arm_r)
	_build_weapons(K)
	# 다리
	leg_l = _make_leg(1.0, K)
	leg_r = _make_leg(-1.0, K)
	# 래그돌 점 (HTML mkMarker)
	mk = {
		"head": head,
		"shL": _group(Vector3(0.42, 1.25, 0), upper), "shR": _group(Vector3(-0.42, 1.25, 0), upper),
		"pelvis": _group(Vector3(0, 0.6, 0), upper),
		"handL": _group(Vector3(0, -0.44, 0), arm_l), "handR": hand_r,
		"footL": _group(Vector3(0, -0.34, 0), leg_l), "footR": _group(Vector3(0, -0.34, 0), leg_r),
	}


## 갑옷 공통 (궁수·석궁병): 어깨 견갑 + 목가리개 + 사슬 치마 — HTML armorKit
func _armor_kit() -> void:
	for sx in [1, -1]:
		_part(_sph, STEEL, Vector3(sx * 0.37, 0.33, 0), Vector3(0.21, 0.14, 0.22), body)
		_part(_sph, STEEL_D, Vector3(sx * 0.38, 0.23, 0), Vector3(0.18, 0.045, 0.19), body)
	_part(_skirt, STEEL_D, Vector3(0, -0.4, 0), Vector3(1.05, 0.45, 1.05), body)
	_part(_cyl, STEEL, Vector3(0, 0.5, 0), Vector3(0.24, 0.07, 0.22), body)


## 몸통 타원 표면 위의 점 — 방향 d로 나가서 몸통(0.46×0.52×0.42)에 닿는 곳
static func _on_body(d: Vector3) -> Vector3:
	d = d.normalized()
	var t := 1.0 / sqrt(pow(d.x / 0.46, 2) + pow(d.y / 0.52, 2) + pow(d.z / 0.42, 2))
	return d * t


## 병과별 옷 (HTML makeModel 몸통 부분)
func _build_outfit() -> void:
	match cls:
		"barbarian":  # 한쪽 어깨 가죽옷: 표범 반점 + 들쭉날쭉 밑단 + 드러난 어깨
			for sp: Array in [[0.5, 0.3, 0.8, 1], [-0.45, 0.05, 0.9, 1.15], [0.1, -0.35, 1, 0.9], [-0.7, -0.45, 0.55, 0.8], [0.75, -0.4, 0.5, 1],
					[0.3, 0.45, -0.85, 1], [-0.5, 0.1, -0.85, 1.1], [0.35, -0.4, -0.85, 0.9], [1, 0.05, -0.1, 1], [-1, -0.1, 0.1, 0.85], [0.05, 0.15, 1, 0.7]]:
				var n := Vector3(sp[0], sp[1], sp[2]).normalized()
				var sz: float = sp[3]
				var m := _part(_sph, 0x9a3a20, _on_body(n), Vector3(0.085 * sz, 0.07 * sz, 0.025), body)
				var e := Basis(Quaternion(Vector3(0, 0, 1), n)).get_euler(EULER_ORDER_XYZ)
				e.z += randf_range(0, PI)
				_rot(m, e)
			for i in 14:
				var a := i / 14.0 * TAU + randf_range(-0.08, 0.08)
				var cn := _part(_cone, 0xf28a1e, Vector3(sin(a) * 0.37, -0.4, cos(a) * 0.335), Vector3(0.075, randf_range(0.13, 0.2), 0.06), body)
				_rot(cn, Vector3(PI + cos(a) * 0.25, 0, -sin(a) * 0.25))
			_part(_sph, 0xf2c7a0, Vector3(-0.22, 0.34, 0), Vector3(0.22, 0.2, 0.27), body)
			for i in 4:
				var cn := _part(_cone, 0xf28a1e, Vector3(-0.02 - i * 0.07, 0.43 - i * 0.08, 0.3 - i * 0.02), Vector3(0.06, 0.13, 0.05), body)
				_rot(cn, Vector3(0.3, 0, 2.2))
		"archer":  # 등에 화살통 + 붉은 브리간딘(금 리벳)
			var q := _part(_cyl, GameData.C.wood_dark, Vector3(0.12, 0.12, -0.44), Vector3(0.09, 0.56, 0.09), body)
			q.rotation.z = -0.35
			for i in 3:
				var f := _part(_box, 0xffffff if i == 1 else 0xd2463c, Vector3(0.22 + i * 0.03, 0.42, -0.44 + (i - 1) * 0.04), Vector3(0.04, 0.12, 0.02), body)
				f.rotation.z = -0.35
			_armor_kit()
			for d: Array in [[-0.35, 0.35], [0, 0.42], [0.35, 0.35], [-0.42, 0.08], [0, 0.1], [0.42, 0.08], [-0.35, -0.08], [0.35, -0.08]]:
				_part(_sph, 0xf3b33d, _on_body(Vector3(d[0], d[1], 0.85)), Vector3.ONE * 0.028, body)
			_part(_box, 0x8a2620, Vector3(0, 0.05, 0.41), Vector3(0.08, 0.5, 0.03), body)
		"crossbow":  # 남색 서코트(금 테두리·금 십자) + 등에 멘 파비스 방패
			_armor_kit()
			_part(_box, 0x263f78, Vector3(0, -0.04, 0.39), Vector3(0.36, 0.62, 0.06), body)
			for y in [0.26, -0.34]:
				_part(_box, 0xf3b33d, Vector3(0, y, 0.395), Vector3(0.37, 0.035, 0.065), body)
			_part(_box, 0xf3b33d, Vector3(0, -0.02, 0.4), Vector3(0.06, 0.3, 0.07), body)
			_part(_box, 0xf3b33d, Vector3(0, 0.05, 0.4), Vector3(0.2, 0.06, 0.07), body)
			var pv := _group(Vector3(0, 0.02, -0.5), body)
			pv.rotation.x = 0.12
			_part(_box, 0x3a62a8, Vector3.ZERO, Vector3(0.56, 0.82, 0.06), pv)
			for y in [0.41, -0.41]:
				_part(_box, 0xf3b33d, Vector3(0, y, 0), Vector3(0.6, 0.05, 0.07), pv)
			for x in [0.28, -0.28]:
				_part(_box, 0xf3b33d, Vector3(x, 0, 0), Vector3(0.05, 0.82, 0.07), pv)
			var em := _part(_cyl, 0xf3b33d, Vector3(0, 0.05, -0.04), Vector3(0.13, 0.02, 0.13), pv)
			em.rotation.x = PI / 2


## 성직자: 긴 사제복 + 보라 영대 + 밧줄 허리띠 + 금 십자가
func _build_robe() -> void:
	_part(_skirt, 0xeee6d2, Vector3(0, -0.52, 0), Vector3.ONE, body)
	var y := 0.3
	while y >= -0.76:
		var zb := 0.42 * sqrt(1 - pow(y / 0.52, 2)) if absf(y) < 0.52 else 0.0
		var zs := 0.36 + (-0.245 - y) / 0.55 * 0.14 if y < -0.24 else 0.0
		_part(_box, 0x7a52b8, Vector3(0, y, maxf(zb, zs) + 0.01), Vector3(0.13, 0.1, 0.03), body)
		y -= 0.09
	_part(_cyl, 0xc9a06a, Vector3(0, -0.22, 0), Vector3(0.44, 0.05, 0.41), body)
	_part(_cyl, 0xc9a06a, Vector3(0.16, -0.4, 0.41), Vector3(0.025, 0.32, 0.025), body)
	_part(_box, 0xf3b33d, Vector3(0, 0.08, 0.44), Vector3(0.05, 0.22, 0.03), body)
	_part(_box, 0xf3b33d, Vector3(0, 0.13, 0.44), Vector3(0.15, 0.05, 0.03), body)


## 머리 꾸밈 (투구가 아니라 머리에 붙음 — 투구가 날아가도 남는다)
func _build_head_extras(mouth: MeshInstance3D, tongue: MeshInstance3D) -> void:
	match cls:
		"barbarian":  # 덥수룩한 머리 + 큰 수염, 입은 수염 사이로 빨갛게
			var HC := 0x7a4a2c
			var BC := 0x6e4125
			_part(_sph, HC, Vector3(0, 0.16, -0.06), Vector3(0.33, 0.23, 0.33), head)
			_part(_sph, HC, Vector3(0, 0.02, -0.16), Vector3(0.3, 0.26, 0.2), head)
			for t4: Array in [[0.05, 0.36, -0.02, -0.3, -0.4, 0.2], [-0.1, 0.35, 0.04, 0.2, 0.5, 0.17], [0.15, 0.3, -0.15, -0.6, -0.9, 0.16], [-0.17, 0.3, -0.12, -0.5, 0.9, 0.15]]:
				_rot(_part(_cone, HC, Vector3(t4[0], t4[1], t4[2]), Vector3(0.06, t4[5], 0.06), head), Vector3(t4[3], 0, t4[4]))
			for x in [-0.17, -0.06, 0.05, 0.16]:
				_rot(_part(_cone, HC, Vector3(x, 0.13, 0.24), Vector3(0.055, 0.14, 0.04), head), Vector3(PI - 0.5, 0, randf_range(-0.3, 0.3)))
			for sx in [1, -1]:
				_part(_sph, HC, Vector3(sx * 0.27, -0.04, 0.02), Vector3(0.08, 0.17, 0.1), head)
			_part(_sph, BC, Vector3(0, -0.17, 0.16), Vector3(0.28, 0.23, 0.18), head)
			for i in 6:
				var x := -0.2 + i * 0.08
				var bc := _part(_cone, BC, Vector3(x, -0.38 + absf(x) * 0.4, 0.17 - absf(x) * 0.3), Vector3(0.06, randf_range(0.12, 0.2), 0.05), head)
				bc.rotation.x = PI
			mouth.material_override = _mat(0xd94a3a)
			mouth.position = Vector3(0.01, -0.13, 0.335)
			mouth.scale = Vector3(0.085, 0.05, 0.03)
			mouth.rotation.z = randf_range(-0.15, 0.15)
			if tongue:
				tongue.position = Vector3(0.02, -0.15, 0.345)
		"cleric":  # 정수리만 벗겨진 수도사 머리 + 발그레한 볼
			var tm := TorusMesh.new()
			tm.inner_radius = 0.27 - 0.075
			tm.outer_radius = 0.27 + 0.075
			tm.rings = 22
			tm.ring_segments = 8
			_part(tm, 0x7a4a2c, Vector3(0, 0.07, 0), Vector3.ONE, head)
			for sx in [1, -1]:
				_part(_sph, 0xf09a9a, Vector3(sx * 0.18, -0.09, 0.23), Vector3(0.06, 0.04, 0.02), head)
		"crossbow":  # 사슬 목가리개
			_part(_sph, STEEL_D, Vector3(0, -0.15, -0.1), Vector3(0.31, 0.18, 0.29), head)
		"bard":  # 연주하면 빵빵해지는 볼 + 뒤로 넘긴 갈색 머리
			for sx in [1, -1]:
				var ck := _part(_sph, GameData.TRUMPET_LOOK.cheek, Vector3(sx * 0.15, -0.12, 0.2), Vector3(0.075, 0.065, 0.06), head)
				ck.set_meta("base", ck.scale)
				cheeks.append(ck)
			_part(_sph, 0x6e4125, Vector3(0, 0.06, -0.14), Vector3(0.29, 0.22, 0.2), head)


## 오른손에 드는 무기 — HTML makeWeapon(). 병과 무기 + 주울 수 있는 저격총·닭·AK (든 것만 보임)
## 마상창은 말 모양에 붙어 있다 (WeaponModels.make_horse)
func _build_weapons(K: Dictionary) -> void:
	for key: String in [K.weapon, "sniper", "chicken", "ak"]:
		if key == "trumpet":  # 트럼펫은 손이 아니라 입에 붙인다 (고개를 들면 같이 들림)
			var w := _group(Vector3(0, -0.15, 0.27), head)
			WeaponModels.make_trumpet(w, _mat)
			weapons[key] = w
			continue
		var w := _group(Vector3.ZERO, hand_r)
		w.rotation.x = 0.0 if key == "holy" or key == "chicken" else PI / 2
		match key:
			"stone":
				var W: Dictionary = GameData.WEAPONS.stone
				_part(Meshes.stone(), W.color, Vector3.ZERO, Vector3.ONE * float(W.size), w)
			"bow":
				WeaponModels.make_bow(w, _mat)
			"crossbow":
				WeaponModels.make_crossbow(w, _mat)
			"holy":
				WeaponModels.make_holy(w, _mat)
			"sniper":
				WeaponModels.make_sniper(w, _mat)
			"ak":
				WeaponModels.make_ak(w, _mat)
			"chicken":
				var c := WeaponModels.make_chicken(_mat)
				c.g.scale = Vector3.ONE * 0.75
				c.g.position = Vector3(0, 0.05, 0.08)
				w.add_child(c.g)
		weapons[key] = w


func _make_arm(sx: float, K: Dictionary) -> Node3D:
	var g := _group(Vector3(sx * 0.44, 1.22, 0), upper)
	_part(_cyl, K.get("arm", K.color), Vector3(0, -0.2, 0), Vector3(0.085, 0.4, 0.085), g)
	_part(_sph, GameData.C.skin, Vector3(0, -0.44, 0), Vector3.ONE * 0.1, g)
	return g


func _make_leg(sx: float, K: Dictionary) -> Node3D:
	var g := _group(Vector3(sx * 0.18, 0.42, 0), self)
	_part(_cyl, K.leg, Vector3(0, -0.15, 0), Vector3(0.1, 0.3, 0.1), g)
	_part(_sph, K.get("foot", 0x4a3426), Vector3(0, -0.36, 0.08), Vector3(0.14, 0.085, 0.24), g)
	return g


## 간단한 병과별 투구 (헤드샷 맞으면 날아갈 부분 = helm 노드)
func _build_helm() -> void:
	match cls:
		"barbarian":  # 짐승 해골 투구 + 뿔
			_part(_sph, 0xeee3c8, Vector3(0, 0.27, -0.02), Vector3(0.31, 0.2, 0.32), helm)
			for sx in [1, -1]:
				_part(_sph, 0x3a2a1e, Vector3(sx * 0.1, 0.31, 0.27), Vector3(0.06, 0.05, 0.03), helm)
				var hn := _part(_cone, 0xf4ecd6, Vector3(sx * 0.29, 0.36, -0.02), Vector3(0.055, 0.26, 0.055), helm)
				hn.rotation.z = -sx * 1.0
			_part(_box, 0xe2d6b8, Vector3(0, 0.24, 0.3), Vector3(0.14, 0.08, 0.12), helm)
			for i in 5:
				var tt := _part(_cone, 0xffffff, Vector3(-0.12 + i * 0.06, 0.14, 0.29 - absi(i - 2) * 0.02), Vector3(0.022, 0.06, 0.022), helm)
				tt.rotation.x = PI
		"archer":  # 꼬리 샐릿 + 붉은 깃털
			_part(_sph, STEEL, Vector3(0, 0.22, -0.02), Vector3(0.33, 0.24, 0.34), helm)
			var tail := _part(_cone, STEEL, Vector3(0, 0.08, -0.3), Vector3(0.22, 0.34, 0.1), helm)
			tail.rotation.x = -PI / 2 - 0.5
			_part(_box, STEEL_D, Vector3(0, 0.45, -0.04), Vector3(0.04, 0.06, 0.5), helm)
			for n in 3:
				var pl := _part(_sph, 0xf0e6d8 if n == 1 else 0xc8322a, Vector3((n - 1) * 0.05, 0.58, -0.12 - n * 0.02), Vector3(0.05, 0.21, 0.05), helm)
				pl.rotation = Vector3(-0.6 - n * 0.15, 0, (n - 1) * 0.3)
		"crossbow":  # 챙 넓은 철모
			_part(_cyl, 0xb9c0c8, Vector3(0, 0.19, 0), Vector3(0.42, 0.04, 0.42), helm)
			_part(_sph, 0xb9c0c8, Vector3(0, 0.21, 0), Vector3(0.3, 0.19, 0.3), helm)
		"bard":  # 긴 깃털 달린 납작한 베레모 (헤드샷이면 투구처럼 날아감)
			var T: Dictionary = GameData.TRUMPET_LOOK
			_rot(_part(_sph, T.beret, Vector3(0.04, 0.25, -0.03), Vector3(0.36, 0.1, 0.35), helm), Vector3(-0.1, 0, -0.22))
			_part(_sph, T.beret, Vector3(0.04, 0.33, -0.03), Vector3(0.05, 0.04, 0.05), helm)
			_rot(_part(_sph, T.feather, Vector3(-0.2, 0.42, -0.2), Vector3(0.04, 0.34, 0.06), helm), Vector3(-0.85, 0, 0.45))
			_rot(_part(_sph, T.feather_tip, Vector3(-0.32, 0.64, -0.42), Vector3(0.03, 0.12, 0.045), helm), Vector3(-1.1, 0, 0.55))
		"cleric":  # 주교 모자
			var mt := CylinderMesh.new()
			mt.top_radius = 0.12
			mt.bottom_radius = 0.24
			mt.height = 0.46
			_part(mt, 0xf4efe2, Vector3(0, 0.43, 0), Vector3.ONE, helm)
			_part(_cyl, GameData.C.gold, Vector3(0, 0.22, 0), Vector3(0.245, 0.05, 0.245), helm)
			var ms := _part(_box, GameData.C.gold, Vector3(0, 0.43, 0.19), Vector3(0.045, 0.44, 0.02), helm)
			ms.rotation.x = -0.25
			_part(_box, GameData.C.gold, Vector3(0, 0.5, 0.175), Vector3(0.12, 0.035, 0.025), helm)


## HTML animModel() 이식. p는 PlayerController(또는 같은 필드를 가진 엔티티).
func animate(p, dt: float) -> void:
	var fa: float = p.fall_amt()
	t += dt
	var pos: Vector3 = p.get_global_transform_interpolated().origin if p.is_inside_tree() else p.global_position
	global_position = pos + Vector3(0, p.mount_h, 0)
	rotation.y = p.fall_yaw if p.fall_t > 0.0 else p.yaw + PI
	rotation.x = p.fall_rx * fa
	rotation.z = p.fall_rz * fa
	var vel: Vector3 = p.velocity
	var hs := Vector2(vel.x, vel.z).length()
	var k := clampf(hs / 5.0, 0.0, 1.0)
	# 가속·감속하면 몸과 머리가 늦게 따라오며 출렁 (젤리)
	var ry := rotation.y
	var rc := cos(-ry)
	var rs := sin(-ry)
	var dv := Vector2(vel.x, vel.z) - prev_vel
	prev_vel = Vector2(vel.x, vel.z)
	if fa == 0.0 and p.kb_t < 0.4:
		var alx := dv.x * rc + dv.y * rs
		var alz := -dv.x * rs + dv.y * rc
		wob_v += Vector2(clampf(-alz * 1.1, -5, 5), clampf(alx * 1.1, -5, 5))
		nk_v += Vector2(clampf(-alz * 1.7, -8, 8), clampf(alx * 1.7, -8, 8))
	if p.grounded and fa == 0.0:
		var prev := phase
		phase += dt * (hs * 1.9 + 0.4)
		var sp := sin(phase)
		# 뒤뚱뒤뚱 팔자걸음
		leg_l.rotation = Vector3(sp * 0.95 * k, 0, 0.12 + 0.1 * k)
		leg_r.rotation = Vector3(-sp * 0.95 * k, 0, -0.12 - 0.1 * k)
		upper.position = Vector3(cos(phase) * 0.07 * k, absf(sp) * 0.12 * k, 0)
		if k > 0.2 and floori(prev / PI) != floori(phase / PI):
			nk_v += Vector2(randf_range(-1.5, 2) * k, randf_range(-3, 3) * k)
	elif not p.grounded:  # 공중에선 다리 허우적
		leg_l.rotation = Vector3(-0.9 + sin(t * 22) * 0.5, 0, 0.4)
		leg_r.rotation = Vector3(0.5 - sin(t * 22) * 0.5, 0, -0.4)
		upper.position = Vector3(0, 0.05, 0)
	else:
		leg_l.rotation = Vector3(0.5, 0, 0.5)
		leg_r.rotation = Vector3(-0.3, 0, -0.5)
		upper.position = Vector3.ZERO
	wob_v += (-150.0 * wob - 7.0 * wob_v) * dt
	wob = (wob + wob_v * dt).clamp(Vector2(-1, -1), Vector2(1, 1))
	nk_v += (-65.0 * nk - 4.0 * nk_v) * dt
	nk = (nk + nk_v * dt).clamp(Vector2(-0.9, -0.9), Vector2(0.9, 0.9))
	lean_x += ((-0.55 if p.sliding else 0.0) + k * 0.14 - lean_x) * minf(1.0, dt * 12)
	upper.rotation = Vector3(lean_x + wob.x, 0, sin(phase) * 0.2 * k + wob.y)
	neck.rotation = Vector3(nk.x + wob.x * 0.5, 0, nk.y + wob.y * 0.6 - sin(phase) * 0.16 * k)
	head.rotation = Vector3(-p.pitch * 0.6, 0, sin(t * 1.3 + seed_off) * 0.14)
	var bq := sin(phase * 2) * 0.08 * k + sin(t * 2.3 + seed_off) * 0.025
	body.scale = Vector3(1 - bq * 0.6, 1 + bq, 1 - bq * 0.6)
	# 눈동자: 아무 데나 굴러다니고 가끔 사시
	eye_t -= dt
	if eye_t <= 0:
		eye_t = randf_range(0.4, 1.6)
		eye_target = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		if randf() < 0.3:
			eye_cross = not eye_cross
	eye += (eye_target - eye) * minf(1.0, dt * 12)
	for i in pupils.size():
		var pp: Dictionary = pupils[i]
		var sx := 1.0 if i == 0 else -1.0
		var r: float = pp.r
		var jx := clampf(eye.x * 0.5 + (-sx * 0.6 if eye_cross else 0.0) - nk.y * 0.9, -0.8, 0.8)
		var jy := clampf(eye.y * 0.4 + nk.x * 0.9 + (0.7 if fa > 0 else 0.0), -0.8, 0.8)
		(pp.m as MeshInstance3D).position = Vector3(jx * r * 0.55, jy * r * 0.55, r * 0.8)
	# 흐물거리는 국수 팔. 돌멩이·성수는 오른팔을 휘둘러 던지고 왼팔은 걸음에 맞춰 흔든다
	# (활·석궁 반동과 석궁 장전 자세는 4단계 — HTML animModel 후반부 rec/xr)
	var ax: float = -1.3 - p.pitch * 0.9
	var flop := sin(phase + 0.6) * 0.25 * k + wob.x * 0.5
	var wep: String = p.wep
	var thrower := wep == "stone" or wep == "holy"
	var throw_k := 0.0
	if thrower and p.fire_anim > 0:
		throw_k = sin((1.0 - p.fire_anim) * PI)
	arm_r.rotation = Vector3(ax - throw_k * 1.3 + flop * 0.5, 0, 0.22 + sin(t * 3 + seed_off) * 0.06 - wob.y * 0.4)
	if thrower:
		arm_l.rotation = Vector3(-0.25 + sin(phase) * 1.0 * k + wob.x * 0.9, 0, 0.2 + absf(sin(phase)) * 0.5 * k + wob.y * 0.8)
	else:
		arm_l.rotation = Vector3(ax + (0.05 if wep == "bow" else 0.0) + flop * 0.5, 0, -0.3 - wob.y * 0.4)
	# 3인칭 반동: 쏘면 팔이 튕기고 상체가 뒤로 (스프링)
	var sdt := minf(dt, 0.03)
	p.rec_v += (-200.0 * p.rec - 14.0 * p.rec_v) * sdt
	p.rec += p.rec_v * sdt
	if p.rec != 0.0:
		arm_r.rotation.x -= p.rec * 0.55
		arm_l.rotation.x -= p.rec * 0.45
		upper.rotation.x -= p.rec * 0.12
	# 석궁 장전: 석궁을 내리고 왼팔로 시위를 끙끙 당긴다 (처음 12%에 내리고 마지막 10%에 다시 듦)
	if wep == "crossbow" and p.cd > 0:
		var q := WeaponModels.xbow_progress(p.cd)
		var xr := clampf(minf(q / 0.12, (0.95 - q) / 0.1), 0, 1)
		arm_r.rotation.x += xr * 0.9
		arm_l.rotation.x += xr * (0.6 + sin(t * 7) * 0.35)
	if wep == "trumpet" and p.mounted <= 0:  # 두 손으로 트럼펫을 입에 대고, 불면 리듬에 맞춰 까딱
		var tilt: float = -p.pitch * 0.6
		arm_r.rotation = Vector3(-1.95 + tilt - p.rec * 0.4, 0, 0.75)
		arm_l.rotation = Vector3(-1.85 + tilt - p.rec * 0.3, 0, -0.75)
		if p.playing:
			var beat := absf(sin(t * TAU * 2.2))
			upper.position.y += beat * 0.04
			head.rotation.x += beat * 0.08
	_anim_cheeks(p, dt)
	_anim_dance(p, fa, dt)
	if fa > 0:  # 넘어지면 만세 자세
		var up := -2.9 + sin(t * 18) * 0.25
		arm_l.rotation.x += (up - arm_l.rotation.x) * fa
		arm_r.rotation.x += (up - arm_r.rotation.x) * fa
	if p.mounted > 0:  # 말 위 자세: 다리 벌려 걸터앉고, 오른팔은 창, 왼팔은 고삐
		leg_l.rotation = Vector3(-0.5, 0, 0.95)
		leg_r.rotation = Vector3(-0.5, 0, -0.95)
		upper.position = Vector3(0, absf(sin(phase)) * 0.05, 0)
		phase += dt * hs * 1.2
		arm_r.rotation = Vector3(-1.25, 0, 0.35)
		arm_l.rotation = Vector3(-0.9 + sin(t * 9) * 0.15, 0, -0.2)
		upper.rotation.x = 0.15 + wob.x
	for key: String in weapons:
		(weapons[key] as Node3D).visible = key == wep
	p.fire_anim = maxf(0.0, p.fire_anim - dt * (GameData.THROW_ANIM if thrower else GameData.FIRE_ANIM))
	# 맞으면 몸이 찌그러졌다 돌아오고, 하얗게 번쩍
	p.hit_squash = maxf(0.0, p.hit_squash - dt * 5)
	var s: float = p.hit_squash
	upper.scale = Vector3(1 + 0.2 * s, 1 - 0.2 * s, 1 + 0.2 * s)
	if voice:
		voice.call("update", p.playing and p.alive, global_position)
	if p.flash > 0 or _fl:
		p.flash = maxf(0.0, p.flash - dt)
		var f: float = p.flash / 0.14
		var c := Color(f, f * 0.85, f * 0.8)
		_set_emission(_mats, c)
		if helm:
			_set_emission(_helm_mats, c)
		_fl = p.flash > 0


# ── 음유시인·춤 (4.5단계) ────────────────────────────────────
## 연주하면 볼이 빵빵하게 (WEAPONS.trumpet.cheek배)
func _anim_cheeks(p, dt: float) -> void:
	if cheeks.is_empty():
		return
	var want: float = GameData.WEAPONS.trumpet.cheek if p.playing else 1.0
	if _deflate > 0:  # 숨이 차면 바람 빠지듯 쪼그라듦 (BardFx.gasp가 부름)
		var FX: Dictionary = GameData.WEAPONS.trumpet.fx
		_deflate = maxf(0.0, _deflate - dt)
		var k := 1.0 - _deflate / float(FX.deflate_t)
		_cheek_k = lerpf(_deflate_from, float(FX.deflate_to), k) + sin(k * 30.0) * 0.06 * (1.0 - k)
	else:
		_cheek_k += (want - _cheek_k) * minf(1.0, dt * 14)
	for c in cheeks:
		c.scale = (c.get_meta("base") as Vector3) * Vector3(_cheek_k, _cheek_k, _cheek_k * 1.2)


## 춤: 팔 만세 흔들기 + 엉덩이 좌우 + 가끔 한 바퀴. 넘어지면(fa) 넘어짐 자세가 이긴다
## (머리 위 음표·디스코 조명은 BardFx가 그린다)
func _anim_dance(p, fa: float, dt: float) -> void:
	var D: Dictionary = GameData.DANCE
	if p.dance_t > 0 and fa == 0.0 and p.mounted <= 0:
		var w := sin(t * 12)
		arm_l.rotation = Vector3(-2.75 + w * 0.35, 0, -0.35 - w * 0.3)
		arm_r.rotation = Vector3(-2.75 - w * 0.35, 0, 0.35 - w * 0.3)
		var hip := sin(t * 8)
		upper.position.x += hip * 0.09
		upper.rotation.z += hip * 0.22
		leg_l.rotation.z += maxf(0.0, hip) * 0.35
		leg_r.rotation.z -= maxf(0.0, -hip) * 0.35
		_spin_wait -= dt
		if _spin <= 0 and _spin_wait <= 0:
			_spin = 0.0001
			_spin_wait = float(D.spin_every)
	else:
		_spin = 0.0
		_spin_wait = float(D.spin_every) * 0.5
	if _spin > 0:
		_spin += dt / float(D.spin_t)
		if _spin >= 1:
			_spin = 0.0
		else:
			var k := _spin * _spin * (3 - 2 * _spin)
			rotation.y += TAU * k


## 숨이 차면 볼이 바람 빠지듯 쪼그라든다 (BardFx.gasp)
func deflate() -> void:
	if cheeks.is_empty():
		return
	_deflate_from = _cheek_k
	_deflate = float(GameData.WEAPONS.trumpet.fx.deflate_t)

