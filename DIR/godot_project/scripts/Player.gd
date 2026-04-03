extends Node2D

signal animation_done

const CharacterImpl_EXE = preload("res://scripts/CharacterImpl_EXE.gd")
const CharacterImpl_COR = preload("res://scripts/CharacterImpl_COR.gd")
const CharacterImpl_PLN = preload("res://scripts/CharacterImpl_PLN.gd")

var character_name: String = "COR"
var character_color: Color = Color(0.2, 0.4, 0.9)
var character_shape: String = "hexagon"
var facing_dir: int = CharacterData.Direction.UP
var _char_impl  # CharacterImpl_EXE / CharacterImpl_COR / CharacterImpl_PLN

func set_character(char_name: String) -> void:
	character_name = char_name
	var data = CharacterData.CHARACTERS[char_name]
	character_color = data["color"]
	character_shape = data["shape"]
	match char_name:
		"EXE": _char_impl = CharacterImpl_EXE.new()
		"COR": _char_impl = CharacterImpl_COR.new()
		"PLN": _char_impl = CharacterImpl_PLN.new()
	queue_redraw()

func set_facing(dir: int) -> void:
	if dir == CharacterData.Direction.NONE:
		return
	if dir == facing_dir:
		return
	facing_dir = dir
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
			var base := PackedVector2Array([
				Vector2(0, -35),    # 前方尖端
				Vector2(14, 0),     # 右側最寬
				Vector2(0, 14.0 * sqrt(3)),  # 後方 60° 銳角頂點
				Vector2(-14, 0),    # 左側最寬
			])
			var angle := _facing_to_angle(facing_dir)
			points = PackedVector2Array()
			for p in base:
				points.append(p.rotated(angle))
		_:
			points = _make_polygon(6, 20.0, 0.0)

	draw_polygon(points, PackedColorArray([character_color]))
	draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.0)

func play_move(from_pos: Vector2) -> void:
	var to_pos := position          # already set by Board
	position = from_pos             # snap back to start
	_char_impl.play_move(self, from_pos, to_pos)

func play_attack(dir: int, success: bool, is_dash: bool = false) -> void:
	_char_impl.play_attack(self, dir, success, is_dash)
	emit_animation_done_after(get_hit_delay(is_dash))

func emit_animation_done_after(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func(): animation_done.emit(), CONNECT_ONE_SHOT)

func play_pln_charge_glow(dir: int) -> void:
	_char_impl.play_charge_preview(self, dir)

func get_hit_delay(is_dash: bool = false) -> float:
	return _char_impl.get_hit_delay(is_dash)

func _facing_to_angle(dir: int) -> float:
	match dir:
		CharacterData.Direction.UP:    return 0.0
		CharacterData.Direction.DOWN:  return PI
		CharacterData.Direction.LEFT:  return -PI / 2.0
		CharacterData.Direction.RIGHT: return PI / 2.0
		_: return 0.0

func _make_polygon(sides: int, radius: float, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var angle = start_angle + (TAU / sides) * i
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
