// bark: 나무줄기 세로 줄무늬. 수치는 GameData.MAT_STYLES.bark
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform float stripes = 14.0;
uniform float depth = 0.35;

void fragment() {
	vec3 base = COLOR.rgb;
	float a = atan(v_wn.z, v_wn.x) / 6.2831;
	float n = vnoise(vec2(a * stripes, v_wpos.y * 0.8)) + 0.4 * vnoise(vec2(a * stripes * 2.3, v_wpos.y * 2.0));
	vec3 c = base * (1.0 - depth * smoothstep(0.55, 1.0, n));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
