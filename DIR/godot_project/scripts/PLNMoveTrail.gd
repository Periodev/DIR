extends Node2D

const COLOR      := Color(0.2, 0.8, 0.3)
const CORE_WIDTH := 1.5
const GLOW_WIDTH := 5.0

var _from: Vector2
var _to: Vector2
var _t: float = 0.0

func setup(p_from: Vector2, p_to: Vector2) -> void:
	_from = p_from
	_to = p_to

func _ready() -> void:
	z_index = 9  # Player(10) 之下，剛好在角色背後

	var tw := create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, 0.30)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _set_t(val: float) -> void:
	_t = val
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - _t
	draw_line(_from, _to,
	          Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.3), GLOW_WIDTH)
	draw_line(_from, _to,
	          Color(COLOR.r, COLOR.g, COLOR.b, alpha), CORE_WIDTH)
