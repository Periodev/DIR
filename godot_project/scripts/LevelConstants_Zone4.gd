class_name LevelConstantsZone4
extends RefCounted

# Zone 4 levels.
# Purpose:
# - Reset local complexity after the Zone 3 two-slot peak.
# - Introduce `LMA` as the new focus skill.
# - Current working name for `LMA`: `Sidestep Strike`.

const LEVELS := [
	{
		"zone": 4,
		"index": 1,
		"code": "4-1",
		"title": "Sidestep Strike",
		"object_map": """
E..
E..
.@.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 1,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# MU AL SRU
	},

	{
		"zone": 4,
		"index": 2,
		"code": "4-2",
		"title": "Turn Pursuit",
		"object_map": """
..E
E..
.@.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 1,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# MU AL SRR
	},

	{
		"zone": 4,
		"index": 3,
		"code": "4-3",
		"title": "Corner Pursuit",
		"object_map": """
E..
...
.@E
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 1,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# AR MU SRU
	},

	{
		"zone": 4,
		"index": 4,
		"code": "4-4",
		"title": "Clear",
		"object_map": """
..E
.E.
E@.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# AL AU MU SRR
	},

	{
		"zone": 4,
		"index": 5,
		"code": "4-5",
		"title": "Return",
		"object_map": """
..E
.@.
E..
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 1,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# MU AR MD SRD
	},

	{
		"zone": 4,
		"index": 6,
		"code": "4-6",
		"title": "Landing",
		"object_map": """
.E.
...
E..
.@.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# MU AL SRU AU
	},

	{
		"zone": 4,
		"index": 7,
		"code": "4-7",
		"title": "Arc",
		"object_map": """
.E.
..@
E..
.E.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# ML AU SRD AD
	},

	{
		"zone": 4,
		"index": 8,
		"code": "4-8",
		"title": "Spiral",
		"object_map": """
.E..
...E
E.@.
..E.
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# MU AR ML AU SRD SRR
	},

	{
		"zone": 4,
		"index": 9,
		"code": "4-9",
		"title": "Zig",
		"object_map": """
EE.
EE.
..@
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
		# MU AL ML AU SRR SRD
	},

	{
		"zone": 4,
		"index": 10,
		"code": "4-10",
		"title": "Miss",
		"object_map": """
..EE
....
E...
.@..
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LAA", "IMA", "LMA"],
		# MU AL SRR MR AU SRR
	},
]
