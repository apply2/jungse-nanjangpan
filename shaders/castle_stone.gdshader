// castle_stone: 성벽·탑·단상 큰 돌 블록 (높이 0.6m, 줄마다 길이 0.8~1.6m). 아래쪽은 이끼 + 땅에 가까울수록 어두움(가짜 AO).
// 윗면은 같은 블록을 바닥돌처럼 깐다 (이끼·AO 없음). 수치는 GameData.MAT_STYLES.castle_stone
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform float block_h = 0.6;
uniform vec2 block_len = vec2(0.8, 1.6);
uniform float mortar = 0.05;
uniform vec4 mortar_col : source_color = vec4(0.32, 0.31, 0.3, 1.0);
uniform float jitter = 0.1;
uniform float blotch = 0.18;
uniform vec4 moss_col : source_color = vec4(0.36, 0.48, 0.25, 1.0);
uniform float moss_h = 1.2;
uniform float ao = 0.35;
uniform float ao_h = 0.7;

void fragment() {
	vec3 base = COLOR.rgb;
	int ax;
	vec2 uv = face_uv(v_wpos, face_normal(), ax);
	float row = floor(uv.y / block_h);
	float len = mix(block_len.x, block_len.y, h21(vec2(row, 3.1)));
	float gx = uv.x / len + h21(vec2(row, 8.7));
	float id = floor(gx);
	float fx = fract(gx);
	float fy = fract(uv.y / block_h);
	float d = min(min(fx, 1.0 - fx) * len, min(fy, 1.0 - fy) * block_h);
	float m = aa_line(d, mortar * 0.5);
	float h = h21(vec2(id, row));
	vec3 c = base * (1.0 + (h - 0.5) * 2.0 * jitter);
	c *= 1.0 - blotch * smoothstep(0.45, 0.8, fbm(uv * 1.3 + h * 7.0));
	c *= 1.0 - 0.18 * (1.0 - smoothstep(mortar * 0.5, mortar * 3.0, d));
	c = mix(c, mortar_col.rgb, m);
	c = mix(c, base * 0.9, far_fade(uv, block_h) * 0.8);
	if (ax != 1) {
		float y = v_wpos.y;
		float moss = smoothstep(0.25, 0.75, fbm(uv * 0.9 + 3.0) + (1.0 - y / moss_h) * 0.9 - 0.45) * step(y, moss_h + 0.4);
		c = mix(c, moss_col.rgb * (0.85 + 0.3 * vnoise(uv * 6.0)), moss * 0.85);
		c *= mix(1.0 - ao, 1.0, smoothstep(0.0, ao_h, y));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
