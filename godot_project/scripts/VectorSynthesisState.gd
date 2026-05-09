class_name VectorSynthesisState
extends RefCounted

const NO_TOKEN: int = -1
const _INPUT_BUFFER_SCRIPT = preload("res://scripts/VectorInputBuffer.gd")

enum Dir { UP, RIGHT, DOWN, LEFT }
enum TokenKind { MOVE, ATTACK }
enum SlotStatus { EMPTY, PARTIAL, COMPLETE }

var slots: Array = []
var selected_slot: int = -1
var input_buffer: RefCounted = _INPUT_BUFFER_SCRIPT.new()
var allowed_skill_types: Dictionary = {}
var last_failure_reason: String = ""


func reset(slot_count: int) -> void:
	slots.clear()
	for _i: int in slot_count:
		slots.append([])
	selected_slot = -1
	input_buffer.clear()
	last_failure_reason = ""


func set_allowed_skill_types(skill_types: Array) -> void:
	allowed_skill_types.clear()
	for skill_type_name: Variant in skill_types:
		for skill_type: int in skill_type_name_to_enums(str(skill_type_name)):
			if skill_type != CharacterData.SkillType.NONE:
				allowed_skill_types[skill_type] = true


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
	return input_buffer.record_move(board_dir)


func record_attack_kill(board_dir: int) -> bool:
	return input_buffer.record_attack_kill(board_dir)


func clear_pending() -> void:
	input_buffer.clear()


func has_pending() -> bool:
	return input_buffer.has_pending()


func pending_move_token() -> int:
	return input_buffer.pending_move_token


func pending_attack_token() -> int:
	return input_buffer.pending_attack_token


func select_slot(index: int) -> void:
	if index < 0 or index >= slots.size():
		selected_slot = -1
	else:
		selected_slot = index


func slot_status(index: int) -> int:
	if not _slot_index_valid(index):
		return SlotStatus.EMPTY
	var token_count: int = slot_token_count(index)
	if token_count == 0:
		return SlotStatus.EMPTY
	if token_count == 1:
		return SlotStatus.PARTIAL
	return SlotStatus.COMPLETE


func slot_tokens(index: int) -> Array:
	if not _slot_index_valid(index):
		return []
	return slots[index].duplicate()


func slot_token_count(index: int) -> int:
	if not _slot_index_valid(index):
		return 0
	return slots[index].size()


func slot_is_empty(index: int) -> bool:
	return slot_token_count(index) == 0


func slot_is_partial(index: int) -> bool:
	return slot_token_count(index) == 1


func slot_is_complete(index: int) -> bool:
	return slot_token_count(index) >= 2


func slot_first_token(index: int) -> int:
	if not slot_is_partial(index):
		return NO_TOKEN
	return slots[index][0]


func slot_can_accept(index: int, token: int) -> bool:
	if token == NO_TOKEN or not _slot_index_valid(index):
		return false
	var token_count: int = slot_token_count(index)
	if token_count == 0:
		return token_is_attack(token)
	if token_count != 1:
		return false
	if not can_compose(slots[index][0], token):
		return false
	return skill_type_allowed(classify_tokens([slots[index][0], token]))


func slot_store(index: int, token: int) -> bool:
	if not slot_can_accept(index, token):
		return false
	slots[index].append(token)
	return true


func can_store_in_slot(index: int, token: int = NO_TOKEN) -> bool:
	var candidate: int = get_pending_token_for_slot(index) if token == NO_TOKEN else token
	return slot_can_accept(index, candidate)


func press_space() -> bool:
	if not has_pending():
		last_failure_reason = "No pending vector to store."
		return false
	var slot_index: int = selected_slot
	var token: int = NO_TOKEN
	if slot_index >= 0:
		token = get_pending_token_for_slot(slot_index)
		if token == NO_TOKEN:
			last_failure_reason = "Selected slot cannot accept current pending vector."
			return false
		if not slot_store(slot_index, token):
			last_failure_reason = "Selected slot rejected that skill composition."
			return false
	else:
		slot_index = _find_default_store_slot()
		if slot_index < 0:
			last_failure_reason = "No slot can accept the current pending vector."
			return false
		token = get_pending_token_for_slot(slot_index)
		if token == NO_TOKEN:
			last_failure_reason = "No valid vector-slot match found."
			return false
		if not slot_store(slot_index, token):
			last_failure_reason = "Auto-selected slot rejected that skill composition."
			return false
	input_buffer.consume(token)
	last_failure_reason = ""
	return true


func auto_store_pending() -> bool:
	var candidates: Array = input_buffer.tokens_in_priority_order()
	if candidates.is_empty():
		return true

	var preferred_result: Dictionary = _try_store_token_order(candidates)
	if not Array(preferred_result.get("consumed", [])).is_empty():
		_apply_auto_store_result(preferred_result)
		return true

	if candidates.size() == 2:
		var reversed: Array = [candidates[1], candidates[0]]
		var reversed_result: Dictionary = _try_store_token_order(reversed)
		if not Array(reversed_result.get("consumed", [])).is_empty():
			_apply_auto_store_result(reversed_result)
			return true
	return true


func can_cast_selected() -> bool:
	return slot_status(selected_slot) == SlotStatus.COMPLETE


func get_last_failure_reason() -> String:
	return last_failure_reason


func consume_selected_skill() -> Array:
	if not can_cast_selected():
		return []
	var slot_data: Array = slot_tokens(selected_slot)
	slots[selected_slot] = []
	return slot_data


func clear_slot(index: int) -> void:
	if _slot_index_valid(index):
		slots[index] = []


func replace_complete_slot(index: int, first_board_dir: int, second_board_dir: int, first_is_attack: bool) -> bool:
	if not _slot_index_valid(index):
		return false
	var first_core_dir: int = board_dir_to_core(first_board_dir)
	var second_core_dir: int = board_dir_to_core(second_board_dir)
	if first_core_dir < 0 or second_core_dir < 0:
		return false
	var first_token: int
	var second_token: int
	if first_is_attack:
		first_token = token_code(TokenKind.ATTACK, first_core_dir)
		second_token = token_code(TokenKind.ATTACK, second_core_dir)
	else:
		first_token = token_code(TokenKind.ATTACK, second_core_dir)
		second_token = token_code(TokenKind.MOVE, first_core_dir)
	if not can_compose(first_token, second_token):
		return false
	if not skill_type_allowed(classify_tokens([first_token, second_token])):
		return false
	slots[index] = [first_token, second_token]
	return true


func legacy_slot(index: int) -> Array:
	if not _slot_index_valid(index):
		return []
	return tokens_to_legacy(slots[index])


func legacy_slots() -> Array:
	var result: Array = []
	for i: int in slots.size():
		result.append(legacy_slot(i))
	return result


func get_view_model() -> Dictionary:
	var slot_copy: Array = []
	for i: int in slots.size():
		slot_copy.append(slot_tokens(i))
	return {
		"slots": slot_copy,
		"selected_slot": selected_slot,
		"pending_move_token": pending_move_token(),
		"pending_attack_token": pending_attack_token(),
	}


static func can_compose(first_token: int, second_token: int) -> bool:
	if first_token == NO_TOKEN or second_token == NO_TOKEN:
		return false
	if not token_is_attack(first_token):
		return false
	if tokens_are_opposite(first_token, second_token):
		return false
	var second_kind: int = token_kind(second_token)
	return second_kind == TokenKind.MOVE or second_kind == TokenKind.ATTACK


static func classify_tokens(tokens: Array) -> int:
	if tokens.size() != 2 or not can_compose(tokens[0], tokens[1]):
		return CharacterData.SkillType.NONE
	return CharacterData.classify_skill(tokens_to_legacy(tokens))


static func tokens_to_legacy(tokens: Array) -> Array:
	if tokens.size() == 0:
		return []
	if tokens.size() == 1:
		return [token_board_dir(tokens[0])]
	if token_is_attack(tokens[0]) and not token_is_attack(tokens[1]):
		return [
			token_board_dir(tokens[1]),
			token_board_dir(tokens[0]),
			false,
		]
	return [
		token_board_dir(tokens[0]),
		token_board_dir(tokens[1]),
		token_is_attack(tokens[0]),
	]


func skill_type_allowed(skill_type: int) -> bool:
	if allowed_skill_types.is_empty():
		return true
	return allowed_skill_types.has(skill_type)


static func skill_type_name_to_enums(skill_type_name: String) -> Array[int]:
	match skill_type_name.to_upper():
		"LAA":
			return [CharacterData.SkillType.ORTHO_AA]
		"IAA":
			return [CharacterData.SkillType.SAME_AA]
		"IMA":
			return [CharacterData.SkillType.SAME_MA]
		"LMA":
			return [CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA]
		"RMA":
			return [CharacterData.SkillType.RIGHT_MA]
		_:
			return []


func _slot_index_valid(index: int) -> bool:
	return index >= 0 and index < slots.size()


func _find_default_store_slot() -> int:
	for i: int in slots.size():
		if slot_is_partial(i) and can_store_in_slot(i):
			return i
	for i: int in slots.size():
		if slot_is_empty(i):
			return i
	return -1


func _try_store_token_order(tokens: Array) -> Dictionary:
	var work_slots: Array = []
	for i: int in slots.size():
		work_slots.append(slot_tokens(i))
	var consumed: Array = []
	for token: int in tokens:
		if _store_token_default(work_slots, token):
			consumed.append(token)
	return {"slots": work_slots, "consumed": consumed}


func _store_token_default(target_slots: Array, token: int) -> bool:
	if not token_is_attack(token):
		return false
	if token_is_attack(token):
		for i: int in target_slots.size():
			var tokens: Array = target_slots[i]
			if tokens.is_empty():
				tokens.append(token)
				return true
	for i: int in range(target_slots.size() - 1, -1, -1):
		var tokens: Array = target_slots[i]
		if tokens.size() == 1 and can_compose(tokens[0], token):
			tokens.append(token)
			return true
	if token_is_attack(token):
		return false
	for i: int in target_slots.size():
		var tokens: Array = target_slots[i]
		if tokens.is_empty():
			return false
	return false


func _apply_auto_store_result(result: Dictionary) -> void:
	slots = result.get("slots", slots)
	input_buffer.consume_many(result.get("consumed", []))


func get_pending_token_for_slot(index: int) -> int:
	if not _slot_index_valid(index):
		return NO_TOKEN
	if slot_is_partial(index):
		var first_token: int = slots[index][0]
		var attack_token: int = pending_attack_token()
		var move_token: int = pending_move_token()
		if attack_token != NO_TOKEN and can_compose(first_token, attack_token):
			return attack_token
		if move_token != NO_TOKEN and can_compose(first_token, move_token):
			return move_token
		return NO_TOKEN
	if slot_is_empty(index):
		return pending_attack_token()
	return NO_TOKEN
