class_name Deck

# 8-card deck: each of the 4 directions appears twice.
# Auto-reshuffles when emptied.

var _cards: Array[int] = []

func _init() -> void:
	_shuffle_new()

func _shuffle_new() -> void:
	_cards = [
		CharacterData.Direction.UP,    CharacterData.Direction.UP,
		CharacterData.Direction.DOWN,  CharacterData.Direction.DOWN,
		CharacterData.Direction.LEFT,  CharacterData.Direction.LEFT,
		CharacterData.Direction.RIGHT, CharacterData.Direction.RIGHT,
	]
	_cards.shuffle()

func draw() -> int:
	if _cards.is_empty():
		_shuffle_new()
	return _cards.pop_front()

func remaining() -> int:
	return _cards.size()
