extends SubViewport
## 메인 메뉴 오른쪽 병과 무리 (시안 Main.html의 캐릭터 그림 자리) — 실제 DerpModel 4개를 자기 World3D에 세워 찍는다.
## 투명 배경이라 뒤의 맵 구경 화면 위에 그대로 얹힌다. 느린 대기 동작: 몸이 좌우로 살짝, 고개 까딱, 눈동자는 DerpModel이 굴림.
## set_active(false)면 렌더·애니메이션을 다 멈춘다 (메뉴가 안 보일 때). 배치는 GameData.MAIN_MENU.crowd.

var active := false
var poses: Array = []    # 모델마다 가짜 플레이어 (DerpModel.animate가 읽는 값만)
var models: Array = []
var _t := 0.0


## DerpModel.animate가 읽는 플레이어 값만 가진 대역 (가만히 서서 무기를 든 모습)
class Pose extends Node3D:
	var yaw := 0.0
	var base_yaw := 0.0
	var pitch := 0.0
	var phase := 0.0
	var velocity := Vector3.ZERO
	var mount_h := 0.0
	var fall_t := 0.0
	var fall_yaw := 0.0
	var fall_rx := 0.0
	var fall_rz := 0.0
	var kb_t := 0.0
	var grounded := true
	var sliding := false
	var wep := ""
	var fire_anim := 0.0
	var rec := 0.0
	var rec_v := 0.0
	var cd := 0.0
	var mounted := 0.0
	var playing := false
	var alive := true
	var hit_squash := 0.0
	var flash := 0.0
	var dance_t := 0.0

	func fall_amt() -> float:
		return 0.0


func _ready() -> void:
	var C: Dictionary = GameData.MAIN_MENU.crowd
	var r: Rect2 = C.rect
	size = Vector2i(r.size)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = GameData.col(0xc8dccc)  # 경기 화면과 같은 빛 (Main._setup_environment)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = GameData.col(0xfff0d2)
	sun.light_energy = 0.85
	add_child(sun)
	sun.look_at_from_position(Vector3(4, 7, 6), Vector3.ZERO)
	var cam := Camera3D.new()
	cam.fov = C.fov
	add_child(cam)
	cam.look_at_from_position(C.cam, C.look)
	cam.current = true
	var shadow_mat := StandardMaterial3D.new()  # 발밑 그림자 (시안 drop-shadow 자리)
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(GameData.col(GameData.UI.ink), float(C.shadow_a))
	for row: Array in C.cast:
		var p := Pose.new()
		p.wep = row[3]
		p.base_yaw = -PI + deg_to_rad(float(row[2]))
		p.yaw = p.base_yaw
		p.phase = randf() * TAU
		add_child(p)
		p.position = row[1]
		var m := DerpModel.new(row[0])
		add_child(m)
		var sh := MeshInstance3D.new()
		sh.mesh = Meshes.disc()
		sh.material_override = shadow_mat
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.scale = Vector3(1, 1, 0.7) * float(C.shadow_r)
		sh.position = p.position + Vector3(0, 0.01, 0)
		add_child(sh)
		poses.append(p)
		models.append(m)
	_step(0.0)


## 메뉴가 보일 때만 그리고 움직인다
func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(dt: float) -> void:
	if active:
		_step(dt)


func _step(dt: float) -> void:
	var C: Dictionary = GameData.MAIN_MENU.crowd
	_t += dt
	for i in poses.size():
		var p: Pose = poses[i]
		p.yaw = p.base_yaw + sin(_t * TAU * float(C.sway_hz) + p.phase) * float(C.sway)
		p.pitch = sin(_t * TAU * float(C.nod_hz) + p.phase * 1.7) * float(C.nod)
		(models[i] as DerpModel).animate(p, dt)
