class_name LevelConstants
extends RefCounted

const LEVELS := [
	{
		"id": 1,
		"title": "L-Strike",
		"object_map": """
.E.
E@E
""",
		"direction_map": "",
		"move_limit": 0,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},

	{
		"id": 2,
		"title": "Align",
		"object_map": """
.E.
E@E
.E.
""",
		"direction_map": "",
		"move_limit": 0,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},

	{
		"id": 3,
		"title": "Reposition",
		"object_map": """
...
.EE
EE@
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},

	{
		"id": 4,
		"title": "Buffer",
		"object_map": """
...
.EE
E.@
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},
    
	{
		"id": 5,
		"title": "Extend",
		"object_map": """
..E
...
E@E
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},
    
	{
		"id": 6,
		"title": "Return",
		"object_map": """
E.. 
@.E 
E..
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},

	{
		"id": 7,
		"title": "Corner",
		"object_map": """
E.. 
E.. 
E@.
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},

	{
		"id": 8,
		"title": "Separate",
		"object_map": """
..E.
.E..
E@..
..E.
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
	},

	{
		"id": 9,
		"title": "Sequence",
		"object_map": """
....
.EE.
.@E.
E..E
""",
		"direction_map": "",
		"move_limit": 3,
		"attack_limit": 3,
		"unlocked_slot_count": 1,
	},


]


static func first_level() -> Dictionary:
	if LEVELS.is_empty():
		return {}
	return LEVELS[0].duplicate(true)
