class_name FixtureData
extends RefCounted
## A single match fixture in the tournament.

enum Stage { GROUP, ROUND_OF_16, QUARTER_FINAL, SEMI_FINAL, FINAL }

var home_index: int = -1
var away_index: int = -1
var home_goals: int = 0
var away_goals: int = 0
var played: bool = false
var stage: Stage = Stage.GROUP
var group_index: int = -1  # Only relevant for group stage fixtures
var bracket_slot: int = -1  # Position in the knockout bracket array

func involves_team(team_index: int) -> bool:
	return home_index == team_index or away_index == team_index

func get_winner_index() -> int:
	## Returns winning team index, or -1 if draw/unplayed.
	if not played:
		return -1
	if home_goals > away_goals:
		return home_index
	elif away_goals > home_goals:
		return away_index
	return -1

func get_loser_index() -> int:
	if not played:
		return -1
	if home_goals > away_goals:
		return away_index
	elif away_goals > home_goals:
		return home_index
	return -1
