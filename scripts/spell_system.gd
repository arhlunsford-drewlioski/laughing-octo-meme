class_name SpellSystem
extends RefCounted
## Manages the Sorcerer Duel layer: mana pacing, active domes, and opponent casting.

const MAX_HAND_SIZE: int = 5
const MAX_MANA: float = 10.0
const MANA_REGEN_PER_TICK: float = 0.009  # ~10 mana over a full 90-minute sim
const OPPONENT_WINDUP_TICKS: int = 16
const DOME_DURATION_TICKS: int = 180
const DOME_RADIUS: float = 0.12

var deck: Array[SpellData] = []
var hand: Array[SpellData] = []
var mana: float = 0.0

var opponent_hand: Array[SpellData] = []
var opponent_mana: float = 0.0
var opponent_archetype: Dictionary = {}  # the archetype info for this match
var opponent_archetype_name: String = "RIVAL SORCERER"
var opponent_casting: bool = false
var opponent_cast_ready: bool = false
var opponent_cast_spell: SpellData = null
var opponent_cast_progress: float = 0.0
var opponent_cast_target_x: float = 0.5
var opponent_cast_target_y: float = 0.5
var opponent_cast_target_goblin: GoblinData = null
var _opponent_cast_ticks: int = 0
var _opponent_cooldown: float = 0.0
var _opponent_cast_chance: float = 0.05
var _opponent_cooldown_min: float = 4.0
var _opponent_cooldown_max: float = 6.5

var blood_pact_targets: Array[GoblinData] = []
var dark_ascension_targets: Array[GoblinData] = []
var curse_charges: int = 0
var active_domes: Array[Dictionary] = []  # {team_index, x, y, radius, ticks}

func setup(spell_deck: Array[SpellData], opponent_spells: Array[SpellData] = []) -> void:
	deck.clear()
	for spell in spell_deck:
		if spell != null and spell.special_effect == "counter_spell":
			deck.append(SpellDatabase.healing_wave())
		elif spell != null:
			deck.append(spell)
	hand.clear()
	mana = 4.0
	blood_pact_targets.clear()
	dark_ascension_targets.clear()
	curse_charges = 0
	active_domes.clear()
	opponent_casting = false
	opponent_cast_ready = false
	opponent_cast_spell = null
	opponent_cast_progress = 0.0
	opponent_cast_target_goblin = null
	_opponent_cast_ticks = 0
	_opponent_cooldown = 4.5
	opponent_mana = 4.0
	_draw_hand()
	_draw_opponent_hand(opponent_spells)

func _draw_hand() -> void:
	hand.clear()
	if deck.is_empty():
		return
	var pool := deck.duplicate()
	pool.shuffle()
	var draw_count := mini(MAX_HAND_SIZE, pool.size())
	for i in range(draw_count):
		hand.append(pool[i])

func _draw_opponent_hand(spells: Array[SpellData]) -> void:
	if not spells.is_empty():
		opponent_hand.clear()
		for spell in spells:
			if spell != null and spell.special_effect == "counter_spell":
				opponent_hand.append(SpellDatabase.healing_wave())
			elif spell != null:
				opponent_hand.append(spell)
		opponent_archetype_name = "RIVAL SORCERER"
		_opponent_cast_chance = 0.05
		_opponent_cooldown_min = 4.0
		_opponent_cooldown_max = 6.0
		return

	var profile: Dictionary = _roll_opponent_profile()
	opponent_archetype_name = str(profile.get("name", "RIVAL SORCERER"))
	_opponent_cast_chance = float(profile.get("cast_chance", 0.05))
	_opponent_cooldown_min = float(profile.get("cooldown_min", 4.0))
	_opponent_cooldown_max = float(profile.get("cooldown_max", 6.0))
	opponent_hand.clear()
	for spell in profile.get("spells", []):
		if spell != null:
			opponent_hand.append(spell)

func _roll_opponent_profile() -> Dictionary:
	## Pick one of the 10 archetypes from SorcererArchetypes.
	var archetype: Dictionary = SorcererArchetypes.random_archetype()
	opponent_archetype = archetype
	# Convert archetype data into profile format expected by this system
	# Aggression -> cast_chance + cooldown
	var aggression: float = float(archetype.get("aggression", 0.5))
	return {
		"name": archetype.get("name", "RIVAL SORCERER").to_upper(),
		"spells": archetype.get("spells", []),
		"cast_chance": 0.03 + aggression * 0.05,  # 0.03 - 0.08
		"cooldown_min": 6.0 - aggression * 3.0,   # 3.0 - 6.0
		"cooldown_max": 8.0 - aggression * 3.0,   # 5.0 - 8.0
	}

func tick() -> void:
	mana = minf(mana + MANA_REGEN_PER_TICK, MAX_MANA)
	opponent_mana = minf(opponent_mana + MANA_REGEN_PER_TICK, MAX_MANA)

	var expired_domes: Array[int] = []
	for i in range(active_domes.size()):
		var dome: Dictionary = active_domes[i]
		dome["ticks"] = int(dome.get("ticks", 0)) - 1
		active_domes[i] = dome
		if int(dome.get("ticks", 0)) <= 0:
			expired_domes.append(i)
	expired_domes.reverse()
	for idx in expired_domes:
		active_domes.remove_at(idx)

	if _opponent_cooldown > 0.0:
		_opponent_cooldown = maxf(_opponent_cooldown - 0.1, 0.0)

	if opponent_casting:
		_opponent_cast_ticks += 1
		opponent_cast_progress = minf(float(_opponent_cast_ticks) / float(OPPONENT_WINDUP_TICKS), 1.0)
		if _opponent_cast_ticks >= OPPONENT_WINDUP_TICKS:
			opponent_cast_ready = true

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

func clear_opponent_cast() -> void:
	opponent_casting = false
	opponent_cast_ready = false
	opponent_cast_spell = null
	opponent_cast_progress = 0.0
	opponent_cast_target_goblin = null
	_opponent_cast_ticks = 0

func apply_dome(team_index: int, target_x: float, target_y: float) -> void:
	active_domes.append({
		"team_index": team_index,
		"x": target_x,
		"y": target_y,
		"radius": DOME_RADIUS,
		"ticks": DOME_DURATION_TICKS,
	})

func get_active_domes_visuals() -> Array[Dictionary]:
	return active_domes.duplicate(true)

func is_goblin_protected(goblin: GoblinData, goblin_states: Dictionary) -> bool:
	if not goblin_states.has(goblin):
		return false
	var gs: Dictionary = goblin_states[goblin]
	var team_index: int = 0 if bool(gs.get("is_home", false)) else 1
	var gx: float = float(gs.get("x", 0.0))
	var gy: float = float(gs.get("y", 0.0))
	for dome in active_domes:
		if int(dome.get("team_index", -1)) != team_index:
			continue
		var radius: float = float(dome.get("radius", DOME_RADIUS))
		var dx: float = gx - float(dome.get("x", 0.0))
		var dy: float = gy - float(dome.get("y", 0.0))
		if sqrt(dx * dx + dy * dy) <= radius:
			return true
	return false

func try_opponent_cast(home_formation: Formation, away_formation: Formation,
		goblin_states: Dictionary) -> void:
	if opponent_casting or opponent_cast_ready or _opponent_cooldown > 0.0:
		return
	if opponent_hand.is_empty():
		return

	var options: Array[Dictionary] = []
	for i in range(opponent_hand.size()):
		var spell: SpellData = opponent_hand[i]
		if spell.mana_cost > opponent_mana:
			continue
		var option: Dictionary = _build_opponent_option(spell, home_formation, away_formation, goblin_states)
		if option.is_empty():
			continue
		option["spell_index"] = i
		option["spell"] = spell
		options.append(option)
	if options.is_empty():
		return

	if randf() > _opponent_cast_chance:
		return

	var picked: Dictionary = {}
	var picked_score: float = -999.0
	for option in options:
		var option_score: float = float(option.get("score", 0.0)) + randf() * 0.35
		if option_score > picked_score:
			picked_score = option_score
			picked = option
	if picked.is_empty():
		return
	var idx: int = int(picked["spell_index"])
	var spell: SpellData = opponent_hand[idx]

	opponent_casting = true
	opponent_cast_ready = false
	opponent_cast_spell = spell
	opponent_cast_progress = 0.0
	opponent_cast_target_x = float(picked.get("x", 0.5))
	opponent_cast_target_y = float(picked.get("y", 0.5))
	opponent_cast_target_goblin = picked.get("goblin", null) as GoblinData
	_opponent_cast_ticks = 0
	opponent_mana -= spell.mana_cost
	opponent_hand.remove_at(idx)
	_opponent_cooldown = randf_range(_opponent_cooldown_min, _opponent_cooldown_max)

func _build_opponent_option(spell: SpellData, home_formation: Formation, away_formation: Formation,
		goblin_states: Dictionary) -> Dictionary:
	match spell.special_effect:
		"fireball":
			return _pick_cluster_target(home_formation.get_all(), goblin_states, true)
		"lightning_bolt":
			return _pick_chain_target(home_formation.get_all(), goblin_states, true)
		"meteor":
			return _pick_cluster_target(home_formation.get_all(), goblin_states, true)
		"earthquake":
			return {"x": 0.5, "y": 0.5, "score": 2.0}
		"chain_lightning":
			return _pick_chain_target(home_formation.get_all(), goblin_states, true)
		"rot_curse":
			return _pick_chain_target(home_formation.get_all(), goblin_states, true)
		"shield_dome":
			return _pick_support_cluster(away_formation.get_all(), goblin_states, false)
		"mass_protect":
			return {"x": 0.5, "y": 0.5, "score": 2.5}
		"heal":
			return _pick_heal_target(away_formation.get_all(), goblin_states)
		"healing_wave":
			return _pick_heal_target(away_formation.get_all(), goblin_states)
		"resurrect":
			return {"x": 0.5, "y": 0.5, "score": 1.8}
		"counter_spell":
			return {"x": 0.5, "y": 0.5, "score": 0.5}
		"teleport":
			return _pick_support_cluster(away_formation.get_all(), goblin_states, false)
		"clone":
			return _pick_striker_target(away_formation.get_all(), goblin_states)
		"mind_control":
			return _pick_striker_target(home_formation.get_all(), goblin_states)
		"swap":
			return _pick_chain_target(home_formation.get_all(), goblin_states, false)
		"rage_potion":
			return _pick_striker_target(away_formation.get_all(), goblin_states)
		"haste":
			return {"x": 0.72, "y": 0.5, "score": 1.2}
		"hex":
			return _pick_chain_target(home_formation.get_all(), goblin_states, true)
		"war_cry":
			return {"x": 0.5, "y": 0.5, "score": 1.0}
		"blood_pact":
			return _pick_striker_target(away_formation.get_all(), goblin_states)
		"dark_surge":
			return _pick_striker_target(away_formation.get_all(), goblin_states)
	return {}

func _pick_cluster_target(goblins: Array, goblin_states: Dictionary, hostile: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	for goblin in goblins:
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var gx: float = float(gs["x"])
		var gy: float = float(gs["y"])
		var nearby: int = _count_nearby(goblins, goblin_states, gx, gy, 0.14)
		var score: float = float(nearby)
		if bool(gs.get("has_ball", false)):
			score += 1.5
		if hostile:
			score += clampf(gx, 0.0, 1.0)
		if score > best_score:
			best_score = score
			best = {"x": gx, "y": gy, "goblin": goblin, "score": score}
	return best

func _pick_chain_target(goblins: Array, goblin_states: Dictionary, prefer_ball_carrier: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	for goblin in goblins:
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var gx: float = float(gs["x"])
		var gy: float = float(gs["y"])
		var score: float = float(_count_nearby(goblins, goblin_states, gx, gy, 0.18)) * 1.4
		if prefer_ball_carrier and bool(gs.get("has_ball", false)):
			score += 2.0
		score += float(goblin.get_stat("shooting")) * 0.05
		if score > best_score:
			best_score = score
			best = {"x": gx, "y": gy, "goblin": goblin, "score": score}
	return best

func _pick_support_cluster(goblins: Array, goblin_states: Dictionary, prefer_injured: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	for goblin in goblins:
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var gx: float = float(gs["x"])
		var gy: float = float(gs["y"])
		var score: float = float(_count_nearby(goblins, goblin_states, gx, gy, 0.16))
		if bool(gs.get("has_ball", false)):
			score += 1.4
		if prefer_injured and goblin.injury != GoblinData.InjuryState.HEALTHY:
			score += 2.0
		if score > best_score:
			best_score = score
			best = {"x": gx, "y": gy, "goblin": goblin, "score": score}
	return best

func _pick_heal_target(goblins: Array, goblin_states: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	for goblin in goblins:
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var gx: float = float(gs["x"])
		var gy: float = float(gs["y"])
		var score: float = 0.5 + float(_count_nearby(goblins, goblin_states, gx, gy, 0.16)) * 0.6
		match goblin.injury:
			GoblinData.InjuryState.MAJOR:
				score += 3.0
			GoblinData.InjuryState.MINOR:
				score += 1.8
			_:
				if bool(gs.get("has_ball", false)):
					score += 1.0
		if score > best_score:
			best_score = score
			best = {"x": gx, "y": gy, "goblin": goblin, "score": score}
	return best

func _pick_striker_target(goblins: Array, goblin_states: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	for goblin in goblins:
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var score: float = float(goblin.get_stat("shooting")) * 0.3
		if bool(gs.get("has_ball", false)):
			score += 1.0
		if score > best_score:
			best_score = score
			best = {"x": float(gs["x"]), "y": float(gs["y"]), "goblin": goblin, "score": score}
	return best

func _count_nearby(goblins: Array, goblin_states: Dictionary, x: float, y: float, radius: float) -> int:
	var count: int = 0
	for goblin in goblins:
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var dx: float = float(gs["x"]) - x
		var dy: float = float(gs["y"]) - y
		if sqrt(dx * dx + dy * dy) <= radius:
			count += 1
	return count

func get_mana_fraction() -> float:
	return mana / MAX_MANA

func get_opponent_mana_fraction() -> float:
	return opponent_mana / MAX_MANA

func apply_post_match_injuries() -> void:
	for g in blood_pact_targets:
		if g.is_alive():
			g.apply_injury(GoblinData.InjuryState.MINOR)
