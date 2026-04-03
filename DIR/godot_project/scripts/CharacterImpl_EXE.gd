extends RefCounted

const EXEJetEffect    = preload("res://scripts/EXEJetEffect.gd")
const EXEImpactArc    = preload("res://scripts/EXEImpactArc.gd")
const EXEImpactArcHit = preload("res://scripts/EXEImpactArcHit.gd")

var defer_player_move: bool = false
var pending_kill_pos: Vector2i = Vector2i(-1, -1)

func play_move(player: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	# [1] Anticipation 0.05s — coil: compress scale, hold position
	# [2] Lock         0.02s — freeze before release
	# [3] Dash         0.08s — EASE_IN burst, no deform, heavy object launched
	# [4] Hard stop    0.02s — single minimal settle, nearly no bounce
	var dir := (to_pos - from_pos).normalized()
	var jet := Node2D.new()
	jet.set_script(EXEJetEffect)
	jet.set("dir_vec", -dir)
	jet.position = from_pos
	player.get_parent().add_child(jet)
	var tw := player.create_tween()
	tw.tween_interval(0.04)
	tw.tween_property(player, "position", to_pos, 0.07)\
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "position", to_pos + dir * 3.0, 0.01)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "position", to_pos, 0.01)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tw2 := player.create_tween()
	tw2.tween_property(player, "scale", Vector2(0.88, 0.85), 0.05)\
	   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_interval(0.02)
	tw2.tween_property(player, "scale", Vector2(1.0, 1.0), 0.02)\
	   .set_trans(Tween.TRANS_LINEAR)

func play_attack(player: Node2D, dir: int, success: bool, _is_dash: bool) -> void:
	var dv := Vector2(CharacterData.DIR_VECTOR[dir])
	var origin := player.position

	# 時間軸
	var pull_dur  := 0.01                          # 後退
	var pause_dur := 0.15                          # 停頓
	var dash_dur  := 0.06 if success else 0.04    # 衝出
	var back_dur  := 0.10 if success else 0.07    # 回歸
	var pull_dist := 6.0                          # 後退距離
	var lunge_dist := 60.0 if success else 50.0   # 衝出距離
	var pre_delay := pull_dur + pause_dur

	# 衝出瞬間的強力 jet（後方噴射）
	var jet1 := Node2D.new()
	jet1.set_script(EXEJetEffect)
	jet1.set("dir_vec", -dv)
	jet1.set("force_main_idx", 2)
	jet1.set("use_attack_pool", true)
	jet1.set("time_scale", 1.2)
	var tw_j1 := player.create_tween()
	tw_j1.tween_interval(pre_delay)
	tw_j1.tween_callback(func():
		jet1.position = origin - dv * pull_dist
		player.get_parent().add_child(jet1))

	# 衝到最遠點時放出橘色衝擊弧
	var arc_delay := pre_delay + dash_dur
	var arc_pos   := origin + dv * lunge_dist
	var tw_arc := player.create_tween()
	tw_arc.tween_interval(arc_delay)
	tw_arc.tween_callback(func():
		var arc := Node2D.new()
		arc.set_script(EXEImpactArcHit if success else EXEImpactArc)
		arc.set("dir_vec", dv)
		arc.position = arc_pos
		player.get_parent().add_child(arc))

	# 位移：後退 → 停頓 → 衝出 → 回歸
	var tw := player.create_tween()
	tw.tween_property(player, "position", origin - dv * pull_dist, pull_dur)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(pause_dur)
	tw.tween_property(player, "position", origin + dv * lunge_dist, dash_dur)\
	  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.25)  # 撞擊停頓
	tw.tween_property(player, "position", origin, back_dur)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_hit_delay(_is_dash: bool) -> float:
	return 0.22  # pull(0.01) + pause(0.15) + dash(0.06)

func play_charge_preview(_player: Node2D, _dir: int) -> void:
	pass

func on_kill(_board: Node2D, _pos: Vector2i, _attack_dir: int) -> void:
	pass

func on_failed_kill(_board: Node2D, _attack_dir: int) -> void:
	pass

func reset_state() -> void:
	pass
