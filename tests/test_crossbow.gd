extends SceneTree
## 석궁 자동 테스트 — HTML weaponUpdate('crossbow') / fire('crossbow') / damage와 같은 결과인지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_crossbow.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나 (석궁병)
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


## n 프레임 동안 공격 키를 누르고(release면 놓고), 새로 생긴 투사체를 new_shots에 모은다
func hold(n: int, release := true) -> void:
	new_shots.clear()
	var prev: Array = C.projectiles.duplicate()
	p.scripted_input = FIRE
	for i in n:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				new_shots.append(pr)
		prev = C.projectiles.duplicate()
	if release:
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
	put(p, SHOOTER, "crossbow", WEST_YAW)
	put(dm, Vector3(-25, 0, 40))
	await wait(5)
	var X: Dictionary = G.WEAPONS.crossbow
	check("석궁병 무기 = 석궁, 체력 110", p.wep == "crossbow" and p.model.weapons.has("crossbow") and p.hp == 110.0, "wep=%s hp=%.0f" % [p.wep, p.hp])

	# ── 누르면 바로 한 발 ──
	await hold(1)
	check("누르면 바로 한 발", new_shots.size() == 1, "n=%d" % new_shots.size())
	if new_shots.size() == 1:
		var pr: Dictionary = new_shots[0]
		check("속도 100", near((pr.vel as Vector3).length(), 100.0, 0.5), "v=%.1f" % (pr.vel as Vector3).length())
		check("중력 2 (거의 직선), 피해 75", pr.grav == 2.0 and pr.dmg == 75.0, "grav=%.0f dmg=%.0f" % [pr.grav, pr.dmg])
	check("장전 4초", near(p.cd, 4.0 - DT, 0.03), "cd=%.3f" % p.cd)
	check("쏘면 큰 반동 (몸 10, 화면 11 — 한 프레임 감쇠 뒤)", p.rec_v > 7.0 and p.v_rec_v > 7.0, "rec_v=%.2f v_rec_v=%.2f" % [p.rec_v, p.v_rec_v])

	# ── 누르고 있으면 장전 끝나는 대로 다음 발 (4초마다) ──
	await wait(30)
	await hold(300)  # 5초
	check("5초 누르고 있으면 장전 끝나고 한 발만 더", new_shots.size() == 1, "n=%d" % new_shots.size())
	await wait(250)

	# ── 몸에 맞으면 75, 볼트가 꽂힘, 크게 밀림, 봇은 0.5초 경직 ──
	put(p, SHOOTER, "crossbow", EAST_YAW)
	p.pitch = -0.08
	put(dm, TARGET)
	await wait(3)
	await hold(1)
	var bolt: Node3D = new_shots[0].mesh if new_shots.size() > 0 else null
	await wait(6)
	check("몸에 맞아 75 피해", near(dm.hp, 25.0), "hp=%.1f" % dm.hp)
	check("넉백 11 (동쪽으로 크게)", dm.velocity.x > 6.0, "v=%s" % dm.velocity)
	check("봇 경직 0.5초", dm.stagger > 0.35, "stagger=%.2f" % dm.stagger)
	check("볼트가 몸에 꽂힘", bolt != null and is_instance_valid(bolt) and bolt.get_parent() == dm.model.body, "")

	# ── 헤드샷이면 한 방 (75×1.5 = 112.5) ──
	await wait(250)
	put(p, SHOOTER, "crossbow", EAST_YAW)
	put(dm, TARGET, "crossbow")  # 체력 110짜리도
	await wait(3)
	var kills0: int = p.kills
	await hold(1)
	if new_shots.size() > 0:  # 머리 높이로 곧게
		var q: Dictionary = new_shots[0]
		q.pos = Vector3(SHOOTER.x + 1, 1.62, SHOOTER.z)
		q.vel = Vector3(100, 0, 0)
		q.grav = 0.0
	await wait(6)
	check("헤드샷 한 방 (체력 110도)", not dm.alive and p.kills == kills0 + 1, "alive=%s hp=%.1f" % [dm.alive, dm.hp])

	# ── 장전 중엔 못 쏘고, 넘어져도 장전은 계속 됨 ──
	await wait(30)
	await hold(30)
	check("장전 중엔 못 쏨", new_shots.is_empty(), "n=%d cd=%.2f" % [new_shots.size(), p.cd])
	var cd0: float = p.cd
	p.trip()
	await wait(30)
	check("넘어져도 장전 시간은 흐름", near(p.cd, cd0 - 30 * DT, 0.03), "cd %.2f→%.2f" % [cd0, p.cd])

	# ── 3인칭 장전 자세: 장전 중간엔 팔이 내려가 있음 ──
	await wait(100)
	put(p, SHOOTER, "crossbow", EAST_YAW)
	await wait(5)
	var arm_ready: float = p.model.arm_r.rotation.x
	await hold(1)
	await wait(120)  # 장전 절반쯤
	var arm_reload: float = p.model.arm_r.rotation.x
	check("장전 중엔 3인칭 팔이 내려감", arm_reload > arm_ready + 0.5, "준비 %.2f → 장전 %.2f" % [arm_ready, arm_reload])

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
