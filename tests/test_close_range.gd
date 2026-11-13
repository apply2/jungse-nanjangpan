extends SceneTree
## 근거리 명중 자동 테스트 (사용자 피드백 "초근접에서 화살·볼트가 잘 안 맞음")
## 거리 1·3·10m × 활(최소/풀차지)·석궁 × 1·3인칭 × 조준점(몸 가운데·머리·몸 양끝·머리 끝)을 정확히 겨누고 쏴서
## 맞았는지(H 머리 / B 몸 / - 빗나감) 표로 찍고 확인한다. + 0.6m(1인칭), 첫 프레임 눈→손 구간 판정, 디버그 표시 켜고 끄기.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_close_range.gd

var main: Node
var G: Node
var C
var p
var dm
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const SHOOTER := Vector3(-25, 0, 18)
const AIMS := ["몸가운데", "머리", "몸왼끝", "몸오른끝", "머리끝"]


func _initialize() -> void:
	var G0 = root.get_node("GameData")
	G0.save_enabled = false
	G0.hitstop_enabled = false
	G0.land_trip_override = 0.0
	G0.third_person = true
	G0.chosen_cls = "archer"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.start_match.call_deferred()
	G0.ai_enabled = false
	_run()


func wait(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


## "HB-" → "H        B        -" (표 칸 맞춤)
func spaced(row: String) -> String:
	var out := ""
	for ch in row:
		out += ch + "        "
	return out


func put(e, pos: Vector3, cls: String, yaw: float) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0
	e.velocity = Vector3.ZERO


## 화면 가운데(카메라 조준선)가 pt를 가리키게 돌린다. 3인칭 카메라는 yaw·pitch에 따라 움직이니 천천히 맞춤.
## 돌려주는 값: 조준선이 pt를 비껴가는 거리(m)
func aim_at(pt: Vector3) -> float:
	for k in 30:
		var d: Vector3 = (pt - p.cam.global_position).normalized()
		p.yaw = lerp_angle(p.yaw, atan2(-d.x, -d.z), 0.5)
		p.pitch = lerpf(p.pitch, asin(d.y), 0.5)
		await wait(1)
	var o: Vector3 = p.cam.global_position
	var f: Vector3 = p.aim_dir()
	return (o + f * (pt - o).dot(f)).distance_to(pt)


## 과녁을 dist m 앞에 세우고 k번 조준점을 겨눠 한 발: "H" "B" "-" (조준이 안 맞춰지면 "?")
func shot(dist: float, k: int, kind: String, t: float) -> String:
	put(dm, SHOOTER + Vector3(dist, 0, 0), "archer", PI / 2)  # 맞으면 밀려나니 쏠 때마다 제자리로
	await wait(2)
	var hc: Vector3 = dm.head_c()
	var bc: Vector3 = (dm.body_a() + dm.body_b()) * 0.5
	var pts := [bc, hc, bc + Vector3(0, 0, -0.4), bc + Vector3(0, 0, 0.4), hc + Vector3(0, 0, -0.25)]
	if await aim_at(pts[k]) > 0.05:
		return "?"
	dm.hp = 9999.0
	dm.invuln = 0.0
	dm.helmet = false  # 맨머리 ×2 → 머리/몸 구분
	var n0: int = C.projectiles.size()
	p.cd = 0.0
	C.fire(p, kind, t)
	var pr = C.projectiles[n0] if C.projectiles.size() > n0 else null
	var dmg: float = pr.dmg if pr else 0.0
	for i in 40:
		await physics_frame
		if pr == null or not C.projectiles.has(pr):
			break
	var lost: float = 9999.0 - dm.hp
	if lost <= 0.01:
		return "-"
	return "H" if lost > dmg * 1.2 else "B"


func _run() -> void:
	await wait(3)
	G = root.get_node("GameData")
	C = main.get_node("Combat")
	p = main.get_node("Player")
	var bots: Array = C.ents.filter(func(e): return e.is_bot)
	dm = bots[0]
	for i in range(1, bots.size()):
		put(bots[i], Vector3(60 + i * 3, 0, -60), "archer", 0.0)
	put(p, SHOOTER, "archer", -PI / 2)
	var shots := [["활 최소", "bow", 0.0], ["활 풀  ", "bow", 1.0], ["석궁   ", "crossbow", 0.0]]
	print("거리  시점   무기    | " + "  ".join(AIMS))
	var res := {}  # "1.0/3/석궁" → 결과 줄
	for tp in [false, true]:
		G.third_person = tp
		for dist in [1.0, 3.0, 10.0]:
			for s in shots:
				put(p, SHOOTER, "archer", -PI / 2)
				var row := ""
				for k in AIMS.size():
					row += await shot(dist, k, s[1], s[2])
				res["%.0f/%s/%s" % [dist, "3" if tp else "1", s[1] + str(s[2])]] = row
				print("%4.0fm  %s  %s | %s" % [dist, "3인칭" if tp else "1인칭", s[0], spaced(row)])
	# ── 확인 ──
	for key: String in res:
		var row: String = res[key]
		var parts := key.split("/")
		var weak10 := parts[0] == "10" and parts[2] == "bow0.0"  # 10m 가장 약한 화살: 중력으로 0.9m 떨어짐 (의도한 포물선)
		if weak10:
			check("%s: 몸 가운데는 맞음 (가장자리는 포물선으로 아래로 지나감 — 정상)" % key, row[0] != "-", row)
		elif parts[0] == "1" and parts[1] == "3":
			# 3인칭 1m: 카메라가 위에서 내려다봐서 몸 가운데·머리 끝엔 조준선을 정확히 못 댐("?") → 댈 수 있는 곳은 다 맞아야 함
			check("%s: 조준선을 댈 수 있는 곳은 다 맞음" % key, not row.contains("-") and row.count("?") <= 2, row)
		else:
			check("%s: 조준점 5곳 다 맞음" % key, not row.contains("-") and not row.contains("?"), row)
		if not weak10 and (parts[0] != "1" or parts[1] == "1"):  # 3인칭 1m는 카메라가 위에서 내려다봐서 몸을 겨눠도 머리가 먼저 가림 (조준선대로 머리)
			check("%s: 머리를 겨누면 머리" % key, row[1] == "H", row)
	# 1인칭 0.6m (서로 겹칠 만큼 가까움 — 캐릭터끼리는 안 부딪힘)
	G.third_person = false
	put(p, SHOOTER, "archer", -PI / 2)
	var r06 := ""
	for s in shots:
		for k in [0, 1, 4]:
			r06 += await shot(0.6, k, s[1], s[2])
	check("1인칭 0.6m: 몸·머리·머리끝 다 맞음 (활 최소/풀·석궁)", not r06.contains("-") and not r06.contains("?"), r06)

	# 첫 프레임은 눈(from) → 나가는 자리를 같이 잼: 나가는 자리 바로 뒤(눈과 손 사이)에 있는 적도 맞음
	put(dm, SHOOTER + Vector3(3, 0, 0), "archer", PI / 2)
	await wait(2)
	await aim_at((dm.body_a() + dm.body_b()) * 0.5)
	var L: Dictionary = C.local_launch(p, "crossbow")
	check("1인칭: 판정 시작점 = 눈, 나가는 자리 = 손 (오른쪽·아래)", L.from == p.eye_pos() and L.pos != L.from, "from=%s pos=%s" % [L.from, L.pos])
	var near: Dictionary = C.hit_test(L.from, L.pos - L.from, dm, 0.05)
	var n0: int = C.projectiles.size()
	C.fire(p, "crossbow", 0.0)
	var pr: Dictionary = C.projectiles[n0]
	check("쏜 투사체는 첫 프레임 판정 시작점(from)을 가짐", pr.has("from") and near.is_empty(), str(pr.get("from")))
	await wait(2)
	check("한 프레임 뒤엔 from이 지워짐 (이후엔 이전 위치 → 다음 위치)", not pr.has("from"), "")

	# 터널링: 석궁 100m/s(프레임당 1.67m)가 몸 두께(0.92m)보다 길어도, 선분 판정이라 프레임 경계와 상관없이 맞음
	var tun := ""
	for off in [0.0, 0.4, 0.8, 1.2]:
		G.third_person = false
		put(p, SHOOTER, "archer", -PI / 2)
		tun += await shot(5.0 + off, 0, "crossbow", 0.0)
	check("석궁이 프레임 사이 어디에 걸려도 맞음 (5~6.2m)", tun == "BBBB", tun)

	# 디버그 표시 (F9): 기본 꺼짐, 켜면 그림, 끄면 지움
	var hd = C.hit_debug
	check("디버그 표시 기본 꺼짐", not G.debug_hits and InputMap.has_action("debug_hits"), "")
	var ev := InputEventKey.new()
	ev.physical_keycode = G.HIT_DEBUG.key
	ev.pressed = true
	hd._unhandled_input(ev)
	await shot(3.0, 0, "crossbow", 0.0)
	await wait(1)
	check("F9로 켜면 생성 지점·비행 경로·히트박스를 그림", G.debug_hits and hd._segs.size() >= 2 and hd._marks.size() >= 3 and hd.mesh.get_surface_count() == 1,
		"선 %d 표시 %d" % [hd._segs.size(), hd._marks.size()])
	hd._unhandled_input(ev)
	await wait(1)
	check("다시 누르면 끄고 지움", not G.debug_hits and hd._segs.is_empty() and hd.mesh.get_surface_count() == 0, "")

	print("ALL PASS" if fails == 0 else "%d FAIL" % fails)
	quit(1 if fails else 0)
