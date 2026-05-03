class_name TeamData
extends RefCounted
## A single team in the tournament.

var team_name: String = ""
var roster: Array[GoblinData] = []
var formation: Formation = null
var faction: int = 0  # legacy - factions removed but field kept for compat
var is_player: bool = false
var team_index: int = -1

# Opponent's signature spellbook (book + pages). Player team leaves null - the
# player's book lives on RunManager.run_spellbook.
var spellbook: SpellbookData = null
var archetype_name: String = ""

func get_strength() -> int:
	## Sum of all stats across the roster. Used for AI-vs-AI simulation.
	var total := 0
	for g in roster:
		for key in GoblinData.STAT_KEYS:
			total += g.get_stat(key)
	return total
