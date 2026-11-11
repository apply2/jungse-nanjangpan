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
signal lobby_mode(mode: String)                   # 대기실: 모드 (방장만 — 개인전 / 쟁탈전)
signal lobby_team                                 # 대기실: 팀 바꾸기 (쟁탈전)

const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const MENU_CROWD := preload("res://scripts/ui/menu_crowd.gd")
const MODEL_STAGE := preload("res://scripts/ui/model_stage.gd")
const RESULT_STAGE := preload("res://scripts/ui/result_stage.gd")
const FULL_PAGES := ["main", "class"]  # 화면 전체를 자기 배경으로 쓰는 페이지 (메뉴 그늘 끔)
const PAGES := ["main", "diff", "mode", "class", "settings", "exit", "friend", "lobby"]

var cur_page := "main"
var screens := {}     # menu / pause / end
var pages := {}       # 메뉴 안의 페이지
var _class_host: Control       # 병과 카드 5장
var _class_cards := {}          # 병과 → 카드 Tap
var _card_imgs := {}            # 병과 → 카드 그림 TextureRect
var _class_pick := ""           # 병과 화면에서 지금 고른 것 (출전 버튼이 씀)
var _class_stage: SubViewport   # 큰 액자 3D (model_stage.gd)
var _card_stage: SubViewport    # 카드 그림 찍는 곳
var _class_stamp: Control       # 합격 도장
var _stamp_tw: Tween
var _class_go: Button           # 이놈으로 출전
var _ci := {}                   # 정보 양피지 글자·막대
var _portraits_made := false
var _diff_pick := ""
var _mode_pick := ""
var _class_sub: Label
var _diff_host: HBoxContainer
var _mode_host: HBoxContainer
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
var _lobby_modes := {}  # 모드 키 → 버튼
var _lobby_mode_note: Label
var _lobby_team_btn: Button
var _lobby_sig := ""   # 대기실 목록이 바뀌었을 때만 다시 그림
var _crowd: SubViewport      # 메인 메뉴 오른쪽 병과 무리 (menu_crowd.gd)
var _tip_label: Label         # 오늘의 팁 (개구)
var _main_foot: Label         # 왼쪽 아래 버전 글씨
var _main_signs := {}         # 이정표 (ranked·ai·friend·settings·exit) — 테스트·사진용
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
	_build_mode()
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
	root.set_meta("bg", bg)
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


## 페이지 제목: 밧줄에 매달린 나무 간판 (크림 글자 + 잉크 외곽선, 판만 살짝 기울임)
func _head2(text: String, parent: Node) -> Label:
	var H: Dictionary = GameData.PAGE_UI.head
	var bd := UiKit.Board.new("wood", H.pad)
	bd.ropes = true
	bd.tilt = float(H.tilt)
	bd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(bd)
	var l := UiKit.wood_text(UiKit.label(text, int(H.font), UiKit.c("cream"), bd), int(H.font))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.trim_font(l, int(H.font), 0.12)
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
	var M: Dictionary = GameData.MAIN_MENU
	var pg := Control.new()  # 화면 전체 — 시안 Main.html 좌표 그대로 (오른쪽 것은 오른쪽, 아래 것은 아래에 붙임)
	pg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pg.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 게임 화면으로 클릭이 새지 않게
	(screens.menu as Control).add_child(pg)
	pages.main = pg
	# 왼쪽만 어둡게 (뒤는 맵을 도는 구경 카메라 그대로)
	var g := Gradient.new()
	g.set_color(0, UiKit.ink(float(M.shade_a)))
	g.set_color(1, UiKit.ink(0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.offset_right = float(M.shade_w)
	pg.add_child(shade)
	_build_crowd(pg)
	# 세로 나무 기둥 (이정표가 박힌 곳) — 화면 아래까지
	var P: Dictionary = M.pole
	var pole := UiKit.Board.new("wood", Vector4.ZERO)
	pole.anchor_bottom = 1.0
	pole.offset_left = float(P.x)
	pole.offset_right = float(P.x) + float(P.w)
	pole.offset_top = float(P.y)
	pole.offset_bottom = 30.0
	pg.add_child(pole)
	_build_title(pg)
	_build_nav(pg)
	_build_tip(pg)
	# 왼쪽 아래 작은 글씨: 버전 (+ PC면 친구대전 안내)
	var F: Dictionary = M.foot
	var foot := UiKit.label(GameData.VERSION + ("" if OS.has_feature("web") else " · 같은 와이파이 친구대전 지원"), int(F.font), UiKit.c("cream"), pg)
	foot.add_theme_color_override("font_outline_color", UiKit.c("ink"))
	foot.add_theme_constant_override("outline_size", UiKit.outline_for(int(F.font)))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = float(F.x)
	foot.offset_bottom = -float(F.bottom)
	foot.offset_top = -float(F.bottom) - float(F.font) - 6.0
	_main_foot = foot


## 판을 시안 좌표에 놓고 가운데를 축으로 기울인다 (Container 밖이라 rotation이 그대로 남음)
func _place(c: Control, pos: Vector2, tilt: float) -> void:
	c.position = pos
	c.rotation = deg_to_rad(tilt)
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2.0)


## 밧줄에 매달린 나무 간판 "중세난장판" + 양피지 쪽지 "일단 던져." (개구)
func _build_title(pg: Control) -> void:
	var T: Dictionary = GameData.MAIN_MENU.title
	var board := UiKit.Board.new("wood", Vector4(10, 4, 10, 10))
	board.ropes = true
	board.rope_len = float(T.rope)
	board.nails = 4
	board.radius = 12.0
	board.custom_minimum_size = T.size
	var h1 := UiKit.wood_text(UiKit.label("중세난장판", int(T.font), UiKit.c("cream"), board), int(T.font))
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h1.add_theme_constant_override("shadow_offset_y", 5)
	pg.add_child(board)
	_place(board, T.pos, float(T.tilt))
	var Mo: Dictionary = GameData.MAIN_MENU.motto
	var note := UiKit.Board.new("parch", Vector4(21, 5, 21, 7))
	UiKit.scribble(str(Mo.text), int(Mo.font), UiKit.c("ink"), note)
	pg.add_child(note)
	_place(note, Mo.pos, float(Mo.tilt))


## 이정표 5개 (길이 들쑥날쑥, 오른쪽으로 뾰족). 마우스 올리면 오른쪽으로 밀리며 -1°
func _build_nav(pg: Control) -> void:
	var N: Dictionary = GameData.MAIN_MENU.nav
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", int(N.gap))
	nav.position = Vector2(N.x, N.y)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(nav)
	var ranked := _nav_sign(nav, "ranked", "wood", "sword", "일반대전", "")
	ranked.pressed.connect(func() -> void: toast("추후 업데이트 될 내용입니다."))
	var ai := _nav_sign(nav, "ai", "wood", "robot", "AI대전", "멍청한 봇이랑 한판")
	ai.pressed.connect(open_diff_page)
	var fr := _nav_sign(nav, "friend", "wood", "people", "친구대전", "친구를 넘어뜨리자")
	fr.pressed.connect(func() -> void:
		if OS.has_feature("web"):  # 같은 와이파이 직접 연결(ENet·UDP)은 브라우저에서 못 함
			toast("친구대전은 PC 버전에서만 할 수 있어요.")
			return
		_friend_status.text = ""
		_nick.text = GameData.nick
		show_page("friend"))
	var st := _nav_sign(nav, "settings", "wood", "gear", "설정", "")
	st.pressed.connect(func() -> void: show_page("settings"))
	var ex := _nav_sign(nav, "exit", "parch", "exit", "도망가기", "")
	ex.pressed.connect(_exit_game)


## 이정표 하나: [아이콘] 큰 글자 (+ 개구 작은 글씨). 나무 = 흰 글자+외곽선, 금칠·양피지 = 잉크 글자
func _nav_sign(nav: VBoxContainer, key: String, kind: String, icon: String, title: String, sub: String) -> UiKit.Tap:
	var S: Dictionary = GameData.MAIN_MENU.signs[key]
	var wood := kind == "wood"
	var fg := UiKit.c("cream") if wood else UiKit.c("ink")
	var bd := UiKit.Board.new(kind, Vector4(20, 0, 8, 0))
	bd.arrow = true
	bd.custom_minimum_size = Vector2(S.w, S.h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bd.add_child(row)
	row.add_child(UiKit.nav_icon(icon, fg, float(S.icon)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(GameData.MAIN_MENU.nav.stack))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var big := UiKit.label(title, int(S.font), fg, col)
	if wood:
		UiKit.wood_text(big, int(S.font))
	if sub != "":
		var sm := UiKit.scribble(sub, int(S.sub), UiKit.c("cream_dim") if wood else UiKit.c("brown"), col)
		if wood:
			UiKit.shadow(sm, UiKit.c("ink", 0.8), 1)
	if key == "ranked":
		_stamp(row)
	var t := UiKit.sign_tap(bd)
	t.face.hover_paint = UiKit.c("gilt")  # 마우스 올린 이정표만 노랗게 (사용자 요청 — 예전엔 AI대전만 늘 금칠)
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if S.has("dx"):  # AI대전은 조금 앞으로 나옴
		var mc := MarginContainer.new()
		mc.add_theme_constant_override("margin_left", int(S.dx))
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_child(t)
		nav.add_child(mc)
	else:
		nav.add_child(t)
	t.seal()
	_main_signs[key] = t
	return t


## '준비 중' 빨간 동그라미 도장 (개구, -12°)
func _stamp(row: HBoxContainer) -> void:
	var S: Dictionary = GameData.MAIN_MENU.stamp
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var st := Stamp.new()
	st.d = float(S.d)
	st.col = GameData.col(S.col)
	st.ring = GameData.col(S.ring)
	st.custom_minimum_size = Vector2(S.d, S.d)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(st)
	var l := UiKit.scribble("준비\n중", int(S.font), Color.WHITE, st)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", -6)
	l.size = Vector2(S.d, S.d)
	l.pivot_offset = l.size / 2.0
	l.rotation = deg_to_rad(float(S.tilt))  # 도장 안 글자만 돌림 (Stamp는 Container가 아니라 그대로 남음)


class Stamp extends Control:
	var d := 60.0
	var col := Color.RED
	var ring := Color.DARK_RED

	func _draw() -> void:
		var c := size / 2.0
		var r := d / 2.0
		draw_circle(c + Vector2(0, 2), r, UiKit.c("ink"), true, -1, true)
		draw_circle(c, r, col, true, -1, true)
		draw_arc(c, r - 1.4, 0, TAU, 40, ring, 2.7, true)


## 오른쪽 위 "오늘의 팁" 양피지 쪽지 (못 하나, +2.5°). 팁은 메인 화면을 열 때마다 바뀐다
func _build_tip(pg: Control) -> void:
	var T: Dictionary = GameData.MAIN_MENU.tip
	var note := UiKit.Board.new("parch", Vector4(20, 22, 20, 15))
	note.nails = 1
	note.custom_minimum_size.x = float(T.w)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	note.add_child(vb)
	UiKit.label("오늘의 팁", int(T.head), UiKit.c("ink"), vb)
	_tip_label = UiKit.scribble("", int(T.font), UiKit.c("ink"), vb)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_constant_override("line_spacing", int(T.line))
	note.anchor_left = 1.0
	note.anchor_right = 1.0
	note.offset_left = -float(T.right) - float(T.w)
	note.offset_right = -float(T.right)
	note.offset_top = float(T.top)
	note.rotation = deg_to_rad(float(T.tilt))
	note.resized.connect(func() -> void: note.pivot_offset = note.size / 2.0)
	pg.add_child(note)
	_roll_tip()


func _roll_tip() -> void:
	if _tip_label:
		var tips: Array = GameData.MAIN_MENU.tips
		_tip_label.text = tips[randi() % tips.size()]


## 오른쪽 병과 무리 (SubViewport 하나에 DerpModel 4개, 투명 배경) — 오른쪽 아래 모서리에 붙임
func _build_crowd(pg: Control) -> void:
	var r: Rect2 = GameData.MAIN_MENU.crowd.rect
	_crowd = MENU_CROWD.new()
	pg.add_child(_crowd)
	var tr := TextureRect.new()
	tr.texture = _crowd.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.anchor_top = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_left = r.position.x - 1280.0
	tr.offset_top = r.position.y - 720.0
	pg.add_child(tr)


## 나가기: PC에선 게임을 끄고, 웹에선 끌 수 없으니 HTML처럼 안내 페이지를 띄운다
func _exit_game() -> void:
	if OS.has_feature("web"):
		show_page("exit")
	else:
		get_tree().quit()


# ── AI대전 난이도 ────────────────────────────────────────────
## 난이도·모드 카드: 병과 카드와 같은 양피지 카드 (못 1개, 서로 다른 기울기, 위쪽 색 띠).
## 카드를 누르면 고르고(형광펜 테), 금칠 '다음'으로 넘어간다
func _build_diff() -> void:
	var pg := _sheet(screens.menu)
	pages.diff = pg
	_pagehead(pg, "AI대전 난이도", "main")
	_diff_host = HBoxContainer.new()
	_diff_host.add_theme_constant_override("separation", 22)
	_diff_host.alignment = BoxContainer.ALIGNMENT_CENTER
	pg.add_child(_diff_host)
	var act := _actions(pg)
	var go := UiKit.primary("다음")
	go.pressed.connect(func() -> void:
		GameData.difficulty = _diff_pick
		GameData.save_settings()
		open_mode_page())
	act.add_child(go)


func open_diff_page() -> void:
	_diff_pick = GameData.difficulty
	_fill_pick(_diff_host, GameData.DIFF.keys(), _diff_pick, func(k: String) -> Dictionary:
		var D: Dictionary = GameData.DIFF[k]
		return {"top": D.skulls, "top_col": GameData.col(D.color), "title": D.name, "desc": D.desc, "bands": [GameData.col(D.color)]},
		func(k: String) -> void: _diff_pick = k)
	show_page("diff")


## 모드 고르기 (난이도 다음): 개인전 / 쟁탈전 5:5 (사용자 요청). 쟁탈전 카드 띠는 블루|레드 방패 색
func _build_mode() -> void:
	var pg := _sheet(screens.menu)
	pages.mode = pg
	_pagehead(pg, "게임 모드", "diff")
	_mode_host = HBoxContainer.new()
	_mode_host.add_theme_constant_override("separation", 22)
	_mode_host.alignment = BoxContainer.ALIGNMENT_CENTER
	pg.add_child(_mode_host)
	var act := _actions(pg)
	var go := UiKit.primary("다음")
	go.pressed.connect(func() -> void:
		GameData.mode = _mode_pick
		GameData.save_settings()
		open_class_page())
	act.add_child(go)


func open_mode_page() -> void:
	_mode_pick = GameData.mode
	var T: Dictionary = GameData.MODES.control.teams
	var info := {
		"ffa": {"title": "개인전", "desc": "봇 %d명과 모두가 적. 4분 동안 %d킬을 먼저 따내면 승리." % [GameData.BOT_COUNT, GameData.KILL_LIMIT],
			"bands": [UiKit.c("marker")]},
		"control": {"title": "쟁탈전 5:5", "desc": "블루팀(나 + 아군 봇 4) 대 레드팀(봇 5). 가운데 우물 거점을 지켜 100%를 먼저 채우면 라운드 승리, 3판 2선승.",
			"bands": [Color(str(T.blue.ui)), Color(str(T.red.ui))]},
	}
	_fill_pick(_mode_host, ["ffa", "control"], _mode_pick, func(k: String) -> Dictionary: return info[k],
		func(k: String) -> void: _mode_pick = k)
	show_page("mode")


## 양피지 고르기 카드 줄 (난이도·모드). desc_of(k) → {top?, top_col?, title, desc, bands}
func _fill_pick(host: HBoxContainer, keys: Array, current: String, desc_of: Callable, on_pick: Callable) -> void:
	for ch in host.get_children():
		host.remove_child(ch)
		ch.queue_free()
	var P: Dictionary = GameData.PICK_CARDS
	var cards := {}
	for i in keys.size():
		var k: String = keys[i]
		var d: Dictionary = desc_of.call(k)
		var bd := UiKit.Board.new("parch", P.pad)
		bd.nails = 1
		bd.bands = d.bands
		bd.custom_minimum_size.x = float(P.w)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		bd.add_child(vb)
		if d.has("top"):
			UiKit.label(str(d.top), 15, d.top_col, vb)
		UiKit.label(str(d.title), 34, UiKit.c("ink"), vb)
		var p := UiKit.label(str(d.desc), 16, UiKit.c("brown"), vb)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.custom_minimum_size.x = float(P.w) - P.pad.x - P.pad.z  # 처음부터 카드 폭으로 줄바꿈 (안 그러면 잠깐 길쭉하게 재짐)
		p.add_theme_constant_override("line_spacing", -6)
		var t := UiKit.board_tap(bd, P.lift)
		t.seal()
		cards[k] = t
		t.pressed.connect(func() -> void:
			for o: String in cards:
				(cards[o] as UiKit.Tap).face.board.ring = UiKit.c("marker") if o == k else Color.TRANSPARENT
			on_pick.call(k))
		bd.ring = UiKit.c("marker") if k == current else Color.TRANSPARENT
		var tilts: Array = P.tilts
		host.add_child(UiKit.tilted(t, float(tilts[i % tilts.size()])))


# ── 병과 선택 (시안 ClassSelect) ─────────────────────────────
## 판자벽 화면: 위 "누가 나갈래?", 왼쪽 큰 액자(고른 병과 3D + 합격 도장), 오른쪽 정보 양피지,
## 아래 카드 5장, 오른쪽 아래 뒤로 + 금칠 "이놈으로 출전". 카드는 고르기만 하고 출전 버튼(또는 숫자키)으로 시작
func _build_class() -> void:
	var CP: Dictionary = GameData.CLASS_PAGE
	var pg := Control.new()
	pg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pg.mouse_filter = Control.MOUSE_FILTER_STOP
	(screens.menu as Control).add_child(pg)
	pages["class"] = pg
	var wall := UiKit.Wall.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	pg.add_child(wall)
	_class_stage = MODEL_STAGE.new(CP.big)
	pg.add_child(_class_stage)
	_card_stage = MODEL_STAGE.new(CP.card)
	pg.add_child(_card_stage)
	var lay := Control.new()  # 1280×720 시안 좌표 (가운데 맞춤)
	lay.custom_minimum_size = Vector2(1280, 720)
	lay.size = Vector2(1280, 720)
	lay.anchor_left = 0.5
	lay.anchor_right = 0.5
	lay.anchor_top = 0.5
	lay.anchor_bottom = 0.5
	lay.offset_left = -640
	lay.offset_right = 640
	lay.offset_top = -360
	lay.offset_bottom = 360
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(lay)
	# 제목
	var T: Dictionary = CP.title
	var tb := UiKit.Board.new("parch", T.pad)
	tb.nails = 2
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tb.add_child(tv)
	var tl := UiKit.label("누가 나갈래?", int(T.font), UiKit.c("ink"), tv)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trim_font(tl, int(T.font), 0.12)
	lay.add_child(tb)
	var center_title := func() -> void:
		tb.position = Vector2(640 - tb.size.x / 2.0, float(T.top))
		tb.pivot_offset = tb.size / 2.0
		if _class_sub:
			_class_sub.position = Vector2(tb.position.x + tb.size.x + 18, tb.position.y + tb.size.y - 34)
	tb.resized.connect(center_title)
	center_title.call_deferred()
	tb.rotation = deg_to_rad(float(T.tilt))
	_class_sub = UiKit.label("", int(CP.sub.font), UiKit.c("cream_dim"), lay)  # 제목 판 오른쪽 벽에 작게: AI대전 · 난이도 · 모드
	UiKit.wood_text(_class_sub, int(CP.sub.font), UiKit.c("cream_dim"))
	# 큰 액자 + 합격 도장
	var F: Dictionary = CP.frame
	var fr := UiKit.Board.new("parch", Vector4(4, 14, 4, 4))
	fr.nails = 2
	fr.custom_minimum_size = F.size
	var pic := TextureRect.new()
	pic.texture = _class_stage.get_texture()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fr.add_child(pic)
	lay.add_child(fr)
	_place(fr, F.pos, float(F.tilt))
	_class_stamp = _approved_stamp(lay)
	# 정보 양피지
	_build_class_info(lay)
	# 카드 5장
	var C: Dictionary = CP.cards
	_class_host = Control.new()
	_class_host.position = C.pos
	_class_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(_class_host)
	for i in GameData.CLASS_ORDER.size():
		var k: String = GameData.CLASS_ORDER[i]
		var card := _class_pick_card(k, i)
		_class_host.add_child(card)
		card.position = Vector2((float(C.size.x) + float(C.gap)) * i, 0)
		card.rotation = deg_to_rad(float(C.tilts[i % C.tilts.size()]))
		card.pivot_offset = C.size / 2.0
		_class_cards[k] = card
	# 뒤로 · 이놈으로 출전 · 개구 한마디
	var B: Dictionary = CP.back
	var back := UiKit.ghost("← 뒤로", int(B.font), Vector4(10, 8, 10, 8))
	back.custom_minimum_size = B.size
	back.position = B.pos
	back.pressed.connect(func() -> void: show_page("mode"))
	lay.add_child(back)
	var G: Dictionary = CP.go
	_class_go = UiKit._kit_button("이놈으로 출전", "gilt", int(G.font), Vector4(20, 8, 20, 8), 4)
	_class_go.custom_minimum_size = G.size
	_class_go.position = G.pos
	_class_go.rotation = deg_to_rad(float(G.tilt))
	_class_go.pivot_offset = G.size / 2.0
	_class_go.pressed.connect(func() -> void: select_class(_class_pick))
	lay.add_child(_class_go)
	var H: Dictionary = CP.hint
	var hint := UiKit.scribble(str(H.text), int(H.font), UiKit.c("cream_dim"), lay)
	UiKit.shadow(hint, UiKit.c("ink", 0.8), 2)
	_place(hint, H.pos, float(H.tilt))


## 오른쪽 정보 양피지: 이름(형광펜 밑줄) + 무기, 개구 한마디, 점선, 체력·속도·사거리 막대, 한 줄 설명
func _build_class_info(lay: Control) -> void:
	var I: Dictionary = GameData.CLASS_PAGE.info
	var bc: Dictionary = GameData.CLASS_PAGE.bar_cols
	var ib := UiKit.Board.new("parch", I.pad)
	ib.nails = 4
	ib.custom_minimum_size = I.size
	ib.position = I.pos
	lay.add_child(ib)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(I.gap))
	ib.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 17)
	vb.add_child(top)
	_ci.name = UiKit.label("", int(I.name), UiKit.c("ink"), top)
	_trim_font(_ci.name, int(I.name), float(I.trim))
	var mk := ColorRect.new()  # 형광펜 밑줄 (글자 아래 52%~90%)
	mk.color = UiKit.c("marker")
	mk.show_behind_parent = true
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ci.name.add_child(mk)
	_ci.name.resized.connect(func() -> void:
		var s: Vector2 = _ci.name.size
		mk.position = Vector2(-5, s.y * 0.5)
		mk.size = Vector2(s.x + 10, s.y * 0.36))
	_ci.weapon = UiKit.label("", int(I.weapon), GameData.col(I.weapon_col), top)
	_ci.weapon.size_flags_vertical = Control.SIZE_SHRINK_END
	_ci.line = UiKit.scribble("", int(I.line), UiKit.c("ink"), vb)
	_trim_font(_ci.line, int(I.line), float(I.trim))
	var dash := Dashes.new()
	dash.custom_minimum_size.y = 4
	vb.add_child(dash)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 15)
	g.add_theme_constant_override("v_separation", int(I.row_gap))
	vb.add_child(g)
	for row: Array in [["hp", "체력"], ["speed", "속도"], ["range", "사거리"]]:
		var l := UiKit.label(row[1], int(I.stat), UiKit.c("ink"), g)
		_trim_font(l, int(I.stat), float(I.trim))
		l.custom_minimum_size.x = 80
		var bar := StatBar.new()
		bar.col = GameData.col(bc[row[0]])
		bar.track = GameData.col(bc.track)
		bar.custom_minimum_size = Vector2(0, float(I.bar_h))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(bar)
		var n := UiKit.label("", int(I.stat), UiKit.c("ink"), g)
		_trim_font(n, int(I.stat), float(I.trim))
		n.custom_minimum_size.x = 100
		_ci[row[0]] = bar
		_ci[row[0] + "_n"] = n
	_ci.desc = UiKit.label("", int(I.desc), UiKit.c("brown"), vb)
	_ci.desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## 큰 글자 위아래 빈 줄 높이를 줄임 (글자 크기 × k만큼씩) — 시안처럼 촘촘하게
func _trim_font(l: Label, size: int, k: float) -> void:
	var fv := FontVariation.new()
	fv.base_font = l.get_theme_font("font")
	fv.spacing_top = -roundi(size * k)
	fv.spacing_bottom = -roundi(size * k * 0.6)
	l.add_theme_font_override("font", fv)


## 병과 카드 하나 (양피지, 못 1개, 왼쪽 위 잉크 숫자, 그림 = 한 번 찍은 DerpModel)
func _class_pick_card(k: String, i: int) -> UiKit.Tap:
	var C: Dictionary = GameData.CLASS_PAGE.cards
	var bd := UiKit.Board.new("parch", Vector4.ZERO)
	bd.nails = 1
	bd.custom_minimum_size = C.size
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bd.add_child(body)
	var inner: Vector2 = C.size - Vector2(4, 4)
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size = C.img
	img.position = Vector2((inner.x - float(C.img.x)) / 2.0, 6)
	body.add_child(img)
	_card_imgs[k] = img
	var nm := UiKit.label(GameData.CLASSES[k].name, int(C.name), UiKit.c("ink"), body)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size = Vector2(inner.x, 30)
	nm.position = Vector2(0, inner.y - 34)
	var key := KeyBadge.new()  # 왼쪽 위 잉크 숫자 (숫자는 안 기울임 — 카드 기울기만큼 되돌림)
	key.text = str(i + 1)
	key.font_size = int(C.key_font)
	key.size = Vector2(C.key, C.key)
	key.position = Vector2(-7, -8)
	key.pivot_offset = key.size / 2.0
	key.rotation = -deg_to_rad(float(C.tilts[i % C.tilts.size()]))
	body.add_child(key)
	var t := UiKit.board_tap(bd, C.lift)
	t.seal()
	t.pressed.connect(func() -> void: pick_class_card(k))
	return t


## '합격' 빨간 도장 (액자 오른쪽 위, 14°)
func _approved_stamp(lay: Control) -> Control:
	var S: Dictionary = GameData.CLASS_PAGE.stamp
	var st := PanelContainer.new()
	var sb := UiKit.box(Color(UiKit.c("parch"), 0.35), GameData.col(S.col), int(S.line), 8, Vector4(12, 2, 12, 4))
	st.add_theme_stylebox_override("panel", sb)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.label("합격", int(S.font), GameData.col(S.col), st)
	st.modulate.a = 0.9
	lay.add_child(st)
	_place(st, S.pos, float(S.tilt))
	return st


## 카드를 눌러 고르기 (시작은 안 함 — 출전 버튼). 도장이 쾅
func pick_class_card(k: String) -> void:
	var changed := k != _class_pick
	_preview_class(k)
	if changed:
		_stamp_slam()


func _preview_class(k: String) -> void:
	_class_pick = k
	for o: String in _class_cards:
		(_class_cards[o] as UiKit.Tap).face.board.ring = UiKit.c("marker") if o == k else Color.TRANSPARENT
	_class_stage.show_class(k)
	var C: Dictionary = GameData.CLASSES[k]
	var st: Dictionary = GameData.class_stats(k)
	_ci.name.text = C.name
	_ci.weapon.text = "무기: " + str(GameData.WEAPONS[C.weapon].name)
	_ci.line.text = str(GameData.CLASS_PAGE.lines.get(k, ""))
	(_ci.hp as StatBar).set_k(st.hp_k)
	(_ci.speed as StatBar).set_k(st.walk_k)
	(_ci.range as StatBar).set_k(st.range_k)
	_ci.hp_n.text = str(st.hp)
	_ci.speed_n.text = "%.1f / %.1f" % [st.walk, st.run]
	_ci.range_n.text = "%dm" % roundi(st.range)
	_ci.desc.text = st.blurb


## 합격 도장 쾅: 크게 떠 있다가 빠르게 내려찍고 살짝 튕김 + 효과음
func _stamp_slam() -> void:
	var S: Dictionary = GameData.CLASS_PAGE.stamp
	var st := _class_stamp
	if _stamp_tw:
		_stamp_tw.kill()
	st.scale = Vector2.ONE * float(S.from)
	st.modulate.a = 0.0
	var t: float = S.pop_t
	_stamp_tw = create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_stamp_tw.tween_property(st, "scale", Vector2.ONE * 0.94, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamp_tw.parallel().tween_property(st, "modulate:a", 0.9, t * 0.6)
	_stamp_tw.tween_callback(func() -> void: Sfx.play("stamp"))
	_stamp_tw.tween_property(st, "scale", Vector2.ONE, 0.08)


func open_class_page() -> void:
	_class_sub.text = "AI대전 · %s · %s" % [GameData.DIFF[GameData.difficulty].name, GameData.MODE_NAMES.get(GameData.mode, "개인전")]
	_preview_class(GameData.chosen_cls)
	_class_stamp.scale = Vector2.ONE
	_class_stamp.modulate.a = 0.9
	if not _portraits_made:
		_portraits_made = true
		_make_portraits()
	show_page("class")


## 카드 그림: DerpModel을 병과마다 한 번만 찍어 둔다 (헤드리스면 그림 없음)
func _make_portraits() -> void:
	for k: String in GameData.CLASS_ORDER:
		var tex: Texture2D = await _card_stage.portrait(k)
		if tex:
			(_card_imgs[k] as TextureRect).texture = tex
	_card_stage.render_target_update_mode = SubViewport.UPDATE_DISABLED


func select_class(k: String) -> void:
	GameData.chosen_cls = k
	GameData.save_settings()
	start_requested.emit()


## 점선 (시안: 14px 선 · 8px 틈, 잉크 50%)
class Dashes extends Control:
	func _draw() -> void:
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, 1, minf(9.0, size.x - x), 2), UiKit.c("ink", 0.5))
			x += 14.0


## 능력치 막대: 양피지색 홈 + 색 채움 (둘 다 잉크 테두리, 채움 아래쪽 그늘). 값이 바뀌면 부드럽게 늘었다 줄었다
class StatBar extends Control:
	var col := Color.RED
	var track := Color.TAN
	var k := 0.0:
		set(v):
			k = v
			queue_redraw()
	var _tw: Tween

	func set_k(v: float) -> void:
		if _tw:
			_tw.kill()
		if not is_inside_tree():
			k = v
			return
		_tw = create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tw.tween_property(self, "k", v, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var h := size.y
		var ink := UiKit.c("ink")
		var tsb := UiKit.box(track, ink, 2, int(h / 2))
		draw_style_box(tsb, Rect2(Vector2.ZERO, size))
		var fw := maxf(h, size.x * clampf(k, 0.0, 1.0))
		var fsb := UiKit.box(col, ink, 2, int(h / 2))
		fsb.shadow_size = 0
		draw_style_box(fsb, Rect2(0, 0, fw, h))
		draw_rect(Rect2(h / 2.0, h - 6, maxf(0.0, fw - h), 4), Color(0, 0, 0, 0.18))


## 카드 왼쪽 위 숫자 (잉크 네모 + 흰 글자)
class KeyBadge extends Control:
	var text := ""
	var font_size := 17

	func _draw() -> void:
		var sb := UiKit.box(UiKit.c("ink"), Color.TRANSPARENT, 0, 5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f := get_theme_default_font()
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(f, Vector2((size.x - ts.x) / 2.0, (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiKit.c("cream"))


## 작은 병과 카드 줄 (대기실·일시정지) — 양피지 카드 (못 1), 고른 카드 = 형광펜 테. 누르면 바로 on_pick
func _fill_cards(host: GridContainer, current: String, _mini: bool, on_pick: Callable) -> void:
	for ch in host.get_children():
		host.remove_child(ch)
		ch.queue_free()
	var MC: Dictionary = GameData.PAGE_UI.mini
	var boards := {}
	for i in GameData.CLASS_ORDER.size():
		var k: String = GameData.CLASS_ORDER[i]
		var C: Dictionary = GameData.CLASSES[k]
		var bd := UiKit.Board.new("parch", MC.pad)
		bd.nails = 1
		bd.custom_minimum_size.x = float(MC.w)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		bd.add_child(hb)
		hb.add_child(UiKit.emblem(k, float(MC.emblem)))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tv)
		var nl := UiKit.label(C.name, int(MC.font), UiKit.c("ink"), tv)
		UiKit.trim_font(nl, int(MC.font), 0.2)
		var wl := UiKit.label(GameData.WEAPONS[C.weapon].name, int(MC.sub), UiKit.c("brown"), tv)
		UiKit.trim_font(wl, int(MC.sub), 0.2)
		var num := UiKit.label(str(i + 1), int(MC.sub), UiKit.c("faded"), hb)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bd.ring = UiKit.c("marker") if k == current else Color.TRANSPARENT
		var t := UiKit.board_tap(bd, GameData.PICK_CARDS.lift)
		t.seal()
		boards[k] = bd
		t.pressed.connect(func() -> void:
			for o: String in boards:
				(boards[o] as UiKit.Board).ring = UiKit.c("marker") if o == k else Color.TRANSPARENT
			on_pick.call(k))
		var tilts: Array = MC.tilts
		host.add_child(UiKit.tilted(t, float(tilts[i % tilts.size()])))


# ── 공용 판 ─────────────────────────────────────────────────
## 큰 판: 양피지 + 쇠못 4 (일시정지·나가기 안내·친구대전·대기실). 안의 VBox를 돌려줌
func _big_board(parent: Node, w := 0.0) -> VBoxContainer:
	var PU: Dictionary = GameData.PAGE_UI
	var bd := UiKit.Board.new("parch", PU.board_pad)
	bd.nails = 4
	bd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if w > 0:
		bd.custom_minimum_size.x = w
	parent.add_child(bd)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(PU.board_gap))
	bd.add_child(vb)
	return vb


## 양피지 위 설명 (잉크, 가운데)
func _ink_sub(text: String, parent: Node, size := 0) -> Label:
	var fs: int = size if size > 0 else int(GameData.PAGE_UI.sub)
	var l := UiKit.label(text, fs, UiKit.c("brown"), parent)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


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
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	pg.add_child(head)
	_head2(str(GameData.PAGE_UI.exit_title), head)
	var vb := _big_board(pg, 520)
	_ink_sub("게임을 껐어요. 브라우저 탭을 닫으면 완전히 꺼져요.", vb)
	var b := UiKit.primary("다시 하러 가기")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: show_page("main"))
	vb.add_child(b)


# ── 친구대전 (같은 와이파이) — HTML pgFriend / pgLobby ─────────
func _build_friend() -> void:
	var pg := _sheet(screens.menu, true)
	pages.friend = pg
	_pagehead(pg, "친구대전", "main")
	var vb := _big_board(pg, 560)
	_ink_sub("방을 만들고 코드를 친구에게 알려주세요. 친구가 코드를 넣으면 들어와요.", vb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 420
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(col)
	UiKit.label("닉네임", 15, UiKit.c("brown"), col)
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
	_friend_status = UiKit.label("", 15, UiKit.c("ink"), vb)
	_friend_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_friend_status.custom_minimum_size.y = 22
	create.pressed.connect(func() -> void: friend_create.emit(nick.text))
	var do_join := func() -> void: friend_join.emit(nick.text, code.text.strip_edges().to_upper())
	join.pressed.connect(do_join)
	code.text_submitted.connect(func(_t: String) -> void: do_join.call())
	var hint := _ink_sub("같은 와이파이(공유기)에 연결된 친구끼리만 들어올 수 있어요. 코드로 못 찾으면 대기실에 보이는 방장 IP를 코드 칸에 넣어 보세요. 개인전엔 봇과 닭이 없고, 쟁탈전은 빈자리를 봇이 채워요.", vb, 13)
	hint.add_theme_color_override("font_color", UiKit.c("faded"))


func friend_status(text: String) -> void:
	_friend_status.text = text


## 대기실: 방 코드 · 사람 목록 · 내 병과 · 게임 시작
func _build_lobby() -> void:
	var pg := _sheet(screens.menu)
	pages.lobby = pg
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	pg.add_child(hb)
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	var back := UiKit.back("← 방 나가기")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: lobby_leave.emit())
	left.add_child(back)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 14)
	hb.add_child(title)
	_head2("방 코드", title)
	var chip := UiKit.Board.new("parch", Vector4(16, 0, 16, 4))
	chip.paint = UiKit.c("marker")
	chip.nails = 1
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(UiKit.tilted(chip, 2.0))
	_lobby_code = UiKit.label("", 44, UiKit.c("ink"), chip)
	UiKit.trim_font(_lobby_code, 44, 0.15)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	var vb := _big_board(pg, 900)
	_lobby_sub = _ink_sub("친구에게 코드를 알려주세요", vb)
	# 모드 고르기 (방장만 누를 수 있음, 친구는 보기만)
	var mrow := HBoxContainer.new()
	mrow.alignment = BoxContainer.ALIGNMENT_CENTER
	mrow.add_theme_constant_override("separation", 10)
	vb.add_child(mrow)
	UiKit.label("모드", 16, UiKit.c("brown"), mrow)
	for k: String in ["ffa", "control"]:
		var mb := UiKit.ghost(GameData.MODE_NAMES.get(k, k) + (" 5:5" if k == "control" else ""), 16, Vector4(16, 6, 16, 6))
		mb.pressed.connect(func() -> void: lobby_mode.emit(k))
		mrow.add_child(mb)
		_lobby_modes[k] = mb
	_lobby_mode_note = UiKit.label("", 14, UiKit.c("faded"), mrow)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	vb.add_child(body)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 6)
	lcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lcol.size_flags_stretch_ratio = 1
	body.add_child(lcol)
	UiKit.label("들어온 사람", 15, UiKit.c("brown"), lcol)
	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override("separation", 4)
	lcol.add_child(_lobby_list)
	var ccol := VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 6)
	ccol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ccol.size_flags_stretch_ratio = 1.3
	body.add_child(ccol)
	UiKit.label("내 병과", 15, UiKit.c("brown"), ccol)
	_lobby_cards = GridContainer.new()
	_lobby_cards.columns = 2
	_lobby_cards.add_theme_constant_override("h_separation", 12)
	_lobby_cards.add_theme_constant_override("v_separation", 12)
	ccol.add_child(_lobby_cards)
	var act := _actions(vb)
	_lobby_team_btn = UiKit.ghost("팀 바꾸기")
	_lobby_team_btn.pressed.connect(func() -> void: lobby_team.emit())
	act.add_child(_lobby_team_btn)
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


## HTML renderLobby: list = [{name, cls, host, st, team}], btn = 버튼 글자 (없으면 숨김)
## md = 방 모드 (control이면 팀별로 나눠 보이고 '팀 바꾸기'), host = 내가 방장 (모드를 바꿀 수 있음)
func render_lobby(code: String, list: Array, sub: String, btn: String, md := "ffa", host := false) -> void:
	_lobby_code.text = code if code != "" else "IP"
	_lobby_sub.text = sub
	_lobby_btn.visible = btn != ""
	_lobby_btn.text = btn
	var ctrl := md == "control"
	_lobby_team_btn.visible = ctrl
	for k: String in _lobby_modes:
		var mb: Button = _lobby_modes[k]
		var on := k == md
		mb.disabled = not host
		mb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if host else Control.CURSOR_ARROW
		mb.visible = host or on
		(mb as UiKit.KitButton).selected = on  # 고른 모드 = 형광펜
	_lobby_mode_note.text = "" if host else "방장이 정해요"
	if ctrl:  # 블루 먼저, 같은 팀끼리
		list = list.duplicate()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (0 if a.get("team", "") == "blue" else 1) < (0 if b.get("team", "") == "blue" else 1))
	var sig := str(list) + md
	if sig == _lobby_sig:
		return
	_lobby_sig = sig
	for ch in _lobby_list.get_children():
		ch.queue_free()
	var T: Dictionary = GameData.MODES.control.teams
	for p: Dictionary in list:
		var tm := str(p.get("team", ""))
		var has_team := ctrl and T.has(tm)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.35), UiKit.c("ink", 0.25), 1, 4, Vector4(8, 3, 8, 4)))
		_lobby_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		if has_team:  # 팀 = 방패 색 + 글자
			var sh := TeamShield.new()
			sh.col = GameData.col(T[tm].body)
			sh.left = tm == "blue"
			sh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(sh)
			var tl := UiKit.label(str(T[tm].short), 15, Color(str(T[tm].ink)), hb)
			tl.custom_minimum_size.x = 30
		var nm := UiKit.label(str(p.name), 17, UiKit.c("ink"), hb)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.label(GameData.CLASSES[p.cls].name, 13, UiKit.c("brown"), hb)
		if p.st == "play":
			UiKit.label("게임 중", 13, UiKit.c("faded"), hb)
		if p.host:
			var em := UiKit.Board.new("parch", Vector4(6, 0, 6, 1))
			em.paint = UiKit.c("marker")
			em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			UiKit.label("방장", 13, UiKit.c("ink"), em)
			hb.add_child(em)


## 대기실 팀 표시: 작은 방패 (블루 = 오른쪽 아래 귀퉁이 둥글게, 레드 = 거울 — HUD 방패와 같은 규칙)
class TeamShield extends Control:
	var col := Color.WHITE
	var left := true

	func _init() -> void:
		custom_minimum_size = Vector2(18, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(1, 1), Vector2(w - 1, 1), Vector2(w - 1, h * 0.55), Vector2(w / 2.0, h - 1), Vector2(1, h * 0.55)])
		draw_colored_polygon(pts, col)
		var ol := pts.duplicate()
		ol.append(pts[0])
		draw_polyline(ol, UiKit.c("ink"), 2.0, true)


## 글자 칸: 양피지 바탕 + 잉크 테두리 (누르면 형광펜 테)
func _field(ph: String, max_len: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = max_len
	le.add_theme_font_size_override("font_size", 19)
	le.add_theme_color_override("font_color", UiKit.c("ink"))
	le.add_theme_color_override("caret_color", UiKit.c("ink"))
	le.add_theme_color_override("selection_color", UiKit.c("marker", 0.6))
	le.add_theme_color_override("font_placeholder_color", UiKit.c("faded", 0.8))
	var pad := Vector4(14, 9, 14, 9)
	var bg := GameData.col(0xfffaea)
	le.add_theme_stylebox_override("normal", UiKit.box(bg, UiKit.c("ink"), 2, 4, pad))
	le.add_theme_stylebox_override("focus", UiKit.box(Color.TRANSPARENT, UiKit.c("marker"), 3, 4, pad))
	return le


# ── 일시정지 ─────────────────────────────────────────────────
func _build_pause() -> void:
	var pg := _sheet(screens.pause, false, 18)
	_pause_main = pg
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	pg.add_child(head)
	_head2("일시정지", head)
	var vb := _big_board(pg)
	var sub := UiKit.rich(16, UiKit.c("ink"), vb)
	sub.add_theme_color_override("default_color", UiKit.c("ink"))
	sub.text = "[center]다음에 나갈 병과 · 바꾸면 %s 적용[/center]" % _hl("다음 부활부터")
	_pause_cards = GridContainer.new()
	_pause_cards.columns = GameData.CLASS_ORDER.size()
	_pause_cards.add_theme_constant_override("h_separation", 12)
	vb.add_child(_pause_cards)
	var act := _actions(vb)
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
## 결과 화면 승리·패배 연출 (사용자 요청 — HTML엔 없음). 수치·문구는 GameData.RESULT·RESULT_LINES·STINGER.
##   승리: 0.6초 느린 화면 → 0.3초 제목 판이 위에서 떨어져 통통 튀고 좌우로 흔들림 → 0.5초 효과음 + 금빛 햇살 + 색종이
##   패배: 배경이 회색으로 바램 → 0.3초 제목 판이 떨어져 못 하나가 빠진 듯 10° 기울어짐 → 0.5초 효과음 → 0.6초 먹구름·비
##   둘 다 1.4초부터 점수판 줄이 위에서부터 하나씩 펼쳐지고, 그 뒤 버튼. 무승부는 연출·소리 없이 그대로.
##   BGM은 0.3초 만에 줄고, 효과음이 끝나면 메뉴 곡이 다시 커진다. 화면을 떠나면 _end_fx_reset()이 다 되돌림.
const GRAY_SHADER := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c, vec3(g) * 0.85, amount), 1.0);
}"

var end_result := ""   # 마지막 결과: victory / defeat / draw (테스트용)
var end_phrase := ""   # 노란 쪽지에 고른 문구
var _end_holder: Control      # 제목 자리 (배치 좌표) — 판은 그 안에서 자유롭게 움직임
var _end_card: Control        # 매달린 제목 판(또는 팀 깃발) + 쪽지 + 못
var _end_panel: PanelContainer  # 나무 제목 판
var _end_pennant: Pennant     # 쟁탈전 승리: 팀 깃발 "블루팀 / 승리!"
var _end_kicker: Label        # 깃발 위 팀 이름
var _end_pen_title: Label
var _end_pen_dots: RoundDots
var _end_memo: PanelContainer
var _end_memo_l: Label
var _end_memo_dots: RoundDots  # 쟁탈전 패배 쪽지 끝 라운드 동그라미
var _end_nails: Array[Control] = []
var _end_winner: Pennant      # 쟁탈전 패배: 작은 깃발 "레드팀 승리"
var _end_winner_l: Label
var _end_head: Label          # 오른쪽 판 제목 (개인전 결과 / 쟁탈전 결과)
var _end_note: Label          # 개인전 패배: "(넘어짐 N회)" 낙서
var _end_me: Control          # "나" 꼬리표
var _end_me_at := Vector2.ZERO
var _end_stage: SubViewport   # 왼쪽 3D 무대 (result_stage.gd)
var _end_props: Control       # 시상대·발판 (무대 뒤)
var _end_again: Button
var _end_btns: Array[Button] = []
var _end_gray: ColorRect      # 패배: 뒤 게임 화면 회색
var _sun: Sunburst            # 승리: 금빛 햇살
var _clouds: Clouds           # 패배: 먹구름
var _end_front: Control       # 색종이·비 (맨 위, 클릭 통과)
var _fx_tweens: Array[Tween] = []
var _fx_nodes: Array[Node] = []
var _fx_on := false
var _slowmo := false
var _stinger_on := false
var _tex_cache := {}


func _build_end() -> void:
	var RU: Dictionary = GameData.RESULT_UI
	var root: Control = screens.end
	(root.get_meta("bg") as Control).modulate.a = float(RU.bg_a)  # 뒤 게임 화면이 잘 보이게 옅은 그늘
	_end_gray = ColorRect.new()
	_end_gray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_end_gray.material = sm
	_end_gray.visible = false
	root.add_child(_end_gray)
	root.move_child(_end_gray, 0)  # 그늘 아래
	var back := Control.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	root.move_child(back, 2)  # 그늘 위
	_sun = Sunburst.new()
	back.add_child(_sun)
	_clouds = Clouds.new()
	back.add_child(_clouds)
	_sun.visible = false
	_clouds.visible = false
	var lay := _lay_1280(root)
	# 왼쪽 무대: 시상대·발판 → 3D 캐릭터
	_end_props = Control.new()
	_end_props.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(_end_props)
	_end_stage = RESULT_STAGE.new()
	root.add_child(_end_stage)
	var S: Dictionary = RU.stage
	var pic := TextureRect.new()
	pic.texture = _end_stage.get_texture()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.position = (S.rect as Rect2).position
	pic.size = (S.rect as Rect2).size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(pic)
	var me_bd := UiKit.Board.new("parch", RU.me_tag.pad)
	var me_l := UiKit.label("나", int(RU.me_tag.font), UiKit.c("ink"), me_bd)
	UiKit.trim_font(me_l, int(RU.me_tag.font), 0.2)
	_end_me = me_bd
	_end_me.rotation_degrees = float(RU.me_tag.tilt)
	_end_me.resized.connect(_place_me_tag)
	lay.add_child(_end_me)
	_end_note = UiKit.scribble("", 24, UiKit.c("cream"), lay)
	UiKit.shadow(_end_note, UiKit.c("ink", 0.8), 2)
	_end_note.rotation_degrees = -6.0
	# 매달린 제목
	_end_holder = Control.new()
	_end_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(_end_holder)
	_end_card = Control.new()
	_end_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_holder.add_child(_end_card)
	var SG: Dictionary = RU.sign
	var bd := UiKit.Board.new("wood", SG.pad)
	bd.ropes = true
	bd.rope_len = float(SG.rope)
	bd.custom_minimum_size = SG.min
	_end_panel = bd
	_end_card.add_child(bd)
	_end_title = UiKit.label("경기 종료", int(SG.font), UiKit.c("cream"), bd)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 팀 깃발 (쟁탈전 승리)
	var P: Dictionary = RU.pennant
	_end_pennant = Pennant.new()
	_end_pennant.custom_minimum_size = P.size
	_end_pennant.ropes = true
	_end_card.add_child(_end_pennant)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -8)
	_end_pennant.add_child(pv)
	_end_kicker = UiKit.wood_text(UiKit.label("", int(P.kicker), UiKit.c("cream"), pv), int(P.kicker))
	_end_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_pen_title = UiKit.wood_text(UiKit.label("", int(P.title), UiKit.c("marker"), pv), int(P.title), UiKit.c("marker"))
	_end_pen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_pen_dots = RoundDots.new()
	_end_pen_dots.d = float(P.dot)
	_end_pen_dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(_end_pen_dots)
	# 쪽지
	var MM: Dictionary = RU.memo
	var mb := UiKit.Board.new("parch", MM.pad)
	_end_memo = mb
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 12)
	mb.add_child(mh)
	_end_memo_l = UiKit.scribble("", int(MM.font), UiKit.c("ink"), mh)
	_end_memo_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_memo_dots = RoundDots.new()
	_end_memo_dots.d = float(MM.dot)
	_end_memo_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(_end_memo_dots)
	_end_card.add_child(mb)
	for i in 2:  # 제목 판을 건 못 두 개 (지면 오른쪽이 빠짐)
		var n := NailDot.new()
		_end_card.add_child(n)
		_end_nails.append(n)
	# 작은 깃발: 이긴 팀 (쟁탈전 패배)
	var SP: Dictionary = RU.small_pennant
	_end_winner = Pennant.new()
	_end_winner.custom_minimum_size = SP.size
	_end_winner.position = SP.pos
	_end_winner.size = SP.size
	_end_winner.top_pad = 8.0
	_end_winner.tilt = 6.0
	lay.add_child(_end_winner)
	_end_winner_l = UiKit.wood_text(UiKit.label("", int(SP.font), UiKit.c("cream"), _end_winner), int(SP.font))
	_end_winner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_winner_l.add_theme_constant_override("line_spacing", -6)
	# 오른쪽 결과판 (양피지 + 못 4)
	var B: Dictionary = RU.board
	var rb := UiKit.Board.new("parch", B.pad)
	rb.nails = 4
	rb.position = B.pos
	rb.custom_minimum_size.x = float(B.w)
	lay.add_child(rb)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rb.add_child(rv)
	_end_head = UiKit.label("개인전 결과", int(B.title), UiKit.c("ink"), rv)
	_end_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.trim_font(_end_head, int(B.title), 0.15)
	_end_sub = UiKit.rich(int(B.sub), UiKit.c("ink"), rv)
	_end_sub.add_theme_color_override("default_color", UiKit.c("ink"))
	_end_table = PanelContainer.new()
	_end_table.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_end_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(_end_table)
	# 버튼 (오른쪽 아래): 메인 메뉴 · 병과 다시 고르기 (양피지) + 한 판 더 (금칠)
	var BT: Dictionary = RU.btns
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(BT.gap))
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.offset_left = float(BT.right)
	hb.offset_right = float(BT.right)
	hb.offset_top = float(BT.top)
	hb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lay.add_child(hb)
	var mm := UiKit.ghost("메인 메뉴", int(BT.font), BT.pad)
	mm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mm.pressed.connect(func() -> void: menu_requested.emit("main"))
	hb.add_child(mm)
	var pick := UiKit.ghost("병과 다시 고르기", int(BT.font), BT.pad)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.pressed.connect(func() -> void: menu_requested.emit("class"))
	hb.add_child(pick)
	_end_again = UiKit._kit_button("한 판 더", "gilt", int(BT.go_font), Vector4(20, 6, 20, 6), 2)
	_end_again.custom_minimum_size = BT.go_size
	_end_again.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_again.pressed.connect(func() -> void: again_requested.emit())
	hb.add_child(_end_again)
	_end_btns = [_end_again, pick, mm]
	_end_front = Control.new()
	_end_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_end_front)
	Sfx.stinger_done.connect(_on_stinger_done)


## 1280×720 시안 좌표판 (화면 가운데 맞춤)
func _lay_1280(parent: Control) -> Control:
	var lay := Control.new()
	lay.size = Vector2(1280, 720)
	lay.anchor_left = 0.5
	lay.anchor_right = 0.5
	lay.anchor_top = 0.5
	lay.anchor_bottom = 0.5
	lay.offset_left = -640
	lay.offset_right = 640
	lay.offset_top = -360
	lay.offset_bottom = 360
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lay)
	return lay


## 개인전 승패: 1~3등이면 승리 연출
func ffa_result(rank: int) -> String:
	return "victory" if rank >= 1 and rank <= int(GameData.RESULT.ffa_win_rank) else "defeat"


## 쟁탈전 승패: 우리 팀이 이기면 승리, 무승부는 draw
func control_result(winner: String, team: String) -> String:
	if winner == "":
		return "draw"
	return "victory" if team == winner else "defeat"


static func _hl(s: String) -> String:
	return "[bgcolor=#%s]%s[/bgcolor]" % [UiKit.c("marker").to_html(false), s]


## HTML endMatch: 우승자·내 순위 + 순위별 제목·문구 (1~3등 승리 연출, 4등부터 패배 연출)
func open_end(rows: Array, me: PlayerController) -> void:
	var win: PlayerController = rows[0]
	var rank := rows.find(me) + 1
	if win == me:
		_end_sub.text = "[center]%s로 아레나를 제패했다[/center]" % _hl("%d킬" % me.kills)
	else:
		_end_sub.text = "[center]우승 %s %d킬 · 내 순위 %d위[/center]" % [UiKit.esc(win.ent_name), win.kills, rank]
	_end_head.text = "개인전 결과"
	var res := ffa_result(rank)
	_set_table(_ffa_table(rows, me, res == "victory"))
	var L: Dictionary = GameData.RESULT_LINES
	var cast: Array = []
	_end_me_at = Vector2.ZERO
	if res == "victory":
		var d: Dictionary = L.ffa[rank]
		_show_end(res, str(d.title), d.lines, [])
		for P: Dictionary in GameData.RESULT_UI.podium:
			var n: int = P.n
			if n > rows.size():
				continue
			var e: PlayerController = rows[n - 1]
			var at := Vector2(float(P.x) + float(P.w) / 2.0, float(P.top))
			cast.append({"cls": e.cls, "at": at, "yaw": (n - 2) * -12.0, "mood": "win" if n == 1 else ""})
			if e == me:
				_end_me_at = at
	else:
		_show_end(res, str(L.ffa_lose.title) % (rank if rank > 0 else rows.size()), L.ffa_lose.lines, [])
		cast.append({"cls": me.cls, "at": GameData.RESULT_UI.lie, "lie": true})
		_end_note.text = str(L.lose_note) % me.deaths
		_end_note.visible = true
	_set_cast(cast, res == "victory", false)


## 쟁탈전 결과: 이긴 팀 + 라운드 점수 + 팀 점수판
func open_end_control(winner: String, wins: Dictionary, rows: Array, me: PlayerController) -> void:
	_end_sub.text = "[center]%s %d : %d %s[/center]" % [ControlMode.team_name("blue"), int(wins.blue), int(wins.red), ControlMode.team_name("red")]
	_end_head.text = "쟁탈전 결과"
	var res := control_result(winner, me.team)
	_set_table(_ctrl_table(rows, me, wins, res))
	var L: Dictionary = GameData.RESULT_LINES
	match res:
		"victory":
			var T: Dictionary = GameData.MODES.control.teams[winner]
			_show_end(res, str(L.ctrl_win.title), L.ctrl_win.lines,
				[Color(str(T.ui)), GameData.col(T.accent), UiKit.c("marker"), GameData.col(0xfff2b0)], winner, wins)
		"defeat":
			var enemy := winner if me.team == "" else ("red" if me.team == "blue" else "blue")
			var lines: Array = []
			for s: String in L.ctrl_lose.lines:
				lines.append(s.format({"enemy": ControlMode.team_name(enemy)}))
			_show_end(res, str(L.ctrl_lose.title), lines, [], "", wins)
			var T: Dictionary = GameData.MODES.control.teams[winner]
			_end_winner.col = GameData.col(T.body)
			_end_winner_l.text = str(L.ctrl_lose.winner) % ControlMode.team_name(winner)
			_end_winner.visible = true
		_:
			_show_end(res, "무승부", [], [])
	# 우리 팀 5명 발판 위에 (나도 같이)
	var PF: Dictionary = GameData.RESULT_UI.platform
	var mates: Array = rows.filter(func(e: PlayerController) -> bool: return me.team == "" or e.team == me.team)
	mates = mates.slice(0, 5)
	var cast: Array = []
	_end_me_at = Vector2.ZERO
	for i in mates.size():
		var e: PlayerController = mates[i]
		var at := Vector2(float(PF.first) + i * float(PF.step), float(PF.top))
		cast.append({"cls": e.cls, "team": e.team, "at": at, "yaw": (i - 2) * -10.0,
			"mood": "win" if res == "victory" else ("lose" if res == "defeat" else "")})
		if e == me:
			_end_me_at = at
	_set_cast(cast, false, true)


## 무대 채우기: 3D 캐릭터 + 시상대(개인전 승리) 또는 발판(쟁탈전) + "나" 꼬리표
func _set_cast(cast: Array, podium: bool, platform: bool) -> void:
	var RU: Dictionary = GameData.RESULT_UI
	for ch in _end_props.get_children():
		ch.queue_free()
	if podium:
		for P: Dictionary in RU.podium:
			var bd := UiKit.Board.new("wood", Vector4(6, 0, 6, 0))
			bd.position = Vector2(float(P.x), float(P.top))
			bd.size = Vector2(float(P.w), 720.0 - float(P.top) + 12.0)
			var l := UiKit.wood_text(UiKit.label(str(P.n), int(RU.podium_font), UiKit.c("cream"), bd), int(RU.podium_font))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			_end_props.add_child(bd)
	if platform:
		var PF: Dictionary = RU.platform
		var bd := UiKit.Board.new("wood", Vector4.ZERO)
		bd.position = Vector2(float(PF.x), float(PF.top))
		bd.size = Vector2(float(PF.w), 720.0 - float(PF.top) + 12.0)
		_end_props.add_child(bd)
	_end_stage.setup(cast)
	_end_me.visible = _end_me_at != Vector2.ZERO
	(_end_me as UiKit.Board).paint = UiKit.c("marker") if end_result == "victory" else Color.TRANSPARENT
	_place_me_tag()


func _place_me_tag() -> void:
	var RU: Dictionary = GameData.RESULT_UI
	var top := _end_me_at - Vector2(0, float(RU.stage.head) * float(RU.stage.ppm))
	_end_me.position = top - Vector2(_end_me.size.x / 2.0, _end_me.size.y)
	_end_me.pivot_offset = _end_me.size / 2.0


func _set_table(t: Control) -> void:
	for ch in _end_table.get_children():
		_end_table.remove_child(ch)  # 바로 빼야 줄 찾기(_table_rows)에 옛 줄이 안 섞임
		ch.queue_free()
	_end_table.add_child(t)


## 결과판 한 줄: 칸 글자들 (폭은 widths, 0 = 남는 폭). me_bg가 있으면 그 바탕(이김 형광펜·짐 하늘색) + 잉크 테
func _end_row(parent: Control, cells: Array, widths: Array, size: int, col: Color, me_bg := Color.TRANSPARENT, sizes := {}) -> HBoxContainer:
	var pc := PanelContainer.new()
	var sb := UiKit.box(me_bg, UiKit.c("ink") if me_bg.a > 0 else Color.TRANSPARENT, 2 if me_bg.a > 0 else 0, 3, Vector4(8, 1, 8, 2))
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	pc.add_child(hb)
	for i in cells.size():
		var fs: int = sizes.get(i, size)
		var l := UiKit.label(str(cells[i]), fs, col, hb)
		UiKit.trim_font(l, fs, 0.22)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_FILL
		var w: float = widths[i]
		if w <= 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			l.custom_minimum_size.x = w
	return hb


## 개인전 결과판: 순위 · 이름 · 병과 · 처치 · 죽음
func _ffa_table(rows: Array, me: PlayerController, won: bool) -> VBoxContainer:
	var B: Dictionary = GameData.RESULT_UI.board
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var W: Array = B.col_w
	_num_cols(_end_row(vb, ["순위", "이름", "병과", "처치", "죽음"], W, int(B.head), UiKit.c("faded")), 3)
	var me_bg := GameData.col(B.me_win if won else B.me_lose)
	for i in rows.size():
		var e: PlayerController = rows[i]
		var nm := "나" if e == me else e.ent_name
		_num_cols(_end_row(vb, [i + 1, nm, GameData.CLASSES[e.cls].name, e.kills, e.deaths], W, int(B.row), UiKit.c("ink"),
			me_bg if e == me else Color.TRANSPARENT, {2: int(B.cls)}), 3)
	return vb


## from번째 칸부터 오른쪽 정렬 (숫자 칸)
func _num_cols(hb: HBoxContainer, from: int, align := HORIZONTAL_ALIGNMENT_RIGHT) -> void:
	for i in range(from, hb.get_child_count()):
		(hb.get_child(i) as Label).horizontal_alignment = align


## 쟁탈전 결과판: 블루·레드 라운드 / 처치 / 우물 차지 시간 + 우리 팀 줄 + MVP(이김) 또는 내 거점 시간(짐)
func _ctrl_table(rows: Array, me: PlayerController, wins: Dictionary, res: String) -> VBoxContainer:
	var B: Dictionary = GameData.RESULT_UI.board
	var L: Dictionary = GameData.RESULT_LINES
	var T: Dictionary = GameData.MODES.control.teams
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw: float = B.sum_w
	var sum := {"blue": [0, 0.0], "red": [0, 0.0]}
	for e: PlayerController in rows:
		if sum.has(e.team):
			sum[e.team][0] += e.kills
			sum[e.team][1] += e.cap_time
	# 팀 이름 줄 (팀 색 글자)
	var th := _end_row(vb, ["", str(T.blue.short), str(T.red.short)], [0.0, sw, sw], int(B.row), UiKit.c("ink"))
	(th.get_child(1) as Label).add_theme_color_override("font_color", Color(str(T.blue.ink)))
	(th.get_child(2) as Label).add_theme_color_override("font_color", Color(str(T.red.ink)))
	_num_cols(th, 1, HORIZONTAL_ALIGNMENT_CENTER)
	for r: Array in [["라운드", wins.blue, wins.red], ["처치", sum.blue[0], sum.red[0]],
			["우물 차지 시간", _mmss(sum.blue[1]), _mmss(sum.red[1])]]:
		_num_cols(_end_row(vb, r, [0.0, sw, sw], int(B.row), UiKit.c("ink")), 1, HORIZONTAL_ALIGNMENT_CENTER)
	var line := ColorRect.new()
	line.color = UiKit.c("ink", 0.25)
	line.custom_minimum_size.y = 2
	vb.add_child(line)
	var mates: Array = rows.filter(func(e: PlayerController) -> bool: return me.team == "" or e.team == me.team)
	var me_bg := GameData.col(B.me_win if res == "victory" else B.me_lose)
	var W: Array = [0.0, 70.0, 46.0, 46.0]
	for e: PlayerController in mates:
		_num_cols(_end_row(vb, ["나" if e == me else e.ent_name, GameData.CLASSES[e.cls].name, e.kills, e.deaths], W, int(B.row), UiKit.c("ink"),
			me_bg if e == me else Color.TRANSPARENT, {1: int(B.cls)}), 2)
	if res == "victory" and not mates.is_empty():
		var best: PlayerController = mates[0]
		for e: PlayerController in mates:
			if e.cap_time > best.cap_time or (e.cap_time == best.cap_time and e.kills > best.kills):
				best = e
		var who := "나" if best == me else best.ent_name
		var txt: String = str(L.mvp_cap) % [who, _min_sec(best.cap_time)] if best.cap_time >= 1.0 else str(L.mvp_kill) % [who, best.kills]
		var mv := UiKit.Board.new("parch", Vector4(10, 4, 10, 6))
		mv.paint = UiKit.c("marker")
		var mh := HBoxContainer.new()
		mh.add_theme_constant_override("separation", 10)
		mv.add_child(mh)
		var tag := UiKit.label("MVP", int(B.row), UiKit.c("ink"), mh)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ml := UiKit.scribble(txt, int(B.mvp_font), UiKit.c("ink"), mh)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ml.custom_minimum_size.x = 300
		vb.add_child(mv)
	elif res == "defeat":
		var nl := UiKit.scribble(str(L.lose_cap) % _min_sec(me.cap_time), int(B.mvp_font), UiKit.c("ink"), vb)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return vb


static func _mmss(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


static func _min_sec(s: float) -> String:
	var n := int(s)
	return ("%d분 %d초" % [n / 60, n % 60]) if n >= 60 else ("%d초" % n)


## title: 제목 판 글자. team이 있으면(쟁탈전 승리) 나무 판 대신 팀 깃발 "블루팀 / 승리!". wins = 라운드 동그라미
func _show_end(res: String, title: String, lines: Array, cols: Array, team := "", wins := {}) -> void:
	_end_fx_reset()
	end_result = res
	end_phrase = str(lines.pick_random()) if not lines.is_empty() else ""
	var RU: Dictionary = GameData.RESULT_UI
	var L: Dictionary = GameData.RESULT_LINES
	var pen := team != ""
	_end_title.text = title
	var long := title.length() > int(RU.sign.long_at)
	var fs: int = RU.sign.font_long if long else RU.sign.font
	_end_title.add_theme_font_size_override("font_size", fs)
	UiKit.wood_text(_end_title, fs)
	UiKit.trim_font(_end_title, fs, 0.12)
	(_end_panel as UiKit.Board).paint = GameData.col(RU.sign.lose_paint) if res == "defeat" else Color.TRANSPARENT
	_end_panel.visible = not pen
	_end_pennant.visible = pen
	if pen:
		_end_kicker.text = ControlMode.team_name(team)
		_end_pen_title.text = title
		_end_pennant.col = GameData.col(GameData.MODES.control.teams[team].body)
		_end_pen_dots.set_wins(wins, team)
	_end_memo_l.text = end_phrase
	_end_memo.visible = end_phrase != ""
	_end_memo_dots.visible = not pen and not wins.is_empty() and res != "draw"
	if _end_memo_dots.visible:
		_end_memo_dots.set_wins(wins, "")
	(_end_memo as UiKit.Board).paint = GameData.col(GameData.RESULT.memo) if res == "victory" else Color.TRANSPARENT
	if res == "defeat":
		_end_again.text = str(L.again_lose_ctrl) if not wins.is_empty() else str(L.again_lose)
	else:
		_end_again.text = "한 판 더"
	_end_winner.visible = false
	_end_note.visible = false
	_end_note.position = RU.lose_note
	show_screen("end")
	_layout_card()
	if res != "draw":
		_play_end_fx(res, cols)


## 지금 보이는 제목 (나무 판 또는 깃발) — 햇살·색종이 가운데
func _title_box() -> Control:
	return _end_pennant if _end_pennant.visible else _end_panel


## 제목 판·쪽지·못 자리 잡기 (판은 컨테이너 밖이라 직접 크기를 정함)
func _layout_card() -> void:
	var RU: Dictionary = GameData.RESULT_UI
	var SG: Dictionary = RU.sign
	var box := _title_box()
	box.size = Vector2.ZERO
	var ps := box.get_combined_minimum_size()
	box.size = ps
	box.position = Vector2.ZERO
	var long := _end_title.text.length() > int(SG.long_at) and box == _end_panel
	var cx: float = float(SG.center_long) if long else float(SG.pos.x) + float(SG.min.x) / 2.0
	_end_holder.position = Vector2(maxf(16.0, cx - ps.x / 2.0), float(SG.pos.y))
	var h := ps.y
	if _end_memo.visible:
		_end_memo.size = Vector2.ZERO
		var msz := _end_memo.get_combined_minimum_size()
		_end_memo.size = msz
		var MM: Dictionary = RU.memo
		_end_memo.position = Vector2((ps.x - msz.x) / 2.0 + 20.0, ps.y - float(MM.overlap))
		_end_memo.pivot_offset = msz / 2.0
		_end_memo.rotation_degrees = float(MM.rot_win) if end_result == "victory" else float(MM.rot_lose)
		h = _end_memo.position.y + msz.y
	var NI: Vector2 = SG.nail_in
	_end_nails[0].position = NI - _end_nails[0].size / 2.0
	_end_nails[1].position = Vector2(ps.x - NI.x, NI.y) - _end_nails[1].size / 2.0
	for n in _end_nails:
		n.visible = box == _end_panel
		n.modulate.a = 1.0
	_end_card.size = Vector2(ps.x, h)
	_end_card.pivot_offset = Vector2(ps.x / 2, ps.y / 2)


## 쇠못 하나 (제목 판을 건 못 — 지면 하나가 빠져 떨어짐)
class NailDot extends Control:
	func _init() -> void:
		size = Vector2(14, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.draw_nail(self, size / 2.0)


## 라운드 동그라미 "●● : ●○" (블루 | 레드). hi 팀의 이긴 판은 형광펜, 나머지 이긴 판은 팀 색, 못 이긴 판은 빈 회색
class RoundDots extends Control:
	var d := 14.0
	var wins := {}
	var hi := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_wins(w: Dictionary, hi_team: String) -> void:
		wins = w
		hi = hi_team
		var n := int(GameData.MODES.control.rounds_to_win)
		custom_minimum_size = Vector2((d + 6.0) * n * 2 + 14.0, d + 4.0)
		queue_redraw()

	func _draw() -> void:
		var n := int(GameData.MODES.control.rounds_to_win)
		var x := 2.0 + d / 2.0
		var y := size.y / 2.0
		var ink := UiKit.c("ink")
		for t: String in ["blue", "red"]:
			var col := GameData.col(GameData.MODES.control.teams[t].body)
			for i in n:
				var on := i < int(wins.get(t, 0))
				var fill := (UiKit.c("marker") if t == hi else col) if on else Color(0.62, 0.6, 0.56)
				draw_circle(Vector2(x, y), d / 2.0, fill, true, -1, true)
				draw_circle(Vector2(x, y), d / 2.0, ink, false, 2.0, true)
				x += d + 6.0
			if t == "blue":
				var cx := x - d / 2.0 + 4.0
				draw_circle(Vector2(cx, y - 3), 1.6, ink, true, -1, true)
				draw_circle(Vector2(cx, y + 3), 1.6, ink, true, -1, true)
				x += 14.0


## 팀 깃발 (시안 ResultCtrlWin): 위는 네모, 아래는 뾰족. 세로 줄무늬 + 잉크 외곽선 + 못 2 (+ 밧줄)
class Pennant extends PanelContainer:
	var col := Color(0.24, 0.44, 0.84):
		set(v):
			col = v
			queue_redraw()
	var ropes := false
	var tilt := 0.0
	var top_pad := 22.0:
		set(v):
			top_pad = v
			_pad()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pad()
		resized.connect(queue_redraw)

	func _pad() -> void:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_top = top_pad
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_bottom = top_pad * 1.6
		add_theme_stylebox_override("panel", sb)

	func _shape(o: Vector2) -> PackedVector2Array:
		var w := size.x
		var h := size.y
		return PackedVector2Array([o, o + Vector2(w, 0), o + Vector2(w, h * 0.62), o + Vector2(w / 2.0, h), o + Vector2(0, h * 0.62)])

	func _draw() -> void:
		var P: Dictionary = GameData.RESULT_UI.pennant
		var K: Dictionary = GameData.UI_KIT
		draw_set_transform(size / 2.0, deg_to_rad(tilt), Vector2.ONE)
		var o := -size / 2.0
		if ropes:
			for x: float in [size.x * 0.3, size.x * 0.7]:
				draw_line(o + Vector2(x, -60.0), o + Vector2(x, 6), GameData.col(0xc9a46a), 4.0, true)
				draw_line(o + Vector2(x, -60.0), o + Vector2(x, 6), UiKit.c("ink", 0.5), 1.0, true)
		draw_colored_polygon(_shape(o + Vector2(0, 5)), UiKit.c("ink", 0.35))
		var sh := _shape(o)
		draw_colored_polygon(sh, col)
		var n: int = P.stripes
		var sw := size.x / (n * 2)
		for i in n:
			var st := PackedVector2Array([o + Vector2(sw * (i * 2 + 1), 0), o + Vector2(sw * (i * 2 + 2), 0), o + Vector2(sw * (i * 2 + 2), size.y), o + Vector2(sw * (i * 2 + 1), size.y)])
			for poly in Geometry2D.intersect_polygons(st, sh):
				draw_colored_polygon(poly, col.lightened(0.08))
		var ol := sh.duplicate()
		ol.append(sh[0])
		draw_polyline(ol, UiKit.c("ink"), float(K.wood.line) if K.has("wood") else 3.0, true)
		UiKit.draw_nail(self, o + Vector2(18, 14))
		UiKit.draw_nail(self, o + Vector2(size.x - 18, 14))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 점수판 줄 (위에서부터 차례로): VBox 바로 아래에 있는 줄·팀 이름
func _table_rows() -> Array[Control]:
	var out: Array[Control] = []
	for n in _end_table.find_children("*", "", true, false):
		if n is Control and not n is VBoxContainer and n.get_parent() is VBoxContainer:
			out.append(n)
	return out


## 지연 delay초(실제 시간) 뒤에 시작하는 Tween 한 줄 — 느린 화면과 상관없이 흐른다
func _track(delay: float) -> Tween:
	var t := create_tween().set_ignore_time_scale(true)
	if delay > 0:
		t.tween_interval(delay)
	_fx_tweens.append(t)
	return t


func _play_end_fx(res: String, cols: Array) -> void:
	var R: Dictionary = GameData.RESULT
	var win := res == "victory"
	_fx_on = true
	Music.stop_bgm(float(R.bgm_out))
	_end_card.modulate.a = 0.0
	_end_sub.modulate.a = 0.0
	var rows := _table_rows()
	for r in rows:
		r.modulate.a = 0.0
	for b in _end_btns:
		b.modulate.a = 0.0
		b.disabled = true
	var drop := float(R.drop_from)
	if win:
		# 0.0초: 느린 화면 0.6초 (실제 시간)
		_slowmo = true
		Engine.time_scale = float(R.slowmo)
		_track(float(R.slowmo_t)).tween_callback(func() -> void:
			_slowmo = false
			Engine.time_scale = 1.0)
		# 0.3초: 제목 판이 떨어져 통통 → 좌우로 흔들
		var t := _track(float(R.drop_at))
		t.tween_callback(func() -> void:
			_end_card.position.y = -drop
			_end_card.modulate.a = 1.0)
		t.tween_property(_end_card, "position:y", 0.0, float(R.drop_t)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		for a: float in R.wobble:
			t.tween_property(_end_card, "rotation_degrees", a, float(R.wobble_t)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 0.5초: 효과음 + 햇살 + 색종이
		var f := _track(float(R.fx_at))
		f.tween_callback(func() -> void:
			_play_stinger("victory")
			_sun.center_of = _title_box()
			_sun.modulate.a = 0.0
			_sun.visible = true
			_confetti(cols))
		f.tween_property(_sun, "modulate:a", 1.0, 0.4)
	else:
		# 0.0초: 배경이 회색으로
		_end_gray.visible = true
		_end_gray.material.set("shader_parameter/amount", 0.0)
		_track(0.0).tween_property(_end_gray.material, "shader_parameter/amount", 1.0, float(R.gray_t))
		# 0.3초: 툭 떨어져서 못 하나가 빠지고 기울어짐 (왼쪽 못에 매달림)
		for n in _end_nails:
			n.visible = true
			n.modulate.a = 1.0
		var t := _track(float(R.drop_at))
		t.tween_callback(func() -> void:
			_end_card.pivot_offset = _end_nails[0].position + _end_nails[0].size / 2
			_end_card.position.y = -drop
			_end_card.modulate.a = 1.0)
		t.tween_property(_end_card, "position:y", 0.0, float(R.fall_t)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(_drop_nail)
		t.tween_property(_end_card, "rotation_degrees", float(R.tilt_deg), float(R.tilt_t)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		# 0.5초: 효과음
		_track(float(R.fx_at)).tween_callback(func() -> void: _play_stinger("defeat"))
		# 0.6초: 먹구름이 내려오고 비
		var r := _track(float(R.rain_at))
		r.tween_callback(func() -> void:
			_clouds.oy = -240.0
			_clouds.visible = true
			_rain())
		r.tween_property(_clouds, "oy", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 1.4초: 점수판 한 줄씩 → 버튼
	var at := float(R.rows_at)
	_track(at).tween_property(_end_sub, "modulate:a", 1.0, float(R.row_t))
	for i in rows.size():
		var row: Control = rows[i]
		var rt := _track(at + i * float(R.row_gap))
		rt.tween_callback(func() -> void:
			row.pivot_offset = row.size / 2
			row.scale = Vector2(1, 0.2))
		rt.tween_property(row, "modulate:a", 1.0, float(R.row_t))
		rt.parallel().tween_property(row, "scale", Vector2.ONE, float(R.row_t)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bt := _track(at + rows.size() * float(R.row_gap) + float(R.row_t))
	bt.tween_callback(func() -> void:
		for b in _end_btns:
			b.disabled = false)
	for b in _end_btns:
		bt.parallel().tween_property(b, "modulate:a", 1.0, float(R.btn_t))


## 패배: 오른쪽 못이 빠져 떨어짐
func _drop_nail() -> void:
	var n := _end_nails[1]
	var t := _track(0.0)
	t.tween_property(n, "position:y", n.position.y + 280.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(n, "modulate:a", 0.0, 0.5)


func _play_stinger(s: String) -> void:
	_stinger_on = true
	Sfx.play_stinger(s)


## 효과음이 끝나면 메뉴 곡을 다시 키움 (결과 화면에 있을 때만)
func _on_stinger_done(_s: String) -> void:
	if not _stinger_on:
		return
	_stinger_on = false
	if _fx_on and (screens.end as Control).visible:
		Music.play_bgm("menu", float(GameData.RESULT.bgm_back))


## 결과 화면을 떠나거나 다시 열 때: 입자·Tween·느린 화면·효과음을 다 되돌림
func _end_fx_reset() -> void:
	for t in _fx_tweens:
		if t and t.is_valid():
			t.kill()
	_fx_tweens.clear()
	for n in _fx_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_fx_nodes.clear()
	if _fx_on or _slowmo:
		Engine.time_scale = 1.0
	_slowmo = false
	if _stinger_on:
		Sfx.stop_stinger()
	_stinger_on = false
	_fx_on = false
	_end_gray.visible = false
	_sun.visible = false
	_clouds.visible = false
	_clouds.oy = 0.0
	_end_card.position = Vector2.ZERO
	_end_card.rotation = 0.0
	_end_card.modulate = Color.WHITE
	for n in _end_nails:
		n.modulate = Color.WHITE
	_end_sub.modulate = Color.WHITE
	for r in _table_rows():
		r.modulate = Color.WHITE
		r.scale = Vector2.ONE
	for b in _end_btns:
		b.disabled = false
		b.modulate = Color.WHITE


func _add_fx(n: Node) -> void:
	_end_front.add_child(n)
	_fx_nodes.append(n)


func _rect_tex(w: int, h: int, col: Color) -> ImageTexture:
	var k := "%d_%d_%s" % [w, h, col.to_html()]
	if not _tex_cache.has(k):
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(col)
		_tex_cache[k] = ImageTexture.create_from_image(img)
	return _tex_cache[k]


## 승리 색종이: 제목 판 뒤에서 팡 터지는 것 + 위에서 팔랑팔랑 떨어지는 것. cols가 비면 개인전 색
func _confetti(cols: Array) -> void:
	var R: Dictionary = GameData.RESULT
	var vp := get_viewport().get_visible_rect().size
	var pal: Array = cols.duplicate()
	if pal.is_empty():
		for h: int in R.confetti:
			pal.append(GameData.col(h))
	var ramp := Gradient.new()  # 색을 섞지 않고 한 색씩 무작위로
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in pal.size():
		offs.append(float(i) / pal.size())
		cs.append(pal[i])
	ramp.offsets = offs
	ramp.colors = cs
	var tex := _rect_tex(10, 6, Color.WHITE)
	var burst := CPUParticles2D.new()
	burst.texture = tex
	burst.amount = int(R.burst)
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 3.5
	burst.position = _title_box().get_global_rect().get_center()
	burst.direction = Vector2(0, -1)
	burst.spread = 75.0
	burst.initial_velocity_min = 380.0
	burst.initial_velocity_max = 820.0
	burst.gravity = Vector2(0, 700)
	burst.damping_min = 60.0
	burst.damping_max = 120.0
	burst.angle_min = -180.0
	burst.angle_max = 180.0
	burst.angular_velocity_min = -540.0
	burst.angular_velocity_max = 540.0
	burst.scale_amount_min = 0.8
	burst.scale_amount_max = 1.5
	burst.color_initial_ramp = ramp
	burst.emitting = true
	_add_fx(burst)
	var fall := CPUParticles2D.new()
	fall.texture = tex
	fall.amount = int(R.fall)
	fall.lifetime = 4.0
	fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fall.emission_rect_extents = Vector2(vp.x / 2, 10)
	fall.position = Vector2(vp.x / 2, -20)
	fall.direction = Vector2(0, 1)
	fall.spread = 20.0
	fall.initial_velocity_min = 90.0
	fall.initial_velocity_max = 180.0
	fall.gravity = Vector2(0, 40)
	fall.angle_min = -180.0
	fall.angle_max = 180.0
	fall.angular_velocity_min = -360.0
	fall.angular_velocity_max = 360.0
	fall.scale_amount_min = 0.8
	fall.scale_amount_max = 1.4
	fall.color_initial_ramp = ramp
	fall.emitting = true
	_add_fx(fall)
	_track(float(R.fall_for)).tween_callback(func() -> void:
		if is_instance_valid(fall):
			fall.emitting = false)


## 패배 비: 위에서 비스듬히 쏟아지는 빗줄기
func _rain() -> void:
	var vp := get_viewport().get_visible_rect().size
	var rain := CPUParticles2D.new()
	rain.texture = _rect_tex(2, 26, Color(0.75, 0.82, 1.0, 0.55))
	rain.amount = int(GameData.RESULT.rain)
	rain.lifetime = 0.9
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(vp.x * 0.65, 10)
	rain.position = Vector2(vp.x / 2, -30)
	rain.direction = Vector2(0.18, 1).normalized()
	rain.spread = 2.0
	rain.initial_velocity_min = 1100.0
	rain.initial_velocity_max = 1350.0
	rain.gravity = Vector2.ZERO
	rain.particle_flag_align_y = true
	rain.emitting = true
	_add_fx(rain)


## 승리 뒤 금빛 햇살: 제목 판 뒤에서 천천히 도는 반투명 줄무늬
class Sunburst extends Control:
	var center_of: Control
	var ang := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		if not visible:
			return
		ang += float(GameData.RESULT.ray_spin) * dt / maxf(Engine.time_scale, 0.01)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		if center_of and center_of.is_inside_tree():
			c = center_of.get_global_rect().get_center() - get_global_rect().position
		var r := size.length()
		var n := int(GameData.RESULT.rays)
		var col := UiKit.c("marker", float(GameData.RESULT.ray_alpha))
		for i in n:
			var a0 := ang + TAU * i / n
			var a1 := a0 + TAU / n * 0.5
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r]), col)
		for k in 5:  # 가운데 은은한 빛
			draw_circle(c, 240.0 - k * 44.0, UiKit.c("marker", 0.05))


## 패배 먹구름: 위쪽에 겹친 동그라미 구름이 천천히 흔들림
class Clouds extends Control:
	var t := 0.0
	var oy := 0.0  # 내려오는 중 (위로 밀린 px) — 꽉 찬 앵커라 position 대신 그릴 때 밀어 줌
	const PUFFS := [[-60, 10, 46], [-20, -14, 58], [30, -4, 52], [72, 14, 40], [4, 24, 50]]

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		if not visible:
			return
		t += dt
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		for layer in 2:
			var col := Color(0.27, 0.28, 0.34, 0.9) if layer == 0 else Color(0.15, 0.16, 0.21, 0.95)
			for i in 7:
				var x := w * (i + 0.5) / 7.0 + sin(t * 0.4 + i * 1.7) * 18.0 + layer * 40.0
				var y := 20.0 + (i % 2) * 26.0 + layer * 18.0 + oy
				var s := 1.0 + (i % 3) * 0.2
				for p: Array in PUFFS:
					draw_circle(Vector2(x + float(p[0]) * s, y + float(p[1]) * s), float(p[2]) * s, col)


# ── 화면 전환 ────────────────────────────────────────────────
func show_screen(id: String) -> void:
	if id != "end" and _fx_on:  # 결과 화면을 떠나면 연출을 다 되돌림
		_end_fx_reset()
	for k: String in screens:
		(screens[k] as Control).visible = k == id


func show_page(id: String) -> void:
	for k: String in pages:
		(pages[k] as Control).visible = k == id
	# 메인은 자기 배경(왼쪽만 어둡게)을 쓰고, 나머지 페이지는 화면 전체 그늘
	((screens.menu as Control).get_meta("bg") as Control).visible = not FULL_PAGES.has(id)
	if id == "main" and cur_page != "main":
		_roll_tip()
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
		var back := {"diff": "main", "mode": "diff", "class": "mode", "settings": "main", "friend": "main"}
		if back.has(cur_page):
			get_viewport().set_input_as_handled()
			show_page(back[cur_page])


# ── 아래쪽 알림 상자 (HTML #toast) ───────────────────────────
## 아래 가운데 작은 양피지 쪽지 (못 1). 나타날 때 위에서 살짝 떨어지며 못에 매달린 듯 흔들림
var _toast_tw: Tween


func _build_toast() -> void:
	var TU: Dictionary = GameData.PAGE_UI.toast
	var bd := UiKit.Board.new("parch", TU.pad)
	bd.nails = 1
	_toast = bd
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_l = UiKit.label("", int(TU.font), UiKit.c("ink"), _toast)
	UiKit.trim_font(_toast_l, int(TU.font), 0.15)
	_toast.modulate.a = 0.0
	add_child(_toast)


func toast(text: String) -> void:
	_toast_l.text = text
	_toast.reset_size()
	var fresh := _toast_t <= 0.0
	_toast_t = GameData.TOAST_T
	if fresh:  # 새로 뜰 때만 흔들 (떠 있는 동안 글자만 바뀌면 그대로)
		var TU: Dictionary = GameData.PAGE_UI.toast
		if _toast_tw:
			_toast_tw.kill()
		_toast_tw = create_tween().set_ignore_time_scale(true)
		_toast.rotation_degrees = 0.0
		for a: float in TU.wobble:
			_toast_tw.tween_property(_toast, "rotation_degrees", a, float(TU.wobble_t)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(dt: float) -> void:
	if _crowd:  # 메인 메뉴가 안 보이면 병과 무리는 그리지도 움직이지도 않음
		_crowd.set_active((pages.main as Control).is_visible_in_tree())
	if _class_stage:  # 병과 화면 큰 액자도 보일 때만
		_class_stage.set_active((pages["class"] as Control).is_visible_in_tree())
	if _end_stage:  # 결과 화면 무대도
		_end_stage.set_active((screens.end as Control).visible)
	_toast_t = maxf(0.0, _toast_t - dt)
	# 0.2초 동안 위에서 살짝 떨어지며 나타나고(못 자리를 축으로 흔들림), 끝나면 같은 식으로 사라진다
	var TU: Dictionary = GameData.PAGE_UI.toast
	_toast.modulate.a = move_toward(_toast.modulate.a, 1.0 if _toast_t > 0 else 0.0, dt / 0.2)
	_toast.visible = _toast.modulate.a > 0.001
	var area := _toast.get_parent_area_size()
	var k := 1.0 - _toast.modulate.a
	_toast.position = Vector2((area.x - _toast.size.x) / 2, area.y - float(TU.bottom) - _toast.size.y - float(TU.drop) * k * k)
	_toast.pivot_offset = Vector2(_toast.size.x / 2.0, 4.0)
