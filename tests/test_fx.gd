extends SceneTree
## 연출 자동 테스트 — HTML makeRagdoll·stepRagdoll(래그돌), hitStop(히트스톱), shake(화면 흔들림),
## hurt·#vignette(붉은 테두리), dmgDir(피격 방향), sfx(효과음 합성·어디서 나는지), makeModel 의상과 같은지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_fx.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var S: Node
var C
var p
var hud
var dm
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const HERE := Vector3(-25, 0, 18)


func _initialize() -> void:
	G = root.get_node("GameData")
	S = root.get_node("Sfx")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G.third_person = false
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


func count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += count_meshes(ch)
	return c


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	p = main.get_node("Player")
	hud = main.hud
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], C.world.spawn_points[i * 5 % C.world.spawn_points.size()])
	C.items.sniper_timer = 9999.0
	C.items.ak_timer = 9999.0
	C.items.horse_timer = 9999.0

	# ── 효과음: 파일·합성 ──
	var missing := []
	for key in S.FILES:
		for path in S.FILES[key]:
			if not ResourceLoader.exists(path):
				missing.append(path)
	check("FILES에 적은 소리 파일이 다 있음", missing.is_empty(), str(missing))
	var both: Array = S.RECIPES.keys().filter(func(key): return S.FILES.has(key))
	check("RECIPES와 FILES 이름이 안 겹침", both.is_empty(), str(both))
	check("안 쓰는 합성 소리는 지움", not (S.RECIPES.has("hoof") or S.RECIPES.has("strain") or S.RECIPES.has("ratchet")), "")
	# 거리·남의 소리 크기 (GameData.SFX_DIST)
	put(p, HERE, "archer", 0.0)
	await wait(2)
	var D: Dictionary = G.SFX_DIST
	var me_pos: Vector3 = p.global_position
	check("내 자리 소리 = 1", S.vol_at(me_pos) == 1.0, "%.2f" % S.vol_at(me_pos))
	var v8: float = S.vol_at(me_pos + Vector3(D.ref, 0, 0))
	check("남의 소리: ref 거리에서 절반 × others", near(v8, 0.5 * D.others, 0.01), "%.3f" % v8)
	var v30: float = S.vol_at(me_pos + Vector3(30, 0, 0))
	check("30m는 예전(1/(1+d/9))보다 작음", v30 < 0.5 * (1.0 / (1.0 + 30.0 / 9.0)), "%.3f" % v30)
	check("가까울수록 큼", S.vol_at(me_pos + Vector3(3, 0, 0)) > v8 and v8 > v30, "")
	check("max 넘으면 0", S.vol_at(me_pos + Vector3(D.max + 1, 0, 0)) == 0.0, "")
	var w = S.render(S.RECIPES.trip)
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	check("소리가 비어 있지 않음", peak > 3000, "peak=%d" % peak)
	var k = S.render(S.RECIPES.kill)
	check("처치 소리: 두 번째 음은 0.07초 뒤", absi(k.data.size() / 2 - (int((0.07 + 0.14 + 0.02) * S.RATE) + 1)) <= 1, "")
	check("모든 소리가 구워짐", S.RECIPES.keys().all(func(key): return S.render(S.RECIPES[key]).data.size() > 100), "")

	# ── 내가 맞힘: 소리 + 히트스톱 ──
	put(p, HERE, "barbarian", -PI / 2)
	put(dm, HERE + Vector3(6, 0, 0), "archer")
	await wait(3)
	S.played.clear()
	G.hitstop_enabled = true
	C.damage(dm, p, 10, "stone", false, Vector3(1, 0, 0), dm.global_position + Vector3(0, 1, 0))
	check("맞히면 퍽 + 딱 소리", S.played.has("hit") and S.played.has("thud"), str(S.played))
	check("돌멩이 히트스톱 0.02초", near(C.hit_stop, 0.02, 0.001), "hs=%.3f" % C.hit_stop)
	S.played.clear()
	C.damage(dm, p, 20, "crossbow", true, Vector3(1, 0, 0), dm.global_position + Vector3(0, 1.6, 0))
	check("헤드샷: 딱 소리 + 투구 떨어지는 소리 + 히트스톱 0.055", S.played.has("head") and S.played.has("clang") and S.played.has("thud_heavy")
		and near(C.hit_stop, 0.055, 0.001), str(S.played))
	C.damage(dm, p, 200, "stone", false, Vector3(1, 0, 0))
	check("처치: 소리 + 히트스톱 0.1", S.played.has("kill") and near(C.hit_stop, 0.1, 0.001), "hs=%.3f" % C.hit_stop)
	await process_frame
	await process_frame
	check("히트스톱 동안 시간 ×0.12", near(Engine.time_scale, 0.12, 0.001), "ts=%.2f" % Engine.time_scale)
	for i in 10:
		await process_frame
	check("끝나면 시간 원래대로", Engine.time_scale == 1.0 and C.hit_stop <= 0, "ts=%.2f" % Engine.time_scale)
	C.stop_hit_stop()
	G.hitstop_enabled = false
	await wait(2)

	# ── 킬 마커: 내가 막타 → 조준점 가운데 해골 (사용자 요청) ──
	var sk = hud._skull
	var K: Dictionary = G.HUD_UI.kill_skull
	check("내가 처치하면 해골 (헤드샷 아니면 흰색)", sk.plays == 1 and not sk.head and sk.state().a > 0.3, "plays=%d" % sk.plays)
	sk.play(false)  # 시간 재기용으로 다시 (연속 킬 = 처음부터)
	var s0: float = sk.state().s
	OS.delay_msec(int(float(K.punch_t) * 1000.0) + 20)
	var s1: float = sk.state().s
	check("처음엔 크게(1.3배) → 0.1초 뒤 원래 크기", near(s0, float(K.punch), 0.05) and s1 == 1.0, "%.2f → %.2f" % [s0, s1])
	OS.delay_msec(int(float(K.hold) * 1000.0) - 50)
	check("0.5초 동안은 그대로 (반투명 0.6)", near(sk.state().a, float(K.alpha), 0.001) and K.alpha == 0.6, "a=%.2f" % sk.state().a)
	sk._process(0.0)
	check("해골은 그룹째 흐리게 (겹친 조각이 비치지 않게)", sk._grp.visible and near(sk._grp.self_modulate.a, float(K.alpha), 0.001), "a=%.2f" % sk._grp.self_modulate.a)
	OS.delay_msec(int(float(K.fade) * 1000.0) / 2 + 50)
	var a_mid: float = sk.state().a
	OS.delay_msec(int(float(K.fade) * 1000.0))
	check("0.25초 동안 0.6 → 0으로 흐려지다 사라짐", a_mid > 0.05 and a_mid < float(K.alpha) - 0.05 and sk.state().a == 0.0, "중간 %.2f → %.2f" % [a_mid, sk.state().a])
	var plays0: int = sk.plays
	put(bots[2], HERE + Vector3(4, 0, 3), "archer")
	await wait(2)
	C.damage(bots[2], p, 999, "crossbow", true, Vector3(1, 0, 0))
	check("헤드샷 킬은 빨간 해골", sk.plays == plays0 + 1 and sk.head, "plays=%d head=%s" % [sk.plays, sk.head])
	put(bots[3], HERE + Vector3(4, 0, -3), "archer")
	await wait(2)
	C.damage(bots[3], bots[4], 999, "stone", false, Vector3(1, 0, 0))
	check("봇이 봇을 죽이면 내 화면엔 해골 없음", sk.plays == plays0 + 1, "plays=%d" % sk.plays)

	# ── 래그돌 ──
	check("죽으면 모델 대신 래그돌", dm.model == null and dm.ragdoll != null and C.ragdolls.has(dm.ragdoll), "")
	var rd = dm.ragdoll
	check("머리·몸통·팔·다리 6조각을 떼어 옴", rd.parts.size() == 6 and rd.root.get_child_count() == 6, "n=%d" % rd.root.get_child_count())
	var L0: Array = rd.cons.map(func(c): return c.len)
	await wait(90)
	var p0: Vector3 = rd.pelvis()
	check("쓰러져 바닥에 누움", p0.y < 0.6 and rd.P.head.p.y < 1.0, "pelvis.y=%.2f head.y=%.2f" % [p0.y, rd.P.head.p.y])
	var worst := 0.0
	for i in rd.cons.size():
		var c: Dictionary = rd.cons[i]
		worst = maxf(worst, absf((c.a.p as Vector3).distance_to(c.b.p) - L0[i]) / L0[i])
	check("뼈 길이 유지 (10% 안)", worst < 0.1, "worst=%.3f" % worst)
	check("몸 조각이 점을 따라감", (rd.head.global_position as Vector3).distance_to(rd.P.head.p) < 0.01, "")
	await wait(int((G.RAGDOLL.life - 1.5) * 60) + 10)
	check("7초 뒤 사라짐", C.ragdolls.is_empty() and not is_instance_valid(rd.root) or rd.root.is_queued_for_deletion(), "n=%d" % C.ragdolls.size())
	# 무기마다 날아가는 정도가 다르다: 저격총은 멀리, 돌멩이는 제자리에서 빙글
	put(dm, HERE + Vector3(6, 0, 0), "archer")
	await wait(3)
	var start: Vector3 = dm.global_position
	C.damage(dm, p, 9999, "sniper", false, Vector3(1, 0, 0))
	var rs = dm.ragdoll
	await wait(60)
	var fly_sn: float = Vector2(rs.pelvis().x - start.x, rs.pelvis().z - start.z).length()
	put(dm, HERE + Vector3(6, 0, 0), "archer")
	await wait(3)
	start = dm.global_position
	C.damage(dm, p, 9999, "stone", false, Vector3(1, 0, 0))
	var rst = dm.ragdoll
	await wait(60)
	var fly_st: float = Vector2(rst.pelvis().x - start.x, rst.pelvis().z - start.z).length()
	check("저격총은 멀리 날아감, 돌멩이는 가까이", fly_sn > 10.0 and fly_st < 5.0, "sniper=%.1f stone=%.1f" % [fly_sn, fly_st])
	check("벽·땅을 뚫지 않음", rs.pelvis().y >= 0.12 and absf(rs.pelvis().x) < G.ARENA + 2, "pelvis=%s" % rs.pelvis())
	put(dm, HERE + Vector3(6, 0, 0), "archer")
	await wait(2)
	check("부활하면 새 모델", dm.model != null and dm.ragdoll == null and dm.model.visible, "")

	# ── 내가 맞음: 흔들림·붉은 테두리·피격 방향·소리 ──
	put(p, HERE, "archer", 0.0)  # 북쪽(-Z)을 봄, 봇은 동쪽
	await wait(3)
	S.played.clear()
	hud._hurt = 0.0
	hud._dirs.items.clear()
	C.damage(p, dm, 10, "stone", false, Vector3(-1, 0, 0))
	check("맞으면 화면 흔들림 0.25+10/110", near(p.shake, 0.25 + 10.0 / 110.0, 0.02), "shake=%.3f" % p.shake)
	check("맞으면 아야 소리", S.played.has("hurt"), str(S.played))
	check("붉은 테두리가 피해/60만큼", near(hud._hurt, 10.0 / 60.0, 0.02), "hurt=%.3f" % hud._hurt)
	check("오른쪽(동쪽)에서 맞으면 호가 오른쪽", hud._dirs.items.size() == 1 and near(hud._dirs.items[0].ang, -PI / 2, 0.01), "ang=%.2f" % hud._dirs.items[0].ang)
	await wait(70)
	check("피격 방향은 1초 뒤 사라짐", hud._dirs.items.is_empty(), "n=%d" % hud._dirs.items.size())
	check("붉은 테두리는 서서히 빠짐", hud._hurt < 0.01, "hurt=%.3f" % hud._hurt)
	for i in 5:
		C.damage(p, dm, 3, "holy", false, Vector3(-1, 0, 0))
	check("성수는 흔들림 0.1", p.shake < 0.3 and p.shake > 0.05, "shake=%.3f" % p.shake)
	p.hp = 20.0
	hud._hurt = 0.0
	await process_frame
	await process_frame
	check("체력 30 미만이면 테두리가 늘 깔림", near(hud._vig_mat.get_shader_parameter("alpha"), 0.25, 0.03), "a=%.2f" % hud._vig_mat.get_shader_parameter("alpha"))
	for i in 4:
		hud.dmg_dir(p.global_position + Vector3(0, 0, 5))
	hud.dmg_dir(p.global_position + Vector3(0, 0, -5))
	check("피격 방향은 최대 4개", hud._dirs.items.size() == 4, "n=%d" % hud._dirs.items.size())
	# 저격총 쏘면 화면이 크게 흔들림
	p.shake = 0.0
	C.items.drop_sniper(p.global_position, 5)
	await wait(20)
	p.scripted_input = FIRE
	await wait(2)
	p.scripted_input = IDLE
	check("저격총 쏘면 흔들림 0.5 + 소리", p.shake > 0.4 and S.played.has("sniper"), "shake=%.2f" % p.shake)

	# ── 무기 소리가 나는 곳 ──
	# 활: 누르면 당기는 소리, 놓으면 휙 (돌 던지는 소리와 같은 파일) + 당기는 소리 끔
	put(p, HERE, "archer", 0.0)
	await wait(5)
	S.played.clear()
	p.scripted_input = FIRE
	await wait(30)
	check("활 당기면 bow_draw", S.played.has("bow_draw") and p.charging, str(S.played))
	p.scripted_input = IDLE
	await wait(2)
	check("놓으면 bow + 당기는 소리 끔", S.played.has("bow") and p.snd_bow == 0 and not p.charging, str(S.played))
	check("활 쏘는 소리 = 돌 던지는 소리 (사용자 요청)", S.FILES.bow == S.FILES.throw, "")
	# 석궁 3인칭 장전: 끊어 당기기 3번 · 걸쇠 · 볼트
	var tp0: bool = G.third_person
	G.third_person = true
	put(p, HERE, "crossbow", 0.0)
	await wait(5)
	S.played.clear()
	p.scripted_input = FIRE
	await wait(2)
	p.scripted_input = IDLE
	var wind_in: Dictionary = IDLE.duplicate()
	wind_in["wind"] = true
	await wait(20)  # 쏜 직후(cd)엔 휠이 안 먹음
	for i in int(G.WEAPONS.crossbow.notches):  # 휠 한 칸씩
		p.scripted_input = wind_in
		await wait(1)
		p.scripted_input = IDLE
		await wait(9)
	await wait(30)
	var cnt := func(n: String) -> int: return S.played.count(n)
	check("석궁 3인칭 휠 장전 소리: 칸마다 끼릭 · latch 1 · seat 1", S.played.has("xbow") and cnt.call("xbow_click") == int(G.WEAPONS.crossbow.notches) and cnt.call("xbow_latch") == 1 and cnt.call("seat") == 1, str(S.played))
	G.third_person = tp0
	# 봇 석궁 장전도 들림
	put(dm, HERE + Vector3(6, 0, 0), "crossbow")
	await wait(3)
	S.played.clear()
	dm.scripted_input = FIRE
	await wait(2)
	dm.scripted_input = IDLE
	await wait(20)
	for i in int(G.WEAPONS.crossbow.notches):
		dm.scripted_input = wind_in
		await wait(1)
		dm.scripted_input = IDLE
		await wait(9)
	await wait(30)
	check("봇 석궁 장전 소리도 남", cnt.call("xbow_click") == int(G.WEAPONS.crossbow.notches) and cnt.call("xbow_latch") == 1, str(S.played))
	# 성수: 던지면 holy_throw, 깨지면 glass
	put(p, HERE, "cleric", 0.0)
	p.pitch = -0.5
	await wait(5)
	S.played.clear()
	p.scripted_input = FIRE
	await wait(2)
	p.scripted_input = IDLE
	await wait(90)
	check("성수 던지면 holy_throw, 깨지면 glass", S.played.has("holy_throw") and S.played.has("glass") and not S.played.has("throw"), str(S.played))
	# 말: 달리면 gallop (반복 소리 한 번만 쌓임), hoof는 없음
	put(p, HERE, "archer", -PI / 2)
	await wait(3)
	S.played.clear()
	C.items.mount(p)
	p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	await wait(40)
	check("말 달리면 gallop (한 번만 쌓임), hoof 없음", S.played.count("gallop") == 1 and not S.played.has("hoof"), str(S.played))
	p.scripted_input = IDLE
	C.items.dismount(p)
	check("내리면 반복 소리 지움", S._loops.is_empty(), "n=%d" % S._loops.size())

	# ── 최적화: 1인칭 손 화면(SubViewport)은 보일 때만 그림 ──
	var vp: SubViewport = hud._vm._vp
	G.third_person = true
	await wait(3)
	check("3인칭이면 1인칭 손 화면을 안 그림", vp.render_target_update_mode == SubViewport.UPDATE_DISABLED, str(vp.render_target_update_mode))
	G.third_person = false
	await wait(3)
	check("1인칭이면 그림", vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, str(vp.render_target_update_mode))
	G.third_person = true
	await wait(2)

	# ── 내가 죽으면 래그돌을 따라가는 카메라 ──
	put(p, HERE, "archer", 0.0)
	await wait(3)
	var plays_before_death: int = hud._skull.plays
	C.damage(p, dm, 9999, "stone", false, Vector3(1, 0, 0))
	await wait(90)
	var pel: Vector3 = p.ragdoll.pelvis()
	check("내가 남에게 죽으면 해골 없음", hud._skull.plays == plays_before_death, "plays=%d" % hud._skull.plays)
	check("죽음 카메라가 래그돌 골반을 봄", p.cam.global_position.distance_to(pel) < 7.5 and (-p.cam.global_basis.z).dot((pel - p.cam.global_position).normalized()) > 0.95,
		"dist=%.1f" % p.cam.global_position.distance_to(pel))

	# ── 병과별 의상 ──
	var counts := {}
	for k2 in G.CLASS_ORDER:
		var m = load("res://scripts/derp_model.gd").new(k2)
		counts[k2] = m.part_count  # 조각은 합쳐서 그리므로 합치기 전 수를 센다
		check(k2 + " 래그돌 점 8개", m.mk.size() == 8, "")
		var body_n: int = count_meshes(m) - m.weapons.values().reduce(func(acc, w): return acc + count_meshes(w), 0)
		check(k2 + " 몸 조각을 관절별로 합침 (손에 드는 무기 빼고 14개 이하)", body_n <= 14, "합치기 전 %d개(무기 포함) → 몸 %d개" % [m.part_count, body_n])
		var wk: String = G.CLASSES[k2].weapon
		var wn: int = count_meshes(m.weapons[wk])
		# 최적화: 무기 그룹 안 조각도 합침 (활은 활대·시위가 다른 부모라 2, 성수병은 반투명 유리 2개를 따로 둬서 3)
		check(k2 + " 손에 든 무기 조각 합침 (%s)" % wk, wn <= 3, "%d개" % wn)
		if wk == "trumpet":
			check("트럼펫 13조각 → 1", wn == 1, "%d개" % wn)
		m.free()
	check("의상 조각 (야만인 표범무늬·수염, 궁수 리벳, 석궁병 방패, 성직자 영대)", counts.barbarian > 70 and counts.archer > 45 and counts.crossbow > 45 and counts.cleric > 40, str(counts))

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
