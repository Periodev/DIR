class_name VectorSynthesisState
extends RefCounted

const NO_TOKEN: int = -1

enum Dir { UP, RIGHT, DOWN, LEFT }
enum TokenKind { MOVE, ATTACK }
enum SlotStatus { EMPTY, PARTIAL, COMPLETE }

var slots: Array = []
var selected_slot: int = -1
var pending_move_token: int = NO_TOKEN
var pending_attack_token: int = NO_TOKEN


func reset(slot_count: int) -> void:
	slots.clear()
	for _i: int in slot_count:
		slots.append([])
	selected_slot = -1
	clear_pending()


static func board_dir_to_core(dir: int) -> int:
	match dir:
		CharacterData.Direction.UP:
			return Dir.UP
		CharacterData.Direction.RIGHT:
			return Dir.RIGHT
		CharacterData.Direction.DOWN:
			return Dir.DOWN
		CharacterData.Direction.LEFT:
			return Dir.LEFT
		_:
			return -1


static func core_dir_to_board(dir: int) -> int:
	match dir:
		Dir.UP:
			return CharacterData.Direction.UP
		Dir.RIGHT:
			return CharacterData.Direction.RIGHT
		Dir.DOWN:
			return CharacterData.Direction.DOWN
		Dir.LEFT:
			return CharacterData.Direction.LEFT
		_:
			return CharacterData.Direction.NONE


static func token_code(kind: int, dir: int) -> int:
	return kind * 4 + dir


static func token_kind(token: int) -> int:
	return int(token / 4)


static func token_dir(token: int) -> int:
	return token % 4


static func token_board_dir(token: int) -> int:
	return core_dir_to_board(token_dir(token))


static func token_is_attack(token: int) -> bool:
	return token_kind(token) == TokenKind.ATTACK


static func opposite_dir(dir: int) -> int:
	return (dir + 2) % 4


static func tokens_are_opposite(a: int, b: int) -> bool:
	return token_dir(a) == opposite_dir(token_dir(b))


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


func clear_pending() -> void:
	pending_move_token = NO_TOKEN
	pending_attack_token = NO_TOKEN


func has_pending() -> bool:
	return pending_move_token != NO_TOKEN or pending_attack_token != NO_TOKEN


func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		selected_slot = -1
	else:
		selected_slot = index


func slot_status(index: int) -> int:
	if index < 0 or index >= slots.size():
		return SlotStatus.EMPTY
	var slot_data: Array = slots[index]
	if slot_data.is_empty():
		return SlotStatus.EMPTY
	if slot_data.size() == 1:
		return SlotStatus.PARTIAL
	return SlotStatus.COMPLETE


func can_store_in_slot(index: int, token: int = NO_TOKEN) -> bool:
	var candidate: int = get_pending_token_for_slot(index) if token == NO_TOKEN else token
	if candidate == NO_TOKEN or index < 0 or index >= slots.size():
		return false
	var slot_data: Array = slots[index]
	if slot_data.is_empty():
		return true
	if slot_data.size() != 1:
		return false
	return can_compose(slot_data[0], candidate)


func press_space() -> bool:
	if not has_pending():
		return false
	var slot_index: int = selected_slot
	var token: int = NO_TOKEN
	if slot_index >= 0:
		token = get_pending_token_for_slot(slot_index)
		if token == NO_TOKEN or not can_store_in_slot(slot_index, token):
			return false
	else:
		slot_index = _find_default_store_slot()
		if slot_index < 0:
			return false
		token = get_pending_token_for_slot(slot_index)
		if token == NO_TOKEN:
			return false
	var slot_data: Array = slots[slot_index]
	if slot_data.is_empty():
		slots[slot_index] = [token]
	else:
		slots[slot_index] = [slot_data[0], token]
	_consume_pending_token(token)
	return true


func auto_store_pending() -> bool:
	var candidates: Array = []
	if pending_move_token != NO_TOKEN:
		candidates.append(pending_move_token)
	if pending_attack_token != NO_TOKEN:
		candidates.append(pending_attack_token)
	if candidates.is_empty():
		return true

	var preferred_result: Dictionary = _try_store_token_order(candidates)
	if bool(preferred_result.get("ok", false)):
		_apply_auto_store_result(preferred_result)
		return true

	if candidates.size() == 2:
		var reversed: Array = [candidates[1], candidates[0]]
		var reversed_result: Dictionary = _try_store_token_order(reversed)
		if bool(reversed_result.get("ok", false)):
			_apply_auto_store_result(reversed_result)
			return true
	return false


func can_cast_selected() -> bool:
	return slot_status(selected_slot) == SlotStatus.COMPLETE


func consume_selected_skill() -> Array:
	if not can_cast_selected():
		return []
	var slot_data: Array = slots[selected_slot].duplicate()
	slots[selected_slot] = []
	return slot_data


func clear_slot(index: int) -> void:
	if index >= 0 and index < slots.size():
		slots[index] = []


func replace_complete_slot(index: int, first_board_dir: int, second_board_dir: int, first_is_attack: bool) -> bool:
	if index < 0 or index >= slots.size():
		return false
	var first_core_dir: int = board_dir_to_core(first_board_dir)
	var second_core_dir: int = board_dir_to_core(second_board_dir)
	if first_core_dir < 0 or second_core_dir < 0:
		return false
	var first_kind: int = TokenKind.ATTACK if first_is_attack else TokenKind.MOVE
	var first_token: int = token_code(first_kind, first_core_dir)
	var second_token: int = token_code(TokenKind.ATTACK, second_core_dir)
	if not can_compose(first_token, second_token):
		return false
	slots[index] = [first_token, second_token]
	return true


func legacy_slot(index: int) -> Array:
	if index < 0 or index >= slots.size():
		return []
	return tokens_to_legacy(slots[index])


func legacy_slots() -> Array:
	var result: Array = []
	for i: int in slots.size():
		result.append(legacy_slot(i))
	return result


func get_view_model() -> Dictionary:
	var slot_copy: Array = []
	for slot_data: Array in slots:
		slot_copy.append(slot_data.duplicate())
	return {
		"slots": slot_copy,
		"selected_slot": selected_slot,
		"pending_move_token": pending_move_token,
		"pending_attack_token": pending_attack_token,
	}


static func can_compose(first_token: int, second_token: int) -> bool:
	if first_token == NO_TOKEN or second_token == NO_TOKEN:
		return false
	if tokens_are_opposite(first_token, second_token):
		return false
	var first_kind: int = token_kind(first_token)
	var second_kind: int = token_kind(second_token)
	return (first_kind == TokenKind.MOVE and second_kind == TokenKind.ATTACK) \
		or (first_kind == TokenKind.ATTACK and second_kind == TokenKind.ATTACK)


static func classify_tokens(tokens: Array) -> int:
	if tokens.size() != 2 or not can_compose(tokens[0], tokens[1]):
		return CharacterData.SkillType.NONE
	var d0: int = token_board_dir(tokens[0])
	var d1: int = token_board_dir(tokens[1])
	var first_is_attack: bool = token_is_attack(tokens[0])
	return CharacterData.classify_skill([d0, d1, first_is_attack])


static func tokens_to_legacy(tokens: Array) -> Array:
	if tokens.size() == 0:
		return []
	if tokens.size() == 1:
		return [token_board_dir(tokens[0])]
	return [
		token_board_dir(tokens[0]),
		token_board_dir(tokens[1]),
		token_is_attack(tokens[0]),
	]


func _find_default_store_slot() -> int:
	for i: int in slots.size():
		if slots[i].size() == 1 and can_store_in_slot(i):
			return i
	for i: int in slots.size():
		if slots[i].is_empty():
			return i
	return -1


func _try_store_token_order(tokens: Array) -> Dictionary:
	var work_slots: Array = []
	for slot_data: Array in slots:
		work_slots.append(slot_data.duplicate())
	for token: int in tokens:
		if not _store_token_default(work_slots, token):
			return {"ok": false}
	return {"ok": true, "slots": work_slots}


func _store_token_default(target_slots: Array, token: int) -> bool:
	for i: int in target_slots.size():
		var slot_data: Array = target_slots[i]
		if slot_data.size() == 1 and can_compose(slot_data[0], token):
			target_slots[i] = [slot_data[0], token]
			return true
	for i: int in target_slots.size():
		if target_slots[i].is_empty():
			target_slots[i] = [token]
			return true
	return false


func _apply_auto_store_result(result: Dictionary) -> void:
	slots = result.get("slots", slots)
	clear_pending()


func get_pending_token_for_slot(index: int) -> int:
	if index < 0 or index >= slots.size():
		return NO_TOKEN
	var slot_data: Array = slots[index]
	if slot_data.size() == 1:
		if pending_attack_token != NO_TOKEN and can_compose(slot_data[0], pending_attack_token):
			return pending_attack_token
		if pending_move_token != NO_TOKEN and can_compose(slot_data[0], pending_move_token):
			return pending_move_token
		return NO_TOKEN
	if slot_data.is_empty():
		if pending_move_token != NO_TOKEN:
			return pending_move_token
		return pending_attack_token
	return NO_TOKEN


func _consume_pending_token(token: int) -> void:
	if token == pending_move_token:
		pending_move_token = NO_TOKEN
	elif token == pending_attack_token:
		pending_attack_token = NO_TOKEN
