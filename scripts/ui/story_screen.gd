extends ScreenBase
## 스토리: 스테이지 선택 → 출격 (에너지 10).

const STAGE_ID := "1-1"


func _init() -> void:
	title_key = "LOBBY_STORY"


func _build_content(c: Control) -> void:
	var card := UiStyle.panel(Color(UiStyle.BG_PANEL, 0.95), UiStyle.ACCENT_VOID, 32)
	card.position = Vector2(0, 40)
	card.custom_minimum_size = Vector2(1100, 0)
	c.add_child(card)
	var col := UiStyle.vbox(18)
	card.add_child(col)
	col.add_child(UiStyle.label("STORY_CHAPTER", 18, UiStyle.ACCENT_VOID, true))
	col.add_child(UiStyle.label("STORY_STAGE_TITLE", 40, UiStyle.TEXT_PRIMARY, true))
	col.add_child(UiStyle.wrap_label("STORY_STAGE_DESC", 18, 1000, UiStyle.TEXT_MUTED))
	var cleared: bool = STAGE_ID in SaveManager.data.story.cleared
	col.add_child(UiStyle.label("STORY_CLEARED" if cleared else "STORY_FIRST_REWARD", 16, UiStyle.STATUS_CONTAMINATION))

	col.add_child(UiStyle.label("STORY_PARTY", 18, UiStyle.TEXT_PRIMARY, true))
	var party := UiStyle.hbox(16)
	for id in [&"j", &"ra", &"stage", &"phase"]:
		var d := Progression.load_character(id)
		var v := UiStyle.vbox(6)
		v.add_child(UiStyle.texture(d.portrait, Vector2(140, 140)))
		v.add_child(UiStyle.label("%s  Lv.%d" % [d.display_name, SaveManager.char_level(id)], 16))
		v.add_child(UiStyle.label(tr(d.role_key()) + " · " + tr(d.element_key()), 14, UiStyle.TEXT_MUTED))
		party.add_child(v)
	col.add_child(party)

	var go := UiStyle.button(tr("STORY_START") % SaveManager.STAGE_ENERGY, true, 22)
	go.name = "StartButton"
	go.custom_minimum_size = Vector2(320, 64)
	go.pressed.connect(start)
	col.add_child(go)
	go.grab_focus.call_deferred()

	var help := UiStyle.panel(Color(UiStyle.BG_PANEL, 0.9), UiStyle.LINE_DEFAULT, 24)
	help.position = Vector2(1160, 40)
	c.add_child(help)
	help.add_child(UiStyle.wrap_label("STORY_CONTROLS", 16, 600))


func start() -> void:
	if not SaveManager.start_stage(STAGE_ID):
		toast(tr("ERR_ENERGY"))
		return
	SceneManager.battle_stage = STAGE_ID
	SceneManager.change_scene(SceneManager.BATTLE_SCENE)
