class_name TeamData
extends RefCounted
## A single team in the tournament.

var team_name: String = ""
var roster: Array[GoblinData] = []
var formation: Formation = null
var faction: int = 0  # FactionSystem.Faction enum
var is_player: bool = false
var team_index: int = -1

func get_strength() -> int:
	## Sum of all zone ratings. Used for AI-vs-AI simulation.
	if formation:
		var zones := formation.get_zone_ratings()
		return zones["attack"] + zones["midfield"] + zones["defense"] + zones["goal"]
	var total := 0
	for g in roster:
		total += g.attack_rating + g.midfield_rating + g.defense_rating + g.goal_rating
	return total
