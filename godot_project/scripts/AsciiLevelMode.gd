class_name AsciiLevelMode
extends "res://scripts/LevelMode.gd"

const CharacterData = preload("res://resources/CharacterData.gd")

var object_map_text: String = ""
var direction_map_text: String = ""
var level_data: Dictionary = {}


func _init(object_map: String = "", direction_map: String = "") -> void:
	object_map_text = object_map
	direction_map_text = direction_map
	level_data = {
		"object_map": object_map,
		"direction_map": direction_map,
	}


func configure(object_map: String, direction_map: String) -> void:
	object_map_text = object_map
	direction_map_text = direction_map
	level_data = {
		"object_map": object_map,
		"direction_map": direction_map,
	}


func configure_level(data: Dictionary) -> void:
	level_data = data.duplicate(true)
	object_map_text = str(level_data.get("object_map", ""))
	direction_map_text = str(level_data.get("direction_map", ""))


func get_dimensions(fallback: Vector2i) -> Vector2i:
	var parsed: Dictionary = _parse_maps()
	if not parsed.get("ok", false):
		return fallback
	return Vector2i(parsed["width"], parsed["height"])


func get_level_id(fallback: int = 0) -> int:
	return int(level_data.get("id", fallback))


func get_level_title(fallback: String = "") -> String:
	return str(level_data.get("title", fallback))


func get_move_limit(fallback: int) -> int:
	return int(level_data.get("move_limit", fallback))


func get_attack_limit(fallback: int) -> int:
	return int(level_data.get("attack_limit", fallback))


func get_unlocked_slot_count(fallback: int) -> int:
	return int(level_data.get("unlocked_slot_count", fallback))


func get_allowed_skill_types(fallback: Array = []) -> Array:
	if level_data.has("allowed_skill_types"):
		return Array(level_data.get("allowed_skill_types", fallback)).duplicate(true)
	return fallback


func allows_kill_recovery() -> bool:
	if level_data.has("kill_recovery_enabled"):
		return bool(level_data.get("kill_recovery_enabled", false))
	return int(level_data.get("zone", 1)) >= 3


func should_auto_spawn_on_end_turn() -> bool:
	return false


func apply_to_board(board: Node) -> bool:
	var parsed: Dictionary = _parse_maps()
	if not parsed.get("ok", false):
		last_error = parsed.get("error", "Unknown ASCII level parse error.")
		return false
	if parsed["width"] > board.COLS or parsed["height"] > board.ROWS:
		last_error = "ASCII level %dx%d exceeds current board limit %dx%d." % [
			parsed["width"], parsed["height"], board.COLS, board.ROWS
		]
		return false

	var object_lines: Array = parsed["object_lines"]
	var direction_lines: Array = parsed["direction_lines"]
	var player_found: bool = false

	for y: int in parsed["height"]:
		for x: int in parsed["width"]:
			var obj_char: String = object_lines[y][x]
			var dir_char: String = direction_lines[y][x]
			var pos: Vector2i = Vector2i(x, y)
			match obj_char:
				"@":
					board.player_pos = pos
					player_found = true
				"E":
					board.grid[y][x] = CharacterData.CellType.ENEMY
					board.enemy_spawn_turn[pos] = board.turn
				"S":
					board.grid[y][x] = CharacterData.shield_enemy_for_dir(_direction_from_char(dir_char))
					board.shield_spawn_turn[pos] = board.turn
					board.enemy_spawn_turn[pos] = board.turn
				"P":
					board.polluted_grid[y][x] = true
				".", " ":
					pass

	if not player_found:
		last_error = "ASCII level did not contain a player start '@'."
		return false

	last_error = ""
	return true


func _parse_maps() -> Dictionary:
	var object_lines: Array = _normalized_lines(object_map_text)
	if object_lines.is_empty():
		return {"ok": false, "error": "Object Map is empty."}
	var direction_lines: Array = _normalized_lines(direction_map_text)
	if direction_lines.is_empty():
		direction_lines = _blank_direction_lines(object_lines)
	if direction_lines.is_empty():
		return {"ok": false, "error": "Direction Map is empty."}
	if object_lines.size() != direction_lines.size():
		return {"ok": false, "error": "Object Map and Direction Map heights do not match."}

	var width: int = object_lines[0].length()
	if width == 0:
		return {"ok": false, "error": "Object Map width must be greater than zero."}

	var player_count: int = 0
	for y: int in object_lines.size():
		var object_line: String = object_lines[y]
		var direction_line: String = direction_lines[y]
		if object_line.length() != width or direction_line.length() != width:
			return {"ok": false, "error": "All map rows must be rectangular and identical in width."}
		for x: int in width:
			var obj_char: String = object_line[x]
			var dir_char: String = direction_line[x]
			match obj_char:
				"@", ".", " ", "E", "P":
					if dir_char != ".":
						return {"ok": false, "error": "Only shield cells may carry direction markers."}
					if obj_char == "@":
						player_count += 1
				"S":
					if _direction_from_char(dir_char) == CharacterData.Direction.NONE:
						return {"ok": false, "error": "Shield enemy at (%d,%d) must define ^ v < or >." % [x, y]}
				_:
					return {"ok": false, "error": "Unsupported map symbol '%s' at (%d,%d)." % [obj_char, x, y]}

	if player_count != 1:
		return {"ok": false, "error": "ASCII level must contain exactly one player start '@'."}

	return {
		"ok": true,
		"width": width,
		"height": object_lines.size(),
		"object_lines": object_lines,
		"direction_lines": direction_lines,
	}


func _normalized_lines(text: String) -> Array:
	var stripped: String = text.strip_edges()
	if stripped.is_empty():
		return []
	var raw_lines: PackedStringArray = stripped.split("\n", false)
	var lines: Array = []
	for raw_line: String in raw_lines:
		lines.append(raw_line.strip_edges())
	return lines


func _blank_direction_lines(object_lines: Array) -> Array:
	var lines: Array = []
	for object_line: String in object_lines:
		lines.append(".".repeat(object_line.length()))
	return lines


func _direction_from_char(dir_char: String) -> int:
	match dir_char:
		"^":
			return CharacterData.Direction.UP
		"v":
			return CharacterData.Direction.DOWN
		"<":
			return CharacterData.Direction.LEFT
		">":
			return CharacterData.Direction.RIGHT
		_:
			return CharacterData.Direction.NONE
