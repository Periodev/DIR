extends RefCounted

const PLNSlashEffect = preload("res://scripts/PLNSlashEffect.gd")
const PLNChargeGlow  = preload("res://scripts/PLNChargeGlow.gd")
const PLNMoveTrail   = preload("res://scripts/PLNMoveTrail.gd")

const WINDUP := PLNSlashEffect.WINDUP

var pending_kill_pos: Vector2i = Vector2i(-1, -1)
var defer_player_move: bool = false

func play_move(player: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var trail := Node2D.new()
	trail.set_script(PLNMoveTrail)
	player.get_parent().add_child(trail)
	trail.setup(from_pos, to_pos)
	var tw := player.create_tween()
	tw.tween_property(player, "position", to_pos, 0.07)\
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func play_attack(player: Node2D, dir: int, success: bool, is_dash: bool) -> void:
	if is_dash:
		play_charge_preview(player, dir)
		var dv: Vector2 = Vector2(CharacterData.DIR_VECTOR[dir])
		var fx: Node2D = Node2D.new()
		fx.set_script(PLNSlashEffect)
		player.add_child(fx)
		fx.setup(dv, not success)   # short=true when blocked
	else:
		var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
		var origin := player.position
		var lunge_dist: float = 30.0 if success else 12.0
		var out_dur: float    = 0.08 if success else 0.05
		var back_dur: float   = 0.12 if success else 0.10
		var tip := origin + Vector2(dv) * lunge_dist
		var tw := player.create_tween()
		tw.tween_property(player, "position", tip, out_dur)\
		  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(player, "position", origin, back_dur)\
		  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_hit_delay(_is_dash: bool) -> float:
	return 0.25  # windup(0.22) + tip_extend(0.03)

func play_charge_preview(player: Node2D, dir: int) -> void:
	var glow: Node2D = Node2D.new()
	glow.set_script(PLNChargeGlow)
	player.add_child(glow)
	glow.setup(dir, WINDUP)

func on_kill(_board: Node2D, _pos: Vector2i, _attack_dir: int) -> void:
	pass

func on_failed_kill(_board: Node2D, _attack_dir: int) -> void:
	pass

# Called by Board when a DASH kill triggers post-kill reposition.
# Sets state and spawns the board-level slash + deferred move timer.
func begin_kill_anim(board: Node2D, origin: Vector2i, target: Vector2i, dir: int) -> void:
	pending_kill_pos = target
	defer_player_move = true
	board.player_node.play_pln_charge_glow(dir)
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var slash_fx: Node2D = Node2D.new()
	slash_fx.set_script(PLNSlashEffect)
	slash_fx.position = Vector2(
		origin.x * board.CELL_STEP + board.CELL_SIZE / 2.0,
		origin.y * board.CELL_STEP + board.CELL_SIZE / 2.0
	)
	board.add_child(slash_fx)
	slash_fx.setup(Vector2(dv), false, -1.0, true, 175.0)
	board.get_tree().create_timer(WINDUP + 0.03 + 0.10).timeout.connect(
		func(): trigger_move(board))

func trigger_move(board: Node2D) -> void:
	if not defer_player_move:
		return
	defer_player_move = false
	var from_pos: Vector2 = board.player_node.position
	var to_pos := Vector2(
		board.player_pos.x * board.CELL_STEP + board.CELL_SIZE / 2.0,
		board.player_pos.y * board.CELL_STEP + board.CELL_SIZE / 2.0
	)
	if from_pos != to_pos:
		board.player_node.position = to_pos
		board.player_node.play_move(from_pos)

func resolve_kill_visual() -> void:
	pending_kill_pos = Vector2i(-1, -1)

func reset_state() -> void:
	pending_kill_pos = Vector2i(-1, -1)
	defer_player_move = false
