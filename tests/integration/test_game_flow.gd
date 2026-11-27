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
	var title := _current()
	check(title.has_node("Background") and title.get_node("Background").texture != null, "타이틀: PSD 배경")
	check_eq(title.buttons.size(), 5, "타이틀: 메뉴 5개 (계속하기·새 게임·설정·크레딧·게임 종료)")
	check(_find_button(title, "MENU_CONTINUE").disabled, "저장이 없으면 계속하기 비활성")
	await wait_frames(2)
	check_eq(title.selected_index(), 1, "처음 선택: 새 게임 (계속하기 비활성)")
	title.get_node("Menu/Settings").grab_focus()
	await tree.create_timer(0.3).timeout
	check_eq(title.selected_index(), 2, "선택 상자가 설정 줄로 이동")
	_find_button(title, "MENU_CREDITS").pressed.emit()
	await wait_frames(2)
	check(title.has_node("CreditsPanel"), "크레딧 창 열림")
	title.find_child("CreditsClose", true, false).pressed.emit()
	await wait_frames(2)
	check(not title.has_node("CreditsPanel"), "크레딧 창 닫힘")
	_find_button(_current(), "MENU_NEW_GAME").pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"Lobby", "새 게임 → 로비")
	check(save.is_loaded() and FileAccess.file_exists(TEST_SAVE), "새 저장 파일 생성")

	# 로비: 사용자 최종 로비 그림 + 바뀌는 값 + 카드 영역
	var lobby := _current()
	check(lobby.get_node("Canvas/Background").texture != null, "로비: 그림 배경")
	check_eq(lobby.hotspots.size(), 16, "로비: 눌리는 영역 16개")
	check_eq(lobby.fields.level.text, "1", "로비: 레벨 = 저장값")
	check_eq(lobby.fields.credit.text, "50,000", "로비: 크레딧 = 저장값")
	check_eq(lobby.fields.energy.text, "%d / %d" % [save.get_currency("energy"), save.ENERGY_MAX], "로비: 에너지")
	check_eq(lobby.fields.story_sub.text, "메인 1-1", "로비: 다음 메인 스테이지")
	check(lobby.fields.name.text == "PLAYER" and lobby.fields.uid.text.begins_with("UID-"), "로비: 이름·UID")
	var story_hs: LobbyHotspot = lobby.hotspots.Story
	check(story_hs._has_point(Vector2(1850, 300) - story_hs.position), "스토리 카드 안쪽은 눌림")
	check(not story_hs._has_point(Vector2(1815, 214) - story_hs.position), "원근: 기울어진 윗변 바깥은 안 눌림")
	lobby.hotspots.Construction.pressed.emit()
	await wait_frames(1)
	check(lobby.has_node("InfoDialog"), "건설: 준비 중 안내")
	lobby.get_node("InfoDialog").queue_free()
	lobby.hotspots.Story.pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().scene_file_path, sm.STORY_SCENE, "로비 스토리 카드 → 스토리 맵")
	await _go(sm.LOBBY_SCENE)
	_current()._on_menu(0)
	await sm.scene_change_finished
	check_eq(_current().scene_file_path, sm.BATTLEPASS_SCENE, "로비 메뉴 → 배틀패스")
	await _go(sm.LOBBY_SCENE)

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
	var gs := _current()
	check(gs.get_node("Background").texture != null, "모집: PSD 그림 배경")
	check(gs.results != null and gs.last_results.size() == 10, "모집 결과 창: 10장")
	check_eq(gs.fields.crystal.text, OfflineContent._num(save.get_currency("crystal")), "모집: 크리스탈 표시 = 저장값")
	check(gs.fields.desc1.text.contains("%d%%" % roundi(Gacha.RATE_5 * 100)) and gs.fields.desc3.text.contains(str(Gacha.PITY)), "모집 설명 = 실제 확률 · 보장 횟수")
	await _press("ui_cancel")
	check(gs.results == null and _current() == gs, "Esc: 결과 창만 닫힘")
	gs.hotspots.CharInfo.pressed.emit()
	await sm.scene_change_finished
	check_eq(Progression.ROSTER[_current().index], Gacha.PICKUP, "캐릭터 정보 → 스테이지 화면")

	# 캐릭터 육성
	await _go(sm.CHARACTER_SCENE)
	var cs := _current()
	cs._select_tab(1)
	await wait_frames(1)
	var lv0: int = save.char_level(&"j")
	cs.find_child("LevelUp1", true, false).pressed.emit()
	check_eq(save.char_level(&"j"), lv0 + 1, "육성: 레벨업 ×1")
	await wait_frames(1)
	check(cs.get_node("Canvas/Background").texture.resource_path.ends_with("info_j.jpg"), "캐릭터 정보: 제이 그림")
	check_eq(cs.fields.level.text, str(save.char_level(&"j")), "캐릭터 정보: 레벨 = 저장값")
	check_eq(cs.fields.power.text, str(Progression.combat_power(cs.current(), save.char_level(&"j"), 0)), "캐릭터 정보: 전투력")
	check(cs._card.visible and cs._glow.position.y > 500, "육성 탭: 내용 카드 + 탭 빛 이동")
	cs._select_tab(0)
	check(not cs._card.visible, "정보 · 특성: 그림의 특성 글 그대로")
	cs.hotspots.Detail.pressed.emit()
	check(cs._card.visible and cs.info_mode == 1, "상세 정보 버튼 → 상세 카드")
	cs.hotspots.Switch.pressed.emit()
	await wait_frames(1)
	cs.picker.find_child("Pick_stage", true, false).pressed.emit()
	await wait_frames(1)
	check(cs.picker == null and cs.current().id == &"stage", "캐릭터 바꾸기 → 스테이지")
	check(cs.get_node("Canvas/Background").texture.resource_path.ends_with("info_stage.jpg"), "스테이지 그림으로 바뀜")
	cs._select_char(0)

	# 스토리 → 전투
	await _go(sm.STORY_SCENE)
	var story := _current()
	check_eq(story.node_buttons.size(), 7, "스토리 맵: PSD 노드 7개")
	check_eq(story._energy.text, "%d / %d" % [save.get_currency("energy"), save.ENERGY_MAX], "스토리 맵: 에너지 표시")
	check_eq(story._progress.text, "0", "스토리 맵: 진행 수 0")
	# 잠긴 노드: 1-2 는 1-1 클리어 전에는 출격 불가
	story.find_child("Node_1-2", true, false).pressed.emit()
	await wait_frames(2)
	check(story.popup.visible, "1-2 노드 → 정보 창")
	var locked_btn: Button = story.popup.find_child("StartButton", true, false)
	check(locked_btn.disabled, "1-2 잠김: 출격 버튼 비활성")
	check_eq(story.find_child("Node_1-2", true, false).get_node("Badge").texture.resource_path.get_file(), "badge_lock.png", "잠김 배지")
	story.popup.find_child("CloseButton", true, false).pressed.emit()
	await wait_frames(2)
	check(not story.popup.visible, "정보 창 닫기")
	# 기록 노드: 전투 없음
	story.find_child("Node_R1-1", true, false).pressed.emit()
	await wait_frames(2)
	check(story.popup.find_child("StartButton", true, false) == null, "기록 노드: 출격 버튼 없음")
	story.popup.close()
	await wait_frames(1)
	story.find_child("Node_1-1", true, false).pressed.emit()
	await wait_frames(2)
	var energy0: int = save.get_currency("energy")
	story.popup.find_child("StartButton", true, false).pressed.emit()
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
	var to_story := _current().find_child("ToStory", true, false)
	check(to_story != null, "결과 화면")
	to_story.pressed.emit()
	await sm.scene_change_finished
	check_eq(_current().name, &"Story", "결과 → 스토리 맵")
	check_eq(_current()._progress.text, "1", "진행 수 1/10")
	check(StageDefs.is_unlocked(save, "1-2"), "1-1 클리어 → 1-2 해금")
	check_eq(_current().find_child("Node_1-2", true, false).get_node("Badge").texture.resource_path.get_file(), "badge_rank.png", "해금 배지")
	check(_current().find_child("Node_1-1", true, false).get_node("ClearTag").visible, "1-1 클리어 표시")
	# 1-2 출격: 강화된 적 배치
	_current().find_child("Node_1-2", true, false).pressed.emit()
	await wait_frames(2)
	var start12: Button = _current().popup.find_child("StartButton", true, false)
	check(not start12.disabled, "1-2 출격 가능")
	start12.pressed.emit()
	await sm.scene_change_finished
	check_eq(sm.battle_stage, "1-2", "1-2 전투 진입")
	var w12: CombatWorld = _current().world
	check_eq(w12.enemies().size(), 7, "1-2 적 7체")
	var brute: Unit = null
	for e in w12.enemies():
		if e.enemy_kind == &"bite_brute":
			brute = e
	check(brute != null and is_equal_approx(brute.max_hp, EnemyDefs.get_def(&"bite_brute").hp * 1.35), "1-2 적 HP ×1.35")
	await _go(sm.LOBBY_SCENE)

	# 이어하기
	await _go(sm.TITLE_SCENE)
	check(not _find_button(_current(), "MENU_CONTINUE").disabled, "저장이 있으면 계속하기 활성")
	await wait_frames(2)
	check_eq(_current().selected_index(), 0, "저장이 있으면 계속하기가 처음 선택")
	save.delete_save()
	save.path = save.DEFAULT_PATH
