extends RefCounted

# RDR (ReDiRector) — movement-focused character.
# Vector slots unlock advanced repositioning.

var defer_player_move: bool = false

# ── Animation ──────────────────────────────────────────────────────────────────

func play_move(player: Node2D, _from_pos: Vector2, to_pos: Vector2) -> void:
	var tw: Tween = player.create_tween()
	tw.tween_property(player, "position", to_pos, 0.07) \
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func play_attack(player: Node2D, dir: int, _success: bool, _is_dash: bool = false) -> void:
	var dv: Vector2 = Vector2(CharacterData.DIR_VECTOR[dir])
	var origin: Vector2 = player.position
	var tw: Tween = player.create_tween()
	tw.tween_property(player, "position", origin + dv * 12.0, 0.05) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "position", origin, 0.08) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_hit_delay(_is_dash: bool = false) -> float:
	return 0.13

func play_charge_preview(_player: Node2D, _dir: int) -> void:
	pass

# ── Slot logic ─────────────────────────────────────────────────────────────────
# RDR: movement-focused. Slots unlock advanced repositioning.
#   basic      → move 1 cell in stored direction
#   same_dir   → dash: slide until hitting a dead cell or wall
#   orthogonal → diagonal: step one cell in each stored direction simultaneously

func on_slot_fire(board: Node2D, _slot_idx: int, combo_type: String, dirs: Array[int]) -> void:
	var dir: int = dirs[0]
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]

	match combo_type:
		"basic":
			var target: Vector2i = board.player_pos + dv
			if _is_valid_live(board, target):
				board.player_pos = target

		"same_dir":
			var pos: Vector2i = board.player_pos
			for _i: int in board.COLS + board.ROWS:
				var next: Vector2i = pos + dv
				if not _is_valid_live(board, next):
					break
				pos = next
			board.player_pos = pos

		"orthogonal":
			var dir2: int = dirs[1]
			var dv2: Vector2i = CharacterData.DIR_VECTOR[dir2]
			var target: Vector2i = board.player_pos + dv + dv2
			if _is_in_bounds(board, target) and board.grid[target.y][target.x] == CharacterData.CellType.LIVE:
				board.player_pos = target

	board.player_facing_dir = dir

func _is_valid_live(board: Node2D, pos: Vector2i) -> bool:
	return _is_in_bounds(board, pos) and board.grid[pos.y][pos.x] == CharacterData.CellType.LIVE

func _is_in_bounds(board: Node2D, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board.COLS and pos.y >= 0 and pos.y < board.ROWS
