extends Node2D

signal animation_done

const CharacterImpl_EXE = preload("res://scripts/CharacterImpl_EXE.gd")
const CharacterImpl_RDR = preload("res://scripts/CharacterImpl_RDR.gd")
const CharacterImpl_PLN = preload("res://scripts/CharacterImpl_PLN.gd")

var character_name: String = "EXE"
var character_color: Color = Color(0.95, 0.40, 0.05)
var character_shape: String = "diamond"
var facing_dir: int = CharacterData.Direction.UP
var _char_impl: RefCounted = null

func set_character(char_name: String) -> void:
	character_name = char_name
	var data: Dictionary = CharacterData.CHARACTERS[char_name]
	character_color = data["color"]
	character_shape = data["shape"]
	match char_name:
		"EXE": _char_impl = CharacterImpl_EXE.new()
		"RDR": _char_impl = CharacterImpl_RDR.new()
		"PLN": _char_impl = CharacterImpl_PLN.new()
	queue_redraw()

func set_facing(dir: int) -> void:
	if dir == CharacterData.Direction.NONE or dir == facing_dir:
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
				Vector2(0, -22), Vector2(22, 0),
				Vector2(0, 22),  Vector2(-22, 0),
			])
		"pentagon":
			points = _make_polygon(5, 20.0, -PI / 2.0)
		"hexagon":
			points = _make_polygon(6, 20.0, 0.0)
		"square":
			points = PackedVector2Array([
				Vector2(-20, -20), Vector2(20, -20),
				Vector2(20, 20),   Vector2(-20, 20),
			])
		"blade_diamond":
			var base: PackedVector2Array = PackedVector2Array([
				Vector2(0, -35),
				Vector2(14, 0),
				Vector2(0, 14.0 * sqrt(3)),
				Vector2(-14, 0),
			])
			var angle: float = _facing_to_angle(facing_dir)
			points = PackedVector2Array()
			for p: Vector2 in base:
				points.append(p.rotated(angle))
		_:
			points = _make_polygon(6, 20.0, 0.0)

	draw_polygon(points, PackedColorArray([character_color]))
	draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.0)

func play_move(from_pos: Vector2) -> void:
	var to_pos: Vector2 = position
	position = from_pos
	_char_impl.play_move(self, from_pos, to_pos)

func play_attack(dir: int, success: bool, is_dash: bool = false) -> void:
	_char_impl.play_attack(self, dir, success, is_dash)
	emit_animation_done_after(get_hit_delay(is_dash))

func emit_animation_done_after(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func() -> void: animation_done.emit(), CONNECT_ONE_SHOT)

func get_hit_delay(is_dash: bool = false) -> float:
	return _char_impl.get_hit_delay(is_dash)

func play_charge_preview(dir: int) -> void:
	_char_impl.play_charge_preview(self, dir)

func _facing_to_angle(dir: int) -> float:
	match dir:
		CharacterData.Direction.UP:    return 0.0
		CharacterData.Direction.DOWN:  return PI
		CharacterData.Direction.LEFT:  return -PI / 2.0
		CharacterData.Direction.RIGHT: return PI / 2.0
		_: return 0.0

func _make_polygon(sides: int, radius: float, start_angle: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in sides:
		var angle: float = start_angle + (TAU / sides) * i
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
