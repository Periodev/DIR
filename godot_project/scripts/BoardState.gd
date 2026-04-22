class_name BoardState
extends RefCounted

var grid: Array = []
var polluted_grid: Array = []
var player_pos: Vector2i = Vector2i.ZERO
var shield_spawn_turn: Dictionary = {}
var enemy_spawn_turn: Dictionary = {}
var enemy_pollution_dir: Dictionary = {}
var guard_control_quadrant: Dictionary = {}
var kill_delta: int = 0
var bonus_moves_delta: int = 0
var recovered_dirs: Array = []
var player_moved: bool = false

func load_from_board(
	source_grid: Array,
	source_polluted_grid: Array,
	source_player_pos: Vector2i,
	source_shield_spawn_turn: Dictionary,
	source_enemy_spawn_turn: Dictionary,
	source_enemy_pollution_dir: Dictionary,
	source_guard_control_quadrant: Dictionary,
	duplicate_data: bool = true
) -> void:
	if duplicate_data:
		grid = duplicate_grid(source_grid)
		polluted_grid = duplicate_bool_grid(source_polluted_grid)
		shield_spawn_turn = source_shield_spawn_turn.duplicate(true)
		enemy_spawn_turn = source_enemy_spawn_turn.duplicate(true)
		enemy_pollution_dir = source_enemy_pollution_dir.duplicate(true)
		guard_control_quadrant = source_guard_control_quadrant.duplicate(true)
	else:
		grid = source_grid
		polluted_grid = source_polluted_grid
		shield_spawn_turn = source_shield_spawn_turn
		enemy_spawn_turn = source_enemy_spawn_turn
		enemy_pollution_dir = source_enemy_pollution_dir
		guard_control_quadrant = source_guard_control_quadrant
	player_pos = source_player_pos

func duplicate_state() -> RefCounted:
	var state: RefCounted = get_script().new()
	state.load_from_board(
		grid,
		polluted_grid,
		player_pos,
		shield_spawn_turn,
		enemy_spawn_turn,
		enemy_pollution_dir,
		guard_control_quadrant,
		true
	)
	return state

static func duplicate_grid(source: Array) -> Array:
	var copy: Array = []
	for row: Array in source:
		copy.append(row.duplicate())
	return copy

static func duplicate_bool_grid(source: Array) -> Array:
	var copy: Array = []
	for row: Array in source:
		copy.append(row.duplicate())
	return copy
