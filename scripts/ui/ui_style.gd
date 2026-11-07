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


static func label(text_key: String, size: int, color: Color = TEXT_PRIMARY, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text_key
	if bold:
		l.add_theme_font_override("font", FONT_BODY_BOLD)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
