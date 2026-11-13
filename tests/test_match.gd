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

	# ── 메인 화면 (마을 게시판, 시안 Main.html) ──
	var MM: Dictionary = G.MAIN_MENU
	check("메인: 이정표 5개", M._main_signs.size() == 5 and M._main_signs.ai.face.board.kind == "wood"
		and M._main_signs.exit.face.board.kind == "parch" and M._main_signs.ranked.face.board.arrow, str(M._main_signs.keys()))
	var ai_face = M._main_signs.ai.face
	ai_face._hover = true
	ai_face._anim()
	var lit: bool = ai_face.board.paint == G.col(G.UI.gilt)
	ai_face._hover = false
	ai_face._anim()
	check("메인: 마우스 올린 이정표만 노랗게, 떼면 원래대로", lit and ai_face.board.paint.a == 0
		and M._main_signs.friend.face.board.paint.a == 0, "")
	check("메인: 오늘의 팁은 목록 중 하나", MM.tips.has(M._tip_label.text), M._tip_label.text)
	check("메인: 화면 전체 그늘 대신 왼쪽만 어둡게", not M.screens.menu.get_meta("bg").visible, "")
	check("메인: 버전 + 친구대전 안내 (PC)", M._main_foot.text.begins_with(G.VERSION) and M._main_foot.text.contains("와이파이"), M._main_foot.text)
	check("메인: 병과 무리 4명이 움직임", M._crowd.active and M._crowd.models.size() == 4
		and M._crowd.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "")
	M._main_signs.ranked.pressed.emit()
	await wait(2)
	check("일반대전 → 알림 상자", M._toast_l.text == "추후 업데이트 될 내용입니다." and M.cur_page == "main", "")
	var seen := {}
	for i in 40:  # 메인 화면을 다시 열 때마다 팁을 새로 고름
		M.show_page("settings")
		M.show_page("main")
		seen[M._tip_label.text] = true
	check("메인을 열 때마다 팁이 바뀜", seen.size() >= 3, "%d가지" % seen.size())
	M._main_signs.settings.pressed.emit()
	await wait(2)
	check("설정 이정표 → 설정 (그늘 다시 켬), 병과 무리는 멈춤", M.cur_page == "settings" and M.screens.menu.get_meta("bg").visible
		and not M._crowd.active and M._crowd.render_target_update_mode == SubViewport.UPDATE_DISABLED, "")
	M.show_page("main")
	await wait(2)
	check("메인으로 돌아오면 병과 무리 다시 움직임", M._crowd.active, "")

	# ── 메뉴 페이지 이동 ──
	M.open_diff_page()
	check("AI대전 → 난이도 페이지", M.cur_page == "diff" and M._diff_host.get_child_count() == 3, "")
	M.open_class_page()
	check("난이도 → 병과 페이지 (설명에 난이도)", M.cur_page == "class" and M._class_sub.text.contains("어려움") and M._class_host.get_child_count() == G.CLASS_ORDER.size(), M._class_sub.text)
	# ── 병과 화면 (마을 게시판: 카드는 고르기만, 출전 버튼으로 시작) ──
	var sfx := root.get_node("Sfx")
	check("병과 화면은 메뉴 그늘 없이 판자벽", not M.screens.menu.get_meta("bg").visible, "")
	check("처음 고른 병과 = 저장된 병과, 카드에 형광펜 테", M._class_pick == G.chosen_cls
		and M._class_cards[G.chosen_cls].face.board.ring == G.col(G.UI.marker), M._class_pick)
	await wait(2)
	check("병과 화면이 보이면 큰 액자 그림", M._class_stage.active, "")
	var other: String = "archer" if G.chosen_cls != "archer" else "bard"
	sfx.played.clear()
	M._class_cards[other].pressed.emit()
	await wait(30)
	check("카드를 누르면 고르기만 (시작 안 함)", M.cur_page == "class" and main.state == "menu" and M._class_pick == other, "state=%s" % main.state)
	check("고른 카드만 형광펜 테", G.CLASS_ORDER.all(func(k): return (M._class_cards[k].face.board.ring.a > 0) == (k == other)), "")
	check("바꾸면 합격 도장 쾅 (효과음)", sfx.played.has("stamp") and M._class_stamp.scale.is_equal_approx(Vector2.ONE), str(sfx.played))
	sfx.played.clear()
	M._class_cards[other].pressed.emit()
	await wait(30)
	check("같은 카드 다시 누르면 도장 안 찍음", not sfx.played.has("stamp"), "")
	var st: Dictionary = G.class_stats(other)
	check("정보 양피지: 이름·무기·한마디·설명", M._ci.name.text == G.CLASSES[other].name
		and M._ci.weapon.text == "무기: " + G.WEAPONS[G.CLASSES[other].weapon].name
		and M._ci.line.text == G.CLASS_PAGE.lines[other] and M._ci.desc.text == st.blurb and not st.blurb.contains("{"), M._ci.desc.text)
	check("정보 양피지: 체력·속도·사거리 숫자", M._ci.hp_n.text == str(G.CLASSES[other].hp)
		and M._ci.speed_n.text == "%.1f / %.1f" % [st.walk, st.run] and M._ci.range_n.text.ends_with("m"), M._ci.speed_n.text)
	await wait(20)  # 막대가 늘어나는 Tween
	var hp_max := 0.0
	for k: String in G.CLASS_ORDER:
		hp_max = maxf(hp_max, float(G.CLASSES[k].hp))
	check("막대 길이 = 병과 중 최대값 대비", absf(M._ci.hp.k - float(G.CLASSES[other].hp) / hp_max) < 0.01, "k=%.3f" % M._ci.hp.k)
	# 능력치 계산: 걷기 = 기본 × 병과, 달리기 ×1.35, 돌멩이 사거리 = 15m 상한, 트럼펫 = 12m
	var sb: Dictionary = G.class_stats("barbarian")
	check("야만인 7.4 / 10.0 m/s", "%.1f / %.1f" % [sb.walk, sb.run] == "7.4 / 10.0", "%.2f %.2f" % [sb.walk, sb.run])
	check("사거리: 돌멩이 ≤15m(상한)·트럼펫 12m·석궁이 가장 멂", sb.range > 10.0 and sb.range <= 15.0
		and is_equal_approx(G.class_stats("bard").range, 12.0) and G.class_stats("crossbow").range_k == 1.0,
		"%.1f %.1f" % [sb.range, G.class_stats("bard").range])
	check("모든 병과 한마디·설명 있음", G.CLASS_ORDER.all(func(k): return G.CLASS_PAGE.lines.has(k) and G.CLASS_PAGE.blurbs.has(k)), "")
	M.show_page("mode")
	await wait(2)
	check("다른 페이지로 가면 큰 액자 멈춤", not M._class_stage.active and M._class_stage.render_target_update_mode == SubViewport.UPDATE_DISABLED, "")
	M.open_class_page()
	# 난이도·모드 카드: 누르면 고르기만, '다음'으로 저장하고 넘어감
	M.open_diff_page()
	var dcards: Array = M._diff_host.get_children()
	check("난이도 카드 3장, 지금 난이도에 형광펜", dcards.size() == 3, "")
	M.open_mode_page()
	check("모드 카드 2장 (쟁탈전 = 블루|레드 띠)", M._mode_host.get_child_count() == 2, "")
	M.open_class_page()
	M.toast("추후 업데이트 될 내용입니다.")
	await wait(20)
	check("아래쪽 알림 상자", M._toast.visible and M._toast_l.text == "추후 업데이트 될 내용입니다.", "")

	# ── 병과 고르면 바로 시작 ──
	bots()[0].kills = 5
	M.select_class("barbarian")
	await wait(2)
	check("병과 고르면 경기 시작", main.state == "playing" and not M.screens.menu.visible and main.hud.visible, "state=%s" % main.state)
	check("경기 중엔 메뉴 병과 무리 안 그림", not M._crowd.active and M._crowd.render_target_update_mode == SubViewport.UPDATE_DISABLED, "")
	check("고른 병과로 스폰",p.alive and p.cls == "barbarian" and not p.spectating and not p.orbit and p.input_enabled, "cls=%s" % p.cls)
	check("모두 0킬 0죽음, 다 살아 있음", C.ents.all(func(e): return e.kills == 0 and e.deaths == 0 and e.alive), "")
	check("4분 시작", absf(main.time_left - G.MATCH_TIME) < 0.1, "t=%.2f" % main.time_left)
	check("전투 시작 문구", main.hud._banner_t.text == "전투 시작!" and main.hud._banner_s.text.contains("어려움 · 야만인 · 20킬"), main.hud._banner_s.text)
	await wait(60)
	check("시간이 흐름", main.time_left < G.MATCH_TIME - 0.9 and main.time_left > G.MATCH_TIME - 1.1, "t=%.2f" % main.time_left)
	check("남은 시간 표시 M:SS", main.hud._timer.text == "3:59", main.hud._timer.text)
	# ── HUD 배치 규칙 (시안 Guide "경기 화면 규칙"): 가운데 40% 비움, 모서리 판 높이 1080p 120px(=80) 이하 ──
	var H = main.hud
	var vp: Vector2 = H._topbar.get_viewport_rect().size
	var kf: float = G.HUD_UI.center_free
	var free := Rect2(vp * (0.5 - kf / 2), vp * kf)
	var corner := {"vitals": H._medal.get_parent(), "weapon": H._w_name.get_parent().get_parent().get_parent(), "feed": H._feed}
	var bad := []
	for n: String in corner:
		var r: Rect2 = corner[n].get_global_rect()
		if r.intersects(free) or (n != "feed" and r.size.y > 80.5):
			bad.append("%s %s" % [n, r])
	if H._topbar.get_global_rect().intersects(free):
		bad.append("topbar %s" % H._topbar.get_global_rect())
	check("HUD: 가운데 40% 비움 · 판 높이 80 이하", bad.is_empty(), str(bad))
	check("HUD: 무기 칸 = 아이콘 + 이름 + 상태", H._w_name.text == "돌멩이" and H._w_icon.texture != null and H._w_state.text != "", H._w_state.text)

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
	var row0: Control = main.hud._feed_items[0].n
	var icons := row0.find_children("*", "TextureRect", true, false)
	check("킬피드: 화살표 대신 무기 아이콘 (양피지 줄)", icons.size() == 1 and row0 is PanelContainer and (row0 as Object).get("kind") == "parch", str(icons.size()))
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
	check("다음 부활 병과", p.next_cls == "cleric" and p.cls == "barbarian" and main.hud._cls_note.text.contains("→ 다음 부활 성직자")
		and main.hud._cls_note_box.visible and main.hud._cls.text == "야만인", main.hud._cls_note.text)
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
	var my_rank: int = C.score_rows().find(p) + 1
	var want_title: String = str(G.RESULT_LINES.ffa[my_rank].title) if my_rank <= 3 else str(G.RESULT_LINES.ffa_lose.title) % my_rank
	check("남이 1위면 내 순위 제목 + 우승자", M._end_title.text == want_title and M._end_sub.text.contains(top_name), "%s / %s" % [M._end_title.text, M._end_sub.text])
	check("결과 화면에선 조작 안 됨 + 빙 도는 카메라", not p.input_enabled and p.orbit, "")
	check("결과 점수판 줄 수", M._end_table.get_child(0).get_child_count() == G.BOT_COUNT + 2, "rows=%d" % M._end_table.get_child(0).get_child_count())

	# ── 한 판 더 → 내가 20킬이면 승리 ──
	M.again_requested.emit()
	await wait(2)
	check("한 판 더", main.state == "playing" and C.ents.all(func(e): return e.kills == 0) and main.hud._feed_items.is_empty(), "")
	p.kills = G.KILL_LIMIT - 1
	C.kill(b[1], p, "stone", false, Vector3.FORWARD)
	check("20킬 하면 바로 끝", main.state == "ended", "state=%s" % main.state)
	check("내가 1위면 '1등!'", M._end_title.text == "1등!" and M.end_result == "victory" and M._end_sub.text.contains("20킬"), M._end_sub.text)

	# ── 남이 20킬이어도 끝 ──
	M.again_requested.emit()
	await wait(2)
	b[3].kills = G.KILL_LIMIT - 1
	C.kill(b[4], b[3], "bow", false, Vector3.FORWARD)
	check("봇이 20킬 해도 끝", main.state == "ended" and M._end_title.text != "1등!", M._end_title.text)

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
