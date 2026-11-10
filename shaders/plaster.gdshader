// plaster: 나무 골조 집의 흰 벽. 은은한 얼룩 + 군데군데(약 5%) 칠이 벗겨져 벽돌이 보임 (brick 함수 재사용).
// 수치는 GameData.MAT_STYLES.plaster
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform float stain = 0.07;
uniform float patch_scale = 0.32;
uniform float patch_cut = 0.69;
uniform vec4 brick_col : source_color = vec4(0.62, 0.33, 0.24, 1.0);
uniform vec4 mortar_col : source_color = vec4(0.88, 0.85, 0.8, 1.0);
uniform vec2 brick_size = vec2(0.5, 0.2);
uniform float mortar = 0.025;

void fragment() {
	vec3 base = COLOR.rgb;
	int ax;
	vec2 uv = face_uv(v_wpos, face_normal(), ax);
	vec3 c = base * (1.0 - stain + stain * 2.0 * fbm(uv * 0.6 + 4.0));
	if (ax != 1) {
		float p = fbm(uv * patch_scale + vec2(7.3, 1.9));
		float e = max(fwidth(p), 1e-4);
		float inside = smoothstep(patch_cut - e, patch_cut + e, p);
		float rim = smoothstep(patch_cut - 0.025, patch_cut, p) * (1.0 - inside);
		vec3 br = brick_albedo(uv, brick_col.rgb, brick_size, mortar, mortar_col.rgb, 0.12, 0.08, brick_col.rgb * 0.7, 0.25);
		c = mix(c, br, inside);
		c *= 1.0 - 0.25 * rim;  // 벗겨진 가장자리 그림자
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
