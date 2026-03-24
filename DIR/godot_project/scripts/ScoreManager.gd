class_name ScoreManager

const ENABLE_COMBO_BONUS := false

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)

var score: int = 0
var combo_counter: int = 0

func on_kill(cell_type: int) -> int:
	var base := 10
	if cell_type == CharacterData.CellType.DEAD_SHIELD:
		base = 20
	elif cell_type == CharacterData.CellType.DEAD_DOUBLE:
		base = 15
	var multiplier: int = max(1, combo_counter) if ENABLE_COMBO_BONUS else 1
	var points: int = base * multiplier
	score += points
	score_changed.emit(score)
	combo_changed.emit(combo_counter if ENABLE_COMBO_BONUS else 0)
	return points

func on_move_to_live() -> void:
	combo_counter = 0
	combo_changed.emit(combo_counter if ENABLE_COMBO_BONUS else 0)

func reset() -> void:
	score = 0
	combo_counter = 0
	score_changed.emit(score)
	combo_changed.emit(combo_counter if ENABLE_COMBO_BONUS else 0)
