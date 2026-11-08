extends Control
## 스토리 맵 (Photoshop 「VEIL_스토리맵_UI.psd」를 그대로 옮긴 화면).
## 배경·고정 UI·노드·배지는 PSD에서 내보낸 이미지(assets/ui/story_map/)이고, 위치는 story_layout.json 을 따릅니다.
## 재화 숫자와 임무 진행 수만 게임 데이터에 맞춰 글자로 그립니다.
## 노드를 누르면 스테이지 정보 창이 열리고, 「출격」으로 전투에 들어갑니다.

const DIR := "res://assets/ui/story_map/"
const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")
const HOVER := Color(1.18, 1.18, 1.22)
const LOCKED := Color(0.5, 0.5, 0.55)

var layout: Dictionary
var node_buttons := {}       ## code -> TextureButton
var popup: StagePopup
var _energy: Label
var _crystal: Label
var _progress: Label
var _settings: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.State.TITLE)
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "story_layout.json"))
	_build()
	refresh()
	var first: Control = node_buttons.get("1-1")
	if first:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if popup.visible:
			popup.close()
		elif _settings:
			pass
		else:
			SceneManager.change_scene(SceneManager.LOBBY_SCENE)


func _tex(name: String) -> Texture2D:
	return load(DIR + name)


func _rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = _tex("story_bg.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var ui := TextureRect.new()
	ui.texture = _tex("story_ui_static.png")
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	# 노드 (PSD 위치 그대로)
	for n in layout.nodes:
		var code: String = n.code
		var b := TextureButton.new()
		b.name = "Node_" + code
		b.texture_normal = _tex("node_%s.png" % code)
		var r := _rect(n.rect)
		b.position = r.position
		b.size = r.size
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = tr(StageDefs.get_def(code).get("title_key", ""))
		b.mouse_entered.connect(_hover.bind(b, true))
		b.mouse_exited.connect(_hover.bind(b, false))
		b.focus_entered.connect(_hover.bind(b, true))
		b.focus_exited.connect(_hover.bind(b, false))
		b.pressed.connect(open_stage.bind(code))
		add_child(b)
		var badge := TextureRect.new()
		badge.name = "Badge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if n.badge:
			var br := _rect(n.badge.rect)
			badge.position = br.position - r.position
			badge.size = br.size
		b.add_child(badge)
		var clear := UiStyle.label("STAGE_CLEAR_TAG", 12, UiStyle.STATUS_CONTAMINATION, true)
		clear.name = "ClearTag"
		clear.position = Vector2(122, 4)
		clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(clear)
		node_buttons[code] = b

	# 동적 글자 (PSD 글자 위치·크기·색 그대로)
	var t: Dictionary = layout.texts
	_energy = _place_text(t["에너지"], UiStyle.FONT_BODY_BOLD)
	_crystal = _place_text(t["크리스탈"], UiStyle.FONT_BODY_BOLD)
	_progress = _place_text(t["진행 수"], UiStyle.FONT_DISPLAY_BOLD)
	_place_text(t["전체 수"], UiStyle.FONT_DISPLAY_SEMIBOLD).text = "/%d" % StageDefs.CHAPTER_TOTAL

	# 핫스팟 (PSD 아이콘 위의 투명 버튼)
	var h: Dictionary = layout.hotspots
	var icons := _rect(h["아이콘 / 뒤로 · 엠블럼 · 메뉴"])
	var third := icons.size.x / 3.0
	_hotspot("BackButton", Rect2(icons.position, Vector2(third, icons.size.y)), func(): SceneManager.change_scene(SceneManager.LOBBY_SCENE), "MENU_TO_LOBBY")
	_hotspot("EmblemButton", Rect2(icons.position + Vector2(third, 0), Vector2(third, icons.size.y)), func(): SceneManager.change_scene(SceneManager.LOBBY_SCENE), "MENU_TO_LOBBY")
	_hotspot("MenuButton", Rect2(icons.position + Vector2(third * 2, 0), Vector2(third, icons.size.y)), _open_settings, "MENU_SETTINGS")
	var arrows := _rect(h["좌우 버튼"])
	_hotspot("PrevChapter", Rect2(arrows.position, Vector2(84, arrows.size.y)), _chapter_locked, "STORY_PREV_CHAPTER")
	_hotspot("NextChapter", Rect2(arrows.end.x - 84, arrows.position.y, 84, arrows.size.y), _chapter_locked, "STORY_NEXT_CHAPTER")
	_hotspot("EventBanner", _rect(h["배너 바탕"]), func(): SceneManager.change_scene(SceneManager.EVENT_SCENE), "LOBBY_EVENT")
	_hotspot("EnergyPlus", _rect(h["에너지 / + 버튼"]), func(): SceneManager.change_scene(SceneManager.SHOP_SCENE), "SHOP_ENERGY")
	_hotspot("CrystalPlus", _rect(h["크리스탈 / + 버튼"]), func(): SceneManager.change_scene(SceneManager.SHOP_SCENE), "LOBBY_SHOP")

	popup = StagePopup.new()
	popup.name = "StagePopup"
	add_child(popup)
	popup.closed.connect(refresh)
	SaveManager.changed.connect(refresh)


## PSD 글자 레이어 정보(기준선 위치·크기·색·정렬)대로 Label 을 놓습니다.
func _place_text(info: Dictionary, font: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	var size := int(info.size)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(info.color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ascent := font.get_ascent(size)
	var width := 260.0
	var x: float = info.pos[0]
	match info.justify:
		"center":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			x -= width / 2.0
		"right":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			x -= width
	l.position = Vector2(x, float(info.pos[1]) - ascent)
	l.size = Vector2(width, font.get_height(size))
	l.text = info.text
	add_child(l)
	return l


func _hotspot(name: String, r: Rect2, cb: Callable, tip: String) -> void:
	var b := Button.new()
	b.name = name
	b.flat = true
	b.position = r.position
	b.size = r.size
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, empty)
	b.pressed.connect(cb)
	add_child(b)


func _hover(b: TextureButton, on: bool) -> void:
	var code := String(b.name).trim_prefix("Node_")
	var base := Color.WHITE if StageDefs.is_unlocked(SaveManager, code) else LOCKED
	b.self_modulate = base * (HOVER if on else Color.WHITE)


func refresh() -> void:
	if not SaveManager.is_loaded():
		return
	_energy.text = "%d / %d" % [SaveManager.get_currency("energy"), SaveManager.ENERGY_MAX]
	_crystal.text = OfflineContent._num(SaveManager.get_currency("crystal"))
	_progress.text = str(StageDefs.cleared_count(SaveManager))
	for n in layout.nodes:
		var code: String = n.code
		var b: TextureButton = node_buttons[code]
		var unlocked := StageDefs.is_unlocked(SaveManager, code)
		b.self_modulate = Color.WHITE if unlocked else LOCKED
		var badge: TextureRect = b.get_node("Badge")
		badge.visible = n.badge != null
		if n.badge:
			badge.texture = _tex("badge_rank.png" if unlocked else "badge_lock.png")
		b.get_node("ClearTag").visible = StageDefs.is_battle(code) and StageDefs.is_cleared(SaveManager, code)


func open_stage(code: String) -> void:
	popup.open(code)


func _chapter_locked() -> void:
	var p := UiStyle.panel(Color(UiStyle.BG_PANEL_RAISED, 0.95), Color("#7A58B0"), 14)
	p.add_child(UiStyle.label("STORY_CHAPTER_LOCKED", 18))
	add_child(p)
	p.reset_size()
	p.position = Vector2(960 - p.size.x / 2, 980)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _open_settings() -> void:
	if _settings:
		return
	_settings = SettingsPanelScene.instantiate()
	_settings.closed.connect(func(): _settings = null)
	add_child(_settings)
