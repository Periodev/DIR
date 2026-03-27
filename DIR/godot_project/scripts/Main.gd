extends Node

const CURRENT_CHARACTER := "EXE"
const ATTACK_MODE_USE_CHARACTER := -1
const CURRENT_ATTACK_MODE := CharacterData.AttackMode.STRIKE

@onready var board: Node2D = $Board
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	board.setup_character(CURRENT_CHARACTER, CURRENT_ATTACK_MODE)
	hud.setup(CURRENT_CHARACTER)

	board.game_over_signal.connect(_on_game_over)
	board.board_updated.connect(_on_board_updated)
	board.score_manager.score_changed.connect(hud.update_score)
	board.score_manager.combo_changed.connect(hud.update_combo)
	board.score_manager.defeat_changed.connect(hud.update_defeats)

	_on_board_updated()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	# Restart
	if keycode == KEY_R:
		board.restart()
		hud.setup(CURRENT_CHARACTER)
		_on_board_updated()
		get_viewport().set_input_as_handled()
		return

	if board.game_state.is_game_over():
		return

	# Movement
	var dir = CharacterData.key_to_direction(keycode)
	if dir != CharacterData.Direction.NONE:
		if board.game_state.is_bonus_move_select():
			board.try_bonus_move(dir)
		else:
			board.try_move(dir)
		get_viewport().set_input_as_handled()
		return

	# Hold (Space)
	if keycode == KEY_SPACE:
		if board.game_state.is_bonus_move_select():
			board.try_bonus_stay()
		elif board.inventory.has_charge_marker:
			board.try_charge_action()
		else:
			board.inventory.toggle_hold()
		_on_board_updated()
		get_viewport().set_input_as_handled()
		return

	# Wait (X)
	if keycode == KEY_X:
		board.try_wait()
		_on_board_updated()
		get_viewport().set_input_as_handled()
		return

	# Ultimate (Enter / Z)
	if keycode == KEY_ENTER or keycode == KEY_Z:
		board.try_ultimate()
		_on_board_updated()
		get_viewport().set_input_as_handled()
		return

func _on_board_updated() -> void:
	hud.update_inventory(board.inventory)
	hud.update_score(board.score_manager.score)
	hud.update_combo(board.score_manager.combo_counter if board.score_manager.ENABLE_COMBO_BONUS else 0)
	hud.update_defeats(board.score_manager.defeat_count)
	hud.update_turns(board.survival_turns)
	hud.update_freeze(board.freeze_steps)

func _on_game_over(final_score: int) -> void:
	hud.show_game_over(final_score)
