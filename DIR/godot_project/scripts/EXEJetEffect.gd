extends Node2D

const GLOW_COLOR := Color(0.95, 0.40, 0.05)
const CORE_COLOR := Color(1.0, 0.97, 0.85)

# 主線池（3 種長度，每次隨機抽 1）
const MAIN_POOL := [
	[0.0, 28.0, Vector2(0.0, 0.0), true],
	[0.0, 36.0, Vector2(0.0, 0.0), true],
	[0.0, 46.0, Vector2(0.0, 0.0), true],
]

# 副線池（8 條），每次隨機抽 3–5 條
# [angle_deg, outer_r, start_offset, is_main]
const SEC_POOL := [
	[ -8.0, 24.0, Vector2(-1.0,  1.0), false],
	[ 13.0, 21.0, Vector2( 1.0,  0.0), false],
	[-17.0, 18.0, Vector2(-1.0, -1.0), false],
	[ 27.0, 16.0, Vector2( 1.0,  1.0), false],
	[ -6.0, 20.0, Vector2( 0.0,  1.0), false],
	[ 22.0, 14.0, Vector2( 1.0, -1.0), false],
	[-32.0, 12.0, Vector2(-1.0,  0.0), false],
	[ 10.0, 26.0, Vector2( 0.0, -1.0), false],
]
const INNER_R := 3.0

var dir_vec: Vector2 = Vector2.DOWN
var time_scale: float = 2.0   # 放慢倍率，1.0 = 正常，2.0 = 慢兩倍
var _compress_phase: bool = true
var _release_t:  float = 0.0
var _sec_alpha:  float = 1.0
var _main_alpha: float = 1.0

var _lines: Array = []

func _ready() -> void:
	z_index = 9
	# 抽副線：shuffle 後取前 randi_range(3,5) 條
	var pool := SEC_POOL.duplicate()
	pool.shuffle()
	_lines = [MAIN_POOL[randi() % 3]] + pool.slice(0, randi_range(3, 5))
	var s := time_scale
	var tw_r := create_tween()
	tw_r.tween_interval(0.04 * s)
	tw_r.tween_callback(_start_release)
	tw_r.tween_method(_set_release_t, 0.0, 1.0, 0.12 * s)\
	    .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var tw_s := create_tween()
	tw_s.tween_interval(0.04 * s)
	tw_s.tween_method(_set_sec_alpha, 1.0, 0.0, 0.14 * s)\
	    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tw_m := create_tween()
	tw_m.tween_interval(0.06 * s)
	tw_m.tween_method(_set_main_alpha, 1.0, 0.0, 0.20 * s)\
	    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


	var tw_f := create_tween()
	tw_f.tween_interval(0.28 * s)
	tw_f.tween_callback(queue_free)

func _start_release()    -> void: _compress_phase = false
func _set_release_t(v: float) -> void: _release_t = v;  queue_redraw()
func _set_sec_alpha(v: float) -> void: _sec_alpha  = v;  queue_redraw()
func _set_main_alpha(v: float)-> void: _main_alpha = v;  queue_redraw()

func _draw() -> void:
	var base_angle := dir_vec.angle()
	for line in _lines:
		var angle   : float   = base_angle + deg_to_rad(line[0])
		var outer_r : float   = line[1]
		var offset  : Vector2 = line[2]
		var is_main : bool    = line[3]
		var alpha   := _main_alpha if is_main else _sec_alpha
		if alpha <= 0.0:
			continue
		var d     := Vector2(cos(angle), sin(angle))
		var cur_r : float
		if _compress_phase:
			cur_r = outer_r * 0.7
		else:
			cur_r = lerpf(outer_r * 0.7, outer_r * 1.5, _release_t)
		var inner := offset + d * INNER_R
		var outer := offset + d * cur_r
		var gw := 5.0 if is_main else 3.0
		var cw := 1.5 if is_main else 1.0
		draw_line(inner, outer,
		          Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, alpha * 0.5), gw)
		draw_line(inner, outer,
		          Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, alpha), cw)
