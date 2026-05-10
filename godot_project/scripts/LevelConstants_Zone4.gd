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
		"unlocked_slot_count": 1,
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
		"unlocked_slot_count": 1,
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
		"unlocked_slot_count": 1,
		"kill_recovery_enabled": false,
		"allowed_skill_types": ["LMA"],
		# AR MU SRU
	},
]
