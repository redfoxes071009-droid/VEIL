extends "res://tests/test_case.gd"
## 실제 오토로드와 씬으로 게임 흐름을 확인합니다.
## 타이틀 → 새 게임 → 테스트 맵 → 일시정지 → 계속 → 일시정지 → 타이틀로.


func _current() -> Node:
	return tree.current_scene


func _press_pause() -> void:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	var up := InputEventAction.new()
	up.action = "pause"
	up.pressed = false
	Input.parse_input_event(up)
	await wait_frames(2)


func _find_button(root: Node, text_key: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text_key:
			return n
	return null


func test_scene_files_load() -> void:
	for p in ["res://scenes/main/boot.tscn", "res://scenes/ui/title_screen.tscn",
			"res://scenes/ui/settings_panel.tscn", "res://scenes/ui/pause_menu.tscn",
			"res://scenes/maps/test_map.tscn"]:
		check(ResourceLoader.exists(p) and load(p) is PackedScene, "씬 로드: %s" % p)


func test_missing_scene_is_rejected() -> void:
	var ok: bool = await tree.root.get_node("SceneManager").change_scene("res://scenes/없는_씬.tscn", 0.0)
	check_eq(ok, false, "없는 씬으로는 전환하지 않음")


func test_full_flow() -> void:
	var sm := tree.root.get_node("SceneManager")
	var gm := tree.root.get_node("GameManager")

	await sm.change_scene(sm.TITLE_SCENE, 0.0)
	check_eq(_current().name, &"TitleScreen", "타이틀 화면")
	check_eq(gm.state, gm.State.TITLE, "상태 TITLE")
	check(tree.root.gui_get_focus_owner() != null, "타이틀 메뉴에 키보드 포커스")

	var new_game := _find_button(_current(), "MENU_NEW_GAME")
	check(new_game != null, "새 게임 버튼 존재")
	new_game.pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"TestMap", "새 게임 → 테스트 맵")
	check_eq(gm.state, gm.State.PLAYING, "상태 PLAYING")

	await _press_pause()
	check(tree.paused, "Esc → 일시정지")
	check_eq(gm.state, gm.State.PAUSED, "상태 PAUSED")

	await _press_pause()
	check(not tree.paused, "Esc 다시 → 계속")
	check_eq(gm.state, gm.State.PLAYING, "상태 PLAYING 복귀")

	await _press_pause()
	var pause_menu := _current().get_node("PauseMenu")
	var settings_btn := _find_button(pause_menu, "MENU_SETTINGS")
	settings_btn.pressed.emit()
	await wait_frames(2)
	check(_current().find_child("SettingsPanel", true, false) != null, "일시정지 → 설정 패널 열림")
	await _press_pause()
	check(_current().find_child("SettingsPanel", true, false) == null, "Esc → 설정 패널 닫힘")
	check(tree.paused, "설정을 닫아도 일시정지 유지")

	var to_title := _find_button(pause_menu, "MENU_TO_TITLE")
	to_title.pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"TitleScreen", "타이틀로 복귀")
	check(not tree.paused, "타이틀에서는 일시정지 해제")
