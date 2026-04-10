extends Node2D

const CharacterImpl_EXE = preload("res://scripts/CharacterImpl_EXE.gd")
const CharacterImpl_RDR = preload("res://scripts/CharacterImpl_RDR.gd")
const CharacterImpl_PLN = preload("res://scripts/CharacterImpl_PLN.gd")

const COLS: int = 5
const ROWS: int = 5
const CELL_SIZE: float = 100.0
const CELL_GAP: float = 8.0
const CELL_STEP: float = CELL_SIZE + CELL_GAP

signal board_updated
signal game_over_signal

# ── Grid ──────────────────────────────────────────────────────────────────────
var grid: Array[Array] = []           # grid[row][col] = CellType (int)
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var player_facing_dir: int = CharacterData.Direction.UP

# ── Card system ───────────────────────────────────────────────────────────────
var deck: Deck = null
var hand: Array[int] = []
var hand_size: int = 4

# ── Vector slots ──────────────────────────────────────────────────────────────
var vector_slots: Array[VectorSlot] = []
var _recording_slot_idx: int = -1    # index of slot being recorded into; -1 = none

# ── Stats / state ─────────────────────────────────────────────────────────────
var survival_turns: int = 0
var game_state: GameStateMachine = null
var current_character: String = "EXE"
var _char_impl: RefCounted = null

# ── Visuals ───────────────────────────────────────────────────────────────────
var cell_nodes: Array[Array] = []
var player_node: Node2D = null
var _cell_scene: PackedScene = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_cell_scene = load("res://scenes/Cell.tscn")
	var player_scene: PackedScene = load("res://scenes/Player.tscn")

	game_state = GameStateMachine.new()

	for r: int in ROWS:
		var row_nodes: Array[Node2D] = []
		for c: int in COLS:
			var cell: Node2D = _cell_scene.instantiate()
			cell.grid_pos = Vector2i(c, r)
			cell.position = Vector2(c * CELL_STEP, r * CELL_STEP)
			add_child(cell)
			row_nodes.append(cell)
		cell_nodes.append(row_nodes)

	player_node = player_scene.instantiate()
	add_child(player_node)
	player_node.animation_done.connect(_on_player_animation_done)

	get_viewport().size_changed.connect(_update_board_offset)
	_update_board_offset()

func setup_character(char_name: String) -> void:
	current_character = char_name
	player_node.set_character(char_name)
	var data: Dictionary = CharacterData.CHARACTERS[char_name]
	hand_size = data["hand_size"]
	match char_name:
		"EXE": _char_impl = CharacterImpl_EXE.new()
		"RDR": _char_impl = CharacterImpl_RDR.new()
		"PLN": _char_impl = CharacterImpl_PLN.new()

	vector_slots.clear()
	for slot_data: Dictionary in data["vector_slots"]:
		vector_slots.append(VectorSlot.new(slot_data["capacity"], slot_data["label"]))

func restart() -> void:
	grid.clear()
	for _r: int in ROWS:
		var row: Array[int] = []
		for _c: int in COLS:
			row.append(CharacterData.CellType.LIVE)
		grid.append(row)

	player_pos = Vector2i(COLS / 2, ROWS / 2)
	player_facing_dir = CharacterData.Direction.UP
	survival_turns = 0
	_recording_slot_idx = -1

	setup_character(current_character)
	deck = Deck.new()
	hand.clear()
	_draw_hand()

	game_state.reset()
	_refresh_visuals()

# ── Card drawing ──────────────────────────────────────────────────────────────

func _draw_hand() -> void:
	while hand.size() < hand_size:
		hand.append(deck.draw())

# ── Input actions ─────────────────────────────────────────────────────────────

# Play a direction card from hand.
# RECORDING mode → consume the card to feed into the active slot.
# IDLE mode      → move the player one step in that direction.
func try_play_direction(dir: int) -> bool:
	if game_state.is_game_over():
		return false

	var card_idx: int = -1
	for i: int in hand.size():
		if hand[i] == dir:
			card_idx = i
			break
	if card_idx < 0:
		return false

	if game_state.is_recording():
		# Move the player (same rules as normal), then record the direction into the slot.
		var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
		var target: Vector2i = player_pos + dv
		if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
			return false
		if grid[target.y][target.x] != CharacterData.CellType.LIVE:
			return false
		hand.remove_at(card_idx)
		player_facing_dir = dir
		player_pos = target
		survival_turns += 1
		_feed_recording_slot(dir)
		if hand.is_empty():
			_draw_hand()
		return true

	if not game_state.is_idle():
		return false

	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = player_pos + dv
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false
	if grid[target.y][target.x] != CharacterData.CellType.LIVE:
		return false

	hand.remove_at(card_idx)
	player_facing_dir = dir
	player_pos = target
	survival_turns += 1

	if hand.is_empty():
		_draw_hand()

	_refresh_visuals()
	return true

# Activate a vector slot by index (Q = slot 0, E = slot 1).
# Empty slot  → enter recording mode.
# Full slot   → fire the slot (attack or movement skill).
# Active slot (recording) → cancel recording.
func try_play_slot(slot_idx: int) -> bool:
	if game_state.is_game_over():
		return false
	if slot_idx < 0 or slot_idx >= vector_slots.size():
		return false

	var slot: VectorSlot = vector_slots[slot_idx]

	if game_state.is_recording():
		if _recording_slot_idx == slot_idx:
			_recording_slot_idx = -1
			game_state.set_state(CharacterData.GameStateEnum.IDLE)
			_refresh_visuals()
			return true
		return false

	if not game_state.is_idle():
		return false

	if slot.is_empty():
		_recording_slot_idx = slot_idx
		game_state.set_state(CharacterData.GameStateEnum.RECORDING)
		_refresh_visuals()
		return true

	if slot.is_full():
		_fire_slot(slot_idx)
		return true

	return false

# ── Internal ──────────────────────────────────────────────────────────────────

func _feed_recording_slot(dir: int) -> void:
	if _recording_slot_idx < 0:
		return
	var slot: VectorSlot = vector_slots[_recording_slot_idx]
	slot.record(dir)
	if slot.is_full():
		_recording_slot_idx = -1
		game_state.set_state(CharacterData.GameStateEnum.IDLE)
	_refresh_visuals()

func _fire_slot(slot_idx: int) -> void:
	var slot: VectorSlot = vector_slots[slot_idx]
	var ctype: String = slot.combo_type()
	var dirs: Array[int] = slot.consume()

	player_facing_dir = dirs[0]
	survival_turns += 1

	_char_impl.on_slot_fire(self, slot_idx, ctype, dirs)
	_refresh_visuals()

# End turn: discard remaining hand and draw a fresh one
func try_end_turn() -> bool:
	if not game_state.is_idle():
		return false
	hand.clear()
	_draw_hand()
	survival_turns += 1
	_refresh_visuals()
	return true

# Debug: turn N random live cells (excluding player) into dead cells
func debug_spawn_dead(count: int) -> void:
	var available: Array[Vector2i] = []
	for r: int in ROWS:
		for c: int in COLS:
			var pos: Vector2i = Vector2i(c, r)
			if pos != player_pos and grid[r][c] == CharacterData.CellType.LIVE:
				available.append(pos)
	available.shuffle()
	for i: int in mini(count, available.size()):
		var pos: Vector2i = available[i]
		grid[pos.y][pos.x] = CharacterData.CellType.DEAD
	_refresh_visuals()

# Called by CharacterImpl to clear one dead cell (attack hit)
func kill_cell(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
		return
	if grid[pos.y][pos.x] == CharacterData.CellType.DEAD:
		grid[pos.y][pos.x] = CharacterData.CellType.LIVE

func _on_player_animation_done() -> void:
	if game_state.is_presenting():
		game_state.set_state(CharacterData.GameStateEnum.IDLE)
		_refresh_visuals()

func _refresh_visuals() -> void:
	for r: int in ROWS:
		for c: int in COLS:
			cell_nodes[r][c].set_type(grid[r][c])

	player_node.set_facing(player_facing_dir)

	var old_pos: Vector2 = player_node.position
	var new_pos: Vector2 = Vector2(
		player_pos.x * CELL_STEP + CELL_SIZE / 2.0,
		player_pos.y * CELL_STEP + CELL_SIZE / 2.0
	)
	player_node.position = new_pos
	if new_pos != old_pos:
		player_node.play_move(old_pos)

	board_updated.emit()

func _update_board_offset() -> void:
	var bw: float = float(COLS - 1) * CELL_STEP + CELL_SIZE
	var bh: float = float(ROWS - 1) * CELL_STEP + CELL_SIZE
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2((vp.x - bw) * 0.5, (vp.y - bh) * 0.5)
