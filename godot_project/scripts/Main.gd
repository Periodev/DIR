extends Node

const DEBUG_CHARACTERS: Array[String] = ["EXE", "RDR", "PLN"]
var _debug_char_idx: int = 0

@onready var board: Node2D = $Board
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	board.current_character = DEBUG_CHARACTERS[_debug_char_idx]
	board.restart()
	hud.setup(board)

	board.board_updated.connect(_on_board_updated)
	board.game_over_signal.connect(_on_game_over)

	_on_board_updated()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	# Restart
	if keycode == KEY_R:
		board.restart()
		hud.setup(board)
		_on_board_updated()
		get_viewport().set_input_as_handled()
		return

	# Debug: spawn 2 dead cells (F3)
	if keycode == KEY_F3:
		board.debug_spawn_dead(2)
		get_viewport().set_input_as_handled()
		return

	# Cycle character (F4)
	if keycode == KEY_F4:
		_debug_char_idx = (_debug_char_idx + 1) % DEBUG_CHARACTERS.size()
		board.current_character = DEBUG_CHARACTERS[_debug_char_idx]
		board.restart()
		hud.setup(board)
		_on_board_updated()
		get_viewport().set_input_as_handled()
		return

	if board.game_state.is_game_over():
		return

	# Direction card: WASD / arrows
	var dir: int = CharacterData.key_to_direction(keycode)
	if dir != CharacterData.Direction.NONE:
		board.try_play_direction(dir)
		get_viewport().set_input_as_handled()
		return

	# Vector slot 0 (Q)
	if keycode == KEY_Q:
		board.try_play_slot(0)
		get_viewport().set_input_as_handled()
		return

	# Vector slot 1 (E)
	if keycode == KEY_E:
		board.try_play_slot(1)
		get_viewport().set_input_as_handled()
		return

	# End turn / refresh hand (Space)
	if keycode == KEY_SPACE:
		board.try_end_turn()
		get_viewport().set_input_as_handled()
		return

func _on_board_updated() -> void:
	hud.update(board)

func _on_game_over() -> void:
	hud.show_game_over()
