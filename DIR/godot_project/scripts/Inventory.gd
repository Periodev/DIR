class_name Inventory

var queue: Array = []  # Array of Direction values, index 0 = oldest
var hold: int = CharacterData.Direction.NONE
var max_size: int = 3
var has_hold: bool = false
var has_charge_marker: bool = false
var charge_direction: int = CharacterData.Direction.NONE
var charge_value: int = 0
var charge_max: int = 0

func setup(char_name: String) -> void:
	var data = CharacterData.CHARACTERS[char_name]
	max_size = data["seq"]
	has_hold = data["has_hold"]
	has_charge_marker = data.get("has_charge_marker", false)
	charge_max = data.get("charge_max", 0)
	reset()

func reset() -> void:
	queue.clear()
	hold = CharacterData.Direction.NONE
	charge_direction = CharacterData.Direction.NONE
	charge_value = 0

func push(dir: int) -> void:
	if queue.size() >= max_size:
		queue.pop_front()
	queue.push_back(dir)

func pop() -> int:
	if queue.is_empty():
		return CharacterData.Direction.NONE
	return queue.pop_front()

func peek() -> int:
	if queue.is_empty():
		return CharacterData.Direction.NONE
	return queue[0]

func toggle_hold() -> void:
	if not has_hold:
		return
	if hold != CharacterData.Direction.NONE:
		# Hold has content -> cycle through the queue when full.
		if queue.size() >= max_size:
			var displaced: int = queue.pop_front()
			queue.push_back(hold)
			hold = displaced
		else:
			queue.push_back(hold)
			hold = CharacterData.Direction.NONE
	elif not queue.is_empty():
		# Hold empty -> take first slot
		hold = queue.pop_front()

func is_full() -> bool:
	return queue.size() >= max_size

func find_direction(dir: int) -> int:
	for i in queue.size():
		if queue[i] == dir:
			return i
	return -1

func remove_at(idx: int) -> void:
	queue.remove_at(idx)

func has_direction(dir: int) -> bool:
	return dir in queue or hold == dir

func register_move(dir: int) -> void:
	if not has_charge_marker:
		return
	if charge_direction == CharacterData.Direction.NONE:
		charge_direction = dir
	if charge_value < charge_max:
		charge_value += 1

func is_charge_full() -> bool:
	return has_charge_marker and charge_value >= charge_max

func consume_charge() -> bool:
	if not is_charge_full():
		return false
	charge_value = 0
	return true
