extends ScreenBase
## 목록형 로비 화면 묶음: 상점 · 배틀패스 · 파견임무 · 우편 · 공지 · 이벤트.
## 씬마다 kind 를 정해 같은 스크립트를 씁니다 (scenes/ui/*.tscn 의 kind 속성).

@export_enum("shop", "battlepass", "dispatch", "mail", "notice", "event") var kind := "shop"

var _list: VBoxContainer
var _pick: OptionButton
var _dispatch_chars := {}


func _init() -> void:
	pass


func _ready() -> void:
	title_key = {"shop": "LOBBY_SHOP", "battlepass": "LOBBY_BATTLEPASS", "dispatch": "LOBBY_DISPATCH",
		"mail": "LOBBY_MAIL", "notice": "LOBBY_NOTICE", "event": "LOBBY_EVENT"}[kind]
	super._ready()
	if kind == "dispatch":
		var t := Timer.new()
		t.wait_time = 1.0
		t.autostart = true
		t.timeout.connect(refresh)
		add_child(t)


func _build_background() -> void:
	if kind == "event":
		var art := UiStyle.texture(Progression.load_character(&"stage").illust, Vector2(1100, 1080))
		art.position = Vector2(820, 0)
		add_child(art)


func _build_content(c: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(1100 if kind == "event" else 1400, 900)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	_list = UiStyle.vbox(12)
	_list.custom_minimum_size = Vector2(scroll.size.x - 20, 0)
	scroll.add_child(_list)
	refresh()


func refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	call("_fill_" + kind)


func _row(title: String, sub: String, right: Control = null) -> PanelContainer:
	var p := UiStyle.panel(Color(UiStyle.BG_PANEL, 0.92), UiStyle.LINE_DEFAULT, 20)
	var h := UiStyle.hbox(24)
	var col := UiStyle.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiStyle.label(title, 22, UiStyle.TEXT_PRIMARY, true))
	if sub != "":
		col.add_child(UiStyle.wrap_label(sub, 16, 900, UiStyle.TEXT_MUTED))
	h.add_child(col)
	if right:
		h.add_child(right)
	p.add_child(h)
	_list.add_child(p)
	return p


func _action(text: String, enabled: bool, cb: Callable, primary := true) -> Button:
	var b := UiStyle.button(text, primary, 18)
	b.custom_minimum_size = Vector2(220, 56)
	b.disabled = not enabled
	b.pressed.connect(cb)
	return b


func _result(err: String) -> void:
	if err != "":
		toast(tr({"currency": "ERR_CURRENCY", "sold_out": "SHOP_SOLD_OUT", "locked": "BP_LOCKED",
			"claimed": "CLAIMED", "busy": "DISPATCH_BUSY", "running": "DISPATCH_RUNNING"}.get(err, "ERR_CURRENCY")))
	else:
		toast(tr("DONE"))
	refresh()


# ---------- 상점 ----------

func _fill_shop() -> void:
	var pick_row := UiStyle.hbox(12)
	pick_row.add_child(UiStyle.label("SHOP_PICK_LABEL", 18))
	_pick = OptionButton.new()
	for id in Progression.ROSTER:
		_pick.add_item(Progression.load_character(id).display_name)
	pick_row.add_child(_pick)
	_list.add_child(pick_row)
	for item in OfflineContent.SHOP:
		var price := tr("SHOP_FREE") if item.price.is_empty() else OfflineContent.reward_text(item.price)
		var ok := OfflineContent.shop_available(SaveManager, item)
		var it: Dictionary = item
		_row(tr(item.name_key), "%s  ·  %s %s" % [OfflineContent.reward_text(item.reward), tr("SHOP_PRICE"), price],
			_action(tr("SHOP_BUY") if ok else tr("SHOP_SOLD_OUT"), ok, func():
				_result(OfflineContent.buy(SaveManager, it, Progression.ROSTER[_pick.selected]))))
	_list.add_child(UiStyle.label("GACHA_NO_PAYMENT", 14, UiStyle.TEXT_MUTED))


# ---------- 배틀패스 ----------

func _fill_battlepass() -> void:
	var xp := int(SaveManager.data.battlepass.xp)
	var tier := OfflineContent.bp_tier(SaveManager)
	var head := UiStyle.vbox(8)
	head.add_child(UiStyle.label(tr("BP_STATUS") % [tier, OfflineContent.BP_TIERS.size(), xp], 20))
	head.add_child(UiStyle.bar(float(xp % OfflineContent.BP_TIER_XP) / OfflineContent.BP_TIER_XP if tier < OfflineContent.BP_TIERS.size() else 1.0, UiStyle.ACCENT_VOID, Vector2(800, 10)))
	head.add_child(UiStyle.label("BP_HINT", 15, UiStyle.TEXT_MUTED))
	_list.add_child(head)
	for i in OfflineContent.BP_TIERS.size():
		var claimed: bool = i in SaveManager.data.battlepass.claimed
		var unlocked := i < tier
		var idx := i
		var label := tr("CLAIMED") if claimed else (tr("CLAIM") if unlocked else tr("BP_LOCKED"))
		_row(tr("BP_TIER") % (i + 1), OfflineContent.reward_text(OfflineContent.BP_TIERS[i]),
			_action(label, unlocked and not claimed, func(): _result(OfflineContent.bp_claim(SaveManager, idx))))


# ---------- 파견임무 ----------

func _fill_dispatch() -> void:
	_list.add_child(UiStyle.label("DISPATCH_HINT", 15, UiStyle.TEXT_MUTED))
	for m in OfflineContent.DISPATCH:
		var mission: Dictionary = m
		var st := OfflineContent.dispatch_state(SaveManager, m.id)
		var right := UiStyle.hbox(12)
		if st.is_empty():
			var opt := OptionButton.new()
			for id in Progression.ROSTER:
				opt.add_item(Progression.load_character(id).display_name)
			opt.select(_dispatch_chars.get(m.id, 0))
			opt.item_selected.connect(func(i): _dispatch_chars[mission.id] = i)
			right.add_child(opt)
			right.add_child(_action(tr("DISPATCH_START"), true, func():
				_result(OfflineContent.dispatch_start(SaveManager, mission, Progression.ROSTER[_dispatch_chars.get(mission.id, 0)]))))
		else:
			var left := OfflineContent.dispatch_remaining(SaveManager, m.id)
			var who := Progression.load_character(StringName(st.char)).display_name
			right.add_child(UiStyle.label("%s · %s" % [who, _time(left)], 18))
			right.add_child(_action(tr("DISPATCH_COLLECT"), left == 0, func(): _result(OfflineContent.dispatch_collect(SaveManager, mission))))
		_row(tr(m.name_key), "%s  ·  %s" % [_time(m.seconds), OfflineContent.reward_text(m.reward)], right)


func _time(sec: int) -> String:
	return "%02d:%02d" % [sec / 60, sec % 60]


# ---------- 우편 ----------

func _fill_mail() -> void:
	for m in OfflineContent.MAIL:
		var mail: Dictionary = m
		var claimed := OfflineContent.mail_claimed(SaveManager, m.id)
		_row(tr(m.title_key), tr(m.body_key) + "\n" + OfflineContent.reward_text(m.reward),
			_action(tr("CLAIMED") if claimed else tr("CLAIM"), not claimed, func(): _result(OfflineContent.mail_claim(SaveManager, mail))))


# ---------- 공지 ----------

func _fill_notice() -> void:
	for n in OfflineContent.NOTICES:
		_row(tr(n.title_key), tr(n.body_key))


# ---------- 이벤트 ----------

func _fill_event() -> void:
	_list.add_child(UiStyle.label("EVENT_TAG", 18, UiStyle.ACCENT_RED, true))
	_list.add_child(UiStyle.label("EVENT_TITLE", 40, UiStyle.TEXT_PRIMARY, true))
	_list.add_child(UiStyle.wrap_label("EVENT_BODY", 18, 1000, UiStyle.TEXT_MUTED))
	var h := UiStyle.hbox(16)
	h.add_child(_action(tr("LOBBY_GACHA"), true, func(): SceneManager.change_scene(SceneManager.GACHA_SCENE)))
	h.add_child(_action(tr("LOBBY_STORY"), true, func(): SceneManager.change_scene(SceneManager.STORY_SCENE), false))
	_list.add_child(h)
