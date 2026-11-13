class_name PlayerController
extends CharacterBody3D
## 플레이어 이동·카메라 — HTML movement() / trip() / integrate() / updateCamera() 이식.
## 원점(position)은 발바닥. 이동 공식은 Quake식 accelerate/friction을 그대로 썼고,
## 충돌만 Godot 물리(move_and_slide)에 맡긴다. 0.56m 이하 턱은 try_step()이 올려준다.

signal toast(text: String)
signal class_changed(cls: String)  # 병과가 바뀌었다 (Music이 듣고 곡을 고름)

@export var cls := "archer"

# 바라보는 방향
var yaw := 0.0
var pitch := 0.0
# 이동 상태 (HTML 엔티티 필드와 이름을 맞춤)
var grounded := false
var sprinting := false
var crouch := false
var crouch_prev := false
var sliding := false
var slide_t := 0.0
var slide_cd := 0.0
var jumped := false
var fall_t := 0.0
var fall_rx := 0.0
var fall_rz := 0.0
var fall_yaw := 0.0
var trip_cd := 0.0
var fast_t := 0.0
var fast_dir := Vector2.ZERO
var kb_t := 0.0       # 넉백 중 (속도 제한 완화, 넘어짐 판정 정지)
var stagger := 0.0    # 경직 (입력 무시)
var slow_t := 0.0     # 성수 둔화
var charges := 3      # 성수 남은 개수 (HTML charges)
var charge_t := 0.0   # 다음 성수가 차기까지 지난 시간 (HTML chargeT)
var has_chicken := false
# 음유시인 트럼펫 (4.5단계, Trumpet이 관리)
var playing := false      # 연주 중
var breath := 3.0         # 남은 숨 (최대 WEAPONS.trumpet.breath_max)
var gasp_t := 0.0         # 숨이 차서 헐떡이는 남은 시간 (연주 못 함, 느려짐)
var squeak_t := 0.0       # 삑사리 뒤 연주 못 하는 남은 시간
var fan_cd := 0.0         # 팡파레 재사용 대기
# 춤 디버프 (누구나 걸림)
var dance_t := 0.0        # 춤추는 남은 시간
var dance_immune := 0.0   # 춤이 끝난 뒤 다시 안 추는 남은 시간
var dance_log: Array = [] # 원뿔 안에 있었던 기록 [시각, 시간] — 최근 DANCE.window초만 남김
var dance_by: Array = []  # 이번 춤을 건 음유시인들 (춤이 시작될 때 원뿔 안에 들리던 연주자) — "춤춰라!"는 이들만 봄
var dance_sway := 0.0     # 춤 때문에 yaw에 더한 출렁임 (다음 프레임에 빼고 새로 더함)
var tr_ticks := {}        # 트럼펫 피해 주기: 연주자 → 쌓인 시간
var has_sniper := false   # 대물 저격총을 주웠음 (Q로 원래 무기와 바꿈)
var has_ak := false       # AK-47을 주웠음
var ammo := 0             # 저격총 남은 탄
var ak_ammo := 0          # AK 남은 탄
var bloom := 0.0          # AK 연사 퍼짐
var horse := {}           # 타고 있는 말 모양 (WeaponModels.make_horse) — Items가 관리
var ln_t := 0.0           # 마상창에 또 맞기까지 남은 시간
var swap_req := false     # Q를 눌렀음 (Combat이 처리)
var ak_flash := 0.0       # 내 1인칭 AK 총구 불꽃
var hp := 100.0
var alive := true

# 피해·처치 (HTML makeEntity 필드) — Combat이 읽고 쓴다
var ent_name := "나"
var is_local := true   # 내가 조종하는 캐릭터 (카메라·마우스 입력)
var is_bot := false
var is_remote := false  # 친구대전: 친구 컴퓨터가 움직이는 캐릭터 (Net이 받은 상태로 따라감)
var peer := 0           # 친구대전 peer id
var net_s: Array = []   # 마지막으로 받은 상태 (Net._state)
var net_dead_t := 0.0
var ai: BotAI = null    # 봇 머리 (is_bot이면 Combat.register가 만들어 줌)
var combat: Combat = null
var next_cls := ""     # 다음 부활 때 쓸 병과
var _sig_cls := ""     # class_changed를 마지막으로 보낸 병과
var spectating := false  # 메뉴에서 구경 중 (안 살아나고 점수판에도 없음) — HTML spectating
var input_enabled := true  # 나: 경기 중일 때만 키보드·마우스를 읽는다 (메뉴·결과 화면에선 false)
var orbit := false     # 나: 메뉴·결과 화면 뒤에서 맵을 빙 도는 카메라 (HTML updateCamera의 메뉴 부분)
var menu_angle := 0.0
var helmet := true
var invuln := 0.0      # 무적 남은 시간
var team := ""         # 쟁탈전 팀 (blue / red, 개인전은 "")
var cap_time := 0.0     # 쟁탈전: 거점 원 안에 있었던 시간 (점수판)
var star_t := 0.0      # 황금 붕어빵 무적 남은 시간 (피해·넉백·남이 넘어뜨림·둔화·춤 막음)
var star_hits := {}    # 몸박치기: 대상 → 다시 때릴 수 있기까지 남은 시간
var no_hit_t := 0.0    # 마지막으로 맞은 뒤 지난 시간
var regen_acc := 0.0
var respawn := 0.0
var kills := 0
var deaths := 0
var last_hit := {}     # {by, kind, head}
var flash := 0.0       # 맞으면 몸이 하얗게 번쩍
var hit_squash := 0.0  # 맞으면 몸이 찌그러짐
var mounted := 0.0     # 말 탑승 남은 시간
var mount_h := 0.0
var death_pos := Vector3.ZERO
var death_dir := Vector3.FORWARD
var ragdoll: Ragdoll = null   # 죽어서 쓰러진 몸 (죽음 카메라가 본다)

# 무기 (HTML makeEntity 필드) — Combat.weapon_update()가 읽고 쓴다
var wep := "bow"         # 지금 든 무기 키 (GameData.WEAPONS)
var cd := 0.0            # 다음 공격까지 남은 시간
var fire_anim := 0.0     # 쏘면 1 → 0 (팔 모션)
var trig_prev := false   # 지난 프레임에 공격 키를 누르고 있었나
var swap_t := 0.0        # 무기 바꾸는 중
var fire_held := false   # 이번 프레임 공격 키
var aim_held := false    # 이번 프레임 조준(우클릭) 키
# 활 (HTML charge / charging / holdT / swayY·swayP·swT)
var charge := 0.0        # 당긴 시간 (최대 WEAPONS.bow.full)
var charging := false
var hold_t := 0.0        # 끝까지 당긴 채 버틴 시간
var sway_y := 0.0        # 후들거림으로 더한 yaw·pitch (다음 프레임에 빼고 새로 더함)
var sway_p := 0.0
var sw_t := 0.0
var snd_bow := 0         # 활 당기는 소리 번호 (Sfx.play → 놓으면 Sfx.stop)
var bow_release := false # min_charge 전에 놓음 → 거기까지 마저 당기고 쏜다
var cancel_req := false  # R: 당기기 취소 (Combat이 처리)
var draw_block := false  # 취소한 뒤 공격 키를 뗄 때까지 다시 안 당김
var xb_last := 1.0       # 석궁 장전 모션 진행도 (지난 프레임) — 걸쇠·볼트 소리 순간을 지났는지 보려고
# 석궁 휠 장전 (사용자 요청) — Combat._xbow_wind·_xbow_anim
var xb_wind: int = GameData.WEAPONS.crossbow.notches  # 감은 칸 수 (WEAPONS.crossbow.notches면 장전 완료). 친구대전으로 보냄
var xb_show := 1.0       # 장전 모션 진행도 0~1 (xb_wind/notches를 show_rate로 따라감)
var xb_heard: int = GameData.WEAPONS.crossbow.notches  # 끼릭 소리를 낸 칸 수 (친구 것도 칸이 늘면 소리)
var wind_req := 0        # 이번 프레임에 받은 휠 칸 수 (Combat이 가져감)
var wind_t := 0.0        # '감는 중' 남은 시간 (마지막 칸 뒤 reload_window초) — 이동 속도 ×reload_speed
var _wind_ms := -100000  # 마지막으로 받은 휠 칸 시각 (실제 ms) — notch_gap 안에 온 휠은 버림
# 반동 스프링 (HTML rec/recV = 3인칭 몸, vRec/vRecV = 1인칭 화면·손 — 내 캐릭터만 씀)
var rec := 0.0
var rec_v := 0.0
var v_rec := 0.0
var v_rec_v := 0.0
var vm_kick := 0.0       # 1인칭 손이 앞뒤로 튀는 양 (HTML vmKick)

# 카메라
var view_y := 1.55
var tp_dist := 3.6
var shake := 0.0

## 테스트·봇용: 비어 있지 않으면 키보드 대신 이 값을 읽는다
## {"f": -1..1, "r": -1..1, "jump": bool, "crouch": bool, "sprint": bool, "fire": bool(없으면 false)}
var scripted_input := {}

@onready var col: CollisionShape3D = $CollisionShape3D
@onready var cam: Camera3D = $Camera3D
var model: DerpModel


func _ready() -> void:
	col.shape = col.shape.duplicate()  # 앉기 때문에 높이를 바꾸므로 공유하지 않는다
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(46)
	# 캐릭터끼리는 부딪히지 않는다 (HTML도 월드 상자하고만 충돌). 월드=1층, 캐릭터=2층
	collision_layer = 2
	collision_mask = 1
	if is_local:
		cam.top_level = true
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	else:
		cam.queue_free()
		cam = null
		set_process_unhandled_input(false)
	set_class(cls)


func set_class(c: String) -> void:
	var changed := c != _sig_cls
	_sig_cls = c
	cls = c
	next_cls = c
	wep = GameData.CLASSES[c].weapon
	charges = int(GameData.WEAPONS.holy.max_charges)
	charge_t = 0.0
	hp = GameData.class_hp(c)
	helmet = true
	if model:
		model.queue_free()
	model = DerpModel.new(c, team)
	model.top_level = true
	model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(model)
	if is_local and not GameData.HELD_SCALE_SELF.is_empty():  # 내 무기만 다른 배율 (조준점 가림 방지)
		model.set_mine(true)
	if changed:
		class_changed.emit(c)


## HTML spawn()의 상태 초기화 부분. 지점 고르기는 Combat.spawn()이 한다.
func spawn_at(p: Vector3) -> void:
	set_class(next_cls if next_cls != "" else cls)  # 모델을 새로 만든다 (날아간 투구 복구)
	alive = true
	invuln = GameData.INVULN
	global_position = p
	velocity = Vector3.ZERO
	yaw = atan2(p.x, p.z)  # 맵 가운데를 보게
	pitch = 0.0
	fall_t = 0.0
	jumped = false
	sliding = false
	crouch_prev = false
	if crouch:
		crouch = false
		(col.shape as CylinderShape3D).height = 1.75
		col.position.y = 0.875
	kb_t = 0.0
	cd = 0.0
	fire_anim = 0.0
	swap_t = 0.0
	trig_prev = false
	fire_held = false
	aim_held = false
	reset_charge()
	draw_block = false
	cancel_req = false
	var NX := int(GameData.WEAPONS.crossbow.notches)  # 부활하면 장전된 채 (예전 cd = 0과 같음)
	xb_wind = NX
	xb_heard = NX
	xb_show = 1.0
	xb_last = 1.0
	wind_req = 0
	wind_t = 0.0
	rec = 0.0
	rec_v = 0.0
	v_rec = 0.0
	v_rec_v = 0.0
	stagger = 0.0
	slow_t = 0.0
	star_t = 0.0
	star_hits.clear()
	trip_cd = 0.0
	fast_t = 0.0
	has_chicken = false
	has_sniper = false
	has_ak = false
	playing = false
	breath = float(GameData.WEAPONS.trumpet.breath_max)
	gasp_t = 0.0
	squeak_t = 0.0
	fan_cd = 0.0
	dance_t = 0.0
	dance_immune = 0.0
	dance_log.clear()
	dance_sway = 0.0
	tr_ticks.clear()
	ammo = 0
	ak_ammo = 0
	bloom = 0.0
	swap_req = false
	ln_t = 0.0
	if not horse.is_empty():
		(horse.g as Node).queue_free()
		horse = {}
	no_hit_t = 0.0
	regen_acc = 0.0
	ragdoll = null
	last_hit = {}
	flash = 0.0
	hit_squash = 0.0
	mounted = 0.0
	mount_h = 0.0
	view_y = p.y + 1.55
	if ai and combat:
		ai.reset(combat.world.random_point())
	reset_physics_interpolation()


## 죽음 — 몸은 Combat.kill이 래그돌로 바꿔 둔다
func die(dir: Vector3) -> void:
	alive = false
	hp = 0.0
	sliding = false
	death_pos = global_position
	death_dir = dir
	velocity = Vector3.ZERO
	fire_held = false
	charging = false
	playing = false
	dance_t = 0.0
	if model:
		model.visible = false


## 활 당기던 것 풀기 (쏘거나, 넘어지거나, 죽거나, 부활할 때)
func reset_charge() -> void:
	charging = false
	bow_release = false
	Sfx.stop(snd_bow)
	snd_bow = 0
	charge = 0.0
	hold_t = 0.0
	sway_y = 0.0
	sway_p = 0.0
	sw_t = 0.0


# ── 피격 판정 위치 (HTML eyeOf / headC / bodyA / bodyB / lieDir) ──
## 누워 있을 때 머리가 있는 쪽
func lie_dir() -> Vector3:
	var th := fall_yaw
	if fall_rz != 0:
		var sg := -signf(fall_rz)
		return Vector3(cos(th) * sg, 0, -sin(th) * sg)
	var sg2 := signf(fall_rx)
	return Vector3(sin(th) * sg2, 0, cos(th) * sg2)


func eye_pos() -> Vector3:
	return global_position + Vector3(0, mount_h + (1.0 if crouch else 1.55), 0)


func head_c() -> Vector3:
	var p := global_position
	if fall_amt() > 0.5:
		return p + Vector3(0, 0.32, 0) + lie_dir() * 1.4
	return p + Vector3(0, mount_h + (1.1 if crouch else 1.62), 0)


func body_a() -> Vector3:
	var p := global_position
	if fall_amt() > 0.5:
		return p + Vector3(0, 0.35, 0) + lie_dir() * 0.35
	return p + Vector3(0, mount_h + 0.4, 0)


func body_b() -> Vector3:
	var p := global_position
	if fall_amt() > 0.5:
		return p + Vector3(0, 0.35, 0) + lie_dir() * 1.0
	return p + Vector3(0, mount_h + (0.8 if crouch else 1.15), 0)


# ── 입력 ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and alive:
		var s: float = GameData.mouse_sens * 0.0021 * (cam.fov / 85.0)
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, -1.5, 1.5)
	elif event.is_action_pressed("swap"):
		swap_req = true
	elif event.is_action_pressed("cancel_draw"):
		cancel_req = true
	elif event.is_action_pressed("wind") and wep == "crossbow" and alive:  # 석궁일 때만 휠 = 장전
		# 정한 방향(wind_dir, 기본 아래)만 인정. 반대쪽은 여기서 버림 → 간격(_wind_ms)·감속(wind_t)도 안 건드림
		if not (event is InputEventMouseButton and event.button_index == GameData.wind_button()):
			return
		var now := Time.get_ticks_msec()  # 실제 시간으로 간격을 잼 (프레임과 상관없이)
		if now - _wind_ms >= int(float(GameData.WEAPONS.crossbow.notch_gap) * 1000.0):
			_wind_ms = now
			wind_req += 1
	elif event.is_action_pressed("toggle_view"):
		GameData.third_person = not GameData.third_person
		GameData.save_settings()
		toast.emit("3인칭 시점" if GameData.third_person else "1인칭 시점")


func _read_input(dt: float) -> Dictionary:
	if not scripted_input.is_empty():
		return scripted_input
	if ai and combat and GameData.ai_enabled:  # 봇: wish(월드 방향)를 바로 준다
		return ai.update(self, combat, dt)
	if not is_local or not input_enabled:  # 남의 캐릭터가 내 키보드를 읽지 않게 / 메뉴·결과 화면에선 가만히
		return {"f": 0.0, "r": 0.0, "jump": false, "crouch": false, "sprint": false}
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	return {
		"fire": captured and Input.is_action_pressed("fire"),
		"aim": captured and Input.is_action_pressed("aim"),
		"f": Input.get_axis("move_back", "move_forward"),
		"r": Input.get_axis("move_left", "move_right"),
		"jump": Input.is_action_pressed("jump"),
		"crouch": Input.is_action_pressed("crouch"),
		"sprint": Input.is_action_pressed("sprint") and not Input.is_action_pressed("fire") and not Input.is_action_pressed("aim"),
	}


func _physics_process(dt: float) -> void:
	if not alive or is_remote:
		return
	var inp := _read_input(dt)
	fire_held = inp.get("fire", false)  # 무기는 Combat이 이 다음에 처리한다
	if inp.get("swap", false):
		swap_req = true
	if inp.get("cancel", false):
		cancel_req = true
	if inp.get("wind", false):  # 봇·테스트의 휠 한 칸 (봇은 bot_ai가 속도를 정함)
		wind_req += 1
	aim_held = inp.get("aim", false)
	var wish: Vector3
	if inp.has("wish"):  # 봇 (HTML botUpdate: 달리기는 봇이 정함)
		wish = inp.wish
		sprinting = inp.sprint
	else:
		var f: float = inp.f
		var r: float = inp.r
		wish = Vector3(-sin(yaw) * f + cos(yaw) * r, 0, -cos(yaw) * f - sin(yaw) * r)
		if wish.length_squared() > 0:
			wish = wish.normalized()
		sprinting = inp.sprint and f > 0 and not inp.crouch  # 공격·조준하면 달리기 풀림
	movement(wish, inp.jump, inp.crouch, dt)


# ── 이동 (Quake 계열) ────────────────────────────────────────
func max_speed() -> float:
	var sp: float
	if mounted > 0:  # 말 위에선 말 속도 (달리기 없음)
		sp = GameData.HORSE_SPEED
	else:
		var spr := GameData.SPRINT if sprinting else 1.0
		var wm: float = GameData.WEAPONS[wep].get("speed_mul", 1.0)  # 저격총 0.9, AK 0.95
		sp = GameData.BASE_SPEED * GameData.CLASSES[cls].speed * wm * spr
		if wep == "crossbow" and wind_t > 0 and xb_wind < int(GameData.WEAPONS.crossbow.notches):  # 석궁 휠로 감는 중 (사용자 요청)
			sp *= float(GameData.WEAPONS.crossbow.reload_speed)
	if slow_t > 0:
		sp *= GameData.WEAPONS.holy.slow
	if has_chicken:
		sp *= GameData.ITEM.chicken_speed
	if dance_t > 0:  # 춤추는 중
		sp *= GameData.DANCE.speed
	if gasp_t > 0:  # 숨이 차서 헐떡임
		sp *= GameData.WEAPONS.trumpet.gasp_speed
	return sp


func accelerate(wish: Vector3, wish_speed: float, accel: float, dt: float) -> void:
	if wish.length_squared() < 1e-6:
		return
	var cur := velocity.x * wish.x + velocity.z * wish.z
	var add := wish_speed - cur
	if add <= 0:
		return
	var acc := minf(accel * dt * wish_speed, add)
	velocity.x += acc * wish.x
	velocity.z += acc * wish.z


func friction(fr: float, dt: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp < 1e-4:
		return
	var drop := maxf(sp, 1.5) * fr * dt
	var k := maxf(sp - drop, 0.0) / sp
	velocity.x *= k
	velocity.z *= k


func movement(wish: Vector3, jump: bool, crouch_in: bool, dt: float) -> void:
	var mtd := mounted > 0
	var spr_k := GameData.SPRINT if sprinting and not mtd else 1.0
	var mx := max_speed()
	slow_t -= dt
	var hs := Vector2(velocity.x, velocity.z).length()
	slide_cd -= dt
	kb_t -= dt
	stagger -= dt
	if stagger > 0:
		wish = Vector3.ZERO
		jump = false
	fall_t -= dt
	if fall_t > 0:
		wish = Vector3.ZERO
		jump = false
		crouch_in = false
	if mtd:  # 말 위에선 앉기·넘어짐 없음
		crouch_in = false
	trip_cd -= dt
	fast_t -= dt
	# 관성: 빠르게 달린 뒤 0.25초 안에 반대 방향을 누르면 (키를 바꾸는 틈에 속도가 줄어도) 넘어짐
	if not mtd and grounded and fall_t <= 0 and not sliding and stagger <= 0 and kb_t <= 0 and trip_cd <= 0 and not crouch_in:
		if hs >= mx / spr_k * 0.75:
			fast_dir = Vector2(velocity.x, velocity.z) / hs
			fast_t = 0.25
		if wish.length_squared() > 0.01 and fast_t > 0 and fast_dir.dot(Vector2(wish.x, wish.z)) < -0.34:
			fast_t = 0
			trip()
			toast.emit("급회전하다 넘어짐!")
			wish = Vector3.ZERO
			jump = false
	# 슬라이드: 빠를 때 앉기 키를 누른 순간
	if crouch_in and not crouch_prev and grounded and hs > mx * 0.55 and slide_cd <= 0:
		sliding = true
		slide_t = 0.8
		slide_cd = 1.1
		var ns := minf(hs + 3.2, mx * 2)
		velocity.x *= ns / hs
		velocity.z *= ns / hs
		if is_local:
			Sfx.play("slide")
	crouch_prev = crouch_in
	_set_crouch(crouch_in)
	if sliding:
		slide_t -= dt
		if slide_t <= 0 or not crouch_in:
			sliding = false
	if grounded:
		if jump:
			velocity.y = GameData.JUMP_V
			grounded = false
			sliding = false
			jumped = true
			if is_local:
				Sfx.play("jump")
		else:
			friction(0.9 if fall_t > 0 else (0.7 if sliding else (2.0 if kb_t > 0 else 6.5)), dt)
			if sliding:
				accelerate(wish, 2, 3, dt)
			else:
				accelerate(wish, mx * 0.5 if crouch else mx, 12, dt)
	if not grounded:
		accelerate(wish, 1.1, 80, dt)  # 공중 제어
	velocity.y -= GameData.GRAV * dt
	var h := Vector2(velocity.x, velocity.z).length()
	var cap := maxf(mx * 2.4, 32.0) if kb_t > 0 else mx * 2.4  # 넉백 중엔 크게 날아가도록
	if h > cap:
		velocity.x *= cap / h
		velocity.z *= cap / h
	var was_air := not grounded
	_integrate(dt)
	if was_air and grounded and jumped:
		jumped = false
		# 점프하고 착지할 때 일정 확률로 넘어짐 (사용자 요청 — 말 위에선 없음)
		var ch: float = GameData.land_trip_override if GameData.land_trip_override >= 0 else GameData.LAND_TRIP
		if not mtd and fall_t <= 0 and randf() < ch:
			trip()
			toast.emit("착지하다 넘어짐!")


func _set_crouch(c: bool) -> void:
	if c == crouch:
		return
	var shape := col.shape as CylinderShape3D
	if not c and test_move(global_transform, Vector3(0, 1.75 - 1.15, 0)):
		return  # 머리 위가 막혀서 못 일어남
	crouch = c
	shape.height = 1.15 if c else 1.75
	col.position.y = shape.height / 2.0


func _integrate(dt: float) -> void:
	if grounded:
		try_step(dt)
	if velocity.y > 0:
		floor_snap_length = 0.0
	else:
		floor_snap_length = 0.6
	move_and_slide()
	grounded = is_on_floor()
	if grounded and velocity.y < 0:
		velocity.y = 0
	var ax: float = combat.world.half_x if combat and combat.world else GameData.ARENA  # 맵마다 이동 범위
	var az: float = combat.world.half_z if combat and combat.world else GameData.ARENA
	global_position.x = clampf(global_position.x, -ax, ax)
	global_position.z = clampf(global_position.z, -az, az)
	if global_position.y < -5:  # 혹시 바닥을 뚫으면 복구
		global_position.y = 0.5
		velocity.y = 0


## 낮은 턱(STEP_H 이하) 자동으로 올라가기 — HTML collideAxis()의 계단 처리와 같은 역할
func try_step(dt: float) -> void:
	var motion := Vector3(velocity.x, 0, velocity.z) * dt
	if motion.length() < 0.0005:
		return
	var xf := global_transform
	var hit := KinematicCollision3D.new()
	if not test_move(xf, motion, hit):
		return
	if hit.get_normal().y > 0.7 and hit.get_position().y < xf.origin.y + 0.05:
		return  # 벽이 아니라 바닥/경사 (발보다 높은 턱 모서리에 닿은 건 비스듬한 법선이 나와도 턱으로 봄 — 비스듬히 걸어가도 올라가게)
	var up := Vector3(0, GameData.STEP_H, 0)
	if test_move(xf, up):
		return  # 머리 위가 막힘
	# 비스듬히 걸으면 벽에 미끄러져 턱 쪽으로 가는 양이 거의 0 → 턱 위에 발이 안 걸림. 벽 안쪽으로 조금 더 밀어서 본다
	var n_h := Vector3(hit.get_normal().x, 0, hit.get_normal().z)
	var probe := motion
	if n_h.length() > 0.1:
		probe -= n_h.normalized() * GameData.STEP_PROBE
	var raised := xf.translated(up)
	if test_move(raised, probe):
		return  # 올라가도 막힘 → 진짜 벽
	var down := KinematicCollision3D.new()
	if test_move(raised.translated(probe), -up, down):
		var land_y := raised.origin.y + down.get_travel().y
		if land_y > xf.origin.y + 0.01:
			global_position.y = land_y + 0.002


# ── 넘어짐 ───────────────────────────────────────────────────
func fall_amt() -> float:
	if fall_t <= 0:
		return 0.0
	return maxf(0.0, minf(1.0, minf((GameData.FALL_TIME - fall_t) / 0.08, fall_t / 0.06)))


func trip() -> void:
	fall_t = GameData.FALL_TIME
	trip_cd = GameData.FALL_TIME + 0.5
	sliding = false
	reset_charge()
	var hs := Vector2(velocity.x, velocity.z).length()
	var A := PI / 2 * 0.92
	if hs > 1.2:  # 움직이다 넘어지면 그 방향으로 배(70%)나 등(30%)으로 쭉 미끄러짐
		var boost := (hs + 1.8) / hs
		velocity.x *= boost
		velocity.z *= boost
		fall_yaw = atan2(velocity.x, velocity.z)
		fall_rz = 0
		fall_rx = A if randf() < 0.7 else -A
		if is_local:
			Sfx.play("slide")
	else:
		fall_yaw = yaw + PI
		var rr := randf()
		if rr < 0.4:
			fall_rx = A
			fall_rz = 0
		elif rr < 0.6:
			fall_rx = -A
			fall_rz = 0
		else:
			fall_rx = 0
			fall_rz = (-1.0 if randf() < 0.5 else 1.0) * A
	Sfx.play("trip", global_position)
	if combat and (not is_local or combat.tp_on()):
		combat.fx.puff(global_position + Vector3(0, 0.1, 0), 0xd8c39a, 0.18, 5)


# ── 카메라 ───────────────────────────────────────────────────
func aim_dir() -> Vector3:
	var cp := cos(pitch)
	return Vector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp)


func _process(dt: float) -> void:
	if is_local:
		if alive:  # 활·석궁 1인칭 반동 스프링 — HTML updateVM의 vRec
			var sdt := minf(dt, 0.03)
			v_rec_v += (-260.0 * v_rec - 17.0 * v_rec_v) * sdt
			v_rec += v_rec_v * sdt
		_update_camera(dt)
	if not model:
		return
	if alive:
		model.animate(self, dt)
	# 스폰 무적 중엔 깜빡임
	var blink := invuln <= 0 or int(floor(invuln * 12)) % 2 == 0
	model.visible = alive and blink and (not is_local or (tp_view() and tp_dist > 0.9))


## 저격총 스코프로 보는 중 (우클릭) — HTML scoped
func is_scoped() -> bool:
	return is_local and alive and aim_held and wep == "sniper" and swap_t <= 0


## 3인칭으로 보이나 — 스코프를 보면 잠깐 1인칭이 된다 (HTML tpOn)
func tp_view() -> bool:
	return GameData.third_person and not is_scoped()


## 메뉴에서 구경하기 — 맵 가운데를 보며 천천히 빙 돈다
func set_spectating(on: bool) -> void:
	spectating = on
	if on:
		alive = false
		fire_held = false
		aim_held = false
		reset_charge()
		playing = false
		if model:
			model.visible = false


func _update_camera(dt: float) -> void:
	if orbit:
		var M: Dictionary = GameData.MENU_CAM
		menu_angle += dt * float(M.speed)
		cam.global_position = Vector3(sin(menu_angle) * float(M.r), float(M.h), cos(menu_angle) * float(M.r))
		cam.look_at(M.look)
		cam.fov = M.fov
		return
	if not alive:  # 죽으면 날아가는 래그돌 골반을 맞은 방향 뒤쪽 위에서 따라간다 (HTML updateCamera)
		var DC: Dictionary = GameData.DEATH_CAM
		var c := ragdoll.pelvis() if ragdoll and ragdoll.life > 0 else death_pos + Vector3(0, 0.6, 0)
		var bd := Vector3(death_dir.x, 0, death_dir.z)
		bd = bd.normalized() if bd.length_squared() > 1e-4 else Vector3(sin(yaw), 0, cos(yaw))
		var want := c - bd * float(DC.back)
		want.y = c.y + float(DC.up)
		cam.global_position = cam.global_position.lerp(want, minf(1.0, dt * float(DC.follow)))
		if cam.global_position.distance_squared_to(c) > 0.01:
			cam.look_at(c)
		cam.fov = 85.0
		return
	var p := get_global_transform_interpolated().origin
	var fa := fall_amt()
	var target := p.y + mount_h + (1.0 if crouch else 1.55) * (1 - fa * 0.7)
	view_y += (target - view_y) * minf(1.0, dt * (16.0 if target > view_y else 30.0))
	var speed := Vector2(velocity.x, velocity.z).length()
	var zoom: float
	var aim_cam: Dictionary = GameData.AIM_CAM.get(wep, {})
	var tp := tp_view()
	var ak_ready := wep != "ak" or swap_t <= 0
	if tp:  # 오른쪽 어깨 너머 3인칭
		var fwd := aim_dir()
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var aim_z := aim_held and aim_cam.size() > 0  # 우클릭 조준: 카메라가 어깨로 다가온다
		var want := GameData.MOUNT_CAM if mounted > 0 else (GameData.AIM_TP_DIST if aim_z else 3.6)
		var pivot := Vector3(p.x, view_y + 0.55, p.z) + right * (GameData.AIM_TP_RIGHT if aim_z else 1.0)
		var back := -fwd * (want + 0.3)
		var q := PhysicsRayQueryParameters3D.create(pivot, pivot + back)
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var res := get_world_3d().direct_space_state.intersect_ray(q)
		var dd := want
		if not res.is_empty():
			var tt: float = pivot.distance_to(res.position) / (want + 0.3)
			dd = maxf(0.35, (want + 0.3) * tt - 0.35)
		tp_dist += (dd - tp_dist) * minf(1.0, dt * (40.0 if dd < tp_dist else 6.0))
		cam.global_position = pivot - fwd * tp_dist
		cam.rotation = Vector3(pitch, yaw, -0.03 if sliding else 0.0)
		zoom = float(aim_cam.tp_fov) if aim_z else (81.0 if sprinting and speed > 3 else 75.0)
	else:
		cam.global_position = Vector3(p.x, view_y, p.z)
		var roll := (-0.06 if sliding else 0.0) + fa * (signf(fall_rz) * 0.9 if fall_rz != 0 else 0.25)
		var dip := 0.6 if fall_rx > 0 else (-0.5 if fall_rx < 0 else 0.0)
		cam.rotation = Vector3(pitch - fa * dip, yaw, roll)
		if is_scoped():
			zoom = GameData.SCOPE_FOV
		elif aim_held and aim_cam.size() > 0 and ak_ready:
			zoom = float(aim_cam.fp_fov)
		else:
			zoom = 92.0 if sprinting and speed > 3 else 85.0
	if shake > 0:
		shake = maxf(0.0, shake - dt * 2)
		cam.rotation.x += randf_range(-1, 1) * shake * 0.03
		cam.rotation.y += randf_range(-1, 1) * shake * 0.03
	cam.rotation.x += v_rec * GameData.VREC_CAM  # 쏘면 화면만 살짝 튕긴다 (조준 방향은 그대로)
	if dance_t > 0:  # 춤에 걸리면 카메라가 리듬에 맞춰 까딱 (조준 출렁임은 Trumpet이 yaw에 줌)
		var FXT: Dictionary = GameData.WEAPONS.trumpet.fx
		var bt := sin(Time.get_ticks_msec() / 1000.0 * TAU * float(FXT.bob_hz))
		cam.rotation.z += bt * float(FXT.bob)
		cam.rotation.x += absf(bt) * float(FXT.bob) * 0.5
	if absf(cam.fov - zoom) > 0.1:
		cam.fov += (zoom - cam.fov) * minf(1.0, dt * 14)
