class_name Hud
extends CanvasLayer
## 경기 중 화면 UI — HTML #hud (updateHUD).
## 조준점·당기기 고리·맞힘 X, 위쪽 시간·1위, 오른쪽 위 킬피드, 왼쪽 아래 병과·체력, 오른쪽 아래 무기,
## 가운데 아래 속도, 큰 문구(banner), 조준점 아래 문구(killPop), 데미지 숫자, 사망 화면, 점수판(Tab).
## 저격총 스코프, 특수 아이템 안내 줄(저격총·말·AK), Q 안내, 피격 방향(붉은 호), 맞으면 붉은 테두리(vignette).

var player: PlayerController
var combat: Combat
var time_left := 0.0
var show_board := false

var _speed: RichTextLabel
var _cls: Label
var _hp_fill: Panel
var _hp_fill_sb: StyleBoxFlat
var _hp_num: Label
var _hp_bar: Panel
var _hp_bar_sb: StyleBoxFlat
var _vitals_regen := false
var _pop: Label
var _pop_t := 0.0
var _death: PanelContainer
var _death_by: RichTextLabel
var _death_sub: Label
var _death_text := ""   # '무기 · 헤드샷' 부분 (뒤의 'N초 뒤 부활'만 매 프레임 바뀜)
var _nums_root: Control
var _nums: Array[Dictionary] = []
var _hitmark: HitMark
var _cross: Crosshair
var _vm: ViewModel
var _ring: ChargeRing
var _w_name: Label
var _w_state: Label
var _w_hint: Label
var _info := {}        # sniper / horse / ak 안내 줄 (HTML #sniperInfo / #horseInfo / #akInfo)
var _scope: Scope
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _hurt := 0.0       # 붉은 테두리 세기 (HTML hurt)
var _dirs: DmgDir
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

const PARCH := Color("#fbf1dc")
const BLOOD := Color("#e5484d")
const GOLD := Color("#f3b33d")
const MUTE := Color("#b8b5cc")
const STEEL := Color("#9fc0ea")
const MOSS := Color("#6cc35a")
const SHADOW := Color(22 / 255.0, 26 / 255.0, 51 / 255.0, 0.9)
## 데미지 숫자 모양 (HTML .dn / .dn.head / .dn.dot / .dn.kill)
const NUM_STYLE := {
	"": {"size": 22, "color": PARCH},
	"head": {"size": 28, "color": BLOOD},
	"dot": {"size": 17, "color": Color("#bfefff")},
	"kill": {"size": 30, "color": GOLD},
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

	# 속도 (HTML #speed: 가운데 아래 20px)
	_speed = UiKit.rich(15, PARCH, root)
	_speed.modulate.a = 0.8
	_speed.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	UiKit.shadow(_speed, Color(0, 0, 0, 0.5), 1)

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
	# 특수 아이템 안내 줄 (위에서 70 / 94 / 118px)
	for kv in [["sniper", 70, GOLD], ["horse", 94, Color("#ffb37a")], ["ak", 118, Color("#ff9a6a")]]:
		var l := UiKit.label("", 15, kv[2], root)
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.offset_top = kv[1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiKit.shadow(l, Color(0, 0, 0, 0.6), 1, 2)
		_info[kv[0]] = l

	_build_topbar(root)
	_build_feed(root)
	_build_vitals(root)
	_build_weapon(root)

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
	UiKit.shadow(_banner_t, UiKit.ink(0.85), 3)
	_banner_s = UiKit.label("", 16, PARCH, _banner)
	_banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.shadow(_banner_s, Color(0, 0, 0, 0.8), 1, 2)
	_banner.modulate.a = 0.0

	# 조준점 아래 문구 (HTML #killPop: 가운데 + 48px)
	_pop = UiKit.label("", 22, GOLD, root)
	_pop.set_anchors_preset(Control.PRESET_CENTER)
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.shadow(_pop, SHADOW, 2)
	_pop.modulate.a = 0.0

	# 사망 화면 (HTML #death: 위에서 30%)
	_death = PanelContainer.new()
	_death.add_theme_stylebox_override("panel", UiKit.panel_box(Vector4(28, 16, 28, 16)))
	_death.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_death.anchor_top = 0.3
	_death.anchor_bottom = 0.3
	_death.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_death)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	_death.add_child(dv)
	_death_by = UiKit.rich(30, PARCH, dv)
	_death_sub = UiKit.label("", 14, MUTE, dv)
	_death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.visible = false

	# 점수판 (HTML #board: 가운데, Tab 누르는 동안)
	_board = PanelContainer.new()
	_board.add_theme_stylebox_override("panel", UiKit.panel_box(Vector4(20, 16, 20, 16)))
	_board.set_anchors_preset(Control.PRESET_CENTER)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board.custom_minimum_size.x = 440
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_board)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	_board.add_child(bv)
	UiKit.label("점수판", 22, GOLD, bv)
	_board_host = VBoxContainer.new()
	bv.add_child(_board_host)
	_board.visible = false


## 위쪽 가운데: 남은 시간 + 1위 (HTML #topbar)
func _build_topbar(root: Control) -> void:
	var tb := PanelContainer.new()
	tb.add_theme_stylebox_override("panel", UiKit.panel_box(Vector4(16, 4, 16, 4)))
	tb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tb.offset_top = 14
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	tb.add_child(hb)
	_timer = UiKit.label("4:00", 30, PARCH, hb)
	_leader = UiKit.rich(13, MUTE, hb)
	_leader.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## 오른쪽 위 킬피드 (HTML #feed)
func _build_feed(root: Control) -> void:
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.offset_top = 14
	_feed.offset_right = -14
	_feed.add_theme_constant_override("separation", 5)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)


## 왼쪽 아래 병과·체력 (HTML #vitals)
func _build_vitals(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(Vector4(14, 10, 14, 10)))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_bottom = -16
	panel.custom_minimum_size.x = 230
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	_cls = UiKit.label("", 15, GOLD, vb)
	_hp_bar = Panel.new()
	_hp_bar.custom_minimum_size = Vector2(0, 22)
	_hp_bar.clip_contents = true
	_hp_bar_sb = UiKit.box(Color(0, 0, 0, 0.35), MOSS, 0, 3)
	_hp_bar.add_theme_stylebox_override("panel", _hp_bar_sb)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_hp_bar)
	_hp_fill = Panel.new()
	_hp_fill_sb = UiKit.box(MOSS, Color.TRANSPARENT, 0, 0)
	_hp_fill.add_theme_stylebox_override("panel", _hp_fill_sb)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.add_child(_hp_fill)
	_hp_num = UiKit.label("100", 17, PARCH, _hp_bar)
	_hp_num.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_hp_num.offset_right = -8
	_hp_num.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hp_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.shadow(_hp_num, Color(0, 0, 0, 0.5), 1)


## 오른쪽 아래 무기 이름·상태 (HTML #weapon)
func _build_weapon(root: Control) -> void:
	var wp := PanelContainer.new()
	wp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	wp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wp.offset_right = -16
	wp.offset_bottom = -16
	wp.custom_minimum_size = Vector2(190, 0)
	wp.add_theme_stylebox_override("panel", UiKit.panel_box(Vector4(16, 10, 16, 10)))
	wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wp)
	var wvb := VBoxContainer.new()
	wvb.add_theme_constant_override("separation", 2)
	wp.add_child(wvb)
	_w_name = UiKit.label("", 28, PARCH, wvb)
	_w_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_w_state = UiKit.label("", 13, MUTE, wvb)
	_w_hint = UiKit.label("", 14, GOLD, wvb)
	_w_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_w_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


# ── 알림들 ───────────────────────────────────────────────────
## 조준점 아래 금색 문구 — HTML popMsg / killPopShow (1초 동안 커졌다 줄고, 위로 살짝 뜨며 사라짐)
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


## HTML killfeed: 'a · 무기 · 헤드샷 · v', 내가 끼면 금색 테두리. 5줄, 5.5초
func killfeed(a: PlayerController, v: PlayerController, kind: String, head: bool) -> void:
	var me := (a != null and a.is_local) or v.is_local
	var pc := PanelContainer.new()
	var sb := UiKit.panel_box(Vector4(10, 5, 10, 5))
	if me:
		sb.border_color = GOLD
		sb.bg_color = Color(80 / 255.0, 54 / 255.0, 12 / 255.0, 0.82)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_END
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 7)
	pc.add_child(hb)
	UiKit.label(a.ent_name if a else "?", 13, PARCH, hb)
	UiKit.label(GameData.WEAPONS[kind].name, 13, GOLD, hb)
	if head:
		UiKit.label("헤드샷", 12, BLOOD, hb).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.label(v.ent_name, 13, PARCH, hb)
	_feed.add_child(pc)
	_feed.move_child(pc, 0)
	_feed_items.push_front({"n": pc, "t": 0.0})
	while _feed_items.size() > GameData.FEED_MAX:
		(_feed_items.pop_back().n as Node).queue_free()


## 내가 죽었을 때 — HTML showDeath
func show_death(a: PlayerController, kind: String, head: bool) -> void:
	_death_by.text = "[center]%s에게 당했다[/center]" % UiKit.gold(UiKit.esc(a.ent_name if a else "누군가"))
	_death_text = GameData.WEAPONS[kind].name + (" · 헤드샷" if head else "")
	_death_sub.text = _death_text + " · 잠시 후 부활"
	_death.visible = true


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
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", SHADOW)
	UiKit.shadow(l, SHADOW, 2)
	l.reset_size()
	l.pivot_offset = l.size / 2
	l.visible = false
	_nums.append({"l": l, "p": pos + Vector3(randf_range(-0.2, 0.2), 0.35, randf_range(-0.2, 0.2)),
		"life": NUM_LIFE, "dx": randf_range(-28, 28)})
	if _nums.size() > NUM_MAX:
		(_nums.pop_front().l as Label).queue_free()


func hitmark(is_kill: bool) -> void:
	_hitmark.pop(is_kill)


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
	_update_nums(dt)
	var HU: Dictionary = GameData.HURT
	_hurt = maxf(0.0, _hurt - dt * float(HU.decay))
	var vig := minf(float(HU.max), _hurt + (float(HU.low_add) if e.alive and e.hp < float(HU.low_hp) else 0.0))
	_vig_mat.set_shader_parameter("alpha", vig)
	_vignette.visible = vig > 0.001
	_dirs.tick(dt)
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
			_leader.text = "%s 나 %d킬 · 목표 %d" % [UiKit.gold("1위", 15), e.kills, GameData.KILL_LIMIT]
		else:
			_leader.text = "1위 %s %s · 나 %s · %d위" % [UiKit.esc(top.ent_name), UiKit.gold(str(top.kills), 15), UiKit.gold(str(e.kills), 15), rows.find(e) + 1]
	# 병과·체력
	var t := GameData.CLASSES[e.cls].name as String
	if e.alive and not e.helmet:
		t += " · 투구 없음"
	if e.alive and e.slow_t > 0:
		t += " · 성수에 젖어 느려짐"
	if e.next_cls != "" and e.next_cls != e.cls:
		t += " → 다음 부활 %s" % GameData.CLASSES[e.next_cls].name
	_cls.text = t
	var mh := GameData.class_hp(e.cls)
	var hp := maxi(0, ceili(e.hp))
	var hpp := float(hp) / mh
	_hp_fill.size = Vector2(_hp_bar.size.x * hpp, _hp_bar.size.y)
	_hp_fill_sb.bg_color = MOSS if hpp > 0.5 else (GOLD if hpp > 0.25 else BLOOD)
	_hp_num.text = str(hp)
	var regen := e.alive and e.no_hit_t >= GameData.REGEN_DELAY and e.hp < mh
	if regen != _vitals_regen:  # 재생 중엔 체력 막대 둘레가 초록으로 빛남
		_vitals_regen = regen
		_hp_bar_sb.set_border_width_all(2 if regen else 0)
		_hp_bar_sb.shadow_color = Color(108 / 255.0, 195 / 255.0, 90 / 255.0, 0.65) if regen else Color.TRANSPARENT
		_hp_bar_sb.shadow_size = 12 if regen else 0
	# 속도·조준점
	var hs := Vector2(e.velocity.x, e.velocity.z).length()
	_speed.text = "%.1f[font_size=11][color=#fbf1dcb3] m/s[/color][/font_size]" % hs
	_speed.reset_size()
	_speed.position = Vector2((_speed.get_parent_area_size().x - _speed.size.x) / 2, _speed.get_parent_area_size().y - 20 - _speed.size.y)
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
	# 점수판
	_board.visible = show_board
	if show_board:
		_board_tick -= dt
		if _board_tick <= 0:
			_board_tick = GameData.BOARD_TICK
			for ch in _board_host.get_children():
				ch.queue_free()
			_board_host.add_child(UiKit.score_table(rows, e))
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
	var y := area.y / 2 + 48
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
	_w_name.add_theme_color_override("font_color", GOLD if e.wep == "sniper" or e.wep == "ak" else PARCH)
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
		"lance":
			st = "말 타는 중 %.1f초 · 찌르면 70 피해 + 멀리 날림" % maxf(0.0, e.mounted)
			ring = e.mounted / GameData.HORSE_TIME
			ring_col = Color("#ffb37a")
	_w_state.text = "넘어져서 공격 불가" if e.fall_t > 0 else st
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
void fragment() {
	// CSS radial-gradient(ellipse at center, transparent 45%, rgba(200,30,40,.65) 100%) — 타원은 모서리를 지남
	float d = length((UV - 0.5) * 2.0) / sqrt(2.0);
	float k = clamp((d - 0.45) / 0.55, 0.0, 1.0);
	COLOR = vec4(200.0 / 255.0, 30.0 / 255.0, 40.0 / 255.0, 0.65 * k * alpha);
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
		var blood := GameData.col(GameData.UI.blood)
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
		draw_arc(Vector2.ZERO, 24, 0, TAU, 48, Color(22 / 255.0, 26 / 255.0, 51 / 255.0, 0.35), 3.5, true)
		if _v > 0.001:
			draw_arc(Vector2.ZERO, 24, -PI / 2, -PI / 2 + TAU * minf(_v, 1.0), 48, _c, 3.5, true)


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
		var sh := Color(22 / 255.0, 26 / 255.0, 51 / 255.0, 0.7)
		for r: Rect2 in [Rect2(-1, -_gap - 9, 2, 9), Rect2(-1, _gap, 2, 9), Rect2(-_gap - 9, -1, 9, 2), Rect2(_gap, -1, 9, 2)]:
			draw_rect(r.grow(1), sh)
			draw_rect(r, c)
		draw_circle(Vector2.ZERO, 3, sh)
		draw_circle(Vector2.ZERO, 2, c)
