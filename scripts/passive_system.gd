class_name PassiveSystem
extends RefCounted
## Centralized goblin passive ability resolution.
## Queries formations and returns modifiers for the match engine and controller.

# -- Keeper save tracking --
var player_keeper_save_used: bool = false
var opponent_keeper_save_used: bool = false

func reset() -> void:
	player_keeper_save_used = false
	opponent_keeper_save_used = false

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

# -- Chance conversion modifiers from goblins --

func chance_conversion_bonus(is_player: bool) -> float:
	## Returns bonus to add to this side's Chance conversion threshold.
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0.0
	var bonus: float = 0.0
	# "Definitely Not Offside Dave" - +5% Chance conversion when in Attack zone
	for goblin in formation.attack:
		if goblin.passive_description.begins_with("Chance cards gain +5%"):
			bonus += 0.05
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

# -- Draw bonus: Whizzik (+1 card if in Midfield) --

func extra_draw_count(is_player: bool) -> int:
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null:
		return 0
	var extra: int = 0
	for goblin in formation.midfield:
		if goblin.passive_description.begins_with("Draws an extra card"):
			extra += 1
	return extra

# -- Keeper save: Nettlebrine (once per match, negate a goal) --

func try_keeper_save(is_player: bool) -> bool:
	## Returns true if the keeper negates this goal. Consumes the save.
	var formation: Formation = GameManager.player_formation if is_player else GameManager.opponent_formation
	if formation == null or formation.keeper == null:
		return false
	if not formation.keeper.passive_description.begins_with("Once per match"):
		return false

	if is_player and not player_keeper_save_used:
		player_keeper_save_used = true
		return true
	elif not is_player and not opponent_keeper_save_used:
		opponent_keeper_save_used = true
		return true
	return false
