class_name UiKit
extends RefCounted
## 메뉴·HUD 공용 UI 조각 — HTML CSS(.panel / .primary / .ghost / .back / .navbtn / .card / .diff / table.score)를
## Godot Control로 옮긴 것. 색은 GameData.UI, 판 모양은 GameData.UI_KIT.
## "마을 게시판 스타일" (reference/ui_design/Guide.html): 재질은 나무(wood)·양피지(parch)·금칠(gilt) 셋.
##   Board = 재질 판 (_draw로 직접 그림), KitButton = 판을 얼굴로 쓰는 버튼 (이정표·금칠 판·양피지).
##   primary = 금칠 판(화면에 하나), ghost/back = 양피지, navbtn = 이정표.
##   글꼴: 도현(기본) + SCRIBBLE(개구 — 한마디·쪽지·팁에만, 한 화면에 1~2곳).
##   기울기는 ±3° 이하(UI_KIT.tilt_max), 숫자는 안 기울인다. Container 안에선 tilted()로 감싸서 돌린다.

static var _icons := {}

## 개구 Bold (한마디·쪽지·팁). Noto·도현 대체 폰트는 GameData._setup_font_fallbacks가 붙인다
const SCRIBBLE: FontFile = preload("res://fonts/Gaegu-Bold-sub.woff2")

## 병과 아이콘 (HTML ICONS의 SVG 그대로)
const ICONS := {
	"barbarian": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M9 25c-1-6 4-12 11-13 7-1 12 3 12 9 0 7-6 11-13 11-6 0-9-3-10-7z" fill="#fff8e6"/><path d="M14 20c2-2 5-3 8-3" stroke="#2b1d12" stroke-width="2" fill="none" stroke-linecap="round"/></svg>',
	"archer": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M14 5c13 6 13 24 0 30" stroke="#fff8e6" stroke-width="3.5" fill="none" stroke-linecap="round"/><path d="M14 5v30" stroke="#fff8e6" stroke-width="1.5"/><path d="M8 20h26M30 16l5 4-5 4" stroke="#fff8e6" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
	"crossbow": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M6 14c8-6 20-6 28 0" stroke="#fff8e6" stroke-width="3.5" fill="none" stroke-linecap="round"/><path d="M20 9v26" stroke="#fff8e6" stroke-width="5" stroke-linecap="round"/><path d="M6 14l14 6 14-6" stroke="#fff8e6" stroke-width="1.5" fill="none"/></svg>',
	"bard": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M7 18h17" stroke="#fff8e6" stroke-width="3.5" stroke-linecap="round"/><path d="M24 18l9-7v14z" fill="#fff8e6"/><path d="M12 18v5M16 18v5M20 18v5" stroke="#fff8e6" stroke-width="2.4" stroke-linecap="round"/></svg>',  # 트럼펫 (4.5단계 새 병과)
	"cleric": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M16 5h8v4l-1 1v5c5 2 8 6 8 11 0 6-5 9-11 9s-11-3-11-9c0-5 3-9 8-11v-5l-1-1z" fill="#fff8e6"/><path d="M20 20v11M15.5 24.5h9" stroke="#6b45a8" stroke-width="2.6" stroke-linecap="round"/></svg>',
}


## 메인 메뉴 이정표 아이콘 (시안 Main.html의 SVG, 선 아이콘). {c} = 선 색
const NAV_ICONS := {
	"sword": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 17.5 3 6V3h3l11.5 11.5"/><path d="m13 19 6-6"/><path d="m16 16 4 4"/><path d="m19 21 2-2"/></svg>',
	"robot": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="8" width="16" height="12" rx="3"/><path d="M12 8V4"/><circle cx="12" cy="3" r="1"/><circle cx="9" cy="14" r="1.4"/><circle cx="15" cy="14" r="1.4"/></svg>',
	"people": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.4"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><path d="M15 14.5c3 0 6 2 6 5.5"/></svg>',
	"gear": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></svg>',
	"exit": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M14 4h5v16h-5"/><path d="M10 16l4-4-4-4"/><path d="M14 12H3"/></svg>',
}


## NAV_ICONS 하나를 px 크기 TextureRect로 (화면 배율 2배로 구워서 또렷하게)
static func nav_icon(key: String, col: Color, px: float) -> TextureRect:
	var ck := "%s_%s_%d" % [key, col.to_html(false), int(px)]
	if not _icons.has(ck):
		var img := Image.new()
		img.load_svg_from_string(String(NAV_ICONS[key]).replace("{c}", "#" + col.to_html(false)), px * 2.0 / 24.0)
		_icons[ck] = ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = _icons[ck]
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 무기 아이콘 (킬피드·무기 칸, 시안 Hud.html). 잉크 선 + 칠한 면. [가로, 세로, 안쪽 svg]
const _WI_HEAD := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} 24" fill="none" stroke="#2b1d12" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
const WEAPON_ICONS := {
	"stone": [24, '<path d="M5 9l5-5 7 2 3 7-4 6-8 0-4-5z" fill="#c9bfae"/>'],
	"bow": [24, '<path d="M5 3c9 3 9 15 0 18" stroke="#8a542b" stroke-width="3"/><path d="M5 3v18"/><path d="M3 12h18"/><path d="M18 9l3 3-3 3"/>'],
	"crossbow": [24, '<path d="M3 9c5-5 13-5 18 0" stroke="#8a542b" stroke-width="3"/><path d="M3 9l9 4 9-4" stroke-width="1.5"/><path d="M12 6v16" stroke="#6b4423" stroke-width="3.5"/><path d="M12 2l-2.5 4h5z" fill="#c9bfae"/>'],
	"holy": [24, '<path d="M10 2h4v2h-.5v4c3.5 1.2 5.5 4 5.5 7.2 0 4-3.2 6.8-7 6.8s-7-2.8-7-6.8c0-3.2 2-6 5.5-7.2V4H10z" fill="#9fd0f0"/><path d="M12 12v6M9.5 14.5h5" stroke="#f2b44a" stroke-width="2.2"/>'],
	"trumpet": [28, '<path d="M2 12h14" stroke="#c99a2e" stroke-width="4"/><path d="M2 12h14"/><path d="M16 12l9-6v12z" fill="#f3b33d"/><path d="M8 12V8M11 12V8"/>'],
	"fanfare": [28, '<path d="M1 12h12" stroke="#c99a2e" stroke-width="4"/><path d="M1 12h12"/><path d="M13 12l8-6v12z" fill="#f3b33d"/><path d="M6 12V8M9 12V8"/><path d="M23.5 6l3-2M24 12h3M23.5 18l3 2" stroke="#d8453b"/>'],
	"sniper": [28, '<path d="M1 13h20l5-1.5v3H11l-2 5H5l1-4.5H1z" fill="#6b4423"/><rect x="9" y="7.5" width="9" height="3.5" rx="1" fill="#4a4a52"/><path d="M12 11v2M15 11v2"/>'],
	"ak": [28, '<path d="M1 10h18l6-1v3h-7l-1.5 2H10l1.5 5H8l-2-5H1z" fill="#8a542b"/><path d="M13.5 13.5c0 3 1 5 3 6.5" stroke-width="3.2"/><path d="M19 10V8h3"/>'],
	"chicken": [24, '<path d="M5 14c0-5 3.5-8 8-7.5.5-3 5-3.5 5.5-.5.2 1.3-.5 2.3-1.5 2.7 2 2.3 2 5.5-.3 7.8-3.4 3.4-11.7 3-11.7-2.5z" fill="#fff8e6"/><path d="M19 7.5l3 1-3 1z" fill="#f2b44a"/><path d="M15 3.8c.3-1.3 1.3-1.8 2-1.2" stroke="#d8453b" stroke-width="2.2"/><circle cx="16.3" cy="7" r=".9" fill="#2b1d12" stroke="none"/><path d="M9 20.5v2M13 20.5v2" stroke="#f2b44a"/>'],
	"lance": [24, '<path d="M4 20L16 8" stroke="#8a542b" stroke-width="3.2"/><path d="M14 5.5L21 3l-2.5 7-2.2.3-1.6-1.6z" fill="#c9bfae"/><path d="M6 13.5l4.5 4.5" stroke-width="3"/>'],
	"star": [24, '<path d="M2.5 12c3-5 10-6.5 14-2.3l4.5-3.2v11l-4.5-3.2c-4 4.2-11 2.7-14-2.3z" fill="#f2b44a"/><circle cx="7" cy="11" r="1.1" fill="#2b1d12" stroke="none"/><path d="M10 9.5c1 1.5 1 3.5 0 5M13 9.8c.8 1.4.8 3 0 4.4" stroke-width="1.4"/>'],
}


## 무기 아이콘 텍스처 (세로 px, 화면 배율 2배로 구움). 모르는 무기는 돌멩이
static func weapon_tex(kind: String, px: float) -> Texture2D:
	var k := kind if WEAPON_ICONS.has(kind) else "stone"
	var ck := "w_%s_%d" % [k, int(px)]
	if not _icons.has(ck):
		var w: int = WEAPON_ICONS[k][0]
		var img := Image.new()
		img.load_svg_from_string(_WI_HEAD.replace("{w}", str(w)) + str(WEAPON_ICONS[k][1]) + "</svg>", px * 2.0 / 24.0)
		_icons[ck] = ImageTexture.create_from_image(img)
	return _icons[ck]


static func weapon_icon(kind: String, px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = weapon_tex(kind, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w: int = WEAPON_ICONS[kind if WEAPON_ICONS.has(kind) else "stone"][0]
	tr.custom_minimum_size = Vector2(px * w / 24.0, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 형광펜 밑줄 (글자 아래 절반, 시안 .marker: 50%~92%). 글자 크기가 바뀌면 따라감
static func marker_under(l: Label, col := Color.TRANSPARENT) -> ColorRect:
	var mk := ColorRect.new()
	mk.color = col if col.a > 0 else c("marker")
	mk.show_behind_parent = true
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(mk)
	var fit := func() -> void:
		mk.position = Vector2(-3, l.size.y * 0.5)
		mk.size = Vector2(l.size.x + 6, l.size.y * 0.4)
	l.resized.connect(fit)
	fit.call()
	return mk


## 큰 글자 위아래 빈 줄 높이를 줄임 (글자 크기 × k만큼씩) — 판 높이를 시안처럼 낮게
static func trim_font(l: Control, size: int, k: float) -> void:
	var key := "normal_font" if l is RichTextLabel else "font"
	var fv := FontVariation.new()
	fv.base_font = l.get_theme_font(key)
	fv.spacing_top = -roundi(size * k)
	fv.spacing_bottom = -roundi(size * k * 0.6)
	l.add_theme_font_override(key, fv)


static func c(key: String, a := 1.0) -> Color:
	var col := GameData.col(GameData.UI[key])
	col.a = a
	return col


static func ink(a: float) -> Color:
	return c("ink", a)


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
	return drop(box(ink(0.78), c("wood", 0.6), 1, 6, pad), ink(0.35), 4)


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


## 형광펜 강조 (예전 이름 그대로 gold — <b>처럼 쓰는 BBCode)
static func gold(text: String, size := 0) -> String:
	var s := "[color=#%s]%s[/color]" % [c("marker").to_html(false), text]
	return "[font_size=%d]%s[/font_size]" % [size, s] if size > 0 else s


static func esc(s: String) -> String:
	return s.replace("[", "[lb]")


# ── 글자 ─────────────────────────────────────────────────────

## 나무판 위 글자 외곽선 굵기 (큰 글자일수록 굵게)
static func outline_for(size: int) -> int:
	var K: Dictionary = GameData.UI_KIT
	return clampi(roundi(size * float(K.text_outline_k)), int(K.text_outline[0]), int(K.text_outline[1]))


## 나무판 위 글자: 흰색(cream) + 잉크 외곽선 + 아래 그림자
static func wood_text(l: Label, size := 0, col := Color.TRANSPARENT) -> Label:
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	var fs: int = size if size > 0 else l.get_theme_font_size("font_size")
	var o := outline_for(fs)
	l.add_theme_color_override("font_color", col if col.a > 0 else c("cream"))
	l.add_theme_color_override("font_outline_color", c("ink"))
	l.add_theme_constant_override("outline_size", o)
	shadow(l, c("ink", 0.9), int(GameData.UI_KIT.text_drop), o)
	return l


## 개구 글씨 (한마디·쪽지·팁 — 한 화면에 1~2곳만)
static func scribble(text: String, size: int, col: Color, parent: Node = null) -> Label:
	var l := label(text, size, col, parent)
	l.add_theme_font_override("font", SCRIBBLE)
	return l


## Container 안에서도 기울어지게 빈 Control로 한 번 감싼다 (Container는 자식 rotation을 0으로 되돌림).
## 돌려받은 감싼 것을 Container에 넣는다. 기울기는 ±UI_KIT.tilt_max로 자른다 — 숫자 판엔 쓰지 말 것
static func tilted(inner: Control, deg: float) -> Control:
	var w := Control.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(inner)
	var lim: float = GameData.UI_KIT.tilt_max
	var rot := deg_to_rad(clampf(deg, -lim, lim))
	var fit_min := func() -> void: w.custom_minimum_size = inner.get_combined_minimum_size()
	inner.minimum_size_changed.connect(fit_min)
	fit_min.call()
	w.resized.connect(func() -> void:
		inner.position = Vector2.ZERO
		inner.size = w.size
		inner.pivot_offset = w.size / 2.0
		inner.rotation = rot)
	return w


## 쇠못 하나 (회색 원 + 하이라이트 + 아래 그림자)
static func draw_nail(ci: CanvasItem, p: Vector2, r := 0.0) -> void:
	var K: Dictionary = GameData.UI_KIT
	if r <= 0:
		r = K.nail_r
	var C: Array = K.nail_cols
	ci.draw_circle(p + Vector2(0, r * 0.35), r, Color(0, 0, 0, 0.45), true, -1, true)
	ci.draw_circle(p, r, GameData.col(C[2]), true, -1, true)
	ci.draw_circle(p - Vector2(r, r) * 0.12, r * 0.78, GameData.col(C[1]), true, -1, true)
	ci.draw_circle(p - Vector2(r, r) * 0.3, r * 0.36, GameData.col(C[0]), true, -1, true)


static var _nail_icons := {}

## 쇠못 그림 (슬라이더 손잡이 등 텍스처가 필요한 곳). 시안 radial-gradient(35% 35%, 밝음 → 몸 55% → 테두리)
static func nail_icon(r: float) -> Texture2D:
	if _nail_icons.has(r):
		return _nail_icons[r]
	var C: Array = GameData.UI_KIT.nail_cols
	var hi := GameData.col(C[0])
	var mid := GameData.col(C[1])
	var lo := GameData.col(C[2])
	var n := ceili(r * 2.0) + 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ctr := Vector2(n, n) / 2.0 - Vector2(0, 1)
	var hl := ctr - Vector2(r, r) * 0.3
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(ctr)
			var col := Color(0, 0, 0, 0)
			var ds := p.distance_to(ctr + Vector2(0, 1.5))  # 아래 그림자
			if ds < r:
				col = Color(0, 0, 0, 0.45 * clampf(r - ds, 0, 1))
			if d < r + 0.5:
				var k := clampf(p.distance_to(hl) / (r * 1.3), 0.0, 1.0)
				var body := hi.lerp(mid, clampf(k / 0.55, 0, 1)) if k < 0.55 else mid.lerp(lo, (k - 0.55) / 0.45)
				body.a = clampf(r + 0.5 - d, 0, 1)
				col = col.blend(body)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_nail_icons[r] = tex
	return tex


# ── 재질 판 ──────────────────────────────────────────────────

## 게시판 재질 판. 나무(wood)·양피지(parch)·금칠(gilt)을 _draw로 직접 그린다
## (텍스처·셰이더 없음 → Compatibility·웹 그대로). 안에 넣은 자식은 판 위에 그려진다.
##   nails: 쇠못 0 / 1(위 가운데) / 2(위 두 모서리) / 4
##   arrow: 이정표 (오른쪽 끝 뾰족), ropes: 위로 매달린 밧줄 2개
##   tilt: 판(배경)만 기울임 — 글자까지 돌리려면 UiKit.tilted()
##   paint: 바탕색 바꾸기 (양피지 버튼 선택 = 형광펜)
class Board extends PanelContainer:
	static var _made := 0
	var kind := "wood":
		set(v):
			kind = v
			_restyle()
	var nails := 0:
		set(v):
			nails = v
			queue_redraw()
	var arrow := false:
		set(v):
			arrow = v
			_restyle()
	var ropes := false:
		set(v):
			ropes = v
			queue_redraw()
	var rope_len := 0.0  # 0이면 UI_KIT.rope_len
	var tilt := 0.0:
		set(v):
			var lim: float = GameData.UI_KIT.tilt_max
			tilt = clampf(v, -lim, lim)
			queue_redraw()
	var paint := Color.TRANSPARENT:
		set(v):
			paint = v
			_geo.clear()
			queue_redraw()
	var sink := 0.0:  # 눌림: 그림자가 이만큼 짧아진다 (판은 Face가 그만큼 내림)
		set(v):
			sink = v
			queue_redraw()
	var pad := Vector4(12, 8, 12, 8):  # 외곽선 안쪽 여백 (왼·위·오른·아래)
		set(v):
			pad = v
			_restyle()
	var radius := -1.0:  # 모서리 둥글기 (음수면 UI_KIT[kind].radius)
		set(v):
			radius = v
			_geo.clear()
			queue_redraw()
	var ring := Color.TRANSPARENT:  # 고른 표시: 판 바깥에 두른 테 (형광펜) + 잉크 테두리 (시안 카드 box-shadow)
		set(v):
			ring = v
			queue_redraw()
	var bands: Array = []:  # 위쪽 색 띠 (외곽선 안쪽). 색 여러 개면 가로로 나눔 — 난이도 색, 쟁탈전 블루|레드
		set(v):
			bands = v
			queue_redraw()
	var band_h := 0.0       # 0이면 UI_KIT.band_h
	var grain_seed := 0  # 나뭇결 무늬 (인스턴스마다 고정)
	var _geo := {}

	func _init(k := "wood", p := Vector4(12, 8, 12, 8)) -> void:
		grain_seed = 7919 * _made + 13
		_made += 1
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		kind = k
		pad = p
		resized.connect(func() -> void: _geo.clear())

	func _M() -> Dictionary:
		return GameData.UI_KIT[kind]

	func tip_len() -> float:
		return float(GameData.UI_KIT.arrow_tip) if arrow else 0.0

	func _restyle() -> void:
		var bw: float = _M().line
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = pad.x + bw
		sb.content_margin_top = pad.y + bw
		sb.content_margin_right = pad.z + bw + tip_len()
		sb.content_margin_bottom = pad.w + bw
		add_theme_stylebox_override("panel", sb)
		_geo.clear()
		queue_redraw()

	# 판 모양: 모서리 둥근 상자, arrow면 오른쪽이 뾰족 (왼쪽만 둥글게)
	func _shape(x0: float, y0: float, w: float, h: float, r: float, t: float, xe: float) -> Dictionary:
		return {"x0": x0, "y0": y0, "w": w, "h": h, "r": clampf(r, 0.0, minf(w, h) / 2.0), "t": t, "xe": xe}

	## y 높이에서 판의 왼쪽·오른쪽 x
	func _xr(S: Dictionary, y: float) -> Vector2:
		var h: float = S.h
		var r: float = S.r
		var yl: float = clampf(y - float(S.y0), 0.0, h)
		var ci := 0.0
		if yl < r:
			ci = r - sqrt(maxf(0.0, r * r - (r - yl) * (r - yl)))
		elif yl > h - r:
			var d := yl - (h - r)
			ci = r - sqrt(maxf(0.0, r * r - d * d))
		var t: float = S.t
		var right: float = float(S.xe) - (t * absf(yl - h / 2.0) / (h / 2.0) if t > 0 else ci)
		return Vector2(float(S.x0) + ci, right)

	func _rows(S: Dictionary, edge: Array) -> PackedFloat32Array:
		var h: float = S.h
		var r: float = S.r
		var ys := [0.0, h]
		for i in 7:
			var a := i * PI / 12.0
			ys.append(r * (1.0 - cos(a)))
			ys.append(h - r * (1.0 - cos(a)))
		if float(S.t) > 0:
			ys.append(h / 2.0)
		for e: float in edge:
			if e < h / 2.0:
				ys.append(e)
				ys.append(h - e)
		var n := maxi(1, ceili(h / 24.0))
		for i in n:
			ys.append(h * i / n)
		ys.sort()
		var out := PackedFloat32Array()
		for y: float in ys:
			if out.is_empty() or y - out[out.size() - 1] > 0.05:
				out.append(y + float(S.y0))
		return out

	func _perimeter(S: Dictionary) -> PackedVector2Array:
		var ys := _rows(S, [])
		var pts := PackedVector2Array()
		for y in ys:
			pts.append(Vector2(_xr(S, y).y, y))
		for i in range(ys.size() - 1, -1, -1):
			pts.append(Vector2(_xr(S, ys[i]).x, ys[i]))
		# 같은 점이 겹치면 다각형 나누기가 실패하니 지운다
		var clean := PackedVector2Array()
		for p in pts:
			if clean.is_empty() or p.distance_to(clean[clean.size() - 1]) > 0.05:
				clean.append(p)
		if clean.size() > 2 and clean[0].distance_to(clean[clean.size() - 1]) <= 0.05:
			clean.remove_at(clean.size() - 1)
		return clean

	func _base() -> Color:
		if paint.a > 0:
			return paint
		return UiKit.c(kind)

	## 판 안쪽 한 점의 색 (그라데이션·얼룩·가장자리 그늘)
	func _col(p: Vector2, S: Dictionary, xr: Vector2) -> Color:
		var ty: float = clampf((p.y - float(S.y0)) / float(S.h), 0.0, 1.0)
		if paint.a > 0 and kind != "parch":
			return paint.lerp(paint.darkened(0.15), ty)
		match kind:
			"wood":
				return UiKit.c("wood_hi").lerp(UiKit.c("wood_lo"), ty)
			"gilt":
				return UiKit.c("gilt_hi").lerp(UiKit.c("gilt_lo"), ty)
		# 양피지 (시안 .parch + .inkp): 왼쪽 위 밝게, 오른쪽 아래 누렇게, 가장자리 그늘
		var K: Dictionary = GameData.UI_KIT
		var W: float = float(S.xe) - float(S.x0)
		var H: float = S.h
		var u := (p.x - float(S.x0)) / W
		var col := _base()
		var k1 := 1.0 - sqrt(pow((u - 0.18) / 0.58, 2) + pow((ty - 0.12) / 0.62, 2))
		if k1 > 0:
			col = col.lerp(Color.WHITE, 0.6 * k1)
		var k2 := 1.0 - sqrt(pow((u - 0.92) / 0.72, 2) + pow((ty - 0.96) / 0.75, 2))
		if k2 > 0:
			col = col.lerp(Color8(150, 100, 40), 0.25 * k2)
		var e := minf(minf(p.x - xr.x, xr.y - p.x), minf(p.y - float(S.y0), float(S.y0) + H - p.y))
		var k3 := clampf(1.0 - e / float(K.parch_edge), 0.0, 1.0)
		if k3 > 0:
			col = col.lerp(Color8(120, 80, 30), float(K.parch_edge_a) * k3 * k3)
		return col

	func _build() -> void:
		var K: Dictionary = GameData.UI_KIT
		var M := _M()
		var w := size.x
		var h := size.y
		var bw: float = M.line
		var r: float = radius if radius >= 0 else float(M.radius)
		var t := tip_len()
		t = minf(t, w * 0.45)
		var outer := _shape(0, 0, w, h, r, t, w)
		var inner: Dictionary
		if t > 0:
			var a := h / 2.0
			var a2 := maxf(1.0, a - bw)
			var L := sqrt(t * t + a * a)
			inner = _shape(bw, bw, w - 2 * bw, h - 2 * bw, r - bw, t * a2 / a, w - bw * L / a)
		else:
			inner = _shape(bw, bw, w - 2 * bw, h - 2 * bw, r - bw, 0, w - bw)
		_geo.outer = _perimeter(outer)
		_geo.inner = inner
		# 안쪽 바탕: 줄(y)·칸(u) 격자에 꼭짓점 색 → 삼각형 한 묶음
		var edge := [2.0, 5.0, 9.0, 14.0, 20.0] if kind == "parch" else []
		var ys := _rows(inner, edge)
		var W: float = float(inner.xe) - float(inner.x0)
		var us := [0.0, 1.0]
		for e: float in edge:
			if e < W / 2.0:
				us.append(e / W)
				us.append(1.0 - e / W)
		var n := maxi(1, ceili(W / 40.0))
		for i in n:
			us.append(float(i) / n)
		us.sort()
		var uu := PackedFloat32Array()
		for u: float in us:
			if uu.is_empty() or u - uu[uu.size() - 1] > 0.001:
				uu.append(u)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for y in ys:
			var xr := _xr(inner, y)
			for u in uu:
				var p := Vector2(lerpf(xr.x, xr.y, u), y)
				pts.append(p)
				cols.append(_col(p, inner, xr))
		var idx := PackedInt32Array()
		var nc := uu.size()
		for i in ys.size() - 1:
			for j in nc - 1:
				var a0 := i * nc + j
				var b0 := (i + 1) * nc + j
				idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])
		_geo.pts = pts
		_geo.cols = cols
		_geo.idx = idx
		# 나뭇결: 판자 이음선 + seed로 고정된 물결 결 + 옹이
		var lines := []  # [PackedVector2Array, Color, 굵기]
		if kind != "parch":
			var gilt := kind == "gilt"
			var seam: float = K.seam
			var sc := Color8(120, 60, 10, int(255 * float(K.seam_gilt_a))) if gilt else Color8(60, 30, 10, int(255 * float(K.seam_a)))
			var y := float(inner.y0) + seam
			while y < float(inner.y0) + float(inner.h) - 3.0:
				var xr := _xr(inner, y)
				lines.append([PackedVector2Array([Vector2(xr.x, y), Vector2(xr.y, y)]), sc, float(K.seam_w)])
				y += seam
			var rng := RandomNumberGenerator.new()
			rng.seed = grain_seed
			var ga: Array = K.grain_a
			for g in int(float(inner.h) / float(K.grain_every)) + 1:
				var gy := rng.randf_range(float(inner.y0) + 3.0, float(inner.y0) + float(inner.h) - 3.0)
				var x0 := rng.randf_range(float(inner.x0), float(inner.x0) + W * 0.5)
				var len := W * rng.randf_range(0.3, 0.9)
				var amp := rng.randf_range(0.5, 1.4)
				var fq := rng.randf_range(0.04, 0.09)
				var ph := rng.randf() * TAU
				var light := rng.randf() < 0.3
				var a := rng.randf_range(float(ga[0]), float(ga[1]))
				var gc := Color8(255, 220, 170, int(255 * a * 0.6)) if light else Color8(60, 30, 10, int(255 * a))
				var pl := PackedVector2Array()
				var x := x0
				while x <= x0 + len:
					var py := gy + sin(x * fq + ph) * amp
					var xr := _xr(inner, py)
					pl.append(Vector2(clampf(x, xr.x + 1, xr.y - 1), py))
					x += 8.0
				if pl.size() > 1:
					lines.append([pl, gc, 1.0])
			for k in int(W / float(K.knot_every)):
				var cx := rng.randf_range(float(inner.x0) + 14, float(inner.x0) + W - 14 - t)
				var cy := rng.randf_range(float(inner.y0) + 6, float(inner.y0) + float(inner.h) - 6)
				var rx := rng.randf_range(5, 9)
				var ry := rng.randf_range(2, 3.2)
				var ring := PackedVector2Array()
				for s in 17:
					var an := s * TAU / 16.0
					ring.append(Vector2(cx + cos(an) * rx, cy + sin(an) * ry))
				lines.append([ring, Color8(60, 30, 10, 70), 1.2])
		_geo.lines = lines

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 4 or h < 4:
			return
		var K: Dictionary = GameData.UI_KIT
		var M := _M()
		if _geo.is_empty():
			_build()
		if tilt != 0.0:
			var rot := deg_to_rad(tilt)
			var ctr := size / 2.0
			draw_set_transform(ctr - ctr.rotated(rot), rot, Vector2.ONE)
		if ropes:
			_draw_ropes()
		var ink := UiKit.c("ink")
		var outer: PackedVector2Array = _geo.outer
		if ring.a > 0:  # 고른 표시: 형광펜 테 + 바깥 잉크 선 (그림자보다 먼저)
			var rw: float = K.ring_w
			var r0: float = radius if radius >= 0 else float(M.radius)
			var big := _perimeter(_shape(-rw - 2, -rw - 2, w + 2 * rw + 4, h + 2 * rw + 4, r0 + rw + 2, 0, w + rw + 2))
			draw_colored_polygon(big, ink)
			draw_colored_polygon(_perimeter(_shape(-rw, -rw, w + 2 * rw, h + 2 * rw, r0 + rw, 0, w + rw)), ring)
		var dr: float = maxf(0.0, float(M.drop) - sink)
		if dr > 0:  # 아래로 단단한 그림자
			var sh := PackedVector2Array()
			for p in outer:
				sh.append(p + Vector2(0, dr))
			var sc := UiKit.c("ink", float(M.drop_a))
			draw_colored_polygon(sh, sc)
			sh.append(sh[0])
			draw_polyline(sh, sc, 1.0, true)
		draw_colored_polygon(outer, ink)  # 잉크 외곽선 (안쪽 판이 위를 덮음)
		var ring := outer.duplicate()
		ring.append(outer[0])
		draw_polyline(ring, ink, 1.0, true)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _geo.idx, _geo.pts, _geo.cols)
		for ln: Array in _geo.lines:
			draw_polyline(ln[0], ln[1], ln[2], true)
		if not bands.is_empty():  # 위쪽 색 띠 + 아래 잉크 선
			var S: Dictionary = _geo.inner
			var bh: float = band_h if band_h > 0 else float(K.band_h)
			var y0: float = S.y0
			var xr0 := _xr(S, y0 + float(S.r))
			var bw := (xr0.y - xr0.x) / bands.size()
			for i in bands.size():
				var x0 := xr0.x + bw * i
				var rr: float = minf(float(S.r), bh)
				var poly := PackedVector2Array()
				# 위 모서리 둥근 부분은 판 모양을 따라감
				var ys: Array = [y0 + 0.01]
				for k in 6:
					ys.append(y0 + rr * (k + 1) / 6.0)
				for yy: float in ys:
					var xr := _xr(S, yy)
					poly.append(Vector2(clampf(x0 + bw, xr.x, xr.y), yy))
				poly.append(Vector2(x0 + bw, y0 + bh))
				poly.append(Vector2(x0, y0 + bh))
				for k in range(ys.size() - 1, -1, -1):
					var xr := _xr(S, ys[k])
					poly.append(Vector2(clampf(x0, xr.x, xr.y), ys[k]))
				var clean := PackedVector2Array()
				for q in poly:
					if clean.is_empty() or q.distance_to(clean[clean.size() - 1]) > 0.05:
						clean.append(q)
				if clean.size() >= 3:
					draw_colored_polygon(clean, bands[i])
			draw_line(Vector2(xr0.x, y0 + bh), Vector2(xr0.y, y0 + bh), ink, 2.0)
		if kind == "wood" and paint.a == 0:  # 위쪽 밝은 띠
			var S: Dictionary = _geo.inner
			var y: float = float(S.y0) + float(K.shine_h) / 2.0
			var xr := _xr(S, y)
			draw_line(Vector2(xr.x, y), Vector2(xr.y, y), Color8(255, 220, 170, int(255 * float(K.shine_a))), float(K.shine_h))
		_draw_nails()
		if tilt != 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_nails() -> void:
		if nails <= 0:
			return
		var d: float = GameData.UI_KIT.nail_in
		var x1 := size.x - tip_len() - d
		if nails == 1:
			UiKit.draw_nail(self, Vector2((size.x - tip_len()) / 2.0, d))
			return
		UiKit.draw_nail(self, Vector2(d, d))
		UiKit.draw_nail(self, Vector2(x1, d))
		if nails >= 4:
			UiKit.draw_nail(self, Vector2(d, size.y - d))
			UiKit.draw_nail(self, Vector2(x1, size.y - d))

	## 위로 매달린 밧줄 두 개 (-35° 사선 줄무늬 막대). 판보다 먼저 그려서 아래 끝은 판에 가려진다
	func _draw_ropes() -> void:
		var K: Dictionary = GameData.UI_KIT
		var rw: float = K.rope_w
		var top: float = -(rope_len if rope_len > 0 else float(K.rope_len))
		var bot: float = float(_M().line) + 4.0
		var C: Array = K.rope_cols
		var band: Array = K.rope_band
		var slope := rw * tan(deg_to_rad(35.0))
		var body_w := size.x - tip_len()
		for fx: float in K.rope_x:
			var x0 := body_w * fx - rw / 2.0
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var y := top - slope
			var i := 0
			while y < bot:
				var b: float = band[i % 2]
				var cc := GameData.col(C[i % 2])
				var q := [Vector2(x0, y + slope), Vector2(x0 + rw, y), Vector2(x0 + rw, y + b), Vector2(x0, y + slope + b)]
				var base := pts.size()
				for p: Vector2 in q:
					pts.append(Vector2(p.x, clampf(p.y, top, bot)))
					cols.append(cc)
				idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
				y += b
				i += 1
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
			var oc := GameData.col(C[2])
			draw_line(Vector2(x0, top), Vector2(x0, bot), oc, 1.4, true)
			draw_line(Vector2(x0 + rw, top), Vector2(x0 + rw, bot), oc, 1.4, true)


## 판을 담은 얼굴 — 버튼(또는 Tap) 위를 덮고, 마우스 올림·누름에 Tween으로 살짝 밀리고 기운다.
## 얼굴은 Container가 아니라서 안의 판은 rotation이 초기화되지 않는다. 판 크기만큼 host의 최소 크기를 맞춘다
class Face extends Control:
	var host: Control
	var board: Board
	var sign := false  # 이정표: 오른쪽으로 밀림
	var lift := Vector2.ZERO  # 0이 아니면 마우스 올릴 때 이만큼 (카드: 위로 8px)
	var hover_paint := Color.TRANSPARENT  # 있으면 마우스 올린 동안 판을 이 색으로 (메인 이정표 = 금칠 노랑)
	var shift := Vector2.ZERO:
		set(v):
			shift = v
			_fit()
	var lean := 0.0:
		set(v):
			lean = v
			_fit()
	var sink := 0.0:
		set(v):
			sink = v
			_fit()
	var _hover := false
	var _down := false
	var _tw: Tween

	func _init(h: Control, b: Board) -> void:
		host = h
		board = b
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		h.add_child(self)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(_fit)
		b.minimum_size_changed.connect(_sync_min)
		_sync_min()
		h.mouse_entered.connect(func() -> void:
			_hover = true
			_anim())
		h.mouse_exited.connect(func() -> void:
			_hover = false
			_down = false
			_anim())
		if h is BaseButton:
			(h as BaseButton).button_down.connect(func() -> void:
				_down = true
				_anim())
			(h as BaseButton).button_up.connect(func() -> void:
				_down = false
				_anim())

	## 판 최소 크기가 바뀌면 host에 옮기고 판 크기도 다시 맞춤.
	## (줄바꿈 글자는 폭이 정해지기 전엔 아주 길쭉하게 재져서 판이 커졌다가 안 줄어드는 일이 있었음 — 난이도 카드)
	func _sync_min() -> void:
		host.custom_minimum_size = board.get_combined_minimum_size()
		_fit.call_deferred()

	func _fit() -> void:
		if not board:
			return
		board.size = size
		board.pivot_offset = size / 2.0
		board.position = shift + Vector2(0, sink)
		board.rotation = deg_to_rad(lean)
		board.sink = sink

	func _off() -> bool:
		return host is BaseButton and (host as BaseButton).disabled

	func _anim() -> void:
		var K: Dictionary = GameData.UI_KIT
		var live := (_hover or _down) and not _off()
		var up: Vector2 = lift if lift != Vector2.ZERO else (K.sign_shift if sign else K.hover_shift)
		var to_shift: Vector2 = up if live else Vector2.ZERO
		var to_lean: float = float(K.hover_tilt) if live else 0.0
		var to_sink: float = float(K.press_sink) if _down and not _off() else 0.0
		if _down and not sign:
			to_shift = Vector2.ZERO
		if hover_paint.a > 0:
			board.paint = hover_paint if live else Color.TRANSPARENT
		if _tw:
			_tw.kill()
		if not is_inside_tree():
			shift = to_shift
			lean = to_lean
			sink = to_sink
			return
		var t: float = K.hover_t
		_tw = create_tween().set_parallel().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "shift", to_shift, t)
		_tw.tween_property(self, "lean", to_lean, t)
		_tw.tween_property(self, "sink", to_sink, t * 0.6)

	## 한 번 꾹 눌렸다 올라옴 (Tap처럼 button_up이 없는 것)
	func poke() -> void:
		_down = true
		_anim()
		get_tree().create_timer(float(GameData.UI_KIT.hover_t), true, false, true).timeout.connect(func() -> void:
			_down = false
			_anim())


## 판을 얼굴로 쓰는 버튼 (금칠 판·양피지·이정표). Button 그대로라 text·pressed·disabled를 똑같이 쓴다.
## Button이 그리는 글자는 투명, 같은 글자를 판 안의 caption이 그린다 (판과 같이 기울도록)
class KitButton extends Button:
	var face: Face
	var board: Board
	var caption: Label
	var selected := false:  # 고른 것 (양피지 → 형광펜 바탕)
		set(v):
			selected = v
			if board:
				board.paint = UiKit.c("marker") if v else Color.TRANSPARENT

	func _draw() -> void:
		if caption and caption.text != text:
			caption.set_deferred("text", text)
		if face:
			face.modulate.a = float(GameData.UI_KIT.disabled_a) if disabled and not selected else 1.0


static func _kit_button(text: String, kind: String, size: int, pad: Vector4, nails := 0, arrow := false) -> KitButton:
	var b := KitButton.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, none)
	for k in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_hover_color", "font_disabled_color", "font_outline_color"]:
		b.add_theme_color_override(k, Color.TRANSPARENT)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	var bd := Board.new(kind, pad)
	bd.nails = nails
	bd.arrow = arrow
	var l := label(text, size, c("ink"), bd)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if kind == "wood":
		wood_text(l, size)
	b.board = bd
	b.caption = l
	b.face = Face.new(b, bd)
	b.face.sign = arrow
	return b


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


## 금칠 판 (HTML .primary) — 화면에 하나만. 위 두 모서리 쇠못, 잉크 글자
static func primary(text: String) -> KitButton:
	return _kit_button(text, "gilt", 26, Vector4(30, 9, 30, 9), 2)


## 양피지 버튼 (HTML .ghost, 크기만 다른 .back) — 보조
static func ghost(text: String, size := 19, pad := Vector4(22, 10, 22, 10)) -> KitButton:
	return _kit_button(text, "parch", size, Vector4(pad.x * 0.8, pad.y * 0.6, pad.z * 0.8, pad.w * 0.6))


static func back(text := "← 뒤로") -> KitButton:
	return ghost(text, 17, Vector4(16, 8, 16, 8))


## 눌러지는 판 — 안에 여러 줄을 넣을 수 있는 버튼 (HTML .navbtn / .card / .diff)
class Tap extends PanelContainer:
	signal pressed
	var n_box: StyleBox
	var h_box: StyleBox
	var on_box: StyleBox
	var on := false
	var bar_col := Color.TRANSPARENT  # 위쪽 색 띠 (난이도 카드)
	var face: Face  # 판 얼굴이 있으면 (이정표) 누를 때 꾹

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
			if face and face.is_inside_tree():
				face.poke()
			pressed.emit()

	## 안쪽 것들이 마우스를 가로채지 않게 (다 넣은 뒤 부른다)
	func seal() -> void:
		_ignore(self)

	func _ignore(n: Node) -> void:
		for ch in n.get_children():
			if ch is Control:
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ignore(ch)


## 판 하나를 눌러지는 이정표로 (안의 내용은 부르는 쪽이 board에 넣고, 다 넣은 뒤 seal()).
## 마우스 올리면 UI_KIT.sign_shift만큼 오른쪽으로 밀리고 hover_tilt만큼 기운다
static func sign_tap(bd: Board) -> Tap:
	var t := board_tap(bd)
	t.face.sign = true
	return t


## 판 하나를 눌러지는 카드로 (마우스 올리면 lift만큼, 없으면 UI_KIT.hover_shift). 고른 표시는 t.face.board.ring
static func board_tap(bd: Board, lift := Vector2.ZERO) -> Tap:
	var none := StyleBoxEmpty.new()
	var t := Tap.new(none, none)
	t.face = Face.new(t, bd)
	t.face.lift = lift
	return t


## 어두운 나무 판자벽 (시안 .wall: 세로 판자 이음새 + 가는 가로 결 + 가운데 밝은 둥근 그늘). 화면 배경용
class Wall extends Control:
	var _geo := {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 게임 화면으로 클릭이 새지 않게
		resized.connect(func() -> void: _geo.clear())

	func _draw() -> void:
		var K: Dictionary = GameData.UI_KIT.wall
		var w := size.x
		var h := size.y
		if w < 2 or h < 2:
			return
		if _geo.is_empty():
			var hi := GameData.col(K.hi)
			var lo := GameData.col(K.lo)
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var nx := 16
			var ny := 10
			for j in ny + 1:
				for i in nx + 1:
					var p := Vector2(w * i / nx, h * j / ny)
					# radial-gradient(ellipse at 50% 40%, hi, lo 80%)
					var d := Vector2((p.x / w - 0.5) / 0.75, (p.y / h - 0.4) / 0.85).length()
					pts.append(p)
					cols.append(hi.lerp(lo, clampf(d / 0.8, 0.0, 1.0)))
			var idx := PackedInt32Array()
			for j in ny:
				for i in nx:
					var a := j * (nx + 1) + i
					var b := a + nx + 1
					idx.append_array([a, a + 1, b, a + 1, b + 1, b])
			_geo = {"pts": pts, "cols": cols, "idx": idx}
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _geo.idx, _geo.pts, _geo.cols)
		var lc := Color8(255, 210, 150, int(255 * float(K.line_a)))
		var y := 0.0
		while y < h:  # 가는 가로 결
			draw_rect(Rect2(0, y, w, float(K.line_w)), lc)
			y += float(K.line_every)
		var sc := Color8(30, 14, 4, int(255 * float(K.seam_a)))
		var x: float = K.plank - K.seam_w
		while x < w:  # 세로 판자 이음새
			draw_rect(Rect2(x, 0, float(K.seam_w), h), sc)
			x += float(K.plank)


## 메인 메뉴 이정표: 왼쪽 큰 글자 + 오른쪽 작은 글자 (HTML .navbtn / .hero / .soon / .sub, 시안 Main.html .wood.arrow)
## hero = 금칠 이정표, 나머지 = 나무 이정표 (sub는 작게), soon은 '준비 중' 양피지 꼬리표
static func navbtn(title: String, small: String, kind := "") -> Tap:
	var hero := kind == "hero"
	var sub := kind == "sub"
	var pad := Vector4(22, 12, 18, 12) if hero else (Vector4(18, 7, 14, 7) if sub else Vector4(20, 9, 16, 9))
	var none := StyleBoxEmpty.new()
	var t := Tap.new(none, none)
	var bd := Board.new("gilt" if hero else "wood", pad)
	bd.arrow = true
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	bd.add_child(hb)
	var bsz := 32 if hero else (22 if sub else 27)
	var big := wood_text(label(title, bsz, c("cream"), hb), bsz)
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == "soon":
		big.modulate.a = 0.8
	if small != "":
		if kind == "soon":  # 준비 중 꼬리표 (양피지 쪽지)
			var tag := Board.new("parch", Vector4(6, 1, 6, 1))
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			label(small, 13, c("ink"), tag)
			hb.add_child(tag)
		else:
			var sm := label(small, 13, c("cream_dim"), hb)
			sm.add_theme_color_override("font_outline_color", c("ink"))
			sm.add_theme_constant_override("outline_size", outline_for(13))
			sm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.face = Face.new(t, bd)
	t.face.sign = true
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


## 점수판 (HTML scoreTable): 순위, 이름+병과 꼬리표, 처치, 죽음. 내 줄은 금색
static func score_table(rows: Array, me: Object) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_row(vb, ["", "이름", "처치", "죽음"], null, true, false)
	for i in rows.size():
		_score_row(vb, [str(i + 1), rows[i].ent_name, str(rows[i].kills), str(rows[i].deaths)], rows[i].cls, false, rows[i] == me)
	return vb


static func _score_row(parent: Control, cells: Array, cls: Variant, head: bool, me: bool, name_col := Color.TRANSPARENT) -> void:
	var pc := PanelContainer.new()
	var sb := box(Color.TRANSPARENT, c("wood") if head else c("wood", 0.45), 0, 0,
		Vector4(8, 4, 8, 4) if head else Vector4(8, 6, 8, 6))
	sb.border_width_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	pc.add_child(hb)
	var fg := c("dust") if head else (c("marker") if me else c("parch"))
	var sz := 12 if head else 14
	var rk := label(cells[0], sz, c("dust"), hb)
	rk.custom_minimum_size.x = 24
	var name_box := HBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 6)
	hb.add_child(name_box)
	label(cells[1], sz, name_col if name_col.a > 0 and not me else fg, name_box)
	if cls != null:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", box(GameData.col(GameData.CLASS_CHIP[cls]), Color.TRANSPARENT, 0, 3, Vector4(6, 1, 6, 1)))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label(GameData.CLASSES[cls].name, 11, c("ink"), chip)
		name_box.add_child(chip)
	for k in range(2, cells.size()):
		var n := label(cells[k], sz, fg, hb)
		n.custom_minimum_size.x = 48
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## 쟁탈전 점수판: 팀마다 (이름·병과·처치·죽음·거점 시간). 이름은 팀 색, 내 줄은 금색
static func team_table(rows: Array, me: Object) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for team: String in ["blue", "red"]:
		var T: Dictionary = GameData.MODES.control.teams[team]
		var part := VBoxContainer.new()
		part.add_theme_constant_override("separation", 0)
		vb.add_child(part)
		var tl := label(str(T.name), 16, Color(str(T.ui)), part)
		tl.custom_minimum_size.y = 24
		_score_row(part, ["", "이름", "처치", "죽음", "거점"], null, true, false)
		var mine := rows.filter(func(e: Object) -> bool: return e.team == team)
		for i in mine.size():
			var e: Object = mine[i]
			_score_row(part, [str(i + 1), e.ent_name, str(e.kills), str(e.deaths), "%d초" % int(e.cap_time)], e.cls, false, e == me, Color(str(T.ui)))
	return vb
