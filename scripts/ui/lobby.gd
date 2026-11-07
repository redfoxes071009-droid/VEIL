extends Control
## 로비 (PDF 「게임 로비 화면 PREVIEW」 구성).
## 왼쪽: 플레이어·이벤트·우편·공지·커뮤니티 / 가운데: 로비 캐릭터 일러스트 / 오른쪽: 스토리·배틀패스·캐릭터·모집·상점·파견임무

const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")

var _settings: Control
var _mail_badge: Label


func _ready() -> void:
	GameManager.set_state(GameManager.State.TITLE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 로비 캐릭터 (고해상도 일러스트)
	var cid := StringName(SaveManager.data.get("lobby_char", "j"))
	var art := UiStyle.texture(Progression.load_character(cid).illust, Vector2(1100, 1080))
	art.name = "LobbyArt"
	art.position = Vector2(410, 0)
	add_child(art)
	var shade := TextureRect.new()
	shade.texture = _side_gradient()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_player_box()
	var cur := CurrencyBar.new()
	var top_right := UiStyle.hbox(12)
	top_right.add_child(cur)
	var settings := UiStyle.button("⚙", false, 22)
	settings.custom_minimum_size = Vector2(56, 48)
	settings.tooltip_text = "MENU_SETTINGS"
	settings.pressed.connect(_open_settings)
	top_right.add_child(settings)
	add_child(top_right)
	top_right.position = Vector2(1880, 32)
	top_right.reset_size()
	top_right.position.x = 1880 - top_right.size.x

	_build_left()
	_build_right()

	var ver := UiStyle.label("LOBBY_VERSION", 14, UiStyle.TEXT_MUTED)
	ver.position = Vector2(40, 1040)
	add_child(ver)


func _build_player_box() -> void:
	var p: Dictionary = SaveManager.data.player
	var box := UiStyle.hbox(16)
	box.position = Vector2(40, 28)
	add_child(box)
	var ring := PanelContainer.new()
	var rs := UiStyle.box(UiStyle.BG_PANEL, UiStyle.ACCENT_RED, 40, 0)
	rs.set_border_width_all(3)
	ring.add_theme_stylebox_override("panel", rs)
	ring.custom_minimum_size = Vector2(80, 80)
	var lv := UiStyle.label(str(int(p.level)), 32)
	lv.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring.add_child(lv)
	box.add_child(ring)
	var col := UiStyle.vbox(4)
	var nm := UiStyle.label(p.name, 24, UiStyle.TEXT_PRIMARY, true)
	nm.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
	col.add_child(nm)
	col.add_child(UiStyle.label(p.uid, 13, UiStyle.TEXT_MUTED))
	var need := Progression.player_exp_to_next(int(p.level))
	col.add_child(UiStyle.bar(float(p.exp) / need, UiStyle.ACCENT_RED, Vector2(220, 6)))
	box.add_child(col)


func _build_left() -> void:
	var col := UiStyle.vbox(14)
	col.position = Vector2(40, 170)
	add_child(col)
	var event := _card("LOBBY_EVENT", "LOBBY_EVENT_SUB", Vector2(300, 120), UiStyle.ACCENT_RED)
	event.pressed.connect(func(): SceneManager.change_scene(SceneManager.EVENT_SCENE))
	col.add_child(event)
	var mail := _small("LOBBY_MAIL", func(): SceneManager.change_scene(SceneManager.MAIL_SCENE))
	_mail_badge = UiStyle.label("", 14, UiStyle.ACCENT_RED, true)
	mail.add_child(_mail_badge)
	_mail_badge.position = Vector2(250, 10)
	var unread := OfflineContent.unread_mail(SaveManager)
	_mail_badge.text = "● %d" % unread if unread > 0 else ""
	col.add_child(mail)
	col.add_child(_small("LOBBY_NOTICE", func(): SceneManager.change_scene(SceneManager.NOTICE_SCENE)))
	col.add_child(_small("LOBBY_COMMUNITY", _community))
	# 소식 배너 (PDF 좌하단)
	var news := _card("LOBBY_NEWS", "LOBBY_NEWS_SUB", Vector2(360, 110), UiStyle.ACCENT_VOID)
	news.position = Vector2(40, 880)
	news.pressed.connect(func(): SceneManager.change_scene(SceneManager.EVENT_SCENE))
	add_child(news)


func _build_right() -> void:
	var x := 1360.0
	var story := _card("LOBBY_STORY", "LOBBY_STORY_SUB", Vector2(520, 170), UiStyle.ACCENT_VOID, 30)
	story.name = "StoryButton"
	story.position = Vector2(x, 150)
	story.pressed.connect(func(): SceneManager.change_scene(SceneManager.STORY_SCENE))
	add_child(story)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(x, 340)
	add_child(grid)
	var items := [
		["LOBBY_BATTLEPASS", "LOBBY_BATTLEPASS_SUB", SceneManager.BATTLEPASS_SCENE],
		["LOBBY_CHARACTER", "LOBBY_CHARACTER_SUB", SceneManager.CHARACTER_SCENE],
		["LOBBY_GACHA", "LOBBY_GACHA_SUB", SceneManager.GACHA_SCENE],
		["LOBBY_SHOP", "LOBBY_SHOP_SUB", SceneManager.SHOP_SCENE],
		["LOBBY_DISPATCH", "LOBBY_DISPATCH_SUB", SceneManager.DISPATCH_SCENE],
	]
	for it in items:
		var c := _card(it[0], it[1], Vector2(253, 130), UiStyle.LINE_DEFAULT)
		c.name = it[0]
		var target: String = it[2]
		c.pressed.connect(func(): SceneManager.change_scene(target))
		grid.add_child(c)


## 제목 + 부제가 있는 큰 버튼 카드.
func _card(title_key: String, sub_key: String, size: Vector2, accent: Color, title_size: int = 24) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	var n := UiStyle.box(Color(UiStyle.BG_PANEL, 0.88), UiStyle.LINE_DEFAULT, 4, 0)
	n.border_width_left = 4
	n.border_color = accent
	var h := n.duplicate()
	h.bg_color = Color(UiStyle.BG_PANEL_RAISED, 0.95)
	h.border_color = UiStyle.ACCENT_VOID
	h.set_border_width_all(1)
	h.border_width_left = 4
	for s in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, n)
	for s in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(s, h)
	var col := UiStyle.vbox(4)
	col.position = Vector2(20, 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UiStyle.label(title_key, title_size, UiStyle.TEXT_PRIMARY, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var s2 := UiStyle.wrap_label(sub_key, 14, size.x - 40, UiStyle.TEXT_MUTED)
	s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s2)
	b.add_child(col)
	return b


func _small(key: String, cb: Callable) -> Button:
	var b := _card(key, "", Vector2(300, 56), UiStyle.LINE_DEFAULT, 18)
	b.get_child(0).position = Vector2(20, 12)
	b.pressed.connect(cb)
	return b


func _community() -> void:
	var d := AcceptDialog.new()
	d.title = tr("LOBBY_COMMUNITY")
	d.dialog_text = tr("COMMUNITY_OFFLINE")
	add_child(d)
	d.popup_centered()


func _open_settings() -> void:
	if _settings:
		return
	_settings = SettingsPanelScene.instantiate()
	_settings.closed.connect(func(): _settings = null)
	add_child(_settings)


func _side_gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	g.colors = PackedColorArray([Color(UiStyle.BG_BASE, 0.95), Color(UiStyle.BG_BASE, 0.0), Color(UiStyle.BG_BASE, 0.0), Color(UiStyle.BG_BASE, 0.95)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	return t
