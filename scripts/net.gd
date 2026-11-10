class_name Net
extends Node
## 친구대전 (같은 와이파이·LAN) — HTML의 MP(claude.ai 방 기능)를 ENet으로 옮긴 것.
## 방장 컴퓨터가 ENet 서버가 되고, 친구는 방 코드 4자리로 찾아 들어온다:
##   방장은 UDP 방송으로 "방 코드 + 포트"를 0.5초마다 알리고, 친구는 그 방송을 듣다가 코드가 맞으면 접속한다.
##   방 코드 대신 방장 IP를 직접 넣어도 된다.
## 권한은 HTML과 같다:
##   - 각자 자기 캐릭터를 움직이고 30Hz로 상태를 보낸다. 남의 캐릭터는 받은 상태를 따라 그린다.
##   - 투사체(돌·활·석궁·성수) 피해는 맞은 사람 쪽에서 판정, 저격총·AK·마상창은 쏜 사람 쪽에서 판정.
##   - 방장이 경기 시간·종료, 저격총·AK·말 등장과 줍기 허락을 맡는다.
## 사건(발사·명중·처치)은 따로 믿을 수 있게(reliable) 보낸다.
## HTML과 다른 점: 방장이 나가면 방이 끝난다 (HTML은 다음 사람이 방장을 이어받음).
## 쟁탈전 (사용자 요청): 방장이 대기실에서 모드를 고른다 (room_mode). 사람은 블루/레드를 고르고(처음엔 방장이 적은 쪽에 넣어 줌),
##   빈자리는 방장 컴퓨터의 봇이 채운다. 봇은 음수 id(-1, -2 …)로 부르고, 방장이 명단(_roster)과 상태(_bots)를 보낸다.
##   방장 봇이 맞는 판정·처치 수는 방장 컴퓨터가 한다 (봇의 '맞은 쪽' = 방장). 사건은 누구 일인지(who)를 같이 보낸다.
##   라운드·점령·점수는 방장 ControlMode가 정하고 snapshot을 _cm으로 보낸다 (친구는 follower).

signal status(text: String)        # 친구대전 화면 아래 문구
signal lobby_changed               # 대기실 다시 그리기
signal start_requested(rem: float) # 경기 시작 (HTML mpStart)
signal end_requested               # 방장이 경기를 끝냄
signal closed(reason: String)      # 연결이 끊겨 방을 나감

const WEPS := ["stone", "bow", "crossbow", "sniper", "holy", "chicken", "lance", "ak", "trumpet", "fanfare", "star"]  # 번호가 바뀌지 않게 뒤에만 더함
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var main: Node            # Main (상태·페이지 확인)
var combat: Combat
var player: PlayerController

var on := false
var is_host := false
var code := ""
var my_name := ""
var cls := "archer"
var remotes := {}         # peer id → PlayerController
var info := {}            # peer id → {n, c, st, k, d, t}
var room_mode := "ffa"    # 방장: 이 방의 모드 (ffa / control). 친구는 mode_now()로 방장 것을 읽는다
var team := ""            # 쟁탈전에서 내 팀 (blue / red)
var bot_roster: Array = []  # 쟁탈전 빈자리 봇 [[id(음수), 이름, 병과, 팀], …] — 방장이 정해서 보냄
var last_mt := {}         # 방장이 보낸 경기 상태 {st, ep, rem}
var seen_epoch := 0
# 방장 쪽
var mst := "lobby"        # lobby / play / end
var epoch := 0
var rem := 0.0
var grants := {}          # 줍기 허락 {sn: [seq, peer], ak: …, hs: …}
# 아이템 줍기 요청·허락 (HTML MP.seqSeen / MP.req / MP.got)
var seq_seen := {}
var req := {}
var got := {}

var _send_t := 0.0
var _host_t := 0.0
var _mt_t := 0.0
var _cm_t := 0.0
var _udp: PacketPeerUDP   # 방장: 방송 보내기 / 친구: 방송 듣기
var _beacon_t := 0.0
var _find_t := 0.0
var _joining := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail("방에 들어가지 못했어요. 방장 컴퓨터가 같은 와이파이에 있는지 확인해 주세요."))
	multiplayer.server_disconnected.connect(func() -> void: _close("방장이 방을 닫았어요"))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## 이 컴퓨터의 와이파이 IP (192.168.x.x 같은 사설 IPv4). 친구가 코드로 못 찾을 때 직접 넣는다
## 공유기는 보통 192.168.x.x를 준다. 172.x는 WSL·Hyper-V 같은 가상 어댑터일 때가 많아 맨 뒤로 둔다
static func lan_ip() -> String:
	var addrs := IP.get_local_addresses()
	for pre: String in ["192.168.", "10."]:
		for a: String in addrs:
			if a.begins_with(pre):
				return a
	for a: String in addrs:
		if a.begins_with("172."):
			var b := int(a.split(".")[1])
			if b >= 16 and b <= 31:
				return a
	return ""


static func gen_code() -> String:
	var c := ""
	for i in 4:
		c += CODE_CHARS[randi() % CODE_CHARS.length()]
	return c


func me_id() -> int:
	return multiplayer.get_unique_id() if on else 0


## 이 캐릭터의 peer id (나면 내 id, 없으면 0)
func peer_of(e: PlayerController) -> int:
	if e == null:
		return 0
	if e.is_bot and not e.is_remote and e.peer < 0:  # 방장 봇
		return e.peer
	if e.is_local:
		return me_id()
	return e.peer if e.is_remote else 0


func ent_of(peer: int) -> PlayerController:
	if peer == 0:
		return null
	if peer == me_id():
		return player
	if peer < 0 and is_host:
		return main.bot_by_id(peer)
	return remotes.get(peer)


## 이 id가 내 컴퓨터에서 피해를 판정하는 캐릭터면 돌려줌 (나, 방장이면 내 봇)
func mine(peer: int) -> PlayerController:
	if peer == 0:
		return null
	if peer == me_id():
		return player
	if peer < 0 and is_host:
		var b: PlayerController = main.bot_by_id(peer)
		return b if b and combat.ents.has(b) else null
	return null


# ── 방 만들기·들어가기·나가기 ────────────────────────────────
func host_room(nick: String, c: String) -> void:
	var N: Dictionary = GameData.NET
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(int(N.port), int(N.max_players) - 1)
	if err != OK:
		status.emit("방을 만들지 못했어요. 이미 이 컴퓨터에서 방을 열었거나 포트 %d이(가) 막혀 있어요." % int(N.port))
		return
	multiplayer.multiplayer_peer = peer
	_begin(nick, c, gen_code(), true)
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_beacon_t = 0.0


## code_or_ip: 방 코드 4자리 또는 방장 IP (예: 192.168.0.12)
func join_room(nick: String, c: String, code_or_ip: String) -> void:
	var s := code_or_ip.strip_edges().to_upper()
	if s.is_valid_ip_address():
		_connect_to(s, nick, c, "")
		return
	if not _valid_code(s):
		status.emit("방 코드 4자리를 입력하세요.")
		return
	_close_udp()
	_udp = PacketPeerUDP.new()
	if _udp.bind(int(GameData.NET.disc_port)) != OK:
		_udp = null
		status.emit("방을 찾을 수 없어요. 방장 IP를 직접 넣어 보세요.")
		return
	my_name = _nick(nick)
	cls = c
	code = s
	_find_t = float(GameData.NET.find_timeout)
	status.emit("같은 와이파이에서 방 %s을(를) 찾는 중…" % s)


static func _valid_code(s: String) -> bool:
	if s.length() != 4:
		return false
	for ch in s:
		if not CODE_CHARS.contains(ch) and not "01IO".contains(ch):
			return false
	return true


func _connect_to(ip: String, nick: String, c: String, room: String) -> void:
	var N: Dictionary = GameData.NET
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, int(N.port)) != OK:
		status.emit("방에 들어가지 못했어요.")
		return
	multiplayer.multiplayer_peer = peer
	_joining = true
	my_name = _nick(nick)
	cls = c
	code = room
	status.emit("연결하는 중…")


static func _nick(n: String) -> String:
	n = n.strip_edges().substr(0, int(GameData.NET.name_max))
	return n if n != "" else "기사%d" % randi_range(10, 99)


func _on_connected() -> void:
	_joining = false
	_begin(my_name, cls, code, false)
	_hello_all()


func _begin(nick: String, c: String, room: String, host: bool) -> void:
	on = true
	is_host = host
	my_name = _nick(nick)
	cls = c
	code = room
	last_mt = {}
	seen_epoch = 0
	mst = "lobby"
	epoch = 0
	rem = 0.0
	grants = {}
	seq_seen = {}
	req = {}
	got = {}
	room_mode = "ffa"
	team = "blue" if host else ""  # 친구는 방장이 적은 팀에 넣어 준다 (_assign_team)
	bot_roster = []
	combat.net = self
	status.emit("")
	main.enter_mp()
	lobby_changed.emit()


func leave() -> void:
	if not on and not _joining and _udp == null:
		return
	_shutdown()
	main.leave_mp()


func _close(reason: String) -> void:
	if not on:
		return
	_shutdown()
	closed.emit(reason)


func _fail(text: String) -> void:
	_joining = false
	_shutdown()
	status.emit(text)


func _shutdown() -> void:
	_close_udp()
	for p: int in remotes.keys():
		_remove_remote(p)
	info.clear()
	bot_roster = []
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	on = false
	is_host = false
	_joining = false
	if combat:
		combat.net = null


func _close_udp() -> void:
	if _udp:
		_udp.close()
	_udp = null


# ── 사람 들어오고 나가기 ─────────────────────────────────────
func _on_peer_connected(id: int) -> void:
	if on:  # 새로 온 사람에게 내 소개 (서버가 다른 친구에게도 전해 준다)
		_hello.rpc_id(id, _my_info())
		if is_host:
			_roster.rpc_id(id, bot_roster)
			_mt.rpc_id(id, _mt_dict())


func _on_peer_disconnected(id: int) -> void:
	_remove_remote(id)
	info.erase(id)
	lobby_changed.emit()


func _hello_all() -> void:
	_hello.rpc(_my_info())


func _my_info() -> Dictionary:
	var st := "play" if main.state == "playing" or main.state == "paused" else "lobby"
	return {"n": my_name, "c": cls, "st": st, "k": player.kills, "d": player.deaths, "t": team}


@rpc("any_peer", "reliable")
func _hello(d: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	info[id] = d
	var e := _ensure_remote(id)
	e.ent_name = str(d.get("n", "친구")).substr(0, int(GameData.NET.name_max))
	e.kills = int(d.get("k", 0))
	e.deaths = int(d.get("d", 0))
	var t := str(d.get("t", ""))
	if is_host and t == "":  # 새로 온 친구: 사람이 적은 팀으로
		t = _emptier_team(id)
		d.t = t
		_assign_team.rpc_id(id, t)
	if t != "" and main.mode and e.team != t:  # 쟁탈전 중에 들어옴: 팀 색으로
		_set_remote_team(e, t)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _assign_team(t: String) -> void:
	team = t
	send_info()


## 쟁탈전 팀별 사람 수 (나 포함, skip은 빼고)
func team_counts(skip := 0) -> Dictionary:
	var n := {"blue": 0, "red": 0}
	if team in n:
		n[team] += 1
	for id: int in info:
		var t := str((info[id] as Dictionary).get("t", ""))
		if id != skip and t in n:
			n[t] += 1
	return n


func _emptier_team(skip := 0) -> String:
	var n := team_counts(skip)
	return "red" if n.red < n.blue else "blue"


## 대기실 '팀 바꾸기' — 상대 팀 사람이 team_size보다 적을 때만
func switch_team() -> bool:
	var other := "red" if team == "blue" else "blue"
	if int(team_counts()[other]) >= int(GameData.MODES.control.team_size):
		status.emit("%s이 꽉 찼어요" % ControlMode.team_name(other))
		return false
	team = other
	send_info()
	return true


## 방장: 대기실에서 모드 고르기
func set_room_mode(k: String) -> void:
	if not is_host or not (k == "ffa" or GameData.MODES.has(k)):
		return
	room_mode = k
	_mt.rpc(_mt_dict())
	lobby_changed.emit()


## 이 방의 모드 (방장이 고른 것)
func mode_now() -> String:
	return room_mode if is_host else str(last_mt.get("md", "ffa"))


func team_of(peer: int) -> String:
	if peer == me_id():
		return team
	return str(info.get(peer, {}).get("t", ""))


func _set_remote_team(e: PlayerController, t: String) -> void:
	main.set_team(e, t)
	if e.model:  # 팀 색으로 몸을 다시 만듦
		var was := e.model.visible
		var hp := e.hp
		e.set_class(e.cls)
		e.hp = hp
		e.model.visible = was


## 병과를 바꾸거나 게임에 들어가고 나올 때 다시 소개
func send_info() -> void:
	if on:
		_hello_all()
	lobby_changed.emit()


func set_cls(c: String) -> void:
	cls = c
	send_info()


func _ensure_remote(id: int, c := "") -> PlayerController:
	if remotes.has(id):
		return remotes[id]
	var e: PlayerController = PLAYER_SCENE.instantiate()
	e.is_local = false
	e.is_remote = true
	e.peer = id
	e.cls = c if c != "" else str(info.get(id, {}).get("c", "archer"))
	if not GameData.CLASSES.has(e.cls):
		e.cls = "archer"
	e.ent_name = "친구"
	main.add_child(e)
	e.alive = false
	e.spectating = false
	if e.model:
		e.model.visible = false
	combat.register(e)
	remotes[id] = e
	return e


func _remove_remote(id: int) -> void:
	var e: PlayerController = remotes.get(id)
	if not e:
		return
	remotes.erase(id)
	combat.unregister(e)
	if not e.horse.is_empty():
		(e.horse.g as Node).queue_free()
		e.horse = {}
	e.queue_free()


## 대기실 목록 (HTML renderLobby)
func lobby_list() -> Array:
	var me_st := "play" if main.state == "playing" or main.state == "paused" else ""
	var list: Array = [{"name": my_name + " (나)", "cls": cls, "host": is_host, "st": me_st}]
	var ids: Array = info.keys()
	ids.sort()
	for id: int in ids:
		var d: Dictionary = info[id]
		var c := str(d.get("c", "archer"))
		list.append({"name": str(d.get("n", "친구")), "cls": c if GameData.CLASSES.has(c) else "archer", "host": id == 1, "st": str(d.get("st", "")), "team": str(d.get("t", ""))})
	list[0].team = team
	return list


func live_match() -> bool:
	return not is_host and last_mt.get("st", "") == "play"


# ── 경기 시작·끝 (방장) ──────────────────────────────────────
func _mt_dict() -> Dictionary:
	return {"st": mst, "ep": epoch, "rem": maxf(0.0, roundf(rem)), "md": room_mode}


func host_start() -> void:
	if not is_host:
		return
	epoch += 1
	seen_epoch = epoch
	mst = "play"
	rem = GameData.MATCH_TIME
	grants = {}
	bot_roster = main.mp_pick_bots() if room_mode == "control" else []  # 쟁탈전: 빈자리를 봇으로
	_roster.rpc(bot_roster)  # 시작 알림보다 먼저 (친구가 봇을 만들어 두게)
	_mt.rpc(_mt_dict())
	start_requested.emit(rem)
	_host_t = 0.0


## 결과 화면·대기실로 돌아감 (HTML goLobby)
func to_lobby() -> void:
	if is_host:
		mst = "lobby"
		if not bot_roster.is_empty():
			bot_roster = []
			_roster.rpc(bot_roster)
		_mt.rpc(_mt_dict())
	send_info()


## 친구: 방장 봇 명단 — 봇을 친구 캐릭터처럼 만들고(음수 id), 명단에 없는 봇은 지운다
@rpc("authority", "reliable")
func _roster(r: Array) -> void:
	bot_roster = r
	var keep := {}
	for b: Array in r:
		if b.size() < 4:
			continue
		var id := int(b[0])
		keep[id] = true
		var c := str(b[2])
		var e := _ensure_remote(id, c if GameData.CLASSES.has(c) else "archer")
		e.ent_name = str(b[1])
		if e.team != str(b[3]):
			_set_remote_team(e, str(b[3]))
	for id: int in remotes.keys():
		if id < 0 and not keep.has(id):
			_remove_remote(id)
	lobby_changed.emit()


## 친구: 진행 중인 경기에 들어가기
func join_live() -> void:
	if live_match():
		seen_epoch = int(last_mt.get("ep", 0))
		start_requested.emit(float(last_mt.get("rem", GameData.MATCH_TIME)))


@rpc("authority", "reliable")
func _mt(mt: Dictionary) -> void:
	last_mt = mt
	var st := str(mt.get("st", "lobby"))
	var ep := int(mt.get("ep", 0))
	if st == "play" and ep > seen_epoch and (main.state == "menu" or main.state == "ended") and main.menu.cur_page != "friend":
		seen_epoch = ep
		start_requested.emit(float(mt.get("rem", GameData.MATCH_TIME)))
	elif st == "end" and main.state in ["playing", "paused"] and ep == seen_epoch:
		end_requested.emit()
	if main.state in ["playing", "paused"] and mt.has("rem") and absf(main.time_left - float(mt.rem)) > 1.5:
		main.time_left = float(mt.rem)
	lobby_changed.emit()


# ── 매 프레임 ────────────────────────────────────────────────
func _physics_process(dt: float) -> void:
	_poll_udp(dt)
	if not on:
		return
	for id: int in remotes:
		_apply_remote(remotes[id], dt)
	var N: Dictionary = GameData.NET
	_send_t -= dt
	if _send_t <= 0:
		_send_t = 1.0 / float(N.send_hz)
		_state.rpc(_state_of(player))
		if is_host and not bot_roster.is_empty():  # 봇 상태는 4명씩 나눠 보냄 (한 묶음이 MTU를 넘지 않게)
			var bs := _bot_states()
			for i in range(0, bs.size(), 4):
				_bots.rpc(bs.slice(i, i + 4))
	if is_host:
		_host_tick(dt)
		if main.mode and mst == "play":  # 쟁탈전 상태 (라운드·점령·점수)
			_cm_t -= dt
			if _cm_t <= 0:
				_cm_t = 1.0 / float(N.ctrl_hz)
				_cm.rpc(main.mode.snapshot())


func _host_tick(dt: float) -> void:
	var N: Dictionary = GameData.NET
	if mst == "play":
		rem -= dt
		main.time_left = maxf(0.0, rem)
	_host_t -= dt
	_mt_t -= dt
	if _host_t <= 0:
		_host_t = 1.0 / float(N.host_hz)
		if mst == "play":
			var mx := player.kills
			for e: PlayerController in remotes.values():
				mx = maxi(mx, e.kills)
			var over := rem <= 0 or mx >= GameData.KILL_LIMIT
			if main.mode:  # 쟁탈전: 라운드 규칙이 끝을 정함 (킬·시간 제한 없음)
				over = main.mode.phase == "over"
			if over:
				mst = "end"
				_mt.rpc(_mt_dict())
				end_requested.emit()
		_it.rpc(_items_dict())
	if _mt_t <= 0:  # 시간 맞추기 겸 1초마다
		_mt_t = 1.0
		_mt.rpc(_mt_dict())


## 방장: 방송 보내기 / 친구: 방송 듣고 코드가 맞는 방에 접속 (HTML의 방 코드 대신)
func _poll_udp(dt: float) -> void:
	if not _udp:
		return
	var N: Dictionary = GameData.NET
	if is_host and on:
		_beacon_t -= dt
		if _beacon_t <= 0:
			_beacon_t = float(N.beacon_every)
			var msg := ("%s|%s|%d" % [N.beacon_tag, code, int(N.port)]).to_utf8_buffer()
			for addr in ["255.255.255.255", "127.0.0.1"]:  # 같은 컴퓨터에서 창 두 개로 시험할 때도 찾게
				_udp.set_dest_address(addr, int(N.disc_port))
				_udp.put_packet(msg)
		return
	_find_t -= dt
	while _udp and _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet().get_string_from_utf8()
		var ip := _udp.get_packet_ip()
		var parts := pkt.split("|")
		if parts.size() == 3 and parts[0] == N.beacon_tag and parts[1] == code:
			_close_udp()
			_connect_to(ip, my_name, cls, code)
			return
	if _find_t <= 0:
		_close_udp()
		status.emit("방 %s을(를) 찾지 못했어요. 코드를 확인하거나 방장 IP를 직접 넣어 보세요." % code)


# ── 내 상태 보내기 / 남의 상태 따라가기 (HTML mpTick / applyRemote) ──
func _my_state() -> Array:
	return _state_of(player)


func _state_of(p: PlayerController) -> Array:
	var playing: bool = main.state == "playing" or main.state == "paused"
	var fl := (1 if p.crouch else 0) | (2 if p.sliding else 0) | (4 if p.grounded else 0) | (8 if p.alive and playing else 0) \
		| (16 if p.sprinting else 0) | (32 if p.charging else 0) | (64 if p.helmet else 0) | (128 if p.has_sniper else 0) \
		| (256 if p.invuln > 0 else 0) | (512 if p.has_ak else 0) | (1024 if p.playing else 0) | (2048 if p.dance_t > 0 else 0) \
		| (4096 if p.star_t > 0 else 0)
	return [p.global_position, p.yaw, p.pitch, p.velocity, fl, p.fall_t, p.fall_rx, p.fall_rz, p.fall_yaw, p.mounted,
		maxf(0.0, ceilf(p.hp)), maxi(0, WEPS.find(p.wep)), p.charge, p.cls, p.kills, p.deaths, "play" if playing else "lobby"]


@rpc("any_peer", "unreliable_ordered")
func _state(s: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	var e: PlayerController = remotes.get(id)
	if not e or s.size() < 17:
		return
	e.net_s = s
	e.kills = int(s[14])
	e.deaths = int(s[15])
	if info.has(id):
		(info[id] as Dictionary).st = str(s[16])


## 방장: 봇 상태 묶음 [[id, 상태], …]
func _bot_states() -> Array:
	var out: Array = []
	for b: Array in bot_roster:
		var e: PlayerController = main.bot_by_id(int(b[0]))
		if e:
			out.append([int(b[0]), _state_of(e)])
	return out


@rpc("authority", "unreliable_ordered")
func _bots(arr: Array) -> void:
	for x: Variant in arr:
		if not x is Array or (x as Array).size() < 2:
			continue
		var e: PlayerController = remotes.get(int(x[0]))
		var st: Array = x[1]
		if not e or st.size() < 17:
			continue
		e.net_s = st
		e.kills = int(st[14])
		e.deaths = int(st[15])


## 친구: 방장 쟁탈전 상태 (작아서 믿을 수 있게 보냄 — unreliable은 reliable 사건 뒤로 밀리면 ENet이 버린다)
@rpc("authority", "reliable")
func _cm(snap: Array) -> void:
	if main.mode and main.mode.follower and main.state in ["playing", "paused"]:
		main.mode.apply_snapshot(snap)


func _apply_remote(e: PlayerController, dt: float) -> void:
	var s: Array = e.net_s
	e.respawn = maxf(0.0, e.respawn - dt)
	if s.is_empty():
		return
	var N: Dictionary = GameData.NET
	var fl := int(s[4])
	var alive := (fl & 8) != 0
	var pos: Vector3 = s[0]
	if alive and not e.alive:
		if e.respawn > 0:  # 방금 죽었다는 사건을 받았으면 옛 상태로 되살리지 않는다
			return
		var c := str(s[13])
		e.set_class(c if GameData.CLASSES.has(c) else e.cls)
		e.alive = true
		e.ragdoll = null
		e.helmet = true
		e.hp = float(s[10])
		e.global_position = pos
		e.yaw = float(s[1])
		e.velocity = Vector3.ZERO
		e.net_dead_t = 0.0
		e.reset_physics_interpolation()
	if not alive:
		if e.alive:  # 처치 사건보다 상태가 먼저 왔을 수 있으니 잠깐 기다렸다가 숨김
			e.net_dead_t += dt
			if e.net_dead_t > float(N.dead_wait):
				e.alive = false
				if e.model:
					e.model.visible = false
				if not e.horse.is_empty():
					combat.items.dismount(e)
		return
	e.net_dead_t = 0.0
	var sc := str(s[13])
	if sc != e.cls and GameData.CLASSES.has(sc):  # 병과가 바뀌면 몸을 새로 만듦
		e.set_class(sc)
	var k := 1.0 - exp(-dt * float(N.follow))
	var p := e.global_position
	if Vector2(pos.x - p.x, pos.z - p.z).length() > float(N.snap_dist):
		p = pos
		e.global_position = p
		e.reset_physics_interpolation()
	e.global_position = p + (pos - p) * k
	e.yaw += wrapf(float(s[1]) - e.yaw, -PI, PI) * k
	e.pitch += (float(s[2]) - e.pitch) * k
	e.velocity = s[3]
	e.crouch = (fl & 1) != 0
	e.sliding = (fl & 2) != 0
	e.grounded = (fl & 4) != 0
	e.sprinting = (fl & 16) != 0
	e.charging = (fl & 32) != 0
	e.has_sniper = (fl & 128) != 0
	e.invuln = 0.5 if (fl & 256) != 0 else 0.0
	e.has_ak = (fl & 512) != 0
	e.playing = (fl & 1024) != 0  # 연주 중이면 내 쪽에서 원뿔 안인지 계산한다 (Trumpet.update_victims)
	e.dance_t = 0.2 if (fl & 2048) != 0 else 0.0  # 춤은 친구 컴퓨터가 정하고, 나는 모습만
	var was_star := e.star_t > 0
	e.star_t = float(GameData.STAR_FX.end_t) + 1.0 if (fl & 4096) != 0 else 0.0
	if e.star_t > 0 and not was_star:  # 친구가 먹었다: 배너 + 그 자리에서 작게 반짝 소리
		combat.items.ate_fx(e)  # 황금 붕어빵 무적: 반짝임만 (끝나기 직전 깜빡임은 못 봄)
	var hel := (fl & 64) != 0
	if e.helmet and not hel and e.model and e.model.helm:
		combat.knock_helmet(e, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())
	e.helmet = hel
	e.fall_t = float(s[5])
	e.fall_rx = float(s[6])
	e.fall_rz = float(s[7])
	e.fall_yaw = float(s[8])
	e.mounted = float(s[9])
	e.mount_h = GameData.MOUNT_H if e.mounted > 0 else 0.0
	e.hp = float(s[10])
	var wi := int(s[11])
	if wi >= 0 and wi < WEPS.size():
		e.wep = WEPS[wi]
	e.charge = float(s[12])


# ── 사건 (HTML mpEvent / handleEvent) ───────────────────────
## x = [종류, …]. f 발사 / sn 저격총 / ak / ln 마상창 / fan 팡파레 / h 맞음 / k 죽음 / st 몸박치기
## from = 누구 일인가 (방장 봇이면 그 봇 id를 같이 보냄, 아니면 보낸 사람)
func event(x: Array, from: PlayerController = null) -> void:
	if on:
		_ev.rpc(x, from.peer if from and from.is_bot and not from.is_remote and from.peer < 0 else 0)


@rpc("any_peer", "reliable")
func _ev(x: Array, who: int) -> void:
	var sid := multiplayer.get_remote_sender_id()
	var e: PlayerController = remotes.get(who if who < 0 and sid == 1 else sid)  # 봇 일은 방장만 보낼 수 있음
	if not e or x.is_empty() or not (main.state in ["playing", "paused"]):
		return
	match str(x[0]):
		"f":  # [f, 무기, 위치, 속도, 당김]
			if e.alive:
				combat.remote_fire(e, WEPS[clampi(int(x[1]), 0, WEPS.size() - 1)], x[2], x[3], clampf(float(x[4]), 0, 1))
		"sn":  # [sn, 총구, 끝, 맞은 사람, 머리]
			combat.remote_shot(e, "sniper", x[1], x[2])
			var v := mine(int(x[3]))
			if v and v.alive:
				combat.damage(v, e, GameData.ITEM.sniper_kill, "sniper", bool(x[4]), ((x[2] as Vector3) - (x[1] as Vector3)).normalized(), x[2])
		"ak":  # [ak, 총구, 끝, 맞은 사람, 머리, 피해]
			combat.remote_shot(e, "ak", x[1], x[2])
			var v := mine(int(x[3]))
			if v and v.alive:
				combat.damage(v, e, clampf(float(x[5]), 0, GameData.WEAPONS.ak.dmg), "ak", bool(x[4]), ((x[2] as Vector3) - (x[1] as Vector3)).normalized(), x[2])
		"fan":  # [fan] — 친구 음유시인의 팡파레. 내가 앞에 있었는지는 내 쪽에서 판정
			if e.alive:
				combat.remote_fanfare(e)
		"ln":  # [ln, 맞은 사람, 머리, 방향]
			var v := mine(int(x[1]))
			if v and v.alive:
				var d: Vector3 = x[3]
				d.y = 0
				combat.damage(v, e, GameData.WEAPONS.lance.dmg, "lance", bool(x[2]), d.normalized() if d.length_squared() > 1e-4 else Vector3(0, 0, 1))
		"st":  # [st, 맞은 사람, 방향] — 황금 붕어빵 무적 몸박치기 (내가 무적이면 damage가 막음)
			var v := mine(int(x[1]))
			if v and v.alive:
				var d: Vector3 = x[2]
				d.y = 0
				combat.damage(v, e, GameData.WEAPONS.star.dmg, "star", false, d.normalized() if d.length_squared() > 1e-4 else Vector3(0, 0, 1))
		"h":  # [h, 때린 사람, 피해, 무기, 머리] — e가 맞음 (맞은 쪽이 판정해서 알려줌)
			if e.alive:
				combat.remote_hit(e, ent_of(int(x[1])), float(x[2]), WEPS[clampi(int(x[3]), 0, WEPS.size() - 1)], bool(x[4]))
		"k":  # [k, 죽인 사람, 무기, 머리, 방향] — e가 죽음
			var d: Vector3 = x[4]
			d.y = 0
			e.respawn = float(GameData.NET.revive_guard)
			combat.remote_kill(e, ent_of(int(x[1])), WEPS[clampi(int(x[2]), 0, WEPS.size() - 1)], bool(x[3]), d.normalized() if d.length_squared() > 1e-4 else Vector3(0, 0, 1))


# ── 특수 아이템: 방장이 등장·위치를 알리고 줍기를 허락 (HTML mirrorItems / handleRequest / mpRequest) ──
func _items_dict() -> Dictionary:
	var I = combat.items
	return {"sn": _pack(I.sniper), "ak": _pack(I.ak), "hs": _pack(I.horse), "hb": _pack(I.horse_b), "gf": _pack(I.fish), "gr": grants}


static func _pack(it: Dictionary) -> Array:
	if it.active:
		return [1, it.pos, ceilf(float(it.life)), int(it.get("seq", 0))]
	return [0, Vector3.ZERO, 0, int(it.get("seq", 0))]


@rpc("authority", "unreliable_ordered")
func _it(it: Dictionary) -> void:
	if is_host:
		return
	var I = combat.items
	var playing: bool = main.state == "playing"
	_mirror(I.sniper, it.get("sn"), "sn", func() -> void:
		if playing:
			I.announce("sn"))
	_mirror(I.ak, it.get("ak"), "ak", func() -> void:
		if playing:
			I.announce("ak"))
	_mirror(I.horse, it.get("hs"), "hs", func() -> void:
		if playing:
			I.announce("hs"))
	_mirror(I.horse_b, it.get("hb"), "hb", func() -> void:  # 쟁탈전 두 번째 말 (알림은 첫 말이 함께 띄움)
		pass)
	_mirror(I.fish, it.get("gf"), "gf", func() -> void:
		if playing:
			I.announce("gf"))
	var gr: Dictionary = it.get("gr", {})
	var me := me_id()
	var p := player
	for key: String in ["sn", "ak", "hs", "hb", "gf"]:
		var g: Array = gr.get(key, [])
		if g.size() == 2 and int(g[1]) == me and got.get(key, -1) != int(g[0]):
			got[key] = int(g[0])
			if key == "gf":
				if p.alive:
					I.eat_fish(p)
			elif key == "hs" or key == "hb":
				if p.alive and p.mounted <= 0:
					I.mount(p, I.horse_b if key == "hb" else I.horse)
			elif p.alive and not p.has_sniper and not p.has_ak and p.mounted <= 0:
				if key == "sn":
					I.pickup_sniper(p)
				else:
					I.pickup_ak(p)


func _mirror(item: Dictionary, arr: Variant, key: String, on_new: Callable) -> void:
	if not arr is Array or (arr as Array).size() < 4:
		return
	var a: Array = arr
	var sq := int(a[3])
	var g: Node3D = item.group
	if int(a[0]) == 1:
		if seq_seen.get(key, -1) != sq:
			seq_seen[key] = sq
			on_new.call()
		item.active = true
		item.pos = a[1]
		item.life = float(a[2])
		if g.global_position.distance_to(a[1]) > 0.01:
			g.global_position = a[1]
			g.reset_physics_interpolation()
		g.visible = true
	else:
		seq_seen[key] = sq
		item.active = false
		g.visible = false


## 친구: 아이템에 닿았으니 방장에게 달라고 함 (같은 아이템에 한 번만)
func request(key: String) -> void:
	if not on or is_host:
		return
	var sq: int = seq_seen.get(key, -1)
	if sq < 0 or req.get(key, -1) == sq:
		return
	req[key] = sq
	_pick.rpc_id(1, key, sq)


@rpc("any_peer", "reliable")
func _pick(key: String, sq: int) -> void:
	if not is_host:
		return
	var I = combat.items
	var it: Dictionary = {"sn": I.sniper, "ak": I.ak, "hs": I.horse, "hb": I.horse_b, "gf": I.fish}.get(key, {})
	if it.is_empty() or not it.active or int(it.get("seq", 0)) != sq:
		return
	it.active = false
	(it.group as Node3D).visible = false
	grants[key] = [sq, multiplayer.get_remote_sender_id()]
	_host_t = 0.0
