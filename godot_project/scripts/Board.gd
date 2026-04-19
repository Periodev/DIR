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
const EXE_STAT_KEYS: Array[String] = ["pierce", "ram", "spin", "dual"]
const EXE_STAT_LABELS: Dictionary = {
	"pierce": "PEN",
	"ram": "RAM",
	"spin": "SPN",
	"dual": "DBL",
}

signal board_updated

enum SpawnMode { SEEDED, TRUE_RANDOM }

var char_config: CharacterData.Config = null
var _char_index: int = 0

var grid: Array[Array] = []
var polluted_grid: Array[Array] = []
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var action_seq: Array[int] = []
var action_seq_is_attack: Array[bool] = []
var action_seq_used_for_space: Array[bool] = []
var exe_pending_attack_slot: int = -1
var moves_this_turn: int = 0
var attacks_this_turn: int = 0
var bonus_moves: int = 0
var bonus_attacks: int = 0
var turn: int = 1
var avg_slot_sum: int = 0
var avg_slot_samples: int = 0
var step_move_count: int = 0
var step_attack_count: int = 0
var exe_skill_stats: Dictionary = {}

var attack_queue: Array[int] = []
var attack_queue_highlighted: int = -1

var skill_slots: Array = []
var skill_preview: int = -1
var kill_count: int = 0
var shield_spawn_turn: Dictionary = {}
var enemy_spawn_turn: Dictionary = {}
var enemy_pollution_dir: Dictionary = {}
var game_over: bool = false
var game_over_reason: String = ""

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_spawn_preview: Array = []
var _spawn_mode: int = SpawnMode.SEEDED
var _debug_skill_slot_override: int = -1

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
		var arrow_half: float = 26.0
		var head_arm: float = 18.0
		var line_w: float = 3.5
		var color: Color = Color(1.0, 0.6, 0.15, 0.95)
		var cols_: int = board.COLS
		var rows_: int = board.ROWS
		var cell_size_: float = board.CELL_SIZE
		var cell_gap_: float = board.CELL_GAP
		var cell_step_: float = board.CELL_STEP

		for dir_id: int in CharacterData.DIR_VECTOR:
			var dv: Vector2i = CharacterData.DIR_VECTOR[dir_id]
			var neighbor: Vector2i = board.player_pos + dv
			if neighbor.x < 0 or neighbor.x >= cols_ or neighbor.y < 0 or neighbor.y >= rows_:
				continue
			if not CharacterData.is_enemy(board.grid[neighbor.y][neighbor.x]):
				continue

			var dv_f: Vector2 = Vector2(float(dv.x), float(dv.y))
			var perp: Vector2 = Vector2(-dv_f.y, dv_f.x)
			var player_center: Vector2 = Vector2(
				board.player_pos.x * cell_step_ + cell_size_ / 2.0,
				board.player_pos.y * cell_step_ + cell_size_ / 2.0
			)
			var gap_center: Vector2 = player_center + dv_f * (cell_size_ / 2.0 + cell_gap_ / 2.0)
			var tail: Vector2 = gap_center - dv_f * arrow_half
			var tip: Vector2 = gap_center + dv_f * arrow_half
			var shaft_end: Vector2 = tip - dv_f * head_arm

			draw_line(tail, shaft_end, color, line_w, true)
			var top_pt: Vector2 = shaft_end - perp * head_arm
			var bot_pt: Vector2 = shaft_end + perp * head_arm
			draw_polyline(PackedVector2Array([top_pt, tip, bot_pt]), color, line_w, true)

		for entry: Dictionary in board._next_spawn_preview:
			var p: Vector2i = entry.get("pos", Vector2i.ZERO)
			var warn_font: Font = ThemeDB.fallback_font
			var warn_size: int = 42
			var warn_y: float = p.y * cell_step_ + (cell_size_ + warn_size * 0.7) / 2.0
			draw_string(
				warn_font,
				Vector2(p.x * cell_step_, warn_y),
				"!",
				HORIZONTAL_ALIGNMENT_CENTER,
				cell_size_,
				warn_size,
				Color(1.0, 0.35, 0.35, 0.95)
			)

		if board.skill_preview >= 0 and board.skill_preview < board.char_config.skill_slot_count:
			if not board.skill_slots[board.skill_preview].is_empty():
				var preview: Dictionary = board.get_skill_preview_cells(board.skill_preview)
				for p in preview.get("move", []):
					if p.x >= 0 and p.x < cols_ and p.y >= 0 and p.y < rows_:
						draw_rect(
							Rect2(p.x * cell_step_, p.y * cell_step_, cell_size_, cell_size_),
							Color(0.3, 0.8, 0.3, 0.35)
						)
				for p in preview.get("hit", []):
					if p.x >= 0 and p.x < cols_ and p.y >= 0 and p.y < rows_:
						draw_rect(
							Rect2(p.x * cell_step_, p.y * cell_step_, cell_size_, cell_size_),
							Color(1.0, 0.3, 0.3, 0.4)
						)

func _load_char_config() -> void:
	char_config = ([_EXE_SCRIPT, _RDR_SCRIPT][_char_index]).get_config()
	if _debug_skill_slot_override > 0:
		char_config.skill_slot_count = _debug_skill_slot_override

func switch_character() -> void:
	_char_index = (_char_index + 1) % 2
	restart()

func toggle_debug_skill_slots() -> void:
	_debug_skill_slot_override = -1 if _debug_skill_slot_override > 0 else 8
	restart()

func toggle_spawn_mode() -> void:
	_spawn_mode = SpawnMode.TRUE_RANDOM if _spawn_mode == SpawnMode.SEEDED else SpawnMode.SEEDED
	_compute_next_spawn_preview(_spawn_count_for_turn(turn + 1))
	_refresh_visuals()

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
	_rng.randomize()
	grid.clear()
	polluted_grid.clear()
	for _r: int in ROWS:
		var row: Array[int] = []
		var polluted_row: Array[bool] = []
		for _c: int in COLS:
			row.append(CharacterData.CellType.LIVE)
			polluted_row.append(false)
		grid.append(row)
		polluted_grid.append(polluted_row)
	player_pos = Vector2i(COLS / 2, ROWS / 2)
	action_seq.clear()
	action_seq_is_attack.clear()
	action_seq_used_for_space.clear()
	exe_pending_attack_slot = -1
	moves_this_turn = 0
	attacks_this_turn = 0
	bonus_moves = 0
	bonus_attacks = 0
	turn = 1
	avg_slot_sum = 0
	avg_slot_samples = 0
	step_move_count = 0
	step_attack_count = 0
	_reset_exe_skill_stats()
	attack_queue.clear()
	attack_queue_highlighted = -1
	skill_slots.resize(char_config.skill_slot_count)
	for i: int in char_config.skill_slot_count:
		skill_slots[i] = []
	skill_preview = -1
	kill_count = 0
	shield_spawn_turn.clear()
	enemy_spawn_turn.clear()
	enemy_pollution_dir.clear()
	game_over = false
	game_over_reason = ""
	_next_spawn_preview.clear()
	_refresh_visuals()

func is_polluted(pos: Vector2i) -> bool:
	return _in_bounds(pos) and polluted_grid[pos.y][pos.x]

func can_accept_input() -> bool:
	return not game_over

func can_combine_skill() -> bool:
	return not is_polluted(player_pos)

func is_basic_move_legal(from: Vector2i, dir: int, state: Dictionary = {}) -> bool:
	var target: Vector2i = from + CharacterData.DIR_VECTOR[dir]
	if not _in_bounds(target):
		return false
	var board_grid: Array = grid if state.is_empty() else state["grid"]
	return board_grid[target.y][target.x] == CharacterData.CellType.LIVE

func try_move(dir: int) -> bool:
	if game_over:
		return false
	if not _resolve_exe_pending_attack_default():
		return false
	if not char_config.use_exe_manual_slotting and action_seq.size() >= char_config.seq_slots:
		return false
	if moves_this_turn >= char_config.max_moves + bonus_moves:
		return false
	if not is_basic_move_legal(player_pos, dir):
		return false
	player_pos += CharacterData.DIR_VECTOR[dir]
	_append_action_step(dir, false)
	moves_this_turn += 1
	_record_step_stats(true, false)
	_refresh_visuals()
	return true

func try_attack(dir: int) -> bool:
	if game_over:
		return false
	if not _resolve_exe_pending_attack_default():
		return false
	if is_polluted(player_pos):
		return false
	if not char_config.use_exe_manual_slotting and action_seq.size() >= char_config.seq_slots:
		return false
	if attacks_this_turn >= char_config.max_attacks + bonus_attacks:
		return false
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = player_pos + dv
	if not _in_bounds(target):
		return false
	if not CharacterData.is_enemy(grid[target.y][target.x]):
		return false
	var shield_dir: int = CharacterData.get_shield_dir(grid[target.y][target.x])
	if shield_dir != CharacterData.Direction.NONE \
	and CharacterData.DIR_VECTOR[dir] + CharacterData.DIR_VECTOR[shield_dir] == Vector2i.ZERO:
		if not CharacterData.is_hard_shield(grid[target.y][target.x]):
			grid[target.y][target.x] = CharacterData.CellType.ENEMY
	else:
		_clear_enemy(target)
		if char_config.teleport_on_kill:
			player_pos = target
	var killed: bool = grid[target.y][target.x] == CharacterData.CellType.LIVE
	if char_config.use_exe_manual_slotting and killed:
		_record_exe_attack_vector(dir)
	elif not char_config.use_rdr_classifier or killed:
		_append_action_step(dir, true)
	attacks_this_turn += 1
	_record_step_stats(false, true)
	_refresh_visuals()
	return true

func try_end_turn() -> bool:
	if game_over:
		return false
	if not _resolve_exe_pending_attack_default():
		return false
	if char_config.use_unified_slots and not char_config.use_rdr_classifier and not char_config.use_exe_manual_slotting:
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
	action_seq_used_for_space.clear()
	moves_this_turn = 0
	attacks_this_turn = 0
	bonus_moves = 0
	bonus_attacks = 0
	_harden_old_shields()
	_spread_pollution()
	debug_spawn_enemies(_spawn_count_for_turn(turn))
	check_loss_state()
	_refresh_visuals()
	return true

func _count_occupied_skill_slots() -> int:
	var occupied: int = 0
	for slot_data: Array in skill_slots:
		if not slot_data.is_empty():
			occupied += 1
	return occupied

func _record_slot_usage_sample() -> void:
	avg_slot_sum += _count_occupied_skill_slots()
	avg_slot_samples += 1

func _record_step_stats(is_move: bool, is_attack: bool) -> void:
	if is_move:
		step_move_count += 1
	if is_attack:
		step_attack_count += 1
	_record_slot_usage_sample()

func _get_average_slot_usage() -> float:
	if avg_slot_samples <= 0:
		return 0.0
	return float(avg_slot_sum) / float(avg_slot_samples)

func _get_move_usage_ratio() -> float:
	var total_steps: int = step_move_count + step_attack_count
	if total_steps <= 0:
		return 0.0
	return float(step_move_count) / float(total_steps)

func _reset_exe_skill_stats() -> void:
	exe_skill_stats.clear()
	for key: String in EXE_STAT_KEYS:
		exe_skill_stats[key] = {
			"synth": 0,
			"cast": 0,
			"kills": 0,
			"recovery": 0,
		}

func _exe_skill_stat_key(stype: int) -> String:
	match stype:
		CharacterData.SkillType.SAME_AA:
			return "pierce"
		CharacterData.SkillType.SAME_MA:
			return "ram"
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			return "spin"
		CharacterData.SkillType.ORTHO_AA:
			return "dual"
		_:
			return ""

func _record_exe_skill_synthesis(slot_data: Array) -> void:
	if not char_config.use_exe_manual_slotting or slot_data.size() != 3:
		return
	var key: String = _exe_skill_stat_key(_classify(slot_data))
	if key.is_empty():
		return
	var stats: Dictionary = exe_skill_stats.get(key, {})
	stats["synth"] = int(stats.get("synth", 0)) + 1
	exe_skill_stats[key] = stats

func _record_exe_skill_cast(slot_data: Array, kills: int, recovery: int) -> void:
	if not char_config.use_exe_manual_slotting or slot_data.size() != 3:
		return
	var key: String = _exe_skill_stat_key(_classify(slot_data))
	if key.is_empty():
		return
	var stats: Dictionary = exe_skill_stats.get(key, {})
	stats["cast"] = int(stats.get("cast", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + kills
	stats["recovery"] = int(stats.get("recovery", 0)) + recovery
	exe_skill_stats[key] = stats

func _get_total_exe_skill_syntheses() -> int:
	var total: int = 0
	for key: String in EXE_STAT_KEYS:
		var stats: Dictionary = exe_skill_stats.get(key, {})
		total += int(stats.get("synth", 0))
	return total

func set_atk_highlight(slot: int) -> void:
	attack_queue_highlighted = -1 if attack_queue_highlighted == slot else slot
	queue_redraw()

func try_combine_skill() -> bool:
	if game_over:
		return false
	if not can_combine_skill():
		return false
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
	if CharacterData.DIR_VECTOR[dir_seq] + CharacterData.DIR_VECTOR[dir_atk] == Vector2i.ZERO:
		return false
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
	_record_slot_usage_sample()
	_refresh_visuals()
	return true

func _try_combine_skill_unified() -> bool:
	if char_config.use_rdr_classifier:
		return _try_store_rdr_skill_vector()
	if char_config.use_exe_manual_slotting:
		return _try_store_exe_skill_component()
	var slot_index: int = skill_preview
	if slot_index < 0 or slot_index >= char_config.skill_slot_count or skill_slots[slot_index].size() != 1:
		slot_index = -1
		for i: int in char_config.skill_slot_count:
			if skill_slots[i].size() == 1:
				slot_index = i
				break
	if slot_index < 0:
		return false
	if action_seq.is_empty():
		return false
	var dir_seq: int = action_seq[-1]
	var dir_atk: int = skill_slots[slot_index][0]
	if CharacterData.DIR_VECTOR[dir_seq] + CharacterData.DIR_VECTOR[dir_atk] == Vector2i.ZERO:
		return false
	skill_slots[slot_index] = [dir_seq, dir_atk, action_seq_is_attack[-1]]
	_record_slot_usage_sample()
	_refresh_visuals()
	return true

func _try_store_rdr_skill_vector() -> bool:
	if action_seq.is_empty():
		return false
	var used_index: int = action_seq.size() - 1
	if used_index < 0 or used_index >= action_seq_used_for_space.size() or action_seq_used_for_space[used_index]:
		return false
	var slot_index: int = skill_preview
	var slot_data: Array = []
	if slot_index >= 0 and slot_index < char_config.skill_slot_count:
		slot_data = skill_slots[slot_index]
	if slot_index < 0 or slot_index >= char_config.skill_slot_count or slot_data.size() >= 3:
		slot_index = -1
		for i: int in char_config.skill_slot_count:
			if skill_slots[i].is_empty():
				slot_index = i
				break
		if slot_index < 0:
			for i: int in char_config.skill_slot_count:
				if skill_slots[i].size() == 1:
					slot_index = i
					break
	if slot_index < 0:
		return false
	slot_data = skill_slots[slot_index]
	if slot_data.size() >= 3:
		return false
	var dir_seq: int = action_seq[-1]
	if slot_data.is_empty():
		skill_slots[slot_index] = [dir_seq]
		action_seq.remove_at(used_index)
		action_seq_is_attack.remove_at(used_index)
		action_seq_used_for_space.remove_at(used_index)
	elif slot_data.size() == 1:
		var dir_prev: int = slot_data[0]
		if CharacterData.DIR_VECTOR[dir_prev] + CharacterData.DIR_VECTOR[dir_seq] == Vector2i.ZERO:
			return false
		skill_slots[slot_index] = [dir_prev, dir_seq, false]
		action_seq_used_for_space[used_index] = true
	else:
		return false
	_record_slot_usage_sample()
	_refresh_visuals()
	return true

func _try_store_exe_skill_component() -> bool:
	if exe_pending_attack_slot >= 0:
		return _resolve_exe_pending_attack_with_space()
	if action_seq.is_empty():
		return false
	var used_index: int = action_seq.size() - 1
	if used_index < 0 or used_index >= action_seq_used_for_space.size() or action_seq_used_for_space[used_index]:
		return false
	var dir_seq: int = action_seq[-1]
	var latest_is_attack: bool = action_seq_is_attack[used_index]
	var slot_index: int = skill_preview
	if slot_index >= 0 and slot_index < char_config.skill_slot_count:
		if not _can_store_exe_skill_component(skill_slots[slot_index], dir_seq, latest_is_attack):
			return false
	else:
		slot_index = _find_exe_skill_slot(dir_seq, latest_is_attack)
		if slot_index < 0:
			return false
	var slot_data: Array = skill_slots[slot_index]
	if slot_data.is_empty():
		skill_slots[slot_index] = [dir_seq]
		action_seq.remove_at(used_index)
		action_seq_is_attack.remove_at(used_index)
		action_seq_used_for_space.remove_at(used_index)
	elif slot_data.size() == 1:
		var dir_prev: int = slot_data[0]
		skill_slots[slot_index] = [dir_seq, dir_prev, latest_is_attack]
		_record_exe_skill_synthesis(skill_slots[slot_index])
		action_seq_used_for_space[used_index] = true
	else:
		return false
	_record_slot_usage_sample()
	_refresh_visuals()
	return true

func _record_exe_attack_vector(dir_seq: int) -> void:
	var empty_slot: int = _first_empty_skill_slot()
	if empty_slot >= 0 and _has_existing_exe_attack_record():
		_append_action_step(dir_seq, true)
		exe_pending_attack_slot = empty_slot
		return
	if empty_slot >= 0:
		skill_slots[empty_slot] = [dir_seq]
		return
	_append_action_step(dir_seq, true)

func _resolve_exe_pending_attack_default() -> bool:
	if exe_pending_attack_slot < 0:
		return true
	if exe_pending_attack_slot >= char_config.skill_slot_count:
		exe_pending_attack_slot = -1
		return false
	var used_index: int = action_seq.size() - 1
	if used_index < 0 or not action_seq_is_attack[used_index]:
		exe_pending_attack_slot = -1
		return true
	if not skill_slots[exe_pending_attack_slot].is_empty():
		exe_pending_attack_slot = -1
		return false
	skill_slots[exe_pending_attack_slot] = [action_seq[used_index]]
	action_seq.remove_at(used_index)
	action_seq_is_attack.remove_at(used_index)
	action_seq_used_for_space.remove_at(used_index)
	exe_pending_attack_slot = -1
	return true

func _resolve_exe_pending_attack_with_space() -> bool:
	var used_index: int = action_seq.size() - 1
	if used_index < 0 or not action_seq_is_attack[used_index]:
		exe_pending_attack_slot = -1
		return false
	var dir_seq: int = action_seq[used_index]
	var slot_index: int = skill_preview
	if slot_index >= 0 and slot_index < char_config.skill_slot_count and skill_slots[slot_index].size() == 1:
		var dir_prev: int = skill_slots[slot_index][0]
		if CharacterData.DIR_VECTOR[dir_prev] + CharacterData.DIR_VECTOR[dir_seq] == Vector2i.ZERO:
			return false
		skill_slots[slot_index] = [dir_seq, dir_prev, true]
		_record_exe_skill_synthesis(skill_slots[slot_index])
		action_seq.remove_at(used_index)
		action_seq_is_attack.remove_at(used_index)
		action_seq_used_for_space.remove_at(used_index)
		exe_pending_attack_slot = -1
		_refresh_visuals()
		return true
	if not _resolve_exe_pending_attack_default():
		return false
	_refresh_visuals()
	return true

func _first_empty_skill_slot() -> int:
	for i: int in char_config.skill_slot_count:
		if skill_slots[i].is_empty():
			return i
	return -1

func _append_action_step(dir_seq: int, is_attack: bool) -> void:
	if char_config.use_exe_manual_slotting:
		while action_seq.size() >= char_config.seq_slots:
			action_seq.remove_at(0)
			action_seq_is_attack.remove_at(0)
			action_seq_used_for_space.remove_at(0)
	action_seq.append(dir_seq)
	action_seq_is_attack.append(is_attack)
	action_seq_used_for_space.append(false)

func _has_existing_exe_attack_record() -> bool:
	for slot_data: Array in skill_slots:
		if slot_data.size() == 1:
			return true
	for i: int in action_seq.size():
		if i < action_seq_used_for_space.size() and action_seq_used_for_space[i]:
			continue
		if action_seq_is_attack[i]:
			return true
	return false

func _draw_dashed_rect_outline(rect: Rect2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.position.x + rect.size.x
	var bottom: float = rect.position.y + rect.size.y
	var x: float = left
	while x < right:
		var seg_end_x: float = min(x + dash_len, right)
		draw_line(Vector2(x, top), Vector2(seg_end_x, top), color, width, true)
		draw_line(Vector2(x, bottom), Vector2(seg_end_x, bottom), color, width, true)
		x += dash_len + gap_len
	var y: float = top
	while y < bottom:
		var seg_end_y: float = min(y + dash_len, bottom)
		draw_line(Vector2(left, y), Vector2(left, seg_end_y), color, width, true)
		draw_line(Vector2(right, y), Vector2(right, seg_end_y), color, width, true)
		y += dash_len + gap_len

func _get_exe_latest_move_index() -> int:
	for i: int in range(action_seq.size() - 1, -1, -1):
		var is_pending_attack: bool = exe_pending_attack_slot >= 0 and i == action_seq.size() - 1 and i < action_seq_is_attack.size() and action_seq_is_attack[i]
		if is_pending_attack:
			continue
		if i < action_seq_is_attack.size() and not action_seq_is_attack[i]:
			if i < action_seq_used_for_space.size() and action_seq_used_for_space[i]:
				return -1
			return i
	return -1

func _get_exe_temp_attack_index() -> int:
	if exe_pending_attack_slot >= 0 and not action_seq.is_empty():
		var pending_index: int = action_seq.size() - 1
		if pending_index < action_seq_is_attack.size() and action_seq_is_attack[pending_index]:
			return pending_index
	for i: int in range(action_seq.size() - 1, -1, -1):
		if i < action_seq_is_attack.size() and action_seq_is_attack[i]:
			if i < action_seq_used_for_space.size() and action_seq_used_for_space[i]:
				return -1
			return i
	return -1

func _find_exe_skill_slot(dir_seq: int, latest_is_attack: bool) -> int:
	if latest_is_attack:
		for i: int in char_config.skill_slot_count:
			if skill_slots[i].is_empty():
				return i
	for i: int in char_config.skill_slot_count:
		if _can_store_exe_skill_component(skill_slots[i], dir_seq, latest_is_attack):
			return i
	return -1

func _can_store_exe_skill_component(slot_data: Array, dir_seq: int, latest_is_attack: bool) -> bool:
	if slot_data.size() >= 3:
		return false
	if slot_data.is_empty():
		return latest_is_attack
	if slot_data.size() != 1:
		return false
	var dir_prev: int = slot_data[0]
	if CharacterData.DIR_VECTOR[dir_prev] + CharacterData.DIR_VECTOR[dir_seq] == Vector2i.ZERO:
		return false
	return true

func _try_combine_skill_mixed() -> bool:
	if action_seq.size() < 2:
		return false
	var dir1: int = action_seq[-2]
	var dir2: int = action_seq[-1]
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

func _spawn_order(seed: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	for r: int in ROWS:
		for c: int in COLS:
			all.append(Vector2i(c, r))
	if _spawn_mode == SpawnMode.SEEDED:
		_rng.seed = seed
	for i: int in range(all.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Vector2i = all[i]
		all[i] = all[j]
		all[j] = tmp
	return all

func _spawn_count_for_turn(spawn_turn: int) -> int:
	return 2 if spawn_turn <= 2 else 3

func _build_spawn_preview(count: int, seed: int) -> Array:
	var result: Array = []
	var order: Array[Vector2i] = _spawn_order(seed)
	for pos: Vector2i in order:
		if result.size() >= count:
			break
		if pos != player_pos and grid[pos.y][pos.x] == CharacterData.CellType.LIVE:
			result.append({
				"pos": pos,
			})
	return result

func debug_spawn_enemies(count: int) -> void:
	if _next_spawn_preview.is_empty():
		_next_spawn_preview = _build_spawn_preview(count, turn)
	for entry: Dictionary in _next_spawn_preview:
		var pos: Vector2i = entry.get("pos", Vector2i.ZERO)
		if pos != player_pos and grid[pos.y][pos.x] == CharacterData.CellType.LIVE:
			grid[pos.y][pos.x] = CharacterData.CellType.ENEMY
			enemy_spawn_turn[pos] = turn
			enemy_pollution_dir[pos] = CharacterData.dominant_cardinal(player_pos - pos)
	_compute_next_spawn_preview(count)
	_refresh_visuals()

func _compute_next_spawn_preview(count: int) -> void:
	_next_spawn_preview = _build_spawn_preview(count, turn + 1)

func _refresh_visuals() -> void:
	for r: int in ROWS:
		for c: int in COLS:
			var pos: Vector2i = Vector2i(c, r)
			cell_nodes[r][c].set_type(grid[r][c])
			cell_nodes[r][c].set_polluted(polluted_grid[r][c])
			cell_nodes[r][c].set_pollution_warning(_is_enemy_pollution_warning(pos))
			cell_nodes[r][c].set_pollution_dir(_enemy_pollution_direction(pos))
			cell_nodes[r][c].set_pollution_target_preview(_is_pollution_target_preview(pos))
			cell_nodes[r][c].set_player(pos == player_pos)
	queue_redraw()
	if _arrow_overlay:
		_arrow_overlay.queue_redraw()
	board_updated.emit()

func _is_enemy_pollution_warning(pos: Vector2i) -> bool:
	if not enemy_spawn_turn.has(pos):
		return false
	if not _in_bounds(pos) or not CharacterData.is_enemy(grid[pos.y][pos.x]):
		return false
	return turn - int(enemy_spawn_turn[pos]) == 0

func _enemy_pollution_direction(pos: Vector2i) -> int:
	if not enemy_pollution_dir.has(pos):
		return CharacterData.Direction.NONE
	if not _in_bounds(pos) or not CharacterData.is_enemy(grid[pos.y][pos.x]):
		return CharacterData.Direction.NONE
	return int(enemy_pollution_dir[pos])

func _is_pollution_target_preview(pos: Vector2i) -> bool:
	for source in enemy_pollution_dir.keys():
		var src: Vector2i = source
		if not _in_bounds(src) or not CharacterData.is_enemy(grid[src.y][src.x]):
			continue
		if not _is_enemy_pollution_warning(src):
			continue
		var dir_id: int = int(enemy_pollution_dir[src])
		if dir_id == CharacterData.Direction.NONE:
			continue
		if src + CharacterData.DIR_VECTOR[dir_id] == pos:
			return true
	return false

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 32
	var slots: int = char_config.seq_slots
	var board_w: float = (COLS - 1) * CELL_STEP + CELL_SIZE
	var total_seq_w: float = (slots - 1) * SEQ_STEP + SEQ_SIZE
	var seq_x0: float = (board_w - total_seq_w) / 2.0
	var base_ui_y: float = ROWS * CELL_STEP + SEQ_MARGIN_TOP
	var seq_y: float

	var rem_moves: int = char_config.max_moves + bonus_moves - moves_this_turn
	var rem_atk: int = char_config.max_attacks + bonus_attacks - attacks_this_turn
	var avg_slot_usage: float = _get_average_slot_usage()
	var move_usage_ratio: float = _get_move_usage_ratio()
	var skill_font_size: int = 26
	var exe_slot_x0: float = 0.0
	var exe_slot_y: float = base_ui_y
	if char_config.use_unified_slots:
		var slot_count: int = char_config.skill_slot_count
		var total_slot_w: float = (slot_count - 1) * SEQ_STEP + SEQ_SIZE
		var slot_x0: float = (board_w - total_slot_w) / 2.0
		if char_config.use_exe_manual_slotting:
			slot_x0 += 24.0
		var slot_y: float = base_ui_y
		exe_slot_x0 = slot_x0
		exe_slot_y = slot_y
		seq_y = slot_y + SEQ_SIZE + ATK_QUEUE_GAP
		for i: int in slot_count:
			var sx: float = slot_x0 + i * SEQ_STEP
			var srect: Rect2 = Rect2(sx, slot_y, SEQ_SIZE, SEQ_SIZE)
			var is_armed: bool = skill_preview == i
			var slot_data: Array = skill_slots[i]
			var is_exe_pending_slot: bool = char_config.use_exe_manual_slotting and i == exe_pending_attack_slot
			if slot_data.size() == 3:
				draw_rect(srect, Color(0.08, 0.08, 0.18))
				draw_rect(srect, Color(0.65, 0.65, 1.0) if is_armed else Color(0.35, 0.35, 0.65),
					false, 2.5 if is_armed else 1.5)
				var stext_y: float = slot_y + (SEQ_SIZE + skill_font_size * 0.7) / 2.0 - 8.0
				var half: float = SEQ_SIZE / 2.0
				var col_a: Color = Color(1.0, 0.6, 0.15) if slot_data[2] else Color.WHITE
				draw_string(font, Vector2(sx, stext_y), CharacterData.DIR_ARROWS[slot_data[0]],
					HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_a)
				draw_string(font, Vector2(sx + half, stext_y), CharacterData.DIR_ARROWS[slot_data[1]],
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
			elif is_exe_pending_slot and not action_seq.is_empty():
				draw_rect(srect, Color(0.10, 0.10, 0.13))
				_draw_dashed_rect_outline(srect, Color(1.0, 0.65, 0.2, 0.95), 2.0, 10.0, 6.0)
			else:
				draw_rect(srect, Color(0.10, 0.10, 0.13))
				draw_rect(srect, Color(0.65, 0.65, 1.0) if is_armed else Color(0.30, 0.30, 0.35),
					false, 2.5 if is_armed else 1.5)
	else:
		var skill_y: float
		if char_config.skill_mixed:
			skill_y = base_ui_y
			seq_y = skill_y + SEQ_SIZE + SKILL_MARGIN_TOP
		else:
			skill_y = base_ui_y
			var atk_slots: int = char_config.attack_queue_cap
			var total_atk_w: float = (atk_slots - 1) * SEQ_STEP + SEQ_SIZE
			var atk_x0: float = (board_w - total_atk_w) / 2.0
			var atk_y: float = skill_y + SEQ_SIZE + SKILL_MARGIN_TOP
			for i: int in atk_slots:
				var ax: float = atk_x0 + i * SEQ_STEP
				var arect: Rect2 = Rect2(ax, atk_y, SEQ_SIZE, SEQ_SIZE)
				var is_hl: bool = i == attack_queue_highlighted
				draw_rect(arect, Color(0.16, 0.09, 0.04) if is_hl else Color(0.10, 0.10, 0.13))
				draw_rect(arect, Color(1.0, 0.6, 0.15) if is_hl else Color(0.40, 0.25, 0.08),
					false, 2.5 if is_hl else 1.5)
				if i < attack_queue.size():
					var atk_arrow: String = CharacterData.DIR_ARROWS[attack_queue[i]]
					var atk_text_y: float = atk_y + (SEQ_SIZE + font_size * 0.7) / 2.0
					draw_string(font, Vector2(ax, atk_text_y), atk_arrow,
						HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, Color(1.0, 0.6, 0.15))
			seq_y = atk_y + SEQ_SIZE + ATK_QUEUE_GAP
		for i: int in char_config.skill_slot_count:
			var sx: float = i * SEQ_STEP
			var srect: Rect2 = Rect2(sx, skill_y, SEQ_SIZE, SEQ_SIZE)
			var is_previewing: bool = skill_preview == i
			draw_rect(srect, Color(0.08, 0.08, 0.18))
			draw_rect(srect, Color(0.65, 0.65, 1.0) if is_previewing else Color(0.35, 0.35, 0.65),
				false, 2.5 if is_previewing else 1.5)
			if not skill_slots[i].is_empty():
				var stext_y: float = skill_y + (SEQ_SIZE + skill_font_size * 0.7) / 2.0 - 8.0
				var half2: float = SEQ_SIZE / 2.0
				var col_a2: Color = Color(1.0, 0.6, 0.15) if (skill_slots[i].size() > 2 and skill_slots[i][2]) else Color.WHITE
				draw_string(font, Vector2(sx, stext_y), CharacterData.DIR_ARROWS[skill_slots[i][0]],
					HORIZONTAL_ALIGNMENT_CENTER, half2, skill_font_size, col_a2)
				draw_string(font, Vector2(sx + half2, stext_y), CharacterData.DIR_ARROWS[skill_slots[i][1]],
					HORIZONTAL_ALIGNMENT_CENTER, half2, skill_font_size, Color(1.0, 0.6, 0.15))
				var stype2: int = _classify(skill_slots[i])
				draw_string(font, Vector2(sx, skill_y + SEQ_SIZE - 2.0),
					CharacterData.SKILL_TYPE_NAMES[stype2],
					HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, 13, Color(0.75, 0.75, 1.0))

	if char_config.use_exe_manual_slotting:
		var temp_x: float = exe_slot_x0 - SEQ_STEP
		var action_x: float = seq_x0
		var temp_size: float = SEQ_SIZE + 10.0
		var temp_rect: Rect2 = Rect2(temp_x - 5.0, exe_slot_y - 5.0, temp_size, temp_size)
		var action_rect: Rect2 = Rect2(action_x, seq_y, SEQ_SIZE, SEQ_SIZE)
		var temp_index: int = _get_exe_temp_attack_index()
		var move_index: int = _get_exe_latest_move_index()
		draw_rect(temp_rect, Color(0.10, 0.10, 0.13))
		draw_rect(action_rect, Color(0.10, 0.10, 0.13))
		if temp_index >= 0:
			_draw_dashed_rect_outline(temp_rect, Color(1.0, 0.65, 0.2, 0.95), 2.0, 10.0, 6.0)
			var temp_y: float = temp_rect.position.y + (temp_rect.size.y + font_size * 0.7) / 2.0
			var temp_col: Color = Color(1.0, 0.72, 0.4, 0.65)
			draw_string(font, Vector2(temp_rect.position.x, temp_y), CharacterData.DIR_ARROWS[action_seq[temp_index]],
				HORIZONTAL_ALIGNMENT_CENTER, temp_rect.size.x, font_size, temp_col)
		if move_index >= 0:
			draw_rect(action_rect, Color(0.30, 0.30, 0.35), false, 1.5)
			var move_y: float = seq_y + (SEQ_SIZE + font_size * 0.7) / 2.0
			draw_string(font, Vector2(action_x, move_y), CharacterData.DIR_ARROWS[action_seq[move_index]],
				HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, Color.WHITE)
	else:
		for i: int in slots:
			var x: float = seq_x0 + i * SEQ_STEP
			var rect: Rect2 = Rect2(x, seq_y, SEQ_SIZE, SEQ_SIZE)
			draw_rect(rect, Color(0.10, 0.10, 0.13))
			var is_hidden_used: bool = i < action_seq_used_for_space.size() and action_seq_used_for_space[i]
			if not is_hidden_used:
				draw_rect(rect, Color(0.30, 0.30, 0.35), false, 1.5)
			if i < action_seq.size() and not is_hidden_used:
				var arrow: String = CharacterData.DIR_ARROWS[action_seq[i]]
				var text_y: float = seq_y + (SEQ_SIZE + font_size * 0.7) / 2.0
				var col: Color = Color(1.0, 0.6, 0.15) if action_seq_is_attack[i] else Color.WHITE
				draw_string(font, Vector2(x, text_y), arrow,
					HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, col)

	var bottom_stat_x: float = 8.0
	var bottom_stat_y: float = seq_y + SEQ_SIZE + 30.0
	draw_string(font, Vector2(bottom_stat_x, bottom_stat_y), str(rem_moves) + "M",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(bottom_stat_x, bottom_stat_y + 30.0), str(rem_atk) + "A",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.6, 0.15))
	if is_polluted(player_pos):
		draw_string(font, Vector2(bottom_stat_x, bottom_stat_y + 60.0), "NO BASIC ATK / NO COMBINE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.9, 0.4))

	var threat: Dictionary = score_pollution_threat()
	var side_x: float = board_w + 28.0
	draw_string(font, Vector2(side_x, 26.0), "TURN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 66.0), str(turn),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	draw_string(font, Vector2(side_x, 94.0), "SPAWN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 118.0), "SEEDED" if _spawn_mode == SpawnMode.SEEDED else "RANDOM",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.95))
	draw_string(font, Vector2(side_x, 152.0), "KILL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 192.0), str(kill_count),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1.0, 0.4, 0.4))
	draw_string(font, Vector2(side_x, 226.0), "THREAT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 266.0), str(threat["score"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.45, 0.9, 0.45))
	draw_string(font, Vector2(side_x, 300.0), "AVG SLOT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 340.0), "%.1f" % avg_slot_usage,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.95, 0.9, 0.55))
	draw_string(font, Vector2(side_x, 374.0), "MOVE%",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 414.0), "%.0f%%" % (move_usage_ratio * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.85, 0.95, 1.0))
	if char_config.use_exe_manual_slotting:
		var total_synth: int = _get_total_exe_skill_syntheses()
		draw_string(font, Vector2(side_x, 454.0), "EXE SKILL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(side_x, 478.0), "SKL S% K R%",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.75))
		for i: int in EXE_STAT_KEYS.size():
			var key: String = EXE_STAT_KEYS[i]
			var stats: Dictionary = exe_skill_stats.get(key, {})
			var synth: int = int(stats.get("synth", 0))
			var cast: int = int(stats.get("cast", 0))
			var kills: int = int(stats.get("kills", 0))
			var recovery: int = int(stats.get("recovery", 0))
			var synth_pct: int = 0 if total_synth <= 0 else int(round(float(synth) * 100.0 / float(total_synth)))
			var avg_kills: float = 0.0 if cast <= 0 else float(kills) / float(cast)
			var recovery_pct: int = 0 if cast <= 0 else int(round(float(recovery) * 50.0 / float(cast)))
			var row_text: String = "%s %2d %.1f %2d" % [
				EXE_STAT_LABELS[key],
				synth_pct,
				avg_kills,
				recovery_pct,
			]
			draw_string(font, Vector2(side_x, 500.0 + i * 18.0), row_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.95))
	if game_over:
		draw_rect(Rect2(-14.0, -14.0, board_w + 160.0, ROWS * CELL_STEP + 30.0), Color(0, 0, 0, 0.35))
		draw_string(font, Vector2(board_w * 0.15, ROWS * CELL_STEP * 0.48), "FAILED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.4, 0.4))
		draw_string(font, Vector2(board_w * 0.15, ROWS * CELL_STEP * 0.48 + 34.0), game_over_reason,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 0.95))

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

func _clear_enemy(p: Vector2i) -> void:
	if not _in_bounds(p):
		return
	if CharacterData.is_enemy(grid[p.y][p.x]):
		grid[p.y][p.x] = CharacterData.CellType.LIVE
		kill_count += 1
		shield_spawn_turn.erase(p)
		enemy_spawn_turn.erase(p)
		enemy_pollution_dir.erase(p)

func _move_enemy_data(from: Vector2i, to: Vector2i) -> void:
	if shield_spawn_turn.has(from):
		shield_spawn_turn[to] = shield_spawn_turn[from]
		shield_spawn_turn.erase(from)
	if enemy_spawn_turn.has(from):
		enemy_spawn_turn[to] = enemy_spawn_turn[from]
		enemy_spawn_turn.erase(from)
	if enemy_pollution_dir.has(from):
		enemy_pollution_dir[to] = enemy_pollution_dir[from]
		enemy_pollution_dir.erase(from)

func _harden_old_shields() -> void:
	for pos: Vector2i in shield_spawn_turn.keys():
		if turn - shield_spawn_turn[pos] >= 2:
			var cell: int = grid[pos.y][pos.x]
			if CharacterData.is_enemy(cell) and not CharacterData.is_hard_shield(cell):
				grid[pos.y][pos.x] = CharacterData.harden_shield(cell)
			shield_spawn_turn.erase(pos)

func _spread_pollution() -> void:
	for pos: Vector2i in enemy_spawn_turn.keys():
		if not _in_bounds(pos):
			continue
		if CharacterData.is_enemy(grid[pos.y][pos.x]) and turn - int(enemy_spawn_turn[pos]) >= 1:
			polluted_grid[pos.y][pos.x] = true
			if enemy_pollution_dir.has(pos):
				var dir_id: int = int(enemy_pollution_dir[pos])
				if dir_id != CharacterData.Direction.NONE:
					var target: Vector2i = pos + CharacterData.DIR_VECTOR[dir_id]
					if _in_bounds(target):
						polluted_grid[target.y][target.x] = true

func _hit_cell(p: Vector2i, attack_dir: int) -> void:
	if not _in_bounds(p) or not CharacterData.is_enemy(grid[p.y][p.x]):
		return
	var cell: int = grid[p.y][p.x]
	var shield_dir: int = CharacterData.get_shield_dir(cell)
	if shield_dir != CharacterData.Direction.NONE \
	and CharacterData.DIR_VECTOR[attack_dir] + CharacterData.DIR_VECTOR[shield_dir] == Vector2i.ZERO:
		if not CharacterData.is_hard_shield(cell):
			grid[p.y][p.x] = CharacterData.CellType.ENEMY
			shield_spawn_turn.erase(p)
	else:
		_clear_enemy(p)
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
			var dash_target: Vector2i = pos + 2 * dv_seq
			result["move"].append(dash_target)
			result["hit"].append(dash_target)
		CharacterData.SkillType.RDR_DIAG:
			var diag_target: Vector2i = pos + dv_seq + dv_atk
			result["move"].append(diag_target)
			result["hit"].append(diag_target)
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
		var new_is_h: bool = new_dir == CharacterData.Direction.LEFT or new_dir == CharacterData.Direction.RIGHT
		var d0_is_h: bool = data[0] == CharacterData.Direction.LEFT or data[0] == CharacterData.Direction.RIGHT
		if d0_is_h == new_is_h:
			data[0] = new_dir
		else:
			data[1] = new_dir
	else:
		var new_is_h2: bool = new_dir == CharacterData.Direction.LEFT or new_dir == CharacterData.Direction.RIGHT
		var d0_is_h2: bool = data[0] == CharacterData.Direction.LEFT or data[0] == CharacterData.Direction.RIGHT
		if d0_is_h2 == new_is_h2:
			data[0] = new_dir
		else:
			data[1] = new_dir
	skill_slots[slot] = data
	_refresh_visuals()

func use_skill(slot: int) -> void:
	if game_over:
		return
	if slot < 0 or slot >= char_config.skill_slot_count or skill_slots[slot].size() != 3:
		return
	var cast_skill: Array = skill_slots[slot].duplicate()
	var live_state: Dictionary = {
		"grid": grid,
		"polluted_grid": polluted_grid,
		"player_pos": player_pos,
		"shield_spawn_turn": shield_spawn_turn,
		"enemy_spawn_turn": enemy_spawn_turn,
		"enemy_pollution_dir": enemy_pollution_dir,
		"kill_delta": 0,
		"bonus_moves_delta": 0,
		"recovered_dirs": [],
		"player_moved": false,
	}
	_apply_skill_to_state(live_state, skill_slots[slot])
	grid = live_state["grid"]
	polluted_grid = live_state["polluted_grid"]
	player_pos = live_state["player_pos"]
	shield_spawn_turn = live_state["shield_spawn_turn"]
	enemy_spawn_turn = live_state["enemy_spawn_turn"]
	enemy_pollution_dir = live_state["enemy_pollution_dir"]
	kill_count += int(live_state["kill_delta"])
	bonus_moves += int(live_state["bonus_moves_delta"])
	if char_config.use_rdr_classifier:
		bonus_attacks += 1
	_record_exe_skill_cast(cast_skill, int(live_state["kill_delta"]), live_state["recovered_dirs"].size())
	skill_slots[slot] = []
	if char_config.use_exe_manual_slotting:
		_apply_recovered_dirs_to_slots(live_state["recovered_dirs"])
	_record_step_stats(false, true)
	_refresh_visuals()

func _board_state() -> Dictionary:
	return {
		"grid": _duplicate_grid(grid),
		"polluted_grid": _duplicate_bool_grid(polluted_grid),
		"player_pos": player_pos,
		"shield_spawn_turn": shield_spawn_turn.duplicate(true),
		"enemy_spawn_turn": enemy_spawn_turn.duplicate(true),
		"enemy_pollution_dir": enemy_pollution_dir.duplicate(true),
		"kill_delta": 0,
		"bonus_moves_delta": 0,
		"recovered_dirs": [],
		"player_moved": false,
	}

func _duplicate_grid(source: Array) -> Array:
	var copy: Array = []
	for row: Array in source:
		copy.append(row.duplicate())
	return copy

func _duplicate_bool_grid(source: Array) -> Array:
	var copy: Array = []
	for row: Array in source:
		copy.append(row.duplicate())
	return copy

func _state_in_bounds(p: Vector2i, state: Dictionary) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS

func _state_cell_is_enemy(state: Dictionary, p: Vector2i) -> bool:
	return _state_in_bounds(p, state) and CharacterData.is_enemy(state["grid"][p.y][p.x])

func _state_is_polluted(state: Dictionary, p: Vector2i) -> bool:
	return _state_in_bounds(p, state) and state["polluted_grid"][p.y][p.x]

func _state_clear_enemy(state: Dictionary, p: Vector2i) -> void:
	if not _state_cell_is_enemy(state, p):
		return
	state["grid"][p.y][p.x] = CharacterData.CellType.LIVE
	state["shield_spawn_turn"].erase(p)
	state["enemy_spawn_turn"].erase(p)
	state["enemy_pollution_dir"].erase(p)
	state["kill_delta"] += 1

func _state_move_enemy_data(state: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if state["shield_spawn_turn"].has(from):
		state["shield_spawn_turn"][to] = state["shield_spawn_turn"][from]
		state["shield_spawn_turn"].erase(from)
	if state["enemy_spawn_turn"].has(from):
		state["enemy_spawn_turn"][to] = state["enemy_spawn_turn"][from]
		state["enemy_spawn_turn"].erase(from)
	if state["enemy_pollution_dir"].has(from):
		state["enemy_pollution_dir"][to] = state["enemy_pollution_dir"][from]
		state["enemy_pollution_dir"].erase(from)

func _state_hit_cell(state: Dictionary, p: Vector2i, attack_dir: int) -> void:
	if not _state_cell_is_enemy(state, p):
		return
	var cell: int = state["grid"][p.y][p.x]
	var shield_dir: int = CharacterData.get_shield_dir(cell)
	if shield_dir != CharacterData.Direction.NONE \
	and CharacterData.DIR_VECTOR[attack_dir] + CharacterData.DIR_VECTOR[shield_dir] == Vector2i.ZERO:
		if not CharacterData.is_hard_shield(cell):
			state["grid"][p.y][p.x] = CharacterData.CellType.ENEMY
			state["shield_spawn_turn"].erase(p)
	else:
		_state_clear_enemy(state, p)
		_state_record_recovery_dir(state, attack_dir)
		if char_config.teleport_on_kill:
			state["player_pos"] = p
			state["player_moved"] = true
			state["bonus_moves_delta"] += 1

func _state_record_recovery_dir(state: Dictionary, attack_dir: int) -> void:
	if not char_config.use_exe_manual_slotting:
		return
	if attack_dir == CharacterData.Direction.NONE:
		return
	if not state.has("recovered_dirs"):
		state["recovered_dirs"] = []
	var recovered_dirs: Array = state["recovered_dirs"]
	if recovered_dirs.size() >= 2:
		return
	if recovered_dirs.has(attack_dir):
		return
	recovered_dirs.append(attack_dir)

func _apply_recovered_dirs_to_slots(recovered_dirs: Array) -> void:
	for dir_id: int in recovered_dirs:
		var empty_slot: int = _first_empty_skill_slot()
		if empty_slot < 0:
			return
		skill_slots[empty_slot] = [dir_id]

func _apply_skill_to_state(state: Dictionary, slot_data: Array) -> void:
	var stype: int = _classify(slot_data)
	var dv_seq: Vector2i = CharacterData.DIR_VECTOR[slot_data[0]]
	var dv_atk: Vector2i = CharacterData.DIR_VECTOR[slot_data[1]]
	var pos: Vector2i = state["player_pos"]
	match stype:
		CharacterData.SkillType.SAME_MA:
			var move_target: Vector2i = pos + dv_seq
			if _state_in_bounds(move_target, state):
				if _state_cell_is_enemy(state, move_target):
					_state_hit_cell(state, move_target, slot_data[0])
					if _state_cell_is_enemy(state, move_target):
						var push_dest: Vector2i = move_target + dv_seq
						if not _state_in_bounds(push_dest, state) or _state_cell_is_enemy(state, push_dest):
							_state_hit_cell(state, move_target, CharacterData.opposite_dir(slot_data[0]))
						else:
							state["grid"][push_dest.y][push_dest.x] = state["grid"][move_target.y][move_target.x]
							state["grid"][move_target.y][move_target.x] = CharacterData.CellType.LIVE
							_state_move_enemy_data(state, move_target, push_dest)
				state["player_pos"] = move_target
				state["player_moved"] = true
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			var move_target2: Vector2i = pos + dv_seq
			if _state_in_bounds(move_target2, state) and state["grid"][move_target2.y][move_target2.x] == CharacterData.CellType.LIVE:
				state["player_pos"] = move_target2
				state["player_moved"] = true
				_state_hit_cell(state, state["player_pos"] + dv_atk, slot_data[1])
		CharacterData.SkillType.SAME_AA:
			_state_hit_cell(state, pos + dv_seq, slot_data[0])
			_state_hit_cell(state, pos + 2 * dv_seq, slot_data[0])
		CharacterData.SkillType.ORTHO_AA:
			_state_hit_cell(state, pos + dv_seq, slot_data[0])
			_state_hit_cell(state, pos + dv_atk, slot_data[1])
		CharacterData.SkillType.RDR_DASH:
			var move_target3: Vector2i = pos + 2 * dv_seq
			if _state_in_bounds(move_target3, state) and not _state_cell_is_enemy(state, move_target3):
				state["player_pos"] = move_target3
				state["player_moved"] = true
		CharacterData.SkillType.RDR_DIAG:
			var jump_dest: Vector2i = pos + dv_seq + dv_atk
			if _state_in_bounds(jump_dest, state) and not _state_cell_is_enemy(state, jump_dest):
				state["player_pos"] = jump_dest
				state["player_moved"] = true

func _count_legal_moves_at(pos: Vector2i, state: Dictionary = {}) -> int:
	var count: int = 0
	for dir_id: int in CharacterData.DIR_VECTOR:
		if is_basic_move_legal(pos, dir_id, state):
			count += 1
	return count

func _skill_changes_state(state: Dictionary, skill: Array) -> bool:
	var before_pos: Vector2i = state["player_pos"]
	var sim: Dictionary = {
		"grid": _duplicate_grid(state["grid"]),
		"polluted_grid": _duplicate_bool_grid(state["polluted_grid"]),
		"player_pos": before_pos,
		"shield_spawn_turn": state["shield_spawn_turn"].duplicate(true),
		"enemy_spawn_turn": state["enemy_spawn_turn"].duplicate(true),
		"enemy_pollution_dir": state["enemy_pollution_dir"].duplicate(true),
		"kill_delta": 0,
		"bonus_moves_delta": 0,
		"recovered_dirs": [],
		"player_moved": false,
	}
	_apply_skill_to_state(sim, skill)
	if sim["kill_delta"] > 0:
		return true
	if sim["player_pos"] != before_pos:
		return true
	if not _state_is_polluted(sim, sim["player_pos"]):
		return true
	return _count_legal_moves_at(sim["player_pos"], sim) > 0

func _count_effective_skills() -> int:
	var state: Dictionary = _board_state()
	var effective: int = 0
	for slot_data: Array in skill_slots:
		if slot_data.size() == 3 and _skill_changes_state(state, slot_data):
			effective += 1
	return effective

func _has_combinable_material() -> bool:
	if action_seq.is_empty():
		return false
	if char_config.use_unified_slots:
		if char_config.use_rdr_classifier:
			for slot_data: Array in skill_slots:
				if slot_data.size() < 3:
					return true
			return false
		if char_config.use_exe_manual_slotting:
			if exe_pending_attack_slot >= 0:
				return true
			var used_index: int = action_seq.size() - 1
			if used_index < 0 or used_index >= action_seq_used_for_space.size() or action_seq_used_for_space[used_index]:
				return false
			var dir_seq: int = action_seq[used_index]
			var latest_is_attack: bool = action_seq_is_attack[used_index]
			for slot_data: Array in skill_slots:
				if _can_store_exe_skill_component(slot_data, dir_seq, latest_is_attack):
					return true
			return false
		for slot_data: Array in skill_slots:
			if slot_data.size() == 1:
				return true
		return false
	if char_config.skill_mixed:
		return action_seq.size() >= 2
	return not attack_queue.is_empty()

func check_loss_state() -> bool:
	if not is_polluted(player_pos):
		return false
	if _count_legal_moves_at(player_pos) > 0:
		return false
	if _count_effective_skills() > 0:
		return false
	game_over = true
	game_over_reason = "Contaminated, boxed in, no live skill."
	return true

func _count_central_pollution() -> int:
	var total: int = 0
	for y: int in range(1, 4):
		for x: int in range(1, 4):
			if polluted_grid[y][x]:
				total += 1
	return total

func _count_polluted_tiles() -> int:
	var total: int = 0
	for row: Array in polluted_grid:
		for polluted: bool in row:
			if polluted:
				total += 1
	return total

func _largest_pollution_cluster() -> int:
	var visited: Dictionary = {}
	var best: int = 0
	for y: int in ROWS:
		for x: int in COLS:
			var start: Vector2i = Vector2i(x, y)
			if not is_polluted(start) or visited.has(start):
				continue
			var stack: Array[Vector2i] = [start]
			visited[start] = true
			var cluster: int = 0
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				cluster += 1
				for dv: Vector2i in CharacterData.DIR_VECTOR.values():
					var nxt: Vector2i = cur + dv
					if is_polluted(nxt) and not visited.has(nxt):
						visited[nxt] = true
						stack.append(nxt)
			best = max(best, cluster)
	return best

func _count_polluted_chokepoints() -> int:
	var chokepoints: int = 0
	for y: int in ROWS:
		for x: int in COLS:
			var p: Vector2i = Vector2i(x, y)
			if not is_polluted(p):
				continue
			var open_neighbors: int = 0
			for dv: Vector2i in CharacterData.DIR_VECTOR.values():
				var n: Vector2i = p + dv
				if _in_bounds(n) and not is_polluted(n):
					open_neighbors += 1
			if open_neighbors <= 1:
				chokepoints += 1
	return chokepoints

func score_pollution_threat() -> Dictionary:
	var score: int = 0
	var legal_moves: int = _count_legal_moves_at(player_pos)
	var effective_skills: int = _count_effective_skills()
	var patterns: Array[String] = []
	if is_polluted(player_pos):
		score += 35
		patterns.append("player_on_pollution")
		if _has_combinable_material():
			score += 12
			patterns.append("combine_locked")
	score += (4 - legal_moves) * 10
	if legal_moves <= 1:
		score += 8
		patterns.append("low_escape")
	var central_pollution: int = _count_central_pollution()
	score += central_pollution * 3
	if central_pollution >= 4:
		patterns.append("central_pollution")
	var cluster: int = _largest_pollution_cluster()
	if cluster >= 3:
		score += min(14, cluster * 2)
		patterns.append("pollution_chain")
	var chokepoints: int = _count_polluted_chokepoints()
	if chokepoints > 0:
		score += min(12, chokepoints * 4)
		patterns.append("pollution_pocket")
	if effective_skills == 0:
		score += 20
		patterns.append("no_effective_skill")
	elif effective_skills == 1:
		score += 10
	if game_over:
		score = 100
		patterns.append("failed")
	return {
		"score": clamp(score, 0, 100),
		"polluted_tiles": _count_polluted_tiles(),
		"central_pollution": central_pollution,
		"legal_moves": legal_moves,
		"effective_skills": effective_skills,
		"patterns": patterns,
	}
