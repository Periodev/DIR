extends Node2D

const COLS: int = 4
const ROWS: int = 4
const CELL_SIZE: float = 100.0
const CELL_GAP: float = 8.0
const CELL_STEP: float = CELL_SIZE + CELL_GAP

const SEQ_SLOTS: int = 3
const SEQ_SIZE: float = 85.0
const SEQ_GAP: float = 8.0
const SEQ_STEP: float = SEQ_SIZE + SEQ_GAP
const SEQ_MARGIN_TOP: float = 20.0

signal board_updated

var grid: Array[Array] = []
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var action_seq: Array[int] = []
var turn: int = 1

var cell_nodes: Array[Array] = []
var _cell_scene: PackedScene = null

func _ready() -> void:
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
	turn = 1
	_refresh_visuals()

func try_move(dir: int) -> bool:
	if action_seq.size() >= SEQ_SLOTS:
		return false
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = player_pos + dv
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false
	if grid[target.y][target.x] != CharacterData.CellType.LIVE:
		return false
	player_pos = target
	action_seq.append(dir)
	_refresh_visuals()
	return true

func try_end_turn() -> bool:
	turn += 1
	action_seq.clear()
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
	board_updated.emit()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 32

	var board_w: float = (COLS - 1) * CELL_STEP + CELL_SIZE
	var total_seq_w: float = (SEQ_SLOTS - 1) * SEQ_STEP + SEQ_SIZE
	var seq_x0: float = (board_w - total_seq_w) / 2.0
	var seq_y: float = ROWS * CELL_STEP + SEQ_MARGIN_TOP

	# Action sequence slots
	for i: int in SEQ_SLOTS:
		var x: float = seq_x0 + i * SEQ_STEP
		var rect: Rect2 = Rect2(x, seq_y, SEQ_SIZE, SEQ_SIZE)
		draw_rect(rect, Color(0.10, 0.10, 0.13))
		draw_rect(rect, Color(0.30, 0.30, 0.35), false, 1.5)

		if i < action_seq.size():
			var arrow: String = CharacterData.DIR_ARROWS[action_seq[i]]
			var text_y: float = seq_y + (SEQ_SIZE + font_size * 0.7) / 2.0
			draw_string(font, Vector2(x, text_y), arrow,
				HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, Color.WHITE)

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
