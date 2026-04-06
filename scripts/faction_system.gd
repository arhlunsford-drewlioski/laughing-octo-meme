class_name FactionSystem
extends RefCounted
## Faction identities and RPSLS counter matchup system.

enum Faction { NONE, GILDED_CODEX, MIDNIGHT_SKULK, IRONCLAD_BASTIONS, SCREAMING_TIDE, THUNDERING_MAW }

const COUNTER_CHANCE_PENALTY: float = 0.10
const COUNTER_MOMENTUM_PENALTY: int = 1

# RPSLS graph: each faction beats exactly 2 others.
const COUNTERS: Dictionary = {
	Faction.GILDED_CODEX: [Faction.IRONCLAD_BASTIONS, Faction.THUNDERING_MAW],
	Faction.MIDNIGHT_SKULK: [Faction.GILDED_CODEX, Faction.SCREAMING_TIDE],
	Faction.IRONCLAD_BASTIONS: [Faction.MIDNIGHT_SKULK, Faction.SCREAMING_TIDE],
	Faction.SCREAMING_TIDE: [Faction.GILDED_CODEX, Faction.THUNDERING_MAW],
	Faction.THUNDERING_MAW: [Faction.MIDNIGHT_SKULK, Faction.IRONCLAD_BASTIONS],
}

static func get_faction_info(faction: int) -> Dictionary:
	match faction:
		Faction.GILDED_CODEX:
			return { "name": "Gilded Codex", "style": "Possession", "color": Color(0.85, 0.75, 0.3) }
		Faction.MIDNIGHT_SKULK:
			return { "name": "Midnight Skulk", "style": "Counter-Attack", "color": Color(0.5, 0.25, 0.7) }
		Faction.IRONCLAD_BASTIONS:
			return { "name": "Ironclad Bastions", "style": "Set Piece", "color": Color(0.5, 0.55, 0.65) }
		Faction.SCREAMING_TIDE:
			return { "name": "Screaming Tide", "style": "High Press", "color": Color(0.85, 0.25, 0.2) }
		Faction.THUNDERING_MAW:
			return { "name": "Thundering Maw", "style": "Physical", "color": Color(0.45, 0.75, 0.3) }
		_:
			return { "name": "Unaffiliated", "style": "Mixed", "color": Color(0.4, 0.4, 0.4) }

static func get_counter_result(attacker_faction: int, defender_faction: int) -> int:
	## Returns +1 if attacker counters defender, -1 if defender counters attacker, 0 if neutral.
	if attacker_faction == Faction.NONE or defender_faction == Faction.NONE:
		return 0
	if attacker_faction == defender_faction:
		return 0
	var attacker_beats: Array = COUNTERS.get(attacker_faction, [])
	if defender_faction in attacker_beats:
		return 1
	var defender_beats: Array = COUNTERS.get(defender_faction, [])
	if attacker_faction in defender_beats:
		return -1
	return 0

static func get_majority_faction(goblins: Array) -> int:
	## Returns the faction with 3+ members, or NONE if no majority.
	var counts: Dictionary = {}
	for goblin in goblins:
		var f: int = goblin.faction
		if f == Faction.NONE:
			continue
		counts[f] = counts.get(f, 0) + 1
	var best_faction: int = Faction.NONE
	var best_count: int = 0
	for f in counts:
		if counts[f] > best_count:
			best_count = counts[f]
			best_faction = f
	if best_count >= 3:
		return best_faction
	return Faction.NONE

static func get_all_factions() -> Array[int]:
	return [Faction.GILDED_CODEX, Faction.MIDNIGHT_SKULK, Faction.IRONCLAD_BASTIONS, Faction.SCREAMING_TIDE, Faction.THUNDERING_MAW]
