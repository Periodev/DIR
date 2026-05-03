class_name LevelConstantsZone3
extends RefCounted

const LEVELS := [
	{
		"zone": 3,
		"index": 1,
		"code": "3-1",
		"title": "Jump",
		"object_map": """
...E
....
E...
@E..
""",
		"direction_map": "",
		"move_limit": 2,
		"attack_limit": 2,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		#AAMSRMSR
	},

	{
		"zone": 3,
		"index": 2,
		"code": "3-2",
		"title": "Cut in",
		"object_map": """
@EE
.E.
EE.
.E.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		#AMSAASRR
	},

	{
		"zone": 3,
		"index": 3,
		"code": "3-3",
		"title": "Crowded",
		"object_map": """
EE.
EEE
@E.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		#AASMASRR, AAMSASRR
	},


	{
		"zone": 3,
		"index": 4,
		"code": "3-4",
		"title": "Hold",
		"object_map": """
E.E
EE@
..E
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		#AASAMSRR
	},


	{
		"zone": 3,
		"index": 5,
		"code": "3-5",
		"title": "Brake",
		"object_map": """
.E.
@E.
.EE
.E.
""",
		"direction_map": "",
		"move_limit": 1,
		"attack_limit": 3,
		"unlocked_slot_count": 2,
		"kill_recovery_enabled": false,
		#AMSARASR
	},



]

