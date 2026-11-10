// wood_plank: 판자 (폭 0.22m, 사이 어두운 틈, 판자마다 색 흔들림 + 나뭇결).
// vertical = false면 가로 판자 (상자·좌판·울타리), true면 세로 판자 (문·덧문·기둥 — 재질 "wood_plank_v").
// 수치는 GameData.MAT_STYLES.wood_plank / wood_plank_v
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform float plank_w = 0.22;
uniform float gap = 0.018;
uniform vec4 gap_col : source_color = vec4(0.12, 0.08, 0.05, 1.0);
uniform float jitter = 0.14;
uniform float grain = 0.12;
uniform float joint_len = 1.6;
uniform bool vertical = false;

void fragment() {
	vec3 base = COLOR.rgb;
	int ax;
	vec2 uv = face_uv(v_wpos, face_normal(), ax);
	vec2 q = (vertical && ax != 1) ? uv.yx : uv;   // q.x = 판자 길이 방향, q.y = 가로지르는 방향
	float across = q.y / plank_w;
	float id = floor(across);
	float fa = fract(across);
	float along = q.x / joint_len + h21(vec2(id, 2.0));
	float jid = floor(along);
	float fj = fract(along);
	float d = min(min(fa, 1.0 - fa) * plank_w, min(fj, 1.0 - fj) * joint_len);
	float h = h21(vec2(id, jid));
	vec3 c = base * (1.0 + (h - 0.5) * 2.0 * jitter);
	float g = sin((fa * 7.0 + vnoise(vec2(q.x * 0.9, id * 3.0)) * 3.0) * 6.2831);
	c *= 1.0 - grain * smoothstep(0.5, 1.0, g);
	c = mix(c, gap_col.rgb, aa_line(d, gap * 0.5));
	c = mix(c, base * 0.92, far_fade(uv, plank_w) * 0.85);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
