class_name BattleHud
extends CanvasLayer
## 전투 HUD (Figma 「02 전투 HUD」 4인 확장판). 전투 화면은 픽셀 아트, HUD는 고해상도.

var world: CombatWorld
var _cards := []        ## [{unit, hp, ct, hp_label, ct_label, extra}]
var _slots := []        ## [{unit, kind, label, cover, key}]
var _objective: Label
var _message: PanelContainer
var _message_label: Label
var _prompt: PanelContainer


func setup(w: CombatWorld) -> void:
	world = w
	layer = 5
	_build()
	w.objective_changed.connect(func(k): _objective.text = k)
	w.message.connect(show_message)
	_objective.text = "OBJ_TERMINAL"


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var party := UiStyle.vbox(10)
	party.position = Vector2(32, 32)
	root.add_child(party)
	for u in world.party:
		party.add_child(_party_card(u))

	var obj := UiStyle.panel(Color(UiStyle.BG_BASE, 0.8), UiStyle.ACCENT_VOID, 16)
	var ov := UiStyle.vbox(4)
	ov.add_child(UiStyle.label("HUD_REQUEST", 13, UiStyle.ACCENT_VOID, true))
	_objective = UiStyle.label("", 20)
	ov.add_child(_objective)
	obj.add_child(ov)
	obj.position = Vector2(1480, 32)
	obj.custom_minimum_size = Vector2(408, 0)
	root.add_child(obj)

	var bar := UiStyle.panel(Color(UiStyle.BG_BASE, 0.82), UiStyle.LINE_DEFAULT, 14)
	var bh := UiStyle.hbox(30)
	bar.add_child(bh)
	var j := world.leader
	bh.add_child(_slot_group("J", [[j, "skill", "Q"], [j, "ult", "R"]]))
	var dodge := UiStyle.vbox(6)
	dodge.add_child(UiStyle.label("HUD_DODGE", 13, UiStyle.TEXT_MUTED, true))
	var dk := UiStyle.panel(UiStyle.BG_PANEL, UiStyle.LINE_DEFAULT, 0)
	dk.custom_minimum_size = Vector2(86, 76)
	var dl := UiStyle.label("SPACE", 18)
	dl.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dk.add_child(dl)
	dodge.add_child(dk)
	bh.add_child(dodge)
	for i in 3:
		var a: Unit = world.party[i + 1]
		bh.add_child(_slot_group(a.display_name, [[a, "skill", str(i + 1)], [a, "ult", "⇧" + str(i + 1)]]))
	root.add_child(bar)
	bar.reset_size()
	bar.position = Vector2(960 - bar.size.x / 2, 1080 - 32 - bar.size.y)

	_prompt = UiStyle.panel(Color(UiStyle.BG_BASE, 0.85), UiStyle.STATUS_CONTAMINATION, 10)
	_prompt.add_child(UiStyle.label("HUD_INTERACT", 18))
	_prompt.position = Vector2(860, 720)
	_prompt.hide()
	root.add_child(_prompt)

	_message = UiStyle.panel(Color(UiStyle.BG_PANEL, 0.96), UiStyle.ACCENT_VOID, 24)
	_message_label = UiStyle.wrap_label("", 18, 760)
	_message.add_child(_message_label)
	_message.position = Vector2(560, 300)
	_message.hide()
	root.add_child(_message)


func _party_card(u: Unit) -> PanelContainer:
	var p := UiStyle.panel(Color(UiStyle.BG_BASE, 0.8), UiStyle.LINE_DEFAULT, 10)
	var h := UiStyle.hbox(12)
	var por := UiStyle.texture(u.data.portrait, Vector2(60, 60))
	h.add_child(por)
	var col := UiStyle.vbox(3)
	var nm := UiStyle.hbox(8)
	nm.add_child(UiStyle.label(u.display_name, 18, UiStyle.TEXT_PRIMARY, true))
	nm.add_child(UiStyle.label(tr(u.data.role_key()) + " · Lv." + str(u.level), 12, UiStyle.TEXT_MUTED))
	col.add_child(nm)
	var hp := UiStyle.bar(1.0, UiStyle.STATUS_HP, Vector2(250, 8))
	var hpl := UiStyle.label("", 12, UiStyle.TEXT_MUTED)
	col.add_child(hp)
	col.add_child(hpl)
	var ct := UiStyle.bar(0.0, UiStyle.STATUS_CONTAMINATION, Vector2(250, 5))
	col.add_child(ct)
	var extra := UiStyle.label("", 12, u.color_main)
	col.add_child(extra)
	h.add_child(col)
	p.add_child(h)
	_cards.append({"unit": u, "hp": hp, "ct": ct, "hp_label": hpl, "extra": extra, "panel": p, "por": por})
	return p


func _slot_group(title: String, slots: Array) -> VBoxContainer:
	var v := UiStyle.vbox(6)
	v.add_child(UiStyle.label(title, 13, UiStyle.TEXT_MUTED, true))
	var row := UiStyle.hbox(8)
	for s in slots:
		var u: Unit = s[0]
		var box := Panel.new()
		box.custom_minimum_size = Vector2(76, 76)
		box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_PANEL, UiStyle.LINE_DEFAULT, 4, 0))
		box.tooltip_text = u.data.skill_name if s[1] == "skill" else u.data.ult_name
		var icon := ColorRect.new()
		icon.color = u.color_main
		icon.position = Vector2(22, 12)
		icon.size = Vector2(32, 32)
		box.add_child(icon)
		var cover := ColorRect.new()
		cover.color = Color(0, 0, 0, 0.6)
		cover.position = Vector2.ZERO
		cover.size = Vector2(76, 76)
		box.add_child(cover)
		var cd := UiStyle.label("", 18)
		cd.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
		cd.position = Vector2(0, 18)
		cd.size = Vector2(76, 30)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cd)
		var key := UiStyle.label(s[2], 14)
		key.add_theme_font_override("font", UiStyle.FONT_DISPLAY_BOLD)
		key.position = Vector2(6, 52)
		box.add_child(key)
		row.add_child(box)
		_slots.append({"unit": u, "kind": s[1], "label": cd, "cover": cover, "box": box})
	v.add_child(row)
	return v


func _process(_delta: float) -> void:
	if world == null:
		return
	for c in _cards:
		var u: Unit = c.unit
		UiStyle.set_bar(c.hp, u.hp_ratio())
		UiStyle.set_bar(c.ct, u.contamination / Unit.ULT_COST)
		c.hp_label.text = "%d / %d   %s %d%%" % [int(u.hp), int(u.max_hp), tr("HUD_CONTAM"), int(u.contamination)]
		var g: Dictionary = u.kit.extra_gauge()
		var st := []
		for s in u.statuses:
			if Status.LABEL_KEYS.has(s):
				st.append(tr(Status.LABEL_KEYS[s]))
		var line := ("%s %d/%d" % [tr(g.label_key), int(g.value), int(g.max)]) if not g.is_empty() else ""
		if not st.is_empty():
			line += ("  " if line != "" else "") + " · ".join(st)
		c.extra.text = line
		c.panel.modulate = Color(1, 1, 1, 1.0 if u.alive else 0.45)
	for s in _slots:
		var u: Unit = s.unit
		var ready := false
		var text := ""
		if s.kind == "skill":
			ready = u.alive and u.skill_cd <= 0.0
			text = "" if u.skill_cd <= 0.0 else "%.1f" % u.skill_cd
		else:
			ready = u.can_use_ult()
			if u.ult_cd > 0.0:
				text = "%.1f" % u.ult_cd
			elif u.contamination < Unit.ULT_COST:
				text = "%d%%" % int(u.contamination)
		s.label.text = text
		s.cover.visible = not ready
		var border := UiStyle.STATUS_CONTAMINATION if s.kind == "ult" and ready else UiStyle.LINE_DEFAULT
		var sb: StyleBoxFlat = s.box.get_theme_stylebox("panel")
		sb.border_color = border
		sb.set_border_width_all(2 if border != UiStyle.LINE_DEFAULT else 1)
	_prompt.visible = world.can_interact(world.leader)


func show_message(key: String) -> void:
	_message_label.text = key
	_message.reset_size()
	_message.position = Vector2(960 - _message.size.x / 2, 330)
	_message.show()
	_message.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(_message, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_message.hide)
