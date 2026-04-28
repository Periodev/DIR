class_name VectorInputBuffer
extends RefCounted

const NO_TOKEN: int = -1

enum TokenKind { MOVE, ATTACK }

var pending_move_token: int = NO_TOKEN
var pending_attack_token: int = NO_TOKEN
var tokens: Array = []

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
	tokens.append(pending_move_token)
	return true

func record_attack_kill(board_dir: int) -> bool:
	var dir: int = board_dir_to_core(board_dir)
	if dir < 0:
		return false
	pending_attack_token = token_code(TokenKind.ATTACK, dir)
	tokens.append(pending_attack_token)
	return true

func clear() -> void:
	pending_move_token = NO_TOKEN
	pending_attack_token = NO_TOKEN
	tokens.clear()

func has_pending() -> bool:
	return not tokens.is_empty()

func tokens_in_priority_order() -> Array:
	return tokens.duplicate()

func consume(token: int) -> void:
	tokens.erase(token)
	if token == pending_move_token:
		pending_move_token = _last_token_of_kind(TokenKind.MOVE)
	elif token == pending_attack_token:
		pending_attack_token = _last_token_of_kind(TokenKind.ATTACK)

func consume_many(consumed_tokens: Array) -> void:
	for token: int in consumed_tokens:
		consume(token)

func _last_token_of_kind(kind: int) -> int:
	for i: int in range(tokens.size() - 1, -1, -1):
		var token: int = tokens[i]
		if int(token / 4) == kind:
			return token
	return NO_TOKEN
