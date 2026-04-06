class_name CardPool
extends RefCounted
## Returns the shop card pool based on the current tournament stage.

static func get_pool_for_stage() -> Array[CardData]:
	## T1 for group stage, T1+T2 for R16/QF, T1+T2+T3 for SF/Final.
	var pool: Array[CardData] = CardDatabase.reward_card_pool()

	if not RunManager.tournament:
		return pool

	match RunManager.tournament.stage:
		TournamentData.Stage.ROUND_OF_16, TournamentData.Stage.QUARTER_FINAL:
			pool.append_array(CardDatabase.tier2_card_pool())
		TournamentData.Stage.SEMI_FINAL, TournamentData.Stage.FINAL:
			pool.append_array(CardDatabase.tier2_card_pool())
			pool.append_array(CardDatabase.tier3_card_pool())

	return pool

static func get_tier_label() -> String:
	if not RunManager.tournament:
		return "Tier 1"
	match RunManager.tournament.stage:
		TournamentData.Stage.ROUND_OF_16, TournamentData.Stage.QUARTER_FINAL:
			return "Tier 2 Unlocked!"
		TournamentData.Stage.SEMI_FINAL, TournamentData.Stage.FINAL:
			return "Tier 3 Unlocked!"
	return "Tier 1"
