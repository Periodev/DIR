extends Node2D

const CELL_SIZE: float = 100.0
const DIAMOND_RADIUS: float = 30.0

var cell_type: int = CharacterData.CellType.LIVE
var grid_pos: Vector2i = Vector2i.ZERO
var candidate_phase: int = 0  # 0=none, 1..4=spawn-preview, 10=highlight

func set_type(t: int) -> void:
	cell_type = t
	queue_redraw()

func set_candidate(phase: int) -> void:
	candidate_phase = phase
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(0.0, 0.0, CELL_SIZE, CELL_SIZE)
	draw_rect(rect, Color(0.10, 0.10, 0.13))

	# Border colour based on candidate phase
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
		draw_rect(rect, Color(0.25, 0.25, 0.30), false, 1.0)

	# Dead cell: red octagon
	var center: Vector2 = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	if cell_type == CharacterData.CellType.DEAD:
		var r: float = DIAMOND_RADIUS
		var octagon: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0,  -r),
			center + Vector2(r * 0.7,  -r * 0.7),
			center + Vector2(r,   0.0),
			center + Vector2(r * 0.7,   r * 0.7),
			center + Vector2(0.0,   r),
			center + Vector2(-r * 0.7,  r * 0.7),
			center + Vector2(-r,  0.0),
			center + Vector2(-r * 0.7, -r * 0.7),
		])
		draw_polygon(octagon, PackedColorArray([Color(0.8, 0.15, 0.15)]))

	# Candidate dot (live cells only)
	if candidate_phase >= 1 and candidate_phase <= 4 and cell_type == CharacterData.CellType.LIVE:
		var preview_dot_colors: Dictionary = {
			1: Color(0.78, 0.88, 0.28),
			2: Color(0.95, 0.85, 0.18),
			3: Color(0.98, 0.63, 0.14),
			4: Color(0.94, 0.30, 0.18),
		}
		draw_circle(center + Vector2(0.0, -CELL_SIZE * 0.3), 6.0, preview_dot_colors[candidate_phase])
	elif candidate_phase == 10 and cell_type == CharacterData.CellType.LIVE:
		draw_circle(center, 10.0, Color(0.2, 0.8, 0.9))
