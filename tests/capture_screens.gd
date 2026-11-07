extends Node
## 개발용: 주요 화면을 PNG로 저장합니다 (화면이 있는 환경에서 실행).
## 실행: godot res://tests/capture_screens.tscn -- <출력 폴더>


func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _shot(dir: String, name: String) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _button(root: Node, key: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n.text == key:
			return n
	return null


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	TranslationServer.set_locale("ko")
	await SceneManager.change_scene(SceneManager.TITLE_SCENE, 0.0)
	await _shot(dir, "01_title")
	_button(get_tree().current_scene, "MENU_SETTINGS").pressed.emit()
	await _shot(dir, "02_title_settings")
	await _press("pause")
	await SceneManager.change_scene(SceneManager.TEST_MAP_SCENE, 0.0)
	await _shot(dir, "03_test_map")
	await _press("pause")
	await _shot(dir, "04_pause")
	get_tree().quit()
