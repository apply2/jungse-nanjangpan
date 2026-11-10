// 맵 재질 셰이더 공용 함수 (맵 꾸미기 — 사용자 요청).
// 무늬는 이미지 대신 계산한다. 좌표는 월드 좌표(m)라서 상자 크기·방향과 상관없이 벽돌 크기가 같다.
// 상자는 축에 맞춰 놓이므로 "가장 큰 법선 축" 하나로 투영한다 (세 방향 섞는 트라이플래너보다 싸고 줄눈이 또렷함).
// 줄눈 경계는 fwidth로 부드럽게, 멀리서는 무늬를 평균색으로 녹여서 지글거리지 않게 한다.
// 바탕색은 정점 색(COLOR — 엔진이 이미 선형으로 바꿔서 줌) — 맵의 상자 색이 그대로 들어온다. 그래서 같은 무늬는 재질 하나로 합쳐 그린다.

varying vec3 v_wpos;
varying vec3 v_wn;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

vec3 srgb2lin(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

// 면의 실제 법선 (화면 미분 — 매끈하게 보간된 법선 대신 평평한 면 방향)
vec3 face_normal() {
	vec3 n = normalize(cross(dFdx(v_wpos), dFdy(v_wpos)));
	return n;
}

// 가장 큰 법선 축으로 투영한 면 좌표(m). axis: 0 = x를 보는 면, 1 = 윗면/아랫면, 2 = z를 보는 면
vec2 face_uv(vec3 p, vec3 n, out int axis) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		axis = 1;
		return p.xz;
	}
	if (a.x >= a.z) {
		axis = 0;
		return vec2(p.z, p.y);
	}
	axis = 2;
	return vec2(p.x, p.y);
}

// 경계까지 거리 d(m)가 w보다 작으면 1 (fwidth로 1픽셀 부드럽게)
float aa_line(float d, float w) {
	float f = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(w - f, w + f, d);
}

// 무늬가 화면에서 얼마나 작아졌나 (0 = 가까움, 1 = 너무 작아서 평균색으로 녹임). cell = 무늬 한 칸 크기(m)
float far_fade(vec2 uv, float cell) {
	float px = length(fwidth(uv));
	return smoothstep(cell * 0.18, cell * 0.5, px);
}

// 러닝 본드 벽돌: x = 줄눈(1), y·z = 벽돌 번호, w = 가장자리까지 거리(m)
vec4 bricks(vec2 uv, vec2 size, float mortar) {
	vec2 g = uv / size;
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5;
	vec2 id = vec2(floor(g.x), row);
	vec2 f = fract(g);
	vec2 dm = min(f, 1.0 - f) * size;
	float d = min(dm.x, dm.y);
	return vec4(aa_line(d, mortar * 0.5), id, d);
}

// 벽돌 한 장 색 (집·굴뚝·우물·회벽이 벗겨진 곳)
vec3 brick_albedo(vec2 uv, vec3 base, vec2 size, float mortar, vec3 mortar_c, float jitter, float odd_chance, vec3 odd_c, float edge_dark) {
	vec4 b = bricks(uv, size, mortar);
	float h = h21(b.yz);
	vec3 c = base * (1.0 + (h - 0.5) * 2.0 * jitter);
	if (h21(b.yz + 17.3) < odd_chance) {
		c = mix(c, odd_c, 0.7);
	}
	c *= 1.0 - edge_dark * (1.0 - smoothstep(mortar * 0.5, mortar * 2.5, b.w));  // 가장자리 살짝 어둡게 (입체감)
	c *= 0.94 + 0.12 * vnoise(uv * 9.0);
	c = mix(c, mortar_c, b.x);
	float ff = far_fade(uv, size.y);
	vec3 avg = mix(base, mortar_c, mortar / size.y);
	return mix(c, avg, ff);
}
