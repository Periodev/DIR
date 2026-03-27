extends Node2D

var character_name: String = "COR"
var character_color: Color = Color(0.2, 0.4, 0.9)
var character_shape: String = "hexagon"

func set_character(char_name: String) -> void:
	character_name = char_name
	var data = CharacterData.CHARACTERS[char_name]
	character_color = data["color"]
	character_shape = data["shape"]
	queue_redraw()

func _draw() -> void:
	var points: PackedVector2Array
	match character_shape:
		"pentagon":
			points = _make_polygon(5, 20.0, -PI / 2.0)
		"hexagon":
			points = _make_polygon(6, 20.0, 0.0)
		"square":
			points = PackedVector2Array([
				Vector2(-20, -20),
				Vector2(20, -20),
				Vector2(20, 20),
				Vector2(-20, 20),
			])
		"blade_diamond":
			points = PackedVector2Array([
				Vector2(0, -25),
				Vector2(10, 0),
				Vector2(0, 25),
				Vector2(-10, 0),
			])
		_:
			points = _make_polygon(6, 20.0, 0.0)

	draw_polygon(points, PackedColorArray([character_color]))
	draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.0)

func _make_polygon(sides: int, radius: float, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var angle = start_angle + (TAU / sides) * i
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
