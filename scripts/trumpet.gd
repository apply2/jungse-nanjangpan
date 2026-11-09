class_name Trumpet
extends RefCounted
## 음유시인 트럼펫 + 춤 디버프 (4.5단계 — HTML에 없는 새 무기라 CLAUDE.md "음유시인 명세"가 기준).
## 수치는 GameData.WEAPONS.trumpet·WEAPONS.fanfare·DANCE.
##
## 연주(좌클릭): 누르는 동안 앞쪽 원뿔 안의 적이 피해를 받고, 오래 들으면 춤춘다.
##   피해·춤은 "듣는 쪽"마다 계산한다 (update_victims). 친구대전에서 맞은 사람 쪽이 판정하는 규칙과 같은 코드로 돈다:
##   연주자의 위치·yaw·pitch·연주 중 비트만 있으면 내가 원뿔 안인지 직접 계산할 수 있다.
## 팡파레(우클릭): 가까운 앞쪽에 한 번 크게 — 쏜 쪽에서 효과를 내고, 친구대전에선 사건 하나("fan")로 보내 맞은 쪽이 판정한다.


## 원뿔 판정 (순수 계산): from에서 dir(단위 벡터) 쪽으로 거리 rng, 반각 half_deg(도) 안에 pt가 있나
static func in_cone(from: Vector3, dir: Vector3, pt: Vector3, rng: float, half_deg: float) -> bool:
	var d := pt - from
	var L := d.length()
	if L > rng:
		return false
	if L < 0.001:
		return true
	return dir.dot(d / L) >= cos(deg_to_rad(half_deg))


## e가 부는 소리(또는 팡파레)가 v에게 닿나 — 몸이나 머리가 원뿔 안에 있고, 벽에 안 막혀야 한다
static func reaches(combat: Combat, e: PlayerController, v: PlayerController, rng: float, half_deg: float) -> bool:
	if v == e or not v.alive:
		return false
	var eye := e.eye_pos()
	var dir := e.aim_dir()
	var body := v.global_position + Vector3(0, v.mount_h + 1.0, 0)
	var head := v.head_c()
	var b_in := in_cone(eye, dir, body, rng, half_deg)
	var h_in := in_cone(eye, dir, head, rng, half_deg)
	if not b_in and not h_in:
		return false
	return (b_in and combat.los(eye, body)) or (h_in and combat.los(eye, head))


static func _push_dir(e: PlayerController, v: PlayerController) -> Vector3:
	var d := v.global_position - e.global_position
	d.y = 0
	if d.length_squared() < 1e-4:
		var a := e.aim_dir()
		d = Vector3(a.x, 0, a.z)
	return d.normalized()


# ── 연주자 쪽: 숨·삑사리·헐떡임 (Combat.weapon_update가 음유시인마다 부름) ──
## want = 지금 불고 싶나 (좌클릭을 누르고 있고, 트럼펫을 들고, 넘어지지 않음)
static func update(combat: Combat, e: PlayerController, want: bool, dt: float) -> void:
	var W: Dictionary = GameData.WEAPONS.trumpet
	e.gasp_t = maxf(0.0, e.gasp_t - dt)
	e.squeak_t = maxf(0.0, e.squeak_t - dt)
	e.fan_cd = maxf(0.0, e.fan_cd - dt)
	if e.gasp_t > 0 or e.squeak_t > 0:
		want = false
	if want and not e.playing:  # 불기 시작할 때마다 삑사리 확률
		var ch: float = GameData.squeak_override if GameData.squeak_override >= 0 else float(W.squeak_chance)
		if randf() < ch:
			e.squeak_t = W.squeak_t
			want = false
			Sfx.play("squeak", e.global_position)
			if e.is_local:
				combat.toast.emit("삑사리!")
		else:
			e.playing = true
	if not want:
		e.playing = false
	if e.playing:
		e.breath -= dt
		if e.breath <= 0:
			e.breath = 0.0
			e.playing = false
			e.gasp_t = W.gasp_t
			Sfx.play("gasp", e.global_position)
			if e.is_local:
				combat.toast.emit("숨이 찼다!")
	else:
		e.breath = minf(float(W.breath_max), e.breath + float(W.breath_regen) * dt)


# ── 팡파레 (우클릭) ──────────────────────────────────────────
static func try_fanfare(combat: Combat, e: PlayerController) -> void:
	if e.fan_cd > 0 or e.gasp_t > 0:
		return
	e.fan_cd = GameData.WEAPONS.fanfare.cd
	e.playing = false
	fanfare_fx(combat, e)
	for v in combat.ents:
		if not v.is_remote:  # 친구 캐릭터는 친구 컴퓨터가 판정 (아래 사건을 받고)
			hit_fanfare(combat, e, v)
	if combat.mp() and e.is_local:
		combat.net.event(["fan"])


static func hit_fanfare(combat: Combat, e: PlayerController, v: PlayerController) -> void:
	var F: Dictionary = GameData.WEAPONS.fanfare
	if reaches(combat, e, v, F.range, F.half_angle):
		combat.damage(v, e, F.dmg, "fanfare", false, _push_dir(e, v))


static func fanfare_fx(combat: Combat, e: PlayerController) -> void:
	e.fire_anim = 1.0
	e.rec_v += 6.0
	if e.is_local:
		e.vm_kick = 1.0
		combat.toast.emit("빠바밤!")
	Sfx.play("fanfare", e.global_position)
	if not e.is_local or combat.tp_on():
		var p := e.eye_pos() + e.aim_dir() * 1.3
		combat.fx.ring(p, 0xf3b33d, 2.4, 0.3)
		combat.fx.puff(p, 0xfff1b0, 0.12, 6)


# ── 듣는 쪽: 피해 주기·춤 (Combat._physics_process가 매 프레임) ──
static func update_victims(combat: Combat, dt: float) -> void:
	var W: Dictionary = GameData.WEAPONS.trumpet
	var D: Dictionary = GameData.DANCE
	var now := combat.clock
	var bards: Array[PlayerController] = []
	for b in combat.ents:
		if b.alive and b.playing:
			bards.append(b)
	for v in combat.ents:
		if v.is_remote or not v.alive:  # 친구 캐릭터의 춤·피해는 친구 컴퓨터가 정한다
			continue
		var heard := false
		var ticks := {}
		for b in bards:
			if not reaches(combat, b, v, W.range, W.half_angle):
				continue
			heard = true
			var acc: float = float(v.tr_ticks.get(b, 0.0)) + dt
			if acc >= float(W.tick):
				acc -= float(W.tick)
				combat.damage(v, b, W.dmg, "trumpet", false, _push_dir(b, v), v.global_position + Vector3(0, v.mount_h + 1.3, 0))
			ticks[b] = acc
		v.tr_ticks = ticks
		if not v.alive:
			continue
		_dance_tick(combat, v, heard, now, dt)
		if v.is_local and not v.is_bot:  # 춤추는 동안 내 조준이 좌우로 출렁 (봇은 조준 오차로 대신)
			var sway := sin(now * TAU * float(D.sway_hz)) * float(D.sway) if v.dance_t > 0 else 0.0
			v.yaw += sway - v.dance_sway
			v.dance_sway = sway


static func _dance_tick(combat: Combat, v: PlayerController, heard: bool, now: float, dt: float) -> void:
	var D: Dictionary = GameData.DANCE
	if v.dance_t > 0:
		v.dance_t -= dt
		if v.fall_t > 0:  # 넘어짐이 우선: 춤은 멈추고 남은 시간은 사라짐
			v.dance_t = 0.0
		if v.dance_t <= 0:
			v.dance_t = 0.0
			v.dance_immune = D.immune
			v.dance_log.clear()
		return
	if v.dance_immune > 0:  # 춤이 끝난 뒤 한동안은 다시 안 춤 (쌓이지도 않음)
		v.dance_immune = maxf(0.0, v.dance_immune - dt)
		v.dance_log.clear()
		return
	if heard:
		v.dance_log.append([now, dt])
	while not v.dance_log.is_empty() and float(v.dance_log[0][0]) <= now - float(D.window):
		v.dance_log.pop_front()
	if v.fall_t > 0:
		return
	var sum := 0.0
	for x: Array in v.dance_log:
		sum += float(x[1])
	if sum >= float(D.need) - 1e-6:
		v.dance_t = D.dur
		v.dance_log.clear()
		if v.is_local:
			combat.toast.emit("몸이 멋대로 춤춘다!")


## 지금까지 원뿔 안에 있었던 시간 (최근 DANCE.window초) — HUD·테스트용
static func heard_sum(v: PlayerController) -> float:
	var sum := 0.0
	for x: Array in v.dance_log:
		sum += float(x[1])
	return sum
