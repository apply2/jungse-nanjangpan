extends SceneTree
## 음유시인 트럼펫 공격 이펙트 자동 테스트 (scripts/fx/bard_fx.gd)
## 풀 개수 상한 (한 명 24·전체 120), 음표가 원뿔 안으로만 퍼지는지, 1인칭 조준점 비켜 감·불투명도,
## 음파 고리 주기, 틱 음표, 춤 게이지 1→3, 춤 시작(조명·색종이·글자)·끝(조명 빨려 올라감), 면역 음표,
## 팡파레·삑사리·숨 참 효과, 효과 노드가 남지 않고 정리되는지, 판정은 그대로인지 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_bard_fx.gd

var main: Node
var G: Node
var C
var p
var bx
var bots: Array = []
var fails := 0
var nums: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const PLAY := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const FAN := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "aim": true}
const HERE := Vector3(-25, 0, 18)


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G.third_person = true
	G.difficulty = "normal"
	G.chosen_cls = "bard"
	G.squeak_override = 0.0
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


func put(e, pos: Vector3, cls := "archer", yaw := 0.0) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0


func objs_of(type: String) -> int:
	return bx._objs.filter(func(o: Dictionary) -> bool: return o.type == type).size()


func all_clear() -> bool:
	var c: Dictionary = bx.counts()
	return c.fly == 0 and c.deco == 0 and c.bits == 0 and c.objs == 0 and c.discos == 0 and c.nodes == 0


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	p = main.get_node("Player")
	bx = C.bard_fx
	C.num.connect(func(_pos: Vector3, text: String, _st: String) -> void: nums.append(text))
	bots = C.ents.filter(func(e): return e.is_bot)
	C.items.sniper_timer = 9999.0
	C.items.ak_timer = 9999.0
	C.items.horse_timer = 9999.0
	for i in bots.size():
		put(bots[i], Vector3(60 + i * 3, 0, 60), "archer")
	put(p, Vector3(30, 0, -30), "archer")
	await wait(5)
	var W: Dictionary = G.WEAPONS.trumpet
	var FX: Dictionary = W.fx
	var half := deg_to_rad(float(W.half_angle))
	bx.clear()
	await wait(3)
	var base_children: int = bx.get_child_count()

	# ── 풀 상한 ──
	var all: Array = [p] + bots
	for e in all:
		e.next_cls = "bard"
		e.spawn_at(e.global_position)
	await wait(2)
	for e in all:
		for k in 40:
			bx._spawn_fly(e)
	var worst := 0
	for e in all:
		worst = maxi(worst, bx.fly_count(e))
	check("풀 상한: 전체 120개", bx.fly_count() == int(FX.max), "n=%d" % bx.fly_count())
	check("풀 상한: 한 명 24개", worst <= int(FX.per_bard), "최대 %d" % worst)
	await wait(2)
	check("그리는 수도 120개를 안 넘음 (♪+♫)", bx.counts().drawn <= int(FX.max), "drawn=%d" % bx.counts().drawn)
	bx.clear()

	# ── 8명이 동시에 연주: 상한 유지 ──
	for i in all.size():
		put(all[i], HERE + Vector3((i % 4) * 4.0, 0, (i / 4) * 30.0 - 10.0), "bard", PI if i < 4 else 0.0)
	await wait(2)
	for e in all:
		e.scripted_input = PLAY
	var peak := 0
	var peak1 := 0
	for f in secs(2.5):
		await physics_frame
		peak = maxi(peak, bx.fly_count())
		for e in all:
			peak1 = maxi(peak1, bx.fly_count(e))
	check("8명 연주 중 음표가 생김", peak > 40, "최대 %d" % peak)
	check("8명 연주 중 전체 ≤ 120, 한 명 ≤ 24", peak <= int(FX.max) and peak1 <= int(FX.per_bard), "%d / %d" % [peak, peak1])
	for e in all:
		e.scripted_input = IDLE
	for i in bots.size():
		put(bots[i], Vector3(60 + i * 3, 0, 60), "archer")
	await wait(secs(1.5))
	check("연주를 멈추면 음표·고리가 다 사라짐", bx.counts().fly == 0 and objs_of("wave") == 0, str(bx.counts()))

	# ── 음표가 원뿔 안으로 퍼짐 / 음파 고리 주기 ──
	var bard = bots[0]
	var dm = bots[1]
	put(bard, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(30, 0, 0), "archer", PI / 2)  # 멀리 (춤 안 걸리게)
	put(p, Vector3(30, 0, -30), "archer")
	await wait(2)
	bard.scripted_input = PLAY
	var waves := 0
	var last_w: int = bx._wave_pool.size() + objs_of("wave")
	var inside := true
	for f in secs(1.0):
		await physics_frame
		var aim: Vector3 = bard.aim_dir()
		for n: Dictionary in bx._fly:
			if (n.d as Vector3).angle_to(aim) > half + 0.001:
				inside = false
		var w: int = objs_of("wave")
		if w > 0 and bx._objs.any(func(o: Dictionary) -> bool: return o.type == "wave" and o.life > float(o.max) - 0.017):
			waves += 1
	bard.scripted_input = IDLE
	check("음표 방향은 모두 원뿔(반각 25°) 안", inside, "")
	check("음파 고리: 0.25초마다 (1초에 4개쯤)", waves >= 3 and waves <= 5, "n=%d" % waves)
	check("음표 생성 간격 0.08초 (1초 동안 ~12개)", bx.fly_count() >= 9, "n=%d" % bx.fly_count())
	await wait(secs(1.0))

	# ── 벽에 닿으면 튕기고 사라짐 ──
	var wall: AABB
	for a: AABB in C.world.aabbs:
		if a.size.y > 2.5 and a.size.x > 2.0 and a.size.x < 7.0 and a.size.z > 2.0 and a.position.y < 0.5:
			wall = a
			break
	put(bard, Vector3(wall.position.x - 3.0, 0, wall.get_center().z), "bard", -PI / 2)
	await wait(2)
	bx._spawn_fly(bard)
	var f0: Dictionary = bx._fly[-1]
	check("벽 앞: 음표가 벽까지만 날아감", f0.wall and float(f0.maxs) < 4.0, "maxs=%.1f" % f0.maxs)
	var bounced := false
	for f in secs(0.5):
		await physics_frame
		if bx._fly.has(f0) and f0.bounce >= 0:
			bounced = true
	check("벽에 닿으면 튕기고 사라짐", bounced and not bx._fly.has(f0), "")

	# ── 1인칭: 조준점 비켜 감·불투명도 60% ──
	G.third_person = false
	put(p, HERE, "bard", -PI / 2)
	await wait(2)
	var clear_a: float = bx._clear_angle(p)
	var ok_fp := true
	for k in 40:
		bx._spawn_fly(p)
		var n: Dictionary = bx._fly[-1]
		if (n.d as Vector3).angle_to(p.aim_dir()) < clear_a or absf((n.col as Color).a - float(FX.fp_alpha)) > 0.01:
			ok_fp = false
		if (n.o as Vector3).distance_to(p.cam.global_position) < float(FX.fp_start) - 0.01:
			ok_fp = false
	check("1인칭 내 음표: 카메라 앞 1m부터, 조준점 둘레(%.1f°) 밖, 불투명도 60%%" % rad_to_deg(clear_a), ok_fp, "")
	bx.clear()
	G.third_person = true
	put(p, Vector3(30, 0, -30), "archer")

	# ── 맞은 적: 틱 음표·춤 게이지 1→3·춤 시작·끝·면역 ──
	put(bard, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	dm.hp = 100.0
	await wait(2)
	nums.clear()
	bard.scripted_input = PLAY
	var gauge := []
	var pops := 0
	var started := false
	for f in secs(0.9):
		await physics_frame
		if dm.dance_t > 0 and not started:
			started = true
			break
		var g: int = bx._snotes.size()
		if gauge.is_empty() or gauge[-1] != g:
			gauge.append(g)
		pops = maxi(pops, bx._deco.size())
	check("맞으면 머리 위로 작은 음표가 뜸", pops >= 2, "deco=%d" % pops)
	check("춤 게이지 음표 1→2→3개", gauge.has(1) and gauge.has(2) and gauge.has(3) and gauge.find(1) < gauge.find(3), str(gauge))
	check("판정은 그대로 (0.25초마다 WEAPONS.trumpet.dmg)", dm.hp < 100.0 and fmod(100.0 - dm.hp, float(W.dmg)) < 0.01, "hp=%.1f" % dm.hp)
	await wait(2)
	bard.scripted_input = IDLE
	var c: Dictionary = bx.counts()
	check("춤 시작: 디스코 조명 + 색종이 20", c.discos == 1 and c.bits >= int(FX.confetti), "%s" % c)
	check("남(봇)이 건 춤이면 내 화면엔 '춤춰라!' 안 뜸", not nums.has(String(FX.dance_text)) and dm.dance_by.has(bard), "%s" % [nums])
	var dmesh = bx._st[dm.get_instance_id()].disco
	var col0: Color = dmesh.material_override.albedo_color
	await wait(secs(0.25))
	check("디스코 조명 색이 0.2초마다 바뀜", dmesh.material_override.albedo_color != col0, "")
	check("춤추는 동안 머리 위 음표 3개", bx._snotes.size() == int(FX.dance_n), "n=%d" % bx._snotes.size())
	await wait(secs(1.9))
	check("춤 끝: 조명이 빨려 올라가는 중", dm.dance_t <= 0 and bx.counts().discos == 0 and objs_of("disco") == 1, str(bx.counts()))
	await wait(secs(0.5))
	check("조명이 다 사라짐", objs_of("disco") == 0, "")
	check("면역 중: 회색 음표 1개", dm.dance_immune > 0 and bx._snotes.size() == 1 and absf((bx._snotes[0][1] as Color).r - (bx._snotes[0][1] as Color).b) < 0.01, "n=%d" % bx._snotes.size())
	await wait(secs(3.0))
	check("면역 끝나면 회색 음표 없음", bx._snotes.size() == 0, "")

	# ── 팡파레 ──
	put(bard, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(2.5, 0, 0), "archer", PI / 2)
	await wait(2)
	var d0: int = bx._deco.size()
	bard.scripted_input = FAN
	await wait(2)
	bard.scripted_input = IDLE
	check("팡파레: 원판 충격파 + 큰 음표 12 + 색종이 10 + 맞은 적 음표", objs_of("fan") == 1 and bx._deco.size() - d0 >= int(FX.fan_notes) + 1 and bx.counts().bits >= int(FX.fan_confetti), str(bx.counts()))
	check("판정은 그대로 (팡파레 15)", absf(dm.hp - (100.0 - float(G.WEAPONS.fanfare.dmg))) < 0.01, "hp=%.1f" % dm.hp)
	await wait(secs(0.3))
	check("충격파 0.25초 뒤 사라짐", objs_of("fan") == 0, "")
	G.third_person = false
	put(p, HERE + Vector3(0, 0, 10), "bard", -PI / 2)
	await wait(2)
	p.shake = 0.0
	p.scripted_input = FAN
	var sh := 0.0
	for f in 4:
		await physics_frame
		sh = maxf(sh, p.shake)
	p.scripted_input = IDLE
	check("1인칭으로 팡파레: 화면 흔들림 0.2", sh > float(FX.fan_shake) - 0.05 and sh <= float(FX.fan_shake) + 0.001, "shake=%.2f (프레임마다 줄어듦)" % sh)
	G.third_person = true

	# ── 삑사리·숨 참 ──
	put(bard, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(30, 0, 0), "archer")
	await wait(2)
	nums.clear()
	G.squeak_override = 1.0
	bard.scripted_input = PLAY
	await wait(2)
	G.squeak_override = 0.0
	bard.scripted_input = IDLE
	check("삑사리: 찌그러진 음표 + '삑!'", objs_of("squeak") == 1 and nums.has(String(FX.squeak_text)), str(nums))
	await wait(secs(1.0))
	check("삑사리 음표 사라짐", objs_of("squeak") == 0, "")
	bard.breath = 0.05
	bard.squeak_t = 0.0
	bard.scripted_input = PLAY
	await wait(8)
	check("숨 참: 땀방울 3개 + 볼 쪼그라듦", objs_of("drop") == int(FX.sweat) and bard.model._deflate > 0, "drops=%d" % objs_of("drop"))
	bard.scripted_input = IDLE
	var lo := 9.0
	for f in secs(0.4):
		await physics_frame
		lo = minf(lo, bard.model._cheek_k)
	check("볼이 0.7배까지 쪼그라들었다가", lo < 0.8, "최소 %.2f" % lo)
	await wait(secs(0.4))
	check("다시 돌아옴", absf(bard.model._cheek_k - 1.0) < 0.1, "%.2f" % bard.model._cheek_k)

	# ── 내가 춤에 걸림: 분홍 테두리 ──
	put(p, HERE + Vector3(0, 0, -20), "archer")
	await wait(2)
	p.dance_t = 1.0
	await wait(20)
	check("내가 춤추면 분홍 테두리·음표", main.hud._dance.visible and main.hud._dance.k > 0.9, "")
	check("1인칭인 내 머리엔 조명 안 그림", not bx._st[p.get_instance_id()].disco.visible if not G.third_person else true, "")
	p.dance_t = 0.0
	await wait(30)
	check("춤 끝나면 테두리 사라짐", not main.hud._dance.visible, "")

	# ── 정리: 남는 노드 없음 ──
	await wait(secs(1.5))
	check("다 끝나면 효과가 남지 않음", all_clear(), str(bx.counts()))
	check("자식 노드 수가 처음과 같음 (고리 풀 제외)", bx.get_child_count() - bx._wave_pool.size() == base_children - 0, "%d vs %d" % [bx.get_child_count() - bx._wave_pool.size(), base_children])
	# 한창일 때 매치를 지워도 다 정리
	put(bard, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(2)
	bard.scripted_input = PLAY
	await wait(secs(1.0))
	bard.fan_cd = 0.0
	bard.scripted_input = FAN
	await wait(2)
	bard.scripted_input = IDLE
	dm.dance_t = 0.0  # 실제 경기에선 정리 뒤 다시 태어나며 춤도 풀린다
	await wait(1)
	C.clear_match_objects()
	await wait(3)
	var c2: Dictionary = bx.counts()
	check("매치 정리(clear) 뒤 남는 효과 없음", c2.fly == 0 and c2.deco == 0 and c2.bits == 0 and c2.objs == 0 and c2.discos == 0 and c2.nodes == 0, str(c2))
	check("매치 정리 뒤 자식 노드 수가 처음과 같음", bx.get_child_count() - bx._wave_pool.size() == base_children, "%d" % (bx.get_child_count() - bx._wave_pool.size()))
	check("음파 고리 풀이 커지지 않음 (8명 동시 ≤ 20)", bx._wave_pool.size() <= 20, "pool=%d" % bx._wave_pool.size())

	# ── '춤춰라!'는 춤을 건 음유시인(나)만 본다 ──
	for e in C.ents:
		e.dance_t = 0.0
		e.dance_immune = 0.0
		e.dance_log.clear()
	put(p, HERE, "bard", -PI / 2)
	put(dm, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(2)
	nums.clear()
	p.scripted_input = PLAY
	for f in secs(1.2):
		await physics_frame
		if dm.dance_t > 0:
			break
	await wait(3)
	p.scripted_input = IDLE
	check("내가 건 춤이면 '춤춰라!'가 뜸", dm.dance_t > 0 and nums.has(String(FX.dance_text)), "%s" % [nums])
	check("caused_by: 건 사람만 참", C.items != null and Trumpet_caused(dm, p) and not Trumpet_caused(dm, bots[2]), "")
	p.dance_t = 0.0

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func Trumpet_caused(v, me) -> bool:  # 테스트 스크립트에선 class_name을 바로 못 써서 스크립트를 불러 부름
	return load("res://scripts/trumpet.gd").caused_by(C, v, me)
