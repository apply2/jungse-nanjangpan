extends SceneTree
## 경기 흐름 자동 테스트 — HTML startMenuSim / startMatch / endMatch / pauseGame / scoreRows / killfeed와 같은지 확인.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_match.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var main: Node
var G: Node
var C
var p
var fails := 0


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G.third_person = true
	G.difficulty = "hard"
	G.chosen_cls = "crossbow"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G.ai_enabled = false  # 봇은 가만히
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func bots() -> Array:
	return C.ents.filter(func(e): return e.is_bot)


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	p = main.get_node("Player")
	var M = main.menu

	# ── 처음엔 메뉴: 나는 구경, 봇끼리 싸움 ──
	check("처음엔 메뉴", main.state == "menu" and M.screens.menu.visible and M.cur_page == "main", "state=%s" % main.state)
	check("메뉴에선 나는 구경 중 (안 살아남)", p.spectating and not p.alive and p.orbit, "")
	check("봇 7명은 살아서 싸움", bots().size() == G.BOT_COUNT and bots().all(func(b): return b.alive), "n=%d" % bots().size())
	check("메뉴에선 HUD 숨김", not main.hud.visible, "")
	check("구경 중인 나는 점수판에 없음", not C.score_rows().has(p) and C.score_rows().size() == G.BOT_COUNT, "")
	await wait(200)
	check("구경 중엔 부활 안 함", not p.alive, "")
	var cam: Camera3D = p.cam
	check("메뉴 카메라: 반지름 52 높이 26 시야 60", absf(Vector2(cam.global_position.x, cam.global_position.z).length() - 52.0) < 0.1
		and absf(cam.global_position.y - 26.0) < 0.01 and absf(cam.fov - 60.0) < 0.01, "pos=%s fov=%.1f" % [cam.global_position, cam.fov])

	# ── 메뉴 페이지 이동 ──
	M.open_diff_page()
	check("AI대전 → 난이도 페이지", M.cur_page == "diff" and M._diff_host.get_child_count() == 3, "")
	M.open_class_page()
	check("난이도 → 병과 페이지 (설명에 난이도)", M.cur_page == "class" and M._class_sub.text.contains("어려움") and M._class_host.get_child_count() == G.CLASS_ORDER.size(), M._class_sub.text)
	M.toast("추후 업데이트 될 내용입니다.")
	await wait(20)
	check("아래쪽 알림 상자", M._toast.visible and M._toast_l.text == "추후 업데이트 될 내용입니다.", "")

	# ── 병과 고르면 바로 시작 ──
	bots()[0].kills = 5
	M.select_class("barbarian")
	await wait(2)
	check("병과 고르면 경기 시작", main.state == "playing" and not M.screens.menu.visible and main.hud.visible, "state=%s" % main.state)
	check("고른 병과로 스폰", p.alive and p.cls == "barbarian" and not p.spectating and not p.orbit and p.input_enabled, "cls=%s" % p.cls)
	check("모두 0킬 0죽음, 다 살아 있음", C.ents.all(func(e): return e.kills == 0 and e.deaths == 0 and e.alive), "")
	check("4분 시작", absf(main.time_left - G.MATCH_TIME) < 0.1, "t=%.2f" % main.time_left)
	check("전투 시작 문구", main.hud._banner_t.text == "전투 시작!" and main.hud._banner_s.text.contains("어려움 · 야만인 · 20킬"), main.hud._banner_s.text)
	await wait(60)
	check("시간이 흐름", main.time_left < G.MATCH_TIME - 0.9 and main.time_left > G.MATCH_TIME - 1.1, "t=%.2f" % main.time_left)
	check("남은 시간 표시 M:SS", main.hud._timer.text == "3:59", main.hud._timer.text)

	# ── 점수판 순서: 처치 많은 순, 같으면 죽음 적은 순 ──
	var b := bots()
	b[0].kills = 3; b[0].deaths = 2
	b[1].kills = 3; b[1].deaths = 1
	b[2].kills = 5
	var rows: Array = C.score_rows()
	check("점수판 순서", rows[0] == b[2] and rows[1] == b[1] and rows[2] == b[0], "")
	await wait(2)
	check("1위 표시 (남이 1위)", main.hud._leader.text.contains(b[2].ent_name) and main.hud._leader.text.ends_with("위"), main.hud._leader.text)

	# ── 처치하면 킬피드, 내가 죽으면 사망 화면 ──
	C.kill(b[3], b[4], "stone", true, Vector3.FORWARD)
	check("킬피드 한 줄", main.hud._feed_items.size() == 1, "n=%d" % main.hud._feed_items.size())
	for i in 6:
		C.kill(b[5], b[6], "bow", false, Vector3.FORWARD)
	check("킬피드는 5줄까지", main.hud._feed_items.size() == 5, "n=%d" % main.hud._feed_items.size())
	C.kill(p, b[0], "crossbow", true, Vector3.FORWARD)
	await wait(2)
	check("사망 화면", main.hud._death.visible and main.hud._death_by.text.contains(b[0].ent_name) and main.hud._death_sub.text.contains("석궁 · 헤드샷 · 3초 뒤 부활"), main.hud._death_sub.text)
	await wait(int(G.FEED_LIFE * 60) + 5)
	check("킬피드는 5.5초 뒤 사라짐", main.hud._feed_items.is_empty(), "n=%d" % main.hud._feed_items.size())
	check("부활하면 사망 화면 닫힘", p.alive and not main.hud._death.visible, "")

	# ── 일시정지: 세상이 멈추고, 병과를 바꾸면 다음 부활부터 ──
	var pos0: Vector3 = p.global_position
	p.scripted_input = {"f": 1.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	main.pause_game()
	var t0: float = main.time_left
	await wait(30)
	check("일시정지 화면", main.state == "paused" and paused and M.screens.pause.visible and M._pause_cards.get_child_count() == G.CLASS_ORDER.size(), "")
	check("일시정지 중엔 안 움직이고 시간도 멈춤", p.global_position.distance_to(pos0) < 0.01 and main.time_left == t0, "moved=%.3f" % p.global_position.distance_to(pos0))
	M.next_class_picked.emit("cleric")
	await wait(2)
	check("다음 부활 병과", p.next_cls == "cleric" and p.cls == "barbarian" and main.hud._cls.text.contains("→ 다음 부활 성직자"), main.hud._cls.text)
	M.resume_requested.emit()
	await wait(10)
	check("계속하기", main.state == "playing" and not paused and not M.screens.pause.visible and p.global_position.distance_to(pos0) > 0.1, "")
	p.scripted_input = {}
	C.kill(p, null, "stone", false, Vector3.FORWARD)
	await wait(int(G.RESPAWN * 60) + 5)
	check("다음 부활 때 바뀐 병과", p.alive and p.cls == "cleric", "cls=%s" % p.cls)

	# ── 시간이 다 되면 끝 ──
	var top_name: String = C.score_rows()[0].ent_name
	main.time_left = 0.05
	await wait(10)
	check("4분 지나면 결과 화면", main.state == "ended" and M.screens.end.visible and not main.hud.visible, "state=%s" % main.state)
	check("남이 1위면 '경기 종료'", M._end_title.text == "경기 종료" and M._end_sub.text.contains(top_name), M._end_sub.text)
	check("결과 화면에선 조작 안 됨 + 빙 도는 카메라", not p.input_enabled and p.orbit, "")
	check("결과 점수판 줄 수", M._end_table.get_child(0).get_child_count() == G.BOT_COUNT + 2, "rows=%d" % M._end_table.get_child(0).get_child_count())

	# ── 한 판 더 → 내가 20킬이면 승리 ──
	M.again_requested.emit()
	await wait(2)
	check("한 판 더", main.state == "playing" and C.ents.all(func(e): return e.kills == 0) and main.hud._feed_items.is_empty(), "")
	p.kills = G.KILL_LIMIT - 1
	C.kill(b[1], p, "stone", false, Vector3.FORWARD)
	check("20킬 하면 바로 끝", main.state == "ended", "state=%s" % main.state)
	check("내가 1위면 '승리!'", M._end_title.text == "승리!" and M._end_sub.text.contains("20킬"), M._end_sub.text)

	# ── 남이 20킬이어도 끝 ──
	M.again_requested.emit()
	await wait(2)
	b[3].kills = G.KILL_LIMIT - 1
	C.kill(b[4], b[3], "bow", false, Vector3.FORWARD)
	check("봇이 20킬 해도 끝", main.state == "ended" and M._end_title.text == "경기 종료", "")

	# ── 메뉴로: 다 치우고 다시 구경 ──
	C.shatter(b[0], Vector3(0, 0, 10))
	M.menu_requested.emit("class")
	await wait(2)
	check("병과 다시 고르기 → 병과 페이지", main.state == "menu" and M.cur_page == "class" and M.screens.menu.visible, "page=%s" % M.cur_page)
	check("메뉴로 가면 구경 + 다 치움", p.spectating and not p.alive and C.zones.is_empty() and C.projectiles.is_empty(), "")
	check("메뉴 구경용 봇 점수 초기화", bots().all(func(e): return e.kills == 0 and e.deaths == 0), "")

	# ── 일시정지 → 메뉴로 나가기 ──
	M.select_class("archer")
	await wait(2)
	main.pause_game()
	await wait(2)
	M.menu_requested.emit("main")
	await wait(2)
	check("일시정지에서 메뉴로 나가면 안 멈춤", main.state == "menu" and not paused and M.cur_page == "main", "")

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
