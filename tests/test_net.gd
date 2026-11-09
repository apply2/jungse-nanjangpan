extends SceneTree
## 친구대전(LAN) 자동 테스트 — 한 프로세스에 Main을 둘 띄우고(방장 A, 친구 B) 서로 다른 SceneMultiplayer로 잇는다.
## 방 코드로 찾기, 대기실, 경기 시작, 위치 따라가기, 투사체(맞은 쪽 판정)·저격총(쏜 쪽 판정)·처치 수,
## 아이템 줍기 허락, 시간 끝나면 경기 끝, 나가기·방 닫힘을 확인한다.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_net.gd
## 통과하면 "ALL PASS"와 종료 코드 0, 실패하면 FAIL 줄과 종료 코드 1.

var G: Node
var A: Node   # 방장 Main
var B: Node   # 친구 Main
var fails := 0

const IDLE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
const FIRE := {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false, "fire": true}
const HERE := Vector3(-25, 0, 18)


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.third_person = false
	G.difficulty = "normal"
	G.chosen_cls = "archer"
	A = _make("A")
	B = _make("B")
	G.ai_enabled = false
	_run()


## /root/A/Main, /root/B/Main — 각자 자기 multiplayer를 써서 RPC 경로("Main/Net")가 같아진다
func _make(n: String) -> Node:
	var holder := Node.new()
	holder.name = n
	root.add_child(holder)
	set_multiplayer(SceneMultiplayer.new(), NodePath("/root/" + n))  # _initialize 때는 아직 get_path()를 못 씀
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


func put(e, pos: Vector3, cls := "archer", yaw := 0.0) -> void:
	e.next_cls = cls
	e.spawn_at(pos)
	e.invuln = 0.0
	e.scripted_input = IDLE
	e.yaw = yaw
	e.pitch = 0.0


func _run() -> void:
	await wait(3)
	var na = A.net
	var nb = B.net
	var pa = A.player
	var pb = B.player

	# ── 방 만들기 ──
	na.host_room("방장", "archer")
	await wait(2)
	check("방장: 방이 열림", na.on and na.is_host and na.code.length() == 4, "code=%s" % na.code)
	check("방장: 대기실 화면, 봇 빠짐", A.state == "menu" and A.menu.cur_page == "lobby" and A.combat.ents.size() == 1, "ents=%d" % A.combat.ents.size())

	# ── 코드로 찾아 들어가기 ──
	nb.join_room("  친구  ", "barbarian", na.code.to_lower())
	var found: bool = await wait_until(func(): return nb.on, 300)
	if not found:  # 방송이 막힌 환경이면 IP로라도 들어가서 나머지를 시험
		print("NOTE 방송으로 못 찾음 → 127.0.0.1로 접속")
		nb.join_room("친구", "barbarian", "127.0.0.1")
		found = await wait_until(func(): return nb.on, 300)
	check("친구: 방 코드로 찾아 들어감", found and not nb.is_host and nb.code == na.code, "code=%s" % nb.code)
	await wait_until(func(): return na.remotes.size() == 1 and nb.remotes.size() == 1 and na.info.size() == 1 and nb.info.size() == 1, 120)
	var la: Array = na.lobby_list()
	var lb: Array = nb.lobby_list()
	check("대기실 목록 2명", la.size() == 2 and lb.size() == 2, "%s / %s" % [la, lb])
	check("이름·병과·방장 표시", la[1].name == "친구" and la[1].cls == "barbarian" and lb[1].host and not lb[0].host and lb[0].name == "친구 (나)", str(lb))
	check("친구 쪽도 봇 빠짐", B.combat.ents.size() == 2 and A.combat.ents.size() == 2, "A=%d B=%d" % [A.combat.ents.size(), B.combat.ents.size()])
	nb.set_cls("crossbow")
	await wait_until(func(): return na.lobby_list()[1].cls == "crossbow", 60)
	check("병과 바꾸면 방장 목록도 바뀜", na.lobby_list()[1].cls == "crossbow")

	# ── 경기 시작 ──
	A.menu.lobby_start.emit()
	await wait_until(func(): return A.state == "playing" and B.state == "playing", 60)
	check("방장이 시작하면 둘 다 경기", A.state == "playing" and B.state == "playing", "%s/%s" % [A.state, B.state])
	check("시간 4분", absf(B.time_left - G.MATCH_TIME) < 2 and absf(A.time_left - G.MATCH_TIME) < 2, "A=%.1f B=%.1f" % [A.time_left, B.time_left])
	check("친구는 고른 병과로 나옴", pb.cls == "crossbow" and pa.cls == "archer", pb.cls)
	for it in [A.combat.items, B.combat.items]:
		it.sniper_timer = 9999.0
		it.ak_timer = 9999.0
		it.horse_timer = 9999.0
	check("친구대전엔 닭이 없음", A.combat.items.chickens.is_empty() and B.combat.items.chickens.is_empty(), "")

	# ── 위치 따라가기 ──
	put(pa, HERE, "barbarian", -PI / 2)        # 동쪽(+X)을 봄
	put(pb, HERE + Vector3(6, 0, 0), "archer", PI / 2)
	await wait(40)
	var rb = na.remotes.values()[0]   # 방장 화면의 친구
	var ra = nb.remotes.values()[0]   # 친구 화면의 방장
	check("방장 화면에 친구가 제자리에 보임", rb.alive and rb.global_position.distance_to(pb.global_position) < 0.3 and rb.model and rb.model.visible,
		"d=%.2f" % rb.global_position.distance_to(pb.global_position))
	check("친구 화면에 방장이 보임", ra.alive and ra.global_position.distance_to(pa.global_position) < 0.3 and ra.cls == "barbarian", ra.cls)
	check("고개 방향도 따라감", absf(wrapf(rb.yaw - pb.yaw, -PI, PI)) < 0.05, "")

	# ── 투사체: 친구 화면에도 날아가고, 맞은 쪽(친구)이 피해를 판정 ──
	pa.scripted_input = FIRE
	await wait(2)
	pa.scripted_input = IDLE
	await wait(3)
	check("친구 화면에도 돌멩이가 생김", B.combat.projectiles.any(func(p): return p.owner == ra and p.kind == "stone"), "n=%d" % B.combat.projectiles.size())
	await wait(30)
	check("돌멩이에 맞아 친구 체력이 줄어듦 (친구 쪽 판정)", pb.hp < 100 and pb.hp >= 85, "hp=%.0f" % pb.hp)
	check("방장 쪽에선 직접 깎지 않고 상태로 받음", absf(rb.hp - pb.hp) < 1.0, "remote hp=%.0f" % rb.hp)

	# ── 저격총: 쏜 쪽(방장)이 판정해서 알림 → 친구 죽음, 방장 처치 +1 ──
	A.combat.items.drop_sniper(pa.global_position, 5)
	await wait(5)
	check("방장은 바로 주움", pa.has_sniper, "")
	await wait(20)
	pa.scripted_input = FIRE
	await wait(2)
	pa.scripted_input = IDLE
	var died: bool = await wait_until(func(): return not pb.alive, 60)
	check("저격총에 맞아 친구가 죽음", died, "hp=%.0f" % pb.hp)
	await wait_until(func(): return pa.kills == 1, 60)
	check("처치 수: 방장 1킬, 친구 1데스", pa.kills == 1 and pb.deaths == 1, "k=%d d=%d" % [pa.kills, pb.deaths])
	await wait(20)
	check("방장 화면에서 친구가 래그돌", not rb.alive and rb.ragdoll != null, "")
	check("친구 화면에도 방장 처치 수가 보임", ra.kills == 1, "k=%d" % ra.kills)
	# 친구 부활 (3초)
	var back: bool = await wait_until(func(): return pb.alive and rb.alive, 300)
	check("친구가 부활하면 방장 화면에도 나타남", back, "")

	# ── 아이템 줍기: 방장이 놓고, 친구가 닿으면 방장이 허락 ──
	pa.has_sniper = false
	pa.wep = "stone"
	var spot := HERE + Vector3(0, 0, -8)
	A.combat.items.drop_ak(spot, 25)
	var seen: bool = await wait_until(func(): return B.combat.items.ak.active, 60)
	check("방장이 놓은 AK가 친구 화면에도 뜸", seen and B.combat.items.ak.pos.distance_to(spot) < 0.1, "")
	put(pb, spot, "archer")
	var got: bool = await wait_until(func(): return pb.has_ak, 90)
	check("친구가 닿으면 방장 허락을 받아 주움", got and not A.combat.items.ak.active, "")
	await wait(20)
	check("방장 화면에서 친구가 AK를 든 걸로 보임", rb.has_ak, "")

	# ── 시간이 다 되면 방장이 끝냄 ──
	na.rem = 0.5
	var ended: bool = await wait_until(func(): return A.state == "ended" and B.state == "ended", 120)
	check("시간 끝 → 둘 다 결과 화면", ended, "%s/%s" % [A.state, B.state])

	# ── 한 판 더 (방장) → 둘 다 다시 경기 ──
	A.start_match()
	await wait_until(func(): return A.state == "playing" and B.state == "playing", 60)
	check("방장이 '한 판 더' 누르면 친구도 들어옴", A.state == "playing" and B.state == "playing", "%s/%s" % [A.state, B.state])
	check("처치 수 0부터", pa.kills == 0 and pb.deaths == 0, "")

	# ── 친구 나가기 ──
	B.go_menu("main")
	await wait_until(func(): return na.remotes.is_empty(), 120)
	check("친구가 나가면 메인 메뉴, 봇 돌아옴", not nb.on and B.state == "menu" and B.menu.cur_page == "main" and B.combat.ents.size() == 8, "ents=%d" % B.combat.ents.size())
	check("방장 쪽에서 친구가 사라짐", na.remotes.is_empty() and na.lobby_list().size() == 1, "")

	# ── 방장이 방을 닫으면 친구는 쫓겨남 ──
	nb.join_room("친구", "archer", "127.0.0.1")
	await wait_until(func(): return nb.on and na.remotes.size() == 1, 300)
	check("다시 들어감 (IP로)", nb.on and na.remotes.size() == 1, "")
	na.leave()
	var kicked: bool = await wait_until(func(): return not nb.on, 300)
	check("방장이 나가면 친구도 방에서 나옴", kicked and B.state == "menu" and B.menu.cur_page == "main", B.menu.cur_page)
	check("방장도 봇이 돌아옴", not na.on and A.combat.ents.size() == 8, "ents=%d" % A.combat.ents.size())

	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
