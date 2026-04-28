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
	},

	{
		"id": 7,
		"title": "Setup",
		"object_map": """
E.. 
E.. 
E@.
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
	},




]


static func first_level() -> Dictionary:
	if LEVELS.is_empty():
		return {}
	return LEVELS[0].duplicate(true)
