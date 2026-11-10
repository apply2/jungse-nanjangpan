// roof_tiles: 반원 기와가 줄줄이 겹친 비늘 무늬. 줄마다 아래쪽 그림자, 기와마다 색 흔들림. 색은 지붕 원래 색(정점 색).
// 수치는 GameData.MAT_STYLES.roof_tiles
shader_type spatial;
#include "res://shaders/world_lib.gdshaderinc"

uniform vec2 tile = vec2(0.34, 0.24);   // 기와 폭 / 줄 간격 (m)
uniform float jitter = 0.12;
uniform float shade = 0.4;

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 n = face_normal();
	if (n.y < 0.0) n = -n;   // 화면 미분 법선은 방향이 뒤집힐 수 있음 → 지붕 면은 늘 위를 봄
	vec2 nh = n.xz;
	vec2 dir = length(nh) > 0.05 ? normalize(nh) : vec2(0.0, 1.0);   // 처마 쪽(내리막) 방향
	// 내리막 좌표: 수평 거리 + 높이 (경사를 따라 줄 간격이 비슷하게)
	vec2 uv = vec2(dot(v_wpos.xz, vec2(-dir.y, dir.x)), dot(v_wpos.xz, dir) - v_wpos.y * 0.6);
	float row = floor(uv.y / tile.y);
	float gx = uv.x / tile.x + mod(row, 2.0) * 0.5;
	vec2 id = vec2(floor(gx), row);
	vec2 f = vec2(fract(gx), fract(uv.y / tile.y));
	// 기와 아래 끝 = 반원. 원 밖(아래 모서리)은 아랫줄 기와 = 윗줄 기와의 그림자 안
	float s = length(vec2(f.x - 0.5, max(f.y - 0.45, 0.0) * 1.35));
	float fw = max(fwidth(s), 1e-4);
	float inside = 1.0 - smoothstep(0.5 - fw, 0.5 + fw, s);
	float h = h21(id);
	vec3 c = base * (1.0 + (h - 0.5) * 2.0 * jitter);
	c *= mix(1.0 - shade, 1.0, inside * (0.75 + 0.25 * f.y) + (1.0 - inside) * 0.6);
	c *= 1.0 - 0.3 * (1.0 - inside) * (1.0 - smoothstep(0.5, 0.62, s));   // 윗줄 기와 바로 아래 진한 그림자
	c = mix(c, base * 0.88, far_fade(uv, tile.y * 0.6) * 0.75);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
