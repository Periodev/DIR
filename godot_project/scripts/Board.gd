extends Node2D

const COLS: int = 4
const ROWS: int = 4
const CELL_SIZE: float = 100.0
const CELL_GAP: float = 8.0
const CELL_STEP: float = CELL_SIZE + CELL_GAP

const SEQ_SIZE: float = 85.0
const SEQ_GAP: float = 8.0
const SEQ_STEP: float = SEQ_SIZE + SEQ_GAP
const SEQ_MARGIN_TOP: float = 20.0

signal board_updated

var char_config: CharacterData.Config = null

var grid: Array[Array] = []
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var action_seq: Array[int] = []
var action_seq_is_attack: Array[bool] = []
var moves_this_turn: int = 0
var attacks_this_turn: int = 0
var turn: int = 1

const _EXE_SCRIPT = preload("res://scripts/CharacterImpl_EXE.gd")

var cell_nodes: Array[Array] = []
var _cell_scene: PackedScene = null
var _arrow_overlay: Node2D = null

class ArrowOverlay extends Node2D:
	var board: Node2D
	func _draw() -> void:
		if board == null:
			return
		var ARROW_HALF: float = 26.0
		var HEAD_ARM: float = 18.0
		var LINE_W: float = 3.5
		var COLOR: Color = Color(1.0, 0.6, 0.15, 0.95)
		var COLS_: int = board.COLS
		var ROWS_: int = board.ROWS
		var CELL_SIZE_: float = board.CELL_SIZE
		var CELL_GAP_: float = board.CELL_GAP
		var CELL_STEP_: float = board.CELL_STEP

		for dir_id: int in CharacterData.DIR_VECTOR:
			var dv: Vector2i = CharacterData.DIR_VECTOR[dir_id]
			var neighbor: Vector2i = board.player_pos + dv
			if neighbor.x < 0 or neighbor.x >= COLS_ or neighbor.y < 0 or neighbor.y >= ROWS_:
				continue
			if board.grid[neighbor.y][neighbor.x] != CharacterData.CellType.ENEMY:
				continue

			var dv_f: Vector2 = Vector2(float(dv.x), float(dv.y))
			var perp: Vector2 = Vector2(-dv_f.y, dv_f.x)
			var player_center: Vector2 = Vector2(
				board.player_pos.x * CELL_STEP_ + CELL_SIZE_ / 2.0,
				board.player_pos.y * CELL_STEP_ + CELL_SIZE_ / 2.0
			)
			var gap_center: Vector2 = player_center + dv_f * (CELL_SIZE_ / 2.0 + CELL_GAP_ / 2.0)
			var tail: Vector2 = gap_center - dv_f * ARROW_HALF
			var tip: Vector2 = gap_center + dv_f * ARROW_HALF
			var shaft_end: Vector2 = tip - dv_f * HEAD_ARM

			# Shaft
			draw_line(tail, shaft_end, COLOR, LINE_W, true)
			# L-shaped head: two lines at 90° meeting at tip
			var top_pt: Vector2 = shaft_end - perp * HEAD_ARM
			var bot_pt: Vector2 = shaft_end + perp * HEAD_ARM
			draw_polyline(PackedVector2Array([top_pt, tip, bot_pt]), COLOR, LINE_W, true)

func _ready() -> void:
	char_config = _EXE_SCRIPT.get_config()
	_cell_scene = load("res://scenes/Cell.tscn")

	for r: int in ROWS:
		var row_nodes: Array[Node2D] = []
		for c: int in COLS:
			var cell: Node2D = _cell_scene.instantiate()
			cell.grid_pos = Vector2i(c, r)
			cell.position = Vector2(c * CELL_STEP, r * CELL_STEP)
			add_child(cell)
			row_nodes.append(cell)
		cell_nodes.append(row_nodes)

	_arrow_overlay = ArrowOverlay.new()
	_arrow_overlay.board = self
	add_child(_arrow_overlay)

	get_viewport().size_changed.connect(_update_board_offset)
	_update_board_offset()
	restart()

func restart() -> void:
	grid.clear()
	for _r: int in ROWS:
		var row: Array[int] = []
		for _c: int in COLS:
			row.append(CharacterData.CellType.LIVE)
		grid.append(row)
	player_pos = Vector2i(COLS / 2, ROWS / 2)
	action_seq.clear()
	action_seq_is_attack.clear()
	moves_this_turn = 0
	attacks_this_turn = 0
	turn = 1
	_refresh_visuals()

func try_move(dir: int) -> bool:
	if action_seq.size() >= char_config.seq_slots:
		return false
	if moves_this_turn >= char_config.max_moves:
		return false
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = player_pos + dv
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false
	if grid[target.y][target.x] != CharacterData.CellType.LIVE:
		return false
	player_pos = target
	action_seq.append(dir)
	action_seq_is_attack.append(false)
	moves_this_turn += 1
	_refresh_visuals()
	return true

func try_attack(dir: int) -> bool:
	if action_seq.size() >= char_config.seq_slots:
		return false
	if attacks_this_turn >= char_config.max_attacks:
		return false
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = player_pos + dv
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false
	if grid[target.y][target.x] != CharacterData.CellType.ENEMY:
		return false
	grid[target.y][target.x] = CharacterData.CellType.LIVE
	action_seq.append(dir)
	action_seq_is_attack.append(true)
	attacks_this_turn += 1
	_refresh_visuals()
	return true

func try_end_turn() -> bool:
	turn += 1
	action_seq.clear()
	action_seq_is_attack.clear()
	moves_this_turn = 0
	attacks_this_turn = 0
	_refresh_visuals()
	return true

func debug_spawn_enemies(count: int) -> void:
	var available: Array[Vector2i] = []
	for r: int in ROWS:
		for c: int in COLS:
			var pos: Vector2i = Vector2i(c, r)
			if pos != player_pos and grid[r][c] == CharacterData.CellType.LIVE:
				available.append(pos)
	available.shuffle()
	for i: int in mini(count, available.size()):
		grid[available[i].y][available[i].x] = CharacterData.CellType.ENEMY
	_refresh_visuals()

func _refresh_visuals() -> void:
	for r: int in ROWS:
		for c: int in COLS:
			cell_nodes[r][c].set_type(grid[r][c])
			cell_nodes[r][c].set_player(Vector2i(c, r) == player_pos)
	queue_redraw()
	if _arrow_overlay:
		_arrow_overlay.queue_redraw()
	board_updated.emit()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 32
	var slots: int = char_config.seq_slots

	var board_w: float = (COLS - 1) * CELL_STEP + CELL_SIZE
	var total_seq_w: float = (slots - 1) * SEQ_STEP + SEQ_SIZE
	var seq_x0: float = (board_w - total_seq_w) / 2.0
	var seq_y: float = ROWS * CELL_STEP + SEQ_MARGIN_TOP

	# Action sequence slots
	for i: int in slots:
		var x: float = seq_x0 + i * SEQ_STEP
		var rect: Rect2 = Rect2(x, seq_y, SEQ_SIZE, SEQ_SIZE)
		draw_rect(rect, Color(0.10, 0.10, 0.13))
		draw_rect(rect, Color(0.30, 0.30, 0.35), false, 1.5)

		if i < action_seq.size():
			var arrow: String = CharacterData.DIR_ARROWS[action_seq[i]]
			var text_y: float = seq_y + (SEQ_SIZE + font_size * 0.7) / 2.0
			var col: Color = Color(1.0, 0.6, 0.15) if action_seq_is_attack[i] else Color.WHITE
			draw_string(font, Vector2(x, text_y), arrow,
				HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, col)

	# Turn counter (right of board)
	var side_x: float = board_w + 28.0
	draw_string(font, Vector2(side_x, 26.0), "TURN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 66.0), str(turn),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)

func _update_board_offset() -> void:
	var board_w: float = (COLS - 1) * CELL_STEP + CELL_SIZE
	var total_h: float = ROWS * CELL_STEP + SEQ_MARGIN_TOP + SEQ_SIZE
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2((vp.x - board_w) / 2.0, (vp.y - total_h) / 2.0)
