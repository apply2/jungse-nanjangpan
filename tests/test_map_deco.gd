extends SceneTree
## 맵 꾸미기 자동 테스트: 충돌 상자·스폰 지점이 꾸미기 전과 똑같은지(지문), 장식에 충돌이 없는지,
## 잔디·들꽃이 충돌 상자·흙길·돌바닥 위에 안 나는지, 잔디 높이 ≤ 0.25m, 고정 시드라 두 번 지어도 같은지,
## 그래픽 품질(낮음·보통·높음) → 잔디 개수·작은 소품·그림자, 설정 저장/불러오기, 설정 패널 버튼.
## 실행: godot --headless --fixed-fps 60 --path . -s tests/test_map_deco.gd

# 꾸미기 전에 잰 충돌 지문 (상자 수 | 충돌 몸 자식 수 | 상자 목록 md5) — 바뀌면 게임 규칙이 바뀐 것
const SIG := {
	"ffa": "108|109|afaf8f0bc06a87296918268109c077bc",
	"control": "144|145|901984c0a8d732faa3599333d865c355",
}
const SPAWN := {"ffa": "0f7d0022a73af5fa595583dafb2c51ae", "control": "73515e55c054f72b098ea8479d5d70cc"}

var G
var fails := 0


func _initialize() -> void:
	G = root.get_node("GameData")
	G.save_enabled = false
	G.hitstop_enabled = false
	G.ai_enabled = false
	G.gfx_quality = "normal"
	_run()


func check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func sig(w) -> String:
	var parts := []
	for a: AABB in w.aabbs:
		parts.append("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [a.position.x, a.position.y, a.position.z, a.size.x, a.size.y, a.size.z])
	return "%d|%d|%s" % [w.aabbs.size(), w.body.get_child_count(), "|".join(parts).md5_text()]


## 맵 아래 모든 충돌 물체 (StaticBody3D 등)
func colliders(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is CollisionObject3D:
			out.append(c)
		out.append_array(colliders(c))
	return out


## 잔디·들꽃의 모든 포기 [월드 위치, 기저] (맵이 MultiMesh에 넣은 값 그대로 — 헤드리스는 MultiMesh에서 못 읽음)
func instances(w, nm: String) -> Array:
	var out := []
	for it: Array in w.scatter_items.get(nm, []):
		var xf: Transform3D = it[0]
		out.append([xf.origin, xf.basis])
	return out


func _run() -> void:
	await process_frame
	var maps := {
		"ffa": load("res://scripts/world_builder.gd").new(),
		"control": load("res://scripts/maps/map_control.gd").new(),
	}
	for k: String in maps:
		root.add_child(maps[k])
	await process_frame
	for k: String in maps:
		var w = maps[k]
		check("[%s] 충돌 상자 그대로 (지문)" % k, sig(w) == SIG[k], sig(w))
		check("[%s] 스폰 지점 그대로" % k, str(w.spawn_points).md5_text() == SPAWN[k])
		var cols := colliders(w).filter(func(c: Node) -> bool: return c.name != "TeamBarriers" and c.get_parent().name != "TeamBarriers")
		check("[%s] 충돌 물체는 원래 것뿐 (장식 충돌 없음)" % k, cols.size() == 1 and cols[0] == w.body, "n=%d" % cols.size())
		# 잔디
		var grass := instances(w, "Grass")
		var flowers := instances(w, "Flowers")
		check("[%s] 잔디 천 포기 넘게" % k, grass.size() > 1000, "n=%d" % grass.size())
		var tall := 0
		for it: Array in grass:
			tall += 1 if (it[1] as Basis).get_scale().y > 0.25 + 1e-4 else 0
		check("[%s] 잔디 높이 ≤ 0.25m" % k, tall == 0, "넘는 것 %d" % tall)
		var bad := 0
		var bad_at := Vector3.ZERO
		for it: Array in grass + flowers:
			var p: Vector3 = it[0]
			var hit: bool = absf(p.x) > w.half_x or absf(p.z) > w.half_z
			for a: AABB in w.aabbs:
				if a.position.y < 0.3 and p.x > a.position.x and p.x < a.end.x and p.z > a.position.z and p.z < a.end.z:
					hit = true
			for r: Vector4 in w._paths:
				if absf(p.x - r.x) < r.z and absf(p.z - r.y) < r.w:
					hit = true
			for q: Rect2 in w._no_grass:
				if q.has_point(Vector2(p.x, p.z)):
					hit = true
			if hit:
				bad += 1
				bad_at = p
		check("[%s] 잔디·들꽃이 상자·흙길·돌바닥·맵 밖에 없음" % k, bad == 0, "%d개 (예: %s)" % [bad, bad_at])
		var mmi_ok := true
		for g: MultiMeshInstance3D in w.grass_nodes:
			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or g.visibility_range_end > float(G.DECO.grass_range) + 0.01:
				mmi_ok = false
		check("[%s] 잔디 그림자 없음·%dm 넘으면 안 보임" % [k, int(G.DECO.grass_range)], mmi_ok and w.grass_nodes.size() > 4, "chunks=%d" % w.grass_nodes.size())
		check("[%s] 횃불·현수막·덩굴 등 작은 소품 있음" % k, w.clutter_nodes.size() > 3, "n=%d" % w.clutter_nodes.size())
		check("[%s] 횃불 %d개 자리" % [k, int(G.DECO.torches)], w._bays.size() >= int(G.DECO.torches), "bays=%d" % w._bays.size())
	# 고정 시드: 다시 지어도 같은 자리
	var again = load("res://scripts/maps/map_control.gd").new()
	root.add_child(again)
	await process_frame
	var h1 := str(instances(maps.control, "Grass").slice(0, 400)).md5_text()
	var h2 := str(instances(again, "Grass").slice(0, 400)).md5_text()
	check("고정 시드: 두 번 지어도 잔디 자리가 같음", h1 == h2 and instances(again, "Grass").size() == instances(maps.control, "Grass").size())
	again.queue_free()
	# 무늬 재질: 상자 style → 합친 메시가 그 셰이더를 씀
	var styles := {}
	for c in maps.ffa.get_children():
		if c is MeshInstance3D and c.material_override is ShaderMaterial and String(c.name).begins_with("Static"):
			styles[(c.material_override as ShaderMaterial).shader.resource_path.get_file()] = true
	for s: String in ["brick.gdshader", "castle_stone.gdshader", "wood_plank.gdshader", "plaster.gdshader", "roof_tiles.gdshader", "bark.gdshader", "hay.gdshader", "cloth_stripe.gdshader", "flame.gdshader"]:
		check("무늬 재질 쓰임: %s" % s, styles.has(s))
	var gm = maps.ffa._ground.material_override
	check("땅 = 잔디·흙길 셰이더 + 흙길 3개", gm is ShaderMaterial and gm.shader.resource_path.ends_with("grass_ground.gdshader") and int(gm.get_shader_parameter("path_count")) == 3)
	check("기본 style \"\"은 단색 그대로", maps.ffa.get_node_or_null("Static") != null and maps.ffa.get_node("Static").material_override is StandardMaterial3D)
	for k: String in maps:
		maps[k].queue_free()
	await process_frame
	await _gfx()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


## 그래픽 품질: 맵·태양에 바로 반영, 저장/불러오기, 설정 패널 버튼
func _gfx() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var w = main.world_ffa
	var total := 0
	for g: MultiMeshInstance3D in w.grass_nodes:
		total += g.multimesh.instance_count
	var shown := func() -> int:
		var n := 0
		for g: MultiMeshInstance3D in w.grass_nodes:
			n += g.multimesh.visible_instance_count if g.visible else 0
		return n
	var clutter_on := func() -> bool:
		return w.clutter_nodes.all(func(c: Node3D) -> bool: return c.visible)
	var clutter_off := func() -> bool:
		return w.clutter_nodes.all(func(c: Node3D) -> bool: return not c.visible)
	check("기본 = 보통 (잔디 절반·소품·그림자 130m)", G.gfx_quality == "normal" and absf(shown.call() - total * 0.5) < w.grass_nodes.size() + 1 and clutter_on.call() and main.sun.shadow_enabled and is_equal_approx(main.sun.directional_shadow_max_distance, 130.0), "%d/%d" % [shown.call(), total])
	G.set_gfx("low")
	check("낮음: 잔디 없음·소품 숨김·그림자 끔", shown.call() == 0 and clutter_off.call() and not main.sun.shadow_enabled)
	G.set_gfx("high")
	check("높음: 잔디 전부·소품·그림자 220m", shown.call() == total and clutter_on.call() and main.sun.shadow_enabled and is_equal_approx(main.sun.directional_shadow_max_distance, 220.0))
	# 저장 → 불러오기
	var old_path: String = G.settings_path
	G.settings_path = "user://test_settings_gfx.cfg"
	G.save_enabled = true
	G.set_gfx("low")
	G.gfx_quality = "high"
	G.load_settings()
	check("설정 파일에 품질 저장 ([video] quality)", G.gfx_quality == "low", G.gfx_quality)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.settings_path))
	G.settings_path = old_path
	G.save_enabled = false
	# 설정 패널 버튼
	var sp: Node = load("res://scenes/ui/settings_panel.tscn").instantiate()
	root.add_child(sp)
	await process_frame
	check("설정 패널에 낮음·보통·높음 버튼", sp._gfx_btns.size() == 3 and sp._gfx_btns.normal.text == "보통")
	(sp._gfx_btns.normal as Button).pressed.emit()
	check("보통 버튼 → 품질 보통", G.gfx_quality == "normal" and shown.call() > 0)
	sp.queue_free()
	main.queue_free()
	await process_frame
