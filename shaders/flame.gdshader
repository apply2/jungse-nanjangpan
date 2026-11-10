// flame: 횃불 불꽃 — 실제 빛 없이 발광만, 크기가 흔들림. 수치는 GameData.MAT_STYLES.flame
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float flicker = 0.045;
uniform float speed = 13.0;
uniform float glow = 1.6;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = fract(sin(dot(floor(w * 3.0), vec3(12.9, 78.2, 37.7))) * 43758.5) * 6.28;
	float k = sin(TIME * speed + ph) * 0.5 + sin(TIME * speed * 1.7 + ph * 2.0) * 0.5;
	VERTEX += NORMAL * flicker * k;
	VERTEX.y += max(NORMAL.y, 0.0) * flicker * 1.5 * (k + 1.0);
}

void fragment() {
	ALBEDO = COLOR.rgb * glow;
}
