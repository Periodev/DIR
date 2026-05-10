class_name LevelConstantsZone5
extends RefCounted

# Zone 5 mixed-skill boards.
# Front-load the lower-pressure 3M / 3A candidates, then ramp 2M / 3A by
# difficulty. Do not require one route to cast LAA, IMA, and LMA together
# because that forces 2M / 4A.

const LEVELS := [
	{
		"zone": 5,
		"index": 1,
		"code": "5-1",
		"title": "Mixed",
		"object_map": """
E...
..EE
E...
..@E
""",
		"direction_map": "",
		"move_limit": 3,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 2,
		"code": "5-2",
		"title": "Topdown",
		"object_map": """
E..@
.EE.
....
.EE.
""",
		"direction_map": "",
		"move_limit": 3,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 3,
		"code": "5-3",
		"title": "Ring",
		"object_map": """
.EE@
E...
E...
...E
""",
		"direction_map": "",
		"move_limit": 3,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 4,
		"code": "5-4",
		"title": "Junction",
		"object_map": """
@E.
.E.
..E
EE.
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 5,
		"code": "5-5",
		"title": "Stair",
		"object_map": """
E.E.
.EE.
..E@
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 6,
		"code": "5-6",
		"title": "Line Up",
		"object_map": """
E...
.E.E
@.E.
...E
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 7,
		"code": "5-7",
		"title": "Ridge",
		"object_map": """
.E.
..E
E.E
@.E
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 8,
		"code": "5-8",
		"title": "Bottom Up",
		"object_map": """
.EE.
....
E...
.EE@
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},

	{
		"zone": 5,
		"index": 9,
		"code": "5-9",
		"title": "Loaded",
		"object_map": """
.EE
E.E
@..
EE.
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
	},
]
