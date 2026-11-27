extends Control
## 캐릭터 정보 — 사용자가 만든 캐릭터별 정보 화면(제이 · 라 · 스테이지 · 페이즈 상세정보, 3508×2480 페이지)을 그대로 씁니다.
## assets/ui/character/info_<id>.jpg : 페이지에서 게임 화면 부분(y 132~2326)만 자르고,
##   바뀌는 것(레벨 · 돌파 · 전투력 · 능력치 6종 · 탭 빛 · 특성/상세 정보 버튼 바탕 · 노란 점)만 지운 그림.
##   빛과 버튼 바탕은 「스테이지 상세정보.psd」의 레이어 색 · 투명도로 정확히 빼냈고, 게임이 같은 값으로 다시 그립니다.
## 좌표는 모두 PSD 페이지 좌표(3508 폭)이며, 그림이 화면 비율과 달라도 전체가 보이게 맞춥니다.

const PAGE := Vector2(3508, 2194)
const OY := 132.0                           ## 페이지에서 화면이 시작하는 y
const NUM_FONT := preload("res://assets/fonts/RobotoCondensed-Medium.ttf")
const NOTO := preload("res://assets/fonts/NotoSansKR-Variable.ttf")
const GLOW := preload("res://assets/ui/character/tab_glow.png")
const BREAK_X := preload("res://assets/ui/character/break_x.png")
const SEG_COLOR := Color("#7786AD")      ## PSD 「레이어 6」: 선택 80% · 비선택 30%
const DOT_COLOR := Color("#FFD900")

const TABS := ["CHAR_TAB_INFO", "CHAR_TAB_GROW", "CHAR_TAB_SHARD", "CHAR_TAB_SKILL", "CHAR_TAB_WEAPON", "CHAR_TAB_PROFILE"]
## PSD 「폰트」 그룹의 탭 글자 상자 (x0, y0, x1, y1)
const TAB_BOX := [[219, 513, 350, 583], [219, 770, 344, 838], [219, 1034, 351, 1102], [223, 1286, 350, 1353], [223, 1549, 348, 1617], [161, 1810, 422, 1878]]
const GLOW_OFFSET := Vector2(101 - 219, 421 - 513)   ## 「정보」 글자 기준 빛 레이어 위치
const STAT_KEYS := [["hp", "STAT_HP"], ["atk", "STAT_ATK"], ["def", "STAT_DEF"], ["crit_rate", "STAT_CRIT"], ["crit_dmg", "STAT_CRIT_DMG"], ["effect_hit", "STAT_EFFECT"]]
const STAT_X := [2465, 2626, 2790, 2960, 3126, 3287]
const STAT_BASE := [1286, 1285, 1286, 1286, 1289, 1292]
const SEG := Rect2(2354, 1646, 1017, 101)
const CARD_DETAIL := Rect2(2330, 1762, 1095, 490)   ## 상세 정보: 설명 글 자리
const CARD_TAB := Rect2(2330, 1336, 1095, 916)      ## 다른 탭: 능력치 아래 전체

## 다른 화면(모집의 「캐릭터 정보」 등)이 열 때 처음 보여 줄 캐릭터. 한 번 쓰면 비웁니다.
static var open_id: StringName = &""

var index := 0
var tab := 0
var info_mode := 0                 ## 0 특성 · 1 상세 정보
var canvas: Control
var hotspots := {}
var fields := {}
var picker: Control                ## 캐릭터 고르기 창
var _bg: TextureRect
var _fill: TextureRect
var _glow: TextureRect
var _breaks: Array[TextureRect] = []
var _seg: Array[ColorRect] = []
var _seg_labels: Array[TextureRect] = []
var _dots := {}
var _card: Panel
var _side: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_fill = TextureRect.new()
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.size = PAGE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_bg = TextureRect.new()
	_bg.name = "Background"
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.size = PAGE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_bg)

	_glow = TextureRect.new()
	_glow.texture = GLOW
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_glow)

	# 특성 · 상세 정보 버튼 바탕 (PSD 레이어 6과 같은 색 · 투명도)
	for i in 2:
		var r := ColorRect.new()
		r.position = _p(Vector2(SEG.position.x + SEG.size.x * 0.5 * i, SEG.position.y))
		r.size = Vector2(SEG.size.x * 0.5, SEG.size.y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(r)
		_seg.append(r)
	# 버튼 글자는 바탕 위에 다시 그림 (PSD 「특성」 · 「상세 정보」 글자 레이어)
	for pair in [["seg_trait.png", Vector2(2568, 1675)], ["seg_detail.png", Vector2(3033, 1675)]]:
		var t := TextureRect.new()
		t.texture = load("res://assets/ui/character/" + pair[0])
		t.position = _p(pair[1])
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(t)
		_seg_labels.append(t)

	# 바뀌는 숫자 (Roboto Condensed Medium, PSD 글자 크기 · 기준선)
	fields.level = _num(Vector2(2570, 810), 122, -8, HORIZONTAL_ALIGNMENT_LEFT, 0.9)
	fields.cap = _num(Vector2(2686, 808), 70, -4, HORIZONTAL_ALIGNMENT_LEFT)
	fields.power = _num(Vector2(2539, 1112), 81, -5, HORIZONTAL_ALIGNMENT_LEFT)
	for i in 6:
		fields["stat%d" % i] = _num(Vector2(STAT_X[i], STAT_BASE[i]), 60, -4, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var x := TextureRect.new()
		x.texture = BREAK_X
		x.position = _p(Vector2(2551 + [0, 74, 147][i], 853))
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(x)
		_breaks.append(x)

	# 탭 옆 알림 점: 육성(레벨업 가능) · 조각(돌파 가능)
	_dots.grow = _dot(Vector2(452, 742))
	_dots.shard = _dot(Vector2(446, 1022))

	# 탭 내용 카드
	_card = Panel.new()
	_card.name = "TabCard"
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.043, 0.051, 0.075, 1.0)
	cs.border_color = SEG_COLOR
	cs.border_width_top = 4
	_card.add_theme_stylebox_override("panel", cs)
	canvas.add_child(_card)
	var inner := Control.new()                 # 카드 안은 2배 크기로 그려 화면에서 실제 픽셀 크기에 가깝게
	inner.name = "Inner"
	inner.scale = Vector2(2, 2)
	inner.position = Vector2(36, 34)
	_card.add_child(inner)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	_side = UiStyle.vbox(14)
	scroll.add_child(_side)

	# 눌리는 영역
	for i in TABS.size():
		var b: Array = TAB_BOX[i]
		var cy: float = (b[1] + b[3]) * 0.5
		_hot("Tab%d" % i, Rect2(110, cy - 95, 380, 190)).pressed.connect(_select_tab.bind(i))
		hotspots["Tab%d" % i].tooltip_text = TABS[i]
	_hot("Back", Rect2(70, 180, 110, 140)).pressed.connect(go_back)
	_hot("Switch", Rect2(375, 180, 135, 140)).pressed.connect(open_picker)
	_hot("Menu", Rect2(700, 180, 120, 140)).pressed.connect(open_picker)
	_hot("Costume", Rect2(1344, 206, 320, 92)).pressed.connect(func(): toast(tr("CHAR_COSTUME_SOON")))
	_hot("Trait", Rect2(SEG.position, Vector2(SEG.size.x * 0.5, SEG.size.y))).pressed.connect(_set_info_mode.bind(0))
	_hot("Detail", Rect2(SEG.position + Vector2(SEG.size.x * 0.5, 0), Vector2(SEG.size.x * 0.5, SEG.size.y))).pressed.connect(_set_info_mode.bind(1))
	hotspots.Back.tooltip_text = "MENU_TO_LOBBY"
	hotspots.Switch.tooltip_text = "CHAR_SWITCH"
	hotspots.Menu.tooltip_text = "CHAR_SWITCH"
	hotspots.Costume.tooltip_text = "CHAR_COSTUME"

	if open_id != &"" and Progression.ROSTER.has(open_id):
		index = Progression.ROSTER.find(open_id)
	open_id = &""
	resized.connect(_fit)
	_fit()
	SaveManager.changed.connect(refresh)
	refresh()


func _fit() -> void:
	var k: float = minf(size.x / PAGE.x, size.y / PAGE.y)
	canvas.scale = Vector2(k, k)
	canvas.position = ((size - PAGE * k) * 0.5).floor()


func current() -> CharacterData:
	return Progression.load_character(Progression.ROSTER[index])


func _select_char(i: int) -> void:
	index = wrapi(i, 0, Progression.ROSTER.size())
	close_picker()
	refresh()


func _select_tab(i: int) -> void:
	tab = i
	refresh()


func _set_info_mode(m: int) -> void:
	info_mode = m
	refresh()


func refresh() -> void:
	if not is_inside_tree() or not SaveManager.is_loaded():
		return
	var d := current()
	var s := SaveManager.char_state(d.id)
	var lv := int(s.level)
	var br := int(s.break)
	_bg.texture = load("res://assets/ui/character/info_%s.jpg" % d.id)
	_fill.texture = load("res://assets/ui/character/fill_%s.jpg" % d.id)

	var b: Array = TAB_BOX[tab]
	_glow.position = _p(Vector2(b[0], b[1]) + GLOW_OFFSET + Vector2(((b[2] - b[0]) - (350 - 219)) * 0.5, 0))

	fields.level.set_runs(str(lv))
	fields.cap.baseline.x = fields.level.baseline.x + fields.level.text_width() - 2
	fields.cap.set_runs("/%d" % Progression.level_cap(br))
	fields.power.set_runs(str(Progression.combat_power(d, lv, br)))
	var stats := Progression.stats_at(d, lv)
	for i in 6:
		var k: String = STAT_KEYS[i][0]
		var v: float = stats[k]
		fields["stat%d" % i].set_runs(("%.1f" % v) if k == "crit_dmg" else str(int(round(v))))
	for i in 3:
		_breaks[i].modulate = Color(1, 1, 1, 1.0 if i < br else 0.3)

	var cap := Progression.level_cap(br)
	_dots.grow.visible = lv < cap and SaveManager.get_currency("credit") >= Progression.level_up_cost(lv)
	_dots.shard.visible = br < Progression.MAX_BREAK and lv >= cap and int(s.shards) >= Progression.break_cost(br)

	# 특성 · 상세 정보 버튼: 정보 탭에서만
	for i in 2:
		_seg[i].visible = tab == 0
		_seg[i].color = Color(SEG_COLOR, 0.8 if i == info_mode else 0.3)
		_seg_labels[i].visible = tab == 0
	hotspots.Trait.visible = tab == 0
	hotspots.Detail.visible = tab == 0

	# 카드: 정보+특성이면 숨김(그림의 특성 글 그대로), 그 외에는 탭 내용
	for ch in _side.get_children():
		ch.queue_free()
	var show_card := not (tab == 0 and info_mode == 0)
	_card.visible = show_card
	if show_card:
		var r := CARD_DETAIL if tab == 0 else CARD_TAB
		_card.position = _p(r.position)
		_card.size = r.size
		var scroll: ScrollContainer = _card.get_node("Inner/Scroll")
		scroll.size = (r.size - Vector2(72, 60)) * 0.5
		_side.custom_minimum_size.x = scroll.size.x - 12
		match tab:
			0: _tab_detail(d, stats)
			1: _tab_grow(d, lv, br)
			2: _tab_shard(d, s, lv, br)
			3: _tab_skill(d)
			4: _tab_weapon(d)
			5: _tab_profile(d)


# ---------------------------------------------------------------- 탭 내용

func _w() -> float:
	return _side.custom_minimum_size.x


func _tab_detail(d: CharacterData, stats: Dictionary) -> void:
	_side.add_child(UiStyle.label("%s · %s" % [d.epithet, d.display_name], 20, UiStyle.TEXT_PRIMARY, true))
	var lines := [
		"%s  %s" % [tr("CHAR_ROLE"), tr(d.role_key())],
		"%s  %s" % [tr("CHAR_RANGE"), tr(d.range_key())],
		"%s  %s" % [tr("CHAR_ELEMENT"), tr(d.element_key())],
		"%s  %.0f / %.0f" % [tr("CHAR_MOVE"), d.move_speed, d.attack_range],
	]
	_side.add_child(UiStyle.label("\n".join(lines), 16))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 4)
	for sk in STAT_KEYS:
		var v: float = stats[sk[0]]
		g.add_child(UiStyle.label("%s  %s" % [tr(sk[1]), ("%.1f" % v) if sk[0] == "crit_dmg" else str(int(round(v)))], 15, UiStyle.TEXT_MUTED))
	_side.add_child(g)


func _tab_grow(d: CharacterData, lv: int, br: int) -> void:
	var cap := Progression.level_cap(br)
	_side.add_child(UiStyle.label("CHAR_TAB_GROW", 24, UiStyle.TEXT_PRIMARY, true))
	_side.add_child(UiStyle.label(tr("GROW_COST") % OfflineContent._num(Progression.level_up_cost(lv)), 18))
	var row := UiStyle.hbox(12)
	for n in [1, 10]:
		var b := UiStyle.button(tr("GROW_LEVEL_UP") % n, n == 1, 18)
		b.name = "LevelUp%d" % n
		b.custom_minimum_size = Vector2(180, 52)
		b.disabled = lv >= cap
		b.pressed.connect(_level_up.bind(d.id, n))
		row.add_child(b)
	_side.add_child(row)
	if lv >= cap and br < Progression.MAX_BREAK:
		_side.add_child(UiStyle.wrap_label("GROW_NEED_BREAK", 16, _w(), UiStyle.ACCENT_RED))
	elif lv >= cap:
		_side.add_child(UiStyle.label("GROW_MAX", 16, UiStyle.TEXT_MUTED))


func _level_up(id: StringName, n: int) -> void:
	var done := 0
	var reason := ""
	for i in n:
		reason = SaveManager.level_up(id)
		if reason != "":
			break
		done += 1
	if done == 0:
		toast(tr({"credit": "ERR_CREDIT", "cap": "GROW_NEED_BREAK", "max": "GROW_MAX"}.get(reason, "ERR_CREDIT")))
	refresh()


func _tab_shard(d: CharacterData, s: Dictionary, lv: int, br: int) -> void:
	_side.add_child(UiStyle.label("CHAR_TAB_SHARD", 24, UiStyle.TEXT_PRIMARY, true))
	if br >= Progression.MAX_BREAK:
		_side.add_child(UiStyle.label("SHARD_MAX", 18))
		return
	var cost := Progression.break_cost(br)
	_side.add_child(UiStyle.wrap_label(tr("SHARD_NEED") % [int(s.shards), cost, Progression.level_cap(br + 1)], 17, _w()))
	_side.add_child(UiStyle.bar(float(s.shards) / cost, SEG_COLOR, Vector2(_w(), 10)))
	var b := UiStyle.button("SHARD_BREAK", true, 18)
	b.name = "BreakButton"
	b.custom_minimum_size = Vector2(180, 52)
	b.pressed.connect(func():
		var r := SaveManager.break_through(d.id)
		if r != "":
			toast(tr({"level": "SHARD_NEED_LEVEL", "shards": "SHARD_NOT_ENOUGH"}.get(r, "SHARD_MAX")))
		refresh())
	_side.add_child(b)
	_side.add_child(UiStyle.wrap_label("SHARD_HINT", 15, _w(), UiStyle.TEXT_MUTED))


func _tab_skill(d: CharacterData) -> void:
	for pair in [["SKILL_BASIC", d.skill_name, d.skill_desc, d.skill_cooldown], ["SKILL_ULT", d.ult_name, d.ult_desc, d.ult_cooldown]]:
		var h := UiStyle.hbox(12)
		var tag := UiStyle.panel(d.color_main if pair[0] == "SKILL_ULT" else SEG_COLOR, Color(0, 0, 0, 0), 6)
		tag.add_child(UiStyle.label(pair[0], 15, UiStyle.BG_BASE, true))
		h.add_child(tag)
		h.add_child(UiStyle.label("‘%s’" % pair[1], 20, UiStyle.TEXT_PRIMARY, true))
		_side.add_child(h)
		_side.add_child(UiStyle.wrap_label(pair[2], 15, _w()))
		var cd := tr("SKILL_COOLDOWN") % pair[3]
		if pair[0] == "SKILL_ULT":
			cd += "  ·  " + tr("SKILL_ULT_GAUGE")
		_side.add_child(UiStyle.label(cd, 14, UiStyle.TEXT_MUTED))


func _tab_weapon(d: CharacterData) -> void:
	_side.add_child(UiStyle.label(d.weapon_name, 24, UiStyle.TEXT_PRIMARY, true))
	_side.add_child(UiStyle.wrap_label(d.weapon_desc, 16, _w()))


func _tab_profile(d: CharacterData) -> void:
	var lines := [
		"%s  %s" % [tr("PROFILE_NAME"), d.display_name],
		"%s  %s" % [tr("PROFILE_RANK"), UiStyle.stars(d.rank)],
		"%s  %d" % [tr("PROFILE_TALL"), d.height_cm],
		"%s  %s" % [tr("CHAR_ELEMENT"), tr(d.element_key())],
	]
	_side.add_child(UiStyle.label("\n".join(lines), 17))
	_side.add_child(UiStyle.wrap_label(d.profile, 16, _w()))


# ---------------------------------------------------------------- 캐릭터 고르기

func open_picker() -> void:
	if picker:
		return
	picker = Control.new()
	picker.name = "Picker"
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(picker)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close_picker())
	picker.add_child(dim)
	var row := UiStyle.hbox(22)
	picker.add_child(row)
	for i in Progression.ROSTER.size():
		var d := Progression.load_character(Progression.ROSTER[i])
		var b := Button.new()
		b.name = "Pick_%s" % d.id
		b.custom_minimum_size = Vector2(200, 250)
		b.icon = d.portrait
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = d.display_name
		b.add_theme_font_size_override("font_size", 22)
		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.05, 0.06, 0.09, 0.95)
		n.border_color = SEG_COLOR if i != index else Color.WHITE
		n.set_border_width_all(2)
		n.set_content_margin_all(10)
		var h := n.duplicate()
		h.bg_color = Color(SEG_COLOR, 0.35)
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, n)
		for st in ["hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(st, h)
		b.pressed.connect(_select_char.bind(i))
		row.add_child(b)
	row.reset_size()
	row.position = ((size - row.size) * 0.5).floor()
	(row.get_child(index) as Button).grab_focus.call_deferred()


func close_picker() -> void:
	if picker:
		picker.queue_free()
		picker = null


# ---------------------------------------------------------------- 공통

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if picker:
			close_picker()
		else:
			go_back()
	elif event is InputEventKey and event.pressed and not event.echo and picker == null:
		if event.keycode == KEY_PAGEUP or event.keycode == KEY_Q:
			_select_char(index - 1)
		elif event.keycode == KEY_PAGEDOWN or event.keycode == KEY_E:
			_select_char(index + 1)


func go_back() -> void:
	SceneManager.change_scene(SceneManager.LOBBY_SCENE)


func toast(text: String) -> void:
	var p := UiStyle.panel(Color(0.05, 0.06, 0.09, 0.95), SEG_COLOR, 14)
	p.add_child(UiStyle.label(text, 18))
	add_child(p)
	p.reset_size()
	p.position = Vector2((size.x - p.size.x) * 0.5, size.y - 120)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


static func _p(v: Vector2) -> Vector2:
	return v - Vector2(0, OY)


func _hot(key: String, r: Rect2) -> LobbyHotspot:
	var p := _p(r.position)
	var h := LobbyHotspot.new()
	h.name = key
	h.setup([[p.x, p.y], [p.x + r.size.x, p.y], [p.x + r.size.x, p.y + r.size.y], [p.x, p.y + r.size.y]])
	canvas.add_child(h)
	hotspots[key] = h
	return h


func _num(baseline: Vector2, sz: int, spacing: int, align: int, sx: float = 1.0) -> RunText:
	var fv := FontVariation.new()
	fv.base_font = NUM_FONT
	fv.spacing_glyph = spacing
	if sx != 1.0:
		fv.variation_transform = Transform2D(Vector2(sx, 0), Vector2(0, 1), Vector2.ZERO)
	var t := RunText.new()
	t.font = fv
	t.font_size = sz
	t.color = Color.WHITE
	t.align = align
	t.baseline = _p(baseline)
	t.size = PAGE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(t)
	return t


func _dot(center: Vector2) -> Panel:
	var d := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = DOT_COLOR
	sb.set_corner_radius_all(12)
	d.add_theme_stylebox_override("panel", sb)
	d.size = Vector2(22, 22)
	d.position = _p(center) - d.size * 0.5
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(d)
	return d
