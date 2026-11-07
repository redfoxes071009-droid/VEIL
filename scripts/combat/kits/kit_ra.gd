extends SkillKit
## 라 (광휘, 근접 탱커) — 〈불굴의 태양〉 / 〈심판의 날〉
## 특성: 피해를 받을 때마다 태양 코어 충전. 가득 차면 다음 기본 공격 강화 + 보호막.
## 심판의 날 쿨타임은 PDF에 없어 30초로 가정 (data/characters/ra.tres).

const SPEAR_COUNT := 2
const SPEAR_GAP := 0.25
const SPEAR_LENGTH := 120.0
const SPEAR_WIDTH := 10.0
const SPEAR_MULT := 2.25
const BLIND_TIME := 3.0
const TWIN_TIME := 12.0
const ALLY_HEAL := 0.306
const REVIVE := 0.50
const SELF_HEAL := 0.15
const BUFF_TIME := 8.0
const REGEN := 0.05
const CORE_MAX := 10
const CORE_BONUS_MULT := 1.0
const CORE_SHIELD := 0.10

var core := 0
var core_ready := false
var _spears_left := 0
var _spear_t := 0.0
var _spear_dir := Vector2.RIGHT


func can_ult_while_downed() -> bool:
	return true


func use_skill(_hold: bool, aim: Vector2) -> bool:
	u.skill_cd = u.data.skill_cooldown
	u.add_status(Status.TWIN_SPEARS, TWIN_TIME)
	_spear_dir = (aim - u.position).normalized()
	if _spear_dir == Vector2.ZERO:
		_spear_dir = u.facing
	_spears_left = SPEAR_COUNT
	_spear_t = 0.0
	return true


func use_ult(_aim: Vector2) -> bool:
	for a in w().allies():
		if a == u:
			continue
		a.heal(a.max_hp * ALLY_HEAL)
	if u.alive:
		u.heal(u.max_hp * SELF_HEAL)
	else:
		u.revive(REVIVE)
	u.add_status(Status.JUDGEMENT, BUFF_TIME)
	w().spawn_fx(&"burst", u.position, {"radius": 70.0, "color": u.color_main})
	return true


func tick(delta: float) -> void:
	if u.has_status(Status.JUDGEMENT):
		u.heal(u.max_hp * REGEN * delta)
	if _spears_left > 0:
		_spear_t -= delta
		if _spear_t <= 0.0:
			_spear_t = SPEAR_GAP
			_spears_left -= 1
			var a := u.position
			var b := a + _spear_dir * SPEAR_LENGTH
			for e in w().enemies_near_segment(a, b, SPEAR_WIDTH * 0.5):
				w().deal_damage(u, e, SPEAR_MULT, {"skill": true})
				if e.alive:
					e.add_status(Status.BLIND, BLIND_TIME)
			w().spawn_fx(&"beam", a, {"to": b, "color": u.color_main, "width": 4.0})


## 쓰러져 있어도 오염도와 쿨타임이 차 있으면 궁극기를 쓸 수 있습니다. AI/자동은 1초 뒤 발동.
func tick_downed(_delta: float) -> void:
	if (u.auto_skills or not u.controlled) and u.downed_time >= 1.0 and u.can_use_ult():
		u.use_ult()


func on_damaged(_amount: float) -> void:
	if core_ready:
		return
	core += 1
	if core >= CORE_MAX:
		core_ready = true


func basic_bonus_flat() -> float:
	return u.atk() * CORE_BONUS_MULT if core_ready else 0.0


func on_basic_hit(_target: Unit) -> void:
	if core_ready:
		core_ready = false
		core = 0
		u.add_status(Status.SHIELD, 6.0, {"amount": u.max_hp * CORE_SHIELD})


func ai_wants_skill() -> bool:
	return w().enemies_in_radius(u.position, 70.0).size() >= 1


func ai_wants_ult() -> bool:
	for a in w().allies():
		if not a.alive or a.hp_ratio() < 0.4:
			return true
	return false


func extra_gauge() -> Dictionary:
	return {"label_key": "HUD_SUN_CORE", "value": core, "max": CORE_MAX}
