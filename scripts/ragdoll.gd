class_name Ragdoll
extends RefCounted
## 죽으면 흐물흐물 쓰러지는 몸 — HTML makeRagdoll·stepRagdoll·poseRagdoll·updateRagdolls.
## 몸의 점 8개(머리·양어깨·골반·양손·양발)를 막대로 이은 Verlet 시뮬레이션이다.
## 캐릭터 모델에서 머리·몸통·팔·다리를 떼어 와서 점 위치에 맞춰 돌려 놓는다.
## 월드 충돌은 world.aabbs 상자 + 땅(y=0)으로 밀어내기만 한다.

const DT := 1.0 / 60.0
const NAMES := ["head", "shL", "shR", "pelvis", "handL", "handR", "footL", "footR"]
const CONS := [["head", "shL"], ["head", "shR"], ["shL", "shR"], ["shL", "pelvis"], ["shR", "pelvis"], ["head", "pelvis"],
	["shL", "handL"], ["shR", "handR"], ["pelvis", "footL"], ["pelvis", "footR"]]

var P := {}            # 이름 → {"p": 지금 위치, "o": 지난 위치}
var cons: Array = []   # [{"a", "b", "len"}]
var root: Node3D       # 떼어 온 몸 조각들의 부모 (지우면 다 사라짐)
var head: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var parts: Array[Node3D] = []
var scales := {}       # 조각 → 원래 크기 (머리는 1.12배)
var mats: Array = []   # 번쩍일 머티리얼
var life: float
var flash: float
var acc := 0.0
var shrink_k := 1.0    # 마지막에 줄어드는 정도
var aabbs: Array = []  # 월드 상자들 (World.aabbs)


## m = 죽은 캐릭터 모델, kind = 맞은 무기, dir = 맞은 방향, vel = 죽을 때 속도, parent = 조각을 붙일 곳
static func make(m: DerpModel, kind: String, dir: Vector3, vel: Vector3, parent: Node3D, world_boxes: Array) -> Ragdoll:
	var R: Dictionary = GameData.RAGDOLL
	var rd := Ragdoll.new()
	rd.life = R.life
	rd.flash = R.flash
	rd.aabbs = world_boxes
	m.visible = true
	for n: String in NAMES:
		var p: Vector3 = (m.mk[n] as Node3D).global_position
		rd.P[n] = {"p": p, "o": p}
	# 처음 속도: 죽을 때 속도 80% + 무기별로 날려보냄. 돌멩이 같은 건 빙글 돌며 쓰러짐
	var base: Vector3 = vel * float(R.vel_keep)
	var center: Vector3 = rd.P.pelvis.p
	var kick: Array = GameData.RAGDOLL_KICK.get(kind, [])
	for n: String in NAMES:
		var v := base
		var q: Dictionary = rd.P[n]
		if kick.size() > 0:
			v += dir * float(kick[0])
			v.y += float(kick[1]) + (float(kick[2]) if n == "head" else 0.0)
		else:
			var r: Vector3 = q.p - center
			v.x += -r.z * 14
			v.z += r.x * 14
			v += dir * 2
			v.y += 1.2
			if n == "head":
				v += dir * 3
				v.y += 1.5
		q.o = (q.p as Vector3) - v * DT
	for c: Array in CONS:
		rd.cons.append({"a": rd.P[c[0]], "b": rd.P[c[1]], "len": (rd.P[c[0]].p as Vector3).distance_to(rd.P[c[1]].p)})
	# 모델에서 몸 조각을 떼어 온다
	rd.root = Node3D.new()
	rd.root.name = "Ragdoll"
	parent.add_child(rd.root)
	rd.mats = m.all_mats()
	rd.head = m.head
	rd.body = m.body
	rd.arm_l = m.arm_l
	rd.arm_r = m.arm_r
	rd.leg_l = m.leg_l
	rd.leg_r = m.leg_r
	for o: Node3D in [rd.head, rd.body, rd.arm_l, rd.arm_r, rd.leg_l, rd.leg_r]:
		rd.scales[o] = o.global_basis.get_scale()
		o.reparent(rd.root, true)
		o.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		rd.parts.append(o)
	rd.pose()
	for o in rd.parts:
		o.reset_physics_interpolation()
	return rd


## 골반 위치 (죽음 카메라가 본다)
func pelvis() -> Vector3:
	return P.pelvis.p


## true를 돌려주면 다 끝나서 지워야 함
func update(dt: float) -> bool:
	acc += dt
	var n := 0
	var max_steps: int = GameData.RAGDOLL.max_steps
	while acc >= DT and n < max_steps:
		step()
		acc -= DT
		n += 1
	if n == max_steps:
		acc = 0.0
	life -= dt
	var shrink: float = GameData.RAGDOLL.shrink
	if life < shrink:
		shrink_k = maxf(0.01, life / shrink)
	pose()
	if flash > 0:
		flash -= dt
		var f := maxf(0.0, flash / float(GameData.RAGDOLL.flash))
		for mt: StandardMaterial3D in mats:
			mt.emission = Color(f, f * 0.85, f * 0.8)
	return life <= 0


func free_nodes() -> void:
	if is_instance_valid(root):
		root.queue_free()


func step() -> void:
	var R: Dictionary = GameData.RAGDOLL
	var damp: float = R.damp
	var g := GameData.GRAV * DT * DT
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for n: String in NAMES:
		var q: Dictionary = P[n]
		var p: Vector3 = q.p
		var v: Vector3 = p - (q.o as Vector3)
		q.o = p
		p += v * damp
		p.y -= g
		q.p = p
		lo = lo.min(p)
		hi = hi.max(p)
	# 이번 걸음에 닿을 수 있는 상자만 추려둔다
	var r: float = R.r
	var box := AABB(lo, hi - lo).grow(r + 0.5)
	var near: Array[AABB] = []
	for a: AABB in aabbs:
		if a.intersects(box):
			near.append(a)
	for it in int(R.iters):
		for c: Dictionary in cons:
			var A: Dictionary = c.a
			var B: Dictionary = c.b
			var d: Vector3 = (B.p as Vector3) - (A.p as Vector3)
			var L := maxf(d.length(), 1e-6)
			var k := (L - float(c.len)) / L * 0.5
			A.p = (A.p as Vector3) + d * k
			B.p = (B.p as Vector3) - d * k
		for n: String in NAMES:
			P[n].p = _collide(P[n].p, near, r)
	var fric: float = R.fric
	for n: String in NAMES:  # 바닥에 닿아 있으면 미끄러지는 속도를 줄인다
		var q: Dictionary = P[n]
		var p: Vector3 = q.p
		var o: Vector3 = q.o
		if p.y < 0.16 or absf(p.y - o.y) < 0.0005:
			q.o = Vector3(p.x - (p.x - o.x) * fric, o.y, p.z - (p.z - o.z) * fric)


## HTML ragCollide: 땅과 상자 밖으로 가장 가까운 면 쪽으로 밀어낸다
static func _collide(p: Vector3, boxes: Array[AABB], r: float) -> Vector3:
	if p.y < r:
		p.y = r
	for c: AABB in boxes:
		var mn := c.position
		var mx := c.end
		if p.x < mn.x - r or p.x > mx.x + r or p.y < mn.y - r or p.y > mx.y + r or p.z < mn.z - r or p.z > mx.z + r:
			continue
		var dx0 := p.x - (mn.x - r)
		var dx1 := (mx.x + r) - p.x
		var dy0 := p.y - (mn.y - r)
		var dy1 := (mx.y + r) - p.y
		var dz0 := p.z - (mn.z - r)
		var dz1 := (mx.z + r) - p.z
		var m := minf(minf(minf(dx0, dx1), minf(dy0, dy1)), minf(dz0, dz1))
		if m == dy1:
			p.y = mx.y + r
		elif m == dx0:
			p.x = mn.x - r
		elif m == dx1:
			p.x = mx.x + r
		elif m == dz0:
			p.z = mn.z - r
		elif m == dz1:
			p.z = mx.z + r
		else:
			p.y = mn.y - r
	return p


static func _ortho_x(x: Vector3, y: Vector3) -> Vector3:
	x -= y * x.dot(y)
	if x.length_squared() < 1e-6:
		x = Vector3(1, 0, 0) - y * y.x
	return x.normalized()


func _place(o: Node3D, x: Vector3, y: Vector3, pos: Vector3) -> void:
	var b := Basis(x, y, x.cross(y)) * Basis.from_scale(scales[o] * shrink_k)
	o.global_transform = Transform3D(b, pos)


## 점 위치에 맞춰 몸 조각을 놓는다 (HTML poseRagdoll)
func pose() -> void:
	var sh_l: Vector3 = P.shL.p
	var sh_r: Vector3 = P.shR.p
	var pel: Vector3 = P.pelvis.p
	var mid := (sh_l + sh_r) * 0.5
	var up := (mid - pel).normalized()
	var x := _ortho_x(sh_l - sh_r, up)
	_place(body, x, up, mid.lerp(pel, 0.48))
	var hy := ((P.head.p as Vector3) - mid).normalized()
	_place(head, _ortho_x(x, hy), hy, P.head.p)
	_limb(arm_l, sh_l, P.handL.p, x)
	_limb(arm_r, sh_r, P.handR.p, x)
	_limb(leg_l, pel + x * 0.18, P.footL.p, x)
	_limb(leg_r, pel - x * 0.18, P.footR.p, x)


func _limb(o: Node3D, from: Vector3, to: Vector3, x: Vector3) -> void:
	var yy := (from - to).normalized()
	_place(o, _ortho_x(x, yy), yy, from)
