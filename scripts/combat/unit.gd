class_name Unit
extends Node2D
## 전투 유닛 (아군 캐릭터와 적 공통). 로직은 CombatWorld.simulate() 가 매 프레임 tick() 으로 진행합니다.
## 그래픽은 임시 픽셀 도형입니다 (최종 픽셀 아트 스프라이트로 교체 예정).

signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

const ULT_COST := 100.0
const DOWNED_FADE := 0.35

var world: CombatWorld
var team: int = Team.PLAYER
var data: CharacterData          ## 아군만
var enemy_kind: StringName       ## 적만
var display_name := ""
var level := 1
var element := 0

var max_hp := 1.0
var hp := 1.0
var base_atk := 1.0
var base_def := 0.0
var crit_rate := 0.0             ## %
var crit_dmg := 50.0             ## %
var base_move := 60.0
var base_range := 20.0
var attack_interval := 1.0
var basic_mult := 1.0
var radius := 6.0
var color_main := Color.WHITE
var color_sub := Color.GRAY

var contamination := 0.0         ## 오염도 = 궁극기 게이지 (0~100). 세계관의 변이와 무관한 전투 자원.
var skill_cd := 0.0
var ult_cd := 0.0
var attack_cd := 0.0
var statuses := {}               ## StringName -> {"t": 남은 초, ...}
var alive := true
var controlled := false
var auto_skills := false         ## 동료 스킬 자동 사용
var facing := Vector2.RIGHT
var target: Unit
var kit: SkillKit
var brain: RefCounted
var downed_time := 0.0


func setup_character(d: CharacterData, lvl: int, w: CombatWorld) -> void:
	world = w
	data = d
	team = Team.PLAYER
	level = lvl
	display_name = d.display_name
	element = d.element
	var s := Progression.stats_at(d, lvl)
	max_hp = s.hp
	hp = max_hp
	base_atk = s.atk
	base_def = s.def
	crit_rate = s.crit_rate
	crit_dmg = s.crit_dmg
	base_move = d.move_speed
	base_range = d.attack_range
	attack_interval = d.attack_interval
	basic_mult = d.basic_mult
	color_main = d.color_main
	color_sub = d.color_sub
	name = String(d.id)
	kit = SkillKit.create(self)


func setup_enemy(kind: StringName, w: CombatWorld) -> void:
	world = w
	team = Team.ENEMY
	enemy_kind = kind
	var e: Dictionary = EnemyDefs.get_def(kind)
	display_name = tr(e.name_key)
	element = e.element
	max_hp = e.hp
	hp = max_hp
	base_atk = e.atk
	base_def = e.def
	crit_rate = 5.0
	base_move = e.speed
	base_range = e.range
	attack_interval = e.interval
	radius = e.radius
	color_main = e.color
	color_sub = e.color.darkened(0.4)


# ---------- 상태 ----------

func has_status(s: StringName) -> bool:
	return statuses.has(s)


func add_status(s: StringName, duration: float, extra: Dictionary = {}) -> void:
	var entry: Dictionary = statuses.get(s, {})
	entry["t"] = maxf(duration, entry.get("t", 0.0))
	entry.merge(extra, true)
	statuses[s] = entry


func remove_status(s: StringName) -> void:
	statuses.erase(s)


func _sum(table: Dictionary) -> float:
	var total := 0.0
	for s in statuses:
		total += table.get(s, 0.0)
	return total


func move_speed() -> float:
	if has_status(Status.ROOT):
		return 0.0
	return base_move * maxf(0.2, 1.0 + _sum(Status.MOVE))


func attack_speed_mult() -> float:
	var m := 1.0 + _sum(Status.ATTACK_SPEED)
	if kit:
		m += kit.attack_speed_bonus()
	return m


func atk() -> float:
	return base_atk * (1.0 + _sum(Status.ATK))


func def() -> float:
	return base_def * (1.0 + _sum(Status.DEF))


func attack_range() -> float:
	return base_range + (kit.range_bonus() if kit else 0.0)


func effective_crit_rate() -> float:
	return crit_rate + (kit.crit_bonus() if kit else 0.0)


func is_targetable() -> bool:
	return alive and not has_status(Status.STEALTH)


func hp_ratio() -> float:
	return hp / max_hp


# ---------- 피해·회복 ----------

## 실제로 깎인 HP를 돌려줍니다. 보호막이 먼저 흡수합니다.
func take_damage(amount: float) -> float:
	if not alive or has_status(Status.DODGE):
		return 0.0
	if has_status(Status.SHIELD):
		var sh: Dictionary = statuses[Status.SHIELD]
		var absorbed := minf(sh.get("amount", 0.0), amount)
		sh["amount"] = sh.get("amount", 0.0) - absorbed
		amount -= absorbed
		if sh["amount"] <= 0.0:
			remove_status(Status.SHIELD)
	hp -= amount
	if kit:
		kit.on_damaged(amount)
	if hp <= 0.0:
		hp = 0.0
		_die()
	queue_redraw()
	return amount


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()


func revive(fraction: float) -> void:
	alive = true
	hp = max_hp * fraction
	downed_time = 0.0
	modulate.a = 1.0
	queue_redraw()


func add_contamination(v: float) -> void:
	if team == Team.PLAYER and alive:
		contamination = clampf(contamination + v, 0.0, ULT_COST)


func _die() -> void:
	alive = false
	statuses.clear()
	modulate.a = DOWNED_FADE
	died.emit(self)


# ---------- 행동 ----------

func can_use_skill() -> bool:
	return kit != null and kit.can_skill()


## 궁극기: 오염도 100% + 쿨타임 0 (사용자 결정 11/8). 라는 쓰러져 있어도 사용 가능.
func can_use_ult() -> bool:
	if kit == null or contamination < ULT_COST or ult_cd > 0.0:
		return false
	return alive or kit.can_ult_while_downed()


func use_skill(hold: bool = false, aim: Vector2 = Vector2.INF) -> bool:
	if not can_use_skill():
		return false
	return kit.use_skill(hold, _aim_or_default(aim))


func use_ult(aim: Vector2 = Vector2.INF) -> bool:
	if not can_use_ult():
		return false
	var ok := kit.use_ult(_aim_or_default(aim))
	if ok:
		contamination = 0.0
		ult_cd = data.ult_cooldown
	return ok


func _aim_or_default(aim: Vector2) -> Vector2:
	if aim != Vector2.INF:
		return aim
	if target and target.alive:
		return target.position
	return position + facing * 40.0


func try_basic_attack() -> void:
	if attack_cd > 0.0 or target == null or not target.alive:
		return
	if position.distance_to(target.position) > attack_range() + target.radius:
		return
	facing = (target.position - position).normalized()
	attack_cd = attack_interval / attack_speed_mult()
	var bonus := kit.basic_bonus_flat() if kit else 0.0
	var dealt: float = world.deal_damage(self, target, basic_mult, {"bonus_flat": bonus, "basic": true})
	world.spawn_fx(&"tracer" if attack_range() > 40 else &"slash", position, {"to": target.position, "color": color_main})
	if dealt > 0.0 and kit:
		kit.on_basic_hit(target)


func dodge(dir: Vector2) -> void:
	if has_status(Status.DODGE) or has_status(Status.ROOT):
		return
	add_status(Status.DODGE, 0.25, {"dir": dir.normalized()})


func tick(delta: float) -> void:
	if not alive:
		downed_time += delta
		if kit:
			kit.tick_downed(delta)
		return
	skill_cd = maxf(0.0, skill_cd - delta)
	ult_cd = maxf(0.0, ult_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	for s in statuses.keys():
		statuses[s]["t"] -= delta
		if statuses[s]["t"] <= 0.0:
			statuses.erase(s)
			if kit:
				kit.on_status_ended(s)
	if kit:
		kit.tick(delta)
	if has_status(Status.DODGE):
		world.move_unit(self, statuses[Status.DODGE]["dir"] * 260.0 * delta)
	elif not controlled and brain:
		brain.think(self, delta)
	modulate.a = 0.45 if has_status(Status.STEALTH) else 1.0
	queue_redraw()


func move_dir(dir: Vector2, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	facing = dir
	world.move_unit(self, dir * move_speed() * delta)


func move_toward_point(p: Vector2, delta: float, stop_dist: float = 2.0) -> void:
	if position.distance_to(p) > stop_dist:
		move_dir(p - position, delta)


# ---------- 그리기 (임시 픽셀 도형) ----------

func _draw() -> void:
	var w := radius * 1.4
	var h := radius * 2.2
	if controlled:
		draw_arc(Vector2(0, 2), radius + 3, 0, TAU, 20, Color(1, 1, 1, 0.6), 1.0)
	# 그림자
	draw_rect(Rect2(-w * 0.6, h * 0.45, w * 1.2, 2), Color(0, 0, 0, 0.4))
	# 몸통·머리
	draw_rect(Rect2(-w / 2, -h / 2 + 3, w, h - 3), color_main)
	draw_rect(Rect2(-w / 2, -h / 2 + 3 + (h - 3) * 0.55, w, 2), color_sub)
	draw_rect(Rect2(-w * 0.35, -h / 2 - 2, w * 0.7, 5), Color("#E8D5C4") if team == Team.PLAYER else color_sub)
	# 바라보는 방향 표시
	draw_rect(Rect2(facing.x * w * 0.5 - 1, -1, 2, 2), Color.WHITE)
	# 체력 바
	var bw := 14.0
	var by := -h / 2 - 6
	draw_rect(Rect2(-bw / 2, by, bw, 2), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-bw / 2, by, bw * hp_ratio(), 2), Color("#E5484D") if team == Team.ENEMY else Color("#7CFF6B"))
	if has_status(Status.ROOT):
		draw_arc(Vector2(0, h / 2), radius, 0, TAU, 12, Color("#9D7BFF"), 1.0)
	if has_status(Status.BLIND):
		draw_rect(Rect2(-3, -h / 2 - 1, 6, 1), Color("#FFC83D"))
	if has_status(Status.SHIELD):
		draw_arc(Vector2.ZERO, radius + 2, 0, TAU, 16, Color("#FFE08A"), 1.0)
