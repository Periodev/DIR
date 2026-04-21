class_name CharacterImpl_RDR
extends RefCounted

static func get_config() -> CharacterData.Config:
	var c := CharacterData.Config.new()
	c.seq_slots      = 9
	c.max_moves      = 3
	c.max_attacks    = 1
	c.attack_queue_cap = 5
	c.teleport_on_kill = true
	c.skill_mixed    = false
	c.use_rdr_classifier = true
	c.skill_slot_count = 4
	c.use_unified_slots = true
	return c
