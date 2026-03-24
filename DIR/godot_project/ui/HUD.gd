extends CanvasLayer

var score_label: Label
var combo_label: Label
var inventory_container: HBoxContainer
var hold_container: HBoxContainer
var hold_slot: Label
var freeze_label: Label
var gameover_panel: PanelContainer
var gameover_score: Label
var message_label: Label

var slot_labels: Array = []
var _max_slots: int = 3
var _has_hold: bool = false

func _ready() -> void:
	# Score - top right
	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.position = Vector2(600, 10)
	score_label.size = Vector2(180, 50)
	add_child(score_label)

	# Combo - below score
	combo_label = Label.new()
	combo_label.text = ""
	combo_label.add_theme_font_size_override("font_size", 22)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.position = Vector2(600, 55)
	combo_label.size = Vector2(180, 30)
	add_child(combo_label)

	# Inventory container - bottom
	var inv_bg = PanelContainer.new()
	inv_bg.position = Vector2(20, 700)
	inv_bg.size = Vector2(760, 60)
	add_child(inv_bg)

	var inv_hbox = HBoxContainer.new()
	inv_hbox.add_theme_constant_override("separation", 8)
	inv_bg.add_child(inv_hbox)

	# Label for "Queue:"
	var q_label = Label.new()
	q_label.text = "SEQ "
	q_label.add_theme_font_size_override("font_size", 20)
	inv_hbox.add_child(q_label)

	inventory_container = HBoxContainer.new()
	inventory_container.add_theme_constant_override("separation", 4)
	inv_hbox.add_child(inventory_container)

	# Separator
	var sep = VSeparator.new()
	inv_hbox.add_child(sep)

	# Hold label
	var h_label = Label.new()
	h_label.text = "HOLD "
	h_label.add_theme_font_size_override("font_size", 20)
	inv_hbox.add_child(h_label)

	hold_slot = Label.new()
	hold_slot.text = "·"
	hold_slot.add_theme_font_size_override("font_size", 28)
	hold_slot.custom_minimum_size = Vector2(36, 36)
	hold_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_hbox.add_child(hold_slot)

	hold_container = inv_hbox

	# Freeze label
	freeze_label = Label.new()
	freeze_label.text = ""
	freeze_label.add_theme_font_size_override("font_size", 24)
	freeze_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.9))
	freeze_label.position = Vector2(20, 10)
	freeze_label.size = Vector2(200, 30)
	add_child(freeze_label)

	# Message
	message_label = Label.new()
	message_label.text = "方向鍵/WASD 移動 | Space: Hold | R: 重來"
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.position = Vector2(0, 770)
	message_label.size = Vector2(800, 30)
	message_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(message_label)

	# Game over panel
	gameover_panel = PanelContainer.new()
	gameover_panel.position = Vector2(200, 250)
	gameover_panel.size = Vector2(400, 250)
	gameover_panel.visible = false
	add_child(gameover_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gameover_panel.add_child(vbox)

	var go_title = Label.new()
	go_title.text = "GAME OVER"
	go_title.add_theme_font_size_override("font_size", 40)
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(go_title)

	gameover_score = Label.new()
	gameover_score.text = "0"
	gameover_score.add_theme_font_size_override("font_size", 60)
	gameover_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_score.add_theme_color_override("font_color", Color(0.95, 0.77, 0.06))
	vbox.add_child(gameover_score)

	var restart_hint = Label.new()
	restart_hint.text = "按 R 重新開始"
	restart_hint.add_theme_font_size_override("font_size", 20)
	restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(restart_hint)

func setup(char_name: String) -> void:
	var data = CharacterData.CHARACTERS[char_name]
	_max_slots = data["seq"]
	_has_hold = data["has_hold"]

	# Rebuild slots
	for child in inventory_container.get_children():
		child.queue_free()
	slot_labels.clear()

	for i in _max_slots:
		var slot = Label.new()
		slot.text = "·"
		slot.add_theme_font_size_override("font_size", 28)
		slot.custom_minimum_size = Vector2(36, 36)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_container.add_child(slot)
		slot_labels.append(slot)

	hold_slot.visible = _has_hold
	# Hide hold label too
	var h_label_node = hold_container.get_child(3) if hold_container.get_child_count() > 3 else null
	if h_label_node:
		h_label_node.visible = _has_hold

	gameover_panel.visible = false

func update_inventory(inv: Inventory) -> void:
	for i in _max_slots:
		if i < inv.queue.size():
			slot_labels[i].text = CharacterData.DIR_ARROWS[inv.queue[i]]
		else:
			slot_labels[i].text = "·"

	if _has_hold:
		hold_slot.text = CharacterData.DIR_ARROWS[inv.hold] if inv.hold != CharacterData.Direction.NONE else "·"

func update_score(score: int) -> void:
	score_label.text = str(score)

func update_combo(combo: int) -> void:
	if combo > 0:
		combo_label.text = "COMBO x%d" % combo
	else:
		combo_label.text = ""

func update_freeze(steps: int) -> void:
	if steps > 0:
		freeze_label.text = "❄ FREEZE: %d" % steps
	else:
		freeze_label.text = ""

func show_game_over(final_score: int) -> void:
	gameover_score.text = str(final_score)
	gameover_panel.visible = true

func hide_game_over() -> void:
	gameover_panel.visible = false
