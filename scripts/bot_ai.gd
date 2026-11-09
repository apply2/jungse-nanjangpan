class_name BotAI
extends RefCounted
## 봇 머리 — HTML botUpdate() / aimSolve() 이식. 봇 하나에 하나씩 (PlayerController.ai).
## 매 물리 프레임 update()가 몸(yaw·pitch)을 돌리고, 사람 입력과 같은 모양의 딕셔너리를 돌려준다:
##   {wish: 월드 이동 방향, jump, crouch, sprint, fire}
## 그러면 PlayerController가 사람과 똑같이 movement()를 돌리고, Combat이 weapon_update()로 쏜다.
## 수치는 GameData.BOT(공통)·GameData.DIFF(난이도)에 있다.
## 저격총·AK·말이 가까이 있으면 주우러 가고(goItem/goAK/goHorse), 말을 타면 대상에게 돌진한다.

# HTML e.ai 필드
var think := 0.0
var target: PlayerController = null
var vis := false
var react := 0.0
var lead := 0.5
var fire_ok := true
var strafe := 1.0
var strafe_t := 0.0
var stuck := 0.0
var unstuck_t := 0.0
var unstuck_dir := Vector3.ZERO
var wander: Variant = null   # Vector3 또는 null
var ex := 0.0                # 이번 생각의 조준 오차 (가로·세로)
var ey := 0.0
var err := 0.04
var want_charge := 0.6       # 활을 이만큼(초) 당기고 놓음
var slide_hold := 0.0
var aim_head := false
var sm := Vector3.ZERO       # 부드럽게 만든 이동 방향
var resting := false         # 음유시인: 숨 고르는 중 (연주 멈추고 거리를 벌림)


## 정규분포 난수 — HTML gauss()
static func gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0:
		u = randf()
	while v == 0.0:
		v = randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)


static func rr(a: Array) -> float:
	return randf_range(float(a[0]), float(a[1]))


## 부활할 때 — HTML spawn()의 Object.assign(e.ai, ...)
func reset(world_point: Vector3) -> void:
	target = null
	vis = false
	react = 0.5
	resting = false
	stuck = 0.0
	unstuck_t = 0.0
	wander = world_point


## 맞으면 때린 사람을 바로 노림 — HTML damage() 마지막 줄
func on_hit(a: PlayerController) -> void:
	target = a
	vis = true
	react = minf(react, float(GameData.BOT.hit_react))


func update(e: PlayerController, combat: Combat, dt: float) -> Dictionary:
	var B: Dictionary = GameData.BOT
	var D: Dictionary = GameData.DIFF[GameData.difficulty]
	var epos := e.global_position
	think -= dt
	strafe_t -= dt
	react -= dt
	# ── 생각: 대상 고르기, 조준 오차 굴리기 ──
	if think <= 0:
		think = rr(B.think)
		var best: PlayerController = null
		var bs := 1e9
		var bv := false
		var eye := e.eye_pos()
		for o in combat.ents:
			if o == e or not o.alive:
				continue
			var d := o.global_position.distance_to(epos)
			if d > float(B.sight):
				continue
			var v := combat.los(eye, o.eye_pos())
			var s := d * (1.0 if v else float(B.hidden_mul)) - (float(B.keep_bonus) if o == target else 0.0)
			if s < bs:
				bs = s
				best = o
				bv = v
		if best != target:
			target = best
			react = rr(D.react)
		vis = bv
		var base: float
		if e.wep == "sniper":
			base = D.sniper_err
		elif e.wep == "ak":
			base = float(D.sniper_err) * float(B.ak_err)
		else:
			base = rr(B.err) * float(D.err)
		var mv := 1.0
		if best:
			mv = 1.0 + minf(Vector2(best.velocity.x, best.velocity.z).length() / 6.0, 1.0) * float(B.err_move)
		err = base * mv
		ex = gauss() * err
		ey = gauss() * err * float(B.err_y)
		aim_head = randf() < float(D.head)
		lead = rr(D.lead)
		fire_ok = randf() < float(D.fire)
		if best:
			want_charge = clampf(best.global_position.distance_to(epos) / float(B.charge_dist), float(B.charge_min), 1.0) * float(GameData.WEAPONS.bow.full)
		if wander == null or epos.distance_to(wander) < float(B.wander_reach):
			wander = combat.world.random_point()
	if strafe_t <= 0:
		strafe_t = rr(B.strafe_t)
		strafe = 0.0 if randf() < float(B.strafe_stop) else (-1.0 if randf() < 0.5 else 1.0)
	var t: PlayerController = target if target and target.alive else null
	# ── 어디로 갈지 ──
	var move := Vector3.ZERO
	var want_fire := false
	var want_fan := false   # 음유시인 팡파레 (우클릭)
	var aim := {}
	var wp: Vector3 = wander if wander != null else epos
	var it: Items = combat.items
	var busy := t != null and vis and t.global_position.distance_to(epos) < float(B.item_busy)
	var free_hands := not e.has_sniper and not e.has_ak
	var go_item: bool = it.sniper.active and free_hands and epos.distance_to(it.sniper.pos) < float(B.item_seek) and not busy
	var go_ak: bool = it.ak.active and free_hands and epos.distance_to(it.ak.pos) < float(B.item_seek) and not busy
	var go_horse: bool = it.horse.active and e.mounted <= 0 and epos.distance_to(it.horse.pos) < float(B.horse_seek) and not busy
	if e.mounted > 0:
		move = (Vector3(t.global_position.x - epos.x, 0, t.global_position.z - epos.z)) if t else wp - epos
	elif go_horse:
		move = (it.horse.pos as Vector3) - epos
	elif go_item:
		move = (it.sniper.pos as Vector3) - epos
	elif go_ak:
		move = (it.ak.pos as Vector3) - epos
	elif t:
		var to := Vector3(t.global_position.x - epos.x, 0, t.global_position.z - epos.z)
		var d := to.length()
		to = to.normalized()
		var pref: float
		if e.wep == "sniper":
			pref = B.pref_sniper
		elif e.wep == "ak":
			pref = B.pref_ak
		else:
			pref = B.pref[e.cls]
		if not vis:
			move = to
		else:
			var band: float = B.pref_band
			if d > pref + band:
				move += to
			elif d < pref - band:
				move -= to
			move += Vector3(-to.z, 0, to.x) * strafe * float(B.strafe_k)
	else:
		move = wp - epos
	if e.mounted > 0:
		if t:  # 말 타면 앞질러 돌진
			var L: float = B.mount_lead
			var tp := t.global_position + t.velocity * L
			aim = {"yaw": atan2(-(tp.x - epos.x), -(tp.z - epos.z)), "pitch": 0.0}
	elif t and vis:
		aim = aim_solve(e, t)
		var d := t.global_position.distance_to(epos)
		var fr: Dictionary = B.fire_range
		if e.wep == "trumpet":  # 음유시인: 가까우면 불고, 붙으면 팡파레, 숨이 모자라면 쉰다
			want_fire = react <= 0 and not resting and d < float(B.bard_play)
			want_fan = react <= 0 and d < float(B.bard_fanfare) and e.fan_cd <= 0
		else:
			want_fire = react <= 0 and (fire_ok or e.wep == "chicken") and (d < float(fr[e.wep]) if fr.has(e.wep) else true)
	# 음유시인 숨 관리: 0.5초 남으면 멈추고, 다 찰 때까지 대상에게서 물러남
	if e.wep == "trumpet":
		if e.playing and e.breath <= float(B.bard_breath_stop):
			resting = true
		elif resting and e.breath >= float(GameData.WEAPONS.trumpet.breath_max) - 0.05:
			resting = false
		if resting and t and e.mounted <= 0:
			var away := Vector3(epos.x - t.global_position.x, 0, epos.z - t.global_position.z)
			if away.length_squared() > 1e-4:
				move = away.normalized() + Vector3(-away.z, 0, away.x).normalized() * strafe * 0.5
	else:
		resting = false
	# 말 탄 사람 피하기
	if e.mounted <= 0:
		for o in combat.ents:
			if o == e or not o.alive or o.mounted <= 0:
				continue
			var ox := epos.x - o.global_position.x
			var oz := epos.z - o.global_position.z
			var od := Vector2(ox, oz).length()
			if od < float(B.knight_avoid) and od > 0.001:
				move += Vector3(-oz / od, 0, ox / od) * 1.6 + Vector3(ox / od, 0, oz / od) * 0.8
	# 남의 성수 웅덩이에선 밖으로
	for z in combat.zones:
		if z.owner == e:
			continue
		var zp: Vector3 = z.pos
		var zx := epos.x - zp.x
		var zz := epos.z - zp.z
		var zd := Vector2(zx, zz).length()
		if zd < float(z.r) + float(B.zone_margin):
			var k := zd if zd > 0 else 1.0
			move = Vector3(zx / k, 0, zz / k)
			break
	move.y = 0
	if move.length_squared() > 0.01:
		move = move.normalized()
	# 방향을 부드럽게 틀어서 급회전 넘어짐을 줄임
	sm = sm.lerp(move, minf(1.0, dt * float(B.smooth)))
	if move.length_squared() > 0.01 and sm.length_squared() > 0.0004:
		move = sm.normalized()
	elif move.length_squared() <= 0.01:
		move = Vector3.ZERO
	# 끼임 탈출: 가려는데 못 가면 점프, 오래 끼면 아무 방향으로
	var hs := Vector2(e.velocity.x, e.velocity.z).length()
	if move.length_squared() > 0.1 and hs < float(B.stuck_speed) and e.grounded:
		stuck += dt
	else:
		stuck = maxf(0.0, stuck - dt * 2)
	var jump := false
	if stuck > float(B.stuck_jump):
		jump = true
		if stuck > float(B.stuck_turn):
			var a := randf_range(0, TAU)
			unstuck_dir = Vector3(sin(a), 0, cos(a))
			unstuck_t = B.unstuck_t
			stuck = 0.0
	if unstuck_t > 0:
		unstuck_t -= dt
		move = unstuck_dir
	# 야만인은 빠를 때 가끔 점프·슬라이드, 다른 병과는 가끔 점프
	if e.cls == "barbarian" and not e.has_sniper and move.length_squared() > 0.1:
		if hs > GameData.BASE_SPEED * 0.9:
			jump = jump or randf() < dt * float(B.barb_jump)
		if e.grounded and hs > GameData.BASE_SPEED * 1.15 and slide_hold <= 0 and randf() < dt * float(B.barb_slide):
			slide_hold = B.slide_hold
	elif randf() < dt * float(B.rand_jump):
		jump = true
	slide_hold -= dt
	var crouch := slide_hold > 0
	# ── 조준 회전 (난이도별 속도 제한) ──
	var dy: float
	var dp: float
	if not aim.is_empty():
		dy = aim.yaw
		dp = aim.pitch
	elif move.length_squared() > 0.1:
		dy = atan2(-move.x, -move.z)
		dp = 0.0
	else:
		dy = e.yaw
		dp = 0.0
	var diff := fposmod(dy - e.yaw + PI, TAU) - PI
	var rate := (float(D.turn) if not aim.is_empty() else float(B.turn_idle)) * dt
	e.yaw += clampf(diff, -rate, rate)
	e.pitch += clampf(dp - e.pitch, -rate, rate)
	var align_lim := float(B.aligned_sniper) if e.wep == "sniper" else float(B.aligned)
	if e.wep == "trumpet":  # 원뿔이 넓으니 반각 안쪽(60%)에만 들어오면 분다
		align_lim = deg_to_rad(float(GameData.WEAPONS.trumpet.half_angle)) * 0.6
	var aligned := absf(diff) < align_lim and (e.wep == "trumpet" or absf(dp - e.pitch) < float(B.aligned_pitch))
	# 멀리 있는 적을 쫓을 때만 달림
	var sprint := t != null and not want_fire and not e.charging and t.global_position.distance_to(epos) > float(B.sprint_dist)
	var held: bool
	if e.wep == "bow":  # 원하는 만큼 당겼으면 놓는다
		held = (want_fire and aligned and (e.cd > 0 or e.charge < want_charge)) or (e.charging and e.charge < want_charge and want_fire)
	else:
		held = want_fire and aligned
	return {"wish": move, "jump": jump, "crouch": crouch, "sprint": sprint, "fire": held, "aim": want_fan and aligned}


## 맞히려면 어디를 봐야 하나 — HTML aimSolve(). {yaw, pitch} (오차 ex·ey 포함)
## 춤추는 봇은 조준 오차가 DANCE.bot_err배 (4.5단계)
func aim_solve(e: PlayerController, t: PlayerController) -> Dictionary:
	var a := _aim_solve(e, t)
	if e.dance_t > 0:
		var m := float(GameData.DANCE.bot_err) - 1.0
		a.yaw += ex * m
		a.pitch += ey * m
	return a


func _aim_solve(e: PlayerController, t: PlayerController) -> Dictionary:
	var B: Dictionary = GameData.BOT
	var eye := e.eye_pos()
	var tpos := t.global_position
	var tvel := t.velocity
	var target_pt := tpos + Vector3(0, float(B.aim_head) if aim_head or e.wep == "sniper" else float(B.aim_body), 0)
	if e.wep == "sniper" or e.wep == "ak" or e.wep == "trumpet":  # 히트스캔·트럼펫 원뿔: 곧장
		var d := target_pt - eye
		return {"yaw": atan2(-d.x, -d.z) + ex, "pitch": atan2(d.y, Vector2(d.x, d.z).length()) + ey}
	if e.wep == "holy" or e.wep == "chicken":  # 포물선: 발밑(닭은 0.9 높이)에 떨어질 각도를 훑어서 찾음
		var W: Dictionary = GameData.WEAPONS[e.wep]
		var L := float(B.lob_lead) * lead
		var tg := Vector3(tpos.x + tvel.x * L, tpos.y + (0.9 if e.wep == "chicken" else 0.0), tpos.z + tvel.z * L)
		var dx := Vector2(tg.x - eye.x, tg.z - eye.z).length()
		var dyy := tg.y - eye.y
		var lp: Array = B.lob_pitch
		var best := 0.2
		var be := 1e9
		var pp: float = lp[0]
		while pp <= float(lp[1]) + 1e-6:
			var vh := float(W.speed) * cos(pp)
			var v0 := float(W.speed) * sin(pp) + float(W.lift)
			var tt := dx / vh
			var y := v0 * tt - 0.5 * float(W.grav) * tt * tt
			var er := absf(y - dyy)
			if er < be:
				be = er
				best = pp
			pp += float(lp[2])
		return {"yaw": atan2(-(tg.x - eye.x), -(tg.z - eye.z)) + ex, "pitch": best + ey}
	# 화살·돌·볼트: 날아가는 동안 움직일 만큼 앞질러 + 중력 포물선 공식(낮은 각)
	var W2: Dictionary = GameData.WEAPONS[e.wep]
	var v: float
	if e.wep == "bow":
		v = lerpf(W2.speed_min, W2.speed_max, want_charge / float(W2.full))
	else:
		v = W2.speed
	var g: float = W2.grav
	var pred := target_pt
	for i in 2:
		var fl := pred.distance_to(eye) / v
		pred = Vector3(target_pt.x + tvel.x * fl * lead, target_pt.y, target_pt.z + tvel.z * fl * lead)
	var dx2 := Vector2(pred.x - eye.x, pred.z - eye.z).length()
	var dy2 := pred.y - eye.y
	var disc := pow(v, 4) - g * (g * dx2 * dx2 + 2 * dy2 * v * v)
	var pitch := PI / 4 if disc < 0 else atan((v * v - sqrt(disc)) / (g * dx2))
	return {"yaw": atan2(-(pred.x - eye.x), -(pred.z - eye.z)) + ex, "pitch": pitch + ey}
