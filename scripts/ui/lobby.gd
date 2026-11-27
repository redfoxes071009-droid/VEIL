extends Control
## 로비 — 사용자 최종 로비 화면(Downloads/겜로비 UI 원근.jpg)을 그대로 씁니다.
## assets/ui/lobby/lobby_bg.jpg: 원본 그림에서 바뀌는 값(레벨·이름·UID·재화·스토리 진행)만 지운 배경.
## assets/ui/lobby/lobby_layout.json: 그 값들의 글자 위치와, 카드마다 눌리는 영역(원근 모양 4점).
## 그림은 2576×1264 캔버스 기준이라 화면 비율에 맞춰 통째로 줄이고, 남는 위아래는 흐린 배경으로 채웁니다.

const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")
const BG := preload("res://assets/ui/lobby/lobby_bg.jpg")
const FILL := preload("res://assets/ui/lobby/lobby_fill.jpg")
const LAYOUT_PATH := "res://assets/ui/lobby/lobby_layout.json"
const NOTO := preload("res://assets/fonts/NotoSansKR-Variable.ttf")
const MAIL_DOT_COLOR := Color("#FFC400")

var layout: Dictionary
var canvas: Control
var hotspots := {}        ## 이름 → LobbyHotspot
var fields := {}          ## 이름 → Label
var _settings: Control
var _menu: PopupMenu
var _mail_dot: Control


func _ready() -> void:
	GameManager.set_state(GameManager.State.TITLE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_build()
	resized.connect(_fit)
	_fit()
	SaveManager.changed.connect(refresh)
	var t := Timer.new()          # 에너지 자연 회복 반영
	t.wait_time = 5.0
	t.autostart = true
	t.timeout.connect(refresh)
	add_child(t)
	refresh()


func _build() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var fill := TextureRect.new()
	fill.name = "Fill"
	fill.texture = FILL
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)

	var cs := _vec(layout.canvas)
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.size = cs
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = cs
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	for key in layout.fields:
		fields[key] = _field(key, layout.fields[key])

	for key in layout.hotspots:
		var h := LobbyHotspot.new()
		h.name = key
		h.setup(layout.hotspots[key])
		canvas.add_child(h)
		hotspots[key] = h
	_mail_dot = _dot(_vec(layout.mail_dot))
	_mail_dot.name = "MailDot"

	var go := func(path: String) -> Callable: return func(): SceneManager.change_scene(path)
	hotspots.Story.pressed.connect(go.call(SceneManager.STORY_SCENE))
	hotspots.Character.pressed.connect(go.call(SceneManager.CHARACTER_SCENE))
	hotspots.Gacha.pressed.connect(go.call(SceneManager.GACHA_SCENE))
	hotspots.Shop.pressed.connect(go.call(SceneManager.SHOP_SCENE))
	hotspots.Dispatch.pressed.connect(go.call(SceneManager.DISPATCH_SCENE))
	hotspots.Event.pressed.connect(go.call(SceneManager.EVENT_SCENE))
	hotspots.News.pressed.connect(go.call(SceneManager.EVENT_SCENE))
	hotspots.Mail.pressed.connect(go.call(SceneManager.MAIL_SCENE))
	hotspots.Notice.pressed.connect(go.call(SceneManager.NOTICE_SCENE))
	for k in ["CreditPlus", "EnergyPlus", "CrystalPlus"]:
		hotspots[k].pressed.connect(go.call(SceneManager.SHOP_SCENE))
	hotspots.Community.pressed.connect(_info.bind("LOBBY_COMMUNITY", "COMMUNITY_OFFLINE"))
	hotspots.Construction.pressed.connect(_info.bind("LOBBY_CONSTRUCTION", "LOBBY_CONSTRUCTION_SOON"))
	hotspots.Settings.pressed.connect(_open_settings)
	hotspots.Menu.pressed.connect(_open_menu)
	var tips := {"Story": "LOBBY_STORY", "Character": "LOBBY_CHARACTER", "Construction": "LOBBY_CONSTRUCTION",
		"Gacha": "LOBBY_GACHA", "Shop": "LOBBY_SHOP", "Dispatch": "LOBBY_DISPATCH", "Event": "LOBBY_EVENT",
		"Mail": "LOBBY_MAIL", "Notice": "LOBBY_NOTICE", "Community": "LOBBY_COMMUNITY", "News": "LOBBY_NEWS",
		"CreditPlus": "CUR_CREDIT", "EnergyPlus": "CUR_ENERGY", "CrystalPlus": "CUR_CRYSTAL",
		"Menu": "LOBBY_MENU", "Settings": "MENU_SETTINGS"}
	for k in tips:
		hotspots[k].tooltip_text = tips[k]

	# 오른쪽 위 메뉴(≡): 로비 그림에 카드가 없는 화면들
	_menu = PopupMenu.new()
	_menu.name = "LobbyMenu"
	_menu.add_item("LOBBY_BATTLEPASS", 0)
	_menu.add_item("LOBBY_TO_TITLE", 1)
	_menu.add_theme_font_override("font", UiStyle.FONT_BODY_BOLD)
	_menu.add_theme_font_size_override("font_size", 20)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	ps.border_color = LobbyHotspot.GLOW
	ps.set_border_width_all(1)
	ps.set_content_margin_all(10)
	_menu.add_theme_stylebox_override("panel", ps)
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(LobbyHotspot.GLOW, 0.18)
	_menu.add_theme_stylebox_override("hover", hs)
	_menu.add_theme_constant_override("v_separation", 12)
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)


## 캔버스를 화면 안에 꽉 차게(비율 유지) 맞추고 가운데 둡니다.
func _fit() -> void:
	var cs := _vec(layout.canvas)
	var k: float = minf(size.x / cs.x, size.y / cs.y)
	canvas.scale = Vector2(k, k)
	canvas.position = ((size - cs * k) * 0.5).floor()


func refresh() -> void:
	if not SaveManager.is_loaded():
		return
	var p: Dictionary = SaveManager.data.player
	fields.level.text = str(int(p.level))
	fields.name.text = str(p.name)
	fields.uid.text = str(p.uid)
	fields.credit.text = OfflineContent._num(SaveManager.get_currency("credit"))
	fields.energy.text = "%d / %d" % [SaveManager.get_currency("energy"), SaveManager.ENERGY_MAX]
	fields.crystal.text = OfflineContent._num(SaveManager.get_currency("crystal"))
	fields.story_sub.text = tr("LOBBY_STORY_NEXT") % next_main_stage()
	for key in ["level", "name", "uid", "credit", "energy", "crystal", "story_sub"]:
		_place(fields[key], layout.fields[key])
	_mail_dot.visible = OfflineContent.unread_mail(SaveManager) > 0


## 아직 클리어하지 않은 첫 메인 스테이지 (모두 클리어했으면 마지막 메인 스테이지).
static func next_main_stage() -> String:
	var last := ""
	for code in StageDefs.STAGES:
		if StageDefs.STAGES[code].type != "main":
			continue
		last = code
		if not StageDefs.is_cleared(SaveManager, code):
			return code
	return last


func _field(key: String, spec: Dictionary) -> Label:
	var l := Label.new()
	l.name = "Field_" + key
	var fv := FontVariation.new()
	if spec.font == "display":
		fv.base_font = UiStyle.FONT_DISPLAY_BOLD
	else:   # FontVariation 안에 FontVariation을 넣으면 굵기가 빠져서, 원본 글꼴에 굵기 700을 직접 지정
		fv.base_font = NOTO
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	fv.spacing_glyph = int(spec.get("spacing", 0))   # 원본 글자 폭에 맞춰 자간을 좁힘
	fv.variation_transform = Transform2D(Vector2(float(spec.sx), 0), Vector2(0, 1), Vector2.ZERO)
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", roundi(float(spec.size)))
	l.add_theme_color_override("font_color", Color(spec.color))
	l.add_theme_constant_override("line_spacing", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	canvas.add_child(l)
	return l


## PSD 글자 상자 아래 끝을 글자 기준선으로 맞춥니다. 가운데 정렬은 상자 가운데 기준.
func _place(l: Label, spec: Dictionary) -> void:
	var b: Array = spec.box
	var font: Font = l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	l.size = Vector2(w + 4, font.get_height(fs))
	var x: float = b[0]
	if spec.align == "center":
		x = (float(b[0]) + float(b[2])) * 0.5 - w * 0.5
	l.position = Vector2(x, float(b[3]) - font.get_ascent(fs))


func _dot(center: Vector2) -> Control:
	var d := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = MAIL_DOT_COLOR
	sb.set_corner_radius_all(8)
	d.add_theme_stylebox_override("panel", sb)
	d.size = Vector2(14, 14)
	d.position = center - d.size * 0.5
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(d)
	return d


func _unhandled_input(event: InputEvent) -> void:
	# 아무것도 선택되지 않은 상태에서 방향키를 누르면 스토리 카드부터 선택
	if get_viewport().gui_get_focus_owner() == null:
		for a in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(a):
				hotspots.Story.grab_focus()
				get_viewport().set_input_as_handled()
				return


func _info(title_key: String, body_key: String) -> void:
	var d := AcceptDialog.new()
	d.name = "InfoDialog"
	d.title = tr(title_key)
	d.dialog_text = tr(body_key)
	add_child(d)
	d.popup_centered()


func _open_menu() -> void:
	var r: Rect2 = hotspots.Menu.get_global_rect()
	_menu.reset_size()
	var pos := Vector2(r.end.x - _menu.size.x, r.end.y + 8)
	_menu.popup(Rect2i(Vector2i(get_screen_transform() * pos), Vector2i.ZERO))


func _on_menu(id: int) -> void:
	match id:
		0: SceneManager.change_scene(SceneManager.BATTLEPASS_SCENE)
		1: SceneManager.change_scene(SceneManager.TITLE_SCENE)


func _open_settings() -> void:
	if _settings:
		return
	_settings = SettingsPanelScene.instantiate()
	_settings.closed.connect(func(): _settings = null)
	add_child(_settings)


static func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
