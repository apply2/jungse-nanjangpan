extends SceneTree
## 피격·피해·부활 자동 테스트 — HTML hitTest / damage / kill / spawn / simulate(재생)와 같은 결과인지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_combat.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var combat
var p      # 나
var dm     # 시험용 허수아비
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const SHOOTER := Vector3(-25, 0, 18)
const TARGET := Vector3(-19, 0, 18)
const EAST := Vector3(1, 0, 0)


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


## 엔티티를 그 자리에 깨끗한 상태로 세운다
func put(e, pos: Vector3, cls := "archer") -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	combat = main.get_node("Combat")
	p = main.get_node("Player")
	var bots: Array = combat.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	# 나머지 허수아비는 멀리 치운다
	for i in range(1, bots.size()):
		put(bots[i], combat.world.spawn_points[i * 5 % combat.world.spawn_points.size()])
	put(p, SHOOTER)
	put(dm, TARGET)
	await wait(5)

	# ── 판정 ──
	var C = combat
	var r: Dictionary = C.hit_test(SHOOTER + Vector3(0, 1.62, 0), EAST * 12, dm, 0.03)
	check("머리 판정", not r.is_empty() and r.head, str(r))
	# HTML segSeg는 표면이 아니라 축에 가장 가까운 곳의 t를 준다 → 0.5
	r = C.hit_test(SHOOTER + Vector3(0, 0.9, 0), EAST * 12, dm, 0.03)
	check("몸 판정", not r.is_empty() and not r.head and near(r.t, 0.5, 0.02), str(r))
	r = C.hit_test(SHOOTER + Vector3(0, 0.9, 0.6), EAST * 12, dm, 0.03)
	check("빗나감", r.is_empty(), str(r))
	r = C.hit_test(SHOOTER + Vector3(0, 2.1, 0), EAST * 12, dm, 0.03)
	check("머리 위로 빗나감", r.is_empty(), str(r))

	# ── 몸 피해 + 넉백 ──
	C.damage(dm, p, 35.0, "bow", false, EAST)
	check("몸 피해 35", near(dm.hp, 65.0), "hp=%.1f" % dm.hp)
	check("활 넉백 (6.5×0.7)", near(dm.velocity.x, 4.55) and near(dm.velocity.y, 3.4), "v=%s" % dm.velocity)
	check("넉백 시간·봇 경직", near(dm.kb_t, 0.45) and near(dm.stagger, 0.3), "kb_t=%.2f stagger=%.2f" % [dm.kb_t, dm.stagger])

	# ── 헤드샷: 투구 ×1.5 → 투구 날아감 → 맨머리 ×2 ──
	C.damage(dm, p, 35.0, "bow", true, EAST)
	check("투구 헤드샷 ×1.5", near(dm.hp, 65.0 - 52.5), "hp=%.1f" % dm.hp)
	check("투구 날아감", not dm.helmet and C.loose_helms.size() == 1 and dm.model.helm == null, "helmet=%s loose=%d" % [dm.helmet, C.loose_helms.size()])
	var kills0: int = p.kills
	C.damage(dm, p, 35.0, "bow", true, EAST)  # 70 → 죽음
	check("맨머리 ×2로 처치", not dm.alive and dm.hp == 0.0 and dm.deaths == 1 and p.kills == kills0 + 1, "alive=%s deaths=%d kills=%d" % [dm.alive, dm.deaths, p.kills])
	var hp_dead: float = dm.hp
	C.damage(dm, p, 35.0, "bow", false, EAST)
	check("죽은 대상은 안 맞음", dm.hp == hp_dead and dm.deaths == 1, "")

	# ── 투구가 땅에 떨어짐 ──
	await wait(150)
	var hy: float = C.loose_helms[0].o.position.y if C.loose_helms.size() > 0 else 99.0
	check("투구가 땅에 떨어짐", hy < 0.3, "y=%.2f" % hy)

	# ── 3초 뒤 부활 ──
	await wait(40)  # 사망 후 190프레임 ≈ 3.17초
	check("3초 뒤 부활", dm.alive and dm.helmet and dm.hp == float(G.class_hp(dm.cls)) and dm.model.helm != null,
		"alive=%s hp=%.0f helmet=%s" % [dm.alive, dm.hp, dm.helmet])
	check("부활 직후 무적", dm.invuln > 1.0, "invuln=%.2f" % dm.invuln)
	var hp0: float = dm.hp
	C.damage(dm, p, 35.0, "bow", false, EAST)
	check("무적 중엔 안 맞음", dm.hp == hp0, "hp=%.1f" % dm.hp)

	# ── 체력 재생: 5초 기다린 뒤 초당 10 ──
	put(dm, TARGET, "archer")
	C.damage(dm, p, 35.0, "bow", false, EAST)
	await wait(294)  # 4.9초
	check("5초 전엔 재생 없음", near(dm.hp, 65.0), "hp=%.1f" % dm.hp)
	await wait(66)   # 6.0초 → 1초 재생
	check("재생 초당 10", absf(dm.hp - 75.0) <= 1.0, "hp=%.1f" % dm.hp)
	put(dm, TARGET, "cleric")
	C.damage(dm, p, 35.0, "bow", false, EAST)
	await wait(360)
	check("성직자 재생 초당 20", absf(dm.hp - 85.0) <= 1.0, "hp=%.1f" % dm.hp)

	# ── 석궁 경직·플레이어는 경직 없음 ──
	put(dm, TARGET, "archer")
	C.damage(dm, p, 75.0, "crossbow", false, EAST)
	check("석궁 봇 경직 0.5", near(dm.stagger, 0.5) and near(dm.velocity.x, 11.0), "stagger=%.2f vx=%.2f" % [dm.stagger, dm.velocity.x])
	put(p, SHOOTER)
	C.damage(p, dm, 10.0, "stone", false, -EAST)
	check("플레이어는 경직 없음", p.stagger <= 0 and near(p.kb_t, 0.45) and near(p.velocity.x, -4.0), "stagger=%.2f vx=%.2f" % [p.stagger, p.velocity.x])

	# ── 넘어지면 머리 판정이 바닥으로 ──
	put(dm, TARGET, "archer")
	await wait(3)
	dm.trip()
	await wait(10)
	r = C.hit_test(SHOOTER + Vector3(0, 1.62, 0), EAST * 12, dm, 0.03)
	check("넘어지면 서 있던 머리 높이는 빗나감", r.is_empty(), str(r))
	await wait(40)

	# ── 스폰 지점: 다른 사람에게서 가장 먼 4곳 중 하나 ──
	put(dm, TARGET)
	var ok := true
	for n in 20:
		C.spawn(dm)
		var others: Array = C.ents.filter(func(e): return e != dm and e.alive)
		var scored: Array = []
		for sp: Vector3 in C.world.spawn_points:
			var d := INF
			for o in others:
				d = minf(d, o.global_position.distance_to(sp))
			scored.append(d)
		scored.sort()
		scored.reverse()
		var mine := INF
		for o in others:
			mine = minf(mine, o.global_position.distance_to(dm.global_position))
		if mine < scored[mini(3, scored.size() - 1)] - 0.001:
			ok = false
	check("가장 먼 4곳 중 스폰", ok, "%d개 지점" % C.world.spawn_points.size())

	# ── 내가 죽고 부활 ──
	put(p, SHOOTER)
	C.damage(p, dm, 999.0, "stone", false, EAST)
	check("플레이어 죽음", not p.alive and near(p.respawn, 3.0) and p.last_hit.by == dm, "alive=%s" % p.alive)
	await wait(185)
	check("플레이어 부활", p.alive and p.hp == float(G.class_hp(p.cls)) and p.invuln > 1.0, "alive=%s hp=%.0f" % [p.alive, p.hp])

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
