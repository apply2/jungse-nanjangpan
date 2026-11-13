extends SceneTree
## 성수 자동 테스트 — HTML weaponUpdate('holy') / fire('holy') / shatter / updateZones / updateHolyAim과 같은 결과인지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_holy.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나 (성직자)
var dm     # 과녁 허수아비
var fails := 0
var new_shots: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const SHOOTER := Vector3(-25, 0, 18)
const TARGET := Vector3(-19, 0, 18)
const EAST_YAW := -PI / 2   # aim_dir = (1, 0, 0)
const WEST_YAW := PI / 2
const DT := 1.0 / 60.0


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


func hold(n: int) -> void:
	new_shots.clear()
	var prev: Array = C.projectiles.duplicate()
	p.scripted_input = FIRE
	for i in n:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				new_shots.append(pr)
		prev = C.projectiles.duplicate()
	p.scripted_input = IDLE


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	G.third_person = false
	C = main.get_node("Combat")
	p = main.get_node("Player")
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], C.world.spawn_points[i * 5 % C.world.spawn_points.size()])
	put(p, SHOOTER, "cleric", WEST_YAW)
	put(dm, Vector3(-25, 0, 40))
	await wait(5)
	var W: Dictionary = G.WEAPONS.holy
	check("성직자 무기 = 성수, 3개", p.wep == "holy" and p.charges == 3 and p.model.weapons.has("holy"), "wep=%s charges=%d" % [p.wep, p.charges])

	# ── 착지 지점 표시 ──
	await process_frame
	check("착지 지점 표시가 뜸 (반경 3)", C.aim_mk.visible and near(C.aim_mk.scale.x, 3.0), "visible=%s" % C.aim_mk.visible)
	var mk_x: float = C.aim_mk.global_position.x

	# ── 한 번 던지기 (2프레임 누름: 대기 0.4초라 한 병만 나감) ──
	await hold(2)
	check("던지면 한 병", new_shots.size() == 1, "n=%d" % new_shots.size())
	if new_shots.size() == 1:
		var v: Vector3 = new_shots[0].vel
		check("속도 19 + 위로 5.5", near(-v.x, 19.0, 0.3) and near(v.y, 5.5, 0.4), "v=%s" % v)
	check("남은 성수 2, 대기 0.4", p.charges == 2 and p.cd > 0.3 and p.cd <= 0.4001, "charges=%d cd=%.2f" % [p.charges, p.cd])
	await process_frame
	var mk_a: float = (C.aim_mk.material_override as StandardMaterial3D).albedo_color.a
	check("대기 중엔 표시가 흐려짐", near(mk_a, 0.25, 0.01), "a=%.2f" % mk_a)

	# ── 땅에 떨어지면 깨지고 웅덩이, 표시했던 자리 근처 ──
	await wait(70)
	check("땅에 닿아 웅덩이", C.projectiles.is_empty() and C.zones.size() == 1, "날아감=%d 웅덩이=%d" % [C.projectiles.size(), C.zones.size()])
	if C.zones.size() == 1:
		var zp: Vector3 = C.zones[0].pos
		check("표시한 자리에 떨어짐", absf(zp.x - mk_x) < 0.6, "웅덩이 x=%.2f 표시 x=%.2f" % [zp.x, mk_x])
		check("내 웅덩이 테두리는 금색", (C.zones[0].rim.material_override as StandardMaterial3D).albedo_color.to_html(false) == G.col(0xffe07a).to_html(false), "")
		check("던진 사람은 안 느려짐", p.slow_t <= 0, "slow_t=%.2f" % p.slow_t)
	await wait(200)
	check("3초 뒤 웅덩이 사라짐", C.zones.is_empty(), "n=%d" % C.zones.size())

	# ── 누르고 있으면 0.4초마다, 3개 다 쓰면 멈춤 ──
	p.charges = 3
	p.charge_t = 0.0
	await hold(90)  # 1.5초
	check("1.5초 누르면 3병 던지고 멈춤", new_shots.size() == 3 and p.charges == 0, "n=%d charges=%d" % [new_shots.size(), p.charges])

	# ── 3초마다 하나씩 다시 참 ──
	var t0: float = p.charge_t
	await wait(roundi((3.0 - t0) / DT) + 2)
	check("3초 지나면 1개 참", p.charges == 1, "charges=%d" % p.charges)
	await wait(366)
	check("6초 더 지나면 3개 꽉 참", p.charges == 3 and p.charge_t == 0.0, "charges=%d" % p.charges)
	C.zones.clear()

	# ── 웅덩이 피해: 0.15초 뒤부터 0.5초마다 8, 3초 동안 6번 = 48 ──
	await wait(30)
	put(dm, TARGET)
	await wait(3)
	var nums: Array = []
	C.num.connect(func(_pos, text, style): nums.append([text, style]))
	C.shatter(p, dm.global_position + Vector3(0, 0.3, 0))
	await wait(3)
	check("안에 있으면 느려짐 (×%.2f)" % G.WEAPONS.holy.slow, dm.slow_t > 0 and near(dm.max_speed(), G.BASE_SPEED * float(G.CLASSES[dm.cls].speed) * G.WEAPONS.holy.slow, 0.01), "slow_t=%.2f max=%.2f" % [dm.slow_t, dm.max_speed()])
	await wait(8)  # 0.18초
	check("0.15초에 첫 피해 8", near(dm.hp, 92.0), "hp=%.1f" % dm.hp)
	check("지속 피해 숫자는 dot 모양", nums.has(["8", "dot"]), str(nums))
	check("지속 피해는 넉백 시간 없음", dm.kb_t <= 0, "kb_t=%.2f" % dm.kb_t)
	await wait(180)
	check("3초 동안 6번 = 48 피해", near(dm.hp, 52.0) and C.zones.is_empty(), "hp=%.1f zones=%d" % [dm.hp, C.zones.size()])
	await wait(15)
	check("웅덩이 끝나면 둔화 풀림", dm.slow_t <= 0, "slow_t=%.2f" % dm.slow_t)

	# ── 사람에 직접 맞아도 깨지면서 웅덩이 (직접 피해는 없음) ──
	put(dm, TARGET)
	put(p, SHOOTER, "cleric", EAST_YAW)
	p.pitch = -0.3
	await wait(3)
	await hold(2)
	await wait(30)
	check("사람 근처에서 깨져 웅덩이", C.zones.size() == 1 and absf((C.zones[0].pos as Vector3).x - TARGET.x) < 1.5, "zones=%d" % C.zones.size())
	await wait(200)
	check("과녁이 웅덩이에 지져짐", dm.hp < 100.0 and dm.hp >= 52.0, "hp=%.1f" % dm.hp)

	# ── 적이 던진 웅덩이는 빨간 테두리, 나는 지져짐 ──
	put(p, SHOOTER, "cleric", EAST_YAW)
	await wait(3)
	C.shatter(dm, p.global_position)
	check("적 웅덩이 테두리는 빨강", (C.zones[-1].rim.material_override as StandardMaterial3D).albedo_color.to_html(false) == G.col(0xff3b30).to_html(false), "")
	await wait(20)
	check("적 웅덩이에선 나도 피해", p.hp < 100.0 and p.slow_t > 0, "hp=%.1f" % p.hp)

	# ── 개인전: 성직자가 자기 웅덩이에 닿아 있으면 초당 2 회복 (사용자 요청). 남은 회복 안 됨 ──
	await wait(200)
	C.zones.clear()
	put(p, SHOOTER, "cleric", EAST_YAW)
	put(dm, SHOOTER + Vector3(1.0, 0, 0))
	await wait(3)
	p.hp = 50.0
	dm.hp = 50.0
	p.no_hit_t = 0.0
	dm.no_hit_t = 0.0
	C.shatter(p, p.global_position)
	await wait(60)
	check("내 웅덩이: 초당 %.0f 회복" % G.WEAPONS.holy.heal, near(p.hp, 50.0 + G.WEAPONS.holy.heal, 0.15), "hp=%.2f" % p.hp)
	check("내 웅덩이: 나는 안 느려짐", p.slow_t <= 0, "")
	check("개인전: 다른 사람은 회복 안 됨 (지져짐)", dm.hp < 50.0, "hp=%.2f" % dm.hp)
	p.hp = 50.0
	C.shatter(p, p.global_position)  # 두 웅덩이가 겹쳐도 한 번만
	await wait(60)
	check("웅덩이가 겹쳐도 초당 %.0f" % G.WEAPONS.holy.heal, near(p.hp, 50.0 + G.WEAPONS.holy.heal, 0.15), "hp=%.2f" % p.hp)

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
