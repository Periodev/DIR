extends Node2D

const CELL_SIZE: float = 100.0

var cell_type: int = CharacterData.CellType.LIVE
var is_player: bool = false
var grid_pos: Vector2i = Vector2i.ZERO

func set_type(t: int) -> void:
	cell_type = t
	queue_redraw()

func set_player(v: bool) -> void:
	is_player = v
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(0.0, 0.0, CELL_SIZE, CELL_SIZE)
	draw_rect(rect, Color(0.10, 0.10, 0.13))
	draw_rect(rect, Color(0.25, 0.25, 0.30), false, 1.0)

	var center: Vector2 = Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

	if cell_type == CharacterData.CellType.ENEMY:
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
		draw_polygon(oct, PackedColorArray([Color(0.8, 0.15, 0.15)]))

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
