extends Node2D

const COLS: int = 5
const ROWS: int = 5
const CELL_SIZE: float = 100.0
const CELL_GAP: float = 8.0
const CELL_STEP: float = CELL_SIZE + CELL_GAP

const SEQ_SIZE: float = 85.0
const SEQ_GAP: float = 8.0
const SEQ_STEP: float = SEQ_SIZE + SEQ_GAP
const SEQ_MARGIN_TOP: float = 20.0
const ATK_QUEUE_GAP: float = 12.0
const SKILL_MARGIN_TOP: float = 20.0

signal board_updated

var char_config: CharacterData.Config = null
var _char_index: int = 0   # 0=EXE, 1=RDR

var grid: Array[Array] = []
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var action_seq: Array[int] = []
var action_seq_is_attack: Array[bool] = []
var moves_this_turn: int = 0
var attacks_this_turn: int = 0
var bonus_moves: int = 0
var bonus_attacks: int = 0
var turn: int = 1

var attack_queue: Array[int] = []
var attack_queue_highlighted: int = -1

var skill_slots: Array = []
var skill_preview: int = -1  # -1 = none, 0/1 = slot index being held
var kill_count: int = 0
var shield_spawn_turn: Dictionary = {}  # Vector2i -> int (turn when spawned)

const _EXE_SCRIPT = preload("res://scripts/CharacterImpl_EXE.gd")
const _RDR_SCRIPT = preload("res://scripts/CharacterImpl_RDR.gd")

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
			if not CharacterData.is_enemy(board.grid[neighbor.y][neighbor.x]):
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

		# Skill preview highlight
		if board.skill_preview >= 0 and board.skill_preview < board.char_config.skill_slot_count:
			if not board.skill_slots[board.skill_preview].is_empty():
				var preview: Dictionary = board.get_skill_preview_cells(board.skill_preview)
				for p in preview.get("move", []):
					if p.x >= 0 and p.x < COLS_ and p.y >= 0 and p.y < ROWS_:
						draw_rect(Rect2(p.x * CELL_STEP_, p.y * CELL_STEP_, CELL_SIZE_, CELL_SIZE_),
							Color(0.3, 0.8, 0.3, 0.35))
				for p in preview.get("hit", []):
					if p.x >= 0 and p.x < COLS_ and p.y >= 0 and p.y < ROWS_:
						draw_rect(Rect2(p.x * CELL_STEP_, p.y * CELL_STEP_, CELL_SIZE_, CELL_SIZE_),
							Color(1.0, 0.3, 0.3, 0.4))

func _load_char_config() -> void:
	char_config = ([_EXE_SCRIPT, _RDR_SCRIPT][_char_index]).get_config()

func switch_character() -> void:
	_char_index = (_char_index + 1) % 2
	restart()

func _ready() -> void:
	_load_char_config()
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
	_load_char_config()
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
	bonus_moves = 0
	bonus_attacks = 0
	turn = 1
	attack_queue.clear()
	attack_queue_highlighted = -1
	skill_slots.resize(char_config.skill_slot_count)
	for i: int in char_config.skill_slot_count:
		skill_slots[i] = []
	skill_preview = -1
	kill_count = 0
	shield_spawn_turn.clear()
	_refresh_visuals()

func try_move(dir: int) -> bool:
	if action_seq.size() >= char_config.seq_slots:
		return false
	if moves_this_turn >= char_config.max_moves + bonus_moves:
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
	if attacks_this_turn >= char_config.max_attacks + bonus_attacks:
		return false
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = player_pos + dv
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return false
	if not CharacterData.is_enemy(grid[target.y][target.x]):
		return false
	var shield_dir: int = CharacterData.get_shield_dir(grid[target.y][target.x])
	if shield_dir != CharacterData.Direction.NONE and \
			CharacterData.DIR_VECTOR[dir] + CharacterData.DIR_VECTOR[shield_dir] == Vector2i.ZERO:
		if not CharacterData.is_hard_shield(grid[target.y][target.x]):
			grid[target.y][target.x] = CharacterData.CellType.ENEMY  # hit shield → strip it
		# hard shield: absorb, do nothing
	else:
		grid[target.y][target.x] = CharacterData.CellType.LIVE   # unshielded side → kill
		kill_count += 1
		if char_config.teleport_on_kill:
			player_pos = target
	var killed: bool = grid[target.y][target.x] == CharacterData.CellType.LIVE
	if not char_config.use_rdr_classifier or killed:
		action_seq.append(dir)
		action_seq_is_attack.append(true)
	attacks_this_turn += 1
	_refresh_visuals()
	return true

func try_end_turn() -> bool:
	if char_config.use_unified_slots:
		var new_attacks: Array[int] = []
		for i: int in action_seq.size():
			if action_seq_is_attack[i]:
				new_attacks.append(action_seq[i])
		var empty_indices: Array[int] = []
		var vector_indices: Array[int] = []
		for i: int in char_config.skill_slot_count:
			if skill_slots[i].size() == 0:
				empty_indices.append(i)
			elif skill_slots[i].size() == 1:
				vector_indices.append(i)
		while new_attacks.size() > empty_indices.size() + vector_indices.size():
			new_attacks.pop_front()
		var fill_idx: int = 0
		for i: int in empty_indices:
			if fill_idx >= new_attacks.size():
				break
			skill_slots[i] = [new_attacks[fill_idx]]
			fill_idx += 1
		for i: int in vector_indices:
			if fill_idx >= new_attacks.size():
				break
			skill_slots[i] = [new_attacks[fill_idx]]
			fill_idx += 1
	else:
		for i: int in action_seq.size():
			if action_seq_is_attack[i]:
				attack_queue.append(action_seq[i])
		while attack_queue.size() > char_config.attack_queue_cap:
			attack_queue.pop_front()
	turn += 1
	action_seq.clear()
	action_seq_is_attack.clear()
	moves_this_turn = 0
	attacks_this_turn = 0
	bonus_moves = 0
	bonus_attacks = 0
	_harden_old_shields()
	debug_spawn_enemies(3)
	return true

func set_atk_highlight(slot: int) -> void:
	attack_queue_highlighted = -1 if attack_queue_highlighted == slot else slot
	queue_redraw()

func try_combine_skill() -> bool:
	if char_config.use_unified_slots:
		return _try_combine_skill_unified()
	if char_config.skill_mixed:
		return _try_combine_skill_mixed()
	if attack_queue_highlighted < 0 or attack_queue_highlighted >= attack_queue.size():
		return false
	if action_seq.is_empty():
		return false
	var dir_seq: int = action_seq[-1]
	var dir_atk: int = attack_queue[attack_queue_highlighted]
	# Reject opposite directions
	if CharacterData.DIR_VECTOR[dir_seq] + CharacterData.DIR_VECTOR[dir_atk] == Vector2i.ZERO:
		return false
	# Find first empty skill slot
	var empty: int = -1
	for i: int in char_config.skill_slot_count:
		if skill_slots[i].is_empty():
			empty = i
			break
	if empty < 0:
		return false
	skill_slots[empty] = [dir_seq, dir_atk, action_seq_is_attack[-1]]
	attack_queue.remove_at(attack_queue_highlighted)
	attack_queue_highlighted = -1
	_refresh_visuals()
	return true

func _try_combine_skill_unified() -> bool:
	if skill_preview < 0 or skill_preview >= char_config.skill_slot_count:
		return false
	var armed_slot: Array = skill_slots[skill_preview]
	if armed_slot.size() != 1:
		return false
	if action_seq.is_empty():
		return false
	var dir_seq: int = action_seq[-1]
	var dir_atk: int = armed_slot[0]
	if CharacterData.DIR_VECTOR[dir_seq] + CharacterData.DIR_VECTOR[dir_atk] == Vector2i.ZERO:
		return false
	skill_slots[skill_preview] = [dir_seq, dir_atk, action_seq_is_attack[-1]]
	_refresh_visuals()
	return true

func _try_combine_skill_mixed() -> bool:
	if action_seq.size() < 2:
		return false
	var dir1: int = action_seq[-2]
	var dir2: int = action_seq[-1]
	# Reject opposite directions
	if CharacterData.DIR_VECTOR[dir1] + CharacterData.DIR_VECTOR[dir2] == Vector2i.ZERO:
		return false
	var empty: int = -1
	for i: int in char_config.skill_slot_count:
		if skill_slots[i].is_empty():
			empty = i
			break
	if empty < 0:
		return false
	skill_slots[empty] = [dir1, dir2, false]
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
		var epos: Vector2i = available[i]
		grid[epos.y][epos.x] = CharacterData.CellType.ENEMY
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

	# Move / attack remaining counter (left of sequence)
	var rem_moves: int = char_config.max_moves + bonus_moves - moves_this_turn
	var rem_atk: int = char_config.max_attacks + bonus_attacks - attacks_this_turn
	var cx: float = seq_x0 - 70.0
	draw_string(font, Vector2(cx, seq_y + 28.0), str(rem_moves) + "M",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(cx, seq_y + 58.0), str(rem_atk) + "A",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.6, 0.15))

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

	var skill_font_size: int = 26
	if char_config.use_unified_slots:
		# Unified slots: single row replacing both attack queue and skill slots
		var slot_count: int = char_config.skill_slot_count
		var total_slot_w: float = (slot_count - 1) * SEQ_STEP + SEQ_SIZE
		var slot_x0: float = (board_w - total_slot_w) / 2.0
		var slot_y: float = seq_y + SEQ_SIZE + ATK_QUEUE_GAP
		for i: int in slot_count:
			var sx: float = slot_x0 + i * SEQ_STEP
			var srect: Rect2 = Rect2(sx, slot_y, SEQ_SIZE, SEQ_SIZE)
			var is_armed: bool = skill_preview == i
			var slot_data: Array = skill_slots[i]
			if slot_data.size() == 3:
				draw_rect(srect, Color(0.08, 0.08, 0.18))
				draw_rect(srect, Color(0.65, 0.65, 1.0) if is_armed else Color(0.35, 0.35, 0.65),
					false, 2.5 if is_armed else 1.5)
				var stext_y: float = slot_y + (SEQ_SIZE + skill_font_size * 0.7) / 2.0 - 8.0
				var half: float = SEQ_SIZE / 2.0
				var col_a: Color = Color(1.0, 0.6, 0.15) if slot_data[2] else Color.WHITE
				draw_string(font, Vector2(sx, stext_y),
					CharacterData.DIR_ARROWS[slot_data[0]],
					HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_a)
				draw_string(font, Vector2(sx + half, stext_y),
					CharacterData.DIR_ARROWS[slot_data[1]],
					HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, Color(1.0, 0.6, 0.15))
				var stype: int = _classify(slot_data)
				draw_string(font, Vector2(sx, slot_y + SEQ_SIZE - 2.0),
					CharacterData.SKILL_TYPE_NAMES[stype],
					HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, 13, Color(0.75, 0.75, 1.0))
			elif slot_data.size() == 1:
				draw_rect(srect, Color(0.16, 0.09, 0.04) if is_armed else Color(0.10, 0.10, 0.13))
				draw_rect(srect, Color(1.0, 0.6, 0.15) if is_armed else Color(0.40, 0.25, 0.08),
					false, 2.5 if is_armed else 1.5)
				var atk_text_y: float = slot_y + (SEQ_SIZE + font_size * 0.7) / 2.0
				draw_string(font, Vector2(sx, atk_text_y), CharacterData.DIR_ARROWS[slot_data[0]],
					HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, Color(1.0, 0.6, 0.15))
			else:
				draw_rect(srect, Color(0.10, 0.10, 0.13))
				draw_rect(srect, Color(0.65, 0.65, 1.0) if is_armed else Color(0.30, 0.30, 0.35),
					false, 2.5 if is_armed else 1.5)
	else:
		# Skill slots (legacy)
		var skill_y: float
		if char_config.skill_mixed:
			skill_y = seq_y + SEQ_SIZE + SKILL_MARGIN_TOP
		else:
			# Attack queue row
			var atk_slots: int = char_config.attack_queue_cap
			var total_atk_w: float = (atk_slots - 1) * SEQ_STEP + SEQ_SIZE
			var atk_x0: float = (board_w - total_atk_w) / 2.0
			var atk_y: float = seq_y + SEQ_SIZE + ATK_QUEUE_GAP

			for i: int in atk_slots:
				var ax: float = atk_x0 + i * SEQ_STEP
				var arect: Rect2 = Rect2(ax, atk_y, SEQ_SIZE, SEQ_SIZE)
				var is_hl: bool = i == attack_queue_highlighted
				draw_rect(arect, Color(0.16, 0.09, 0.04) if is_hl else Color(0.10, 0.10, 0.13))
				draw_rect(arect, Color(1.0, 0.6, 0.15) if is_hl else Color(0.40, 0.25, 0.08), false,
					2.5 if is_hl else 1.5)
				if i < attack_queue.size():
					var atk_arrow: String = CharacterData.DIR_ARROWS[attack_queue[i]]
					var atk_text_y: float = atk_y + (SEQ_SIZE + font_size * 0.7) / 2.0
					draw_string(font, Vector2(ax, atk_text_y), atk_arrow,
						HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, Color(1.0, 0.6, 0.15))

			skill_y = atk_y + SEQ_SIZE + SKILL_MARGIN_TOP
		for i: int in char_config.skill_slot_count:
			var sx: float = i * SEQ_STEP
			var srect: Rect2 = Rect2(sx, skill_y, SEQ_SIZE, SEQ_SIZE)
			var is_previewing: bool = skill_preview == i
			draw_rect(srect, Color(0.08, 0.08, 0.18))
			draw_rect(srect, Color(0.65, 0.65, 1.0) if is_previewing else Color(0.35, 0.35, 0.65),
				false, 2.5 if is_previewing else 1.5)
			if not skill_slots[i].is_empty():
				var stext_y: float = skill_y + (SEQ_SIZE + skill_font_size * 0.7) / 2.0 - 8.0
				var half: float = SEQ_SIZE / 2.0
				var col_a: Color = Color(1.0, 0.6, 0.15) if (skill_slots[i].size() > 2 and skill_slots[i][2]) else Color.WHITE
				var col_b: Color = Color(1.0, 0.6, 0.15)
				draw_string(font, Vector2(sx, stext_y),
					CharacterData.DIR_ARROWS[skill_slots[i][0]],
					HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_a)
				draw_string(font, Vector2(sx + half, stext_y),
					CharacterData.DIR_ARROWS[skill_slots[i][1]],
					HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_b)
				var stype: int = _classify(skill_slots[i])
				var type_name: String = CharacterData.SKILL_TYPE_NAMES[stype]
				draw_string(font, Vector2(sx, skill_y + SEQ_SIZE - 2.0), type_name,
					HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, 13, Color(0.75, 0.75, 1.0))

	# Turn counter + kill count (right of board)
	var side_x: float = board_w + 28.0
	draw_string(font, Vector2(side_x, 26.0), "TURN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 66.0), str(turn),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	draw_string(font, Vector2(side_x, 100.0), "KILL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 140.0), str(kill_count),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1.0, 0.4, 0.4))

func _update_board_offset() -> void:
	var board_w: float = (COLS - 1) * CELL_STEP + CELL_SIZE
	var total_h: float
	if char_config != null and char_config.use_unified_slots:
		total_h = ROWS * CELL_STEP + SEQ_MARGIN_TOP + SEQ_SIZE + ATK_QUEUE_GAP + SEQ_SIZE
	else:
		total_h = ROWS * CELL_STEP + SEQ_MARGIN_TOP + SEQ_SIZE + ATK_QUEUE_GAP + SEQ_SIZE + SKILL_MARGIN_TOP + SEQ_SIZE
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2((vp.x - board_w) / 2.0, (vp.y - total_h) / 2.0)

func _classify(slot_data: Array) -> int:
	if char_config.use_rdr_classifier:
		return CharacterData.classify_skill_rdr(slot_data)
	return CharacterData.classify_skill(slot_data)

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

func _has_adjacent_enemy(p: Vector2i) -> bool:
	for dv: Vector2i in CharacterData.DIR_VECTOR.values():
		var n: Vector2i = p + dv
		if _in_bounds(n) and CharacterData.is_enemy(grid[n.y][n.x]):
			return true
	return false

func _remove_enemy(p: Vector2i) -> void:
	if not _in_bounds(p):
		return
	if CharacterData.is_enemy(grid[p.y][p.x]):
		grid[p.y][p.x] = CharacterData.CellType.LIVE
		kill_count += 1
		shield_spawn_turn.erase(p)

func _harden_old_shields() -> void:
	for pos: Vector2i in shield_spawn_turn.keys():
		if turn - shield_spawn_turn[pos] >= 2:
			var cell: int = grid[pos.y][pos.x]
			if CharacterData.is_enemy(cell) and not CharacterData.is_hard_shield(cell):
				grid[pos.y][pos.x] = CharacterData.harden_shield(cell)
			shield_spawn_turn.erase(pos)

# Hit with direction: respects shield (strip on shield side, kill on open side)
func _hit_cell(p: Vector2i, attack_dir: int) -> void:
	if not _in_bounds(p) or not CharacterData.is_enemy(grid[p.y][p.x]):
		return
	var cell: int = grid[p.y][p.x]
	var shield_dir: int = CharacterData.get_shield_dir(cell)
	if shield_dir != CharacterData.Direction.NONE and \
			CharacterData.DIR_VECTOR[attack_dir] + CharacterData.DIR_VECTOR[shield_dir] == Vector2i.ZERO:
		if not CharacterData.is_hard_shield(cell):
			grid[p.y][p.x] = CharacterData.CellType.ENEMY  # strip shield
			shield_spawn_turn.erase(p)
		# hard shield: absorb, do nothing
	else:
		grid[p.y][p.x] = CharacterData.CellType.LIVE
		kill_count += 1
		shield_spawn_turn.erase(p)
		if char_config.teleport_on_kill:
			player_pos = p
			bonus_moves += 1

func get_skill_preview_cells(slot: int) -> Dictionary:
	var result: Dictionary = {"move": [], "hit": []}
	if slot < 0 or slot >= char_config.skill_slot_count or skill_slots[slot].size() != 3:
		return result
	var slot_data: Array = skill_slots[slot]
	var stype: int = _classify(slot_data)
	var dv_seq: Vector2i = CharacterData.DIR_VECTOR[slot_data[0]]
	var dv_atk: Vector2i = CharacterData.DIR_VECTOR[slot_data[1]]
	var pos: Vector2i = player_pos
	match stype:
		CharacterData.SkillType.SAME_MA:
			result["move"].append(pos + dv_seq)
			result["hit"].append(pos + dv_seq)
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			result["move"].append(pos + dv_seq)
			result["hit"].append(pos + dv_seq + dv_atk)
		CharacterData.SkillType.SAME_AA:
			if _in_bounds(pos + dv_seq):
				result["hit"].append(pos + dv_seq)
			if _in_bounds(pos + 2 * dv_seq):
				result["hit"].append(pos + 2 * dv_seq)
		CharacterData.SkillType.ORTHO_AA:
			if _in_bounds(pos + dv_seq):
				result["hit"].append(pos + dv_seq)
			if _in_bounds(pos + dv_atk):
				result["hit"].append(pos + dv_atk)
		CharacterData.SkillType.RDR_DASH:
			var t: Vector2i = pos + 2 * dv_seq
			result["move"].append(t)
			result["hit"].append(t)
		CharacterData.SkillType.RDR_DIAG:
			var t: Vector2i = pos + dv_seq + dv_atk
			result["move"].append(t)
			result["hit"].append(t)
	return result

func set_skill_preview(slot: int) -> void:
	skill_preview = slot
	if _arrow_overlay:
		_arrow_overlay.queue_redraw()
	queue_redraw()

func rotate_armed_skill(new_dir: int) -> void:
	var slot: int = skill_preview
	if slot < 0 or slot >= char_config.skill_slot_count or skill_slots[slot].size() != 3:
		return
	var data: Array = skill_slots[slot].duplicate()
	var stype: int = _classify(data)
	if stype == CharacterData.SkillType.SAME_MA or stype == CharacterData.SkillType.SAME_AA:
		data[0] = new_dir
		data[1] = new_dir
	elif stype == CharacterData.SkillType.LEFT_MA or stype == CharacterData.SkillType.RIGHT_MA:
		# Any arrow sets the new forward; hook side (left/right relative to forward) is preserved.
		# LEFT_MA: atk = CW perp of forward = (dv.y, -dv.x)
		# RIGHT_MA: atk = CCW perp of forward = (-dv.y, dv.x)
		data[0] = new_dir
		var dv: Vector2i = CharacterData.DIR_VECTOR[new_dir]
		var atk_dv: Vector2i = Vector2i(dv.y, -dv.x) if stype == CharacterData.SkillType.LEFT_MA \
			else Vector2i(-dv.y, dv.x)
		for d: int in CharacterData.DIR_VECTOR:
			if CharacterData.DIR_VECTOR[d] == atk_dv:
				data[1] = d
				break
	elif stype == CharacterData.SkillType.RDR_DASH:
		data[0] = new_dir
		data[1] = new_dir
	elif stype == CharacterData.SkillType.RDR_DIAG:
		var new_is_h: bool = (new_dir == CharacterData.Direction.LEFT or new_dir == CharacterData.Direction.RIGHT)
		var d0_is_h: bool = (data[0] == CharacterData.Direction.LEFT or data[0] == CharacterData.Direction.RIGHT)
		if d0_is_h == new_is_h: data[0] = new_dir
		else: data[1] = new_dir
	else:
		# ORTHO_AA: axis-replacement (H key replaces H component, V key replaces V component)
		var new_is_h: bool = (new_dir == CharacterData.Direction.LEFT
			or new_dir == CharacterData.Direction.RIGHT)
		var d0_is_h: bool = (data[0] == CharacterData.Direction.LEFT
			or data[0] == CharacterData.Direction.RIGHT)
		if d0_is_h == new_is_h:
			data[0] = new_dir
		else:
			data[1] = new_dir
	skill_slots[slot] = data
	_refresh_visuals()

func use_skill(slot: int) -> void:
	if slot < 0 or slot >= char_config.skill_slot_count or skill_slots[slot].size() != 3:
		return
	var slot_data: Array = skill_slots[slot]
	var stype: int = _classify(slot_data)
	var dv_seq: Vector2i = CharacterData.DIR_VECTOR[slot_data[0]]
	var dv_atk: Vector2i = CharacterData.DIR_VECTOR[slot_data[1]]
	var pos: Vector2i = player_pos
	match stype:
		CharacterData.SkillType.SAME_MA:
			var move_target: Vector2i = pos + dv_seq
			if _in_bounds(move_target):
				if CharacterData.is_enemy(grid[move_target.y][move_target.x]):
					_hit_cell(move_target, slot_data[0])  # 第一擊：殺或破盾
					if CharacterData.is_enemy(grid[move_target.y][move_target.x]):
						# 盾被破，敵人仍在 → 推動
						var push_dest: Vector2i = move_target + dv_seq
						if not _in_bounds(push_dest) or CharacterData.is_enemy(grid[push_dest.y][push_dest.x]):
							_hit_cell(move_target, CharacterData.opposite_dir(slot_data[0]))  # 擠壓必殺
						else:
							grid[push_dest.y][push_dest.x] = grid[move_target.y][move_target.x]
							grid[move_target.y][move_target.x] = CharacterData.CellType.LIVE
							if shield_spawn_turn.has(move_target):
								shield_spawn_turn[push_dest] = shield_spawn_turn[move_target]
								shield_spawn_turn.erase(move_target)
				player_pos = move_target  # 流程後 move_target 必為空
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			var move_target: Vector2i = pos + dv_seq
			if _in_bounds(move_target) and grid[move_target.y][move_target.x] == CharacterData.CellType.LIVE:
				player_pos = move_target
				_hit_cell(player_pos + dv_atk, slot_data[1])
		CharacterData.SkillType.SAME_AA:
			_hit_cell(pos + dv_seq, slot_data[0])
			_hit_cell(pos + 2 * dv_seq, slot_data[0])
		CharacterData.SkillType.ORTHO_AA:
			_hit_cell(pos + dv_seq, slot_data[0])
			_hit_cell(pos + dv_atk, slot_data[1])
		CharacterData.SkillType.RDR_DASH:
			var move_target: Vector2i = pos + 2 * dv_seq
			if _in_bounds(move_target) and not CharacterData.is_enemy(grid[move_target.y][move_target.x]):
				player_pos = move_target
		CharacterData.SkillType.RDR_DIAG:
			var jump_dest: Vector2i = pos + dv_seq + dv_atk
			if _in_bounds(jump_dest) and not CharacterData.is_enemy(grid[jump_dest.y][jump_dest.x]):
				player_pos = jump_dest
	if stype == CharacterData.SkillType.RDR_DASH or stype == CharacterData.SkillType.RDR_DIAG:
		if _has_adjacent_enemy(player_pos):
			bonus_attacks += 1
	skill_slots[slot] = []
	_refresh_visuals()
