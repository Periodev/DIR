extends Node2D

const CELL_SIZE := 100.0
const DIAMOND_RADIUS := 30.0

var cell_type: int = CharacterData.CellType.LIVE
var shield_dir: int = CharacterData.Direction.NONE
var grid_pos: Vector2i = Vector2i.ZERO
var candidate_phase: int = 0  # 0=none, 1..4=spawn preview gradient, 10=bonus move

func set_type(t: int) -> void:
	cell_type = t
	queue_redraw()

func set_shield_dir(dir: int) -> void:
	shield_dir = dir
	queue_redraw()

func set_candidate(phase: int) -> void:
	candidate_phase = phase
	queue_redraw()

func _draw() -> void:
	# Background
	var bg_color: Color
	match cell_type:
		CharacterData.CellType.LIVE:
			bg_color = Color(0.85, 0.85, 0.85)
		_:
			bg_color = Color(0.85, 0.85, 0.85)

	var rect = Rect2(0, 0, CELL_SIZE, CELL_SIZE)
	draw_rect(rect, bg_color)

	# Candidate border
	if candidate_phase >= 1 and candidate_phase <= 4:
		var preview_colors: Dictionary = {
			1: Color(0.78, 0.88, 0.28),
			2: Color(0.95, 0.85, 0.18),
			3: Color(0.98, 0.63, 0.14),
			4: Color(0.94, 0.30, 0.18),
		}
		draw_rect(rect, preview_colors[candidate_phase], false, 3.0)
	elif candidate_phase == 10:
		draw_rect(rect, Color(0.2, 0.8, 0.9), false, 3.0)
	else:
		draw_rect(rect, Color(0.6, 0.6, 0.6), false, 1.0)

	# Dead indicator - red diamond
	var center = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	if cell_type != CharacterData.CellType.LIVE:
		var r = DIAMOND_RADIUS
		var diamond = PackedVector2Array([
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0),
		])
		draw_polygon(diamond, PackedColorArray([Color(0.8, 0.15, 0.15)]))

		# DEAD_SHIELD: white border rectangle
		if cell_type == CharacterData.CellType.DEAD_SHIELD:
			var sr = r + 6
			var shield_rect = Rect2(center.x - sr, center.y - sr, sr * 2, sr * 2)
			draw_rect(shield_rect, Color.WHITE, false, 2.0)

		# DEAD_DOUBLE: cross mark
		if cell_type == CharacterData.CellType.DEAD_DOUBLE:
			var cr = r * 0.5
			draw_line(center + Vector2(-cr, -cr), center + Vector2(cr, cr), Color.WHITE, 2.0)
			draw_line(center + Vector2(cr, -cr), center + Vector2(-cr, cr), Color.WHITE, 2.0)

		# DEAD_DOUBLE_LIFE: inner white diamond means an extra life, not a shield.
		if cell_type == CharacterData.CellType.DEAD_DOUBLE_LIFE:
			var inner_r = r * 0.45
			var inner_diamond = PackedVector2Array([
				center + Vector2(0, -inner_r),
				center + Vector2(inner_r, 0),
				center + Vector2(0, inner_r),
				center + Vector2(-inner_r, 0),
			])
			draw_polyline(inner_diamond + PackedVector2Array([inner_diamond[0]]), Color.WHITE, 2.0)

		# DEAD_ONE_WAY_SHIELD: white guard line on one side
		if cell_type == CharacterData.CellType.DEAD_ONE_WAY_SHIELD:
			var sr = r + 8.0
			var half = r * 0.7
			match shield_dir:
				CharacterData.Direction.UP:
					draw_line(
						center + Vector2(-half, -sr),
						center + Vector2(half, -sr),
						Color.WHITE,
						5.0
					)
				CharacterData.Direction.DOWN:
					draw_line(
						center + Vector2(-half, sr),
						center + Vector2(half, sr),
						Color.WHITE,
						5.0
					)
				CharacterData.Direction.LEFT:
					draw_line(
						center + Vector2(-sr, -half),
						center + Vector2(-sr, half),
						Color.WHITE,
						5.0
					)
				CharacterData.Direction.RIGHT:
					draw_line(
						center + Vector2(sr, -half),
						center + Vector2(sr, half),
						Color.WHITE,
						5.0
					)

	# Candidate warning text
	if candidate_phase >= 1 and candidate_phase <= 4 and cell_type == CharacterData.CellType.LIVE:
		var preview_dot_colors: Dictionary = {
			1: Color(0.78, 0.88, 0.28),
			2: Color(0.95, 0.85, 0.18),
			3: Color(0.98, 0.63, 0.14),
			4: Color(0.94, 0.30, 0.18),
		}
		draw_circle(center + Vector2(0, -CELL_SIZE * 0.3), 6.0, preview_dot_colors[candidate_phase])
	elif candidate_phase == 10 and cell_type == CharacterData.CellType.LIVE:
		draw_circle(center, 10.0, Color(0.2, 0.8, 0.9))
