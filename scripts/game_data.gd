extends Node
## 게임 전체 수치·규칙 데이터 (오토로드 이름: GameData)
## reference/arrow-arena.html 의 CLASSES / WEAPONS / DIFF / 상수를 그대로 옮긴 것.
## 밸런스를 바꿀 땐 이 파일만 고치면 된다. 색은 0xRRGGBB 정수 → col()로 Color 변환.

# ── 공통 상수 (HTML 386번째 줄) ──────────────────────────────
const FALL_TIME := 0.6       # 넘어져 있는 시간(초)
const LAND_TRIP := 0.2       # 점프하고 착지할 때 넘어질 확률 (사용자 요청으로 다시 넣음)
const HEADSHOT := 1.5        # 투구 쓴 머리 배율
const BARE_HEAD := 2.0       # 투구 벗겨진 머리 배율
const SPRINT := 1.35         # 달리기 배율 (Shift)
const HORSE_TIME := 7.0      # 말 탑승 시간
const HORSE_SPEED := 20.5    # 말 속도 m/s
const MOUNT_H := 0.95        # 말 위 높이
const BASE_SPEED := 5.4      # 기본 걷기 속도 m/s (병과 speed 배율을 곱함)
const JUMP_V := 8.0
const GRAV := 22.0
const MATCH_TIME := 240.0
const KILL_LIMIT := 20
const BOT_COUNT := 7
const RESPAWN := 3.0
const ARENA := 44.4          # 이동 가능 범위 (±)
const STEP_H := 0.56         # 자동으로 올라가는 턱 높이
const STEP_PROBE := 0.12     # 턱 오르기 검사 때 벽 안쪽으로 더 밀어 봄 (비스듬히 걸어도 올라가게 — 사용자 요청)

# ── 피해·처치·부활 (HTML damage / hitTest / spawn / simulate) ──
const HEAD_R := 0.3          # 머리 판정 반지름 (+투사체 반지름)
const BODY_R := 0.46         # 몸통 캡슐 반지름 (+투사체 반지름)
const REGEN_DELAY := 5.0     # 이 시간 동안 안 맞으면 재생 시작
const REGEN := 10            # 기본 초당 회복량 (병과 regen으로 덮어씀)
const INVULN := 1.2          # 스폰 직후 무적
const SPAWN_PICK := 4        # 가장 먼 스폰 지점 몇 곳 중에서 고를지
const BOT_RECLASS := 0.35    # 봇이 죽을 때 병과를 바꿀 확률
const KB_TIME := 0.45        # 맞은 뒤 마찰 감소·속도 상한 해제 시간
const KB_TIME_AK := 0.12
const BOT_STAGGER := 0.3     # 봇 경직
const BOT_STAGGER_XBOW := 0.5
const HEAD_KB := 1.25        # 헤드샷 넉백 배율
const HEAD_UP := 1.15        # 헤드샷 띄우기 배율
const MOUNT_KB := 0.2        # 말 탄 대상 넉백 배율
const HIT_WOB := {"crossbow": 14.0, "bow": 10.0, "holy": 2.5, "ak": 2.5, "trumpet": 1.0, "fanfare": 10.0}  # 맞은 쪽으로 몸 출렁 (나머지 6)
const HIT_WOB_DEFAULT := 6.0
const HIT_WOB_HEAD := 1.3

# ── 투사체 발사 (HTML fire / updateProjectiles) ──
## 3인칭 캐릭터가 손(트럼펫은 입)에 든 무기 크기 배율 — 보기만 (판정·사거리·뷰모델·투사체 그대로, 사용자 요청: 잘 안 보여서)
## 무기 그룹 원점(손잡이·마우스피스) 기준으로 커진다. 닭은 원래 0.75로 줄여 둔 값에 곱함
## lance: 탄 사람 말의 마상창 — 굵기만 (길이를 늘리면 판정 창끝 3.5m보다 길어 보임), 창끝 뾰족한 부분은 tip배 (끝점은 그대로)
const HELD_SCALE := {
	"stone": 1.7, "bow": 1.45, "crossbow": 1.4, "holy": 1.6, "trumpet": 1.35,
	"sniper": 1.3, "ak": 1.45, "chicken": 1.35,
	"lance": {"thick": 1.6, "len": 1.0, "tip": 1.3},
}
## 내 캐릭터만 다르게 할 무기 (어깨 너머 화면에서 조준점을 가리면). 없는 무기는 HELD_SCALE
const HELD_SCALE_SELF := {"chicken": 1.0}  # 닭: 1.35면 어깨 너머 화면에서 조준점 둘레(화면 높이 10%)를 13%, 1.1이면 1% 가려서 내 닭만 원래 크기
const FIRE_FWD := 0.35       # 눈에서 조준 방향으로 이만큼 앞에서 나감
const FIRE_DROP := 0.08      # 내가 쏠 땐 살짝 아래에서 (손 위치 느낌)
const FIRE_RIGHT := {"stone": 0.12, "bow": 0.16}  # 내가 쏠 땐 오른쪽으로 (나머지 0.08)
const FIRE_RIGHT_DEFAULT := 0.08
const PROJ_LIFE := 4.0       # 사거리(range)가 없는 투사체의 수명(초)
const PROJ_CULL := 3.0       # 이번 이동 거리 + 이만큼보다 먼 캐릭터는 판정 생략
const TP_AIM_DIST := 300.0   # 3인칭: 화면 가운데가 가리키는 곳을 찾는 거리
const TP_AIM_R := 0.05       # 그때 캐릭터 판정 반지름
const THROW_ANIM := 5.0      # 던지기 팔 모션 속도 (돌멩이·성수, 나머지 3)
const FIRE_ANIM := 3.0

# ── 화살·볼트 (HTML makeArrow / stickArrow / worldArrows) ──
# len 길이, r 굵기, shaft 화살대 색, tip 촉 굵기, fletch 깃 색
const ARROWS := {
	"bow": {"len": 0.75, "r": 0.012, "shaft": 0xd9b27a, "tip": 0.028, "fletch": 0xd2463c},
	"crossbow": {"len": 0.5, "r": 0.018, "shaft": 0x6b4a2e, "tip": 0.035, "fletch": 0x2c2f35},
}
const ARROW_TIP := 0x8d939b
const WORLD_ARROW_LIFE := 10.0   # 벽·땅에 꽂힌 화살이 남는 시간
const WORLD_ARROW_MAX := 70      # 넘으면 오래된 것부터 지움
const BOW_WOOD := 0x8a5a2b
const BOW_STRING := 0xf3ead2
const XBOW_PROD := 0x5b5f66   # 석궁 활대(쇠)
const XBOW_NUT := 0x3a3e46    # 걸쇠

# ── 반동 (HTML fire의 recV / vRecV, animModel·updateVM의 스프링) ──
# 몸(3인칭 팔·상체)이 튕기는 양 = rec[0] + rec[1]×당긴 정도, 1인칭 화면·손 = vrec[0] + vrec[1]×당긴 정도
const RECOIL := {"bow": {"rec": [5.0, 4.0], "vrec": [4.0, 4.0]}, "crossbow": {"rec": [10.0, 0.0], "vrec": [11.0, 0.0]},
	"ak": {"rec": [1.2, 0.0], "vrec": [1.4, 0.0]}}
const VREC_CAM := 0.022          # 화면이 위로 튕기는 양 (조준 방향은 그대로)

# ── 우클릭 조준 시 카메라 (HTML updateCamera) ──
const AIM_CAM := {"bow": {"tp_fov": 64.0, "fp_fov": 72.0}, "crossbow": {"tp_fov": 55.0, "fp_fov": 58.0},
	"ak": {"tp_fov": 47.0, "fp_fov": 53.0}}  # AK = 75/1.6, 85/1.6
const SCOPE_FOV := 24.0      # 저격총 스코프 (우클릭)
const MOUNT_CAM := 5.0       # 말 타면 3인칭 카메라가 뒤로
const AIM_TP_DIST := 2.3         # 3인칭 조준 중 카메라 거리 (평소 3.6)
const AIM_TP_RIGHT := 0.85       # 3인칭 조준 중 어깨 옆 거리 (평소 1.0)

# ── 1인칭 무기 화면 (HTML vmCam / buildVM / updateVM) ──
const VM_FOV := 60.0
const VM_KICK := {"sniper": 1.0, "ak": 0.12, "crossbow": 0.0, "bow": 0.0}  # 쏘면 손이 앞뒤로 튐 (나머지 0.2)
const VM_KICK_DEFAULT := 0.2

# ── 성수 웅덩이 (HTML shatter / updateZones / updateHolyAim) ──
const HOLY := {
	"glass": 0x9fe4ff, "glass_emit": 0x1f5a78, "glass_alpha": 0.78, "cork": 0x9a6a3a, "cross": 0xf3b33d,
	"size": 1.15,             # 날아가는 병 크기 배율
	"disc": 0x8fdcff, "disc_alpha": 0.42,
	"rim_mine": 0xffe07a, "rim_enemy": 0xff3b30, "rim_alpha": 0.8,  # 내 웅덩이 금색, 적 웅덩이 빨강
	"first_tick": 0.15,       # 깨진 뒤 첫 피해까지
	"grow": 0.15,             # 웅덩이가 퍼지는 시간
	"fade": 0.4,              # 끝날 때 흐려지는 시간
	"edge": 0.3,              # 판정 반경 = area + edge
	"y_below": 0.4, "y_above": 1.6,  # 웅덩이 높이 기준 판정 범위
	"slow_hold": 0.2,         # 안에 있으면 매 프레임 둔화를 이만큼 채움
	"aim_steps": 90, "aim_dt": 0.04,  # 착지 지점 표시: 궤적 시뮬레이션
	"aim_alpha": 0.8, "aim_alpha_off": 0.25,  # 못 던질 때(대기·빈 병)는 흐리게
}

# ── 병과 ─────────────────────────────────────────────────────
# speed: BASE_SPEED 배율 / hp: 없으면 100 / regen: 초당 회복량(기본 10, 5초간 안 맞으면 시작)
const CLASSES := {
	"barbarian": {"name": "야만인", "weapon": "stone", "speed": 1.372, "hp": 90,
		"color": 0xf28a1e, "leg": 0xf2c7a0, "arm": 0xf2c7a0, "foot": 0xe9b48e, "pips": [5, 1, 1, 5],
		"desc": "가장 빠르다. 바짝 붙어서 돌멩이를 퍼붓는 돌격형."},
	"archer": {"name": "궁수", "weapon": "bow", "speed": 1.0556, "hp": 100,  # 걷기 5.7 m/s (사용자 요청으로 5.4→5.7 버프)
		"color": 0xb8322a, "leg": 0x8b939c, "arm": 0x7d858f, "foot": 0x5b6068, "pips": [3, 3, 3, 3],
		"desc": "당길수록 세지는 활로 중거리를 견제한다."},
	"crossbow": {"name": "석궁병", "weapon": "crossbow", "speed": 0.85, "hp": 110,
		"color": 0x4d72b8, "leg": 0x8b939c, "arm": 0x7d858f, "foot": 0x5b6068, "pips": [2, 4, 4, 1],
		"desc": "느리지만 한 발이 묵직하다. 머리에 맞히면 한 방."},
	"cleric": {"name": "성직자", "weapon": "holy", "speed": 1.0, "hp": 100, "regen": 20,
		"color": 0xeee6d2, "leg": 0xeee6d2, "arm": 0xeee6d2, "foot": 0x8a5a32, "pips": [3, 2, 3, 2],
		"desc": "성수병을 3개까지 모아 연달아 던진다. 3초간 남는 웅덩이가 밟은 적을 지지고 느리게 만든다. 체력 회복이 두 배 빠르다."},
	# 4.5단계 (HTML에 없는 새 병과). 투구 자리엔 긴 깃털 달린 납작한 베레모 — 헤드샷이면 투구처럼 날아감
	# pips는 명세에 없어서 임시로 정함 (이동 조금 빠름 · 피해 약함 · 사거리 짧음 · 계속 연주)
	"bard": {"name": "음유시인", "weapon": "trumpet", "speed": 1.05, "hp": 95,
		"color": 0x7a3fa8, "leg": 0xf3b33d, "arm": 0x7a3fa8, "foot": 0x5b3a22, "pips": [3, 1, 2, 5],
		"desc": "트럼펫을 불어 적을 춤추게 만든다. 춤추는 적은 느리고 조준이 흔들린다."},
}
const CLASS_ORDER := ["barbarian", "archer", "crossbow", "cleric", "bard"]
const STAT_LABELS := ["이동속도", "공격력", "사거리", "연사"]  # 병과 카드의 pips 순서
const CLASS_EMBLEM := {"barbarian": 0xe8811f, "archer": 0xb8322a, "crossbow": 0x4d72b8, "cleric": 0x8c63c9, "bard": 0x7a3fa8}  # 카드 동그라미
const CLASS_CHIP := {"barbarian": 0xf2a04e, "archer": 0xe8857a, "crossbow": 0x9fc0ea, "cleric": 0xcdb8ef, "bard": 0xc9a2e8}    # 점수판 꼬리표

# ── 무기 ─────────────────────────────────────────────────────
# 단위: dmg 피해, cd 재사용(초), speed 투사체 속도(m/s), grav 중력, kb 넉백, up 띄우기, radius 판정 반경
const WEAPONS := {
	"stone": {"name": "돌멩이", "dmg": 10, "cd": 0.4, "speed": 32, "grav": 16, "range": 15, "kb": 4, "up": 2.6, "radius": 0.12,
		"color": 0x8b8f96, "size": 0.11},  # size: 돌 모양 반지름 (손에 든 것·날아가는 것)
	# 사용자 요청 궁수 버프 (계속 압박하는 무기): 짧게 끊어 연사, 꽉 당기면 세고 곧게. 차지 비율 = bow_t(당긴 시간)
	# nock: 쏜 뒤 다음 화살 거는 시간 (1.0→0.3) / full: 끝까지 당기는 시간 (1.5→1.0)
	# min_charge: 최소 당김 (0.08→0.15). 이보다 빨리 놓으면 min_charge까지 마저 당긴 뒤 최소 세기로 쏜다
	# dmg·speed는 차지 비율 0→1로 보간 (35~55 → 15~50: 0.45초마다 연사하니 한 발은 약하게. 속도 42→28로 약할수록 크게 휨)
	# 끝까지 당긴 채 sway_start초가 지나면 후들거림(진폭 sway_k×초, 최대 sway_max), slip_t초가 되면 손이 미끄러짐
	"bow": {"name": "활", "dmg_min": 15, "dmg_max": 50, "nock": 0.3, "full": 1.0, "speed_min": 28, "speed_max": 72,
		"grav": 14, "kb": 6.5, "up": 3.4, "radius": 0.05, "min_charge": 0.15,
		"sway_start": 1.0, "sway_k": 0.05, "sway_max": 0.11, "slip_t": 3.0, "slip_yaw": 0.6, "slip_pitch": [-0.35, 0.55]},
	# 사용자 요청 휠 장전 (예전: 쏜 뒤 4초 자동 장전): 쏜 뒤 마우스 휠을 notches칸 굴려야 다시 쏜다.
	#   휠 위·아래 다 됨, 중간에 멈춰도 진행도 유지, 장전돼 있으면 휠 무시, 부활하면 장전된 채 (예전에도 부활하면 바로 쏠 수 있었음)
	#   notches: 사용자 요청으로 10→25칸
	#   notch_gap: 한 칸으로 치는 최소 간격(실제 시간). 이 안에 들어온 휠은 버림 — 프리스핀 휠·터치패드로 순식간에 감지 못하게.
	#              사용자 요청으로 0.15→0.04 (가장 빨라도 25칸 ≈ 1초)
	#   reload_speed: 휠로 감는 중 이동 속도 배율 (사용자 요청 0.9→0.75 = 25% 느려짐). 곱연산 (달리기 등과 같이 곱함)
	#   reload_window: 마지막 휠 칸 뒤 이만큼은 '감는 중'으로 봄 (칸 사이에 속도가 튀지 않게). 다 감으면 바로 풀림
	#   show_rate: 장전 모션이 진행도를 따라가는 속도 (초당) / cd: 쏜 직후 휠도 안 먹는 시간
	#   grav 6→2 (사용자 요청: 거의 직선, 85m에서 0.7m 떨어짐)
	"crossbow": {"name": "석궁", "dmg": 75, "reload_speed": 0.75, "reload_window": 0.3, "notches": 25, "notch_gap": 0.04, "show_rate": 3.0, "cd": 0.25,
		"speed": 100, "grav": 2, "kb": 11, "up": 5, "radius": 0.05},
	"sniper": {"name": "대물 저격총", "ammo": 5, "kb": 0, "speed_mul": 0.9},
	"ak": {"name": "AK-47", "dmg": 23, "min_dmg": 18, "fall0": 30, "fall1": 80, "range": 120, "rate": 0.12, "mag": 25,
		"kb": 1.2, "up": 0, "hip": 0.03, "ads": 0.006, "bloom": 0.006, "max_bloom": 0.05, "speed_mul": 0.95, "zoom": 1.6, "swap": 0.3},
	"chicken": {"name": "닭", "dmg": 1, "kb": 5, "up": 3, "speed": 24, "lift": 5, "grav": 18, "radius": 0.3},
	"lance": {"name": "마상창", "dmg": 70, "kb": 28, "up": 9},
	"star": {"name": "황금 붕어빵", "dmg": 20, "kb": 18, "up": 6},  # 무적 몸박치기 (큰 넉백)
	"holy": {"name": "성수", "cd": 0.4, "max_charges": 3, "recharge": 3.0, "slow": 0.35,  # slow: 웅덩이 속 이동 배율 (65% 느려짐, 사용자 요청으로 0.25→0.35)
		 "speed": 19, "lift": 5.5,
		"grav": 20, "radius": 0.14, "kb": 0, "dmg": 8, "tick_every": 0.5, "dur": 3.0, "area": 3.0,
		"heal": 4.0},  # heal: 웅덩이에 닿아 있는 동안 초당 회복 — 던진 사람 (개인전·쟁탈전), 쟁탈전은 같은 팀도 (사용자 요청)
	# 트럼펫 (음유시인, 4.5단계). 좌클릭 = 연주(누르는 동안), 우클릭 = 팡파레 (조준 확대 없음)
	# 연주: 앞쪽 원뿔(range m, 반각 half_angle 도) 안의 적에게 tick초마다 dmg. 벽 뒤는 안 들림. 넉백 없음, 피해 숫자는 dot 스타일
	# 숨: 최대 breath_max초 연주, 안 불면 초당 breath_regen 회복. 다 쓰면 gasp_t초 동안 연주 못 하고 이동 ×gasp_speed
	# 삑사리: 연주를 시작할 때마다 squeak_chance 확률, squeak_t초 동안 연주 안 됨
	# 연출: 연주 중 볼 크기 cheek 배, 음마다 ±detune 센트 음정 틀어짐
	"trumpet": {"name": "트럼펫", "range": 12.0, "half_angle": 25.0, "tick": 0.25, "dmg": 3.0, "kb": 0, "up": 0,
		"breath_max": 3.0, "breath_regen": 1.5, "gasp_t": 1.0, "gasp_speed": 0.8,
		"squeak_chance": 0.05, "squeak_t": 0.8,
		"cheek": 1.6, "detune": 20.0,
		# 공격 이펙트 (보기만 함 — 판정과 무관, 네트워크로 안 보냄). scripts/fx/bard_fx.gd가 씀
		"fx": {
			# 1. 날아가는 음표: note_every초마다 1개 (double 확률로 ♫), speed m/s, 좌우 꿀렁 wobble m·wobble_hz, 빙글 spin rad/s
			#    pop_t초 동안 톡 튀어나오고, 사거리의 fade_from부터 흐려짐. 벽에 닿으면 bounce_t초 튕기고 사라짐
			#    한 명당 per_bard개, 전체 max개 (넘으면 오래된 것부터 재활용). glow = 색 밝기 배율 (살짝 발광)
			"note_every": 0.08, "double": 0.2, "speed": 14.0, "wobble": 0.35, "wobble_hz": 3.0, "spin": 7.0,
			"size": 1.5, "pop_t": 0.1, "fade_from": 0.75, "bounce_t": 0.18, "bounce_v": 2.5,
			"per_bard": 24, "max": 120, "glow": 1.15,
			"colors": [0xf3b33d, 0xff7eb6, 0x7fd3ff, 0xa6e35a],
			# 2. 음파 고리: 판정 주기(tick)마다 나팔 끝에서 퍼짐. wave_life초, 불투명도 wave_alpha, 고리 두께 비율 wave_inner
			"wave_life": 0.4, "wave_alpha": 0.3, "wave_inner": 0.93, "wave_col": 0xfff1b0,
			# 3. 맞은 적: 틱마다 머리 위 작은 음표 (pop_*), 춤 게이지 음표 (gauge_*: 최대 3개, 반지름·높이·도는 속도·크기)
			"pop_life": 0.6, "pop_up": 1.8, "pop_size": 1.1,
			"gauge_r": 0.42, "gauge_h": 0.62, "gauge_spin": 3.0, "gauge_size": 1.1,
			#    춤 시작: 색종이 confetti조각, "춤춰라!", 디스코 조명 (꼭대기 disco_top m, 바닥 반지름 disco_r, 불투명도, disco_swap초마다 색 바뀜)
			#    춤 음표 dance_n개가 dance_r 반지름으로 dance_spin rad/s 돎. 끝나면 조명이 disco_out초 동안 위로 빨려 올라감
			"confetti": 20, "confetti_cols": [0xff4fa3, 0x4fd8ff, 0xffe14f, 0x8cff6a, 0xb06bff, 0xffffff],
			"dance_text": "춤춰라!", "disco_top": 3.4, "disco_r": 0.95, "disco_alpha": 0.22, "disco_swap": 0.2, "disco_out": 0.35,
			"disco_cols": [0xff4fa3, 0x4fd8ff, 0xffe14f, 0x8cff6a, 0xb06bff],
			"dance_n": 3, "dance_r": 0.5, "dance_h": 0.7, "dance_spin": 5.0, "dance_size": 1.3,
			#    면역 중: 회색 음표 하나가 비스듬히 (immune_tilt rad)
			"immune_col": 0x9a9a9a, "immune_tilt": 0.6, "immune_size": 1.2,
			# 4. 팡파레: 원판 충격파 (fan_r m, fan_t초), 큰 음표 fan_notes개 부채꼴 (속도·크기), 색종이·흙먼지, 1인칭 흔들림
			"fan_r": 3.5, "fan_t": 0.25, "fan_alpha": 0.45, "fan_notes": 12, "fan_note_speed": 9.0, "fan_note_size": 2.4,
			"fan_confetti": 10, "fan_dust": 0xc8b08a, "fan_shake": 0.2, "fan_hit_size": 2.2,
			# 5. 삑사리: 찌그러진 회색 음표 + 회색 연기 + "삑!"
			"squeak_col": 0x8a8a8a, "squeak_text": "삑!", "squeak_life": 0.9,
			# 6. 숨 참: 땀방울 sweat개 (하늘색), 하얀 김, 볼이 deflate_t초 동안 deflate_to배까지 쪼그라듦
			"sweat": 3, "sweat_col": 0x7fd3ff, "steam_col": 0xffffff, "deflate_t": 0.3, "deflate_to": 0.7,
			# 7. 1인칭: 내 음표는 카메라 앞 fp_start m부터, 조준점 둘레(화면 높이의 fp_clear) 비켜 감, 불투명도 fp_alpha
			#    내가 춤추면 분홍 테두리 (vig_col, vig_alpha), 테두리를 도는 음표 edge_notes개, 카메라 까딱 (bob rad, bob_hz)
			"fp_start": 1.0, "fp_clear": 0.08, "fp_alpha": 0.6,
			"vig_col": 0xff7eb6, "vig_alpha": 0.6, "edge_notes": 12, "bob": 0.035, "bob_hz": 2.2,
			# 풀 크기 (deco: 작은·큰 음표, bits: 색종이)
			"deco_max": 96, "bits_max": 160,
		}},
	# 팡파레 (음유시인 우클릭): 앞쪽 range m, 반각 half_angle 도 안의 적에게 dmg, 넉백 kb, 띄우기 up, 재사용 cd초
	"fanfare": {"name": "팡파레", "range": 3.5, "half_angle": 45.0, "dmg": 15, "kb": 9, "up": 3, "cd": 6.0},
}

# ── 춤 디버프 (트럼펫, 4.5단계) ──────────────────────────────
# 원뿔 안에 window초 동안 누적 need초 이상 있으면 dur초 동안 춤. 끝나면 immune초 동안 다시 안 춤
# 춤추는 동안 이동 ×speed, 봇 조준 오차 ×bot_err. 공격은 못 함 (사용자 요청으로 바꿈), 이동 조작은 안 뺏음
# 넘어짐(fall_t)이 우선 — 넘어지면 춤은 멈추고 남은 시간은 사라짐
# 아래 연출 값은 명세에 없어서 정함: sway 플레이어 조준 출렁(라디안)·sway_hz 출렁 빠르기,
# spin_every 몇 초마다 한 바퀴·spin_t 한 바퀴 도는 시간 (춤 음표는 WEAPONS.trumpet.fx)
const DANCE := {"window": 1.5, "need": 0.75, "dur": 2.0, "immune": 3.0, "speed": 0.6, "bot_err": 2.5,
	"sway": 0.06, "sway_hz": 1.6, "spin_every": 1.1, "spin_t": 0.45}

# 트럼펫·음유시인 모양 색 (명세: 금색 트럼펫, 깃털 달린 납작한 베레모)
const TRUMPET_LOOK := {"brass": 0xf3b33d, "brass_dark": 0xb97a14, "beret": 0x4b2370, "feather": 0xf4ecd6, "feather_tip": 0xd94a3a,
	"cheek": 0xf3a5a0,
	# 화려한 의상 (사용자 요청): 조끼 앞 마름모 무늬(금·청록), 하얀 주름 깃, 부푼 어깨(금 + 보라 줄), 들쭉날쭉 밑단, 빨간 망토(금 테), 등에 류트, 베레모 브로치·두 번째 깃털
	"diamond": 0x2fb8a8, "ruff": 0xfff6e6, "cape": 0xd94a3a, "lute": 0xc98a4a, "lute_dark": 0x6b4226, "gem": 0xe23d6b}

# 트럼펫 소리 (AudioStreamGenerator로 실시간 합성): 톱니파 + 비브라토 + 로우패스
# melody: base_hz 기준 반음 수 (도-미-솔-미-도-솔-도), note 한 음 길이(초), gap 음 사이 쉼
const TRUMPET_SND := {"base_hz": 523.25, "melody": [0, 4, 7, 4, 0, 7, 12], "note": 0.16, "gap": 0.025,
	"vib_hz": 6.0, "vib_cents": 18.0, "lowpass": 2400.0, "vol": 0.22, "rate": 22050}

# ── 봇 난이도 ────────────────────────────────────────────────
const DIFF := {
	"easy": {"name": "쉬움", "react": [1.0, 1.5], "err": 1.5, "sniper_err": 0.09, "head": 0.0, "lead": [0.0, 0.4], "fire": 0.5, "turn": 2.4,
		"xbow_wind": 10.0,  # 봇 석궁 휠 감기 (초당 칸 수 — 25칸에 2.5초 / 1.9초 / 1.6초. 사람이 가장 빠르면 1초)
		"color": 0x6cc35a, "skulls": "●○○", "desc": "봇이 늦게 반응하고 자주 빗나가요. 넘어지는 데 적응하기 좋아요."},
	"normal": {"name": "보통", "react": [0.7, 1.1], "err": 1.0, "sniper_err": 0.06, "head": 0.03, "lead": [0.1, 0.6], "fire": 0.65, "turn": 3.2,
		"xbow_wind": 13.0,
		"color": 0xf3b33d, "skulls": "●●○", "desc": "적당히 맞히고 적당히 넘어져요. 기본 난이도예요."},
	"hard": {"name": "어려움", "react": [0.4, 0.7], "err": 0.6, "sniper_err": 0.035, "head": 0.1, "lead": [0.4, 0.9], "fire": 0.85, "turn": 4.5,
		"xbow_wind": 16.0,
		"color": 0xe5484d, "skulls": "●●●", "desc": "빨리 반응하고, 움직임을 읽고, 헤드샷도 노려요."},
}

# ── 봇 AI (HTML botUpdate / aimSolve). 난이도별 값은 DIFF, 나머지 공통 값은 여기 ──
# 사용자 피드백으로 정확도를 두 번 낮춘 값이다. 너무 잘 맞히지 않게 유지할 것.
const BOT := {
	"think": [0.3, 0.55],        # 이 간격마다 대상·조준 오차를 새로 정함
	"sight": 65.0,               # 이 거리 안에서만 대상을 고름
	"hidden_mul": 2.4,           # 안 보이는 대상은 거리 ×2.4로 침
	"keep_bonus": 6.0,           # 지금 대상은 6m 가깝게 침 (자꾸 바꾸지 않게)
	"err": [0.09, 0.15],         # 기본 조준 오차(라디안) × 난이도 err
	"err_move": 0.6,             # 대상이 빠르면 오차 최대 +60% (속도 6m/s에서)
	"err_y": 0.7,                # 세로 오차는 가로의 70%
	"ak_err": 0.8,               # AK는 저격 오차 ×0.8
	"charge_dist": 34.0,         # 활: 거리/34 만큼 당김 (0.35~1)
	"charge_min": 0.35,
	"bard_play": 11.0,           # 음유시인: 대상이 이 거리 안이고 보이면 연주 (원뿔 반각 안으로 돌아섬)
	"bard_fanfare": 3.5,         # 음유시인: 이 거리 안이면 팡파레
	"bard_breath_stop": 0.5,     # 음유시인: 숨이 이만큼 남으면 멈추고 거리를 벌려 숨 회복
	"wander_reach": 3.0,         # 돌아다닐 지점에 이만큼 가까우면 새 지점
	"strafe_t": [0.6, 1.8],      # 좌우 무빙 방향을 바꾸는 간격
	"strafe_stop": 0.2,          # 무빙 안 할 확률
	"strafe_k": 0.9,
	"pref": {"barbarian": 4.0, "archer": 22.0, "crossbow": 30.0, "cleric": 15.0, "bard": 8.0},  # 병과별 선호 거리
	"pref_sniper": 28.0, "pref_ak": 16.0,
	"item_seek": 45.0, "horse_seek": 40.0, "fish_seek": 40.0,  # 황금 붕어빵은 40m
	"star_avoid": 10.0,          # 무적인 적에게서 이만큼은 도망감 (대상으로도 안 고름)  # 이 거리 안의 저격총·AK / 말은 주우러 감
	"item_busy": 8.0,            # 단, 보이는 적이 이보다 가까우면 싸움이 먼저
	"pref_band": 5.0,            # 선호 거리 ±5m면 다가가지도 물러나지도 않음
	"fire_range": {"stone": 15.5, "holy": 32.0, "chicken": 26.0, "crossbow": 85.0, "ak": 60.0},  # 없으면 제한 없음
	"knight_avoid": 12.0,        # 말 탄 사람 피하기 반경
	"zone_margin": 0.6,          # 남의 성수 웅덩이 반경 + 이만큼 안이면 밖으로 나감
	"smooth": 3.5,               # 이동 방향을 부드럽게 (급회전 넘어짐 줄이기)
	"stuck_speed": 1.2,          # 가려는데 이보다 느리면 끼었다고 봄
	"stuck_jump": 0.35,          # 끼인 지 이만큼이면 점프
	"stuck_turn": 0.9,           # 이만큼이면 아무 방향으로 0.8초 탈출
	"unstuck_t": 0.8,
	"barb_jump": 0.5,            # 야만인: 빠를 때 초당 점프 확률
	"barb_slide": 0.7,           # 야만인: 빠를 때 초당 슬라이드 확률
	"slide_hold": 0.6,
	"rand_jump": 0.35,           # 다른 병과: 초당 점프 확률
	"turn_idle": 4.0,            # 조준 안 할 때 회전 속도
	"aligned": 0.07, "aligned_sniper": 0.02, "aligned_pitch": 0.06,  # 이만큼 맞춰야 쏨
	"sprint_dist": 10.0,         # 대상이 이보다 멀면 달려서 쫓음
	"hit_react": 0.5,            # 맞으면 때린 사람을 대상으로, 반응은 최대 0.5초
	"aim_head": 1.6, "aim_body": 1.0,  # 노리는 높이 (발 기준)
	"lob_lead": 0.7,             # 성수·닭 앞질러 던지기 배율
	"lob_pitch": [-0.6, 1.0, 0.025],   # 포물선 각도 찾기 범위·간격
	"mount_lead": 0.35,          # 말 탔을 때 앞질러 돌진
}

const BOT_NAMES :=["감자 농부", "졸린 경비병", "수상한 수도사", "대장장이 올라프", "길 잃은 음유시인",
	"방앗간 한스", "늪지 마녀", "허풍쟁이 기사", "양치기 마르타", "술 취한 용병"]

# ── 게임 모드 (사용자 요청 — HTML엔 개인전만 있음) ─────────────
# ffa = 개인전 (기존 그대로), control = 쟁탈전 (5대5 거점 점령전, 오버워치 쟁탈 참고). 맵은 scripts/maps/map_control.gd
const MODE_NAMES := {"ffa": "개인전", "control": "쟁탈전"}
const MODES := {
	"control": {
		"name": "쟁탈전", "team_size": 5,          # AI대전: 나 + 아군 봇 4 vs 적군 봇 5
		"rounds_to_win": 2,                         # 3판 2선승
		"unlock": 15.0,                             # 라운드 시작 뒤 거점이 열리기까지
		"cap_half": 9.0, "cap_h": 4.0,              # 거점 = 정사각형 (가운데에서 가로·세로 ±9m, 18m × 18m — 사용자 요청으로 원 r7 → 네모) / 안으로 세는 높이 (단상 위로)
		"cap_time": 8.0,                            # 1명이면 이만큼 걸려 점령
		"cap_mul": [1.0, 1.0, 1.5, 2.0],            # 원 안 인원(0·1·2·3명 이상)별 배율
		"decay": 0.125,                             # 아무도 없으면 채워 둔 게이지가 초당 이만큼(1/8) 줄어듦
		"score_every": 0.9,                         # 거점을 가진 팀 %가 이 초마다 1%
		"overtime_at": 99,                          # 여기서 적이 원 안에 있으면 멈추고 연장전
		"round_max": 240.0,                         # 라운드가 이만큼 넘으면 %가 높은 팀 승리 (안전장치)
		"respawn": 5.0,                             # 쟁탈전 부활 시간 (개인전은 RESPAWN 3초 그대로)
		"spawn_heal": 100.0,                        # 스폰룸 안에서 초당 체력
		"round_gap": 6.0,                           # 라운드 사이 결과 화면
		"end_gap": 6.0,                             # 마지막 라운드 뒤 결과 화면까지
		"barrier_alpha": 0.16,                      # 스폰룸 문 막 (적만 막힘)
		# 팀 색: 몸 / 밝은 강조색 / 어두운 색(서코트·띠) / 성직자 옷(연한 색)
		"teams": {
			"blue": {"name": "블루팀", "short": "블루", "body": 0x3d6fd6, "accent": 0x8fb4ff, "dark": 0x2a4e9e, "pale": 0xc9d7f7, "ui": "#5d8fff", "ink": "#2f5cc0"},  # ink: 양피지 위 이름 글자
			"red": {"name": "레드팀", "short": "레드", "body": 0xd8453b, "accent": 0xff9a8f, "dark": 0x9e2e27, "pale": 0xf7cdc9, "ui": "#ff6a5f", "ink": "#b8322a"},
		},
		"neutral_col": 0xffffff, "locked_col": 0x8a8a8a,
		# 병과 색 덮어쓰기: 원래 색(hex) → 팀 색 역할 (body / accent / dark / pale). helm_ 붙은 건 투구(모자) 안에서만
		"paint": {
			"barbarian": {0xf28a1e: "body"},
			"archer": {0xb8322a: "body", 0x8a2620: "dark", 0xd2463c: "accent", 0xc8322a: "accent"},   # 화살 깃·투구 깃털
			"crossbow": {0x4d72b8: "body", 0x263f78: "dark", 0x3a62a8: "accent"},                   # 등 방패 그림
			"cleric": {0xeee6d2: "pale", 0x7a52b8: "accent", "helm_gold": "accent"},                 # 영대·모자 띠
			"bard": {0x7a3fa8: "body", 0xf4ecd6: "accent", 0xd94a3a: "accent"},                     # 조끼·모자 깃털
		},
		# 봇
		"bot_hold_in": 2,                           # 우리 거점이면 원 안에 이만큼, 나머지는 감시 지점
		"bot_roles": {"barbarian": "point", "cleric": "point", "bard": "point", "archer": "watch", "crossbow": "watch"},
		"lane_weight": {                            # 3갈래(왼쪽 시장 골목 / 가운데 큰길 / 오른쪽 성벽 길) 고르는 가중치
			"barbarian": [5, 2, 1], "archer": [1, 2, 4], "crossbow": [1, 2, 4], "cleric": [2, 3, 2], "bard": [3, 3, 1]},
		"lane_reach": 3.5,                          # 갈래 길 지점에 이만큼 다가가면 다음 지점으로
		"path_every": 0.6,                          # 경로 다시 찾기 간격
		"path_reach": 1.2,                          # 경로 점에 이만큼 다가가면 다음 점
		"no_camp": 16.0,                            # 적 스폰룸 입구에서 이 거리 안으론 쫓아가지 않음 (스폰킬 금지)
		"fight_r": 14.0,                            # 거점으로 가는 길에도 이 안의 보이는 적과는 싸움 (연장전·뺏김은 제외)
		"nav_cell": 0.25, "nav_cell_h": 0.1, "nav_agent_r": 0.5, "nav_agent_h": 1.8, "nav_climb": 0.5, "nav_slope": 46.0,  # 칸 크기의 배수로
		"marker_h": 2.55,                           # 아군 ▼ 표시 높이 (발 기준)
	},
}

# ── 맵 색상 (HTML의 C 객체) ──────────────────────────────────
const C := {
	"grass": 0x86cf5f, "grass_dark": 0x6fb34e, "path": 0xdcbd80, "stone": 0xbdb6a8, "stone2": 0x9c9586,
	"stone_dark": 0x857e70, "wood": 0xb98552, "wood_dark": 0x7a4f2c, "plaster": 0xf1e3c4, "roof_r": 0xc9533c,
	"roof_b": 0x4f6fa8, "hay": 0xe8c860, "leaf": 0x5aa84a, "leaf2": 0x6dbb55, "trunk": 0x7a5230, "gold": 0xf3b33d,
	"cloth": 0xe9dfc8, "skin": 0xf2c7a0, "sky": 0x9fd3f0,
	"roof_slate": 0x6f7684, "roof_brown": 0x9b6a45,  # 쟁탈전 맵 지붕 (팀 색 빨강·파랑과 안 헷갈리게)
	# 맵 꾸미기 (사용자 요청) 소품 색
	"brick": 0xb0614a, "iron": 0x3b3b42, "beam": 0x5c3b22, "glass": 0x3d4b6b, "ivy": 0x5c8a45, "ivy2": 0x6f9a52,
	"shutter_g": 0x5f7d5a, "shutter_b": 0x4f6a8a, "flower_r": 0xd9534a, "flower_y": 0xf0c94a, "flower_box": 0x7a5230,
	"torch_cup": 0x2e2e33, "flame": 0xff9a3c, "flame_core": 0xffe08a, "marble": 0xe8e1d2,
	"quoin": 0xd3cbb9, "slit": 0x2a2826, "knob": 0x1e1e22, "rope": 0xc9b58a,
}

# ── 맵 재질 (사용자 요청 — 무늬는 셰이더로 계산, shaders/ 폴더) ─────────────
# 맵 빌더가 box(…, style="brick")처럼 고르면 그 style의 재질로 그린다. 바탕색은 상자 색(정점 색) 그대로.
# 키 "shader" 말고는 전부 셰이더 uniform: 0x 정수 = 색, 나머지는 그대로 (float·Vector2·bool). 크기는 m.
# style ""(기본)은 지금처럼 단색.
const MAT_STYLES := {
	"brick": {"shader": "res://shaders/brick.gdshader", "brick_size": Vector2(0.5, 0.2), "mortar": 0.025,
		"mortar_col": 0xe6e0d4, "jitter": 0.12, "odd_chance": 0.08, "odd_col": 0x8a5a44, "edge_dark": 0.25, "cap_col": 0xb9b2a4},
	"castle_stone": {"shader": "res://shaders/castle_stone.gdshader", "block_h": 0.6, "block_len": Vector2(0.8, 1.6), "mortar": 0.05,
		"mortar_col": 0x5c5952, "jitter": 0.1, "blotch": 0.18, "moss_col": 0x667f45, "moss_h": 1.2, "ao": 0.35, "ao_h": 0.7},
	"wood_plank": {"shader": "res://shaders/wood_plank.gdshader", "plank_w": 0.22, "gap": 0.018, "gap_col": 0x2e2014,
		"jitter": 0.14, "grain": 0.12, "joint_len": 1.6, "vertical": false},
	"wood_plank_v": {"shader": "res://shaders/wood_plank.gdshader", "plank_w": 0.22, "gap": 0.018, "gap_col": 0x2e2014,
		"jitter": 0.14, "grain": 0.12, "joint_len": 2.4, "vertical": true},
	"plaster": {"shader": "res://shaders/plaster.gdshader", "stain": 0.07, "patch_scale": 0.32, "patch_cut": 0.69,
		"brick_col": 0xa85a44, "mortar_col": 0xe6e0d4, "brick_size": Vector2(0.5, 0.2), "mortar": 0.025},
	"roof_tiles": {"shader": "res://shaders/roof_tiles.gdshader", "tile": Vector2(0.34, 0.24), "jitter": 0.12, "shade": 0.4},
	"bark": {"shader": "res://shaders/bark.gdshader", "stripes": 14.0, "depth": 0.35},
	"hay": {"shader": "res://shaders/hay.gdshader", "fiber": 38.0, "jitter": 0.16},
	"cloth_stripe": {"shader": "res://shaders/cloth_stripe.gdshader", "width": 0.4, "stripe_col": 0xf5eedc},
	"flame": {"shader": "res://shaders/flame.gdshader", "flicker": 0.045, "speed": 13.0, "glow": 1.6},
	# 땅 (판 하나) — 잔디 + 흙길 마스크. 잔디색은 캐릭터보다 채도를 낮게
	"grass_ground": {"shader": "res://shaders/grass_ground.gdshader", "col_a": 0x86b866, "col_b": 0x6f9f55, "col_c": 0x97c272,
		"col_d": 0x7c9a5a, "soil_col": 0x8c7350, "patch_scale": 0.045, "soil_amount": 0.05, "blade": 0.08,
		# dirt_path (흙길 — 같은 셰이더 안)
		"path_col": 0xd6bd85, "rut_col": 0xae9468, "gravel_col": 0x9c968c, "edge_noise": 0.7, "edge_soft": 0.25,
		"rut_off": 0.8, "rut_w": 0.22, "gravel": 0.12},
	"grass_blade": {"shader": "res://shaders/grass_blade.gdshader", "sway": 0.06, "wind_speed": 1.8, "wind_scale": 0.32,
		"height": 1.0, "root_dark": 0.45},  # height: 메시 높이 (포기마다 DECO.grass_h로 줄여 그림)
}

# ── 맵 장식 (사용자 요청 — 전부 충돌 없음, 벽에서 10cm 넘게 안 튀어나옴. 성벽은 아래 recess 참고) ──
const DECO := {
	"seed": 7321,                     # 배치 무작위 시드 (고정 → 친구대전에서도 모두 같은 모양)
	# 잔디 포기 (MultiMesh): 1m²당 개수(품질 '높음' 기준), 높이, 묶음 크기, 보이는 거리
	"grass_density": 0.55, "grass_h": 0.22, "grass_chunk": 16.0, "grass_range": 40.0,
	"grass_cols": [0x7fa865, 0x8cb26e, 0x739a5c, 0x95b878],
	"flower_ratio": 0.05, "flower_cols": [0xf4f1e6, 0xf0d35a, 0xa98bd6], "flower_h": 0.2,
	"pebble_per_m": 0.5, "pebble_col": 0x8f8b84,
	# 나무 골조 집
	"post_gap": 1.75, "post_w": 0.16, "beam_h": 0.16, "out": 0.06,  # out: 벽에서 튀어나온 두께 (m, 10cm 이하)
	"chimney_chance": 0.45,
	# 성벽: 안쪽 면을 recess만큼 들여서 그리고 (충돌은 그대로), 그 앞에 버팀벽(같은 깊이)을 buttress_gap마다 → 버팀벽 앞면 = 충돌 면
	"recess": 0.5, "buttress_gap": 12.0, "buttress_w": 1.4, "parapet": 0.6,
	"torches": 8, "banner_every": 2,   # 버팀벽 칸 몇 개마다 현수막
	"leaf_jitter": 0.1,                # 나뭇잎 덩어리 밝기 흔들림
}

# ── 그래픽 품질 (설정 화면, user://settings.cfg) — 사용자 요청 ──
# grass: 잔디 비율 (DECO.grass_density에 곱함), clutter: 작은 소품(덩굴·꽃·횃불·현수막·덧문·자갈·들꽃), shadow_dist: 그림자 거리(0 = 끔)
const GFX := {
	"low": {"name": "낮음", "grass": 0.0, "clutter": false, "shadow_dist": 0.0},
	"normal": {"name": "보통", "grass": 0.5, "clutter": true, "shadow_dist": 130.0},
	"high": {"name": "높음", "grass": 1.0, "clutter": true, "shadow_dist": 220.0},
}
const GFX_ORDER := ["low", "normal", "high"]

# 아이템이 나타나는 자리
# ── 특수 아이템 (HTML updateChickens / updateSniper / updateAK / updateHorses / lanceCheck) ──
# 시간은 초, 거리는 m. [a, b]는 그 사이 무작위
const ITEM := {
	# 저격총·AK: 맵에 없고 아무도 안 들고 있으면 timer마다 chance 확률로 나타남. 첫 등장은 first
	"sniper_first": [18.0, 30.0], "sniper_timer": [12.0, 20.0], "sniper_chance": 0.4,
	"ak_first": [20.0, 35.0], "ak_timer": [12.0, 20.0], "ak_chance": 0.4,
	"ak_apart": 12.0,       # AK는 저격총 자리와 이만큼 떨어진 곳에
	"life": 40.0,           # 나타난 뒤 이만큼 지나면 사라짐
	"drop_life": 25.0,      # 죽은 사람이 떨어뜨린 것
	"pick_r": 1.6,          # 닿으면 줍는 거리
	"sniper_cd": 1.0,       # 한 발 쏘면 기다림
	"sniper_swap": 0.35,    # Q로 바꾸는 시간 (AK는 WEAPONS.ak.swap)
	"empty_swap": 0.45,     # 다 쓰고 원래 무기로 돌아오는 시간
	"sniper_range": 400.0, "sniper_r": 0.03, "ak_r": 0.02,  # 히트스캔 길이·판정 굵기
	"sniper_kill": 9999.0,  # 저격총 피해 (즉사)
	"ak_bot_ads": 12.0,     # 봇은 대상이 이보다 멀면 정조준
	"ak_move_spread": 0.6, "ak_air_spread": 0.03,  # 움직이면 hip×(1+0.6×속도/6), 공중이면 +0.03
	# 말
	"horse_first": [25.0, 40.0], "horse_timer": [15.0, 25.0], "horse_chance": 0.35, "horse_life": 40.0,
	"mount_r": 2.2,         # 이만큼 다가가면 올라탐
	"runaway": 2.5, "runaway_speed": 10.0,  # 시간이 끝나면 말이 달아남
	"lance_min_speed": 3.0, # 이보다 느리면 창 판정 없음
	"lance_from": 1.2, "lance_from_y": 1.6, "lance_tip": 3.5, "lance_tip_y": 1.25, "lance_r": 0.42,
	"lance_again": 0.8,     # 같은 대상은 이 간격에 한 번만
	"trample_r": 1.2, "trample_h": 1.5, "trample_kb": 6.0, "trample_up": 4.0,  # 말 몸통에 치이면 넘어짐
	# 닭
	"chicken_first": 3.0, "chicken_timer": [6.0, 10.0], "chicken_max": 4, "chicken_cap": 6,
	"chicken_spots": [Vector3(-14, 0, 6), Vector3(16, 0, -4)],  # 경기 시작할 때 두 마리
	"chicken_grab_r": 1.2, "chicken_flee_r": 4.5, "chicken_walk": 1.2, "chicken_run": 5.0,
	"chicken_no_pick": 1.2, # 던진 닭은 이만큼 지나야 다시 잡힘
	"chicken_speed": 1.05,  # 들고 있으면 이동 속도 배율
	# 황금 붕어빵 (사용자 요청 — HTML에 없음): 먹으면 dur초 무적 (사용자 요청으로 5→8초). 맵에 하나만, 누가 무적이면 안 나옴
	"golden_fish": {
		"dur": 8.0, "spawn_min": 15.0, "spawn_max": 25.0, "chance": 0.4, "life": 40.0,
		"first": [15.0, 25.0],  # 경기 시작 뒤 첫 판정
		"apart": 12.0,          # 다른 특수 아이템과 이만큼 떨어진 SNIPER_SPOTS에
		"pick_r": 1.6,          # 닿으면 바로 먹음
		"col": 0xf3b33d, "col_dark": 0xc98a1e, "ring_col": 0xffd56b, "glow": 0.35,  # 금색 + 살짝 발광 (비늘 줄은 진한 금색)
		"spin": 1.8, "bob": 0.18, "bob_hz": 2.2, "y": 1.0, "scale": 1.6, "sparkles": 4,
		# 몸 박치기: 무적 중에 적과 몸이 닿으면 (같은 적은 again초에 한 번)
		"touch_r": 0.9, "touch_h": 1.6, "again": 0.5,
	},
}
const SNIPER_SPOTS := [Vector3(0, 2, 3), Vector3(-36, 0, -12), Vector3(36, 0, 8), Vector3(-6, 0, -36),
	Vector3(6, 0, 36), Vector3(28, 3.9, 12), Vector3(-24, 0, 22), Vector3(24, 0, -20)]
# 황금 붕어빵 무적 연출 (마리오카트 스타 느낌 — 보기만 함). scripts/fx/star_fx.gd가 씀
const STAR_FX := {
	"gold": 0xffc93c, "white": 0xfffbe8,
	"flash_hz": 8.0, "end_hz": 16.0, "end_t": 1.0,  # 몸 번쩍임 초당 횟수 / 끝나기 end_t초 전부터 빨라지고 중간중간 꺼짐
	"overlay_a": 0.78, "emit": 0.9,                   # 덮어씌우는 색 진하기, 발광 세기
	"spark_every": 0.035, "spark_life": 0.7, "spark_up": 1.8, "spark_size": 0.16, "spark_r": 0.55,  # 몸 둘레 별 반짝이
	"trail_every": 0.03, "trail_life": 0.55, "trail_size": 0.09, "trail_speed": 2.0,  # 움직이면 금가루 꼬리 (이 속도 넘을 때)
	"pool": 220,                                       # 반짝이 MultiMesh 최대 개수
	"light_range": 4.0, "light_energy": 1.6, "light_max": 2,  # 은은한 금빛 (웹은 빛 개수 제한 → 가장 가까운 2명만)
	"vig_alpha": 0.75, "vig_hz": 2.2, "edge_sparks": 16,      # 1인칭: 금색 비네트 두근, 테두리 반짝이
}
const HORSE_SPOTS := [Vector3(-30, 0, 0), Vector3(30, 0, -4), Vector3(2, 0, 30), Vector3(-12, 0, -32),
	Vector3(34, 0, 32), Vector3(-34, 0, -30), Vector3(-20, 0, 22)]

# ── 매치·메뉴·HUD (HTML startMatch / startMenuSim / updateHUD / killfeed / banner / toast) ──
## 메인 메뉴 (마을 게시판 — reference/ui_design/Main.html, px는 1080 시안 × 0.667)
const VERSION := "v0.2"
const MAIN_MENU := {
	"tips": [  # 오늘의 팁 (메인 화면을 열 때마다 하나, \n = 줄 바꿈 자리). 규칙이 바뀌면 같이 고칠 것
		"달리다가 급하게 돌면\n넘어집니다. 진짜로.",
		"활을 끝까지 당긴 채\n3초 버티면 손이 미끄러진다.",
		"석궁은 머리에 맞히면\n한 방.",
		"남이 던진 성수 웅덩이에선\n느려진다.",
		"황금 붕어빵을 먹으면\n8초 무적.",
		"Tab을 누르면 점수판.",
	],
	"shade_w": 573.0, "shade_a": 0.42,      # 왼쪽 어둡게 (시안 860px, 잉크 .42 → 0)
	"title": {"pos": Vector2(47, 35), "size": Vector2(440, 147), "font": 88, "tilt": -2.0, "rope": 40.0},
	"motto": {"pos": Vector2(200, 166), "font": 31, "tilt": 3.0, "text": "일단 던져."},
	"pole": {"x": 79.0, "y": 220.0, "w": 23.0},
	"nav": {"x": 47.0, "y": 248.0, "gap": 12.0, "stack": -18},  # stack = 큰 글자와 작은 글씨 사이 (음수 = 겹치게)
	# 이정표: 폭·높이·글자·아이콘 크기 (시안 그대로 들쑥날쑥). AI대전은 오른쪽으로 9px 나옴
	"signs": {
		"ranked": {"w": 373.0, "h": 64.0, "font": 37, "icon": 29},
		"ai": {"w": 413.0, "h": 75.0, "font": 43, "icon": 33, "dx": 9.0, "sub": 17},
		"friend": {"w": 387.0, "h": 64.0, "font": 37, "icon": 29, "sub": 16},
		"settings": {"w": 313.0, "h": 56.0, "font": 33, "icon": 27},
		"exit": {"w": 267.0, "h": 48.0, "font": 28, "icon": 23},
	},
	"stamp": {"d": 61.0, "font": 17, "tilt": -12.0, "col": 0xb8322a, "ring": 0x7d1f19},  # '준비 중' 빨간 도장
	"tip": {"right": 47.0, "top": 47.0, "w": 280.0, "tilt": 2.5, "head": 20, "font": 20, "line": -7},
	"foot": {"x": 47.0, "bottom": 17.0, "font": 15},
	# 오른쪽 병과 무리 (SubViewport 하나, 투명 배경). 위치는 m, 카메라는 +z에서 -z를 봄
	"crowd": {
		"rect": Rect2(610, 130, 670, 590), "fov": 30.0, "cam": Vector3(0.4, 1.45, 7.3), "look": Vector3(0.4, 1.2, 0),
		"cast": [  # [병과, 위치, 몸 돌림(도, +면 화면 왼쪽을 봄), 무기]
			["cleric", Vector3(2.35, 0, -1.5), -18.0, "holy"],
			["archer", Vector3(-1.45, 0, -1.1), 22.0, "bow"],
			["bard", Vector3(1.15, 0, 0.2), -14.0, "trumpet"],
			["barbarian", Vector3(-0.35, 0, 1.25), 16.0, "stone"],
		],
		"sway": 0.12, "sway_hz": 0.23, "nod": 0.12, "nod_hz": 0.31,  # 느린 대기 동작: 몸 좌우로 살짝, 고개 까딱
		"shadow_a": 0.28, "shadow_r": 0.55,
	},
}
## 병과 선택 화면 (시안 ClassSelect.html, px × 0.667). 막대 숫자는 class_stats()가 실제 값으로 계산
const CLASS_PAGE := {
	"lines": {  # 개구 한마디
		"barbarian": "생각 없음. 돌 있음.", "archer": "당기다 손 미끄러짐 주의.", "crossbow": "한 발이면 끝. 휠로 감아라.",
		"cleric": "성수 맛 좀 봐라.", "bard": "내 연주에 춤춰라.",
	},
	# 아래 한 줄 설명. {..}는 WEAPONS 값으로 채움 (game_data를 고치면 문구도 따라감)
	"blurbs": {
		"barbarian": "{cd}초마다 돌을 퍼붓는 돌격형. 가장 빠르지만 가장 약하다.",
		"archer": "짧게 끊어 쏘면 연사, 끝까지 당기면 {dmg_max} 피해. 화살은 포물선으로 떨어진다.",
		"crossbow": "피해 {dmg}, 머리에 맞히면 한 방. 쏜 뒤엔 마우스 휠을 {notches}칸 굴려 감는다.",
		"cleric": "성수병 {max_charges}개를 모아 던진다. 웅덩이가 적을 지지고 느리게 만든다.",
		"bard": "트럼펫을 불면 적이 춤춘다. 춤추는 적은 느리고 공격을 못 한다.",
	},
	"eye_h": 1.62,   # 사거리 계산: 눈높이(player.eye_pos)에서 정면으로 쏴서 땅에 닿는 거리 (무기 range가 있으면 거기까지)
	"bar_cols": {"hp": 0xe5484d, "speed": 0x3fa7e0, "range": 0x6cc35a, "track": 0xe2c992},
	"title": {"top": 27.0, "font": 64, "pad": Vector4(47, 5, 47, 10), "tilt": -1.5},
	"sub": {"font": 15},   # 제목 아래 작은 글씨 (AI대전 · 난이도 · 모드)
	"frame": {"pos": Vector2(113, 146), "size": Vector2(347, 347), "tilt": -2.0},
	"stamp": {"pos": Vector2(375, 160), "font": 43, "tilt": 14.0, "col": 0xc4302b, "line": 4.0, "pop_t": 0.22, "from": 2.2},
	"info": {"pos": Vector2(507, 147), "size": Vector2(673, 347), "pad": Vector4(40, 22, 40, 20), "gap": 5,
		"trim": 0.2, "row_gap": 4, "name": 69, "weapon": 23, "weapon_col": 0x6b3f1f, "line": 33, "stat": 23, "bar_h": 17.0, "desc": 19},
	"cards": {"pos": Vector2(100, 527), "size": Vector2(133, 157), "gap": 17.0, "name": 24, "img": Vector2(118, 115),
		"key": 27.0, "key_font": 17, "tilts": [-2.0, 1.5, -1.0, 2.0, -1.5], "lift": Vector2(0, -5)},
	"back": {"pos": Vector2(887, 527), "size": Vector2(93, 60), "font": 25},
	"go": {"pos": Vector2(887, 601), "size": Vector2(293, 91), "font": 44, "tilt": -1.0},
	"hint": {"pos": Vector2(996, 539), "font": 20, "tilt": -3.0, "text": "1~5 키로도 골라요"},
	# 3D 무대: big = 큰 액자 (천천히 좌우로), card = 카드 그림 (정면, 한 번만 찍음)
	"big": {"px": Vector2i(340, 340), "fov": 30.0, "cam": Vector3(0, 1.1, 5.6), "look": Vector3(0, 0.98, 0), "yaw": 22.0, "sway": 14.0, "sway_hz": 0.12},
	"card": {"px": Vector2i(236, 230), "fov": 30.0, "cam": Vector3(0, 1.0, 4.4), "look": Vector3(0, 0.95, 0), "yaw": 8.0, "sway": 0.0, "sway_hz": 0.0},
}
## 난이도·모드 카드 (병과 카드와 같은 양피지 카드 규칙)
## 경기 화면 HUD (시안 Hud.html, 1920 px × 0.667). 규칙: 가운데 40%는 비움(조준점·알림 쪽지만),
## 정보는 네 모서리 + 위 가운데 점수판, 판 높이 1080p 120px(= 80) 이하, 팀은 색 + 글자 + 방패 귀퉁이
const HUD_UI := {
	"edge": 20.0,                         # 화면 가장자리 여백 (30px)
	"bow_full_pop": 3.0,                  # 활을 끝까지 당기면 조준점 고리가 번쩍 퍼짐 (초당 줄어드는 양 — 1/3초)
	"xbow_label_font": 15,                # 석궁 휠 장전 "6/10" (조준점 고리 아래)
	"top": {"top": 12.0, "rope": 16.0, "timer_font": 22, "tag_pad": Vector4(14, 0, 14, 2), "tag_r": 5.0,
		"leader_font": 15, "leader_pad": Vector4(12, 3, 12, 5), "gap": -2},
	"ctrl": {"w": 507.0, "h": 166.0, "line": 2.7, "drop": 4.0,
		"tag_top": 12.0, "tag_font": 17, "tag_pad": Vector4(12, 0, 12, 2),
		"shield": Vector2(153, 56), "shield_x": 47.0, "shield_top": 44.0, "shield_r": [7.0, 7.0, 27.0, 7.0],
		"shield_font": 31, "shield_pad": 15.0, "dot": 15.0, "dot_gap": 5.0, "dot_off": Color(1, 1, 1, 0.25),
		"medal_top": 39.0, "medal": 72.0, "medal_in": 52.0, "flag": 29.0, "track": 0xe2c992, "neutral": 0xc9a77c,
		"bar_top": 113.0, "bar": Vector2(191, 15), "bar_bg": Color(0.957, 0.894, 0.737, 0.85),
		"pct_font": 25, "pct_x": 4.0, "note_top": 132.0, "note_font": 20, "note_tilt": -1.0, "note_pad": Vector4(12, 2, 12, 4)},  # 상태 쪽지는 % 막대(113~128) 바로 아래 — 막대를 안 가리게 (사용자 요청)
	"sign": {"font": 20, "sub": 15, "lift": 3.4, "pad": Vector2(11, 4), "tri": Vector2(16, 9), "fade_r": 140.0, "fade_min": 0.35},
	"ally": {"font": 16, "tri": Vector2(14, 9)},
	"feed": {"font": 19, "icon": 20.0, "gap": 7, "sep": 8, "pad": Vector4(11, 3, 11, 5), "r": 4.0,
		"head_font": 13, "head_col": 0xc4302b, "head_tilt": -4.0, "me": "나", "trim": 0.28},
	"vitals": {"medal": 80.0, "medal_in": 62.0, "plank": Vector2(267, 69), "overlap": 17.0, "pad": Vector4(29, 6, 15, 9), "r": 9.0,
		"name_font": 24, "hp_font": 29, "bar_h": 15.0, "bar_bg": 0x3a2414, "note_font": 14,
		"low": 0.25, "blink_hz": 3.0, "blink_col": 0xff9a8f},
	"weapon": {"size": Vector2(267, 75), "pad": Vector4(15, 5, 15, 6), "r": 5.0, "icon": 43.0, "gap": 12,
		"name_font": 29, "state_font": 16, "hint_font": 15, "bottom": 37.0, "breath_h": 7.0, "trim": 0.3},
	"keys": {"font": 15, "bottom": 11.0, "text": "Esc 메뉴 · Tab 점수판"},
	"pop": {"font": 22, "y": 48.0},       # 조준점 아래 자막 (배경 없음)
	"death": {"title": "넘어졌다... 다시?", "font": 38, "by": 24, "sub": 16, "gap": 2},  # 사망 자막 (배경 없음)
	"notes_gap": 6.0,                     # 위 가운데 점수판 아래 아이템 안내 줄까지
	"center_free": 0.4,                   # 가운데 비워 둘 비율 (테스트가 확인)
}
const PICK_CARDS := {"tilts": [-1.5, 1.0, -0.8], "lift": Vector2(0, -5), "w": 300.0, "pad": Vector4(18, 22, 18, 18)}
const MENU_CAM := {"r": 52.0, "h": 26.0, "speed": 0.05, "fov": 60.0, "look": Vector3(0, 2, 0)}  # 메뉴 뒤 구경 카메라
const TIMER_LOW := 30         # 남은 시간이 이 초 이하면 빨간 글씨
const FEED_MAX := 5           # 킬피드 최대 줄 수
const FEED_LIFE := 5.5        # 킬피드 한 줄이 남는 시간
const BANNER_T := 2.8         # 가운데 위 큰 문구
const POP_T := 1.0            # 조준점 아래 문구 (처치·알림)
const TOAST_T := 2.2          # 아래쪽 알림 상자
const BOARD_TICK := 0.3       # 점수판 다시 그리는 간격
const SENS_RANGE := [0.4, 3.0, 0.1]  # 감도 슬라이더 최소·최대·간격
# 메뉴·HUD 색 — "마을 게시판 스타일" (reference/ui_design/Guide.html). 재질은 나무·양피지·금칠 셋뿐
const UI := {
	"ink": 0x2b1d12,       # 잉크: 모든 외곽선·글자
	"parch": 0xf4e4bc,     # 양피지: 설명·쪽지·킬피드·무기 칸
	"wood": 0x9a6236, "wood_hi": 0xb57a47, "wood_lo": 0x8a542b,  # 나무판 (위 밝게 → 아래 어둡게)
	"gilt": 0xf2b44a, "gilt_hi": 0xf6c25a, "gilt_lo": 0xd9922e,  # 금칠: 주요 버튼 하나만
	"marker": 0xffd84a,    # 형광펜: 강조·선택·알림·내 줄
	"hp": 0x6cc35a, "blue": 0x3d6fd6, "red": 0xd8453b,
	"cream": 0xfff8e6,     # 나무판 위 글자 (+ 잉크 외곽선)
	"cream_dim": 0xffe9bf, # 나무판 위 작은 글자
	"brown": 0x5a3410,     # 양피지 위 설명 글자
	"faded": 0x7b5a3a,     # 양피지 위 흐린 글자
	"dust": 0xc9a77c,      # 어두운 판 위 흐린 글자 (옛 mute 자리)
	"sky": 0x9cc0f2,       # 어두운 곳에서 보이는 밝은 파랑 (석궁 장전 고리 등, 옛 steel 자리)
}
## UiKit 판·버튼 모양 (px는 1280×720 기준 = 시안 1920×1080 값 × 0.667)
const UI_KIT := {
	"wood": {"line": 3.0, "drop": 5.0, "radius": 7.0, "drop_a": 1.0},    # 시안 외곽선 4 · 그림자 8
	"parch": {"line": 2.0, "drop": 4.0, "radius": 4.0, "drop_a": 0.9},   # 시안 3 · 6
	"gilt": {"line": 3.0, "drop": 5.0, "radius": 8.0, "drop_a": 1.0},
	"seam": 18.0, "seam_w": 2.0,          # 나무 판자 이음선 간격·굵기 (시안 25~29px마다 3px)
	"seam_a": 0.38, "seam_gilt_a": 0.3,
	"grain_every": 9.0, "grain_a": [0.08, 0.18], "knot_every": 170.0,  # 나뭇결 (인스턴스마다 seed 고정)
	"shine_a": 0.22, "shine_h": 4.0,      # 위쪽 밝은 띠 (시안 inset 0 6px)
	"parch_edge": 15.0, "parch_edge_a": 0.33,  # 양피지 가장자리 어둡게 (시안 inset 22~26px)
	"nail_r": 4.7, "nail_in": 9.0,        # 쇠못 반지름·모서리에서 거리
	"rope_w": 8.0, "rope_len": 46.0, "rope_x": [0.14, 0.86], "rope_band": [4.7, 3.3],  # 밧줄 (시안 12px 폭)
	"rope_cols": [0xdcb878, 0x9c7438, 0x5a3e1a],  # 밧줄 밝은 줄·어두운 줄·테두리
	"nail_cols": [0xe8e2d8, 0x77706a, 0x35302b],  # 쇠못 하이라이트·몸·테두리
	"arrow_tip": 34.0,                    # 이정표 오른쪽 뾰족한 부분 길이
	"tilt_max": 3.0,                      # 기울기 한도(도). 숫자는 안 기울인다
	"text_outline": [3, 9], "text_outline_k": 0.22,  # 나무판 위 글자 외곽선 = 글자 크기 × k (3~9, 시안 5~14px)
	"text_drop": 3,                       # 나무판 위 글자 아래 그림자
	# 자막 (경기 화면 위에 잠깐 뜨는 글자 — 배경판 없이 외곽선 + 그림자만, UiKit.caption)
	"caption": {"big": 28, "outline_big": [10, 14], "outline_small": [6, 8], "outline_k": 0.25,
		"drop_big": 4, "drop_small": 3, "shadow_a": 0.8},
	"hover_t": 0.12, "hover_shift": Vector2(0, -2), "hover_tilt": -1.0,  # 마우스 올림: 살짝 들리고 기울기
	"sign_shift": Vector2(7, 0),          # 이정표는 오른쪽으로 밀림 (시안 translateX 10px rotate -1deg)
	"press_sink": 3.0,                    # 누르면 그림자 쪽으로 꾹
	"disabled_a": 0.55,
	"ring_w": 5.0,                        # 고른 카드 형광펜 테 (시안 7px + 잉크 3px)
	"band_h": 7.0,                        # 카드 위쪽 색 띠
	# 판자벽 배경 (시안 .wall): 판자 폭 236px·이음새 6px, 가로 결 17px마다 3px, 가운데 밝게
	"wall": {"plank": 157.0, "seam_w": 4.0, "seam_a": 0.55, "line_every": 11.0, "line_w": 2.0, "line_a": 0.05, "hi": 0x8a5630, "lo": 0x5a3218},
}

# ── 연출 (8단계: HTML impactFx·makeRagdoll·updateCamera·updateHUD) ──
# ── 오디오 (Music 오토로드·설정 화면) ──
## 배경음악 목록. 같은 파일이면 키가 바뀌어도 이어서 튼다 (menu는 나중에 메뉴 전용 곡으로 바꿀 자리)
const BGM := {
	"match": "res://audio/bgm_scotland_silly.ogg",       # 일반 매치 (65초 루프)
	"match_bard": "res://audio/bgm_scotland_edm_v2.ogg", # 내가 음유시인일 때 (60초 루프)
	"menu": "res://audio/bgm_scotland_silly.ogg",
	"star": "res://audio/bgm_metal_heavy_loop.ogg",     # 황금 붕어빵 무적 (play_override)
}
const MUSIC := {
	"fade": 1.5,        # 곡 바꿀 때 크로스페이드(초)
	"stop_fade": 1.0,   # stop_bgm 기본
	"start_fade": 1.0,  # 게임 켤 때(웹은 첫 클릭 뒤) 페이드인
	"star_in": 0.2, "star_out": 0.8,  # 황금 붕어빵: 무적 곡으로 빠르게 / 끝나면 원래 곡으로
	"bard_cls": "bard", # 이 병과면 match_bard (CLASSES에 있을 때만)
}
const VOL_DEFAULT := {"master": 0.8, "music": 0.7, "sfx": 0.8}  # 설정 화면 기본값
const VOL_BUS := {"master": "Master", "music": "Music", "sfx": "SFX"}  # default_bus_layout.tres
const SFX_VOL := 1.0          # 효과음 전체 크기 (HTML은 따로 없음 = 1)
# 효과음 (사용자가 만든 파일, audio/sfx/)
const PITCH_JITTER := 0.04                      # 파일 소리 음높이 흔들기 ±
const SFX_NO_JITTER := ["fanfare", "horn"]
const SFX_GAIN := {"thud": 0.6}                 # 소리별 크기 배율 (기본 1.0) — 크기 조절은 여기서
const SFX_PITCH := {"thud": 1.15}               # 소리별 음높이 배율
# 거리·남의 소리 (사용자 요청 — HTML은 1/(1+거리/9)라 멀어도 잘 안 줄었음). Sfx.vol_at
#   크기 = 1 / (1 + (거리/ref)^rolloff), fade_from~max 사이에서 0까지 더 줄임.
#   내 캐릭터 자리(self_r 안)에서 난 소리 = 내 소리, 나머지(적·아군·봇)는 × others
const SFX_DIST := {"ref": 8.0, "rolloff": 1.5, "fade_from": 50.0, "max": 80.0, "others": 0.7, "self_r": 0.5}
const XBOW_RELOAD_SND := {"latch": 0.63, "seat": 0.86}  # 석궁 장전 모션 진행도에서 걸쇠·볼트 소리 나는 순간 (휠 한 칸마다는 xbow_click)
const GALLOP := {"min_speed": 2.0, "pitch_min": 0.85, "pitch_max": 1.2, "speed_ref": HORSE_SPEED}  # 말 속도 → 다그닥 음높이
const HITSTOP_SCALE := 0.12   # 히트스톱 동안 시간이 이만큼 느리게 흐름
# 내가 맞혔을 때 히트스톱 길이(초) — 처치 0.1, 닭 0.04, 헤드샷 0.055(AK 0.025), 무거운 무기 0.045, 그 외 0.02(AK 0)
const HITSTOP := {"kill": 0.1, "chicken": 0.04, "head": 0.055, "head_ak": 0.025, "heavy": 0.045, "normal": 0.02, "ak": 0.0}

# ── 결과 화면 승리·패배 연출 (사용자 요청 — HTML엔 없음. menu.gd _play_end_fx) ──
## 결과 화면 효과음 (반복 없음, Sfx.play_stinger 전용 플레이어)
const STINGER := {"victory": "res://audio/sfx_victory.ogg", "defeat": "res://audio/sfx_defeat.ogg"}
const RESULT := {
	"ffa_win_rank": 3,      # 개인전: 이 순위 안이면 승리 연출 (1~3등)
	"bgm_out": 0.3,         # 결과 화면이 뜨면 BGM이 이만큼 동안 작아짐
	"bgm_back": 1.5,        # 효과음이 끝나면 메뉴 곡이 이만큼 동안 커짐
	"slowmo": 0.3, "slowmo_t": 0.6,   # 승리: 처음 0.6초(실제 시간) 동안 Engine.time_scale 0.3
	"drop_at": 0.3,         # 제목 판이 떨어지기 시작
	"drop_from": 520.0,     # 위에서 이만큼(px) 위에서 떨어짐
	"drop_t": 0.55,         # 승리: 떨어져 통통 튀는 시간
	"wobble": [6.0, -5.0, 3.5, -2.0, 0.0], "wobble_t": 0.11,  # 승리: 좌우 흔들림(도) — 한 번에 0.11초
	"fall_t": 0.35,         # 패배: 툭 떨어지는 시간
	"tilt_deg": 10.0, "tilt_t": 0.9,  # 패배: 못 하나가 빠져 기울어짐
	"fx_at": 0.5,           # 효과음 + 햇살·색종이
	"rain_at": 0.6,         # 패배: 먹구름·비
	"rows_at": 1.4, "row_gap": 0.06, "row_t": 0.18,  # 점수판 줄이 위에서부터 하나씩
	"btn_t": 0.25,          # 버튼 나타나는 시간
	"gray_t": 0.35,         # 패배: 배경이 회색으로 바래는 시간
	"burst": 90, "fall": 70, "fall_for": 3.0,  # 색종이: 터지는 수·떨어지는 수·떨어지는 시간
	"rain": 220,            # 빗줄기 수
	"rays": 14, "ray_spin": 0.25, "ray_alpha": 0.24,  # 햇살 줄 수·도는 속도(rad/s)·투명도
	"confetti": [0xf3b33d, 0xfbf1dc, 0xe5484d, 0x6cc35a, 0x5d8fff, 0xff8fd0],  # 개인전 색종이
	"memo": 0xffe27a, "memo_rot": -3.0,  # 노란 쪽지 색·기울기(도)
}
## 남은 화면 (일시정지·설정·나가기 안내·친구대전·대기실·알림): 큰 판 = 양피지 + 못 4, 제목 = 매달린 나무 간판
const PAGE_UI := {
	"board_pad": Vector4(28, 22, 28, 22), "board_gap": 16, "sub": 16,
	"head": {"font": 40, "pad": Vector4(28, 2, 28, 8), "tilt": -1.5},
	"exit_title": "도망 성공!",
	"mini": {"w": 150.0, "pad": Vector4(10, 10, 10, 8), "emblem": 34.0, "font": 19, "sub": 12, "tilts": [-1.0, 0.8, -0.5, 1.2, -0.8]},
	"toast": {"font": 19, "pad": Vector4(20, 15, 20, 8), "bottom": 48.0, "drop": 18.0, "wobble": [-4.0, 3.0, -1.5, 0.0], "wobble_t": 0.09},
}
## 결과 화면 배치 (시안 Result*.html, 1920 px × 0.667). 왼쪽 = 매달린 제목 판(또는 팀 깃발) + 쪽지 + 3D 캐릭터, 오른쪽 = 양피지 결과판
const RESULT_UI := {
	"bg_a": 0.45,                                  # 뒤 게임 화면 그늘 (다른 메뉴보다 옅게)
	"sign": {"pos": Vector2(220, 27), "min": Vector2(440, 128), "pad": Vector4(44, 2, 44, 8), "font": 84, "font_long": 54,
		"long_at": 6, "center_long": 380.0, "rope": 40.0, "lose_paint": 0x8c7660, "nail_in": Vector2(16, 14)},
	"pennant": {"size": Vector2(320, 220), "kicker": 31, "title": 72, "dot": 20.0, "stripes": 8, "pad_top": 22.0},
	"small_pennant": {"pos": Vector2(673, 20), "size": Vector2(113, 87), "font": 20},
	"memo": {"font": 27, "pad": Vector4(22, 6, 22, 8), "rot_win": 2.0, "rot_lose": -2.0, "dot": 14.0, "overlap": 16.0},
	"board": {"pos": Vector2(793, 80), "w": 427.0, "pad": Vector4(26, 22, 26, 18), "title": 33, "sub": 14, "head": 14,
		"row": 20, "cls": 14, "col_w": [34.0, 0.0, 70.0, 46.0, 46.0], "me_win": 0xffd84a, "me_lose": 0xc9d7f7,
		"sum_w": 78.0, "mvp_font": 19},
	"btns": {"right": 1220.0, "top": 603.0, "gap": 14, "font": 22, "pad": Vector4(16, 10, 16, 10), "go_font": 36, "go_size": Vector2(193, 70)},
	"stage": {"rect": Rect2(30, 150, 780, 570), "ppm": 118.0, "head": 2.35},
	"podium": [{"n": 2, "x": 127.0, "w": 200.0, "top": 587.0}, {"n": 1, "x": 340.0, "w": 200.0, "top": 533.0}, {"n": 3, "x": 553.0, "w": 200.0, "top": 627.0}],
	"podium_font": 60,
	"platform": {"x": 47.0, "w": 760.0, "top": 662.0, "first": 125.0, "step": 140.0},
	"lie": Vector2(420, 690),                      # 패배(개인전): 누워 있는 내 캐릭터 발 자리
	"lose_note": Vector2(590, 505),                # 패배(개인전): "(넘어짐 N회)" 낙서 자리
	"me_tag": {"font": 28, "pad": Vector4(10, 2, 10, 4), "tilt": -4.0},
}
## 결과 문구 — 하나를 골라 제목 아래 노란 쪽지에. {enemy} = 상대 팀 이름
const RESULT_LINES := {
	"ffa": {
		1: {"title": "1등!", "lines": ["중세 최강 바보 등극", "왕관은 없지만 돌은 많다"]},
		2: {"title": "2등!", "lines": ["아깝다! 은메달도 메달이다", "1등 뒤통수는 잘 봤다"]},
		3: {"title": "3등!", "lines": ["시상대에는 올라갔다", "동메달! 엄마한테 자랑하자"]},
	},
	"ffa_lose": {"title": "%d등...", "lines": ["닭이 너보다 많이 잡았다", "넘어진 횟수는 1등", "봇한테 진 건 비밀로 해 줄게", "다음 판엔 돌을 던져 보자"]},
	"ctrl_win": {"title": "승리!", "kicker": "%s", "lines": ["우물은 이제 우리 거다", "물 맛이 기가 막힌다"]},  # 깃발: 팀 이름(kicker) + 승리!
	"ctrl_lose": {"title": "우물을 빼앗겼다...", "winner": "%s
승리", "lines": ["목마르다. 물 한 모금만", "거점 근처라도 가 보자", "{enemy}이 우리 우물에서 세수 중"]},
	"again_lose": "복수하러 간다",  # 패배하면 '한 판 더' 버튼 글자
	"again_lose_ctrl": "우물 되찾기",  # 쟁탈전에서 지면
	"lose_note": "(넘어짐 %d회)",       # 개인전 패배: 쓰러진 나 옆 낙서 (죽은 횟수)
	"mvp_cap": "%s - 거점 지킴이 (우물 위 %s)",  # 쟁탈전 승리: 우리 팀에서 거점에 가장 오래 있던 사람
	"mvp_kill": "%s - 처치왕 (%d킬)",            # 아무도 거점에 안 섰으면 처치가 가장 많은 사람
	"lose_cap": "거점 위에 서 있던 시간: 나 %s",
}
# 내가 맞았을 때 화면 흔들림 — 기본 0.25(AK 0.08) + min(피해,80)/110, 닭 0.3, 성수 0.1. 저격총을 쏘면 0.5
const SHAKE := {"base": 0.25, "ak": 0.08, "dmg_cap": 80.0, "dmg_div": 110.0, "chicken": 0.3, "holy": 0.1, "sniper_fire": 0.5,
	"decay": 2.0, "amp": 0.03}
# 붉은 테두리: 맞으면 피해/60만큼 차고 초당 1.2씩 빠짐, 체력 30 미만이면 +0.25, 최대 0.9
const HURT := {"per_dmg": 60.0, "decay": 1.2, "low_hp": 30.0, "low_add": 0.25, "max": 0.9}
# 피격 방향 표시: 조준점에서 185px 위 붉은 호, 1초(60%까지 진하게), 최대 4개
const DMG_DIR := {"life": 1.0, "hold": 0.6, "r": 185.0, "w": 120.0, "h": 30.0, "thick": 7.0, "max": 4}
# 래그돌 (점 8개를 막대로 이은 Verlet). 7초 남고 마지막 0.6초에 줄어듦. 죽을 때 0.2초 번쩍
const RAGDOLL := {"life": 7.0, "shrink": 0.6, "flash": 0.2, "iters": 6, "damp": 0.995, "fric": 0.86, "r": 0.13,
	"vel_keep": 0.8, "max_steps": 4}
# 무기별로 날려보내는 힘 [맞은 방향, 위로, 머리만 더 위로]. 나머지(돌멩이·닭·짓밟기)는 빙글 돌며 쓰러짐
const RAGDOLL_KICK := {"sniper": [26.0, 7.0, 3.0], "lance": [22.0, 10.0, 3.0], "ak": [7.0, 2.5, 0.0],
	"crossbow": [14.0, 4.5, 0.0], "bow": [8.0, 3.0, 0.0], "holy": [1.5, 4.5, 2.5]}
const DEATH_CAM := {"back": 5.5, "up": 3.2, "follow": 3.0}  # 죽으면 래그돌 골반을 뒤쪽 위에서 봄
# 친구대전 (LAN, 9단계: HTML MP) — 방장 컴퓨터가 ENet 서버. 방 코드는 UDP 방송으로 찾는다
const NET := {
	"port": 24680, "disc_port": 24681, "max_players": 10, "beacon_tag": "JNP1", "beacon_every": 0.5, "find_timeout": 6.0,
	"send_hz": 30.0, "host_hz": 4.0, "ctrl_hz": 10.0, "name_max": 10,  # ctrl_hz: 쟁탈전 상태(라운드·점령·점수)를 보내는 빈도
	"follow": 14.0, "snap_dist": 6.0,   # 남의 캐릭터: 받은 위치로 부드럽게 따라감, 6m 넘게 벌어지면 순간이동
	"dead_wait": 0.5, "revive_guard": 1.0,  # 죽음 사건보다 상태가 먼저 와도 잠깐 기다림 / 죽은 직후 옛 상태로 안 살아남
}
var hitstop_enabled := true   # false면 히트스톱 안 함 (자동 테스트용 — 프레임 수로 시간을 재니까)
var land_trip_override := -1.0  # 테스트: 0 이상이면 착지 넘어짐 확률을 이걸로
var squeak_override := -1.0   # 테스트: 0 이상이면 트럼펫 삑사리 확률을 이걸로 (무작위 때문에 테스트가 흔들리지 않게)

# ── 런타임 설정 (user://settings.cfg에 저장 — HTML localStorage aa-cls / aa-diff / aa-sens / aa-view) ──
var settings_path := "user://settings.cfg"  # 테스트는 다른 파일로 바꿔서 내 설정을 안 건드림
var difficulty := "normal"
var mode := "ffa"           # 지금 고른 게임 모드 (ffa 개인전 / control 쟁탈전)
var gfx_quality := "normal"  # 그래픽 품질 (low / normal / high — GFX)

signal gfx_changed  # 그래픽 품질이 바뀜 (Main: 그림자, 맵: 잔디·소품)
var chosen_cls := "archer"   # AI대전에서 고른 내 병과
var ai_enabled := true       # false면 봇이 가만히 서 있음 (자동 테스트용)
var save_enabled := true     # false면 설정을 파일에 쓰지 않음 (자동 테스트용)
var mouse_sens := 1.2
var third_person := true
var nick := ""               # 친구대전 닉네임 (HTML aa-nick)
var volumes: Dictionary = VOL_DEFAULT.duplicate()  # 0~1, 설정 화면 슬라이더 (master / music / sfx)

var _mat_cache := {}


func _ready() -> void:
	_setup_input()
	_setup_font_fallbacks()
	load_settings()
	apply_volumes()


## 도현 폰트에 없는 글자(· … ⚠)를 Noto에서 빌려 온다. PC는 시스템 폰트로 대신 그리지만
## 웹에는 시스템 폰트가 없어서 네모(□)로 나온다 (10단계). 두 파일은 그 글자만 남긴 1KB짜리다.
func _setup_font_fallbacks() -> void:
	var f: FontFile = load("res://fonts/DoHyeon-Regular.ttf")
	if f.fallbacks.is_empty():
		f.fallbacks = [load("res://fonts/NotoSans-Bold-sub.ttf"), load("res://fonts/NotoSansSymbols2-sub.ttf")]
	# 개구(UiKit.SCRIBBLE, 한마디·쪽지·팁)는 완성형 2350자 + 영문·숫자뿐 → 같은 Noto, 그래도 없는 한글은 도현으로
	var g: FontFile = load("res://fonts/Gaegu-Bold-sub.woff2")
	if g.fallbacks.is_empty():
		g.fallbacks = [load("res://fonts/NotoSans-Bold-sub.ttf"), load("res://fonts/NotoSansSymbols2-sub.ttf"), f]


func load_settings() -> void:
	if not save_enabled:  # 테스트: -s 모드에선 오토로드 _ready가 테스트 준비보다 늦게 돌 수 있다
		return
	var cf := ConfigFile.new()
	if cf.load(settings_path) != OK:
		return
	var c: String = cf.get_value("game", "cls", chosen_cls)
	if CLASSES.has(c):
		chosen_cls = c
	var md: String = cf.get_value("game", "mode", mode)
	if md == "ffa" or MODES.has(md):
		mode = md
	var gq: String = cf.get_value("video", "quality", gfx_quality)
	if GFX.has(gq):
		gfx_quality = gq
	var d: String = cf.get_value("game", "diff", difficulty)
	if DIFF.has(d):
		difficulty = d
	mouse_sens = clampf(float(cf.get_value("game", "sens", mouse_sens)), SENS_RANGE[0], SENS_RANGE[1])
	third_person = bool(cf.get_value("game", "third_person", third_person))
	nick = str(cf.get_value("game", "nick", nick))
	for k: String in VOL_DEFAULT:
		volumes[k] = clampf(float(cf.get_value("audio", k, volumes[k])), 0.0, 1.0)


func save_settings() -> void:
	if not save_enabled:
		return
	var cf := ConfigFile.new()
	cf.set_value("game", "cls", chosen_cls)
	cf.set_value("game", "diff", difficulty)
	cf.set_value("game", "mode", mode)
	cf.set_value("game", "sens", mouse_sens)
	cf.set_value("game", "third_person", third_person)
	cf.set_value("game", "nick", nick)
	cf.set_value("video", "quality", gfx_quality)
	for k: String in VOL_DEFAULT:
		cf.set_value("audio", k, volumes[k])
	cf.save(settings_path)


## 팀 색 (쟁탈전). role = body / accent / dark / pale
static func team_hex(team: String, role: String) -> int:
	return int(MODES.control.teams[team][role])


## 쟁탈전에서 이 병과·팀의 원래 색 hex를 팀 색으로 (in_helm: 투구·모자 안의 조각인가). 안 바꾸면 그대로
static func team_paint(cls: String, team: String, hex: int, in_helm := false) -> int:
	if team == "":
		return hex
	var P: Dictionary = MODES.control.paint.get(cls, {})
	if P.has(hex):
		return team_hex(team, P[hex])
	if in_helm and hex == C.gold and P.has("helm_gold"):
		return team_hex(team, P.helm_gold)
	return hex


## 볼륨 하나 바꾸기 (0~1) — 바로 버스에 반영. 저장은 부르는 쪽이 save_settings()로
func set_volume(k: String, v: float) -> void:
	volumes[k] = clampf(v, 0.0, 1.0)
	apply_volumes()


## volumes를 오디오 버스에 적용: linear_to_db, 0%면 음소거
func apply_volumes() -> void:
	for k: String in VOL_BUS:
		var i := AudioServer.get_bus_index(VOL_BUS[k])
		if i < 0:
			continue
		var v: float = volumes[k]
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


## 0xRRGGBB → Color
static func col(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff)


## 그래픽 품질 바꾸기 (설정 화면) — 저장하고 gfx_changed로 알림
## 병과 선택 화면 막대: 체력·걷기/달리기 속도·사거리(m)와 각 막대 비율 (모든 병과 중 가장 큰 값 = 1)
func class_stats(k: String) -> Dictionary:
	var all := {}
	for c: String in CLASS_ORDER:
		var C: Dictionary = CLASSES[c]
		var walk: float = BASE_SPEED * float(C.speed)
		all[c] = {"hp": int(C.get("hp", 100)), "walk": walk, "run": walk * SPRINT, "range": weapon_reach(C.weapon)}
	var out: Dictionary = all[k].duplicate()
	for key: String in ["hp", "walk", "range"]:
		var mx := 0.0
		for c: String in all:
			mx = maxf(mx, float(all[c][key]))
		out[key + "_k"] = float(out[key]) / mx
	var vals := {}
	for key: String in WEAPONS[CLASSES[k].weapon]:
		var v: Variant = WEAPONS[CLASSES[k].weapon][key]
		vals[key] = str(int(v)) if v is float and is_equal_approx(v, roundf(v)) else str(v)  # 4.0 → "4"
	out.blurb = str(CLASS_PAGE.blurbs.get(k, "")).format(vals)
	return out


## 활 차지 비율 0~1: min_charge까지 당기면 0, full이면 1 (피해·화살 속도 보간에 씀)
func bow_t(charge: float) -> float:
	var B: Dictionary = WEAPONS.bow
	return clampf((charge - float(B.min_charge)) / (float(B.full) - float(B.min_charge)), 0.0, 1.0)


## 눈높이에서 정면(수평)으로 쐈을 때 땅에 닿는 거리 (m). range가 있으면 거기까지. 원뿔 무기(트럼펫)는 range
func weapon_reach(w: String) -> float:
	var W: Dictionary = WEAPONS[w]
	var v: float = W.get("speed_max", W.get("speed", 0.0))
	var lim: float = W.get("range", INF)
	if v <= 0.0 or not W.has("grav"):
		return lim
	var g: float = W.grav
	var lift: float = W.get("lift", 0.0)
	var h: float = CLASS_PAGE.eye_h
	var t := (lift + sqrt(lift * lift + 2.0 * g * h)) / g
	return minf(v * t, lim)


func set_gfx(q: String) -> void:
	if not GFX.has(q):
		return
	gfx_quality = q
	save_settings()
	gfx_changed.emit()


func gfx() -> Dictionary:
	return GFX[gfx_quality]


## 같은 색은 머티리얼 하나를 같이 쓴다 (HTML의 lam()). 램버트처럼 무광.
func mat(hex: int) -> StandardMaterial3D:
	if not _mat_cache.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = col(hex)
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_mat_cache[hex] = m
	return _mat_cache[hex]


## 봇이 무작위로 고를 수 있는 병과 ("wip" 병과는 뺌)
## 손에 든 무기 배율 (mine = 내 캐릭터)
static func held_scale(key: String, mine := false) -> float:
	if mine and HELD_SCALE_SELF.has(key):
		return float(HELD_SCALE_SELF[key])
	var v: Variant = HELD_SCALE.get(key, 1.0)
	return float(v) if not v is Dictionary else 1.0


func bot_classes() -> Array:
	return CLASS_ORDER.filter(func(k: String) -> bool: return not CLASSES[k].get("wip", false))


func class_hp(cls: String) -> int:
	return int(CLASSES[cls].get("hp", 100))


func class_regen(cls: String) -> float:
	return float(CLASSES[cls].get("regen", REGEN))


## 키 설정은 코드로 등록한다 (project.godot에 직렬화된 InputEvent를 손으로 쓰지 않으려고).
## 에디터의 Project Settings > Input Map 에서 같은 이름으로 덮어써도 된다.
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C],
		"toggle_view": [KEY_V], "swap": [KEY_Q], "interact": [KEY_E], "scoreboard": [KEY_TAB],
		"cancel_draw": [KEY_R],  # 활 당기기 취소 (사용자 요청)
		"class_1": [KEY_1], "class_2": [KEY_2], "class_3": [KEY_3], "class_4": [KEY_4], "class_5": [KEY_5],  # 병과 고르는 화면에서만
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
	for action: String in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)
	# 석궁 휠 장전 (사용자 요청): 휠 위·아래 한 칸 = 한 번. 석궁을 들었을 때만 쓴다 (다른 병과는 휠 동작 없음)
	if not InputMap.has_action("wind"):
		InputMap.add_action("wind")
	for b: MouseButton in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var wb := InputEventMouseButton.new()
		wb.button_index = b
		InputMap.action_add_event("wind", wb)
