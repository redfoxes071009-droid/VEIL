class_name UiStyle
extends RefCounted
## Figma 「VEIL — 프로토타입 UI」의 VEIL Color 변수와 같은 값을 씁니다.
## 색을 바꿀 때는 Figma 변수와 이 파일을 함께 바꿔 주세요.

const BG_BASE := Color("#0B0D10")
const BG_PANEL := Color("#141A21")
const BG_PANEL_RAISED := Color("#1C242D")
const LINE_DEFAULT := Color("#2E3844")
const TEXT_PRIMARY := Color("#E6E9ED")
const TEXT_MUTED := Color("#8A949E")
const ACCENT_VOID := Color("#9D7BFF")
const STATUS_HP := Color("#E5484D")
const STATUS_CONTAMINATION := Color("#B6FF3B")

const FONT_DISPLAY_BOLD := preload("res://assets/fonts/Rajdhani-Bold.ttf")
const FONT_DISPLAY_SEMIBOLD := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
const FONT_BODY_BOLD := preload("res://assets/fonts/noto_sans_kr_bold.tres")


static func panel_box(border: Color = LINE_DEFAULT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG_PANEL
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(40)
	return box


## 타이틀·일시정지 메뉴 버튼 (Figma: MenuButton, Default/Focused).
static func menu_button(text_key: String) -> Button:
	var b := Button.new()
	b.text = text_key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 56)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT_MUTED)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, TEXT_PRIMARY)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 27
	normal.content_margin_right = 24
	var focused := StyleBoxFlat.new()
	focused.bg_color = BG_PANEL_RAISED
	focused.border_color = ACCENT_VOID
	focused.border_width_left = 3
	focused.content_margin_left = 24
	focused.content_margin_right = 24
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", focused)
	b.add_theme_stylebox_override("focus", focused)
	b.add_theme_stylebox_override("pressed", focused)
	# 마우스를 올리면 키보드 포커스도 옮겨 두 표시가 겹치지 않게 합니다.
	b.mouse_entered.connect(b.grab_focus)
	return b


const ACCENT_RED := Color("#E0344B")  ## PDF 캐릭터 정보 화면의 선택 탭 색


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 4, margin: int = 16) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1 if border.a > 0 else 0)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b


static func panel(bg: Color = Color(BG_BASE, 0.85), border: Color = LINE_DEFAULT, margin: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 4, margin))
	return p


## 일반 버튼. primary 는 보이드 보라색 채움.
static func button(text_key: String, primary: bool = false, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text_key
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	var bg := ACCENT_VOID if primary else BG_PANEL_RAISED
	var fg := BG_BASE if primary else TEXT_PRIMARY
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	var normal := box(bg, LINE_DEFAULT if not primary else Color(0, 0, 0, 0), 4, 12)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	hover.border_color = ACCENT_VOID
	hover.set_border_width_all(1)
	var disabled := normal.duplicate()
	disabled.bg_color = BG_PANEL
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	return b


static func stars(n: int) -> String:
	return "★".repeat(n)


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func wrap_label(text_key: String, size: int, width: float, color: Color = TEXT_PRIMARY) -> Label:
	var l := label(text_key, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func texture(tex: Texture2D, size: Vector2, mode: int = TextureRect.STRETCH_KEEP_ASPECT_COVERED) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = mode
	t.custom_minimum_size = size
	t.size = size
	t.clip_contents = true
	return t


static func bar(ratio: float, color: Color, size: Vector2) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = size
	track.add_theme_stylebox_override("panel", box(BG_BASE, LINE_DEFAULT, 1, 0))
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(0.0, (size.x - 2) * clampf(ratio, 0.0, 1.0)), size.y - 2)
	track.add_child(fill)
	return track


static func set_bar(track: Control, ratio: float) -> void:
	var fill: ColorRect = track.get_node("Fill")
	fill.size.x = maxf(0.0, (track.custom_minimum_size.x - 2) * clampf(ratio, 0.0, 1.0))


static func label(text_key: String, size: int, color: Color = TEXT_PRIMARY, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text_key
	if bold:
		l.add_theme_font_override("font", FONT_BODY_BOLD)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
