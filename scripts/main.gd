extends Node3D
## 게임 진입점 — 조명·하늘·안개, 캐릭터 만들기, 경기 흐름(HTML startMatch / endMatch / startMenuSim /
## pauseGame / resumeGame / goMenu), 마우스 잠금.
## 상태: menu(메뉴 뒤에서 봇끼리 싸움) → playing → paused / ended.
## 일시정지는 SceneTree.paused로 월드·캐릭터·Combat을 멈춘다. Main·HUD·메뉴는 계속 돈다.
## 친구대전(Net)에선 봇을 빼고, 일시정지해도 게임은 멈추지 않는다 (HTML MP). 시간·종료는 방장이 정한다.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var world: WorldBuilder = $World
@onready var combat: Combat = $Combat
@onready var player: PlayerController = $Player
@onready var hud: Hud = $HUD

var menu: Menu
var net: Net
var bots: Array[PlayerController] = []
var state := "menu"
var _lobby_t := 0.0
var _was_locked := false  # 웹: 지난 프레임에 마우스가 잠겨 있었나
var time_left: float = GameData.MATCH_TIME


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: Node in [world, combat, player]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 HUD는 그대로 보임
	_setup_environment()
	combat.world = world
	player.toast.connect(hud.pop_msg)
	combat.toast.connect(hud.pop_msg)
	combat.num.connect(hud.spawn_num)
	combat.hitmark.connect(hud.hitmark)
	combat.hurt.connect(hud.on_hurt)
	combat.dmg_dir.connect(hud.dmg_dir)
	player.class_changed.connect(Music.on_class_changed)  # 내 병과 기준으로 BGM
	combat.star_changed.connect(func(e: PlayerController, on: bool) -> void:
		if e != player:  # 남이 먹었을 땐 BGM 안 바뀜
			return
		if on:
			Music.play_override("star", GameData.MUSIC.star_in)  # 황금 붕어빵: 메탈로 빠르게
		else:
			Music.end_override(GameData.MUSIC.star_out))      # 끝나면 원래 곡을 멈췄던 자리부터
	Sfx.listener = player
	Sfx.listener_cam = player.cam
	combat.killed.connect(_on_killed)
	combat.items.banner.connect(func(t: String, sub: String) -> void:
		if state == "playing":  # 아이템 등장·획득 문구는 경기 중에만
			hud.banner(t, sub))
	hud.player = player
	hud.combat = combat
	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.start_requested.connect(start_match)
	menu.resume_requested.connect(resume_game)
	menu.menu_requested.connect(go_menu)
	menu.again_requested.connect(start_match)
	menu.next_class_picked.connect(func(k: String) -> void:
		player.next_cls = k
		if net.on:
			net.set_cls(k))
	combat.register(player)
	_spawn_bots()
	_setup_net()
	go_menu("main")


## 친구대전 (LAN) 연결 — HTML mpConnect / leaveMP / handlePeers
func _setup_net() -> void:
	net = Net.new()
	net.name = "Net"
	net.main = self
	net.combat = combat
	net.player = player
	add_child(net)
	net.status.connect(menu.friend_status)
	net.lobby_changed.connect(_render_lobby)
	net.start_requested.connect(mp_start)
	net.end_requested.connect(end_match)
	net.closed.connect(func(reason: String) -> void:
		leave_mp()
		menu.toast(reason))
	menu.friend_create.connect(func(nick: String) -> void:
		_save_nick(nick)
		net.host_room(nick, GameData.chosen_cls))
	menu.friend_join.connect(func(nick: String, code: String) -> void:
		_save_nick(nick)
		net.join_room(nick, GameData.chosen_cls, code))
	menu.lobby_leave.connect(func() -> void: net.leave())
	menu.lobby_start.connect(func() -> void:
		if net.is_host:
			net.host_start()
		else:
			net.join_live())
	menu.lobby_class.connect(func(k: String) -> void:
		player.next_cls = k
		net.set_cls(k))


func _save_nick(nick: String) -> void:
	GameData.nick = nick.strip_edges()
	GameData.save_settings()


## 방에 들어감: 봇을 빼고 대기실로 (HTML enterMPMode)
func enter_mp() -> void:
	for b in bots:
		combat.unregister(b)
		if not b.horse.is_empty():
			combat.items.dismount(b)
		b.alive = false
		b.process_mode = Node.PROCESS_MODE_DISABLED
		if b.model:
			b.model.visible = false
	combat.clear_match_objects()
	hud.clear()
	go_lobby()


## 방에서 나옴: 봇을 다시 넣고 메인 메뉴 (HTML leaveMP)
func leave_mp() -> void:
	for b in bots:
		b.process_mode = Node.PROCESS_MODE_PAUSABLE
		combat.register(b)
	go_menu("main")


## 대기실 (HTML goLobby)
func go_lobby() -> void:
	get_tree().paused = false
	_set_state("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_spectating(true)
	menu.show_screen("menu")
	menu.open_lobby(net.cls)
	net.to_lobby()
	_render_lobby()


func _render_lobby() -> void:
	if not net.on or state != "menu" or menu.cur_page != "lobby":
		return
	var list := net.lobby_list()
	var live := net.live_match()
	var sub: String
	if net.is_host:
		sub = "%d명 · 친구가 다 들어오면 게임 시작을 누르세요" % list.size()
		var ip := Net.lan_ip()
		if ip != "":
			sub += " · 방장 IP %s" % ip
	elif live:
		sub = "%d명 · 게임이 진행 중이에요" % list.size()
	else:
		sub = "%d명 · 방장이 시작하기를 기다리는 중" % list.size()
	var btn := "게임 시작" if net.is_host else ("진행 중인 게임 참가" if live else "")
	menu.render_lobby(net.code, list, sub, btn)


## 친구대전 경기 시작 (HTML mpStart) — 나만 스폰. 친구는 각자 컴퓨터에서 스폰한다
func mp_start(rem: float) -> void:
	get_tree().paused = false
	combat.clear_match_objects()
	hud.clear()
	time_left = rem
	player.kills = 0
	player.deaths = 0
	player.next_cls = net.cls
	player.spectating = false
	player.alive = false
	for e: PlayerController in net.remotes.values():
		e.kills = 0
		e.deaths = 0
	combat.spawn(player)
	_set_state("playing")
	menu.show_screen("")
	hud.banner("친구대전 시작!", "%s · %d킬을 먼저 따내면 승리" % [GameData.CLASSES[player.cls].name, GameData.KILL_LIMIT])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	net.send_info()


## 봇 BOT_COUNT명. 이름은 섞어서, 병과는 무작위 (HTML pickBotClass). 스폰은 startMenuSim / startMatch가 한다.
func _spawn_bots() -> void:
	var names: Array = GameData.BOT_NAMES.duplicate()
	names.shuffle()
	for i in GameData.BOT_COUNT:
		var b: PlayerController = PLAYER_SCENE.instantiate()
		bots.append(b)
		b.is_local = false
		b.is_bot = true
		b.ent_name = names[i % names.size()]
		b.cls = GameData.bot_classes().pick_random()
		b.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(b)
		b.alive = false
		combat.register(b)


# ── 경기 흐름 ────────────────────────────────────────────────
## HTML startMatch: 다 치우고, 모두 0킬 0죽음으로 다시 스폰, 4분 시작
func start_match() -> void:
	if net and net.on:  # 결과 화면 '한 판 더' (HTML againBtn)
		if net.is_host:
			net.host_start()
		else:
			menu.toast("방장이 다시 시작하면 자동으로 들어가요")
		return
	get_tree().paused = false
	combat.clear_match_objects()
	hud.clear()
	time_left = GameData.MATCH_TIME
	player.next_cls = GameData.chosen_cls
	player.spectating = false
	for e in combat.ents:
		e.kills = 0
		e.deaths = 0
		e.alive = false
	for e in combat.ents:
		combat.spawn(e)
	_set_state("playing")
	menu.show_screen("")
	hud.banner("전투 시작!", "AI대전 %s · %s · %d킬을 먼저 따내면 승리" % [
		GameData.DIFF[GameData.difficulty].name, GameData.CLASSES[player.cls].name, GameData.KILL_LIMIT])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## HTML startMenuSim: 나는 구경만 하고 봇끼리 싸운다
func _start_menu_sim() -> void:
	combat.clear_match_objects()
	hud.clear()
	player.set_spectating(true)
	for e in combat.ents:
		if e != player:
			e.kills = 0
			e.deaths = 0
			combat.spawn(e)


## HTML goMenu: 메뉴(page: main / class …)로 돌아가며 구경 모드
func go_menu(page: String) -> void:
	if net and net.on:  # 친구대전: '메인 메뉴'·'나가기'는 방을 나감, '병과 다시 고르기'는 대기실 (HTML quitBtn / pickBtn)
		if page == "class":
			go_lobby()
		else:
			net.leave()
		return
	get_tree().paused = false
	_set_state("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_screen("menu")
	if page == "class":
		menu.open_class_page()
	else:
		menu.show_page(page)
	_start_menu_sim()


func pause_game() -> void:
	if state != "playing":
		return
	_set_state("paused")
	combat.stop_hit_stop()
	get_tree().paused = not net.on  # 친구대전은 멈추지 않는다 (나만 손을 놓음)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.open_pause(player.next_cls if player.next_cls != "" else player.cls)


func resume_game() -> void:
	if state != "paused":
		return
	get_tree().paused = false
	_set_state("playing")
	menu.show_screen("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## HTML endMatch: 점수판 순서로 1등을 정하고 결과 화면
func end_match() -> void:
	if state != "playing":
		return
	_set_state("ended")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.open_end(combat.score_rows(), player)


func _set_state(s: String) -> void:
	state = s
	player.input_enabled = s == "playing"
	player.orbit = s == "menu" or s == "ended"  # 메뉴·결과 화면 뒤에선 맵을 빙 도는 카메라
	hud.visible = s == "playing" or s == "paused"
	Sfx.playing = s == "playing"
	if s == "playing":
		Music.set_match(true, player.cls)
	elif s == "menu":
		Music.set_match(false)
	if s == "menu" or s == "ended":  # 경기가 끝나면 무적 곡은 바로 원래 곡으로
		Music.end_override(0.0)
		if player.star_t > 0:
			combat.end_star(player)
	if s != "playing":
		combat.stop_hit_stop()
	if s != "playing":
		hud.show_board = false


func _on_killed(v: PlayerController, a: PlayerController, kind: String, head: bool) -> void:
	hud.killfeed(a, v, kind, head)
	if v == player:
		hud.show_death(a, kind, head)
	if not net.on and a and a != v and a.kills >= GameData.KILL_LIMIT and state == "playing":
		end_match()  # 친구대전은 방장이 끝낸다


func _process(dt: float) -> void:
	_check_web_lock()
	if net.on:
		if (state == "playing" or state == "paused") and not net.is_host:  # 방장 시계에 맞춰가며 줄임
			time_left = maxf(0.0, time_left - dt / maxf(Engine.time_scale, 0.01))
		_lobby_t -= dt
		if _lobby_t <= 0:
			_lobby_t = 0.5
			_render_lobby()
	elif state == "playing":
		time_left -= dt / maxf(Engine.time_scale, 0.01)  # 히트스톱 중에도 시계는 실제 시간대로
		if time_left <= 0:
			time_left = 0.0
			end_match()
	hud.time_left = time_left


func _setup_environment() -> void:
	var sky := GameData.col(GameData.C.sky)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	# Three.js HemisphereLight(하늘 eaf6ff / 땅 5d8a45, 0.82) 를 단색 환경광으로 근사
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = GameData.col(0xc8dccc)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = sky
	env.fog_density = 1.0
	env.fog_depth_begin = 75.0
	env.fog_depth_end = 190.0
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = GameData.col(0xfff0d2)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 130.0
	sun.shadow_bias = 0.04
	add_child(sun)
	sun.look_at_from_position(Vector3(35, 70, 22), Vector3.ZERO)


## 웹에선 Esc를 브라우저가 먼저 가져가 마우스 잠금만 풀린다 → 잠금이 풀리면 일시정지 (HTML pointerlockchange)
func _check_web_lock() -> void:
	if not OS.has_feature("web"):
		return
	var locked := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_locked and not locked and state == "playing":
		pause_game()
	_was_locked = locked


func _unhandled_input(event: InputEvent) -> void:
	if state != "playing":
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # HTML: 화면을 누르면 다시 마우스 잠금
		return
	if event.is_action_pressed("ui_cancel"):  # HTML: 마우스 잠금이 풀리면 일시정지
		get_viewport().set_input_as_handled()
		pause_game()
	elif event.is_action_pressed("scoreboard"):
		hud.show_board = true
	elif event.is_action_released("scoreboard"):
		hud.show_board = false


## 창이 포커스를 잃으면 일시정지 (HTML: 포인터 잠금이 풀리면 pauseGame, blur면 키 떼기)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing" and not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
		pause_game()
