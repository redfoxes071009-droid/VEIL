extends SkillKit
## 스테이지 (전도, 원거리 딜러) — 〈콤보! (COMBO!)〉 / 〈크래킹 (CRACKING)〉
## 콤보!: 1초 동안 5연발. 적중마다 콤보 +1 (최대 5, 5초 유지·갱신), 전도 피해 +20% (5초).
## 크래킹: 스택 전부 소모, 광역 전도 피해. 스택당 확산 반경 증가, 마지막 일격 픽셀 폭발(스택 × 공격력 30%).

const MAX_COMBO := 5
const COMBO_TIME := 5.0
const SPEED_PER_COMBO := 0.05
const CONDUCT_BONUS := 0.20
const BURST_SHOTS := 5
const BURST_GAP := 0.2
const SHOT_MULT := 0.6
const SPREAD_RATIO := 0.3
const SPREAD_RADIUS := 30.0
const ULT_RADIUS := 36.0
const ULT_RADIUS_PER_STACK := 8.0
const ULT_MULT := 2.0
const PIXEL_BURST_PER_STACK := 0.30

var combo := 0
var combo_t := 0.0
var _burst_left := 0
var _burst_t := 0.0


func use_skill(_hold: bool, _aim: Vector2) -> bool:
	if u.target == null or not u.target.alive:
		return false
	u.skill_cd = u.data.skill_cooldown
	_burst_left = BURST_SHOTS
	_burst_t = 0.0
	return true


func tick(delta: float) -> void:
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = BURST_GAP
			_burst_left -= 1
			_fire_shot()


func _fire_shot() -> void:
	var t := u.target
	if t == null or not t.alive:
		t = w().nearest_enemy(u, u.attack_range() + 30.0)
		u.target = t
	if t == null:
		_burst_left = 0
		return
	var dealt: float = w().deal_damage(u, t, SHOT_MULT, {"skill": true})
	w().spawn_fx(&"tracer", u.position, {"to": t.position, "color": u.color_main})
	if dealt <= 0.0:
		return
	combo = mini(MAX_COMBO, combo + 1)
	combo_t = COMBO_TIME
	u.add_status(Status.CONDUCT_BONUS, COMBO_TIME)
	# 특성: 악성코드 전염 — 가까운 다른 적에게 30% 추가 피해
	for e in w().enemies_in_radius(t.position, SPREAD_RADIUS):
		if e != t:
			w().deal_damage(u, e, SHOT_MULT * SPREAD_RATIO, {"skill": true, "no_contam": true})
			break


func use_ult(aim: Vector2) -> bool:
	var stacks := combo
	var center := u.target.position if u.target and u.target.alive else aim
	var radius := ULT_RADIUS + ULT_RADIUS_PER_STACK * stacks
	var hit := w().enemies_in_radius(center, radius)
	for e in hit:
		w().deal_damage(u, e, ULT_MULT, {"skill": true})
	if stacks > 0:
		for e in hit:
			if e.alive:
				w().deal_damage(u, e, 0.0, {"skill": true, "bonus_flat": u.atk() * PIXEL_BURST_PER_STACK * stacks, "no_crit": true})
	w().spawn_fx(&"burst", center, {"radius": radius, "color": u.color_sub})
	combo = 0
	combo_t = 0.0
	return true


func attack_speed_bonus() -> float:
	return SPEED_PER_COMBO * combo


func damage_mult(element: int) -> float:
	if element == CharacterData.Element.CONDUCT and u.has_status(Status.CONDUCT_BONUS):
		return 1.0 + CONDUCT_BONUS
	return 1.0


func ai_wants_ult() -> bool:
	return super.ai_wants_ult() and (combo >= 3 or (combo > 0 and combo_t < 1.0))


func extra_gauge() -> Dictionary:
	return {"label_key": "HUD_COMBO", "value": combo, "max": MAX_COMBO}
