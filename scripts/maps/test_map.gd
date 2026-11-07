extends Node2D
## 테스트 맵 (임시). Phase 3에서 J·라·적·단말·출구가 들어옵니다.


func _ready() -> void:
	GameManager.set_state(GameManager.State.PLAYING)
