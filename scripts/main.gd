extends Node3D
## 게임 진입점 — 조명·하늘·안개, 캐릭터 만들기, 경기 흐름(HTML startMatch / endMatch / startMenuSim /
## pauseGame / resumeGame / goMenu), 마우스 잠금.
## 상태: menu(메뉴 뒤에서 봇끼리 싸움) → playing → paused / ended.
## 일시정지는 SceneTree.paused로 월드·캐릭터·Combat을 멈춘다. Main·HUD·메뉴는 계속 돈다.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var world: WorldBuilder = $World
@onready var combat: Combat = $Combat
@onready var player: PlayerController = $Player
@onready var hud: Hud = $HUD

var menu: Menu
var state := "menu"
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
	menu.next_class_picked.connect(func(k: String) -> void: player.next_cls = k)
	combat.register(player)
	_spawn_bots()
	go_menu("main")


## 봇 BOT_COUNT명. 이름은 섞어서, 병과는 무작위 (HTML pickBotClass). 스폰은 startMenuSim / startMatch가 한다.
func _spawn_bots() -> void:
	var names: Array = GameData.BOT_NAMES.duplicate()
	names.shuffle()
	for i in GameData.BOT_COUNT:
		var b: PlayerController = PLAYER_SCENE.instantiate()
		b.is_local = false
		b.is_bot = true
		b.ent_name = names[i % names.size()]
		b.cls = GameData.CLASS_ORDER[randi() % GameData.CLASS_ORDER.size()]
		b.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(b)
		b.alive = false
		combat.register(b)


# ── 경기 흐름 ────────────────────────────────────────────────
## HTML startMatch: 다 치우고, 모두 0킬 0죽음으로 다시 스폰, 4분 시작
func start_match() -> void:
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
	get_tree().paused = true
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
	if s != "playing":
		combat.stop_hit_stop()
	if s != "playing":
		hud.show_board = false


func _on_killed(v: PlayerController, a: PlayerController, kind: String, head: bool) -> void:
	hud.killfeed(a, v, kind, head)
	if v == player:
		hud.show_death(a, kind, head)
	if a and a != v and a.kills >= GameData.KILL_LIMIT and state == "playing":
		end_match()


func _process(dt: float) -> void:
	if state == "playing":
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
