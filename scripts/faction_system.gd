class_name FactionSystem
extends RefCounted
## DEPRECATED. Factions were removed - opponent identity now comes from
## sorcerer archetypes/spellbooks instead. This stub keeps the API alive
## so older callsites compile and render neutrally, but every value is no-op.
## Safe to delete once the call graph is fully scrubbed.

enum Faction { NONE, GILDED_CODEX, MIDNIGHT_SKULK, IRONCLAD_BASTIONS, SCREAMING_TIDE, THUNDERING_MAW }

const COUNTER_CHANCE_PENALTY: float = 0.0
const COUNTER_MOMENTUM_PENALTY: int = 0

const COUNTERS: Dictionary = {}

const _NEUTRAL_INFO: Dictionary = {
	"name": "Goblin Crew",
	"style": "",
	"color": Color(0.78, 0.78, 0.82),
}

static func get_faction_info(_faction: int) -> Dictionary:
	return _NEUTRAL_INFO.duplicate()

static func get_counter_result(_attacker_faction: int, _defender_faction: int) -> int:
	return 0

static func get_majority_faction(_goblins: Array) -> int:
	return Faction.NONE

static func get_all_factions() -> Array[int]:
	return []
