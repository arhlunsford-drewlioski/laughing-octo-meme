class_name GoblinAI
extends RefCounted
## Per-goblin decision making for match simulation.
## Given context, returns an action + target for one goblin's tick.

enum Action {
	IDLE,
	MOVE_TO_POSITION,
	CHASE_BALL,
	PASS,
	SHOOT,
	DRIBBLE,
	TACKLE,
	INTERCEPT,
	CROSS,
	CLEAR,
	HOLD_UP,
}

## Result of a decision: what to do and where/who
class Decision:
	var action: Action = Action.IDLE
	var target_x: float = 0.5
	var target_y: float = 0.5
	var target_goblin: GoblinData = null

	func _init(a: Action = Action.IDLE, tx: float = 0.5, ty: float = 0.5, tg: GoblinData = null) -> void:
		action = a
		target_x = tx
		target_y = ty
		target_goblin = tg

## Context passed into decide()
class Context:
	var goblin: GoblinData
	var goblin_x: float
	var goblin_y: float
	var ball_x: float
	var ball_y: float
	var ball_state: Ball.BallState
	var ball_owner: GoblinData
	var team_has_ball: bool
	var is_home: bool
	var home_x: float
	var home_y: float
	var teammates: Array  # of {goblin: GoblinData, x: float, y: float}
	var opponents: Array
	var keeper_x: float
	var keeper_y: float
	var ball_control_time: float = 0.0
	var settle_time: float = 0.0
	var role: int = TeamCoordinator.Role.HOLDER  # assigned by TeamCoordinator

# ── Dict helpers (teammate/opponent entries are Dictionaries) ───────────────

static func _df(d: Dictionary, key: String) -> float:
	return float(d[key])

static func _dg(d: Dictionary) -> GoblinData:
	return d["goblin"] as GoblinData

static func _sf(goblin: GoblinData, stat_name: String) -> float:
	return float(goblin.get_stat(stat_name))

static func _is_pos(goblin: GoblinData, positions: Array) -> bool:
	return positions.has(goblin.position)

static func _shooting_bias(ctx: Context) -> float:
	var bias: float = _sf(ctx.goblin, "shooting") * 0.18 + _sf(ctx.goblin, "strength") * 0.04 + _sf(ctx.goblin, "chaos") * 0.03
	if _is_pos(ctx.goblin, ["striker", "poacher", "shadow_striker"]):
		bias += 0.90
	elif _is_pos(ctx.goblin, ["attacking_mid", "trequartista"]):
		bias += 0.60
	elif _is_pos(ctx.goblin, ["winger", "playmaker"]):
		bias += 0.20
	elif _is_pos(ctx.goblin, ["anchor", "sweeper", "enforcer", "wing_back"]):
		bias -= 0.55
	return bias

static func _dribble_bias(ctx: Context) -> float:
	var bias: float = _sf(ctx.goblin, "speed") * 0.16 + _sf(ctx.goblin, "chaos") * 0.10
	if _is_pos(ctx.goblin, ["winger", "shadow_striker", "trequartista", "striker"]):
		bias += 0.75
	elif _is_pos(ctx.goblin, ["playmaker", "attacking_mid", "wing_back"]):
		bias += 0.35
	elif _is_pos(ctx.goblin, ["target_man", "anchor", "sweeper", "enforcer"]):
		bias -= 0.45
	return bias

static func _hold_up_bias(ctx: Context) -> float:
	var bias: float = _sf(ctx.goblin, "strength") * 0.16 + _sf(ctx.goblin, "defense") * 0.05
	if _is_pos(ctx.goblin, ["target_man", "false_nine"]):
		bias += 0.90
	elif _is_pos(ctx.goblin, ["poacher", "shadow_striker"]):
		bias -= 0.20
	return bias

static func _pass_risk_bias(ctx: Context) -> float:
	var bias: float = _sf(ctx.goblin, "chaos") * 0.14 + _sf(ctx.goblin, "shooting") * 0.04
	if _is_pos(ctx.goblin, ["playmaker", "trequartista", "false_nine", "attacking_mid"]):
		bias += 0.70
	elif _is_pos(ctx.goblin, ["anchor", "sweeper", "enforcer"]):
		bias -= 0.45
	return bias

# ── Main Decision Entry ─────────────────────────────────────────────────────

static func decide(ctx: Context) -> Decision:
	var pos_data := PositionDatabase.get_position(ctx.goblin.position)
	if pos_data.is_empty():
		return Decision.new(Action.IDLE)

	var dist_to_ball: float = _dist(ctx.goblin_x, ctx.goblin_y, ctx.ball_x, ctx.ball_y)

	# Keeper always stays in goal unless ball is very close
	if ctx.goblin.position == "keeper":
		return _decide_keeper(ctx, dist_to_ball)

	# I have the ball
	if ctx.ball_owner == ctx.goblin:
		return _decide_with_ball(ctx, pos_data)

	# ── Role-driven decisions (anti-swarm) ──────────────────────────────
	var role: int = ctx.role

	# Loose ball: designated LOOSE_CHASER always pursues.
	# Others only chase if very close (within claim range) to prevent ball sitting.
	var is_loose: bool = ctx.ball_state == Ball.BallState.LOOSE or ctx.ball_state == Ball.BallState.DEAD
	if is_loose:
		if role == TeamCoordinator.Role.LOOSE_CHASER:
			return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)
		if dist_to_ball < 0.20:
			return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)

	# Presser: close down the ball carrier aggressively
	if role == TeamCoordinator.Role.PRESSER:
		return _decide_presser(ctx, dist_to_ball)

	# Cover presser: position behind the presser to cut off escape
	if role == TeamCoordinator.Role.COVER_PRESSER:
		return _decide_cover_presser(ctx)

	# Marker: track a nearby opponent
	if role == TeamCoordinator.Role.MARKER:
		return _decide_marker(ctx)

	# My team has the ball - hold shape (off-ball movement handles positioning)
	if ctx.team_has_ball:
		return _decide_own_team_ball(ctx, pos_data)

	# Holder when opponent has ball: stay in zone, cut passing lanes
	return _decide_holder_defending(ctx)

# ── Keeper Logic ────────────────────────────────────────────────────────────

static func _decide_keeper(ctx: Context, dist_to_ball: float) -> Decision:
	if ctx.ball_owner == ctx.goblin:
		# Distribute to nearest non-attacker (build from back)
		var best: Dictionary = {}
		var best_dist: float = 999.0
		for t in ctx.teammates:
			if _dg(t) == ctx.goblin:
				continue
			# Skip attackers - force buildup through defense/midfield
			var tpos: String = _dg(t).position
			var tzone: String = PositionDatabase.get_zone(tpos)
			if tzone == "attack":
				continue
			var d: float = _dist(ctx.goblin_x, ctx.goblin_y, _df(t, "x"), _df(t, "y"))
			if d < best_dist:
				best_dist = d
				best = t
		if best.is_empty():
			best = _find_nearest_teammate(ctx)
		if not best.is_empty():
			return Decision.new(Action.PASS, _df(best, "x"), _df(best, "y"), _dg(best))
		return Decision.new(Action.CLEAR, ctx.home_x + (0.3 if ctx.is_home else -0.3), 0.5)

	if dist_to_ball < 0.06 and not ctx.team_has_ball:
		return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)

	var target_y: float = clampf(ctx.ball_y, 0.3, 0.7)
	return Decision.new(Action.MOVE_TO_POSITION, ctx.home_x, target_y)

# ── With Ball ───────────────────────────────────────────────────────────────

static func _decide_with_ball(ctx: Context, _pos_data: Dictionary) -> Decision:
	## Zone-based decisions: what to do depends on WHERE you are on the pitch.
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	var dist_to_goal: float = absf(ctx.goblin_x - goal_x)
	var fwd_dir: float = 1.0 if ctx.is_home else -1.0
	var shooting_bias: float = _shooting_bias(ctx)
	var dribble_bias: float = _dribble_bias(ctx)
	var hold_up_bias: float = _hold_up_bias(ctx)
	var pass_risk_bias: float = _pass_risk_bias(ctx)

	# How much pressure? Count opponents nearby
	var nearest_opp_dist: float = 999.0
	for opp in ctx.opponents:
		var d: float = _dist(ctx.goblin_x, ctx.goblin_y, _df(opp, "x"), _df(opp, "y"))
		if d < nearest_opp_dist:
			nearest_opp_dist = d
	var under_heavy_pressure: bool = nearest_opp_dist < 0.12
	var under_pressure: bool = nearest_opp_dist < 0.18
	var still_settling: bool = ctx.ball_control_time < ctx.settle_time

	var snap_shot_range: float = 0.20 + _sf(ctx.goblin, "shooting") * 0.013
	var shot_window: float = 0.30 + _sf(ctx.goblin, "shooting") * 0.010
	var shoot_chance: float = clampf(0.14 + shooting_bias * 0.07 - dist_to_goal * 0.45, 0.05, 0.92)

	# Very close to goal? Most attackers should pull the trigger.
	if dist_to_goal < snap_shot_range:
		if not under_heavy_pressure or shoot_chance > 0.34 or hold_up_bias < 1.2:
			return Decision.new(Action.SHOOT, goal_x, randf_range(0.35, 0.65))
	# Edge of the box and central? Better shooters look for the finish.
	elif dist_to_goal < shot_window and absf(ctx.goblin_y - 0.5) < 0.22:
		var pressure_penalty: float = 0.18 if under_heavy_pressure else (0.08 if under_pressure else 0.0)
		if randf() < clampf(shoot_chance - pressure_penalty, 0.04, 0.85):
			return Decision.new(Action.SHOOT, goal_x, randf_range(0.35, 0.65))

	# Wide position? Cross into the box.
	var is_wide: bool = absf(ctx.goblin_y - 0.5) > 0.25
	var cross_chance: float = clampf(0.15 + _sf(ctx.goblin, "speed") * 0.04 + _sf(ctx.goblin, "chaos") * 0.03, 0.08, 0.82)
	if _is_pos(ctx.goblin, ["winger", "wing_back"]):
		cross_chance += 0.18
	if is_wide and dist_to_goal < 0.40 and not still_settling and randf() < cross_chance:
		return Decision.new(Action.CROSS, goal_x - (0.08 if ctx.is_home else -0.08), randf_range(0.35, 0.65))

	# Under heavy pressure - must release the ball
	if under_heavy_pressure:
		if hold_up_bias > 1.7 and nearest_opp_dist > 0.07:
			var layoff: Dictionary = _find_best_pass(ctx)
			if not layoff.is_empty():
				return Decision.new(Action.HOLD_UP, _df(layoff, "x"), _df(layoff, "y"), _dg(layoff))
		# Try forward pass first
		var fwd: Dictionary = _find_forward_teammate(ctx)
		if not fwd.is_empty():
			return Decision.new(Action.PASS, _df(fwd, "x"), _df(fwd, "y"), _dg(fwd))
		# Then best pass
		var t: Dictionary = _find_best_pass(ctx)
		if not t.is_empty():
			return Decision.new(Action.PASS, _df(t, "x"), _df(t, "y"), _dg(t))
		# Desperate: dribble away
		var dribble_target: Vector2 = _smart_dribble_target(ctx)
		return Decision.new(Action.DRIBBLE, dribble_target.x, dribble_target.y)

	# Space ahead? Dribble forward (even under moderate pressure)
	var space_ahead: bool = true
	for opp in ctx.opponents:
		var ox: float = _df(opp, "x")
		var oy: float = _df(opp, "y")
		var ahead: bool = (fwd_dir > 0 and ox > ctx.goblin_x) or (fwd_dir < 0 and ox < ctx.goblin_x)
		if ahead and _dist(ctx.goblin_x, ctx.goblin_y, ox, oy) < 0.18:
			space_ahead = false
			break

	var dribble_chance: float = clampf(0.12 + dribble_bias * 0.07 - (0.12 if under_pressure else 0.0), 0.04, 0.90)
	if still_settling and not under_heavy_pressure:
		dribble_chance = clampf(dribble_chance + 0.30 + _sf(ctx.goblin, "strength") * 0.02, 0.20, 0.95)
	if space_ahead and dist_to_goal > 0.35 and randf() < dribble_chance:
		var dribble_target: Vector2 = _smart_dribble_target(ctx)
		return Decision.new(Action.DRIBBLE, dribble_target.x, dribble_target.y)

	if still_settling and hold_up_bias > 1.4 and not under_heavy_pressure:
		var settle_target: Vector2 = _smart_dribble_target(ctx)
		return Decision.new(Action.DRIBBLE, settle_target.x, settle_target.y)

	# Under moderate pressure with no space ahead - pass forward
	if under_pressure and not still_settling:
		var fwd: Dictionary = _find_forward_teammate(ctx)
		if not fwd.is_empty():
			return Decision.new(Action.PASS, _df(fwd, "x"), _df(fwd, "y"), _dg(fwd))
		var best: Dictionary = _find_best_pass(ctx)
		if not best.is_empty():
			return Decision.new(Action.PASS, _df(best, "x"), _df(best, "y"), _dg(best))

	# In defensive third? Pass forward or dribble out.
	var in_own_third: bool = (ctx.is_home and ctx.goblin_x < 0.35) or (not ctx.is_home and ctx.goblin_x > 0.65)
	if in_own_third:
		if pass_risk_bias < 0.4 and not still_settling:
			var safe: Dictionary = _find_best_pass(ctx)
			if not safe.is_empty():
				return Decision.new(Action.PASS, _df(safe, "x"), _df(safe, "y"), _dg(safe))
		var fwd_target: Dictionary = _find_forward_teammate(ctx)
		if not fwd_target.is_empty():
			return Decision.new(Action.PASS, _df(fwd_target, "x"), _df(fwd_target, "y"), _dg(fwd_target))
		var dribble_out: Vector2 = _smart_dribble_target(ctx)
		return Decision.new(Action.DRIBBLE, dribble_out.x, dribble_out.y)

	if pass_risk_bias > 1.3 and not under_pressure and not still_settling:
		var killer_ball: Dictionary = _find_forward_teammate(ctx)
		if not killer_ball.is_empty():
			return Decision.new(Action.PASS, _df(killer_ball, "x"), _df(killer_ball, "y"), _dg(killer_ball))

	if _is_pos(ctx.goblin, ["playmaker", "attacking_mid", "false_nine"]) and not under_heavy_pressure and not still_settling:
		var best: Dictionary = _find_best_pass(ctx)
		if not best.is_empty():
			return Decision.new(Action.PASS, _df(best, "x"), _df(best, "y"), _dg(best))

	# Fallback: dribble forward
	var dribble_target: Vector2 = _smart_dribble_target(ctx)
	return Decision.new(Action.DRIBBLE, dribble_target.x, dribble_target.y)

# ── Own Team Has Ball ───────────────────────────────────────────────────────

static func _decide_own_team_ball(ctx: Context, _pos_data: Dictionary) -> Decision:
	## Off-ball movement is handled by _set_offball_movement() in the simulation.
	## AI only needs to return IDLE here - the zone rect system positions them.
	return Decision.new(Action.IDLE)

# ── Role-Based Defending ───────────────────────────────────────────────────

static func _decide_presser(ctx: Context, dist_to_ball: float) -> Decision:
	## The ONE goblin closing down the ball carrier. Tackles when close.
	var tackle_window: float = 0.042 + _sf(ctx.goblin, "defense") * 0.002 + _sf(ctx.goblin, "strength") * 0.001
	if dist_to_ball < tackle_window:
		return Decision.new(Action.TACKLE, ctx.ball_x, ctx.ball_y)
	var close_down_range: float = 0.15 + _sf(ctx.goblin, "speed") * 0.010 + _sf(ctx.goblin, "defense") * 0.008
	if dist_to_ball > close_down_range:
		var screen_x: float = lerpf(ctx.goblin_x, ctx.ball_x, 0.72)
		var screen_y: float = lerpf(ctx.goblin_y, ctx.ball_y, 0.72)
		return Decision.new(Action.MOVE_TO_POSITION, screen_x, screen_y)
	return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)

static func _decide_cover_presser(ctx: Context) -> Decision:
	## Positions behind the presser to cut off escape routes.
	## Sits between ball and own goal, slightly offset.
	var own_goal_x: float = 0.0 if ctx.is_home else 1.0
	# Position halfway between ball and own goal, shifted toward ball's y
	var cover_x: float = lerpf(ctx.ball_x, own_goal_x, 0.3)
	var cover_y: float = lerpf(ctx.ball_y, 0.5, 0.3)
	# If close enough, tackle
	var dist_to_ball: float = _dist(ctx.goblin_x, ctx.goblin_y, ctx.ball_x, ctx.ball_y)
	if dist_to_ball < 0.06:
		return Decision.new(Action.TACKLE, ctx.ball_x, ctx.ball_y)
	return Decision.new(Action.MOVE_TO_POSITION, cover_x, cover_y)

static func _decide_marker(ctx: Context) -> Decision:
	## Marks nearest opponent - stays goal-side but tracks actively.
	var own_goal_x: float = 0.0 if ctx.is_home else 1.0
	var dist_to_ball: float = _dist(ctx.goblin_x, ctx.goblin_y, ctx.ball_x, ctx.ball_y)
	var tackle_window: float = 0.040 + _sf(ctx.goblin, "defense") * 0.002 + _sf(ctx.goblin, "strength") * 0.001

	# Tackle if ball is close
	if dist_to_ball < tackle_window:
		return Decision.new(Action.TACKLE, ctx.ball_x, ctx.ball_y)

	var nearest_opp: Dictionary = {}
	var nearest_d: float = 999.0
	for opp in ctx.opponents:
		if _dg(opp) == ctx.ball_owner:
			continue
		var d: float = _dist(ctx.goblin_x, ctx.goblin_y, _df(opp, "x"), _df(opp, "y"))
		if d < nearest_d:
			nearest_d = d
			nearest_opp = opp

	if not nearest_opp.is_empty():
		var goal_side_bias: float = clampf(0.30 - _sf(ctx.goblin, "defense") * 0.015 - _sf(ctx.goblin, "speed") * 0.008, 0.10, 0.24)
		var mark_x: float = lerpf(_df(nearest_opp, "x"), own_goal_x, goal_side_bias)
		var mark_y: float = _df(nearest_opp, "y")
		if _sf(ctx.goblin, "defense") >= 7.0:
			mark_y = lerpf(mark_y, ctx.ball_y, 0.15)
		return Decision.new(Action.MOVE_TO_POSITION, mark_x, mark_y)

	# No opponent to mark - cut passing lane
	var cut_x: float = lerpf(ctx.ball_x, own_goal_x, 0.3)
	var cut_y: float = lerpf(ctx.ball_y, ctx.home_y, 0.5)
	return Decision.new(Action.MOVE_TO_POSITION, cut_x, cut_y)

static func _decide_holder_defending(ctx: Context) -> Decision:
	## Futsal defending: active but not swarming. Close down when ball
	## enters your area, otherwise cut passing lanes.
	var own_goal_x: float = 0.0 if ctx.is_home else 1.0
	var dist_to_ball: float = _dist(ctx.goblin_x, ctx.goblin_y, ctx.ball_x, ctx.ball_y)
	var tackle_window: float = 0.040 + _sf(ctx.goblin, "defense") * 0.002 + _sf(ctx.goblin, "strength") * 0.001

	# Tackle if close
	if dist_to_ball < tackle_window:
		return Decision.new(Action.TACKLE, ctx.ball_x, ctx.ball_y)

	# Close down if ball is nearby (futsal = pressing everywhere)
	var close_down_range: float = 0.12 + _sf(ctx.goblin, "defense") * 0.012 + _sf(ctx.goblin, "speed") * 0.007
	if dist_to_ball < close_down_range:
		# Move toward ball but stop short - don't dive in
		var press_ratio: float = clampf(0.24 + _sf(ctx.goblin, "defense") * 0.022 + _sf(ctx.goblin, "strength") * 0.010, 0.25, 0.56)
		var press_x: float = lerpf(ctx.goblin_x, ctx.ball_x, press_ratio)
		var press_y: float = lerpf(ctx.goblin_y, ctx.ball_y, press_ratio)
		return Decision.new(Action.MOVE_TO_POSITION, press_x, press_y)

	# Further away: position between ball and own goal
	var cut_x: float = lerpf(ctx.ball_x, own_goal_x, 0.35)
	var cut_y: float = lerpf(ctx.ball_y, ctx.home_y, 0.5)
	return Decision.new(Action.MOVE_TO_POSITION, cut_x, cut_y)

# ── Helpers ─────────────────────────────────────────────────────────────────

static func _smart_dribble_target(ctx: Context) -> Vector2:
	## Dribble toward goal but swerve around the nearest opponent.
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	var fwd_dir: float = 1.0 if ctx.is_home else -1.0
	var dribble_step: float = 0.10 + _sf(ctx.goblin, "speed") * 0.012 + _sf(ctx.goblin, "chaos") * 0.004
	if _is_pos(ctx.goblin, ["winger", "shadow_striker", "trequartista"]):
		dribble_step += 0.02
	elif _is_pos(ctx.goblin, ["target_man", "anchor", "sweeper"]):
		dribble_step -= 0.02
	var target_x: float = ctx.goblin_x + fwd_dir * dribble_step
	var target_y: float = ctx.goblin_y

	# Find closest opponent in front of us
	var nearest_opp_dist: float = 999.0
	var nearest_opp_y: float = ctx.goblin_y
	for opp in ctx.opponents:
		var ox: float = _df(opp, "x")
		var oy: float = _df(opp, "y")
		# Is this opponent roughly ahead of us?
		var ahead: bool = (fwd_dir > 0 and ox > ctx.goblin_x) or (fwd_dir < 0 and ox < ctx.goblin_x)
		if not ahead:
			continue
		var d: float = _dist(ctx.goblin_x, ctx.goblin_y, ox, oy)
		if d < nearest_opp_dist and d < 0.2:
			nearest_opp_dist = d
			nearest_opp_y = oy

	# If opponent is close ahead, swerve away from them
	if nearest_opp_dist < 0.2:
		if nearest_opp_y > ctx.goblin_y:
			target_y = ctx.goblin_y - (0.06 + _sf(ctx.goblin, "chaos") * 0.006)
		else:
			target_y = ctx.goblin_y + (0.06 + _sf(ctx.goblin, "chaos") * 0.006)

	target_y = clampf(target_y, 0.05, 0.95)
	target_x = clampf(target_x, 0.02, 0.98)
	return Vector2(target_x, target_y)

static func _dist(x1: float, y1: float, x2: float, y2: float) -> float:
	return sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)

## Returns empty Dictionary if none found
static func _find_nearest_teammate(ctx: Context) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = 999.0
	for t in ctx.teammates:
		if _dg(t) == ctx.goblin:
			continue
		var d: float = _dist(ctx.goblin_x, ctx.goblin_y, _df(t, "x"), _df(t, "y"))
		if d < best_dist:
			best_dist = d
			best = t
	return best

## Find best pass target considering forward, wide, and safe options
static func _find_best_pass(ctx: Context) -> Dictionary:
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	var best: Dictionary = {}
	var best_score: float = -999.0
	var pass_risk_bias: float = _pass_risk_bias(ctx)

	for t in ctx.teammates:
		var receiver: GoblinData = _dg(t)
		if receiver == ctx.goblin:
			continue
		var tx: float = _df(t, "x")
		var ty: float = _df(t, "y")
		var d: float = _dist(ctx.goblin_x, ctx.goblin_y, tx, ty)

		# Skip if too close (won't advance play) or too far (very risky)
		if d < 0.06 or d > 0.75:
			continue

		# Score components:
		# 1. Forward progress toward goal (heavily weighted)
		var forward: float = 0.0
		if ctx.is_home:
			forward = (tx - ctx.goblin_x) * 3.0
		else:
			forward = (ctx.goblin_x - tx) * 3.0
		# Penalize backward passes
		if forward < 0:
			forward *= 2.0  # double penalty for going backward

		# 2. Width bonus - reward passes that switch play or go wide
		var width_bonus: float = absf(ty - ctx.goblin_y) * 1.0

		# 3. Space - is the target away from opponents?
		var space: float = 0.0
		for opp in ctx.opponents:
			var opp_dist: float = _dist(tx, ty, _df(opp, "x"), _df(opp, "y"))
			if opp_dist < 0.15:
				space -= 0.5
			elif opp_dist > 0.2:
				space += 0.3

		# 4. Closeness to goal
		var goal_proximity: float = (1.0 - absf(tx - goal_x)) * 0.5

		var receiver_bonus: float = _sf(receiver, "speed") * 0.10 + _sf(receiver, "shooting") * 0.10 + _sf(receiver, "strength") * 0.06
		if _is_pos(receiver, ["striker", "poacher", "shadow_striker", "attacking_mid"]):
			receiver_bonus += goal_proximity * 0.9
		elif _is_pos(receiver, ["target_man", "false_nine"]):
			receiver_bonus += _sf(receiver, "strength") * 0.08
		elif _is_pos(receiver, ["winger", "wing_back"]):
			receiver_bonus += absf(ty - 0.5) * 0.5
		var distance_penalty: float = maxf(0.0, d - 0.36) * clampf(1.45 - pass_risk_bias * 0.16, 0.55, 1.45)
		var score: float = forward * (1.0 + pass_risk_bias * 0.10) + width_bonus + space + goal_proximity + receiver_bonus - distance_penalty
		if score > best_score:
			best_score = score
			best = t

	return best

## Returns empty Dictionary if none found
static func _find_forward_teammate(ctx: Context) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	var pass_risk_bias: float = _pass_risk_bias(ctx)
	for t in ctx.teammates:
		var receiver: GoblinData = _dg(t)
		if receiver == ctx.goblin:
			continue
		var tx: float = _df(t, "x")
		var ty: float = _df(t, "y")
		var forward_amount: float
		if ctx.is_home:
			forward_amount = tx - ctx.goblin_x
		else:
			forward_amount = ctx.goblin_x - tx
		if forward_amount <= 0.0:
			continue
		var closeness_to_goal: float = 1.0 - absf(tx - goal_x)
		var space_bonus: float = 0.0
		for opp in ctx.opponents:
			var opp_dist: float = _dist(tx, ty, _df(opp, "x"), _df(opp, "y"))
			if opp_dist < 0.12:
				space_bonus -= 0.5
			elif opp_dist > 0.18:
				space_bonus += 0.25
		var receiver_bonus: float = _sf(receiver, "speed") * 0.12 + _sf(receiver, "shooting") * 0.12 + _sf(receiver, "strength") * 0.05
		if _is_pos(receiver, ["striker", "poacher", "shadow_striker"]):
			receiver_bonus += 0.65
		elif _is_pos(receiver, ["winger", "wing_back"]):
			receiver_bonus += absf(ty - 0.5) * 0.45
		var risk_length_bonus: float = maxf(0.0, forward_amount - 0.18) * pass_risk_bias * 0.25
		var s: float = forward_amount * 0.65 + closeness_to_goal * 0.50 + receiver_bonus + space_bonus + risk_length_bonus
		if s > best_score:
			best_score = s
			best = t
	return best
