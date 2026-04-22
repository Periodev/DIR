class_name VectorInputBuffer
extends RefCounted

const NO_TOKEN: int = -1

enum TokenKind { MOVE, ATTACK }

var pending_move_token: int = NO_TOKEN
var pending_attack_token: int = NO_TOKEN

static func token_code(kind: int, dir: int) -> int:
	return kind * 4 + dir

static func board_dir_to_core(dir: int) -> int:
	match dir:
		CharacterData.Direction.UP:
			return 0
		CharacterData.Direction.RIGHT:
			return 1
		CharacterData.Direction.DOWN:
			return 2
		CharacterData.Direction.LEFT:
			return 3
		_:
			return -1

func record_move(board_dir: int) -> bool:
	var dir: int = board_dir_to_core(board_dir)
	if dir < 0:
		return false
	pending_move_token = token_code(TokenKind.MOVE, dir)
	return true

func record_attack_kill(board_dir: int) -> bool:
	var dir: int = board_dir_to_core(board_dir)
	if dir < 0:
		return false
	pending_attack_token = token_code(TokenKind.ATTACK, dir)
	return true

func clear() -> void:
	pending_move_token = NO_TOKEN
	pending_attack_token = NO_TOKEN

func has_pending() -> bool:
	return pending_move_token != NO_TOKEN or pending_attack_token != NO_TOKEN

func tokens_in_priority_order() -> Array:
	var result: Array = []
	if pending_move_token != NO_TOKEN:
		result.append(pending_move_token)
	if pending_attack_token != NO_TOKEN:
		result.append(pending_attack_token)
	return result

func consume(token: int) -> void:
	if token == pending_move_token:
		pending_move_token = NO_TOKEN
	elif token == pending_attack_token:
		pending_attack_token = NO_TOKEN
