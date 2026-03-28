extends Node2D

const COLOR       := Color(0.2, 0.4, 0.9)   # COR 角色色
const MIN_RADIUS  :=  5.0
const MAX_RADIUS  := 65.0                    # 略超出格子半徑(50)
const RING_WIDTH  :=  3.0
const GLOW_WIDTH  :=  8.0

var ring1_t: float = 0.0   # 0→1
var ring2_t: float = 0.0   # 0→1，延遲啟動

func _ready() -> void:
	z_index = 6  # HitEffect(5) 之上

	# Ring 1：立刻展開
	var tw1 := create_tween()
	tw1.tween_method(_set_r1, 0.0, 1.0, 0.45)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Ring 2：延遲 0.10s 後展開
	var tw2 := create_tween()
	tw2.tween_interval(0.10)
	tw2.tween_method(_set_r2, 0.0, 1.0, 0.45)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_callback(queue_free)

func _set_r1(t: float) -> void:
	ring1_t = t
	queue_redraw()

func _set_r2(t: float) -> void:
	ring2_t = t
	queue_redraw()

func _draw() -> void:
	_draw_ring(ring1_t)
	_draw_ring(ring2_t)

func _draw_ring(t: float) -> void:
	if t <= 0.0:
		return
	var r     := lerpf(MIN_RADIUS, MAX_RADIUS, t)
	var alpha := 1.0 - t
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
	         Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.25), GLOW_WIDTH)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
	         Color(COLOR.r, COLOR.g, COLOR.b, alpha), RING_WIDTH)
