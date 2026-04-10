extends RefCounted

var defer_player_move: bool = false

# ── Animation ──────────────────────────────────────────────────────────────────

func play_move(player: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var dir: Vector2 = (to_pos - from_pos).normalized()
	var tw: Tween = player.create_tween()
	tw.tween_interval(0.03)
	tw.tween_property(player, "position", to_pos, 0.07) \
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "position", to_pos + dir * 3.0, 0.01) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "position", to_pos, 0.01) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func play_attack(player: Node2D, dir: int, _success: bool, _is_dash: bool = false) -> void:
	var dv: Vector2 = Vector2(CharacterData.DIR_VECTOR[dir])
	var origin: Vector2 = player.position
	var tw: Tween = player.create_tween()
	tw.tween_property(player, "position", origin - dv * 6.0, 0.03) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.08)
	tw.tween_property(player, "position", origin + dv * 50.0, 0.06) \
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.15)
	tw.tween_property(player, "position", origin, 0.10) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_hit_delay(_is_dash: bool = false) -> float:
	return 0.17  # pull(0.03) + pause(0.08) + dash(0.06)

func play_charge_preview(_player: Node2D, _dir: int) -> void:
	pass

# ── Slot logic ─────────────────────────────────────────────────────────────────
# EXE: attack-focused.
#   basic      → single directional strike
#   same_dir   → Skill A: pierce two cells in a line
#   orthogonal → Skill B: strike in both stored directions simultaneously

func on_slot_fire(board: Node2D, _slot_idx: int, combo_type: String, dirs: Array[int]) -> void:
	var dir: int = dirs[0]
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var target: Vector2i = board.player_pos + dv

	match combo_type:
		"basic":
			board.kill_cell(target)
		"same_dir":
			board.kill_cell(target)
			board.kill_cell(target + dv)
		"orthogonal":
			board.kill_cell(target)
			var dir2: int = dirs[1]
			board.kill_cell(board.player_pos + CharacterData.DIR_VECTOR[dir2])

	board.game_state.set_state(CharacterData.GameStateEnum.PRESENTING)
	board.player_node.play_attack(dir, true)
