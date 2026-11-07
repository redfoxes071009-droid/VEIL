extends Control
## 설정 패널 (Figma: 03 일시정지 · 설정 — 설정 패널).
## 값을 바꾸는 즉시 적용하고 저장합니다. Esc 또는 닫기 버튼으로 닫습니다.

signal closed

var _volume: HSlider
var _volume_value: Label
var _mode: OptionButton
var _resolution: OptionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_values()
	_volume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(UiStyle.BG_BASE, 0.78)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.ACCENT_VOID))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	panel.add_child(col)
	col.add_child(UiStyle.label("SETTINGS_TITLE", 32, UiStyle.TEXT_PRIMARY, true))

	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 5
	_volume.custom_minimum_size = Vector2(260, 24)
	_volume_value = UiStyle.label("", 18)
	_volume_value.custom_minimum_size = Vector2(40, 0)
	var vol_box := HBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 16)
	vol_box.add_child(_volume)
	vol_box.add_child(_volume_value)
	col.add_child(_row("SETTINGS_MASTER_VOLUME", vol_box))

	_mode = OptionButton.new()
	_mode.add_item("SETTINGS_WINDOWED", SettingsManager.WindowMode.WINDOWED)
	_mode.add_item("SETTINGS_FULLSCREEN", SettingsManager.WindowMode.FULLSCREEN)
	col.add_child(_row("SETTINGS_WINDOW_MODE", _mode))

	_resolution = OptionButton.new()
	for r: Vector2i in SettingsManager.RESOLUTIONS:
		_resolution.add_item("%d×%d" % [r.x, r.y])
	col.add_child(_row("SETTINGS_RESOLUTION", _resolution))

	var footer := HBoxContainer.new()
	footer.add_child(UiStyle.label("SETTINGS_HINT", 14, UiStyle.TEXT_MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "SETTINGS_CLOSE"
	close_btn.pressed.connect(close)
	footer.add_child(close_btn)
	col.add_child(footer)

	_volume.value_changed.connect(_on_volume_changed)
	_mode.item_selected.connect(_on_mode_selected)
	_resolution.item_selected.connect(_on_resolution_selected)


func _row(label_key: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UiStyle.label(label_key, 18)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(control)
	return row


func _load_values() -> void:
	_volume.set_value_no_signal(roundf(SettingsManager.master_volume * 100.0))
	_volume_value.text = str(int(_volume.value))
	_mode.select(_mode.get_item_index(SettingsManager.window_mode))
	_resolution.select(SettingsManager.resolution_index)
	_resolution.disabled = SettingsManager.window_mode == SettingsManager.WindowMode.FULLSCREEN


func _on_volume_changed(value: float) -> void:
	_volume_value.text = str(int(value))
	SettingsManager.set_master_volume(value / 100.0)
	_commit()


func _on_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(_mode.get_item_id(index))
	_resolution.disabled = SettingsManager.window_mode == SettingsManager.WindowMode.FULLSCREEN
	_commit()


func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution_index(index)
	_commit()


func _commit() -> void:
	SettingsManager.apply()
	SettingsManager.save_settings()
