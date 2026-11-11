extends Node3D
## 셰이더 미리 데우기 (최적화 — 화면 끊김 줄이기).
## Compatibility 렌더러는 어떤 재질을 "처음 그리는 순간" 셰이더를 컴파일하느라 화면이 0.05~0.5초 멈춘다
## (연기·고리·총알 자국·성수 웅덩이·아이템 빛기둥·음표·무적 금빛 … 종류마다 한 번씩).
## 그래서 시작할 때 그 재질들을 눈에 안 보일 만큼 작은 상자에 입혀 카메라 앞에서 한 번씩 그려 둔다.
##   - roots 아래 노드(숨겨 둔 것 포함)가 쓰는 재질 + extra(아직 노드가 없는 효과용 재질)를 모은다. 같은 셰이더가 될 재질은 한 번만.
##   - 재질마다 상자 둘: 하나는 그냥, 하나는 작은 OmniLight 안에 (황금 붕어빵 금빛 같은 점 조명을 받으면 셰이더가 또 따로라서).
##   - 한 프레임에 PER_FRAME개씩만 새로 보여 준다 (한꺼번에 하면 시작할 때 화면이 몇 초 통째로 멈춘다).
## 재질 객체는 원래 것을 그대로 쓰므로(색·설정을 건드리지 않음) 겉모습은 바뀌지 않는다. 헤드리스에선 아무것도 안 한다.
## 쓰는 법: const ShaderWarm := preload("res://scripts/fx/shader_warm.gd") → ShaderWarm.run(부모, [노드…], [재질…])

const PER_FRAME := 2    # 한 프레임에 새로 그리는 재질 수
const DIST := 2.0       # 카메라 앞 거리 (m)
const SIZE := 0.0002    # 상자 한 변 (m) — 화면에서 1픽셀보다 훨씬 작다
const APART := 0.5      # 빛 받는 상자와 안 받는 상자 사이 (m)

static var _done := {}  # 이미 데운 것 (셰이더 서명 + 그리는 방식)

var _shown := 1         # 지금까지 보여 준 자식 수 (0번은 조명)
var _hold := 2          # 다 보여 준 뒤 몇 프레임 더 두었다 지움


static func run(host: Node, roots: Array, extra: Array = []) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var w := new()
	w.name = "ShaderWarm"
	w.process_mode = Node.PROCESS_MODE_ALWAYS
	w.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var light := OmniLight3D.new()
	light.omni_range = APART * 0.2
	light.light_energy = 0.01
	w.add_child(light)
	for r: Node in roots:
		w._scan(r)
	for m: Material in extra:
		w._proxy(m, null, true)
	if w.get_child_count() == 1:
		w.free()
		return
	host.add_child(w)


func _scan(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			_from(mi, mi.mesh, null)
	elif n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm and mm.mesh:
			_from(n as MultiMeshInstance3D, mm.mesh, mm)
	for c in n.get_children():
		_scan(c)


func _from(src: GeometryInstance3D, mesh: Mesh, mm: MultiMesh) -> void:
	var shadow := src.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if src.material_override:
		_proxy(src.material_override, mm, shadow)
	else:
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m:
				_proxy(m, mm, shadow)
	if src.material_overlay:
		_proxy(src.material_overlay, mm, false)


## 같은 셰이더가 될 재질인지 가리는 서명: 셰이더 재질은 셰이더, 기본 재질은 켜고 끄는 설정(bool·고르기 int·텍스처 유무)
static func _sig(m: Material) -> String:
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return "S%d" % (sh.get_instance_id() if sh else 0)
	var s := PackedStringArray([m.get_class()])
	for p: Dictionary in m.get_property_list():
		if p.type == TYPE_BOOL or p.type == TYPE_INT:
			s.append(str(int(m.get(p.name))))
		elif p.type == TYPE_OBJECT:
			s.append("o" if m.get(p.name) != null else "")
	return ",".join(s)


## 재질 mat을 입힌 작은 상자 둘 (빛 받는 것 → 안 받는 것 순서로 자식에 붙임). mm이 있으면 MultiMesh로 그리는 셰이더
func _proxy(mat: Material, mm: MultiMesh, shadow: bool) -> void:
	var key := _sig(mat) + ("|s" if shadow else "|")
	if mm:
		key += "|mm%d%d%d" % [mm.transform_format, int(mm.use_colors), int(mm.use_custom_data)]
	if _done.has(key):
		return
	_done[key] = true
	for x: float in [0.0, APART]:
		var g: GeometryInstance3D
		if mm:
			var m2 := MultiMesh.new()
			m2.transform_format = mm.transform_format
			m2.use_colors = mm.use_colors
			m2.use_custom_data = mm.use_custom_data
			m2.mesh = Meshes.box()
			m2.instance_count = 1
			m2.set_instance_transform(0, Transform3D.IDENTITY)
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = m2
			g = mi
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = Meshes.box()
			g = mi
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.scale = Vector3.ONE * SIZE
		g.position.x = x
		g.visible = false
		add_child(g)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	global_position = cam.global_position - cam.global_basis.z * DIST
	var n := get_child_count()
	if _shown >= n:
		_hold -= 1
		if _hold <= 0:
			queue_free()
		return
	for i in PER_FRAME * 2:
		if _shown < n:
			(get_child(_shown) as Node3D).visible = true
			_shown += 1
