class_name VectorSlot

var capacity: int = 1
var label: String = ""
var stored: Array[int] = []

func _init(cap: int, lbl: String) -> void:
	capacity = cap
	label = lbl

func is_empty() -> bool:
	return stored.is_empty()

func is_full() -> bool:
	return stored.size() >= capacity

func record(dir: int) -> void:
	stored.append(dir)

func consume() -> Array[int]:
	var result: Array[int] = stored.duplicate()
	stored.clear()
	return result

func reset() -> void:
	stored.clear()

# Returns "" if not full.
# capacity=1 → "basic"
# capacity=2, same dirs → "same_dir"
# capacity=2, perpendicular → "orthogonal"
func combo_type() -> String:
	if not is_full():
		return ""
	if capacity == 1:
		return "basic"
	return "same_dir" if stored[0] == stored[1] else "orthogonal"

func display_text() -> String:
	var content: String = ""
	for d: int in stored:
		content += CharacterData.DIR_ARROWS[d]
	if content.is_empty():
		content = "-"
	return "[%s:%s]" % [label, content]
