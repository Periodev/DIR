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
		"circle":
			draw_circle(Vector2.ZERO, 22.0, character_color)
			draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color.WHITE, 2.0)
			return
		"diamond":
			points = PackedVector2Array([
				Vector2(0, -22),
				Vector2(22, 0),
				Vector2(0, 22),
				Vector2(-22, 0),
			])
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

func play_move(from_pos: Vector2) -> void:
	var to_pos := position          # already set by Board
	position = from_pos             # snap back to start
	match character_name:
		"EXE":
			# [1] Anticipation 0.05s — coil: compress scale, hold position
			# [2] Lock         0.02s — freeze before release
			# [3] Dash         0.08s — EASE_IN burst, no deform, heavy object launched
			# [4] Hard stop    0.02s — single minimal settle, nearly no bounce
			var dir := (to_pos - from_pos).normalized()
			var tw := create_tween()
			tw.tween_interval(0.07)
			tw.tween_property(self, "position", to_pos, 0.08)\
			  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_property(self, "position", to_pos + dir * 3.0, 0.01)\
			  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "position", to_pos, 0.01)\
			  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			var tw2 := create_tween()
			tw2.tween_property(self, "scale", Vector2(0.88, 0.85), 0.05)\
			   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw2.tween_interval(0.02)
			tw2.tween_property(self, "scale", Vector2(1.0, 1.0), 0.02)\
			   .set_trans(Tween.TRANS_LINEAR)
		"PLN":
			var tw := create_tween()
			tw.tween_property(self, "position", to_pos, 0.07)\
			  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_:  # COR, GRD, and others
			var tw := create_tween()
			tw.tween_property(self, "position", to_pos, 0.16)\
			  .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func play_attack(dir: int, success: bool) -> void:
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var lunge_dist: float = 30.0 if success else 12.0
	var out_dur: float  = 0.08 if success else 0.05
	var back_dur: float = 0.12 if success else 0.10
	var origin := position
	var tip := position + Vector2(dv) * lunge_dist
	var tw := create_tween()
	tw.tween_property(self, "position", tip, out_dur)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", origin, back_dur)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _make_polygon(sides: int, radius: float, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var angle = start_angle + (TAU / sides) * i
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
