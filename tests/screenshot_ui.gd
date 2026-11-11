extends SceneTree
## 마을 게시판 UI 사진 → tests/screenshots/ui_<tag>_*.png
##   settings  메인 메뉴 → 설정 (새 재질을 처음 입힌 화면)
##   main      메인 메뉴 (마을 게시판, 시안 Main.jpg와 비교) + main_hover (AI대전에 마우스 올림) + 팁 줄 수 출력
##   kit       UiKit 재료 견본: 나무(밧줄·쇠못 4)·양피지·금칠·이정표·기울기·버튼 3종(보통·마우스 올림·고름)·개구 한마디
## 화면이 있어야 함 (headless 아님): godot --path . --resolution 1280x720 -s tests/screenshot_ui.gd -- tag=after

var G: Node
var M: Node
var tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	G = root.get_node("GameData")
	G.save_enabled = false
	G.ai_enabled = false
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func snap(name: String) -> void:
	await frames(3)
	var img := root.get_texture().get_image()
	var path := "res://tests/screenshots/ui_%s_%s.png" % [tag, name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	await frames(30)
	M.menu.show_page("main")
	await snap("main")
	# 팁이 정해 둔 줄 수로만 나오는지 (개구가 넓어서 넘치면 한 글자만 다음 줄로 감)
	for tip: String in G.MAIN_MENU.tips:
		M.menu._tip_label.text = tip
		await frames(2)
		var want := tip.count("\n") + 1
		var got: int = M.menu._tip_label.get_line_count()
		print("tip lines %d/%d %s  %s" % [got, want, "OK" if got == want else "WRAP!", tip.replace("\n", " / ")])
	# AI대전 이정표에 마우스 올린 모습
	var ai = M.menu._main_signs.ai
	ai.face._hover = true
	ai.face._anim()
	await frames(12)
	await snap("main_hover")
	ai.face._hover = false
	ai.face._anim()
	M.menu.show_page("settings")
	await snap("settings")
	M.menu.open_diff_page()
	await snap("diff")
	M.menu.open_mode_page()
	await snap("mode")
	G.chosen_cls = "archer"
	M.menu.open_class_page()
	await frames(40)  # 카드 그림 찍기 기다림
	M.menu.pick_class_card("barbarian")
	await frames(30)
	await snap("class")
	M.menu.show_page("exit")
	await snap("exit")
	M.menu.show_page("friend")
	M.menu.friend_status("방을 찾는 중...")
	await snap("friend")
	M.menu.open_lobby("archer")
	M.menu.render_lobby("K7QX", [
		{"name": "허풍쟁이 기사", "cls": "archer", "host": true, "st": "lobby", "team": "blue"},
		{"name": "감자 농부", "cls": "cleric", "host": false, "st": "lobby", "team": "red"},
		{"name": "늪지 마녀", "cls": "bard", "host": false, "st": "play", "team": "blue"}],
		"친구에게 코드를 알려주세요 · 빈자리 봇: 블루 3 · 레드 4", "게임 시작", "control", true)
	await snap("lobby")
	M.menu.show_page("main")
	M.menu.toast("추후 업데이트 될 내용입니다.")
	await frames(30)
	await snap("toast")
	M.menu.open_pause("archer")
	await snap("pause")
	M.menu._pause_page(true)
	await snap("pause_settings")
	M.menu.show_screen("menu")
	M.menu.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	_kit(layer)
	await snap("kit")
	quit()


## 재료 견본 한 장
func _kit(layer: CanvasLayer) -> void:
	var U = load("res://scripts/ui_kit.gd")
	var bg := ColorRect.new()
	bg.color = G.col(0x6b3f1f)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 40)
	m.add_theme_constant_override("margin_top", 70)
	layer.add_child(m)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	m.add_child(cols)
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", 26)
	cols.add_child(a)
	# 매달린 간판 (밧줄 2 + 쇠못 4) — 글자는 흰색 + 잉크 외곽선
	var sign = U.Board.new("wood", Vector4(26, 10, 26, 14))
	sign.ropes = true
	sign.nails = 4
	U.wood_text(U.label("중세난장판", 52, Color.WHITE, sign), 52)
	a.add_child(sign)
	var p = U.Board.new("parch", Vector4(18, 14, 18, 12))
	p.nails = 1
	var pv := VBoxContainer.new()
	p.add_child(pv)
	U.label("오늘의 팁", 18, U.c("ink"), pv)
	U.scribble("달리다가 급하게 돌면\n넘어집니다. 진짜로.", 22, U.c("ink"), pv)
	a.add_child(U.tilted(p, 2.0))
	var gl = U.Board.new("gilt", Vector4(20, 8, 20, 8))
	gl.nails = 2
	U.label("금칠 판 (주요 1개)", 26, U.c("ink"), gl)
	a.add_child(gl)
	var tl = U.Board.new("wood", Vector4(16, 6, 16, 6))
	tl.tilt = -2.0
	U.wood_text(U.label("판만 -2° (tilt)", 20, Color.WHITE, tl), 20)
	a.add_child(tl)
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 18)
	b.custom_minimum_size.x = 420
	cols.add_child(b)
	b.add_child(U.navbtn("일반대전", "준비 중", "soon"))
	b.add_child(U.navbtn("AI대전", "봇 7명과 개인전", "hero"))
	var hv = U.navbtn("친구대전", "방 코드로 같이")
	b.add_child(hv)
	b.add_child(U.navbtn("설정", "", "sub"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	b.add_child(row)
	row.add_child(U.primary("이놈으로 출전"))
	row.add_child(U.ghost("도망가기"))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	b.add_child(row2)
	var g1 = U.ghost("보통", 16, Vector4(16, 6, 16, 6))
	g1.selected = true
	row2.add_child(g1)
	var g2 = U.ghost("마우스 올림", 16, Vector4(16, 6, 16, 6))
	row2.add_child(g2)
	var g3 = U.ghost("못 누름", 16, Vector4(16, 6, 16, 6))
	g3.disabled = true
	row2.add_child(g3)
	row2.add_child(U.back())
	await frames(2)
	hv.face._hover = true  # 마우스 올린 모습 (오른쪽으로 밀리고 -1°)
	hv.face._anim()
	g2.face._hover = true
	g2.face._anim()
