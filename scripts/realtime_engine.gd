class_name RealtimeEngine
extends RefCounted
## Event generation and resolution for real-time coach mode.

# Keeper save tracking (once per match)
var player_keeper_save_used: bool = false
var opponent_keeper_save_used: bool = false

# Event description variants
const DESCRIPTIONS := {
	"player_attack": [
		"Your winger has space!",
		"Through ball into the box!",
		"Overlap run on the flank!",
	],
	"opp_attack": [
		"Opponent breaks through!",
		"Dangerous cross coming in!",
		"They're bearing down on goal!",
	],
	"midfield_battle": [
		"Midfield scramble!",
		"Loose ball in the middle!",
		"50/50 challenge!",
	],
	"counter_attack": [
		"Counterattack!",
		"Fast break!",
		"Numbers up on the break!",
	],
	"set_piece": [
		"Corner kick!",
		"Free kick near the box!",
		"Dangerous set piece!",
	],
	"momentum_shift": [
		"The crowd roars!",
		"The tempo is shifting!",
		"Momentum is building!",
	],
}

# Which card types are relevant per zone
const ZONE_CARD_MAP := {
	"attack": [CardData.CardType.ATK_BUFF, CardData.CardType.TACTICAL],
	"midfield": [CardData.CardType.MID_BUFF],
	"defense": [CardData.CardType.DEF_BUFF],
}

const ZONE_HINT_MAP := {
	"attack": "ATK cards help here!",
	"midfield": "MID cards help here!",
	"defense": "DEF cards help here!",
}

func generate_event(player_formation: Formation, opponent_formation: Formation, momentum: int) -> Dictionary:
	## Generate a random match event weighted by momentum and zone ratings.
	var weights := {
		"player_attack": 20 + maxi(0, momentum) * 5,
		"opp_attack": 20 + maxi(0, -momentum) * 5,
		"midfield_battle": 25,
		"counter_attack": 10 + absi(momentum) * 3,
		"set_piece": 15,
		"momentum_shift": 10,
	}

	var event_id: String = _weighted_pick(weights)

	# Determine zone and side
	var relevant_zone: String
	var side: String
	match event_id:
		"player_attack", "counter_attack":
			relevant_zone = "attack"
			side = "player"
		"opp_attack":
			relevant_zone = "defense"
			side = "opponent"
		"midfield_battle", "momentum_shift":
			relevant_zone = "midfield"
			side = "neutral"
		"set_piece":
			if randf() < 0.5:
				relevant_zone = "attack"
				side = "player"
			else:
				relevant_zone = "defense"
				side = "opponent"

	# Calculate base threshold using zone stats
	var player_zones: Dictionary = player_formation.get_zone_ratings()
	var opponent_zones: Dictionary = opponent_formation.get_zone_ratings()
	var possession: float = _calc_base_possession(player_formation, opponent_formation)
	var base_threshold: float

	match event_id:
		"player_attack", "counter_attack":
			base_threshold = _goal_threshold(possession, momentum)
			if event_id == "counter_attack":
				base_threshold += 0.05  # Counter attacks are more dangerous
		"opp_attack":
			base_threshold = _goal_threshold(1.0 - possession, -momentum)
		"set_piece":
			if side == "player":
				base_threshold = _goal_threshold(possession, momentum) + 0.03
			else:
				base_threshold = _goal_threshold(1.0 - possession, -momentum) + 0.03
		_:
			base_threshold = 0.0  # Midfield/momentum events don't use goal threshold

	# Pick the actor goblin from the relevant zone
	var actor: String = ""
	match event_id:
		"player_attack", "counter_attack":
			actor = _pick_scorer(player_formation, "attack")
		"opp_attack":
			actor = _pick_scorer(opponent_formation, "attack")
		"midfield_battle", "momentum_shift":
			actor = _pick_scorer(player_formation, "midfield")
		"set_piece":
			if side == "player":
				actor = _pick_scorer(player_formation, "attack")
			else:
				actor = _pick_scorer(opponent_formation, "attack")

	# Pick a random description, inject goblin name
	var desc_list: Array = DESCRIPTIONS[event_id]
	var description: String = desc_list[randi() % desc_list.size()]
	if actor != "" and actor != "Unknown":
		description = actor + " - " + description

	# Response window: 3-5 seconds
	var response_time: float = randf_range(3.0, 5.0)

	return {
		"event_id": event_id,
		"description": description,
		"relevant_zone": relevant_zone,
		"side": side,
		"response_time": response_time,
		"base_threshold": base_threshold,
		"hint": ZONE_HINT_MAP[relevant_zone],
		"actor": actor,
	}

func resolve_event(event: Dictionary, card: CardData, player_formation: Formation, opponent_formation: Formation, momentum: int) -> Dictionary:
	## Resolve an event. card may be null (timed out).
	var threshold: float = event["base_threshold"]
	var card_bonus: float = 0.0
	var event_id: String = event["event_id"]
	var side: String = event["side"]

	# Calculate card bonus
	if card != null:
		var buff_value: int = _get_card_buff_value(card)
		var relevant: bool = is_card_relevant(card, event["relevant_zone"])
		var multiplier: float = 0.05 if relevant else 0.025
		card_bonus = buff_value * multiplier

	# Resolve based on event type
	match event_id:
		"player_attack", "counter_attack":
			threshold += card_bonus
			return _resolve_shot(threshold, "player", player_formation, opponent_formation)

		"opp_attack":
			threshold -= card_bonus  # Card helps player defend
			return _resolve_shot(threshold, "opponent", opponent_formation, player_formation)

		"set_piece":
			if side == "player":
				threshold += card_bonus
				return _resolve_shot(threshold, "player", player_formation, opponent_formation)
			else:
				threshold -= card_bonus
				return _resolve_shot(threshold, "opponent", opponent_formation, player_formation)

		"midfield_battle", "momentum_shift":
			return _resolve_midfield(card, card_bonus, player_formation, opponent_formation)

	# Fallback
	return {"outcome": "nothing", "description": "Nothing happens.", "momentum_shift": 0, "goblin_name": ""}

func is_card_relevant(card: CardData, relevant_zone: String) -> bool:
	if not ZONE_CARD_MAP.has(relevant_zone):
		return false
	return card.card_type in ZONE_CARD_MAP[relevant_zone]

func _resolve_shot(threshold: float, shooting_side: String, atk_formation: Formation, def_formation: Formation) -> Dictionary:
	threshold = clampf(threshold, 0.05, 0.60)
	var roll: float = randf()
	var goblin_name: String = _pick_scorer(atk_formation, "attack")

	if roll <= threshold:
		# Check keeper save
		var is_player_defending: bool = shooting_side == "opponent"
		if _try_keeper_save(def_formation, is_player_defending):
			return {
				"outcome": "save",
				"description": "SAVED! Keeper denies " + goblin_name + "!",
				"momentum_shift": 0,
				"goblin_name": goblin_name,
			}
		var outcome_key: String = "goal_player" if shooting_side == "player" else "goal_opponent"
		var mom_shift: int = 1 if shooting_side == "player" else -1
		return {
			"outcome": outcome_key,
			"description": "GOAL! " + goblin_name + " scores!",
			"momentum_shift": mom_shift,
			"goblin_name": goblin_name,
		}
	else:
		return {
			"outcome": "miss",
			"description": goblin_name + " fires wide!",
			"momentum_shift": 0,
			"goblin_name": goblin_name,
		}

func _resolve_midfield(card: CardData, card_bonus: float, player_formation: Formation, opponent_formation: Formation) -> Dictionary:
	var shift: int = 0
	if card != null and card_bonus > 0.0:
		shift = 1
	else:
		var player_zones: Dictionary = player_formation.get_zone_ratings()
		var opponent_zones: Dictionary = opponent_formation.get_zone_ratings()
		var mid_diff: int = player_zones["midfield"] - opponent_zones["midfield"]
		shift = signi(mid_diff)

	if shift > 0:
		return {
			"outcome": "momentum_player",
			"description": "You win the battle! Momentum swings your way.",
			"momentum_shift": shift,
			"goblin_name": "",
		}
	elif shift < 0:
		return {
			"outcome": "momentum_opponent",
			"description": "They win the battle! Momentum swings against you.",
			"momentum_shift": shift,
			"goblin_name": "",
		}
	else:
		return {
			"outcome": "nothing",
			"description": "Evenly matched. Nothing changes.",
			"momentum_shift": 0,
			"goblin_name": "",
		}

func _calc_base_possession(player_formation: Formation, opponent_formation: Formation) -> float:
	var player_zones: Dictionary = player_formation.get_zone_ratings()
	var opponent_zones: Dictionary = opponent_formation.get_zone_ratings()
	var mid_diff: int = player_zones["midfield"] - opponent_zones["midfield"]
	return clampf(0.5 + mid_diff * 0.05, 0.2, 0.8)

func _goal_threshold(possession: float, momentum: int) -> float:
	return clampf(0.15 + possession * 0.15 + momentum * 0.03, 0.05, 0.60)

func _try_keeper_save(formation: Formation, is_player: bool) -> bool:
	var keeper := formation.get_keeper()
	if keeper == null:
		return false
	if not keeper.passive_description.begins_with("Once per match"):
		return false
	if is_player and not player_keeper_save_used:
		player_keeper_save_used = true
		return true
	elif not is_player and not opponent_keeper_save_used:
		opponent_keeper_save_used = true
		return true
	return false

func _pick_scorer(formation: Formation, zone: String) -> String:
	var goblins: Array[GoblinData] = formation.get_zone(zone)
	if goblins.is_empty():
		return "Unknown"
	return goblins[randi() % goblins.size()].goblin_name

func _get_card_buff_value(card: CardData) -> int:
	match card.card_type:
		CardData.CardType.ATK_BUFF, CardData.CardType.MID_BUFF, CardData.CardType.TACTICAL:
			return card.possession_value
		CardData.CardType.DEF_BUFF:
			return card.defense_value
	return 1  # Fallback for other card types

func _weighted_pick(weights: Dictionary) -> String:
	var total: float = 0.0
	for w in weights.values():
		total += w
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for key in weights:
		cumulative += weights[key]
		if roll <= cumulative:
			return key
	return weights.keys().back()
