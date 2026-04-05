class_name PassiveSystem
extends RefCounted
## Centralized goblin passive ability resolution.
## Queries formations and returns modifiers for the match engine and controller.

# -- Keeper save tracking --
var player_keeper_save_used: bool = false
var opponent_keeper_save_used: bool = false

# -- Halftime tracking for Pibble --
var past_halftime: bool = false

func reset() -> void:
	player_keeper_save_used = false
	opponent_keeper_save_used = false
	past_halftime = false

# -- Tempo passive: Gorwick (+1 Possession per Tempo card played) --

func tempo_possession_bonus(is_player: bool) -> int:
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0
	var bonus: int = 0
	for goblin in formation.get_all_outfield():
		if goblin.passive_description.begins_with("Adds +1 Possession"):
			bonus += 1
	return bonus

# -- Tempo disruption: Old Mugwort (-1 to opponent Tempo Possession) --

func tempo_disruption_penalty(is_opponent: bool) -> int:
	## Returns the penalty subtracted from each opponent Tempo card's possession.
	var formation: Formation = GameManager.player_formation if not is_opponent else GameManager.opponent_formation
	if formation == null:
		return 0
	var penalty: int = 0
	for goblin in formation.get_all_outfield():
		if goblin.passive_description.begins_with("Opponent Tempo cards give -1"):
			penalty += 1
	# Also check goal
	var keeper := formation.get_keeper()
	if keeper and keeper.passive_description.begins_with("Opponent Tempo cards give -1"):
		penalty += 1
	return penalty

# -- Chance conversion modifiers from goblins --

func chance_conversion_bonus(is_player: bool, card: CardData) -> float:
	## Returns bonus to add to this side's Chance conversion threshold.
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0.0
	var bonus: float = 0.0
	# "Definitely Not Offside Dave" - +5% Chance conversion when in Attack zone
	for goblin in formation.attack:
		if goblin.passive_description.begins_with("Chance cards gain +5%"):
			bonus += 0.05
	# "Snaggleclaw the Lucky" - Chance cards under 25% base gain +10%
	if card.base_conversion < 0.25:
		for goblin in formation.get_all_outfield():
			if goblin.passive_description.begins_with("Chance cards under 25%"):
				bonus += 0.10
		var keeper := formation.get_keeper()
		if keeper and keeper.passive_description.begins_with("Chance cards under 25%"):
			bonus += 0.10
	return bonus

func chance_conversion_penalty(is_defender: bool) -> float:
	## Returns penalty to subtract from the opposing side's Chance conversion.
	var formation: Formation = GameManager.player_formation if is_defender else GameManager.opponent_formation
	if formation == null:
		return 0.0
	var penalty: float = 0.0
	# "Skulkra Ironshins" - reduces opponent Chance conversion by 3% when in Defense
	for goblin in formation.defense:
		if goblin.passive_description.begins_with("Reduces opponent Chance"):
			penalty += 0.03
	return penalty

# -- Draw bonus: Whizzik (+1 card if in Midfield), Pibble (+1 after halftime) --

func extra_draw_count(is_player: bool) -> int:
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0
	var extra: int = 0
	for goblin in formation.midfield:
		if goblin.passive_description.begins_with("Draws an extra card"):
			extra += 1
	# Pibble: after halftime, draw 1 extra card each round
	if past_halftime:
		for goblin in formation.get_all_outfield():
			if goblin.passive_description.begins_with("After halftime"):
				extra += 1
		var keeper := formation.get_keeper()
		if keeper and keeper.passive_description.begins_with("After halftime"):
			extra += 1
	return extra

# -- Goal momentum: Blix (+1 Momentum when you score) --

func goal_momentum_bonus(is_player: bool) -> int:
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0
	var bonus: int = 0
	for goblin in formation.get_all_outfield():
		if goblin.passive_description.begins_with("Scoring a goal shifts"):
			bonus += 1
	var keeper := formation.get_keeper()
	if keeper and keeper.passive_description.begins_with("Scoring a goal shifts"):
		bonus += 1
	return bonus

# -- Keeper save: Nettlebrine (once per match, negate a goal) --

func try_keeper_save(is_player: bool) -> bool:
	## Returns true if the keeper negates this goal. Consumes the save.
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return false
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
