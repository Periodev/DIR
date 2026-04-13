class_name CharacterImpl_RDR
extends RefCounted

static func get_config() -> CharacterData.Config:
	var c := CharacterData.Config.new()
	c.seq_slots      = 9
	c.max_moves      = 2
	c.max_attacks    = 3
	c.teleport_on_kill = true
	c.skill_mixed    = false
	c.use_rdr_classifier = true
	return c
