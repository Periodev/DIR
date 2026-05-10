class_name LevelConstants
extends RefCounted

const Zone1 = preload("res://scripts/LevelConstants_Zone1.gd")
const Zone2 = preload("res://scripts/LevelConstants_Zone2.gd")
const Zone3 = preload("res://scripts/LevelConstants_Zone3.gd")
const Zone4 = preload("res://scripts/LevelConstants_Zone4.gd")

const DEFAULT_LOAD_ZONE: int = 4


static func first_level() -> Dictionary:
	var levels: Array = all_levels()
	if levels.is_empty():
		return {}
	return levels[0].duplicate(true)


static func first_level_index_for_zone(zone: int) -> int:
	var levels: Array = all_levels()
	for i: int in levels.size():
		var level: Dictionary = levels[i]
		if int(level.get("zone", 1)) == zone:
			return i
	return 0


static func all_levels() -> Array:
	var result: Array = []
	var next_id: int = 1
	for source_levels: Array in [Zone1.LEVELS, Zone2.LEVELS, Zone3.LEVELS, Zone4.LEVELS]:
		for source_level: Dictionary in source_levels:
			var level: Dictionary = source_level.duplicate(true)
			level["id"] = next_id
			result.append(level)
			next_id += 1
	return result
