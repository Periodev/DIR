extends Node2D

var diamond_scale: float = 1.0
var diamond_alpha: float = 1.0
const DIAMOND_RADIUS := 30.0

func _ready() -> void:
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "diamond_scale", 0.0, 0.25)
	tw.tween_property(self, "diamond_alpha", 0.0, 0.25)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if diamond_alpha <= 0.0:
		return
	var r := DIAMOND_RADIUS * diamond_scale
	var pts := PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0),
		Vector2(0, r),  Vector2(-r, 0)
	])
	var color := Color(0.85, 0.15, 0.15, diamond_alpha)
	draw_polygon(pts, PackedColorArray([color, color, color, color]))
