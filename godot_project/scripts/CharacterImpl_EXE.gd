class_name CharacterImpl_EXE
extends RefCounted

static func get_config() -> CharacterData.Config:
	var c := CharacterData.Config.new()
	c.seq_slots  = 4
	c.max_moves  = 2
	c.max_attacks = 2
	return c
