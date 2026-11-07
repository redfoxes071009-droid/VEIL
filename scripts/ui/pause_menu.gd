extends CanvasLayer
## 일시정지 메뉴 (Figma: 03 일시정지 · 설정 — 일시정지 패널).
## 플레이 중인 맵 씬에 넣어 사용합니다. Esc 로 열고 닫습니다.

const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")

var _root: Control
var _menu: VBoxContainer
var _settings: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _settings:
		return  # 설정 패널이 스스로 닫습니다.
	get_viewport().set_input_as_handled()
	if _root.visible:
		resume()
	else:
		open()


func open() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	GameManager.set_paused(true)
	_root.show()
	_menu.get_child(0).grab_focus()


func resume() -> void:
	_root.hide()
	GameManager.set_paused(false)


func is_open() -> bool:
	return _root.visible


func _build() -> void:
	_root = Control.new()
	_root.name = "PauseRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var scrim := ColorRect.new()
	scrim.color = Color(UiStyle.BG_BASE, 0.78)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	panel.add_child(col)
	col.add_child(UiStyle.label("PAUSE_TITLE", 32, UiStyle.TEXT_PRIMARY, true))

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 4)
	col.add_child(_menu)
	_add_item("MENU_RESUME", resume)
	_add_item("MENU_SETTINGS", _on_settings)
	_add_item("MENU_TO_LOBBY", _on_to_title)


func _add_item(key: String, callback: Callable) -> void:
	var b := UiStyle.menu_button(key)
	b.pressed.connect(callback)
	_menu.add_child(b)


func _on_settings() -> void:
	_settings = SettingsPanelScene.instantiate()
	_settings.closed.connect(_on_settings_closed)
	_root.add_child(_settings)


func _on_settings_closed() -> void:
	_settings = null
	_menu.get_child(1).grab_focus()


func _on_to_title() -> void:
	_root.hide()
	GameManager.set_paused(false)
	SceneManager.change_scene(SceneManager.LOBBY_SCENE)
