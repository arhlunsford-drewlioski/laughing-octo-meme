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

# -- Possession passive: Gorwick (+1 Possession per Possession card played) --

func possession_play_bonus(is_player: bool) -> int:
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0
	var bonus: int = 0
	for goblin in formation.get_all_outfield():
		if goblin.passive_description.begins_with("Adds +1 Possession"):
			bonus += 1
	return bonus

# -- Possession disruption: Old Mugwort (-1 to opponent Possession cards) --

func possession_disruption_penalty(is_opponent: bool) -> int:
	## Returns the penalty subtracted from each opponent Possession card's value.
	var formation: Formation = GameManager.player_formation if not is_opponent else GameManager.opponent_formation
	if formation == null:
		return 0
	var penalty: int = 0
	for goblin in formation.get_all_outfield():
		if goblin.passive_description.begins_with("Opponent Possession cards give -1"):
			penalty += 1
	var keeper := formation.get_keeper()
	if keeper and keeper.passive_description.begins_with("Opponent Possession cards give -1"):
		penalty += 1
	return penalty

# -- Tempo goal modifiers from goblins --

func tempo_goal_bonus(is_player: bool, card: CardData) -> float:
	## Returns bonus to add to this side's Tempo goal conversion threshold.
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0.0
	var bonus: float = 0.0
	# "Definitely Not Offside Dave" - +5% Tempo conversion when in Attack zone
	for goblin in formation.attack:
		if goblin.passive_description.begins_with("Tempo cards gain +5%"):
			bonus += 0.05
	# "Snaggleclaw the Lucky" - Tempo cards under 25% base gain +10%
	if card.base_conversion < 0.25:
		for goblin in formation.get_all_outfield():
			if goblin.passive_description.begins_with("Tempo cards under 25%"):
				bonus += 0.10
		var keeper := formation.get_keeper()
		if keeper and keeper.passive_description.begins_with("Tempo cards under 25%"):
			bonus += 0.10
	return bonus

func tempo_goal_penalty(is_defender: bool) -> float:
	## Returns penalty to subtract from the opposing side's Tempo conversion.
	var formation: Formation = GameManager.player_formation if is_defender else GameManager.opponent_formation
	if formation == null:
		return 0.0
	var penalty: float = 0.0
	# "Skulkra Ironshins" - reduces opponent Tempo conversion by 3% when in Defense
	for goblin in formation.defense:
		if goblin.passive_description.begins_with("Reduces opponent Tempo"):
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
