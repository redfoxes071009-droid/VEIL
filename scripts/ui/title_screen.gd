extends Control
## 타이틀 화면 (Figma: 01 타이틀).

const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")

var _menu: VBoxContainer
var _settings: Control


func _ready() -> void:
	GameManager.set_state(GameManager.State.TITLE)
	_build()
	_menu.get_child(0).grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 키 아트 자리 (고해상도 일러스트가 들어올 곳, 임시)
	var art := ColorRect.new()
	art.name = "KeyArtPlaceholder"
	art.color = UiStyle.BG_PANEL_RAISED
	art.anchor_left = 820.0 / 1920.0
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	add_child(art)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 56)
	left.position = Vector2(140, 260)
	add_child(left)

	var logo_box := VBoxContainer.new()
	logo_box.add_theme_constant_override("separation", 0)
	left.add_child(logo_box)
	var logo := UiStyle.label("GAME_TITLE", 180)
	logo.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
	logo_box.add_child(logo)
	logo_box.add_child(UiStyle.label("GAME_SUBTITLE", 22, UiStyle.TEXT_MUTED))

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 4)
	left.add_child(_menu)
	_add_item("MENU_NEW_GAME", _on_new_game)
	_add_item("MENU_SETTINGS", _on_settings)
	_add_item("MENU_QUIT", GameManager.quit_game)

	var ver := UiStyle.label("VERSION_LABEL", 16, UiStyle.TEXT_MUTED)
	ver.add_theme_font_override("font", UiStyle.FONT_DISPLAY_SEMIBOLD)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 140
	ver.offset_top = -60
	add_child(ver)


func _add_item(key: String, callback: Callable) -> void:
	var b := UiStyle.menu_button(key)
	b.pressed.connect(callback)
	_menu.add_child(b)


func _on_new_game() -> void:
	SceneManager.change_scene(SceneManager.TEST_MAP_SCENE)


func _on_settings() -> void:
	if _settings:
		return
	_settings = SettingsPanelScene.instantiate()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)


func _on_settings_closed() -> void:
	_settings = null
	_menu.get_child(1).grab_focus()
