extends Node2D

const PLNSlashEffect  = preload("res://scripts/PLNSlashEffect.gd")
const PLNMoveTrail    = preload("res://scripts/PLNMoveTrail.gd")
const CORAttackArc    = preload("res://scripts/CORAttackArc.gd")
const CORRippleEffect = preload("res://scripts/CORRippleEffect.gd")

var character_name: String = "COR"
var character_color: Color = Color(0.2, 0.4, 0.9)
var character_shape: String = "hexagon"
var facing_dir: int = CharacterData.Direction.UP
var _pending_penetration: bool = false

func set_character(char_name: String) -> void:
	character_name = char_name
	var data = CharacterData.CHARACTERS[char_name]
	character_color = data["color"]
	character_shape = data["shape"]
	queue_redraw()

func set_facing(dir: int) -> void:
	if dir == CharacterData.Direction.NONE:
		return
	if dir == facing_dir:
		return
	facing_dir = dir
	queue_redraw()

func _draw() -> void:
	var points: PackedVector2Array
	match character_shape:
		"circle":
			draw_circle(Vector2.ZERO, 22.0, character_color)
			draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color.WHITE, 2.0)
			return
		"diamond":
			points = PackedVector2Array([
				Vector2(0, -22),
				Vector2(22, 0),
				Vector2(0, 22),
				Vector2(-22, 0),
			])
		"pentagon":
			points = _make_polygon(5, 20.0, -PI / 2.0)
		"hexagon":
			points = _make_polygon(6, 20.0, 0.0)
		"square":
			points = PackedVector2Array([
				Vector2(-20, -20),
				Vector2(20, -20),
				Vector2(20, 20),
				Vector2(-20, 20),
			])
		"blade_diamond":
			var base := PackedVector2Array([
				Vector2(0, -35),    # 前方尖端
				Vector2(14, 0),     # 右側最寬
				Vector2(0, 14.0 * sqrt(3)),  # 後方 60° 銳角頂點
				Vector2(-14, 0),    # 左側最寬
			])
			var angle := _facing_to_angle(facing_dir)
			points = PackedVector2Array()
			for p in base:
				points.append(p.rotated(angle))
		_:
			points = _make_polygon(6, 20.0, 0.0)

	draw_polygon(points, PackedColorArray([character_color]))
	draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 2.0)

func play_move(from_pos: Vector2) -> void:
	var to_pos := position          # already set by Board
	position = from_pos             # snap back to start
	match character_name:
		"EXE":
			# [1] Anticipation 0.05s — coil: compress scale, hold position
			# [2] Lock         0.02s — freeze before release
			# [3] Dash         0.08s — EASE_IN burst, no deform, heavy object launched
			# [4] Hard stop    0.02s — single minimal settle, nearly no bounce
			var dir := (to_pos - from_pos).normalized()
			var tw := create_tween()
			tw.tween_interval(0.07)
			tw.tween_property(self, "position", to_pos, 0.08)\
			  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_property(self, "position", to_pos + dir * 3.0, 0.01)\
			  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "position", to_pos, 0.01)\
			  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			var tw2 := create_tween()
			tw2.tween_property(self, "scale", Vector2(0.88, 0.85), 0.05)\
			   .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw2.tween_interval(0.02)
			tw2.tween_property(self, "scale", Vector2(1.0, 1.0), 0.02)\
			   .set_trans(Tween.TRANS_LINEAR)
		"PLN":
			var trail := Node2D.new()
			trail.set_script(PLNMoveTrail)
			get_parent().add_child(trail)
			trail.setup(from_pos, to_pos)
			var tw := create_tween()
			tw.tween_property(self, "position", to_pos, 0.07)\
			  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_:  # COR, GRD, and others
			if character_name == "COR":
				var fx := Node2D.new()
				fx.set_script(CORRippleEffect)
				fx.set("single", true)
				fx.position = from_pos
				get_parent().add_child(fx)
			if character_name == "COR" and _pending_penetration:
				_pending_penetration = false
				# 滲透曲線：快速接近 → 半重疊前阻尼減速 → 推過後順滑完成
				var resist := from_pos + (to_pos - from_pos) * 0.58
				var tw := create_tween()
				tw.tween_property(self, "position", resist, 0.15)\
				  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				tw.tween_interval(0.09)
				tw.tween_property(self, "position", to_pos, 0.09)\
				  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			else:
				var tw := create_tween()
				tw.tween_property(self, "position", to_pos, 0.12)\
				  .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func play_attack(dir: int, success: bool, is_dash: bool = false) -> void:
	match character_name:
		"COR": _attack_COR(dir, success, is_dash)
		"PLN": _attack_PLN(dir, success, is_dash)
		"EXE": _attack_EXE(dir, success, is_dash)
		"GRD": _attack_GRD(dir, success, is_dash)
		_:     _attack_generic(dir, success)

func _attack_COR(dir: int, success: bool, is_dash: bool) -> void:
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var origin := position
	if is_dash and success:
		_pending_penetration = true  # play_move 用滲透曲線
	elif is_dash and not success:
		# 滲透失敗：同樣快速壓入（阻力感），約20%處被擋住，加速彈回
		var tip := origin + Vector2(dv) * 60.0
		var tw := create_tween()
		tw.tween_property(self, "position", tip, 0.14)\
		  .set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.20)
		tw.tween_property(self, "position", origin, 0.15)\
		  .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		# STRIKE：先放弧形，再做點刺動畫
		var fx := Node2D.new()
		fx.set_script(CORAttackArc)
		fx.set("dir_vec", Vector2(dv))
		fx.position = origin
		get_parent().add_child(fx)
		_attack_generic(dir, success)

func _attack_PLN(dir: int, success: bool, is_dash: bool) -> void:
	if is_dash:
		var dv := Vector2(CharacterData.DIR_VECTOR[dir])
		var fx := Node2D.new()
		fx.set_script(PLNSlashEffect)
		add_child(fx)
		fx.setup(dv, not success)   # short=true when blocked
	else:
		_attack_generic(dir, success)

func _attack_EXE(dir: int, success: bool, _is_dash: bool) -> void:
	_attack_generic(dir, success)

func _attack_GRD(dir: int, success: bool, _is_dash: bool) -> void:
	_attack_generic(dir, success)

func _attack_generic(dir: int, success: bool) -> void:
	var dv: Vector2i = CharacterData.DIR_VECTOR[dir]
	var origin := position
	var lunge_dist: float = 30.0 if success else 12.0
	var out_dur: float    = 0.08 if success else 0.05
	var back_dur: float   = 0.12 if success else 0.10
	var tip := origin + Vector2(dv) * lunge_dist
	var tw := create_tween()
	tw.tween_property(self, "position", tip, out_dur)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", origin, back_dur)\
	  .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _facing_to_angle(dir: int) -> float:
	match dir:
		CharacterData.Direction.UP:    return 0.0
		CharacterData.Direction.DOWN:  return PI
		CharacterData.Direction.LEFT:  return -PI / 2.0
		CharacterData.Direction.RIGHT: return PI / 2.0
		_: return 0.0

func _make_polygon(sides: int, radius: float, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var angle = start_angle + (TAU / sides) * i
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
