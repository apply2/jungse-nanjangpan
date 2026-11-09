extends SceneTree
## 특수 아이템 자동 테스트 — HTML updateChickens / grabChicken / fire('chicken'), 저격총(pickup·hitscan·스코프·Q·떨어뜨림),
## AK-47(akDmg·연사·퍼짐·탄창), 기사의 말(mount·lanceCheck·dismount·짓밟기), 봇이 아이템 주우러 가기와 같은지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_items.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var I
var p
var dm
var fails := 0
var toasts: Array = []
var banners: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const SHOOTER := Vector3(-25, 0, 18)
const TARGET := Vector3(-19, 0, 18)
const EAST_YAW := -PI / 2   # aim_dir = (1, 0, 0)


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G.third_person = false
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G.ai_enabled = false  # 봇은 가만히 (마지막에 한 명만 켬)
	main.start_match.call_deferred()
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


func hold(n: int, inp := FIRE) -> void:
	p.scripted_input = inp
	for i in n:
		await physics_frame
	p.scripted_input = IDLE


func clear_chickens() -> void:
	for c in I.chickens:
		c.body.queue_free()
	I.chickens.clear()
	I.chicken_timer = 9999.0


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	I = C.items
	p = main.get_node("Player")
	C.toast.connect(func(t): toasts.append(t))
	I.banner.connect(func(t, _s): banners.append(t))
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]

	# ── 경기 시작: 닭 두 마리, 아이템 첫 등장 시간 ──
	check("경기 시작하면 닭 두 마리", I.chickens.size() == 2, "n=%d" % I.chickens.size())
	check("첫 등장 시간 (저격총 18~30, AK 20~35, 말 25~40)", I.sniper_timer > 17.5 and I.sniper_timer <= 30 and I.ak_timer > 19.5 and I.ak_timer <= 35
		and I.horse_timer > 24.5 and I.horse_timer <= 40, "sn=%.1f ak=%.1f hs=%.1f" % [I.sniper_timer, I.ak_timer, I.horse_timer])
	# 이제부터 아이템은 테스트가 직접 놓는다
	clear_chickens()
	I.sniper_timer = 9999.0
	I.ak_timer = 9999.0
	I.horse_timer = 9999.0
	for i in range(1, bots.size()):
		put(bots[i], C.world.spawn_points[i * 5 % C.world.spawn_points.size()])
	put(p, SHOOTER, "archer", EAST_YAW)
	put(dm, TARGET)
	await wait(5)

	# ── 닭: 닿으면 잡고, 던지면 맞은 사람이 넘어지고, 닭은 다시 돌아다님 ──
	I.spawn_chicken(SHOOTER + Vector3(0.4, 0, 0))
	await wait(4)
	check("닭에 닿으면 잡음", p.has_chicken and p.wep == "chicken" and I.chickens.is_empty() and toasts.has("닭을 잡았다! 클릭해서 던지기"), "wep=%s" % p.wep)
	check("닭 들면 속도 ×1.05", near(p.max_speed(), G.BASE_SPEED * 1.05, 0.01), "max=%.2f" % p.max_speed())
	await wait(15)  # 잡는 동작(0.15초)
	p.pitch = -0.15
	var tripped := false
	p.scripted_input = FIRE
	await wait(2)
	p.scripted_input = IDLE
	check("던지면 원래 무기로", not p.has_chicken and p.wep == "bow", "wep=%s" % p.wep)
	for i in 40:
		await physics_frame
		if dm.fall_t > 0:
			tripped = true
	check("닭에 맞으면 피해 1 + 넘어짐", near(dm.hp, 99.0) and tripped and dm.last_hit.get("kind") == "chicken", "hp=%.1f tripped=%s" % [dm.hp, tripped])
	check("던진 닭은 다시 돌아다님 (바로는 못 잡음)", I.chickens.size() == 1 and I.chickens[0].no_pick > 0, "n=%d" % I.chickens.size())
	clear_chickens()

	# ── 대물 저격총 ──
	I.spawn_sniper()
	check("저격총 등장 + 알림", I.sniper.active and I.sniper.ammo == 5 and near(I.sniper.life, 40.0) and banners.has("대물 저격총이 나타났다!"), "")
	put(p, SHOOTER, "archer", EAST_YAW)
	put(dm, TARGET)
	I.drop_sniper(p.global_position, 5)
	await wait(2)
	check("닿으면 줍기", p.has_sniper and p.wep == "sniper" and p.ammo == 5 and not I.sniper.active, "wep=%s ammo=%d" % [p.wep, p.ammo])
	check("저격총 들면 속도 ×0.9", near(p.max_speed(), G.BASE_SPEED * 0.9, 0.01), "max=%.2f" % p.max_speed())
	G.third_person = true
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
	await wait(40)
	check("우클릭 = 스코프 (3인칭이어도 1인칭 화면, 시야 24)", p.is_scoped() and not C.tp_on() and near(p.cam.fov, G.SCOPE_FOV, 0.5), "fov=%.1f" % p.cam.fov)
	p.scripted_input = IDLE
	G.third_person = false
	await wait(2)
	check("떼면 스코프 끝", not p.is_scoped(), "")
	await hold(2)
	await wait(2)
	check("한 발이면 즉사", not dm.alive and dm.last_hit.get("kind") == "sniper", "alive=%s" % dm.alive)
	check("남은 탄 4, 1초 대기", p.ammo == 4 and p.cd > 0.9, "ammo=%d cd=%.2f" % [p.ammo, p.cd])
	await hold(30)
	check("대기 중에 누르면 안 나감", p.ammo == 4, "ammo=%d" % p.ammo)
	await wait(40)
	await hold(90)
	check("누르고 있어도 한 번에 한 발", p.ammo == 3, "ammo=%d" % p.ammo)
	# Q: 원래 무기 ↔ 저격총
	p.swap_req = true
	await wait(2)
	check("Q → 원래 무기 (0.35초)", p.wep == "bow" and p.has_sniper and p.swap_t > 0.3, "wep=%s swap=%.2f" % [p.wep, p.swap_t])
	p.swap_req = true
	await wait(2)
	check("Q → 다시 저격총", p.wep == "sniper", "wep=%s" % p.wep)
	# 죽으면 남은 탄과 함께 떨어뜨림
	var dpos: Vector3 = p.global_position
	C.kill(p, null, "stone", false, Vector3.FORWARD)
	check("죽으면 그 자리에 떨어짐 (남은 탄 3, 25초)", I.sniper.active and I.sniper.ammo == 3 and near(I.sniper.life, 25.0)
		and (I.sniper.pos as Vector3).distance_to(dpos) < 0.01 and not p.has_sniper, "ammo=%d" % I.sniper.ammo)
	I.sniper.active = false
	I.sniper.group.visible = false
	# 마지막 탄을 쓰면 원래 무기로
	put(p, SHOOTER, "archer", EAST_YAW)
	put(dm, Vector3(-25, 0, 40))
	I.drop_sniper(p.global_position, 1)
	await wait(15)
	await hold(2)
	await wait(2)
	check("다 쓰면 원래 무기로", not p.has_sniper and p.wep == "bow" and p.swap_t > 0.3, "wep=%s" % p.wep)

	# ── AK-47 ──
	check("AK 거리 감쇠 23 → 18", C.ak_dmg(10) == 23.0 and C.ak_dmg(55) == 21.0 and C.ak_dmg(80) == 18.0 and C.ak_dmg(110) == 18.0,
		"%s %s %s" % [C.ak_dmg(55), C.ak_dmg(80), C.ak_dmg(110)])
	put(p, SHOOTER, "archer", EAST_YAW)
	put(dm, TARGET, "crossbow")
	I.drop_ak(p.global_position, 25)
	await wait(2)
	check("AK 줍기", p.has_ak and p.wep == "ak" and p.ak_ammo == 25 and near(p.swap_t, 0.3, 0.05), "wep=%s" % p.wep)
	check("AK 들면 속도 ×0.95", near(p.max_speed(), G.BASE_SPEED * 0.95, 0.01), "max=%.2f" % p.max_speed())
	await wait(20)
	var hp0: float = dm.hp
	p.scripted_input = FIRE
	await wait(61)
	var bloom: float = p.bloom
	p.scripted_input = IDLE
	var shots: int = 25 - p.ak_ammo
	check("1초 누르면 0.12초마다 연사 (8~10발)", shots >= 8 and shots <= 10, "shots=%d" % shots)
	check("연사하면 퍼짐이 커짐", bloom > 0.005 and bloom <= 0.05, "bloom=%.3f" % bloom)
	check("AK에 맞음", dm.hp < hp0 or not dm.alive, "hp=%.1f" % dm.hp)
	await wait(60)
	check("떼면 퍼짐이 줄어듦", p.bloom < bloom, "bloom=%.3f" % p.bloom)
	put(dm, Vector3(-25, 0, 40))
	p.ak_ammo = 1
	toasts.clear()
	await hold(2)
	await wait(2)
	check("탄창이 비면 버림", not p.has_ak and p.wep == "bow" and toasts.has("탄창이 비었다! AK-47을 버렸다"), str(toasts))

	# ── 기사의 말 + 마상창 ──
	put(p, SHOOTER, "archer", EAST_YAW)
	put(dm, SHOOTER + Vector3(12, 0, 0), "crossbow")
	await wait(3)
	I.spawn_horse()
	I.horse.pos = p.global_position
	I.horse.group.global_position = p.global_position
	await wait(2)
	check("말에 닿으면 올라탐", p.mounted > 6.9 and near(p.mount_h, G.MOUNT_H) and p.wep == "lance" and not I.horse.active and not p.horse.is_empty(),
		"mounted=%.2f wep=%s" % [p.mounted, p.wep])
	check("말 속도 20.5", near(p.max_speed(), G.HORSE_SPEED, 0.01), "max=%.2f" % p.max_speed())
	check("눈높이 +0.95", near(p.eye_pos().y - p.global_position.y, G.MOUNT_H + 1.55), "")
	var hit_at := -1
	p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": true, "sprint": false}
	for i in 60:
		await physics_frame
		if dm.last_hit.get("kind") == "lance" and hit_at < 0:
			hit_at = i
	p.scripted_input = IDLE
	check("말 위에선 앉기 안 됨", not p.crouch and not p.sliding, "")
	check("창끝에 찔리면 70 피해", hit_at >= 0 and (near(dm.hp, 40.0) or near(dm.hp, 5.0) or not dm.alive), "hp=%.1f at=%d" % [dm.hp, hit_at])
	check("찔리면 멀리 날아감", dm.global_position.distance_to(SHOOTER) > 20.0, "x=%.1f" % dm.global_position.x)
	# 시간이 끝나면 내리고 말이 달아남
	await wait(int(G.HORSE_TIME * 60))
	check("7초 뒤 내림", p.mounted <= 0 and p.mount_h == 0.0 and p.wep == "bow" and p.horse.is_empty() and I.runaways.size() == 1 and toasts.has("말이 떠났다"),
		"mounted=%.2f wep=%s" % [p.mounted, p.wep])
	await wait(160)
	check("달아난 말은 사라짐", I.runaways.is_empty(), "n=%d" % I.runaways.size())
	# 말 몸통에 치이면 넘어짐 (옆에 바짝 붙은 사람)
	put(p, SHOOTER, "archer", EAST_YAW)
	put(dm, SHOOTER + Vector3(0, 0, 1.0))
	I.mount(p)
	p.velocity = Vector3(8, 0, 0)
	I.lance_check(p)
	check("말 몸통에 치이면 넘어짐", dm.fall_t > 0 and dm.hp == 100.0, "fall=%.2f hp=%.1f" % [dm.fall_t, dm.hp])
	# 말 탄 채 죽으면 내림
	C.kill(p, dm, "stone", false, Vector3.FORWARD)
	check("말 탄 채 죽으면 내림", p.mounted <= 0 and p.horse.is_empty(), "")

	# ── 봇이 가까운 저격총을 주우러 감 ──
	put(p, Vector3(-25, 0, 40), "archer")
	put(dm, TARGET)
	dm.scripted_input = {}
	G.ai_enabled = true
	I.drop_sniper(SHOOTER, 5)
	var got := false
	for i in 300:
		await physics_frame
		if dm.has_sniper:
			got = true
			break
	check("봇이 저격총을 주우러 감", got, "dist=%.1f" % dm.global_position.distance_to(SHOOTER))

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
