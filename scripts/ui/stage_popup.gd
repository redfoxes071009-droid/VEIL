class_name StagePopup
extends Control
## 스토리 맵 노드를 눌렀을 때 뜨는 스테이지 정보 창. 스토리 맵 PSD와 같은 톤
## (검은 카드 #0B0C0F · 흰 테두리 · 보라 #7A58B0 강조)으로 그립니다.

signal closed

const PURPLE := Color("#7A58B0")
const CARD := Color("#0B0C0F")
const LINE := Color("#D8DCE2")

var code := ""
var _body: VBoxContainer
var _start: Button


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func open(stage_code: String) -> void:
	code = stage_code
	for ch in get_children():
		ch.queue_free()
	_build()
	show()
	if _start and not _start.disabled:
		_start.grab_focus.call_deferred()


func close() -> void:
	hide()
	closed.emit()


func _build() -> void:
	var d := StageDefs.get_def(code)
	var battle := StageDefs.is_battle(code)
	var unlocked := StageDefs.is_unlocked(SaveManager, code)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.62)
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(1920, 1080)
	scrim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	var sb := UiStyle.box(Color(CARD, 0.96), Color(LINE, 0.55), 0, 36)
	sb.border_width_left = 6
	sb.border_color = Color(LINE, 0.55)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(820, 0)
	panel.position = Vector2(1050, 200)
	add_child(panel)

	_body = UiStyle.vbox(16)
	panel.add_child(_body)
	var tag_row := UiStyle.hbox(12)
	var tag := UiStyle.panel(PURPLE, Color(0, 0, 0, 0), 6)
	tag.add_child(UiStyle.label(StageDefs.type_key(code), 14, Color.WHITE, true))
	tag_row.add_child(tag)
	var file := UiStyle.label("FILE / •  " + code, 16, Color("#E6E8EB"))
	file.add_theme_font_override("font", UiStyle.FONT_DISPLAY_SEMIBOLD)
	tag_row.add_child(file)
	if battle and StageDefs.is_cleared(SaveManager, code):
		tag_row.add_child(UiStyle.label("STAGE_CLEAR_TAG", 14, UiStyle.STATUS_CONTAMINATION, true))
	_body.add_child(tag_row)
	_body.add_child(UiStyle.label(d.title_key, 34, Color("#F7F8F9"), true))
	var desc := UiStyle.wrap_label(d.desc_key, 17, 748, Color("#C9CDD2"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.add_child(desc)
	var sep := ColorRect.new()
	sep.color = Color(LINE, 0.25)
	sep.custom_minimum_size = Vector2(748, 1)
	_body.add_child(sep)

	if battle:
		var info := GridContainer.new()
		info.columns = 2
		info.add_theme_constant_override("h_separation", 40)
		info.add_theme_constant_override("v_separation", 8)
		for pair in [["STAGE_REC_LEVEL", str(d.rec_level)], ["STAGE_ENERGY", str(d.energy)],
				["STAGE_ENEMY", tr("STAGE_ENEMY_VALUE") % int(round(d.enemy_mult * 100))],
				["STAGE_REWARD", tr("STAGE_REWARD_VALUE") % [OfflineContent._num(int(12000 * d.reward_mult)), 160 if not StageDefs.is_cleared(SaveManager, code) else 0]]]:
			info.add_child(UiStyle.label(pair[0], 15, UiStyle.TEXT_MUTED))
			info.add_child(UiStyle.label(pair[1], 17, Color("#F2F3F5"), true))
		_body.add_child(info)
		var party := UiStyle.hbox(10)
		for id in [&"j", &"ra", &"stage", &"phase"]:
			var c := Progression.load_character(id)
			var v := UiStyle.vbox(4)
			v.add_child(UiStyle.texture(c.portrait, Vector2(96, 96)))
			v.add_child(UiStyle.label("%s Lv.%d" % [c.display_name, SaveManager.char_level(id)], 13, Color("#D6DADF")))
			party.add_child(v)
		_body.add_child(party)

	if not unlocked:
		var reqs := StageDefs.missing_requirements(SaveManager, code)
		_body.add_child(UiStyle.label(tr("STAGE_LOCKED") % ", ".join(reqs), 16, Color("#9C7FCC"), true))

	var row := UiStyle.hbox(14)
	if battle:
		_start = _button(tr("STORY_START") % int(d.energy), true)
		_start.name = "StartButton"
		_start.disabled = not unlocked
		_start.pressed.connect(_deploy)
		row.add_child(_start)
	else:
		_start = null
	var close_btn := _button(tr("SETTINGS_CLOSE"), false)
	close_btn.name = "CloseButton"
	close_btn.pressed.connect(close)
	row.add_child(close_btn)
	_body.add_child(row)
	if battle:
		_body.add_child(UiStyle.label("STAGE_CONTROLS_HINT", 13, UiStyle.TEXT_MUTED))
	if not battle and _start == null:
		close_btn.grab_focus.call_deferred()


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300 if primary else 160, 58)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", UiStyle.FONT_BODY_BOLD)
	var bg := PURPLE if primary else Color(CARD, 0.9)
	var n := UiStyle.box(bg, Color(LINE, 0.55) if not primary else Color(0, 0, 0, 0), 0, 12)
	var h := n.duplicate()
	h.bg_color = bg.lightened(0.15)
	h.border_color = Color.WHITE
	h.set_border_width_all(1)
	var dis := n.duplicate()
	dis.bg_color = Color("#2A2E35")
	for s in ["normal"]:
		b.add_theme_stylebox_override(s, n)
	for s in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(s, h)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#7D848C"))
	return b


func _deploy() -> void:
	if not StageDefs.is_unlocked(SaveManager, code):
		return
	if not SaveManager.start_stage(code):
		_body.add_child(UiStyle.label("ERR_ENERGY", 16, Color("#FF6B6B"), true))
		return
	SceneManager.battle_stage = code
	SceneManager.change_scene(SceneManager.BATTLE_SCENE)
