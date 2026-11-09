class_name Items
extends Node3D
## 특수 아이템 — HTML updateChickens / grabChicken / spawnChicken, 기사의 말(buildHorseItem / spawnHorse /
## mount / dismount / lanceCheck / updateHorses), 대물 저격총(buildSniperItem / spawnSniper / dropSniper /
## pickup / updateSniper), AK-47(buildAKItem / spawnAK / dropAK / pickupAK / updateAK) 이식.
## Combat 아래에 있고, Combat이 매 물리 프레임 update_*()를 부른다. 수치는 GameData.ITEM.

signal banner(t: String, s: String)  # 남이 줍거나 아이템이 나타남 (Main이 경기 중일 때만 띄움)

var combat: Combat

var chickens: Array[Dictionary] = []  # {body, c(모양), heading, turn_t, no_pick, t, flee}
var chicken_timer := 3.0
var sniper := {"active": false, "pos": Vector3.ZERO, "life": 0.0, "t": 0.0, "ammo": 5, "seq": 0}
var ak := {"active": false, "pos": Vector3.ZERO, "life": 0.0, "t": 0.0, "ammo": 25, "seq": 0}
var horse := {"active": false, "pos": Vector3.ZERO, "life": 0.0, "t": 0.0, "seq": 0}  # seq: 놓을 때마다 +1 (친구대전 줍기 허락용)
var runaways: Array[Dictionary] = []  # 시간이 끝나 달아나는 말 {h, dir, life}
var sniper_timer := 0.0
var ak_timer := 0.0
var horse_timer := 30.0


func _ready() -> void:
	_build_gun_item(sniper, "sniper", 1.3, 0xffcf5a, 0xffd56b)
	_build_gun_item(ak, "ak", 1.7, 0xff7a45, 0xff9a6a)
	var g := Node3D.new()
	add_child(g)
	var h := WeaponModels.make_horse(true)
	g.add_child(h.g)
	horse.model = h
	horse.group = g
	horse.pillar = _pillar(g, 1.2, 0xff8a3d, 0.22)
	g.visible = false


## 빛기둥: 반지름 r, 높이 60, 더해지는(밝아지는) 반투명 — 안개 영향 없음
func _pillar(parent: Node3D, r: float, hex: int, alpha: float) -> MeshInstance3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.disable_fog = true
	mt.albedo_color = Color(GameData.col(hex), alpha)
	var m := MeshInstance3D.new()
	m.mesh = Meshes.tube(r, 60.0)
	m.material_override = mt
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = 30
	parent.add_child(m)
	return m


## 저격총·AK 자리: 빙글 도는 총 + 빛기둥 + 바닥 고리 — HTML buildSniperItem / buildAKItem
func _build_gun_item(it: Dictionary, key: String, scl: float, pillar_hex: int, ring_hex: int) -> void:
	var g := Node3D.new()
	add_child(g)
	var holder := Node3D.new()
	holder.position.y = 1
	g.add_child(holder)
	var gun := Node3D.new()
	gun.scale = Vector3.ONE * scl
	gun.rotation.z = 0.2
	holder.add_child(gun)
	if key == "sniper":
		WeaponModels.make_sniper(gun)
	else:
		WeaponModels.make_ak(gun)
	it.pillar = _pillar(g, 0.7, pillar_hex, 0.28)
	var rmt := StandardMaterial3D.new()
	rmt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmt.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	rmt.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmt.albedo_color = Color(GameData.col(ring_hex), 0.75)
	var ring := MeshInstance3D.new()
	ring.mesh = Meshes.flat_ring(0.9 / 1.3)  # RingGeometry(0.9, 1.3)
	ring.material_override = rmt
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.04
	g.add_child(ring)
	it.ring = ring
	it.holder = holder
	it.group = g
	g.visible = false


static func rr(a: Array) -> float:
	return randf_range(float(a[0]), float(a[1]))


## 새 경기·메뉴 구경 — HTML clearMatchObjects의 아이템 부분 (닭 두 마리를 미리 풀어 둠)
func clear() -> void:
	var I: Dictionary = GameData.ITEM
	for c in chickens:
		(c.body as Node).queue_free()
	chickens.clear()
	chicken_timer = I.chicken_first
	if not combat.mp():  # 친구대전엔 닭이 없다
		for p: Vector3 in I.chicken_spots:
			spawn_chicken(p)
	horse.active = false
	(horse.group as Node3D).visible = false
	horse_timer = rr(I.horse_first)
	for r in runaways:
		(r.h.g as Node).queue_free()
	runaways.clear()
	sniper.active = false
	(sniper.group as Node3D).visible = false
	sniper_timer = rr(I.sniper_first)
	ak.active = false
	(ak.group as Node3D).visible = false
	ak_timer = rr(I.ak_first)


# ── 대물 저격총 / AK-47 ──────────────────────────────────────
func _place(it: Dictionary, pos: Vector3, life: float) -> void:
	it.seq = int(it.get("seq", 0)) + 1
	it.active = true
	it.pos = pos
	it.life = life
	var g: Node3D = it.group
	g.global_position = pos
	g.visible = true
	g.reset_physics_interpolation()


func spawn_sniper() -> void:
	var spots: Array = GameData.SNIPER_SPOTS
	_place(sniper, spots[randi() % spots.size()], GameData.ITEM.life)
	sniper.ammo = int(GameData.WEAPONS.sniper.ammo)
	announce("sn")


## 아이템이 나타났다는 알림 + 소리 (친구대전 손님은 방장이 알려줄 때 부른다)
## 등장 알림은 제목만 띄운다 (설명 문구는 사용자 요청으로 뺌)
func announce(key: String) -> void:
	var me_in := combat.me != null and not combat.me.spectating
	match key:
		"sn":
			banner.emit("대물 저격총이 나타났다!", "")
			if me_in:
				Sfx.play("bell")
		"ak":
			banner.emit("AK-47이 나타났다!", "")
			if me_in:
				Sfx.play("bell")
		"hs":
			banner.emit("기사의 말이 나타났다!", "")
			if me_in:
				Sfx.play("neigh", horse.pos)


func spawn_ak() -> void:
	var spots: Array = GameData.SNIPER_SPOTS
	var opts := spots.filter(func(q: Vector3) -> bool:
		return not sniper.active or Vector2(q.x - sniper.pos.x, q.z - sniper.pos.z).length() > float(GameData.ITEM.ak_apart))
	var q: Vector3 = opts[randi() % opts.size()] if opts.size() > 0 else spots[0]
	_place(ak, q, GameData.ITEM.life)
	ak.ammo = int(GameData.WEAPONS.ak.mag)
	announce("ak")


## 죽은 사람이 들고 있던 총을 그 자리에 떨어뜨림 (남은 탄 그대로)
func drop_sniper(pos: Vector3, ammo: int) -> void:
	_place(sniper, pos, GameData.ITEM.drop_life)
	sniper.ammo = ammo if ammo > 0 else int(GameData.WEAPONS.sniper.ammo)


func drop_ak(pos: Vector3, ammo: int) -> void:
	_place(ak, pos, GameData.ITEM.drop_life)
	ak.ammo = ammo if ammo > 0 else int(GameData.WEAPONS.ak.mag)


func pickup_sniper(e: PlayerController) -> void:
	sniper.active = false
	(sniper.group as Node3D).visible = false
	e.ammo = sniper.ammo
	e.has_sniper = true
	e.wep = "sniper"
	e.reset_charge()
	e.swap_t = 0.15
	if not e.is_local:
		banner.emit("대물 저격총 획득: " + e.ent_name, "조심하세요. 한 방에 날아갑니다.")
	if e.is_local:
		Sfx.play("pickup")


func pickup_ak(e: PlayerController) -> void:
	ak.active = false
	(ak.group as Node3D).visible = false
	e.ak_ammo = ak.ammo
	e.has_ak = true
	e.wep = "ak"
	e.bloom = 0.0
	e.reset_charge()
	e.swap_t = GameData.WEAPONS.ak.swap
	if not e.is_local:
		banner.emit("AK-47 획득: " + e.ent_name, "총알이 쏟아집니다. 엄폐하세요.")
	else:
		Sfx.play("pickup")


## 아무도 안 들고 있으면 가끔 나타남, 빙글빙글·빛기둥 깜빡, 닿으면 주움 — HTML updateSniper / updateAK
func _update_gun(it: Dictionary, dt: float, is_sniper: bool) -> void:
	var I: Dictionary = GameData.ITEM
	var held := combat.ents.any(func(e: PlayerController) -> bool: return e.has_sniper if is_sniper else e.has_ak)
	if not it.active and not held and combat.authority():
		if is_sniper:
			sniper_timer -= dt
			if sniper_timer <= 0:
				sniper_timer = rr(I.sniper_timer)
				if randf() < float(I.sniper_chance):
					spawn_sniper()
		else:
			ak_timer -= dt
			if ak_timer <= 0:
				ak_timer = rr(I.ak_timer)
				if randf() < float(I.ak_chance):
					spawn_ak()
	if not it.active:
		return
	it.t += dt
	it.life -= dt
	var holder: Node3D = it.holder
	holder.rotation.y += dt * 1.5
	holder.position.y = 1 + sin(it.t * 2.5) * 0.15
	((it.pillar as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.2 + sin(it.t * 4) * 0.08
	var rs := (1 + sin(it.t * 3) * 0.12) * 1.3
	(it.ring as Node3D).scale = Vector3(rs, rs, rs)
	if it.life <= 0:
		it.active = false
		(it.group as Node3D).visible = false
		return
	for e in combat.ents:
		if not e.is_remote and e.alive and not e.has_sniper and not e.has_ak and e.mounted <= 0 and e.global_position.distance_to(it.pos) < float(I.pick_r):
			if not combat.authority():  # 친구대전 손님: 방장에게 달라고 하고 허락을 기다림
				if e.is_local:
					combat.net.request("sn" if is_sniper else "ak")
				return
			if is_sniper:
				pickup_sniper(e)
			else:
				pickup_ak(e)
			return


func update_sniper(dt: float) -> void:
	_update_gun(sniper, dt, true)


func update_ak(dt: float) -> void:
	_update_gun(ak, dt, false)


# ── 닭 ───────────────────────────────────────────────────────
func spawn_chicken(pos: Vector3, no_pick := 0.0) -> void:
	var I: Dictionary = GameData.ITEM
	if chickens.size() >= int(I.chicken_cap):
		(chickens.pop_front().body as Node).queue_free()
	var body := CharacterBody3D.new()
	body.collision_layer = 0  # 사람과는 부딪히지 않고 월드에만
	body.collision_mask = 1
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(46)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()  # HTML integrate()는 사람과 같은 r 0.38 · h 1.75 상자로 계산
	shape.radius = 0.38
	shape.height = 1.75
	cs.shape = shape
	cs.position.y = 0.875
	body.add_child(cs)
	var c := WeaponModels.make_chicken()
	body.add_child(c.g)
	add_child(body)
	body.global_position = pos
	body.velocity = Vector3(randf_range(-2, 2), 3, randf_range(-2, 2))
	body.reset_physics_interpolation()
	chickens.append({"body": body, "c": c, "heading": randf_range(0, TAU), "turn_t": 0.0, "no_pick": no_pick,
		"t": randf_range(0, 9), "flee": 0.0, "grounded": false, "cluck_t": randf_range(2, 6)})


## 돌아다니다 사람이 가까이 오면 도망가고, 닿으면 잡힘 — HTML updateChickens
func update_chickens(dt: float) -> void:
	if combat.mp():
		return
	var I: Dictionary = GameData.ITEM
	chicken_timer -= dt
	if chicken_timer <= 0:
		chicken_timer = rr(I.chicken_timer)
		if chickens.size() < int(I.chicken_max):
			spawn_chicken(combat.world.random_point())
	for i in range(chickens.size() - 1, -1, -1):
		var c := chickens[i]
		var body: CharacterBody3D = c.body
		var pos := body.global_position
		c.t += dt
		c.cluck_t -= dt
		if c.cluck_t <= 0:  # 가끔 꼬꼬댁
			c.cluck_t = randf_range(3, 8)
			Sfx.play("cluck", (c.body as Node3D).global_position)
		c.no_pick -= dt
		c.turn_t -= dt
		var near: PlayerController = null
		var nd: float = I.chicken_flee_r
		for e in combat.ents:
			if not e.alive:
				continue
			var d := e.global_position.distance_to(pos)
			if d < nd:
				nd = d
				near = e
		var sp: float = I.chicken_walk
		if near:
			c.heading = atan2(pos.x - near.global_position.x, pos.z - near.global_position.z) + sin(c.t * 6) * 0.5
			sp = I.chicken_run
			c.flee = 0.5
		elif c.turn_t <= 0:
			c.turn_t = randf_range(1, 3)
			c.heading += randf_range(-1.5, 1.5)
			if randf() < 0.3:
				sp = 0.0
		if c.flee > 0:
			c.flee -= dt
		var v := body.velocity
		if c.grounded:
			v.x += (sin(c.heading) * sp - v.x) * minf(1.0, dt * 6)
			v.z += (cos(c.heading) * sp - v.z) * minf(1.0, dt * 6)
			if c.flee > 0 and randf() < dt * 2.5:
				v.y = 3.5
		v.y -= GameData.GRAV * dt
		body.velocity = v
		body.move_and_slide()
		c.grounded = body.is_on_floor()
		if c.grounded and body.velocity.y < 0:
			body.velocity.y = 0
		pos = body.global_position
		var A: float = GameData.ARENA
		if absf(pos.x) > A - 0.5 or absf(pos.z) > A - 0.5:
			c.heading += PI
		var g: Node3D = c.c.g
		var hs := Vector2(body.velocity.x, body.velocity.z).length()
		if hs > 0.2:
			g.rotation.y += wrapf(atan2(body.velocity.x, body.velocity.z) - g.rotation.y, -PI, PI) * minf(1.0, dt * 10)
		var fl := 0.15 if c.grounded and c.flee <= 0 else 1.0
		WeaponModels.anim_chicken(c.c, c.t, fl, fl > 0.5, hs, sp == 0.0)
		if c.no_pick <= 0:
			for e in combat.ents:
				if e.alive and not e.has_chicken and e.mounted <= 0 and e.global_position.distance_to(pos) < float(I.chicken_grab_r):
					combat.grab_chicken(e)
					body.queue_free()
					chickens.remove_at(i)
					break


# ── 기사의 말 + 마상창 ───────────────────────────────────────
func spawn_horse() -> void:
	var spots: Array = GameData.HORSE_SPOTS
	_place(horse, spots[randi() % spots.size()], GameData.ITEM.horse_life)
	(horse.group as Node3D).rotation.y = randf_range(0, TAU)
	announce("hs")


func mount(e: PlayerController) -> void:
	horse.active = false
	(horse.group as Node3D).visible = false
	e.mounted = GameData.HORSE_TIME
	e.mount_h = GameData.MOUNT_H
	e.wep = "lance"
	e.reset_charge()
	e.swap_t = 0.2
	e.sliding = false
	e.fall_t = 0.0
	var h := WeaponModels.make_horse(true)
	add_child(h.g)
	(h.g as Node3D).global_position = e.global_position
	(h.g as Node3D).rotation.y = e.yaw + PI
	(h.g as Node3D).reset_physics_interpolation()
	e.horse = h
	Sfx.play("neigh", e.global_position)
	if e.is_local:
		combat.toast.emit("돌격! 창끝으로 들이받으세요")
	else:
		banner.emit("%s이(가) 말에 올라탔다!" % e.ent_name, "창에 찔리면 멀리 날아가요 · 피하세요")


func dismount(e: PlayerController) -> void:
	if not e.horse.is_empty():
		runaways.append({"h": e.horse, "dir": Vector3(-sin(e.yaw), 0, -cos(e.yaw)), "life": GameData.ITEM.runaway})
		e.horse = {}
	e.mounted = 0.0
	e.mount_h = 0.0
	if e.wep == "lance":
		e.wep = GameData.CLASSES[e.cls].weapon
	e.swap_t = 0.3


## 창끝(앞 1.2~3.5m)에 걸리면 70 피해, 말 몸통에 치이면 넘어짐 — HTML lanceCheck
func lance_check(e: PlayerController) -> void:
	var I: Dictionary = GameData.ITEM
	var sp := Vector2(e.velocity.x, e.velocity.z).length()
	if sp < float(I.lance_min_speed):
		return
	var f := Vector3(-sin(e.yaw), 0, -cos(e.yaw))
	var ep := e.global_position
	var a := ep + Vector3(0, I.lance_from_y, 0) + f * float(I.lance_from)
	var tip := ep + Vector3(0, I.lance_tip_y, 0) + f * float(I.lance_tip)
	var d := tip - a
	for v in combat.ents:
		if v == e or not v.alive or v.invuln > 0:
			continue
		var h := Combat.hit_test(a, d, v, I.lance_r)  # 창 판정을 넉넉하게
		if not h.is_empty():
			if v.ln_t > 0:
				continue
			v.ln_t = I.lance_again
			if v.is_remote:  # 친구는 친구 쪽에서 피해를 받는다
				combat.net.event(["ln", v.peer, h.head, f])
			else:
				combat.damage(v, e, GameData.WEAPONS.lance.dmg, "lance", h.head, f, a + d * float(h.t))
			continue
		var vp := v.global_position
		if not v.is_remote and v.mounted <= 0 and v.fall_t <= 0 and Vector2(vp.x - ep.x, vp.z - ep.z).length() < float(I.trample_r) and absf(vp.y - ep.y) < float(I.trample_h):
			var aw := Vector3(vp.x - ep.x, 0, vp.z - ep.z).normalized()
			v.velocity += aw * float(I.trample_kb)
			v.velocity.y = I.trample_up
			v.grounded = false
			v.trip()
			Sfx.play("thud", v.global_position)


func update_horses(dt: float) -> void:
	var I: Dictionary = GameData.ITEM
	for v in combat.ents:
		v.ln_t -= dt
	if combat.authority() and not horse.active and not combat.ents.any(func(e: PlayerController) -> bool: return e.mounted > 0):
		horse_timer -= dt
		if horse_timer <= 0:
			horse_timer = rr(I.horse_timer)
			if randf() < float(I.horse_chance):
				spawn_horse()
	if horse.active:
		horse.t += dt
		horse.life -= dt
		WeaponModels.anim_horse(horse.model, 0, dt)
		((horse.pillar as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.16 + sin(horse.t * 4) * 0.06
		if horse.life <= 0:
			horse.active = false
			(horse.group as Node3D).visible = false
		else:
			for e in combat.ents:
				if not e.is_remote and e.alive and e.mounted <= 0 and e.fall_t <= 0 and e.global_position.distance_to(horse.pos) < float(I.mount_r):
					if not combat.authority():
						if e.is_local:
							combat.net.request("hs")
					else:
						mount(e)
					break
	for e in combat.ents:
		if e.is_remote:  # 친구의 말: 보이기만 (창 판정은 타는 사람 쪽에서)
			if e.alive and e.mounted > 0:
				if e.horse.is_empty():
					var h := WeaponModels.make_horse(true)
					add_child(h.g)
					e.horse = h
				var g: Node3D = e.horse.g
				g.global_position = e.global_position
				g.rotation.y = e.yaw + PI
				WeaponModels.anim_horse(e.horse, Vector2(e.velocity.x, e.velocity.z).length(), dt)
			elif not e.horse.is_empty():
				dismount(e)
			continue
		if e.mounted <= 0:
			continue
		if not e.alive:
			dismount(e)
			continue
		e.mounted -= dt
		var sp := Vector2(e.velocity.x, e.velocity.z).length()
		var hg: Node3D = e.horse.g
		hg.global_position = e.global_position
		hg.rotation.y = e.yaw + PI
		WeaponModels.anim_horse(e.horse, sp, dt)
		e.horse.hoof_t = float(e.horse.get("hoof_t", 0.0)) - dt * (sp / 4)
		if sp > 2 and e.horse.hoof_t <= 0:  # 다그닥
			e.horse.hoof_t = 0.28
			Sfx.play("hoof", e.global_position)
		lance_check(e)
		if e.mounted <= 0:
			dismount(e)
			if e.is_local:
				combat.toast.emit("말이 떠났다")
	for i in range(runaways.size() - 1, -1, -1):
		var r := runaways[i]
		r.life -= dt
		var g: Node3D = r.h.g
		g.global_position += (r.dir as Vector3) * float(I.runaway_speed) * dt
		WeaponModels.anim_horse(r.h, I.runaway_speed, dt)
		if r.life < 0.5:
			g.scale = Vector3.ONE * maxf(0.01, r.life / 0.5)
		if r.life <= 0:
			g.queue_free()
			runaways.remove_at(i)
