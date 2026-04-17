extends Node2D

const CELL_SIZE: float = 100.0

var cell_type: int = CharacterData.CellType.LIVE
var is_player: bool = false
var is_polluted: bool = false
var is_pollution_warning: bool = false
var pollution_dir: int = CharacterData.Direction.NONE
var is_pollution_target_preview: bool = false
var grid_pos: Vector2i = Vector2i.ZERO

func set_type(t: int) -> void:
	cell_type = t
	queue_redraw()

func set_player(v: bool) -> void:
	is_player = v
	queue_redraw()

func set_polluted(v: bool) -> void:
	is_polluted = v
	queue_redraw()

func set_pollution_warning(v: bool) -> void:
	is_pollution_warning = v
	queue_redraw()

func set_pollution_dir(v: int) -> void:
	pollution_dir = v
	queue_redraw()

func set_pollution_target_preview(v: bool) -> void:
	is_pollution_target_preview = v
	queue_redraw()

func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.position.x + rect.size.x
	var bottom: float = rect.position.y + rect.size.y
	var x: float = left
	while x < right:
		var seg_end_x: float = min(x + dash_len, right)
		draw_line(Vector2(x, top), Vector2(seg_end_x, top), color, width, true)
		draw_line(Vector2(x, bottom), Vector2(seg_end_x, bottom), color, width, true)
		x += dash_len + gap_len
	var y: float = top
	while y < bottom:
		var seg_end_y: float = min(y + dash_len, bottom)
		draw_line(Vector2(left, y), Vector2(left, seg_end_y), color, width, true)
		draw_line(Vector2(right, y), Vector2(right, seg_end_y), color, width, true)
		y += dash_len + gap_len

func _draw() -> void:
	var rect: Rect2 = Rect2(0.0, 0.0, CELL_SIZE, CELL_SIZE)
	draw_rect(rect, Color(0.10, 0.10, 0.13))
	if is_polluted:
		draw_rect(rect.grow(-4.0), Color(0.46, 0.22, 0.62, 0.78))
		draw_rect(rect.grow(-10.0), Color(0.22, 0.08, 0.34, 0.58))
	if is_pollution_target_preview:
		_draw_dashed_rect(rect.grow(-8.0), Color(0.95, 0.45, 0.82, 0.85), 2.0, 10.0, 6.0)
	draw_rect(rect, Color(0.25, 0.25, 0.30), false, 1.0)

	var center: Vector2 = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

	if CharacterData.is_enemy(cell_type):
		var r: float = 28.0
		var oct: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0,       -r),
			center + Vector2(r * 0.7,  -r * 0.7),
			center + Vector2(r,         0.0),
			center + Vector2(r * 0.7,   r * 0.7),
			center + Vector2(0.0,       r),
			center + Vector2(-r * 0.7,  r * 0.7),
			center + Vector2(-r,        0.0),
			center + Vector2(-r * 0.7, -r * 0.7),
		])
		var enemy_color: Color = Color(0.76, 0.22, 0.46) if is_pollution_warning else Color(0.8, 0.15, 0.15)
		draw_polygon(oct, PackedColorArray([enemy_color]))
		if pollution_dir != CharacterData.Direction.NONE:
			var dv_f: Vector2 = Vector2(CharacterData.DIR_VECTOR[pollution_dir])
			var arrow_tail: Vector2 = center - dv_f * 12.0
			var arrow_tip: Vector2 = center + dv_f * 12.0
			var arrow_perp: Vector2 = Vector2(-dv_f.y, dv_f.x)
			draw_line(arrow_tail, arrow_tip, Color(1.0, 0.84, 0.92, 0.95), 3.0, true)
			draw_polyline(PackedVector2Array([
				arrow_tip - dv_f * 6.0 - arrow_perp * 6.0,
				arrow_tip,
				arrow_tip - dv_f * 6.0 + arrow_perp * 6.0,
			]), Color(1.0, 0.84, 0.92, 0.95), 3.0, true)
		var shield_dir: int = CharacterData.get_shield_dir(cell_type)
		if shield_dir != CharacterData.Direction.NONE:
			var dv: Vector2i = CharacterData.DIR_VECTOR[shield_dir]
			var dv_f: Vector2 = Vector2(float(dv.x), float(dv.y))
			var perp: Vector2 = Vector2(-dv_f.y, dv_f.x)
			var sc: Vector2 = center + dv_f * (r + 10.0)
			var shield_color: Color = Color(1.0, 0.75, 0.1) if CharacterData.is_hard_shield(cell_type) else Color(0.3, 0.65, 1.0)
			draw_line(sc - perp * 18.0, sc + perp * 18.0, shield_color, 5.0, true)

	if is_player:
		var pr: float = 20.0
		var diamond: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0, -pr),
			center + Vector2(pr,   0.0),
			center + Vector2(0.0,  pr),
			center + Vector2(-pr,  0.0),
		])
		draw_polygon(diamond, PackedColorArray([Color(0.9, 0.9, 0.9)]))
		draw_polyline(PackedVector2Array([
			center + Vector2(0.0, -pr),
			center + Vector2(pr,   0.0),
			center + Vector2(0.0,  pr),
			center + Vector2(-pr,  0.0),
			center + Vector2(0.0, -pr),
		]), Color.WHITE, 2.0)
