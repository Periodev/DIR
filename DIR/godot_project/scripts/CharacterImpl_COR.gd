extends RefCounted

const CORRippleEffect = preload("res://scripts/CORRippleEffect.gd")
const CORChargeRipple = preload("res://scripts/CORChargeRipple.gd")
const CORAttackArc    = preload("res://scripts/CORAttackArc.gd")
const COR_CHARGE_DUR  := 0.30   # 回波 0.20s + 停頓 0.10s

var _pending_penetration: bool = false
var defer_player_move: bool = false
var pending_kill_pos: Vector2i = Vector2i(-1, -1)

func play_move(player: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var fx := Node2D.new()
	fx.set_script(CORRippleEffect)
	fx.set("single", true)
	fx.position = from_pos
	player.get_parent().add_child(fx)
	if _pending_penetration:
		_pending_penetration = false
		# 滲透曲線：蓄力停頓 → 快速接近 → 半重疊前阻尼減速 → 推過後順滑完成
		var resist := from_pos + (to_pos - from_pos) * 0.58
		var tw := player.create_tween()
		tw.tween_interval(COR_CHARGE_DUR)
		tw.tween_property(player, "position", resist, 0.15)\
		  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.09)
		tw.tween_property(player, "position", to_pos, 0.09)\
		  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		var tw := player.create_tween()
		tw.tween_property(player, "position", to_pos, 0.12)\
		  .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func play_attack(player: Node2D, dir: int, success: bool, is_dash: bool) -> void:
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var origin := player.position

	# 蓄力波紋（所有攻擊共用）
	var charge_fx := Node2D.new()
	charge_fx.set_script(CORChargeRipple)
	charge_fx.position = origin
	player.get_parent().add_child(charge_fx)

	if is_dash and success:
		_pending_penetration = true  # play_move 用滲透曲線（內含 COR_CHARGE_DUR 延遲）
	elif is_dash and not success:
		# 滲透失敗：停頓後壓入被擋，彈回
		var tip := origin + Vector2(dv) * 60.0
		var tw := player.create_tween()
		tw.tween_interval(COR_CHARGE_DUR)
		tw.tween_property(player, "position", tip, 0.14)\
		  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.20)
		tw.tween_property(player, "position", origin, 0.15)\
		  .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		# STRIKE：停頓後放弧 + 點刺
		var tw_delay := player.create_tween()
		tw_delay.tween_interval(COR_CHARGE_DUR)
		tw_delay.tween_callback(func():
			var fx := Node2D.new()
			fx.set_script(CORAttackArc)
			fx.set("dir_vec", Vector2(dv))
			fx.position = origin
			player.get_parent().add_child(fx)
			var lunge_dist: float = 30.0 if success else 12.0
			var tip := origin + Vector2(dv) * lunge_dist
			var tw2 := player.create_tween()
			tw2.tween_property(player, "position", tip, 0.05)\
			   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.tween_property(player, "position", origin, 0.12)\
			   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))

func get_hit_delay(is_dash: bool) -> float:
	return COR_CHARGE_DUR + (0.15 if is_dash else 0.05)

func play_charge_preview(_player: Node2D, _dir: int) -> void:
	pass

func on_kill(board: Node2D, pos: Vector2i, _attack_dir: int) -> void:
	var world_pos := Vector2(
		pos.x * board.CELL_STEP + board.CELL_SIZE / 2.0,
		pos.y * board.CELL_STEP + board.CELL_SIZE / 2.0
	)
	board.player_node.animation_done.connect(func() -> void:
		board.get_tree().create_timer(0.15).timeout.connect(func() -> void:
			var fx := Node2D.new()
			fx.set_script(CORRippleEffect)
			fx.position = world_pos
			board.add_child(fx)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)

func on_failed_kill(board: Node2D, attack_dir: int) -> void:
	var player_vpos := Vector2(
		board.player_pos.x * board.CELL_STEP + board.CELL_SIZE / 2.0,
		board.player_pos.y * board.CELL_STEP + board.CELL_SIZE / 2.0
	)
	var stall_pos := player_vpos + Vector2(CharacterData.DIR_VECTOR[attack_dir]) * 60.0
	board.player_node.animation_done.connect(func() -> void:
		var fx := Node2D.new()
		fx.set_script(CORRippleEffect)
		fx.set("weak", true)
		fx.position = stall_pos
		board.add_child(fx)
	, CONNECT_ONE_SHOT)

func reset_state() -> void:
	_pending_penetration = false
