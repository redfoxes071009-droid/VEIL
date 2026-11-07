extends "res://tests/test_case.gd"
## 실제 오토로드와 씬으로 게임 흐름을 확인합니다.
## 타이틀 → 새 게임 → 로비 → 모든 로비 화면 → 스토리 → 전투 → 일시정지·설정 → 로비.

const TEST_SAVE := "user://test_flow_save.json"


func _sm() -> Node:
	return tree.root.get_node("SceneManager")


func _save() -> Node:
	return tree.root.get_node("SaveManager")


func _current() -> Node:
	return tree.current_scene


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_frames(2)


func _find_button(root: Node, text_key: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text_key:
			return n
	return null


func _go(path: String) -> void:
	await _sm().change_scene(path, 0.0)
	await wait_frames(2)


func test_scene_files_load() -> void:
	var sm := _sm()
	for p in [sm.TITLE_SCENE, sm.LOBBY_SCENE, sm.BATTLE_SCENE, sm.STORY_SCENE, sm.CHARACTER_SCENE, sm.GACHA_SCENE,
			sm.SHOP_SCENE, sm.BATTLEPASS_SCENE, sm.DISPATCH_SCENE, sm.MAIL_SCENE, sm.NOTICE_SCENE, sm.EVENT_SCENE,
			"res://scenes/ui/settings_panel.tscn", "res://scenes/ui/pause_menu.tscn"]:
		check(ResourceLoader.exists(p) and load(p) is PackedScene, "씬 로드: %s" % p)


func test_missing_scene_is_rejected() -> void:
	var ok: bool = await _sm().change_scene("res://scenes/없는_씬.tscn", 0.0)
	check_eq(ok, false, "없는 씬으로는 전환하지 않음")


func test_full_flow() -> void:
	var sm := _sm()
	var save := _save()
	var gm := tree.root.get_node("GameManager")
	save.path = TEST_SAVE
	save.delete_save()

	await _go(sm.TITLE_SCENE)
	check_eq(_current().name, &"TitleScreen", "타이틀 화면")
	check(_find_button(_current(), "MENU_CONTINUE") == null, "저장이 없으면 이어하기 없음")
	_find_button(_current(), "MENU_NEW_GAME").pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"Lobby", "새 게임 → 로비")
	check(save.is_loaded() and FileAccess.file_exists(TEST_SAVE), "새 저장 파일 생성")

	# 로비의 모든 하위 화면 열고 닫기
	for p in [sm.CHARACTER_SCENE, sm.GACHA_SCENE, sm.SHOP_SCENE, sm.BATTLEPASS_SCENE, sm.DISPATCH_SCENE,
			sm.MAIL_SCENE, sm.NOTICE_SCENE, sm.EVENT_SCENE, sm.STORY_SCENE]:
		await _go(p)
		check(_current().scene_file_path == p, "화면 열림: %s" % p.get_file())
		await _press("ui_cancel")
		await wait_frames(3)
		if sm.is_busy():
			await sm.scene_change_finished
		check_eq(_current().name, &"Lobby", "Esc → 로비: %s" % p.get_file())

	# 우편 → 크리스탈 → 모집
	var crystal0: int = save.get_currency("crystal")
	check_eq(OfflineContent.mail_claim(save, OfflineContent.MAIL[0]), "", "환영 우편 받기")
	check_eq(save.get_currency("crystal"), crystal0 + 1600, "크리스탈 +1600")
	await _go(sm.GACHA_SCENE)
	_current().find_child("PullTen", true, false).pressed.emit()
	await wait_frames(2)
	check_eq(save.get_currency("crystal"), crystal0, "10회 모집 = 크리스탈 1600")
	check_eq(int(save.data.gacha.total), 10, "모집 10회 기록")

	# 캐릭터 육성
	await _go(sm.CHARACTER_SCENE)
	var cs := _current()
	cs._select_tab(1)
	await wait_frames(1)
	var lv0: int = save.char_level(&"j")
	cs.find_child("LevelUp1", true, false).pressed.emit()
	check_eq(save.char_level(&"j"), lv0 + 1, "육성: 레벨업 ×1")

	# 스토리 → 전투
	await _go(sm.STORY_SCENE)
	var energy0: int = save.get_currency("energy")
	_current().find_child("StartButton", true, false).pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"Battle", "출격 → 전투")
	check_eq(save.get_currency("energy"), energy0 - 10, "에너지 10 소모")
	check_eq(gm.state, gm.State.PLAYING, "상태 PLAYING")
	var world: CombatWorld = _current().world
	check_eq(world.party.size(), 4, "전투 파티 4명")
	check_eq(world.leader.level, lv0 + 1, "육성한 레벨이 전투에 반영")

	await _press("pause")
	check(tree.paused, "Esc → 일시정지")
	await _press("pause")
	check(not tree.paused, "Esc 다시 → 계속")

	# 승리 처리 → 보상 → 로비
	var credit0: int = save.get_currency("credit")
	for e in world.enemies():
		e.take_damage(1e9)
	world.leader.position = world.terminal_pos + Vector2(0, 14)
	world.interact(world.leader)
	world.leader.position = world.exit_rect.get_center()
	await wait_frames(3)
	check_eq(world.state, CombatWorld.State.WON, "승리")
	await wait_seconds(1.2)
	check(save.get_currency("credit") > credit0, "승리 보상 크레딧")
	check("1-1" in save.data.story.cleared, "스테이지 클리어 기록")
	var to_lobby := _current().find_child("ToLobby", true, false)
	check(to_lobby != null, "결과 화면")
	to_lobby.pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"Lobby", "결과 → 로비")

	# 이어하기
	await _go(sm.TITLE_SCENE)
	check(_find_button(_current(), "MENU_CONTINUE") != null, "저장이 있으면 이어하기 표시")
	save.delete_save()
	save.path = save.DEFAULT_PATH
