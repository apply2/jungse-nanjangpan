extends MeshInstance3D
## 명중 판정 디버그 표시 (Combat 아래 HitDebug 노드, 보기만 함). GameData.debug_hits가 켜졌을 때만 그린다.
## 키: GameData.HIT_DEBUG.key (기본 F9)로 켜고 끔. 기본은 꺼짐.
##   - 히트박스: 모든 캐릭터의 머리 구(HEAD_R)·몸 캡슐(BODY_R). 판정에 쓰는 head_c·body_a·body_b 그대로
##   - 쏜 자리: 판정 시작점 from(하늘색 +) → 투사체가 생긴 자리 pos(초록 +), 조준선이 가리킨 점(분홍 +)
##   - 비행 경로: 매 물리 프레임 판정한 선분(노랑), 사람에 맞은 곳(빨강 +)·벽에 맞은 곳(회색 +)
## 시간은 실제 시간 (히트스톱에 안 느려짐). 남는 시간은 HIT_DEBUG.life초.

var combat
var _im := ImmediateMesh.new()
var _segs: Array = []    # [a, b, 색, 끝나는 ms]
var _marks: Array = []   # [점, 색, 크기, 끝나는 ms]


func _ready() -> void:
	mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true  # 벽 뒤도 보이게
	m.render_priority = 10
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hits"):
		GameData.debug_hits = not GameData.debug_hits
		if not GameData.debug_hits:
			clear()


func clear() -> void:
	_segs.clear()
	_marks.clear()
	_im.clear_surfaces()


func _col(key: String) -> Color:
	return GameData.col(int(GameData.HIT_DEBUG.colors[key]))


func _until() -> int:
	return Time.get_ticks_msec() + int(float(GameData.HIT_DEBUG.life) * 1000.0)


## 쏜 순간: 판정 시작점 → 생긴 자리, 조준점
func spawn(from: Vector3, pos: Vector3, aim: Variant) -> void:
	var u := _until()
	_segs.append([from, pos, _col("from"), u])
	_marks.append([from, _col("from"), 0.06, u])
	_marks.append([pos, _col("spawn"), 0.08, u])
	if aim != null:
		_marks.append([aim, _col("aim"), 0.1, u])


## 한 물리 프레임에 판정한 선분
func seg(a: Vector3, b: Vector3) -> void:
	_segs.append([a, b, _col("path"), _until()])


## 맞은 곳 (사람이면 빨강, 벽·땅이면 회색)
func hit(pt: Vector3, person: bool) -> void:
	_marks.append([pt, _col("hit" if person else "wall"), 0.12, _until()])


func _process(_dt: float) -> void:
	_im.clear_surfaces()
	if not GameData.debug_hits or combat == null:
		return
	var now := Time.get_ticks_msec()
	_segs = _segs.filter(func(s): return s[3] > now)
	_marks = _marks.filter(func(m): return m[3] > now)
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for s in _segs:
		_line(s[0], s[1], s[2])
	for m in _marks:
		_cross(m[0], m[2], m[1])
	for e in combat.ents:
		if not e.alive:
			continue
		_sphere(e.head_c(), GameData.HEAD_R, _col("head"))
		_capsule(e.body_a(), e.body_b(), GameData.BODY_R, _col("body"))
	_im.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_im.surface_set_color(c)
	_im.surface_add_vertex(a)
	_im.surface_set_color(c)
	_im.surface_add_vertex(b)


func _cross(p: Vector3, r: float, c: Color) -> void:
	for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_line(p - ax * r, p + ax * r, c)


## 원: 가운데 c, 반지름 r, 면의 두 축 u·v
func _circle(c: Vector3, r: float, u: Vector3, v: Vector3, col: Color, from := 0.0, to := TAU) -> void:
	var n := 20
	var prev := c + (u * cos(from) + v * sin(from)) * r
	for i in range(1, n + 1):
		var a := lerpf(from, to, float(i) / n)
		var q := c + (u * cos(a) + v * sin(a)) * r
		_line(prev, q, col)
		prev = q


func _sphere(c: Vector3, r: float, col: Color) -> void:
	_circle(c, r, Vector3.RIGHT, Vector3.BACK, col)
	_circle(c, r, Vector3.RIGHT, Vector3.UP, col)
	_circle(c, r, Vector3.BACK, Vector3.UP, col)


## 캡슐: 선분 a-b, 반지름 r (넘어져 누운 몸도 그대로)
func _capsule(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var ax := b - a
	var w := ax.normalized() if ax.length() > 0.001 else Vector3.UP
	var u := w.cross(Vector3.RIGHT if absf(w.x) < 0.9 else Vector3.BACK).normalized()
	var v := w.cross(u)
	_circle(a, r, u, v, col)
	_circle(b, r, u, v, col)
	for k in 4:
		var off := (u * cos(k * PI / 2) + v * sin(k * PI / 2)) * r
		_line(a + off, b + off, col)
	# 양 끝 반구
	_circle(b, r, u, w, col, 0, PI)
	_circle(b, r, v, w, col, 0, PI)
	_circle(a, r, u, -w, col, 0, PI)
	_circle(a, r, v, -w, col, 0, PI)
