extends SubViewport
## 결과 화면 왼쪽 무대 (시안 Result*.jpg): 시상대 위 1~3등 / 쓰러진 나 / 우리 팀 5명.
## 직교 카메라라 화면 px ↔ m가 그대로 맞는다 (GameData.RESULT_UI.stage.ppm). 결과 화면이 보일 때만 그림.
## setup([{cls, team, at: 화면 좌표(1280×720 배치, 발 자리), yaw: 도, lie: 쓰러짐, mood: "win"/"lose"/""}])

const Pose := preload("res://scripts/ui/menu_crowd.gd").Pose


## 쓰러진 자세 (DerpModel이 fall_amt로 몸을 눕히고 팔을 만세)
class LiePose extends Pose:
	func fall_amt() -> float:
		return 1.0


var active := false
var poses: Array = []
var models: Array = []
var moods: Array = []
var _t := 0.0


func _ready() -> void:
	var S: Dictionary = GameData.RESULT_UI.stage
	var r: Rect2 = S.rect
	size = Vector2i(r.size * 1.5)  # 1080p에서도 또렷하게
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = GameData.col(0xc8dccc)
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = r.size.y / float(S.ppm)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 0, 20), Vector3(0, 0, 0))
	cam.current = true


## 배치 좌표(px) → 무대 m
static func to_world(at: Vector2) -> Vector3:
	var S: Dictionary = GameData.RESULT_UI.stage
	var r: Rect2 = S.rect
	var ppm: float = S.ppm
	return Vector3((at.x - r.position.x - r.size.x / 2.0) / ppm, (r.position.y + r.size.y / 2.0 - at.y) / ppm, 0)


func setup(cast: Array) -> void:
	for m in models:
		(m as Node).queue_free()
	for p in poses:
		(p as Node).queue_free()
	models.clear()
	poses.clear()
	moods.clear()
	for e: Dictionary in cast:
		var lie: bool = e.get("lie", false)
		var p: Pose = LiePose.new() if lie else Pose.new()
		p.wep = GameData.CLASSES[e.cls].weapon
		p.base_yaw = -PI + deg_to_rad(float(e.get("yaw", 0.0)))
		p.yaw = p.base_yaw
		p.phase = randf() * TAU
		if lie:
			p.fall_t = 1.0
			p.fall_yaw = p.base_yaw + PI
			p.fall_rz = PI / 2.0
		add_child(p)
		p.position = to_world(e.at)
		var m := DerpModel.new(e.cls, str(e.get("team", "")))
		add_child(m)
		poses.append(p)
		models.append(m)
		moods.append(str(e.get("mood", "")))
	_step(0.0)
	if not active:
		render_target_update_mode = SubViewport.UPDATE_ONCE


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(dt: float) -> void:
	if active:
		_step(dt)


## 이기면 통통 뛰고 고개 까딱, 지면 고개 숙이고 천천히 흔들
func _step(dt: float) -> void:
	_t += dt
	for i in poses.size():
		var p: Pose = poses[i]
		var ph: float = p.phase
		match moods[i]:
			"win":
				p.yaw = p.base_yaw + sin(_t * 1.3 + ph) * 0.25
				p.pitch = sin(_t * 5.0 + ph) * 0.12
				p.mount_h = absf(sin(_t * 4.0 + ph)) * 0.12
			"lose":
				p.yaw = p.base_yaw + sin(_t * 0.6 + ph) * 0.12
				p.pitch = -0.35 + sin(_t * 0.9 + ph) * 0.05
			_:
				p.yaw = p.base_yaw + sin(_t * 0.8 + ph) * 0.15
		(models[i] as DerpModel).animate(p, dt)
