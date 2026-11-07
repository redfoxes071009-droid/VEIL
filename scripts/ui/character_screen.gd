extends ScreenBase
## 캐릭터 정보 (PDF 13~15쪽 구성).
## 왼쪽 탭: 정보 · 육성 · 조각 · 스킬 · 무기 · 프로파일 / 가운데 일러스트 / 오른쪽: 이름·★·코드·레벨·돌파·조각·전투력·능력치·탭 내용

const TABS := ["CHAR_TAB_INFO", "CHAR_TAB_GROW", "CHAR_TAB_SHARD", "CHAR_TAB_SKILL", "CHAR_TAB_WEAPON", "CHAR_TAB_PROFILE"]
const STAT_KEYS := [["hp", "STAT_HP"], ["atk", "STAT_ATK"], ["def", "STAT_DEF"], ["crit_rate", "STAT_CRIT"], ["crit_dmg", "STAT_CRIT_DMG"], ["effect_hit", "STAT_EFFECT"]]

var index := 0
var tab := 0
var _art: TextureRect
var _side: VBoxContainer
var _tab_buttons: Array[Button] = []
var _roster: HBoxContainer
var _info_mode := 0


func _init() -> void:
	title_key = "LOBBY_CHARACTER"


func _build_background() -> void:
	_art = UiStyle.texture(null, Vector2(940, 1080))
	_art.position = Vector2(270, 0)
	add_child(_art)


func _build_content(c: Control) -> void:
	var tabs := UiStyle.vbox(6)
	tabs.position = Vector2(0, 40)
	c.add_child(tabs)
	for i in TABS.size():
		var b := UiStyle.menu_button(TABS[i])
		b.custom_minimum_size = Vector2(200, 64)
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1180, 0)
	scroll.size = Vector2(660, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	_side = UiStyle.vbox(16)
	_side.custom_minimum_size = Vector2(640, 0)
	scroll.add_child(_side)

	_roster = UiStyle.hbox(12)
	_roster.position = Vector2(1180, 820)
	c.add_child(_roster)
	for i in Progression.ROSTER.size():
		var d := Progression.load_character(Progression.ROSTER[i])
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 88)
		b.icon = d.portrait
		b.expand_icon = true
		b.tooltip_text = d.display_name
		b.pressed.connect(_select_char.bind(i))
		_roster.add_child(b)
	refresh()


func current() -> CharacterData:
	return Progression.load_character(Progression.ROSTER[index])


func _select_char(i: int) -> void:
	index = i
	refresh()


func _select_tab(i: int) -> void:
	tab = i
	refresh()


func refresh() -> void:
	var d := current()
	var s := SaveManager.char_state(d.id)
	var lv := int(s.level)
	var br := int(s.break)
	_art.texture = d.illust
	for i in _tab_buttons.size():
		var b := _tab_buttons[i]
		b.add_theme_color_override("font_color", UiStyle.ACCENT_RED if i == tab else UiStyle.TEXT_MUTED)
	for i in _roster.get_child_count():
		_roster.get_child(i).modulate = Color.WHITE if i == index else Color(1, 1, 1, 0.45)
	for ch in _side.get_children():
		ch.queue_free()

	# 이름 · ★ · 코드
	var head := UiStyle.hbox(16)
	var nm := UiStyle.label(d.display_name, 48, UiStyle.TEXT_PRIMARY, true)
	head.add_child(nm)
	var st := UiStyle.label(UiStyle.stars(d.rank), 32, UiStyle.TEXT_PRIMARY)
	head.add_child(st)
	_side.add_child(head)
	var sub := UiStyle.label("[%s]  ·  %s · %s(%s)" % [d.code, d.epithet, d.display_name, tr(d.element_key())], 16, UiStyle.TEXT_MUTED)
	_side.add_child(sub)

	# 레벨 · 돌파 · 조각
	var row := UiStyle.hbox(28)
	var lvl := UiStyle.label("%d/%d" % [lv, Progression.level_cap(br)], 36)
	lvl.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
	row.add_child(_labeled(lvl, "CHAR_LEVEL"))
	var bk := UiStyle.label("✕".repeat(br) + "·".repeat(Progression.MAX_BREAK - br), 30, UiStyle.TEXT_PRIMARY)
	row.add_child(_labeled(bk, "CHAR_BREAK"))
	var sh := UiStyle.label(str(int(s.shards)), 30)
	sh.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
	row.add_child(_labeled(sh, "CUR_SHARD"))
	_side.add_child(row)

	# 전투력 · 능력치 6종
	var cp := UiStyle.panel(UiStyle.BG_PANEL_RAISED, Color(0, 0, 0, 0), 10)
	cp.add_child(UiStyle.label(tr("CHAR_POWER") % OfflineContent._num(Progression.combat_power(d, lv, br)), 22, UiStyle.TEXT_PRIMARY, true))
	_side.add_child(cp)
	var stats := Progression.stats_at(d, lv)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 22)
	for sk in STAT_KEYS:
		var v: float = stats[sk[0]]
		var val := UiStyle.label(("%.1f" % v) if sk[0] == "crit_dmg" else str(int(round(v))), 20)
		val.add_theme_font_override("font", UiStyle.FONT_DISPLAY_SEMIBOLD)
		grid.add_child(_labeled(val, sk[1]))
	_side.add_child(grid)
	_side.add_child(HSeparator.new())

	match tab:
		0: _tab_info(d)
		1: _tab_grow(d, lv, br)
		2: _tab_shard(d, s, lv, br)
		3: _tab_skill(d)
		4: _tab_weapon(d)
		5: _tab_profile(d)


func _labeled(value: Control, key: String) -> VBoxContainer:
	var v := UiStyle.vbox(2)
	v.add_child(value)
	v.add_child(UiStyle.label(key, 13, UiStyle.TEXT_MUTED))
	return v


func _tab_info(d: CharacterData) -> void:
	var seg := UiStyle.hbox(0)
	for i in 2:
		var b := UiStyle.button(["CHAR_TRAIT", "CHAR_DETAIL"][i], i == _info_mode, 16)
		b.custom_minimum_size = Vector2(200, 44)
		b.pressed.connect(func(): _info_mode = i; refresh())
		seg.add_child(b)
	_side.add_child(seg)
	if _info_mode == 0:
		_side.add_child(UiStyle.wrap_label(d.trait_desc, 17, 620))
	else:
		var lines := [
			"%s: %s" % [tr("CHAR_ROLE"), tr(d.role_key())],
			"%s: %s" % [tr("CHAR_RANGE"), tr(d.range_key())],
			"%s: %s" % [tr("CHAR_ELEMENT"), tr(d.element_key())],
			"%s: %.0f / %.0f" % [tr("CHAR_MOVE"), d.move_speed, d.attack_range],
		]
		_side.add_child(UiStyle.wrap_label("\n".join(lines), 17, 620))
	var set_lobby := UiStyle.button("CHAR_SET_LOBBY", false, 16)
	set_lobby.disabled = SaveManager.data.lobby_char == String(d.id)
	set_lobby.pressed.connect(func():
		SaveManager.data.lobby_char = String(d.id)
		SaveManager.save_game()
		refresh())
	_side.add_child(set_lobby)


func _tab_grow(d: CharacterData, lv: int, br: int) -> void:
	var cap := Progression.level_cap(br)
	_side.add_child(UiStyle.label(tr("GROW_COST") % OfflineContent._num(Progression.level_up_cost(lv)), 18))
	var row := UiStyle.hbox(12)
	for n in [1, 10]:
		var b := UiStyle.button(tr("GROW_LEVEL_UP") % n, n == 1, 18)
		b.name = "LevelUp%d" % n
		b.disabled = lv >= cap
		b.pressed.connect(_level_up.bind(d.id, n))
		row.add_child(b)
	_side.add_child(row)
	if lv >= cap and br < Progression.MAX_BREAK:
		_side.add_child(UiStyle.label("GROW_NEED_BREAK", 16, UiStyle.ACCENT_RED))


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
	if br >= Progression.MAX_BREAK:
		_side.add_child(UiStyle.label("SHARD_MAX", 18))
		return
	var cost := Progression.break_cost(br)
	_side.add_child(UiStyle.label(tr("SHARD_NEED") % [int(s.shards), cost, Progression.level_cap(br + 1)], 18))
	_side.add_child(UiStyle.bar(float(s.shards) / cost, UiStyle.ACCENT_VOID, Vector2(600, 10)))
	var b := UiStyle.button("SHARD_BREAK", true, 18)
	b.name = "BreakButton"
	b.pressed.connect(func():
		var r := SaveManager.break_through(d.id)
		if r != "":
			toast(tr({"level": "SHARD_NEED_LEVEL", "shards": "SHARD_NOT_ENOUGH"}.get(r, "SHARD_MAX")))
		refresh())
	_side.add_child(b)
	_side.add_child(UiStyle.wrap_label("SHARD_HINT", 15, 620, UiStyle.TEXT_MUTED))


func _tab_skill(d: CharacterData) -> void:
	for pair in [["SKILL_BASIC", d.skill_name, d.skill_desc, d.skill_cooldown], ["SKILL_ULT", d.ult_name, d.ult_desc, d.ult_cooldown]]:
		var h := UiStyle.hbox(12)
		var tag := UiStyle.panel(d.color_main if pair[0] == "SKILL_ULT" else UiStyle.ACCENT_VOID, Color(0, 0, 0, 0), 6)
		tag.add_child(UiStyle.label(pair[0], 15, UiStyle.BG_BASE, true))
		h.add_child(tag)
		h.add_child(UiStyle.label("〈%s〉" % pair[1], 20, UiStyle.TEXT_PRIMARY, true))
		_side.add_child(h)
		_side.add_child(UiStyle.wrap_label(pair[2], 15, 620))
		var cd := tr("SKILL_COOLDOWN") % pair[3]
		if pair[0] == "SKILL_ULT":
			cd += "  ·  " + tr("SKILL_ULT_GAUGE")
		_side.add_child(UiStyle.label(cd, 14, UiStyle.TEXT_MUTED))


func _tab_weapon(d: CharacterData) -> void:
	_side.add_child(UiStyle.label(d.weapon_name, 24, UiStyle.TEXT_PRIMARY, true))
	_side.add_child(UiStyle.wrap_label(d.weapon_desc, 17, 620))


func _tab_profile(d: CharacterData) -> void:
	var lines := [
		"%s  %s" % [tr("PROFILE_NAME"), d.display_name],
		"%s  %s" % [tr("PROFILE_RANK"), UiStyle.stars(d.rank)],
		"%s  %d" % [tr("PROFILE_TALL"), d.height_cm],
		"%s  %s" % [tr("CHAR_ELEMENT"), tr(d.element_key())],
	]
	_side.add_child(UiStyle.label("\n".join(lines), 18))
	_side.add_child(UiStyle.wrap_label(d.profile, 17, 620))
