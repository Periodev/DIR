class_name CharacterData

enum Direction { NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4 }
enum CellType { LIVE, DEAD }
enum GameStateEnum { IDLE, PRESENTING, RECORDING, GAME_OVER }

const DIR_VECTOR: Dictionary = {
	Direction.UP:    Vector2i(0, -1),
	Direction.DOWN:  Vector2i(0, 1),
	Direction.LEFT:  Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
}

const OPPOSITE: Dictionary = {
	Direction.UP:    Direction.DOWN,
	Direction.DOWN:  Direction.UP,
	Direction.LEFT:  Direction.RIGHT,
	Direction.RIGHT: Direction.LEFT,
}

const DIR_ARROWS: Dictionary = {
	Direction.NONE:  "-",
	Direction.UP:    "^",
	Direction.DOWN:  "v",
	Direction.LEFT:  "<",
	Direction.RIGHT: ">",
}

# vector_slots: Array of {capacity: int, label: String}
# capacity 1 = basic slot, capacity 2 = strong slot
const CHARACTERS: Dictionary = {
	"EXE": {
		"color":     Color(0.95, 0.40, 0.05),
		"shape":     "diamond",
		"hand_size": 4,
		"vector_slots": [
			{"capacity": 1, "label": "STRIKE"},
			{"capacity": 2, "label": "SKILL"},
		],
	},
	"RDR": {
		"color":     Color(0.2, 0.8, 0.3),
		"shape":     "blade_diamond",
		"hand_size": 4,
		"vector_slots": [
			{"capacity": 1, "label": "MOVE"},
			{"capacity": 2, "label": "SHIFT"},
		],
	},
	"PLN": {
		"color":     Color(0.5, 0.3, 0.9),
		"shape":     "pentagon",
		"hand_size": 4,
		"vector_slots": [
			{"capacity": 1, "label": "TRAP"},
			{"capacity": 2, "label": "COMBO"},
		],
	},
}

static func key_to_direction(keycode: Key) -> Direction:
	match keycode:
		KEY_UP, KEY_W:    return Direction.UP
		KEY_DOWN, KEY_S:  return Direction.DOWN
		KEY_LEFT, KEY_A:  return Direction.LEFT
		KEY_RIGHT, KEY_D: return Direction.RIGHT
		_: return Direction.NONE

# Returns true if dir_a and dir_b are perpendicular (one horiz, one vert)
static func are_orthogonal(dir_a: int, dir_b: int) -> bool:
	if dir_a == Direction.NONE or dir_b == Direction.NONE:
		return false
	var a_vert: bool = (dir_a == Direction.UP or dir_a == Direction.DOWN)
	var b_vert: bool = (dir_b == Direction.UP or dir_b == Direction.DOWN)
	return a_vert != b_vert
