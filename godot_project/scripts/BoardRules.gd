class_name BoardRules
extends RefCounted

func in_bounds(p: Vector2i, cols: int, rows: int) -> bool:
	return p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows

func cell_is_enemy(state: RefCounted, p: Vector2i, cols: int, rows: int) -> bool:
	return in_bounds(p, cols, rows) and CharacterData.is_enemy(state.grid[p.y][p.x])

func is_polluted(state: RefCounted, p: Vector2i, cols: int, rows: int) -> bool:
	return in_bounds(p, cols, rows) and state.polluted_grid[p.y][p.x]

func is_basic_move_legal(state: RefCounted, from: Vector2i, dir: int, cols: int, rows: int) -> bool:
	var target: Vector2i = from + CharacterData.DIR_VECTOR[dir]
	if not in_bounds(target, cols, rows):
		return false
	return state.grid[target.y][target.x] == CharacterData.CellType.LIVE

func clear_enemy(state: RefCounted, p: Vector2i, cols: int, rows: int) -> void:
	if not cell_is_enemy(state, p, cols, rows):
		return
	state.grid[p.y][p.x] = CharacterData.CellType.LIVE
	state.shield_spawn_turn.erase(p)
	state.enemy_spawn_turn.erase(p)
	state.enemy_pollution_dir.erase(p)
	state.guard_control_quadrant.erase(p)
	state.kill_delta += 1

func move_enemy_data(state: RefCounted, from: Vector2i, to: Vector2i) -> void:
	if state.shield_spawn_turn.has(from):
		state.shield_spawn_turn[to] = state.shield_spawn_turn[from]
		state.shield_spawn_turn.erase(from)
	if state.enemy_spawn_turn.has(from):
		state.enemy_spawn_turn[to] = state.enemy_spawn_turn[from]
		state.enemy_spawn_turn.erase(from)
	if state.enemy_pollution_dir.has(from):
		state.enemy_pollution_dir[to] = state.enemy_pollution_dir[from]
		state.enemy_pollution_dir.erase(from)
	if state.guard_control_quadrant.has(from):
		state.guard_control_quadrant[to] = state.guard_control_quadrant[from]
		state.guard_control_quadrant.erase(from)

func hit_cell(
	state: RefCounted,
	p: Vector2i,
	attack_dir: int,
	cols: int,
	rows: int,
	teleport_on_kill: bool,
	award_kill_move: bool = true
) -> void:
	if not cell_is_enemy(state, p, cols, rows):
		return
	var cell: int = state.grid[p.y][p.x]
	var shield_dir: int = CharacterData.get_shield_dir(cell)
	if shield_dir != CharacterData.Direction.NONE \
	and CharacterData.DIR_VECTOR[attack_dir] + CharacterData.DIR_VECTOR[shield_dir] == Vector2i.ZERO:
		if not CharacterData.is_hard_shield(cell):
			state.grid[p.y][p.x] = CharacterData.CellType.ENEMY
			state.shield_spawn_turn.erase(p)
	else:
		clear_enemy(state, p, cols, rows)
		record_recovery_dir(state, attack_dir)
		if award_kill_move and teleport_on_kill:
			state.player_pos = p
			state.player_moved = true
			state.bonus_moves_delta += 1

func record_recovery_dir(state: RefCounted, attack_dir: int) -> void:
	if attack_dir == CharacterData.Direction.NONE:
		return
	if state.recovered_dirs.size() >= 2:
		return
	if state.recovered_dirs.has(attack_dir):
		return
	state.recovered_dirs.append(attack_dir)

func apply_skill_to_state(
	state: RefCounted,
	slot_data: Array,
	cols: int,
	rows: int,
	teleport_on_kill: bool
) -> void:
	var stype: int = CharacterData.classify_skill(slot_data)
	var dv_seq: Vector2i = CharacterData.DIR_VECTOR[slot_data[0]]
	var dv_atk: Vector2i = CharacterData.DIR_VECTOR[slot_data[1]]
	var pos: Vector2i = state.player_pos
	match stype:
		CharacterData.SkillType.SAME_MA:
			var dash_pos: Vector2i = pos
			for _step: int in 2:
				var next_pos: Vector2i = dash_pos + dv_seq
				if not in_bounds(next_pos, cols, rows):
					break
				if cell_is_enemy(state, next_pos, cols, rows):
					hit_cell(state, next_pos, slot_data[0], cols, rows, teleport_on_kill)
					dash_pos = next_pos
					break
				dash_pos = next_pos
			if dash_pos != pos:
				state.player_pos = dash_pos
				state.player_moved = true
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			var move_target2: Vector2i = pos + dv_seq
			if in_bounds(move_target2, cols, rows) and state.grid[move_target2.y][move_target2.x] == CharacterData.CellType.LIVE:
				state.player_pos = move_target2
				state.player_moved = true
				hit_cell(state, state.player_pos + dv_atk, slot_data[1], cols, rows, teleport_on_kill)
		CharacterData.SkillType.SAME_AA:
			var front_target: Vector2i = pos + dv_seq
			if not cell_is_enemy(state, front_target, cols, rows):
				return
			hit_cell(state, front_target, slot_data[0], cols, rows, teleport_on_kill)
			hit_cell(state, pos + 2 * dv_seq, slot_data[0], cols, rows, teleport_on_kill)
		CharacterData.SkillType.ORTHO_AA:
			hit_cell(state, pos + dv_seq, slot_data[0], cols, rows, teleport_on_kill)
			hit_cell(state, pos + dv_atk, slot_data[1], cols, rows, teleport_on_kill)


func skill_can_activate(
	state: RefCounted,
	skill: Array,
	cols: int,
	rows: int
) -> bool:
	var stype: int = CharacterData.classify_skill(skill)
	if stype != CharacterData.SkillType.SAME_AA:
		return true
	var front_dir: int = skill[0]
	return cell_is_enemy(state, state.player_pos + CharacterData.DIR_VECTOR[front_dir], cols, rows)

func count_legal_moves_at(state: RefCounted, pos: Vector2i, cols: int, rows: int) -> int:
	var count: int = 0
	for dir_id: int in CharacterData.DIR_VECTOR:
		if is_basic_move_legal(state, pos, dir_id, cols, rows):
			count += 1
	return count

func skill_changes_state(
	state: RefCounted,
	skill: Array,
	cols: int,
	rows: int,
	teleport_on_kill: bool
) -> bool:
	if not skill_can_activate(state, skill, cols, rows):
		return false
	var before_pos: Vector2i = state.player_pos
	var sim: RefCounted = state.duplicate_state()
	apply_skill_to_state(sim, skill, cols, rows, teleport_on_kill)
	if sim.kill_delta > 0:
		return true
	if sim.player_pos != before_pos:
		return true
	if not is_polluted(sim, sim.player_pos, cols, rows):
		return true
	return count_legal_moves_at(sim, sim.player_pos, cols, rows) > 0
