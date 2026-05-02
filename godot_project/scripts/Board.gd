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
const PENDING_CIRCLE_SIZE: float = 72.0
const PENDING_CIRCLE_GAP: float = 18.0
const SHOW_SIDE_STATS: bool = false

signal board_updated

enum SpawnMode { SEEDED, TRUE_RANDOM }
enum PlayMode { NORMAL, GUARD, SURVIVAL }
enum GuardQuadrant { TL, TR, BL, BR }

var char_config: CharacterData.Config = null

var grid: Array[Array] = []
var polluted_grid: Array[Array] = []
var player_pos: Vector2i = Vector2i(COLS / 2, ROWS / 2)
var moves_this_turn: int = 0
var attacks_this_turn: int = 0
var bonus_moves: int = 0
var bonus_attacks: int = 0
var turn: int = 1

var skill_slots: Array = []
var skill_preview: int = -1
var synthesis: VectorSynthesisState = VectorSynthesisState.new()
var score_tracker: RefCounted = null
var board_rules: RefCounted = null
var kill_count: int = 0
var shield_spawn_turn: Dictionary = {}
var enemy_spawn_turn: Dictionary = {}
var enemy_pollution_dir: Dictionary = {}
var guard_control_quadrant: Dictionary = {}
var game_over: bool = false
var game_over_reason: String = ""

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_spawn_preview: Array = []
var _spawn_mode: int = SpawnMode.SEEDED
var _play_mode: int = PlayMode.NORMAL
var _board_cols: int = COLS
var _board_rows: int = ROWS
var _debug_skill_slot_override: int = -1
var _pending_attack_marked: bool = false
var _pending_move_marked: bool = false
var _guard_quadrant_counts: Array = [0, 0, 0, 0]
var _guard_active_quadrant: int = -1

const _EXE_SCRIPT = preload("res://scripts/CharacterImpl_EXE.gd")
const _SCORE_TRACKER_SCRIPT = preload("res://scripts/ScoreTracker.gd")
const _BOARD_STATE_SCRIPT = preload("res://scripts/BoardState.gd")
const _BOARD_RULES_SCRIPT = preload("res://scripts/BoardRules.gd")
const _ASCII_LEVEL_MODE_SCRIPT = preload("res://scripts/AsciiLevelMode.gd")

var cell_nodes: Array[Array] = []
var _cell_scene: PackedScene = null
var _arrow_overlay: Node2D = null
var level_mode: RefCounted = null

class ArrowOverlay extends Node2D:
	var board: Node2D

	func _draw() -> void:
		if board == null:
			return
		var arrow_half: float = 26.0
		var head_arm: float = 18.0
		var line_w: float = 3.5
		var color: Color = Color(1.0, 0.6, 0.15, 0.95)
		var cols_: int = board.get_board_cols()
		var rows_: int = board.get_board_rows()
		var cell_size_: float = board.CELL_SIZE
		var cell_gap_: float = board.CELL_GAP
		var cell_step_: float = board.CELL_STEP

		if board.is_control_mode():
			if board.is_guard_mode():
				var center: Vector2i = Vector2i(cols_ / 2, rows_ / 2)
				draw_rect(
					Rect2(center.x * cell_step_ + 5.0, center.y * cell_step_ + 5.0, cell_size_ - 10.0, cell_size_ - 10.0),
					Color(0.45, 0.95, 1.0, 0.95),
					false,
					4.0
				)
			var active_quadrant: int = board.get_guard_active_quadrant()
			var preview_quadrant: int = board.get_guard_preview_quadrant()
			if preview_quadrant >= 0:
				_draw_guard_corner_mark(preview_quadrant, Color(0.45, 0.95, 1.0, 0.9), cols_, rows_, cell_size_, cell_step_)
			if active_quadrant >= 0:
				_draw_guard_corner_mark(active_quadrant, Color(1.0, 0.35, 0.35, 0.95), cols_, rows_, cell_size_, cell_step_)
				var active_rect: Rect2i = board.get_guard_quadrant_rect(active_quadrant)
				draw_rect(
					Rect2(
						active_rect.position.x * cell_step_ + 3.0,
						active_rect.position.y * cell_step_ + 3.0,
						(active_rect.size.x - 1) * cell_step_ + cell_size_ - 6.0,
						(active_rect.size.y - 1) * cell_step_ + cell_size_ - 6.0
					),
					Color(1.0, 0.35, 0.35, 0.95),
					false,
					4.0
				)

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

	func _draw_guard_corner_mark(quadrant: int, mark_color: Color, cols_: int, rows_: int, cell_size_: float, cell_step_: float) -> void:
		var corner: Vector2
		var h_dir: float
		var v_dir: float
		match quadrant:
			board.GuardQuadrant.TL:
				corner = Vector2(4.0, 4.0)
				h_dir = 1.0
				v_dir = 1.0
			board.GuardQuadrant.TR:
				corner = Vector2((cols_ - 1) * cell_step_ + cell_size_ - 4.0, 4.0)
				h_dir = -1.0
				v_dir = 1.0
			board.GuardQuadrant.BL:
				corner = Vector2(4.0, (rows_ - 1) * cell_step_ + cell_size_ - 4.0)
				h_dir = 1.0
				v_dir = -1.0
			board.GuardQuadrant.BR:
				corner = Vector2((cols_ - 1) * cell_step_ + cell_size_ - 4.0, (rows_ - 1) * cell_step_ + cell_size_ - 4.0)
				h_dir = -1.0
				v_dir = -1.0
			_:
				corner = Vector2.ZERO
				h_dir = 0.0
				v_dir = 0.0
		var mark_len: float = 54.0
		draw_line(corner, corner + Vector2(mark_len * h_dir, 0.0), mark_color, 5.0, true)
		draw_line(corner, corner + Vector2(0.0, mark_len * v_dir), mark_color, 5.0, true)

func _load_char_config() -> void:
	char_config = _EXE_SCRIPT.get_config()
	if _debug_skill_slot_override > 0:
		char_config.skill_slot_count = _debug_skill_slot_override
	var unlocked_slot_count: int = get_unlocked_slot_count()
	char_config.skill_slot_count = mini(char_config.skill_slot_count, unlocked_slot_count)

func toggle_debug_skill_slots() -> void:
	_debug_skill_slot_override = -1 if _debug_skill_slot_override > 0 else 8
	restart()

func toggle_play_mode() -> void:
	match _play_mode:
		PlayMode.NORMAL:
			_play_mode = PlayMode.GUARD
		PlayMode.GUARD:
			_play_mode = PlayMode.SURVIVAL
		_:
			_play_mode = PlayMode.NORMAL
	restart()

func is_guard_mode() -> bool:
	return _play_mode == PlayMode.GUARD

func is_survival_mode() -> bool:
	return _play_mode == PlayMode.SURVIVAL

func is_control_mode() -> bool:
	return _play_mode == PlayMode.GUARD or _play_mode == PlayMode.SURVIVAL

func get_board_cols() -> int:
	return _board_cols

func get_board_rows() -> int:
	return _board_rows

func get_play_mode_label() -> String:
	match _play_mode:
		PlayMode.GUARD:
			return "GUARD"
		PlayMode.SURVIVAL:
			return "SURVIVE"
		_:
			return "NORMAL"

func get_guard_preview_quadrant() -> int:
	if not is_control_mode() or _next_spawn_preview.is_empty():
		return -1
	return int(_next_spawn_preview[0].get("quadrant", -1))

func get_guard_active_quadrant() -> int:
	return _guard_active_quadrant if is_control_mode() else -1

func get_guard_quadrant_rect(quadrant: int) -> Rect2i:
	return _guard_quadrant_rect(quadrant)

func toggle_spawn_mode() -> void:
	_spawn_mode = SpawnMode.TRUE_RANDOM if _spawn_mode == SpawnMode.SEEDED else SpawnMode.SEEDED
	if _play_mode == PlayMode.NORMAL:
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
	if score_tracker == null:
		score_tracker = _SCORE_TRACKER_SCRIPT.new()
	if board_rules == null:
		board_rules = _BOARD_RULES_SCRIPT.new()
	_rng.randomize()
	if _play_mode == PlayMode.SURVIVAL:
		_board_cols = 4
		_board_rows = 4
	else:
		var level_dims: Vector2i = _get_level_dimensions()
		_board_cols = level_dims.x
		_board_rows = level_dims.y
	_update_board_offset()
	_initialize_empty_board()
	player_pos = Vector2i(_board_cols / 2, _board_rows / 2)
	moves_this_turn = 0
	attacks_this_turn = 0
	bonus_moves = 0
	bonus_attacks = 0
	turn = 1
	score_tracker.reset()
	skill_slots.resize(char_config.skill_slot_count)
	for i: int in char_config.skill_slot_count:
		skill_slots[i] = []
	skill_preview = -1
	synthesis.reset(char_config.skill_slot_count)
	_sync_exe_skill_slots()
	kill_count = 0
	shield_spawn_turn.clear()
	enemy_spawn_turn.clear()
	enemy_pollution_dir.clear()
	guard_control_quadrant.clear()
	_guard_quadrant_counts = [0, 0, 0, 0]
	_guard_active_quadrant = -1
	game_over = false
	game_over_reason = ""
	_pending_attack_marked = false
	_pending_move_marked = false
	_next_spawn_preview.clear()
	if not _apply_level_mode():
		push_error("Level mode apply failed: %s" % _get_level_mode_error())
	if is_control_mode():
		_compute_next_guard_preview()
	_refresh_visuals()


func set_level_mode(mode: RefCounted) -> void:
	level_mode = mode


func clear_level_mode() -> void:
	level_mode = null


func load_ascii_level(object_map: String, direction_map: String) -> void:
	level_mode = _ASCII_LEVEL_MODE_SCRIPT.new(object_map, direction_map)
	restart()


func load_level_definition(level_def: Dictionary) -> void:
	var mode: RefCounted = _ASCII_LEVEL_MODE_SCRIPT.new()
	if mode.has_method("configure_level"):
		mode.configure_level(level_def)
	level_mode = mode
	restart()


func _get_level_dimensions() -> Vector2i:
	if level_mode != null and level_mode.has_method("get_dimensions"):
		var dims: Vector2i = level_mode.get_dimensions(Vector2i(COLS, ROWS))
		if dims.x > COLS or dims.y > ROWS or dims.x <= 0 or dims.y <= 0:
			return Vector2i(COLS, ROWS)
		return dims
	return Vector2i(COLS, ROWS)


func _initialize_empty_board() -> void:
	grid.clear()
	polluted_grid.clear()
	for _r: int in _board_rows:
		var row: Array[int] = []
		var polluted_row: Array[bool] = []
		for _c: int in _board_cols:
			row.append(CharacterData.CellType.LIVE)
			polluted_row.append(false)
		grid.append(row)
		polluted_grid.append(polluted_row)


func _apply_level_mode() -> bool:
	if _play_mode == PlayMode.SURVIVAL:
		return true
	if level_mode == null:
		return true
	if not level_mode.has_method("apply_to_board"):
		return false
	return level_mode.apply_to_board(self)


func _get_level_mode_error() -> String:
	if level_mode != null and level_mode.has_method("get_last_error"):
		return level_mode.get_last_error()
	return "Unknown level mode error."


func _should_auto_spawn_on_end_turn() -> bool:
	if level_mode != null and level_mode.has_method("should_auto_spawn_on_end_turn"):
		return level_mode.should_auto_spawn_on_end_turn()
	return true


func get_level_id() -> int:
	if level_mode != null and level_mode.has_method("get_level_id"):
		return level_mode.get_level_id(0)
	return 0


func get_level_title() -> String:
	if level_mode != null and level_mode.has_method("get_level_title"):
		return level_mode.get_level_title("")
	return ""


func get_move_limit() -> int:
	var fallback: int = char_config.max_moves if char_config != null else 0
	if level_mode != null and level_mode.has_method("get_move_limit"):
		return level_mode.get_move_limit(fallback)
	return fallback


func get_attack_limit() -> int:
	var fallback: int = char_config.max_attacks if char_config != null else 0
	if level_mode != null and level_mode.has_method("get_attack_limit"):
		return level_mode.get_attack_limit(fallback)
	return fallback


func get_unlocked_slot_count() -> int:
	var fallback: int = char_config.skill_slot_count if char_config != null else 1
	if level_mode != null and level_mode.has_method("get_unlocked_slot_count"):
		var level_count: int = level_mode.get_unlocked_slot_count(fallback)
		return maxi(1, level_count)
	return maxi(1, fallback)


func allows_kill_recovery() -> bool:
	if level_mode != null and level_mode.has_method("allows_kill_recovery"):
		return level_mode.allows_kill_recovery()
	return true


func get_skill_slot_count() -> int:
	return char_config.skill_slot_count if char_config != null else 0

func is_polluted(pos: Vector2i) -> bool:
	return _in_bounds(pos) and polluted_grid[pos.y][pos.x]

func can_accept_input() -> bool:
	return not game_over

func _sync_exe_skill_slots() -> void:
	skill_slots = synthesis.legacy_slots()
	skill_preview = synthesis.selected_slot

func _slot_data(slot: int) -> Array:
	if slot < 0 or slot >= char_config.skill_slot_count:
		return []
	return synthesis.legacy_slot(slot)

func get_selected_skill_slot() -> int:
	return synthesis.selected_slot

func is_skill_slot_complete(slot: int) -> bool:
	return _slot_data(slot).size() == 3

func _synthesis_slot_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for i: int in synthesis.slots.size():
		sizes.append(synthesis.slot_token_count(i))
	return sizes

func _record_new_exe_syntheses(before_sizes: Array[int]) -> void:
	for i: int in synthesis.slots.size():
		if i < before_sizes.size() and before_sizes[i] < 2 and synthesis.slot_token_count(i) == 2:
			_record_exe_skill_synthesis(synthesis.legacy_slot(i))

func _auto_store_exe_pending() -> void:
	if not synthesis.has_pending():
		return
	var before_sizes: Array[int] = _synthesis_slot_sizes()
	synthesis.auto_store_pending()
	_sync_exe_skill_slots()
	_record_new_exe_syntheses(before_sizes)
	_record_slot_usage_sample()

func can_combine_skill() -> bool:
	return true

func is_basic_move_legal(from: Vector2i, dir: int, state: RefCounted = null) -> bool:
	var board_state: RefCounted = _make_board_state(false) if state == null else state
	return board_rules.is_basic_move_legal(board_state, from, dir, _board_cols, _board_rows)

func try_move(dir: int) -> bool:
	if game_over:
		return false
	_auto_store_exe_pending()
	if moves_this_turn >= get_move_limit() + bonus_moves:
		return false
	if not is_basic_move_legal(player_pos, dir):
		return false
	player_pos += CharacterData.DIR_VECTOR[dir]
	synthesis.record_move(dir)
	_sync_exe_skill_slots()
	moves_this_turn += 1
	_record_step_stats(true, false)
	_refresh_visuals()
	return true

func try_attack(dir: int) -> bool:
	if game_over:
		return false
	_auto_store_exe_pending()
	if is_polluted(player_pos):
		return false
	if attacks_this_turn >= get_attack_limit() + bonus_attacks:
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
	if killed:
		synthesis.record_attack_kill(dir)
		_sync_exe_skill_slots()
	attacks_this_turn += 1
	_record_step_stats(false, true)
	_refresh_visuals()
	return true

func try_end_turn() -> bool:
	if game_over:
		return false
	_auto_store_exe_pending()
	turn += 1
	moves_this_turn = 0
	attacks_this_turn = 0
	bonus_moves = 0
	bonus_attacks = 0
	_harden_old_shields()
	if is_control_mode():
		_spread_guard_pollution()
		_spawn_guard_controls()
		_compute_next_guard_preview()
	else:
		_spread_pollution()
		if _should_auto_spawn_on_end_turn():
			debug_spawn_enemies(_spawn_count_for_turn(turn))
	check_loss_state()
	_refresh_visuals()
	return true

func _count_occupied_skill_slots() -> int:
	var occupied: int = 0
	for slot_data: Array in synthesis.legacy_slots():
		if not slot_data.is_empty():
			occupied += 1
	return occupied

func _record_slot_usage_sample() -> void:
	score_tracker.record_slot_usage(_count_occupied_skill_slots())

func _record_step_stats(is_move: bool, is_attack: bool) -> void:
	score_tracker.record_step(is_move, is_attack, _count_occupied_skill_slots())

func _record_exe_skill_synthesis(slot_data: Array) -> void:
	if slot_data.size() != 3:
		return
	score_tracker.record_skill_synthesis(_classify(slot_data))

func _record_exe_skill_cast(slot_data: Array, kills: int, recovery: int) -> void:
	if slot_data.size() != 3:
		return
	score_tracker.record_skill_cast(_classify(slot_data), kills, recovery)

func try_combine_skill() -> bool:
	if game_over:
		return false
	if not can_combine_skill():
		return false
	return _try_store_exe_skill_component()

func _try_store_exe_skill_component() -> bool:
	var before_sizes: Array[int] = _synthesis_slot_sizes()
	if not synthesis.press_space():
		return false
	_sync_exe_skill_slots()
	_record_new_exe_syntheses(before_sizes)
	_record_slot_usage_sample()
	_refresh_visuals()
	return true

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


func _draw_pending_circle(center: Vector2, radius: float, label: String, token: int, active_color: Color, text_color: Color, font: Font, font_size: int) -> void:
	draw_circle(center, radius, Color(0.10, 0.10, 0.13))
	draw_arc(center, radius, 0.0, TAU, 40, active_color if token != VectorSynthesisState.NO_TOKEN else Color(0.30, 0.30, 0.35), 2.0)
	draw_string(
		font,
		Vector2(center.x - radius, center.y - radius - 6.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		14,
		Color(0.65, 0.65, 0.72)
	)
	if token != VectorSynthesisState.NO_TOKEN:
		var token_y: float = center.y + font_size * 0.28
		draw_string(
			font,
			Vector2(center.x - radius, token_y),
			CharacterData.DIR_ARROWS[VectorSynthesisState.token_board_dir(token)],
			HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0,
			font_size,
			text_color
		)


func toggle_pending_marker(is_attack_marker: bool) -> void:
	if is_attack_marker:
		_pending_attack_marked = not _pending_attack_marked
	else:
		_pending_move_marked = not _pending_move_marked
	queue_redraw()

func _spawn_order(seed: int) -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	for r: int in _board_rows:
		for c: int in _board_cols:
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
	if is_control_mode():
		if _next_spawn_preview.is_empty():
			_compute_next_guard_preview()
		_spawn_guard_controls()
		_compute_next_guard_preview()
		_refresh_visuals()
		return
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

func _guard_quadrant_origin(quadrant: int) -> Vector2i:
	match quadrant:
		GuardQuadrant.TL:
			return Vector2i(0, 0)
		GuardQuadrant.TR:
			return Vector2i(_board_cols - 1, 0)
		GuardQuadrant.BL:
			return Vector2i(0, _board_rows - 1)
		GuardQuadrant.BR:
			return Vector2i(_board_cols - 1, _board_rows - 1)
		_:
			return Vector2i.ZERO

func _guard_quadrant_rect(quadrant: int) -> Rect2i:
	var size: int = 3 if _play_mode == PlayMode.SURVIVAL else 4
	match quadrant:
		GuardQuadrant.TL:
			return Rect2i(0, 0, size, size)
		GuardQuadrant.TR:
			return Rect2i(_board_cols - size, 0, size, size)
		GuardQuadrant.BL:
			return Rect2i(0, _board_rows - size, size, size)
		GuardQuadrant.BR:
			return Rect2i(_board_cols - size, _board_rows - size, size, size)
		_:
			return Rect2i(0, 0, _board_cols, _board_rows)

func _choose_guard_quadrant() -> int:
	var candidates: Array = []
	for quadrant: int in range(4):
		var counts: Array = _guard_quadrant_counts.duplicate()
		counts[quadrant] += 1
		var low: int = counts[0]
		var high: int = counts[0]
		for count: int in counts:
			low = min(low, count)
			high = max(high, count)
		if high - low < 3:
			candidates.append(quadrant)
	if candidates.is_empty():
		candidates = [GuardQuadrant.TL, GuardQuadrant.TR, GuardQuadrant.BL, GuardQuadrant.BR]
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _compute_next_guard_preview() -> void:
	var quadrant: int = _choose_guard_quadrant()
	_guard_quadrant_counts[quadrant] += 1
	_next_spawn_preview = _build_guard_spawn_preview(quadrant, 5)

func _build_guard_spawn_preview(quadrant: int, count: int) -> Array:
	var result: Array = []
	var cells: Array = []
	for y: int in _board_rows:
		for x: int in _board_cols:
			cells.append(Vector2i(x, y))
	for i: int in range(cells.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	for pos: Vector2i in cells:
		if result.size() >= count:
			break
		if pos != player_pos and grid[pos.y][pos.x] == CharacterData.CellType.LIVE:
			result.append({
				"pos": pos,
				"quadrant": quadrant,
			})
	return result

func _spawn_guard_controls() -> void:
	_guard_active_quadrant = get_guard_preview_quadrant()
	for entry: Dictionary in _next_spawn_preview:
		var pos: Vector2i = entry.get("pos", Vector2i.ZERO)
		var quadrant: int = int(entry.get("quadrant", GuardQuadrant.TL))
		if pos != player_pos and _in_bounds(pos) and grid[pos.y][pos.x] == CharacterData.CellType.LIVE:
			grid[pos.y][pos.x] = CharacterData.CellType.ENEMY
			guard_control_quadrant[pos] = quadrant

func _spread_guard_pollution() -> void:
	var controls: Array = guard_control_quadrant.keys()
	for source in controls:
		var pos: Vector2i = source
		if not _in_bounds(pos) or not CharacterData.is_enemy(grid[pos.y][pos.x]):
			guard_control_quadrant.erase(pos)
	if _guard_active_quadrant < 0:
		return
	var grow_count: int = min(_count_guard_controls_in_quadrant_rect(_guard_active_quadrant), 3)
	for _i: int in grow_count:
		_grow_guard_pollution(_guard_active_quadrant)

func _count_guard_controls_in_quadrant_rect(quadrant: int) -> int:
	var rect: Rect2i = _guard_quadrant_rect(quadrant)
	var total: int = 0
	for source in guard_control_quadrant.keys():
		var pos: Vector2i = source
		if not _in_bounds(pos) or not CharacterData.is_enemy(grid[pos.y][pos.x]):
			continue
		if pos.x >= rect.position.x and pos.x < rect.position.x + rect.size.x \
		and pos.y >= rect.position.y and pos.y < rect.position.y + rect.size.y:
			total += 1
	return total

func _grow_guard_pollution(quadrant: int) -> void:
	var origin: Vector2i = _guard_quadrant_origin(quadrant)
	var best_depth: int = 999
	var candidates: Array = []
	for y: int in _board_rows:
		for x: int in _board_cols:
			if polluted_grid[y][x]:
				continue
			var pos: Vector2i = Vector2i(x, y)
			var depth: int = abs(pos.x - origin.x) + abs(pos.y - origin.y)
			if depth < best_depth:
				best_depth = depth
				candidates = [pos]
			elif depth == best_depth:
				candidates.append(pos)
	if candidates.is_empty():
		return
	var picked: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
	polluted_grid[picked.y][picked.x] = true

func _refresh_visuals() -> void:
	for r: int in ROWS:
		for c: int in COLS:
			if r >= _board_rows or c >= _board_cols:
				cell_nodes[r][c].visible = false
				continue
			cell_nodes[r][c].visible = true
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
	var board_w: float = (_board_cols - 1) * CELL_STEP + CELL_SIZE
	var total_seq_w: float = (slots - 1) * SEQ_STEP + SEQ_SIZE
	var seq_x0: float = (board_w - total_seq_w) / 2.0
	var base_ui_y: float = _board_rows * CELL_STEP + SEQ_MARGIN_TOP
	var seq_y: float

	var rem_moves: int = get_move_limit() + bonus_moves - moves_this_turn
	var rem_atk: int = get_attack_limit() + bonus_attacks - attacks_this_turn
	var avg_slot_usage: float = score_tracker.average_slot_usage()
	var move_usage_ratio: float = score_tracker.move_usage_ratio()
	var skill_font_size: int = 26
	var exe_slot_x0: float = 0.0
	var exe_slot_y: float = base_ui_y
	var slot_count: int = char_config.skill_slot_count
	var total_slot_w: float = (slot_count - 1) * SEQ_STEP + SEQ_SIZE
	var slot_x0: float = (board_w - total_slot_w) / 2.0 + 24.0
	var slot_y: float = base_ui_y
	exe_slot_x0 = slot_x0
	exe_slot_y = slot_y
	var pending_row_y: float = slot_y + SEQ_SIZE + 18.0
	seq_y = pending_row_y + PENDING_CIRCLE_SIZE + 18.0
	for i: int in slot_count:
		var sx: float = slot_x0 + i * SEQ_STEP
		var srect: Rect2 = Rect2(sx, slot_y, SEQ_SIZE, SEQ_SIZE)
		var is_armed: bool = skill_preview == i
		var slot_data: Array = skill_slots[i]
		var is_pending_slot: bool = synthesis.has_pending() and synthesis.selected_slot == i and synthesis.can_store_in_slot(i)
		if slot_data.size() == 3:
			draw_rect(srect, Color(0.08, 0.08, 0.18))
			draw_rect(srect, Color(0.65, 0.65, 1.0) if is_armed else Color(0.35, 0.35, 0.65), false, 2.5 if is_armed else 1.5)
			var stext_y: float = slot_y + (SEQ_SIZE + skill_font_size * 0.7) / 2.0 - 8.0
			var half: float = SEQ_SIZE / 2.0
			var col_a: Color = Color(1.0, 0.6, 0.15) if slot_data[2] else Color.WHITE
			draw_string(font, Vector2(sx, stext_y), CharacterData.DIR_ARROWS[slot_data[0]], HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, col_a)
			draw_string(font, Vector2(sx + half, stext_y), CharacterData.DIR_ARROWS[slot_data[1]], HORIZONTAL_ALIGNMENT_CENTER, half, skill_font_size, Color(1.0, 0.6, 0.15))
			draw_string(font, Vector2(sx, slot_y + SEQ_SIZE - 2.0), CharacterData.SKILL_TYPE_NAMES[_classify(slot_data)], HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, 13, Color(0.75, 0.75, 1.0))
		elif slot_data.size() == 1:
			draw_rect(srect, Color(0.16, 0.09, 0.04) if is_armed else Color(0.10, 0.10, 0.13))
			draw_rect(srect, Color(1.0, 0.6, 0.15) if is_armed else Color(0.40, 0.25, 0.08), false, 2.5 if is_armed else 1.5)
			var single_col: Color = Color(1.0, 0.6, 0.15) if VectorSynthesisState.token_is_attack(synthesis.slot_first_token(i)) else Color.WHITE
			var atk_text_y: float = slot_y + (SEQ_SIZE + font_size * 0.7) / 2.0
			draw_string(font, Vector2(sx, atk_text_y), CharacterData.DIR_ARROWS[slot_data[0]], HORIZONTAL_ALIGNMENT_CENTER, SEQ_SIZE, font_size, single_col)
		else:
			draw_rect(srect, Color(0.10, 0.10, 0.13))
			if is_pending_slot:
				_draw_dashed_rect_outline(srect, Color(1.0, 0.65, 0.2, 0.95), 2.0, 10.0, 6.0)
			else:
				draw_rect(srect, Color(0.65, 0.65, 1.0) if is_armed else Color(0.30, 0.30, 0.35), false, 2.5 if is_armed else 1.5)

	var pending_attack_token: int = synthesis.pending_attack_token()
	var pending_move_token: int = synthesis.pending_move_token()
	var pending_total_w: float = PENDING_CIRCLE_SIZE * 2.0 + PENDING_CIRCLE_GAP
	var pending_x0: float = (board_w - pending_total_w) / 2.0
	var pending_radius: float = PENDING_CIRCLE_SIZE / 2.0
	var pending_a_center: Vector2 = Vector2(pending_x0 + pending_radius, pending_row_y + pending_radius)
	var pending_m_center: Vector2 = Vector2(pending_x0 + PENDING_CIRCLE_SIZE + PENDING_CIRCLE_GAP + pending_radius, pending_row_y + pending_radius)
	var pending_a_color: Color = Color(1.0, 0.35, 0.35, 1.0) if _pending_attack_marked else Color(1.0, 0.65, 0.2, 0.95)
	var pending_m_color: Color = Color(0.35, 0.95, 0.55, 1.0) if _pending_move_marked else Color(0.85, 0.9, 1.0, 0.95)
	var pending_a_text: Color = Color(1.0, 0.82, 0.82, 0.9) if _pending_attack_marked else Color(1.0, 0.72, 0.4, 0.75)
	var pending_m_text: Color = Color(0.85, 1.0, 0.9, 0.95) if _pending_move_marked else Color.WHITE
	_draw_pending_circle(pending_a_center, pending_radius, "Q / A", pending_attack_token, pending_a_color, pending_a_text, font, font_size)
	_draw_pending_circle(pending_m_center, pending_radius, "E / M", pending_move_token, pending_m_color, pending_m_text, font, font_size)

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
	var level_id: int = get_level_id()
	var level_title: String = get_level_title()
	var level_label: String = "LEVEL %d" % level_id if level_id > 0 else "LEVEL"
	draw_string(font, Vector2(side_x, 26.0), level_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 50.0), level_title if not level_title.is_empty() else "-",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.95))
	draw_string(font, Vector2(side_x, 84.0), "TURN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
	draw_string(font, Vector2(side_x, 124.0), str(turn),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	if SHOW_SIDE_STATS:
		draw_string(font, Vector2(side_x, 262.0), "KILL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(side_x, 302.0), str(kill_count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1.0, 0.4, 0.4))
		draw_string(font, Vector2(side_x, 336.0), "THREAT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(side_x, 376.0), str(threat["score"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.45, 0.9, 0.45))
		draw_string(font, Vector2(side_x, 410.0), "AVG SLOT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(side_x, 450.0), "%.1f" % avg_slot_usage,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.95, 0.9, 0.55))
		draw_string(font, Vector2(side_x, 484.0), "MOVE%",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(side_x, 524.0), "%.0f%%" % (move_usage_ratio * 100.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.85, 0.95, 1.0))
		draw_string(font, Vector2(side_x, 564.0), "EXE SKILL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(side_x, 588.0), "SKL S% K R%",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.75))
		var skill_rows: Array[Dictionary] = score_tracker.skill_rows()
		for i: int in skill_rows.size():
			var row: Dictionary = skill_rows[i]
			var row_text: String = "%s %2d %.1f %2d" % [
				row["label"],
				row["synth_pct"],
				row["avg_kills"],
				row["recovery_pct"],
			]
			draw_string(font, Vector2(side_x, 610.0 + i * 18.0), row_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.95))
	if game_over:
		draw_rect(Rect2(-14.0, -14.0, board_w + 160.0, _board_rows * CELL_STEP + 30.0), Color(0, 0, 0, 0.35))
		draw_string(font, Vector2(board_w * 0.15, _board_rows * CELL_STEP * 0.48), "FAILED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.4, 0.4))
		draw_string(font, Vector2(board_w * 0.15, _board_rows * CELL_STEP * 0.48 + 34.0), game_over_reason,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 0.95))

func _update_board_offset() -> void:
	var board_w: float = (_board_cols - 1) * CELL_STEP + CELL_SIZE
	var total_h: float = _board_rows * CELL_STEP + SEQ_MARGIN_TOP + SEQ_SIZE + 18.0 + PENDING_CIRCLE_SIZE + 18.0 + SEQ_SIZE
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2((vp.x - board_w) / 2.0, (vp.y - total_h) / 2.0)

func _classify(slot_data: Array) -> int:
	return CharacterData.classify_skill(slot_data)

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < _board_cols and p.y >= 0 and p.y < _board_rows

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
		guard_control_quadrant.erase(p)

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
	if guard_control_quadrant.has(from):
		guard_control_quadrant[to] = guard_control_quadrant[from]
		guard_control_quadrant.erase(from)

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
	var slot_data: Array = _slot_data(slot)
	if slot < 0 or slot >= char_config.skill_slot_count or slot_data.size() != 3:
		return result
	var stype: int = _classify(slot_data)
	var dv_seq: Vector2i = CharacterData.DIR_VECTOR[slot_data[0]]
	var dv_atk: Vector2i = CharacterData.DIR_VECTOR[slot_data[1]]
	var pos: Vector2i = player_pos
	match stype:
		CharacterData.SkillType.SAME_MA:
			var dash_pos: Vector2i = pos
			for _step: int in 2:
				var next_pos: Vector2i = dash_pos + dv_seq
				if not _in_bounds(next_pos):
					break
				if CharacterData.is_enemy(grid[next_pos.y][next_pos.x]):
					result["hit"].append(next_pos)
					result["move"].append(next_pos)
					break
				dash_pos = next_pos
				result["move"].append(dash_pos)
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			result["move"].append(pos + dv_seq)
			result["hit"].append(pos + dv_seq + dv_atk)
		CharacterData.SkillType.SAME_AA:
			var front_target: Vector2i = pos + dv_seq
			if _in_bounds(front_target) and CharacterData.is_enemy(grid[front_target.y][front_target.x]):
				result["hit"].append(front_target)
				if _in_bounds(pos + 2 * dv_seq):
					result["hit"].append(pos + 2 * dv_seq)
		CharacterData.SkillType.ORTHO_AA:
			if _in_bounds(pos + dv_seq):
				result["hit"].append(pos + dv_seq)
			if _in_bounds(pos + dv_atk):
				result["hit"].append(pos + dv_atk)
	return result

func set_skill_preview(slot: int) -> void:
	synthesis.select_slot(slot)
	_sync_exe_skill_slots()
	if _arrow_overlay:
		_arrow_overlay.queue_redraw()
	queue_redraw()

func rotate_armed_skill(new_dir: int) -> void:
	_auto_store_exe_pending()
	var slot: int = skill_preview
	var data: Array = _slot_data(slot)
	if slot < 0 or slot >= char_config.skill_slot_count or data.size() != 3:
		return
	data = data.duplicate()
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
	else:
		var new_is_h2: bool = new_dir == CharacterData.Direction.LEFT or new_dir == CharacterData.Direction.RIGHT
		var d0_is_h2: bool = data[0] == CharacterData.Direction.LEFT or data[0] == CharacterData.Direction.RIGHT
		if d0_is_h2 == new_is_h2:
			data[0] = new_dir
		else:
			data[1] = new_dir
	synthesis.replace_complete_slot(slot, data[0], data[1], data[2])
	_sync_exe_skill_slots()
	_refresh_visuals()

func use_skill(slot: int) -> void:
	if game_over:
		return
	var slot_data: Array = _slot_data(slot)
	if slot < 0 or slot >= char_config.skill_slot_count or slot_data.size() != 3:
		return
	var cast_skill: Array = slot_data.duplicate()
	var live_state: RefCounted = _make_board_state(false)
	if not board_rules.skill_can_activate(live_state, cast_skill, _board_cols, _board_rows):
		return
	board_rules.apply_skill_to_state(live_state, cast_skill, _board_cols, _board_rows, char_config.teleport_on_kill)
	grid = live_state.grid
	polluted_grid = live_state.polluted_grid
	player_pos = live_state.player_pos
	shield_spawn_turn = live_state.shield_spawn_turn
	enemy_spawn_turn = live_state.enemy_spawn_turn
	enemy_pollution_dir = live_state.enemy_pollution_dir
	guard_control_quadrant = live_state.guard_control_quadrant
	kill_count += live_state.kill_delta
	bonus_moves += live_state.bonus_moves_delta
	var recovered_count: int = live_state.recovered_dirs.size() if allows_kill_recovery() else 0
	_record_exe_skill_cast(cast_skill, live_state.kill_delta, recovered_count)
	synthesis.clear_slot(slot)
	_sync_exe_skill_slots()
	if allows_kill_recovery():
		_apply_recovered_dirs_to_slots(live_state.recovered_dirs)
	_record_step_stats(false, true)
	_refresh_visuals()

func _make_board_state(duplicate_data: bool = true) -> RefCounted:
	var state: RefCounted = _BOARD_STATE_SCRIPT.new()
	state.load_from_board(
		grid,
		polluted_grid,
		player_pos,
		shield_spawn_turn,
		enemy_spawn_turn,
		enemy_pollution_dir,
		guard_control_quadrant,
		duplicate_data
	)
	return state

func _apply_recovered_dirs_to_slots(recovered_dirs: Array) -> void:
	if not recovered_dirs.is_empty():
		synthesis.record_attack_kill(recovered_dirs[0])
	_sync_exe_skill_slots()

func _count_legal_moves_at(pos: Vector2i, state: RefCounted = null) -> int:
	var board_state: RefCounted = _make_board_state(false) if state == null else state
	return board_rules.count_legal_moves_at(board_state, pos, _board_cols, _board_rows)

func _skill_changes_state(state: RefCounted, skill: Array) -> bool:
	return board_rules.skill_changes_state(state, skill, _board_cols, _board_rows, char_config.teleport_on_kill)

func _count_effective_skills() -> int:
	var state: RefCounted = _make_board_state()
	var effective: int = 0
	for i: int in skill_slots.size():
		var slot_data: Array = skill_slots[i]
		if slot_data.size() == 3 and _skill_changes_state(state, slot_data):
			effective += 1
	return effective

func _has_combinable_material() -> bool:
	if not synthesis.has_pending():
		return false
	if synthesis.selected_slot >= 0:
		return synthesis.can_store_in_slot(synthesis.selected_slot)
	for i: int in synthesis.slots.size():
		if synthesis.can_store_in_slot(i):
			return true
	return false

func check_loss_state() -> bool:
	if _play_mode == PlayMode.GUARD:
		var center: Vector2i = Vector2i(_board_cols / 2, _board_rows / 2)
		if is_polluted(center):
			game_over = true
			game_over_reason = "Guard point polluted."
			return true
		return false
	if _play_mode == PlayMode.SURVIVAL:
		if _is_board_fully_polluted():
			game_over = true
			game_over_reason = "Board fully polluted."
			return true
		return false
	if not is_polluted(player_pos):
		return false
	if _count_legal_moves_at(player_pos) > 0:
		return false
	if _count_effective_skills() > 0:
		return false
	game_over = true
	game_over_reason = "Contaminated, boxed in, no live skill."
	return true

func _is_board_fully_polluted() -> bool:
	for y: int in _board_rows:
		for x: int in _board_cols:
			if not polluted_grid[y][x]:
				return false
	return true

func _count_central_pollution() -> int:
	var total: int = 0
	for y: int in range(1, _board_rows - 1):
		for x: int in range(1, _board_cols - 1):
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
	for y: int in _board_rows:
		for x: int in _board_cols:
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
	for y: int in _board_rows:
		for x: int in _board_cols:
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
	return score_tracker.score_pollution_threat({
		"player_on_pollution": is_polluted(player_pos),
		"has_combinable_material": _has_combinable_material(),
		"legal_moves": _count_legal_moves_at(player_pos),
		"effective_skills": _count_effective_skills(),
		"central_pollution": _count_central_pollution(),
		"largest_pollution_cluster": _largest_pollution_cluster(),
		"polluted_chokepoints": _count_polluted_chokepoints(),
		"polluted_tiles": _count_polluted_tiles(),
		"game_over": game_over,
	})
