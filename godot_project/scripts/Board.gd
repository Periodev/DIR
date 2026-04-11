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
const ATK_QUEUE_GAP: float = 12.0
const SKILL_MARGIN_TOP: float = 20.0
const SKILL_SLOTS: int = 2

signal board_updated

var char_config: CharacterData.Config = null

var grid: Array[Array] = []
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var action_seq: Array[int] = []
var action_seq_is_attack: Array[bool] = []
var moves_this_turn: int = 0
var attacks_this_turn: int = 0
var turn: int = 1

var attack_queue: Array[int] = []
var attack_queue_highlighted: int = -1

var skill_slots: Array = [[], []]
var skill_preview: int = -1  # -1 = none, 0/1 = slot index being held

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

		# Skill preview highlight
		if board.skill_preview >= 0 and board.skill_preview < board.SKILL_SLOTS:
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
	attack_queue.clear()
	attack_queue_highlighted = -1
	skill_slots = [[], []]
	skill_preview = -1
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
	for i: int in action_seq.size():
		if action_seq_is_attack[i]:
			attack_queue.append(action_seq[i])
	while attack_queue.size() > char_config.max_attacks:
		attack_queue.pop_front()
	turn += 1
	action_seq.clear()
	action_seq_is_attack.clear()
	moves_this_turn = 0
	attacks_this_turn = 0
	_refresh_visuals()
	return true

func set_atk_highlight(slot: int) -> void:
	attack_queue_highlighted = -1 if attack_queue_highlighted == slot else slot
	queue_redraw()

func try_combine_skill() -> bool:
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
	for i: int in SKILL_SLOTS:
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

	# Attack queue row
	var atk_slots: int = char_config.max_attacks
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

	# Skill slots (bottom-left)
	var skill_y: float = atk_y + SEQ_SIZE + SKILL_MARGIN_TOP
	var skill_font_size: int = 26
	for i: int in SKILL_SLOTS:
		var sx: float = i * SEQ_STEP
		var srect: Rect2 = Rect2(sx, skill_y, SEQ_SIZE, SEQ_SIZE)
		var is_previewing: bool = skill_preview == i
		draw_rect(srect, Color(0.08, 0.08, 0.18))
		draw_rect(srect, Color(0.65, 0.65, 1.0) if is_previewing else Color(0.35, 0.35, 0.65),
			false, 2.5 if is_previewing else 1.5)
		if not skill_slots[i].is_empty():
			var stext_y: float = skill_y + (SEQ_SIZE + skill_font_size * 0.7) / 2.0 - 8.0
			var half: float = SEQ_SIZE / 2.0
			var col_a: Color = Color(1.0, 0.6, 0.15) if skill_slots[i][2] else Color.WHITE
			var col_b: Color = Color(1.0, 0.6, 0.15)
			draw_string(font, Vector2(sx, stext_y),
				CharacterData.DIR_ARROWS[skill_slots[i][0]],
				HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_a)
			draw_string(font, Vector2(sx + half, stext_y),
				CharacterData.DIR_ARROWS[skill_slots[i][1]],
				HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_b)
			var stype: int = CharacterData.classify_skill(skill_slots[i])
			var type_name: String = CharacterData.SKILL_TYPE_NAMES[stype]
			draw_string(font, Vector2(sx, skill_y + SEQ_SIZE - 2.0), type_name,
				HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, 13, Color(0.75, 0.75, 1.0))

	# Turn counter (right of board)
	var side_x: float = board_w + 28.0
	draw_string(font, Vector2(side_x, 26.0), "TURN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 66.0), str(turn),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)

func _update_board_offset() -> void:
	var board_w: float = (COLS - 1) * CELL_STEP + CELL_SIZE
	var total_h: float = ROWS * CELL_STEP + SEQ_MARGIN_TOP + SEQ_SIZE + ATK_QUEUE_GAP + SEQ_SIZE + SKILL_MARGIN_TOP + SEQ_SIZE
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2((vp.x - board_w) / 2.0, (vp.y - total_h) / 2.0)

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

func _remove_enemy(p: Vector2i) -> void:
	if not _in_bounds(p):
		return
	if grid[p.y][p.x] == CharacterData.CellType.ENEMY:
		grid[p.y][p.x] = CharacterData.CellType.LIVE

func get_skill_preview_cells(slot: int) -> Dictionary:
	var result: Dictionary = {"move": [], "hit": []}
	if slot < 0 or slot >= SKILL_SLOTS or skill_slots[slot].is_empty():
		return result
	var slot_data: Array = skill_slots[slot]
	var stype: int = CharacterData.classify_skill(slot_data)
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
			if _in_bounds(pos + dv_seq + dv_atk):
				result["hit"].append(pos + dv_seq + dv_atk)
	return result

func set_skill_preview(slot: int) -> void:
	skill_preview = slot
	if _arrow_overlay:
		_arrow_overlay.queue_redraw()
	queue_redraw()

func rotate_armed_skill(new_dir: int) -> void:
	var slot: int = skill_preview
	if slot < 0 or slot >= SKILL_SLOTS or skill_slots[slot].is_empty():
		return
	var data: Array = skill_slots[slot].duplicate()
	var stype: int = CharacterData.classify_skill(data)
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
	if slot < 0 or slot >= SKILL_SLOTS or skill_slots[slot].is_empty():
		return
	var slot_data: Array = skill_slots[slot]
	var stype: int = CharacterData.classify_skill(slot_data)
	var dv_seq: Vector2i = CharacterData.DIR_VECTOR[slot_data[0]]
	var dv_atk: Vector2i = CharacterData.DIR_VECTOR[slot_data[1]]
	var pos: Vector2i = player_pos
	match stype:
		CharacterData.SkillType.SAME_MA:
			_remove_enemy(pos + dv_seq)
			player_pos = pos + dv_seq
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			var move_target: Vector2i = pos + dv_seq
			if _in_bounds(move_target) and grid[move_target.y][move_target.x] == CharacterData.CellType.LIVE:
				player_pos = move_target
				_remove_enemy(player_pos + dv_atk)
		CharacterData.SkillType.SAME_AA:
			_remove_enemy(pos + dv_seq)
			_remove_enemy(pos + 2 * dv_seq)
		CharacterData.SkillType.ORTHO_AA:
			_remove_enemy(pos + dv_seq)
			_remove_enemy(pos + dv_atk)
			_remove_enemy(pos + dv_seq + dv_atk)
	skill_slots[slot] = []
	_refresh_visuals()
