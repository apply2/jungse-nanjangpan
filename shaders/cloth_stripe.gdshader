// cloth_stripe: 좌판 천막 — 넓은 두 색 줄무늬 (바탕색 + stripe_col). 수치는 GameData.MAT_STYLES.cloth_stripe
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform float width = 0.4;
uniform vec4 stripe_col : source_color = vec4(0.96, 0.93, 0.86, 1.0);

void fragment() {
	vec3 base = COLOR.rgb;
	float u = v_wpos.x + v_wpos.z;
	float f = fract(u / (width * 2.0));
	float d = min(abs(f - 0.5), min(f, 1.0 - f)) * width * 2.0;   // 줄 경계까지 거리 (m)
	float e = max(fwidth(u), 1e-4);
	float stripe = smoothstep(0.5 - e / (width * 2.0), 0.5 + e / (width * 2.0), f) * (1.0 - smoothstep(1.0 - e / (width * 2.0), 1.0, f));
	vec3 c = mix(base, stripe_col.rgb, stripe);
	c *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, 0.03, d));
	c *= 0.95 + 0.08 * vnoise(v_wpos.xz * 3.0);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
