extends SceneTree
## 활 자동 테스트 — HTML weaponUpdate('bow') / fire('bow') / stickArrow / worldArrows와 같은 결과인지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_bow.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p      # 나 (궁수)
var dm     # 과녁 허수아비
var fails := 0
var toasts: Array = []
var new_shots: Array = []  # 이번에 새로 생긴 투사체

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


## n 프레임 누르고 있다가 놓는다. 놓은 프레임까지 새로 생긴 투사체를 new_shots에 모은다.
func pull(n: int, release := true) -> void:
	new_shots.clear()
	var prev: Array = C.projectiles.duplicate()
	p.scripted_input = FIRE
	for i in n + (1 if release else 0):
		if release and i == n:
			p.scripted_input = IDLE
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				new_shots.append(pr)
		prev = C.projectiles.duplicate()


## n 프레임 더 기다리며 새로 생긴 투사체를 new_shots에 보탠다
func collect(n: int) -> void:
	var prev: Array = C.projectiles.duplicate()
	for i in n:
		await physics_frame
		for pr in C.projectiles:
			if not prev.has(pr):
				new_shots.append(pr)
		prev = C.projectiles.duplicate()


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	G.third_person = false  # 3인칭 조준 보정은 카메라 위치에 따라 달라지므로 1인칭으로
	C = main.get_node("Combat")
	p = main.get_node("Player")
	C.toast.connect(func(t): toasts.append(t))
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], C.world.spawn_points[i * 5 % C.world.spawn_points.size()])
	put(p, SHOOTER, "archer", WEST_YAW)
	put(dm, Vector3(-25, 0, 40))  # 처음엔 치워 둔다
	await wait(5)
	var B: Dictionary = G.WEAPONS.bow
	check("궁수 무기 = 활", p.wep == "bow" and p.model.weapons.has("bow"), "wep=%s" % p.wep)

	check("수치: 끝까지 1초·화살 거는 데 0.3초·최소 0.15초·피해 15~50", B.full == 1.0 and B.nock == 0.3 and B.min_charge == 0.15 and B.dmg_min == 15 and B.dmg_max == 50, "")
	check("차지 비율: 최소에서 0, 끝까지면 1", G.bow_t(B.min_charge) == 0.0 and G.bow_t(B.full) == 1.0 and near(G.bow_t(0.575), 0.5, 0.001), "")

	# ── 너무 짧게 놓으면 최소(0.15초)까지 마저 당긴 뒤 최소 세기로 ──
	await pull(3)
	check("0.05초에 놓으면 바로는 안 나감", new_shots.is_empty() and p.charging, "n=%d charging=%s" % [new_shots.size(), p.charging])
	await collect(12)
	check("최소까지 마저 당기고 한 발", new_shots.size() == 1 and not p.charging, "n=%d" % new_shots.size())
	if new_shots.size() == 1:
		check("최소 세기: 피해 15·속도 28", new_shots[0].dmg == float(B.dmg_min) and near((new_shots[0].vel as Vector3).length(), float(B.speed_min), 0.6),
			"dmg=%.0f v=%.1f" % [new_shots[0].dmg, (new_shots[0].vel as Vector3).length()])
	await wait(30)

	# ── 반쯤 당기기: 속도·피해가 당긴 만큼 ──
	await pull(36)
	check("0.6초 당기고 놓으면 한 발", new_shots.size() == 1, "n=%d" % new_shots.size())
	if new_shots.size() == 1:
		var pr: Dictionary = new_shots[0]
		var t: float = G.bow_t(36 * DT)
		var v: Vector3 = pr.vel
		check("속도 = 28~72 중 당긴 만큼", near(v.length(), lerpf(B.speed_min, B.speed_max, t), 0.6), "v=%.1f 기대 %.1f" % [v.length(), lerpf(B.speed_min, B.speed_max, t)])
		check("피해 = 15~50 중 당긴 만큼", pr.dmg == roundf(lerpf(B.dmg_min, B.dmg_max, t)), "dmg=%.0f 기대 %.0f" % [pr.dmg, roundf(lerpf(B.dmg_min, B.dmg_max, t))])
		check("화살 모양은 날아가는 방향을 봄", (pr.mesh as Node3D).global_basis.z.normalized().dot(v.normalized()) > 0.99, "")
	check("다음 화살 거는 데 0.3초", near(p.cd, float(B.nock) - DT, 0.03), "cd=%.3f" % p.cd)
	check("쏘면 반동 (몸·화면)", p.rec_v > 0 and p.v_rec_v > 0, "rec_v=%.2f v_rec_v=%.2f" % [p.rec_v, p.v_rec_v])

	# ── 화살 거는 동안엔 못 당김 ──
	await pull(10, false)
	check("재사용 대기 중엔 못 당김", not p.charging and p.charge == 0.0, "charging=%s cd=%.2f" % [p.charging, p.cd])
	await wait(20)  # 대기가 끝나면 누르고 있던 걸로 당기기 시작
	check("대기 끝나면 당기기 시작", p.charging and p.charge > 0.1, "charge=%.2f" % p.charge)
	p.scripted_input = IDLE
	await wait(80)

	# ── 연사: 짧게 끊어 쏘면 1.4초에 3발 ──
	new_shots.clear()
	for i in 3:
		p.scripted_input = FIRE
		await collect(3)
		p.scripted_input = IDLE
		await collect(25)
	check("짧게 끊어 쏘면 1.4초에 3발", new_shots.size() == 3, "n=%d" % new_shots.size())
	await wait(30)

	# ── R로 당기기 취소: 안 나가고, 키를 뗄 때까지 다시 안 당김 ──
	toasts.clear()
	await pull(30, false)
	var cancel_in: Dictionary = FIRE.duplicate()
	cancel_in["cancel"] = true
	p.scripted_input = cancel_in
	await collect(1)
	p.scripted_input = FIRE
	await collect(20)
	check("R: 당기기 취소 (계속 누르고 있어도 다시 안 당김)", not p.charging and p.charge == 0.0 and new_shots.is_empty() and toasts.has("당기기 취소"), "charging=%s n=%d" % [p.charging, new_shots.size()])
	p.scripted_input = IDLE
	await collect(5)
	check("취소하고 놓아도 안 나감", new_shots.is_empty(), "n=%d" % new_shots.size())
	await pull(10, false)
	check("다시 누르면 당김", p.charging, "")
	p.scripted_input = IDLE
	await wait(40)

	# ── 끝까지 당기면 알림 소리 (내 화면) ──
	var S: Node = root.get_node("Sfx")
	S.played.clear()
	await pull(int(B.full * 60) + 3, false)
	check("끝까지 당기면 bow_full 소리", S.played.count("bow_full") == 1, str(S.played))
	p.scripted_input = IDLE
	await wait(40)

	# ── 끝까지 당겨서 몸에 맞힘: 50 피해, 몸에 꽂힘 ──
	put(p, SHOOTER, "archer", EAST_YAW)
	p.pitch = -0.08  # 몸통 높이로
	put(dm, TARGET)
	await wait(3)
	await pull(95)
	check("끝까지 당기면 최대 속도 72", new_shots.size() == 1 and near((new_shots[0].vel as Vector3).length(), 72.0, 0.6), "n=%d" % new_shots.size())
	var arrow: Node3D = new_shots[0].mesh if new_shots.size() > 0 else null
	await wait(10)
	check("몸에 맞아 50 피해", near(dm.hp, 100.0 - float(B.dmg_max)), "hp=%.1f" % dm.hp)
	check("넉백 (동쪽으로 밀림)", dm.velocity.x > 2.0, "v=%s" % dm.velocity)
	check("화살이 몸에 꽂힘", arrow != null and is_instance_valid(arrow) and arrow.get_parent() == dm.model.body, "parent=%s" % (arrow.get_parent() if arrow and is_instance_valid(arrow) else null))
	check("맞은 화살은 날아가는 목록에서 빠짐", C.projectiles.is_empty(), "n=%d" % C.projectiles.size())

	# ── 머리: 투구 ×1.5 → 50×1.5, 투구 날림 ──
	await wait(70)
	put(dm, TARGET)
	await wait(3)
	await pull(95)
	if new_shots.size() > 0:  # 머리 높이로 곧게 날린다
		var q: Dictionary = new_shots[0]
		q.pos = Vector3(SHOOTER.x + 1, 1.62, SHOOTER.z)
		q.vel = Vector3(72, 0, 0)
		q.grav = 0.0
	await wait(10)
	check("헤드샷 75 (50×1.5)", near(dm.hp, 100.0 - float(B.dmg_max) * 1.5), "hp=%.1f" % dm.hp)
	check("투구 날아감", not dm.helmet, "helmet=%s" % dm.helmet)
	var harrow: Node3D = new_shots[0].mesh if new_shots.size() > 0 else null
	check("화살이 머리에 꽂힘", harrow != null and is_instance_valid(harrow) and harrow.get_parent() == dm.model.head, "")

	# ── 땅에 맞으면 꽂혀 있다가 10초 뒤 사라짐 ──
	put(dm, Vector3(-25, 0, 40))
	await wait(70)
	p.pitch = -1.2
	for w in C.world_arrows:  # 앞에서 꽂힌 화살이 도중에 사라져 수가 안 맞지 않게
		w.life = 999.0
	var stuck0: int = C.world_arrows.size()
	await pull(30)
	await wait(10)
	check("땅에 꽂힘", C.projectiles.is_empty() and C.world_arrows.size() == stuck0 + 1, "날아감=%d 꽂힘=%d→%d" % [C.projectiles.size(), stuck0, C.world_arrows.size()])
	if C.world_arrows.size() == stuck0 + 1:
		var wa: Dictionary = C.world_arrows[-1]
		var m: Node3D = wa.m
		check("꽂힌 화살은 땅 근처", m.global_position.y < 0.5, "y=%.2f" % m.global_position.y)
		wa.life = 0.1
		await wait(10)
		check("시간 지나면 사라짐", C.world_arrows.size() == stuck0 and not is_instance_valid(m), "n=%d" % C.world_arrows.size())

	# ── 끝까지 당긴 채 버티면 후들거리다 3초에 손이 미끄러짐 ──
	await wait(70)
	put(p, SHOOTER, "archer", WEST_YAW)
	await wait(3)
	toasts.clear()
	var yaw0: float = p.yaw
	await pull(int((float(B.full) + 1.25) * 60), false)  # 끝까지 당김 + 1.25초 버팀
	var dyaw := absf(p.yaw - yaw0)
	check("끝까지 당긴 뒤 1초 넘으면 조준이 흔들림", dyaw > 0.001 and new_shots.is_empty() and p.hold_t > 0.9, "dyaw=%.4f hold=%.2f" % [dyaw, p.hold_t])
	await pull(110, false)  # 버틴 지 3초를 넘김 (1.25 + 1.83초)
	p.scripted_input = IDLE
	check("3초 버티면 저절로 발사", new_shots.size() == 1, "n=%d" % new_shots.size())
	check("'손이 미끄러졌다!' 알림", toasts.has("손이 미끄러졌다!"), str(toasts))
	check("미끄러진 화살도 최대 세기", new_shots.size() == 1 and new_shots[0].dmg == float(B.dmg_max), "")
	check("미끄러지면 당기기 풀림", not p.charging and p.hold_t == 0.0, "")

	# ── 당기다 넘어지면 풀림, 넘어진 동안 못 당김 ──
	await wait(80)
	await pull(30, false)
	p.trip()
	check("넘어지면 당기기 풀림", not p.charging and p.charge == 0.0, "")
	await pull(20)
	check("넘어진 동안엔 못 쏨", new_shots.is_empty(), "n=%d" % new_shots.size())

	# ── 쏜 뒤에 1인칭 화면 반동은 원래대로 돌아옴 ──
	await wait(60)
	await pull(40)
	await wait(5)
	var vr_peak: float = absf(p.v_rec)
	await wait(90)
	check("화면 반동이 돌아옴", vr_peak > 0.01 and absf(p.v_rec) < 0.005, "peak=%.3f now=%.4f" % [vr_peak, p.v_rec])

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
