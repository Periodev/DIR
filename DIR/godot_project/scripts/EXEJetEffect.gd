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
# 攻擊副線池（6 條，大角度擴散），隨機取 3 條
const ATTACK_SEC_POOL := [
	[-48.0, 22.0, Vector2(-1.0,  1.0), false],
	[ 42.0, 20.0, Vector2( 1.0,  0.0), false],
	[-28.0, 26.0, Vector2(-1.0, -1.0), false],
	[ 55.0, 18.0, Vector2( 1.0,  1.0), false],
	[-18.0, 24.0, Vector2( 0.0,  1.0), false],
	[ 38.0, 16.0, Vector2( 1.0, -1.0), false],
]
const INNER_R := 3.0

var dir_vec: Vector2 = Vector2.DOWN
var use_attack_pool: bool = false
var time_scale: float = 1.2   # 放慢倍率，1.0 = 正常，2.0 = 慢兩倍
var force_main_idx: int = -1  # -1 = 隨機；0/1/2 = 固定選哪條主線
var force_sec_count: int = -1 # -1 = 隨機 3–5；正整數 = 固定副線數
var compress_dur: float = 0.04 # compress phase 持續時間
var _compress_phase: bool = true
var _release_t:  float = 0.0
var _sec_alpha:  float = 1.0
var _main_alpha: float = 1.0

var _lines: Array = []

func _ready() -> void:
	z_index = 9
	# 主線：force_main_idx >= 0 時固定，否則隨機
	var main_line = MAIN_POOL[force_main_idx] if force_main_idx >= 0 else MAIN_POOL[randi() % 3]
	# 一般副線：隨機 3–5 條
	var pool := SEC_POOL.duplicate()
	pool.shuffle()
	var sec_count := force_sec_count if force_sec_count > 0 else randi_range(3, 5)
	_lines = [main_line] + pool.slice(0, sec_count)
	# 攻擊模式：額外加 3 條大角度擴散副線
	if use_attack_pool:
		var atk_pool := ATTACK_SEC_POOL.duplicate()
		atk_pool.shuffle()
		_lines += atk_pool.slice(0, 3)
	var s := time_scale
	var cd := compress_dur
	var tw_r := create_tween()
	tw_r.tween_interval(cd * s)
	tw_r.tween_callback(_start_release)
	tw_r.tween_method(_set_release_t, 0.0, 1.0, 0.12 * s)\
	    .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var tw_s := create_tween()
	tw_s.tween_interval(cd * s)
	tw_s.tween_method(_set_sec_alpha, 1.0, 0.0, 0.14 * s)\
	    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tw_m := create_tween()
	tw_m.tween_interval((cd + 0.02) * s)
	tw_m.tween_method(_set_main_alpha, 1.0, 0.0, 0.20 * s)\
	    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var tw_f := create_tween()
	tw_f.tween_interval((cd + 0.24) * s)
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
