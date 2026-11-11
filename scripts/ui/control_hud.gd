class_name ControlHud
extends Control
## 쟁탈전 HUD (Hud 아래, 쟁탈전일 때만 보임). 모양은 시안 Hud.html (수치 GameData.HUD_UI.ctrl·sign·ally):
##   위 가운데 점수판: 밧줄에 매달린 나무 꼬리표 "쟁탈전 · N판", 블루 방패(왼쪽)·레드 방패(오른쪽) = 팀 이름 + 이긴 판 동그라미,
##     가운데 둥근 거점 메달(깃발 = 주인 색, 바깥 고리 = 점령 진행), 아래 % 막대 둘 + 가운데 양피지 상태 쪽지
##   월드: 거점 위 나무 표지판 "거점 16m"(아래 뾰족), 아군 머리 위 이름 + 파란 ▼ (벽 너머로도),
##     적 이름은 조준점 아래 있을 때만, 거점이 화면 밖이면 가장자리에 화살표
##   죽었을 때 다음 부활 병과 고르기 (숫자키 1~5 또는 클릭)

var hud: Hud
var mode: ControlMode
var _top: Top           # 위 가운데 점수판 (방패·메달·막대는 직접 그림)
var _tag: Label         # 쟁탈전 · N판
var _note: UiKit.Board  # 상태 쪽지
var _status: Label
var _status_mk: ColorRect
var _cls_row: HBoxContainer
var _cls_btns := {}
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var C: Dictionary = GameData.HUD_UI.ctrl
	_top = Top.new()
	_top.anchor_left = 0.5
	_top.anchor_right = 0.5
	_top.offset_left = -float(C.w) / 2.0
	_top.offset_right = float(C.w) / 2.0
	_top.offset_bottom = float(C.h)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	# 밧줄에 매달린 나무 꼬리표
	var tag := UiKit.Board.new("wood", C.tag_pad)
	tag.ropes = true
	tag.rope_len = float(C.tag_top) + 4.0
	tag.radius = 5
	_top.add_child(tag)
	_tag = UiKit.label("쟁탈전 · 1판", int(C.tag_font), Hud.PARCH, tag)
	UiKit.wood_text(_tag, int(C.tag_font))
	tag.resized.connect(func() -> void: tag.position = Vector2((float(C.w) - tag.size.x) / 2.0, float(C.tag_top)))
	# 가운데 양피지 상태 쪽지 (형광펜 밑줄)
	_note = UiKit.Board.new("parch", C.note_pad)
	_note.radius = 4
	_note.tilt = float(C.note_tilt)
	_top.add_child(_note)
	_status = UiKit.label("", int(C.note_font), Hud.INK, _note)
	_status_mk = UiKit.marker_under(_status)
	_note.resized.connect(func() -> void: _note.position = Vector2((float(C.w) - _note.size.x) / 2.0, float(C.note_top)))
	# 죽었을 때 병과 바꾸기 (사망 쪽지 아래)
	_cls_row = HBoxContainer.new()
	_cls_row.anchor_left = 0.5
	_cls_row.anchor_right = 0.5
	_cls_row.anchor_top = 0.5
	_cls_row.anchor_bottom = 0.5
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


## 위 가운데 점수판 아래 끝 (Hud가 아이템 안내 줄을 그 아래에 놓음)
func top_h() -> float:
	return float(GameData.HUD_UI.ctrl.h)


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
	var tag := "쟁탈전 · %d판" % maxi(1, mode.round_no)
	if _tag.text != tag:
		_tag.text = tag
	var st := mode.status_text()
	if _status.text != st:
		_status.text = st
	var hot := mode.contested or mode.overtime
	_status.add_theme_color_override("font_color", Color(str(GameData.MODES.control.teams.red.ink)) if hot else Hud.INK)
	_status_mk.visible = st != ""
	_note.visible = st != ""
	_top.mode = mode
	_top.queue_redraw()
	var e := hud.player
	_cls_row.visible = e != null and not e.alive and not e.spectating and mode.phase != "over"
	if _cls_row.visible:
		var nc := e.next_cls if e.next_cls != "" else e.cls
		for k: String in _cls_btns:
			(_cls_btns[k] as UiKit.KitButton).selected = k == nc  # 다음 부활 병과 = 형광펜
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
	var A: Dictionary = GameData.HUD_UI.ally
	var mh := float(GameData.MODES.control.marker_h)
	for e in hud.combat.ents:
		if e == me or not e.alive or e.team == "":
			continue
		var head := e.global_position + Vector3(0, mh, 0)
		if cam.is_position_behind(head):
			continue
		var sp := cam.unproject_position(head)
		if e.team == me.team:  # 아군: 이름 + 팀 색 ▼ (벽 너머로도)
			var col := GameData.col(T[e.team].body)
			var tw: Vector2 = A.tri
			var tri := PackedVector2Array([sp + Vector2(-tw.x / 2, -tw.y), sp + Vector2(tw.x / 2, -tw.y), sp])
			draw_colored_polygon(tri + PackedVector2Array(), Hud.INK)
			draw_set_transform(Vector2(0, -1.5))
			draw_colored_polygon(tri, col)
			draw_set_transform(Vector2.ZERO)
			_text(sp + Vector2(0, -tw.y - 5), e.ent_name, int(A.font), Hud.PARCH)
		else:  # 적: 조준점 근처에 있고 보일 때만 이름
			if cam.is_position_behind(e.global_position + Vector3(0, 1.0, 0)):
				continue
			var bs := cam.unproject_position(e.global_position + Vector3(0, 1.0, 0))
			var d := maxf(1.0, cam.global_position.distance_to(e.global_position))
			var r := clampf(900.0 / d, 18.0, 120.0)
			if _seg_dist(center, sp, bs) < r * 0.5 and hud.combat.los(cam.global_position, e.global_position + Vector3(0, 1.4, 0)):
				_text(sp + Vector2(0, -6), e.ent_name, int(A.font), GameData.col(T[e.team].body).lightened(0.15))
	_draw_point_sign(cam, me, center)


## 거점 표지판: 화면 안이면 거점 위에 나무 꼬리표 "거점 16m" + 아래 뾰족, 밖이면 가장자리 화살표
func _draw_point_sign(cam: Camera3D, me: PlayerController, center: Vector2) -> void:
	var S: Dictionary = GameData.HUD_UI.sign
	var cap: Vector3 = mode.world.cap_pos
	var cp: Vector3 = cap + Vector3(0, float(S.lift), 0)
	var behind := cam.is_position_behind(cp)
	var p := cam.unproject_position(cp)
	var m := 40.0
	var on := not behind and p.x > m and p.x < size.x - m and p.y > m and p.y < size.y - m
	var col := ControlMode.team_color(mode.holder) if mode.phase != "locked" else GameData.col(GameData.MODES.control.locked_col)
	if on:
		var dist := roundi(Vector2(me.global_position.x - cap.x, me.global_position.z - cap.z).length())
		# 조준점 가까이 오면 흐리게 (가운데를 가리지 않게)
		var a := clampf(p.distance_to(center) / float(S.fade_r), float(S.fade_min), 1.0)
		var f := _f()
		var t1 := "거점"
		var t2 := "%dm" % dist
		var w1 := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, int(S.font)).x
		var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, int(S.sub)).x
		var pad: Vector2 = S.pad
		var bw := w1 + 5 + w2 + pad.x * 2
		var bh := float(S.font) + pad.y * 2
		var tri: Vector2 = S.tri
		var r := Rect2(p.x - bw / 2, p.y - tri.y - bh, bw, bh)
		var sb := UiKit.box(Color(UiKit.c("wood"), a), Color(Hud.INK, a), 3, 5)
		sb.shadow_color = Color(Hud.INK, a)
		sb.shadow_size = 0
		draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(Hud.INK, a))  # 아래 그림자
		draw_style_box(sb, r)
		draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8, 3)), Color(1, 0.86, 0.67, 0.22 * a))
		draw_rect(Rect2(r.position.x + 3, r.end.y - 6, r.size.x - 6, 3), Color(col, 0.9 * a))  # 아래 띠 = 주인 색
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - tri.x / 2, r.end.y), Vector2(p.x + tri.x / 2, r.end.y), Vector2(p.x, p.y)]), Color(Hud.INK, a))
		var base := r.position.y + pad.y + float(S.font) * 0.86
		var x0 := r.position.x + pad.x
		_text_l(Vector2(x0, base), t1, int(S.font), Color(Hud.PARCH, a), a)
		_text_l(Vector2(x0 + w1 + 5, base), t2, int(S.sub), Color(Hud.PARCH, a), a)
		return
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
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([at + dir * 14, at - dir * 8 + side * 11, at - dir * 8 - side * 11])
	draw_colored_polygon(arrow, col)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Hud.INK, 2.5, true)
	_text(at - dir * 26 + Vector2(0, 5), "거점", 13, Hud.PARCH)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
	return p.distance_to(a + ab * t)


func _f() -> Font:
	return get_theme_default_font() if get_theme_default_font() else _font


## 가운데 맞춘 글자 (잉크 외곽선)
func _text(at: Vector2, s: String, fs: int, col: Color) -> void:
	var w := _f().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text_l(at - Vector2(w / 2, 0), s, fs, col, col.a)


func _text_l(at: Vector2, s: String, fs: int, col: Color, a := 1.0) -> void:
	var f := _f()
	draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.outline_for(fs), Color(Hud.INK, a))
	draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 위 가운데 점수판 그림: 방패 둘(팀 이름 + 이긴 판 동그라미), 거점 메달, % 막대 둘, % 숫자
class Top extends Control:
	var mode: ControlMode

	func _draw() -> void:
		if mode == null:
			return
		var C: Dictionary = GameData.HUD_UI.ctrl
		var T: Dictionary = GameData.MODES.control.teams
		var W: float = C.w
		var sz: Vector2 = C.shield
		var sx: float = C.shield_x
		var sy: float = C.shield_top
		var R: Array = C.shield_r
		var need := int(GameData.MODES.control.rounds_to_win)
		# 방패: 블루 = 오른쪽 아래 귀퉁이가 크게 둥글고, 레드 = 왼쪽 아래 (서로 메달 쪽)
		for team: String in ["blue", "red"]:
			var x := sx if team == "blue" else W - sx - sz.x
			var rad := [R[0], R[1], R[2], R[3]] if team == "blue" else [R[1], R[0], R[3], R[2]]
			var rect := Rect2(x, sy, sz.x, sz.y)
			_shape(rect, rad, GameData.col(T[team].body), C)
			var f := get_theme_default_font()
			var fs := int(C.shield_font)
			var name: String = T[team].short
			var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var base := sy + sz.y / 2 + fs * 0.36
			var pad: float = C.shield_pad
			var tx := x + pad if team == "blue" else x + sz.x - pad - nw
			_out(Vector2(tx, base), name, fs)
			# 이긴 판 동그라미 (0:0 숫자 대신) — 이긴 판 = 형광펜
			var d: float = C.dot
			var g: float = C.dot_gap
			var dots_w := need * d + (need - 1) * g
			var dx := x + sz.x - pad - dots_w if team == "blue" else x + pad
			for i in need:
				var won: bool = i < int(mode.wins[team])
				if team == "red":
					won = (need - 1 - i) < int(mode.wins[team])  # 레드는 메달 쪽(왼쪽)부터 채움 — 거울
				var cc := Vector2(dx + d / 2 + i * (d + g), sy + sz.y / 2)
				draw_circle(cc, d / 2, Hud.INK, true, -1, true)
				draw_circle(cc, d / 2 - 2, Hud.GOLD if won else C.dot_off, true, -1, true)
		# % 막대 (블루는 메달 쪽 오른쪽 끝부터, 레드는 왼쪽 끝부터)
		var bs: Vector2 = C.bar
		var by: float = C.bar_top
		for team: String in ["blue", "red"]:
			var bx := sx if team == "blue" else W - sx - bs.x
			var rr := int(bs.y / 2)
			draw_style_box(UiKit.box(C.bar_bg, Hud.INK, 2, rr), Rect2(bx, by, bs.x, bs.y))
			var k := clampf(float(mode.pct[team]) / 100.0, 0.0, 1.0)
			if k > 0:
				var fw := maxf(bs.y, bs.x * k)
				var fr := Rect2(bx + bs.x - fw if team == "blue" else bx, by, fw, bs.y)
				draw_style_box(UiKit.box(GameData.col(T[team].body), Hud.INK, 2, rr), fr)
				draw_rect(Rect2(fr.position.x + rr, by + bs.y - 5, maxf(0.0, fw - 2 * rr), 3), Color(0, 0, 0, 0.18))
			var f := get_theme_default_font()
			var fs := int(C.pct_font)
			var s := "%d%%" % int(mode.pct[team])
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var px: float = C.pct_x
			var base := by + bs.y / 2 + fs * 0.36
			_out(Vector2(bx - px - w if team == "blue" else bx + bs.x + px, base), s, fs)
		_medal(C)

	## 둥근 거점 메달: 바깥 고리 = 주인 색(없으면 양피지 홈) 위에 점령 중인 팀 색 호, 안쪽 양피지 + 깃발(주인 색)
	func _medal(C: Dictionary) -> void:
		var W: float = C.w
		var R: float = float(C.medal) / 2.0
		var c := Vector2(W / 2.0, float(C.medal_top) + R)
		var locked := mode.phase == "locked"
		var lock_col := GameData.col(GameData.MODES.control.locked_col)
		var own := lock_col if locked else (ControlMode.team_color(mode.holder) if mode.holder != "" else GameData.col(C.track))
		draw_circle(c + Vector2(0, float(C.drop)), R, Hud.INK, true, -1, true)
		draw_circle(c, R, own, true, -1, true)
		if not locked and mode.cap_team != "" and mode.cap_prog > 0:
			var pts := PackedVector2Array([c])
			var n := 40
			for i in n + 1:
				var a := -PI / 2 + TAU * mode.cap_prog * i / n
				pts.append(c + Vector2(cos(a), sin(a)) * R)
			draw_colored_polygon(pts, ControlMode.team_color(mode.cap_team))
		draw_arc(c, R - 1.3, 0, TAU, 48, Hud.INK, float(C.line), true)
		var ri: float = float(C.medal_in) / 2.0
		draw_circle(c, ri, Hud.PARCH, true, -1, true)
		draw_circle(c - Vector2(ri, ri) * 0.25, ri * 0.6, Color(1, 1, 1, 0.25), true, -1, true)
		draw_arc(c, ri, 0, TAU, 40, Hud.INK, 2.0, true)
		# 깃발 (시안 svg: M6 21V3 / M6 4h11l-2.5 4L17 12H6, 24칸)
		var s: float = float(C.flag) / 24.0
		var P := func(x: float, y: float) -> Vector2: return c + (Vector2(x, y) - Vector2(12, 12)) * s
		var flag := PackedVector2Array([P.call(6, 4), P.call(17, 4), P.call(14.5, 8), P.call(17, 12), P.call(6, 12)])
		var fc := lock_col if locked else (ControlMode.team_color(mode.holder) if mode.holder != "" else GameData.col(C.neutral))
		draw_colored_polygon(flag, fc)
		draw_polyline(flag + PackedVector2Array([flag[0]]), Hud.INK, 2.4 * s, true)
		draw_line(P.call(6, 21), P.call(6, 3), Hud.INK, 2.6 * s, true)

	## 방패 판: 잉크 그림자 → 색 → 위쪽 밝은 띠 → 잉크 테 (귀퉁이마다 둥글기 다름)
	func _shape(r: Rect2, rad: Array, col: Color, C: Dictionary) -> void:
		var drop: float = C.drop
		draw_colored_polygon(_rr(Rect2(r.position + Vector2(0, drop), r.size), rad), Hud.INK)
		var pts := _rr(r, rad)
		draw_colored_polygon(pts, col)
		var ln: float = C.line
		draw_colored_polygon(_rr(Rect2(r.position + Vector2(ln, ln), Vector2(r.size.x - 2 * ln, 5)), [rad[0] * 0.6, rad[1] * 0.6, 0.0, 0.0]), Color(1, 1, 1, 0.2))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Hud.INK, ln, true)

	## 귀퉁이마다 반지름이 다른 둥근 네모 (왼위·오른위·오른아래·왼아래)
	static func _rr(r: Rect2, rad: Array) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var cs := [
			[r.position + Vector2(rad[0], rad[0]), PI, float(rad[0])],
			[Vector2(r.end.x - rad[1], r.position.y + rad[1]), PI * 1.5, float(rad[1])],
			[r.end - Vector2(rad[2], rad[2]), 0.0, float(rad[2])],
			[Vector2(r.position.x + rad[3], r.end.y - rad[3]), PI * 0.5, float(rad[3])],
		]
		for cn: Array in cs:
			for i in 7:
				var a: float = cn[1] + PI * 0.5 * i / 6.0
				pts.append(cn[0] + Vector2(cos(a), sin(a)) * cn[2])
		return pts

	## 크림색 글자 + 잉크 외곽선 (나무판·방패 위 글자 규칙)
	func _out(at: Vector2, s: String, fs: int) -> void:
		var f := get_theme_default_font()
		draw_string_outline(f, at + Vector2(0, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.outline_for(fs), Hud.INK)
		draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.outline_for(fs), Hud.INK)
		draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Hud.PARCH)
