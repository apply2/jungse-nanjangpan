# 중세난장판 — Godot 이식 프로젝트

Krunker.io를 참고한 중세풍 **병맛 브라우저 FPS**를 Godot으로 옮기는 프로젝트.
원본은 HTML 파일 하나(Three.js)로 만든 프로토타입이고, `reference/arrow-arena.html`에 그대로 들어 있다.
**규칙·수치·느낌의 기준은 언제나 이 HTML이다.** 헷갈리면 HTML 코드를 읽고 그대로 따라 한다.

- 엔진: **Godot 4.7** (4.7.2-stable에서 확인)
- 언어: **GDScript만 사용** — C#으로 짜면 웹으로 내보낼 수 없다
- 렌더러: **Compatibility** (웹 내보내기 대상)
- 물리: Jolt, 60Hz, 물리 보간(physics interpolation) 켬
- 1인 개발. 사용자는 한국어로 대화하고, 코드 주석·UI 문구도 한국어로 쓴다.

---

## 작업 규칙

1. **한 번에 한 단계씩.** 아래 로드맵 순서대로 진행한다. 단계가 끝나면 테스트를 돌리고, 사용자가 직접 플레이해서 손맛을 확인한 뒤 다음 단계로 간다.
2. **수치는 `scripts/game_data.gd`에만 둔다.** 다른 파일에 숫자를 직접 쓰지 말고 `GameData.WEAPONS.bow.full`처럼 가져온다. 사용자가 밸런스를 바꾸라고 하면 이 파일만 고친다.
3. **HTML 동작을 그대로 옮긴다.** 새 아이디어로 바꾸지 않는다. 바꾸고 싶으면 먼저 사용자에게 묻는다.
4. **좌표계가 같다.** Three.js와 Godot 모두 Y가 위, -Z가 앞인 오른손 좌표계다. 위치·회전 숫자를 그대로 쓰면 된다.
   - 회전 순서: Three는 `'YXZ'`, Godot Node3D 기본도 YXZ다.
   - 카메라 FOV: 둘 다 세로 기준이다.
   - 메시 크기: Three의 `BoxGeometry(1,1,1)`은 Godot `BoxMesh.size=(1,1,1)`과 같다.
   - 구·원기둥은 Godot 기본 크기가 다르다. Godot `SphereMesh` 기본 반지름은 0.5라서 radius=1, height=2로 맞춰 쓴다. 원기둥(`CylinderMesh`)도 반지름 1, 높이 1로 맞춘다.
   - 지오메트리 자체를 미리 돌려 구운 경우(`roofGeo.rotateY`)는 부모 노드로 크기를, 자식 노드로 회전을 나눈다. `world_builder.gd`의 `roof()` 참고.
5. **이름 대응.** HTML의 camelCase를 snake_case로 바꾼다 (`fallT` → `fall_t`, `kbT` → `kb_t`, `hasSniper` → `has_sniper`). 엔티티 필드 이름을 맞춰두면 HTML 코드를 옮기기 쉽다.
6. **타입을 적는다.** Dictionary에서 꺼낸 값처럼 Variant인 값에는 `:=`를 쓰지 말고 `var x: float = ...`로 쓴다. 그렇지 않으면 컴파일 오류가 난다.
7. **테스트.** 이동·전투 규칙을 바꾸면 `tests/`에 헤드리스 테스트를 추가하거나 고치고 돌린다. 테스트 실행 방법은 맨 아래에 있다.
8. 그래픽은 지금처럼 **기본 도형 조합**으로 만든다 (TABS 느낌의 흐물흐물 캐릭터). 외부 3D 모델은 사용자가 요청할 때만 쓴다.

---

## 현재 상태 — 1~8단계 완료, 9단계(친구대전, 같은 와이파이) 구현됨 · 사용자 플레이 확인 대기 (다음: 10단계 웹 내보내기)

```
project.godot          설정 (오토로드 GameData, Jolt, Compatibility, 폰트)
scenes/main.tscn       Main(main.gd) ─ World(world_builder.gd) ─ Combat(combat.gd) ─ Player(player.tscn) ─ HUD(hud.gd) (+ 코드로 봇 7명, Menu(menu.gd))
scenes/player.tscn     CharacterBody3D + 원기둥 충돌(r 0.38, h 1.75, 원점=발) + Camera3D
scripts/game_data.gd   ★ 모든 수치·병과·무기·난이도·색. 키 설정도 여기서 코드로 등록함
scripts/world_builder.gd  맵 전체 (HTML buildWorld 1:1). 충돌 상자는 aabbs 배열에도 저장
scripts/combat.gd      무기(weapon_update·_bow_update·fire), 투사체(update_projectiles), 화살 꽂힘(stick_arrow·world_arrows), 성수 웅덩이(shatter·update_zones)·착지 지점 표시(aim_mk), 피격 판정(hit_test), damage, impact_fx, kill, 투구 날림, 스폰 지점, 재생·부활 타이머. 모든 캐릭터는 ents에 등록. 캐릭터 이동 뒤에 돈다(process_physics_priority)
scripts/fx.gd          맞은 효과 puff·ring·chunks (Combat 아래 Fx 노드)
scripts/meshes.gd      공용 도형: 정십이면체 돌멩이, 고리, 연기 구, 상자, 활대(도넛 조각 arc), 단위 원기둥·원뿔·구, 바닥 원판(disc)·얇은 고리(flat_ring)
scripts/weapon_models.gd  무기·화살·성수병 모양 (HTML makeArrow·makeWeapon·arcMesh·stick). 캐릭터 손·뷰모델·날아가는 화살이 같이 씀
scripts/viewmodel.gd   1인칭 손·무기 (HTML buildVM·updateVM). 따로 된 SubViewport(시야각 60)로 찍어 HUD 맨 아래에 덮음. 지금은 돌멩이·활·석궁·성수
scripts/player.gd      캐릭터 하나(나·봇 공용, is_local로 구분. 봇은 ai가 입력을 만듦). Quake식 이동, 달리기, 슬라이드, 점프, 급회전 넘어짐, 계단 오르기, 1·3인칭 카메라
scripts/derp_model.gd  흐물 캐릭터 몸 + 애니메이션 (뒤뚱 걸음, 젤리 출렁, 굴러다니는 눈, 넘어지면 만세)
scripts/main.gd        경기 흐름 (HTML startMatch·endMatch·startMenuSim·pauseGame·goMenu). state = menu / playing / paused / ended, 남은 시간, 20킬 종료
scripts/hud.gd         경기 중 화면 (HTML updateHUD): 시간·1위, 킬피드, 병과·체력, 무기, 속도, 조준점(움직이면 벌어짐), banner, 조준점 아래 문구(pop_msg), 데미지 숫자, 사망 화면, 점수판(Tab)
scripts/menu.gd        메뉴 (메인·난이도·병과·설정·친구대전 자리·나가기), 일시정지, 결과 화면, 아래쪽 알림 상자(toast)
scripts/ui_kit.gd      메뉴·HUD 공용 조각 (HTML CSS의 .panel·.primary·.ghost·.navbtn·병과 카드·난이도 카드·점수판, 병과 아이콘 SVG)
tests/test_movement.gd 이동 자동 테스트 (HTML과 같은 값이 나오는지)
tests/test_combat.gd   피격·피해·투구·재생·부활·스폰 자동 테스트
tests/test_stone.gd    돌멩이·투사체·맞은 효과 자동 테스트
tests/test_bow.gd      활 당기기·세기·후들거림·손 미끄러짐·꽂힘·반동 자동 테스트
tests/test_crossbow.gd 석궁 발사·장전 4초·75 피해·헤드샷 한 방·경직·장전 자세 자동 테스트
tests/test_holy.gd     성수 충전·재충전·포물선·웅덩이 피해·둔화·착지 표시·테두리 색 자동 테스트
scripts/bot_ai.gd      봇 머리 (HTML botUpdate·aimSolve). 대상 고르기·반응·조준 오차·앞질러 쏘기·포물선·무빙·끼임 탈출·웅덩이 피하기
tests/test_bot.gd      봇 조준 계산·앞질러 쏘기·대상·반응·회전 속도·활 당기기·오차 범위·시야·끼임·맞으면 반격·웅덩이 탈출 자동 테스트
tests/test_match.gd    메뉴 구경·병과 고르면 시작·시간·점수판 순서·킬피드·사망 화면·일시정지·다음 부활 병과·4분/20킬 종료·결과·메뉴 복귀 자동 테스트
scripts/items.gd       특수 아이템 (Combat 아래 Items 노드. HTML updateChickens·updateSniper·updateAK·updateHorses·lanceCheck). 닭 돌아다니기·잡기, 저격총·AK 빛기둥·줍기·떨어뜨림, 말 등장·탑승·창 찌르기·짓밟기·달아남. 알림은 banner 신호
tests/test_items.gd    닭 잡기·던지기·넘어짐, 저격총 줍기·즉사·한 발씩·Q 전환·스코프·떨어뜨림, AK 거리 감쇠·연사·퍼짐·탄창, 말 탑승·창 70·멀리 날림·7초 뒤 내림·짓밟기, 봇 줍기 자동 테스트
scripts/ragdoll.gd     죽으면 쓰러지는 몸 (HTML makeRagdoll·stepRagdoll·poseRagdoll). 점 8개 Verlet + world.aabbs 충돌. 모델의 머리·몸통·팔·다리를 떼어 와서 돌림
scripts/sfx.gd         효과음 (오토로드 Sfx, HTML sfx). WebAudio tone·noise 합성을 PCM으로 구워 AudioStreamPlayer 32개로 튼다. 소리 파일 없음
scripts/net.gd         친구대전 (Main 아래 Net 노드, HTML MP). ENet 방 만들기·코드로 찾기(UDP 방송)·IP로 들어가기, 상태 30Hz, 사건(f·sn·ak·ln·h·k), 방장 경기 시간·아이템·줍기 허락
tests/test_net.gd      친구대전: Main 둘을 한 프로세스에 띄워 방·대기실·시작·위치·투사체·저격총·처치 수·줍기 허락·끝·나가기 자동 테스트
tests/test_fx.gd       효과음 합성·소리 나는 곳, 히트스톱, 래그돌(쓰러짐·뼈 길이·무기별 날아감·7초 뒤 사라짐), 흔들림, 붉은 테두리, 피격 방향, 죽음 카메라, 병과 의상 자동 테스트
fonts/DoHyeon-Regular.ttf  HTML과 같은 '도현' 폰트 (OFL 라이선스)
reference/arrow-arena.html 원본
```

실행하면 메인 메뉴가 뜨고, 뒤에서 봇 7명이 싸우는 걸 맵을 빙 도는 카메라로 보여준다 (나는 구경, HTML startMenuSim).
AI대전 → 난이도 → 병과(클릭 또는 1~4) → 바로 경기. 4분이 지나거나 누가 20킬을 하면 결과 화면 (한 판 더 / 병과 다시 고르기 / 메인 메뉴).
경기 중 Esc(또는 창 포커스 잃음) = 일시정지 (`SceneTree.paused`, 다음 부활 병과·감도 바꾸기), Tab = 점수판, V = 시점, 클릭하면 마우스 다시 잠금.
- 일반대전은 "추후 업데이트 될 내용입니다." 알림. 나가기: PC는 바로 끄고, 웹은 HTML처럼 "게임을 종료했어요" 페이지.
- 설정(병과·난이도·감도·시점)은 `user://settings.cfg`에 저장 (HTML localStorage 대신). 테스트는 `GameData.save_enabled = false`.
- 경기 중 1~4로 병과 바꾸기와 F1~F3 난이도 키는 지웠다 (HTML에도 없음). 병과는 일시정지에서 다음 부활부터.
- 킬피드·사망 화면·20킬 종료는 `Combat.killed` 신호를 Main이 받아 처리한다. 처치·알림 문구(HTML popMsg/killPop)는 `hud.pop_msg`.
1번(야만인)으로 좌클릭하면 돌멩이를 던진다 (누르고 있으면 0.4초마다 연사).
2번(궁수)은 좌클릭을 누르고 있으면 활을 당기고 놓으면 쏜다. 3번(석궁병)은 좌클릭하면 바로 쏘고 4초 장전한다(누르고 있으면 장전 끝나는 대로 다시 쏨). 우클릭은 조준(카메라가 다가오고 확대).
- 석궁 장전 모션: 1인칭은 세우기 → 시위 세 번 끊어 당기기 → 걸쇠 → 볼트 끼우기 → 조준 자세, 3인칭은 석궁을 내리고 왼팔로 당긴다. 장전 소리(끙차·톱니·걸쇠·볼트)는 뷰모델이 낸다.
- 화살은 사람에 맞으면 머리·몸에 꽂히고, 벽·땅에 맞으면 10초 꽂혀 있다.
- 반동: 3인칭은 팔·상체가 튕기고(`rec`), 1인칭은 화면·손이 튕긴다(`v_rec`, 조준은 그대로).
- 오른쪽 아래 무기 칸에 상태 문구, 조준점 둘레에 당기기 고리가 뜬다 (HTML `#weapon`, `#ring`).
4번(성직자)은 좌클릭으로 성수를 던진다 (3개까지, 3초마다 1개 참, 0.4초 간격). 던질 곳에 금색 고리로 착지 지점이 뜬다.
- 깨지면 반경 3m 웅덩이가 3초 남고, 안에 있는 다른 사람은 0.15초 뒤부터 0.5초마다 8 피해 + 속도 ×0.25. 던진 사람은 안 맞는다.
- 임시 즉발 사격(`DEBUG_SHOT`)은 지웠다.
- 봇: `Combat.register`가 `BotAI`를 붙이고, 봇의 `_read_input`이 `ai.update()`로 {wish(월드 방향), jump, crouch, sprint, fire}를 만든다. 그 뒤는 사람과 같은 movement·weapon_update.
- 봇 수치는 `GameData.BOT`(공통)와 `DIFF`(난이도). 봇도 가까운 말·저격총·AK를 주우러 간다 (`BOT.item_seek`·`horse_seek`).
- HTML처럼 끼이면 점프하는데, 공중에선 끼임 시간이 줄어서 "아무 방향 탈출"은 머리 위가 막혔을 때 정도만 나온다 (HTML도 같음).
- `scripted_input`이 비어 있지 않으면 AI보다 먼저 쓰인다. 테스트는 `GameData.ai_enabled = false`로 봇을 세워 둔다.
- 공격 입력은 player.gd가 `fire_held`에 담고, Combat이 이동 다음에 `weapon_update()`로 처리한다. `scripted_input`에 `"fire": true`를 넣으면 테스트·봇도 쏠 수 있다.
- 3인칭에선 화면 가운데가 가리키는 곳으로 던진다 (HTML `playerAimDir`/`tpAim`).
- 맞히면 조준점에 X 표시(처치면 빨간색)가 뜬다 — HTML `hitmark`.
- 1인칭 손 모델(뷰모델)은 무기 8개 다 있다 (마상창은 아래에 말 머리가 보임). 스코프를 보면 숨는다.
- 특수 아이템 (7단계): 수치는 `GameData.ITEM`·`WEAPONS`·`HORSE_*`.
  - 저격총·AK·말은 정해진 지점(`SNIPER_SPOTS`·`HORSE_SPOTS`)에 빛기둥과 함께 나타나고 40초 뒤 사라진다. 경기 시작 때 닭 2마리.
  - 저격총은 누를 때마다 한 발 (대기 중에 누르고 있으면 안 나감, HTML 그대로). 우클릭 스코프는 3인칭이어도 1인칭 화면(시야 24).
  - Q(`swap` 액션)로 원래 무기와 바꾼다. 죽으면 저격총·AK는 남은 탄과 함께 25초 떨어져 있고, 말은 내리고, 닭은 놓는다.
  - 화면 위 안내 줄: 아이템까지 거리·남은 시간, 남이 들고 있으면 경고. 오른쪽 아래에 Q 안내.
- 캐릭터끼리는 충돌하지 않는다 (월드=1층, 캐릭터=2층). HTML도 캐릭터는 월드 상자하고만 부딪힌다.
- 연출 (8단계): 수치는 `GameData.HITSTOP`·`SHAKE`·`HURT`·`DMG_DIR`·`RAGDOLL`·`RAGDOLL_KICK`·`DEATH_CAM`.
  - 죽으면 `Combat.kill`이 모델을 래그돌로 바꾸고(`v.ragdoll`) 모델은 지운다. 부활할 때 `set_class`가 새로 만든다. 죽음 카메라는 래그돌 골반을 따라간다.
  - 히트스톱은 `Engine.time_scale = 0.12`로 한다. 남은 시간은 실제 시간으로 줄이고, 경기 시계도 실제 시간대로 간다. 일시정지·메뉴로 가면 바로 푼다.
  - 내가 맞으면 화면 흔들림(`player.shake`), 붉은 테두리(`hud.on_hurt`), 때린 쪽 붉은 호(`hud.dmg_dir`) — Combat의 `hurt`·`dmg_dir` 신호.
  - 효과음: `Sfx.play(이름, 위치)`. 위치가 있으면 경기 중에만 나고 거리에 따라 작아진다. 헤드리스에선 소리 없이 `Sfx.played`에 이름만 쌓인다 (테스트용).
  - 병과 의상은 HTML makeModel 그대로 (`derp_model.gd`의 `_build_outfit`·`_build_robe`·`_build_head_extras`).

**HTML과 다른 점 (의도한 것)**
- 충돌은 HTML의 직접 만든 AABB 대신 Godot 물리(`move_and_slide`)를 쓴다.
- 0.56m 이하 턱은 `try_step()`이 자동으로 올려준다.
- 속도·가속·마찰·넘어짐 공식은 HTML과 같다.
- 단색 환경광은 HTML의 HemisphereLight를 근사한 것이다.

---

## 로드맵 (이 순서대로)

HTML에서 볼 함수는 줄 번호와 함께 적었다. 줄 번호는 원본 기준이라 약간 어긋날 수 있으니 함수 이름으로 찾는다.

| 단계 | 내용 | HTML 참고 |
|---|---|---|
| ✅ 1 | 이동·카메라·맵 | `movement` 810, `trip` 837, `integrate` 856, `updateCamera` 1881, `buildWorld` 425, `makeModel` 549, `animModel` 1330 |
| ✅ 2 | **피격 판정·데미지 기초**: 머리/몸 판정, `damage()`, 넉백, 투구 날아감, 체력 재생, 죽음·3초 뒤 리스폰, 스폰 지점 고르기 | `hitTest` 950, `damage` 1024, `kill` 1078, `knockHelmet` 1097, `spawn` 793, `simulate` 1870(재생) |
| ✅ 3 | **돌멩이** (야만인): 투사체 시스템(중력·월드 충돌·사람 충돌), 던지는 팔 모션, 맞은 효과(조각·링·숫자) | `fire` 923, `updateProjectiles` 958, `impactFx` 1049 |
| ✅ 4 | **활·석궁·성수**: 활 당기기·후들거림·손 미끄러짐, 석궁 장전, 성수 충전 3개·웅덩이·둔화, 1인칭 무기 모델(뷰모델), 반동 | `weaponUpdate` 898, `shatter`/`updateZones` 875, `buildVM` 1391, `updateVM` 1449 |
| ✅ 5 | **봇 AI + 난이도**: 대상 고르기, 반응 시간, 조준 오차, 앞질러 쏘기(lead), 포물선 계산, 끼임 탈출 | `botUpdate` 1255, `aimSolve` 1313, `DIFF` |
| ✅ 6 | **매치 흐름 + 메뉴 + HUD**: 메인메뉴(일반대전 토스트 / AI대전 → 난이도 → 병과 → 바로 시작 / 친구대전 / 설정 / 나가기), 4분·20킬, 킬피드, 점수판(Tab), 사망 화면, 일시정지, 결과 화면 | `startMatch` 1632, `endMatch` 1650, `updateHUD` 1575, HTML 상단 CSS/마크업 |
| ✅ 7 | **특수 아이템**: 닭(잡기·던지기·맞으면 넘어짐), 대물 저격총, AK-47, 기사의 말+마상창 | `updateChickens` 1114, `updateSniper` 1220, `updateAK`, `updateHorses` 1184, `lanceCheck` 1176 |
| ✅ 8 | **연출**: 죽으면 래그돌, 히트스톱, 화면 흔들림, 피격 방향 표시, 병과별 의상 디테일, 효과음 | `makeRagdoll` 664, `sfx` 747 |
| ✅ 9 | **친구대전 (멀티플레이)** — 아래 "멀티플레이 설계" 참고 | `MP` 1713 이하 |
| 10 | 웹 내보내기 + 최적화 | — |

각 단계의 완료 기준: 테스트 통과 + 사용자가 플레이해서 HTML 버전과 느낌이 같다고 확인.

---

## 게임 규칙 명세

수치는 전부 `game_data.gd`에 있다. 여기서는 **동작**을 설명한다.

### 이동 (완료)
- 걷기 속도 = `BASE_SPEED × 병과 speed × 무기 배율`이다.
  - 무기 배율: 저격총 0.9, AK 0.95
  - Shift로 달리면 ×1.35. 앞으로 갈 때만, 공격·조준·앉기 중엔 안 됨
  - 성수 웅덩이 안이면 ×0.25, 닭을 들고 있으면 ×1.05
- 땅 마찰은 6.5, 넉백 중엔 2, 슬라이드 중엔 0.7, 넘어져 있을 땐 0.9다.
- 가속은 땅 12, 공중 80이다. 공중 제어의 최대 속도는 1.1이라 공중에선 방향만 살짝 바뀐다.
- 수평 속도 상한은 최대속도의 2.4배다. 넉백 중엔 최소 32까지 허용한다.
- **슬라이드**: 최대속도의 55% 이상으로 달리다 Ctrl/C를 누른 순간 시작한다.
  - 0.8초 동안 미끄러지고, 시작할 때 속도 +3.2(최대속도 2배까지)
  - 다시 쓰려면 1.1초 기다려야 함
- **급회전 넘어짐**: 최대 걷기속도의 75% 이상으로 움직인 뒤 0.25초 안에 반대쪽(내적 < -0.34)을 누르면 넘어진다.
  - 키를 바꾸는 틈에 속도가 줄어도 넘어지게 하려고 0.25초 창을 둔다.
  - 넘어진 상태로 0.6초 동안 미끄러지고, 그동안 입력이 막힌다.
  - 일어난 뒤 0.5초 동안은 다시 넘어지지 않는다.
- 점프 넘어짐과 정지 넘어짐은 사용자 요청으로 **제거됨**. 다시 넣지 말 것.

### 병과
| 병과 | 무기 | 속도 배율 | 체력 | 특징 |
|---|---|---|---|---|
| 야만인 | 돌멩이 | 1.372 (달리기 10.0 m/s) | 90 (사용자 요청으로 100→90) | 짐승 해골 투구 |
| 궁수 | 활 | 1.0 | 100 | 빨간 갑옷 |
| 석궁병 | 석궁 | 0.85 | 110 | 파란 갑옷 |
| 성직자 | 성수 | 1.0 | 100 | 체력 재생 2배 (초당 20) |

### 피해 공통
- 머리 판정: 투구를 쓰고 있으면 ×1.5. 첫 헤드샷에 투구가 날아가고, 그 뒤로는 맨머리라 ×2.0이다.
- 넉백은 맞은 방향으로 수평으로 밀고 살짝 띄운다.
  - 헤드샷이면 넉백 ×1.25, 띄우기 ×1.15
  - 말 탄 대상은 넉백 ×0.2
  - 맞으면 `kb_t` 0.45초 동안 마찰이 줄고 속도 상한이 풀린다 (AK는 0.12초). 봇은 경직 0.3초, 석궁에 맞으면 0.5초.
- 체력 재생: 5초 동안 안 맞으면 초당 10씩 찬다 (성직자는 20).
- 리스폰은 3초 뒤다.
  - 다른 사람에게서 가장 먼 스폰 지점 4곳 중 하나를 고른다.
  - 스폰 직후 1.2초 무적이다.
  - 봇은 죽을 때 35% 확률로 병과를 바꾼다.

### 무기
- **돌멩이**: 피해 10, 0.4초마다 연사.
  - 속도 32, 사거리 15m (넘으면 사라짐)
- **활**: 누르고 있으면 당긴다. 1.5초에 끝까지 당겨지고, 놓으면 쏜다.
  - 피해 35~55, 속도 42~72 (당긴 정도에 비례). 0.08초 미만으로 당기면 안 나감
  - 다시 쏘려면 1.0초 기다려야 함
  - 끝까지 당긴 채로 1초가 넘으면 조준이 후들거린다.
  - 3초가 되면 손이 미끄러져 엉뚱한 방향으로 나간다 ("손이 미끄러졌다!").
- **석궁**: 피해 75 (헤드샷이면 한 방). 장전 4초, 속도 100, 중력 6.
  - 장전 중엔 화면이 위로 들리는 모션이 나온다. 아래로 내리면 화면을 가려서 바꿨다.
- **성수** (성직자): 최대 3개까지 들고 있고, 3초마다 1개씩 찬다. 한 번 던지면 0.4초 기다린다.
  - 땅에 닿으면 깨지면서 반경 3m 웅덩이가 3초 동안 남는다.
  - 웅덩이 안에서는 0.5초마다 피해 8을 받고 75% 느려진다 (속도 ×0.25).
  - 내 웅덩이는 테두리가 금색, 적 웅덩이는 빨간색이다.
  - 던질 곳에 착지 지점 표시가 뜬다.
- **대물 저격총** (특수): 맵에 가끔 빛기둥과 함께 나타나고, 닿으면 바로 줍는다.
  - 히트스캔, 맞으면 즉사. 5발 쏘면 사라진다. 한 발 쏘면 1초 기다린다.
  - 우클릭하면 스코프 조준. Q로 원래 무기와 바꾼다. 들고 있으면 속도 ×0.9.
  - 죽으면 그 자리에 남은 탄과 함께 떨어진다.
- **AK-47** (특수, Krunker 돌격소총 기준): 피해 23 (30m 넘으면 줄어서 80m에서 18), 0.12초마다 연사, 25발 쓰면 사라짐.
  - 그냥 쏘면 0.03 퍼짐. 움직이거나 공중이면 더 퍼지고, 오래 쏠수록 더 퍼진다 (최대 +0.05).
  - 우클릭하면 0.006 퍼짐에 1.6배 확대. 들고 있으면 속도 ×0.95, 꺼내는 데 0.3초.
  - 저격총과 AK 중 하나만 들 수 있다.
- **닭**: 맵에 돌아다니고(최대 4마리), 닿으면 잡는다. 클릭하면 던진다.
  - 맞으면 피해 1에 무조건 넘어진다. 던진 닭은 다시 돌아다닌다.
  - 잡고 있으면 속도 ×1.05.
- **기사의 말 + 마상창**: 닿으면 7초 동안 탄다. 속도 20.5 m/s.
  - 창끝(앞 1.2~3.5m)에 걸리면 피해 70에 아주 멀리 날아간다 (넉백 28, 띄우기 9). 같은 대상은 0.8초에 한 번만 맞는다.
  - 말 몸통에 치이면 넘어진다. 말 위에선 넘어지지 않고 앉기도 안 된다.
  - 시간이 끝나면 말이 달아난다.

### 봇 난이도
| | 반응(초) | 조준 오차 배율 | 헤드샷 노림 | 앞질러 쏘기 | 사격 확률 |
|---|---|---|---|---|---|
| 쉬움 | 1.0~1.5 | 1.5 | 0% | 0~0.4 | 0.5 |
| 보통 | 0.7~1.1 | 1.0 | 3% | 0.1~0.6 | 0.65 |
| 어려움 | 0.4~0.7 | 0.6 | 10% | 0.4~0.9 | 0.85 |

- 봇은 0.3~0.55초마다 생각한다.
  - 65m 안에서 대상을 고른다. 안 보이는 대상은 거리 ×2.4로 계산하고, 현재 대상은 6m 보너스를 준다.
  - 생각할 때마다 조준 오차를 새로 굴린다.
- 사용자 피드백으로 봇 정확도를 **두 번 낮췄다.** 너무 잘 맞히지 않게 유지할 것.

### 매치
- AI대전: 봇 7명과 개인전. 4분이 지나거나 누군가 20킬을 하면 끝난다.
- 메인메뉴: 일반대전(누르면 "추후 업데이트 될 내용입니다." 토스트), AI대전(난이도 → 병과 → 즉시 입장), 친구대전, 설정(감도·시점), 나가기.

### 조작
| 동작 | 키 |
|---|---|
| 이동 | WASD |
| 달리기 | 왼쪽 Shift |
| 슬라이드 | 왼쪽 Ctrl 또는 C |
| 점프 | Space |
| 공격 | 좌클릭 |
| 조준 | 우클릭 |
| 특수무기 전환 | Q |
| 시점 전환 (기본 3인칭 어깨 너머) | V |
| 점수판 | Tab |
| 마우스 풀기·일시정지 | Esc |

마우스 감도 공식은 `감도 × 0.0021 × (현재FOV/85)`이다.

---

## 멀티플레이 (9단계 — 구현됨, 같은 와이파이만)

사용자와 정한 것: **중계 서버 없이 같은 와이파이(LAN)에서만**. ENet 직접 연결이라 PC 전용이다 (웹 빌드에선 안 됨).
- 방 만들기: 방장 컴퓨터가 ENet 서버(포트 `NET.port` 24680)가 되고, UDP 24681로 `"JNP1|코드|포트"`를 0.5초마다 방송한다 (255.255.255.255와 127.0.0.1).
- 참가: 코드 4자리를 넣으면 6초 동안 방송을 듣다가 코드가 맞는 방에 접속한다. 코드 칸에 방장 IP(대기실에 보임)를 넣어도 된다.
- 처음 방을 만들 때 Windows 방화벽이 Godot 허용을 물어본다. **개인 네트워크 허용**을 눌러야 친구가 들어온다.
- 대기실(menu `lobby` 페이지): 방 코드, 사람 목록(병과·방장·게임 중), 내 병과, 게임 시작(방장) / 진행 중인 게임 참가(친구).
- 친구대전엔 봇·닭이 없다. 일시정지해도 게임은 안 멈춘다. 20킬·시간 종료는 방장이 판단해 알린다.
- 결과 화면: 한 판 더 = 방장만 (친구는 자동으로 들어감), 병과 다시 고르기 = 대기실, 메인 메뉴 = 방 나가기.
- 남의 캐릭터는 `is_remote`(player.gd `_physics_process`를 안 돎), Net `_apply_remote`가 받은 상태를 따라간다.
- Combat `damage()`는 친구대전에서 **내 캐릭터만** 깎는다. 남을 맞히면 그쪽 컴퓨터가 판정해 "h"/"k" 사건을 보낸다. 처치 수는 죽인 사람이 "k"를 받고 스스로 센다.
- 아이템은 방장만 생성·떨어뜨림. 친구가 닿으면 `net.request` → 방장이 `grants`에 적어 `_it`로 알려줌 (HTML seq/grant).
- **HTML과 다른 점**: 방장이 나가면 방이 끝난다 (HTML은 다음 사람이 방장을 이어받음).
- 수치는 `GameData.NET`.

### 처음 설계 메모

HTML 버전은 claude.ai의 방(room) 기능 위에서 돌아서 **Godot에선 쓸 수 없다.** 새로 만든다.
- 웹 빌드는 `WebSocketMultiplayerPeer`를 쓴다 (PC 전용이면 `ENetMultiplayerPeer`).
- 방 코드 4자리로 들어가려면 **사람을 이어주는 중계 서버가 필요하다.** 선택지는 Nakama 같은 오픈소스 서버를 직접 띄우거나 W4 Cloud 같은 서비스를 쓰는 것이다.
  - 어떤 걸 쓸지는 그 단계에서 사용자와 정한다.
- 권한 구조는 HTML과 같게 한다.
  - 방장: 매치 시간·종료, 특수 아이템 생성과 줍기 승인
  - 투사체: 맞은 사람 쪽에서 판정
  - 저격총·AK·마상창: 쏜 사람 쪽에서 판정
- 동기화는 30Hz로 한다. 위치·속도·yaw/pitch·상태 비트(앉기·슬라이드·달리기·투구·특수무기)·넘어짐·체력·무기를 보내고, 사건(발사·명중·처치)은 따로 보낸다.

---

## 테스트 실행

Godot 실행 파일 경로는 환경에 맞게 바꾼다 (Windows 예: `Godot_v4.7.2-stable_win64.exe`).

```bash
# 스크립트 오류 확인 (2초 실행 후 종료)
godot --headless --path . --quit-after 120

# 이동·전투·돌멩이 자동 테스트 — 모두 "ALL PASS"가 나와야 함
godot --headless --fixed-fps 60 --path . -s tests/test_movement.gd
godot --headless --fixed-fps 60 --path . -s tests/test_combat.gd
godot --headless --fixed-fps 60 --path . -s tests/test_stone.gd
godot --headless --fixed-fps 60 --path . -s tests/test_bow.gd
godot --headless --fixed-fps 60 --path . -s tests/test_crossbow.gd
godot --headless --fixed-fps 60 --path . -s tests/test_holy.gd
godot --headless --fixed-fps 60 --path . -s tests/test_bot.gd
godot --headless --fixed-fps 60 --path . -s tests/test_match.gd
godot --headless --fixed-fps 60 --path . -s tests/test_items.gd
godot --headless --fixed-fps 60 --path . -s tests/test_fx.gd
godot --headless --fixed-fps 60 --path . -s tests/test_net.gd   # 포트 24680·24681을 씀
```

새 `class_name` 스크립트를 추가하면 한 번 `godot --headless --editor --path . --quit`로 클래스 목록을 갱신해야 다른 스크립트가 찾는다.

테스트에서 `await physics_frame` 한 번만 누르고 바로 떼면 캐릭터가 입력을 읽기 전에 떼질 수 있다. 한 번 쏘기는 2프레임 누른다.
`-s` 테스트 스크립트에선 오토로드 이름(`GameData`)을 바로 쓸 수 없다. `root.get_node("GameData")`로 접근한다.
같은 이유로 테스트 스크립트에서 `BotAI`·`Combat` 같은 class_name 타입을 직접 적으면(`var ai: BotAI`, `Combat.seg_point`) GameData보다 먼저 컴파일돼 실패한다. 타입 없이 쓰거나 인스턴스(`C.seg_point`)로 부른다.
main.tscn은 메뉴 상태로 시작한다. 경기가 필요한 테스트는 `root.add_child(main)` 뒤에 `main.start_match.call_deferred()`를 부른다 (바로 부르면 Main이 아직 트리에 없음).
히트스톱은 프레임 수로 시간을 재는 테스트를 망치므로 테스트에선 `GameData.hitstop_enabled = false`로 끈다.
그 전에 `GameData`의 save_enabled·third_person·difficulty·chosen_cls를 정해 두면 저장된 설정과 상관없이 같은 조건으로 돈다.
플레이어는 `scripted_input` 딕셔너리로 입력을 흉내 낼 수 있다. 같은 구조로 봇 입력에도 쓸 수 있다.
