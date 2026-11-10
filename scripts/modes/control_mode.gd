class_name ControlMode
extends Node
## 쟁탈전 규칙 (사용자 요청 — HTML엔 없음). 수치는 GameData.MODES.control.
## Main이 쟁탈전을 시작할 때 만들어 Combat.mode에 걸어 둔다 (개인전이면 Combat.mode = null → 기존 그대로).
## 한 라운드: 모두 스폰룸에서 시작 → unlock초 뒤 거점 열림 → 점령·경합·점수 → 한 팀이 100%면 승리.
## 3라운드 2선승. 라운드 사이 round_gap초 결과, 마지막 라운드 뒤 end_gap초 뒤 결과 화면 (match_over).
## 판정은 물리 프레임마다 (Combat보다 뒤 — 죽은 사람은 안 셈).

signal banner(title: String, sub: String)          # 화면 가운데 큰 알림 (Main이 HUD로)
signal round_over(winner: String)                  # 라운드 끝 ("" = 무승부)
signal match_over(winner: String)                  # 마지막 결과 화면을 띄울 때

const TEAMS := ["blue", "red"]

var combat: Combat
var world: MapControl
var me: PlayerController

var phase := "locked"    # locked(거점 닫힘) / open / gap(라운드 사이) / over(끝)
var round_no := 1
var wins := {"blue": 0, "red": 0}
var pct := {"blue": 0, "red": 0}   # 라운드 점수 (0~100, 거점을 뺏겨도 유지)
var holder := ""         # 거점 주인 ("" = 중립)
var cap_team := ""       # 지금 게이지를 채우는 팀 (owner가 아닌 팀)
var cap_prog := 0.0      # 0~1
var contested := false
var overtime := false
var round_t := 0.0       # 이번 라운드 지난 시간
var unlock_left := 0.0
var gap_left := 0.0
var last_winner := ""
var match_winner := ""
var counts := {"blue": 0, "red": 0}  # 지금 원 안 인원
var _score_acc := 0.0


func M() -> Dictionary:
	return GameData.MODES.control


static func other(team: String) -> String:
	return "red" if team == "blue" else "blue"


static func team_name(team: String) -> String:
	return str(GameData.MODES.control.teams[team].name) if team != "" else "무승부"


## 경기 시작 (라운드 1)
func start(c: Combat, w: MapControl, my: PlayerController) -> void:
	combat = c
	world = w
	me = my
	round_no = 1
	wins = {"blue": 0, "red": 0}
	match_winner = ""
	for e in combat.ents:
		e.cap_time = 0.0
	_begin_round()


func _begin_round() -> void:
	phase = "locked"
	pct = {"blue": 0, "red": 0}
	holder = ""
	cap_team = ""
	cap_prog = 0.0
	contested = false
	overtime = false
	round_t = 0.0
	_score_acc = 0.0
	unlock_left = float(M().unlock)
	last_winner = ""
	combat.clear_match_objects()
	for e in combat.ents:
		if e.spectating:
			continue
		if e.mounted > 0:
			combat.items.dismount(e)
		e.alive = false
		combat.spawn(e)
	banner.emit("라운드 %d" % round_no, "%d초 뒤에 거점이 열립니다" % int(M().unlock))
	_look()


## 거점 안인가 (정사각형: 가로·세로 ±cap_half, 높이 cap_h)
func in_circle(e: PlayerController) -> bool:
	var p := e.global_position
	var c := world.cap_pos
	var h := float(M().cap_half)
	return absf(p.x - c.x) <= h and absf(p.z - c.z) <= h and p.y > c.y - 1.0 and p.y < c.y + float(M().cap_h)


## 자기 팀 스폰룸 안인가 (회복) / 아무 스폰룸 안인가 (공격 금지)
func in_own_spawn(e: PlayerController) -> bool:
	return e.team != "" and MapControl.spawn_room(e.team).has_point(e.global_position + Vector3(0, 0.5, 0))


func in_any_spawn(e: PlayerController) -> bool:
	for t: String in TEAMS:
		if MapControl.spawn_room(t).has_point(e.global_position + Vector3(0, 0.5, 0)):
			return true
	return false


## Combat.weapon_update가 물음: 공격 못 하는 때 (스폰룸 안, 라운드 사이)
func no_attack(e: PlayerController) -> bool:
	return phase == "gap" or phase == "over" or in_any_spawn(e)


## Combat.damage가 물음: 피해를 막는 때 (라운드 사이)
func no_damage() -> bool:
	return phase == "gap" or phase == "over"


func respawn_time() -> float:
	return float(M().respawn)


## 팀 스폰 지점 (비어 있는 곳 먼저)
func spawn_pos(e: PlayerController) -> Vector3:
	var spots := MapControl.spawn_spots(e.team if e.team != "" else "blue")
	spots.shuffle()
	for p in spots:
		var free := true
		for o in combat.ents:
			if o != e and o.alive and o.global_position.distance_to(p) < 1.2:
				free = false
				break
		if free:
			return p
	return spots[0]


## 한 팀 n명일 때 점령 속도 (초당 게이지)
func cap_rate(n: int) -> float:
	var mul: Array = M().cap_mul
	return float(mul[mini(n, mul.size() - 1)]) / float(M().cap_time)


func update(dt: float) -> void:
	if phase == "over":
		return
	if phase == "gap":
		gap_left -= dt
		if gap_left <= 0:
			_after_gap()
		return
	round_t += dt
	_spawn_heal(dt)
	counts = {"blue": 0, "red": 0}
	for e in combat.ents:
		if e.alive and not e.spectating and e.team != "" and in_circle(e):
			counts[e.team] += 1
			if phase == "open":
				e.cap_time += dt
	if phase == "locked":
		unlock_left -= dt
		if unlock_left <= 0:
			phase = "open"
			_announce("거점이 열렸습니다!", "거점으로 가서 점령하세요")
		_look()
		return
	step_capture(dt)
	if phase == "open" and round_t >= float(M().round_max):  # 안전장치: 4분 넘으면 % 높은 팀
		var w := "blue" if pct.blue > pct.red else ("red" if pct.red > pct.blue else holder)
		_end_round(w)
	_look()


## 점령·경합·점수 (counts를 보고 — 테스트는 counts를 직접 넣고 부름)
func step_capture(dt: float) -> void:
	var nb: int = counts.blue
	var nr: int = counts.red
	contested = nb > 0 and nr > 0
	if not contested:
		var t := "blue" if nb > 0 else ("red" if nr > 0 else "")
		var n := maxi(nb, nr)
		if t == "":  # 아무도 없음: 채워 둔 게이지가 천천히 빠짐
			cap_prog = maxf(0.0, cap_prog - float(M().decay) * dt)
			if cap_prog <= 0:
				cap_team = ""
		elif t == holder:  # 주인 팀만 있음: 상대가 채워 둔 게이지를 빼냄
			cap_prog = maxf(0.0, cap_prog - cap_rate(n) * dt)
			if cap_prog <= 0:
				cap_team = ""
		else:
			if cap_team != "" and cap_team != t:  # 상대 팀이 채워 둔 걸 먼저 0으로
				cap_prog -= cap_rate(n) * dt
				if cap_prog <= 0:
					cap_prog = 0.0
					cap_team = t
			else:
				cap_team = t
				cap_prog += cap_rate(n) * dt
				if cap_prog >= 1.0:
					_captured(t)
	# 점수: 주인 팀 %가 score_every초마다 1. 99%에서 적이 원 안이면 멈춤 = 연장전
	if holder != "":
		var enemy_in: bool = counts[other(holder)] > 0
		var at: int = int(M().overtime_at)
		if pct[holder] >= at and enemy_in:
			if not overtime:
				overtime = true
				_announce("연장전!", "거점에서 적을 몰아내세요")
			_score_acc = 0.0
		else:
			if overtime and not enemy_in:  # 연장전에서 적이 다 나가면 바로 100% → 승리
				overtime = false
				pct[holder] = 100
				_end_round(holder)
				return
			_score_acc += dt
			while _score_acc >= float(M().score_every) and phase == "open":
				_score_acc -= float(M().score_every)
				pct[holder] = mini(100, pct[holder] + 1)
				if pct[holder] >= 100:
					_end_round(holder)
	else:
		overtime = false


func _captured(t: String) -> void:
	var prev := holder
	holder = t
	cap_team = ""
	cap_prog = 0.0
	overtime = false
	_score_acc = 0.0
	if me and me.team != "":
		if t == me.team or prev != me.team:  # '빼앗겼습니다'는 우리 거점이었을 때만
			_announce("%s이 거점을 점령했습니다!" % team_name(t), "")
		else:
			_announce("거점을 빼앗겼습니다!", "%s이 거점을 점령했습니다" % team_name(t))
	else:
		_announce("%s이 거점을 점령했습니다!" % team_name(t), "")


func _end_round(w: String) -> void:
	if phase != "open" and phase != "locked":
		return
	last_winner = w
	if w != "":
		wins[w] += 1
	overtime = false
	contested = false
	phase = "gap"
	var final: bool = round_no >= 3 or (w != "" and wins[w] >= int(M().rounds_to_win))
	if final:
		match_winner = "blue" if wins.blue > wins.red else ("red" if wins.red > wins.blue else "")
		gap_left = float(M().end_gap)
		var mine := me != null and me.team == match_winner
		_announce(("%s 승리!" % team_name(match_winner)) if match_winner != "" else "무승부!",
			("우리 팀이 이겼어요! " if mine else "") + "블루 %d : %d 레드" % [wins.blue, wins.red])
	else:
		gap_left = float(M().round_gap)
		var mine := me != null and me.team == w
		var t := ("라운드 승리!" if mine else "라운드 패배") if w != "" else "라운드 무승부"
		_announce(t, "블루 %d : %d 레드 · 다음 라운드까지 %d초" % [wins.blue, wins.red, int(gap_left)])
	round_over.emit(w)


func _after_gap() -> void:
	if match_winner != "" or round_no >= 3 or wins.blue >= int(M().rounds_to_win) or wins.red >= int(M().rounds_to_win):
		phase = "over"
		match_over.emit(match_winner)
		return
	round_no += 1
	_begin_round()


func _announce(t: String, sub: String) -> void:
	banner.emit(t, sub)
	Sfx.play("horn")


func _spawn_heal(dt: float) -> void:
	for e in combat.ents:
		if e.alive and not e.is_remote and in_own_spawn(e):
			e.hp = minf(float(GameData.class_hp(e.cls)), e.hp + float(M().spawn_heal) * dt)


## 화면 위 상태 문구
func status_text() -> String:
	match phase:
		"locked":
			return "거점 열림까지 %d초" % ceili(unlock_left)
		"gap", "over":
			return "블루 %d : %d 레드" % [wins.blue, wins.red]
	if overtime:
		return "연장전!"
	if contested:
		return "경합 중!"
	if cap_team != "":
		return "%s 점령 중 %d%%" % [team_name(cap_team), int(cap_prog * 100)]
	if holder != "":
		return "%s 거점" % team_name(holder)
	return "거점을 점령하세요"


static func team_color(team: String) -> Color:
	if team == "":
		return GameData.col(GameData.MODES.control.neutral_col)
	return GameData.col(GameData.team_hex(team, "body"))


## 거점 겉모양 (테두리 = 주인 색, 게이지 = 점령 중인 팀 색, 깃발)
func _look() -> void:
	if world == null or world.cap_rim == null:
		return
	if phase == "locked":
		var g := GameData.col(GameData.MODES.control.locked_col)
		world.set_cap_look(g, g, 0.0, g, 0.0)
		return
	var rim := team_color(holder)
	var fill := team_color(cap_team) if cap_team != "" else rim
	world.set_cap_look(rim, fill, cap_prog, rim, 1.0 if holder != "" else cap_prog)
