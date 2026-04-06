class_name GoblinDatabase
extends RefCounted
## MVP goblin roster definitions. 10 goblins to draft from, faction-aware opponent generation.

static func make_goblin(p_name: String, p_personality: String, p_passive: String, atk: int, mid: int, def: int, gk: int, p_faction: int = 0) -> GoblinData:
	var g := GoblinData.new()
	g.goblin_name = p_name
	g.personality = p_personality
	g.passive_description = p_passive
	g.faction = p_faction
	g.attack_rating = atk
	g.midfield_rating = mid
	g.defense_rating = def
	g.goal_rating = gk
	return g

static func full_roster() -> Array[GoblinData]:
	## All 10 goblins available in the draft pool (2 per faction).
	var F := FactionSystem.Faction
	return [
		make_goblin(
			"Gorwick the Relentless",
			"Never stops running. Never knows where he's going.",
			"Adds +1 Possession when any Possession card is played.",
			5, 3, 1, 1, F.GILDED_CODEX),
		make_goblin(
			"Definitely Not Offside Dave",
			"Standing exactly where the rules say he shouldn't be.",
			"Tempo cards gain +5% conversion when in Attack zone.",
			4, 2, 1, 0, F.SCREAMING_TIDE),
		make_goblin(
			"Gribbix the Adequate",
			"Does everything at a solid 6 out of 10.",
			"No passive. Just vibes.",
			3, 3, 3, 2, F.GILDED_CODEX),
		make_goblin(
			"Skulkra Ironshins",
			"Got kicked so many times her shins became armor.",
			"Reduces opponent Tempo conversion by 3% when in Defense.",
			1, 3, 5, 2, F.IRONCLAD_BASTIONS),
		make_goblin(
			"Whizzik Fastfoot",
			"Believes speed solves every problem. It does not.",
			"Draws an extra card at round start if in Midfield.",
			3, 5, 1, 0, F.MIDNIGHT_SKULK),
		make_goblin(
			"Nettlebrine the Immovable",
			"Claimed the goal as personal territory. Will fight the ball.",
			"Once per match: negate a converted Tempo goal.",
			0, 1, 2, 6, F.IRONCLAD_BASTIONS),
		make_goblin(
			"Blix the Unhinged",
			"Celebrates before the ball goes in. Sometimes it does.",
			"Scoring a goal shifts Momentum +1 toward you.",
			5, 1, 1, 1, F.THUNDERING_MAW),
		make_goblin(
			"Old Mugwort",
			"Has been playing since before the rules were invented.",
			"Opponent Possession cards give -1 each.",
			1, 4, 3, 2, F.MIDNIGHT_SKULK),
		make_goblin(
			"Pibble Twoboots",
			"Wears two boots on one foot. Claims it's tactical.",
			"After halftime, draw 1 extra card each round.",
			2, 2, 4, 3, F.SCREAMING_TIDE),
		make_goblin(
			"Snaggleclaw the Lucky",
			"Trips into goals. Has never scored on purpose.",
			"Tempo cards under 25% base gain +10% bonus.",
			3, 3, 2, 1, F.THUNDERING_MAW),
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

# Faction-themed opponent templates: name pools and stat profiles per faction.
# Keys are raw ints matching FactionSystem.Faction enum values to avoid cross-class const load-order issues.
const _FACTION_OPPONENTS: Dictionary = {
	1: {  # GILDED_CODEX
		"names": ["Scrollwick", "Inkblot", "Quillsnarl", "Ledgrik", "Pagefold", "Dustspine", "Bindleclaw", "Rulesworth"],
		"personalities": ["Reads the playbook upside down.", "Passes with mathematical precision.", "Counts every blade of grass.", "Knows the offside rule. Technically.", "Runs formations by the book.", "Thinks in triangles.", "Always in position. Boring position.", "Has a plan. Plans never survive kickoff."],
		"stats": [
			[2, 5, 2, 1], [3, 4, 2, 1], [2, 4, 3, 1], [3, 3, 3, 1],
			[2, 5, 1, 2], [3, 4, 2, 1], [1, 3, 3, 3], [0, 2, 2, 5]
		],
	},
	2: {  # MIDNIGHT_SKULK
		"names": ["Shadecreep", "Whisperknife", "Duskfang", "Silentfoot", "Ambushgob", "Gloomsneak", "Nightbiter", "Trickstab"],
		"personalities": ["Appears from nowhere. Disappears just as fast.", "Waits. Waits. Strikes.", "You never see him until it's too late.", "Prefers the shadows. And fouling.", "Counters everything. Initiates nothing.", "Lurks near the halfway line.", "Strikes when you're celebrating.", "Defense is just preemptive attack."],
		"stats": [
			[4, 2, 3, 1], [3, 3, 3, 1], [4, 3, 2, 1], [3, 2, 4, 1],
			[3, 3, 3, 1], [4, 2, 3, 1], [2, 2, 3, 3], [0, 1, 2, 5]
		],
	},
	3: {  # IRONCLAD_BASTIONS
		"names": ["Slab Ironwall", "Boltrivet", "Shieldgrunt", "Fortifax", "Wallbanger", "Bunkerboss", "Stonefoot", "Gatecrasher"],
		"personalities": ["Immovable. Literally cemented to the pitch.", "Blocks shots with his face. Enjoys it.", "Nothing gets past. Nothing.", "Built like a very angry wall.", "Headers are his love language.", "Guards the box like it owes him money.", "Slow but inevitable.", "The goal is his and his alone."],
		"stats": [
			[1, 2, 5, 2], [2, 2, 5, 1], [1, 3, 4, 2], [2, 3, 4, 1],
			[2, 2, 4, 2], [1, 3, 5, 1], [1, 2, 3, 3], [0, 1, 2, 6]
		],
	},
	4: {  # SCREAMING_TIDE
		"names": ["Blitzgob", "Rampager", "Chargefang", "Presswick", "Stompfoot", "Rushclaw", "Swarmling", "Floodgate"],
		"personalities": ["Runs at the defense. All of them. Alone.", "Pressing is not a tactic. It's a lifestyle.", "Never stops. Never thinks. Never stops.", "Overwhelms with enthusiasm.", "Closes down space by filling it with goblin.", "First to the ball. Last to think.", "Where he goes, chaos follows.", "Stands in goal. Screams."],
		"stats": [
			[5, 3, 1, 1], [4, 4, 1, 1], [5, 2, 2, 1], [4, 3, 2, 1],
			[5, 3, 1, 1], [4, 4, 1, 1], [3, 3, 1, 2], [0, 1, 1, 5]
		],
	},
	5: {  # THUNDERING_MAW
		"names": ["Skullcrush", "Bonesnap", "Grindtusk", "Hammerleg", "Brawlgut", "Smashwick", "Ironjaw", "Thickskull"],
		"personalities": ["Believes in direct communication. With fists.", "Kicks the ball. And everything else.", "Subtlety is for the weak.", "Runs through opponents. Literally.", "Tackles with his entire body.", "The pitch shakes when he runs.", "More muscle than strategy.", "Catches the ball. With his face."],
		"stats": [
			[5, 1, 3, 1], [4, 2, 4, 0], [5, 1, 3, 1], [4, 1, 4, 1],
			[5, 2, 3, 0], [4, 1, 4, 1], [3, 1, 4, 2], [0, 0, 3, 5]
		],
	},
}

static func generate_opponent_roster(faction: int) -> Array[GoblinData]:
	## Generate 6 goblins for an opponent of the given faction.
	var templates: Dictionary = _FACTION_OPPONENTS.get(faction, _FACTION_OPPONENTS[1])
	var names: Array = templates["names"].duplicate()
	var personalities: Array = templates["personalities"].duplicate()
	var stats: Array = templates["stats"].duplicate()

	# Shuffle and pick 6
	var indices: Array[int] = []
	for i in range(names.size()):
		indices.append(i)
	indices.shuffle()
	indices.resize(6)

	var roster: Array[GoblinData] = []
	for i in indices:
		roster.append(make_goblin(names[i], personalities[i], "", stats[i][0], stats[i][1], stats[i][2], stats[i][3], faction))
	return roster

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
