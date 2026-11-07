extends "res://tests/test_case.gd"
## InputConfig 단위 테스트.

const InputConfigScript := preload("res://scripts/core/input_config.gd")


func test_all_actions_registered() -> void:
	for action: String in InputConfigScript.DEFAULT_BINDINGS:
		check(InputMap.has_action(action), "행동 등록됨: %s" % action)
		check(InputMap.action_get_events(action).size() > 0, "키가 연결됨: %s" % action)


func test_keys_use_physical_keycode() -> void:
	var ev: InputEvent = InputMap.action_get_events("move_left")[0]
	check(ev is InputEventKey, "move_left 는 키 입력")
	check_eq((ev as InputEventKey).physical_keycode, KEY_A, "move_left = 물리 A 키")


func test_ally_ultimate_requires_shift() -> void:
	var ev := InputMap.action_get_events("ally_1_ultimate")[0] as InputEventKey
	check(ev.shift_pressed, "라 궁극기는 Shift+1")


func test_register_is_idempotent() -> void:
	var before := InputMap.action_get_events("skill_1").size()
	InputConfigScript.register_default_actions()
	check_eq(InputMap.action_get_events("skill_1").size(), before, "두 번 등록해도 키가 늘지 않음")
