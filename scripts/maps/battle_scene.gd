extends Node2D
## 전투 씬: 640×360 픽셀 전투 화면을 3배 확대(최근접 필터) + 고해상도 HUD.

const PIXEL_SCALE := 3

var world: CombatWorld
var controller: PlayerController
var hud: BattleHud
var _result: Control


func _ready() -> void:
	var container := SubViewportContainer.new()
	container.name = "PixelView"
	container.stretch = true
	container.stretch_shrink = PIXEL_SCALE
	container.size = Vector2(1920, 1080)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	var vp := SubViewport.new()
	vp.name = "World"
	vp.size = Vector2i(640, 360)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.handle_input_locally = true
	container.add_child(vp)

	world = CombatWorld.new()
	world.name = "CombatWorld"
	vp.add_child(world)
	world.setup_stage(SaveManager.party_levels() if SaveManager.is_loaded() else {})
	for u in world.party:
		if u != world.leader:
			u.auto_skills = SettingsManager.ally_auto_skills
	world.battle_finished.connect(_on_finished)

	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	controller.setup(world)

	hud = BattleHud.new()
	add_child(hud)
	hud.setup(world)
	GameManager.set_state(GameManager.State.PLAYING)


func _on_finished(won: bool) -> void:
	await get_tree().create_timer(0.8).timeout
	var reward := {}
	if won and SaveManager.is_loaded():
		reward = SaveManager.clear_stage(SceneManager.battle_stage)
	GameManager.set_state(GameManager.State.TITLE)
	_show_result(won, reward)


func _show_result(won: bool, reward: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_result = Control.new()
	_result.name = "Result"
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_result)
	var scrim := ColorRect.new()
	scrim.color = Color(UiStyle.BG_BASE, 0.8)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(center)
	var p := UiStyle.panel(UiStyle.BG_PANEL, UiStyle.STATUS_CONTAMINATION if won else UiStyle.STATUS_HP, 40)
	center.add_child(p)
	var col := UiStyle.vbox(20)
	p.add_child(col)
	col.add_child(UiStyle.label("RESULT_WIN" if won else "RESULT_LOSE", 48, UiStyle.TEXT_PRIMARY, true))
	if won:
		var r := reward.duplicate()
		r.erase("first_clear")
		col.add_child(UiStyle.label(OfflineContent.reward_text(r), 18))
		var extra := "%s +%d · %s +%d" % [tr("RESULT_PLAYER_EXP"), int(r.get("player_exp", 0)), tr("RESULT_BP_XP"), int(r.get("bp_xp", 0))]
		col.add_child(UiStyle.label(extra, 16, UiStyle.TEXT_MUTED))
		if reward.get("first_clear", false):
			col.add_child(UiStyle.label("RESULT_FIRST_CLEAR", 16, UiStyle.STATUS_CONTAMINATION))
	else:
		col.add_child(UiStyle.label("RESULT_LOSE_HINT", 18, UiStyle.TEXT_MUTED))
	var row := UiStyle.hbox(16)
	var lobby := UiStyle.button("RESULT_TO_LOBBY", true, 20)
	lobby.name = "ToLobby"
	lobby.pressed.connect(func(): SceneManager.change_scene(SceneManager.LOBBY_SCENE))
	row.add_child(lobby)
	var retry := UiStyle.button("RESULT_RETRY", false, 20)
	retry.pressed.connect(func():
		if SaveManager.start_stage(SceneManager.battle_stage):
			SceneManager.change_scene(SceneManager.BATTLE_SCENE)
		else:
			retry.text = tr("ERR_ENERGY"))
	row.add_child(retry)
	col.add_child(row)
	lobby.grab_focus()
