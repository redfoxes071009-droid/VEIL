extends Node
## 모듈 간 신호 중계소 (오토로드: EventBus).
## 모듈끼리 서로를 직접 참조하지 않고, 여기의 신호로만 알립니다.

## 게임 상태(GameManager.State)가 바뀌었을 때.
signal game_state_changed(new_state: int)

## 일시정지 메뉴가 열리거나 닫혔을 때.
signal pause_toggled(is_paused: bool)

## 설정값이 바뀌어 적용되었을 때.
signal settings_applied
