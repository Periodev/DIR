extends CanvasLayer

var _turns_label: Label = null
var _deck_label: Label = null
var _recording_label: Label = null
var _hand_container: HBoxContainer = null
var _hand_slots: Array[Label] = []
var _slot_labels: Array[Label] = []
var _slot_container: HBoxContainer = null
var _message_label: Label = null
var _gameover_panel: PanelContainer = null

func _ready() -> void:
	# Turn counter (top-left)
	_turns_label = Label.new()
	_turns_label.add_theme_font_size_override("font_size", 22)
	_turns_label.position = Vector2(20.0, 10.0)
	_turns_label.size = Vector2(200.0, 30.0)
	add_child(_turns_label)

	# Deck count
	_deck_label = Label.new()
	_deck_label.add_theme_font_size_override("font_size", 18)
	_deck_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_deck_label.position = Vector2(20.0, 38.0)
	_deck_label.size = Vector2(200.0, 24.0)
	add_child(_deck_label)

	# Recording hint
	_recording_label = Label.new()
	_recording_label.add_theme_font_size_override("font_size", 20)
	_recording_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.1))
	_recording_label.text = ""
	_recording_label.position = Vector2(20.0, 62.0)
	_recording_label.size = Vector2(600.0, 28.0)
	add_child(_recording_label)

	# Hand panel (second-to-last row)
	var hand_panel: PanelContainer = PanelContainer.new()
	add_child(hand_panel)
	var hand_hbox: HBoxContainer = HBoxContainer.new()
	hand_hbox.add_theme_constant_override("separation", 6)
	hand_panel.add_child(hand_hbox)
	var hand_lbl: Label = Label.new()
	hand_lbl.text = "HAND  "
	hand_lbl.add_theme_font_size_override("font_size", 20)
	hand_hbox.add_child(hand_lbl)
	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 4)
	hand_hbox.add_child(_hand_container)

	# Slot panel (last row)
	var slot_panel: PanelContainer = PanelContainer.new()
	add_child(slot_panel)
	var slot_hbox: HBoxContainer = HBoxContainer.new()
	slot_hbox.add_theme_constant_override("separation", 12)
	slot_panel.add_child(slot_hbox)
	var slot_lbl: Label = Label.new()
	slot_lbl.text = "SLOTS  "
	slot_lbl.add_theme_font_size_override("font_size", 20)
	slot_hbox.add_child(slot_lbl)
	_slot_container = HBoxContainer.new()
	_slot_container.add_theme_constant_override("separation", 16)
	slot_hbox.add_child(_slot_container)

	# Controls hint
	_message_label = Label.new()
	_message_label.text = "WASD: Move  |  Q/E: Slot  |  Space: End Turn  |  R: Restart  |  F4: Char"
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(_message_label)

	# Game-over overlay
	_gameover_panel = PanelContainer.new()
	_gameover_panel.visible = false
	add_child(_gameover_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_gameover_panel.add_child(vbox)
	var go_title: Label = Label.new()
	go_title.text = "GAME OVER"
	go_title.add_theme_font_size_override("font_size", 40)
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(go_title)
	var restart_hint: Label = Label.new()
	restart_hint.text = "Press R to restart"
	restart_hint.add_theme_font_size_override("font_size", 20)
	restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(restart_hint)

	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()

# Rebuild slot labels for the current board character.  Call after restart().
func setup(board: Node2D) -> void:
	for child: Node in _hand_container.get_children():
		child.queue_free()
	_hand_slots.clear()
	for _i: int in board.hand_size:
		var lbl: Label = Label.new()
		lbl.text = "-"
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.custom_minimum_size = Vector2(36.0, 36.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hand_container.add_child(lbl)
		_hand_slots.append(lbl)

	for child: Node in _slot_container.get_children():
		child.queue_free()
	_slot_labels.clear()
	var key_hints: Array[String] = ["Q", "E", "Z", "X"]
	for i: int in board.vector_slots.size():
		var lbl: Label = Label.new()
		lbl.text = "[%s]-" % key_hints[i]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.custom_minimum_size = Vector2(160.0, 30.0)
		_slot_container.add_child(lbl)
		_slot_labels.append(lbl)

	_gameover_panel.visible = false
	_layout_ui()

# Refresh all dynamic text.  Call every time board_updated fires.
func update(board: Node2D) -> void:
	_turns_label.text = "TURN %d" % board.survival_turns
	_deck_label.text = "DECK: %d / 8" % board.deck.remaining()

	for i: int in _hand_slots.size():
		if i < board.hand.size():
			_hand_slots[i].text = CharacterData.DIR_ARROWS[board.hand[i]]
		else:
			_hand_slots[i].text = "-"

	var key_hints: Array[String] = ["Q", "E", "Z", "X"]
	for i: int in _slot_labels.size():
		if i >= board.vector_slots.size():
			break
		var slot: VectorSlot = board.vector_slots[i]
		var rec_marker: String = " ●REC" if board._recording_slot_idx == i else ""
		_slot_labels[i].text = "[%s]%s%s" % [key_hints[i], slot.display_text(), rec_marker]

	if board.game_state.is_recording():
		_recording_label.text = "● REC — play a direction card to store into slot"
	else:
		_recording_label.text = ""

func show_game_over() -> void:
	_gameover_panel.visible = true

func hide_game_over() -> void:
	_gameover_panel.visible = false

func _layout_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var inv_w: float = min(vp.x - 40.0, 960.0)
	var inv_x: float = (vp.x - inv_w) * 0.5

	# Hand panel and slot panel are the 4th and 5th children (after the 3 labels)
	var panels: Array[PanelContainer] = []
	for child: Node in get_children():
		if child is PanelContainer and child != _gameover_panel:
			panels.append(child as PanelContainer)

	if panels.size() >= 1:
		panels[0].position = Vector2(inv_x, vp.y - 130.0)
		panels[0].size = Vector2(inv_w, 60.0)
	if panels.size() >= 2:
		panels[1].position = Vector2(inv_x, vp.y - 68.0)
		panels[1].size = Vector2(inv_w, 60.0)

	_message_label.position = Vector2(0.0, vp.y - 30.0)
	_message_label.size = Vector2(vp.x, 30.0)

	_gameover_panel.size = Vector2(400.0, 180.0)
	_gameover_panel.position = Vector2(
		(vp.x - 400.0) * 0.5,
		(vp.y - 180.0) * 0.5
	)
