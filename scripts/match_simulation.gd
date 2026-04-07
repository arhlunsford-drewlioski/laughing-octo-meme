class_name MatchSimulation
extends RefCounted
## Core headless match engine. Ticks 4x/sec, emits state snapshots.
## No Node dependency - pure simulation logic.

# ── Constants ───────────────────────────────────────────────────────────────

const TICKS_PER_SECOND: float = 4.0
const TICK_DELTA: float = 1.0 / TICKS_PER_SECOND  # 0.25s real time
const MATCH_DURATION: float = 90.0  # match minutes
const MINUTES_PER_TICK: float = 0.5  # each tick = 0.5 match minutes -> 180 ticks per match
const READINESS_THRESHOLD: float = 2.0  # faster decisions
const MOVEMENT_SPEED: float = 0.07  # normalized units per tick at speed=5
const PASS_SPEED: float = 2.5  # ball travel speed for passes
const SHOT_SPEED: float = 3.5  # ball travel speed for shots
const LOOSE_BALL_RANGE: float = 0.25  # distance to auto-claim loose ball
const LOOSE_BALL_CHASE_RANGE: float = 0.50  # distance to start chasing loose ball
const TACKLE_RANGE: float = 0.10
const SHOT_RANGE: float = 0.30  # max distance from goal to shoot (tighter)

# ── Home positions (normalized) ─────────────────────────────────────────────
# Home team attacks right (x=1.0), away attacks left (x=0.0)

const HOME_ZONE_X := {
	"goal": 0.05,
	"defense": 0.22,
	"midfield": 0.42,
	"attack": 0.72,
}

const AWAY_ZONE_X := {
	"goal": 0.95,
	"defense": 0.78,
	"midfield": 0.58,
	"attack": 0.28,
}

# Y positions for 1-3 goblins in a zone
const ZONE_Y_SPREAD := {
	1: [0.5],
	2: [0.25, 0.75],
	3: [0.15, 0.50, 0.85],
}

# ── State ───────────────────────────────────────────────────────────────────

var home_formation: Formation
var away_formation: Formation
var ball: Ball
var clock: float = 0.0
var score: Array[int] = [0, 0]
var spells_locked: bool = false
var mana: Array[float] = [3.0, 3.0]
var match_started: bool = false
var match_over: bool = false

# Per-goblin runtime state: { GoblinData: { x, y, readiness, cooldown, action, facing } }
var goblin_states: Dictionary = {}

# Events generated this tick
var _tick_events: Array = []

# Debug counters
var _debug_actions: Dictionary = {}
var _debug_ticks: int = 0
var _debug_ready_count: int = 0
var _debug_cooldown_count: int = 0

# ── Dictionary helpers (Godot 4 Dictionary values are Variant) ──────────────

static func _gf(d: Dictionary, key: String) -> float:
	return float(d[key])

static func _gb(d: Dictionary, key: String) -> bool:
	return bool(d[key])

# ── Initialization ──────────────────────────────────────────────────────────

func start_match(home: Formation, away: Formation) -> Dictionary:
	home_formation = home
	away_formation = away
	ball = Ball.new()
	clock = 0.0
	score = [0, 0]
	match_started = true
	match_over = false
	_tick_events.clear()
	goblin_states.clear()

	# Place goblins at home positions
	_init_goblin_positions(home, true)
	_init_goblin_positions(away, false)

	# Reset goblin match state
	for goblin in home.get_all():
		goblin.reset_for_match()
	for goblin in away.get_all():
		goblin.reset_for_match()

	# Kick off - home team gets ball
	var home_mids := home.midfield
	if not home_mids.is_empty():
		var kicker: GoblinData = home_mids[0]
		var ks: Dictionary = goblin_states[kicker]
		ball.set_controlled(kicker, _gf(ks, "x"), _gf(ks, "y"))
	else:
		ball.set_dead(0.5, 0.5)

	return _build_snapshot()

func _init_goblin_positions(formation: Formation, is_home: bool) -> void:
	var zone_x_map: Dictionary = HOME_ZONE_X if is_home else AWAY_ZONE_X
	for zone_name in Formation.ZONES:
		var goblins: Array = formation.get_zone(zone_name)
		var base_x: float = zone_x_map[zone_name]
		var y_positions: Array = ZONE_Y_SPREAD.get(goblins.size(), [0.5])
		for i in goblins.size():
			var goblin: GoblinData = goblins[i]
			var yi: float = y_positions[mini(i, y_positions.size() - 1)]
			goblin_states[goblin] = {
				"x": base_x,
				"y": yi,
				"home_x": base_x,
				"home_y": yi,
				"readiness": randf_range(0.0, 5.0),
				"cooldown": 0.0,
				"action": GoblinAI.Action.IDLE,
				"facing": 1.0 if is_home else -1.0,
				"is_home": is_home,
			}

# ── Tick ────────────────────────────────────────────────────────────────────

func tick() -> Dictionary:
	if not match_started or match_over:
		return _build_snapshot()

	_tick_events.clear()
	_debug_ticks += 1
	_debug_ready_count = 0
	_debug_cooldown_count = 0

	# 1. Advance clock
	clock += MINUTES_PER_TICK
	if clock >= MATCH_DURATION:
		clock = MATCH_DURATION
		match_over = true
		_tick_events.append({"type": "match_end", "score": score.duplicate()})
		return _build_snapshot()

	# 2. Update ball
	_update_ball()

	# 3. Check loose ball claims
	_check_loose_ball_claims()

	# 4. Process goblins (sorted by readiness, highest first)
	var all_goblins: Array = _get_all_goblins_sorted_by_readiness()
	for goblin in all_goblins:
		var gs: Dictionary = goblin_states[goblin]

		# Accumulate readiness
		var spd: float = float(goblin.get_stat("speed"))
		gs["readiness"] = _gf(gs, "readiness") + spd * TICK_DELTA * 2.0

		# Tick cooldown
		if _gf(gs, "cooldown") > 0.0:
			gs["cooldown"] = _gf(gs, "cooldown") - TICK_DELTA
			_debug_cooldown_count += 1
			continue

		# Ready to act?
		if _gf(gs, "readiness") >= READINESS_THRESHOLD:
			gs["readiness"] = 0.0
			_debug_ready_count += 1
			_process_goblin_action(goblin)

	# 5. Set fallback movement for goblins without explicit targets
	_set_offball_movement()

	# 6. Move goblins toward their action targets
	_move_goblins()

	# 7. Update ball position if controlled
	if ball.state == Ball.BallState.CONTROLLED and ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		ball.x = _gf(owner_gs, "x")
		ball.y = _gf(owner_gs, "y")

	return _build_snapshot()

# ── Ball Update ─────────────────────────────────────────────────────────────

func _update_ball() -> void:
	var arrived := ball.update(TICK_DELTA)
	if arrived and ball.state == Ball.BallState.TRAVELLING:
		var receiver := _find_nearest_goblin_to(ball.x, ball.y, 0.15)
		if receiver:
			ball.set_controlled(receiver, ball.x, ball.y)
			_tick_events.append({"type": "pass_received", "goblin": receiver.goblin_name})
		else:
			ball.set_loose(ball.x, ball.y)

func _check_loose_ball_claims() -> void:
	if ball.state == Ball.BallState.DEAD:
		# Only used for kickoffs after goals - give to nearest goblin
		var nearest := _find_nearest_goblin_to(ball.x, ball.y, 999.0)
		if nearest:
			var ngs: Dictionary = goblin_states[nearest]
			ball.set_controlled(nearest, _gf(ngs, "x"), _gf(ngs, "y"))
		return

	if ball.state != Ball.BallState.LOOSE:
		return
	var nearest := _find_nearest_goblin_to(ball.x, ball.y, LOOSE_BALL_RANGE)
	if nearest:
		ball.set_controlled(nearest, ball.x, ball.y)
		_tick_events.append({"type": "ball_won", "goblin": nearest.goblin_name})

# ── Goblin Processing ──────────────────────────────────────────────────────

func _process_goblin_action(goblin: GoblinData) -> void:
	var gs: Dictionary = goblin_states[goblin]
	var ctx := _build_ai_context(goblin)
	var decision := GoblinAI.decide(ctx)

	gs["action"] = decision.action
	var action_name: String = GoblinAI.Action.keys()[decision.action]
	_debug_actions[action_name] = _debug_actions.get(action_name, 0) + 1

	match decision.action:
		GoblinAI.Action.PASS, GoblinAI.Action.CLEAR, GoblinAI.Action.HOLD_UP:
			_execute_pass(goblin, decision)
		GoblinAI.Action.SHOOT:
			_execute_shot(goblin, decision)
		GoblinAI.Action.CROSS:
			_execute_cross(goblin, decision)
		GoblinAI.Action.DRIBBLE:
			_execute_dribble(goblin, decision)
		GoblinAI.Action.TACKLE:
			_execute_tackle(goblin, decision)
		GoblinAI.Action.INTERCEPT, GoblinAI.Action.CHASE_BALL, GoblinAI.Action.MOVE_TO_POSITION:
			_set_move_target(goblin, decision.target_x, decision.target_y)
		_:
			pass

func _execute_pass(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	var gs: Dictionary = goblin_states[goblin]

	var accuracy: float = 0.70 + goblin.get_stat("speed") * 0.03
	var chaos_var: float = goblin.get_stat("chaos") * 0.02
	accuracy += randf_range(-chaos_var, chaos_var)

	var tx: float = decision.target_x
	var ty: float = decision.target_y

	if randf() > accuracy:
		tx += randf_range(-0.1, 0.1)
		ty += randf_range(-0.1, 0.1)
		tx = clampf(tx, 0.0, 1.0)
		ty = clampf(ty, 0.0, 1.0)

	ball.set_travelling(_gf(gs, "x"), _gf(gs, "y"), tx, ty, PASS_SPEED)
	gs["cooldown"] = 0.5
	var to_name: String = decision.target_goblin.goblin_name if decision.target_goblin else ""
	_tick_events.append({"type": "pass", "from": goblin.goblin_name, "to": to_name})

func _execute_shot(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	var gs: Dictionary = goblin_states[goblin]
	var is_home: bool = _gb(gs, "is_home")
	var goal_x: float = 1.0 if is_home else 0.0

	var shooting: float = float(goblin.get_stat("shooting"))
	var strength: float = float(goblin.get_stat("strength"))
	var chaos: float = float(goblin.get_stat("chaos"))
	var dist_to_goal: float = absf(_gf(gs, "x") - goal_x)

	# Distance penalty: further shots are weaker and less accurate
	var dist_penalty: float = dist_to_goal * 2.0  # 0.28 away = -0.56 penalty
	var shot_power: float = shooting + strength * 0.3 - dist_penalty + randf_range(-chaos * 0.3, chaos * 0.3)
	var shot_accuracy: float = shooting * 0.8 - dist_penalty + randf_range(-chaos * 0.3, chaos * 0.3)

	# Find opponent keeper
	var opp_formation: Formation = away_formation if is_home else home_formation
	var keeper: GoblinData = opp_formation.get_keeper()
	var keeper_save: float = 0.0
	if keeper:
		# Keeper save: strong enough to stop most, beatable by best
		keeper_save = float(keeper.get_stat("strength") + keeper.get_stat("defense")) * 0.65
		keeper_save += randf_range(-1.5, 1.5)

	# Check for blocks
	var opp_goblins := opp_formation.get_all()
	for opp in opp_goblins:
		if not goblin_states.has(opp):
			continue
		var opp_gs: Dictionary = goblin_states[opp]
		var dist: float = _dist(_gf(opp_gs, "x"), _gf(opp_gs, "y"), _gf(gs, "x"), _gf(gs, "y"))
		if dist < 0.12 and opp != keeper:
			var block_chance: float = (opp.get_stat("defense") + opp.get_stat("strength")) * 0.02
			if randf() < block_chance:
				_tick_events.append({"type": "block", "goblin": opp.goblin_name, "shooter": goblin.goblin_name})
				ball.set_loose(_gf(opp_gs, "x") + randf_range(-0.05, 0.05), _gf(opp_gs, "y") + randf_range(-0.05, 0.05))
				gs["cooldown"] = 0.75
				return

	_tick_events.append({"type": "shot", "goblin": goblin.goblin_name, "power": shot_power, "accuracy": shot_accuracy})
	gs["cooldown"] = 0.75  # Recovery after shooting

	# Resolution: miss if accuracy is low
	if shot_accuracy < 7.0 and randf() < (7.0 - shot_accuracy) * 0.15:
		_tick_events.append({"type": "miss", "goblin": goblin.goblin_name})
		ball.set_loose(goal_x, randf_range(0.3, 0.7))
	elif shot_power > keeper_save:
		var team_idx: int = 0 if is_home else 1
		score[team_idx] += 1
		_tick_events.append({"type": "goal", "goblin": goblin.goblin_name, "score": score.duplicate()})
		ball.set_dead(0.5, 0.5)
		_reset_positions_for_kickoff(1 - team_idx)
	else:
		var keeper_name: String = keeper.goblin_name if keeper else "unknown"
		_tick_events.append({"type": "save", "keeper": keeper_name, "shooter": goblin.goblin_name})
		if randf() < 0.35:
			ball.set_loose(goal_x + (0.08 if not is_home else -0.08), randf_range(0.35, 0.65))
		else:
			if keeper and goblin_states.has(keeper):
				var kgs: Dictionary = goblin_states[keeper]
				ball.set_controlled(keeper, _gf(kgs, "x"), _gf(kgs, "y"))
			else:
				ball.set_loose(goal_x + (0.08 if not is_home else -0.08), 0.5)

func _execute_cross(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	var gs: Dictionary = goblin_states[goblin]
	ball.set_travelling(_gf(gs, "x"), _gf(gs, "y"), decision.target_x, decision.target_y, PASS_SPEED * 0.8)
	gs["cooldown"] = 0.5
	_tick_events.append({"type": "cross", "goblin": goblin.goblin_name})

func _execute_dribble(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	_set_move_target(goblin, decision.target_x, decision.target_y)

	var gs: Dictionary = goblin_states[goblin]
	# Commit to the dribble - longer cooldown means visible ball-carrying runs
	gs["cooldown"] = 0.5

	var is_home: bool = _gb(gs, "is_home")
	var opp_formation: Formation = away_formation if is_home else home_formation
	for opp in opp_formation.get_all():
		if not goblin_states.has(opp):
			continue
		var opp_gs: Dictionary = goblin_states[opp]
		if _gf(opp_gs, "cooldown") > 0.0:
			continue
		if _dist(_gf(gs, "x"), _gf(gs, "y"), _gf(opp_gs, "x"), _gf(opp_gs, "y")) < TACKLE_RANGE:
			var dribble_stat: float = goblin.get_stat("speed") + goblin.get_stat("chaos") * 0.5
			var defend_stat: float = opp.get_stat("defense") + opp.get_stat("strength") * 0.5
			var result: float = _stat_contest(dribble_stat, defend_stat, float(goblin.get_stat("chaos")), float(opp.get_stat("chaos")))
			if result < 0:
				ball.set_loose(_gf(gs, "x"), _gf(gs, "y"))
				_tick_events.append({"type": "dispossessed", "goblin": goblin.goblin_name, "by": opp.goblin_name})
				opp_gs["cooldown"] = 0.3
			else:
				opp_gs["cooldown"] = 0.5
			break

func _execute_tackle(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	var gs: Dictionary = goblin_states[goblin]
	_set_move_target(goblin, decision.target_x, decision.target_y)

	if ball.owner == null or ball.owner == goblin:
		return
	if not goblin_states.has(ball.owner):
		return
	var owner_gs: Dictionary = goblin_states[ball.owner]
	if _dist(_gf(gs, "x"), _gf(gs, "y"), _gf(owner_gs, "x"), _gf(owner_gs, "y")) > TACKLE_RANGE:
		return

	var victim: GoblinData = ball.owner
	var tackle_stat: float = goblin.get_stat("defense") + goblin.get_stat("strength") * 0.5
	var keep_stat: float = victim.get_stat("speed") + victim.get_stat("strength") * 0.5
	var result: float = _stat_contest(tackle_stat, keep_stat, float(goblin.get_stat("chaos")), float(victim.get_stat("chaos")))

	gs["cooldown"] = 0.5
	var victim_gs: Dictionary = goblin_states[victim]
	victim_gs["cooldown"] = 0.5

	if result > 0:
		_tick_events.append({"type": "tackle", "goblin": goblin.goblin_name, "victim": victim.goblin_name})
		ball.set_loose(_gf(owner_gs, "x"), _gf(owner_gs, "y"))
		var foul_chance: float = goblin.get_stat("chaos") * 0.02 + (0.1 if goblin.position == "enforcer" else 0.0)
		if randf() < foul_chance:
			_tick_events.append({"type": "foul", "goblin": goblin.goblin_name, "victim": victim.goblin_name})
			ball.set_loose(_gf(owner_gs, "x"), _gf(owner_gs, "y"))
	else:
		# Failed tackle - tackler is beaten, ball carrier keeps going
		_tick_events.append({"type": "tackle_failed", "goblin": goblin.goblin_name})
		gs["cooldown"] = 0.75

# ── Off-Ball Movement ──────────────────────────────────────────────────────

func _set_offball_movement() -> void:
	## Zone-rect based positioning. Each goblin finds the best spot within
	## their position's roaming rectangle based on game phase.

	# Determine possession
	var home_has_ball: bool = false
	var away_has_ball: bool = false
	if ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		if _gb(owner_gs, "is_home"):
			home_has_ball = true
		else:
			away_has_ball = true

	# Pre-compute loose ball chasers: nearest 2 per team (not keepers)
	var _loose_ball_chasers: Dictionary = {}  # goblin -> true
	var is_loose: bool = ball.state == Ball.BallState.LOOSE or ball.state == Ball.BallState.DEAD
	if is_loose:
		var home_dists: Array = []
		var away_dists: Array = []
		for goblin in goblin_states:
			if goblin.position == "keeper":
				continue
			var gs2: Dictionary = goblin_states[goblin]
			var d: float = _dist(_gf(gs2, "x"), _gf(gs2, "y"), ball.x, ball.y)
			if _gb(gs2, "is_home"):
				home_dists.append({"goblin": goblin, "dist": d})
			else:
				away_dists.append({"goblin": goblin, "dist": d})
		home_dists.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
		away_dists.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
		for i in mini(2, home_dists.size()):
			if float(home_dists[i]["dist"]) < LOOSE_BALL_CHASE_RANGE:
				_loose_ball_chasers[home_dists[i]["goblin"]] = true
		for i in mini(2, away_dists.size()):
			if float(away_dists[i]["dist"]) < LOOSE_BALL_CHASE_RANGE:
				_loose_ball_chasers[away_dists[i]["goblin"]] = true

	for goblin in goblin_states:
		if _move_targets.has(goblin):
			continue

		var gs: Dictionary = goblin_states[goblin]

		# Skip goblins on cooldown - they're committed to their last action
		if _gf(gs, "cooldown") > 0.0:
			continue

		var is_home: bool = _gb(gs, "is_home")
		var home_y: float = _gf(gs, "home_y")
		var my_team_has_ball: bool = (home_has_ball and is_home) or (away_has_ball and not is_home)
		var is_left_flank: bool = home_y < 0.5

		# Loose ball: only designated chasers pursue
		if is_loose and _loose_ball_chasers.has(goblin):
			_set_move_target(goblin, ball.x, ball.y)
			continue

		# Get zone rect for this position and game phase
		var in_poss: bool = my_team_has_ball and not is_loose
		var rect: Array = PositionDatabase.get_zone_rect_flipped(
			goblin.position, in_poss, is_home, is_left_flank)
		var rx_min: float = rect[0]
		var rx_max: float = rect[1]
		var ry_min: float = rect[2]
		var ry_max: float = rect[3]

		var tx: float
		var ty: float

		if in_poss:
			tx = _offball_in_possession(gs, goblin, rx_min, rx_max, ry_min, ry_max, is_home)
			ty = _offball_y_in_possession(gs, goblin, ry_min, ry_max)
		else:
			tx = _offball_out_possession(gs, goblin, rx_min, rx_max, is_home)
			ty = _offball_y_out_possession(gs, goblin, ry_min, ry_max)

		_set_move_target(goblin, tx, ty)

func _offball_in_possession(gs: Dictionary, goblin: GoblinData, rx_min: float, rx_max: float, ry_min: float, ry_max: float, is_home: bool) -> float:
	## X target when team has ball. Attackers push forward, defenders hold.
	var zone: String = _get_goblin_zone(goblin)
	var goal_x: float = 1.0 if is_home else 0.0
	var dist_to_carrier: float = 999.0
	if ball.owner and goblin_states.has(ball.owner):
		var ogs: Dictionary = goblin_states[ball.owner]
		dist_to_carrier = _dist(_gf(gs, "x"), _gf(gs, "y"), _gf(ogs, "x"), _gf(ogs, "y"))

	match zone:
		"attack":
			# Push to forward edge of zone - make runs
			return lerpf(rx_min, rx_max, 0.75)
		"midfield":
			# Support play - bias forward but stay available
			if dist_to_carrier < 0.25:
				# Near ball: offer passing angle
				return lerpf(rx_min, rx_max, 0.6)
			return lerpf(rx_min, rx_max, 0.5)
		"defense":
			# Push up but stay in defensive half of zone
			return lerpf(rx_min, rx_max, 0.45)
		"goal":
			return rx_min + 0.02
		_:
			return lerpf(rx_min, rx_max, 0.5)

func _offball_y_in_possession(gs: Dictionary, goblin: GoblinData, ry_min: float, ry_max: float) -> float:
	## Y target when team has ball. Create width, find space.
	var home_y: float = _gf(gs, "home_y")
	# Bias toward the edge of zone that matches home flank (create width)
	if home_y < 0.5:
		return lerpf(ry_min, ry_max, 0.2)  # hug near-side
	elif home_y > 0.5:
		return lerpf(ry_min, ry_max, 0.8)  # hug far-side
	else:
		# Central players: drift slightly toward ball side
		var ball_bias: float = lerpf(0.5, (ball.y - ry_min) / maxf(ry_max - ry_min, 0.01), 0.3)
		return lerpf(ry_min, ry_max, clampf(ball_bias, 0.3, 0.7))

func _offball_out_possession(gs: Dictionary, goblin: GoblinData, rx_min: float, rx_max: float, is_home: bool) -> float:
	## X target when opponent has ball. Get goal-side of the ball.
	var own_goal_x: float = 0.0 if is_home else 1.0

	# Position between ball and own goal - defenders drop deep, midfielders track
	var ideal_x: float = lerpf(ball.x, own_goal_x, 0.4)
	return clampf(ideal_x, rx_min, rx_max)

func _offball_y_out_possession(gs: Dictionary, goblin: GoblinData, ry_min: float, ry_max: float) -> float:
	## Y target when opponent has ball. Compact toward ball side more aggressively.
	var home_y: float = _gf(gs, "home_y")
	# Stronger shift toward ball y to cut passing lanes
	var ideal_y: float = lerpf(home_y, ball.y, 0.35)
	return clampf(ideal_y, ry_min, ry_max)

func _get_goblin_zone(goblin: GoblinData) -> String:
	var formation: Formation = home_formation if goblin_states.has(goblin) and _gb(goblin_states[goblin], "is_home") else away_formation
	return formation.find_zone(goblin)

# ── Movement ────────────────────────────────────────────────────────────────

var _move_targets: Dictionary = {}

func _set_move_target(goblin: GoblinData, tx: float, ty: float) -> void:
	_move_targets[goblin] = {"x": clampf(tx, 0.02, 0.98), "y": clampf(ty, 0.05, 0.95)}

const SEPARATION_DIST: float = 0.05  # min distance between same-team goblins
const SEPARATION_FORCE: float = 0.02  # push strength per tick

func _move_goblins() -> void:
	# Apply movement toward targets
	for goblin in goblin_states:
		if not _move_targets.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var target: Dictionary = _move_targets[goblin]
		var spd: float = float(goblin.get_stat("speed"))
		var move_amount: float = MOVEMENT_SPEED * (spd / 5.0)

		var dx: float = _gf(target, "x") - _gf(gs, "x")
		var dy: float = _gf(target, "y") - _gf(gs, "y")
		var dist: float = sqrt(dx * dx + dy * dy)

		# Settle threshold: don't move if already close enough
		if dist < 0.03:
			continue

		if dist <= move_amount:
			gs["x"] = _gf(target, "x")
			gs["y"] = _gf(target, "y")
		else:
			var ratio: float = move_amount / dist
			gs["x"] = _gf(gs, "x") + dx * ratio
			gs["y"] = _gf(gs, "y") + dy * ratio

		# Update facing
		if abs(dx) > 0.001:
			gs["facing"] = 1.0 if dx > 0 else -1.0

	_move_targets.clear()

	# Separation: push apart same-team goblins that are too close
	var all_goblins: Array = goblin_states.keys()
	for i in all_goblins.size():
		for j in range(i + 1, all_goblins.size()):
			var ga: GoblinData = all_goblins[i]
			var gb: GoblinData = all_goblins[j]
			var gsa: Dictionary = goblin_states[ga]
			var gsb: Dictionary = goblin_states[gb]

			# Only separate same-team goblins
			if _gb(gsa, "is_home") != _gb(gsb, "is_home"):
				continue

			var dx: float = _gf(gsa, "x") - _gf(gsb, "x")
			var dy: float = _gf(gsa, "y") - _gf(gsb, "y")
			var dist: float = sqrt(dx * dx + dy * dy)

			if dist < SEPARATION_DIST and dist > 0.001:
				var overlap: float = SEPARATION_DIST - dist
				var push: float = overlap * SEPARATION_FORCE / dist
				gsa["x"] = clampf(_gf(gsa, "x") + dx * push, 0.02, 0.98)
				gsa["y"] = clampf(_gf(gsa, "y") + dy * push, 0.05, 0.95)
				gsb["x"] = clampf(_gf(gsb, "x") - dx * push, 0.02, 0.98)
				gsb["y"] = clampf(_gf(gsb, "y") - dy * push, 0.05, 0.95)

# ── Kickoff Reset ───────────────────────────────────────────────────────────

func _reset_positions_for_kickoff(kicking_team_idx: int) -> void:
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		gs["x"] = lerpf(_gf(gs, "x"), _gf(gs, "home_x"), 0.7)
		gs["y"] = lerpf(_gf(gs, "y"), _gf(gs, "home_y"), 0.7)
		gs["readiness"] = randf_range(0.0, 5.0)
		gs["cooldown"] = 0.5

	var formation: Formation = home_formation if kicking_team_idx == 0 else away_formation
	var mids := formation.midfield
	if not mids.is_empty():
		var kicker: GoblinData = mids[0]
		ball.set_controlled(kicker, 0.5, 0.5)
		var kgs: Dictionary = goblin_states[kicker]
		kgs["x"] = 0.5
		kgs["y"] = 0.5

# ── AI Context Builder ─────────────────────────────────────────────────────

func _build_ai_context(goblin: GoblinData) -> GoblinAI.Context:
	var gs: Dictionary = goblin_states[goblin]
	var ctx := GoblinAI.Context.new()
	ctx.goblin = goblin
	ctx.goblin_x = _gf(gs, "x")
	ctx.goblin_y = _gf(gs, "y")
	ctx.ball_x = ball.x
	ctx.ball_y = ball.y
	ctx.ball_state = ball.state
	ctx.ball_owner = ball.owner
	ctx.is_home = _gb(gs, "is_home")
	ctx.home_x = _gf(gs, "home_x")
	ctx.home_y = _gf(gs, "home_y")

	# Determine if my team has the ball
	if ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		ctx.team_has_ball = _gb(owner_gs, "is_home") == _gb(gs, "is_home")
	else:
		ctx.team_has_ball = false

	# Build teammate/opponent lists
	ctx.teammates = []
	ctx.opponents = []
	var is_home: bool = _gb(gs, "is_home")
	var my_formation: Formation = home_formation if is_home else away_formation
	var opp_formation: Formation = away_formation if is_home else home_formation

	for t in my_formation.get_all():
		if goblin_states.has(t):
			var tgs: Dictionary = goblin_states[t]
			ctx.teammates.append({"goblin": t, "x": _gf(tgs, "x"), "y": _gf(tgs, "y")})
	for o in opp_formation.get_all():
		if goblin_states.has(o):
			var ogs: Dictionary = goblin_states[o]
			ctx.opponents.append({"goblin": o, "x": _gf(ogs, "x"), "y": _gf(ogs, "y")})

	# Opponent keeper position
	var opp_keeper: GoblinData = opp_formation.get_keeper()
	if opp_keeper and goblin_states.has(opp_keeper):
		var kgs: Dictionary = goblin_states[opp_keeper]
		ctx.keeper_x = _gf(kgs, "x")
		ctx.keeper_y = _gf(kgs, "y")
	else:
		ctx.keeper_x = 0.95 if is_home else 0.05
		ctx.keeper_y = 0.5

	return ctx

# ── Stat Contest ────────────────────────────────────────────────────────────

func _stat_contest(attacker_stat: float, defender_stat: float, atk_chaos: float, def_chaos: float) -> float:
	var base: float = (attacker_stat - defender_stat) / 10.0
	var chaos_range: float = (atk_chaos + def_chaos) * 0.03
	return base + randf_range(-chaos_range, chaos_range)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _dist(x1: float, y1: float, x2: float, y2: float) -> float:
	return sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)

func _find_nearest_goblin_to(px: float, py: float, max_dist: float) -> GoblinData:
	var best: GoblinData = null
	var best_dist: float = max_dist
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		var d: float = _dist(_gf(gs, "x"), _gf(gs, "y"), px, py)
		if d < best_dist:
			best_dist = d
			best = goblin
	return best

func _get_all_goblins_sorted_by_readiness() -> Array:
	var all: Array = goblin_states.keys()
	all.sort_custom(func(a, b):
		return _gf(goblin_states[a], "readiness") > _gf(goblin_states[b], "readiness")
	)
	return all

func is_match_over() -> bool:
	return match_over

func get_debug_summary() -> String:
	var lines: Array[String] = []
	lines.append("Ticks: %d" % _debug_ticks)
	lines.append("Actions taken:")
	var sorted_actions := _debug_actions.keys()
	sorted_actions.sort()
	for key in sorted_actions:
		lines.append("  %s: %d" % [key, _debug_actions[key]])
	return "\n".join(lines)

# ── Snapshot ────────────────────────────────────────────────────────────────

func _build_snapshot() -> Dictionary:
	var goblins_arr: Array = []
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		goblins_arr.append({
			"name": goblin.goblin_name,
			"position": goblin.position,
			"x": _gf(gs, "x"),
			"y": _gf(gs, "y"),
			"action": gs["action"],
			"facing": _gf(gs, "facing"),
			"team": "home" if _gb(gs, "is_home") else "away",
			"has_ball": ball.owner == goblin,
		})

	return {
		"ball": ball.to_dict(),
		"goblins": goblins_arr,
		"score": score.duplicate(),
		"clock": clock,
		"events": _tick_events.duplicate(),
		"match_over": match_over,
		"spells_locked": spells_locked,
	}
