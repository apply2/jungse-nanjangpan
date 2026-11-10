// grass_blade: 잔디 포기 (MultiMesh). 바람에 살랑임 — 뿌리는 그대로, 끝으로 갈수록 크게 흔들림.
// 색은 인스턴스 색(채도 낮은 초록) × 아래쪽 어둡게. 그림자 없음. 수치는 GameData.MAT_STYLES.grass_blade
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform float sway = 0.06;
uniform float wind_speed = 1.8;
uniform float wind_scale = 0.32;
uniform float height = 0.25;
uniform float root_dark = 0.45;

varying float v_h;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_h = clamp(VERTEX.y / height, 0.0, 1.0);
	float ph = TIME * wind_speed + w.x * wind_scale + w.z * wind_scale * 0.8;
	float k = sin(ph) * 0.7 + sin(ph * 2.3 + 1.3) * 0.3;
	VERTEX.x += k * sway * v_h * v_h;
	VERTEX.z += k * sway * 0.5 * v_h * v_h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);  // 앞뒤 면 모두 위를 보게 (뒷면이 까맣지 않게)
	ALBEDO = COLOR.rgb * mix(1.0 - root_dark, 1.0, v_h);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
