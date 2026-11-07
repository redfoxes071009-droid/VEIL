extends Node
## 최초 실행 씬: 설정을 불러와 적용한 뒤 타이틀로 이동합니다.


func _ready() -> void:
	TranslationServer.set_locale("ko")
	SettingsManager.load_settings()
	SettingsManager.apply()
	SceneManager.change_scene.call_deferred(SceneManager.TITLE_SCENE, 0.0)
