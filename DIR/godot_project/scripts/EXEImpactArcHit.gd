extends Node2D

const COLOR      := Color(1.0, 0.22, 0.05)   # 稍紅
const ARC_WIDTH  :=  8.0
const GLOW_WIDTH := 18.0   # 收窄
const MIN_R      := 14.0
const MAX_R      := 150.0
const SPREAD     := PI / 9.0   # ±20°

var dir_vec: Vector2 = Vector2.UP
var arc_t: float = 0.0

func _ready() -> void:
	z_index = 7
	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, 0.18)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)

func _set_t(t: float) -> void: arc_t = t; queue_redraw()

func _draw() -> void:
	if arc_t <= 0.0:
		return
	var r     := lerpf(MIN_R, MAX_R, arc_t)
	var alpha: float = clamp(2.0 - arc_t * 2.0, 0.0, 1.0)   # t<0.5 全亮，之後線性淡出
	var a0    := dir_vec.angle()
	draw_arc(Vector2.ZERO, r, a0 - SPREAD, a0 + SPREAD, 48,
			 Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.45), GLOW_WIDTH)
	draw_arc(Vector2.ZERO, r, a0 - SPREAD, a0 + SPREAD, 48,
			 Color(COLOR.r, COLOR.g, COLOR.b, alpha), ARC_WIDTH)
