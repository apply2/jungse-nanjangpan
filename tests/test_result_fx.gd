extends SceneTree
## 결과 화면 승리·패배 연출 자동 테스트 (사용자 요청):
##   개인전 3등 = 승리, 4등 = 패배 / 쟁탈전 우리 팀 승리 = 승리, 패배 = 패배, 무승부 = 소리 없음
##   문구가 맞는 목록에서 나옴 / 헤드리스에서 효과음을 불러도 오류 없음 / 화면을 닫으면 Engine.time_scale = 1.0
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_result_fx.gd

var main: Node
var G: Node
var C
var p
var M
var fails := 0


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.third_person = true
	G.difficulty = "normal"
	G.chosen_cls = "barbarian"
	G.mode = "ffa"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G.ai_enabled = false
	_run()


func wait(n: int) -> void:
	for i in n:
		await process_frame


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


## 내가 rank등이 되게 점수판 순서를 만든다
func rows_with_me_at(rank: int) -> Array:
	var others: Array = C.ents.filter(func(e): return e != p)
	var rows: Array = others.duplicate()
	rows.insert(rank - 1, p)
	return rows


func _run() -> void:
	await wait(3)
	C = main.get_node("Combat")
	p = main.get_node("Player")
	M = main.menu
	var S = root.get_node("Sfx")
	var L: Dictionary = G.RESULT_LINES
	main.start_match.call_deferred()
	await wait(5)
	check("경기 시작", main.state == "playing")

	# ── 승패 판정 ──
	check("개인전 1·2·3등 = 승리", M.ffa_result(1) == "victory" and M.ffa_result(2) == "victory" and M.ffa_result(3) == "victory")
	check("개인전 4등부터 = 패배", M.ffa_result(4) == "defeat" and M.ffa_result(8) == "defeat")
	check("쟁탈전 판정", M.control_result("blue", "blue") == "victory" and M.control_result("red", "blue") == "defeat" and M.control_result("", "blue") == "draw")

	# ── 헤드리스 효과음 ──
	S.play_stinger("victory")
	check("헤드리스에서 효과음 불러도 오류 없음 (이름만 남음)", S.last_stinger == "victory")
	S.stop_stinger()

	# ── 개인전 3등: 승리 ──
	main.end_match()  # 실제 흐름 (state ended)
	await wait(2)
	M.open_end(rows_with_me_at(3), p)
	check("3등 → 승리 연출", M.end_result == "victory" and M._end_title.text == "3등!", M._end_title.text)
	check("3등 문구는 3등 목록에서", L.ffa[3].lines.has(M.end_phrase) and M._end_memo.visible, M.end_phrase)
	check("승리: 처음엔 느린 화면 0.3", is_equal_approx(Engine.time_scale, G.RESULT.slowmo), "ts=%.2f" % Engine.time_scale)
	check("승리 버튼은 '한 판 더'", M._end_again.text == "한 판 더")
	await wait(int(G.RESULT.slowmo_t * 60) + 10)
	check("0.6초 뒤 시간 원래대로", Engine.time_scale == 1.0, "ts=%.2f" % Engine.time_scale)
	check("효과음 승리", S.last_stinger == "victory")
	check("햇살·색종이", M._sun.visible and M._fx_nodes.size() >= 2, "fx=%d" % M._fx_nodes.size())
	await wait(150)
	var rows: Array = M._table_rows()
	check("점수판 줄이 다 펼쳐짐", rows.size() > 3 and rows.all(func(r): return r.modulate.a > 0.99), "rows=%d" % rows.size())
	check("버튼이 나타남", M._end_btns.all(func(b): return not b.disabled and b.modulate.a > 0.99))
	check("제목 판 제자리", absf(M._end_card.position.y) < 0.5 and absf(M._end_card.rotation_degrees) < 0.5, "y=%.1f rot=%.1f" % [M._end_card.position.y, M._end_card.rotation_degrees])

	# ── 개인전 4등: 패배 ──
	M.open_end(rows_with_me_at(4), p)
	check("4등 → 패배 연출", M.end_result == "defeat" and M._end_title.text == "4등...", M._end_title.text)
	check("패배 문구는 패배 목록에서", L.ffa_lose.lines.has(M.end_phrase), M.end_phrase)
	check("패배 버튼은 '복수하러 간다'", M._end_again.text == "복수하러 간다", M._end_again.text)
	check("패배엔 느린 화면 없음 + 회색 배경", Engine.time_scale == 1.0 and M._end_gray.visible)
	await wait(90)
	check("효과음 패배 + 비", S.last_stinger == "defeat" and M._clouds.visible and M._fx_nodes.size() >= 1)
	await wait(60)
	check("판이 10° 기울어짐", absf(M._end_card.rotation_degrees - G.RESULT.tilt_deg) < 1.0, "rot=%.1f" % M._end_card.rotation_degrees)

	# ── 화면을 닫으면 다 되돌림 (승리 느린 화면 도중에 닫기) ──
	M.open_end(rows_with_me_at(1), p)
	check("1등 제목", M._end_title.text == "1등!" and L.ffa[1].lines.has(M.end_phrase), M._end_title.text)
	check("느린 화면 중", Engine.time_scale < 1.0)
	M.again_requested.emit()  # 한 판 더
	await wait(3)
	check("한 판 더 → 시간 1.0 + 연출 정리", Engine.time_scale == 1.0 and not M._fx_on and M._fx_tweens.is_empty() and main.state == "playing",
		"ts=%.2f" % Engine.time_scale)
	await wait(2)
	check("입자 지움", M._end_front.get_child_count() == 0, "n=%d" % M._end_front.get_child_count())

	# ── 쟁탈전 문구·제목 (판정 함수 + 화면) ──
	var team_rows: Array = C.ents.duplicate()
	p.team = "blue"
	M.open_end_control("blue", {"blue": 2, "red": 1}, team_rows, p)
	check("쟁탈전 우리 팀 승리 → 승리", M.end_result == "victory" and M._end_title.text == "승리!" and M._end_kicker.text == "블루팀" and M._end_pennant.visible and L.ctrl_win.lines.has(M.end_phrase), M._end_title.text)
	M.open_end_control("red", {"blue": 1, "red": 2}, team_rows, p)
	var lose_lines: Array = L.ctrl_lose.lines.map(func(s): return s.format({"enemy": "레드팀"}))
	check("쟁탈전 우리 팀 패배 → 패배", M.end_result == "defeat" and M._end_title.text == L.ctrl_lose.title and lose_lines.has(M.end_phrase), M.end_phrase)
	check("쟁탈전 패배 버튼 '우물 되찾기' + 이긴 팀 작은 깃발", M._end_again.text == L.again_lose_ctrl and M._end_winner.visible and M._end_winner_l.text.begins_with("레드팀"))
	p.team = "red"
	var seen_blue := false
	for i in 30:  # 레드팀이 지면 '블루팀이 우리 우물에서 세수 중'
		M.open_end_control("blue", {"blue": 2, "red": 0}, team_rows, p)
		if M.end_phrase.contains("세수"):
			seen_blue = M.end_phrase.begins_with("블루팀")
			break
	check("레드팀이면 상대 이름이 블루팀", seen_blue)
	S.last_stinger = ""
	M.open_end_control("", {"blue": 1, "red": 1}, team_rows, p)
	await wait(60)
	check("무승부: 연출·소리 없음", M.end_result == "draw" and M._end_title.text == "무승부" and S.last_stinger == "" and not M._fx_on and not M._end_memo.visible)
	p.team = ""

	# ── 메뉴로 나가도 시간 1.0 ──
	M.open_end(rows_with_me_at(2), p)
	check("2등 → 승리", M.end_result == "victory" and M._end_title.text == "2등!" and L.ffa[2].lines.has(M.end_phrase))
	M.menu_requested.emit("main")
	await wait(3)
	check("메인 메뉴로 → 시간 1.0 + 연출 정리", Engine.time_scale == 1.0 and not M._fx_on and main.state == "menu", "ts=%.2f" % Engine.time_scale)

	print("test_result_fx: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
