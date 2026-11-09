extends SceneTree
## 돌멩이·투사체 자동 테스트 — HTML fire / weaponUpdate / updateProjectiles / impactFx와 같은 결과인지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_stone.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나 (야만인)
var dm     # 과녁 허수아비
var fails := 0
var nums: Array = []      # Combat.num 신호 기록 [text, style]
var marks: Array = []     # Combat.hitmark 신호 기록

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const SHOOTER := Vector3(-25, 0, 18)
const TARGET := Vector3(-19, 0, 18)
const EAST_YAW := -PI / 2   # aim_dir = (1, 0, 0)
const WEST_YAW := PI / 2


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
	root.get_node("GameData").ai_enabled = false  # 봇은 가만히 (봇 AI는 test_bot.gd)
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func near(a: float, b: float, eps := 0.05) -> bool:
	return absf(a - b) < eps


func put(e, pos: Vector3, cls := "archer", yaw := 0.0) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0


## n 프레임 동안 공격 키를 누르고, 새로 생긴 투사체 수를 센다
func hold_fire(n: int) -> int:
	p.scripted_input = FIRE
	var count := 0
	var prev: Array = C.projectiles.duplicate()
	for i in n:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				count += 1
		prev = C.projectiles.duplicate()
	p.scripted_input = IDLE
	return count


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	G.third_person = false  # 3인칭 조준 보정은 카메라 위치에 따라 달라지므로 1인칭으로
	C = main.get_node("Combat")
	p = main.get_node("Player")
	C.num.connect(func(_pos, text, style): nums.append([text, style]))
	C.hitmark.connect(func(k): marks.append(k))
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], C.world.spawn_points[i * 5 % C.world.spawn_points.size()])
	put(p, SHOOTER, "barbarian", EAST_YAW)
	put(dm, TARGET)
	await wait(5)
	var W: Dictionary = G.WEAPONS.stone

	# ── 한 번 던지기: 투사체 속성 ──
	check("야만인 무기 = 돌멩이", p.wep == "stone" and dm.model.weapons.size() > 0 and p.model.weapons.has("stone"), "wep=%s" % p.wep)
	p.scripted_input = FIRE
	await wait(1)
	p.scripted_input = IDLE
	check("돌 하나 날아감", C.projectiles.size() == 1, "n=%d" % C.projectiles.size())
	var pr: Dictionary = C.projectiles[0] if C.projectiles.size() > 0 else {}
	if not pr.is_empty():
		var v: Vector3 = pr.vel
		check("속도 32, 동쪽", near(Vector2(v.x, v.z).length(), 32.0, 0.6) and v.x > 31, "v=%s" % v)
		check("사거리 15m → 수명 15/32초", near(pr.life + 1.0 / 60.0, 15.0 / 32.0, 0.02), "life=%.3f" % pr.life)
		check("재사용 대기 0.4", near(p.cd, 0.4 - 1.0 / 60.0, 0.02), "cd=%.3f" % p.cd)
	check("던지기 팔 모션 시작", p.fire_anim > 0.8, "fire_anim=%.2f" % p.fire_anim)

	# ── 날아가서 몸에 맞음 ──
	await wait(20)
	check("몸에 맞아 10 피해", near(dm.hp, 90.0), "hp=%.1f" % dm.hp)
	check("돌은 맞으면 사라짐", C.projectiles.is_empty(), "n=%d" % C.projectiles.size())
	check("돌 넉백 4 (동쪽으로 밀림)", dm.velocity.x > 1.0, "v=%s" % dm.velocity)
	check("데미지 숫자 10", nums.size() > 0 and nums[-1] == ["10", ""], str(nums))
	check("맞힘 표시", marks.size() > 0 and marks[-1] == false, str(marks))
	check("조각·링·연기 효과", C.fx.count() >= 10, "fx=%d" % C.fx.count())
	check("팔 모션 끝남", p.fire_anim == 0.0, "fire_anim=%.2f" % p.fire_anim)

	# ── 누르고 있으면 0.4초마다 연사 ──
	put(dm, Vector3(-25, 0, 40))  # 과녁 치우기
	put(p, SHOOTER, "barbarian", WEST_YAW)
	p.pitch = 0.3
	await wait(2)
	var shots: int = await hold_fire(60)
	check("1초 누르면 3발 (0, 0.4, 0.8초)", shots == 3, "shots=%d" % shots)

	# ── 사거리 끝나면 사라짐 (하늘로) ──
	await wait(40)
	C.projectiles.clear()
	put(p, SHOOTER, "barbarian", WEST_YAW)
	p.pitch = 0.6
	await wait(2)
	await hold_fire(1)
	var start: Vector3 = C.projectiles[0].pos if C.projectiles.size() > 0 else Vector3.ZERO
	var last := start
	var frames := 0
	while C.projectiles.size() > 0 and frames < 120:
		last = C.projectiles[0].pos
		await physics_frame
		frames += 1
	check("15m쯤 날아가서 사라짐", frames >= 26 and frames <= 30 and near(Vector2(last.x - start.x, last.z - start.z).length(), 15.0 * cos(0.6), 1.0),
		"frames=%d 수평거리=%.1f" % [frames, Vector2(last.x - start.x, last.z - start.z).length()])

	# ── 땅에 맞으면 바로 사라지고 흙먼지 ──
	await wait(60)
	var fx0: int = C.fx.count()
	p.pitch = -1.3
	await hold_fire(1)
	await wait(6)
	check("땅에 맞아 사라짐", C.projectiles.is_empty(), "n=%d" % C.projectiles.size())
	check("흙먼지", C.fx.count() > fx0, "fx=%d→%d" % [fx0, C.fx.count()])

	# ── 넘어져 있으면 못 던짐 ──
	await wait(30)
	p.pitch = 0.0
	p.trip()
	var tripped_shots: int = await hold_fire(10)
	check("넘어지면 못 던짐", tripped_shots == 0, "shots=%d" % tripped_shots)
	await wait(60)

	# ── 머리에 맞음: 투구 ×1.5 → 15, 투구 날림 ──
	put(p, SHOOTER, "barbarian", EAST_YAW)
	put(dm, TARGET)
	await wait(3)
	nums.clear()
	await hold_fire(1)
	if C.projectiles.size() > 0:  # 날아가는 돌을 머리 높이로 옮겨 곧게 날린다
		var q: Dictionary = C.projectiles[0]
		q.pos = Vector3(SHOOTER.x + 1, 1.62, SHOOTER.z)
		q.vel = Vector3(32, 0, 0)
		q.grav = 0.0
	await wait(15)
	check("헤드샷 15 (×1.5)", near(dm.hp, 85.0), "hp=%.1f" % dm.hp)
	check("투구 날아감", not dm.helmet, "helmet=%s" % dm.helmet)
	check("헤드샷 숫자·투구 날림 문구", nums.has(["15", "head"]) and nums.has(["투구 날림!", "head"]), str(nums))

	# ── 처치하면 '처치' ──
	dm.hp = 5.0
	nums.clear()
	marks.clear()
	await wait(30)
	await hold_fire(1)
	await wait(15)
	check("돌로 처치", not dm.alive and p.kills >= 1, "alive=%s kills=%d" % [dm.alive, p.kills])
	check("처치 숫자·표시", nums.has(["처치", "kill"]) and marks.has(true), "%s %s" % [nums, marks])

	# ── 내 돌에 나는 안 맞음 (바로 아래로) ──
	await wait(200)
	put(p, SHOOTER, "barbarian", EAST_YAW)
	await wait(3)
	var hp0: float = p.hp
	p.pitch = -1.5
	await hold_fire(1)
	await wait(10)
	check("내 돌에 안 맞음", p.hp == hp0, "hp=%.1f" % p.hp)

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
