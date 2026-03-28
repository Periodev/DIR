extends Node2D

var dir_vec: Vector2 = Vector2.ZERO
var slash_extent: float = 0.0  # 0..1  — tip travel distance
var slash_alpha:  float = 0.0  # 0..1  — opacity (independent of extent)
var spark_t:      float = 0.0

const SLASH_LEN    := 130.0
const BEHIND_LEN   :=  38.0
const MAX_WIDTH    :=   5.0   # scar thickness at centre
const GLOW_WIDTH   :=   9.0   # soft outer glow half-width
const SCAR_STEPS   :=  12     # polygon subdivision (smoothness)
const SPARK_SPREAD := 14.0
const SPARK_LEN    :=  9.0

func setup(dv: Vector2) -> void:
	dir_vec = dv.normalized()
	z_index = 8

	# Tip extends out fast
	var tw_ext := create_tween()
	tw_ext.tween_method(_set_extent, 0.0, 1.0, 0.06)\
		  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Alpha: snap in → hold → slow fade (scar lingers)
	var tw_a := create_tween()
	tw_a.tween_method(_set_alpha, 0.0, 1.0, 0.04)\
		.set_trans(Tween.TRANS_LINEAR)
	tw_a.tween_interval(0.10)
	tw_a.tween_method(_set_alpha, 1.0, 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_a.tween_callback(queue_free)

	# Sparks trigger when tip arrives
	var tw_sp := create_tween()
	tw_sp.tween_interval(0.06)
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
		var tip  := dir_vec * (slash_extent * SLASH_LEN)
		_draw_scar(tail, tip, slash_alpha)

	if spark_t > 0.0:
		var impact     := dir_vec * SLASH_LEN
		var spark_alpha := 1.0 - spark_t
		if spark_alpha > 0.0:
			var angles := [-PI / 6.0, PI / 6.0, -PI / 3.0, PI / 3.0, 0.0]
			for a in angles:
				var sd    := dir_vec.rotated(a)
				var start := impact
				var end   := impact + sd * (spark_t * SPARK_SPREAD + SPARK_LEN * 0.5)
				draw_line(start, end, Color(1.0, 1.0, 1.0, spark_alpha), 1.5)

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
		pts_core.append(p + perp * (w * MAX_WIDTH))
		pts_glow.append(p + perp * (w * GLOW_WIDTH))

	# Lower edge: tip → tail  (completes the closed shape)
	for i in range(n, -1, -1):
		var t := float(i) / float(n)
		var p := tail.lerp(tip, t)
		var w := sin(t * PI)
		pts_core.append(p - perp * (w * MAX_WIDTH))
		pts_glow.append(p - perp * (w * GLOW_WIDTH))

	draw_colored_polygon(pts_glow, Color(1.0, 1.0, 1.0, alpha * 0.18))
	draw_colored_polygon(pts_core, Color(1.0, 1.0, 1.0, alpha))
