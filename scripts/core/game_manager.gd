extends Node
## 게임 전체 상태 관리 (오토로드: GameManager).

enum State { BOOT, TITLE, PLAYING, PAUSED }

var state: int = State.BOOT


func set_state(new_state: int) -> void:
	if new_state == state:
		return
	state = new_state
	EventBus.game_state_changed.emit(state)


## 플레이 중에만 일시정지할 수 있습니다.
func set_paused(paused: bool) -> void:
	if paused and state != State.PLAYING:
		return
	if not paused and state != State.PAUSED:
		return
	get_tree().paused = paused
	set_state(State.PAUSED if paused else State.PLAYING)
	EventBus.pause_toggled.emit(paused)


func quit_game() -> void:
	SettingsManager.save_settings()
	get_tree().quit()
