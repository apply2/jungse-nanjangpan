extends Node
## 게임 전체 수치·규칙 데이터 (오토로드 이름: GameData)
## reference/arrow-arena.html 의 CLASSES / WEAPONS / DIFF / 상수를 그대로 옮긴 것.
## 밸런스를 바꿀 땐 이 파일만 고치면 된다. 색은 0xRRGGBB 정수 → col()로 Color 변환.

# ── 공통 상수 (HTML 386번째 줄) ──────────────────────────────
const FALL_TIME := 0.6       # 넘어져 있는 시간(초)
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
	"archer": {"name": "궁수", "weapon": "bow", "speed": 1.0, "hp": 100,
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
	# nock: 쏜 뒤 다음 화살 거는 시간 / full: 끝까지 당기는 시간 / min_charge: 이보다 짧게 당기면 안 나감
	# 끝까지 당긴 채 sway_start초가 지나면 후들거림(진폭 sway_k×초, 최대 sway_max), slip_t초가 되면 손이 미끄러짐
	"bow": {"name": "활", "dmg_min": 35, "dmg_max": 55, "nock": 1.0, "full": 1.5, "speed_min": 42, "speed_max": 72,
		"grav": 14, "kb": 6.5, "up": 3.4, "radius": 0.05, "min_charge": 0.08,
		"sway_start": 1.0, "sway_k": 0.05, "sway_max": 0.11, "slip_t": 3.0, "slip_yaw": 0.6, "slip_pitch": [-0.35, 0.55]},
	# cd = 장전 시간. 누르고 있으면 장전 끝나는 대로 다시 쏜다
	"crossbow": {"name": "석궁", "dmg": 75, "cd": 4.0, "speed": 100, "grav": 6, "kb": 11, "up": 5, "radius": 0.05},
	"sniper": {"name": "대물 저격총", "ammo": 5, "kb": 0, "speed_mul": 0.9},
	"ak": {"name": "AK-47", "dmg": 23, "min_dmg": 18, "fall0": 30, "fall1": 80, "range": 120, "rate": 0.12, "mag": 25,
		"kb": 1.2, "up": 0, "hip": 0.03, "ads": 0.006, "bloom": 0.006, "max_bloom": 0.05, "speed_mul": 0.95, "zoom": 1.6, "swap": 0.3},
	"chicken": {"name": "닭", "dmg": 1, "kb": 5, "up": 3, "speed": 24, "lift": 5, "grav": 18, "radius": 0.3},
	"lance": {"name": "마상창", "dmg": 70, "kb": 28, "up": 9},
	"holy": {"name": "성수", "cd": 0.4, "max_charges": 3, "recharge": 3.0, "slow": 0.35,  # slow: 웅덩이 속 이동 배율 (65% 느려짐, 사용자 요청으로 0.25→0.35)
		 "speed": 19, "lift": 5.5,
		"grav": 20, "radius": 0.14, "kb": 0, "dmg": 8, "tick_every": 0.5, "dur": 3.0, "area": 3.0},
	# 트럼펫 (음유시인, 4.5단계). 좌클릭 = 연주(누르는 동안), 우클릭 = 팡파레 (조준 확대 없음)
	# 연주: 앞쪽 원뿔(range m, 반각 half_angle 도) 안의 적에게 tick초마다 dmg. 벽 뒤는 안 들림. 넉백 없음, 피해 숫자는 dot 스타일
	# 숨: 최대 breath_max초 연주, 안 불면 초당 breath_regen 회복. 다 쓰면 gasp_t초 동안 연주 못 하고 이동 ×gasp_speed
	# 삑사리: 연주를 시작할 때마다 squeak_chance 확률, squeak_t초 동안 연주 안 됨
	# 연출: 연주 중 볼 크기 cheek 배, 음마다 ±detune 센트 음정 틀어짐
	"trumpet": {"name": "트럼펫", "range": 12.0, "half_angle": 25.0, "tick": 0.25, "dmg": 1.5, "kb": 0, "up": 0,
		"breath_max": 3.0, "breath_regen": 1.5, "gasp_t": 1.0, "gasp_speed": 0.8,
		"squeak_chance": 0.05, "squeak_t": 0.8,
		"cheek": 1.6, "detune": 20.0},
	# 팡파레 (음유시인 우클릭): 앞쪽 range m, 반각 half_angle 도 안의 적에게 dmg, 넉백 kb, 띄우기 up, 재사용 cd초
	"fanfare": {"name": "팡파레", "range": 3.5, "half_angle": 45.0, "dmg": 15, "kb": 9, "up": 3, "cd": 6.0},
}

# ── 춤 디버프 (트럼펫, 4.5단계) ──────────────────────────────
# 원뿔 안에 window초 동안 누적 need초 이상 있으면 dur초 동안 춤. 끝나면 immune초 동안 다시 안 춤
# 춤추는 동안 이동 ×speed, 봇 조준 오차 ×bot_err. 공격은 가능, 조작은 안 뺏음 (명세: 바꾸지 말 것)
# 넘어짐(fall_t)이 우선 — 넘어지면 춤은 멈추고 남은 시간은 사라짐
# 아래 연출 값은 명세에 없어서 정함: sway 플레이어 조준 출렁(라디안)·sway_hz 출렁 빠르기,
# spin_every 몇 초마다 한 바퀴·spin_t 한 바퀴 도는 시간, note_every 음표가 뜨는 간격
const DANCE := {"window": 1.5, "need": 0.75, "dur": 2.0, "immune": 3.0, "speed": 0.6, "bot_err": 2.5,
	"sway": 0.06, "sway_hz": 1.6, "spin_every": 1.1, "spin_t": 0.45, "note_every": 0.28}

# 트럼펫·음유시인 모양 색 (명세: 금색 트럼펫, 깃털 달린 납작한 베레모)
const TRUMPET_LOOK := {"brass": 0xf3b33d, "brass_dark": 0xb97a14, "beret": 0x4b2370, "feather": 0xf4ecd6, "feather_tip": 0xd94a3a,
	"cheek": 0xf3a5a0, "note": [0xf3b33d, 0xc9a2e8, 0x7fd0ff, 0xff8fb0]}

# 트럼펫 소리 (AudioStreamGenerator로 실시간 합성): 톱니파 + 비브라토 + 로우패스
# melody: base_hz 기준 반음 수 (도-미-솔-미-도-솔-도), note 한 음 길이(초), gap 음 사이 쉼
const TRUMPET_SND := {"base_hz": 523.25, "melody": [0, 4, 7, 4, 0, 7, 12], "note": 0.16, "gap": 0.025,
	"vib_hz": 6.0, "vib_cents": 18.0, "lowpass": 2400.0, "vol": 0.22, "rate": 22050}

# ── 봇 난이도 ────────────────────────────────────────────────
const DIFF := {
	"easy": {"name": "쉬움", "react": [1.0, 1.5], "err": 1.5, "sniper_err": 0.09, "head": 0.0, "lead": [0.0, 0.4], "fire": 0.5, "turn": 2.4,
		"color": 0x6cc35a, "skulls": "●○○", "desc": "봇이 늦게 반응하고 자주 빗나가요. 넘어지는 데 적응하기 좋아요."},
	"normal": {"name": "보통", "react": [0.7, 1.1], "err": 1.0, "sniper_err": 0.06, "head": 0.03, "lead": [0.1, 0.6], "fire": 0.65, "turn": 3.2,
		"color": 0xf3b33d, "skulls": "●●○", "desc": "적당히 맞히고 적당히 넘어져요. 기본 난이도예요."},
	"hard": {"name": "어려움", "react": [0.4, 0.7], "err": 0.6, "sniper_err": 0.035, "head": 0.1, "lead": [0.4, 0.9], "fire": 0.85, "turn": 4.5,
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
	"item_seek": 45.0, "horse_seek": 40.0,  # 이 거리 안의 저격총·AK / 말은 주우러 감
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

# ── 맵 색상 (HTML의 C 객체) ──────────────────────────────────
const C := {
	"grass": 0x86cf5f, "grass_dark": 0x6fb34e, "path": 0xdcbd80, "stone": 0xbdb6a8, "stone2": 0x9c9586,
	"stone_dark": 0x857e70, "wood": 0xb98552, "wood_dark": 0x7a4f2c, "plaster": 0xf1e3c4, "roof_r": 0xc9533c,
	"roof_b": 0x4f6fa8, "hay": 0xe8c860, "leaf": 0x5aa84a, "leaf2": 0x6dbb55, "trunk": 0x7a5230, "gold": 0xf3b33d,
	"cloth": 0xe9dfc8, "skin": 0xf2c7a0, "sky": 0x9fd3f0,
}

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
}
const SNIPER_SPOTS := [Vector3(0, 2, 3), Vector3(-36, 0, -12), Vector3(36, 0, 8), Vector3(-6, 0, -36),
	Vector3(6, 0, 36), Vector3(28, 3.9, 12), Vector3(-24, 0, 22), Vector3(24, 0, -20)]
const HORSE_SPOTS := [Vector3(-30, 0, 0), Vector3(30, 0, -4), Vector3(2, 0, 30), Vector3(-12, 0, -32),
	Vector3(34, 0, 32), Vector3(-34, 0, -30), Vector3(-20, 0, 22)]

# ── 매치·메뉴·HUD (HTML startMatch / startMenuSim / updateHUD / killfeed / banner / toast) ──
const MENU_CAM := {"r": 52.0, "h": 26.0, "speed": 0.05, "fov": 60.0, "look": Vector3(0, 2, 0)}  # 메뉴 뒤 구경 카메라
const TIMER_LOW := 30         # 남은 시간이 이 초 이하면 빨간 글씨
const FEED_MAX := 5           # 킬피드 최대 줄 수
const FEED_LIFE := 5.5        # 킬피드 한 줄이 남는 시간
const BANNER_T := 2.8         # 가운데 위 큰 문구
const POP_T := 1.0            # 조준점 아래 문구 (처치·알림)
const TOAST_T := 2.2          # 아래쪽 알림 상자
const BOARD_TICK := 0.3       # 점수판 다시 그리는 간격
const SENS_RANGE := [0.4, 3.0, 0.1]  # 감도 슬라이더 최소·최대·간격
# 메뉴·HUD 색 (HTML :root)
const UI := {
	"ink": 0x161a33, "ink2": 0x232a55, "line": 0x3d4680, "parch": 0xfbf1dc, "mute": 0xb8b5cc,
	"gold": 0xf3b33d, "gold_deep": 0xb97a14, "blood": 0xe5484d, "moss": 0x6cc35a, "steel": 0x9fc0ea,
}

# ── 연출 (8단계: HTML impactFx·makeRagdoll·updateCamera·updateHUD) ──
const SFX_VOL := 1.0          # 효과음 전체 크기 (HTML은 따로 없음 = 1)
const HITSTOP_SCALE := 0.12   # 히트스톱 동안 시간이 이만큼 느리게 흐름
# 내가 맞혔을 때 히트스톱 길이(초) — 처치 0.1, 닭 0.04, 헤드샷 0.055(AK 0.025), 무거운 무기 0.045, 그 외 0.02(AK 0)
const HITSTOP := {"kill": 0.1, "chicken": 0.04, "head": 0.055, "head_ak": 0.025, "heavy": 0.045, "normal": 0.02, "ak": 0.0}
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
	"port": 24680, "disc_port": 24681, "max_players": 8, "beacon_tag": "JNP1", "beacon_every": 0.5, "find_timeout": 6.0,
	"send_hz": 30.0, "host_hz": 4.0, "name_max": 10,
	"follow": 14.0, "snap_dist": 6.0,   # 남의 캐릭터: 받은 위치로 부드럽게 따라감, 6m 넘게 벌어지면 순간이동
	"dead_wait": 0.5, "revive_guard": 1.0,  # 죽음 사건보다 상태가 먼저 와도 잠깐 기다림 / 죽은 직후 옛 상태로 안 살아남
}
var hitstop_enabled := true   # false면 히트스톱 안 함 (자동 테스트용 — 프레임 수로 시간을 재니까)
var squeak_override := -1.0   # 테스트: 0 이상이면 트럼펫 삑사리 확률을 이걸로 (무작위 때문에 테스트가 흔들리지 않게)

# ── 런타임 설정 (user://settings.cfg에 저장 — HTML localStorage aa-cls / aa-diff / aa-sens / aa-view) ──
const SETTINGS_PATH := "user://settings.cfg"
var difficulty := "normal"
var chosen_cls := "archer"   # AI대전에서 고른 내 병과
var ai_enabled := true       # false면 봇이 가만히 서 있음 (자동 테스트용)
var save_enabled := true     # false면 설정을 파일에 쓰지 않음 (자동 테스트용)
var mouse_sens := 1.2
var third_person := true
var nick := ""               # 친구대전 닉네임 (HTML aa-nick)

var _mat_cache := {}


func _ready() -> void:
	_setup_input()
	_setup_font_fallbacks()
	load_settings()


## 도현 폰트에 없는 글자(· … ⚠)를 Noto에서 빌려 온다. PC는 시스템 폰트로 대신 그리지만
## 웹에는 시스템 폰트가 없어서 네모(□)로 나온다 (10단계). 두 파일은 그 글자만 남긴 1KB짜리다.
func _setup_font_fallbacks() -> void:
	var f: FontFile = load("res://fonts/DoHyeon-Regular.ttf")
	if f.fallbacks.is_empty():
		f.fallbacks = [load("res://fonts/NotoSans-Bold-sub.ttf"), load("res://fonts/NotoSansSymbols2-sub.ttf")]


func load_settings() -> void:
	if not save_enabled:  # 테스트: -s 모드에선 오토로드 _ready가 테스트 준비보다 늦게 돌 수 있다
		return
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	var c: String = cf.get_value("game", "cls", chosen_cls)
	if CLASSES.has(c):
		chosen_cls = c
	var d: String = cf.get_value("game", "diff", difficulty)
	if DIFF.has(d):
		difficulty = d
	mouse_sens = clampf(float(cf.get_value("game", "sens", mouse_sens)), SENS_RANGE[0], SENS_RANGE[1])
	third_person = bool(cf.get_value("game", "third_person", third_person))
	nick = str(cf.get_value("game", "nick", nick))


func save_settings() -> void:
	if not save_enabled:
		return
	var cf := ConfigFile.new()
	cf.set_value("game", "cls", chosen_cls)
	cf.set_value("game", "diff", difficulty)
	cf.set_value("game", "sens", mouse_sens)
	cf.set_value("game", "third_person", third_person)
	cf.set_value("game", "nick", nick)
	cf.save(SETTINGS_PATH)


## 0xRRGGBB → Color
static func col(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff)


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
