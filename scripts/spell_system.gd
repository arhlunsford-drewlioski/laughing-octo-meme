class_name SpellSystem
extends RefCounted
## Manages spell deck, hand, mana regen, and opponent AI casting for the sorcerer duel.

const MAX_HAND_SIZE: int = 5
const MAX_MANA: float = 10.0
const MANA_REGEN_PER_TICK: float = 0.011  # ~1 mana per 9 match-minutes, ~10 total per match

var deck: Array[SpellData] = []
var hand: Array[SpellData] = []
var mana: float = 0.0  # starts at 0, regens over time

# Opponent AI sorcerer
var opponent_hand: Array[SpellData] = []
var opponent_mana: float = 0.0
var opponent_casting: bool = false        # is the AI currently winding up?
var opponent_cast_spell: SpellData = null  # the spell being wound up
var opponent_cast_progress: float = 0.0   # 0.0 to 1.0 (1.0 = fires)
var opponent_cast_target_x: float = 0.5
var opponent_cast_target_y: float = 0.5
const OPPONENT_WINDUP_TICKS: int = 15     # 1.5 seconds to wind up
var _opponent_cast_ticks: int = 0
var _opponent_cooldown: float = 0.0       # seconds before AI considers next cast

# Track post-match effects
var blood_pact_targets: Array[GoblinData] = []
var dark_ascension_targets: Array[GoblinData] = []
var curse_charges: int = 0

# Shield dome tracking: {GoblinData: ticks_remaining}
var shielded_goblins: Dictionary = {}
const SHIELD_DURATION_TICKS: int = 200  # 20 seconds

func setup(spell_deck: Array[SpellData], opponent_spells: Array[SpellData] = []) -> void:
	deck = spell_deck.duplicate()
	mana = 0.0
	blood_pact_targets.clear()
	dark_ascension_targets.clear()
	curse_charges = 0
	shielded_goblins.clear()
	opponent_casting = false
	opponent_cast_spell = null
	opponent_cast_progress = 0.0
	_opponent_cast_ticks = 0
	_opponent_cooldown = 3.0  # wait 3 seconds before first cast
	opponent_mana = 0.0
	_draw_hand()
	_draw_opponent_hand(opponent_spells)

func _draw_hand() -> void:
	hand.clear()
	if deck.is_empty():
		return
	var pool := deck.duplicate()
	pool.shuffle()
	var draw_count := mini(MAX_HAND_SIZE, pool.size())
	for i in draw_count:
		hand.append(pool[i])

func _draw_opponent_hand(spells: Array[SpellData]) -> void:
	opponent_hand = spells.duplicate()
	if opponent_hand.is_empty():
		# Default opponent loadout: fireball + shield dome
		opponent_hand = [
			SpellDatabase.fireball(),
			SpellDatabase.fireball(),
			SpellDatabase.shield_dome(),
			SpellDatabase.shield_dome(),
			SpellDatabase.haste(),
		]

func tick() -> void:
	## Call once per sim tick. Regens mana, ticks shields, advances opponent cast.
	mana = minf(mana + MANA_REGEN_PER_TICK, MAX_MANA)
	opponent_mana = minf(opponent_mana + MANA_REGEN_PER_TICK, MAX_MANA)

	# Tick shield durations
	var expired_shields: Array = []
	for g in shielded_goblins:
		shielded_goblins[g] = int(shielded_goblins[g]) - 1
		if int(shielded_goblins[g]) <= 0:
			expired_shields.append(g)
	for g in expired_shields:
		shielded_goblins.erase(g)

	# Tick opponent cooldown
	if _opponent_cooldown > 0.0:
		_opponent_cooldown -= 0.1  # TICK_DELTA

	# Tick opponent wind-up
	if opponent_casting:
		_opponent_cast_ticks += 1
		opponent_cast_progress = float(_opponent_cast_ticks) / float(OPPONENT_WINDUP_TICKS)
		if _opponent_cast_ticks >= OPPONENT_WINDUP_TICKS:
			opponent_casting = false  # ready to fire - match_sim_viewer will handle it

func can_cast(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	return hand[index].mana_cost <= mana

func cast(index: int) -> SpellData:
	if not can_cast(index):
		return null
	var spell := hand[index]
	mana -= spell.mana_cost
	hand.remove_at(index)
	return spell

func is_goblin_shielded(goblin: GoblinData) -> bool:
	return shielded_goblins.has(goblin)

func apply_shield(goblin: GoblinData) -> void:
	shielded_goblins[goblin] = SHIELD_DURATION_TICKS

func counter_opponent_cast() -> bool:
	## Cancel the opponent's current wind-up. Returns true if successful.
	if not opponent_casting:
		return false
	if mana < 1.0:
		return false
	mana -= 1.0  # counter costs 1 mana
	opponent_casting = false
	opponent_cast_spell = null
	opponent_cast_progress = 0.0
	_opponent_cast_ticks = 0
	_opponent_cooldown = 5.0  # opponent waits longer after being countered
	return true

func try_opponent_cast(home_formation: Formation, away_formation: Formation,
		goblin_states: Dictionary) -> void:
	## AI decides whether to start casting. Called from match_sim_viewer.
	if opponent_casting or _opponent_cooldown > 0.0:
		return
	if opponent_hand.is_empty():
		return

	# Find a spell we can afford
	var castable: Array[int] = []
	for i in opponent_hand.size():
		if opponent_hand[i].mana_cost <= opponent_mana:
			castable.append(i)
	if castable.is_empty():
		return

	# Random chance to cast each tick (~5% when mana available)
	if randf() > 0.05:
		return

	# Pick a random castable spell
	var idx: int = castable[randi() % castable.size()]
	var spell: SpellData = opponent_hand[idx]

	# Start wind-up
	opponent_casting = true
	opponent_cast_spell = spell
	opponent_cast_progress = 0.0
	_opponent_cast_ticks = 0
	opponent_mana -= spell.mana_cost
	opponent_hand.remove_at(idx)

	# Pick target: random enemy (player) goblin for most spells
	var player_goblins: Array = home_formation.get_all()
	if not player_goblins.is_empty():
		var target_goblin: GoblinData = player_goblins[randi() % player_goblins.size()]
		if goblin_states.has(target_goblin):
			var gs: Dictionary = goblin_states[target_goblin]
			opponent_cast_target_x = float(gs["x"])
			opponent_cast_target_y = float(gs["y"])
		else:
			opponent_cast_target_x = randf_range(0.2, 0.5)
			opponent_cast_target_y = randf_range(0.2, 0.8)
	_opponent_cooldown = randf_range(4.0, 8.0)  # wait 4-8 seconds between casts

func get_mana_fraction() -> float:
	return mana / MAX_MANA

func get_opponent_mana_fraction() -> float:
	return opponent_mana / MAX_MANA

func apply_post_match_injuries() -> void:
	for g in blood_pact_targets:
		if g.is_alive():
			g.apply_injury(GoblinData.InjuryState.MINOR)
