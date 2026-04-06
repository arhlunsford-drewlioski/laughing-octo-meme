extends Node
## Tracks tournament run state. Autoloaded as RunManager.

# Gold economy
const GOLD_WIN: int = 5
const GOLD_DRAW: int = 2
const GOLD_LOSS: int = 1
const GOLD_PER_GOAL: int = 1
const GOLD_GOAL_CAP: int = 3

# Run state
var run_active: bool = false
var gold: int = 0

# Tournament
var tournament: TournamentData = null

# Faction state
var player_faction: int = 0

# Persistent deck across matches
var run_deck_cards: Array[CardData] = []

# Match results history
var match_results: Array[Dictionary] = []

signal gold_changed(new_gold: int)

func start_tournament(roster: Array[GoblinData]) -> void:
	run_active = true
	gold = 0
	match_results.clear()

	player_faction = FactionSystem.get_majority_faction(roster)
	run_deck_cards = CardDatabase.player_starter_deck()

	tournament = TeamGenerator.generate_tournament(roster, player_faction)

func get_current_opponent_roster() -> Array[GoblinData]:
	if not tournament:
		return GoblinDatabase.opponent_roster()
	var opp_idx := tournament.get_player_opponent_index()
	if opp_idx < 0:
		return GoblinDatabase.opponent_roster()
	return tournament.get_team(opp_idx).roster

func get_current_opponent_faction() -> int:
	if not tournament:
		return FactionSystem.Faction.NONE
	var opp_idx := tournament.get_player_opponent_index()
	if opp_idx < 0:
		return FactionSystem.Faction.NONE
	return tournament.get_team(opp_idx).faction

func get_current_opponent_name() -> String:
	if not tournament:
		return "Unknown"
	var opp_idx := tournament.get_player_opponent_index()
	if opp_idx < 0:
		return "Unknown"
	return tournament.get_team(opp_idx).team_name

func get_stage_name() -> String:
	if not tournament:
		return ""
	match tournament.stage:
		TournamentData.Stage.GROUP:
			return "Group Stage"
		TournamentData.Stage.ROUND_OF_16:
			return "Round of 16"
		TournamentData.Stage.QUARTER_FINAL:
			return "Quarter Final"
		TournamentData.Stage.SEMI_FINAL:
			return "Semi Final"
		TournamentData.Stage.FINAL:
			return "FINAL"
		_:
			return ""

func record_match_result(p_goals: int, o_goals: int) -> void:
	var fixture := tournament.get_next_player_fixture()
	if not fixture:
		return

	var opp_idx := fixture.away_index if fixture.home_index == tournament.player_team_index else fixture.home_index
	var won := p_goals > o_goals
	var drew := p_goals == o_goals

	# Record in fixture
	if fixture.home_index == tournament.player_team_index:
		fixture.home_goals = p_goals
		fixture.away_goals = o_goals
	else:
		fixture.home_goals = o_goals
		fixture.away_goals = p_goals
	fixture.played = true

	# Update group standings if in group stage
	if tournament.stage == TournamentData.Stage.GROUP:
		var pg := tournament.get_player_group()
		if pg:
			pg.record_result(fixture.home_index, fixture.away_index, fixture.home_goals, fixture.away_goals)

	# Award gold
	var gold_earned := GOLD_LOSS
	if won:
		gold_earned = GOLD_WIN
	elif drew:
		gold_earned = GOLD_DRAW
	gold_earned += mini(p_goals * GOLD_PER_GOAL, GOLD_GOAL_CAP)
	add_gold(gold_earned)

	# Track match history
	match_results.append({
		"opponent_name": tournament.get_team(opp_idx).team_name if tournament.get_team(opp_idx) else "Unknown",
		"opponent_faction": get_current_opponent_faction(),
		"player_goals": p_goals,
		"opponent_goals": o_goals,
		"won": won,
		"stage": get_stage_name(),
		"gold_earned": gold_earned,
	})

func simulate_remaining_group_matches() -> void:
	## After the player plays a group matchday, simulate all other group matches for that matchday.
	if not tournament or tournament.stage != TournamentData.Stage.GROUP:
		return

	var matchday := tournament.group_matchday
	for group in tournament.groups:
		# Each matchday has 2 fixtures per group (indices matchday*2 and matchday*2+1)
		var start_idx := matchday * 2
		for fi in range(start_idx, mini(start_idx + 2, group.fixtures.size())):
			var f: FixtureData = group.fixtures[fi]
			if f.played:
				continue
			# Simulate AI-vs-AI
			var home := tournament.get_team(f.home_index)
			var away := tournament.get_team(f.away_index)
			if home and away:
				var result := TeamGenerator.simulate_match(home, away)
				f.home_goals = result["home_goals"]
				f.away_goals = result["away_goals"]
				f.played = true
				group.record_result(f.home_index, f.away_index, f.home_goals, f.away_goals)

func advance_tournament() -> void:
	## Call after recording a match result and simulating remaining matches.
	if not tournament:
		return

	if tournament.stage == TournamentData.Stage.GROUP:
		tournament.group_matchday += 1
		if tournament.group_matchday >= 3:
			# All group matches done - check if player qualified
			var pg := tournament.get_player_group()
			if pg:
				var qualified := pg.get_qualified_indices()
				if tournament.player_team_index not in qualified:
					# Player eliminated in group stage
					return
			tournament.advance_to_knockouts()
			_simulate_non_player_knockout_matches()
	else:
		# Knockout stage
		tournament.advance_bracket_round()
		if tournament.stage != TournamentData.Stage.COMPLETE:
			_simulate_non_player_knockout_matches()

func _simulate_non_player_knockout_matches() -> void:
	## Simulate all knockout fixtures that don't involve the player in the current round.
	for f in tournament.bracket:
		if f.played or f.home_index < 0 or f.away_index < 0:
			continue
		if f.involves_team(tournament.player_team_index):
			continue
		# Check if this fixture is in the current stage
		var fixture_stage := _fixture_stage_matches_tournament(f)
		if not fixture_stage:
			continue
		var home := tournament.get_team(f.home_index)
		var away := tournament.get_team(f.away_index)
		if home and away:
			var result := TeamGenerator.simulate_match(home, away)
			f.home_goals = result["home_goals"]
			f.away_goals = result["away_goals"]
			# Ensure no draws in knockout - home team gets extra goal on draw
			if f.home_goals == f.away_goals:
				if randf() < 0.5:
					f.home_goals += 1
				else:
					f.away_goals += 1
			f.played = true

func _fixture_stage_matches_tournament(f: FixtureData) -> bool:
	match tournament.stage:
		TournamentData.Stage.ROUND_OF_16:
			return f.bracket_slot >= 0 and f.bracket_slot < 8
		TournamentData.Stage.QUARTER_FINAL:
			return f.bracket_slot >= 8 and f.bracket_slot < 12
		TournamentData.Stage.SEMI_FINAL:
			return f.bracket_slot >= 12 and f.bracket_slot < 14
		TournamentData.Stage.FINAL:
			return f.bracket_slot == 14
	return false

func is_eliminated() -> bool:
	if not tournament:
		return false
	# Group stage: check after all 3 matchdays
	if tournament.stage == TournamentData.Stage.GROUP and tournament.group_matchday >= 3:
		var pg := tournament.get_player_group()
		if pg:
			var qualified := pg.get_qualified_indices()
			return tournament.player_team_index not in qualified
	return tournament.is_player_eliminated()

func has_won_tournament() -> bool:
	if not tournament:
		return false
	return tournament.has_player_won()

func is_run_over() -> bool:
	return is_eliminated() or has_won_tournament()

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func add_reward_card(card: CardData) -> void:
	run_deck_cards.append(card)

func remove_deck_card(index: int) -> void:
	if index >= 0 and index < run_deck_cards.size():
		run_deck_cards.remove_at(index)

func reset_run() -> void:
	run_active = false
	gold = 0
	player_faction = 0
	run_deck_cards.clear()
	match_results.clear()
	tournament = null
