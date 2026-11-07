extends Node
## 입력 행동 정의 (오토로드: InputConfig).
## 키는 물리 키 위치(physical_keycode)로 등록해 한글·영문 자판 상태와 상관없이 동작합니다.
## 나중에 키 변경 기능을 넣을 때도 이 행동 이름을 그대로 사용합니다.

const DEADZONE := 0.2

## 행동 이름 → 기본 키 목록.
## 각 항목: {"key": Key} 또는 {"key": Key, "shift": true} 또는 {"mouse": MouseButton}
const DEFAULT_BINDINGS := {
	"move_left": [{"key": KEY_A}],
	"move_right": [{"key": KEY_D}],
	"move_up": [{"key": KEY_W}],
	"move_down": [{"key": KEY_S}],
	"dodge": [{"key": KEY_SPACE}],
	"skill_1": [{"key": KEY_Q}],
	"skill_2": [{"key": KEY_E}],
	"ultimate": [{"key": KEY_R}],
	"ally_1_skill": [{"key": KEY_1}],
	"ally_1_ultimate": [{"key": KEY_1, "shift": true}],
	"interact": [{"key": KEY_F}],
	"target_select": [{"mouse": MOUSE_BUTTON_LEFT}],
	"pause": [{"key": KEY_ESCAPE}],
}


func _ready() -> void:
	register_default_actions()


## 기본 행동을 InputMap에 등록합니다. 이미 있는 행동은 건드리지 않습니다.
static func register_default_actions() -> void:
	for action: String in DEFAULT_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for binding: Dictionary in DEFAULT_BINDINGS[action]:
			InputMap.action_add_event(action, _make_event(binding))


static func _make_event(binding: Dictionary) -> InputEvent:
	if binding.has("mouse"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = binding["mouse"]
		return mouse
	var key := InputEventKey.new()
	key.physical_keycode = binding["key"]
	key.shift_pressed = binding.get("shift", false)
	return key
