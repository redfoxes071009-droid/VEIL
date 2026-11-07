extends SkillKit
## 페이즈 (전도, 근접 서포터) — 〈차원 개방〉 / 〈차원 질주〉
## 차원 개방: 전방 부채꼴 전도 피해 + 이동 속도 -20%. 발동 시 [광속 질주].
##   [광속 질주] 중에 다시 쓰면 스킬 쿨다운이 초기화됩니다 (광속 질주는 소모).
##   쿨타임은 PDF에 없어 6초로 가정. 피해량 "공격 속도 수치의 35%" 는 공격력 175%로 임시 해석.
## 차원 질주: 포털 게이지를 초당 3pt 소모하는 [질주]. 아군 이동 +20%·공속 +15%, 주변 적 내성 -20%.

const ARC_RADIUS := 34.0
const ARC_ANGLE := deg_to_rad(100.0)
const SKILL_MULT := 1.75
const SLOW_TIME := 3.0
const LIGHTSPEED_TIME := 4.0
const PORTAL_MAX := 30.0
const PORTAL_PER_HIT := 6.0
const PORTAL_DRAIN := 3.0
const SPRINT_AURA := 80.0

var portal := 0.0


func use_skill(_hold: bool, aim: Vector2) -> bool:
	var dir := (aim - u.position).normalized()
	if dir == Vector2.ZERO:
		dir = u.facing
	u.facing = dir
	for e in w().enemies_in_radius(u.position, ARC_RADIUS):
		var to := (e.position - u.position).normalized()
		if absf(dir.angle_to(to)) <= ARC_ANGLE * 0.5:
			w().deal_damage(u, e, SKILL_MULT, {"skill": true})
			if e.alive:
				e.add_status(Status.SLOW, SLOW_TIME)
			portal = minf(PORTAL_MAX, portal + PORTAL_PER_HIT)
	w().spawn_fx(&"arc", u.position, {"radius": ARC_RADIUS, "dir": dir, "angle": ARC_ANGLE, "color": u.color_main})
	if u.has_status(Status.LIGHTSPEED):
		u.remove_status(Status.LIGHTSPEED)
		u.skill_cd = 0.0
	else:
		u.skill_cd = u.data.skill_cooldown
		u.add_status(Status.LIGHTSPEED, LIGHTSPEED_TIME)
	return true


func use_ult(_aim: Vector2) -> bool:
	if portal < PORTAL_DRAIN:
		return false
	u.add_status(Status.SPRINT, 999.0)
	return true


func tick(delta: float) -> void:
	if not u.has_status(Status.SPRINT):
		return
	portal -= PORTAL_DRAIN * delta
	if portal <= 0.0:
		portal = 0.0
		u.remove_status(Status.SPRINT)
		return
	for a in w().allies():
		if a.alive:
			a.add_status(Status.HASTE, 0.3)
	for e in w().enemies_in_radius(u.position, SPRINT_AURA):
		e.add_status(Status.RESIST_DOWN, 0.3)


func ai_wants_skill() -> bool:
	return w().enemies_in_radius(u.position, ARC_RADIUS).size() > 0


func ai_wants_ult() -> bool:
	return portal >= 15.0 and w().enemies_in_radius(u.position, SPRINT_AURA).size() >= 2


func extra_gauge() -> Dictionary:
	return {"label_key": "HUD_PORTAL", "value": portal, "max": PORTAL_MAX}
