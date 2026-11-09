extends SceneTree
## 황금 붕어빵 자동 테스트: 등장 자리(다른 아이템과 12m)·무적 중엔 안 나옴·먹기·5초 무적·다시 먹으면 5초로,
## 피해·넉백·닭·말·둔화·춤 막기, 몸박치기 20(같은 적 0.5초), 반짝임(덮어씌우기·반짝이·빛 2개·끝날 때 깜빡임),
## 1인칭 비네트·HUD 막대·뷰모델, 무적 BGM(0.2초 전환·원래 곡 일시정지 후 이어서·경기 끝나면 바로 복구),
## 봇(주우러 감·무적이면 돌진·무적인 적은 안 노리고 도망), 친구대전 비트·무기 번호.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_fish.gd

var main: Node
var G: Node
var M: Node
var C
var I
var p
var bots: Array = []
var fails := 0
var toasts: Array = []
var banners: Array = []

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}


func _initialize() -> void:
	G = root.get_node("GameData")
	M = root.get_node("Music")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G.third_person = true
	G.difficulty = "normal"
	G.chosen_cls = "archer"
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


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	I = C.items
	p = main.get_node("Player")
	for e in C.ents:
		if e != p:
			bots.append(e)
	C.toast.connect(func(t: String) -> void: toasts.append(t))
	I.banner.connect(func(t: String, _s: String) -> void: banners.append(t))
	var F: Dictionary = G.ITEM.golden_fish
	# 다른 아이템은 안 나오게
	I.sniper_timer = 9999.0
	I.ak_timer = 9999.0
	I.horse_timer = 9999.0
	for c in I.chickens:
		c.body.queue_free()
	I.chickens.clear()
	I.chicken_timer = 9999.0
	for b in bots:
		put(b, Vector3(40, 0, -40))  # 멀리 치워 둠

	# ── 수치 ──
	check("수치: 5초·15~25초·40%·40초", is_equal_approx(F.dur, 5.0) and is_equal_approx(F.spawn_min, 15.0) and is_equal_approx(F.spawn_max, 25.0) and is_equal_approx(F.chance, 0.4) and is_equal_approx(F.life, 40.0))
	check("BGM star 키", G.BGM.get("star", "") == "res://audio/bgm_metal_heavy_loop.ogg" and ResourceLoader.exists(G.BGM.star))

	# ── 등장 자리: 다른 아이템과 12m 이상 ──
	var sn_spot: Vector3 = G.SNIPER_SPOTS[1]
	I._place(I.sniper, sn_spot, 999.0)
	var far_ok := true
	for i in 40:
		I.spawn_fish()
		var d := Vector2(I.fish.pos.x - sn_spot.x, I.fish.pos.z - sn_spot.z).length()
		if d < float(F.apart):
			far_ok = false
	check("다른 아이템과 12m 이상 떨어진 SNIPER_SPOTS", far_ok and G.SNIPER_SPOTS.has(I.fish.pos))
	check("나타날 때 배너", banners.has("황금 붕어빵이 나타났다!"))
	check("빛기둥·바닥 고리·반짝이 4개", I.fish.group.visible and I.fish.pillar != null and I.fish.ring != null and I.fish.sparks.size() == 4)
	I.sniper.active = false
	I.sniper.group.visible = false

	# ── 둥실둥실·빙글빙글 ──
	var y0: float = I.fish.holder.position.y
	var r0: float = I.fish.holder.rotation.y
	await wait(20)
	check("빙글빙글 돌고 위아래로 움직임", absf(I.fish.holder.rotation.y - r0) > 0.3 and absf(I.fish.holder.position.y - y0) > 0.001)

	# ── 먹기 ──
	put(p, I.fish.pos)
	await wait(2)
	check("닿으면 바로 먹음 → 5초 무적", not I.fish.active and p.star_t > 4.8, "star_t=%.2f" % p.star_t)
	check("화면 문구", toasts.has("황금 붕어빵! 5초 무적"))
	var snd: Array = root.get_node("Sfx").played
	check("냠! + 차임", snd.has("nyam") and snd.has("chime"))
	check("무적 BGM으로", M.override_key == "star")
	await wait(20)
	check("0.2초 만에 무적 곡 크게, 원래 곡 줄고 일시정지", M._ov_gain > 0.99 and M._duck <= 0.0 and M._p[M._active].stream_paused, "ov %.2f duck %.2f" % [M._ov_gain, M._duck])

	# ── 무적 중엔 새로 안 나옴 ──
	I.fish_timer = 0.0
	await wait(5)
	check("누가 무적이면 안 나옴", not I.fish.active and I.fish_timer <= 0.0)
	I.fish_timer = 9999.0  # 이 뒤로는 저절로 안 나오게 (무작위 자리에 내가 서 있으면 먹어 버림)

	# ── 막는 것 ──
	var hp0: float = p.hp
	p.velocity = Vector3.ZERO
	C.damage(p, bots[0], 50, "crossbow", true, Vector3(1, 0, 0))
	check("피해·넉백 막음", p.hp == hp0 and p.velocity.length() < 0.01 and p.kb_t <= 0, "hp %.0f v %.2f" % [p.hp, p.velocity.length()])
	C.damage(p, bots[0], 9999, "sniper", true, Vector3(1, 0, 0))
	check("저격총도 막음", p.alive and p.hp == hp0)
	C.shatter(bots[0], p.global_position)
	await wait(3)
	check("성수 둔화 안 걸림", p.slow_t <= 0)
	p.dance_t = 0.0
	for i in 60:
		p.dance_log.append([C.clock, 0.05])
	await wait(2)
	check("춤 안 걸림", p.dance_t <= 0)
	# 말 몸통 (짓밟기): 말 탄 봇 바로 앞
	var rider = bots[1]
	put(rider, p.global_position + Vector3(0.6, 0, 0))
	I.mount(rider)
	rider.velocity = Vector3(-8, 0, 0)
	rider.yaw = PI / 2
	I.lance_check(rider)
	check("말 몸통에 치여도 안 넘어짐", p.fall_t <= 0 and p.hp == hp0)
	I.dismount(rider)
	put(rider, Vector3(40, 0, -40))
	for z in C.zones:
		z.life = 0.0
	await wait(2)

	# ── 다시 먹으면 5초로 ──
	p.star_t = 1.5
	I.spawn_fish()
	put(p, I.fish.pos)
	p.star_t = 1.5
	await wait(2)
	check("무적 중에 또 먹으면 남은 시간을 5초로", p.star_t > 4.8, "%.2f" % p.star_t)

	# ── 몸박치기 ──
	var v = bots[2]
	put(v, p.global_position + Vector3(0.5, 0, 0))
	var vhp: float = v.hp
	await wait(2)
	check("몸이 닿으면 피해 20 + 큰 넉백", is_equal_approx(v.hp, vhp - 20.0) and Vector2(v.velocity.x, v.velocity.z).length() > 10.0, "hp %.0f→%.0f v %.1f" % [vhp, v.hp, Vector2(v.velocity.x, v.velocity.z).length()])
	v.global_position = p.global_position + Vector3(0.5, 0, 0)
	v.velocity = Vector3.ZERO
	await wait(10)
	check("같은 적은 0.5초에 한 번", is_equal_approx(v.hp, vhp - 20.0), "hp %.0f" % v.hp)
	v.global_position = p.global_position + Vector3(0.5, 0, 0)
	v.velocity = Vector3.ZERO
	await wait(26)
	v.global_position = p.global_position + Vector3(0.5, 0, 0)
	await wait(2)
	check("0.5초 지나면 다시", v.hp < vhp - 30.0, "hp %.0f" % v.hp)
	put(v, Vector3(40, 0, -40))

	# ── 반짝임 ──
	var geos: Array = p.model.find_children("*", "GeometryInstance3D", true, false)
	var over := 0
	for i in 16:  # 초당 8번 번쩍 — 꺼진 순간이 없다 (끝나기 전)
		await process_frame
		for g in geos:
			if g.material_overlay != null:
				over += 1
				break
	check("몸 전체에 금색↔흰색 덮어씌움", over >= 15 and geos.size() > 3, "%d/16 (조각 %d)" % [over, geos.size()])
	var shared_ok := true
	for g in geos:
		if g.material_overlay != null and g.material_overlay == G.mat(0xffffff):
			shared_ok = false
	check("공유 재질은 안 건드림 (캐릭터마다 따로)", shared_ok and G.mat(0xf3b33d).albedo_color == G.col(0xf3b33d))
	var cols := {}
	for i in 16:
		var c: Color = C.star_fx.flash_color(3.0, i / 16.0)
		cols[c.to_html()] = true
	check("초당 8번 금색↔흰색", cols.size() == 2)
	var offs := 0
	for i in 48:
		if C.star_fx.flash_color(0.5, i / 48.0).a == 0:
			offs += 1
	check("끝나기 1초 전: 초당 16번 + 중간중간 꺼짐", offs >= 10 and offs <= 20, "꺼짐 %d/48" % offs)
	check("반짝이 파티클", C.star_fx.spark_count() > 10, "%d" % C.star_fx.spark_count())
	# 빛: 무적 셋이어도 2개만
	for b in bots.slice(0, 2):
		put(b, p.global_position + Vector3(randf_range(5, 9), 0, randf_range(5, 9)))
		C.give_star(b)
	await wait(3)
	check("금빛은 가장 가까운 2명만", C.star_fx.lit_count() == 2)
	for b in bots.slice(0, 2):
		C.end_star(b)
		put(b, Vector3(40, 0, -40))
	var b0 = bots[0]
	var far_spot: Vector3 = Vector3.ZERO
	for q: Vector3 in G.SNIPER_SPOTS:  # 내가 서 있는 자리와 먼 곳에
		if q.distance_to(p.global_position) > 8.0:
			far_spot = q
			break
	I._place(I.fish, far_spot, 40.0)
	put(b0, I.fish.pos)
	await wait(2)
	check("봇이 먹으면 배너", banners.has("%s이(가) 황금 붕어빵을 먹었다!" % b0.ent_name) and b0.star_t > 4.8)
	check("남이 먹으면 BGM 안 바뀜 (내 무적 곡 그대로)", M.override_key == "star")
	C.end_star(b0)
	put(b0, Vector3(40, 0, -40))

	# ── HUD ──
	var hud = main.get_node("HUD")
	await wait(2)
	check("HUD 위 가운데 막대 + 무적 N초", hud._star_box.visible and hud._star_lbl.text.begins_with("무적 ") and hud._star_lbl.text.ends_with("초"), hud._star_lbl.text)
	G.third_person = false
	await wait(10)
	check("1인칭: 금색 비네트·테두리 반짝이", hud._star.visible and hud._star.k > 0.5)
	var vm = hud._vm
	var vm_on := false
	for i in 6:
		await process_frame
		vm_on = vm_on or vm._star_on
	check("1인칭 뷰모델도 번쩍", vm_on)
	G.third_person = true

	# ── 끝 ──
	p.star_t = 0.3
	var paused_pos: float = M._p[M._active].get_playback_position()
	await wait(30)
	check("무적 끝", p.star_t <= 0 and M.override_key == "")
	var still := true
	for g in geos:
		if is_instance_valid(g) and g.material_overlay != null:
			still = false
	check("끝나면 원래 재질로 복구", still)
	check("원래 곡은 처음부터가 아니라 멈췄던 자리부터", not M._p[M._active].stream_paused and M._p[M._active].get_playback_position() >= paused_pos - 0.05, "%.2f → %.2f" % [paused_pos, M._p[M._active].get_playback_position()])
	await wait(50)
	check("0.8초 페이드로 원래 곡 복귀", M._duck >= 1.0 and M._ov_gain <= 0.0, "duck %.2f" % M._duck)
	await wait(3)
	check("뷰모델 번쩍임도 꺼짐", not vm._star_on)

	# ── 경기가 끝나면 바로 복구 ──
	C.give_star(p)
	await wait(5)
	check("다시 무적 곡", M.override_key == "star")
	main.end_match()
	check("경기 끝나면 즉시 원래 곡으로", M.override_key == "" and M._duck >= 1.0 and p.star_t <= 0)
	main.start_match()
	await wait(3)
	I.sniper_timer = 9999.0
	I.ak_timer = 9999.0
	I.horse_timer = 9999.0

	# ── 봇 ──
	G.ai_enabled = true
	var bb = bots[3]
	for b in bots:
		if b != bb:
			put(b, Vector3(40, 0, -40))
	put(p, Vector3(-40, 0, 40))
	put(bb, Vector3(0, 0, 20))
	bb.scripted_input = {}  # AI가 움직이게
	I._place(I.fish, Vector3(6, 0, 36), 999.0)
	var d0: float = bb.global_position.distance_to(I.fish.pos)
	for i in 240:  # 봇 반응·방향 틀기에 시간이 들쭉날쭉해서 넉넉히
		await physics_frame
		if bb.star_t > 0 or bb.global_position.distance_to(I.fish.pos) < d0 - 6.0:
			break
	check("봇: 40m 안의 붕어빵을 주우러 감", bb.global_position.distance_to(I.fish.pos) < d0 - 3.0 or bb.star_t > 0, "%.1f → %.1f" % [d0, bb.global_position.distance_to(I.fish.pos)])
	I.fish.active = false
	I.fish.group.visible = false
	# 무적인 봇은 가장 가까운 적에게 돌진
	put(bb, Vector3(-20, 0, 18))
	bb.scripted_input = {}
	put(p, Vector3(-12, 0, 18))
	C.give_star(bb)
	bb.ai.think = 0.0
	var dd0: float = bb.global_position.distance_to(p.global_position)
	await wait(60)
	check("무적 봇은 돌진", bb.global_position.distance_to(p.global_position) < dd0 - 2.0 or p.hp < G.class_hp(p.cls), "%.1f → %.1f" % [dd0, bb.global_position.distance_to(p.global_position)])
	C.end_star(bb)
	# 무적인 적은 안 노리고 도망
	put(bb, Vector3(-20, 0, 18))
	bb.scripted_input = {}
	put(p, Vector3(-14, 0, 18))
	C.give_star(p)
	bb.ai.think = 0.0
	bb.ai.target = null
	await wait(3)
	check("무적인 적은 대상으로 안 고름", bb.ai.target != p)
	var de0: float = bb.global_position.distance_to(p.global_position)
	await wait(70)
	check("무적인 적에게서 도망", bb.global_position.distance_to(p.global_position) > de0 + 1.0, "%.1f → %.1f" % [de0, bb.global_position.distance_to(p.global_position)])
	C.end_star(p)
	G.ai_enabled = false

	# ── 친구대전 ──
	var net = main.get_node("Net")
	check("무기 번호에 star", net.WEPS.has("star") and net.WEPS.find("star") == net.WEPS.size() - 1)
	C.give_star(p)
	var st: Array = net._my_state()
	check("상태 비트 4096 = 무적", (int(st[4]) & 4096) != 0)
	C.end_star(p)
	check("아이템 목록에 gf", net._items_dict().has("gf"))

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
