class_name SettingsPanel
extends VBoxContainer
## 설정 화면 본문 (scenes/ui/settings_panel.tscn) — 메인 메뉴 '설정'과 일시정지 '설정'이 같이 쓴다.
## 마우스 감도·시점(HTML .sens·.seg) + 그래픽 품질(낮음·보통·높음) + 볼륨 세 개(전체·배경음악·효과음) + 조작키 목록.
## 바꾸면 바로 GameData에 넣고 user://settings.cfg에 저장한다. 볼륨은 바로 버스에 반영돼 미리 들어볼 수 있다.
## 화면에 보일 때마다 GameData에서 다시 읽는다 (다른 패널이나 V키로 바뀌었을 수 있어서).

@export var show_keys := true

const VOL_ROWS := [["master", "전체 볼륨"], ["music", "배경음악"], ["sfx", "효과음"]]

var _sens_s: HSlider
var _sens_o: Label
var _view_btns := {}
var _gfx_btns := {}
var _vol := {}  # 키 → {s: HSlider, o: Label}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	add_child(top)
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


func _panel(parent: Node, pad: Vector4) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.ink(0.7), Color.TRANSPARENT, 0, 8, pad))
	parent.add_child(pc)
	return pc


## 금색으로 차는 가로 슬라이더 (HTML .sens input)
func _slider(lo: float, hi: float, step: float, w: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(w, 20)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	var track := UiKit.box(Color(1, 1, 1, 0.18), Color.TRANSPARENT, 0, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	var fill := UiKit.box(UiKit.c("gold"), Color.TRANSPARENT, 0, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s


func _build_sens(parent: Node) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_panel(parent, Vector4(14, 8, 14, 8)).add_child(hb)
	UiKit.label("마우스 감도", 14, UiKit.c("parch"), hb).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var R: Array = GameData.SENS_RANGE
	_sens_s = _slider(R[0], R[1], R[2], 130)
	hb.add_child(_sens_s)
	_sens_o = UiKit.label("", 14, UiKit.c("parch"), hb)
	_sens_o.custom_minimum_size.x = 34
	_sens_o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sens_s.value_changed.connect(func(v: float) -> void:
		GameData.mouse_sens = v
		GameData.save_settings()
		refresh())


## 시점 3인칭 / 1인칭 (HTML .seg)
func _build_view(parent: Node) -> void:
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	_panel(parent, Vector4(14, 6, 8, 6)).add_child(sh)
	UiKit.label("시점", 14, UiKit.c("parch"), sh).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	sh.add_child(gap)
	for v in [["tp", "3인칭", true], ["fp", "1인칭", false]]:
		var b := Button.new()
		b.text = v[1]
		b.add_theme_font_size_override("font_size", 16)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.focus_mode = Control.FOCUS_NONE
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
	add_child(row)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	_panel(row, Vector4(14, 6, 8, 6)).add_child(sh)
	UiKit.label("그래픽", 14, UiKit.c("parch"), sh).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	sh.add_child(gap)
	for q: String in GameData.GFX_ORDER:
		var b := Button.new()
		b.text = GameData.GFX[q].name
		b.add_theme_font_size_override("font_size", 16)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			GameData.set_gfx(q)
			_sync_view())
		sh.add_child(b)
		_gfx_btns[q] = b


## 시점·그래픽 버튼 중 지금 것을 금색으로 (HTML .seg button[aria-pressed])
func _sync_view() -> void:
	for k: String in _gfx_btns:
		_seg_style(_gfx_btns[k], k == GameData.gfx_quality)
	for k: String in _view_btns:
		_seg_style(_view_btns[k], (k == "tp") == GameData.third_person)


func _seg_style(b: Button, on: bool) -> void:
	var pad := Vector4(14, 6, 14, 6)
	var n := UiKit.box(UiKit.c("gold") if on else Color.TRANSPARENT, UiKit.c("gold") if on else UiKit.c("line"), 2, 6, pad)
	var h := UiKit.box(UiKit.c("gold") if on else Color(1, 1, 1, 0.05), UiKit.c("gold"), 2, 6, pad)
	UiKit._style_button(b, n, h, n, UiKit.c("ink") if on else UiKit.c("parch"))


## 볼륨 슬라이더 세 개 (0~100%) — 움직이면 바로 버스에 반영, 0%면 음소거
func _build_volume() -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 8)
	var pc := _panel(self, Vector4(18, 12, 18, 12))
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.add_child(g)
	for row: Array in VOL_ROWS:
		var k: String = row[0]
		var l := UiKit.label(row[1], 14, UiKit.c("parch"), g)
		l.custom_minimum_size.x = 76
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var s := _slider(0, 100, 1, 260)
		g.add_child(s)
		var o := UiKit.label("", 14, UiKit.c("parch"), g)
		o.custom_minimum_size.x = 44
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_vol[k] = {"s": s, "o": o}
		s.value_changed.connect(func(v: float) -> void:
			GameData.set_volume(k, v / 100.0)
			GameData.save_settings()
			o.text = "%d%%" % roundi(v))


func _build_keys() -> void:
	var keys := PanelContainer.new()
	keys.add_theme_stylebox_override("panel", UiKit.box(UiKit.ink(0.72), Color(61 / 255.0, 70 / 255.0, 128 / 255.0, 0.7), 1, 8, Vector4(18, 14, 18, 14)))
	add_child(keys)
	var kg := GridContainer.new()
	kg.columns = 2
	kg.add_theme_constant_override("h_separation", 18)
	kg.add_theme_constant_override("v_separation", 8)
	keys.add_child(kg)
	for kv in [["W A S D", "이동"], ["Space", "점프"], ["Shift", "달리기 · 공격하면 풀림"], ["Ctrl / C", "달리다 누르면 슬라이드, 서 있으면 앉기"],
			["클릭", "공격 · 활은 누르고 당겼다 놓기"], ["우클릭", "조준 (석궁 · 저격총)"], ["Q", "저격총 ↔ 원래 무기"], ["Tab", "점수판"],
			["V", "3인칭 ↔ 1인칭 시점"], ["Esc", "마우스 풀기 · 일시정지"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kg.add_child(cell)
		var dt := PanelContainer.new()
		dt.add_theme_stylebox_override("panel", UiKit.drop(UiKit.box(UiKit.c("parch"), Color.TRANSPARENT, 0, 4, Vector4(8, 3, 8, 3)), UiKit.c("gold_deep"), 2))
		dt.custom_minimum_size.x = 84
		dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var kl := UiKit.label(kv[0], 14, UiKit.c("ink"), dt)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(dt)
		UiKit.label(kv[1], 13, UiKit.c("mute"), cell).size_flags_vertical = Control.SIZE_SHRINK_CENTER
