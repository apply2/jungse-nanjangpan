class_name Meshes
extends RefCounted
## 여러 곳에서 같이 쓰는 기본 도형 (HTML의 G 객체, puffGeo, ringGeo).
## Godot 기본 도형에 없는 것(정십이면체 돌멩이, 납작한 고리)은 여기서 직접 만든다.
## 한 번 만든 메시는 캐시해서 같이 쓴다.

static var _cache := {}


## 반지름 1 정십이면체 — HTML DodecahedronGeometry(1,0). 면마다 법선이 따로라 각진 돌멩이처럼 보인다.
static func stone() -> ArrayMesh:
	if _cache.has("stone"):
		return _cache.stone
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var ip := 1.0 / phi
	var verts: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				verts.append(Vector3(x, y, z))
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			verts.append(Vector3(0, a * ip, b * phi))
			verts.append(Vector3(a * ip, b * phi, 0))
			verts.append(Vector3(a * phi, 0, b * ip))
	for i in verts.size():
		verts[i] = verts[i].normalized()
	# 면 법선 = 정이십면체 꼭짓점 방향. 법선 쪽으로 가장 튀어나온 꼭짓점 5개가 그 면이다.
	var normals: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			normals.append(Vector3(0, a * phi, b).normalized())
			normals.append(Vector3(a, 0, b * phi).normalized())
			normals.append(Vector3(a * phi, b, 0).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in normals:
		var face: Array[Vector3] = verts.duplicate()
		face.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.dot(n) > q.dot(n))
		face.resize(5)
		var c := Vector3.ZERO
		for v in face:
			c += v
		c /= 5.0
		var u := (face[0] - c).normalized()
		var w := n.cross(u)
		face.sort_custom(func(p: Vector3, q: Vector3) -> bool:
			return atan2((p - c).dot(w), (p - c).dot(u)) < atan2((q - c).dot(w), (q - c).dot(u)))
		for k in range(1, 4):  # 부채꼴로 삼각형 3개 (Godot 앞면 = 시계 방향)
			st.set_normal(n)
			st.add_vertex(face[0])
			st.set_normal(n)
			st.add_vertex(face[k + 1])
			st.set_normal(n)
			st.add_vertex(face[k])
	var m := st.commit()
	_cache.stone = m
	return m


## 안쪽 0.62, 바깥 1 고리 (XY 평면, +Z를 봄) — HTML RingGeometry(0.62,1,32)
static func ring() -> ArrayMesh:
	if _cache.has("ring"):
		return _cache.ring
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 32
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var i0 := Vector3(cos(a0), sin(a0), 0) * 0.62
		var o0 := Vector3(cos(a0), sin(a0), 0)
		var i1 := Vector3(cos(a1), sin(a1), 0) * 0.62
		var o1 := Vector3(cos(a1), sin(a1), 0)
		for v in [i0, o1, o0, i0, i1, o1]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	var m := st.commit()
	_cache.ring = m
	return m


## 반지름 1 구 (가로 8, 세로 6 조각) — HTML puffGeo
static func puff() -> SphereMesh:
	if _cache.has("puff"):
		return _cache.puff
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 8
	s.rings = 6
	_cache.puff = s
	return s


## 활대처럼 휜 도넛 조각 — HTML TorusGeometry(R, tube, 6, 24, arc).
## XY 평면에서 +X(각도 0)부터 반시계로 arc만큼 돈다.
static func arc(R: float, tube: float, arc_len: float) -> ArrayMesh:
	var key := "arc_%s_%s_%s" % [R, tube, arc_len]
	if _cache.has(key):
		return _cache[key]
	var radial := 6
	var tubular := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in radial + 1:
		for i in tubular + 1:
			var u := float(i) / tubular * arc_len
			var v := float(j) / radial * TAU
			var c := Vector3(R * cos(u), R * sin(u), 0)
			var p := Vector3((R + tube * cos(v)) * cos(u), (R + tube * cos(v)) * sin(u), tube * sin(v))
			st.set_normal((p - c).normalized())
			st.add_vertex(p)
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a := (tubular + 1) * j + i - 1
			var b := (tubular + 1) * (j - 1) + i - 1
			var c2 := (tubular + 1) * (j - 1) + i
			var d := (tubular + 1) * j + i
			# Three는 반시계(a,b,d)가 앞면, Godot은 시계 방향이 앞면이라 뒤집는다
			for idx in [a, d, b, b, d, c2]:
				st.add_index(idx)
	var m := st.commit()
	_cache[key] = m
	return m


## 반지름 1·높이 1 원기둥 — HTML G.cyl (축 = Y)
static func cyl() -> CylinderMesh:
	if _cache.has("cyl"):
		return _cache.cyl
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 12
	c.rings = 1
	_cache.cyl = c
	return c


## 반지름 1·높이 1 원뿔 (뾰족한 끝 = +Y) — HTML G.cone
static func cone() -> CylinderMesh:
	if _cache.has("cone"):
		return _cache.cone
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 12
	c.rings = 1
	_cache.cone = c
	return c


## 반지름 1 구 — HTML G.sph
static func sph() -> SphereMesh:
	if _cache.has("sph"):
		return _cache.sph
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 10
	_cache.sph = s
	return s


## 바닥에 눕힌 반지름 1 원판 (XZ 평면, 위를 봄) — HTML CircleGeometry(1,40).rotateX(-PI/2)
## 양면으로 그리는 머티리얼과 같이 쓴다.
static func disc() -> ArrayMesh:
	if _cache.has("disc"):
		return _cache.disc
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for v in [Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1), 0, sin(a1))]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var m := st.commit()
	_cache.disc = m
	return m


## 바닥에 눕힌 고리 (안쪽 inner, 바깥 1) — HTML RingGeometry(0.9,1,48).rotateX(-PI/2)
## 저격총·AK 바닥 고리는 RingGeometry(0.9,1.3) = flat_ring(0.9/1.3)을 1.3배로 키워 쓴다.
static func flat_ring(inner := 0.9) -> ArrayMesh:
	var key := "flat_ring_%.3f" % inner
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 48
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var i0 := Vector3(cos(a0), 0, sin(a0)) * inner
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var i1 := Vector3(cos(a1), 0, sin(a1)) * inner
		var o1 := Vector3(cos(a1), 0, sin(a1))
		for v in [i0, o0, o1, i0, o1, i1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var m := st.commit()
	_cache[key] = m
	return m


## 위아래가 뚫린 원기둥 (빛기둥) — HTML CylinderGeometry(r, r, h, 20, 1, true)
static func tube(r: float, h: float) -> CylinderMesh:
	var key := "tube_%.2f_%.1f" % [r, h]
	if _cache.has(key):
		return _cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	_cache[key] = c
	return c


## 1×1×1 상자 — HTML G.box
static func box() -> BoxMesh:
	if _cache.has("box"):
		return _cache.box
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	_cache.box = b
	return b
