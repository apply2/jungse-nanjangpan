class_name MatStyles
## 맵 재질 셰이더 만들기 (맵 꾸미기 — 사용자 요청). 셰이더는 shaders/, 수치는 GameData.MAT_STYLES.
## MAT_STYLES의 "shader" 말고 나머지 값은 전부 셰이더 uniform으로 들어간다 (int는 색 16진수 → Color).
## 같은 무늬는 재질 하나를 같이 쓴다 (바탕색은 정점 색이라 상자마다 달라도 됨) → 합친 메시 하나 = 그리기 한 번.

static var _cache := {}


## 무늬 재질 (캐시). extra가 있으면 그 값(MAT_STYLES와 같은 꼴)을 덮어쓴 새 재질 (캐시 안 함)
static func get_mat(style: String, extra := {}) -> ShaderMaterial:
	if extra.is_empty() and _cache.has(style):
		return _cache[style]
	var d: Dictionary = GameData.MAT_STYLES[style]
	var sm := ShaderMaterial.new()
	sm.shader = load(d.shader)
	for k: String in d:
		if k != "shader":
			sm.set_shader_parameter(k, _val(d[k]))
	for k: String in extra:
		sm.set_shader_parameter(k, _val(extra[k]))
	if extra.is_empty():
		_cache[style] = sm
	return sm


static func _val(v: Variant) -> Variant:
	if v is int:
		return GameData.col(v)
	return v


## 땅 재질 (잔디 + 흙길). paths = 흙길 직사각형 (가운데 x, 가운데 z, 반폭 x, 반폭 z) — 맵마다 새로 만듦
static func ground(paths: Array[Vector4]) -> ShaderMaterial:
	var arr := PackedVector4Array()
	for p in paths:
		arr.append(p)
	var n := mini(arr.size(), 24)
	arr.resize(24)
	var sm := get_mat("grass_ground", {"_fresh": 1.0})
	sm.set_shader_parameter("paths", arr)
	sm.set_shader_parameter("path_count", n)
	return sm
