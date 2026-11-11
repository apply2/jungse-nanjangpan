extends SceneTree
## 경기 화면 HUD 사진 → tests/screenshots/hud_<tag>_<모드>_<가로>.png (시안 Hud.jpg와 비교)
##   control  쟁탈전: 점수판(방패·메달·막대·쪽지), 거점 표지판, 아군 ▼, 킬피드 3줄(헤드샷·나), 활 당김 호, 무기 칸
##   ffa      개인전: 나무 꼬리표 시간 + 1위 양피지, 체력 낮음(빨간 깜빡) + 상태 쪽지, 조준점 아래 쪽지
##   death    사망 화면 "넘어졌다... 다시?"
## 가운데 40% 안에 들어간 HUD 판이 있으면 CENTER! 줄을 출력한다.
## 화면이 있어야 함: godot --path . --resolution 1280x720 -s tests/screenshot_hud.gd -- mode=control tag=after
##                  (1920x1080도 같은 식으로. 모드: control / ffa — ffa는 death도 찍음)

var G: Node
var M: Node
var tag := "after"
var mode := "control"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("mode="):
			mode = a.substr(5)
	G = root.get_node("GameData")
	G.save_enabled = false
	G.ai_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.third_person = true
	G.chosen_cls = "archer"
	G.mode = mode if mode == "control" else "ffa"
	M = load("res://scenes/main.tscn").instantiate()
	root.add_child(M)
	M.start_match.call_deferred()
	_run()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func snap(name: String) -> void:
	await frames(3)
	var img := root.get_texture().get_image()
	var path := "res://tests/screenshots/hud_%s_%s_%d.png" % [tag, name, img.get_width()]
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


## 가운데 40% 상자와 겹치는 모서리 판 찾기 (조준점·쪽지·배너·사망 화면은 허용)
func center_check() -> void:
	var H = M.hud
	var vp: Vector2 = H._topbar.get_viewport_rect().size
	var k: float = G.HUD_UI.center_free
	var free := Rect2(vp * (0.5 - k / 2), vp * k)
	var panels := {"topbar": H._topbar, "ctrl_top": H._ctrl._top, "feed": H._feed, "vitals": H._medal.get_parent(),
		"weapon": H._w_name.get_parent().get_parent().get_parent().get_parent(), "notes": H._notes}
	for n: String in panels:
		var c: Control = panels[n]
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		print("%-9s %s h=%d %s" % [n, r, int(r.size.y), "CENTER!" if r.intersects(free) else "ok"])


func _run() -> void:
	await frames(40)
	var C = M.combat
	var p = M.player
	var bots: Array = C.ents.filter(func(e): return e != p)
	if mode == "control":
		var cm = M.combat.mode
		var cap: Vector3 = cm.world.cap_pos
		p.global_position = cap + Vector3(-1.5, 0.3, 17)
		p.yaw = 0.05
		p.pitch = -0.05
		var mates: Array = bots.filter(func(e): return e.team == p.team)
		var foes: Array = bots.filter(func(e): return e.team != p.team)
		mates[0].global_position = cap + Vector3(-9, 0.3, 12)
		for i in 3:
			foes[i].global_position = cap + Vector3(-3 + i * 3, 0.3, -2 - i)
		cm.phase = "open"
		cm.round_no = 2
		cm.wins = {"blue": 1, "red": 0}
		cm.holder = "blue"
		cm.cap_team = "red"
		cm.cap_prog = 0.38
		cm.pct = {"blue": 37, "red": 12}
	else:
		p.global_position = Vector3(0, 0.3, 14)
		p.yaw = 0.0
		bots[2].kills = 6
		p.kills = 3
		p.hp = 20
		p.helmet = false
		p.next_cls = "cleric"
	await frames(5)
	C.kill(bots[1], bots[0], "stone", false, Vector3.FORWARD)
	C.kill(bots[3], bots[2], "trumpet", false, Vector3.FORWARD)
	C.kill(bots[4], p, "bow", true, Vector3.FORWARD)
	p.scripted_input = {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}  # 활 당기는 중
	await frames(58)
	if mode != "control":
		M.hud.pop_msg("처치! " + bots[4].ent_name)
		await frames(14)
	await snap(mode)
	center_check()
	if mode != "control":
		p.scripted_input = {}
		C.kill(p, bots[2], "crossbow", true, Vector3.FORWARD)
		await frames(50)
		await snap("death")
	quit()
