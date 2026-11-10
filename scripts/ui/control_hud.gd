class_name ControlHud
extends Control
## 쟁탈전 HUD (Hud 아래, 쟁탈전일 때만 보임 — 사용자 요청):
##   위 가운데: "블루 1 : 0 레드" + 양쪽 % 막대 + 거점 아이콘(주인 색 + 점령 게이지 고리) + 상태 문구
##   아군 머리 위 ▼ + 이름 (벽 너머로도), 적 이름은 조준점 아래 있을 때만 (빨강)
##   거점이 화면 밖이면 가장자리에 화살표
##   죽었을 때 다음 부활 병과 고르기 (숫자키 1~5 또는 클릭)

var hud: Hud
var mode: ControlMode
var _score: RichTextLabel
var _bar := {}      # team → ProgressBar
var _pct := {}      # team → Label
var _status: Label
var _icon: Control
var _cls_row: HBoxContainer
var _cls_btns := {}
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var top := VBoxContainer.new()
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_top = 10
	top.offset_left = -260
	top.offset_right = 260
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_score = UiKit.rich(22, Hud.PARCH, top)
	UiKit.shadow(_score, Color(0, 0, 0, 0.7), 1, 2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	for team: String in ["blue", "red"]:
		if team == "red":
			_icon = PointIcon.new()
			_icon.custom_minimum_size = Vector2(54, 54)
			row.add_child(_icon)
		var col := Color(str(GameData.MODES.control.teams[team].ui))
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var pl := UiKit.label("0%", 18, col)
		UiKit.shadow(pl, Color(0, 0, 0, 0.7), 1, 2)
		var b := ProgressBar.new()
		b.show_percentage = false
		b.custom_minimum_size = Vector2(150, 14)
		b.max_value = 100
		b.fill_mode = ProgressBar.FILL_END_TO_BEGIN if team == "blue" else ProgressBar.FILL_BEGIN_TO_END
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.45)
		bg.set_corner_radius_all(4)
		bg.border_color = Color(col, 0.7)
		bg.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(4)
		b.add_theme_stylebox_override("background", bg)
		b.add_theme_stylebox_override("fill", fill)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if team == "blue":
			box.add_child(pl)
			box.add_child(b)
		else:
			box.add_child(b)
			box.add_child(pl)
		_bar[team] = b
		_pct[team] = pl
	_status = UiKit.label("", 16, Hud.GOLD, top)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.shadow(_status, Color(0, 0, 0, 0.75), 1, 2)
	# 죽었을 때 병과 바꾸기 (사망 화면 아래)
	_cls_row = HBoxContainer.new()
	_cls_row.anchor_left = 0.5
	_cls_row.anchor_right = 0.5
	_cls_row.anchor_top = 0.45
	_cls_row.anchor_bottom = 0.45
	_cls_row.offset_left = -330
	_cls_row.offset_right = 330
	_cls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cls_row.add_theme_constant_override("separation", 8)
	add_child(_cls_row)
	for i in GameData.CLASS_ORDER.size():
		var k: String = GameData.CLASS_ORDER[i]
		var b := UiKit.ghost("%d %s" % [i + 1, GameData.CLASSES[k].name], 15, Vector4(12, 6, 12, 6))
		b.pressed.connect(func() -> void: pick_class(k))
		_cls_row.add_child(b)
		_cls_btns[k] = b
	_cls_row.visible = false


## 다음 부활 병과 (쟁탈전은 죽어 있는 동안 바꿀 수 있음)
func pick_class(k: String) -> void:
	if hud.player == null:
		return
	hud.player.next_cls = k
	GameData.chosen_cls = k
	GameData.save_settings()
	if hud.combat and hud.combat.mp():  # 친구대전: 대기실 병과도 같이
		hud.combat.net.cls = k
		hud.combat.net.send_info()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or hud.player == null or hud.player.alive:
		return
	for n in GameData.CLASS_ORDER.size():
		if event.is_action_pressed("class_%d" % (n + 1)):
			get_viewport().set_input_as_handled()
			pick_class(GameData.CLASS_ORDER[n])
			return


func _process(_dt: float) -> void:
	if mode == null:
		return
	var T: Dictionary = GameData.MODES.control.teams
	_score.text = "[center][color=%s]블루[/color] %s : %s [color=%s]레드[/color]  [font_size=13][color=#b8b5cc]라운드 %d[/color][/font_size][/center]" % [
		T.blue.ui, UiKit.gold(str(mode.wins.blue), 26), UiKit.gold(str(mode.wins.red), 26), T.red.ui, mode.round_no]
	for team: String in ["blue", "red"]:
		(_bar[team] as ProgressBar).value = mode.pct[team]
		(_pct[team] as Label).text = "%d%%" % mode.pct[team]
	_status.text = mode.status_text()
	_status.add_theme_color_override("font_color", Hud.BLOOD if mode.contested or mode.overtime else Hud.GOLD)
	(_icon as PointIcon).mode = mode
	_icon.queue_redraw()
	var e := hud.player
	_cls_row.visible = e != null and not e.alive and not e.spectating and mode.phase != "over"
	if _cls_row.visible:
		var nc := e.next_cls if e.next_cls != "" else e.cls
		for k: String in _cls_btns:
			(_cls_btns[k] as Button).modulate = Hud.GOLD if k == nc else Color.WHITE
	queue_redraw()


func _cam() -> Camera3D:
	return get_viewport().get_camera_3d()


func _draw() -> void:
	if mode == null or hud.player == null or hud.combat == null:
		return
	var cam := _cam()
	if cam == null:
		return
	var me := hud.player
	var center := size / 2
	var T: Dictionary = GameData.MODES.control.teams
	var mh := float(GameData.MODES.control.marker_h)
	for e in hud.combat.ents:
		if e == me or not e.alive or e.team == "":
			continue
		var head := e.global_position + Vector3(0, mh, 0)
		if cam.is_position_behind(head):
			continue
		var sp := cam.unproject_position(head)
		if e.team == me.team:  # 아군: ▼ + 이름 (벽 너머로도)
			var col := Color(str(T[e.team].ui))
			var tri := PackedVector2Array([sp + Vector2(-7, -8), sp + Vector2(7, -8), sp + Vector2(0, 2)])
			draw_colored_polygon(tri, col)
			_text(sp + Vector2(0, -14), e.ent_name, 13, col)
		else:  # 적: 조준점 근처에 있고 보일 때만 이름
			if cam.is_position_behind(e.global_position + Vector3(0, 1.0, 0)):
				continue
			var bs := cam.unproject_position(e.global_position + Vector3(0, 1.0, 0))
			var d := maxf(1.0, cam.global_position.distance_to(e.global_position))
			var r := clampf(900.0 / d, 18.0, 120.0)
			if _seg_dist(center, sp, bs) < r * 0.5 and hud.combat.los(cam.global_position, e.global_position + Vector3(0, 1.4, 0)):
				_text(sp + Vector2(0, -6), e.ent_name, 14, Color(str(T[e.team].ui)))
	# 거점이 화면 밖이면 가장자리 화살표
	var cp: Vector3 = mode.world.cap_pos + Vector3(0, 1.5, 0)
	var behind := cam.is_position_behind(cp)
	var p := cam.unproject_position(cp)
	var m := 40.0
	var on := not behind and p.x > m and p.x < size.x - m and p.y > m and p.y < size.y - m
	if not on:
		var dir := (p - center)
		if behind:
			dir = -dir
		if dir.length() < 1:
			dir = Vector2(0, 1)
		dir = dir.normalized()
		var hx := size.x / 2 - m
		var hy := size.y / 2 - m
		var k := minf(hx / maxf(absf(dir.x), 0.001), hy / maxf(absf(dir.y), 0.001))
		var at := center + dir * k
		var col := ControlMode.team_color(mode.holder) if mode.phase != "locked" else GameData.col(GameData.MODES.control.locked_col)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([at + dir * 14, at - dir * 8 + side * 11, at - dir * 8 - side * 11]), col)
		draw_polyline(PackedVector2Array([at + dir * 14, at - dir * 8 + side * 11, at - dir * 8 - side * 11, at + dir * 14]), Color(0, 0, 0, 0.6), 2)
		_text(at - dir * 26 + Vector2(0, 5), "거점", 12, Color.WHITE)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
	return p.distance_to(a + ab * t)


func _text(at: Vector2, s: String, fs: int, col: Color) -> void:
	var f: Font = get_theme_default_font() if get_theme_default_font() else _font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, at - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
	draw_string(f, at - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 거점 아이콘: 주인 색 동그라미 + 점령 게이지 고리 (12시부터 시계 방향)
class PointIcon extends Control:
	var mode: ControlMode

	func _draw() -> void:
		if mode == null:
			return
		var c := size / 2
		var r := minf(size.x, size.y) / 2 - 4
		var locked := mode.phase == "locked"
		var oc := GameData.col(GameData.MODES.control.locked_col) if locked else ControlMode.team_color(mode.holder)
		draw_circle(c, r, Color(0, 0, 0, 0.55))
		draw_circle(c, r - 6, Color(oc, 0.9))
		draw_arc(c, r - 2, 0, TAU, 40, Color(1, 1, 1, 0.25), 3)
		if mode.cap_team != "" and mode.cap_prog > 0:
			draw_arc(c, r - 2, -PI / 2, -PI / 2 + TAU * mode.cap_prog, 40, ControlMode.team_color(mode.cap_team), 5)
		var f := get_theme_default_font()
		var s := "잠김" if locked else ("!" if mode.contested else "")
		if s != "" and f:
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, c + Vector2(-w / 2, 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.15))
