extends SceneTree
## 결과 화면 사진 → tests/screenshots/result_<tag>_<종류>_<가로>.png (시안 Result*.jpg와 비교)
##   ffa_win (1등) · ffa_lose (6등) · ctrl_win (블루 2:1) · ctrl_lose (레드 2:1)
## 화면이 있어야 함: godot --path . --resolution 1280x720 -s tests/screenshot_result.gd -- tag=after

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
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.chosen_cls = "archer"
	G.mode = "control"
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func snap(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "res://tests/screenshots/result_%s_%s_%d.png" % [tag, name, img.get_width()]
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	await frames(40)
	var C = M.combat
	var p = M.player
	var all: Array = C.ents.duplicate()
	var cls := ["barbarian", "archer", "bard", "crossbow", "cleric"]
	for i in all.size():
		var e = all[i]
		e.kills = 20 - i * 2
		e.deaths = 3 + i
		e.cap_time = 30.0 + i * 11.0
		if e != p:
			e.set_class(cls[i % cls.size()])
	var others: Array = all.filter(func(e): return e != p)
	var menu = M.menu
	M.end_match()  # 실제 흐름처럼 경기 끝 (HUD 숨김, 창 포커스를 잃어도 일시정지 안 됨)
	await frames(5)
	# 개인전 1등
	var rows: Array = others.slice(0, 7)
	rows.insert(0, p)
	menu.open_end(rows, p)
	await frames(200)
	snap("ffa_win")
	rows = others.slice(0, 7)
	rows.insert(5, p)
	menu.open_end(rows, p)
	await frames(200)
	snap("ffa_lose")
	p.team = "blue"
	menu.open_end_control("blue", {"blue": 2, "red": 1}, all, p)
	await frames(200)
	snap("ctrl_win")
	menu.open_end_control("red", {"blue": 1, "red": 2}, all, p)
	await frames(200)
	snap("ctrl_lose")
	quit()
