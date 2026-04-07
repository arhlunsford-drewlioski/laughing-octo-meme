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

# ── Dict helpers (teammate/opponent entries are Dictionaries) ───────────────

static func _df(d: Dictionary, key: String) -> float:
	return float(d[key])

static func _dg(d: Dictionary) -> GoblinData:
	return d["goblin"] as GoblinData

# ── Main Decision Entry ─────────────────────────────────────────────────────

static func decide(ctx: Context) -> Decision:
	var pos_data := PositionDatabase.get_position(ctx.goblin.position)
	if pos_data.is_empty():
		return Decision.new(Action.IDLE)

	var dist_to_ball: float = _dist(ctx.goblin_x, ctx.goblin_y, ctx.ball_x, ctx.ball_y)

	# Ball is loose/dead - chase it aggressively
	if ctx.ball_state == Ball.BallState.LOOSE or ctx.ball_state == Ball.BallState.DEAD:
		if dist_to_ball < 0.40:
			return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)

	# Keeper always stays in goal unless ball is very close
	if ctx.goblin.position == "keeper":
		return _decide_keeper(ctx, dist_to_ball)

	# I have the ball
	if ctx.ball_owner == ctx.goblin:
		return _decide_with_ball(ctx, pos_data)

	# My team has the ball
	if ctx.team_has_ball:
		return _decide_own_team_ball(ctx, pos_data)

	# Opponent has the ball
	return _decide_opponent_ball(ctx, pos_data, dist_to_ball)

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

	if dist_to_ball < 0.08 and not ctx.team_has_ball:
		return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)

	var target_y: float = clampf(ctx.ball_y, 0.3, 0.7)
	return Decision.new(Action.MOVE_TO_POSITION, ctx.home_x, target_y)

# ── With Ball ───────────────────────────────────────────────────────────────

static func _decide_with_ball(ctx: Context, _pos_data: Dictionary) -> Decision:
	## Zone-based decisions: what to do depends on WHERE you are on the pitch.
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	var dist_to_goal: float = absf(ctx.goblin_x - goal_x)

	# Under pressure? Pass immediately.
	var under_pressure: bool = false
	for opp in ctx.opponents:
		if _dist(ctx.goblin_x, ctx.goblin_y, _df(opp, "x"), _df(opp, "y")) < 0.1:
			under_pressure = true
			break

	if under_pressure:
		if dist_to_goal < 0.2 and ctx.goblin.get_stat("shooting") >= 6 and randf() < 0.3:
			return Decision.new(Action.SHOOT, goal_x, randf_range(0.35, 0.65))
		var t: Dictionary = _find_nearest_teammate(ctx)
		if not t.is_empty():
			return Decision.new(Action.PASS, _df(t, "x"), _df(t, "y"), _dg(t))

	# Check if in open space (no opponent within 0.15)
	var in_space: bool = true
	for opp in ctx.opponents:
		if _dist(ctx.goblin_x, ctx.goblin_y, _df(opp, "x"), _df(opp, "y")) < 0.15:
			in_space = false
			break

	# Wide position? Cross into the box.
	var is_wide: bool = absf(ctx.goblin_y - 0.5) > 0.25
	if is_wide and dist_to_goal < 0.40:
		return Decision.new(Action.CROSS, goal_x - (0.08 if ctx.is_home else -0.08), randf_range(0.35, 0.65))

	# Close to goal? Shoot.
	if dist_to_goal < 0.28:
		return Decision.new(Action.SHOOT, goal_x, randf_range(0.35, 0.65))

	# In open space? DRIBBLE FORWARD - carry the ball, don't pass
	if in_space and dist_to_goal > 0.28:
		var dribble_target: Vector2 = _smart_dribble_target(ctx)
		return Decision.new(Action.DRIBBLE, dribble_target.x, dribble_target.y)

	# Pick pass target: forward, wide, or nearest
	var pass_target: Dictionary = _find_best_pass(ctx)

	# In defensive third? Pass forward or dribble out.
	var in_own_third: bool = (ctx.is_home and ctx.goblin_x < 0.35) or (not ctx.is_home and ctx.goblin_x > 0.65)
	if in_own_third:
		var fwd_target: Dictionary = _find_forward_teammate(ctx)
		if not fwd_target.is_empty():
			return Decision.new(Action.PASS, _df(fwd_target, "x"), _df(fwd_target, "y"), _dg(fwd_target))
		var dribble_out: Vector2 = _smart_dribble_target(ctx)
		return Decision.new(Action.DRIBBLE, dribble_out.x, dribble_out.y)

	# Under pressure: pass
	if not pass_target.is_empty():
		return Decision.new(Action.PASS, _df(pass_target, "x"), _df(pass_target, "y"), _dg(pass_target))

	# Fallback: dribble
	var dribble_target: Vector2 = _smart_dribble_target(ctx)
	return Decision.new(Action.DRIBBLE, dribble_target.x, dribble_target.y)

# ── Own Team Has Ball ───────────────────────────────────────────────────────

static func _decide_own_team_ball(ctx: Context, _pos_data: Dictionary) -> Decision:
	## Off-ball movement is handled by _set_offball_movement() in the simulation.
	## AI only needs to return IDLE here - the zone rect system positions them.
	return Decision.new(Action.IDLE)

# ── Opponent Has Ball ───────────────────────────────────────────────────────

static func _decide_opponent_ball(ctx: Context, _pos_data: Dictionary, dist_to_ball: float) -> Decision:
	## Actively defend: tackle if close, press if moderate distance,
	## mark nearest opponent if far. Never just stand idle.
	# Tackle range - go for it
	if dist_to_ball < 0.12:
		return Decision.new(Action.TACKLE, ctx.ball_x, ctx.ball_y)

	# Press aggressively - these are goblins, they want that ball
	if dist_to_ball < 0.40:
		return Decision.new(Action.CHASE_BALL, ctx.ball_x, ctx.ball_y)

	# Further away: mark nearest opponent or cut passing lanes
	var own_goal_x: float = 0.0 if ctx.is_home else 1.0
	var nearest_opp: Dictionary = {}
	var nearest_d: float = 999.0
	for opp in ctx.opponents:
		var d: float = _dist(ctx.goblin_x, ctx.goblin_y, _df(opp, "x"), _df(opp, "y"))
		if d < nearest_d:
			nearest_d = d
			nearest_opp = opp

	if not nearest_opp.is_empty() and nearest_d < 0.40:
		# Tight marking - get goal-side of opponent
		var mark_x: float = lerpf(_df(nearest_opp, "x"), own_goal_x, 0.2)
		var mark_y: float = _df(nearest_opp, "y")
		return Decision.new(Action.MOVE_TO_POSITION, mark_x, mark_y)

	# Cut passing lane between ball and nearest forward opponent
	var cut_x: float = lerpf(ctx.ball_x, own_goal_x, 0.3)
	var cut_y: float = lerpf(ctx.ball_y, ctx.goblin_y, 0.5)
	return Decision.new(Action.MOVE_TO_POSITION, cut_x, cut_y)

# ── Helpers ─────────────────────────────────────────────────────────────────

static func _smart_dribble_target(ctx: Context) -> Vector2:
	## Dribble toward goal but swerve around the nearest opponent.
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	var fwd_dir: float = 1.0 if ctx.is_home else -1.0
	var target_x: float = ctx.goblin_x + fwd_dir * 0.15  # step forward
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
			target_y = ctx.goblin_y - 0.1  # go opposite side
		else:
			target_y = ctx.goblin_y + 0.1

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

	for t in ctx.teammates:
		if _dg(t) == ctx.goblin:
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

		var score: float = forward + width_bonus + space + goal_proximity
		if score > best_score:
			best_score = score
			best = t

	return best

## Returns empty Dictionary if none found
static func _find_forward_teammate(ctx: Context) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -999.0
	var goal_x: float = 1.0 if ctx.is_home else 0.0
	for t in ctx.teammates:
		if _dg(t) == ctx.goblin:
			continue
		var tx: float = _df(t, "x")
		var forward_amount: float
		if ctx.is_home:
			forward_amount = tx - ctx.goblin_x
		else:
			forward_amount = ctx.goblin_x - tx
		if forward_amount <= 0.0:
			continue
		var closeness_to_goal: float = 1.0 - absf(tx - goal_x)
		var s: float = forward_amount * 0.5 + closeness_to_goal * 0.5
		if s > best_score:
			best_score = s
			best = t
	return best
