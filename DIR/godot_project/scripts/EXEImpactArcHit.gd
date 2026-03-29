extends Node2D

const COLOR      := Color(0.95, 0.40, 0.05)   # EXE jet orange
const ARC_WIDTH  :=  15.0
const GLOW_WIDTH := 32.0
const MIN_R      := 14.0
const MAX_R      := 170.0
const SPREAD     := PI / 6.0   # ±30°

var dir_vec: Vector2 = Vector2.UP
var arc_t: float = 0.0

func _ready() -> void:
	z_index = 7
	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, 0.30)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)

func _set_t(t: float) -> void: arc_t = t; queue_redraw()

func _draw() -> void:
	if arc_t <= 0.0:
		return
	var r     := lerpf(MIN_R, MAX_R, arc_t)
	var alpha: float = clamp(3.33 - arc_t * 3.33, 0.0, 1.0)   # t<0.7 全亮，之後線性淡出
	var a0    := dir_vec.angle()
	draw_arc(Vector2.ZERO, r, a0 - SPREAD, a0 + SPREAD, 48,
			 Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.45), GLOW_WIDTH)
	draw_arc(Vector2.ZERO, r, a0 - SPREAD, a0 + SPREAD, 48,
			 Color(COLOR.r, COLOR.g, COLOR.b, alpha), ARC_WIDTH)
