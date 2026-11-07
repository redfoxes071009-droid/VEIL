class_name SkillKit
extends RefCounted
## 캐릭터 스킬 묶음의 기본 클래스. 캐릭터마다 kit_<id>.gd 가 이 클래스를 확장합니다.

var u: Unit


static func create(unit: Unit) -> SkillKit:
	var path := "res://scripts/combat/kits/kit_%s.gd" % unit.data.id
	var k: SkillKit = load(path).new()
	k.u = unit
	return k


func can_skill() -> bool:
	return u.alive and u.skill_cd <= 0.0 and not u.has_status(Status.DODGE)


func can_ult_while_downed() -> bool:
	return false


func use_skill(_hold: bool, _aim: Vector2) -> bool:
	return false


func use_ult(_aim: Vector2) -> bool:
	return false


func tick(_delta: float) -> void:
	pass


func tick_downed(_delta: float) -> void:
	pass


func on_basic_hit(_target: Unit) -> void:
	pass


func on_damaged(_amount: float) -> void:
	pass


func on_status_ended(_s: StringName) -> void:
	pass


func attack_speed_bonus() -> float:
	return 0.0


func range_bonus() -> float:
	return 0.0


func crit_bonus() -> float:
	return 0.0


func basic_bonus_flat() -> float:
	return 0.0


## 피해 배율 보정 (예: 스테이지의 전도 피해 보너스).
func damage_mult(_element: int) -> float:
	return 1.0


## AI 가 스킬·궁극기를 쓸지 판단 (동료 자동 사용 또는 J를 AI로 돌릴 때).
func ai_wants_skill() -> bool:
	return u.target != null and u.target.alive \
		and u.position.distance_to(u.target.position) <= u.attack_range() + 20.0


func ai_wants_ult() -> bool:
	return ai_wants_skill()


## HUD 에 표시할 추가 자원 (없으면 빈 사전). {"label_key", "value", "max"}
func extra_gauge() -> Dictionary:
	return {}


func w() -> CombatWorld:
	return u.world
