class_name LevelConstantsZone1
extends RefCounted

const LEVELS := [
	{
		"zone": 1,
		"index": 1,
		"code": "1-1",
		"title": "L-Strike",
		"object_map": """
.E.
E@E
""",
		"direction_map": "",
		"move_limit": 0,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
		"allowed_skill_types": ["LAA"],
		#AASR
	},

	{
		"zone": 1,
		"index": 2,
		"code": "1-2",
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
		"allowed_skill_types": ["LAA"],
		#AASR
	},

	{
		"zone": 1,
		"index": 3,
		"code": "1-3",
		"title": "Reposition",
		"object_map": """
.EE
EE@
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
		"allowed_skill_types": ["LAA"],
		#AASMR
	},

	{
		"zone": 1,
		"index": 4,
		"code": "1-4",
		"title": "Buffer",
		"object_map": """
.EE
E.@
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 1,
		"allowed_skill_types": ["LAA"],
		#AMASR
	},

	{
		"zone": 1,
		"index": 5,
		"code": "1-5",
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
		"allowed_skill_types": ["LAA"],
		#AMMASR
	},

	{
		"zone": 1,
		"index": 6,
		"code": "1-6",
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
		"allowed_skill_types": ["LAA"],
		#AMAMSR, MAMASR
	},

	{
		"zone": 1,
		"index": 7,
		"code": "1-7",
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
		"allowed_skill_types": ["LAA"],
		#AMASMR
	},

	{
		"zone": 1,
		"index": 8,
		"code": "1-8",
		"title": "Pair",
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
		"allowed_skill_types": ["LAA"],
		#AMASMR
	},

	{
		"zone": 1,
		"index": 9,
		"code": "1-9",
		"title": "Sequence",
		"object_map": """
.E..
.@E.
E.EE
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 1,
		"allowed_skill_types": ["LAA"],
		#AMASAMR
	},
]
