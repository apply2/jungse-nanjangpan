// hay: 건초 — 가는 결 + 노란색 흔들림. 수치는 GameData.MAT_STYLES.hay
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform float fiber = 38.0;
uniform float jitter = 0.16;

void fragment() {
	vec3 base = COLOR.rgb;
	int ax;
	vec2 uv = face_uv(v_wpos, normalize(v_wn), ax);
	float f1 = vnoise(vec2(uv.x * fiber, uv.y * 2.5));
	float f2 = vnoise(vec2(uv.x * 3.0 + 5.0, uv.y * fiber * 0.8));
	vec3 c = base * (1.0 + (vnoise(uv * 1.7) - 0.5) * 2.0 * jitter);
	c *= 0.82 + 0.3 * max(f1, f2);
	c = mix(c, base, far_fade(uv, 0.15) * 0.7);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
