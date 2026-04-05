class_name GoblinDatabase
extends RefCounted
## MVP goblin roster definitions.

static func make_goblin(p_name: String, p_personality: String, p_passive: String, atk: int, mid: int, def: int, gk: int, is_keeper: bool = false) -> GoblinData:
	var g := GoblinData.new()
	g.goblin_name = p_name
	g.personality = p_personality
	g.passive_description = p_passive
	g.attack_rating = atk
	g.midfield_rating = mid
	g.defense_rating = def
	g.goal_rating = gk
	g.keeper = is_keeper
	return g

static func player_roster() -> Array[GoblinData]:
	return [
		make_goblin(
			"Gorwick the Relentless",
			"Never stops running. Never knows where he's going.",
			"Adds +1 Possession when any Tempo card is played.",
			5, 3, 1, 0),
		make_goblin(
			"Definitely Not Offside Dave",
			"Standing exactly where the rules say he shouldn't be.",
			"Chance cards gain +5% conversion when in Attack zone.",
			4, 2, 1, 0),
		make_goblin(
			"Gribbix the Adequate",
			"Does everything at a solid 6 out of 10.",
			"No passive. Just vibes.",
			3, 3, 3, 0),
		make_goblin(
			"Skulkra Ironshins",
			"Got kicked so many times her shins became armor.",
			"Reduces opponent Chance conversion by 3% when in Defense.",
			1, 3, 5, 0),
		make_goblin(
			"Whizzik Fastfoot",
			"Believes speed solves every problem. It does not.",
			"Draws an extra card at round start if in Midfield.",
			3, 5, 1, 0),
		make_goblin(
			"Nettlebrine the Immovable",
			"Claimed the goal as personal territory. Will fight the ball.",
			"Once per match: negate a converted Chance card.",
			0, 0, 1, 6, true),
	]

static func opponent_roster() -> Array[GoblinData]:
	return [
		make_goblin("Krunk", "Big and angry.", "", 4, 2, 2, 0),
		make_goblin("Snikkit", "Small and sneaky.", "", 3, 3, 2, 0),
		make_goblin("Bogrot", "Smells like strategy.", "", 2, 4, 2, 0),
		make_goblin("Thudwick", "Runs into things on purpose.", "", 2, 2, 4, 0),
		make_goblin("Gnarlfang", "Has opinions about formations.", "", 3, 2, 3, 0),
		make_goblin("Blort", "Fell into the goal and stayed.", "", 0, 0, 1, 5, true),
	]

static func build_default_formation(roster: Array[GoblinData]) -> Formation:
	## Assigns roster to a default 2-1-2 formation.
	var formation := Formation.new()
	for goblin in roster:
		if goblin.keeper:
			formation.keeper = goblin
			continue

	# Assign non-keepers by their best zone
	var outfield: Array[GoblinData] = []
	for goblin in roster:
		if not goblin.keeper:
			outfield.append(goblin)

	# Sort by attack rating descending, put top 2 in attack
	var sorted := outfield.duplicate()
	sorted.sort_custom(func(a: GoblinData, b: GoblinData) -> bool: return a.attack_rating > b.attack_rating)

	if sorted.size() >= 1:
		formation.assign_goblin(sorted[0], "attack")
	if sorted.size() >= 2:
		formation.assign_goblin(sorted[1], "attack")

	# Sort remainder by defense rating, put top 2 in defense
	var remaining: Array[GoblinData] = []
	for g in sorted:
		if formation.find_zone(g) == "":
			remaining.append(g)
	remaining.sort_custom(func(a: GoblinData, b: GoblinData) -> bool: return a.defense_rating > b.defense_rating)

	if remaining.size() >= 1:
		formation.assign_goblin(remaining[0], "defense")
	if remaining.size() >= 2:
		formation.assign_goblin(remaining[1], "defense")

	# Rest in midfield
	for g in outfield:
		if formation.find_zone(g) == "":
			formation.assign_goblin(g, "midfield")

	return formation
