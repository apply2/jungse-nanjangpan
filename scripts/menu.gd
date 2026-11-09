class_name Menu
extends CanvasLayer
## 메뉴·일시정지·결과 화면과 아래쪽 알림 상자 — HTML #menu / #pause / #end / #toast.
## 메인메뉴: 일반대전(준비 중 알림) / AI대전(난이도 → 병과 → 바로 시작) / 친구대전(9단계) / 설정 / 나가기.
## 경기 흐름은 Main이 쥐고, 여기서는 버튼을 눌렀다는 신호만 보낸다.

signal start_requested            # 병과를 골랐다 → AI대전 시작
signal resume_requested           # 일시정지 → 계속하기
signal menu_requested(page: String)  # 메뉴로 (page: main / class)
signal again_requested            # 결과 화면 → 한 판 더
signal next_class_picked(cls: String)  # 일시정지 화면에서 다음 부활 병과
signal friend_create(nick: String)               # 친구대전: 방 만들기
signal friend_join(nick: String, code: String)   # 친구대전: 코드(또는 방장 IP)로 참가
signal lobby_leave                                # 대기실: 방 나가기
signal lobby_start                                # 대기실: 게임 시작 (방장) / 진행 중인 게임 참가
signal lobby_class(cls: String)                   # 대기실: 내 병과

const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const PAGES := ["main", "diff", "class", "settings", "exit", "friend", "lobby"]

var cur_page := "main"
var screens := {}     # menu / pause / end
var pages := {}       # 메뉴 안의 페이지
var _class_host: GridContainer
var _class_sub: Label
var _diff_host: HBoxContainer
var _pause_cards: GridContainer
var _end_title: Label
var _end_sub: RichTextLabel
var _end_table: PanelContainer
var _pause_main: VBoxContainer  # 일시정지 첫 화면
var _pause_set: VBoxContainer   # 일시정지 → 설정
var _friend_status: Label
var _nick: LineEdit
var _code_in: LineEdit
var _lobby_code: Label
var _lobby_sub: Label
var _lobby_list: VBoxContainer
var _lobby_cards: GridContainer
var _lobby_btn: Button
var _lobby_sig := ""   # 대기실 목록이 바뀌었을 때만 다시 그림
var _toast: PanelContainer
var _toast_l: Label
var _toast_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	screens.menu = _screen()
	screens.pause = _screen()
	screens.end = _screen()
	_build_main()
	_build_diff()
	_build_class()
	_build_settings()
	_build_exit()
	_build_friend()
	_build_lobby()
	_build_pause()
	_build_end()
	_build_toast()
	show_screen("menu")
	show_page("main")


# ── 뼈대 ─────────────────────────────────────────────────────
## 화면 하나: 남색 둥근 그늘 + 가운데 정렬 + 넘치면 스크롤 (HTML .screen)
func _screen() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, UiKit.ink(0.35))
	g.set_color(1, UiKit.ink(0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.32, 0.35)
	gt.width = 256
	gt.height = 256
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 게임 화면으로 클릭이 새지 않게
	root.add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 16)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 28)
	sc.add_child(m)
	var cc := CenterContainer.new()
	m.add_child(cc)
	root.set_meta("center", cc)
	return root


## 페이지 하나 (HTML .sheet.page). narrow면 폭 640
func _sheet(screen: Control, narrow := false, gap := 24) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 640 if narrow else 960
	vb.add_theme_constant_override("separation", gap)
	(screen.get_meta("center") as Control).add_child(vb)
	return vb


func _head2(text: String, parent: Node) -> Label:
	var l := UiKit.label(text, 58, UiKit.c("parch"), parent)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.shadow(l, UiKit.c("ink"), 4)
	return l


func _sub2(text: String, parent: Node) -> Label:
	var l := UiKit.label(text, 15, UiKit.c("parch"), parent)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 위쪽: [← 뒤로]  제목  [   ] + 아래 설명 (HTML .pagehead)
func _pagehead(parent: Node, title: String, back_to: String, back_text := "← 뒤로") -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	parent.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1
	hb.add_child(left)
	var b := UiKit.back(back_text)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: show_page(back_to))
	left.add_child(b)
	_head2(title, hb)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	return vb


func _actions(parent: Node) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 22)
	parent.add_child(hb)
	return hb


# ── 메인 ─────────────────────────────────────────────────────
func _build_main() -> void:
	var pg := _sheet(screens.menu)
	pages.main = pg
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 6)
	pg.add_child(brand)
	var eb := UiKit.label("중세 개인전 · 프로토타입 v0.2", 13, UiKit.c("gold"), brand)
	eb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h1 := UiKit.rich(86, UiKit.c("parch"), brand)
	h1.text = "[center]중세%s[/center]" % UiKit.gold("난장판")
	h1.add_theme_color_override("font_shadow_color", UiKit.c("ink"))
	h1.add_theme_constant_override("shadow_offset_x", 0)
	h1.add_theme_constant_override("shadow_offset_y", 5)
	var lede := UiKit.label("활, 석궁, 돌멩이, 성수, 그리고 닭. 넘어지고 미끄러지며 4분 동안 가장 많이 쓰러뜨리면 이깁니다.", 15, UiKit.c("parch"))
	lede.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lede.custom_minimum_size.x = 560
	lede.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiKit.shadow(lede, Color(0, 0, 0, 0.6), 1)
	brand.add_child(lede)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	nav.custom_minimum_size.x = 420
	nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pg.add_child(nav)
	var ranked := UiKit.navbtn("일반대전", "준비 중", "soon")
	ranked.pressed.connect(func() -> void: toast("추후 업데이트 될 내용입니다."))
	nav.add_child(ranked)
	var ai := UiKit.navbtn("AI대전", "봇 %d명과 개인전" % GameData.BOT_COUNT, "hero")
	ai.pressed.connect(open_diff_page)
	nav.add_child(ai)
	var fr := UiKit.navbtn("친구대전", "방 코드로 같이")
	fr.pressed.connect(func() -> void:
		if OS.has_feature("web"):  # 같은 와이파이 직접 연결(ENet·UDP)은 브라우저에서 못 함
			toast("친구대전은 PC 버전에서만 할 수 있어요.")
			return
		_friend_status.text = ""
		_nick.text = GameData.nick
		show_page("friend"))
	nav.add_child(fr)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	nav.add_child(row)
	var st := UiKit.navbtn("설정", "", "sub")
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.pressed.connect(func() -> void:
		show_page("settings"))
	row.add_child(st)
	var ex := UiKit.navbtn("나가기", "", "sub")
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ex.pressed.connect(_exit_game)
	row.add_child(ex)


## 나가기: PC에선 게임을 끄고, 웹에선 끌 수 없으니 HTML처럼 안내 페이지를 띄운다
func _exit_game() -> void:
	if OS.has_feature("web"):
		show_page("exit")
	else:
		get_tree().quit()


# ── AI대전 난이도 ────────────────────────────────────────────
func _build_diff() -> void:
	var pg := _sheet(screens.menu)
	pages.diff = pg
	_pagehead(pg, "AI대전 난이도", "main")
	_diff_host = HBoxContainer.new()
	_diff_host.add_theme_constant_override("separation", 14)
	pg.add_child(_diff_host)


func open_diff_page() -> void:
	for ch in _diff_host.get_children():
		ch.queue_free()
	for k: String in GameData.DIFF:
		var card := UiKit.diff_card(k)
		card.on_box = card.h_box  # 지금 난이도는 테두리가 난이도 색
		card.set_on(k == GameData.difficulty)
		card.pressed.connect(func() -> void:
			GameData.difficulty = k
			GameData.save_settings()
			open_class_page())
		_diff_host.add_child(card)
	show_page("diff")


# ── 병과 선택 ────────────────────────────────────────────────
func _build_class() -> void:
	var pg := _sheet(screens.menu)
	pages["class"] = pg
	var head := _pagehead(pg, "병과 선택", "diff")
	_class_sub = _sub2("고르면 바로 전투에 들어갑니다", head)
	pg.custom_minimum_size.x = 1180  # 병과 5개가 한 줄에 들어가게
	_class_host = GridContainer.new()
	_class_host.columns = GameData.CLASS_ORDER.size()
	_class_host.add_theme_constant_override("h_separation", 14)
	_class_host.add_theme_constant_override("v_separation", 14)
	pg.add_child(_class_host)
	var note := UiKit.rich(13, UiKit.c("mute"), pg)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.fit_content = true
	note.text = "[center]빠르게 달리다 %s하면 0.6초 동안 넘어져 미끄러집니다. 활을 꽉 당긴 채 1초 넘게 버티면 팔이 떨리고 3초면 놓쳐요. %s에 닿으면 주워서 던질 수 있고, 헤드샷을 맞으면 %s가 날아가 머리 피해가 2배가 됩니다. 가끔 나타나는 %s에 올라타면 7초 동안 빠르게 돌격하며 창에 찔린 적을 멀리 날려 보내요.[/center]" % [
		UiKit.gold("급회전"), UiKit.gold("닭"), UiKit.gold("투구"), UiKit.gold("기사의 말")]


func _fill_cards(host: GridContainer, current: String, mini: bool, on_pick: Callable) -> void:
	for ch in host.get_children():
		host.remove_child(ch)
		ch.queue_free()
	var cards: Array[UiKit.Tap] = []
	for i in GameData.CLASS_ORDER.size():
		var k: String = GameData.CLASS_ORDER[i]
		var card := UiKit.class_card(k, i, mini)
		card.set_on(k == current)
		cards.append(card)
		card.pressed.connect(func() -> void:
			for o in cards:
				o.set_on(o == card)
			on_pick.call(k))
		host.add_child(card)


func open_class_page() -> void:
	_fill_cards(_class_host, GameData.chosen_cls, false, select_class)
	_class_sub.text = "AI대전 · %s · 고르면 바로 전투에 들어갑니다" % GameData.DIFF[GameData.difficulty].name
	show_page("class")


func select_class(k: String) -> void:
	GameData.chosen_cls = k
	GameData.save_settings()
	start_requested.emit()


# ── 설정 ─────────────────────────────────────────────────────
## 본문은 scenes/ui/settings_panel.tscn (일시정지 화면도 같은 걸 씀)
func _build_settings() -> void:
	var pg := _sheet(screens.menu, true)
	pages.settings = pg
	_pagehead(pg, "설정", "main")
	pg.add_child(SETTINGS_SCENE.instantiate())


# ── 나가기 (웹) ──────────────────────────────────────────────
func _build_exit() -> void:
	var pg := _sheet(screens.menu, true)
	pages.exit = pg
	_head2("게임을 종료했어요", pg)
	_sub2("브라우저 탭을 닫으면 완전히 꺼져요.", pg)
	var b := UiKit.primary("메인 화면으로")
	b.pressed.connect(func() -> void: show_page("main"))
	_actions(pg).add_child(b)


# ── 친구대전 (같은 와이파이) — HTML pgFriend / pgLobby ─────────
func _build_friend() -> void:
	var pg := _sheet(screens.menu, true)
	pages.friend = pg
	var head := _pagehead(pg, "친구대전", "main")
	_sub2("방을 만들고 코드를 친구에게 알려주세요. 친구가 코드를 넣으면 들어와요.", head)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = 420
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pg.add_child(col)
	UiKit.label("닉네임", 14, UiKit.c("mute"), col)
	var nick := _field("예: 허풍쟁이 기사", 10)
	col.add_child(nick)
	_nick = nick
	var create := UiKit.primary("방 만들기")
	col.add_child(create)
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 10)
	col.add_child(jr)
	var code := _field("코드 4자리", 15)  # 방장 IP를 직접 넣을 수도 있어서 길게 받음
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	jr.add_child(code)
	_code_in = code
	var join := UiKit.ghost("참가")
	jr.add_child(join)
	_friend_status = UiKit.label("", 14, UiKit.c("parch"), pg)
	_friend_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_friend_status.custom_minimum_size.y = 22
	create.pressed.connect(func() -> void: friend_create.emit(nick.text))
	var do_join := func() -> void: friend_join.emit(nick.text, code.text.strip_edges().to_upper())
	join.pressed.connect(do_join)
	code.text_submitted.connect(func(_t: String) -> void: do_join.call())
	var hint := UiKit.label("같은 와이파이(공유기)에 연결된 친구끼리 들어올 수 있어요. 코드로 못 찾으면 대기실에 보이는 방장 IP를 코드 칸에 넣어 보세요. 친구대전에는 봇과 닭이 나오지 않아요.", 13, UiKit.c("mute"), pg)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func friend_status(text: String) -> void:
	_friend_status.text = text


## 대기실: 방 코드 · 사람 목록 · 내 병과 · 게임 시작
func _build_lobby() -> void:
	var pg := _sheet(screens.menu)
	pages.lobby = pg
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pg.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	var back := UiKit.back("← 방 나가기")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: lobby_leave.emit())
	left.add_child(back)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	hb.add_child(title)
	_head2("방 코드", title)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(UiKit.c("gold"), Color.TRANSPARENT, 0, 8, Vector4(14, 2, 14, 2)))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(chip)
	_lobby_code = UiKit.label("", 52, UiKit.c("ink"), chip)
	_lobby_code.add_theme_constant_override("outline_size", 0)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	_lobby_sub = _sub2("친구에게 코드를 알려주세요", vb)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	pg.add_child(body)
	var plist := PanelContainer.new()
	plist.add_theme_stylebox_override("panel", UiKit.box(UiKit.ink(0.85), UiKit.c("line"), 1, 10, Vector4(12, 12, 12, 12)))
	plist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plist.size_flags_stretch_ratio = 1
	plist.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(plist)
	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override("separation", 8)
	plist.add_child(_lobby_list)
	_lobby_cards = GridContainer.new()
	_lobby_cards.columns = 2
	_lobby_cards.add_theme_constant_override("h_separation", 14)
	_lobby_cards.add_theme_constant_override("v_separation", 14)
	_lobby_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_cards.size_flags_stretch_ratio = 2
	body.add_child(_lobby_cards)
	var act := _actions(pg)
	_lobby_btn = UiKit.primary("게임 시작")
	_lobby_btn.pressed.connect(func() -> void: lobby_start.emit())
	act.add_child(_lobby_btn)


func open_lobby(cls: String) -> void:
	_fill_cards(_lobby_cards, cls, true, func(k: String) -> void:
		GameData.chosen_cls = k
		GameData.save_settings()
		lobby_class.emit(k))
	_lobby_sig = ""
	show_page("lobby")


## HTML renderLobby: list = [{name, cls, host, st}], btn = 버튼 글자 (없으면 숨김)
func render_lobby(code: String, list: Array, sub: String, btn: String) -> void:
	_lobby_code.text = code if code != "" else "IP"
	_lobby_sub.text = sub
	_lobby_btn.visible = btn != ""
	_lobby_btn.text = btn
	var sig := str(list)
	if sig == _lobby_sig:
		return
	_lobby_sig = sig
	for ch in _lobby_list.get_children():
		ch.queue_free()
	for p: Dictionary in list:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.04), Color.TRANSPARENT, 0, 6, Vector4(8, 6, 8, 6)))
		_lobby_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiKit.box(GameData.col(GameData.CLASS_CHIP[p.cls]), Color.TRANSPARENT, 0, 3, Vector4(6, 1, 6, 1)))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiKit.label(GameData.CLASSES[p.cls].name, 11, UiKit.c("ink"), chip)
		hb.add_child(chip)
		var nm := UiKit.label(str(p.name), 15, UiKit.c("parch"), hb)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if p.st == "play":
			UiKit.label("게임 중", 12, UiKit.c("mute"), hb)
		if p.host:
			var em := PanelContainer.new()
			em.add_theme_stylebox_override("panel", UiKit.box(UiKit.c("gold"), Color.TRANSPARENT, 0, 4, Vector4(6, 1, 6, 1)))
			em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			UiKit.label("방장", 12, UiKit.c("ink"), em)
			hb.add_child(em)


func _field(ph: String, max_len: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = max_len
	le.add_theme_font_size_override("font_size", 18)
	le.add_theme_color_override("font_color", UiKit.c("parch"))
	le.add_theme_color_override("font_placeholder_color", UiKit.c("mute", 0.6))
	var pad := Vector4(14, 10, 14, 10)
	le.add_theme_stylebox_override("normal", UiKit.box(UiKit.ink(0.9), UiKit.c("line"), 2, 8, pad))
	le.add_theme_stylebox_override("focus", UiKit.box(Color.TRANSPARENT, UiKit.c("gold"), 2, 8, pad))
	return le


# ── 일시정지 ─────────────────────────────────────────────────
func _build_pause() -> void:
	var pg := _sheet(screens.pause, false, 22)
	_pause_main = pg
	_head2("일시정지", pg)
	var sub := UiKit.rich(15, UiKit.c("parch"), pg)
	sub.text = "[center]병과를 바꾸면 %s 적용됩니다.[/center]" % UiKit.gold("다음 부활부터")
	_pause_cards = GridContainer.new()
	_pause_cards.columns = GameData.CLASS_ORDER.size()
	_pause_cards.add_theme_constant_override("h_separation", 14)
	pg.add_child(_pause_cards)
	var act := _actions(pg)
	var resume := UiKit.primary("계속하기")
	resume.pressed.connect(func() -> void: resume_requested.emit())
	act.add_child(resume)
	var st := UiKit.ghost("설정")
	st.pressed.connect(func() -> void: _pause_page(true))
	act.add_child(st)
	var quit := UiKit.ghost("메뉴로 나가기")
	quit.pressed.connect(func() -> void: menu_requested.emit("main"))
	act.add_child(quit)
	# 일시정지 → 설정 (메인 메뉴 설정과 같은 씬)
	_pause_set = _sheet(screens.pause, true)
	var hb := HBoxContainer.new()
	_pause_set.add_child(hb)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	var b := UiKit.back()
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: _pause_page(false))
	left.add_child(b)
	_head2("설정", hb)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	_pause_set.add_child(SETTINGS_SCENE.instantiate())
	_pause_set.visible = false


## 일시정지 화면: 첫 화면 ↔ 설정
func _pause_page(settings: bool) -> void:
	_pause_main.visible = not settings
	_pause_set.visible = settings


func open_pause(next_cls: String) -> void:
	_fill_cards(_pause_cards, next_cls, true, func(k: String) -> void:
		GameData.chosen_cls = k
		GameData.save_settings()
		next_class_picked.emit(k))
	_pause_page(false)
	show_screen("pause")


# ── 결과 ─────────────────────────────────────────────────────
func _build_end() -> void:
	var pg := _sheet(screens.end, false, 22)
	_end_title = _head2("경기 종료", pg)
	_end_sub = UiKit.rich(15, UiKit.c("parch"), pg)
	_end_table = PanelContainer.new()
	_end_table.add_theme_stylebox_override("panel", UiKit.box(UiKit.ink(0.88), UiKit.c("line"), 1, 8, Vector4(16, 14, 16, 14)))
	pg.add_child(_end_table)
	var act := _actions(pg)
	var again := UiKit.primary("한 판 더")
	again.pressed.connect(func() -> void: again_requested.emit())
	act.add_child(again)
	var pick := UiKit.ghost("병과 다시 고르기")
	pick.pressed.connect(func() -> void: menu_requested.emit("class"))
	act.add_child(pick)
	var mm := UiKit.ghost("메인 메뉴")
	mm.pressed.connect(func() -> void: menu_requested.emit("main"))
	act.add_child(mm)


## HTML endMatch: 1등이 나면 '승리!', 아니면 '경기 종료' + 우승자·내 순위
func open_end(rows: Array, me: PlayerController) -> void:
	var win: PlayerController = rows[0]
	var rank := rows.find(me) + 1
	_end_title.text = "승리!" if win == me else "경기 종료"
	if win == me:
		_end_sub.text = "[center]%s로 아레나를 제패했습니다.[/center]" % UiKit.gold("%d킬" % me.kills)
	else:
		_end_sub.text = "[center]우승 %s %d킬 · 내 순위 %s (%d킬 %d죽음)[/center]" % [
			UiKit.gold(UiKit.esc(win.ent_name)), win.kills, UiKit.gold("%d위" % rank), me.kills, me.deaths]
	for ch in _end_table.get_children():
		ch.queue_free()
	_end_table.add_child(UiKit.score_table(rows, me))
	show_screen("end")


# ── 화면 전환 ────────────────────────────────────────────────
func show_screen(id: String) -> void:
	for k: String in screens:
		(screens[k] as Control).visible = k == id


func show_page(id: String) -> void:
	for k: String in pages:
		(pages[k] as Control).visible = k == id
	cur_page = id


func _unhandled_input(event: InputEvent) -> void:
	if (screens.pause as Control).visible and _pause_set.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # 일시정지 설정에서 Esc = 뒤로
		_pause_page(false)
		return
	if not (screens.menu as Control).visible:
		return
	if cur_page == "class":  # 병과 고르는 화면에선 숫자키(1~5)로 바로 고름
		for n in GameData.CLASS_ORDER.size():
			if event.is_action_pressed("class_%d" % (n + 1)):
				get_viewport().set_input_as_handled()
				select_class(GameData.CLASS_ORDER[n])
				return
	if event.is_action_pressed("ui_cancel"):  # Esc = 뒤로
		var back := {"diff": "main", "class": "diff", "settings": "main", "friend": "main"}
		if back.has(cur_page):
			get_viewport().set_input_as_handled()
			show_page(back[cur_page])


# ── 아래쪽 알림 상자 (HTML #toast) ───────────────────────────
func _build_toast() -> void:
	_toast = PanelContainer.new()
	var sb := UiKit.box(UiKit.c("ink"), UiKit.c("gold"), 2, 10, Vector4(22, 12, 22, 12))
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_l = UiKit.label("", 19, UiKit.c("parch"), _toast)
	_toast.modulate.a = 0.0
	add_child(_toast)


func toast(text: String) -> void:
	_toast_l.text = text
	_toast.reset_size()
	_toast_t = GameData.TOAST_T


func _process(dt: float) -> void:
	_toast_t = maxf(0.0, _toast_t - dt)
	# 0.2초 동안 아래에서 16px 올라오며 나타나고, 끝나면 같은 식으로 사라진다
	_toast.modulate.a = move_toward(_toast.modulate.a, 1.0 if _toast_t > 0 else 0.0, dt / 0.2)
	_toast.visible = _toast.modulate.a > 0.001
	var area := _toast.get_parent_area_size()
	_toast.position = Vector2((area.x - _toast.size.x) / 2, area.y - 48 - _toast.size.y + 16 * (1.0 - _toast.modulate.a))
