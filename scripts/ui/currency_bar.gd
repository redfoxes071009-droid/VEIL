class_name CurrencyBar
extends HBoxContainer
## 상단 재화 표시 (PDF 로비: 크레딧 · 에너지 x/240 · 크리스탈).

var _labels := {}


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	for c in ["credit", "energy", "crystal"]:
		var p := UiStyle.panel(Color(UiStyle.BG_BASE, 0.8), UiStyle.LINE_DEFAULT, 8)
		var h := UiStyle.hbox(10)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = {"credit": Color("#FFC83D"), "energy": Color("#3FE0FF"), "crystal": Color("#FF7A3D")}[c]
		var box := CenterContainer.new()
		box.add_child(dot)
		h.add_child(box)
		var l := UiStyle.label("", 18)
		l.add_theme_font_override("font", UiStyle.FONT_DISPLAY_SEMIBOLD)
		l.custom_minimum_size = Vector2(110, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
		p.add_child(h)
		p.tooltip_text = {"credit": "CUR_CREDIT", "energy": "CUR_ENERGY", "crystal": "CUR_CRYSTAL"}[c]
		add_child(p)
		_labels[c] = l
	SaveManager.changed.connect(refresh)
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	t.timeout.connect(refresh)
	add_child(t)
	refresh()


func refresh() -> void:
	if not SaveManager.is_loaded():
		return
	_labels.credit.text = OfflineContent._num(SaveManager.get_currency("credit"))
	_labels.energy.text = "%d / %d" % [SaveManager.get_currency("energy"), SaveManager.ENERGY_MAX]
	_labels.crystal.text = OfflineContent._num(SaveManager.get_currency("crystal"))
