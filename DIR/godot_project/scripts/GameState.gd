class_name GameStateMachine

signal state_changed(new_state: int)

var current_state: int = CharacterData.GameStateEnum.IDLE

func set_state(s: int) -> void:
	if current_state != s:
		current_state = s
		state_changed.emit(s)

func is_idle() -> bool:
	return current_state == CharacterData.GameStateEnum.IDLE

func is_game_over() -> bool:
	return current_state == CharacterData.GameStateEnum.GAME_OVER

func is_bonus_move_select() -> bool:
	return current_state == CharacterData.GameStateEnum.BONUS_MOVE_SELECT

func reset() -> void:
	set_state(CharacterData.GameStateEnum.IDLE)
