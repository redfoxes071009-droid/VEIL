extends SkillKit
## J (공허, 원거리 딜러) — 〈생명의 대가〉 / 〈어둠속의 그림자〉
## 1m = 4px 로 환산 (은신 사거리 +15m = +60px).

const HP_COST := 0.15
const STEALTH_TIME := 20.0
const STEALTH_RANGE := 60.0
const STEALTH_CRIT := 20.0
const STEALTH_BONUS := 0.20
const DASH_DIST := 64.0
const DASH_MULT := 1.8
const THORN_RADIUS := 40.0
const THORN_CORE := 14.0
const THORN_MULT := 3.0
const ROOT_TIME := 5.0
const ULT_RANGE := 140.0


func can_skill() -> bool:
	# 은신 중 짧게 누르면 조기 종료 (쿨타임과 무관)
	if u.alive and u.has_status(Status.STEALTH):
		return true
	return super.can_skill()


func use_skill(hold: bool, aim: Vector2) -> bool:
	if u.has_status(Status.STEALTH) and not hold:
		u.remove_status(Status.STEALTH)
		return true
	if u.skill_cd > 0.0:
		return false
	u.hp = maxf(1.0, u.hp - u.hp * HP_COST)
	u.skill_cd = u.data.skill_cooldown
	if hold:
		u.add_status(Status.STEALTH, STEALTH_TIME)
		w().spawn_fx(&"ring", u.position, {"radius": 16.0, "color": u.color_main})
	else:
		var dir := (aim - u.position).normalized()
		if dir == Vector2.ZERO:
			dir = u.facing
		var start := u.position
		w().move_unit(u, dir * DASH_DIST)
		for e in w().enemies_near_segment(start, u.position, 10.0):
			w().deal_damage(u, e, DASH_MULT, {"skill": true})
		w().spawn_fx(&"beam", start, {"to": u.position, "color": u.color_main, "width": 3.0})
	return true


func use_ult(aim: Vector2) -> bool:
	var center := u.position + (aim - u.position).limit_length(ULT_RANGE)
	for e in w().enemies_in_radius(center, THORN_RADIUS):
		w().deal_damage(u, e, THORN_MULT, {"skill": true, "ignore_def": true})
		if e.alive and e.position.distance_to(center) <= THORN_CORE + e.radius:
			e.add_status(Status.ROOT, ROOT_TIME)
	w().spawn_fx(&"burst", center, {"radius": THORN_RADIUS, "color": u.color_main})
	u.add_status(Status.STEALTH, STEALTH_TIME)
	return true


func range_bonus() -> float:
	return STEALTH_RANGE if u.has_status(Status.STEALTH) else 0.0


func crit_bonus() -> float:
	return STEALTH_CRIT if u.has_status(Status.STEALTH) else 0.0


func basic_bonus_flat() -> float:
	return u.atk() * STEALTH_BONUS if u.has_status(Status.STEALTH) else 0.0


func ai_wants_skill() -> bool:
	return super.ai_wants_skill() and u.hp_ratio() > 0.5 and not u.has_status(Status.STEALTH)
