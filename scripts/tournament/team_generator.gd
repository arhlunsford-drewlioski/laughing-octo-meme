class_name TeamGenerator
extends RefCounted
## Generates 31 AI teams for a 32-team World Cup tournament.

# Two-part goblin club names
const PREFIXES: Array[String] = [
	"Rust", "Sludge", "Feral", "Bog", "Ashwick", "Ironpike",
	"Grimstone", "Mudwater", "Rotwood", "Blackmarsh", "Thornfield",
	"Dusthollow", "Cragtop", "Mirefall", "Dankshire", "Goreburg",
	"Swampgate", "Blisterpeak", "Scabrock", "Rattlebone", "Gloomfen",
	"Brackenvale", "Shankford", "Gutterwick", "Stillmuck", "Knobhill",
	"Pestleton", "Blightmoor", "Skullditch", "Wartburg", "Sporedale",
	"Mugshire", "Crankton", "Fungalwood", "Grimsocket", "Shambletown",
]

const SUFFIXES: Array[String] = [
	"Crushers", "Kickers", "Stompers", "United", "Wanderers",
	"Town", "Athletic", "Rovers", "FC", "Rangers",
	"City", "Brawlers", "Hooligans", "XI", "Terrors",
	"Marauders", "Bruisers", "Scrapers", "Ramblers", "Wreckers",
	"Crunchers", "Mashers", "Thumpers", "Chargers", "Pounders",
	"Smashers", "Grinders", "Battlers", "Warriors", "Destroyers",
	"Scrappers", "Tacklers", "Nutmegs", "Strikers", "Booters",
]

static func generate_teams(count: int) -> Array[TeamData]:
	## Generate count AI teams with unique names, factions, and rosters.
	var prefixes := PREFIXES.duplicate()
	var suffixes := SUFFIXES.duplicate()
	prefixes.shuffle()
	suffixes.shuffle()

	var factions := FactionSystem.get_all_factions()
	var teams: Array[TeamData] = []

	for i in range(count):
		var team := TeamData.new()
		team.team_name = prefixes[i % prefixes.size()] + " " + suffixes[i % suffixes.size()]
		team.faction = factions[i % factions.size()]
		team.roster = GoblinDatabase.generate_opponent_roster(team.faction)
		team.formation = GoblinDatabase.build_default_formation(team.roster)
		team.is_player = false
		teams.append(team)

	return teams

static func generate_tournament(player_roster: Array[GoblinData], player_faction: int) -> TournamentData:
	## Create a full 32-team tournament with the player as team 0.
	var tournament := TournamentData.new()

	# Create player team
	var player_team := TeamData.new()
	player_team.team_name = "Your Goblins"
	player_team.roster = player_roster
	player_team.formation = GoblinDatabase.build_default_formation(player_roster)
	player_team.faction = player_faction
	player_team.is_player = true
	player_team.team_index = 0
	tournament.teams.append(player_team)
	tournament.player_team_index = 0

	# Generate 31 AI teams
	var ai_teams := generate_teams(31)
	for i in range(ai_teams.size()):
		ai_teams[i].team_index = i + 1
		tournament.teams.append(ai_teams[i])

	# Create 8 groups of 4
	# Player always in Group A (index 0)
	var team_indices: Array[int] = []
	for i in range(1, 32):
		team_indices.append(i)
	team_indices.shuffle()

	var letters := ["A", "B", "C", "D", "E", "F", "G", "H"]
	for g_idx in range(8):
		var group := GroupData.new()
		group.group_letter = letters[g_idx]
		group.group_index = g_idx

		if g_idx == 0:
			# Player's group
			group.team_indices.append(0)  # Player
			for j in range(3):
				group.team_indices.append(team_indices.pop_front())
		else:
			for j in range(4):
				group.team_indices.append(team_indices.pop_front())

		group.init_standings()
		group.generate_round_robin_fixtures()
		tournament.groups.append(group)

	tournament.init_bracket()
	tournament.stage = TournamentData.Stage.GROUP
	tournament.group_matchday = 0

	return tournament

static func simulate_match(home: TeamData, away: TeamData) -> Dictionary:
	## Instant AI-vs-AI match simulation. Returns { home_goals, away_goals }.
	var home_str := home.get_strength()
	var away_str := away.get_strength()
	var total := float(home_str + away_str)
	if total == 0:
		total = 1.0
	var home_ratio := home_str / total

	var home_goals := _weighted_goals(home_ratio)
	var away_goals := _weighted_goals(1.0 - home_ratio)
	return { "home_goals": home_goals, "away_goals": away_goals }

static func _weighted_goals(strength_ratio: float) -> int:
	## Generate a plausible goal count weighted by team strength.
	## Average ~1.3 goals, ranging 0-4.
	var roll := randf()
	# Shift thresholds based on strength
	var base := strength_ratio * 0.6 + 0.2  # Range 0.2-0.8
	if roll < 0.30 - base * 0.15:
		return 0
	elif roll < 0.65 - base * 0.10:
		return 1
	elif roll < 0.85:
		return 2
	elif roll < 0.95:
		return 3
	else:
		return 4
