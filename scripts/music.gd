extends Node
## 배경음악 (오토로드 Music) — HTML엔 없음, 사용자 요청으로 추가.
## AudioStreamPlayer 두 개를 번갈아 쓰며 크로스페이드한다. 둘 다 "Music" 버스.
## 곡 목록은 GameData.BGM, 페이드 시간은 GameData.MUSIC.
##
## 곡 고르기 (track_for):
##   경기 중이면 내 병과가 음유시인 → "match_bard", 아니면 "match". 메뉴면 "menu".
##   내 캐릭터(Main.player)의 class_changed 신호와 Main._set_state가 알려 준다 — 친구대전에서도 내 병과 기준.
## 같은 파일이 이미 나오고 있으면 다시 시작하지 않는다 (키가 달라도 파일이 같으면 그대로 이어서).
## 오토로드라 씬이 바뀌어도 끊기지 않는다. 일시정지 중에도 돈다.
## 웹: 브라우저는 클릭 전엔 소리를 막으니, 첫 클릭(또는 키) 뒤에 재생을 시작한다.

var key := ""          # 지금 고른 곡 (BGM 키). 멈췄으면 ""
var in_match := false  # 경기 중인가 (Main이 알려 줌)
var cls := ""          # 내 병과 (class_changed로 받음)

var _p: Array[AudioStreamPlayer] = []
var _gain := [0.0, 0.0]    # 0~1, 페이드용 (볼륨은 버스가 따로 정함)
var _target := [0.0, 0.0]
var _rate := [1.0, 1.0]    # 초당 gain 변화량
var _paths := ["", ""]     # 플레이어마다 걸린 파일
var _active := 0           # 지금 커지고 있는(또는 다 커진) 쪽
var _unlocked := true      # 웹: 첫 입력 전엔 false
var _pending := ""         # 웹: 잠금이 풀리면 틀 곡


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus := "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = linear_to_db(0.0001)
		add_child(p)
		_p.append(p)
	_unlocked = not OS.has_feature("web")
	set_process_input(not _unlocked)
	play_bgm("menu", GameData.MUSIC.start_fade)  # 게임 켜면 1초 페이드인


## 병과·경기 여부 → BGM 키 (순수 계산 — 테스트용)
static func track_for(c: String, match: bool) -> String:
	if not match:
		return "menu"
	var bard: String = GameData.MUSIC.bard_cls
	if c == bard and GameData.CLASSES.has(bard) and GameData.BGM.has("match_bard"):
		return "match_bard"
	return "match"


## 내 캐릭터의 class_changed 신호 (리스폰 때 병과가 바뀌면)
func on_class_changed(c: String) -> void:
	cls = c
	_pick()


## Main._set_state: 경기 시작(true) / 메뉴로(false)
func set_match(on: bool, c := "") -> void:
	in_match = on
	if c != "":
		cls = c
	_pick()


func _pick() -> void:
	play_bgm(track_for(cls, in_match), GameData.MUSIC.fade)


## 곡 틀기 (크로스페이드 fade_sec초). 같은 파일이 나오고 있으면 그대로 둔다.
func play_bgm(k: String, fade_sec := 1.5) -> void:
	if not GameData.BGM.has(k):
		push_warning("BGM 키 없음: " + k)
		return
	key = k
	if not _unlocked:
		_pending = k
		return
	var path: String = GameData.BGM[k]
	if _paths[_active] == path and _p[_active].playing:
		_fade(_active, 1.0, fade_sec)  # 같은 곡 — 멈추는 중이었으면 다시 키우기만
		return
	var nxt := 1 - _active
	if not (_paths[nxt] == path and _p[nxt].playing):  # 막 빠지던 곡이면 그 자리에서 되살림
		var s: AudioStream = load(path)
		if "loop" in s:
			s.set("loop", true)  # 끝과 처음이 이어지게 만든 루프 음원
		_p[nxt].stream = s
		_paths[nxt] = path
		_gain[nxt] = 0.0
		_p[nxt].play()
	_fade(nxt, 1.0, fade_sec)
	_fade(_active, 0.0, fade_sec)
	_active = nxt


## 음악 멈추기 (fade_sec초 동안 작아짐)
func stop_bgm(fade_sec := 1.0) -> void:
	key = ""
	_pending = ""
	for i in 2:
		_fade(i, 0.0, fade_sec)


## 지금 실제로 크게 나오고 있는 파일 (테스트용)
func current_path() -> String:
	return _paths[_active] if _target[_active] > 0 else ""


func _fade(i: int, to: float, sec: float) -> void:
	_target[i] = to
	_rate[i] = absf(to - float(_gain[i])) / sec if sec > 0 else INF


func _process(dt: float) -> void:
	for i in 2:
		var g: float = move_toward(_gain[i], _target[i], _rate[i] * dt)
		_gain[i] = g
		_p[i].volume_db = linear_to_db(maxf(g, 0.0001))
		if g <= 0.0 and _target[i] <= 0.0 and _p[i].playing:
			_p[i].stop()
			_paths[i] = ""


## 웹: 첫 클릭·키 입력에서 소리 잠금이 풀린다
func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed():
		_unlocked = true
		set_process_input(false)
		if _pending != "":
			var k := _pending
			_pending = ""
			play_bgm(k, GameData.MUSIC.start_fade)
