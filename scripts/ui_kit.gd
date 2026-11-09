class_name UiKit
extends RefCounted
## 메뉴·HUD 공용 UI 조각 — HTML CSS(.panel / .primary / .ghost / .back / .navbtn / .card / .diff / table.score)를
## Godot Control로 옮긴 것. 색은 GameData.UI.

static var _icons := {}

## 병과 아이콘 (HTML ICONS의 SVG 그대로)
const ICONS := {
	"barbarian": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M9 25c-1-6 4-12 11-13 7-1 12 3 12 9 0 7-6 11-13 11-6 0-9-3-10-7z" fill="#fbf1dc"/><path d="M14 20c2-2 5-3 8-3" stroke="#161a33" stroke-width="2" fill="none" stroke-linecap="round"/></svg>',
	"archer": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M14 5c13 6 13 24 0 30" stroke="#fbf1dc" stroke-width="3.5" fill="none" stroke-linecap="round"/><path d="M14 5v30" stroke="#fbf1dc" stroke-width="1.5"/><path d="M8 20h26M30 16l5 4-5 4" stroke="#fbf1dc" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
	"crossbow": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M6 14c8-6 20-6 28 0" stroke="#fbf1dc" stroke-width="3.5" fill="none" stroke-linecap="round"/><path d="M20 9v26" stroke="#fbf1dc" stroke-width="5" stroke-linecap="round"/><path d="M6 14l14 6 14-6" stroke="#fbf1dc" stroke-width="1.5" fill="none"/></svg>',
	"cleric": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M16 5h8v4l-1 1v5c5 2 8 6 8 11 0 6-5 9-11 9s-11-3-11-9c0-5 3-9 8-11v-5l-1-1z" fill="#fbf1dc"/><path d="M20 20v11M15.5 24.5h9" stroke="#6b45a8" stroke-width="2.6" stroke-linecap="round"/></svg>',
}


static func c(key: String, a := 1.0) -> Color:
	var col := GameData.col(GameData.UI[key])
	col.a = a
	return col


static func ink(a: float) -> Color:
	return Color(22 / 255.0, 26 / 255.0, 51 / 255.0, a)


static func box(bg: Color, border := Color.TRANSPARENT, bw := 0, radius := 6, pad := Vector4(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.anti_aliasing = true
	return sb


## 아래로 단단한 그림자 (CSS box-shadow: 0 Npx 0 색)
static func drop(sb: StyleBoxFlat, col: Color, y: float) -> StyleBoxFlat:
	sb.shadow_color = col
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, y - 1)
	return sb


## HUD 판 (HTML .panel)
static func panel_box(pad := Vector4(16, 6, 16, 6)) -> StyleBoxFlat:
	return drop(box(ink(0.78), c("gold", 0.35), 1, 6, pad), Color(10 / 255.0, 12 / 255.0, 28 / 255.0, 0.35), 4)


static func label(text: String, size: int, col: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l


## 글자 그림자 (CSS text-shadow: 0 Ypx 0 색)
static func shadow(l: Control, col: Color, y: int, outline := 0) -> void:
	l.add_theme_color_override("font_shadow_color", col)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", y)
	l.add_theme_constant_override("shadow_outline_size", outline)


## <b>처럼 금색 강조가 들어가는 한 줄 — [color]·[font_size] BBCode로 쓴다
static func rich(size: int, col: Color, parent: Node = null) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", col)
	if parent:
		parent.add_child(r)
	return r


static func gold(text: String, size := 0) -> String:
	var s := "[color=#%s]%s[/color]" % [c("gold").to_html(false), text]
	return "[font_size=%d]%s[/font_size]" % [size, s] if size > 0 else s


static func esc(s: String) -> String:
	return s.replace("[", "[lb]")


static func _style_button(b: Button, n: StyleBox, h: StyleBox, p: StyleBox, fg: Color, fg_h := Color.TRANSPARENT) -> void:
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", n)
	for k in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_hover_color", fg_h if fg_h.a > 0 else fg)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE


## 금색 큰 버튼 (HTML .primary)
static func primary(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	var pad := Vector4(40, 12, 40, 12)
	var n := drop(box(c("gold"), Color.TRANSPARENT, 0, 8, pad), c("gold_deep"), 5)
	var h := drop(box(c("gold").lightened(0.06), Color.TRANSPARENT, 0, 8, pad), c("gold_deep"), 5)
	var p := drop(box(c("gold"), Color.TRANSPARENT, 0, 8, Vector4(40, 15, 40, 9)), c("gold_deep"), 1)
	_style_button(b, n, h, p, c("ink"))
	return b


## 테두리 버튼 (HTML .ghost, 크기만 다른 .back)
static func ghost(text: String, size := 19, pad := Vector4(22, 10, 22, 10)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var n := box(ink(0.85), c("line"), 2, 8, pad)
	var h := box(ink(0.85), c("gold"), 2, 8, pad)
	_style_button(b, n, h, h, c("parch"))
	return b


static func back(text := "← 뒤로") -> Button:
	return ghost(text, 17, Vector4(16, 8, 16, 8))


## 눌러지는 판 — 안에 여러 줄을 넣을 수 있는 버튼 (HTML .navbtn / .card / .diff)
class Tap extends PanelContainer:
	signal pressed
	var n_box: StyleBox
	var h_box: StyleBox
	var on_box: StyleBox
	var on := false
	var bar_col := Color.TRANSPARENT  # 위쪽 색 띠 (난이도 카드)

	func _init(n: StyleBox, h: StyleBox, o: StyleBox = null) -> void:
		n_box = n
		h_box = h
		on_box = o if o else h
		add_theme_stylebox_override("panel", n_box)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: _restyle(true))
		mouse_exited.connect(func() -> void: _restyle(false))

	func set_on(v: bool) -> void:
		on = v
		_restyle(false)

	func _restyle(hover: bool) -> void:
		add_theme_stylebox_override("panel", on_box if on else (h_box if hover else n_box))

	func _draw() -> void:
		if bar_col.a > 0:
			draw_rect(Rect2(2, 2, size.x - 4, 6), bar_col)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			accept_event()
			pressed.emit()

	## 안쪽 것들이 마우스를 가로채지 않게 (다 넣은 뒤 부른다)
	func seal() -> void:
		_ignore(self)

	func _ignore(n: Node) -> void:
		for ch in n.get_children():
			if ch is Control:
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ignore(ch)


## 메인 메뉴 버튼: 왼쪽 큰 글자 + 오른쪽 작은 글자 (HTML .navbtn / .hero / .soon / .sub)
static func navbtn(title: String, small: String, kind := "") -> Tap:
	var hero := kind == "hero"
	var sub := kind == "sub"
	var pad := Vector4(24, 18, 24, 18) if hero else (Vector4(16, 11, 16, 11) if sub else Vector4(22, 14, 22, 14))
	var n: StyleBoxFlat
	var h: StyleBoxFlat
	if hero:
		n = drop(box(c("gold"), c("gold"), 2, 10, pad), c("gold_deep"), 5)
		h = drop(box(c("gold").lightened(0.06), c("gold"), 2, 10, pad), c("gold_deep"), 5)
	else:
		n = box(ink(0.88), c("line"), 2, 10, pad)
		h = box(ink(0.88), c("gold"), 2, 10, pad)
	var t := Tap.new(n, h)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	t.add_child(hb)
	var fg := c("ink") if hero else c("parch")
	var big := label(title, 32 if hero else (21 if sub else 26), fg, hb)
	if kind == "soon":
		big.modulate.a = 0.8
	if sub:
		big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if small != "":
		var sm := label(small, 13, c("ink", 0.75) if hero else c("mute"))
		if kind == "soon":  # 준비 중 꼬리표
			var tag := PanelContainer.new()
			tag.add_theme_stylebox_override("panel", box(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 0, 4, Vector4(8, 2, 8, 2)))
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tag.add_child(sm)
			hb.add_child(tag)
		else:
			sm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(sm)
	t.seal()
	return t


static func icon(cls: String) -> Texture2D:
	if not _icons.has(cls):
		var img := Image.new()
		img.load_svg_from_string(ICONS[cls], 2.0)
		_icons[cls] = ImageTexture.create_from_image(img)
	return _icons[cls]


## 병과 동그라미 + 아이콘 (HTML .emb)
static func emblem(cls: String, d: float) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(GameData.col(GameData.CLASS_EMBLEM[cls]), Color.TRANSPARENT, 0, int(d / 2)))
	p.custom_minimum_size = Vector2(d, d)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tr := TextureRect.new()
	tr.texture = icon(cls)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(d, d) * 0.63
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(tr)
	return p


## 병과 카드 (HTML renderCards). mini면 설명·능력치 없이 작게 (일시정지 화면)
static func class_card(cls: String, index: int, mini: bool) -> Tap:
	var C: Dictionary = GameData.CLASSES[cls]
	var pad := Vector4(12, 12, 12, 12) if mini else Vector4(16, 16, 16, 14)
	var t := Tap.new(box(ink(0.88), c("line"), 2, 8, pad), box(ink(0.88), GameData.col(0x5a64a6), 2, 8, pad),
		drop(box(Color(40 / 255.0, 36 / 255.0, 48 / 255.0, 0.94), c("gold"), 2, 8, pad), Color(185 / 255.0, 122 / 255.0, 20 / 255.0, 0.45), 6))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	t.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	top.add_child(emblem(cls, 42 if mini else 54))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tv)
	label(C.name, 22 if mini else 28, c("parch"), tv)
	var wp := label("%s · 체력 %d · 속도 %.2f배" % [GameData.WEAPONS[C.weapon].name, int(C.get("hp", 100)), float(C.speed)], 13, c("mute"), tv)
	wp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var num := label(str(index + 1), 14, c("mute"), top)
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not mini:
		var desc := label(C.desc, 14, c("parch"), vb)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 150
		desc.add_theme_constant_override("line_spacing", 4)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 12)
		g.add_theme_constant_override("v_separation", 5)
		vb.add_child(g)
		var pips: Array = C.pips
		for j in GameData.STAT_LABELS.size():
			label(GameData.STAT_LABELS[j], 12, c("mute"), g)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.add_child(row)
			for n in 5:
				var pip := Panel.new()
				pip.custom_minimum_size = Vector2(0, 8)
				pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pip.add_theme_stylebox_override("panel", box(c("gold") if n < int(pips[j]) else Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, 2))
				row.add_child(pip)
	t.seal()
	return t


## 난이도 카드 (HTML renderDiffs: 위에 색 띠, 해골, 이름, 설명)
static func diff_card(key: String) -> Tap:
	var D: Dictionary = GameData.DIFF[key]
	var dc := GameData.col(D.color)
	var pad := Vector4(18, 20, 18, 18)
	var t := Tap.new(box(ink(0.9), c("line"), 2, 10, pad), box(ink(0.9), dc, 2, 10, pad))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	t.add_child(vb)
	var sk := label(D.skulls, 15, dc, vb)
	sk.add_theme_constant_override("outline_size", 0)
	label(D.name, 34, c("parch"), vb)
	var p := label(D.desc, 14, c("mute"), vb)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size.x = 180
	p.add_theme_constant_override("line_spacing", 4)
	t.bar_col = dc  # 위쪽 색 띠 (::before)
	t.seal()
	return t


## 점수판 (HTML scoreTable): 순위, 이름+병과 꼬리표, 처치, 죽음. 내 줄은 금색
static func score_table(rows: Array, me: Object) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_row(vb, ["", "이름", "처치", "죽음"], null, true, false)
	for i in rows.size():
		_score_row(vb, [str(i + 1), rows[i].ent_name, str(rows[i].kills), str(rows[i].deaths)], rows[i].cls, false, rows[i] == me)
	return vb


static func _score_row(parent: Control, cells: Array, cls: Variant, head: bool, me: bool) -> void:
	var pc := PanelContainer.new()
	var sb := box(Color.TRANSPARENT, c("line") if head else Color(61 / 255.0, 70 / 255.0, 128 / 255.0, 0.45), 0, 0,
		Vector4(8, 4, 8, 4) if head else Vector4(8, 6, 8, 6))
	sb.border_width_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	pc.add_child(hb)
	var fg := c("mute") if head else (c("gold") if me else c("parch"))
	var sz := 12 if head else 14
	var rk := label(cells[0], sz, c("mute"), hb)
	rk.custom_minimum_size.x = 24
	var name_box := HBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 6)
	hb.add_child(name_box)
	label(cells[1], sz, fg, name_box)
	if cls != null:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", box(GameData.col(GameData.CLASS_CHIP[cls]), Color.TRANSPARENT, 0, 3, Vector4(6, 1, 6, 1)))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label(GameData.CLASSES[cls].name, 11, c("ink"), chip)
		name_box.add_child(chip)
	for k in [2, 3]:
		var n := label(cells[k], sz, fg, hb)
		n.custom_minimum_size.x = 48
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
