class_name MatchEngine
extends RefCounted
## Resolves a single round: Possession vs Defense, Momentum shift, Tempo goal attempts.

var passives: PassiveSystem

# Faction counter state
var faction_counter_result: int = 0  # +1 player advantage, -1 opponent advantage, 0 neutral

# Round accumulators - reset each round
var player_possession: int = 0
var opponent_possession: int = 0
var player_defense: int = 0
var opponent_defense: int = 0
var player_tempo_cards: Array[CardData] = []
var opponent_tempo_cards: Array[CardData] = []

func set_faction_matchup(player_faction: int, opponent_faction: int) -> void:
	faction_counter_result = FactionSystem.get_counter_result(player_faction, opponent_faction)

func reset_round() -> void:
	player_possession = 0
	opponent_possession = 0
	player_defense = 0
	opponent_defense = 0
	player_tempo_cards.clear()
	opponent_tempo_cards.clear()

# -- Card application --

func apply_possession(card: CardData, is_player: bool) -> void:
	if is_player:
		player_possession += card.possession_value
	else:
		opponent_possession += card.possession_value

func apply_defense(card: CardData, is_player: bool) -> void:
	if is_player:
		player_defense += card.defense_value
	else:
		opponent_defense += card.defense_value

func queue_tempo(card: CardData, is_player: bool) -> void:
	if is_player:
		player_tempo_cards.append(card)
	else:
		opponent_tempo_cards.append(card)

# -- Resolution --

func get_net_possession(is_player: bool) -> int:
	## Returns this side's possession minus the opponent's defense against them.
	if is_player:
		return maxi(0, player_possession - opponent_defense)
	else:
		return maxi(0, opponent_possession - player_defense)

func resolve_possession() -> int:
	## Returns Momentum shift amount. Positive = toward player, negative = toward opponent.
	var player_net: int = get_net_possession(true)
	var opponent_net: int = get_net_possession(false)
	var diff: int = player_net - opponent_net
	var shift: int = 0
	if diff > 4:
		shift = 2
	elif diff > 0:
		shift = 1
	elif diff < -4:
		shift = -2
	elif diff < 0:
		shift = -1
	# Faction counter: advantage side gets +1 momentum per round
	shift += faction_counter_result
	return shift

func resolve_tempo_goal(card: CardData, momentum: int, is_player: bool) -> Dictionary:
	## Returns { "converted": bool, "roll": float, "threshold": float, "saved": bool }
	var player_net: int = get_net_possession(true)
	var opponent_net: int = get_net_possession(false)
	var poss_diff: int = player_net - opponent_net
	if not is_player:
		poss_diff = -poss_diff

	# Possession advantage bonus: ±3% per point of net possession difference, capped at ±15%
	var poss_bonus: float = clampf(poss_diff * 0.03, -0.15, 0.15)

	# Momentum bonus
	var momentum_bonus: float
	if is_player:
		momentum_bonus = momentum * 0.03
	else:
		momentum_bonus = -momentum * 0.03

	# Zone modifier: attacker's attack zone vs defender's defense zone
	var atk_zones: Dictionary = GameManager.get_player_zones() if is_player else GameManager.get_opponent_zones()
	var def_zones: Dictionary = GameManager.get_opponent_zones() if is_player else GameManager.get_player_zones()
	var zone_bonus: float = (atk_zones["attack"] - def_zones["defense"]) * 0.02

	# Goblin passive modifiers
	var passive_bonus: float = 0.0
	var passive_penalty: float = 0.0
	if passives:
		passive_bonus = passives.tempo_goal_bonus(is_player, card)
		passive_penalty = passives.tempo_goal_penalty(not is_player)

	# Faction counter penalty: disadvantaged side loses conversion
	var faction_penalty: float = 0.0
	if faction_counter_result > 0 and not is_player:
		faction_penalty = FactionSystem.COUNTER_CHANCE_PENALTY
	elif faction_counter_result < 0 and is_player:
		faction_penalty = FactionSystem.COUNTER_CHANCE_PENALTY

	var threshold: float = clampf(card.base_conversion + poss_bonus + momentum_bonus + zone_bonus + passive_bonus - passive_penalty - faction_penalty, 0.05, 0.95)
	var roll: float = randf()
	var converted: bool = roll <= threshold

	# Keeper save check
	var saved: bool = false
	if converted and passives:
		saved = passives.try_keeper_save(not is_player)
		if saved:
			converted = false

	return {
		"converted": converted,
		"roll": roll,
		"threshold": threshold,
		"saved": saved,
	}

func resolve_all_tempo_goals(momentum: int) -> Array[Dictionary]:
	## Resolves all queued Tempo cards for both sides. Returns array of result dicts.
	var results: Array[Dictionary] = []

	for card in player_tempo_cards:
		var result := resolve_tempo_goal(card, momentum, true)
		result["card"] = card
		result["is_player"] = true
		results.append(result)

	for card in opponent_tempo_cards:
		var result := resolve_tempo_goal(card, momentum, false)
		result["card"] = card
		result["is_player"] = false
		results.append(result)

	return results
