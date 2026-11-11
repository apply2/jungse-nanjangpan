extends SubViewport
## 병과 한 명을 세워 찍는 무대 (투명 배경·자기 World3D). 병과 선택 화면이 쓴다.
##   큰 액자: show_class(k) + set_active(true) → 천천히 좌우로 흔들며 계속 그림
##   카드 그림: portrait(k) → 한 번만 찍어 ImageTexture로 돌려줌 (UPDATE_ONCE). 헤드리스면 null
## 배치(카메라·몸 돌림)는 GameData.CLASS_PAGE의 stage 설정 하나 (big / card).

const Pose := preload("res://scripts/ui/menu_crowd.gd").Pose

var cfg: Dictionary
var cls := ""
var active := false
var pose: Node3D
var model: DerpModel
var _t := 0.0


func _init(conf: Dictionary) -> void:
	cfg = conf
	size = Vector2i(conf.px)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_DISABLED


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = GameData.col(0xc8dccc)  # 경기 화면과 같은 빛
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
	cam.fov = cfg.fov
	add_child(cam)
	cam.look_at_from_position(cfg.cam, cfg.look)
	cam.current = true
	pose = Pose.new()
	add_child(pose)


## 병과 바꾸기 (모델을 새로 만든다)
func show_class(k: String) -> void:
	if k == cls and model:
		return
	cls = k
	if model:
		model.queue_free()
	model = DerpModel.new(k)
	add_child(model)
	pose.wep = GameData.CLASSES[k].weapon
	pose.base_yaw = -PI + deg_to_rad(float(cfg.yaw))
	pose.yaw = pose.base_yaw
	model.animate(pose, 0.0)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(dt: float) -> void:
	if not active or not model:
		return
	_t += dt
	pose.yaw = pose.base_yaw + sin(_t * TAU * float(cfg.sway_hz)) * deg_to_rad(float(cfg.sway))
	pose.pitch = sin(_t * TAU * float(cfg.sway_hz) * 1.3 + 1.0) * 0.08
	model.animate(pose, dt)


## 한 번만 찍은 그림 (카드용). 화면이 없으면(헤드리스) null
func portrait(k: String) -> Texture2D:
	show_class(k)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
