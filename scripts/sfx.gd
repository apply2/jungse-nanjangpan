extends Node
## 효과음 (오토로드 Sfx). 소리는 두 가지:
##   FILES   — 사용자가 만든 소리 파일 (audio/sfx/, 앞뒤 무음 자르고 크기 맞춤). 여러 개면 무작위(같은 걸 연달아 안 고름),
##             칠 때마다 음높이를 ±GameData.PITCH_JITTER 흔든다 (SFX_NO_JITTER는 안 흔듦, SFX_PITCH가 있으면 곱함).
##   RECIPES — HTML의 WebAudio 합성(tone·noise)을 PCM으로 구운 소리. FILES에 없는 이름만.
## 처음엔 한 프레임에 하나씩 미리 굽고·불러 두고, 아직 안 된 걸 부르면 그 자리에서 굽거나 load()한다.
## 크기 = vol_at(위치) × GameData.SFX_GAIN[이름] × SFX_VOL. 위치가 있는 소리는 경기 중일 때만 나고 거리에 따라 작아진다 (HTML vol(): 1/(1+거리/9)).
## play()는 번호를 돌려주고 stop(번호)로 끌 수 있다 (활 당기기). 플레이어 32개 중 쉬는 것부터, 다 바쁘면 가장 오래된 것.
## 반복 소리(말 다그닥): loop(owner, 이름, 위치, 음높이)를 매 물리 프레임 부른다. 안 부르면 저절로 꺼진다.
## 헤드리스(자동 테스트)에선 소리를 안 내고 played에 이름만 쌓는다.

const RATE := 22050
const DIR := "res://audio/sfx/"

## 소리 이름 → 파일 목록 (여러 개면 무작위)
const FILES := {
	"throw": [DIR + "stone_whoosh.ogg"],
	"bow": [DIR + "stone_whoosh.ogg"],  # 사용자 요청: 화살 날아가는 소리 = 돌 날아가는 소리
	"bow_draw": [DIR + "bow_draw.ogg"],
	"thunk": [DIR + "arrow_thunk.ogg"],
	"xbow": [DIR + "xbow.ogg"],
	"xbow_crank": [DIR + "xbow_crank.ogg"],
	"xbow_latch": [DIR + "xbow_latch.ogg"],
	"holy_throw": [DIR + "holy_throw.ogg"],
	"glass": [DIR + "glass_0.ogg", DIR + "glass_1.ogg"],
	"ak": [DIR + "ak.ogg"],
	"sniper": [DIR + "sniper.ogg"],
	"thud_heavy": [DIR + "body_hit.ogg"],
	"thud": [DIR + "body_hit.ogg"],  # 작게·높게 (SFX_GAIN·SFX_PITCH)
	"clang": [DIR + "clang.ogg"],
	"squeak": [DIR + "squeak.ogg"],
	"fanfare": [DIR + "fanfare.ogg"],
	"gasp": [DIR + "gasp.ogg"],
	"cluck": [DIR + "cluck.ogg"],
	"horn": [DIR + "horn.ogg"],
	"nyam": [DIR + "nyam.ogg"],
	"neigh": [DIR + "neigh.ogg"],
	"gallop": [DIR + "gallop_loop.ogg"],  # 반복 (loop)
}

## 합성 소리: 이름 → 층 목록. 층마다 시작 지연(초, HTML setTimeout)이 있다.
##   ["t", 주파수, 길이, 파형, 크기, 주파수변화, 지연]  — HTML tone(f,dur,type,vol,slide)
##   ["n", 길이, 크기, 필터주파수, 필터종류, 지연]       — HTML noise(dur,vol,freq,type)
const RECIPES := {
	"trip": [["t", 520, 0.32, "triangle", 0.22, -380, 0.0], ["n", 0.12, 0.3, 600, "lowpass", 0.0]],
	"sizzle": [["n", 0.14, 0.1, 2800, "highpass", 0.0]],
	"hit": [["t", 900, 0.06, "square", 0.07, 0, 0.0]],
	"head": [["t", 1300, 0.08, "square", 0.08, 0, 0.0], ["t", 650, 0.08, "triangle", 0.08, 0, 0.0]],
	"kill": [["t", 660, 0.08, "square", 0.09, 0, 0.0], ["t", 990, 0.14, "square", 0.09, 0, 0.07]],
	"hurt": [["t", 170, 0.16, "sawtooth", 0.12, -70, 0.0]],
	"pickup": [["t", 520, 0.1, "triangle", 0.16, 0, 0.0], ["t", 780, 0.16, "triangle", 0.16, 0, 0.09]],
	"chime": [["t", 1568, 0.3, "sine", 0.12, 0, 0.0], ["t", 2093, 0.3, "sine", 0.1, 0, 0.07], ["t", 2637, 0.5, "sine", 0.09, 0, 0.14]],  # 반짝 차임
	"bell": [["t", 784, 0.9, "sine", 0.18, 0, 0.0], ["t", 1046, 1.1, "sine", 0.14, 0, 0.16]],
	"slide": [["n", 0.32, 0.09, 900, "bandpass", 0.0]],
	"reload": [["n", 0.06, 0.14, 2600, "bandpass", 0.0], ["t", 1200, 0.05, "square", 0.05, -500, 0.0]],  # 성수 한 병 참
	"seat": [["n", 0.07, 0.16, 1300, "bandpass", 0.0]],  # 석궁 볼트 끼우기
	# 석궁 휠 한 칸 '끼릭' (자리만 — audio/sfx/xbow_click.ogg를 넣고 FILES에 "xbow_click"을 더하면 파일로 바뀜. 그땐 여기서 지울 것)
	"xbow_click": [["n", 0.035, 0.12, 3400, "bandpass", 0.0], ["t", 760, 0.03, "square", 0.04, -200, 0.0]],
	"slip": [["t", 300, 0.25, "sawtooth", 0.08, -180, 0.0]],
	"bow_full": [["t", 1760, 0.06, "triangle", 0.1, 0, 0.0], ["t", 2349, 0.09, "triangle", 0.09, 0, 0.05]],  # 활 끝까지 당김 (내 화면만)
	"jump": [["n", 0.05, 0.03, 500, "lowpass", 0.0]],
	# 병과 선택 '합격' 도장 쾅 (나무 책상에 찍는 둔탁한 소리 + 종이 탁)
	"stamp": [["n", 0.07, 0.42, 620, "lowpass", 0.0], ["t", 120, 0.13, "sine", 0.4, -60, 0.0], ["n", 0.03, 0.16, 2600, "bandpass", 0.01]],
}

var enabled := true          # 헤드리스면 꺼짐
var playing := false         # 경기 중일 때만 위치 있는 소리가 난다 (Main이 정함)
var listener: Node3D = null  # 거리 기준 (살아 있으면 내 캐릭터, 죽었으면 카메라)
var listener_cam: Node3D = null
var played: Array[String] = []  # 자동 테스트용 — 마지막에 낸 소리 이름들 (헤드리스에서도 쌓임)

signal stinger_done(sound: String)  # 결과 화면 효과음이 끝까지 나왔을 때
var last_stinger := ""      # 마지막 결과 효과음 이름 (헤드리스에서도 남음)
var _stinger: AudioStreamPlayer = null

var _cache := {}            # 합성 이름 또는 파일 경로 → AudioStream
var _pending: Array = []    # 미리 굽거나 불러 둘 것
var _pool: Array[AudioStreamPlayer] = []
var _sid := 0               # play()가 돌려주는 번호
var _last_pick := {}        # 이름 → 지난번에 고른 파일 번호
var _loops := {}            # owner 인스턴스 id → {p, sound, frame}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	for i in 32:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_pending = RECIPES.keys()
	for paths: Array in FILES.values():
		for path: String in paths:
			if not _pending.has(path):
				_pending.append(path)


func _process(_dt: float) -> void:
	if not _pending.is_empty():  # 한 프레임에 하나씩 미리 굽기·불러오기
		var k: String = _pending.pop_back()
		if k.begins_with("res://"):
			_file(k)
		else:
			_stream(k)
	_update_loops()


## pos에서 난 소리가 들리는 크기 (경기 중이 아니면 0). 수치는 GameData.SFX_DIST (사용자 요청 — HTML 1/(1+거리/9)보다 거리에 따라 더 줄어듦)
##   1 / (1 + (거리/ref)^rolloff), fade_from~max에서 0까지. 내 캐릭터 자리(self_r 안)가 아니면 남의 소리라 × others
func vol_at(pos: Vector3) -> float:
	if not playing:
		return 0.0
	var D: Dictionary = GameData.SFX_DIST
	var from: Vector3 = Vector3.ZERO
	var alive := false
	if listener and listener.get("alive"):
		from = listener.global_position
		alive = true
	elif listener_cam:
		from = listener_cam.global_position
	var d := pos.distance_to(from)
	if alive and d < float(D.self_r):  # 내 소리
		return 1.0
	var v := 1.0 / (1.0 + pow(d / float(D.ref), float(D.rolloff)))
	var f0 := float(D.fade_from)
	if d > f0:
		v *= clampf((float(D.max) - d) / (float(D.max) - f0), 0.0, 1.0)
	return v * float(D.others)


## 결과 화면 효과음 (GameData.STINGER, 반복 없음). 전용 플레이어 하나 — Sfx.playing과 상관없이 나고 일시정지 중에도 돈다.
## 헤드리스에선 아무것도 안 한다 (테스트용으로 이름만 last_stinger에 남김). 다 끝나면 stinger_done.
func play_stinger(sound: String) -> void:
	last_stinger = sound
	if not enabled:
		return
	if not GameData.STINGER.has(sound):
		push_warning("결과 효과음 없음: " + sound)
		return
	if _stinger == null:
		_stinger = AudioStreamPlayer.new()
		_stinger.bus = "SFX"
		_stinger.process_mode = Node.PROCESS_MODE_ALWAYS
		_stinger.finished.connect(func() -> void: stinger_done.emit(last_stinger))
		add_child(_stinger)
	var s: AudioStream = load(GameData.STINGER[sound])
	if "loop" in s:
		s.set("loop", false)
	_stinger.stream = s
	_stinger.volume_db = linear_to_db(GameData.SFX_VOL)
	_stinger.play()


func stop_stinger() -> void:
	if _stinger and _stinger.playing:
		_stinger.stop()


## 소리 내기. pos가 있으면 거리에 따라 작아지고, 경기 중이 아니면 안 난다.
## 돌려주는 값 = 이 소리 번호 (stop()에 씀, 안 났으면 0)
func play(sound: String, pos: Variant = null) -> int:
	var v := 1.0
	if pos != null:
		if not playing:
			return 0
		v = vol_at(pos)
	played.append(sound)
	if played.size() > 64:
		played.pop_front()
	var vol := v * float(GameData.SFX_GAIN.get(sound, 1.0)) * GameData.SFX_VOL
	if not enabled or vol < 0.01:
		return 0
	var p := _free_player()
	if FILES.has(sound):
		p.stream = _file(_pick(sound))
		p.pitch_scale = _pitch(sound)
	else:
		p.stream = _stream(sound)
		p.pitch_scale = 1.0
	p.volume_db = linear_to_db(vol)
	p.play()
	_sid += 1
	p.set_meta("sid", _sid)
	return _sid


## play()가 돌려준 번호의 소리가 아직 나고 있으면 끈다 (그 플레이어가 다른 소리를 내고 있으면 안 건드림)
func stop(sid: int) -> void:
	if sid <= 0:
		return
	for p in _pool:
		if int(p.get_meta("sid", 0)) == sid:
			if p.playing:
				p.stop()
			p.set_meta("sid", 0)
			return


## 반복 소리 (말 다그닥). 매 물리 프레임 부른다 — 처음이면 owner 전용 플레이어를 만들어 틀고, 있으면 크기·음높이만 갱신.
## 이번 프레임에 안 불린 반복 소리는 다음 _process에서 저절로 꺼진다.
func loop(owner: Object, sound: String, pos: Vector3, pitch: float = 1.0) -> void:
	if not playing:
		return
	var key := owner.get_instance_id()
	var L: Dictionary = _loops.get(key, {})
	if L.is_empty() or L.sound != sound:
		if not L.is_empty():
			loop_stop(owner)
		played.append(sound)  # 시작할 때 한 번만
		if played.size() > 64:
			played.pop_front()
		L = {"p": null, "sound": sound}
		if enabled:
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			var s: AudioStream = _file(_pick(sound))
			if "loop" in s:
				s.set("loop", true)
			p.stream = s
			add_child(p)
			L.p = p
		_loops[key] = L
	L.frame = Engine.get_physics_frames()
	var p: AudioStreamPlayer = L.p
	if p:
		var vol := vol_at(pos) * float(GameData.SFX_GAIN.get(sound, 1.0)) * GameData.SFX_VOL
		p.volume_db = linear_to_db(maxf(vol, 0.0001))
		p.pitch_scale = maxf(0.01, pitch * float(GameData.SFX_PITCH.get(sound, 1.0)))
		if not p.playing:
			p.play()


## owner의 반복 소리를 끄고 지운다
func loop_stop(owner: Object) -> void:
	var key := owner.get_instance_id()
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key].p
	if p:
		p.stop()
		p.queue_free()
	_loops.erase(key)


## 반복 소리 정리: 경기 중이 아니면 다 끄고, 일시정지면 멈췄다 이어서, 이번 물리 프레임에 안 불린 건 끈다
func _update_loops() -> void:
	if _loops.is_empty():
		return
	var now := Engine.get_physics_frames()
	var paused := get_tree().paused
	for key: int in _loops.keys():
		var L: Dictionary = _loops[key]
		var p: AudioStreamPlayer = L.p
		if not playing or (not paused and now - int(L.frame) > 2):
			if p:
				p.stop()
				p.queue_free()
			_loops.erase(key)
			continue
		if paused:
			L.frame = now  # 일시정지 동안엔 안 불려도 그대로 둠
		if p:
			p.stream_paused = paused


## 쉬는 플레이어부터, 다 바쁘면 가장 오래된 것
func _free_player() -> AudioStreamPlayer:
	var best: AudioStreamPlayer = _pool[0]
	var best_sid := 1 << 62
	for p in _pool:
		if not p.playing:
			return p
		var s := int(p.get_meta("sid", 0))
		if s < best_sid:
			best_sid = s
			best = p
	return best


## 파일 고르기 — 여러 개면 무작위, 지난번과 같은 건 연달아 안 고름
func _pick(sound: String) -> String:
	var list: Array = FILES[sound]
	if list.size() == 1:
		return list[0]
	var last: int = _last_pick.get(sound, -1)
	var i := randi() % list.size()
	if i == last:
		i = (i + 1 + randi() % (list.size() - 1)) % list.size()
	_last_pick[sound] = i
	return list[i]


## 파일 소리 음높이: SFX_PITCH × (1 ± PITCH_JITTER). 음악(SFX_NO_JITTER)은 안 흔듦
func _pitch(sound: String) -> float:
	var k := float(GameData.SFX_PITCH.get(sound, 1.0))
	if not GameData.SFX_NO_JITTER.has(sound):
		k *= 1.0 + randf_range(-GameData.PITCH_JITTER, GameData.PITCH_JITTER)
	return k


func _file(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


func _stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = render(RECIPES[sound])
	return _cache[sound]


## 층들을 한 버퍼에 더해 16비트 WAV로 만든다
static func render(layers: Array) -> AudioStreamWAV:
	var total := 0.0
	for L: Array in layers:
		var dur: float = L[2] if L[0] == "t" else L[1]
		total = maxf(total, float(L[-1]) + dur + 0.02)
	var n := int(total * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	for L: Array in layers:
		if L[0] == "t":
			_tone(buf, float(L[1]), float(L[2]), L[3], float(L[4]), float(L[5]), float(L[6]))
		else:
			_noise(buf, float(L[1]), float(L[2]), float(L[3]), L[4], float(L[5]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## 크기 vol에서 0.0001까지 지수로 줄어드는 소리 크기 (WebAudio exponentialRampToValueAtTime)
static func _env(vol: float, t: float, dur: float) -> float:
	return vol * pow(0.0001 / vol, t / dur) if t < dur else 0.0


## 발진기: 주파수가 f에서 f+slide로 곧게 바뀐다 (linearRampToValueAtTime)
static func _tone(buf: PackedFloat32Array, f: float, dur: float, type: String, vol: float, slide: float, delay: float) -> void:
	var f1 := maxf(20.0, f + slide)
	var i0 := int(delay * RATE)
	var cnt := int((dur + 0.02) * RATE)
	var ph := 0.0
	for i in cnt:
		var j := i0 + i
		if j >= buf.size():
			break
		var t := float(i) / RATE
		var fr := f + (f1 - f) * minf(t / dur, 1.0)
		ph = fmod(ph + fr / RATE, 1.0)
		var s := 0.0
		match type:
			"sine":
				s = sin(TAU * ph)
			"square":
				s = 1.0 if ph < 0.5 else -1.0
			"sawtooth":
				s = 2.0 * ph - 1.0
			_:  # triangle
				s = 1.0 - 4.0 * absf(ph - 0.5)
		buf[j] += s * _env(vol, t, dur)


## 잡음 + 2차 필터 (WebAudio BiquadFilter: lowpass·highpass는 Q=1dB, bandpass는 Q=1)
static func _noise(buf: PackedFloat32Array, dur: float, vol: float, freq: float, type: String, delay: float) -> void:
	var w0 := TAU * minf(freq, RATE * 0.45) / RATE
	var cw := cos(w0)
	var q := 1.0 if type == "bandpass" else pow(10.0, 1.0 / 20.0)
	var alpha := sin(w0) / (2.0 * q)
	var b0: float
	var b1: float
	var b2: float
	match type:
		"highpass":
			b0 = (1 + cw) / 2
			b1 = -(1 + cw)
			b2 = (1 + cw) / 2
		"bandpass":
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
		_:
			b0 = (1 - cw) / 2
			b1 = 1 - cw
			b2 = (1 - cw) / 2
	var a0 := 1 + alpha
	var a1 := -2 * cw
	var a2 := 1 - alpha
	b0 /= a0
	b1 /= a0
	b2 /= a0
	a1 /= a0
	a2 /= a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var i0 := int(delay * RATE)
	var cnt := int((dur + 0.02) * RATE)
	for i in cnt:
		var j := i0 + i
		if j >= buf.size():
			break
		var x := randf() * 2.0 - 1.0
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[j] += y * _env(vol, float(i) / RATE, dur)
