class_name SettingsPanel
extends VBoxContainer
## 설정 화면 본문 (scenes/ui/settings_panel.tscn) — 메인 메뉴 '설정'과 일시정지 '설정'이 같이 쓴다.
## 마우스 감도·시점(HTML .sens·.seg) + 그래픽 품질(낮음·보통·높음) + 볼륨 세 개(전체·배경음악·효과음) + 조작키 목록.
## 바꾸면 바로 GameData에 넣고 user://settings.cfg에 저장한다. 볼륨은 바로 버스에 반영돼 미리 들어볼 수 있다.
## 화면에 보일 때마다 GameData에서 다시 읽는다 (다른 패널이나 V키로 바뀌었을 수 있어서).
## 모양: 마을 게시판 — 나무판(쇠못 4개)에 양피지 쪽지를 핀으로 붙임. 숫자 있는 쪽지는 안 기울인다.

@export var show_keys := true

const VOL_ROWS := [["master", "전체 볼륨"], ["music", "배경음악"], ["sfx", "효과음"]]

var _sens_s: HSlider
var _sens_o: Label
var _view_btns := {}
var _gfx_btns := {}
var _vol := {}  # 키 → {s: HSlider, o: Label}
var _body: VBoxContainer  # 나무판 안쪽 (쪽지들)


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var board := UiKit.Board.new("wood", Vector4(14, 14, 14, 12))
	board.nails = 4
	add_child(board)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	board.add_child(_body)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	_body.add_child(top)
	_build_sens(top)
	_build_view(top)
	_build_gfx()
	_build_volume()
	if show_keys:
		_build_keys()
	visibility_changed.connect(refresh)
	refresh()


## GameData 값으로 슬라이더·버튼을 다시 맞춘다
func refresh() -> void:
	if not _sens_s:
		return
	_sens_s.set_value_no_signal(GameData.mouse_sens)
	_sens_o.text = "%.1f" % GameData.mouse_sens
	for k: String in _vol:
		var v: float = GameData.volumes[k]
		(_vol[k].s as HSlider).set_value_no_signal(roundf(v * 100.0))
		(_vol[k].o as Label).text = "%d%%" % roundi(v * 100.0)
	_sync_view()


## 양피지 쪽지 하나 (위 가운데 쇠못). tilt ≠ 0이면 살짝 기울여 붙인다 — 숫자 쪽지는 0
func _panel(parent: Node, pad: Vector4, tilt := 0.0) -> PanelContainer:
	var pc := UiKit.Board.new("parch", pad)
	pc.nails = 1
	if tilt != 0.0:
		var w := UiKit.tilted(pc, tilt)
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent.add_child(w)
	else:
		pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent.add_child(pc)
	return pc


func _title(text: String, parent: Node) -> Label:
	var l := UiKit.label(text, 15, UiKit.c("ink"), parent)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## 가로 슬라이더 (HTML .sens input): 어두운 나무 홈 + 형광펜으로 참 + 쇠못 손잡이
func _slider(lo: float, hi: float, step: float, w: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(w, 20)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	var track := UiKit.box(UiKit.c("wood_lo"), UiKit.c("ink"), 2, 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	var fill := UiKit.box(UiKit.c("marker"), UiKit.c("ink"), 2, 4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", UiKit.nail_icon(7.0))
	s.add_theme_icon_override("grabber_highlight", UiKit.nail_icon(8.0))
	return s


func _build_sens(parent: Node) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_panel(parent, Vector4(14, 12, 14, 8)).add_child(hb)
	_title("마우스 감도", hb)
	var R: Array = GameData.SENS_RANGE
	_sens_s = _slider(R[0], R[1], R[2], 130)
	hb.add_child(_sens_s)
	_sens_o = UiKit.label("", 15, UiKit.c("ink"), hb)
	_sens_o.custom_minimum_size.x = 34
	_sens_o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sens_s.value_changed.connect(func(v: float) -> void:
		GameData.mouse_sens = v
		GameData.save_settings()
		refresh())


## 시점 3인칭 / 1인칭 (HTML .seg) — 양피지 버튼, 고른 것 = 형광펜
func _build_view(parent: Node) -> void:
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	_panel(parent, Vector4(14, 11, 10, 7), -1.5).add_child(sh)
	_title("시점", sh)
	var gap := Control.new()
	gap.custom_minimum_size.x = 4
	sh.add_child(gap)
	for v in [["tp", "3인칭", true], ["fp", "1인칭", false]]:
		var b := UiKit.ghost(v[1], 16, Vector4(16, 6, 16, 6))
		var tp: bool = v[2]
		b.pressed.connect(func() -> void:
			GameData.third_person = tp
			GameData.save_settings()
			_sync_view())
		sh.add_child(b)
		_view_btns[v[0]] = b


## 그래픽 품질 낮음 / 보통 / 높음 (GameData.GFX — 잔디·작은 소품·그림자)
func _build_gfx() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	_panel(row, Vector4(14, 11, 10, 7), 1.0).add_child(sh)
	_title("그래픽", sh)
	var gap := Control.new()
	gap.custom_minimum_size.x = 4
	sh.add_child(gap)
	for q: String in GameData.GFX_ORDER:
		var b := UiKit.ghost(GameData.GFX[q].name, 16, Vector4(16, 6, 16, 6))
		b.pressed.connect(func() -> void:
			GameData.set_gfx(q)
			_sync_view())
		sh.add_child(b)
		_gfx_btns[q] = b


## 시점·그래픽 버튼 중 지금 것을 형광펜으로 (HTML .seg button[aria-pressed])
func _sync_view() -> void:
	for k: String in _gfx_btns:
		(_gfx_btns[k] as UiKit.KitButton).selected = k == GameData.gfx_quality
	for k: String in _view_btns:
		(_view_btns[k] as UiKit.KitButton).selected = (k == "tp") == GameData.third_person


## 볼륨 슬라이더 세 개 (0~100%) — 움직이면 바로 버스에 반영, 0%면 음소거
func _build_volume() -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panel(row, Vector4(18, 12, 18, 4)).add_child(vb)
	vb.add_child(g)
	for vr: Array in VOL_ROWS:
		var k: String = vr[0]
		var l := UiKit.label(vr[1], 15, UiKit.c("ink"), g)
		l.custom_minimum_size.x = 76
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var s := _slider(0, 100, 1, 260)
		g.add_child(s)
		var o := UiKit.label("", 15, UiKit.c("ink"), g)
		o.custom_minimum_size.x = 44
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_vol[k] = {"s": s, "o": o}
		s.value_changed.connect(func(v: float) -> void:
			GameData.set_volume(k, v / 100.0)
			GameData.save_settings()
			o.text = "%d%%" % roundi(v))
	# 한마디 (개구 — 이 화면에 한 곳만)
	var tip := UiKit.scribble("바꾸면 바로 저장돼요.", 18, UiKit.c("brown"), vb)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## 조작키 쪽지: 작은 나무 키캡 + 설명
func _build_keys() -> void:
	var keys := _panel(_body, Vector4(16, 13, 16, 9), 0.6)
	var kg := GridContainer.new()
	kg.columns = 2
	kg.add_theme_constant_override("h_separation", 18)
	kg.add_theme_constant_override("v_separation", 5)
	keys.add_child(kg)
	for kv in [["W A S D", "이동"], ["Space", "점프"], ["Shift", "달리기 · 공격하면 풀림"], ["Ctrl / C", "달리다 누르면 슬라이드, 서 있으면 앉기"],
			["클릭", "공격 · 활은 누르고 당겼다 놓기"], ["우클릭", "조준 (석궁 · 저격총)"], ["Q", "저격총 ↔ 원래 무기"], ["Tab", "점수판"],
			["V", "3인칭 ↔ 1인칭 시점"], ["Esc", "마우스 풀기 · 일시정지"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kg.add_child(cell)
		var dt := UiKit.Board.new("wood", Vector4(6, 0, 6, 0))
		dt.custom_minimum_size.x = 84
		dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var kl := UiKit.wood_text(UiKit.label(kv[0], 13, UiKit.c("cream"), dt), 13)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(dt)
		UiKit.label(kv[1], 14, UiKit.c("brown"), cell).size_flags_vertical = Control.SIZE_SHRINK_CENTER
