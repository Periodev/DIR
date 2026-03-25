class_name CharacterData

enum Direction { NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4 }

enum CellType { LIVE, DEAD, DEAD_SHIELD, DEAD_DOUBLE }

enum AttackMode { RAM, STRIKE }

enum GameStateEnum { IDLE, GENERATING, BONUS_MOVE_SELECT, GAME_OVER }

const DIR_VECTOR := {
	Direction.UP:    Vector2i( 0, -1),
	Direction.DOWN:  Vector2i( 0,  1),
	Direction.LEFT:  Vector2i(-1,  0),
	Direction.RIGHT: Vector2i( 1,  0),
}

const OPPOSITE := {
	Direction.UP:    Direction.DOWN,
	Direction.DOWN:  Direction.UP,
	Direction.LEFT:  Direction.RIGHT,
	Direction.RIGHT: Direction.LEFT,
}

const DIR_ARROWS := {
	Direction.NONE:  "",
	Direction.UP:    "↑",
	Direction.DOWN:  "↓",
	Direction.LEFT:  "←",
	Direction.RIGHT: "→",
}

const CHARACTERS := {
	"EXE": {
		"seq":       2,
		"has_hold":  false,
		"has_charge_marker": false,
		"charge_max": 0,
		"has_ult":   false,
		"attack_mode": AttackMode.RAM,
		"has_pierce": true,
		"has_penetrating_attack": false,
		"has_post_kill_reposition": false,
		"color":     Color(0.9, 0.2, 0.2),
		"shape":     "pentagon",
	},
	"COR": {
		"seq":       3,
		"has_hold":  false,
		"has_charge_marker": true,
		"charge_max": 5,
		"has_ult":   false,
		"attack_mode": AttackMode.RAM,
		"has_pierce": false,
		"has_penetrating_attack": false,
		"has_post_kill_reposition": false,
		"color":     Color(0.2, 0.4, 0.9),
		"shape":     "hexagon",
	},
	"PLN": {
		"seq":       4,
		"has_hold":  false,
		"has_charge_marker": false,
		"charge_max": 0,
		"has_ult":   true,
		"attack_mode": AttackMode.RAM,
		"has_pierce": false,
		"has_penetrating_attack": false,
		"has_post_kill_reposition": true,
		"color":     Color(0.2, 0.8, 0.3),
		"shape":     "blade_diamond",
	},
}

const ENABLE_VARIANTS := false

static func key_to_direction(keycode: Key) -> Direction:
	match keycode:
		KEY_UP, KEY_W:
			return Direction.UP
		KEY_DOWN, KEY_S:
			return Direction.DOWN
		KEY_LEFT, KEY_A:
			return Direction.LEFT
		KEY_RIGHT, KEY_D:
			return Direction.RIGHT
		_:
			return Direction.NONE
