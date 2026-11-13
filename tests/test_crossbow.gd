extends SceneTree
## 석궁 자동 테스트 — HTML fire('crossbow') / damage와 같은 결과인지 + 휠 장전(사용자 요청: 휠 25칸을 굴려야 다시 쏨) 확인.
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


## 휠을 k칸 굴린다 (한 칸 굴리고 칸 사이 간격만큼 쉼)
func spin(k: int, gap_frames := 10) -> void:
	var w: Dictionary = IDLE.duplicate()
	w["wind"] = true
	for i in k:
		p.scripted_input = w
		await physics_frame
		p.scripted_input = IDLE
		await wait(gap_frames - 1)


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
	check("쏘면 0칸부터 (휠 장전 25칸)", p.xb_wind == 0 and X.notches == 25, "wind=%d" % p.xb_wind)
	var walk: float = G.BASE_SPEED * float(G.CLASSES.crossbow.speed)
	check("재장전 중엔 이동 속도 ×0.9", near(p.max_speed(), walk * 0.9, 0.01), "max=%.2f" % p.max_speed())
	var NX := int(X.notches)
	check("쏘면 큰 반동 (몸 10, 화면 11 — 한 프레임 감쇠 뒤)", p.rec_v > 7.0 and p.v_rec_v > 7.0, "rec_v=%.2f v_rec_v=%.2f" % [p.rec_v, p.v_rec_v])

	# ── 자동 장전 없음: 5초 기다려도 못 쏨 ──
	await wait(300)
	await hold(30)
	check("자동 장전 없음 (5초 지나도 0칸, 못 쏨)", p.xb_wind == 0 and new_shots.is_empty(), "wind=%d n=%d" % [p.xb_wind, new_shots.size()])

	# ── 휠 한 칸 = 한 칸, 중간에 멈춰도 유지 ──
	var S: Node = root.get_node("Sfx")
	S.played.clear()
	await spin(6)
	check("휠 6칸 → 6/25", p.xb_wind == 6, "wind=%d" % p.xb_wind)
	check("칸마다 끼릭 소리", S.played.count("xbow_click") == 6, str(S.played))
	await wait(120)
	await hold(20)
	check("멈춰도 6칸 그대로, 아직 못 쏨", p.xb_wind == 6 and new_shots.is_empty(), "wind=%d" % p.xb_wind)
	# 한 번에 휙 돌리면 (매 프레임 휠) 칸 사이 간격만큼만 감김
	var burst: Dictionary = IDLE.duplicate()
	burst["wind"] = true
	p.scripted_input = burst
	await wait(5)
	p.scripted_input = IDLE
	await wait(10)
	check("한 번에 휙 돌려도 2칸까지만 (1칸 + 남겨 둔 1칸)", p.xb_wind == 8, "wind=%d" % p.xb_wind)
	await spin(NX - 8)
	check("남은 칸 다 감으면 장전 완료 (걸쇠·볼트 소리)", p.xb_wind == NX and S.played.has("xbow_latch") and S.played.has("seat"), str(S.played))
	await spin(2)
	check("다 감았으면 휠 무시", p.xb_wind == NX, "wind=%d" % p.xb_wind)
	check("장전되면 이동 속도 원래대로", near(p.max_speed(), walk, 0.01), "max=%.2f" % p.max_speed())
	await hold(2)
	check("장전되면 쏨", new_shots.size() == 1 and p.xb_wind == 0, "n=%d" % new_shots.size())
	# 누르고 감으면 다 감는 대로 쏨 (가장 빨라도 25칸 × notch_gap)
	var fw: Dictionary = FIRE.duplicate()
	fw["wind"] = true
	await wait(20)
	new_shots.clear()
	var prev: Array = C.projectiles.duplicate()
	var shot_at := -1
	p.scripted_input = fw
	for i in int(NX * X.notch_gap * 60) + 40:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				new_shots.append(pr)
				if shot_at < 0:
					shot_at = i
		prev = C.projectiles.duplicate()
	p.scripted_input = IDLE
	check("누르고 휠을 계속 굴리면 다 감는 대로 한 발", new_shots.size() == 1 and shot_at >= int((NX - 1) * X.notch_gap * 60), "n=%d at=%d" % [new_shots.size(), shot_at])
	await wait(30)

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

	# ── 넘어져도 휠은 감김, 부활하면 장전된 채 ──
	await wait(30)
	await hold(30)
	check("장전 안 됐으면 못 쏨", new_shots.is_empty(), "n=%d wind=%d" % [new_shots.size(), p.xb_wind])
	var w0: int = p.xb_wind
	p.trip()
	await spin(2)
	check("넘어져도 휠은 감김", p.xb_wind == w0 + 2, "wind %d→%d" % [w0, p.xb_wind])
	await wait(60)
	put(p, SHOOTER, "crossbow", EAST_YAW)
	check("부활하면 장전된 채", p.xb_wind == int(X.notches) and p.xb_show == 1.0, "wind=%d" % p.xb_wind)

	# ── 3인칭 장전 자세: 반쯤 감으면 팔이 내려가 있음 ──
	await wait(5)
	var arm_ready: float = p.model.arm_r.rotation.x
	await hold(1)
	await spin(5)
	await wait(20)
	var arm_reload: float = p.model.arm_r.rotation.x
	check("반쯤 감았을 때 3인칭 팔이 내려감", arm_reload > arm_ready + 0.5, "준비 %.2f → 장전 %.2f (show %.2f)" % [arm_ready, arm_reload, p.xb_show])

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
