class_name MatchEngine
extends RefCounted
## Resolves a single round: Possession comparison, Momentum shift, Chance conversion.

var passives: PassiveSystem

# Faction counter state
var faction_counter_result: int = 0  # +1 player advantage, -1 opponent advantage, 0 neutral

# Round accumulators - reset each round
var player_possession: int = 0
var opponent_possession: int = 0
var player_chances: Array[CardData] = []
var opponent_chances: Array[CardData] = []

func set_faction_matchup(player_faction: int, opponent_faction: int) -> void:
	faction_counter_result = FactionSystem.get_counter_result(player_faction, opponent_faction)

func reset_round() -> void:
	player_possession = 0
	opponent_possession = 0
	player_chances.clear()
	opponent_chances.clear()

# -- Card application --

func apply_tempo(card: CardData, is_player: bool) -> void:
	if is_player:
		player_possession += card.possession_value
	else:
		opponent_possession += card.possession_value

func queue_chance(card: CardData, is_player: bool) -> void:
	if is_player:
		player_chances.append(card)
	else:
		opponent_chances.append(card)

# -- Resolution --

func resolve_possession() -> int:
	## Returns Momentum shift amount. Positive = toward player, negative = toward opponent.
	var diff := player_possession - opponent_possession
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

func resolve_chance(card: CardData, momentum: int, is_player: bool) -> Dictionary:
	## Returns { "converted": bool, "roll": float, "threshold": float, "saved": bool }
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
		passive_bonus = passives.chance_conversion_bonus(is_player, card)
		passive_penalty = passives.chance_conversion_penalty(not is_player)

	# Faction counter penalty: disadvantaged side loses conversion
	var faction_penalty: float = 0.0
	if faction_counter_result > 0 and not is_player:
		faction_penalty = FactionSystem.COUNTER_CHANCE_PENALTY
	elif faction_counter_result < 0 and is_player:
		faction_penalty = FactionSystem.COUNTER_CHANCE_PENALTY

	var threshold: float = clampf(card.base_conversion + momentum_bonus + zone_bonus + passive_bonus - passive_penalty - faction_penalty, 0.05, 0.95)
	var roll: float = randf()
	var converted: bool = roll <= threshold

	# Keeper save check - defender's keeper can negate a goal
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

func resolve_all_chances(momentum: int) -> Array[Dictionary]:
	## Resolves all queued Chance cards for both sides. Returns array of result dicts.
	var results: Array[Dictionary] = []

	for card in player_chances:
		var result := resolve_chance(card, momentum, true)
		result["card"] = card
		result["is_player"] = true
		results.append(result)

	for card in opponent_chances:
		var result := resolve_chance(card, momentum, false)
		result["card"] = card
		result["is_player"] = false
		results.append(result)

	return results
