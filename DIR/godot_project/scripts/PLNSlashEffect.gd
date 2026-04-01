extends Node2D

var dir_vec: Vector2 = Vector2.ZERO
var slash_extent: float = 0.0
var slash_alpha: float = 0.0

const SLASH_LEN := 160.0
const SLASH_LEN_SHORT := 120.0
const TAIL_OFFSET := 0.0
const MAX_WIDTH := 14.0
const MAX_WIDTH_SHORT := 12.0
const GLOW_WIDTH := 22.0
const SCAR_STEPS := 12
const SLASH_COLOR := Color(0.15, 1.0, 0.55)
const WINDUP := 0.22
const TAIL_FADE_ALPHA := 0.08
const TAIL_GLOW_ALPHA := 0.02

var _slash_len: float = SLASH_LEN
var _max_width: float = MAX_WIDTH

func setup(dv: Vector2, short: bool = false, windup_override: float = -1.0, _no_sparks: bool = false, length_override: float = -1.0) -> void:
	var actual_windup: float = WINDUP if windup_override < 0.0 else windup_override
	dir_vec = dv.normalized()
	z_index = 8
	if length_override >= 0.0:
		_slash_len = length_override
		_max_width = MAX_WIDTH
	else:
		_slash_len = SLASH_LEN_SHORT if short else SLASH_LEN
		_max_width = MAX_WIDTH_SHORT if short else MAX_WIDTH

	var tw_ext: Tween = create_tween()
	tw_ext.tween_interval(actual_windup)
	tw_ext.tween_method(_set_extent, 0.0, 1.0, 0.03)\
		  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var tw_a: Tween = create_tween()
	tw_a.tween_interval(actual_windup)
	tw_a.tween_method(_set_alpha, 0.0, 1.0, 0.02)\
		.set_trans(Tween.TRANS_LINEAR)
	tw_a.tween_interval(0.12)
	tw_a.tween_method(_set_alpha, 1.0, 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_a.tween_callback(queue_free)

func _set_extent(t: float) -> void:
	slash_extent = t
	queue_redraw()

func _set_alpha(t: float) -> void:
	slash_alpha = t
	queue_redraw()

func _draw() -> void:
	if slash_alpha <= 0.0:
		return
	var tail: Vector2 = dir_vec * TAIL_OFFSET
	var tip: Vector2 = dir_vec * (slash_extent * _slash_len)
	_draw_scar(tail, tip, slash_alpha)

func _draw_scar(tail: Vector2, tip: Vector2, alpha: float) -> void:
	var perp: Vector2 = dir_vec.rotated(PI * 0.5)
	var pts_core: PackedVector2Array = PackedVector2Array()
	var pts_glow: PackedVector2Array = PackedVector2Array()
	var colors_core: PackedColorArray = PackedColorArray()
	var colors_glow: PackedColorArray = PackedColorArray()

	for i in range(SCAR_STEPS + 1):
		var t: float = float(i) / float(SCAR_STEPS)
		var p: Vector2 = tail.lerp(tip, t)
		var w: float = 1.0 - t
		var local_alpha: float = lerpf(TAIL_FADE_ALPHA, 1.0, t) * alpha
		var glow_alpha: float = lerpf(TAIL_GLOW_ALPHA, 0.34, t) * alpha
		pts_core.append(p + perp * (w * _max_width))
		pts_glow.append(p + perp * (w * GLOW_WIDTH))
		colors_core.append(Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, local_alpha))
		colors_glow.append(Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, glow_alpha))

	for i in range(SCAR_STEPS, -1, -1):
		var t: float = float(i) / float(SCAR_STEPS)
		var p: Vector2 = tail.lerp(tip, t)
		var w: float = 1.0 - t
		var local_alpha: float = lerpf(TAIL_FADE_ALPHA, 1.0, t) * alpha
		var glow_alpha: float = lerpf(TAIL_GLOW_ALPHA, 0.34, t) * alpha
		pts_core.append(p - perp * (w * _max_width))
		pts_glow.append(p - perp * (w * GLOW_WIDTH))
		colors_core.append(Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, local_alpha))
		colors_glow.append(Color(SLASH_COLOR.r, SLASH_COLOR.g, SLASH_COLOR.b, glow_alpha))

	draw_polygon(pts_glow, colors_glow)
	draw_polygon(pts_core, colors_core)
