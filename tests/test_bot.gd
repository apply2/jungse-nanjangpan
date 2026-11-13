extends SceneTree
## 봇 AI 자동 테스트 — HTML botUpdate / aimSolve / DIFF와 같은 결과인지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_bot.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나
var b      # 시험할 봇
var others: Array = []
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const DT := 1.0 / 60.0
const OPEN_A := Vector3(-25, 0, 18)   # 트인 곳


func _initialize() -> void:
	var G0 = root.get_node("GameData")  # 저장된 설정과 상관없이 같은 조건으로
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G0.third_person = true
	G0.difficulty = "normal"
	G0.mouse_sens = 1.2
	G0.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()  # 메뉴를 건너뛰고 바로 경기 (Main이 트리에 들어간 뒤)
	root.get_node("GameData").ai_enabled = false  # 준비하는 동안은 가만히
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func near(a: float, b2: float, eps := 0.05) -> bool:
	return absf(a - b2) < eps


## 봇 b를 cls로 pos에 세우고 AI를 켠다
func put_bot(pos: Vector3, cls: String, yaw := 0.0) -> void:
	b.next_cls = cls
	b.spawn_at(pos)
	b.invuln = 0.0
	b.scripted_input = {}
	b.yaw = yaw
	b.pitch = 0.0


func put_me(pos: Vector3, cls := "archer") -> void:
	p.next_cls = cls
	p.spawn_at(pos)
	p.invuln = 99.0  # 테스트 중엔 안 죽게
	p.scripted_input = IDLE


## b가 쏜 투사체 수 (n 프레임 동안)
func count_shots(n: int) -> Array:
	var shots: Array = []
	var prev: Array = C.projectiles.duplicate()
	for i in n:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr) and pr.owner == b:
				pr["_dist"] = b.global_position.distance_to(p.global_position)  # 쏜 순간 거리
				shots.append(pr)
		prev = C.projectiles.duplicate()
	return shots


## Combat.update_projectiles와 같은 방식으로 날려서, 목표점 aim_pt에 가장 가까이 간 거리
func fly_miss(kind: String, from_eye: Vector3, yaw: float, pitch: float, aim_pt: Vector3, t := 1.0) -> float:
	var W: Dictionary = G.WEAPONS[kind]
	var cp := cos(pitch)
	var dir := Vector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp)
	var speed: float = lerpf(W.speed_min, W.speed_max, t) if kind == "bow" else float(W.speed)
	var pos: Vector3 = from_eye + dir * float(G.FIRE_FWD)
	var vel: Vector3 = dir * speed
	if W.has("lift"):
		vel.y += float(W.lift)
	var best := INF
	for i in 400:
		var d := vel * DT
		vel.y -= float(W.grav) * DT
		var c: Dictionary = C.seg_point(pos, d, aim_pt)
		best = minf(best, sqrt(c.dist2))
		pos += d
		if pos.y < -1:
			break
	return best


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	G.third_person = false
	C = main.get_node("Combat")
	p = main.get_node("Player")
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	check("봇 7명, 머리 있음", bots.size() == G.BOT_COUNT and bots.all(func(e): return e.ai != null), "n=%d" % bots.size())
	b = bots[0]
	others = bots.slice(1)
	for o in others:  # 나머지 봇은 퇴장 (대상 고르기에 안 끼게)
		o.die(Vector3.FORWARD)
		o.respawn = 1e9
	put_me(OPEN_A)
	await wait(3)

	# ── aimSolve: 오차 0이면 무기마다 정확히 맞는 각도 ──
	var ai = b.ai
	ai.ex = 0.0
	ai.ey = 0.0
	ai.lead = 0.0
	ai.aim_head = false
	for case in [["stone", 12.0], ["bow", 30.0], ["crossbow", 50.0], ["holy", 15.0]]:
		var kind: String = case[0]
		var dist: float = case[1]
		b.next_cls = {"stone": "barbarian", "bow": "archer", "crossbow": "crossbow", "holy": "cleric"}[kind]
		b.spawn_at(OPEN_A + Vector3(dist, 0, 0))
		b.scripted_input = IDLE
		ai.want_charge = G.WEAPONS.bow.full
		var a: Dictionary = ai.aim_solve(b, p)
		var aim_pt: Vector3 = p.global_position + (Vector3.ZERO if kind == "holy" else Vector3(0, G.BOT.aim_body, 0))
		var miss := fly_miss(kind, b.eye_pos(), a.yaw, a.pitch, aim_pt)
		check("조준 계산 %s %.0fm" % [kind, dist], miss < (0.6 if kind == "holy" else 0.15), "빗나간 거리 %.2fm pitch=%.3f" % [miss, a.pitch])

	# ── 앞질러 쏘기: 움직이는 대상이면 앞쪽을 봄 ──
	b.next_cls = "archer"
	b.spawn_at(OPEN_A + Vector3(30, 0, 0))
	b.scripted_input = IDLE
	ai.lead = 1.0
	p.velocity = Vector3(0, 0, -5)  # 북쪽으로 달리는 중
	var lead_aim: Dictionary = ai.aim_solve(b, p)
	ai.lead = 0.0
	var still_aim: Dictionary = ai.aim_solve(b, p)
	p.velocity = Vector3.ZERO
	var dyaw := fposmod(lead_aim.yaw - still_aim.yaw + PI, TAU) - PI
	check("앞질러 쏘기 (달리는 쪽으로 조준)", dyaw < -0.05, "yaw 차이 %.3f" % dyaw)

	# ── 대상 고르기·반응: 트인 곳 15m, 어려움 ──
	G.ai_enabled = true
	G.difficulty = "hard"
	put_me(OPEN_A, "archer")
	put_bot(OPEN_A + Vector3(15, 0, 0), "crossbow", 0.0)
	var shots: Array = await count_shots(40)
	check("0.55초 안에 나를 대상으로", b.ai.target == p and b.ai.vis, "target=%s vis=%s" % [b.ai.target, b.ai.vis])
	shots += await count_shots(200)
	check("반응 시간 뒤 석궁 발사", shots.size() >= 1, "4초 동안 %d발" % shots.size())

	# ── 반응 시간 동안은 안 쏨 (쉬움: 1.0~1.5초) ──
	G.difficulty = "easy"
	put_me(OPEN_A, "archer")
	put_bot(OPEN_A + Vector3(10, 0, 0), "barbarian", PI / 2)  # 나를 봄
	shots = await count_shots(55)  # 첫 생각까지 최대 0.55초 + 반응 1.0초 → 0.9초까진 절대 안 쏨
	check("쉬움: 반응 1초 전엔 안 쏨", shots.is_empty(), "%d발" % shots.size())

	# ── 회전 속도 제한: 쉬움 2.4 rad/s ──
	put_me(OPEN_A + Vector3(0, 0, 0))
	put_bot(OPEN_A + Vector3(12, 0, 0), "archer", -PI / 2)  # 등 돌림 (동쪽을 봄)
	await wait(36)  # 첫 생각 + 일부 회전
	var y0: float = b.yaw
	await wait(30)
	var turned := absf(fposmod(b.yaw - y0 + PI, TAU) - PI)
	check("쉬움: 0.5초에 최대 1.2rad 회전", turned <= 1.2 + 0.05, "%.2f rad" % turned)

	# ── 활: 거리/34만큼 당기고 놓음 (궁수는 22m를 좋아해서 물러나며 쏨) ──
	G.difficulty = "hard"
	put_me(OPEN_A, "archer")
	put_bot(OPEN_A + Vector3(15, 0, 0), "archer", PI / 2)
	shots = await count_shots(480)
	# 거리/34만큼 당기면 놓는다. 당기는 중에 '이번엔 안 쏨'(fire_ok)이 나오면 HTML처럼 일찍 놓을 수도 있어서
	# "목표보다 더 당기지 않는다"와 "적어도 한 발은 목표만큼 당겼다"를 본다.
	var over := 0
	var on_target := 0
	var detail := []
	for s in shots:
		var dist: float = s._dist
		var BW: Dictionary = G.WEAPONS.bow
		var exp_dmg := roundf(lerpf(BW.dmg_min, BW.dmg_max, G.bow_t(clampf(dist / 34.0, 0.35, 1.0) * float(BW.full))))
		detail.append("%.0fm:%.0f/%.0f" % [dist, s.dmg, exp_dmg])
		if s.dmg > exp_dmg + 4:  # 생각 사이 물러난 거리(최대 ~3m)만큼 여유 (피해 폭이 넓어져 2→4)
			over += 1
		if absf(s.dmg - exp_dmg) <= 4:
			on_target += 1
	check("활 봇: 거리/34만큼 당겨 쏨", shots.size() >= 1 and over == 0 and on_target >= 1, " ".join(detail))

	# ── 조준 오차: 난이도마다 기본 0.09~0.15 × err ──
	for dk in ["easy", "normal", "hard"]:
		G.difficulty = dk
		put_me(OPEN_A)
		put_bot(OPEN_A + Vector3(20, 0, 0), "crossbow", PI / 2)
		var lo := 1e9
		var hi := 0.0
		for k in 6:
			await wait(34)
			lo = minf(lo, b.ai.err)
			hi = maxf(hi, b.ai.err)
		var m: float = G.DIFF[dk].err
		check("오차 범위 %s (×%.1f)" % [dk, m], lo >= 0.09 * m - 1e-4 and hi <= 0.15 * m + 1e-4, "%.3f~%.3f" % [lo, hi])

	# ── 건물에 가리면 안 보임 → 안 쏨 ──
	var wall := _find_wall()
	check("벽 찾음", not wall.is_empty(), "")
	if not wall.is_empty():
		G.difficulty = "hard"
		put_me(wall.a, "archer")
		put_bot(wall.b, "crossbow")
		check("벽 너머는 시야 없음 (los)", not C.los(p.eye_pos(), b.eye_pos()), "")
		await wait(40)
		check("가려진 대상: vis=false", b.ai.target == p and not b.ai.vis, "target=%s vis=%s" % [b.ai.target, b.ai.vis])
		# 나를 향해 벽으로 걸어가다 막히면 점프 (HTML: 끼인 지 0.35초)
		# (벽을 따라 미끄러져 가면 끼지 않을 수도 있다 — 그땐 움직이고만 있으면 됨)
		var stuck_jump := false
		var was_stuck := false
		var start: Vector3 = b.global_position
		for i in 240:
			await physics_frame
			if b.ai.stuck > 0.35:
				was_stuck = true
			if was_stuck and b.velocity.y > 1.0:
				stuck_jump = true
		var moved: float = b.global_position.distance_to(start)
		check("벽에 막히면 점프 (안 막히면 계속 움직임)", (was_stuck and stuck_jump) or (not was_stuck and moved > 1.0),
			"끼임=%s 점프=%s 이동 %.1fm" % [was_stuck, stuck_jump, moved])

	# ── 맞으면 때린 사람을 노림 ──
	put_me(OPEN_A)
	put_bot(OPEN_A + Vector3(30, 0, 0), "archer")
	await wait(2)
	b.ai.target = null
	b.ai.react = 3.0
	C.damage(b, p, 1.0, "stone", false, Vector3(1, 0, 0))
	check("맞으면 때린 사람이 대상, 반응 0.5초 이하", b.ai.target == p and b.ai.vis and b.ai.react <= 0.5, "react=%.2f" % b.ai.react)

	# ── 남의 성수 웅덩이에선 빠져나감 ──
	put_me(OPEN_A + Vector3(0, 0, -20))
	put_bot(OPEN_A + Vector3(10, 0, 0), "archer")
	await wait(2)
	var center: Vector3 = b.global_position
	C.shatter(p, center)
	await wait(150)
	var out: float = Vector2(b.global_position.x - center.x, b.global_position.z - center.z).length()
	check("웅덩이 밖으로 빠져나감", out > 2.0, "중심에서 %.1fm" % out)

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


## 키 2.5m 넘는 건물 상자를 찾아 양쪽(남·북)에 설 자리를 준다 {a, b}
func _find_wall() -> Dictionary:
	for bx in C.world.aabbs:
		var box: AABB = bx
		if box.size.y < 2.5 or box.size.x < 4 or box.size.z > 12 or box.position.y > 0.5:
			continue
		var cx := box.position.x + box.size.x / 2
		var pa := Vector3(cx, 0, box.position.z - 1.5)
		var pb := Vector3(cx, 0, box.end.z + 1.5)
		if absf(cx) > 40 or absf(pa.z) > 42 or absf(pb.z) > 42:
			continue
		if C.world.overlaps_any(pa, 0.8, 1.9) or C.world.overlaps_any(pb, 0.8, 1.9):
			continue
		if C.los(pa + Vector3(0, 1.55, 0), pb + Vector3(0, 1.55, 0)):
			continue
		return {"a": pa, "b": pb}
	return {}
