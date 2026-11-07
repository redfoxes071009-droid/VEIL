class_name PlayerController
extends Node
## J 조작 (5장 조작표). 이동 WASD · 조준 마우스 · 대상 지정 좌클릭 · 생명의 대가 Q(짧게/길게) ·
## 어둠속의 그림자 R · 회피 Space · 상호작용 F · 동료 스킬 1/2/3 · 동료 궁극기 Shift+1/2/3.

const HOLD_TIME := 0.35
const DODGE_COOLDOWN := 1.0
const ALLY_ACTIONS := [["ally_1_skill", "ally_1_ultimate"], ["ally_2_skill", "ally_2_ultimate"], ["ally_3_skill", "ally_3_ultimate"]]

var world: CombatWorld
var unit: Unit
var _skill_pressed_at := -1.0
var _manual_target: Unit
var _dodge_cd := 0.0
var _time := 0.0


func setup(w: CombatWorld) -> void:
	world = w
	unit = w.leader


func aim_point() -> Vector2:
	return world.get_local_mouse_position()


func _physics_process(delta: float) -> void:
	_time += delta
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	if world == null or world.state != CombatWorld.State.RUNNING or get_tree().paused or not unit.alive:
		return
	if unit.has_status(Status.DODGE):
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	unit.move_dir(dir, delta)
	_update_target()
	unit.try_basic_attack()


func _update_target() -> void:
	if _manual_target and (not _manual_target.alive or unit.position.distance_to(_manual_target.position) > 260.0):
		_manual_target = null
	unit.target = _manual_target if _manual_target else world.nearest_enemy(unit, unit.attack_range() + 12.0)


func _unhandled_input(event: InputEvent) -> void:
	if world == null or world.state != CombatWorld.State.RUNNING or get_tree().paused:
		return
	for i in ALLY_ACTIONS.size():
		if event.is_action_pressed(ALLY_ACTIONS[i][1], false, true):
			command_ally(i, true)
			return
		if event.is_action_pressed(ALLY_ACTIONS[i][0], false, true):
			command_ally(i, false)
			return
	if event.is_action_pressed("skill_1"):
		_skill_pressed_at = _time
	elif event.is_action_released("skill_1") and _skill_pressed_at >= 0.0:
		var hold := _time - _skill_pressed_at >= HOLD_TIME
		_skill_pressed_at = -1.0
		unit.use_skill(hold, aim_point())
	elif event.is_action_pressed("ultimate"):
		unit.use_ult(aim_point())
	elif event.is_action_pressed("dodge"):
		try_dodge()
	elif event.is_action_pressed("interact"):
		world.interact(unit)
	elif event.is_action_pressed("target_select"):
		_manual_target = world.nearest_enemy_to_point(aim_point(), 16.0)


func try_dodge() -> void:
	if _dodge_cd > 0.0 or not unit.alive:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	unit.dodge(dir if dir != Vector2.ZERO else unit.facing)
	_dodge_cd = DODGE_COOLDOWN


## index: 0 라, 1 스테이지, 2 페이즈
func command_ally(index: int, ultimate: bool) -> bool:
	var a: Unit = world.party[index + 1]
	if a.target == null or not a.target.alive:
		a.target = world.nearest_enemy(a, a.attack_range() + 40.0)
	return a.use_ult() if ultimate else a.use_skill(false)
