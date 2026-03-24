extends Node2D

const COLS := 5
const ROWS := 5
const CELL_SIZE := 100.0
const CELL_GAP := 8.0
const CELL_STEP := CELL_SIZE + CELL_GAP

signal game_over_signal(final_score: int)
signal board_updated

var grid: Array = []  # grid[row][col] = CellType
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var candidate_cells: Array = []  # Array of Vector2i
var cycle_counter: int = 0
var freeze_steps: int = 0

var inventory: Inventory
var score_manager: ScoreManager
var game_state: GameStateMachine
var current_character: String = "COR"
var current_attack_mode_override: int = -1

var cell_nodes: Array = []  # cell_nodes[row][col] = Cell node
var player_node: Node2D

var _cell_scene: PackedScene

func _ready() -> void:
	_cell_scene = load("res://scenes/Cell.tscn")
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

	restart()

func setup_character(char_name: String, attack_mode_override: int = -1) -> void:
	current_character = char_name
	current_attack_mode_override = attack_mode_override
	inventory.setup(char_name)
	player_node.set_character(char_name)

func restart() -> void:
	# Reset grid
	grid.clear()
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append(CharacterData.CellType.LIVE)
		grid.append(row)

	player_pos = Vector2i(COLS / 2, ROWS / 2)
	candidate_cells.clear()
	cycle_counter = 0
	cycle_resolved = false
	freeze_steps = 0

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
		player_pos = target
		inventory.push(dir)
		score_manager.on_move_to_live()

		# Advance cycle
		game_state.set_state(CharacterData.GameStateEnum.GENERATING)
		_advance_cycle()
		_refresh_visuals()
		_check_game_over()
		return true

	else:
		# Dead cell - check inventory for matching direction (any position)
		var match_idx := inventory.find_direction(dir)
		if match_idx < 0:
			return false  # No matching direction in queue

		# Remove matched direction (first occurrence)
		inventory.remove_at(match_idx)
		if _get_attack_mode() == CharacterData.AttackMode.RAM:
			player_pos = target

		# Kill flow
		_kill_flow(target, target_type)

		# Advance cycle
		game_state.set_state(CharacterData.GameStateEnum.GENERATING)
		_advance_cycle()
		_refresh_visuals()
		_check_game_over()
		return true

func _get_attack_mode() -> int:
	if current_attack_mode_override >= 0:
		return current_attack_mode_override
	var data = CharacterData.CHARACTERS[current_character]
	return data.get("attack_mode", CharacterData.AttackMode.RAM)

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

func _kill_flow(pos: Vector2i, cell_type: int) -> void:
	if cell_type == CharacterData.CellType.DEAD_SHIELD:
		# First hit: become regular DEAD, still score
		grid[pos.y][pos.x] = CharacterData.CellType.DEAD
		score_manager.combo_counter += 1
		score_manager.on_kill(cell_type)
		return

	# Set to LIVE
	grid[pos.y][pos.x] = CharacterData.CellType.LIVE
	score_manager.combo_counter += 1
	score_manager.on_kill(cell_type)

	# DEAD_DOUBLE: damage adjacent cells
	if cell_type == CharacterData.CellType.DEAD_DOUBLE:
		for dv in CharacterData.DIR_VECTOR.values():
			var neighbor = pos + dv
			if neighbor.x < 0 or neighbor.x >= COLS or neighbor.y < 0 or neighbor.y >= ROWS:
				continue
			var n_type = grid[neighbor.y][neighbor.x]
			if n_type != CharacterData.CellType.LIVE:
				grid[neighbor.y][neighbor.x] = CharacterData.CellType.LIVE
				score_manager.combo_counter += 1
				score_manager.on_kill(n_type)

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
		if cycle_counter >= 3:
			cycle_counter = 0
			cycle_resolved = false
	elif cycle_counter == 1:
		_start_new_cycle()
	elif cycle_counter == 2:
		_clean_candidates()
		for pos in candidate_cells:
			cell_nodes[pos.y][pos.x].set_candidate(2)
	elif cycle_counter >= 3:
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
			if grid[r][c] == CharacterData.CellType.LIVE:
				available.append(pos)
	available.shuffle()
	var count = min(2, available.size())
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

	if pos == player_pos:
		var first := inventory.pop()
		if first == CharacterData.Direction.NONE:
			grid[pos.y][pos.x] = _pick_dead_type()
			return
		var second := inventory.pop()
		if second != CharacterData.Direction.NONE:
			return

	grid[pos.y][pos.x] = _pick_dead_type()

func _pick_dead_type() -> int:
	if not CharacterData.ENABLE_VARIANTS:
		return CharacterData.CellType.DEAD
	var roll = randf()
	if roll < 0.75:
		return CharacterData.CellType.DEAD
	elif roll < 0.90:
		return CharacterData.CellType.DEAD_SHIELD
	else:
		return CharacterData.CellType.DEAD_DOUBLE

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
			cell.set_candidate(0)

	# Mark candidates
	for i in candidate_cells.size():
		var pos = candidate_cells[i]
		var phase = 1 if cycle_counter <= 1 else 2
		cell_nodes[pos.y][pos.x].set_candidate(phase)

	# Update player position
	player_node.position = Vector2(
		player_pos.x * CELL_STEP + CELL_SIZE / 2.0,
		player_pos.y * CELL_STEP + CELL_SIZE / 2.0
	)

	board_updated.emit()
