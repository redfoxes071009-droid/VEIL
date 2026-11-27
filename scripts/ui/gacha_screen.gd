extends Control
## 모집 (로컬 전용, 실제 결제 없음). 픽업: 무대 위의 악마 · 스테이지.
## 화면 그림: 사용자 Photoshop 「VEIL_캐릭터모집_UI.psd」(1920×1080) 그대로.
## assets/ui/gacha/gacha_bg.jpg 는 바뀌는 글자(재화 · UID · 확률 설명 1·3줄)만 지운 것이고,
## 그 자리에 게임이 실제 값을 PSD와 같은 글꼴 · 크기 · 색 · 기준선으로 그립니다.

const BG := preload("res://assets/ui/gacha/gacha_bg.jpg")
const CREDIT_ICON := preload("res://assets/ui/gacha/credit_icon.png")
const NOTO := preload("res://assets/fonts/NotoSansKR-Variable.ttf")
const CharScreen := preload("res://scripts/ui/character_screen.gd")
const PINK := Color("#F28ECF")          ## PSD 강조색 (설명의 숫자, 10회 버튼)
const DESC := Color("#E6E8EB")
const RARITY_COLOR := {3: Color("#8A949E"), 4: Color("#B88CFF"), 5: Color("#F5C518")}

## 눌리는 영역 (PSD 좌표). 사각형은 [x0, y0, x1, y1], 원은 [cx, cy, r].
const RECTS := {
	"Back": [80, 50, 140, 114],
	"CreditPlus": [1532, 60, 1576, 106], "CrystalPlus": [1832, 60, 1876, 106],
	"Banner1": [108, 200, 408, 312], "Banner2": [122, 336, 402, 440],
	"Soon1": [122, 462, 402, 566], "Soon2": [122, 588, 402, 692], "Soon3": [122, 715, 402, 819], "Soon4": [122, 841, 402, 945],
	"FeatJ": [478, 748, 588, 858], "FeatRa": [600, 748, 710, 858], "FeatPhase": [722, 748, 832, 858],
	"CharInfo": [1652, 808, 1862, 852],
	"PullOne": [1132, 928, 1492, 1006], "PullTen": [1520, 928, 1880, 1006],
}
const CIRCLES := {"IconShop": [502, 975, 27], "IconRates": [582, 975, 27], "IconInfo": [662, 975, 27], "IconHistory": [742, 975, 27]}

var rng := RandomNumberGenerator.new()
var hotspots := {}
var fields := {}
var results: Control           ## 모집 결과 창 (열려 있을 때만)
var last_results: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = BG
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 바뀌는 글자 (PSD 글자 레이어 기준: 기준선 y, 정렬 x)
	fields.credit = _text(Vector2(1444, 94), 28, 700, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	fields.crystal = _text(Vector2(1750, 94), 28, 700, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	fields.uid = _text(Vector2(1890, 1062), 13, 600, Color("#8A949E"), HORIZONTAL_ALIGNMENT_RIGHT)
	fields.desc1 = _text(Vector2(478, 432), 22, 600, DESC, HORIZONTAL_ALIGNMENT_LEFT)
	fields.desc3 = _text(Vector2(478, 508), 22, 600, DESC, HORIZONTAL_ALIGNMENT_LEFT)
	# 2·4번째 줄은 그림에 한국어로 들어 있어, 1·3번째 줄도 항상 한국어 문장으로 맞춥니다.
	fields.desc1.set_runs(_ko("GACHA_DESC_1") % _pct(Gacha.RATE_5))
	fields.desc3.set_runs(_ko("GACHA_DESC_3") % Gacha.PITY)

	for k in RECTS:
		var r: Array = RECTS[k]
		_hotspot(k, [[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]])
	for k in CIRCLES:
		var c: Array = CIRCLES[k]
		var pts := []
		for i in 20:
			var a := TAU * i / 20.0
			pts.append([c[0] + cos(a) * c[2], c[1] + sin(a) * c[2]])
		_hotspot(k, pts)

	hotspots.Back.pressed.connect(go_back)
	for k in ["CreditPlus", "CrystalPlus", "IconShop"]:
		hotspots[k].pressed.connect(func(): SceneManager.change_scene(SceneManager.SHOP_SCENE))
	hotspots.Banner1.pressed.connect(func(): pass)    # 지금 보고 있는 모집
	hotspots.Banner2.pressed.connect(func(): toast(tr("GACHA_BANNER_CLOSED")))
	for k in ["Soon1", "Soon2", "Soon3", "Soon4"]:
		hotspots[k].pressed.connect(func(): toast(tr("GACHA_SOON")))
	hotspots.CharInfo.pressed.connect(_open_char.bind(Gacha.PICKUP))
	hotspots.FeatJ.pressed.connect(_open_char.bind(&"j"))
	hotspots.FeatRa.pressed.connect(_open_char.bind(&"ra"))
	hotspots.FeatPhase.pressed.connect(_open_char.bind(&"phase"))
	hotspots.IconRates.pressed.connect(_dialog.bind("GACHA_RATES_TITLE", tr("GACHA_RATES") + "\n\n" + tr("GACHA_NO_PAYMENT")))
	hotspots.IconInfo.pressed.connect(_dialog.bind("GACHA_INFO_TITLE", tr("GACHA_INFO_BODY")))
	hotspots.IconHistory.pressed.connect(_show_history)
	hotspots.PullOne.pressed.connect(_pull.bind(1))
	hotspots.PullTen.pressed.connect(_pull.bind(10))
	var tips := {"Back": "MENU_TO_LOBBY", "CreditPlus": "CUR_CREDIT", "CrystalPlus": "CUR_CRYSTAL", "IconShop": "LOBBY_SHOP",
		"IconRates": "GACHA_RATES_TITLE", "IconInfo": "GACHA_INFO_TITLE", "IconHistory": "GACHA_HISTORY_TITLE"}
	for k in tips:
		hotspots[k].tooltip_text = tips[k]

	SaveManager.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not SaveManager.is_loaded():
		return
	fields.credit.set_runs(OfflineContent._num(SaveManager.get_currency("credit")))
	fields.crystal.set_runs(OfflineContent._num(SaveManager.get_currency("crystal")))
	fields.uid.set_runs(str(SaveManager.data.player.uid).replace("UID-", "UID · "))


func _pull(n: int) -> void:
	if results:
		return
	var res := Gacha.pull(SaveManager, n, rng)
	if res.is_empty():
		toast(tr("ERR_CRYSTAL"))
		return
	last_results = res
	_show_results(res)


# ---------------------------------------------------------------- 모집 결과 창

func _show_results(res: Array[Dictionary]) -> void:
	results = Control.new()
	results.name = "Results"
	results.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(results)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	results.add_child(dim)

	var cols := 5 if res.size() > 1 else 1
	var rows := ceili(res.size() / float(cols))
	var card := Vector2(212, 288)
	var gap := 18.0
	var grid_w := cols * card.x + (cols - 1) * gap
	var grid_h := rows * card.y + (rows - 1) * gap
	var panel_size := Vector2(maxf(grid_w + 120, 640), grid_h + 250)
	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.04, 0.07, 0.96)
	ps.border_color = Color(PINK, 0.8)
	ps.set_border_width_all(1)
	ps.border_width_top = 4
	panel.add_theme_stylebox_override("panel", ps)
	panel.size = panel_size
	panel.position = (Vector2(1920, 1080) - panel_size) * 0.5
	results.add_child(panel)

	var head := _plain_label(tr("GACHA_RESULT"), 34, 700, Color.WHITE)
	head.position = Vector2(56, 34)
	panel.add_child(head)
	var tag := _plain_label(tr("GACHA_BANNER_TITLE"), 18, 500, PINK)
	tag.position = Vector2(58, 86)
	panel.add_child(tag)

	var origin := Vector2((panel_size.x - grid_w) * 0.5, 130)
	for i in res.size():
		var c := _result_card(res[i], card)
		c.position = origin + Vector2(i % cols * (card.x + gap), i / cols * (card.y + gap))
		panel.add_child(c)
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.2)

	var pity := _plain_label(tr("GACHA_PITY") % [int(SaveManager.data.gacha.pity), Gacha.PITY], 18, 500, Color("#B9C0C8"))
	pity.position = Vector2(58, panel_size.y - 78)
	panel.add_child(pity)
	var ok := Button.new()
	ok.name = "ResultClose"
	ok.text = "GACHA_RESULT_OK"
	ok.add_theme_font_override("font", _font(700))
	ok.add_theme_font_size_override("font_size", 22)
	var n := StyleBoxFlat.new()
	n.bg_color = PINK.darkened(0.15)
	n.set_content_margin_all(12)
	var h := n.duplicate()
	h.bg_color = PINK
	for s in ["normal", "disabled"]:
		ok.add_theme_stylebox_override(s, n)
	for s in ["hover", "focus", "pressed"]:
		ok.add_theme_stylebox_override(s, h)
	ok.custom_minimum_size = Vector2(220, 58)
	ok.size = ok.custom_minimum_size
	ok.position = Vector2(panel_size.x - 56 - 220, panel_size.y - 92)
	ok.pressed.connect(close_results)
	panel.add_child(ok)
	ok.grab_focus.call_deferred()


func _result_card(r: Dictionary, sz: Vector2) -> Control:
	var col: Color = RARITY_COLOR[int(r.rarity)]
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.13)
	sb.border_color = col
	sb.set_border_width_all(2 if r.rarity < 5 else 3)
	p.add_theme_stylebox_override("panel", sb)
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := Rect2(Vector2(10, 10), Vector2(sz.x - 20, sz.x - 20))
	if r.has("char"):
		var t := TextureRect.new()
		t.texture = Progression.load_character(r.char).portrait
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.position = pic.position
		t.size = pic.size
		t.clip_contents = true
		p.add_child(t)
	else:
		var blank := ColorRect.new()
		blank.color = Color(0.14, 0.15, 0.19)
		blank.position = pic.position
		blank.size = pic.size
		p.add_child(blank)
		var ic := TextureRect.new()
		ic.texture = CREDIT_ICON
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(96, 68)
		ic.position = pic.get_center() - ic.size * 0.5
		p.add_child(ic)
	var stars := _plain_label(UiStyle.stars(int(r.rarity)), 18, 700, col)
	stars.position = Vector2(12, sz.x - 4)
	p.add_child(stars)
	var txt := ""
	if r.has("char"):
		txt = "%s  %s ×%d" % [Progression.load_character(r.char).display_name, tr("CUR_SHARD"), r.shards]
	else:
		txt = "%s ×%s" % [tr("CUR_CREDIT"), OfflineContent._num(r.credit)]
	var name_l := _plain_label(txt, 16, 500, Color("#E6E8EB"))
	name_l.position = Vector2(12, sz.x + 24)
	p.add_child(name_l)
	if r.has("char") and r.char == Gacha.PICKUP:
		var up := _plain_label("UP!", 14, 700, PINK)
		up.position = Vector2(sz.x - 44, sz.x - 2)
		p.add_child(up)
	return p


func close_results() -> void:
	if results:
		results.queue_free()
		results = null


# ---------------------------------------------------------------- 기타

func _show_history() -> void:
	var g: Dictionary = SaveManager.data.gacha
	_dialog("GACHA_HISTORY_TITLE", tr("GACHA_HISTORY_BODY") % [int(g.total), int(g.pity), Gacha.PITY])


func _open_char(id: StringName) -> void:
	CharScreen.open_id = id
	SceneManager.change_scene(SceneManager.CHARACTER_SCENE)


func _dialog(title_key: String, body: String) -> void:
	var d := AcceptDialog.new()
	d.name = "InfoDialog"
	d.title = tr(title_key)
	d.dialog_text = body
	add_child(d)
	d.popup_centered()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if results:
			close_results()
		else:
			go_back()


func go_back() -> void:
	SceneManager.change_scene(SceneManager.LOBBY_SCENE)


## 하단에 잠깐 뜨는 안내 문구.
func toast(text: String) -> void:
	var p := UiStyle.panel(Color(0.06, 0.05, 0.09, 0.95), PINK, 14)
	p.add_child(UiStyle.label(text, 18))
	add_child(p)
	p.reset_size()
	p.position = Vector2(960 - p.size.x / 2, 880)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _hotspot(key: String, pts: Array) -> LobbyHotspot:
	var h := LobbyHotspot.new()
	h.name = key
	h.setup(pts)
	add_child(h)
	hotspots[key] = h
	return h


static func _ko(key: String) -> String:
	var t := TranslationServer.get_translation_object("ko")
	return String(t.get_message(key)) if t else TranslationServer.translate(key)


static func _pct(v: float) -> String:
	var p := v * 100.0
	return str(int(p)) if is_equal_approx(p, roundf(p)) else "%.1f" % p


static func _font(weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = NOTO
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


func _plain_label(text: String, size: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", _font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _text(baseline: Vector2, size: int, weight: int, color: Color, align: int) -> RunText:
	var t := RunText.new()
	t.font = _font(weight)
	t.font_size = size
	t.color = color
	t.highlight = PINK
	t.align = align
	t.baseline = baseline
	t.size = Vector2(1920, 1080)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t
