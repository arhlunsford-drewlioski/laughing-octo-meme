extends Node
## Global match state. Autoloaded as GameManager.

# -- Constants --
const MAX_ROUNDS: int = 8
const HALFTIME_AFTER: int = 4
const ENERGY_PER_ROUND: int = 3
const MOMENTUM_MIN: int = -5
const MOMENTUM_MAX: int = 5  # 11 ticks total: -5 to +5, center = 0
const HAND_DRAW_SIZE: int = 5

# -- Match state --
var current_round: int = 0
var energy: int = ENERGY_PER_ROUND

## Momentum: -5 (full opponent) to +5 (full player). 0 = center.
var momentum: int = 0

var player_goals: int = 0
var opponent_goals: int = 0

enum Phase { SETUP, PLAY_CARDS, RESOLVING, ROUND_END, HALFTIME, MATCH_END }
var current_phase: Phase = Phase.SETUP

# -- Formations --
var player_formation: Formation
var opponent_formation: Formation

# -- Draft roster (passed from draft screen to match) --
var selected_roster: Array[GoblinData] = []

# -- Faction state (set per match from RunManager) --
var player_faction: int = 0
var opponent_faction: int = 0

# -- Signals --
signal momentum_changed(new_value: int)
signal score_changed(player_goals: int, opponent_goals: int)
signal round_started(round_num: int)
signal phase_changed(new_phase: Phase)
signal energy_changed(new_energy: int)
signal formation_changed()

# -- Methods --
func reset_match() -> void:
	current_round = 0
	momentum = 0
	player_goals = 0
	opponent_goals = 0
	energy = ENERGY_PER_ROUND
	set_phase(Phase.SETUP)
	score_changed.emit(player_goals, opponent_goals)
	momentum_changed.emit(momentum)
	energy_changed.emit(energy)

func set_phase(phase: Phase) -> void:
	current_phase = phase
	phase_changed.emit(phase)

func start_round() -> void:
	current_round += 1
	energy = ENERGY_PER_ROUND
	energy_changed.emit(energy)
	round_started.emit(current_round)
	set_phase(Phase.PLAY_CARDS)

func spend_energy(cost: int) -> bool:
	if cost > energy:
		return false
	energy -= cost
	energy_changed.emit(energy)
	return true

func refund_energy(cost: int) -> void:
	energy = mini(energy + cost, ENERGY_PER_ROUND)
	energy_changed.emit(energy)

func shift_momentum(amount: int) -> void:
	momentum += amount
	momentum_changed.emit(momentum)

func is_match_over() -> bool:
	return current_round >= MAX_ROUNDS and current_phase == Phase.ROUND_END

func is_halftime() -> bool:
	return current_round == HALFTIME_AFTER and current_phase == Phase.ROUND_END

# -- Zone ratings from formations --
func get_player_zones() -> Dictionary:
	if player_formation:
		return player_formation.get_zone_ratings()
	return { "attack": 0, "midfield": 0, "defense": 0, "goal": 0 }

func get_opponent_zones() -> Dictionary:
	if opponent_formation:
		return opponent_formation.get_zone_ratings()
	return { "attack": 0, "midfield": 0, "defense": 0, "goal": 0 }
