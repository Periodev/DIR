extends Node2D

const CORE_COLOR := Color(0.55, 1.0, 0.40, 1.0)
const HALO_COLOR := Color(0.40, 1.0, 0.35, 0.52)
const CORE_WIDTH := 3.0
const HALO_WIDTH := 8.0

var _angle: float = 0.0
var _alpha: float = 1.0
var _scale_mul: float = 1.16
var _progress: float = 0.0

func setup(facing_dir: int, hold_duration: float) -> void:
	_angle = _facing_to_angle(facing_dir)
	z_index = 7
	queue_redraw()

	var tw: Tween = create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, hold_duration)\
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_alpha, 1.0, 0.0, 0.04)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_scale_mul, 1.16, 1.06, hold_duration)\
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)

func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()

func _set_scale_mul(value: float) -> void:
	_scale_mul = value
	queue_redraw()

func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.0:
		return

	var points: PackedVector2Array = _make_blade_points(_scale_mul)
	var loop: PackedVector2Array = points + PackedVector2Array([points[0]])
	var ring_alpha: float = _alpha * (1.0 - _progress * 0.72)
	if ring_alpha > 0.0:
		draw_polyline(loop, Color(HALO_COLOR.r, HALO_COLOR.g, HALO_COLOR.b, HALO_COLOR.a * ring_alpha), HALO_WIDTH)
		draw_polyline(loop, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, ring_alpha), CORE_WIDTH)

	var tip_dir: Vector2 = Vector2.UP.rotated(_angle)
	var tip: Vector2 = tip_dir * (35.0 * _scale_mul)
	var perp: Vector2 = tip_dir.rotated(PI * 0.5)
	var front_weight: float = clampf((_progress - 0.18) / 0.82, 0.0, 1.0)
	if front_weight > 0.0:
		var start_center: Vector2 = tip_dir * lerpf(-6.0, 6.0, front_weight)
		var side_span: float = lerpf(34.0, 10.0, front_weight)
		var beam_len: float = lerpf(22.0, 12.0, front_weight)
		var beam: PackedVector2Array = PackedVector2Array([
			start_center + perp * side_span,
			tip - tip_dir * beam_len,
			start_center - perp * side_span,
		])
		draw_colored_polygon(beam, Color(HALO_COLOR.r, HALO_COLOR.g, HALO_COLOR.b, 0.28 * _alpha * front_weight))
		draw_polyline(beam + PackedVector2Array([beam[0]]), Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.65 * _alpha * front_weight), 2.2)

func _make_blade_points(scale_mul: float) -> PackedVector2Array:
	var base: PackedVector2Array = PackedVector2Array([
		Vector2(0, -35),
		Vector2(14, 0),
		Vector2(0, 14.0 * sqrt(3)),
		Vector2(-14, 0),
	])
	var points: PackedVector2Array = PackedVector2Array()
	for p in base:
		points.append((p * scale_mul).rotated(_angle))
	return points

func _facing_to_angle(dir: int) -> float:
	match dir:
		CharacterData.Direction.UP:
			return 0.0
		CharacterData.Direction.RIGHT:
			return PI * 0.5
		CharacterData.Direction.DOWN:
			return PI
		CharacterData.Direction.LEFT:
			return -PI * 0.5
		_:
			return 0.0
