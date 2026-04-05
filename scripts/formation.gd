class_name Formation
extends RefCounted
## Manages goblin zone assignments for one side. 6 total: up to 3 per outfield zone, 1 in goal.

const MAX_OUTFIELD_PER_ZONE: int = 3
const MAX_GOAL: int = 1
const TEAM_SIZE: int = 6
const ZONES := ["attack", "midfield", "defense", "goal"]

var attack: Array[GoblinData] = []
var midfield: Array[GoblinData] = []
var defense: Array[GoblinData] = []
var goal: Array[GoblinData] = []

func get_zone(zone: String) -> Array[GoblinData]:
	match zone:
		"attack": return attack
		"midfield": return midfield
		"defense": return defense
		"goal": return goal
		_: return []

func max_for_zone(zone: String) -> int:
	if zone == "goal":
		return MAX_GOAL
	return MAX_OUTFIELD_PER_ZONE

func total_count() -> int:
	return attack.size() + midfield.size() + defense.size() + goal.size()

func assign_goblin(goblin: GoblinData, zone: String) -> bool:
	var arr := get_zone(zone)
	if arr.size() >= max_for_zone(zone):
		return false
	if total_count() >= TEAM_SIZE:
		return false
	if find_zone(goblin) != "":
		return false  # Already assigned somewhere
	arr.append(goblin)
	return true

func remove_goblin(goblin: GoblinData) -> bool:
	for zone in ZONES:
		var arr := get_zone(zone)
		var idx := arr.find(goblin)
		if idx != -1:
			arr.remove_at(idx)
			return true
	return false

func move_goblin(goblin: GoblinData, new_zone: String) -> bool:
	var current := find_zone(goblin)
	if current == "":
		return false
	if current == new_zone:
		return false
	var target := get_zone(new_zone)
	if target.size() >= max_for_zone(new_zone):
		return false
	remove_goblin(goblin)
	target.append(goblin)
	return true

func find_zone(goblin: GoblinData) -> String:
	for zone in ZONES:
		if get_zone(zone).has(goblin):
			return zone
	return ""

func get_zone_ratings() -> Dictionary:
	var ratings := { "attack": 0, "midfield": 0, "defense": 0, "goal": 0 }
	for goblin in attack:
		ratings["attack"] += goblin.get_rating_for_zone("attack")
	for goblin in midfield:
		ratings["midfield"] += goblin.get_rating_for_zone("midfield")
	for goblin in defense:
		ratings["defense"] += goblin.get_rating_for_zone("defense")
	for goblin in goal:
		ratings["goal"] += goblin.get_rating_for_zone("goal")
	return ratings

func get_keeper() -> GoblinData:
	if goal.is_empty():
		return null
	return goal[0]

func is_valid() -> bool:
	if total_count() != TEAM_SIZE:
		return false
	if goal.size() != 1:
		return false
	for zone in ["attack", "midfield", "defense"]:
		if get_zone(zone).size() > MAX_OUTFIELD_PER_ZONE:
			return false
		if get_zone(zone).is_empty():
			return false
	return true

func get_all_outfield() -> Array[GoblinData]:
	var all: Array[GoblinData] = []
	all.append_array(attack)
	all.append_array(midfield)
	all.append_array(defense)
	return all
