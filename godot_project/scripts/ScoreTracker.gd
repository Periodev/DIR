class_name ScoreTracker
extends RefCounted

const SKILL_KEYS: Array[String] = ["pierce", "ram", "spin", "dual"]
const SKILL_LABELS: Dictionary = {
	"pierce": "PEN",
	"ram": "RAM",
	"spin": "SPN",
	"dual": "DBL",
}

var avg_slot_sum: int = 0
var avg_slot_samples: int = 0
var step_move_count: int = 0
var step_attack_count: int = 0
var skill_stats: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	avg_slot_sum = 0
	avg_slot_samples = 0
	step_move_count = 0
	step_attack_count = 0
	skill_stats.clear()
	for key: String in SKILL_KEYS:
		skill_stats[key] = {
			"synth": 0,
			"cast": 0,
			"kills": 0,
			"recovery": 0,
		}

func record_slot_usage(occupied_slots: int) -> void:
	avg_slot_sum += occupied_slots
	avg_slot_samples += 1

func record_step(is_move: bool, is_attack: bool, occupied_slots: int) -> void:
	if is_move:
		step_move_count += 1
	if is_attack:
		step_attack_count += 1
	record_slot_usage(occupied_slots)

func average_slot_usage() -> float:
	if avg_slot_samples <= 0:
		return 0.0
	return float(avg_slot_sum) / float(avg_slot_samples)

func move_usage_ratio() -> float:
	var total_steps: int = step_move_count + step_attack_count
	if total_steps <= 0:
		return 0.0
	return float(step_move_count) / float(total_steps)

static func skill_stat_key(stype: int) -> String:
	match stype:
		CharacterData.SkillType.SAME_AA:
			return "pierce"
		CharacterData.SkillType.SAME_MA:
			return "ram"
		CharacterData.SkillType.LEFT_MA, CharacterData.SkillType.RIGHT_MA:
			return "spin"
		CharacterData.SkillType.ORTHO_AA:
			return "dual"
		_:
			return ""

func record_skill_synthesis(skill_type: int) -> void:
	var key: String = skill_stat_key(skill_type)
	if key.is_empty():
		return
	var stats: Dictionary = skill_stats.get(key, {})
	stats["synth"] = int(stats.get("synth", 0)) + 1
	skill_stats[key] = stats

func record_skill_cast(skill_type: int, kills: int, recovery: int) -> void:
	var key: String = skill_stat_key(skill_type)
	if key.is_empty():
		return
	var stats: Dictionary = skill_stats.get(key, {})
	stats["cast"] = int(stats.get("cast", 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + kills
	stats["recovery"] = int(stats.get("recovery", 0)) + recovery
	skill_stats[key] = stats

func total_skill_syntheses() -> int:
	var total: int = 0
	for key: String in SKILL_KEYS:
		var stats: Dictionary = skill_stats.get(key, {})
		total += int(stats.get("synth", 0))
	return total

func skill_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var total_synth: int = total_skill_syntheses()
	for key: String in SKILL_KEYS:
		var stats: Dictionary = skill_stats.get(key, {})
		var synth: int = int(stats.get("synth", 0))
		var cast: int = int(stats.get("cast", 0))
		var kills: int = int(stats.get("kills", 0))
		var recovery: int = int(stats.get("recovery", 0))
		rows.append({
			"label": SKILL_LABELS[key],
			"synth_pct": 0 if total_synth <= 0 else int(round(float(synth) * 100.0 / float(total_synth))),
			"avg_kills": 0.0 if cast <= 0 else float(kills) / float(cast),
			"recovery_pct": 0 if cast <= 0 else int(round(float(recovery) * 50.0 / float(cast))),
		})
	return rows

func score_pollution_threat(metrics: Dictionary) -> Dictionary:
	var score: int = 0
	var legal_moves: int = int(metrics.get("legal_moves", 0))
	var effective_skills: int = int(metrics.get("effective_skills", 0))
	var central_pollution: int = int(metrics.get("central_pollution", 0))
	var cluster: int = int(metrics.get("largest_pollution_cluster", 0))
	var chokepoints: int = int(metrics.get("polluted_chokepoints", 0))
	var patterns: Array[String] = []

	if bool(metrics.get("player_on_pollution", false)):
		score += 35
		patterns.append("player_on_pollution")
		if bool(metrics.get("has_combinable_material", false)):
			score += 12
			patterns.append("combine_locked")
	score += (4 - legal_moves) * 10
	if legal_moves <= 1:
		score += 8
		patterns.append("low_escape")
	score += central_pollution * 3
	if central_pollution >= 4:
		patterns.append("central_pollution")
	if cluster >= 3:
		score += min(14, cluster * 2)
		patterns.append("pollution_chain")
	if chokepoints > 0:
		score += min(12, chokepoints * 4)
		patterns.append("pollution_pocket")
	if effective_skills == 0:
		score += 20
		patterns.append("no_effective_skill")
	elif effective_skills == 1:
		score += 10
	if bool(metrics.get("game_over", false)):
		score = 100
		patterns.append("failed")

	return {
		"score": clamp(score, 0, 100),
		"polluted_tiles": int(metrics.get("polluted_tiles", 0)),
		"central_pollution": central_pollution,
		"legal_moves": legal_moves,
		"effective_skills": effective_skills,
		"patterns": patterns,
	}
