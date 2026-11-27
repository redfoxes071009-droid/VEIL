class_name RunText
extends Control
## 한 줄 글자를 PSD 기준선(baseline)에 그대로 그립니다. 「< >」로 감싼 부분은 강조색.
## (모집 · 캐릭터 정보 화면에서 그림에 맞춰 바뀌는 값을 그릴 때 사용)

var font: Font
var font_size := 22
var color := Color.WHITE
var highlight := Color.WHITE
var align := HORIZONTAL_ALIGNMENT_LEFT
var baseline := Vector2.ZERO
var text := ""               ## 강조 표시를 뺀 실제 글자
var runs: Array = []         ## [[글자, 강조 여부], ...]

func set_runs(s: String) -> void:
	runs.clear()
	var hl := false
	var cur := ""
	for ch in s:
		if ch == "<" or ch == ">":
			if cur != "":
				runs.append([cur, hl])
			cur = ""
			hl = ch == "<"
		else:
			cur += ch
	if cur != "":
		runs.append([cur, hl])
	text = ""
	for r in runs:
		text += r[0]
	queue_redraw()

func _draw() -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := baseline.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	for r in runs:
		draw_string(font, Vector2(x, baseline.y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, highlight if r[1] else color)
		x += font.get_string_size(r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func text_width() -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
