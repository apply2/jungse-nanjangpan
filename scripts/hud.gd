class_name Hud
extends CanvasLayer
## 경기 중 화면 UI — HTML #hud (updateHUD). 모양은 마을 게시판 시안 Hud.html (수치 GameData.HUD_UI).
## 가운데 40%는 비움 (조준점·당기기 고리·맞힘 X·조준점 아래 쪽지만). 정보는 네 모서리 + 위 가운데:
##   위 가운데: 개인전 = 밧줄에 매달린 나무 꼬리표(남은 시간) + 양피지(1위) / 쟁탈전 = ControlHud 점수판
##   오른쪽 위 킬피드(양피지 줄 + 무기 아이콘), 왼쪽 아래 나(둥근 액자 + 나무판 체력), 오른쪽 아래 무기(양피지 칸)
## 그 밖에 큰 문구(banner), 데미지 숫자, 사망 화면, 점수판(Tab), 저격총 스코프, 특수 아이템 안내 줄, Q 안내,
## 피격 방향(붉은 호), 맞으면 붉은 테두리(vignette), 춤·황금 붕어빵 테두리.

var player: PlayerController
var combat: Combat
var time_left := 0.0
var show_board := false
var mode: ControlMode = null:  # 쟁탈전이면 규칙 (위쪽 시간 대신 쟁탈전 HUD)
	set(v):
		mode = v
		if _ctrl:
			_ctrl.mode = v
			_ctrl.visible = v != null
		if _topbar:
			_topbar.visible = v == null
var _ctrl: ControlHud
var _topbar: Control

var _speed: RichTextLabel
var _cls: Label          # 나무판의 병과 이름
var _cls_note: Label     # 판 위 작은 쪽지: 투구 없음 · 성수에 젖어 느려짐 · → 다음 부활 X
var _cls_note_box: Control
var _hp: HpBar
var _hp_num: Label
var _medal: Medal
var _vitals_regen := false
var _pop: Label         # 조준점 아래 자막 (배경 없음)
var _pop_t := 0.0
var _death: VBoxContainer  # 사망 자막 (배경 없음)
var _death_by: RichTextLabel
var _death_sub: Label
var _death_text := ""   # '무기 · 헤드샷' 부분 (뒤의 'N초 뒤 부활'만 매 프레임 바뀜)
var _nums_root: Control
var _nums: Array[Dictionary] = []
var _hitmark: HitMark
var _cross: Crosshair
var _vm: ViewModel
var _ring: ChargeRing
var _w_icon: TextureRect
var _w_icon_kind := ""
var _w_name: Label
var _w_state: Label
var _breath: ProgressBar   # 음유시인 숨 게이지 (무기 칸 상태 줄 아래 가로 막대)
var _w_hint: Label
var _info := {}        # sniper / horse / ak 안내 줄 (HTML #sniperInfo / #horseInfo / #akInfo)
var _notes: VBoxContainer  # 위 가운데 점수판 바로 아래: 아이템 안내 줄 + 무적 막대
var _scope: Scope
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _hurt := 0.0       # 붉은 테두리 세기 (HTML hurt)
var _dance: DanceEdge  # 내가 춤에 걸리면: 분홍 테두리 + 테두리를 도는 음표 (트럼펫 이펙트 7)
var _dirs: DmgDir
var _star: StarEdge          # 황금 붕어빵 무적 (1인칭): 금색 비네트 두근 + 테두리 반짝이
var _star_box: VBoxContainer # 화면 위 가운데: "무적 3.2초" + 금색 막대
var _star_lbl: Label
var _star_bar: ProgressBar
var _timer: Label
var _leader: RichTextLabel
var _feed: VBoxContainer
var _feed_items: Array[Dictionary] = []
var _banner: VBoxContainer
var _banner_t: Label
var _banner_s: Label
var _banner_age := 99.0
var _board: PanelContainer
var _board_host: VBoxContainer
var _board_tick := 0.0
var _clock := 0.0

## 마을 게시판 색 — GameData.UI와 같은 값 (const라 여기 한 번 더 적음, test_ui_kit가 같은지 확인)
const PARCH := Color("#f4e4bc")   # UI.parch
const BLOOD := Color("#d8453b")   # UI.red
const GOLD := Color("#ffd84a")    # UI.marker (형광펜: 강조·알림)
const MUTE := Color("#c9a77c")    # UI.dust
const STEEL := Color("#9cc0f2")   # UI.sky
const MOSS := Color("#6cc35a")    # UI.hp
const INK := Color("#2b1d12")     # UI.ink
const SHADOW := Color(INK, 0.9)
## 데미지 숫자 모양 (HTML .dn / .dn.head / .dn.dot / .dn.kill)
const NUM_STYLE := {
	"": {"size": 22, "color": PARCH},
	"head": {"size": 28, "color": BLOOD},
	"dot": {"size": 17, "color": Color("#bfefff")},
	"kill": {"size": 30, "color": GOLD},
	"dance": {"size": 34, "color": Color("#ff7eb6")},  # 춤춰라! (트럼펫 이펙트)
	"squeak": {"size": 22, "color": Color("#d6d6d6")},  # 삑!
}
const NUM_LIFE := 0.85
const NUM_MAX := 14


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vm = ViewModel.new()  # 1인칭 손·무기 (3D 화면 바로 위, 다른 HUD 아래)
	root.add_child(_vm)

	_nums_root = Control.new()
	_nums_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nums_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_nums_root)

	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_cross)
	_ring = ChargeRing.new()  # 활 당기기 진행 고리 (HTML #ring)
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_ring)
	_hitmark = HitMark.new()
	_hitmark.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_hitmark)

	# 저격총 스코프 (HTML #scope: 가운데 원만 뚫린 검은 화면 + 십자선)
	_scope = Scope.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	root.add_child(_scope)
	# 피격 방향 (HTML #dmgDir) + 붉은 테두리 (HTML #vignette: 가운데 45%부터 바깥으로 붉게)
	_dirs = DmgDir.new()
	_dirs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dirs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dirs)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = sh
	_vignette.material = _vig_mat
	root.add_child(_vignette)
	_dance = DanceEdge.new()
	_dance.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsm := ShaderMaterial.new()
	dsm.shader = sh
	var dcol := GameData.col(GameData.WEAPONS.trumpet.fx.vig_col)
	dsm.set_shader_parameter("col", Vector3(dcol.r, dcol.g, dcol.b))
	_dance.vig = ColorRect.new()
	_dance.vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dance.vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dance.vig.material = dsm
	_dance.add_child(_dance.vig)
	_dance.visible = false
	root.add_child(_dance)
	_star = StarEdge.new()
	_star.set_anchors_preset(Control.PRESET_FULL_RECT)
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssm := ShaderMaterial.new()
	ssm.shader = sh
	var scol := GameData.col(GameData.STAR_FX.gold)
	ssm.set_shader_parameter("col", Vector3(scol.r, scol.g, scol.b))
	_star.vig = ColorRect.new()
	_star.vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_star.vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star.vig.material = ssm
	_star.add_child(_star.vig)
	_star.visible = false
	root.add_child(_star)

	_build_topbar(root)
	_build_feed(root)
	_build_vitals(root)
	_build_weapon(root)
	_ctrl = ControlHud.new()
	_ctrl.hud = self
	_ctrl.visible = false
	root.add_child(_ctrl)
	_build_notes(root)

	# 큰 문구 (HTML #banner: 위에서 24%)
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.anchor_top = 0.24
	_banner.anchor_bottom = 0.24
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_constant_override("separation", 6)
	root.add_child(_banner)
	_banner_t = UiKit.label("", 52, GOLD, _banner)
	_banner_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.caption(_banner_t)
	_banner_s = UiKit.label("", 18, PARCH, _banner)
	_banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.caption(_banner_s)
	_banner.modulate.a = 0.0

	# 조준점 아래 자막 (HTML #killPop: 가운데 + 48px) — 배경 없이 금색 글자 + 외곽선
	var P: Dictionary = GameData.HUD_UI.pop
	_pop = UiKit.label("", int(P.font), GOLD, root)
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.caption(_pop)
	_pop.modulate.a = 0.0

	# 사망 자막 (HTML #death: 위에서 30%) — 배경 없이 개구 "넘어졌다... 다시?"
	var D: Dictionary = GameData.HUD_UI.death
	_death = VBoxContainer.new()
	_death.add_theme_constant_override("separation", int(D.gap))
	_death.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_death.anchor_top = 0.3
	_death.anchor_bottom = 0.3
	_death.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_death)
	var dt := UiKit.scribble(str(D.title), int(D.font), PARCH, _death)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.caption(dt)
	_death_by = UiKit.rich(int(D.by), PARCH, _death)
	UiKit.caption(_death_by)
	_death_sub = UiKit.label("", int(D.sub), MUTE, _death)
	_death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.caption(_death_sub)
	_death.visible = false

	# 점수판 (HTML #board: 가운데, Tab 누르는 동안) — 나무판 (줄 글자가 밝은 색이라)
	var sb := UiKit.Board.new("wood", Vector4(20, 16, 20, 16))
	sb.nails = 4
	_board = sb
	_board.set_anchors_preset(Control.PRESET_CENTER)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board.custom_minimum_size.x = 440
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_board)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	_board.add_child(bv)
	UiKit.wood_text(UiKit.label("점수판", 24, PARCH, bv), 24)
	_board_host = VBoxContainer.new()
	bv.add_child(_board_host)
	_board.visible = false


## 위쪽 가운데 (개인전): 밧줄에 매달린 나무 꼬리표 = 남은 시간, 아래 양피지 = 1위 (HTML #topbar)
func _build_topbar(root: Control) -> void:
	var T: Dictionary = GameData.HUD_UI.top
	var tb := VBoxContainer.new()
	_topbar = tb
	tb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tb.offset_top = float(T.top)
	tb.add_theme_constant_override("separation", int(T.gap))
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tb)
	var tag := UiKit.Board.new("wood", T.tag_pad)
	tag.ropes = true
	tag.rope_len = float(T.rope)
	tag.radius = float(T.tag_r)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tb.add_child(tag)
	_timer = UiKit.label("4:00", int(T.timer_font), PARCH, tag)
	UiKit.wood_text(_timer, int(T.timer_font))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lp := UiKit.Board.new("parch", T.leader_pad)
	lp.radius = 4
	lp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tb.add_child(lp)
	_leader = UiKit.rich(int(T.leader_font), INK, lp)


## 오른쪽 위 킬피드 (HTML #feed): 양피지 줄이 위에서 아래로
func _build_feed(root: Control) -> void:
	var E: float = GameData.HUD_UI.edge
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.offset_top = E
	_feed.offset_right = -E
	_feed.add_theme_constant_override("separation", int(GameData.HUD_UI.feed.sep))
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)


## 왼쪽 아래 나 (HTML #vitals): 둥근 나무 액자(병과 아이콘) + 나무판(병과 이름·체력 숫자·초록 막대)
func _build_vitals(root: Control) -> void:
	var V: Dictionary = GameData.HUD_UI.vitals
	var E: float = GameData.HUD_UI.edge
	var md: float = V.medal
	var pl: Vector2 = V.plank
	var w := md - float(V.overlap) + pl.x
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = E
	box.offset_right = E + w
	box.offset_top = -E - md
	box.offset_bottom = -E
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var plank := UiKit.Board.new("wood", V.pad)
	plank.radius = float(V.r)
	plank.custom_minimum_size = pl
	plank.position = Vector2(md - float(V.overlap), (md - pl.y) / 2.0)
	plank.size = pl
	box.add_child(plank)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	plank.add_child(vb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	_cls = UiKit.label("", int(V.name_font), PARCH, row)
	UiKit.wood_text(_cls, int(V.name_font))
	UiKit.trim_font(_cls, int(V.name_font), 0.18)
	_cls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cls.size_flags_vertical = Control.SIZE_SHRINK_END
	_hp_num = UiKit.label("100", int(V.hp_font), PARCH, row)
	UiKit.wood_text(_hp_num, int(V.hp_font))
	UiKit.trim_font(_hp_num, int(V.hp_font), 0.2)
	_hp = HpBar.new()
	_hp.custom_minimum_size.y = float(V.bar_h)
	vb.add_child(_hp)
	_medal = Medal.new()
	_medal.size = Vector2(md, md)
	box.add_child(_medal)
	# 판 위 작은 쪽지 (투구 없음 · 젖음 · 다음 부활 병과) — 있을 때만
	var nb := UiKit.Board.new("parch", Vector4(10, 2, 10, 4))
	nb.radius = 4
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nb.position = Vector2(md - float(V.overlap) + 6, -26)
	box.add_child(nb)
	_cls_note_box = nb
	_cls_note = UiKit.label("", int(V.note_font), INK, nb)
	nb.visible = false


## 오른쪽 아래 무기 (HTML #weapon): 양피지 칸 = 무기 아이콘 + 이름(형광펜 밑줄) + 한 줄 상태. 아래 작은 "Esc 메뉴 · Tab 점수판"
func _build_weapon(root: Control) -> void:
	var W: Dictionary = GameData.HUD_UI.weapon
	var K: Dictionary = GameData.HUD_UI.keys
	var E: float = GameData.HUD_UI.edge
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -E
	col.offset_bottom = -float(W.bottom)
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	_w_hint = UiKit.label("", int(W.hint_font), GOLD, col)  # Q 안내 (특수 무기 있을 때)
	UiKit.wood_text(_w_hint, int(W.hint_font), GOLD)
	_w_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	var wp := UiKit.Board.new("parch", W.pad)
	wp.nails = 2
	wp.radius = float(W.r)
	wp.custom_minimum_size = W.size
	wp.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(wp)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(W.gap))
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wp.add_child(hb)
	_w_icon = UiKit.weapon_icon("stone", float(W.icon))
	hb.add_child(_w_icon)
	var wvb := VBoxContainer.new()
	wvb.add_theme_constant_override("separation", 0)
	wvb.alignment = BoxContainer.ALIGNMENT_CENTER
	wvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(wvb)
	_w_name = UiKit.label("", int(W.name_font), INK, wvb)
	UiKit.trim_font(_w_name, int(W.name_font), float(W.trim))
	_w_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiKit.marker_under(_w_name)
	_w_state = UiKit.label("", int(W.state_font), UiKit.c("brown"), wvb)
	UiKit.trim_font(_w_state, int(W.state_font), float(W.trim))
	_breath = ProgressBar.new()
	_breath.show_percentage = false
	_breath.custom_minimum_size = Vector2(0, float(W.breath_h))
	_breath.max_value = float(GameData.WEAPONS.trumpet.breath_max)
	_breath.add_theme_stylebox_override("background", UiKit.box(Color("#e2c992"), INK, 2, 4))
	_breath.add_theme_stylebox_override("fill", UiKit.box(Color("#9fd0ff"), INK, 2, 4))
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath.visible = false
	wvb.add_child(_breath)
	# 맨 아래 작은 글씨: 속도 · Esc 메뉴 · Tab 점수판
	var keys := HBoxContainer.new()
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	keys.offset_right = -E - 3
	keys.offset_bottom = -float(K.bottom)
	keys.add_theme_constant_override("separation", 10)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(keys)
	_speed = UiKit.rich(int(K.font), PARCH, keys)  # 속도 (HTML #speed — 가운데 아래에서 모서리로 옮김)
	_speed.add_theme_color_override("font_outline_color", INK)
	_speed.add_theme_constant_override("outline_size", UiKit.outline_for(int(K.font)))
	_speed.size_flags_vertical = Control.SIZE_SHRINK_END
	var kl := UiKit.label(str(K.text), int(K.font), PARCH, keys)
	UiKit.wood_text(kl, int(K.font))


## 위 가운데 점수판 바로 아래: 특수 아이템 안내 줄 + 황금 붕어빵 무적 막대
func _build_notes(root: Control) -> void:
	_notes = VBoxContainer.new()
	_notes.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notes.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notes.add_theme_constant_override("separation", 2)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)
	for kv in [["sniper", GOLD], ["horse", Color("#ffb37a")], ["ak", Color("#ff9a6a")]]:
		var l := UiKit.label("", 15, kv[1], _notes)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UiKit.caption(l)
		_info[kv[0]] = l
	_build_star_bar(_notes)


# ── 알림들 ───────────────────────────────────────────────────
## 조준점 아래 양피지 쪽지 — HTML popMsg / killPopShow (1초 동안 커졌다 줄고, 위로 살짝 뜨며 사라짐)
func pop_msg(text: String) -> void:
	_pop.text = text
	_pop.reset_size()
	_pop_t = 0.0
	_pop.pivot_offset = _pop.size / 2


## 가운데 위 큰 문구 — HTML banner (2.8초)
func banner(t: String, s: String) -> void:
	_banner_t.text = t
	_banner_s.text = s
	_banner_age = 0.0


## HTML killfeed: 양피지 줄 '공격자 [무기 아이콘] 피해자 [헤드샷]'. 이름은 팀 색(개인전은 잉크), 나는 "나" + 형광펜.
## 내가 낀 줄은 형광펜 테두리. 5줄, 5.5초
func killfeed(a: PlayerController, v: PlayerController, kind: String, head: bool) -> void:
	var F: Dictionary = GameData.HUD_UI.feed
	var me := (a != null and a.is_local) or v.is_local
	var pc := UiKit.Board.new("parch", F.pad)
	pc.radius = float(F.r)
	if me:
		pc.ring = GOLD
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(F.gap))
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	_feed_name(a, hb)
	var ic := UiKit.weapon_icon(kind, float(F.icon))
	ic.tooltip_text = str(GameData.WEAPONS[kind].name) if GameData.WEAPONS.has(kind) else kind
	hb.add_child(ic)
	_feed_name(v, hb)
	if head:  # 빨간 작은 꼬리표 (글자라 살짝만 기울임)
		var hp := PanelContainer.new()
		hp.add_theme_stylebox_override("panel", UiKit.box(GameData.col(F.head_col), Color.TRANSPARENT, 0, 4, Vector4(5, 0, 5, 1)))
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.label("헤드샷", int(F.head_font), Color.WHITE, hp)
		hb.add_child(UiKit.tilted(hp, float(F.head_tilt)))
		hp.get_parent().size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_feed.add_child(pc)
	_feed.move_child(pc, 0)
	_feed_items.push_front({"n": pc, "t": 0.0})
	while _feed_items.size() > GameData.FEED_MAX:
		(_feed_items.pop_back().n as Node).queue_free()


func _feed_name(e: PlayerController, parent: Node) -> void:
	var F: Dictionary = GameData.HUD_UI.feed
	var l := UiKit.label((str(F.me) if e.is_local else e.ent_name) if e else "?", int(F.font), _name_col(e), parent)
	UiKit.trim_font(l, int(F.font), float(F.trim))
	if e and e.is_local:
		UiKit.marker_under(l)


## 양피지 위 이름 색: 쟁탈전이면 팀 색(진하게), 아니면 잉크
static func _name_col(e: PlayerController) -> Color:
	if e and e.team != "":
		return Color(str(GameData.MODES.control.teams[e.team].ink))
	return INK


## 내가 죽었을 때 — HTML showDeath
func show_death(a: PlayerController, kind: String, head: bool) -> void:
	var red := str(GameData.MODES.control.teams.red.ink)
	_death_by.text = "[center][color=%s]%s[/color]에게 당했다[/center]" % [red, UiKit.esc(a.ent_name if a else "누군가")]
	_death_text = GameData.WEAPONS[kind].name + (" · 헤드샷" if head else "")
	_death_sub.text = _death_text + " · 잠시 후 부활"
	_death.visible = true


## 황금 붕어빵 무적 남은 시간 (화면 위 가운데, 아이템 안내 줄 아래)
func _build_star_bar(parent: Control) -> void:
	_star_box = VBoxContainer.new()
	_star_box.add_theme_constant_override("separation", 3)
	_star_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_star_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_star_box)
	_star_lbl = UiKit.label("", 20, GOLD, _star_box)
	_star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.caption(_star_lbl)
	_star_bar = ProgressBar.new()
	_star_bar.show_percentage = false
	_star_bar.custom_minimum_size = Vector2(240, 12)
	_star_bar.max_value = float(GameData.ITEM.golden_fish.dur)
	_star_bar.add_theme_stylebox_override("background", UiKit.box(Color(INK, 0.55), INK, 2, 6))
	_star_bar.add_theme_stylebox_override("fill", UiKit.box(GOLD, INK, 2, 6))
	_star_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_box.add_child(_star_bar)
	_star_box.visible = false


## 새 경기·메뉴로 갈 때 남은 알림을 치운다 (HTML clearMatchObjects의 nums·feed 부분)
func clear() -> void:
	for n in _nums:
		(n.l as Node).queue_free()
	_nums.clear()
	for f in _feed_items:
		(f.n as Node).queue_free()
	_feed_items.clear()
	_death.visible = false
	_pop_t = 99.0
	_pop.modulate.a = 0.0
	_banner_age = 99.0
	_banner.modulate.a = 0.0
	show_board = false
	_hurt = 0.0
	_dirs.items.clear()
	_dirs.queue_redraw()


## 내가 맞음 — 붉은 테두리가 피해/60만큼 진해진다
func on_hurt(dmg: float) -> void:
	_hurt = minf(1.0, _hurt + dmg / float(GameData.HURT.per_dmg))


## 때린 사람 쪽에 붉은 호 — 맞은 순간 내가 보던 방향 기준 (HTML dmgDir)
func dmg_dir(from: Vector3) -> void:
	if not player:
		return
	var dx := from.x - player.global_position.x
	var dz := from.z - player.global_position.z
	_dirs.add(atan2(-dx, -dz) - player.yaw)


## 맞은 자리에서 떠오르는 숫자 — HTML spawnNum
func spawn_num(pos: Vector3, text: String, style: String) -> void:
	var st: Dictionary = NUM_STYLE.get(style, NUM_STYLE[""])
	var l := UiKit.label(text, st.size, st.color, _nums_root)
	UiKit.caption(l)
	l.reset_size()
	l.pivot_offset = l.size / 2
	l.visible = false
	_nums.append({"l": l, "p": pos + Vector3(randf_range(-0.2, 0.2), 0.35, randf_range(-0.2, 0.2)),
		"life": NUM_LIFE, "dx": randf_range(-28, 28)})
	if _nums.size() > NUM_MAX:
		(_nums.pop_front().l as Label).queue_free()


func hitmark(is_kill: bool) -> void:
	_hitmark.pop(is_kill)


## 양피지 위 강조 (형광펜 바탕)
static func _hl(s: String) -> String:
	return "[bgcolor=#ffd84a]%s[/bgcolor]" % s


func _update_nums(dt: float) -> void:
	var cam: Camera3D = player.cam if player else null
	for i in range(_nums.size() - 1, -1, -1):
		var n := _nums[i]
		var l: Label = n.l
		n.life -= dt
		if n.life <= 0 or not cam:
			l.queue_free()
			_nums.remove_at(i)
			continue
		var p: Vector3 = n.p
		p.y += dt * 1.3
		n.p = p
		if cam.is_position_behind(p):
			l.visible = false
			continue
		var t: float = 1.0 - n.life / NUM_LIFE
		var sc := 1.7 - t / 0.12 * 0.7 if t < 0.12 else 1.0
		var sp := cam.unproject_position(p)  # canvas_items 늘이기에서도 HUD 좌표와 같다
		l.visible = true
		l.modulate.a = minf(1.0, n.life / 0.3)
		l.position = sp + Vector2(float(n.dx) * t, 0) - l.size / 2
		l.scale = Vector2.ONE * sc


func _process(dt: float) -> void:
	if not player or not visible:
		return
	var e := player
	_clock += dt
	_update_nums(dt)
	var HU: Dictionary = GameData.HURT
	_hurt = maxf(0.0, _hurt - dt * float(HU.decay))
	var vig := minf(float(HU.max), _hurt + (float(HU.low_add) if e.alive and e.hp < float(HU.low_hp) else 0.0))
	_vig_mat.set_shader_parameter("alpha", vig)
	_vignette.visible = vig > 0.001
	_dirs.tick(dt)
	_dance.tick(dt, e.alive and e.dance_t > 0)
	var starred := e.alive and e.star_t > 0
	_star.tick(dt, starred and not e.tp_view(), e.star_t)
	_star_box.visible = starred
	if starred:
		_star_lbl.text = "무적 %.1f초" % e.star_t
		_star_bar.value = e.star_t
		var c := StarFx.flash_color(e.star_t, Time.get_ticks_msec() / 1000.0)  # 막대도 같이 번쩍
		(_star_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c if c.a > 0 else GOLD
	_vm.player = e
	_update_weapon()
	_update_anims(dt)
	# 시간·1위
	var tl := maxi(0, ceili(time_left))
	_timer.text = "%d:%02d" % [tl / 60, tl % 60]
	_timer.add_theme_color_override("font_color", BLOOD if tl <= GameData.TIMER_LOW else PARCH)
	var rows := combat.score_rows() if combat else ([] as Array[PlayerController])
	if rows.size() > 0:
		var top: PlayerController = rows[0]
		if top == e:
			_leader.text = "%s 나 %d킬 · 목표 %d" % [_hl("1위"), e.kills, GameData.KILL_LIMIT]
		else:
			_leader.text = "1위 %s %s킬 · 나 %d킬 · %d위" % [UiKit.esc(top.ent_name), _hl(str(top.kills)), e.kills, rows.find(e) + 1]
	# 병과·체력 (이름은 나무판, 상태는 판 위 작은 쪽지)
	_cls.text = GameData.CLASSES[e.cls].name
	var notes := PackedStringArray()
	if e.alive and not e.helmet:
		notes.append("투구 없음")
	if e.alive and e.slow_t > 0:
		notes.append("성수에 젖어 느려짐")
	var note := " · ".join(notes)
	if e.next_cls != "" and e.next_cls != e.cls:
		note += (" " if note != "" else "") + "→ 다음 부활 %s" % GameData.CLASSES[e.next_cls].name
	if note != _cls_note.text:
		_cls_note.text = note
		_cls_note_box.visible = note != ""
		_cls_note_box.reset_size()
	_medal.cls = e.cls
	var V: Dictionary = GameData.HUD_UI.vitals
	var mh := GameData.class_hp(e.cls)
	var hp := maxi(0, ceili(e.hp))
	var hpp := float(hp) / mh
	var hc := MOSS if hpp > 0.5 else GOLD
	if hpp <= float(V.low):  # 낮으면 빨갛게 깜빡
		hc = BLOOD.lerp(GameData.col(V.blink_col), 0.5 + 0.5 * sin(_clock * TAU * float(V.blink_hz)))
	_hp.set_state(hpp, hc, e.alive and e.no_hit_t >= GameData.REGEN_DELAY and e.hp < mh)  # 재생 중엔 둘레가 초록으로 빛남
	_vitals_regen = _hp.glow
	_hp_num.text = str(hp)
	# 속도·조준점
	var hs := Vector2(e.velocity.x, e.velocity.z).length()
	_speed.text = "%.1f[font_size=11] m/s[/font_size]" % hs
	var gap := 6 + minf(hs, 18) * 0.7 + (0.0 if e.grounded else 6.0) + (4.0 if e.wep == "stone" else 0.0)
	if e.wep == "ak":
		gap += (-3.0 if e.aim_held else 6.0) + e.bloom * 260
	_cross.set_gap(gap)
	var scoped := e.is_scoped()
	_cross.visible = e.alive and not scoped
	_scope.visible = scoped
	_update_info(e)
	# 사망 화면
	if e.alive:
		_death.visible = false
	elif _death.visible:
		_death_sub.text = "%s · %d초 뒤 부활" % [_death_text, maxi(1, ceili(e.respawn))]
	_death.position.x = (_death.get_parent_area_size().x - _death.size.x) / 2
	# 아이템 안내 줄은 위 가운데 점수판 바로 아래
	var top_end: float = (_ctrl.top_h() if mode else _topbar.position.y + _topbar.size.y)
	_notes.offset_top = top_end + float(GameData.HUD_UI.notes_gap)
	# 점수판
	_board.visible = show_board
	if show_board:
		_board_tick -= dt
		if _board_tick <= 0:
			_board_tick = GameData.BOARD_TICK
			for ch in _board_host.get_children():
				ch.queue_free()
			_board_host.add_child(UiKit.team_table(rows, e) if mode else UiKit.score_table(rows, e))
	else:
		_board_tick = 0.0


## banner·killPop·킬피드 시간 흐름 (HTML CSS 애니메이션 ban / kp / kfin)
func _update_anims(dt: float) -> void:
	_banner_age += dt
	var bt: float = GameData.BANNER_T
	var u := _banner_age / bt
	if u < 1.0:  # 0~8%: 1.25배에서 줄며 나타남, 80~100%: 사라짐
		_banner.modulate.a = u / 0.08 if u < 0.08 else (1.0 if u < 0.8 else 1.0 - (u - 0.8) / 0.2)
		_banner.pivot_offset = _banner.size / 2
		_banner.scale = Vector2.ONE * (lerpf(1.25, 1.0, u / 0.08) if u < 0.08 else 1.0)
	else:
		_banner.modulate.a = 0.0
	_pop_t += dt
	var pt: float = GameData.POP_T
	var k := _pop_t / pt
	var area := _pop.get_parent_area_size()
	var y := area.y / 2 + float(GameData.HUD_UI.pop.y)
	if k < 1.0:  # 0~12%: 1.7배에서 줄며 나타남, 75~100%: 12px 떠오르며 사라짐
		_pop.modulate.a = k / 0.12 if k < 0.12 else (1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.25)
		_pop.scale = Vector2.ONE * (lerpf(1.7, 1.0, k / 0.12) if k < 0.12 else 1.0)
		if k > 0.75:
			y -= 12 * (k - 0.75) / 0.25
	else:
		_pop.modulate.a = 0.0
	_pop.position = Vector2((area.x - _pop.size.x) / 2, y)
	for i in range(_feed_items.size() - 1, -1, -1):
		var f := _feed_items[i]
		f.t += dt
		var n: Control = f.n
		n.modulate.a = minf(1.0, f.t / 0.18)
		if f.t >= GameData.FEED_LIFE:
			n.queue_free()
			_feed_items.remove_at(i)


## 무기 이름·상태 문구·조준점 고리 — HTML updateHUD의 wName / wState / ring
func _update_weapon() -> void:
	var e := player
	_w_name.text = GameData.WEAPONS[e.wep].name
	_w_name.add_theme_color_override("font_color", Color(str(GameData.MODES.control.teams.red.ink)) if e.wep == "sniper" or e.wep == "ak" else INK)
	if e.wep != _w_icon_kind:
		_w_icon_kind = e.wep
		_w_icon.texture = UiKit.weapon_tex(e.wep, float(GameData.HUD_UI.weapon.icon))
		_w_icon.custom_minimum_size = UiKit.weapon_icon(e.wep, float(GameData.HUD_UI.weapon.icon)).custom_minimum_size
	var st := ""
	var ring := -1.0
	var ring_col := GOLD
	match e.wep:
		"stone":
			st = "던지는 중" if e.cd > 0 else "누르고 있으면 계속 던짐"
		"bow":
			var B: Dictionary = GameData.WEAPONS.bow
			if e.charging:
				var p := e.charge / float(B.full)
				ring = p
				st = "당기는 중 %d%% · %d 피해" % [roundi(p * 100), roundi(lerpf(B.dmg_min, B.dmg_max, p))]
				ring_col = BLOOD if p >= 1 else GOLD
			else:
				st = "화살 거는 중" if e.cd > 0 else "누르고 당겼다 놓기"
			if e.hold_t > float(B.sway_start):
				st = "팔이 후들거린다! %.1f초 뒤 놓침" % maxf(0.0, float(B.slip_t) - e.hold_t)
				ring_col = BLOOD
		"crossbow":
			var X: Dictionary = GameData.WEAPONS.crossbow
			if e.cd > 0:
				var q := WeaponModels.xbow_progress(e.cd)
				var stage := "석궁 세우는 중" if q < 0.18 else ("시위 당기는 중" if q < 0.64 else ("화살 끼우는 중" if q < 0.86 else "조준 자세로"))
				st = "%s · %.1f초" % [stage, e.cd]
				ring = q
				ring_col = STEEL
			else:
				st = "장전 완료 · %d 피해" % int(X.dmg)
		"holy":
			var H2: Dictionary = GameData.WEAPONS.holy
			var mx := int(H2.max_charges)
			var rc: float = H2.recharge
			var pips := "●".repeat(e.charges) + "○".repeat(mx - e.charges)
			if e.charges < mx:
				ring = e.charge_t / rc
				ring_col = STEEL
			if e.charges <= 0:
				st = "성수 %s · 채우는 중 %.1f초" % [pips, rc - e.charge_t]
			else:
				st = "성수 %s · 클릭: 던지기" % pips
				if e.charges < mx:
					st += " · 다음 %.1f초" % (rc - e.charge_t)
		"ak":
			st = "%d/%d발 · 누르고 있으면 연사 · 우클릭 정조준" % [e.ak_ammo, int(GameData.WEAPONS.ak.mag)]
		"sniper":
			st = "남은 탄 %d발 · 우클릭 조준" % maxi(1, e.ammo)
		"chicken":
			st = "클릭: 던지기 · 맞으면 넘어짐"
		"trumpet":
			if e.gasp_t > 0:
				st = "숨이 찼다! 헐떡이는 중"
			elif e.squeak_t > 0:
				st = "삑사리! 입술 고르는 중"
			elif e.playing:
				st = "연주 중 · 숨 %.1f초" % e.breath
			else:
				st = "누르고 있으면 연주 · 우클릭 팡파레"
			if e.fan_cd > 0:
				st += " · 팡파레 %.0f초" % ceilf(e.fan_cd)
		"lance":
			st = "말 타는 중 %.1f초 · 찌르면 70 피해 + 멀리 날림" % maxf(0.0, e.mounted)
			ring = e.mounted / GameData.HORSE_TIME
			ring_col = Color("#ffb37a")
	_w_state.text = "넘어져서 공격 불가" if e.fall_t > 0 else ("춤추느라 공격 불가" if e.dance_t > 0 else st)
	_breath.visible = e.wep == "trumpet"
	if _breath.visible:
		_breath.value = e.breath
		var fs := _breath.get_theme_stylebox("fill") as StyleBoxFlat
		fs.bg_color = BLOOD if e.gasp_t > 0 else (GOLD if e.breath < 1.0 else Color("#9fd0ff"))
	var hint := ""
	if e.has_sniper:
		hint = "Q  원래 무기로" if e.wep == "sniper" else "Q  대물 저격총 꺼내기"
	elif e.has_ak:
		hint = "Q  원래 무기로" if e.wep == "ak" else "Q  AK-47 꺼내기"
	_w_hint.text = hint
	_w_hint.visible = hint != ""
	_ring.set_value(ring if e.alive else -1.0, ring_col)


## 특수 아이템 안내 — 맵에 있으면 거리·남은 시간, 누가 들고 있으면 경고 (HTML updateHUD 끝부분)
func _update_info(e: PlayerController) -> void:
	var it: Items = combat.items if combat else null
	if not it:
		return
	var others := combat.ents.filter(func(o: PlayerController) -> bool: return o != e)
	var sl: Label = _info.sniper
	var holder: Array = others.filter(func(o: PlayerController) -> bool: return o.has_sniper)
	if it.sniper.active and e.alive:
		sl.text = "대물 저격총 %dm · %d초 뒤 사라짐" % [roundi(e.global_position.distance_to(it.sniper.pos)), ceili(it.sniper.life)]
	elif holder.size() > 0:
		sl.text = "⚠ %s이(가) 대물 저격총을 들고 있다" % holder[0].ent_name
	else:
		sl.text = ""
	var hl: Label = _info.horse
	var rider: Array = others.filter(func(o: PlayerController) -> bool: return o.mounted > 0)
	if it.horse.active and e.alive:
		hl.text = "기사의 말 %dm · %d초 뒤 사라짐" % [roundi(e.global_position.distance_to(it.horse.pos)), ceili(it.horse.life)]
	elif rider.size() > 0:
		hl.text = "⚠ %s이(가) 말을 타고 돌격 중 · %d초" % [rider[0].ent_name, ceili(rider[0].mounted)]
	else:
		hl.text = ""
	var al: Label = _info.ak
	var ah: Array = others.filter(func(o: PlayerController) -> bool: return o.has_ak)
	if it.ak.active and e.alive:
		al.text = "AK-47 %dm · %d초 뒤 사라짐" % [roundi(e.global_position.distance_to(it.ak.pos)), ceili(it.ak.life)]
	elif ah.size() > 0:
		al.text = "⚠ %s이(가) AK-47을 들고 있다" % ah[0].ent_name
	else:
		al.text = ""
	for k: String in _info:
		(_info[k] as Label).visible = (_info[k] as Label).text != ""


const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float alpha = 0.0;
uniform vec3 col = vec3(0.7843, 0.1176, 0.1569);
void fragment() {
	// CSS radial-gradient(ellipse at center, transparent 45%, rgba(200,30,40,.65) 100%) — 타원은 모서리를 지남
	float d = length((UV - 0.5) * 2.0) / sqrt(2.0);
	float k = clamp((d - 0.45) / 0.55, 0.0, 1.0);
	COLOR = vec4(col, 0.65 * k * alpha);
}
"""


## 피격 방향 — 조준점에서 185px 위에 붉은 호 (위가 두꺼운 반달). 1초 동안 60%까지 진하다가 사라짐. 최대 4개
class DmgDir extends Control:
	var items: Array = []  # [{ang, t}]

	func add(ang: float) -> void:
		items.append({"ang": ang, "t": 0.0})
		while items.size() > int(GameData.DMG_DIR.max):
			items.pop_front()
		queue_redraw()

	func tick(dt: float) -> void:
		if items.is_empty():
			return
		var life: float = GameData.DMG_DIR.life
		for it: Dictionary in items:
			it.t += dt
		items = items.filter(func(it: Dictionary) -> bool: return it.t < life)
		queue_redraw()

	func _draw() -> void:
		var D: Dictionary = GameData.DMG_DIR
		var rx: float = D.w / 2.0
		var ry: float = D.h
		var th: float = D.thick
		var cy: float = -float(D.r) + ry  # 반달 아래쪽 가운데
		var blood := GameData.col(GameData.UI.red)
		for it: Dictionary in items:
			var k: float = it.t / float(D.life)
			var a := 1.0 if k < float(D.hold) else maxf(0.0, 1.0 - (k - float(D.hold)) / (1.0 - float(D.hold)))
			draw_set_transform(size / 2, -float(it.ang))
			for g in 3:  # 번지는 빛 (drop-shadow 6px)
				_arc(rx + 3 + g * 2, ry + 3 + g * 2, th + 4 + g * 2, cy, Color(blood, a * 0.12))
			_arc(rx, ry, th, cy, Color(blood, a))
		draw_set_transform(Vector2.ZERO)

	## 위쪽 반 타원 테두리 — 꼭대기에서 두께 th, 양 끝으로 갈수록 얇아짐 (CSS border-top + 둥근 모서리)
	func _arc(rx: float, ry: float, th: float, cy: float, c: Color) -> void:
		var pts := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var t := PI + PI * i / n
			pts.append(Vector2(cos(t) * rx, cy + sin(t) * ry))
		for i in range(n, -1, -1):
			var t := PI + PI * i / n
			pts.append(Vector2(cos(t) * rx, cy + sin(t) * (ry - th)))
		draw_colored_polygon(pts, c)


## 저격총 스코프 — HTML #scope: 반지름 min(32vh,32vw) 원 밖은 거의 검정, 가운데 십자선
class Scope extends Control:
	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) * 0.32
		var dark := Color(8 / 255.0, 9 / 255.0, 16 / 255.0, 0.97)
		# 원 밖을 덮는 다각형 (큰 사각형에서 원을 뺀 모양을 부채꼴 띠로 채움)
		var n := 96
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var far := size.length()
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a0), sin(a0)) * far,
				c + Vector2(cos(a1), sin(a1)) * far, c + Vector2(cos(a1), sin(a1)) * r]), dark)
		var line := Color(8 / 255.0, 9 / 255.0, 16 / 255.0, 0.9)
		draw_rect(Rect2(c.x - 1, size.y * 0.18, 2, size.y * 0.64), line)
		draw_rect(Rect2(c.x - r, c.y - 1, r * 2, 2), line)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## 조준점 둘레 진행 고리 (반지름 24, 위에서 시계 방향) — HTML #ring
class ChargeRing extends Control:
	var _v := -1.0
	var _c := Hud.GOLD

	func set_value(v: float, c: Color) -> void:
		if v == _v and c == _c:
			return
		_v = v
		_c = c
		queue_redraw()

	func _draw() -> void:
		if _v < 0:
			return
		draw_arc(Vector2.ZERO, 24, 0, TAU, 48, Color(Hud.INK, 0.3), 3.5, true)
		if _v > 0.001:  # 금색 호 (시안 #ring) — 잉크 테를 먼저 깔아 밝은 땅에서도 보이게
			var a1 := -PI / 2 + TAU * minf(_v, 1.0)
			draw_arc(Vector2.ZERO, 24, -PI / 2, a1, 48, Color(Hud.INK, 0.75), 6.0, true)
			draw_arc(Vector2.ZERO, 24, -PI / 2, a1, 48, _c, 3.5, true)


## 맞히면 조준점에 잠깐 뜨는 X (처치면 빨간색) — HTML #hitmark
class HitMark extends Control:
	var _t := 0.0
	var _life := 0.0
	var _kill := false

	func pop(is_kill: bool) -> void:
		_kill = is_kill
		_life = 0.26 if is_kill else 0.12
		_t = 0.0
		queue_redraw()

	func _process(dt: float) -> void:
		if _life <= 0 and _t > 0.3:
			return
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 if _t < _life else maxf(0.0, 1.0 - (_t - _life) / 0.12)
		if a <= 0:
			return
		var sc := lerpf(1.9, 1.0, minf(1.0, _t / 0.16))  # 크게 튀어나왔다 줄어듦
		var c := Hud.BLOOD if _kill else Hud.PARCH
		c.a = a
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dir: Vector2 = d.normalized()
			draw_line(dir * 4.2 * sc, dir * 14.0 * sc, Color(0, 0, 0, 0.4 * a), 4.0)
			draw_line(dir * 4.2 * sc, dir * 14.0 * sc, c, 2.0)


## 십자 조준점 — HTML .xh: 막대 4개(2×9)와 점, 빨리 움직이거나 공중이면 벌어짐(--gap)
class Crosshair extends Control:
	var _gap := 7.0

	func set_gap(g: float) -> void:
		if absf(g - _gap) > 0.05:
			_gap = g
			queue_redraw()

	func _draw() -> void:
		var c := Hud.PARCH
		var sh := Color(Hud.INK, 0.7)
		for r: Rect2 in [Rect2(-1, -_gap - 9, 2, 9), Rect2(-1, _gap, 2, 9), Rect2(-_gap - 9, -1, 9, 2), Rect2(_gap, -1, 9, 2)]:
			draw_rect(r.grow(1), sh)
			draw_rect(r, c)
		draw_circle(Vector2.ZERO, 3, sh)
		draw_circle(Vector2.ZERO, 2, c)


## 내가 춤에 걸렸을 때 화면 (트럼펫 이펙트 7): 가장자리 분홍빛 비네트 + 테두리를 따라 둥둥 떠다니는 음표.
## 음표는 글자(♪) 대신 원·막대·깃발을 직접 그린다 (폰트에 없을 수 있어서). 수치는 WEAPONS.trumpet.fx
class DanceEdge extends Control:
	var vig: ColorRect
	var k := 0.0   # 0~1 나타나는 정도
	var t := 0.0

	func tick(dt: float, on: bool) -> void:
		k = move_toward(k, 1.0 if on else 0.0, dt * 4.0)
		t += dt
		visible = k > 0.001
		if visible:
			(vig.material as ShaderMaterial).set_shader_parameter("alpha", k * float(GameData.WEAPONS.trumpet.fx.vig_alpha))
			queue_redraw()

	func _edge_point(u: float, m: float) -> Vector2:
		var w := size.x - 2 * m
		var h := size.y - 2 * m
		var d := fposmod(u, 1.0) * 2.0 * (w + h)
		if d < w:
			return Vector2(m + d, m)
		d -= w
		if d < h:
			return Vector2(m + w, m + d)
		d -= h
		if d < w:
			return Vector2(m + w - d, m + h)
		return Vector2(m, m + h - (d - w))

	func _draw() -> void:
		var FX: Dictionary = GameData.WEAPONS.trumpet.fx
		var cols: Array = FX.colors
		var n := int(FX.edge_notes)
		for i in n:
			var p := _edge_point(float(i) / n + t * 0.035, 38.0 + sin(t * 3.0 + i * 1.7) * 10.0)
			var c := GameData.col(cols[i % cols.size()])
			c.a = 0.85 * k
			var sc := 0.9 + 0.25 * sin(t * 5.0 + i)
			draw_set_transform(p, sin(t * 2.6 + i) * 0.35, Vector2(sc, sc))
			draw_circle(Vector2(-4, 10), 8.5, c)                       # 머리
			draw_rect(Rect2(2.5, -22, 3.5, 32), c)                     # 기둥
			draw_colored_polygon(PackedVector2Array([Vector2(2.5, -22), Vector2(15, -12), Vector2(14, -6), Vector2(2.5, -14)]), c)  # 깃발
		draw_set_transform_matrix(Transform2D.IDENTITY)


## 황금 붕어빵 무적일 때 1인칭 화면: 가장자리 금색 비네트가 맥박처럼 두근 + 테두리를 따라 떠다니는 반짝이 (별을 직접 그림).
## 끝나기 1초 전부터는 비네트가 빠르게 깜빡임. 수치는 GameData.STAR_FX
class StarEdge extends Control:
	var vig: ColorRect
	var k := 0.0
	var t := 0.0
	var left := 0.0

	func tick(dt: float, on: bool, star_left: float) -> void:
		k = move_toward(k, 1.0 if on else 0.0, dt * 5.0)
		t += dt
		left = star_left
		visible = k > 0.001
		if visible:
			var F: Dictionary = GameData.STAR_FX
			var beat := 0.55 + 0.45 * absf(sin(t * PI * float(F.vig_hz)))  # 두근두근
			if left < float(F.end_t) and int(floor(t * float(F.end_hz))) % 3 == 2:
				beat = 0.15
			(vig.material as ShaderMaterial).set_shader_parameter("alpha", k * float(F.vig_alpha) * beat)
			queue_redraw()

	func _edge_point(u: float, m: float) -> Vector2:
		var w := size.x - 2 * m
		var h := size.y - 2 * m
		var d := fposmod(u, 1.0) * 2.0 * (w + h)
		if d < w:
			return Vector2(m + d, m)
		d -= w
		if d < h:
			return Vector2(m + w, m + d)
		d -= h
		if d < w:
			return Vector2(m + w - d, m + h)
		return Vector2(m, m + h - (d - w))

	func _draw() -> void:
		var F: Dictionary = GameData.STAR_FX
		var n := int(F.edge_sparks)
		for i in n:
			var p := _edge_point(float(i) / n - t * 0.05 + sin(i * 2.3) * 0.02, 30.0 + sin(t * 2.5 + i * 1.9) * 14.0)
			var tw := absf(sin(t * 4.0 + i * 1.3))  # 반짝반짝
			var c := GameData.col(F.gold if i % 3 != 0 else F.white)
			c.a = k * (0.35 + 0.65 * tw)
			var r := 7.0 + 9.0 * tw
			var q := r * 0.22
			draw_set_transform(p, t * 1.5 + i, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(q, -q), Vector2(r, 0), Vector2(q, q),
				Vector2(0, r), Vector2(-q, q), Vector2(-r, 0), Vector2(-q, -q)]), c)  # 네 갈래 별
		draw_set_transform_matrix(Transform2D.IDENTITY)


## 왼쪽 아래 체력 막대 (시안: 어두운 홈 + 초록 채움, 둘 다 잉크 테두리, 채움 아래쪽 그늘). 재생 중엔 둘레가 초록으로 빛남
class HpBar extends Control:
	var k := 1.0
	var col := Hud.MOSS
	var glow := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(v: float, c: Color, g: bool) -> void:
		v = clampf(v, 0.0, 1.0)
		if is_equal_approx(v, k) and c.is_equal_approx(col) and g == glow:
			return
		k = v
		col = c
		glow = g
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var r := int(h / 2)
		if glow:
			for i in 3:
				var g := UiKit.box(Color.TRANSPARENT, Color(Hud.MOSS, 0.28 - i * 0.08), 2, r + 3 + i * 2)
				draw_style_box(g, Rect2(Vector2.ONE * -(3 + i * 2), size + Vector2.ONE * (6 + i * 4)))
		draw_style_box(UiKit.box(GameData.col(GameData.HUD_UI.vitals.bar_bg), Hud.INK, 2, r), Rect2(Vector2.ZERO, size))
		if k > 0.0:
			var w := maxf(h, size.x * k)
			draw_style_box(UiKit.box(col, Hud.INK, 2, r), Rect2(0, 0, w, h))
			draw_rect(Rect2(r, h - 6, maxf(0.0, w - 2 * r), 4), Color(0, 0, 0, 0.2))


## 왼쪽 아래 둥근 나무 액자 + 병과 아이콘 (병과 색 동그라미)
class Medal extends Control:
	var cls := "":
		set(v):
			if v != cls:
				cls = v
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var V: Dictionary = GameData.HUD_UI.vitals
		var c := size / 2
		var R := size.x / 2
		var ri: float = float(V.medal_in) / 2.0
		draw_circle(c + Vector2(0, 4), R, Hud.INK, true, -1, true)            # 아래 그림자
		draw_circle(c, R, Hud.INK, true, -1, true)                            # 잉크 테
		draw_circle(c, R - 2.7, UiKit.c("wood_lo"), true, -1, true)           # 나무 (위 밝게)
		draw_circle(c - Vector2(0, 2), R - 4.5, UiKit.c("wood"), true, -1, true)
		draw_circle(c - Vector2(0, R * 0.35), R * 0.55, Color(UiKit.c("wood_hi"), 0.55), true, -1, true)
		for i in 3:  # 나뭇결 (가로 띠)
			var y := c.y - R * 0.6 + i * R * 0.6
			var hw := sqrt(maxf(0.0, (R - 5) * (R - 5) - pow(y - c.y, 2)))
			draw_line(Vector2(c.x - hw, y), Vector2(c.x + hw, y), Color(0.24, 0.12, 0.04, 0.3), 2.0)
		if cls == "":
			return
		draw_circle(c, ri + 2, Hud.INK, true, -1, true)
		draw_circle(c, ri, GameData.col(GameData.CLASS_EMBLEM[cls]), true, -1, true)
		var tex := UiKit.icon(cls)
		var s := ri * 1.3
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), false)
