class_name MatchEngine
extends RefCounted
## Resolves a single round: Possession comparison, Momentum shift, Chance conversion.

# Round accumulators - reset each round
var player_possession: int = 0
var opponent_possession: int = 0
var player_chances: Array[CardData] = []
var opponent_chances: Array[CardData] = []

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
	if diff > 4:
		return 2
	elif diff > 0:
		return 1
	elif diff < -4:
		return -2
	elif diff < 0:
		return -1
	return 0

func resolve_chance(card: CardData, momentum: int, is_player: bool) -> Dictionary:
	## Returns { "converted": bool, "roll": float, "threshold": float }
	var momentum_bonus: float
	if is_player:
		momentum_bonus = momentum * 0.03
	else:
		momentum_bonus = -momentum * 0.03

	# Zone modifier: attacker's attack zone vs defender's defense zone
	var atk_zones: Dictionary = GameManager.get_player_zones() if is_player else GameManager.get_opponent_zones()
	var def_zones: Dictionary = GameManager.get_opponent_zones() if is_player else GameManager.get_player_zones()
	var zone_bonus: float = (atk_zones["attack"] - def_zones["defense"]) * 0.02

	var threshold: float = clampf(card.base_conversion + momentum_bonus + zone_bonus, 0.05, 0.95)
	var roll: float = randf()

	return {
		"converted": roll <= threshold,
		"roll": roll,
		"threshold": threshold,
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
