extends ScreenBase
## 모집 (로컬 전용, 실제 결제 없음). 픽업: 무대 위의 악마 · 스테이지.

var rng := RandomNumberGenerator.new()
var _results: HBoxContainer
var _pity: Label


func _init() -> void:
	title_key = "LOBBY_GACHA"


func _build_background() -> void:
	var art := UiStyle.texture(Progression.load_character(Gacha.PICKUP).illust, Vector2(1100, 1080))
	art.position = Vector2(820, 0)
	art.modulate = Color(1, 1, 1, 0.9)
	add_child(art)


func _build_content(c: Control) -> void:
	rng.randomize()
	var col := UiStyle.vbox(18)
	col.position = Vector2(0, 30)
	c.add_child(col)
	col.add_child(UiStyle.label("GACHA_BANNER_TAG", 18, UiStyle.ACCENT_RED, true))
	col.add_child(UiStyle.label("GACHA_BANNER_TITLE", 44, UiStyle.TEXT_PRIMARY, true))
	col.add_child(UiStyle.wrap_label("GACHA_RATES", 16, 760, UiStyle.TEXT_MUTED))
	_pity = UiStyle.label("", 16)
	col.add_child(_pity)
	var row := UiStyle.hbox(16)
	var one := UiStyle.button(tr("GACHA_ONE") % Gacha.COST_ONE, false, 20)
	one.name = "PullOne"
	one.custom_minimum_size = Vector2(260, 64)
	one.pressed.connect(_pull.bind(1))
	row.add_child(one)
	var ten := UiStyle.button(tr("GACHA_TEN") % Gacha.COST_TEN, true, 20)
	ten.name = "PullTen"
	ten.custom_minimum_size = Vector2(260, 64)
	ten.pressed.connect(_pull.bind(10))
	row.add_child(ten)
	col.add_child(row)
	col.add_child(UiStyle.label("GACHA_NO_PAYMENT", 14, UiStyle.TEXT_MUTED))
	_results = UiStyle.hbox(10)
	_results.position = Vector2(0, 560)
	c.add_child(_results)
	_refresh()


func _refresh() -> void:
	_pity.text = tr("GACHA_PITY") % [int(SaveManager.data.gacha.pity), Gacha.PITY]


func _pull(n: int) -> void:
	var res := Gacha.pull(SaveManager, n, rng)
	if res.is_empty():
		toast(tr("ERR_CRYSTAL"))
		return
	for ch in _results.get_children():
		ch.queue_free()
	for r in res:
		var card := UiStyle.panel(UiStyle.BG_PANEL, [UiStyle.LINE_DEFAULT, UiStyle.LINE_DEFAULT, UiStyle.LINE_DEFAULT, Color("#3FE0FF"), Color("#B88CFF"), Color("#FFC83D")][r.rarity], 8)
		var v := UiStyle.vbox(4)
		if r.has("char"):
			v.add_child(UiStyle.texture(Progression.load_character(r.char).portrait, Vector2(140, 140)))
			v.add_child(UiStyle.label(UiStyle.stars(r.rarity), 14))
			v.add_child(UiStyle.label("%s %s ×%d" % [Progression.load_character(r.char).display_name, tr("CUR_SHARD"), r.shards], 13))
		else:
			var blank := ColorRect.new()
			blank.custom_minimum_size = Vector2(140, 140)
			blank.color = UiStyle.BG_PANEL_RAISED
			v.add_child(blank)
			v.add_child(UiStyle.label(UiStyle.stars(r.rarity), 14))
			v.add_child(UiStyle.label("%s ×%s" % [tr("CUR_CREDIT"), OfflineContent._num(r.credit)], 13))
		card.add_child(v)
		_results.add_child(card)
	_refresh()
