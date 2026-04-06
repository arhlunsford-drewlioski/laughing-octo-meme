class_name AutoEngine
extends RefCounted
## Auto-resolve engine for autobattler mode. Zone vs zone matchups.

# Buffs applied this round (reset each round)
var player_atk_buff: int = 0
var player_def_buff: int = 0
var player_mid_buff: int = 0
var opponent_atk_buff: int = 0
var opponent_def_buff: int = 0
var opponent_mid_buff: int = 0

# Keeper save tracking
var player_keeper_save_used: bool = false
var opponent_keeper_save_used: bool = false

func reset_round() -> void:
	player_atk_buff = 0
	player_def_buff = 0
	player_mid_buff = 0
	opponent_atk_buff = 0
	opponent_def_buff = 0
	opponent_mid_buff = 0

func apply_buff(card: CardData, is_player: bool) -> void:
	var value: int = 0
	match card.card_type:
		CardData.CardType.ATK_BUFF:
			value = card.possession_value
			if is_player:
				player_atk_buff += value
			else:
				opponent_atk_buff += value
		CardData.CardType.DEF_BUFF:
			value = card.defense_value
			if is_player:
				player_def_buff += value
			else:
				opponent_def_buff += value
		CardData.CardType.MID_BUFF:
			value = card.possession_value
			if is_player:
				player_mid_buff += value
			else:
				opponent_mid_buff += value
		CardData.CardType.TACTICAL:
			# +ATK, -DEF tradeoff
			value = card.possession_value
			if is_player:
				player_atk_buff += value
				player_def_buff -= 2
			else:
				opponent_atk_buff += value
				opponent_def_buff -= 2

func resolve_round(player_formation: Formation, opponent_formation: Formation, momentum: int) -> Array[Dictionary]:
	## Returns array of event dicts describing what happened.
	## Events: { "type": "midfield"/"chance"/"goal"/"miss"/"save", "side": "player"/"opponent", ... }
	var events: Array[Dictionary] = []
	var player_zones: Dictionary = player_formation.get_zone_ratings()
	var opponent_zones: Dictionary = opponent_formation.get_zone_ratings()

	# 1. Midfield battle
	var player_mid: int = player_zones["midfield"] + player_mid_buff
	var opp_mid: int = opponent_zones["midfield"] + opponent_mid_buff
	var mid_diff: int = player_mid - opp_mid
	var possession: float = clampf(0.5 + mid_diff * 0.05, 0.2, 0.8)

	events.append({
		"type": "midfield",
		"player_mid": player_mid,
		"opponent_mid": opp_mid,
		"possession": possession,
	})

	# 2. Player attack vs opponent defense
	var player_atk: int = player_zones["attack"] + player_atk_buff
	var opp_def: int = opponent_zones["defense"] + opponent_def_buff
	var player_chances: int = _calc_chances(player_atk, opp_def)

	events.append({
		"type": "attack_phase",
		"side": "player",
		"atk": player_atk,
		"def": opp_def,
		"chances": player_chances,
	})

	# Resolve player chances
	for i in player_chances:
		var threshold: float = _goal_threshold(possession, momentum, true)
		var roll: float = randf()
		var converted: bool = roll <= threshold
		var saved: bool = false

		if converted:
			saved = _try_keeper_save(opponent_formation, false)
			if saved:
				converted = false

		var goblin_name: String = _pick_scorer(player_formation, "attack")
		events.append({
			"type": "goal" if converted else ("save" if saved else "miss"),
			"side": "player",
			"threshold": threshold,
			"roll": roll,
			"goblin": goblin_name,
		})

	# 3. Opponent attack vs player defense
	var opp_atk: int = opponent_zones["attack"] + opponent_atk_buff
	var player_def: int = player_zones["defense"] + player_def_buff
	var opp_chances: int = _calc_chances(opp_atk, player_def)

	events.append({
		"type": "attack_phase",
		"side": "opponent",
		"atk": opp_atk,
		"def": player_def,
		"chances": opp_chances,
	})

	# Resolve opponent chances (invert possession and momentum)
	var opp_possession: float = 1.0 - possession
	for i in opp_chances:
		var threshold: float = _goal_threshold(opp_possession, -momentum, true)
		var roll: float = randf()
		var converted: bool = roll <= threshold
		var saved: bool = false

		if converted:
			saved = _try_keeper_save(player_formation, true)
			if saved:
				converted = false

		var goblin_name: String = _pick_scorer(opponent_formation, "attack")
		events.append({
			"type": "goal" if converted else ("save" if saved else "miss"),
			"side": "opponent",
			"threshold": threshold,
			"roll": roll,
			"goblin": goblin_name,
		})

	# 4. Momentum shift based on possession
	var mom_shift: int = 0
	if mid_diff > 4:
		mom_shift = 2
	elif mid_diff > 0:
		mom_shift = 1
	elif mid_diff < -4:
		mom_shift = -2
	elif mid_diff < 0:
		mom_shift = -1

	events.append({
		"type": "momentum",
		"shift": mom_shift,
	})

	return events

func _calc_chances(atk: int, def: int) -> int:
	var diff: int = atk - def
	return maxi(1, 1 + diff / 3)  # Always at least 1 chance

func _goal_threshold(possession: float, momentum: int, _is_attacker: bool) -> float:
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
