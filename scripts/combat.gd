class_name Combat
extends Node3D
## 무기·투사체·피격 판정·피해·처치·부활 — HTML weaponUpdate() / fire() / updateProjectiles()
## / hitTest() / damage() / impactFx() / kill() / knockHelmet() / updateHelms()
## / spawn()(지점 고르기) / simulate()(무적·재생·부활 타이머) 이식.
## 모든 캐릭터(나, 허수아비, 나중엔 봇)는 PlayerController이고 ents에 등록한다.
## 날아가는 투사체와 날아간 투구도 이 노드 아래에 둔다.
## process_physics_priority를 높여서 캐릭터 이동이 끝난 뒤에 돈다 (HTML simulate 순서와 같게).

signal toast(text: String)  # 내 화면 알림
signal killed(v: PlayerController, a: PlayerController, kind: String, head: bool)
signal num(pos: Vector3, text: String, style: String)  # 내가 때린 데미지 숫자 (style: "" / head / dot / kill)
signal hitmark(is_kill: bool)  # 내가 맞혔을 때 조준점 X 표시
signal hurt(dmg: float)        # 내가 맞음 → 붉은 테두리 (HTML hurt)
signal dmg_dir(from: Vector3)  # 내가 맞음 → 때린 사람 쪽에 붉은 호 (HTML dmgDir)
signal star_changed(e: PlayerController, on: bool)  # 황금 붕어빵 무적 시작·끝 (Main이 내 것만 보고 BGM을 바꿈)

var world: WorldBuilder
var fx: Fx
var bard_fx: BardFx         # 음유시인 트럼펫 이펙트 (scripts/fx/bard_fx.gd — 보기만 함)
var star_fx: StarFx         # 황금 붕어빵 무적 반짝임 (scripts/fx/star_fx.gd — 보기만 함)
var items: Items            # 닭·말·저격총·AK
var me: PlayerController    # 내 캐릭터 (스코프·3인칭 판단)
var net: Net = null         # 친구대전 중이면 Net (아니면 null)
var mode: ControlMode = null  # 쟁탈전이면 규칙 (개인전은 null — 기존 그대로)
var ents: Array[PlayerController] = []
var loose_helms: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var world_arrows: Array[Dictionary] = []  # 벽·땅에 꽂힌 화살 {m, life}
var zones: Array[Dictionary] = []  # 성수 웅덩이 {owner, pos, r, life, tick, disc, rim, t}
var aim_mk: MeshInstance3D         # 성수 착지 지점 표시 (내 화면)
var ragdolls: Array = []           # 쓰러진 몸 (Ragdoll)
var hit_stop := 0.0                # 남은 히트스톱 (실제 시간, 초)
var _hs_on := false                 # 히트스톱이 Engine.time_scale을 늦춰 둔 상태
var clock := 0.0                   # 경기 물리 시간 (춤 누적 기록에 씀)

const SPINS := ["stone", "holy", "chicken"]  # 날아가며 빙글빙글 도는 투사체 (나머지는 진행 방향을 봄)


func _ready() -> void:
	process_physics_priority = 10
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	bard_fx = BardFx.new()
	bard_fx.name = "BardFx"
	bard_fx.combat = self
	add_child(bard_fx)
	star_fx = StarFx.new()
	star_fx.name = "StarFx"
	star_fx.combat = self
	add_child(star_fx)
	items = Items.new()
	items.name = "Items"
	items.combat = self
	add_child(items)
	var H: Dictionary = GameData.HOLY
	aim_mk = MeshInstance3D.new()
	aim_mk.mesh = Meshes.flat_ring()
	aim_mk.material_override = _flat_mat(H.rim_mine, H.aim_alpha, 4)
	aim_mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_mk.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	aim_mk.visible = false
	add_child(aim_mk)


## 시작할 때 셰이더를 미리 데울 재질들 — 경기 중에 처음 나오는 효과용 (Main이 ShaderWarm에 넘긴다)
func warm_mats() -> Array:
	var a: Array = [WeaponModels.glass_mat()]
	a.append_array(fx.keep_mats)
	a.append_array(bard_fx.keep_mats)
	a.append_array(star_fx.keep_mats)
	return a


func register(e: PlayerController) -> void:
	if not ents.has(e):
		ents.append(e)
	e.combat = self
	if e.is_local:
		me = e
	if e.is_bot and not e.ai:
		e.ai = BotAI.new()


## 빠지는 캐릭터의 투사체·성수 웅덩이도 같이 치운다 (친구가 나가 노드가 지워진 뒤 owner로 남으면
## ally()·타입 있는 변수에서 "previously freed" 오류가 나서 투사체·웅덩이가 멈춘다)
func unregister(e: PlayerController) -> void:
	ents.erase(e)
	for i in range(projectiles.size() - 1, -1, -1):
		if projectiles[i].owner == e:
			(projectiles[i].mesh as Node).queue_free()
			projectiles.remove_at(i)
	for i in range(zones.size() - 1, -1, -1):
		if zones[i].owner == e:
			(zones[i].disc as Node).queue_free()
			(zones[i].rim as Node).queue_free()
			zones.remove_at(i)


## 친구대전 중인가 (HTML MP.on)
func mp() -> bool:
	return net != null and net.on


## 아이템 등장·말 등장 같은 걸 이 컴퓨터가 정하나 (혼자 하거나 방장일 때)
func authority() -> bool:
	return not mp() or net.is_host


## 3인칭이면 화면 가운데 조준 보정을 쓴다. 저격총 스코프를 보면 1인칭 (HTML tpOn)
func tp_on() -> bool:
	return me.tp_view() if me else GameData.third_person


# ── 매 물리 프레임 (HTML simulate) ──
func _physics_process(dt: float) -> void:
	clock += dt
	_tick_timers(dt)
	items.update_sniper(dt)
	items.update_ak(dt)
	items.update_fish(dt)
	for e in ents:
		if e.alive and not e.is_remote:  # 친구 캐릭터는 받은 사건으로만 쏜다
			if e.swap_req:
				toggle_special(e)
			weapon_update(e, e.fire_held, dt)
		elif e.alive and e.wep == "crossbow" and e.cd > 0:  # 친구 석궁: 쏜 사건부터 장전 시간을 재서 장전 소리를 냄
			e.cd = maxf(0.0, e.cd - dt)
			_xbow_reload_sfx(e)
		e.swap_req = false
	Trumpet.update_victims(self, dt)  # 트럼펫 소리를 들은 쪽: 피해·춤 (4.5단계)
	update_projectiles(dt)
	update_zones(dt)
	items.update_chickens(dt)
	items.update_horses(dt)
	_update_world_arrows(dt)
	_update_helms(dt)
	if mode:
		mode.update(dt)
	for i in range(ragdolls.size() - 1, -1, -1):
		var rd: Ragdoll = ragdolls[i]
		if rd.update(dt):
			rd.free_nodes()
			ragdolls.remove_at(i)


## 히트스톱 — 내가 맞히면 아주 잠깐 시간이 느려진다 (HTML hitStop: 그동안 시뮬레이션 ×0.12)
## 게임 시간 전체(Engine.time_scale)를 늦추고, 남은 시간은 실제 시간으로 줄인다.
func _tick_hit_stop(delta: float) -> void:
	if hit_stop > 0:
		hit_stop -= delta / maxf(Engine.time_scale, 0.01)
		if hit_stop > 0:
			Engine.time_scale = GameData.HITSTOP_SCALE
			_hs_on = true
			return
	if _hs_on:  # 히트스톱이 건 것만 되돌림 (결과 화면 느린 화면을 덮어쓰지 않게)
		_hs_on = false
		Engine.time_scale = 1.0


func add_hit_stop(t: float) -> void:
	if GameData.hitstop_enabled and t > 0:
		hit_stop = maxf(hit_stop, t)


func stop_hit_stop() -> void:
	hit_stop = 0.0
	_hs_on = false
	Engine.time_scale = 1.0


## 무적·재생·부활
func _tick_timers(dt: float) -> void:
	for e in ents:
		if e.is_remote:  # 친구 캐릭터의 체력·부활은 친구 컴퓨터가 정한다
			continue
		if e.alive:
			e.invuln = maxf(0.0, e.invuln - dt)
			if e.star_t > 0:  # 황금 붕어빵 무적
				_star_touch(e, dt)
				e.star_t -= dt
				if e.star_t <= 0:
					end_star(e)
			# 체력 재생: REGEN_DELAY초 동안 안 맞으면 1씩 차오른다
			var mh := float(GameData.class_hp(e.cls))
			e.no_hit_t += dt
			if e.no_hit_t >= GameData.REGEN_DELAY and e.hp < mh:
				e.regen_acc += dt
				var rs := 1.0 / GameData.class_regen(e.cls)
				while e.regen_acc >= rs:
					e.regen_acc -= rs
					e.hp = minf(mh, e.hp + 1)
			else:
				e.regen_acc = 0.0
		elif not e.spectating:  # 메뉴에서 구경 중인 나는 부활하지 않는다
			e.respawn -= dt
			if e.respawn <= 0:
				spawn(e)


## 점수판 순서: 처치 많은 순, 같으면 죽음 적은 순. 구경 중인 사람은 빠진다 (HTML scoreRows)
func score_rows() -> Array[PlayerController]:
	var rows: Array[PlayerController] = ents.filter(func(e: PlayerController) -> bool: return not e.spectating)
	rows.sort_custom(func(a: PlayerController, b: PlayerController) -> bool:
		return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	return rows


## 투사체·웅덩이·꽂힌 화살·효과·날아간 투구를 전부 치운다 (HTML clearMatchObjects)
## 닭·말·저격총·AK·래그돌도 지운다.
func clear_match_objects() -> void:
	for p in projectiles:
		(p.mesh as Node).queue_free()
	projectiles.clear()
	for z in zones:
		(z.disc as Node).queue_free()
		(z.rim as Node).queue_free()
	zones.clear()
	for w in world_arrows:
		(w.m as Node).queue_free()
	world_arrows.clear()
	for h in loose_helms:
		(h.o as Node).queue_free()
	loose_helms.clear()
	for rd: Ragdoll in ragdolls:
		rd.free_nodes()
	ragdolls.clear()
	stop_hit_stop()
	fx.clear()
	bard_fx.clear()
	star_fx.clear()
	items.clear()


# ── 스폰: 살아 있는 다른 사람에게서 가장 먼 지점 몇 곳 중 하나 ──
func spawn(e: PlayerController) -> void:
	if mode:  # 쟁탈전: 자기 팀 스폰룸
		e.spawn_at(mode.spawn_pos(e))
		return
	var others := ents.filter(func(o: PlayerController) -> bool: return o != e and o.alive)
	var scored: Array[Dictionary] = []
	for p: Vector3 in world.spawn_points:
		var d := randf_range(0, 50)
		if others.size() > 0:
			d = INF
			for o: PlayerController in others:
				d = minf(d, o.global_position.distance_to(p))
		scored.append({"p": p, "d": d})
	if scored.is_empty():
		e.spawn_at(Vector3(0, 0, 20))
		return
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d > b.d)
	var pick: Vector3 = scored[randi() % mini(GameData.SPAWN_PICK, scored.size())].p
	e.spawn_at(pick)


## 같은 팀인가 (쟁탈전). 개인전은 team이 ""라 늘 false. 아군끼리는 투사체가 통과하고 피해·넘어짐·둔화·춤이 없다
static func ally(a: PlayerController, b: PlayerController) -> bool:
	return a != null and b != null and a != b and a.team != "" and a.team == b.team


# ── 선분 판정 도구 (HTML segSeg / segPoint) ──
## 선분 o→o+d 위에서 점 p에 가장 가까운 곳: {t, dist2}
static func seg_point(o: Vector3, d: Vector3, p: Vector3) -> Dictionary:
	var dd := d.dot(d)
	var t := clampf((p - o).dot(d) / dd, 0, 1) if dd > 0 else 0.0
	return {"t": t, "dist2": (o + d * t).distance_squared_to(p)}


## 두 선분 사이 최단 거리: {s(첫 선분 위 비율), dist2}
static func seg_seg(p1: Vector3, d1: Vector3, p2: Vector3, d2: Vector3) -> Dictionary:
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		pass
	elif a <= 1e-9:
		t = clampf(f / e, 0, 1)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0, 1)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0, 1) if den != 0 else 0.0
			t = (b * s + f) / e
			if t < 0:
				t = 0
				s = clampf(-c / a, 0, 1)
			elif t > 1:
				t = 1
				s = clampf((b - c) / a, 0, 1)
	return {"s": s, "dist2": (p1 + d1 * s).distance_squared_to(p2 + d2 * t)}


## 선분 o→o+d가 v의 머리(구)나 몸(캡슐)에 닿는지. pr = 투사체 반지름.
## 닿으면 {t(0~1), head}, 아니면 빈 딕셔너리. 몸이 머리보다 0.25m 이상 앞에서 닿을 때만 몸으로 친다.
static func hit_test(o: Vector3, d: Vector3, v: PlayerController, pr: float) -> Dictionary:
	var length := d.length()
	var res := {}
	var h := seg_point(o, d, v.head_c())
	var hr := GameData.HEAD_R + pr
	if h.dist2 < hr * hr:
		res = {"t": h.t, "head": true}
	var ba := v.body_a()
	var s := seg_seg(o, d, ba, v.body_b() - ba)
	var br := GameData.BODY_R + pr
	if s.dist2 < br * br and (res.is_empty() or s.s * length < h.t * length - 0.25):
		res = {"t": s.s, "head": false}
	return res


## 월드(건물·땅)에 닿는 비율 t (0~1), 안 닿으면 INF — HTML worldRay
func world_ray(o: Vector3, d: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(o, o + d, 1)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return INF
	return o.distance_to(res.position) / d.length()


## a와 b 사이가 트였나 (건물에 안 가림) — HTML los
func los(a: Vector3, b: Vector3) -> bool:
	var t := world_ray(a, b - a)
	return not (t > 0.001 and t < 0.995)


## 발밑 땅 높이 — HTML groundBelow
func ground_below(pt: Vector3) -> float:
	var o := pt + Vector3(0, 0.3, 0)
	var d := Vector3(0, -40, 0)
	var t := world_ray(o, d)
	return o.y + d.y * t if t <= 1 else 0.0


# ── 황금 붕어빵 무적 ─────────────────────────────────────────
## 먹으면 dur초 무적 (또 먹으면 다시 dur초로). 피해·넉백·남이 넘어뜨림·성수 둔화·춤을 막는다
func give_star(e: PlayerController) -> void:
	var was := e.star_t > 0
	e.star_t = float(GameData.ITEM.golden_fish.dur)
	e.slow_t = 0.0
	e.dance_t = 0.0
	e.dance_log.clear()
	if not was:
		e.star_hits.clear()
		star_changed.emit(e, true)


## 무적 끝 (시간이 다 됐거나 죽었을 때)
func end_star(e: PlayerController) -> void:
	e.star_t = 0.0
	e.star_hits.clear()
	star_changed.emit(e, false)


## 무적 중에 적과 몸이 닿으면 피해 20 + 큰 넉백 (같은 적은 again초에 한 번). 친구는 친구 쪽에서 피해를 받는다
func _star_touch(e: PlayerController, dt: float) -> void:
	var G: Dictionary = GameData.ITEM.golden_fish
	for k in e.star_hits.keys():
		e.star_hits[k] = float(e.star_hits[k]) - dt
	var ep := e.global_position
	for v in ents:
		if v == e or not v.alive or v.invuln > 0 or v.star_t > 0 or ally(e, v):
			continue
		var vp := v.global_position
		var d := Vector3(vp.x - ep.x, 0, vp.z - ep.z)
		if d.length() > float(G.touch_r) or absf(vp.y - ep.y) > float(G.touch_h):
			continue
		if float(e.star_hits.get(v, 0.0)) > 0:
			continue
		e.star_hits[v] = G.again
		var dir := d.normalized() if d.length_squared() > 1e-4 else Vector3(-sin(e.yaw), 0, -cos(e.yaw))
		Sfx.play("thud", vp)
		if v.is_remote:
			net.event(["st", v.peer, dir], e)
		else:
			damage(v, e, GameData.WEAPONS.star.dmg, "star", false, dir, vp + Vector3(0, 1.0, 0))


# ── 피해 ─────────────────────────────────────────────────────
## v가 a에게 kind 무기로 base만큼 맞음. dir = 날아온 방향(넉백 방향), pt = 맞은 지점(없으면 null)
func damage(v: PlayerController, a: PlayerController, base: float, kind: String, head: bool, dir: Vector3, pt: Variant = null) -> void:
	if not v.alive or v.invuln > 0 or v.star_t > 0:  # 황금 붕어빵 무적: 피해·넉백 다 막음
		return
	if ally(a, v):  # 쟁탈전: 팀킬 없음 (마상창·닭·팡파레·트럼펫·몸박치기도 여기서 막힘)
		return
	if mode and mode.no_damage():  # 쟁탈전: 라운드 사이
		return
	if mp() and v.is_remote:  # 친구대전: 피해는 맞은 사람 쪽에서만 판정 (HTML damage). 방장 봇은 방장 컴퓨터가 판정
		return
	var knocked := head and v.helmet
	var dmg := base * (GameData.HEADSHOT if v.helmet else GameData.BARE_HEAD) if head else base
	v.hp -= dmg
	v.last_hit = {"by": a, "kind": kind, "head": head}
	v.hit_squash = 1.0
	v.flash = 0.14
	v.no_hit_t = 0.0
	v.regen_acc = 0.0
	# 넉백: 수평으로 밀고 살짝 띄워서 미끄러지게
	var W: Dictionary = GameData.WEAPONS[kind]
	var kb: float = W.get("kb", 0)
	var up: float = W.get("up", 0)
	if kind == "bow":
		kb *= 0.7 + 0.6 * clampf((base - 35) / 20.0, 0, 1)
	if head:
		kb *= GameData.HEAD_KB
		up *= GameData.HEAD_UP
	if v.mounted > 0:
		kb *= GameData.MOUNT_KB
		up = 0
	v.velocity.x += dir.x * kb
	v.velocity.z += dir.z * kb
	if up > 0:
		v.velocity.y = maxf(v.velocity.y, up)
		v.grounded = false
	if kind == "ak":
		if v.mounted <= 0:
			v.kb_t = maxf(v.kb_t, GameData.KB_TIME_AK)
	elif kind != "holy" and kind != "trumpet" and v.mounted <= 0:  # 성수·트럼펫은 지속 피해라 경직·미끄러짐 없음
		v.kb_t = GameData.KB_TIME
		if v.is_bot:
			v.stagger = GameData.BOT_STAGGER_XBOW if kind == "crossbow" else GameData.BOT_STAGGER
	# 맞은 방향으로 몸이 출렁 (스프링)
	if v.model:
		var th := -(v.yaw + PI)
		var c := cos(th)
		var s := sin(th)
		var lx := dir.x * c + dir.z * s
		var lz := -dir.x * s + dir.z * c
		var imp: float = GameData.HIT_WOB.get(kind, GameData.HIT_WOB_DEFAULT) * (GameData.HIT_WOB_HEAD if head else 1.0)
		v.model.wob_v += Vector2(lz * imp, -lx * imp)
	if v.is_local:
		hurt.emit(dmg)
		Sfx.play("hurt")
	if a and a.is_local:
		hitmark.emit(false)
		if kind != "holy" and kind != "trumpet":
			Sfx.play("head" if head else "hit")
	var dead := v.hp <= 0
	if knocked:
		knock_helmet(v, dir)
		if a and a.is_local:
			num.emit(v.global_position + Vector3(0, 2, 0), "투구 날림!", "head")
		if v.is_local and not dead:
			toast.emit("투구가 날아갔다! 머리 피해 2배")
	impact_fx(v, a, pt, kind, head, dir, dmg, dead)
	if mp() and a and a.is_remote:  # 내가(또는 내 봇이) 맞았다고 모두에게 알림 (맞은 효과·히트마크용)
		net.event(["h", a.peer, roundf(dmg), Net.WEPS.find(kind), head], v)
	if dead:
		kill(v, a, kind, head, dir)
		return
	if v.is_bot and v.ai and a and a.alive and a != v:  # 봇은 때린 사람을 바로 노린다
		v.ai.on_hit(a)


## 맞은 효과: 조각·링·숫자·소리·히트스톱(내가 맞힘)·화면 흔들림과 피격 방향(내가 맞음) — HTML impactFx
## 내가 맞은 건 1인칭이면 안 보이게 한다 (화면을 가리니까).
func impact_fx(v: PlayerController, a: PlayerController, pt: Variant, kind: String, head: bool, dir: Vector3, dmg: float, dead: bool) -> void:
	var p: Vector3 = pt if pt != null else v.global_position + Vector3(0, 1.1, 0)
	var seen := not v.is_local or tp_on()
	var mine := a != null and a.is_local
	var col: int = GameData.CLASSES[v.cls].color
	if kind == "chicken":
		if seen:
			fx.ring(p, 0xffffff, 0.8, 0.22)
			if dead:
				fx.ring(p, 0xffd56b, 2.2, 0.38)
		if mine:
			num.emit(p, "처치" if dead else "꼬꼬댁!", "kill" if dead else "head")
			add_hit_stop(GameData.HITSTOP.kill if dead else GameData.HITSTOP.chicken)
		_hurt_me(v, a, GameData.SHAKE.chicken)
		return
	if kind == "holy" or kind == "trumpet":  # 지속 피해는 가볍게 (숫자도 작은 dot)
		if seen:
			fx.puff(p, 0xffe07a if kind == "holy" else 0xc9a2e8, 0.08, 2)
			if dead:
				fx.ring(p, 0xffd56b, 2.2, 0.38)
		if kind == "holy":
			Sfx.play("sizzle", p)
		if mine:
			num.emit(p, "처치" if dead else str(roundi(dmg)), "kill" if dead else "dot")
			if dead:
				add_hit_stop(GameData.HITSTOP.kill)
		_hurt_me(v, a, GameData.SHAKE.holy)
		return
	var heavy := kind == "crossbow" or kind == "sniper" or kind == "lance"
	var light := kind == "ak" and not head and not dead
	if seen and light:
		fx.chunks(p, col, dir, 2, 3.5)
	elif seen:
		fx.chunks(p, col, dir, 8 if head or heavy else 5, 7.5 if heavy else 4.5)
		fx.chunks(p, 0xffffff, dir, 4 if head else 2, 5)
		if head:
			fx.chunks(p, 0xf3b33d, dir, 4, 5.5)
		fx.ring(p, 0xffd56b if head else 0xffffff, 1.4 if heavy else (1.1 if head else 0.75), 0.22)
		if dead:
			fx.ring(p, 0xffd56b, 2.2, 0.38)
	Sfx.play("thud_heavy" if heavy or dead else "thud", p)
	var HS: Dictionary = GameData.HITSTOP
	if mine:
		num.emit(p, "처치" if dead else str(roundi(dmg)), "kill" if dead else ("head" if head else ""))
		if dead:
			add_hit_stop(HS.kill)
		elif head:
			add_hit_stop(HS.head_ak if kind == "ak" else HS.head)
		elif heavy:
			add_hit_stop(HS.heavy)
		else:
			add_hit_stop(HS.ak if kind == "ak" else HS.normal)
	var SH: Dictionary = GameData.SHAKE
	_hurt_me(v, a, (SH.ak if kind == "ak" else SH.base) + minf(dmg, SH.dmg_cap) / float(SH.dmg_div))


## 내가 맞았으면 화면을 흔들고 때린 사람 쪽을 표시
func _hurt_me(v: PlayerController, a: PlayerController, shake: float) -> void:
	if not v.is_local:
		return
	v.shake = maxf(v.shake, shake)
	if a and a != v:
		dmg_dir.emit(a.global_position)


# ── 무기 (HTML weaponUpdate) ─────────────────────────────────
## held = 이번 프레임에 공격 키를 누르고 있나
func weapon_update(e: PlayerController, held: bool, dt: float) -> void:
	e.cd = maxf(0.0, e.cd - dt)
	e.swap_t = maxf(0.0, e.swap_t - dt)
	if e.wep == "crossbow":
		_xbow_reload_sfx(e)
	if e.bloom > 0:  # AK 퍼짐: 쏘는 중엔 천천히, 떼면 빨리 줄어듦
		e.bloom = maxf(0.0, e.bloom - dt * (0.04 if e.trig_prev else 0.15))
	# 성직자는 성수가 3초마다 하나씩 다시 찬다 (다른 무기를 들고 있어도)
	if GameData.CLASSES[e.cls].weapon == "holy":
		var H2: Dictionary = GameData.WEAPONS.holy
		if e.charges < int(H2.max_charges):
			e.charge_t += dt
			if e.charge_t >= float(H2.recharge):
				e.charges += 1
				e.charge_t = 0.0
				if e.is_local:
					Sfx.play("reload")
		else:
			e.charge_t = 0.0
	# 춤추는 동안엔 어떤 무기로도 공격 못 함 (사용자 요청 — 연주·팡파레·던지기·쏘기·활 당기기 전부)
	var dancing := e.dance_t > 0
	# 음유시인은 숨이 다른 무기를 들고 있어도 돌아온다. 연주·팡파레는 트럼펫을 들고 넘어지지·춤추지 않았을 때만
	if GameData.CLASSES[e.cls].weapon == "trumpet":
		var can := e.wep == "trumpet" and e.swap_t <= 0 and e.fall_t <= 0 and not dancing and not (mode and mode.no_attack(e))
		Trumpet.update(self, e, held and can, dt)
		if can and e.aim_held:
			Trumpet.try_fanfare(self, e)
	if e.swap_t > 0 or e.fall_t > 0 or dancing or (mode and mode.no_attack(e)):  # 쟁탈전: 스폰룸 안·라운드 사이엔 공격 금지
		e.trig_prev = held
		if dancing and e.charging:  # 당기던 활은 놓침 (춤 끝나고 놓아도 안 나감)
			e.reset_charge()
		return
	match e.wep:
		"bow":
			_bow_update(e, held, dt)
		"stone", "crossbow":  # 누르고 있으면 재사용 대기(석궁은 장전)가 끝나는 대로 쏜다
			if held and e.cd <= 0:
				fire(e, e.wep)
		"holy":  # 누르고 있으면 0.4초마다, 남은 성수가 있는 만큼
			if held and e.cd <= 0 and e.charges > 0:
				fire(e, "holy")
		"chicken":  # 한 번 누를 때 한 마리 (봇은 누르고 있어도 던짐)
			if held and (e.is_bot or not e.trig_prev):
				fire(e, "chicken")
		"sniper":  # 한 번 누를 때 한 발
			if held and not e.trig_prev and e.cd <= 0:
				fire(e, "sniper")
		"ak":  # 누르고 있으면 연사
			if held and e.cd <= 0:
				fire(e, "ak")
		"trumpet":  # 위에서 Trumpet.update가 처리
			pass
	e.trig_prev = held


## Q: 저격총·AK ↔ 원래 무기 — HTML playerUpdate의 qPressed
func toggle_special(e: PlayerController) -> void:
	if not (e.has_sniper or e.has_ak) or e.has_chicken or e.mounted > 0:
		return
	var sp := "sniper" if e.has_sniper else "ak"
	e.wep = GameData.CLASSES[e.cls].weapon if e.wep == sp else sp
	e.reset_charge()
	e.swap_t = GameData.WEAPONS.ak.swap if sp == "ak" else GameData.ITEM.sniper_swap


## 닭을 잡음 — HTML grabChicken
func grab_chicken(e: PlayerController) -> void:
	e.has_chicken = true
	e.wep = "chicken"
	e.reset_charge()
	e.swap_t = 0.15
	if e.is_local:
		toast.emit("닭을 잡았다! 클릭해서 던지기")
	Sfx.play("cluck", e.global_position)


## 활: 누르면 당기고 놓으면 쏜다. 끝까지 당긴 채 오래 버티면 후들거리다 손이 미끄러진다.
func _bow_update(e: PlayerController, held: bool, dt: float) -> void:
	var B: Dictionary = GameData.WEAPONS.bow
	var full: float = B.full
	if held and e.cd <= 0:
		if not e.charging:  # 당기기 시작: 끼익 (놓거나 쏘면 reset_charge가 끔)
			e.snd_bow = Sfx.play("bow_draw", e.global_position)
		e.charging = true
		e.charge = minf(full, e.charge + dt)
		if e.charge >= full:
			e.hold_t += dt
			if e.hold_t > float(B.sway_start):  # 팔이 후들후들 — 조준이 직접 흔들린다
				e.sw_t += dt
				var A := minf(float(B.sway_max), float(B.sway_k) * (e.hold_t - float(B.sway_start)))
				var t := e.sw_t
				var oy := A * (sin(t * 5.1) + 0.5 * sin(t * 8.7 + 1))
				var op := A * 0.7 * (sin(t * 6.3 + 2) + 0.5 * sin(t * 9.9))
				e.yaw += oy - e.sway_y
				e.pitch = clampf(e.pitch + op - e.sway_p, -1.5, 1.5)
				e.sway_y = oy
				e.sway_p = op
			if e.hold_t >= float(B.slip_t):  # 손이 미끄러져 엉뚱한 데로 발사
				var sy: float = B.slip_yaw
				var sp: Array = B.slip_pitch
				e.yaw += randf_range(-sy, sy)
				e.pitch = clampf(e.pitch + randf_range(sp[0], sp[1]), -1.5, 1.5)
				fire(e, "bow", 1.0)
				e.reset_charge()
				if e.is_local:
					toast.emit("손이 미끄러졌다!")
					Sfx.play("slip")
	elif not held and e.charging:
		if e.charge >= float(B.min_charge):
			fire(e, "bow", e.charge / full)
		e.reset_charge()


## 석궁 장전 소리 (3인칭·봇도 들림): 시위 끊어 당기기 3번 · 걸쇠 · 볼트 끼우기.
## 지난 프레임 진행도(xb_last)와 이번 사이에 지나간 순간에만 낸다 — 순간은 GameData.XBOW_RELOAD_SND
func _xbow_reload_sfx(e: PlayerController) -> void:
	var X: Dictionary = GameData.XBOW_RELOAD_SND
	var pr := WeaponModels.xbow_progress(e.cd)
	var last := e.xb_last
	e.xb_last = pr
	if pr <= last:
		return
	var pos := e.global_position
	for k in 3:
		var th := float(X.pull0) + float(X.pull) * k / 3.0 + 0.005
		if last < th and pr >= th:
			Sfx.play("xbow_crank", pos)
	if last < float(X.latch) and pr >= float(X.latch):
		Sfx.play("xbow_latch", pos)
	if last < float(X.seat) and pr >= float(X.seat):
		Sfx.play("seat", pos)


## 3인칭: 화면 가운데(카메라 정면)가 가리키는 지점 — HTML tpAim
func tp_aim(e: PlayerController) -> Vector3:
	var o := e.cam.global_position
	var d := e.aim_dir() * GameData.TP_AIM_DIST
	var best := minf(1.0, world_ray(o, d))
	for v in ents:
		if v == e or not v.alive or ally(e, v):  # 아군은 조준점이 지나감
			continue
		var h := hit_test(o, d, v, GameData.TP_AIM_R)
		if not h.is_empty() and h.t < best:
			best = h.t
	return o + d * best


## 내가 쏠 때 방향: 3인칭이면 몸에서 나가니까 화면 가운데 지점을 향하게 — HTML playerAimDir
func player_aim_dir(e: PlayerController, from: Vector3) -> Vector3:
	var f := e.aim_dir()
	if not (e.is_local and e.cam and tp_on()):
		return f
	var d := tp_aim(e) - from
	return f if d.dot(f) < 1.5 else d.normalized()


## 내가 쏠 때 나가는 곳·방향 — 화면 가운데 조준선 위로 정확히 (사용자 요청: 좌하탄 고침. HTML은 눈에서 조준점으로 쏴서
## 3인칭이면 조준점이 멀 때 가까운 거리에선 조준선보다 왼쪽 아래(카메라가 오른쪽 위라서)로 지나갔다)
##   3인칭: 카메라 조준선에서 내 눈에 가장 가까운 점(+FIRE_FWD)에서 조준선 방향 그대로.
##          눈 → 그 점, 카메라 → 그 점이 벽에 막히거나 조준점이 그보다 가까우면 예전처럼 눈에서 조준점으로.
##   1인칭: 손 자리(눈에서 오른쪽·아래, hand = true일 때)에서 조준점(조준선이 처음 닿는 곳)으로.
## 돌려주는 값: {pos, dir}
func local_launch(e: PlayerController, kind: String, hand := true) -> Dictionary:
	var eye := e.eye_pos()
	var f := e.aim_dir()
	if not e.cam:
		return {"pos": eye + f * GameData.FIRE_FWD, "dir": f}
	var o := e.cam.global_position
	var target := tp_aim(e)
	var reach := (target - o).dot(f)
	if tp_on():
		var s := maxf(0.0, (eye - o).dot(f)) + GameData.FIRE_FWD
		var start := o + f * s
		if reach > s + 0.1 and world_ray(eye, start - eye) >= 1.0 and world_ray(o, start - o) >= 1.0:
			return {"pos": start, "dir": f}
		var d := player_aim_dir(e, eye)
		return {"pos": eye + d * GameData.FIRE_FWD, "dir": d}
	var pos := eye + f * GameData.FIRE_FWD
	if hand:
		var right := Vector3(cos(e.yaw), 0, -sin(e.yaw))
		pos += right * float(GameData.FIRE_RIGHT.get(kind, GameData.FIRE_RIGHT_DEFAULT))
		pos.y -= GameData.FIRE_DROP
	var to := target - pos
	return {"pos": pos, "dir": to.normalized() if to.dot(f) > 1.0 else f}


## 발사 — HTML fire(). 저격총·AK는 히트스캔, 나머지는 투사체
## t = 활을 당긴 정도 0~1
func fire(e: PlayerController, kind: String, t := 0.0) -> void:
	var eye := e.eye_pos()
	var dir := e.aim_dir()
	var launch := {}
	if e.is_local:  # 조준선 위로 (히트스캔은 손 자리 없이 눈·조준선에서)
		launch = local_launch(e, kind, kind != "sniper" and kind != "ak")
		dir = launch.dir
		if kind == "sniper" or kind == "ak":
			eye = launch.pos - dir * GameData.FIRE_FWD
	var W: Dictionary = GameData.WEAPONS[kind]
	var mesh: Node3D
	var speed: float
	var dmg: float
	# 반동 모션 (조준은 그대로): 3인칭 몸은 rec, 내 1인칭 화면·손은 v_rec
	if GameData.RECOIL.has(kind):
		var R: Dictionary = GameData.RECOIL[kind]
		e.rec_v += float(R.rec[0]) + float(R.rec[1]) * t
		if e.is_local:
			e.v_rec_v += float(R.vrec[0]) + float(R.vrec[1]) * t
	if e.is_local:
		e.vm_kick += float(GameData.VM_KICK.get(kind, GameData.VM_KICK_DEFAULT))
	if kind == "sniper" or kind == "ak":
		e.fire_anim = 1.0
		if kind == "sniper":
			_fire_sniper(e, eye, dir)
		else:
			_fire_ak(e, eye, dir)
		return
	match kind:
		"stone":
			e.cd = W.cd
			var mi := MeshInstance3D.new()
			mi.mesh = Meshes.stone()
			mi.material_override = GameData.mat(W.color)
			mi.scale = Vector3.ONE * float(W.size)
			mesh = mi
			speed = W.speed
			dmg = W.dmg
			Sfx.play("throw", e.global_position)
		"bow":  # 당긴 만큼 빠르고 세다
			speed = lerpf(W.speed_min, W.speed_max, t)
			dmg = roundf(lerpf(W.dmg_min, W.dmg_max, t))
			e.cd = W.nock
			mesh = WeaponModels.make_arrow("bow")
			Sfx.play("bow", e.global_position)
		"crossbow":
			speed = W.speed
			dmg = W.dmg
			e.cd = W.cd
			mesh = WeaponModels.make_arrow("crossbow")
			Sfx.play("xbow", e.global_position)
		"holy":  # 위로 살짝 띄워 던지는 포물선. 맞으면 피해 대신 웅덩이
			speed = W.speed
			dmg = 0.0
			e.cd = W.cd
			e.charges -= 1
			var hg := Node3D.new()
			WeaponModels.make_holy(hg)
			hg.scale = Vector3.ONE * float(GameData.HOLY.size)
			mesh = hg
			Sfx.play("holy_throw", e.global_position)
		"chicken":  # 닭을 던짐 → 다시 원래 무기
			speed = W.speed
			dmg = W.dmg
			e.cd = maxf(e.cd, 0.3)
			var cg: Node3D = WeaponModels.make_chicken().g
			mesh = cg
			e.has_chicken = false
			e.wep = GameData.CLASSES[e.cls].weapon
			e.swap_t = 0.3
			Sfx.play("cluck", e.global_position)
		_:
			push_warning("아직 없는 투사체: " + kind)
			return
	e.fire_anim = 1.0
	var pos: Vector3 = launch.pos if e.is_local else eye + dir * GameData.FIRE_FWD
	var vel := dir * speed
	add_child(mesh)
	mesh.global_position = pos
	if not SPINS.has(kind):
		mesh.global_basis = WeaponModels.face(vel)
	mesh.reset_physics_interpolation()
	if W.has("lift"):
		vel.y += float(W.lift)
	var life: float = float(W.range) / speed if W.has("range") else GameData.PROJ_LIFE
	projectiles.append({
		"kind": kind, "pos": pos, "vel": vel, "grav": float(W.grav), "owner": e, "dmg": dmg,
		"mesh": mesh, "life": life, "radius": float(W.radius),
		"spin": Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15)),
	})
	if mp() and not e.is_remote:  # 친구 화면에도 같은 투사체를 만든다 (맞았는지는 맞은 사람이 판정)
		net.event(["f", Net.WEPS.find(kind), pos, vel, t], e)


## 대물 저격총: 400m 히트스캔, 맞으면 즉사. 5발 쓰면 원래 무기로 — HTML fire('sniper') / hitscan
func _fire_sniper(e: PlayerController, eye: Vector3, dir: Vector3) -> void:
	var I: Dictionary = GameData.ITEM
	var d := dir * float(I.sniper_range)
	var best := world_ray(eye, d)
	var hit_e: PlayerController = null
	var head := false
	for v in ents:
		if v == e or not v.alive or ally(e, v):  # 아군은 그냥 통과
			continue
		var r := hit_test(eye, d, v, I.sniper_r)
		if not r.is_empty() and r.t < best:
			best = r.t
			hit_e = v
			head = r.head
	var end := eye + d * minf(best, 1.0)
	var from := _muzzle(e, eye, dir, 0.22, 0.18)
	if mp() and not e.is_remote:  # 저격총은 쏜 사람 쪽에서 판정해서 알림
		net.event(["sn", from, end, hit_e.peer if hit_e and hit_e.is_remote else 0, head], e)
	fx.tracer(from, end)
	fx.puff(from, 0xffd27a, 0.18, 4)
	if hit_e:
		damage(hit_e, e, I.sniper_kill, "sniper", head, dir, end)
	else:
		fx.puff(end, 0xcdbb98, 0.25, 6)
	e.ammo -= 1
	if e.ammo <= 0:
		e.has_sniper = false
		e.wep = GameData.CLASSES[e.cls].weapon
		e.swap_t = I.empty_swap
		e.cd = 0.1
	else:
		e.cd = I.sniper_cd
	if e.is_local:
		e.shake = GameData.SHAKE.sniper_fire
	Sfx.play("sniper", e.global_position)


## 총알이 나가 보이는 자리: 내 1인칭이면 화면 오른쪽 아래, 아니면 캐릭터 오른손
func _muzzle(e: PlayerController, eye: Vector3, dir: Vector3, right: float, drop: float) -> Vector3:
	if e.is_local and not tp_on():
		var r := Vector3(cos(e.yaw), 0, -sin(e.yaw))
		var f := eye + dir * 0.9 + r * right
		f.y -= drop
		return f
	if e.model and e.model.hand_r:
		return e.model.hand_r.global_position
	return eye


## AK-47: 120m 히트스캔, 거리에 따라 23→18 피해, 퍼짐(움직임·공중·연사), 우클릭 정조준 — HTML fire('ak') / akShot
func _fire_ak(e: PlayerController, eye: Vector3, dir: Vector3) -> void:
	var W: Dictionary = GameData.WEAPONS.ak
	var I: Dictionary = GameData.ITEM
	var ads: bool
	if e.is_local:
		ads = e.aim_held and e.swap_t <= 0
	else:
		ads = e.ai != null and e.ai.target != null and e.ai.target.alive and e.ai.target.global_position.distance_to(e.global_position) > float(I.ak_bot_ads)
	var mv := minf(1.0, Vector2(e.velocity.x, e.velocity.z).length() / 6.0)
	var spr: float
	if ads:
		spr = float(W.ads) + e.bloom * 0.3
	else:
		spr = float(W.hip) * (1 + mv * float(I.ak_move_spread)) + (0.0 if e.grounded else float(I.ak_air_spread)) + e.bloom
	e.bloom = minf(float(W.max_bloom), e.bloom + float(W.bloom))
	var rt := Vector3(cos(e.yaw), 0, -sin(e.yaw))
	var up := rt.cross(dir).normalized()
	var an := randf() * TAU
	var mg := sqrt(randf()) * spr
	dir = (dir + rt * cos(an) * mg + up * sin(an) * mg).normalized()
	var L: float = W.range
	var d := dir * L
	var best := world_ray(eye, d)
	var hit_e: PlayerController = null
	var head := false
	for v in ents:
		if v == e or not v.alive or ally(e, v) or v.global_position.distance_to(eye) > L + 3:
			continue
		var r := hit_test(eye, d, v, I.ak_r)
		if not r.is_empty() and r.t < best:
			best = r.t
			hit_e = v
			head = r.head
	var end := eye + d * minf(best, 1.0)
	var from: Vector3
	if e.is_local and not tp_on():
		from = _muzzle(e, eye, dir, 0.02 if e.aim_held else 0.2, 0.06 if e.aim_held else 0.16)
	else:
		from = _muzzle(e, eye, dir, 0, 0) + dir * 0.75
		fx.puff(from, 0xffd27a, 0.07, 2)
	fx.tracer(from, end, 0xffd27a, 0.012, 0.1, 0.9)
	var dmg := ak_dmg(minf(best, 1.0) * L)
	if mp() and not e.is_remote:
		net.event(["ak", from, end, hit_e.peer if hit_e and hit_e.is_remote else 0, head, dmg], e)
	if hit_e:
		damage(hit_e, e, dmg, "ak", head, dir, end)
	elif best < 1:
		fx.puff(end, 0xcdbb98, 0.07, 2)
	e.cd = W.rate
	e.ak_ammo -= 1
	if e.is_local:
		e.ak_flash = 1.0
	Sfx.play("ak", e.global_position)
	if e.ak_ammo <= 0:
		e.has_ak = false
		e.wep = GameData.CLASSES[e.cls].weapon
		e.swap_t = I.empty_swap
		e.cd = 0.1
		if e.is_local:
			toast.emit("탄창이 비었다! AK-47을 버렸다")


## AK 거리 감쇠: 30m까지 23, 80m에서 18 — HTML akDmg
static func ak_dmg(dist: float) -> float:
	var W: Dictionary = GameData.WEAPONS.ak
	if dist <= float(W.fall0):
		return W.dmg
	return roundf(maxf(float(W.min_dmg), float(W.dmg) - (float(W.dmg) - float(W.min_dmg)) * (dist - float(W.fall0)) / (float(W.fall1) - float(W.fall0))))


# ── 투사체 (HTML updateProjectiles) ──────────────────────────
## 이번 틱 이동 선분 pos→pos+d 로 월드와 캐릭터를 둘 다 검사하고, 먼저 닿는 쪽으로 처리한다.
func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		var pos: Vector3 = p.pos
		var vel: Vector3 = p.vel
		var d := vel * dt
		vel.y -= float(p.grav) * dt
		p.vel = vel
		var tw := world_ray(pos, d)
		var th := INF
		var hit_e: PlayerController = null
		var head := false
		var mid := pos + d * 0.5
		var seg := d.length()
		for v in ents:
			if v == p.owner or not v.alive or ally(p.owner, v) or v.global_position.distance_to(mid) > seg + GameData.PROJ_CULL:
				continue
			var r := hit_test(pos, d, v, p.radius)
			if not r.is_empty() and r.t < th:
				th = r.t
				hit_e = v
				head = r.head
		var mesh: Node3D = p.mesh
		var kind: String = p.kind
		if kind == "chicken" and ((hit_e and th <= tw) or tw <= 1):  # 맞으면 넘어뜨리고, 다시 돌아다님
			var pt := pos + d * minf(th, tw)
			mesh.queue_free()
			fx.chunks(pt, 0xfafaf2, Vector3.UP, 8, 4)
			Sfx.play("cluck", pt)
			if hit_e and th <= tw:
				var cdir := Vector3(vel.x, 0, vel.z).normalized()
				damage(hit_e, p.owner, p.dmg, "chicken", false, cdir, pt)
				if hit_e.alive and hit_e.fall_t <= 0 and hit_e.mounted <= 0 and hit_e.star_t <= 0 and not ally(p.owner, hit_e):
					hit_e.trip()
			items.spawn_chicken(Vector3(pt.x, ground_below(pt), pt.z), GameData.ITEM.chicken_no_pick)
			projectiles.remove_at(i)
			continue
		if kind == "holy" and ((hit_e and th <= tw) or tw <= 1):  # 사람이든 땅이든 닿으면 깨짐
			mesh.queue_free()
			shatter(p.owner, pos + d * minf(th, tw))
			projectiles.remove_at(i)
			continue
		if hit_e and th <= tw:  # 사람에 맞음
			var pt := pos + d * th
			var dir := vel.normalized()
			if kind == "stone":
				mesh.queue_free()
			else:  # 화살은 몸에 꽂힌다
				stick_arrow(mesh, hit_e, head, pt, dir)
			if not hit_e.is_local or tp_on():
				fx.puff(pt, GameData.CLASSES[hit_e.cls].color, 0.14, 7 if head else 4)
				if kind == "stone":
					fx.puff(pt, 0xffffff, 0.08, 3)
			damage(hit_e, p.owner, p.dmg, kind, head, dir, pt)
			projectiles.remove_at(i)
			continue
		if tw <= 1:  # 벽·땅에 맞음
			var pt := pos + d * tw
			if kind == "stone":
				mesh.queue_free()
				fx.puff(pt, 0xcdbb98, 0.1, 3)
			else:  # 화살은 벽·땅에 10초 꽂혀 있다
				var dir := vel.normalized()
				mesh.global_basis = WeaponModels.face(dir)
				mesh.global_position = pt + dir * 0.14
				mesh.reset_physics_interpolation()
				world_arrows.append({"m": mesh, "life": GameData.WORLD_ARROW_LIFE})
				if world_arrows.size() > GameData.WORLD_ARROW_MAX:
					(world_arrows.pop_front().m as Node3D).queue_free()
				fx.puff(pt, 0xcdbb98, 0.08, 2)
			Sfx.play("thunk", pt)
			projectiles.remove_at(i)
			continue
		pos += d
		p.pos = pos
		mesh.global_position = pos
		p.life -= dt
		if SPINS.has(kind):
			var spin: Vector3 = p.spin
			mesh.rotation.x += spin.x * dt
			mesh.rotation.y += spin.y * dt
		else:  # 화살은 날아가는 방향을 본다
			mesh.global_basis = WeaponModels.face(vel)
		if p.life <= 0:  # 사거리 끝
			mesh.queue_free()
			projectiles.remove_at(i)


## 맞은 화살을 머리나 몸통에 붙인다 — HTML stickArrow
func stick_arrow(m: Node3D, v: PlayerController, head: bool, pt: Vector3, dir: Vector3) -> void:
	if not v.model:
		m.queue_free()
		return
	var p: Vector3
	if head:
		var c := v.head_c()
		var off := pt - c
		p = c + (off.normalized() if off.length_squared() > 1e-8 else -dir) * 0.2
	else:
		var a := v.body_a()
		var ab := v.body_b() - a
		var t := clampf((pt - a).dot(ab) / ab.length_squared(), 0, 1)
		var q := a + ab * t
		var off := pt - q
		off.y = 0
		if off.length_squared() < 1e-4:
			off = -dir
			off.y = 0
		p = q + off.normalized() * 0.34
	m.global_basis = WeaponModels.face(dir)
	m.global_position = p + dir * 0.12
	# 모델은 물리 보간을 끄고 매 화면 프레임 움직이니까 화살도 그 설정을 따른다
	m.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	m.reparent(v.model.head if head else v.model.body, true)


func _update_world_arrows(dt: float) -> void:
	for i in range(world_arrows.size() - 1, -1, -1):
		var w := world_arrows[i]
		w.life -= dt
		if w.life <= 0:
			(w.m as Node3D).queue_free()
			world_arrows.remove_at(i)


func kill(v: PlayerController, a: PlayerController, kind: String, head: bool, dir: Vector3) -> void:
	v.deaths += 1
	v.respawn = mode.respawn_time() if mode else GameData.RESPAWN
	if v.star_t > 0:
		end_star(v)
	v.reset_charge()  # 당기던 활 소리도 끔
	if a and a != v and not a.is_remote:  # 친구대전에선 죽인 사람(의 컴퓨터)이 처치 사건을 받고 스스로 센다
		a.kills += 1
	if mp() and not v.is_remote:
		net.event(["k", net.peer_of(a) if a and a != v else 0, Net.WEPS.find(kind), head, dir], v)
	# 말에서 내리고, 들고 있던 저격총·AK·닭은 그 자리에 떨어뜨림
	if v.mounted > 0:
		items.dismount(v)
	if v.has_sniper:  # 친구대전에선 방장 것만 떨어진다 (HTML 그대로)
		if authority():
			items.drop_sniper(v.global_position, v.ammo)
		v.has_sniper = false
	if v.has_ak:
		if authority():
			items.drop_ak(v.global_position, v.ak_ammo)
		v.has_ak = false
	if v.has_chicken:
		v.has_chicken = false
		items.spawn_chicken(v.global_position, 1.0)
	_ragdoll(v, kind, dir)
	v.die(dir)
	if a and a.is_local and a != v:
		hitmark.emit(true)
		Sfx.play("kill")
		toast.emit(("헤드샷 처치 · " if head else "처치 · ") + v.ent_name)
	if v.is_bot and randf() < GameData.BOT_RECLASS:
		v.next_cls = GameData.bot_classes().pick_random()
	killed.emit(v, a, kind, head)  # 킬피드·사망 화면·20킬 종료는 Main이 받는다


## 몸은 래그돌이 되어 날아간다 (모델은 다음 부활 때 새로 만든다)
func _ragdoll(v: PlayerController, kind: String, dir: Vector3) -> void:
	if v.model:
		var rd := Ragdoll.make(v.model, kind, dir, v.velocity, self, world.aabbs)
		ragdolls.append(rd)
		v.ragdoll = rd
		v.model.queue_free()
		v.model = null


# ── 친구대전: 친구 컴퓨터에서 온 사건 (HTML remoteFire / handleEvent) ──
## 친구가 쏜 투사체를 내 화면에도 만든다. 나한테 맞으면 내 쪽에서 피해를 판정한다
func remote_fire(e: PlayerController, kind: String, pos: Vector3, vel: Vector3, t: float) -> void:
	var W: Dictionary = GameData.WEAPONS[kind]
	var mesh: Node3D
	var dmg := 0.0
	match kind:
		"stone":
			var mi := MeshInstance3D.new()
			mi.mesh = Meshes.stone()
			mi.material_override = GameData.mat(W.color)
			mi.scale = Vector3.ONE * float(W.size)
			mesh = mi
			dmg = W.dmg
			Sfx.play("throw", pos)
		"bow":
			mesh = WeaponModels.make_arrow("bow")
			dmg = roundf(lerpf(W.dmg_min, W.dmg_max, t))
			Sfx.play("bow", pos)
			e.rec_v += 5 + 4 * t
		"crossbow":
			mesh = WeaponModels.make_arrow("crossbow")
			dmg = W.dmg
			Sfx.play("xbow", pos)
			e.rec_v += 10
			e.cd = W.cd
			e.xb_last = 0.0
		"holy":
			var hg := Node3D.new()
			WeaponModels.make_holy(hg)
			hg.scale = Vector3.ONE * float(GameData.HOLY.size)
			mesh = hg
			Sfx.play("holy_throw", pos)
		_:
			return
	e.fire_anim = 1.0
	add_child(mesh)
	mesh.global_position = pos
	if not SPINS.has(kind):
		mesh.global_basis = WeaponModels.face(vel)
	mesh.reset_physics_interpolation()
	var speed := maxf(1.0, vel.length())
	projectiles.append({
		"kind": kind, "pos": pos, "vel": vel, "grav": float(W.grav), "owner": e, "dmg": dmg,
		"mesh": mesh, "life": float(W.range) / speed if W.has("range") else GameData.PROJ_LIFE, "radius": float(W.radius),
		"spin": Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15)),
	})


## 친구가 저격총·AK를 쏨: 궤적·불꽃·소리만 (맞았는지는 쏜 사람이 정해서 같이 보냄)
func remote_shot(e: PlayerController, kind: String, from: Vector3, end: Vector3) -> void:
	e.fire_anim = 1.0
	if kind == "sniper":
		fx.tracer(from, end)
		fx.puff(from, 0xffd27a, 0.18, 4)
		Sfx.play("sniper", from)
	else:
		fx.tracer(from, end, 0xffd27a, 0.012, 0.1, 0.9)
		fx.puff(from, 0xffd27a, 0.07, 2)
		Sfx.play("ak", from)
		e.rec_v += 1.2


## 친구 음유시인이 팡파레를 붊: 효과는 그대로, 나(방장이면 내 봇도)가 앞에 있었으면 내 쪽에서 판정
func remote_fanfare(e: PlayerController) -> void:
	Trumpet.fanfare_fx(self, e)
	for v in ents:
		if v.alive and not v.is_remote:
			Trumpet.hit_fanfare(self, e, v)


## 친구가 맞음 (친구 쪽에서 판정해서 알려줌): 맞은 효과·숫자·히트마크
func remote_hit(e: PlayerController, a: PlayerController, dmg: float, kind: String, head: bool) -> void:
	e.flash = 0.14
	e.hit_squash = 1.0
	var dir := Vector3(0, 0, 1)
	if a:
		dir = Vector3(e.global_position.x - a.global_position.x, 0, e.global_position.z - a.global_position.z)
		dir = dir.normalized() if dir.length_squared() > 1e-4 else Vector3(0, 0, 1)
	var pt := e.global_position + Vector3(0, e.mount_h + (1.6 if head else 1.0), 0)
	impact_fx(e, a, pt, kind, head, dir, dmg, false)
	if a and a.is_local:
		hitmark.emit(false)
		if kind != "holy" and kind != "trumpet":
			Sfx.play("head" if head else "hit")


## 친구가 죽음: 래그돌·킬피드, 내가 죽였으면 내 처치 +1
func remote_kill(e: PlayerController, a: PlayerController, kind: String, head: bool, dir: Vector3) -> void:
	if not e.horse.is_empty() or e.mounted > 0:
		items.dismount(e)
	_ragdoll(e, kind, dir)
	e.die(dir)
	if a and not a.is_remote:  # 나 (방장이면 내 봇도)
		a.kills += 1
	if a and a.is_local:
		hitmark.emit(true)
		Sfx.play("kill")
		toast.emit(("헤드샷 처치 · " if head else "처치 · ") + e.ent_name)
	killed.emit(e, a, kind, head)


# ── 날아간 투구 ──────────────────────────────────────────────
func knock_helmet(v: PlayerController, dir: Vector3) -> void:
	v.helmet = false
	if not v.model or not v.model.helm:
		return
	var hm := v.model.detach_helm()
	hm.reparent(self, true)
	hm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	hm.reset_physics_interpolation()
	loose_helms.append({
		"o": hm,
		"v": Vector3(dir.x * 4 + randf_range(-1, 1), randf_range(4.5, 6.5), dir.z * 4 + randf_range(-1, 1)),
		"w": Vector3(randf_range(-12, 12), randf_range(-8, 8), randf_range(-12, 12)),
		"life": 15.0, "s0": hm.scale.x, "rest": false,
	})
	Sfx.play("clang", v.global_position)


func _update_helms(dt: float) -> void:
	for i in range(loose_helms.size() - 1, -1, -1):
		var h := loose_helms[i]
		var o: Node3D = h.o
		h.life -= dt
		if not h.rest:
			var vel: Vector3 = h.v
			var w: Vector3 = h.w
			vel.y -= GameData.GRAV * dt
			o.position += vel * dt
			o.rotation += w * dt
			var gy := ground_below(o.position) - 0.2
			if o.position.y < gy:
				o.position.y = gy
				if vel.y < -2.5:  # 통통 튀다가
					vel.y *= -0.35
					vel.x *= 0.6
					vel.z *= 0.6
					w *= 0.5
				else:  # 멈춤
					h.rest = true
			h.v = vel
			h.w = w
		if h.life < 0.6:
			o.scale = Vector3.ONE * h.s0 * maxf(0.01, h.life / 0.6)
		if h.life <= 0:
			o.queue_free()
			loose_helms.remove_at(i)


# ── 성수 웅덩이 (HTML shatter / updateZones / updateHolyAim) ──
## 바닥에 까는 반투명 원판·고리 머티리얼 (HTML MeshBasicMaterial, depthWrite false)
func _flat_mat(hex: int, alpha: float, prio: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(GameData.col(hex), alpha)
	m.render_priority = prio
	return m


func _flat(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3.ONE * 0.01
	add_child(m)
	m.global_position = pos
	m.reset_physics_interpolation()
	return m


## 성수병이 깨짐: 유리 조각·김·링, 그리고 발밑 땅에 웅덩이
func shatter(thrower: PlayerController, pt: Vector3) -> void:
	var W: Dictionary = GameData.WEAPONS.holy
	var H: Dictionary = GameData.HOLY
	var gy := ground_below(pt)
	var c := Vector3(pt.x, gy, pt.z)
	fx.chunks(pt, 0xbfefff, Vector3.UP, 7, 4)
	fx.puff(pt, 0xe8fbff, 0.16, 6)
	fx.ring(Vector3(pt.x, gy + 0.2, pt.z), 0xffe07a, 1.6, 0.3)
	Sfx.play("glass", pt)
	var disc := _flat(Meshes.disc(), _flat_mat(H.disc, H.disc_alpha, 2), Vector3(c.x, gy + 0.03, c.z))
	var mine := thrower != null and thrower.is_local
	var rim_hex: int = H.rim_mine if mine else H.rim_enemy
	if thrower and thrower.team != "" and me and me.team != "":  # 쟁탈전: 우리 팀 파랑·적 팀 빨강
		rim_hex = GameData.team_hex("blue", "accent") if thrower.team == me.team else GameData.team_hex("red", "body")
	var rim := _flat(Meshes.flat_ring(), _flat_mat(rim_hex, H.rim_alpha, 3), Vector3(c.x, gy + 0.04, c.z))
	zones.append({"owner": thrower, "pos": c, "r": float(W.area), "life": float(W.dur), "tick": float(H.first_tick),
		"disc": disc, "rim": rim, "t": 0.0})


## v가 웅덩이 z 안에 있나 (가로 반경 + 테두리, 높이 범위)
func _in_zone(z: Dictionary, v: PlayerController) -> bool:
	var H: Dictionary = GameData.HOLY
	var zp: Vector3 = z.pos
	var p := v.global_position
	var flat := Vector2(p.x - zp.x, p.z - zp.z).length()
	return flat < float(z.r) + float(H.edge) and p.y > zp.y - float(H.y_below) and p.y < zp.y + float(H.y_above)


func update_zones(dt: float) -> void:
	var W: Dictionary = GameData.WEAPONS.holy
	var H: Dictionary = GameData.HOLY
	var healed := {}
	for i in range(zones.size() - 1, -1, -1):
		var z := zones[i]
		z.life -= dt
		z.t += dt
		z.tick -= dt
		var t: float = z.t
		var zr: float = z.r
		var zp: Vector3 = z.pos
		var thrower: PlayerController = z.owner
		# 퍼지면서 나타나고, 끝날 때 흐려짐. 테두리는 살짝 일렁임
		var grow := minf(1.0, t / float(H.grow))
		var fade := clampf(float(z.life) / float(H.fade), 0, 1)
		var sc := zr * (0.4 + 0.6 * grow)
		var disc: MeshInstance3D = z.disc
		var rim: MeshInstance3D = z.rim
		disc.scale = Vector3.ONE * sc
		rim.scale = Vector3.ONE * sc * (1 + sin(t * 6) * 0.03)
		(disc.material_override as StandardMaterial3D).albedo_color.a = float(H.disc_alpha) * fade
		(rim.material_override as StandardMaterial3D).albedo_color.a = float(H.rim_alpha) * fade
		if randf() < dt * 14:  # 반짝이
			var a := randf_range(0, TAU)
			var rr := sqrt(randf()) * zr
			fx.puff(Vector3(zp.x + cos(a) * rr, zp.y + 0.1, zp.z + sin(a) * rr), 0xffe07a if randf() < 0.5 else 0xffffff, 0.05, 1)
		# 안에 있으면 느려짐 (던진 사람은 빼고)
		for v in ents:
			if not v.alive or v == thrower or ally(thrower, v) or not _in_zone(z, v):
				continue
			if v.star_t > 0:  # 황금 붕어빵 무적: 둔화 안 걸림
				continue
			v.slow_t = float(H.slow_hold)
			if (not v.is_local or tp_on()) and randf() < dt * 6:
				var vp := v.global_position
				fx.puff(Vector3(vp.x + randf_range(-0.3, 0.3), vp.y + 0.15, vp.z + randf_range(-0.3, 0.3)), 0x9fe4ff, 0.07, 1)
		# 닿아 있는 동안 회복: 던진 사람 (개인전도), 쟁탈전은 같은 팀도 (사용자 요청). 웅덩이가 겹쳐도 한 번만
		for v in ents:
			if v.alive and not v.is_remote and not healed.has(v) and (v == thrower or ally(thrower, v)) and _in_zone(z, v):
				healed[v] = true
				v.hp = minf(float(GameData.class_hp(v.cls)), v.hp + float(W.heal) * dt)
		# 0.5초마다 지짐
		if z.tick <= 0:
			z.tick += float(W.tick_every)
			for v in ents:
				if not v.alive or v == thrower or ally(thrower, v) or not _in_zone(z, v):
					continue
				var vp := v.global_position
				var off := Vector3(vp.x - zp.x, 0, vp.z - zp.z)
				var dir := off.normalized() if off.length() > 0.01 else Vector3(1, 0, 0)
				damage(v, thrower, float(W.dmg), "holy", false, dir, vp + Vector3(0, 1, 0))
		if z.life <= 0:
			disc.queue_free()
			rim.queue_free()
			zones.remove_at(i)


## 성수 착지 지점 표시 — 던질 궤적을 미리 따라가 땅에 닿는 곳에 고리. 대기 중이거나 빈 병이면 흐리게.
func _process(dt: float) -> void:
	_tick_hit_stop(dt)
	var e: PlayerController = null
	for v in ents:
		if v.is_local:
			e = v
			break
	if not e or not e.alive or e.wep != "holy" or e.fall_t > 0 or not e.cam:
		aim_mk.visible = false
		return
	var W: Dictionary = GameData.WEAPONS.holy
	var H: Dictionary = GameData.HOLY
	var L := local_launch(e, "holy")  # 실제로 던질 때와 같은 자리·방향
	var dir: Vector3 = L.dir
	var p: Vector3 = L.pos
	var v := dir * float(W.speed)
	v.y += float(W.lift)
	var step: float = H.aim_dt
	var hit: Variant = null
	for i in int(H.aim_steps):
		var d := v * step
		v.y -= float(W.grav) * step
		var t := world_ray(p, d)
		if t <= 1:
			hit = p + d * t
			break
		p += d
	if hit == null:
		aim_mk.visible = false
		return
	var hp: Vector3 = hit
	aim_mk.global_position = Vector3(hp.x, ground_below(hp) + 0.05, hp.z)
	aim_mk.scale = Vector3.ONE * float(W.area)
	var off: bool = e.cd > 0 or e.charges <= 0
	(aim_mk.material_override as StandardMaterial3D).albedo_color.a = float(H.aim_alpha_off) if off else float(H.aim_alpha)
	aim_mk.visible = true
