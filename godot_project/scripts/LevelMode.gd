class_name LevelMode
extends RefCounted

var last_error: String = ""


func get_dimensions(fallback: Vector2i) -> Vector2i:
	return fallback


func get_level_id(fallback: int = 0) -> int:
	return fallback


func get_level_title(fallback: String = "") -> String:
	return fallback


func get_move_limit(fallback: int) -> int:
	return fallback


func get_attack_limit(fallback: int) -> int:
	return fallback


func get_unlocked_slot_count(fallback: int) -> int:
	return fallback


func should_auto_spawn_on_end_turn() -> bool:
	return true


func apply_to_board(_board: Node) -> bool:
	last_error = ""
	return true


func get_last_error() -> String:
	return last_error
