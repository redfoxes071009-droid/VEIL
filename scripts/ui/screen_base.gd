class_name ScreenBase
extends Control
## 로비 하위 화면 공통 틀: 배경 · 상단 바(뒤로 · 제목 · 재화) · 본문 영역.
## 하위 클래스는 _build_content(content) 를 구현합니다.

var title_key := ""
var content: Control
var currency_bar: CurrencyBar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiStyle.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_background()

	var top := UiStyle.hbox(24)
	top.position = Vector2(40, 28)
	top.size = Vector2(1840, 64)
	add_child(top)
	var back := UiStyle.button("‹", false, 28)
	back.custom_minimum_size = Vector2(64, 56)
	back.pressed.connect(go_back)
	top.add_child(back)
	var t := UiStyle.label(title_key, 32, UiStyle.TEXT_PRIMARY, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	currency_bar = CurrencyBar.new()
	top.add_child(currency_bar)

	content = Control.new()
	content.name = "Content"
	content.position = Vector2(40, 120)
	content.size = Vector2(1840, 920)
	add_child(content)
	_build_content(content)


func _build_background() -> void:
	pass


func _build_content(_c: Control) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func go_back() -> void:
	SceneManager.change_scene(SceneManager.LOBBY_SCENE)


## 하단에 잠깐 뜨는 안내 문구.
func toast(text: String) -> void:
	var p := UiStyle.panel(Color(UiStyle.BG_PANEL_RAISED, 0.95), UiStyle.ACCENT_VOID, 14)
	p.add_child(UiStyle.label(text, 18))
	add_child(p)
	p.position = Vector2(960 - 200, 980)
	p.reset_size()
	p.position.x = 960 - p.size.x / 2
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
