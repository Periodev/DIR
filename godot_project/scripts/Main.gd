extends Node

const LevelConstants = preload("res://scripts/LevelConstants.gd")

@onready var board: Node2D = $Board
var _debug_level_index: int = 0

func _ready() -> void:
	_load_default_level()


func _load_default_level() -> void:
	_load_level_by_index(LevelConstants.first_level_index_for_zone(LevelConstants.DEFAULT_LOAD_ZONE))


func _load_level_by_index(index: int) -> void:
	var levels: Array = LevelConstants.all_levels()
	if levels.is_empty():
		return
	_debug_level_index = clampi(index, 0, levels.size() - 1)
	board.load_level_definition(levels[_debug_level_index].duplicate(true))


func _load_prev_level() -> void:
	_load_level_by_index(_debug_level_index - 1)


func _load_next_level() -> void:
	_load_level_by_index(_debug_level_index + 1)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	var skill_keycodes: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4]
	for i: int in skill_keycodes.size():
		if keycode == skill_keycodes[i]:
			var slot_index: int = i % 4
			if slot_index >= board.get_skill_slot_count():
				get_viewport().set_input_as_handled()
				return
			board.set_skill_preview(slot_index if board.get_selected_skill_slot() != slot_index else -1)
			get_viewport().set_input_as_handled()
			return

	if keycode == KEY_R:
		_load_level_by_index(_debug_level_index)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F1:
		_load_prev_level()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F2:
		_load_next_level()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_Q:
		board.toggle_pending_marker(true)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_E:
		board.toggle_pending_marker(false)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F3:
		board.debug_spawn_enemies(2)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F4:
		board.toggle_spawn_mode()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F5:
		board.toggle_debug_skill_slots()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F6:
		board.toggle_play_mode()
		get_viewport().set_input_as_handled()
		return

	if not board.can_accept_input():
		return

	var dir: int = CharacterData.key_to_direction(keycode)
	if dir != CharacterData.Direction.NONE:
		if board.get_selected_skill_slot() >= 0:
			board.rotate_armed_skill(dir)
		else:
			if not board.try_attack(dir):
				board.try_move(dir)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_SPACE:
		var selected_slot: int = board.get_selected_skill_slot()
		if selected_slot >= 0:
			if board.is_skill_slot_complete(selected_slot):
				board.use_skill(selected_slot)
				board.set_skill_preview(-1)
			else:
				board.try_combine_skill()
		else:
			board.try_combine_skill()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_ENTER:
		board.try_end_turn()
		get_viewport().set_input_as_handled()
		return
