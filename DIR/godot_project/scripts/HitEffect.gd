extends Node2D

var color: Color = Color(0.8, 0.15, 0.15, 1.0)
const FLASH_RADIUS := 33.0

func _ready() -> void:
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_method(_set_color, Color(0.8, 0.15, 0.15, 1.0), Color(1.0, 1.0, 1.0, 1.0), 0.05)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_color, Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0), 0.35)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _set_color(c: Color) -> void:
	color = c
	queue_redraw()

func _draw() -> void:
	if color.a <= 0.0:
		return
	var r := FLASH_RADIUS
	var octagon := PackedVector2Array([
		Vector2(0, -r),
		Vector2(r * 0.7, -r * 0.7),
		Vector2(r, 0),
		Vector2(r * 0.7, r * 0.7),
		Vector2(0, r),
		Vector2(-r * 0.7, r * 0.7),
		Vector2(-r, 0),
		Vector2(-r * 0.7, -r * 0.7),
	])
	draw_polygon(octagon, PackedColorArray([color, color, color, color, color, color, color, color]))
