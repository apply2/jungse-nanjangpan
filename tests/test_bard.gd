extends SceneTree
## 음유시인 자동 테스트 (4.5단계, HTML에 없는 새 병과 — CLAUDE.md "음유시인 명세" 기준)
## 원뿔 안/밖, 벽 뒤 차단, 피해 주기, 누적 0.75초 춤, 1.5초 창, 3초 면역, 넘어짐 우선, 숨 소진·헐떡임,
## 삑사리, 팡파레, 춤 중 공격 가능, 봇 조준 오차 ×2.5, 베레모·볼·HUD 숨 막대를 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_bard.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p
var bard
var dm
var fails := 0
var msgs: Array[String] = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const PLAY := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const FAN := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
const HERE := Vector3(-25, 0, 18)


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = false
	G.difficulty = "normal"
	G.chosen_cls = "bard"
	G.squeak_override = 0.0  # 삑사리는 따로 시험
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G.ai_enabled = false
	main.start_match.call_deferred()
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func secs(t: float) -> int:
	return int(round(t * 60.0))


func check(name: String, ok: bool, detail := "") -> void:
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


## 연주자는 동쪽(+X)을 보고, 과녁은 그 앞 d만큼
func setup(d := 6.0, side := 0.0) -> void:
	put(bard, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(d, 0, side), "archer", PI / 2)
	dm.hp = 100.0
	await wait(2)


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	p = main.get_node("Player")
	C.toast.connect(func(t: String) -> void: msgs.append(t))
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	bard = bots[0]
	dm = bots[1]
	for i in range(2, bots.size()):
		put(bots[i], C.world.spawn_points[i * 5 % C.world.spawn_points.size()])
	put(p, Vector3(30, 0, -30), "archer")
	C.items.sniper_timer = 9999.0
	C.items.ak_timer = 9999.0
	C.items.horse_timer = 9999.0
	var T = load("res://scripts/trumpet.gd")
	var W: Dictionary = G.WEAPONS.trumpet
	var D: Dictionary = G.DANCE

	# ── 데이터 ──
	check("음유시인: 트럼펫·속도 1.05·체력 95", G.CLASSES.bard.weapon == "trumpet" and near(G.CLASSES.bard.speed, 1.05, 0.001) and G.class_hp("bard") == 95, "")
	check("봇도 음유시인을 고를 수 있음 (구현 끝)", G.bot_classes().has("bard"), str(G.bot_classes()))

	# ── 원뿔 (순수 계산) ──
	var o := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	check("원뿔 안: 정면 10m", T.in_cone(o, fwd, Vector3(0, 0, -10), 12.0, 25.0), "")
	check("원뿔 밖: 정면 13m (사거리 12)", not T.in_cone(o, fwd, Vector3(0, 0, -13), 12.0, 25.0), "")
	var a24 := deg_to_rad(24.0)
	var a26 := deg_to_rad(26.0)
	check("원뿔 안: 24°", T.in_cone(o, fwd, Vector3(sin(a24), 0, -cos(a24)) * 8, 12.0, 25.0), "")
	check("원뿔 밖: 26°", not T.in_cone(o, fwd, Vector3(sin(a26), 0, -cos(a26)) * 8, 12.0, 25.0), "")
	check("원뿔 밖: 뒤쪽", not T.in_cone(o, fwd, Vector3(0, 0, 5), 12.0, 25.0), "")

	# ── 실제로 들림 / 옆이면 안 들림 ──
	await setup(6.0)
	check("앞 6m: 들림", T.reaches(C, bard, dm, W.range, W.half_angle), "")
	await setup(6.0, 4.0)  # 약 34° 옆
	check("옆 34°: 안 들림", not T.reaches(C, bard, dm, W.range, W.half_angle), "")

	# ── 벽 뒤 차단: 집 하나를 사이에 둔다 ──
	var wall: AABB
	for a: AABB in C.world.aabbs:
		if a.size.y > 2.5 and a.size.x > 2.0 and a.size.x < 7.0 and a.size.z > 2.0 and a.position.y < 0.5:
			wall = a
			break
	var wc := wall.get_center()
	put(bard, Vector3(wall.position.x - 1.5, 0, wc.z), "bard", -PI / 2)
	put(dm, Vector3(wall.end.x + 1.5, 0, wc.z), "archer", PI / 2)
	dm.hp = 100.0
	await wait(2)
	var dist: float = bard.global_position.distance_to(dm.global_position)
	check("벽 뒤 차단: 원뿔 안이어도 벽에 막히면 안 들림", dist < W.range and not T.reaches(C, bard, dm, W.range, W.half_angle), "거리 %.1f" % dist)
	bard.scripted_input = PLAY
	await wait(secs(1.0))
	bard.scripted_input = IDLE
	check("벽 뒤: 피해·춤 없음", dm.hp == 100.0 and dm.dance_t <= 0 and T.heard_sum(dm) == 0.0, "hp=%.1f" % dm.hp)

	# ── 피해 주기: 0.25초마다 1.5 ──
	await setup(6.0)
	bard.scripted_input = PLAY
	await wait(secs(0.5) + 1)
	check("연주 중", bard.playing, "")
	check("0.5초에 2번 맞음 (1.5×2)", near(dm.hp, 100.0 - 3.0, 0.01), "hp=%.2f" % dm.hp)
	check("넉백 없음", Vector2(dm.velocity.x, dm.velocity.z).length() < 0.05 and dm.kb_t <= 0 and dm.stagger <= 0, "v=%s" % dm.velocity)

	# ── 춤: 누적 0.75초 ──
	await wait(secs(0.15))  # 이제 0.65초쯤
	check("0.65초: 아직 안 춤", dm.dance_t <= 0, "들은 시간 %.2f" % T.heard_sum(dm))
	await wait(secs(0.15))
	check("0.75초 넘게 들으면 2초 춤", dm.dance_t > 1.8, "dance_t=%.2f" % dm.dance_t)
	check("춤추면 이동 ×0.6", near(dm.max_speed(), G.BASE_SPEED * G.CLASSES.archer.speed * D.speed, 0.01), "max=%.2f" % dm.max_speed())
	bard.scripted_input = IDLE
	await wait(secs(2.05))
	check("2초 뒤 춤 끝, 3초 면역", dm.dance_t <= 0 and dm.dance_immune > 2.8, "immune=%.2f" % dm.dance_immune)
	bard.scripted_input = PLAY
	await wait(secs(2.0))
	check("면역 중엔 계속 들어도 안 춤", dm.dance_t <= 0, "immune=%.2f" % dm.dance_immune)
	bard.breath = W.breath_max  # 숨이 먼저 떨어지지 않게
	await wait(secs(1.0) + secs(0.8))
	check("면역 끝나고 다시 0.75초 들으면 또 춤", dm.dance_t > 0, "dance_t=%.2f" % dm.dance_t)
	bard.scripted_input = IDLE
	await wait(secs(2.2))

	# ── 1.5초 창: 띄엄띄엄 들으면 누적 ──
	await setup(6.0)
	bard.breath = W.breath_max
	bard.scripted_input = PLAY
	await wait(secs(0.4))
	bard.scripted_input = IDLE
	await wait(secs(0.3))
	bard.scripted_input = PLAY
	await wait(secs(0.4))
	bard.scripted_input = IDLE
	check("0.4초 + 쉼 0.3초 + 0.4초 = 1.5초 안 누적 0.8초 → 춤", dm.dance_t > 0, "들은 시간 %.2f" % T.heard_sum(dm))
	await wait(secs(2.2) + secs(3.1))
	await setup(6.0)
	bard.scripted_input = PLAY
	await wait(secs(0.4))
	bard.scripted_input = IDLE
	await wait(secs(1.4))
	bard.scripted_input = PLAY
	await wait(secs(0.4))
	bard.scripted_input = IDLE
	check("0.4초 + 쉼 1.4초 + 0.4초 → 창 밖으로 빠져서 안 춤", dm.dance_t <= 0, "들은 시간 %.2f" % T.heard_sum(dm))

	# ── 넘어짐 우선 ──
	await setup(6.0)
	bard.breath = W.breath_max
	bard.scripted_input = PLAY
	await wait(secs(0.8))
	bard.scripted_input = IDLE
	check("(넘어짐 시험 준비) 춤추는 중", dm.dance_t > 0, "")
	dm.trip()
	await wait(2)
	check("넘어지면 춤은 멈추고 남은 시간은 사라짐", dm.dance_t <= 0 and dm.fall_t > 0, "dance_t=%.2f" % dm.dance_t)
	await wait(secs(3.5))

	# ── 춤추는 중에도 공격 가능 ──
	await setup(6.0)
	put(dm, HERE + Vector3(6, 0, 0), "barbarian", PI / 2)
	await wait(2)
	dm.dance_t = 1.5
	var n0: int = C.projectiles.size()
	dm.scripted_input = PLAY
	await wait(3)
	dm.scripted_input = IDLE
	check("춤추는 중에도 돌멩이를 던짐", C.projectiles.size() > n0, "")

	# ── 봇 조준 오차 ×2.5 ──
	put(dm, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	bard.ai.ex = 0.1
	bard.ai.ey = 0.0
	dm.dance_t = 0.0
	put(bard, HERE, "barbarian", -PI / 2)
	bard.ai.ex = 0.1
	bard.ai.ey = 0.0
	var a0: Dictionary = bard.ai.aim_solve(bard, dm)
	bard.dance_t = 1.0
	var a1: Dictionary = bard.ai.aim_solve(bard, dm)
	bard.dance_t = 0.0
	check("춤추는 봇은 조준 오차 ×2.5", near(a1.yaw - a0.yaw, 0.1 * (D.bot_err - 1.0), 0.001), "차이 %.3f" % (a1.yaw - a0.yaw))

	# ── 숨 소진 (내가 음유시인) ──
	put(p, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(30, 0, 0), "archer")
	await wait(2)
	msgs.clear()
	p.scripted_input = PLAY
	await wait(secs(2.9))
	check("2.9초: 아직 연주 중", p.playing and p.breath < 0.2, "breath=%.2f" % p.breath)
	await wait(secs(0.15))
	check("3초 불면 숨이 참: 연주 멈춤 + 1초 헐떡임", not p.playing and p.gasp_t > 0.8 and msgs.has("숨이 찼다!"), str(msgs))
	check("헐떡이면 이동 ×0.8", near(p.max_speed(), G.BASE_SPEED * G.CLASSES.bard.speed * W.gasp_speed, 0.01), "max=%.2f" % p.max_speed())
	await wait(secs(0.5))
	check("헐떡이는 동안은 눌러도 못 붊", not p.playing, "")
	await wait(secs(0.6))
	check("1초 뒤 다시 불 수 있음", p.playing, "")
	p.scripted_input = IDLE
	var b0: float = p.breath
	await wait(secs(1.0))
	check("안 불면 초당 1.5초씩 회복", near(p.breath - b0, W.breath_regen, 0.05), "%.2f → %.2f" % [b0, p.breath])
	await wait(secs(2.0))
	check("최대 3초까지만", near(p.breath, W.breath_max, 0.001), "breath=%.2f" % p.breath)

	# ── 삑사리 ──
	G.squeak_override = 1.0
	msgs.clear()
	var S = root.get_node("Sfx")
	S.played.clear()
	p.scripted_input = PLAY
	await wait(2)
	check("삑사리: 연주 안 됨 + 문구 + 소리", not p.playing and p.squeak_t > 0.7 and msgs.has("삑사리!") and S.played.has("squeak"), str(msgs))
	await wait(secs(0.5))
	check("삑사리 동안은 눌러도 못 붊", not p.playing, "")
	G.squeak_override = 0.0
	await wait(secs(0.4))
	check("0.8초 뒤 다시 붊", p.playing, "")
	p.scripted_input = IDLE
	await wait(2)

	# ── 팡파레 ──
	var F: Dictionary = G.WEAPONS.fanfare
	put(p, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(2.5, 0, 0), "archer", PI / 2)
	await wait(2)
	S.played.clear()
	p.scripted_input = FAN
	await wait(2)
	p.scripted_input = IDLE
	check("팡파레: 앞 2.5m에 15 피해 + 넉백", near(dm.hp, 100.0 - F.dmg, 0.01) and dm.velocity.x > 3.0, "hp=%.1f vx=%.1f" % [dm.hp, dm.velocity.x])
	check("팡파레 소리", S.played.has("fanfare"), str(S.played))
	check("우클릭해도 확대 안 함", p.cam.fov > 80.0, "fov=%.1f" % p.cam.fov)
	put(dm, HERE + Vector3(2.5, 0, 0), "archer", PI / 2)
	await wait(2)
	p.scripted_input = FAN
	await wait(3)
	p.scripted_input = IDLE
	check("재사용 6초: 바로 다시는 안 나감", dm.hp == 100.0 and p.fan_cd > 5.5, "cd=%.1f" % p.fan_cd)
	p.fan_cd = 0.0
	put(dm, HERE + Vector3(4.5, 0, 0), "archer", PI / 2)
	await wait(2)
	p.scripted_input = FAN
	await wait(2)
	p.scripted_input = IDLE
	check("팡파레 3.5m 밖은 안 맞음", dm.hp == 100.0, "hp=%.1f" % dm.hp)

	# ── 모델·HUD ──
	put(p, HERE, "bard", -PI / 2)
	await wait(3)
	var m = p.model
	check("베레모(투구 자리)·볼·트럼펫이 있음", m.helm != null and m.cheeks.size() == 2 and m.weapons.has("trumpet"), "")
	var c0: float = m.cheeks[0].scale.x
	p.scripted_input = PLAY
	await wait(20)
	check("연주하면 볼이 빵빵해짐 (×1.6)", m.cheeks[0].scale.x / c0 > 1.5, "%.2f배" % (m.cheeks[0].scale.x / c0))
	check("HUD 숨 막대가 보이고 줄어듦", main.hud._breath.visible and main.hud._breath.value < W.breath_max, "")
	p.scripted_input = IDLE
	put(dm, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(2)
	C.damage(p, dm, 10, "bow", true, Vector3(-1, 0, 0))
	check("헤드샷이면 베레모가 날아감", not p.helmet and p.model.helm == null, "")
	dm.dance_t = 1.0
	await wait(30)
	check("춤추면 머리 위에 음표", dm.model._notes.size() > 0, "n=%d" % dm.model._notes.size())

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
