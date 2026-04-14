class_name GoblinGenerator
extends RefCounted
## Procedural goblin generation for starting rosters and opponents.
## Every run feels different.

# ── Name Parts ───────────────────────────────────────────────────────────────

const FIRST_NAMES: Array[String] = [
	"Grix", "Bork", "Snag", "Wug", "Flib", "Nak", "Tork", "Pib",
	"Grum", "Skiz", "Molk", "Drit", "Blug", "Sniv", "Krag", "Wort",
	"Vex", "Zub", "Gob", "Nix", "Plonk", "Murg", "Crud", "Brix",
	"Splat", "Thunk", "Glim", "Rak", "Squit", "Drek", "Fug", "Zib",
	"Grot", "Lurk", "Scab", "Blat", "Nub", "Krik", "Slop", "Murk",
	"Grub", "Twitch", "Bonk", "Stink", "Gnash", "Crunk", "Fizz", "Runt",
	"Thordak", "Skullcrusher", "Gnarlfang", "Rotgut", "Blight", "Sludge",
	"Grimjaw", "Bogrot", "Snikkit", "Thudwick", "Wartface", "Blort",
]

# Famous footballer last names (no Messi/Ronaldo - we like our kneecaps)
const LAST_NAMES: Array[String] = [
	"Materazzi", "Smith-Rowe", "Zidane", "Pele", "Maradona", "Cruyff",
	"Beckham", "Bergkamp", "Scholes", "Pirlo", "Buffon", "Kaka",
	"Rivaldo", "Drogba", "Eto'o", "Rooney", "Gerrard", "Lampard",
	"Neymar", "Modric", "Xavi", "Iniesta", "Busquets", "Ramos",
	"Puyol", "Maldini", "Baresi", "Gullit", "Van Basten", "Platini",
	"Cantona", "Henry", "Vieira", "Trezeguet", "Haaland", "Mbappé",
	"Salah", "De Bruyne", "Lewandowski", "Suarez", "Cavani", "Ibrahimovic",
	"Robben", "Ribery", "Schweinsteiger", "Muller", "Klose", "Lahm",
	"Saka", "Foden", "Bellingham", "Gavi", "Pedri", "Valverde",
	"Casillas", "Neuer", "Oblak", "Courtois", "Yashin", "Cech",
]

const PERSONALITIES: Array[String] = [
	"Runs with the grace of a falling boulder.",
	"Claims to have scored 47 goals last season. Nobody was counting.",
	"Thinks the offside rule is a myth.",
	"Once headbutted a goalpost. Won.",
	"Celebrates before the ball goes in. Sometimes it does.",
	"Has a plan for every situation. None of them work.",
	"Doesn't know which goal is theirs. Doesn't care.",
	"Tackles with enthusiasm and zero technique.",
	"Was found sleeping on the pitch. Got drafted.",
	"Kicks everything. The ball, opponents, teammates, air.",
	"Believes speed is a personality trait.",
	"Slow but absolutely certain about where to stand.",
	"Has never passed the ball voluntarily.",
	"Screams when running. Nobody knows why.",
	"Plays like they owe someone money.",
	"Fell into the goal once. Stayed there.",
	"Communicates exclusively through aggressive pointing.",
	"Has opinions about formations. All of them wrong.",
	"Trips into brilliant positions. Trips out of them too.",
	"Genuinely thinks the pitch is haunted.",
	"Previous team disbanded under mysterious circumstances.",
	"Will play for food. Quality of play matches the food.",
	"Once intercepted a pass meant for a teammate.",
	"Runs directly at problems. Solves zero of them.",
	"More muscle than strategy. More enthusiasm than muscle.",
	"Positioned exactly where the rules say they shouldn't be.",
	"Technically knows what a ball is. Technically.",
	"The coach's nephew. Plays like it.",
	"Survived three tournaments. Learned nothing.",
	"Treats every match like a personal grudge.",
]

# ── Position pools per zone (for balanced team generation) ───────────────

const ATTACK_POSITIONS: Array[String] = [
	"striker", "winger", "trequartista", "poacher", "shadow_striker", "false_nine",
]

const MIDFIELD_POSITIONS: Array[String] = [
	"midfielder", "playmaker", "box_to_box", "attacking_mid",
]

const DEFENSE_POSITIONS: Array[String] = [
	"sweeper", "enforcer", "anchor", "wing_back",
]

# ── Generation ───────────────────────────────────────────────────────────────

static var _used_names: Array[String] = []

static func reset_names() -> void:
	_used_names.clear()

static func generate_goblin(faction: int = 0, stat_min: int = 3, stat_max: int = 7, position_hint: String = "") -> GoblinData:
	## Generate a random goblin with stats in the given range.
	## Position is random if not specified. Primary stats get a bonus.
	var g := GoblinData.new()

	# Name (avoid duplicates within a generation batch)
	var name_str := _random_name()
	var attempts := 0
	while name_str in _used_names and attempts < 20:
		name_str = _random_name()
		attempts += 1
	_used_names.append(name_str)
	g.goblin_name = name_str

	# Personality
	g.personality = PERSONALITIES[randi() % PERSONALITIES.size()]

	# Faction
	if faction <= 0:
		faction = randi_range(1, 5)
	g.faction = faction

	# Position
	if position_hint != "":
		g.position = position_hint
	else:
		# Random from all positions
		var all_pos := ATTACK_POSITIONS + MIDFIELD_POSITIONS + DEFENSE_POSITIONS
		g.position = all_pos[randi() % all_pos.size()]

	# Stats: base random in range, with bonus to primary stats
	var primary := PositionDatabase.get_primary_stats(g.position)
	for stat_name in GoblinData.STAT_KEYS:
		var base := randi_range(stat_min, stat_max)
		if stat_name in primary:
			base += randi_range(1, 2)
		g.set(stat_name, clampi(base, 1, 10))

	return g

static func _random_name() -> String:
	var first: String = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last: String = LAST_NAMES[randi() % LAST_NAMES.size()]
	return first + " " + last

# ── Draft Pool Generation ────────────────────────────────────────────────────

static func generate_draft_pool(count: int = 10) -> Array[GoblinData]:
	## Generate a randomized draft pool for the start of a run.
	## Ensures positional balance: at least 2 attackers, 2 midfielders, 2 defenders, 1 keeper.
	reset_names()
	var pool: Array[GoblinData] = []
	var factions := FactionSystem.get_all_factions()

	# Guaranteed positional balance (7 slots)
	# 2 attackers
	for i in 2:
		var pos: String = ATTACK_POSITIONS[randi() % ATTACK_POSITIONS.size()]
		pool.append(generate_goblin(factions[i % factions.size()], 4, 7, pos))
	# 2 midfielders
	for i in 2:
		var pos: String = MIDFIELD_POSITIONS[randi() % MIDFIELD_POSITIONS.size()]
		pool.append(generate_goblin(factions[(i + 2) % factions.size()], 4, 7, pos))
	# 2 defenders
	for i in 2:
		var pos: String = DEFENSE_POSITIONS[randi() % DEFENSE_POSITIONS.size()]
		pool.append(generate_goblin(factions[(i + 4) % factions.size()], 4, 7, pos))
	# 1 keeper
	pool.append(generate_goblin(factions[randi() % factions.size()], 4, 7, "keeper"))

	# Fill remaining slots with random positions
	var remaining := count - pool.size()
	for i in remaining:
		pool.append(generate_goblin(factions[randi() % factions.size()], 3, 7))

	pool.shuffle()
	return pool

# ── Difficulty-Scaled Opponent Generation ────────────────────────────────────

static func generate_scaled_opponent_roster(faction: int, difficulty: float) -> Array[GoblinData]:
	## Generate 6 opponent goblins scaled by difficulty (0.0 = easy, 1.0 = hardest).
	## Group stage ~0.0-0.3, R16 ~0.4, QF ~0.6, SF ~0.8, Final ~1.0.
	reset_names()

	# Scale stat ranges by difficulty
	var stat_min: int = clampi(int(2 + difficulty * 2), 2, 5)    # 2 -> 4
	var stat_max: int = clampi(int(6 + difficulty * 3), 6, 9)    # 6 -> 9
	var primary_bonus_max: int = 2 if difficulty < 0.7 else 3

	# Use faction templates for position distribution (from GoblinDatabase)
	var templates: Dictionary = GoblinDatabase._FACTION_OPPONENTS.get(faction, GoblinDatabase._FACTION_OPPONENTS[1])
	var stat_templates: Array = templates["templates"].duplicate()
	var names_pool: Array = templates["names"].duplicate()
	var pers_pool: Array = templates["personalities"].duplicate()

	# Shuffle and pick 6
	var indices: Array[int] = []
	for i in range(stat_templates.size()):
		indices.append(i)
	indices.shuffle()
	indices.resize(mini(6, indices.size()))

	var roster: Array[GoblinData] = []
	for idx in indices:
		var t: Array = stat_templates[idx]
		var pos: String = t[0]
		var g := GoblinData.new()

		g.goblin_name = names_pool[idx] if idx < names_pool.size() else _random_name()
		g.personality = pers_pool[idx] if idx < pers_pool.size() else PERSONALITIES[randi() % PERSONALITIES.size()]
		g.position = pos
		g.faction = faction

		# Base stats from template, scaled by difficulty
		var primary := PositionDatabase.get_primary_stats(pos)
		for i in range(GoblinData.STAT_KEYS.size()):
			var stat_name: String = GoblinData.STAT_KEYS[i]
			var template_val: int = t[i + 1]  # template: [pos, sho, spd, def, str, hp, cha]
			# Blend template with difficulty scaling
			var scaled: int = template_val + int(difficulty * 2.0)
			# Add variance
			scaled += randi_range(-1, 1)
			# Extra for primary stats at high difficulty
			if stat_name in primary and difficulty >= 0.5:
				scaled += randi_range(0, primary_bonus_max - 1)
			g.set(stat_name, clampi(scaled, stat_min, stat_max))

		roster.append(g)

	return roster
