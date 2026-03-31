extends Node2D

const COLOR      := Color(0.2, 0.4, 0.9)
const MAX_R      := 62.0
const MIN_R      :=  8.0
const RING_WIDTH :=  7.0
const GLOW_WIDTH := 20.0
const RING_DUR   :=  0.14   # 收縮 0.06+0.14=0.20s 完成
const STAGGER    :=  0.06

var ring1_t: float = 0.0
var ring2_t: float = 0.0

func _ready() -> void:
	z_index = 6

	var tw1 := create_tween()
	tw1.tween_method(_set_r1, 0.0, 1.0, RING_DUR)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tw2 := create_tween()
	tw2.tween_interval(STAGGER)
	tw2.tween_method(_set_r2, 0.0, 1.0, RING_DUR)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_callback(queue_free)

func _set_r1(t: float) -> void: ring1_t = t; queue_redraw()
func _set_r2(t: float) -> void: ring2_t = t; queue_redraw()

func _draw() -> void:
	_draw_ring(ring1_t)
	_draw_ring(ring2_t)

func _draw_ring(t: float) -> void:
	if t <= 0.0:
		return
	var r     := lerpf(MAX_R, MIN_R, t)   # 由外往內收縮
	var alpha := t                         # 越收越亮（蓄力感）
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
	         Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.30), GLOW_WIDTH)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
	         Color(COLOR.r, COLOR.g, COLOR.b, alpha), RING_WIDTH)
