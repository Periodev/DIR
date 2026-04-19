extends Node

@onready var board: Node2D = $Board

func _ready() -> void:
	board.restart()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	var skill_keycodes: Array[Key] = [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_COMMA]
	for i: int in skill_keycodes.size():
		if keycode == skill_keycodes[i]:
			board.set_skill_preview(i if board.skill_preview != i else -1)
			get_viewport().set_input_as_handled()
			return

	if keycode == KEY_R:
		board.restart()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F2:
		board.switch_character()
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

	if not board.can_accept_input():
		return

	var dir: int = CharacterData.key_to_direction(keycode)
	if dir != CharacterData.Direction.NONE:
		if board.skill_preview >= 0:
			board.rotate_armed_skill(dir)
		else:
			if not board.try_attack(dir):
				board.try_move(dir)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_SPACE:
		if board.skill_preview >= 0:
			var slot_data: Array = board.skill_slots[board.skill_preview]
			if slot_data.size() == 3:
				board.use_skill(board.skill_preview)
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
