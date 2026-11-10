extends SceneTree
## 친구대전 쟁탈전 자동 테스트 — 한 프로세스에 Main 둘(방장 A, 친구 B)을 띄워 잇는다 (test_net.gd와 같은 방식).
## 대기실 모드·팀 나누기·팀 바꾸기, 빈자리 봇(방장 컴퓨터)·봇 명단·봇 위치 따라가기,
## 친구 → 방장 봇 피해(방장 쪽 판정)·방장 봇 → 친구 피해(친구 쪽 판정)·서로 처치 수,
## 거점 열림·점령·라운드 끝·다음 라운드·경기 끝(친구는 방장 상태를 따라감), 대기실 복귀·개인전으로 다시 시작을 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_net_control.gd   (포트 24680·24681을 씀)
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var G: Node
var A: Node   # 방장 Main
var B: Node   # 친구 Main
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.land_trip_override = 0.0
	G.third_person = false
	G.difficulty = "normal"
	G.chosen_cls = "barbarian"
	A = _make("A")
	B = _make("B")
	G.ai_enabled = false  # 봇은 세워 두고 직접 움직임
	_run()


func _make(n: String) -> Node:
	var holder := Node.new()
	holder.name = n
	root.add_child(holder)
	set_multiplayer(SceneMultiplayer.new(), NodePath("/root/" + n))
	var m: Node = load("res://scenes/main.tscn").instantiate()
	holder.add_child(m)
	return m


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func wait_until(f: Callable, max_frames := 300) -> bool:
	for i in max_frames:
		if f.call():
			return true
		await physics_frame
	return f.call()


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + detail)
	if not ok:
		fails += 1


func put(e, pos: Vector3, yaw := 0.0) -> void:
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0


## 쟁탈전 맵에서 동서로 6m 떨어져 서로 보이는 빈 자리 (스폰룸·거점 밖)
func open_spot(c) -> Vector3:
	for z in range(14, 46, 4):
		for x in range(-20, 16, 4):
			var p := Vector3(x, 1.0, z)
			var gy: float = c.ground_below(p)
			if gy < -0.5 or gy > 0.6:
				continue
			var eye := Vector3(x, gy + 1.5, z)
			if c.world_ray(eye, Vector3(6, 0, 0)) >= 1.0 and c.world_ray(eye + Vector3(0, -1.2, 0), Vector3(6, 0, 0)) >= 1.0 \
					and c.world_ray(eye, Vector3(0, 3, 0)) >= 1.0 and c.world_ray(eye + Vector3(6, 0, 0), Vector3(0, 3, 0)) >= 1.0:
				return Vector3(x, gy, z)
	return Vector3(0, 0, 30)


func _run() -> void:
	await wait(3)
	var na = A.net
	var nb = B.net
	var pa = A.player
	var pb = B.player
	var TS: int = G.MODES.control.team_size

	# ── 방 만들기·들어가기 (IP로) ──
	na.host_room("방장", "barbarian")
	await wait(2)
	nb.join_room("친구", "barbarian", "127.0.0.1")
	await wait_until(func(): return nb.on and na.remotes.size() == 1 and nb.remotes.size() == 1, 300)
	check("친구가 들어옴", nb.on and na.remotes.size() == 1)
	await wait_until(func(): return nb.team != "", 60)
	check("방장은 블루, 친구는 사람이 적은 레드로", na.team == "blue" and nb.team == "red", "%s/%s" % [na.team, nb.team])
	await wait_until(func(): return na.team_of(na.remotes.keys()[0]) == "red", 60)
	check("방장 대기실에도 친구 팀이 보임", na.lobby_list()[1].team == "red", str(na.lobby_list()))

	# ── 모드: 방장이 쟁탈전으로 ──
	check("처음엔 개인전", na.mode_now() == "ffa" and nb.mode_now() == "ffa")
	na.set_room_mode("control")
	await wait_until(func(): return nb.mode_now() == "control", 60)
	check("방장이 쟁탈전을 고르면 친구도 쟁탈전", nb.mode_now() == "control")
	nb.switch_team()
	await wait_until(func(): return na.team_of(na.remotes.keys()[0]) == "blue", 60)
	check("팀 바꾸기 → 블루 (방장 목록에도)", nb.team == "blue" and na.team_counts().blue == 2, str(na.team_counts()))
	nb.switch_team()
	await wait_until(func(): return na.team_of(na.remotes.keys()[0]) == "red", 60)
	check("다시 레드", nb.team == "red" and na.team_counts().red == 1)
	var B_ID: int = nb.me_id()

	# ── 시작: 빈자리 봇 ──
	A.menu.lobby_start.emit()
	await wait_until(func(): return A.state == "playing" and B.state == "playing", 90)
	check("방장이 시작하면 둘 다 경기", A.state == "playing" and B.state == "playing", "%s/%s" % [A.state, B.state])
	check("방장은 규칙을 돌리고 친구는 따라감", A.mode != null and not A.mode.follower and B.mode != null and B.mode.follower)
	check("쟁탈전 맵", A.world == A.world_ctrl and B.world == B.world_ctrl)
	var a_bots: Array = A.combat.ents.filter(func(e): return e.is_bot)
	var nblue: int = a_bots.filter(func(e): return e.team == "blue").size()
	var nred: int = a_bots.filter(func(e): return e.team == "red").size()
	check("빈자리 봇: 블루 %d · 레드 %d" % [TS - 1, TS - 1], nblue == TS - 1 and nred == TS - 1, "blue=%d red=%d" % [nblue, nred])
	check("방장 쪽 10명", A.combat.ents.size() == TS * 2, "n=%d" % A.combat.ents.size())
	await wait_until(func(): return B.combat.ents.size() == TS * 2, 60)
	check("친구 쪽도 10명 (봇은 친구 캐릭터처럼)", B.combat.ents.size() == TS * 2 and nb.remotes.keys().filter(func(id): return id < 0).size() == (TS - 1) * 2,
		"n=%d" % B.combat.ents.size())
	check("팀: 친구 레드, 방장 블루 (서로 화면에서도)", pb.team == "red" and pa.team == "blue" and na.remotes[B_ID].team == "red" and nb.remotes[1].team == "blue")
	var bot = a_bots.filter(func(e): return e.team == "blue")[0]
	var rbot = nb.remotes.get(bot.peer)
	check("친구 화면의 봇: 이름·팀이 같음", rbot != null and rbot.ent_name == bot.ent_name and rbot.team == "blue")
	await wait_until(func(): return B.mode.round_no == 1, 60)
	await wait(5)
	check("둘 다 자기 팀 스폰룸에서 시작", A.world_ctrl.spawn_room("blue").has_point(pa.global_position + Vector3(0, 0.5, 0))
		and A.world_ctrl.spawn_room("red").has_point(pb.global_position + Vector3(0, 0.5, 0)), "%s / %s" % [pa.global_position, pb.global_position])
	check("라운드 1, 거점 잠김 (친구도)", A.mode.round_no == 1 and B.mode.round_no == 1 and B.mode.phase == "locked", "%d/%d %s" % [A.mode.round_no, B.mode.round_no, B.mode.phase])

	# ── 봇 위치 따라가기 ──
	var spot := open_spot(A.combat)
	bot.next_cls = "barbarian"            # 둘 다 돌멩이 (한 번 클릭으로 바로 던짐)
	pb.next_cls = "barbarian"
	put(bot, spot, -PI / 2)               # 봇: 동쪽(+X)을 봄
	put(pb, spot + Vector3(6, 0, 0), PI / 2)  # 친구: 서쪽을 봄
	await wait(40)
	check("친구 화면에 봇이 제자리에 보임", rbot.alive and rbot.global_position.distance_to(bot.global_position) < 0.3, "d=%.2f" % rbot.global_position.distance_to(bot.global_position))

	# ── 친구 → 방장 봇: 방장 쪽이 판정 ──
	var hp0: float = bot.hp
	pb.scripted_input = FIRE
	await wait(2)
	pb.scripted_input = IDLE
	await wait_until(func(): return bot.hp < hp0, 60)
	check("친구 돌멩이에 방장 봇 체력이 줄어듦 (방장 쪽 판정)", bot.hp < hp0 and bot.hp >= hp0 - 15, "hp=%.0f→%.0f" % [hp0, bot.hp])
	await wait(10)
	check("친구 화면의 봇 체력도 따라감", absf(rbot.hp - bot.hp) < 1.0, "remote=%.0f" % rbot.hp)

	# ── 방장 봇 → 친구: 친구 쪽이 판정, 봇이 처치 ──
	await wait(30)
	pb.hp = 5.0
	bot.scripted_input = FIRE
	await wait(2)
	bot.scripted_input = IDLE
	await wait(3)
	check("친구 화면에도 봇 돌멩이가 생김", B.combat.projectiles.any(func(p): return p.owner == rbot), "n=%d" % B.combat.projectiles.size())
	var died: bool = await wait_until(func(): return not pb.alive, 60)
	check("봇 돌멩이에 친구가 죽음 (친구 쪽 판정)", died, "hp=%.0f" % pb.hp)
	await wait_until(func(): return bot.kills == 1, 60)
	check("방장 쪽에서 봇 처치 +1", bot.kills == 1 and pb.deaths == 1, "k=%d d=%d" % [bot.kills, pb.deaths])
	await wait(10)
	check("친구 화면의 봇 처치 수도 1", rbot.kills == 1, "k=%d" % rbot.kills)
	check("방장 화면에서 친구가 래그돌", not na.remotes[B_ID].alive)
	var back: bool = await wait_until(func(): return pb.alive, 400)
	check("친구는 5초 뒤 레드 스폰룸에서 부활", back and A.world_ctrl.spawn_room("red").has_point(pb.global_position + Vector3(0, 0.5, 0)))

	# ── 친구가 방장 봇을 처치 ──
	bot.next_cls = "barbarian"
	pb.next_cls = "barbarian"
	put(bot, spot, -PI / 2)
	put(pb, spot + Vector3(6, 0, 0), PI / 2)
	await wait(40)
	bot.hp = 5.0
	pb.scripted_input = FIRE
	await wait(2)
	pb.scripted_input = IDLE
	var bdead: bool = await wait_until(func(): return not bot.alive, 60)
	check("친구가 방장 봇을 처치", bdead)
	await wait_until(func(): return pb.kills == 1, 60)
	check("친구 처치 +1 (방장이 알려줌), 봇 죽음 +1", pb.kills == 1 and bot.deaths == 1, "k=%d d=%d" % [pb.kills, bot.deaths])
	await wait(20)
	check("친구 화면에서 봇이 래그돌", not rbot.alive and rbot.ragdoll != null)

	# ── 거점: 방장이 열고, 친구가 점령 ──
	for e in A.combat.ents:  # 방장 쪽 사람·봇은 거점 밖 (스폰룸)
		if not e.is_remote and e.alive:
			put(e, A.world_ctrl.spawn_spots(e.team)[0])
	A.mode.unlock_left = 0.05
	await wait_until(func(): return B.mode.phase == "open", 60)
	check("거점이 열리면 친구도 열림", A.mode.phase == "open" and B.mode.phase == "open", B.mode.phase)
	put(pb, A.world.cap_pos + Vector3(3, 0.5, 3))
	await wait_until(func(): return A.mode.cap_team == "red" and B.mode.cap_prog > 0.05, 120)
	check("친구가 거점에 들어가면 방장 규칙이 레드 점령을 셈 (친구 화면에도)", A.mode.cap_team == "red" and B.mode.cap_team == "red" and B.mode.cap_prog > 0.05,
		"A=%s B=%s %.2f" % [A.mode.cap_team, B.mode.cap_team, B.mode.cap_prog])
	A.mode.cap_prog = 0.99
	await wait_until(func(): return B.mode.holder == "red", 60)
	check("점령 → 친구 화면에도 레드 거점", A.mode.holder == "red" and B.mode.holder == "red")
	check("친구는 거점 시간을 직접 셈", pb.cap_time > 0.3, "%.2f" % pb.cap_time)

	# ── 라운드 끝 → 다음 라운드 ──
	A.mode.pct = {"blue": 0, "red": 99}
	await wait_until(func(): return B.mode.phase == "gap", 120)
	check("레드 100% → 라운드 끝 (친구도)", A.mode.phase == "gap" and B.mode.phase == "gap" and B.mode.wins.red == 1, "%s %s" % [B.mode.phase, B.mode.wins])
	A.mode.gap_left = 0.05
	await wait_until(func(): return B.mode.round_no == 2, 90)
	await wait(5)
	check("라운드 2: 친구도 스폰룸으로 돌아감", B.mode.round_no == 2 and B.mode.phase == "locked"
		and A.world_ctrl.spawn_room("red").has_point(pb.global_position + Vector3(0, 0.5, 0)), str(pb.global_position))

	# ── 경기 끝 ──
	A.mode._end_round("red")   # 레드 2승
	A.mode.gap_left = 0.05
	var ended: bool = await wait_until(func(): return A.state == "ended" and B.state == "ended", 120)
	check("2선승 → 둘 다 결과 화면", ended and B.mode.match_winner == "red", "%s/%s" % [A.state, B.state])

	# ── 대기실로 → 봇이 빠짐 ──
	A.go_menu("class")
	B.go_menu("class")
	await wait_until(func(): return nb.remotes.size() == 1, 60)
	check("대기실: 방장 봇이 쉬고 친구 쪽 봇도 사라짐", A.combat.ents.size() == 2 and B.combat.ents.size() == 2 and nb.remotes.size() == 1,
		"A=%d B=%d" % [A.combat.ents.size(), B.combat.ents.size()])
	check("개인전 맵으로 돌아옴", A.world == A.world_ffa and B.world == B.world_ffa)

	# ── 개인전으로 다시 ──
	na.set_room_mode("ffa")
	await wait_until(func(): return nb.mode_now() == "ffa", 60)
	A.menu.lobby_start.emit()
	await wait_until(func(): return A.state == "playing" and B.state == "playing", 90)
	check("개인전으로 다시 시작: 봇 없음·팀 없음", A.mode == null and B.mode == null and A.combat.ents.size() == 2 and B.combat.ents.size() == 2
		and pa.team == "" and pb.team == "" and na.remotes[B_ID].team == "", "A=%d" % A.combat.ents.size())

	na.leave()
	await wait_until(func(): return not nb.on, 300)
	check("방장이 나가면 둘 다 메뉴, 봇 7명", not na.on and not nb.on and A.combat.ents.size() == 8 and B.combat.ents.size() == 8,
		"A=%d B=%d" % [A.combat.ents.size(), B.combat.ents.size()])

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
