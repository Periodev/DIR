extends RefCounted

# PLN (PLaNner) — TBD: movement leaves vector traces as traps on the ground.
# Slot logic is a placeholder; full design pending.

var defer_player_move: bool = false

# ── Animation ──────────────────────────────────────────────────────────────────

func play_move(player: Node2D, _from_pos: Vector2, to_pos: Vector2) -> void:
	var tw: Tween = player.create_tween()
	tw.tween_property(player, "position", to_pos, 0.10) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_attack(player: Node2D, dir: int, _success: bool, _is_dash: bool = false) -> void:
	var dv: Vector2 = Vector2(CharacterData.DIR_VECTOR[dir])
	var origin: Vector2 = player.position
	var tw: Tween = player.create_tween()
	tw.tween_property(player, "position", origin + dv * 10.0, 0.06) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "position", origin, 0.10) \
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_hit_delay(_is_dash: bool = false) -> float:
	return 0.13

func play_charge_preview(_player: Node2D, _dir: int) -> void:
	pass

# ── Slot logic ─────────────────────────────────────────────────────────────────
# TBD: vector traces left on ground; slots act as trap remotes.

func on_slot_fire(_board: Node2D, _slot_idx: int, _combo_type: String, _dirs: Array[int]) -> void:
	pass  # TBD
