extends Node2D

const COLOR      := Color(0.2, 0.4, 0.9)
const ARC_WIDTH  :=  8.0
const GLOW_WIDTH := 22.0
const MIN_R      := 18.0
const MAX_R      := 85.0
const SPREAD     := PI / 6.0    # ±30°，約 60° 弧寬

var dir_vec: Vector2 = Vector2.UP   # add_child 前設定
var arc1_t: float = 0.0
var arc2_t: float = 0.0
var arc3_t: float = 0.0

func _ready() -> void:
	z_index = 7   # CORRippleEffect(6) 之上，Player(10) 之下

	var tw1 := create_tween()
	tw1.tween_method(_set_a1, 0.0, 1.0, 0.25)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var tw2 := create_tween()
	tw2.tween_interval(0.07)
	tw2.tween_method(_set_a2, 0.0, 1.0, 0.25)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var tw3 := create_tween()
	tw3.tween_interval(0.14)
	tw3.tween_method(_set_a3, 0.0, 1.0, 0.25)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw3.tween_callback(queue_free)

func _set_a1(t: float) -> void: arc1_t = t; queue_redraw()
func _set_a2(t: float) -> void: arc2_t = t; queue_redraw()
func _set_a3(t: float) -> void: arc3_t = t; queue_redraw()

func _draw() -> void:
	_draw_arc(arc1_t)
	_draw_arc(arc2_t)
	_draw_arc(arc3_t)

func _draw_arc(t: float) -> void:
	if t <= 0.0:
		return
	var r     := lerpf(MIN_R, MAX_R, t)
	var alpha := 1.0 - t
	var a0    := dir_vec.angle()
	draw_arc(Vector2.ZERO, r, a0 - SPREAD, a0 + SPREAD, 32,
	         Color(COLOR.r, COLOR.g, COLOR.b, alpha), GLOW_WIDTH)
	draw_arc(Vector2.ZERO, r, a0 - SPREAD, a0 + SPREAD, 32,
	         Color(COLOR.r, COLOR.g, COLOR.b, alpha), ARC_WIDTH)
