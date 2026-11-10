// grass_ground: 땅 전체 (판 하나). 초록 4가지가 큰 노이즈로 섞이고, 흙 반점·풀결.
// dirt_path: 흙길은 따로 상자를 깔지 않고 이 셰이더가 paths(직사각형 목록)를 마스크로 받아 그린다.
//   가장자리는 노이즈로 울퉁불퉁하게 잔디와 섞이고, 긴 길엔 수레바퀴 자국 2줄 + 작은 자갈 점.
// 수치는 GameData.MAT_STYLES.grass_ground / dirt_path, 길 목록은 WorldBuilder.path_rect()
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform vec4 col_a : source_color = vec4(0.5, 0.72, 0.38, 1.0);
uniform vec4 col_b : source_color = vec4(0.42, 0.63, 0.33, 1.0);
uniform vec4 col_c : source_color = vec4(0.58, 0.76, 0.42, 1.0);
uniform vec4 col_d : source_color = vec4(0.47, 0.6, 0.35, 1.0);
uniform vec4 soil_col : source_color = vec4(0.55, 0.45, 0.3, 1.0);
uniform float patch_scale = 0.045;
uniform float soil_amount = 0.05;
uniform float blade = 0.08;

uniform vec4 path_col : source_color = vec4(0.84, 0.74, 0.52, 1.0);
uniform vec4 rut_col : source_color = vec4(0.66, 0.55, 0.37, 1.0);
uniform vec4 gravel_col : source_color = vec4(0.6, 0.58, 0.55, 1.0);
uniform float edge_noise = 0.7;
uniform float edge_soft = 0.25;
uniform float rut_off = 0.8;
uniform float rut_w = 0.22;
uniform float gravel = 0.12;
uniform vec4 paths[24];          // (가운데 x, 가운데 z, 반폭 x, 반폭 z)
uniform int path_count = 0;

void fragment() {
	vec2 p = v_wpos.xz;
	// 잔디: 큰 얼룩 (밝은 풀밭 / 짙은 풀밭)
	float n1 = fbm(p * patch_scale);
	float n2 = fbm(p * patch_scale * 2.7 + 13.0);
	vec3 g = mix(col_a.rgb, col_b.rgb, smoothstep(0.35, 0.65, n1));
	g = mix(g, col_c.rgb, smoothstep(0.55, 0.75, n2) * 0.7);
	g = mix(g, col_d.rgb, smoothstep(0.6, 0.8, fbm(p * 0.11 + 5.0)) * 0.6);
	// 흙 반점 드문드문
	float sp = vnoise(p * 1.3 + 2.0) * vnoise(p * 0.37);
	g = mix(g, soil_col.rgb, smoothstep(1.0 - soil_amount * 4.0, 1.0 - soil_amount * 3.0, sp) * 0.75);
	// 풀결 (아주 작은 노이즈, 멀면 녹임)
	float fine = vnoise(p * vec2(9.0, 23.0));
	g *= 1.0 - blade + blade * 2.0 * mix(fine, 0.5, far_fade(p, 0.12));
	// 흙길: 가장 안쪽인 직사각형 하나를 고름
	float best = 1e5;
	vec2 loc = vec2(0.0);
	vec2 half_sz = vec2(1.0);
	for (int i = 0; i < 24; i++) {
		if (i >= path_count) break;
		vec4 r = paths[i];
		vec2 q = p - r.xy;
		vec2 dd = abs(q) - r.zw;
		float sd = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0);
		if (sd < best) {
			best = sd;
			loc = q;
			half_sz = r.zw;
		}
	}
	float edge = best + (fbm(p * 0.9) - 0.5) * edge_noise * 2.0;
	float m = 1.0 - smoothstep(-edge_soft, edge_soft, edge);
	if (m > 0.001) {
		vec3 dirt = path_col.rgb * (0.9 + 0.2 * fbm(p * 1.7));
		// 수레바퀴 자국: 긴 길에서 길 방향을 따라 두 줄
		bool along_z = half_sz.y > half_sz.x;
		float across = along_z ? loc.x : loc.y;
		float minor = along_z ? half_sz.x : half_sz.y;
		float major = along_z ? half_sz.y : half_sz.x;
		if (major > minor * 1.6 && minor >= 1.2) {
			float rd = abs(abs(across) - rut_off);
			float wob = (vnoise(p * 0.6) - 0.5) * 0.15;
			float rut = 1.0 - smoothstep(rut_w * 0.5 - 0.06, rut_w * 0.5 + 0.06, rd + wob);
			dirt = mix(dirt, rut_col.rgb, rut * 0.8);
		}
		// 작은 자갈 점
		vec2 cell = floor(p / 0.35);
		vec2 cf = fract(p / 0.35) - 0.5;
		vec2 off = vec2(h21(cell), h21(cell + 9.1)) - 0.5;
		float pd = length(cf - off * 0.6) * 0.35;
		float peb = step(h21(cell + 3.3), gravel) * aa_line(pd, 0.05);
		dirt = mix(dirt, gravel_col.rgb * (0.85 + 0.3 * h21(cell + 1.7)), peb);
		g = mix(g, dirt, m);
	}
	ALBEDO = g;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
