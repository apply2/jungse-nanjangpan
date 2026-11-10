// brick: 집·굴뚝·우물 벽돌 (러닝 본드 0.5×0.2m). 윗면은 평평한 돌 덮개. 수치는 GameData.MAT_STYLES.brick
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform vec2 brick_size = vec2(0.5, 0.2);
uniform float mortar = 0.025;
uniform vec4 mortar_col : source_color = vec4(0.9, 0.88, 0.84, 1.0);
uniform float jitter = 0.12;
uniform float odd_chance = 0.08;
uniform vec4 odd_col : source_color = vec4(0.55, 0.35, 0.27, 1.0);
uniform float edge_dark = 0.25;
uniform vec4 cap_col : source_color = vec4(0.72, 0.69, 0.64, 1.0);

void fragment() {
	vec3 base = COLOR.rgb;
	int ax;
	vec2 uv = face_uv(v_wpos, face_normal(), ax);
	vec3 c;
	if (ax == 1) {
		c = cap_col.rgb * (0.9 + 0.2 * vnoise(uv * 1.5));
	} else {
		c = brick_albedo(uv, base, brick_size, mortar, mortar_col.rgb, jitter, odd_chance, odd_col.rgb, edge_dark);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
