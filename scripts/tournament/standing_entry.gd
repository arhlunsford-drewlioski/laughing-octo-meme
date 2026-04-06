class_name StandingEntry
extends RefCounted
## A single row in a group standings table.

var team_index: int = -1
var played: int = 0
var won: int = 0
var drawn: int = 0
var lost: int = 0
var goals_for: int = 0
var goals_against: int = 0

var points: int:
	get: return won * 3 + drawn

var goal_difference: int:
	get: return goals_for - goals_against

func record_result(gf: int, ga: int) -> void:
	played += 1
	goals_for += gf
	goals_against += ga
	if gf > ga:
		won += 1
	elif gf < ga:
		lost += 1
	else:
		drawn += 1
