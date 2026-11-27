class_name LobbyHotspot
extends BaseButton
## 로비 그림 위의 투명 버튼. 원근이 들어간 카드 모양(사각형 4점)대로만 눌리고,
## 마우스를 올리거나 키보드로 선택하면 카드 테두리가 밝게 빛납니다.

const GLOW := Color("#B8D2FF")

var polygon := PackedVector2Array()   ## 이 노드 기준 좌표


## pts: 로비 캔버스(2576×1264) 좌표의 꼭짓점들.
func setup(pts: Array) -> void:
	var r := Rect2(Vector2(pts[0][0], pts[0][1]), Vector2.ZERO)
	for p in pts:
		r = r.expand(Vector2(p[0], p[1]))
	position = r.position
	size = r.size
	polygon.clear()
	for p in pts:
		polygon.append(Vector2(p[0], p[1]) - r.position)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)


func _draw() -> void:
	var mode := get_draw_mode()
	var lit := mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED or mode == DRAW_PRESSED or has_focus()
	if not lit:
		return
	var a := 0.16 if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0.07
	draw_colored_polygon(polygon, Color(GLOW, a))
	var loop := polygon.duplicate()
	loop.append(polygon[0])
	draw_polyline(loop, Color(GLOW, 0.95), 3.0, true)
