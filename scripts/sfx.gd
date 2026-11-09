extends Node
## 효과음 — HTML의 WebAudio 합성(tone·noise)을 그대로 PCM으로 구워서 튼다 (오토로드 Sfx).
## 소리 파일 없이 발진기(사인·사각·톱니·삼각)와 필터 건 잡음으로 만든다.
## 처음엔 한 프레임에 하나씩 미리 구워두고, 아직 안 구운 걸 부르면 그 자리에서 굽는다.
## 위치가 있는 소리는 경기 중일 때만 나고 거리에 따라 작아진다 (HTML vol(): 1/(1+거리/9)).
## 헤드리스(자동 테스트)에선 아무것도 안 한다.

const RATE := 22050

## 소리 이름 → 층 목록. 층마다 시작 지연(초, HTML setTimeout)이 있다.
##   ["t", 주파수, 길이, 파형, 크기, 주파수변화, 지연]  — HTML tone(f,dur,type,vol,slide)
##   ["n", 길이, 크기, 필터주파수, 필터종류, 지연]       — HTML noise(dur,vol,freq,type)
const RECIPES := {
	"throw": [["n", 0.12, 0.18, 1400, "bandpass", 0.0]],
	"bow": [["t", 260, 0.14, "triangle", 0.2, -140, 0.0], ["n", 0.07, 0.12, 3200, "highpass", 0.0], ["t", 110, 0.22, "triangle", 0.15, -40, 0.0]],
	"xbow": [["t", 150, 0.1, "square", 0.12, -70, 0.0], ["n", 0.14, 0.25, 1900, "lowpass", 0.0], ["t", 68, 0.2, "sine", 0.38, -28, 0.0], ["n", 0.05, 0.22, 900, "bandpass", 0.0]],
	"sniper": [["n", 0.7, 0.8, 800, "lowpass", 0.0], ["t", 55, 0.5, "sine", 0.6, -25, 0.0]],
	"ak": [["n", 0.08, 0.4, 2600, "lowpass", 0.0], ["t", 130, 0.06, "square", 0.1, -70, 0.0], ["n", 0.16, 0.16, 520, "lowpass", 0.0]],
	"thunk": [["n", 0.09, 0.2, 650, "lowpass", 0.0]],
	"trip": [["t", 520, 0.32, "triangle", 0.22, -380, 0.0], ["n", 0.12, 0.3, 600, "lowpass", 0.0]],
	"glass": [["n", 0.25, 0.35, 4200, "highpass", 0.0], ["t", 1800, 0.12, "triangle", 0.12, 600, 0.0], ["t", 2600, 0.1, "sine", 0.08, -400, 0.0]],
	"sizzle": [["n", 0.14, 0.1, 2800, "highpass", 0.0]],
	"thud": [["n", 0.11, 0.32, 850, "lowpass", 0.0], ["t", 165, 0.11, "sine", 0.25, -70, 0.0]],
	"thud_heavy": [["n", 0.2, 0.5, 520, "lowpass", 0.0], ["t", 105, 0.2, "sine", 0.4, -70, 0.0]],
	"hit": [["t", 900, 0.06, "square", 0.07, 0, 0.0]],
	"head": [["t", 1300, 0.08, "square", 0.08, 0, 0.0], ["t", 650, 0.08, "triangle", 0.08, 0, 0.0]],
	"kill": [["t", 660, 0.08, "square", 0.09, 0, 0.0], ["t", 990, 0.14, "square", 0.09, 0, 0.07]],
	"hurt": [["t", 170, 0.16, "sawtooth", 0.12, -70, 0.0]],
	"pickup": [["t", 520, 0.1, "triangle", 0.16, 0, 0.0], ["t", 780, 0.16, "triangle", 0.16, 0, 0.09]],
	"bell": [["t", 784, 0.9, "sine", 0.18, 0, 0.0], ["t", 1046, 1.1, "sine", 0.14, 0, 0.16]],
	"slide": [["n", 0.32, 0.09, 900, "bandpass", 0.0]],
	"reload": [["n", 0.06, 0.14, 2600, "bandpass", 0.0], ["t", 1200, 0.05, "square", 0.05, -500, 0.0]],
	"ratchet": [["n", 0.035, 0.1, 3400, "bandpass", 0.0], ["t", 760, 0.03, "square", 0.035, -200, 0.0]],
	"strain": [["t", 150, 0.22, "sawtooth", 0.05, 40, 0.0], ["n", 0.2, 0.05, 500, "lowpass", 0.0]],
	"seat": [["n", 0.07, 0.16, 1300, "bandpass", 0.0]],
	"clang": [["t", 1450, 0.25, "square", 0.08, -300, 0.0], ["t", 2150, 0.3, "triangle", 0.08, -500, 0.0], ["n", 0.08, 0.2, 3000, "highpass", 0.0]],
	"cluck": [["t", 720, 0.07, "square", 0.06, 220, 0.0], ["t", 540, 0.1, "square", 0.05, -160, 0.085]],
	"slip": [["t", 300, 0.25, "sawtooth", 0.08, -180, 0.0]],
	"neigh": [["t", 620, 0.18, "sawtooth", 0.1, 300, 0.0], ["t", 900, 0.35, "sawtooth", 0.09, -450, 0.15], ["t", 500, 0.2, "sawtooth", 0.06, -200, 0.48]],
	"hoof": [["n", 0.05, 0.22, 420, "lowpass", 0.0], ["n", 0.04, 0.16, 520, "lowpass", 0.07]],
	"jump": [["n", 0.05, 0.03, 500, "lowpass", 0.0]],
	# 음유시인 (4.5단계). 연주 멜로디는 TrumpetVoice가 실시간으로 만든다
	"squeak": [["t", 1500, 0.08, "sawtooth", 0.12, 1100, 0.0], ["t", 2700, 0.14, "square", 0.07, -1500, 0.07]],  # 삑사리: 높게 삑 하고 꺾임
	"fanfare": [["t", 523, 0.11, "sawtooth", 0.16, 0, 0.0], ["t", 659, 0.11, "sawtooth", 0.16, 0, 0.11],
		["t", 784, 0.34, "sawtooth", 0.2, 0, 0.22], ["n", 0.12, 0.08, 1800, "bandpass", 0.0]],  # 빠바밤: 3음 상승
	"gasp": [["n", 0.32, 0.12, 1200, "bandpass", 0.0], ["n", 0.28, 0.08, 900, "bandpass", 0.42]],  # 헐떡임
}

var enabled := true          # 헤드리스면 꺼짐
var playing := false         # 경기 중일 때만 위치 있는 소리가 난다 (Main이 정함)
var listener: Node3D = null  # 거리 기준 (살아 있으면 내 캐릭터, 죽었으면 카메라)
var listener_cam: Node3D = null
var played: Array[String] = []  # 자동 테스트용 — 마지막에 낸 소리 이름들 (헤드리스에서도 쌓임)

var _cache := {}
var _pending: Array = []
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		set_process(false)
		return
	for i in 32:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_pending = RECIPES.keys()


func _process(_dt: float) -> void:  # 한 프레임에 하나씩 미리 굽기
	if _pending.is_empty():
		set_process(false)
		return
	_stream(_pending.pop_back())


## pos에서 난 소리가 들리는 크기 (경기 중이 아니면 0) — HTML vol(): 1/(1+거리/9)
func vol_at(pos: Vector3) -> float:
	if not playing:
		return 0.0
	var from: Vector3 = Vector3.ZERO
	if listener and listener.get("alive"):
		from = listener.global_position
	elif listener_cam:
		from = listener_cam.global_position
	return 1.0 / (1.0 + pos.distance_to(from) / 9.0)


## 소리 내기. pos가 있으면 거리에 따라 작아지고, 경기 중이 아니면 안 난다.
func play(sound: String, pos: Variant = null) -> void:
	var v := 1.0
	if pos != null:
		if not playing:
			return
		v = vol_at(pos)
	played.append(sound)
	if played.size() > 64:
		played.pop_front()
	if not enabled or v * GameData.SFX_VOL < 0.01:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _stream(sound)
	p.volume_db = linear_to_db(v * GameData.SFX_VOL)
	p.play()


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
