extends SceneTree
## 마을 게시판 UI 재료 (UiKit) 자동 테스트: 팔레트·HUD 상수, 개구 글꼴, Board 재질 3개·이정표·쇠못·밧줄·기울기 한도,
## 버튼 3종이 여전히 Button(text·pressed·disabled), 글자 따라가기, 고름 = 형광펜, 이정표 Tap 누름, 설정 패널 버튼
## godot --headless --fixed-fps 60 --path . -s tests/test_ui_kit.gd

var G: Node
var U
var fails := 0


func check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("" if ok or info == "" else "  (" + str(info) + ")"))
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	U = load("res://scripts/ui_kit.gd")
	_run()


func _run() -> void:
	await frames(2)
	# 팔레트 (Guide.html 색)
	var want := {"ink": 0x2b1d12, "parch": 0xf4e4bc, "wood": 0x9a6236, "wood_hi": 0xb57a47, "wood_lo": 0x8a542b,
		"gilt": 0xf2b44a, "marker": 0xffd84a, "hp": 0x6cc35a, "blue": 0x3d6fd6, "red": 0xd8453b, "cream": 0xfff8e6}
	var bad := []
	for k: String in want:
		if int(G.UI.get(k, -1)) != int(want[k]):
			bad.append(k)
	check("팔레트가 시안 색", bad.is_empty(), str(bad))
	check("옛 키 이름은 없음", not (G.UI.has("gold") or G.UI.has("line") or G.UI.has("mute") or G.UI.has("blood")))
	var H = load("res://scripts/hud.gd")
	var hud_ok: bool = H.PARCH == G.col(G.UI.parch) and H.GOLD == G.col(G.UI.marker) and H.BLOOD == G.col(G.UI.red) \
		and H.MOSS == G.col(G.UI.hp) and H.MUTE == G.col(G.UI.dust) and H.STEEL == G.col(G.UI.sky) and H.INK == G.col(G.UI.ink)
	check("HUD 상수 = GameData.UI", hud_ok)
	check("HUD 그림자 = 잉크", H.SHADOW.is_equal_approx(Color(G.col(G.UI.ink), 0.9)))

	# 글꼴
	var sc: FontFile = U.SCRIBBLE
	check("개구 글꼴 불러옴", sc != null and sc.has_char("넘".unicode_at(0)))
	check("개구에 Noto·도현 대체 폰트", sc.fallbacks.size() >= 2)
	var sl: Label = U.scribble("넘어졌다... 다시?", 20, U.c("ink"))
	check("scribble 라벨은 개구", sl.get_theme_font("font") == sc)
	sl.free()
	check("외곽선: 작은 글자 3~4, 큰 글자 ≤ 9", U.outline_for(14) in [3, 4] and U.outline_for(60) == 9 and U.outline_for(32) >= 6)

	# Board
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	for kind: String in ["wood", "parch", "gilt"]:
		var b = U.Board.new(kind, Vector4(10, 6, 10, 6))
		host.add_child(b)
		b.size = Vector2(200, 60)
		b._build()
		var outer: PackedVector2Array = b._geo.outer
		var inside := true
		for p in b._geo.pts:
			inside = inside and p.x >= 0 and p.x <= 200 and p.y >= 0 and p.y <= 60
		check("%s 판: 외곽선·바탕 삼각형" % kind, outer.size() > 8 and b._geo.idx.size() % 3 == 0 and b._geo.idx.size() > 0 and inside)
		if kind != "parch":
			check("%s 판: 나뭇결 선" % kind, b._geo.lines.size() >= 3)
		var sb: StyleBox = b.get_theme_stylebox("panel")
		var line: float = G.UI_KIT[kind].line
		check("%s 판: 여백 = pad + 외곽선" % kind, is_equal_approx(sb.content_margin_left, 10 + line))
	var w1 = U.Board.new("wood")
	var w2 = U.Board.new("wood")
	host.add_child(w1)
	host.add_child(w2)
	for w in [w1, w2]:
		w.size = Vector2(300, 80)
		w._build()
	var g1: Array = w1._geo.lines
	var w1b = U.Board.new("wood")
	w1b.grain_seed = w1.grain_seed
	host.add_child(w1b)
	w1b.size = Vector2(300, 80)
	w1b._build()
	check("나뭇결: 같은 seed면 같은 무늬", str(g1) == str(w1b._geo.lines))
	check("나뭇결: 인스턴스마다 seed 다름", w1.grain_seed != w2.grain_seed and str(g1) != str(w2._geo.lines))
	var ar = U.Board.new("wood", Vector4(10, 6, 10, 6))
	ar.arrow = true
	host.add_child(ar)
	ar.size = Vector2(300, 60)
	ar._build()
	var tipx := 0.0
	for p in ar._geo.outer:
		tipx = maxf(tipx, p.x)
	var right_mid: float = ar._xr(ar._geo.inner, 30).y
	var right_top: float = ar._xr(ar._geo.inner, 5).y
	check("이정표: 오른쪽 끝 뾰족 (가운데가 가장 멂)", is_equal_approx(tipx, 300.0) and right_mid > right_top + 10)
	check("이정표: 오른쪽 여백에 뾰족한 부분", ar.get_theme_stylebox("panel").content_margin_right >= float(G.UI_KIT.arrow_tip))
	ar.tilt = 10.0
	check("기울기 ±3° 한도", is_equal_approx(ar.tilt, 3.0))
	ar.nails = 4
	ar.ropes = true
	ar.queue_redraw()
	await frames(2)
	check("쇠못·밧줄 그려도 오류 없음", ar.nails == 4 and ar.ropes)
	var tw: Control = U.tilted(U.Board.new("parch"), -8.0)
	host.add_child(tw)
	tw.size = Vector2(100, 40)
	await frames(1)
	check("tilted(): 감싼 안쪽만 돌림, 한도 3°", is_equal_approx(rad_to_deg(tw.get_child(0).rotation), -3.0) and tw.rotation == 0.0)
	check("nail_icon 텍스처", U.nail_icon(7.0).get_width() >= 14)

	# 버튼 3종 — Button 그대로
	var box := VBoxContainer.new()
	host.add_child(box)
	var pr = U.primary("이놈으로 출전")
	var gh = U.ghost("도망가기")
	var bk = U.back()
	for b in [pr, gh, bk]:
		box.add_child(b)
	await frames(2)
	check("primary = 금칠 판 Button + 쇠못 2", pr is Button and pr.board.kind == "gilt" and pr.board.nails == 2 and pr.text == "이놈으로 출전")
	check("ghost·back = 양피지 Button", gh is Button and gh.board.kind == "parch" and bk.board.kind == "parch" and bk.text == "← 뒤로")
	check("버튼 크기 = 판 크기", pr.size.x >= pr.board.get_combined_minimum_size().x and pr.size.y >= pr.board.get_combined_minimum_size().y)
	var hits := [0]
	pr.pressed.connect(func() -> void: hits[0] += 1)
	pr.pressed.emit()
	check("pressed 신호 그대로", hits[0] == 1)
	pr.text = "한 판 더"
	await frames(2)
	check("글자 바꾸면 판 글자도 따라감", pr.caption.text == "한 판 더")
	gh.selected = true
	check("고름 = 형광펜 바탕", gh.board.paint == U.c("marker"))
	gh.selected = false
	check("고름 풀면 양피지", gh.board.paint.a == 0.0)
	bk.disabled = true
	await frames(2)
	check("못 누르면 흐리게", bk.face.modulate.a < 1.0)
	gh.face._hover = true
	gh.face._anim()
	await frames(12)
	check("마우스 올림: 살짝 들리고 기울기", gh.face.lean < -0.5 and gh.board.rotation != 0.0)
	gh.face._hover = false
	gh.face._anim()
	await frames(12)
	check("마우스 내림: 제자리", absf(gh.face.lean) < 0.01 and gh.board.position.is_equal_approx(Vector2.ZERO))
	box.queue_sort()
	gh.face._hover = true
	gh.face._anim()
	await frames(12)
	box.queue_sort()
	await frames(2)
	check("다시 정렬돼도 판 기울기 유지", gh.board.rotation != 0.0)

	# 이정표 navbtn
	var nb = U.navbtn("AI대전", "봇 7명과 개인전", "hero")
	box.add_child(nb)
	await frames(2)
	check("navbtn = 금칠 이정표 Tap", nb.face.board.kind == "gilt" and nb.face.board.arrow and nb.face.sign)
	var tapped := [0]
	nb.pressed.connect(func() -> void: tapped[0] += 1)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	nb._gui_input(ev)
	check("이정표 누르면 pressed", tapped[0] == 1)
	var nb2 = U.navbtn("설정", "", "sub")
	check("이정표 기본 = 나무", nb2.face.board.kind == "wood")
	nb2.free()

	# 설정 패널 (이번에 새 재질을 입힌 화면)
	var sp = load("res://scenes/ui/settings_panel.tscn").instantiate()
	host.add_child(sp)
	await frames(2)
	check("설정: 나무 게시판 + 쇠못 4", sp.get_child(0).kind == "wood" and sp.get_child(0).nails == 4)
	G.gfx_quality = "normal"
	sp.refresh()
	check("설정: 지금 그래픽 버튼만 형광펜", sp._gfx_btns.normal.selected and not sp._gfx_btns.low.selected)
	sp._view_btns.fp.pressed.emit()
	check("설정: 1인칭 누르면 형광펜이 옮겨감", sp._view_btns.fp.selected and not sp._view_btns.tp.selected and not G.third_person)
	G.third_person = true

	# 최적화: 판·못·HUD 도형을 삼각형 한 묶음(UiKit.Tris)으로 — 그리기 호출 한 번
	var T = U.Tris.new()
	T.poly(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]), Color.RED, true)
	check("Tris: 다각형 + 부드러운 테두리 = 부채 4 + 테 4칸", T.idx.size() == 4 * 3 + 4 * 6 and T.pts.size() == 1 + 4 + 4, "idx %d pts %d" % [T.idx.size(), T.pts.size()])
	T.clear()
	T.line(PackedVector2Array([Vector2(0, 0), Vector2(0, 0), Vector2(10, 0)]), Color.RED, 2.0)
	check("Tris: 선 (겹친 점 빼고) 한 칸 = 띠 3줄", T.idx.size() == 18 and T.pts.size() == 8, "idx %d pts %d" % [T.idx.size(), T.pts.size()])
	var okb := true
	for kind in ["wood", "parch", "gilt"]:
		var bb = U.Board.new(kind)
		bb.nails = 4
		bb.bands = [Color.RED, Color.BLUE]
		host.add_child(bb)
		bb.size = Vector2(220, 90)
		bb._build()
		var tr = bb._geo.tris
		var mx := 0
		for i in tr.idx:
			mx = maxi(mx, i)
		okb = okb and tr.idx.size() > 0 and tr.idx.size() % 3 == 0 and mx < tr.pts.size() and tr.pts.size() == tr.cols.size()
		bb.queue_free()
	check("판: 외곽선·바탕·결·띠·못을 삼각형 한 묶음으로 미리 만듦", okb)

	host.queue_free()
	await frames(2)
	_font_coverage()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit()


## 웹엔 시스템 폰트가 없어서 폰트에 없는 글자는 □로 나온다.
##   1) scripts·scenes의 문자열 글자가 전부 도현 + Noto 대체 폰트에 있는지
##   2) 개구(손글씨)로 쓰는 문구가 전부 개구에 있는지 (없으면 도현으로 대신 그려져 모양이 섞임)
func _font_coverage() -> void:
	var dh: FontFile = load("res://fonts/DoHyeon-Regular.ttf")
	var chain: Array = [dh, load("res://fonts/NotoSans-Bold-sub.ttf"), load("res://fonts/NotoSansSymbols2-sub.ttf")]
	var gaegu: FontFile = load("res://fonts/Gaegu-Bold-sub.woff2")
	var lit := RegEx.new()
	lit.compile('"((?:[^"\\\n]|\\.)*)"')
	var files: Array[String] = []
	_collect(files, "res://scripts", ".gd")
	_collect(files, "res://scenes", ".tscn")
	var missing := {}
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		for m in lit.search_all(src):
			var s: String = m.get_string(1).c_unescape()
			if s.begins_with("<svg") or s.begins_with("res://") or s.begins_with("shader_type"):
				continue
			for ch in s:
				var u := ch.unicode_at(0)
				if u < 32:
					continue
				if not chain.any(func(ff: FontFile) -> bool: return ff.has_char(u)):
					missing[ch] = f.get_file()
	check("문자열 글자가 전부 도현·Noto에 있음 (웹 □ 없음)", missing.is_empty(), str(missing))
	# 개구로 쓰는 문구 (UiKit.scribble 자리)
	var R: Dictionary = G.RESULT_LINES
	var texts: Array = [G.HUD_UI.death.title, G.MAIN_MENU.motto.text, "멍청한 봇이랑 한판", "친구를 넘어뜨리자", "준비\n중",
		G.CLASS_PAGE.hint.text, "바꾸면 바로 저장돼요.", R.lose_note % 37, R.mvp_cap, R.mvp_kill, R.lose_cap, "0123456789분초:()-"]
	texts.append_array(G.MAIN_MENU.tips)
	texts.append_array(G.CLASS_PAGE.lines.values())
	texts.append_array(G.BOT_NAMES)
	for k in [1, 2, 3]:
		texts.append_array(R.ffa[k].lines)
	for k in ["ffa_lose", "ctrl_win", "ctrl_lose"]:
		texts.append_array(R[k].lines)
	for t in G.MODES.control.teams.values():
		texts.append(str(t.name))
	var g_miss := ""
	for t in texts:
		for ch in str(t):
			var u := ch.unicode_at(0)
			if u > 32 and not gaegu.has_char(u) and not g_miss.contains(ch):
				g_miss += ch
	check("개구 문구 글자가 전부 개구에 있음", g_miss == "", g_miss)


func _collect(out: Array[String], dir: String, ext: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_collect(out, dir + "/" + d, ext)
