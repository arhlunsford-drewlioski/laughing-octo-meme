class_name TournamentData
extends RefCounted
## Full 32-team World Cup tournament state.

enum Stage { GROUP, ROUND_OF_16, QUARTER_FINAL, SEMI_FINAL, FINAL, COMPLETE }

var teams: Array[TeamData] = []
var groups: Array[GroupData] = []  # 8 groups of 4
var bracket: Array[FixtureData] = []  # 15 knockout fixtures: 8 R16, 4 QF, 2 SF, 1 Final
var stage: Stage = Stage.GROUP
var player_team_index: int = 0
var group_matchday: int = 0  # 0, 1, 2 (which matchday we're on in group stage)

func get_player_group() -> GroupData:
	for g in groups:
		if player_team_index in g.team_indices:
			return g
	return null

func get_team(index: int) -> TeamData:
	if index >= 0 and index < teams.size():
		return teams[index]
	return null

func get_next_player_fixture() -> FixtureData:
	## Find the next unplayed fixture involving the player.
	if stage == Stage.GROUP:
		var pg := get_player_group()
		if pg:
			for f in pg.fixtures:
				if not f.played and f.involves_team(player_team_index):
					return f
	else:
		for f in bracket:
			if not f.played and f.involves_team(player_team_index):
				return f
	return null

func is_player_eliminated() -> bool:
	if stage == Stage.GROUP:
		return false  # Can't be eliminated during group stage play
	if stage == Stage.COMPLETE:
		# Check if player won the final
		var final_fixture := bracket[14]  # Last bracket slot is the final
		if final_fixture.played:
			return final_fixture.get_winner_index() != player_team_index
		return false
	# In knockout: check if player lost their last bracket match
	for f in bracket:
		if f.played and f.involves_team(player_team_index):
			if f.get_loser_index() == player_team_index:
				return true
	return false

func has_player_won() -> bool:
	if stage != Stage.COMPLETE:
		return false
	var final_fixture := bracket[14]
	return final_fixture.played and final_fixture.get_winner_index() == player_team_index

func is_player_in_group_stage() -> bool:
	return stage == Stage.GROUP

func advance_to_knockouts() -> void:
	## Called after all group matches are done. Fill bracket R16 slots.
	stage = Stage.ROUND_OF_16
	# Standard World Cup bracket:
	# R16 slot 0: 1A vs 2B, slot 1: 1C vs 2D, slot 2: 1E vs 2F, slot 3: 1G vs 2H
	# R16 slot 4: 1B vs 2A, slot 5: 1D vs 2C, slot 6: 1F vs 2E, slot 7: 1H vs 2G
	var pairings := [[0,1], [2,3], [4,5], [6,7], [1,0], [3,2], [5,4], [7,6]]
	for i in range(8):
		var g1 := groups[pairings[i][0]]
		var g2 := groups[pairings[i][1]]
		var q1 := g1.get_qualified_indices()
		var q2 := g2.get_qualified_indices()
		bracket[i].home_index = q1[0]  # 1st place from first group
		bracket[i].away_index = q2[1]  # 2nd place from second group
		bracket[i].stage = FixtureData.Stage.ROUND_OF_16

func advance_bracket_round() -> void:
	## After a knockout round is complete, fill the next round's fixtures.
	if stage == Stage.ROUND_OF_16:
		# QF slots 8-11, fed by R16 winners
		for i in range(4):
			bracket[8 + i].home_index = bracket[i * 2].get_winner_index()
			bracket[8 + i].away_index = bracket[i * 2 + 1].get_winner_index()
			bracket[8 + i].stage = FixtureData.Stage.QUARTER_FINAL
		stage = Stage.QUARTER_FINAL
	elif stage == Stage.QUARTER_FINAL:
		# SF slots 12-13
		for i in range(2):
			bracket[12 + i].home_index = bracket[8 + i * 2].get_winner_index()
			bracket[12 + i].away_index = bracket[8 + i * 2 + 1].get_winner_index()
			bracket[12 + i].stage = FixtureData.Stage.SEMI_FINAL
		stage = Stage.SEMI_FINAL
	elif stage == Stage.SEMI_FINAL:
		# Final slot 14
		bracket[14].home_index = bracket[12].get_winner_index()
		bracket[14].away_index = bracket[13].get_winner_index()
		bracket[14].stage = FixtureData.Stage.FINAL
		stage = Stage.FINAL
	elif stage == Stage.FINAL:
		stage = Stage.COMPLETE

func init_bracket() -> void:
	## Create 15 empty bracket slots.
	bracket.clear()
	for i in range(15):
		var f := FixtureData.new()
		f.bracket_slot = i
		bracket.append(f)

func get_player_opponent_index() -> int:
	var f := get_next_player_fixture()
	if f:
		return f.away_index if f.home_index == player_team_index else f.home_index
	return -1
