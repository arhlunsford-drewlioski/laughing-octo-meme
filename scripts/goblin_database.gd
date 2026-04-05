class_name GoblinDatabase
extends RefCounted
## MVP goblin roster definitions. 10 goblins to draft from, 6 opponents.

static func make_goblin(p_name: String, p_personality: String, p_passive: String, atk: int, mid: int, def: int, gk: int) -> GoblinData:
	var g := GoblinData.new()
	g.goblin_name = p_name
	g.personality = p_personality
	g.passive_description = p_passive
	g.attack_rating = atk
	g.midfield_rating = mid
	g.defense_rating = def
	g.goal_rating = gk
	return g

static func full_roster() -> Array[GoblinData]:
	## All 10 goblins available in the draft pool.
	return [
		make_goblin(
			"Gorwick the Relentless",
			"Never stops running. Never knows where he's going.",
			"Adds +1 Possession when any Tempo card is played.",
			5, 3, 1, 1),
		make_goblin(
			"Definitely Not Offside Dave",
			"Standing exactly where the rules say he shouldn't be.",
			"Chance cards gain +5% conversion when in Attack zone.",
			4, 2, 1, 0),
		make_goblin(
			"Gribbix the Adequate",
			"Does everything at a solid 6 out of 10.",
			"No passive. Just vibes.",
			3, 3, 3, 2),
		make_goblin(
			"Skulkra Ironshins",
			"Got kicked so many times her shins became armor.",
			"Reduces opponent Chance conversion by 3% when in Defense.",
			1, 3, 5, 2),
		make_goblin(
			"Whizzik Fastfoot",
			"Believes speed solves every problem. It does not.",
			"Draws an extra card at round start if in Midfield.",
			3, 5, 1, 0),
		make_goblin(
			"Nettlebrine the Immovable",
			"Claimed the goal as personal territory. Will fight the ball.",
			"Once per match: negate a converted Chance card.",
			0, 1, 2, 6),
		make_goblin(
			"Blix the Unhinged",
			"Celebrates before the ball goes in. Sometimes it does.",
			"Scoring a goal shifts Momentum +1 toward you.",
			5, 1, 1, 1),
		make_goblin(
			"Old Mugwort",
			"Has been playing since before the rules were invented.",
			"Opponent Tempo cards give -1 Possession each.",
			1, 4, 3, 2),
		make_goblin(
			"Pibble Twoboots",
			"Wears two boots on one foot. Claims it's tactical.",
			"After halftime, draw 1 extra card each round.",
			2, 2, 4, 3),
		make_goblin(
			"Snaggleclaw the Lucky",
			"Trips into goals. Has never scored on purpose.",
			"Chance cards under 25% base gain +10% bonus.",
			3, 3, 2, 1),
	]

static func opponent_roster() -> Array[GoblinData]:
	return [
		make_goblin("Krunk", "Big and angry.", "", 4, 2, 2, 1),
		make_goblin("Snikkit", "Small and sneaky.", "", 3, 3, 2, 0),
		make_goblin("Bogrot", "Smells like strategy.", "", 2, 4, 2, 1),
		make_goblin("Thudwick", "Runs into things on purpose.", "", 2, 2, 4, 1),
		make_goblin("Gnarlfang", "Has opinions about formations.", "", 3, 2, 3, 0),
		make_goblin("Blort", "Fell into the goal and stayed.", "", 0, 0, 1, 5),
	]

static func build_default_formation(roster: Array[GoblinData]) -> Formation:
	## Assigns 6 goblins to a default 2-1-2-1 formation.
	## Picks the best GK for goal, then assigns by zone strength.
	var formation := Formation.new()

	# Pick keeper: highest GK rating
	var sorted_by_gk := roster.duplicate()
	sorted_by_gk.sort_custom(func(a: GoblinData, b: GoblinData) -> bool: return a.goal_rating > b.goal_rating)
	formation.assign_goblin(sorted_by_gk[0], "goal")

	# Remaining 5 outfield
	var outfield: Array[GoblinData] = []
	for g in roster:
		if formation.find_zone(g) == "":
			outfield.append(g)

	# Top 2 by ATK -> attack
	var sorted_atk := outfield.duplicate()
	sorted_atk.sort_custom(func(a: GoblinData, b: GoblinData) -> bool: return a.attack_rating > b.attack_rating)
	if sorted_atk.size() >= 1:
		formation.assign_goblin(sorted_atk[0], "attack")
	if sorted_atk.size() >= 2:
		formation.assign_goblin(sorted_atk[1], "attack")

	# Remaining: top 2 by DEF -> defense
	var remaining: Array[GoblinData] = []
	for g in outfield:
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
