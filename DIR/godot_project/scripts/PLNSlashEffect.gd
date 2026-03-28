extends Node2D

var dir_vec: Vector2 = Vector2.ZERO
var slash_extent: float = 0.0  # 0..1  — tip travel distance
var slash_alpha:  float = 0.0  # 0..1  — opacity (independent of extent)
var spark_t:      float = 0.0

const SLASH_LEN       := 160.0  # full — tip passes through enemy
const SLASH_LEN_SHORT := 120.0  # short — tip slightly overlaps enemy cell
const BEHIND_LEN      :=  38.0
const MAX_WIDTH       :=   5.0
const MAX_WIDTH_SHORT :=   3.5  # slightly thinner for the blocked version
const GLOW_WIDTH      :=   9.0
const SCAR_STEPS      :=  12
const SPARK_SPREAD    := 14.0
const SPARK_LEN       :=  9.0
const SLASH_COLOR     := Color(0.15, 1.0, 0.55)
const WINDUP          := 0.13

var _slash_len: float  = SLASH_LEN
var _max_width: float  = MAX_WIDTH

func setup(dv: Vector2, short: bool = false, windup_override: float = -1.0, no_sparks: bool = false, length_override: float = -1.0) -> void:
	var actual_windup := WINDUP if windup_override < 0.0 else windup_override
	dir_vec    = dv.normalized()
	z_index    = 8
	if length_override >= 0.0:
		_slash_len = length_override
		_max_width = MAX_WIDTH
	else:
		_slash_len = SLASH_LEN_SHORT if short else SLASH_LEN
		_max_width = MAX_WIDTH_SHORT if short else MAX_WIDTH

	# Windup pause → tip extends out
	var tw_ext := create_tween()
	tw_ext.tween_interval(actual_windup)
	tw_ext.tween_method(_set_extent, 0.0, 1.0, 0.03)\
		  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Alpha: pause → snap in → hold → slow fade
	var tw_a := create_tween()
	tw_a.tween_interval(actual_windup)
	tw_a.tween_method(_set_alpha, 0.0, 1.0, 0.02)\
		.set_trans(Tween.TRANS_LINEAR)
	tw_a.tween_interval(0.12)
	tw_a.tween_method(_set_alpha, 1.0, 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_a.tween_callback(queue_free)

	# Sparks trigger when tip arrives
	if not no_sparks:
		var tw_sp := create_tween()
		tw_sp.tween_interval(actual_windup + 0.03)
		tw_sp.tween_method(_set_spark, 0.0, 1.0, 0.18)\
			 .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_extent(t: float) -> void:
	slash_extent = t
	queue_redraw()

func _set_alpha(t: float) -> void:
	slash_alpha = t
	queue_redraw()

func _set_spark(t: float) -> void:
	spark_t = t
	queue_redraw()

func _draw() -> void:
	if slash_alpha > 0.0:
		var tail := dir_vec * -BEHIND_LEN
		var tip  := dir_vec * (slash_extent * _slash_len)
		_draw_scar(tail, tip, slash_alpha)

	if spark_t > 0.0:
		var impact     := dir_vec * _slash_len
		var spark_alpha := 1.0 - spark_t
		if spark_alpha > 0.0:
			var angles := [-PI / 6.0, PI / 6.0, -PI / 3.0, PI / 3.0, 0.0]
			for a in angles:
				var sd    := dir_vec.rotated(a)
				var start := impact
				var end   := impact + sd * (spark_t * SPARK_SPREAD + SPARK_LEN * 0.5)
				draw_line(start, end, Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, spark_alpha), 1.5)

# Draws a lens/spindle polygon along [tail → tip].
# Width profile is a sin curve — zero at both ends, MAX_WIDTH at centre.
func _draw_scar(tail: Vector2, tip: Vector2, alpha: float) -> void:
	var perp := dir_vec.rotated(PI * 0.5)
	var n    := SCAR_STEPS

	var pts_core := PackedVector2Array()
	var pts_glow := PackedVector2Array()

	# Upper edge: tail → tip
	for i in range(n + 1):
		var t := float(i) / float(n)
		var p := tail.lerp(tip, t)
		var w := sin(t * PI)
		pts_core.append(p + perp * (w * _max_width))
		pts_glow.append(p + perp * (w * GLOW_WIDTH))

	# Lower edge: tip → tail  (completes the closed shape)
	for i in range(n, -1, -1):
		var t := float(i) / float(n)
		var p := tail.lerp(tip, t)
		var w := sin(t * PI)
		pts_core.append(p - perp * (w * _max_width))
		pts_glow.append(p - perp * (w * GLOW_WIDTH))

	draw_colored_polygon(pts_glow, Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, alpha * 0.20))
	draw_colored_polygon(pts_core, Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, alpha))
