extends Node2D

const COLS := 5
const ROWS := 5
const SPAWN_CYCLE_STEPS := 3
const SPAWNS_PER_CYCLE := 1
const SPAWN_CELL_TYPE := CharacterData.CellType.DEAD_ONE_WAY_SHIELD
const BLOCK_OUTER_RING_SPAWN := false
const CELL_SIZE := 100.0
const CELL_GAP := 8.0
const CELL_STEP := CELL_SIZE + CELL_GAP

signal game_over_signal(final_score: int)
signal board_updated

var grid: Array = []  # grid[row][col] = CellType
var cell_shield_dirs: Array = []  # cell_shield_dirs[row][col] = Direction
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var player_facing_dir: int = CharacterData.Direction.UP
var candidate_cells: Array = []  # Array of Vector2i
var bonus_move_options: Dictionary = {}  # Direction -> Vector2i
var bonus_move_can_stay: bool = false
var bonus_move_advances_turn: bool = false
var bonus_move_stores_memory: bool = false
var bonus_move_stores_directional_memory: bool = false
var bonus_move_is_attack: bool = false
var cycle_counter: int = 0
var freeze_steps: int = 0
var pending_post_defense_step: bool = false
var survival_turns: int = 0

var inventory: Inventory
var score_manager: ScoreManager
var game_state: GameStateMachine
var current_character: String = "COR"
var current_attack_mode_override: int = -1

var cell_nodes: Array = []  # cell_nodes[row][col] = Cell node
var player_node: Node2D

var _cell_scene: PackedScene
var _hit_effect_scene: PackedScene

func _ready() -> void:
	_cell_scene = load("res://scenes/Cell.tscn")
	_hit_effect_scene = load("res://scenes/HitEffect.tscn")
	var player_scene = load("res://scenes/Player.tscn")

	inventory = Inventory.new()
	score_manager = ScoreManager.new()
	game_state = GameStateMachine.new()

	# Build grid of cell nodes
	for r in ROWS:
		var row_nodes := []
		for c in COLS:
			var cell = _cell_scene.instantiate()
			cell.grid_pos = Vector2i(c, r)
			cell.position = Vector2(c * CELL_STEP, r * CELL_STEP)
			add_child(cell)
			row_nodes.append(cell)
		cell_nodes.append(row_nodes)

	# Player node
	player_node = player_scene.instantiate()
	add_child(player_node)

	get_viewport().size_changed.connect(_update_board_offset)
	_update_board_offset()
	restart()

func setup_character(char_name: String, attack_mode_override: int = -1) -> void:
	current_character = char_name
	current_attack_mode_override = attack_mode_override
	inventory.setup(char_name)
	player_node.set_character(char_name)

func restart() -> void:
	# Reset grid
	grid.clear()
	cell_shield_dirs.clear()
	for r in ROWS:
		var row := []
		var shield_row := []
		for c in COLS:
			row.append(CharacterData.CellType.LIVE)
			shield_row.append(CharacterData.Direction.NONE)
		grid.append(row)
		cell_shield_dirs.append(shield_row)

	player_pos = Vector2i(COLS / 2, ROWS / 2)
	player_facing_dir = CharacterData.Direction.UP
	candidate_cells.clear()
	bonus_move_options.clear()
	bonus_move_can_stay = false
	bonus_move_advances_turn = false
	bonus_move_stores_memory = false
	bonus_move_stores_directional_memory = false
	bonus_move_is_attack = false
	cycle_counter = 0
	cycle_resolved = false
	freeze_steps = 0
	pending_post_defense_step = false
	survival_turns = 0

	setup_character(current_character, current_attack_mode_override)
	score_manager.reset()
	game_state.reset()

	_refresh_visuals()

func try_move(dir: int) -> bool:
	if not game_state.is_idle():
		return false

	var dv = CharacterData.DIR_VECTOR[dir]
	var target = player_pos + dv

	# Bounds check
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false

	var target_type = grid[target.y][target.x]

	if target_type == CharacterData.CellType.LIVE:
		# Move to live cell
		player_facing_dir = dir
		player_pos = target
		inventory.push(_get_move_memory_token(dir))
		inventory.register_move(dir)
		score_manager.on_move_to_live()

		return _finalize_turn_after_action()

	else:
		# Dead cell - check inventory for matching direction (any position)
		var match_idx := inventory.find_direction(dir)
		if match_idx < 0:
			return false  # No matching direction in queue

		var origin := player_pos

		# Remove matched direction (first occurrence)
		inventory.remove_at(match_idx)
		player_facing_dir = dir
		if _try_break_one_way_shield(target, dir, target_type):
			cell_nodes[target.y][target.x].flash_shield_break(0.09)
			player_node.play_attack(dir, false, _get_attack_mode() == CharacterData.AttackMode.DASH)
			return _finalize_turn_after_action()
		if _has_penetrating_attack():
			_resolve_penetrating_attack(dir, origin, target, target_type)
		elif _get_attack_mode() == CharacterData.AttackMode.DASH:
			_resolve_attack(dir, target, target_type)
			if grid[target.y][target.x] == CharacterData.CellType.LIVE:
				player_pos = target
				inventory.register_move(dir)
		else:
			_resolve_attack(dir, target, target_type)
		if player_pos == origin:
			var attack_hit: bool = (grid[target.y][target.x] == CharacterData.CellType.LIVE)
			var was_dash := _get_attack_mode() == CharacterData.AttackMode.DASH
			player_node.play_attack(dir, attack_hit, was_dash)

		if _begin_post_kill_reposition_if_needed(target, dir):
			_refresh_visuals()
			return true
		return _finalize_turn_after_action()

func try_charge_action() -> bool:
	if not game_state.is_idle():
		return false
	if not inventory.has_charge_marker:
		return false
	if not inventory.is_charge_full():
		return false
	if inventory.charge_direction == CharacterData.Direction.NONE:
		return false

	var dir := inventory.charge_direction
	var dv = CharacterData.DIR_VECTOR[dir]
	var target = player_pos + dv
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false

	if not inventory.consume_charge():
		return false

	player_facing_dir = dir
	var target_type = grid[target.y][target.x]
	if target_type == CharacterData.CellType.LIVE:
		player_pos = target
		score_manager.on_move_to_live()
	else:
		var pos_before_attack := player_pos
		if _try_break_one_way_shield(target, dir, target_type):
			cell_nodes[target.y][target.x].flash_shield_break(0.09)
			player_node.play_attack(dir, false, _get_attack_mode() == CharacterData.AttackMode.DASH)
			return _finalize_turn_after_action()
		if _get_attack_mode() == CharacterData.AttackMode.DASH:
			_resolve_attack(dir, target, target_type)
			if grid[target.y][target.x] == CharacterData.CellType.LIVE:
				player_pos = target
		else:
			_resolve_attack(dir, target, target_type)
		if player_pos == pos_before_attack:
			var attack_hit: bool = (grid[target.y][target.x] == CharacterData.CellType.LIVE)
			var was_dash := _get_attack_mode() == CharacterData.AttackMode.DASH
			player_node.play_attack(dir, attack_hit, was_dash)
	return _finalize_turn_after_action()

func try_wait() -> bool:
	if not game_state.is_idle():
		return false
	return _finalize_turn_after_action()

func try_bonus_move(dir: int) -> bool:
	if not game_state.is_bonus_move_select():
		return false
	if not bonus_move_options.has(dir):
		return false

	player_facing_dir = dir
	if bonus_move_is_attack:
		var target: Vector2i = bonus_move_options[dir]
		var target_type: int = grid[target.y][target.x]
		bonus_move_options.clear()
		bonus_move_can_stay = false
		bonus_move_advances_turn = false
		bonus_move_stores_memory = false
		bonus_move_stores_directional_memory = false
		bonus_move_is_attack = false
		if not _consume_neutral_memory():
			game_state.set_state(CharacterData.GameStateEnum.IDLE)
			_refresh_visuals()
			_check_game_over()
			return false
		if _try_break_one_way_shield(target, dir, target_type):
			game_state.set_state(CharacterData.GameStateEnum.IDLE)
			_refresh_visuals()
			_check_game_over()
			return true
		if target_type != CharacterData.CellType.LIVE:
			_resolve_attack(dir, target, target_type)
			var attack_hit: bool = (grid[target.y][target.x] == CharacterData.CellType.LIVE)
			player_node.play_attack(dir, attack_hit)
		game_state.set_state(CharacterData.GameStateEnum.IDLE)
		_refresh_visuals()
		_check_game_over()
		return true

	player_pos = bonus_move_options[dir]
	bonus_move_options.clear()
	bonus_move_can_stay = false
	if bonus_move_stores_directional_memory:
		inventory.push(dir)
	elif bonus_move_stores_memory:
		inventory.push(_get_move_memory_token(dir))
	bonus_move_stores_memory = false
	bonus_move_stores_directional_memory = false
	bonus_move_is_attack = false
	if bonus_move_advances_turn:
		bonus_move_advances_turn = false
		return _finalize_turn_after_action()
	bonus_move_advances_turn = false
	game_state.set_state(CharacterData.GameStateEnum.IDLE)
	_refresh_visuals()
	_check_game_over()
	return true

func try_bonus_stay() -> bool:
	if not game_state.is_bonus_move_select():
		return false
	if not bonus_move_can_stay:
		return false

	bonus_move_options.clear()
	bonus_move_can_stay = false
	bonus_move_stores_memory = false
	bonus_move_stores_directional_memory = false
	bonus_move_is_attack = false
	if bonus_move_advances_turn:
		bonus_move_advances_turn = false
		return _finalize_turn_after_action()
	bonus_move_advances_turn = false
	game_state.set_state(CharacterData.GameStateEnum.IDLE)
	_refresh_visuals()
	_check_game_over()
	return true

func _get_attack_mode() -> int:
	if current_attack_mode_override >= 0:
		return current_attack_mode_override
	var data = CharacterData.CHARACTERS[current_character]
	return data.get("attack_mode", CharacterData.AttackMode.DASH)

func _has_pierce_passive() -> bool:
	var data = CharacterData.CHARACTERS[current_character]
	if not data.get("has_pierce", false):
		return false
	return _get_attack_mode() != CharacterData.AttackMode.DASH

func _get_move_memory_token(dir: int) -> int:
	var data = CharacterData.CHARACTERS[current_character]
	if data.get("moves_generate_neutral_only", false):
		return CharacterData.Direction.NEUTRAL
	return dir

func _has_penetrating_attack() -> bool:
	var data = CharacterData.CHARACTERS[current_character]
	return data.get("has_penetrating_attack", false)

func _has_post_kill_reposition() -> bool:
	var data = CharacterData.CHARACTERS[current_character]
	return data.get("has_post_kill_reposition", false)

func _has_post_defense_step() -> bool:
	var data = CharacterData.CHARACTERS[current_character]
	return data.get("has_post_defense_step", false)

func _consume_neutral_memory() -> bool:
	var neutral_idx: int = inventory.find_direction(CharacterData.Direction.NEUTRAL)
	if neutral_idx < 0:
		return false
	inventory.remove_at(neutral_idx)
	return true

func _try_break_one_way_shield(target: Vector2i, attack_dir: int, target_type: int) -> bool:
	if target_type != CharacterData.CellType.DEAD_ONE_WAY_SHIELD:
		return false
	if cell_shield_dirs[target.y][target.x] != CharacterData.OPPOSITE[attack_dir]:
		return false

	grid[target.y][target.x] = CharacterData.CellType.DEAD
	cell_shield_dirs[target.y][target.x] = CharacterData.Direction.NONE
	score_manager.combo_counter += 1
	score_manager.on_kill(target_type)
	return true

func _get_shield_dir_toward_player(pos: Vector2i) -> int:
	var delta: Vector2i = player_pos - pos
	if delta == Vector2i.ZERO:
		return CharacterData.OPPOSITE[player_facing_dir]
	if abs(delta.x) >= abs(delta.y):
		return CharacterData.Direction.RIGHT if delta.x > 0 else CharacterData.Direction.LEFT
	return CharacterData.Direction.DOWN if delta.y > 0 else CharacterData.Direction.UP

func _resolve_attack(dir: int, target: Vector2i, target_type: int) -> void:
	_kill_flow(target, dir, target_type)

	if not _has_pierce_passive():
		return
	if grid[target.y][target.x] != CharacterData.CellType.LIVE:
		return

	var next_pos = target + CharacterData.DIR_VECTOR[dir]
	if next_pos.x < 0 or next_pos.x >= COLS or next_pos.y < 0 or next_pos.y >= ROWS:
		return

	var next_type = grid[next_pos.y][next_pos.x]
	if next_type == CharacterData.CellType.LIVE:
		return

	_kill_flow(next_pos, dir, next_type)

func _resolve_penetrating_attack(dir: int, origin: Vector2i, target: Vector2i, target_type: int) -> void:
	_kill_flow(target, dir, target_type)

	# If the first hit did not clear the target, DASH degrades into STRIKE and stays put.
	if grid[target.y][target.x] != CharacterData.CellType.LIVE:
		player_pos = origin
		return

	var behind = target + CharacterData.DIR_VECTOR[dir]
	if behind.x < 0 or behind.x >= COLS or behind.y < 0 or behind.y >= ROWS:
		player_pos = target
		return
	if grid[behind.y][behind.x] != CharacterData.CellType.LIVE:
		player_pos = target
		return

	player_pos = behind

func _begin_post_kill_reposition_if_needed(target: Vector2i, entry_dir: int) -> bool:
	if not _has_post_kill_reposition():
		return false
	if grid[target.y][target.x] != CharacterData.CellType.LIVE:
		return false

	bonus_move_options.clear()
	bonus_move_can_stay = true
	bonus_move_advances_turn = true
	bonus_move_stores_memory = false
	bonus_move_stores_directional_memory = false
	bonus_move_is_attack = false
	for dir in CharacterData.DIR_VECTOR:
		var pos = player_pos + CharacterData.DIR_VECTOR[dir]
		if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
			continue
		if grid[pos.y][pos.x] != CharacterData.CellType.LIVE:
			continue
		bonus_move_options[dir] = pos

	if bonus_move_options.is_empty() and not bonus_move_can_stay:
		return false

	game_state.set_state(CharacterData.GameStateEnum.BONUS_MOVE_SELECT)
	return true

func _finalize_turn_after_action() -> bool:
	survival_turns += 1
	game_state.set_state(CharacterData.GameStateEnum.GENERATING)
	_advance_cycle()
	if _begin_post_defense_step_if_needed():
		_refresh_visuals()
		return true
	_refresh_visuals()
	_check_game_over()
	return true

func try_ultimate() -> bool:
	if not game_state.is_idle():
		return false
	var data = CharacterData.CHARACTERS[current_character]
	if not data["has_ult"]:
		return false
	if not inventory.is_full():
		return false

	inventory.queue.clear()
	freeze_steps = 3
	_refresh_visuals()
	return true

func _spawn_hit_effect(pos: Vector2i) -> void:
	var fx = _hit_effect_scene.instantiate()
	fx.z_index = 5
	fx.position = Vector2(pos.x * CELL_STEP + CELL_SIZE / 2.0, pos.y * CELL_STEP + CELL_SIZE / 2.0)
	add_child(fx)

func _kill_flow(pos: Vector2i, attack_dir: int, cell_type: int) -> void:
	if cell_type == CharacterData.CellType.DEAD_ONE_WAY_SHIELD:
		if cell_shield_dirs[pos.y][pos.x] == CharacterData.OPPOSITE[attack_dir]:
			grid[pos.y][pos.x] = CharacterData.CellType.DEAD
			cell_shield_dirs[pos.y][pos.x] = CharacterData.Direction.NONE
			score_manager.combo_counter += 1
			score_manager.on_kill(cell_type, false)
			return

	if cell_type == CharacterData.CellType.DEAD_DOUBLE_LIFE:
		grid[pos.y][pos.x] = CharacterData.CellType.DEAD
		cell_shield_dirs[pos.y][pos.x] = CharacterData.Direction.NONE
		score_manager.combo_counter += 1
		score_manager.on_kill(cell_type, false)
		return

	if cell_type == CharacterData.CellType.DEAD_SHIELD:
		# First hit: become regular DEAD, still score
		grid[pos.y][pos.x] = CharacterData.CellType.DEAD
		cell_shield_dirs[pos.y][pos.x] = CharacterData.Direction.NONE
		score_manager.combo_counter += 1
		score_manager.on_kill(cell_type, false)
		return

	# Set to LIVE
	grid[pos.y][pos.x] = CharacterData.CellType.LIVE
	cell_shield_dirs[pos.y][pos.x] = CharacterData.Direction.NONE
	score_manager.combo_counter += 1
	score_manager.on_kill(cell_type)
	_spawn_hit_effect(pos)

	# DEAD_DOUBLE: damage adjacent cells
	if cell_type == CharacterData.CellType.DEAD_DOUBLE:
		for dv in CharacterData.DIR_VECTOR.values():
			var neighbor = pos + dv
			if neighbor.x < 0 or neighbor.x >= COLS or neighbor.y < 0 or neighbor.y >= ROWS:
				continue
			var n_type = grid[neighbor.y][neighbor.x]
			if n_type != CharacterData.CellType.LIVE:
				grid[neighbor.y][neighbor.x] = CharacterData.CellType.LIVE
				cell_shield_dirs[neighbor.y][neighbor.x] = CharacterData.Direction.NONE
				score_manager.combo_counter += 1
				score_manager.on_kill(n_type)
				_spawn_hit_effect(neighbor)

var cycle_resolved: bool = false  # true = this cycle already spawned, remaining turns idle

func _advance_cycle() -> void:
	if freeze_steps > 0:
		freeze_steps -= 1
		if freeze_steps > 0:
			game_state.set_state(CharacterData.GameStateEnum.IDLE)
			return
		# freeze just ended, proceed with normal cycle

	cycle_counter += 1

	if cycle_resolved:
		# Already spawned this cycle, idle until cycle ends
		if cycle_counter >= SPAWN_CYCLE_STEPS:
			cycle_counter = 0
			cycle_resolved = false
	elif cycle_counter == 1:
		_start_new_cycle()
	elif cycle_counter >= SPAWN_CYCLE_STEPS:
		_clean_candidates()
		for pos in candidate_cells:
			_apply_candidate_spawn(pos)
		candidate_cells.clear()
		cycle_counter = 0
		cycle_resolved = false

	game_state.set_state(CharacterData.GameStateEnum.IDLE)

func _start_new_cycle() -> void:
	candidate_cells.clear()
	var available: Array = []
	for r in ROWS:
		for c in COLS:
			var pos = Vector2i(c, r)
			if _is_spawnable_live_cell(pos):
				available.append(pos)
	available.shuffle()
	var count = min(SPAWNS_PER_CYCLE, available.size())
	for i in count:
		candidate_cells.append(available[i])

func _clean_candidates() -> void:
	var cleaned: Array = []
	for pos in candidate_cells:
		if grid[pos.y][pos.x] == CharacterData.CellType.LIVE:
			cleaned.append(pos)
	candidate_cells = cleaned

func _apply_candidate_spawn(pos: Vector2i) -> void:
	if grid[pos.y][pos.x] != CharacterData.CellType.LIVE:
		return
	var cell_type: int = _pick_dead_type()

	if pos == player_pos:
		var first := inventory.pop()
		if first == CharacterData.Direction.NONE:
			_spawn_dead(pos, cell_type)
			return
		var second := inventory.pop()
		if second != CharacterData.Direction.NONE:
			score_manager.combo_counter += 1
			score_manager.on_kill(cell_type)
			if _has_post_defense_step():
				pending_post_defense_step = true
			return

	_spawn_dead(pos, cell_type)

func _spawn_dead(pos: Vector2i, cell_type: int) -> void:
	grid[pos.y][pos.x] = cell_type
	if cell_type == CharacterData.CellType.DEAD_ONE_WAY_SHIELD:
		cell_shield_dirs[pos.y][pos.x] = _get_shield_dir_toward_player(pos)
	else:
		cell_shield_dirs[pos.y][pos.x] = CharacterData.Direction.NONE

func _pick_dead_type() -> int:
	return SPAWN_CELL_TYPE

func _begin_post_defense_step_if_needed() -> bool:
	if not pending_post_defense_step:
		return false
	pending_post_defense_step = false
	if inventory.find_direction(CharacterData.Direction.NEUTRAL) < 0:
		return false

	bonus_move_options.clear()
	bonus_move_can_stay = false
	bonus_move_advances_turn = false
	bonus_move_stores_memory = false
	bonus_move_stores_directional_memory = false
	bonus_move_is_attack = true
	for dir in CharacterData.DIR_VECTOR:
		var pos = player_pos + CharacterData.DIR_VECTOR[dir]
		if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
			continue
		if grid[pos.y][pos.x] == CharacterData.CellType.LIVE:
			continue
		bonus_move_options[dir] = pos

	if bonus_move_options.is_empty():
		bonus_move_is_attack = false
		return false

	game_state.set_state(CharacterData.GameStateEnum.BONUS_MOVE_SELECT)
	return true

func _is_spawnable_live_cell(pos: Vector2i) -> bool:
	if grid[pos.y][pos.x] != CharacterData.CellType.LIVE:
		return false
	if not BLOCK_OUTER_RING_SPAWN:
		return true
	return pos.x > 0 and pos.x < COLS - 1 and pos.y > 0 and pos.y < ROWS - 1

func _check_game_over() -> void:
	if grid[player_pos.y][player_pos.x] != CharacterData.CellType.LIVE:
		game_state.set_state(CharacterData.GameStateEnum.GAME_OVER)
		game_over_signal.emit(score_manager.score)
		return

	for dv in CharacterData.DIR_VECTOR.values():
		var neighbor = player_pos + dv
		if neighbor.x < 0 or neighbor.x >= COLS or neighbor.y < 0 or neighbor.y >= ROWS:
			continue
		var n_type = grid[neighbor.y][neighbor.x]
		if n_type == CharacterData.CellType.LIVE:
			return  # Has escape

	# All neighbors are DEAD or out of bounds - check inventory + hold
	for dv_dir in CharacterData.DIR_VECTOR:
		var dv: Vector2i = CharacterData.DIR_VECTOR[dv_dir]
		var neighbor: Vector2i = player_pos + dv
		if neighbor.x < 0 or neighbor.x >= COLS or neighbor.y < 0 or neighbor.y >= ROWS:
			continue
		if grid[neighbor.y][neighbor.x] != CharacterData.CellType.LIVE:
			# Check if any slot in queue has this direction
			if inventory.has_direction(dv_dir):
				return  # Can consume and move

	game_state.set_state(CharacterData.GameStateEnum.GAME_OVER)
	game_over_signal.emit(score_manager.score)

func _refresh_visuals() -> void:
	# Update all cells
	for r in ROWS:
		for c in COLS:
			var cell = cell_nodes[r][c]
			cell.set_type(grid[r][c])
			cell.set_shield_dir(cell_shield_dirs[r][c])
			cell.set_candidate(0)

	# Mark candidates
	if cycle_counter >= 1:
		for i in candidate_cells.size():
			var pos: Vector2i = candidate_cells[i]
			var phase: int = _get_candidate_preview_phase()
			cell_nodes[pos.y][pos.x].set_candidate(phase)

	for pos in bonus_move_options.values():
		cell_nodes[pos.y][pos.x].set_candidate(10)
	if bonus_move_can_stay:
		cell_nodes[player_pos.y][player_pos.x].set_candidate(10)

	# Update player position
	var old_player_visual_pos := player_node.position
	player_node.position = Vector2(
		player_pos.x * CELL_STEP + CELL_SIZE / 2.0,
		player_pos.y * CELL_STEP + CELL_SIZE / 2.0
	)
	if player_node.position != old_player_visual_pos:
		player_node.play_move(old_player_visual_pos)

	board_updated.emit()

func _update_board_offset() -> void:
	var board_width: float = float(COLS - 1) * CELL_STEP + CELL_SIZE
	var board_height: float = float(ROWS - 1) * CELL_STEP + CELL_SIZE
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2(
		(viewport_size.x - board_width) * 0.5,
		(viewport_size.y - board_height) * 0.5
	)

func _get_candidate_preview_phase() -> int:
	if SPAWN_CYCLE_STEPS <= 1:
		return 4
	var progress: float = float(cycle_counter - 1) / float(SPAWN_CYCLE_STEPS - 1)
	return clampi(int(floor(progress * 4.0)) + 1, 1, 4)
