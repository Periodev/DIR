class_name CharacterData

enum Direction { NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4 }
enum CellType { LIVE, ENEMY, ENEMY_SHIELD_UP, ENEMY_SHIELD_DOWN, ENEMY_SHIELD_LEFT, ENEMY_SHIELD_RIGHT }

static func is_enemy(cell: int) -> bool:
	return cell != CellType.LIVE

static func get_shield_dir(cell: int) -> Direction:
	match cell:
		CellType.ENEMY_SHIELD_UP:    return Direction.UP
		CellType.ENEMY_SHIELD_DOWN:  return Direction.DOWN
		CellType.ENEMY_SHIELD_LEFT:  return Direction.LEFT
		CellType.ENEMY_SHIELD_RIGHT: return Direction.RIGHT
		_: return Direction.NONE

static func shield_enemy_for_dir(d: Direction) -> CellType:
	match d:
		Direction.UP:    return CellType.ENEMY_SHIELD_UP
		Direction.DOWN:  return CellType.ENEMY_SHIELD_DOWN
		Direction.LEFT:  return CellType.ENEMY_SHIELD_LEFT
		Direction.RIGHT: return CellType.ENEMY_SHIELD_RIGHT
		_: return CellType.ENEMY

static func dominant_cardinal(diff: Vector2i) -> Direction:
	if diff == Vector2i.ZERO:
		return Direction.NONE
	if abs(diff.x) >= abs(diff.y):
		return Direction.RIGHT if diff.x > 0 else Direction.LEFT
	else:
		return Direction.DOWN if diff.y > 0 else Direction.UP

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

enum SkillType { NONE, SAME_MA, LEFT_MA, RIGHT_MA, SAME_AA, ORTHO_AA }

const SKILL_TYPE_NAMES: Dictionary = {
	SkillType.NONE:     "",
	SkillType.SAME_MA:  "同向MA",
	SkillType.LEFT_MA:  "左勾",
	SkillType.RIGHT_MA: "右勾",
	SkillType.SAME_AA:  "同向AA",
	SkillType.ORTHO_AA: "正交AA",
}

static func classify_skill(slot_data: Array) -> SkillType:
	if slot_data.is_empty():
		return SkillType.NONE
	var dir_seq: int = slot_data[0]
	var dir_atk: int = slot_data[1]
	var is_seq_atk: bool = slot_data[2]
	var dv_seq: Vector2i = DIR_VECTOR[dir_seq]
	var dv_atk: Vector2i = DIR_VECTOR[dir_atk]
	if not is_seq_atk:
		if dir_seq == dir_atk:
			return SkillType.SAME_MA
		var cross: int = dv_seq.x * dv_atk.y - dv_seq.y * dv_atk.x
		return SkillType.LEFT_MA if cross < 0 else SkillType.RIGHT_MA
	else:
		if dir_seq == dir_atk:
			return SkillType.SAME_AA
		return SkillType.ORTHO_AA
