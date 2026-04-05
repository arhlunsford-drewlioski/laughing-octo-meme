class_name Formation
extends RefCounted
## Manages goblin zone assignments for one side. 5 outfield + 1 keeper.

const MAX_PER_ZONE: int = 3
const OUTFIELD_COUNT: int = 5
const ZONES := ["attack", "midfield", "defense"]

var attack: Array[GoblinData] = []
var midfield: Array[GoblinData] = []
var defense: Array[GoblinData] = []
var keeper: GoblinData = null

func get_zone(zone: String) -> Array[GoblinData]:
	match zone:
		"attack": return attack
		"midfield": return midfield
		"defense": return defense
		_: return []

func _set_zone(zone: String, arr: Array[GoblinData]) -> void:
	match zone:
		"attack": attack = arr
		"midfield": midfield = arr
		"defense": defense = arr

func outfield_count() -> int:
	return attack.size() + midfield.size() + defense.size()

func assign_goblin(goblin: GoblinData, zone: String) -> bool:
	if goblin.keeper:
		return false
	var arr := get_zone(zone)
	if arr.size() >= MAX_PER_ZONE:
		return false
	if outfield_count() >= OUTFIELD_COUNT:
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
	if goblin.keeper:
		return false
	var current := find_zone(goblin)
	if current == "":
		return false
	if current == new_zone:
		return false
	var target := get_zone(new_zone)
	if target.size() >= MAX_PER_ZONE:
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
	if keeper:
		ratings["goal"] = keeper.get_rating_for_zone("goal")
	return ratings

func is_valid() -> bool:
	if outfield_count() != OUTFIELD_COUNT:
		return false
	if keeper == null:
		return false
	for zone in ZONES:
		if get_zone(zone).size() > MAX_PER_ZONE:
			return false
	return true

func get_all_outfield() -> Array[GoblinData]:
	var all: Array[GoblinData] = []
	all.append_array(attack)
	all.append_array(midfield)
	all.append_array(defense)
	return all
