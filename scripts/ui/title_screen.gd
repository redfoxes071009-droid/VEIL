extends Control
## 타이틀(게임 시작 메뉴) 화면 — Photoshop 「메인메뉴화면.psd」를 그대로 옮긴 화면.
## 배경(그림·로고·HUD·환영 안내창)은 PSD에서 메뉴만 빼고 내보낸 이미지(assets/ui/title/title_bg.jpg)이고,
## 메뉴 글자와 선택 상자는 PSD의 위치·크기·색(title_layout.json)대로 게임에서 그립니다.
## 마우스를 올리거나 ↑↓ 로 고르면 선택 상자가 그 줄로 옮겨 갑니다.

const DIR := "res://assets/ui/title/"
const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")
const ITEMS := [
	["Continue", "MENU_CONTINUE"],
	["NewGame", "MENU_NEW_GAME"],
	["Settings", "MENU_SETTINGS"],
	["Credits", "MENU_CREDITS"],
	["Quit", "MENU_QUIT"],
]

var layout: Dictionary
var buttons: Array[Button] = []
var select_box: TextureRect
var _settings: Control
var _credits: Control
var _font: Font
var _size: int
var _color: Color
var _color_sel: Color


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.State.TITLE)
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "title_layout.json"))
	_font = UiStyle.FONT_BODY_BOLD
	_size = int(layout.font_size)
	_color = Color(layout.color)
	_color_sel = Color(layout.color_selected)
	_build()
	var first := _first_enabled()
	if first:
		first.grab_focus.call_deferred()


func _build() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load(DIR + "title_bg.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 선택 상자 (PSD의 「선택 표시」+「선택 테두리」)
	var r: Array = layout.select_rect
	select_box = TextureRect.new()
	select_box.name = "SelectBox"
	select_box.texture = load(DIR + "menu_select.png")
	select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_box.position = Vector2(r[0], r[1])
	add_child(select_box)

	var menu := Control.new()
	menu.name = "Menu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var box_h: float = r[3] - r[1]
	var box_top_from_baseline: float = float(layout.select_baseline) - r[1]
	var asc := _font.get_ascent(_size)
	var fh := _font.get_height(_size)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = float(layout.x) - r[0]
	for i in ITEMS.size():
		var b := Button.new()
		b.name = ITEMS[i][0]
		b.text = ITEMS[i][1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", _size)
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(s, empty)
		b.add_theme_color_override("font_color", _color)
		b.add_theme_color_override("font_hover_color", _color_sel)
		b.add_theme_color_override("font_focus_color", _color_sel)
		b.add_theme_color_override("font_pressed_color", _color_sel)
		b.add_theme_color_override("font_hover_pressed_color", _color_sel)
		b.add_theme_color_override("font_disabled_color", Color(_color, 0.32))
		# PSD 기준선에 글자가 오도록: 버튼은 선택 상자와 같은 높이, 글자는 그 안 가운데
		var baseline: float = layout.baselines[i]
		var top := baseline - box_top_from_baseline
		b.position = Vector2(r[0], top)
		b.size = Vector2(r[2] - r[0], box_h)
		# 버튼은 글자를 세로 가운데에 그리므로, 기준선이 PSD와 맞게 위아래 여백을 조정
		var want_text_top := baseline - asc - top
		var centered_top := (box_h - fh) / 2.0
		var shift := want_text_top - centered_top
		var st := empty.duplicate() as StyleBoxEmpty
		st.content_margin_top = maxf(0.0, shift * 2.0)
		st.content_margin_bottom = maxf(0.0, -shift * 2.0)
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(s, st)
		b.focus_entered.connect(_select.bind(b))
		b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
		menu.add_child(b)
		buttons.append(b)
	for i in buttons.size():
		var up := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var down := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = up.get_path()
		buttons[i].focus_neighbor_bottom = down.get_path()
		buttons[i].focus_previous = up.get_path()
		buttons[i].focus_next = down.get_path()

	var cont: Button = menu.get_node("Continue")
	cont.disabled = not SaveManager.has_save()
	cont.focus_mode = Control.FOCUS_NONE if cont.disabled else Control.FOCUS_ALL
	cont.pressed.connect(_on_continue)
	menu.get_node("NewGame").pressed.connect(_on_new_game)
	menu.get_node("Settings").pressed.connect(_on_settings)
	menu.get_node("Credits").pressed.connect(_on_credits)
	menu.get_node("Quit").pressed.connect(GameManager.quit_game)


func _first_enabled() -> Button:
	for b in buttons:
		if not b.disabled:
			return b
	return null


## 선택 상자를 고른 줄로 옮김
func _select(b: Button) -> void:
	var target := Vector2(select_box.position.x, b.position.y)
	if not is_inside_tree() or select_box.position.distance_to(target) < 0.5:
		select_box.position = target
		return
	var tw := create_tween()
	tw.tween_property(select_box, "position", target, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func selected_index() -> int:
	for i in buttons.size():
		if absf(buttons[i].position.y - select_box.position.y) < 1.0:
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _credits:
		get_viewport().set_input_as_handled()
		_close_credits()


func _on_continue() -> void:
	if SaveManager.load_game():
		SceneManager.change_scene(SceneManager.LOBBY_SCENE)
	else:
		var d := AcceptDialog.new()
		d.dialog_text = tr("SAVE_LOAD_FAILED")
		add_child(d)
		d.popup_centered()


func _on_new_game() -> void:
	if not SaveManager.has_save():
		start_new_game()
		return
	var d := ConfirmationDialog.new()
	d.name = "NewGameConfirm"
	d.dialog_text = tr("NEW_GAME_CONFIRM")
	d.confirmed.connect(start_new_game)
	add_child(d)
	d.popup_centered()


func start_new_game() -> void:
	SaveManager.new_game()
	SceneManager.change_scene(SceneManager.LOBBY_SCENE)


func _on_settings() -> void:
	if _settings:
		return
	_settings = SettingsPanelScene.instantiate()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)


func _on_settings_closed() -> void:
	_settings = null
	get_node("Menu/Settings").grab_focus()


## 크레딧 창 — 화면 왼쪽 환영 안내창과 같은 모양(어두운 상자 · 연보라 테두리 · 왼쪽 탭 · 청록 제목)
func _on_credits() -> void:
	if _credits:
		return
	_credits = Control.new()
	_credits.name = "CreditsPanel"
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_credits)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_credits())
	_credits.add_child(scrim)

	var line := Color("#B8BAFF")
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0A0B12", 0.94)
	sb.border_color = Color(line, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_left = 18
	sb.content_margin_left = 40
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(620, 0)
	_credits.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := UiStyle.label("MENU_CREDITS", 26, Color("#9EE8FF"), true)
	v.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(line, 0.6)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	var body := UiStyle.wrap_label("CREDITS_BODY", 17, 540, Color("#C9CCFF"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(body)
	var close := Button.new()
	close.name = "CreditsClose"
	close.text = "SETTINGS_CLOSE"
	close.custom_minimum_size = Vector2(160, 40)
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color("#0A0B12", 0.8)
	cb.border_color = Color(line, 0.8)
	cb.set_border_width_all(1)
	var cbh := cb.duplicate() as StyleBoxFlat
	cbh.border_color = Color.WHITE
	for s in ["normal"]:
		close.add_theme_stylebox_override(s, cb)
	for s in ["hover", "focus", "pressed"]:
		close.add_theme_stylebox_override(s, cbh)
	close.add_theme_font_override("font", UiStyle.FONT_BODY_BOLD)
	close.add_theme_color_override("font_color", Color("#C9CCFF"))
	close.pressed.connect(_close_credits)
	v.add_child(close)
	panel.reset_size()
	panel.position = (Vector2(1920, 1080) - panel.get_combined_minimum_size()) / 2.0
	close.grab_focus.call_deferred()


func _close_credits() -> void:
	if _credits:
		_credits.queue_free()
		_credits = null
		get_node("Menu/Credits").grab_focus()
