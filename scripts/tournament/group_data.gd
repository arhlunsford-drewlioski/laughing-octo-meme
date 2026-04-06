class_name GroupData
extends RefCounted
## A group of 4 teams with standings and fixtures.

var group_letter: String = ""  # "A" through "H"
var group_index: int = -1
var team_indices: Array[int] = []
var standings: Array[StandingEntry] = []
var fixtures: Array[FixtureData] = []  # 6 fixtures per group (round-robin)

func init_standings() -> void:
	standings.clear()
	for ti in team_indices:
		var entry := StandingEntry.new()
		entry.team_index = ti
		standings.append(entry)

func get_standing(team_index: int) -> StandingEntry:
	for s in standings:
		if s.team_index == team_index:
			return s
	return null

func record_result(home_index: int, away_index: int, home_goals: int, away_goals: int) -> void:
	var home_standing := get_standing(home_index)
	var away_standing := get_standing(away_index)
	if home_standing:
		home_standing.record_result(home_goals, away_goals)
	if away_standing:
		away_standing.record_result(away_goals, home_goals)

func get_sorted_standings() -> Array[StandingEntry]:
	## Sort by points, then goal difference, then goals scored.
	var sorted: Array[StandingEntry] = standings.duplicate()
	sorted.sort_custom(func(a: StandingEntry, b: StandingEntry) -> bool:
		if a.points != b.points:
			return a.points > b.points
		if a.goal_difference != b.goal_difference:
			return a.goal_difference > b.goal_difference
		return a.goals_for > b.goals_for
	)
	return sorted

func get_qualified_indices() -> Array[int]:
	## Returns the top 2 team indices.
	var sorted := get_sorted_standings()
	var qualified: Array[int] = []
	for i in range(mini(2, sorted.size())):
		qualified.append(sorted[i].team_index)
	return qualified

func generate_round_robin_fixtures() -> void:
	## Generate 6 fixtures: each of the 4 teams plays the other 3 once.
	## Organized into 3 matchdays (2 fixtures each).
	fixtures.clear()
	var t := team_indices
	# Matchday 1: t[0] vs t[1], t[2] vs t[3]
	# Matchday 2: t[0] vs t[2], t[1] vs t[3]
	# Matchday 3: t[0] vs t[3], t[1] vs t[2]
	var matchups := [[0,1, 2,3], [0,2, 1,3], [0,3, 1,2]]
	for md in matchups:
		var f1 := FixtureData.new()
		f1.home_index = t[md[0]]
		f1.away_index = t[md[1]]
		f1.stage = FixtureData.Stage.GROUP
		f1.group_index = group_index
		fixtures.append(f1)
		var f2 := FixtureData.new()
		f2.home_index = t[md[2]]
		f2.away_index = t[md[3]]
		f2.stage = FixtureData.Stage.GROUP
		f2.group_index = group_index
		fixtures.append(f2)
