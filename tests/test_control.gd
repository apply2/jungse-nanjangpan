extends SceneTree
## 쟁탈전 자동 테스트: 팀 나누기(5:5)·팀 색, 점령 속도(1·2·3명), 상대 게이지 먼저 빼기, 빈 거점 감소, 경합 멈춤,
## 점수 0.9초마다 1%, 99% 연장전 → 적이 나가면 100% 승리, 4분 안전장치, 3판 2선승,
## 팀킬 없음(투사체·히트스캔·성수·마상창·직접 피해), 부활 5초, 스폰룸 회복·공격 금지,
## 맵 거울 대칭, 양 팀 스폰에서 3갈래 내비 경로, 적 팀은 스폰룸 문에서 막힘, 봇이 거점으로 감.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_control.gd

var main: Node
var G: Node
var C
var p
var mode
var W
var blues: Array = []
var reds: Array = []
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const DT := 1.0 / 60.0


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.third_person = false
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	G.mode = "control"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G.ai_enabled = false
	main.start_match.call_deferred()
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func put(e, pos: Vector3, cls := "archer") -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.velocity = Vector3.ZERO


## 규칙만 따로 돌림 (counts를 직접 넣고 step_capture)
func sim(sec: float, nb: int, nr: int) -> void:
	var n := int(round(sec / DT))
	for i in n:
		mode.counts = {"blue": nb, "red": nr}
		mode.step_capture(DT)


func fresh() -> void:
	mode.phase = "open"
	mode.holder = ""
	mode.cap_team = ""
	mode.cap_prog = 0.0
	mode.pct = {"blue": 0, "red": 0}
	mode.overtime = false
	mode.contested = false
	mode.round_t = 0.0
	mode.wins = {"blue": 0, "red": 0}
	mode.round_no = 1
	mode.match_winner = ""
	mode.set("_score_acc", 0.0)


func _run() -> void:
	await wait(5)
	C = main.get_node("Combat")
	p = main.get_node("Player")
	mode = C.mode
	W = C.world
	var CM: Dictionary = G.MODES.control
	check("쟁탈전 규칙이 걸림", mode != null and W != null and W.map_id == "control")
	var ch: float = CM.cap_half
	put(p, Vector3(ch - 0.5, 0.5, ch - 0.5))
	await wait(2)
	var corner_in: bool = mode.in_circle(p)
	put(p, Vector3(ch + 0.6, 0.5, 0))
	await wait(2)
	check("거점 = 18m 정사각형 (모서리 안, 변 밖)", is_equal_approx(ch, 9.0) and corner_in and not mode.in_circle(p))
	put(p, mode.spawn_pos(p))
	await wait(2)
	for e in C.ents:
		if e.team == "blue":
			blues.append(e)
		elif e.team == "red":
			reds.append(e)
	check("팀 5:5 (나는 블루)", blues.size() == 5 and reds.size() == 5 and p.team == "blue", "%d:%d" % [blues.size(), reds.size()])
	check("모두 자기 팀 스폰룸에서 시작", C.ents.all(func(e) -> bool: return mode.in_own_spawn(e)))
	check("처음엔 거점 잠김 15초", mode.phase == "locked" and mode.unlock_left > 14.0 and mode.status_text().begins_with("거점 열림까지"), mode.status_text())
	check("블루 몸 색 = 0x3d6fd6", G.team_paint("archer", "blue", 0xb8322a) == 0x3d6fd6 and G.team_paint("archer", "red", 0xb8322a) == 0xd8453b)
	check("성직자 옷은 연한 팀 색", G.team_paint("cleric", "blue", 0xeee6d2) == 0xc9d7f7 and G.team_paint("cleric", "red", 0xeee6d2) == 0xf7cdc9)
	check("개인전 색은 그대로", G.team_paint("archer", "", 0xb8322a) == 0xb8322a)
	check("적 스폰룸 문 막: 블루는 레드 문(8)에, 레드는 블루 문(4)에 막힘", (p.collision_mask & 8) != 0 and (p.collision_mask & 4) == 0 and (reds[0].collision_mask & 4) != 0)

	# ── 거점 규칙 (자동 진행은 잠깐 멈추고 직접 돌림) ──
	C.mode = null
	fresh()
	sim(7.9, 1, 0)
	var not_yet: bool = mode.holder == ""
	sim(0.15, 1, 0)
	check("1명 8초에 점령", not_yet and mode.holder == "blue", "prog %.2f" % mode.cap_prog)
	fresh()
	sim(8.0 / 1.5 - 0.1, 2, 0)
	not_yet = mode.holder == ""
	sim(0.15, 2, 0)
	check("2명 ×1.5 (5.3초)", not_yet and mode.holder == "blue")
	fresh()
	sim(3.9, 3, 0)
	not_yet = mode.holder == ""
	sim(0.15, 4, 0)
	check("3명 이상 ×2 (4초)", not_yet and mode.holder == "blue")
	fresh()
	mode.cap_team = "red"
	mode.cap_prog = 0.5
	sim(3.9, 1, 0)
	var drained: bool = mode.cap_team == "red" and mode.cap_prog > 0
	sim(0.2, 1, 0)
	var flipped: bool = mode.cap_team == "blue"
	sim(7.7, 1, 0)
	not_yet = mode.holder == ""
	sim(0.3, 1, 0)
	check("상대 게이지 50%를 먼저 0으로 (4초) 뒤 점령 (8초)", drained and flipped and not_yet and mode.holder == "blue")
	fresh()
	mode.cap_team = "blue"
	mode.cap_prog = 0.5
	sim(2.0, 0, 0)
	check("빈 거점은 초당 1/8 감소", absf(mode.cap_prog - 0.25) < 0.01, "%.3f" % mode.cap_prog)
	mode.cap_prog = 0.5
	sim(3.0, 1, 1)
	check("경합: 게이지 멈춤 + 경합 중!", absf(mode.cap_prog - 0.5) < 0.001 and mode.contested and mode.status_text() == "경합 중!")
	fresh()
	mode.holder = "red"
	sim(9.0 + 0.05, 0, 0)
	check("점수: 0.9초마다 1%", mode.pct.red == 10 and mode.pct.blue == 0, str(mode.pct))
	mode.cap_team = "blue"
	mode.cap_prog = 0.3
	sim(1.0, 0, 2)
	check("주인 팀만 있으면 상대 게이지를 빼냄", mode.cap_prog < 0.3 - 0.15)
	fresh()
	mode.holder = "blue"
	mode.pct.blue = 98
	sim(3.0, 1, 1)
	check("99%에서 적이 있으면 멈추고 연장전", mode.pct.blue == 99 and mode.overtime and mode.phase == "open" and mode.status_text() == "연장전!", str(mode.pct))
	sim(DT, 1, 0)
	check("적이 나가면 100% → 라운드 승리", mode.pct.blue == 100 and mode.phase == "gap" and mode.wins.blue == 1 and mode.last_winner == "blue")
	fresh()
	mode.holder = "blue"
	mode.pct.blue = 99
	mode.overtime = true
	sim(4.1, 0, 3)
	check("연장전 중에 점령하면 거점이 넘어감", mode.holder == "red" and not mode.overtime and mode.phase == "open")
	fresh()
	mode.pct = {"blue": 30, "red": 40}
	mode.holder = ""
	mode.round_t = 239.99
	var cnt_before: Dictionary = mode.counts
	mode.update(0.02)
	check("4분 안전장치: % 높은 팀(레드) 승리", mode.phase == "gap" and mode.last_winner == "red" and mode.wins.red == 1, str(cnt_before))
	# 3판 2선승
	fresh()
	mode.wins = {"blue": 1, "red": 0}
	mode.holder = "blue"
	mode.pct.blue = 99
	sim(1.0, 1, 0)
	check("2승이면 경기 끝 (블루팀 승리)", mode.phase == "gap" and mode.match_winner == "blue")
	fresh()
	mode.wins = {"blue": 0, "red": 0}
	mode.holder = "red"
	mode.pct.red = 99
	sim(1.0, 0, 0)
	check("1승이면 다음 라운드 기다림", mode.phase == "gap" and mode.match_winner == "" and mode.wins.red == 1)
	# 라운드 사이엔 피해 없음
	C.mode = mode
	var hp0: float = reds[0].hp
	C.damage(reds[0], p, 30, "stone", false, Vector3.FORWARD)
	check("라운드 사이엔 피해 없음", reds[0].hp == hp0)
	fresh()

	# ── 팀킬 없음 ──
	var ally = blues[1]
	var enemy = reds[0]
	put(p, Vector3(0, 0.5, 20))
	put(ally, Vector3(0, 0.5, 14))
	put(enemy, Vector3(6, 0.5, 14))
	await wait(3)
	C.damage(ally, p, 50, "stone", false, Vector3.FORWARD)
	check("직접 피해: 아군 0", ally.hp == G.class_hp(ally.cls))
	C.damage(enemy, p, 20, "stone", false, Vector3.FORWARD)
	check("직접 피해: 적은 맞음", enemy.hp < G.class_hp(enemy.cls))
	put(enemy, Vector3(8, 0.5, 30))
	await wait(2)
	# 투사체 (돌멩이를 아군에게 곧장)
	p.next_cls = "barbarian"
	put(p, Vector3(0, 0, 20), "barbarian")
	await wait(2)
	_aim_at(p, ally.global_position + Vector3(0, 1.0, 0))
	C.fire(p, "stone")
	await wait(40)
	check("투사체: 아군 통과 (피해 0)", ally.hp == G.class_hp(ally.cls))
	# 히트스캔 (저격총)
	p.has_sniper = true
	p.ammo = 5
	p.wep = "sniper"
	_aim_at(p, ally.global_position + Vector3(0, 1.0, 0))
	C.fire(p, "sniper")
	await wait(2)
	check("히트스캔(저격총): 아군 즉사 안 함", ally.alive and ally.hp == G.class_hp(ally.cls))
	p.has_sniper = false
	# 성수 웅덩이
	C.shatter(p, ally.global_position)
	await wait(60)
	check("성수: 아군 피해·둔화 없음", ally.hp == G.class_hp(ally.cls) and ally.slow_t <= 0)
	var rim_ok := false
	for z in C.zones:
		var c: Color = (z.rim as MeshInstance3D).material_override.albedo_color
		rim_ok = absf(c.b - G.col(G.team_hex("blue", "accent")).b) < 0.02
	check("성수 테두리: 우리 팀 파랑", rim_ok)
	# 성수: 같은 팀은 초당 2 회복, 적은 회복 안 됨
	await wait(200)
	C.zones.clear()
	put(ally, Vector3(-4, 0.5, 16))
	put(enemy, Vector3(-3, 0.5, 16))
	await wait(3)
	ally.hp = 40.0
	ally.no_hit_t = 0.0
	enemy.hp = 40.0
	enemy.no_hit_t = 0.0
	C.shatter(p, ally.global_position)
	await wait(60)
	check("성수: 같은 팀 초당 %.0f 회복" % G.WEAPONS.holy.heal, absf(ally.hp - 40.0 - G.WEAPONS.holy.heal) < 0.15, "hp %.2f" % ally.hp)
	check("성수: 적은 회복 안 됨", enemy.hp < 40.0, "hp %.2f" % enemy.hp)
	C.zones.clear()
	put(enemy, Vector3(6, 0.5, 14))
	ally.hp = G.class_hp(ally.cls)
	# 마상창
	put(p, Vector3(0, 0, 20))
	put(ally, Vector3(0, 0, 18))
	await wait(2)
	C.items.mount(p, C.items.horse)
	p.yaw = 0.0
	p.velocity = Vector3(0, 0, -15)
	C.items.lance_check(p)
	check("마상창: 아군 0", ally.hp == G.class_hp(ally.cls))
	put(ally, Vector3(-10, 0, 30))
	enemy.ln_t = 0.0
	enemy.global_position = Vector3(0, 0, p.global_position.z - 2.2)
	p.velocity = Vector3(0, 0, -15)
	C.items.lance_check(p)
	check("마상창: 적은 맞음", enemy.hp < G.class_hp(enemy.cls) or not enemy.alive, "hp %.0f" % enemy.hp)
	C.items.dismount(p)
	p.velocity = Vector3.ZERO

	# ── 거점 단상(0.5m): 점프 없이 걸어서 올라감 — 비스듬히 걸어도 (사용자 요청) ──
	var stepped := 0
	var step_miss := ""
	var yaws := [0.0, 0.6, -0.6, 1.0, -1.0, 1.2, -1.2, 1.4, -1.4]
	for yw: float in yaws:
		var fwd := Vector3(-sin(yw), 0, -cos(yw))
		put(p, Vector3(0, 0, 9.0) - fwd * 1.5)
		p.yaw = yw
		p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": false}
		var on := false
		for i in 150:
			await physics_frame
			var q: Vector3 = p.global_position
			if q.y > 0.49 and absf(q.x) < 8.7 and absf(q.z) < 8.7:
				on = true
				break
		stepped += 1 if on else 0
		if not on:
			step_miss += " %.1f" % yw
	p.scripted_input = IDLE
	check("거점 단상: 걸어서 올라감 (정면·비스듬히 %d방향)" % yaws.size(), stepped == yaws.size(), "못 오른 각도:" + step_miss)

	# ── 부활 5초 ──
	put(enemy, Vector3(10, 0, 10))
	await wait(2)
	C.kill(enemy, p, "stone", false, Vector3.FORWARD)
	check("쟁탈전 부활 5초", is_equal_approx(enemy.respawn, float(CM.respawn)))
	var rt := 0
	while not enemy.alive and rt < 400:
		await physics_frame
		rt += 1
	check("레드는 레드 스폰룸에서 부활", enemy.alive and mode.in_own_spawn(enemy) and enemy.global_position.z < -50, "%d프레임" % rt)

	# ── 스폰룸 회복·공격 금지 ──
	put(p, Vector3(0, 0, 59), "barbarian")
	p.hp = 10
	await wait(30)
	check("스폰룸: 초당 100 회복", p.hp > 50, "%.0f" % p.hp)
	var np: int = C.projectiles.size()
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
	await wait(30)
	p.scripted_input = IDLE
	check("스폰룸 안에선 공격 못 함", C.projectiles.size() == np)
	put(p, Vector3(0, 0, 30), "barbarian")
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
	await wait(4)
	p.scripted_input = IDLE
	check("스폰룸 밖에선 공격됨", C.projectiles.size() > np)

	# ── 맵 거울 대칭 ──
	var keyset := {}
	var blue_n := 0
	var red_n := 0
	for a: AABB in W.aabbs:
		var cz := a.get_center().z
		if cz > 0.001:
			blue_n += 1
		elif cz < -0.001:
			red_n += 1
			keyset[_key(a)] = true
	var miss := 0
	for a: AABB in W.aabbs:
		if a.get_center().z > 0.001:
			var f := AABB(Vector3(a.position.x, a.position.y, -a.end.z), a.size)
			var found := false
			for r: AABB in W.aabbs:
				if r.position.is_equal_approx(f.position) and r.size.is_equal_approx(f.size):
					found = true
					break
			if not found:
				miss += 1
				print("  안 맞음: ", a)
	check("맵 거울 대칭 (블루 상자를 뒤집으면 레드 상자)", blue_n == red_n and blue_n > 50 and miss == 0, "블루 %d 레드 %d 안 맞음 %d" % [blue_n, red_n, miss])
	check("크기 x -32~32, z -64~64", is_equal_approx(W.half_x, 31.4) and is_equal_approx(W.half_z, 63.4))

	# ── 내비 경로: 양 팀 스폰에서 3갈래로 거점까지 ──
	await wait(3)
	for team: String in ["blue", "red"]:
		var start: Vector3 = W.spawn_spots(team)[2]
		var lanes: Array = W.lane_points(team)
		for li in lanes.size():
			var pts: Array = [start]
			pts.append_array(lanes[li])
			pts.append(W.flip(Vector3(0, 0.5, 3.0), team))  # 거점 단상 위 (가운데는 우물)
			var ok := true
			var info := ""
			for k in range(pts.size() - 1):
				var path: PackedVector3Array = W.nav_path(pts[k], pts[k + 1])
				var end_ok: bool = path.size() > 0 and Vector2(path[path.size() - 1].x - pts[k + 1].x, path[path.size() - 1].z - pts[k + 1].z).length() < 1.5 \
					and absf(path[path.size() - 1].y - (pts[k + 1] as Vector3).y) < 1.0
				if not end_ok:
					ok = false
					info = "%s → %s 끝 %s" % [pts[k], pts[k + 1], path[path.size() - 1] if path.size() > 0 else "없음"]
					break
			check("내비: %s 스폰 → %s → 거점" % [team, ["시장 골목", "큰길", "성벽 길"][li]], ok, info)
	# 성벽 길 위로 올라간 경로인가 (높이 3)
	var wall_path: PackedVector3Array = W.nav_path(Vector3(28, 0, 40), Vector3(28, 3, 20))
	var top := 0.0
	for q in wall_path:
		top = maxf(top, q.y)
	check("내비: 성벽 계단으로 높이 3까지", top > 2.6, "최고 %.2f" % top)

	# ── 스폰룸 문: 적만 막힘 ──
	put(enemy, Vector3(0, 0, 48), "archer")
	put(ally, Vector3(7, 0, 48), "archer")
	enemy.yaw = PI   # +z (블루 스폰룸 쪽)으로
	ally.yaw = PI
	var fwd := {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	enemy.scripted_input = fwd
	ally.scripted_input = fwd
	await wait(150)
	check("레드는 블루 스폰룸 문을 못 지나감", enemy.global_position.z < 52.4, "z %.2f" % enemy.global_position.z)
	check("블루는 자기 스폰룸으로 들어감", ally.global_position.z > 54.0, "z %.2f" % ally.global_position.z)
	enemy.scripted_input = IDLE
	ally.scripted_input = IDLE

	# ── 봇이 거점으로 감 (AI 켬, 짧은 경기) ──
	fresh()
	mode.phase = "locked"
	mode.unlock_left = 0.05
	for e in C.ents:
		if e != p:
			e.scripted_input = {}
			e.spawn_at(mode.spawn_pos(e))
	G.ai_enabled = true
	p.spawn_at(Vector3(0, 0, 60))
	p.scripted_input = IDLE
	p.invuln = 9999.0
	var best := 999.0
	for i in 60 * 25:
		await physics_frame
		for e in C.ents:
			if e != p and e.alive:
				best = minf(best, Vector2(e.global_position.x, e.global_position.z).length())
		if mode.holder != "" or mode.cap_prog > 0.2:
			break
	check("봇이 25초 안에 거점에 들어가 점령을 시작", mode.holder != "" or mode.cap_prog > 0.2, "가장 가까이 %.1fm, holder %s prog %.2f" % [best, mode.holder, mode.cap_prog])
	G.ai_enabled = false

	# ── 실제 흐름: 라운드 승리 → 6초 → 2라운드(모두 스폰룸, 거점 잠김) → 2승 → 6초 → 결과 화면 ──
	fresh()
	for e in C.ents:
		e.scripted_input = IDLE
		e.spawn_at(mode.spawn_pos(e))
	mode.holder = "red"
	mode.pct.red = 99
	await wait(70)
	check("라운드 1: 레드 승리 → 결과 대기", mode.phase == "gap" and mode.wins.red == 1)
	await wait(int(60 * float(CM.round_gap)) + 10)
	check("6초 뒤 2라운드: 거점 잠김·중립·0%", mode.round_no == 2 and mode.phase == "locked" and mode.holder == "" and mode.pct.blue == 0 and mode.pct.red == 0)
	check("2라운드: 모두 자기 스폰룸", C.ents.all(func(e) -> bool: return e.alive and mode.in_own_spawn(e)))
	mode.phase = "open"
	mode.holder = "red"
	mode.pct.red = 99
	await wait(70)
	check("2승: 레드팀 승리", mode.match_winner == "red" and mode.phase == "gap")
	await wait(int(60 * float(CM.end_gap)) + 10)
	check("6초 뒤 결과 화면", main.state == "ended" and mode.phase == "over")

	# ── 메뉴로 가면 개인전으로 돌아감 ──
	main.go_menu("main")
	await wait(3)
	check("메뉴: 개인전 맵·팀 없음·봇 7명", C.mode == null and C.world.map_id == "ffa" and C.ents.all(func(e) -> bool: return e.team == "") and C.ents.size() == 8, "ents %d" % C.ents.size())

	print("ALL PASS" if fails == 0 else "FAILED %d" % fails)
	quit(1 if fails else 0)


func _aim_at(e, pt: Vector3) -> void:
	var eye: Vector3 = e.eye_pos()
	var d := pt - eye
	e.yaw = atan2(-d.x, -d.z)
	e.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _key(a: AABB) -> String:
	return "%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [a.position.x, a.position.y, a.position.z, a.size.x, a.size.y, a.size.z]
