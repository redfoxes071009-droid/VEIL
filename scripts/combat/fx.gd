class_name CombatFx
extends Node2D
## 임시 전투 이펙트 (도형으로 그림). 최종 이펙트 리소스로 교체 예정.

var kind: StringName
var params := {}
var life := 0.35
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if kind == &"text":
		position.y -= 18.0 * delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(1.0 - _t / life, 0.0, 1.0)
	var c: Color = params.get("color", Color.WHITE)
	c.a *= a
	match kind:
		&"tracer":
			draw_line(Vector2.ZERO, params.to - position, c, 1.0)
		&"slash":
			var dir: Vector2 = (params.to - position).normalized()
			draw_arc(dir * 6.0, 6.0, dir.angle() - 1.0, dir.angle() + 1.0, 6, c, 1.5)
		&"beam":
			draw_line(Vector2.ZERO, params.to - position, c, params.get("width", 2.0))
		&"ring":
			draw_arc(Vector2.ZERO, params.radius * (1.0 + _t), 0, TAU, 24, c, 1.0)
		&"burst":
			draw_circle(Vector2.ZERO, params.radius * (0.6 + 0.4 * _t / life), Color(c, c.a * 0.25))
			draw_arc(Vector2.ZERO, params.radius, 0, TAU, 32, c, 1.0)
		&"arc":
			var d: Vector2 = params.dir
			var half: float = params.angle * 0.5
			draw_arc(Vector2.ZERO, params.radius, d.angle() - half, d.angle() + half, 10, c, 2.0)
		&"text":
			var font := ThemeDB.fallback_font
			draw_string_outline(font, Vector2(-12, 0), params.text, HORIZONTAL_ALIGNMENT_CENTER, 24, params.get("size", 8), 2, Color(0, 0, 0, a))
			draw_string(font, Vector2(-12, 0), params.text, HORIZONTAL_ALIGNMENT_CENTER, 24, params.get("size", 8), c)
