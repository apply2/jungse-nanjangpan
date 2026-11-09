extends SceneTree
## 이동 자동 테스트 — HTML 버전과 같은 결과가 나오는지 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_movement.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.
## (-s 스크립트에선 오토로드 이름을 바로 못 쓰므로 root.get_node("GameData")로 접근)

var main: Node
var p: CharacterBody3D
var frame := 0
var step_i := 0
var t0 := 0
var fails := 0
var peak := 0.0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}


func _initialize() -> void:
	var G0 = root.get_node("GameData")  # 저장된 설정과 상관없이 같은 조건으로
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0  # 착지 넘어짐 끔 (무작위라)
	G0.third_person = true
	G0.difficulty = "normal"
	G0.mouse_sens = 1.2
	G0.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()  # 메뉴를 건너뛰고 바로 경기 (Main이 트리에 들어간 뒤)
	root.get_node("GameData").ai_enabled = false  # 봇은 가만히 (봇 AI는 test_bot.gd)


func _physics_process(_dt: float) -> bool:
	frame += 1
	_run()
	return false


func inp(f := 0.0, sprint := false, crouch := false, jump := false) -> Dictionary:
	return {"f": f, "r": 0.0, "jump": jump, "crouch": crouch, "sprint": sprint}


func setup(pos: Vector3, yaw: float, i: Dictionary, cls := "archer") -> void:
	if p.cls != cls:
		p.set_class(cls)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.pitch = 0
	p.fall_t = 0
	p.trip_cd = 0
	p.sliding = false
	p.scripted_input = i
	t0 = frame
	step_i += 1


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func hspeed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _run() -> void:
	var el := frame - t0
	var G = root.get_node("GameData")
	match step_i:
		0:
			if frame == 3:
				p = main.get_node("Player")
				setup(Vector3(0, 0, 12), 0.0, inp(1.0))  # 남쪽 계단 아래 → 북쪽(-Z)으로 걷기
		1:
			if el == 150:
				check("계단 올라가기", p.global_position.y > 1.9, "y=%.2f (단상 높이 2.0)" % p.global_position.y)
				setup(Vector3(0, 0, -18), 0.0, inp(1.0))
		2:
			if el == 120:
				check("벽에 막힘", absf(p.global_position.z + 21.12) < 0.05, "z=%.2f (기대 -21.12)" % p.global_position.z)
				setup(Vector3(-25, 0, 18), -PI / 2, inp(1.0, true), "barbarian")
		3:
			if el == 60:
				check("야만인 달리기 속도", absf(hspeed() - 10.0) < 0.05, "%.2f m/s (기대 10.00)" % hspeed())
				setup(Vector3(-25, 0, 18), -PI / 2, inp(1.0), "crossbow")
		4:
			if el == 60:
				var want: float = G.BASE_SPEED * 0.85
				check("석궁병 걷기 속도", absf(hspeed() - want) < 0.05, "%.2f m/s (기대 %.2f)" % [hspeed(), want])
				setup(Vector3(-25, 0, 18), -PI / 2, inp(1.0, true), "archer")
		5:
			if el == 50:
				p.scripted_input = inp(-1.0)  # 달리다 반대로 → 넘어져야 함
			if el == 54:
				check("급회전 넘어짐", p.fall_t > 0, "fall_t=%.2f" % p.fall_t)
				setup(Vector3(-25, 0, 18), -PI / 2, inp(1.0, true), "archer")
		6:
			if el == 50:
				p.scripted_input = inp(1.0, false, true)
			if el == 52:
				check("슬라이드", p.sliding and hspeed() > 9.5, "sliding=%s %.2f m/s" % [p.sliding, hspeed()])
				setup(Vector3(-25, 0, 18), 0, inp(0.0, false, false, true))
				peak = 0.0
		7:
			peak = maxf(peak, p.global_position.y)
			if el == 3:
				p.scripted_input = IDLE
			if el == 60:
				check("점프 높이", absf(peak - 1.39) < 0.05, "%.2f m (HTML 1.39)" % peak)
				G.land_trip_override = 1.0  # 착지 넘어짐: 확률 1이면 무조건
				setup(Vector3(-25, 0, 18), 0, inp(0.0, false, false, true))
		8:
			if el == 3:
				p.scripted_input = IDLE
			if el > 10 and p.grounded:
				check("착지 넘어짐 (확률 1)", p.fall_t > 0, "fall_t=%.2f" % p.fall_t)
				G.land_trip_override = 0.0
				setup(Vector3(-25, 0, 18), 0, inp(0.0, false, false, true))
		9:
			if el == 3:
				p.scripted_input = IDLE
			if el > 10 and p.grounded:
				check("착지 안 넘어짐 (확률 0)", p.fall_t <= 0, "fall_t=%.2f" % p.fall_t)
				check("착지 넘어짐 확률 20%", is_equal_approx(float(G.LAND_TRIP), 0.2), "%.2f" % G.LAND_TRIP)
				print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
				quit(1 if fails > 0 else 0)
