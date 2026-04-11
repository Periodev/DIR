extends Node

@onready var board: Node2D = $Board

func _ready() -> void:
	board.restart()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	if keycode == KEY_R:
		board.restart()
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_F3:
		board.debug_spawn_enemies(2)
		get_viewport().set_input_as_handled()
		return

	var dir: int = CharacterData.key_to_direction(keycode)
	if dir != CharacterData.Direction.NONE:
		if not board.try_attack(dir):
			board.try_move(dir)
		get_viewport().set_input_as_handled()
		return

	if keycode == KEY_ENTER:
		board.try_end_turn()
		get_viewport().set_input_as_handled()
		return
