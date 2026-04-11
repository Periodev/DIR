class_name CharacterData

enum Direction { NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4 }
enum CellType { LIVE, ENEMY }

class Config:
	var seq_slots: int = 3
	var max_moves: int = 3
	var max_attacks: int = 3

const DIR_VECTOR: Dictionary = {
	Direction.UP:    Vector2i(0, -1),
	Direction.DOWN:  Vector2i(0, 1),
	Direction.LEFT:  Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
}

const DIR_ARROWS: Dictionary = {
	Direction.NONE:  "·",
	Direction.UP:    "^",
	Direction.DOWN:  "v",
	Direction.LEFT:  "<",
	Direction.RIGHT: ">",
}

static func key_to_direction(keycode: Key) -> Direction:
	match keycode:
		KEY_UP, KEY_W:    return Direction.UP
		KEY_DOWN, KEY_S:  return Direction.DOWN
		KEY_LEFT, KEY_A:  return Direction.LEFT
		KEY_RIGHT, KEY_D: return Direction.RIGHT
		_: return Direction.NONE
