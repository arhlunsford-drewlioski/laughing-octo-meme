class_name GoblinDatabase
extends RefCounted
## MVP goblin roster definitions. 10 goblins to draft from, faction-aware opponent generation.
## Now uses 6 hex stats (shooting, speed, defense, strength, health, chaos) + position.

static func make_goblin(p_name: String, p_personality: String, p_position: String,
		p_shooting: int, p_speed: int, p_defense: int, p_strength: int, p_health: int, p_chaos: int,
		p_faction: int = 0) -> GoblinData:
	var g := GoblinData.new()
	g.goblin_name = p_name
	g.personality = p_personality
	g.position = p_position
	g.faction = p_faction
	g.shooting = p_shooting
	g.speed = p_speed
	g.defense = p_defense
	g.strength = p_strength
	g.health = p_health
	g.chaos = p_chaos
	return g

static func full_roster() -> Array[GoblinData]:
	## Fallback 10-goblin roster for non-run matches (2 per faction).
	## Run mode uses GoblinGenerator.generate_draft_pool() instead.
	var F := FactionSystem.Faction
	return [
		#                         name, personality, position, SHO SPD DEF STR HP  CHA, faction
		make_goblin("Gorwick Scholes",
			"Never stops running. Never knows where he's going.",
			"box_to_box", 3, 6, 4, 3, 5, 2, F.GILDED_CODEX),
		make_goblin("Sniv Inzaghi",
			"Standing exactly where the rules say he shouldn't be.",
			"poacher", 7, 4, 1, 5, 3, 5, F.SCREAMING_TIDE),
		make_goblin("Gribbix Xavi",
			"Does everything at a solid 6 out of 10.",
			"midfielder", 4, 4, 4, 4, 5, 3, F.GILDED_CODEX),
		make_goblin("Skulkra Maldini",
			"Got kicked so many times her shins became armor.",
			"anchor", 2, 2, 7, 6, 7, 2, F.IRONCLAD_BASTIONS),
		make_goblin("Whizzik Mbappé",
			"Believes speed solves every problem. It does not.",
			"winger", 4, 8, 2, 2, 3, 5, F.MIDNIGHT_SKULK),
		make_goblin("Blort Yashin",
			"Claimed the goal as personal territory. Will fight the ball.",
			"keeper", 1, 2, 7, 8, 5, 2, F.IRONCLAD_BASTIONS),
		make_goblin("Blix Cantona",
			"Celebrates before the ball goes in. Sometimes it does.",
			"trequartista", 7, 6, 1, 2, 3, 8, F.THUNDERING_MAW),
		make_goblin("Mugwort Pirlo",
			"Has been playing since before the rules were invented.",
			"playmaker", 4, 5, 3, 3, 4, 6, F.MIDNIGHT_SKULK),
		make_goblin("Pibble Puyol",
			"Wears two boots on one foot. Claims it's tactical.",
			"sweeper", 2, 4, 6, 5, 6, 3, F.SCREAMING_TIDE),
		make_goblin("Snaggleclaw Muller",
			"Trips into goals. Has never scored on purpose.",
			"shadow_striker", 6, 4, 2, 4, 5, 7, F.THUNDERING_MAW),
	]

static func opponent_roster() -> Array[GoblinData]:
	return [
		make_goblin("Krunk", "Big and angry.", "striker", 6, 5, 3, 5, 4, 3),
		make_goblin("Snikkit", "Small and sneaky.", "winger", 4, 7, 2, 2, 3, 5),
		make_goblin("Bogrot", "Smells like strategy.", "midfielder", 3, 4, 4, 4, 5, 3),
		make_goblin("Thudwick", "Runs into things on purpose.", "enforcer", 2, 3, 6, 6, 5, 4),
		make_goblin("Gnarlfang", "Has opinions about formations.", "midfielder", 4, 4, 5, 3, 4, 3),
		make_goblin("Blort", "Fell into the goal and stayed.", "keeper", 1, 2, 6, 7, 5, 2),
	]

# Faction-themed opponent templates: name pools and stat profiles per faction.
# Keys are raw ints matching FactionSystem.Faction enum values.
# Stats: [position, shooting, speed, defense, strength, health, chaos]
const _FACTION_OPPONENTS: Dictionary = {
	1: {  # GILDED_CODEX — tactical, midfield-heavy
		"names": ["Scrollwick", "Inkblot", "Quillsnarl", "Ledgrik", "Pagefold", "Dustspine", "Bindleclaw", "Rulesworth"],
		"personalities": ["Reads the playbook upside down.", "Passes with mathematical precision.", "Counts every blade of grass.", "Knows the offside rule. Technically.", "Runs formations by the book.", "Thinks in triangles.", "Always in position. Boring position.", "Has a plan. Plans never survive kickoff."],
		"templates": [
			["attacking_mid", 5, 5, 4, 3, 4, 3],
			["playmaker", 4, 5, 3, 3, 4, 5],
			["midfielder", 3, 4, 5, 4, 5, 3],
			["box_to_box", 3, 5, 4, 3, 5, 3],
			["sweeper", 2, 4, 6, 4, 5, 2],
			["striker", 6, 5, 2, 3, 4, 3],
			["anchor", 2, 3, 6, 5, 5, 2],
			["keeper", 1, 2, 6, 7, 5, 2],
		],
	},
	2: {  # MIDNIGHT_SKULK — counter-attack, high chaos
		"names": ["Shadecreep", "Whisperknife", "Duskfang", "Silentfoot", "Ambushgob", "Gloomsneak", "Nightbiter", "Trickstab"],
		"personalities": ["Appears from nowhere. Disappears just as fast.", "Waits. Waits. Strikes.", "You never see him until it's too late.", "Prefers the shadows. And fouling.", "Counters everything. Initiates nothing.", "Lurks near the halfway line.", "Strikes when you're celebrating.", "Defense is just preemptive attack."],
		"templates": [
			["shadow_striker", 6, 5, 2, 3, 4, 6],
			["winger", 4, 7, 2, 2, 3, 5],
			["enforcer", 2, 3, 6, 5, 4, 5],
			["midfielder", 3, 5, 5, 3, 4, 4],
			["false_nine", 5, 4, 2, 5, 3, 6],
			["sweeper", 2, 5, 6, 4, 4, 3],
			["wing_back", 3, 6, 5, 3, 4, 3],
			["keeper", 1, 2, 5, 7, 5, 3],
		],
	},
	3: {  # IRONCLAD_BASTIONS — defensive wall
		"names": ["Slab Ironwall", "Boltrivet", "Shieldgrunt", "Fortifax", "Wallbanger", "Bunkerboss", "Stonefoot", "Gatecrasher"],
		"personalities": ["Immovable. Literally cemented to the pitch.", "Blocks shots with his face. Enjoys it.", "Nothing gets past. Nothing.", "Built like a very angry wall.", "Headers are his love language.", "Guards the box like it owes him money.", "Slow but inevitable.", "The goal is his and his alone."],
		"templates": [
			["anchor", 2, 2, 7, 7, 6, 2],
			["enforcer", 2, 3, 6, 6, 5, 4],
			["sweeper", 2, 4, 7, 5, 6, 2],
			["target_man", 5, 2, 3, 7, 6, 3],
			["midfielder", 3, 3, 5, 5, 6, 2],
			["wing_back", 2, 5, 6, 4, 5, 2],
			["box_to_box", 2, 4, 5, 4, 7, 2],
			["keeper", 1, 2, 7, 8, 6, 1],
		],
	},
	4: {  # SCREAMING_TIDE — aggressive pressing
		"names": ["Blitzgob", "Rampager", "Chargefang", "Presswick", "Stompfoot", "Rushclaw", "Swarmling", "Floodgate"],
		"personalities": ["Runs at the defense. All of them. Alone.", "Pressing is not a tactic. It's a lifestyle.", "Never stops. Never thinks. Never stops.", "Overwhelms with enthusiasm.", "Closes down space by filling it with goblin.", "First to the ball. Last to think.", "Where he goes, chaos follows.", "Stands in goal. Screams."],
		"templates": [
			["striker", 7, 6, 2, 4, 3, 4],
			["winger", 5, 7, 2, 3, 3, 5],
			["trequartista", 6, 6, 1, 2, 3, 7],
			["poacher", 6, 4, 1, 6, 4, 5],
			["box_to_box", 3, 6, 4, 4, 5, 3],
			["midfielder", 4, 5, 3, 4, 4, 4],
			["wing_back", 3, 6, 4, 3, 4, 3],
			["keeper", 1, 3, 4, 6, 5, 3],
		],
	},
	5: {  # THUNDERING_MAW — brute strength
		"names": ["Skullcrush", "Bonesnap", "Grindtusk", "Hammerleg", "Brawlgut", "Smashwick", "Ironjaw", "Thickskull"],
		"personalities": ["Believes in direct communication. With fists.", "Kicks the ball. And everything else.", "Subtlety is for the weak.", "Runs through opponents. Literally.", "Tackles with his entire body.", "The pitch shakes when he runs.", "More muscle than strategy.", "Catches the ball. With his face."],
		"templates": [
			["target_man", 6, 3, 3, 8, 5, 3],
			["enforcer", 3, 3, 5, 7, 5, 5],
			["striker", 6, 4, 2, 6, 4, 4],
			["poacher", 5, 3, 2, 7, 5, 5],
			["anchor", 2, 2, 6, 7, 7, 2],
			["midfielder", 3, 4, 4, 6, 5, 3],
			["false_nine", 5, 3, 2, 7, 4, 5],
			["keeper", 1, 2, 5, 8, 6, 2],
		],
	},
}

static func generate_opponent_roster(faction: int) -> Array[GoblinData]:
	## Generate 6 goblins for an opponent of the given faction.
	var templates: Dictionary = _FACTION_OPPONENTS.get(faction, _FACTION_OPPONENTS[1])
	var names: Array = templates["names"].duplicate()
	var personalities: Array = templates["personalities"].duplicate()
	var stat_templates: Array = templates["templates"].duplicate()

	# Shuffle and pick 6
	var indices: Array[int] = []
	for i in range(names.size()):
		indices.append(i)
	indices.shuffle()
	indices.resize(6)

	var roster: Array[GoblinData] = []
	for i in indices:
		var t: Array = stat_templates[i]
		roster.append(make_goblin(names[i], personalities[i], t[0],
			t[1], t[2], t[3], t[4], t[5], t[6], faction))
	return roster

# ── Recruitment Pool ──────────────────────────────────────────────────────────

const _RECRUIT_FIRST_NAMES: Array = [
	"Grot", "Sniv", "Murg", "Blat", "Nix", "Wort", "Drib", "Fug",
	"Skab", "Gunk", "Plop", "Crud", "Squit", "Rak", "Zib", "Drek",
]

const _RECRUIT_LAST_NAMES: Array = [
	"Lingard", "Mustafi", "Bendtner", "Heskey", "Bebe",
	"Altidore", "Balotelli", "Quaresma", "Taarabt", "Adebayor",
	"Chamakh", "Djemba-Djemba", "Kerlon", "Pennant", "Obertan",
]

const _RECRUIT_PERSONALITIES: Array = [
	"Showed up uninvited. Stayed.",
	"Technically knows what a ball is.",
	"Was watching from the stands. Got drafted.",
	"Claims to have played before. Evidence suggests otherwise.",
	"Enthusiastic. That's about it.",
	"Found wandering near the pitch.",
	"His mother says he's very talented.",
	"Free agent for a reason.",
	"Will play for food.",
	"Previous team 'mysteriously disbanded.'",
]

const _RECRUIT_POSITIONS: Array = [
	"striker", "winger", "midfielder", "keeper", "enforcer", "sweeper",
	"box_to_box", "target_man", "poacher", "shadow_striker",
]

static func generate_recruit() -> GoblinData:
	## Generate a random recruit goblin. Stats are 2-5 range (weaker than starters).
	var first: String = _RECRUIT_FIRST_NAMES[randi() % _RECRUIT_FIRST_NAMES.size()]
	var last: String = _RECRUIT_LAST_NAMES[randi() % _RECRUIT_LAST_NAMES.size()]
	var gob_name := first + " " + last
	var personality: String = _RECRUIT_PERSONALITIES[randi() % _RECRUIT_PERSONALITIES.size()]
	var pos: String = _RECRUIT_POSITIONS[randi() % _RECRUIT_POSITIONS.size()]
	var faction: int = (randi() % 5) + 1  # Random faction 1-5

	# Base stats 2-4, with +1-2 bonus to primary stats
	var primary := PositionDatabase.get_primary_stats(pos)
	var stats := {}
	for stat_name in GoblinData.STAT_KEYS:
		stats[stat_name] = randi_range(2, 4)
		if stat_name in primary:
			stats[stat_name] += randi_range(1, 2)
		stats[stat_name] = mini(stats[stat_name], 7)

	return make_goblin(gob_name, personality, pos,
		stats["shooting"], stats["speed"], stats["defense"],
		stats["strength"], stats["health"], stats["chaos"], faction)

static func generate_recruits(count: int) -> Array[GoblinData]:
	var recruits: Array[GoblinData] = []
	var used_names: Array[String] = []
	for i in count:
		var g := generate_recruit()
		# Avoid duplicate names
		while g.goblin_name in used_names:
			g = generate_recruit()
		used_names.append(g.goblin_name)
		recruits.append(g)
	return recruits

static func build_default_formation(roster: Array[GoblinData]) -> Formation:
	## Assigns 6 goblins to formation based on their position's natural zone.
	## Falls back to best-fit if zones overflow.
	var formation := Formation.new()

	# First pass: assign each goblin to their natural zone
	# Sort so keeper goes first (guaranteed 1 goal slot)
	var sorted := roster.duplicate()
	sorted.sort_custom(func(a: GoblinData, b: GoblinData) -> bool:
		if a.position == "keeper" and b.position != "keeper":
			return true
		if b.position == "keeper" and a.position != "keeper":
			return false
		return false
	)

	var unassigned: Array[GoblinData] = []
	for g in sorted:
		if not formation.assign_goblin(g):
			unassigned.append(g)

	# Second pass: put overflow goblins in zones with space
	for g in unassigned:
		for zone in ["midfield", "defense", "attack"]:
			if formation.assign_goblin_to_zone(g, zone):
				break

	# If no keeper was selected, force the best strength+defense goblin into goal
	if formation.goal.is_empty():
		var best_keeper: GoblinData = null
		var best_score: int = -1
		for g in formation.get_all_outfield():
			var keeper_score: int = g.get_stat("strength") + g.get_stat("defense")
			if keeper_score > best_score:
				best_score = keeper_score
				best_keeper = g
		if best_keeper:
			formation.remove_goblin(best_keeper)
			formation.assign_goblin_to_zone(best_keeper, "goal")

	# If any outfield zone is empty, redistribute from overstacked zones
	for zone in ["attack", "midfield", "defense"]:
		if formation.get_zone(zone).is_empty():
			# Steal from the largest zone
			var largest_zone := ""
			var largest_size := 0
			for z in ["attack", "midfield", "defense"]:
				if z != zone and formation.get_zone(z).size() > largest_size:
					largest_size = formation.get_zone(z).size()
					largest_zone = z
			if largest_zone != "" and largest_size > 1:
				var donor_arr := formation.get_zone(largest_zone)
				var stolen: GoblinData = donor_arr[donor_arr.size() - 1]
				formation.remove_goblin(stolen)
				formation.assign_goblin_to_zone(stolen, zone)

	return formation
