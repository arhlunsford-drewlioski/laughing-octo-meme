class_name TeamCoordinator
extends RefCounted
## Assigns one role per goblin each tick to prevent swarming.
## Only ONE goblin per team gets each active role (presser, chaser, etc).

enum Role {
	BALL_CARRIER,   # has the ball
	PRESSER,        # nearest defender to ball carrier, closes down
	COVER_PRESSER,  # 2nd nearest, cuts off escape route
	LOOSE_CHASER,   # nearest to loose ball (only 1!)
	MARKER,         # marks a specific opponent
	HOLDER,         # holds zone position
}

# Minimum ticks a goblin keeps their role before reassignment
const ROLE_STICKY_TICKS: int = 2

# ── State ──────────────────────────────────────────────────────────────────

# { GoblinData: Role }
var _roles: Dictionary = {}
# { GoblinData: int } - ticks remaining on current role
var _role_ticks: Dictionary = {}
# Whether a possession change happened this tick (resets stickiness)
var _force_reassign: bool = false

# Track previous ball state to detect possession changes
var _prev_ball_owner: GoblinData = null
var _prev_ball_state: int = -1  # Ball.BallState

# ── Public API ─────────────────────────────────────────────────────────────

func get_role(goblin: GoblinData) -> Role:
	return _roles.get(goblin, Role.HOLDER)

func get_role_name(goblin: GoblinData) -> String:
	return Role.keys()[get_role(goblin)]

## Call once per tick, before AI decisions. Assigns roles for both teams.
func update(goblin_states: Dictionary, ball: Ball,
		home_formation: Formation, away_formation: Formation) -> void:
	# Detect possession changes -> force reassignment
	_force_reassign = false
	if ball.owner != _prev_ball_owner or ball.state != _prev_ball_state:
		_force_reassign = true
	_prev_ball_owner = ball.owner
	_prev_ball_state = ball.state

	# Tick down stickiness counters
	for goblin in _role_ticks:
		_role_ticks[goblin] = maxi(_role_ticks[goblin] - 1, 0)

	# Assign roles per team
	_assign_team_roles(home_formation, away_formation, goblin_states, ball, true)
	_assign_team_roles(away_formation, home_formation, goblin_states, ball, false)

# ── Role Assignment ────────────────────────────────────────────────────────

func _assign_team_roles(formation: Formation, _opp_formation: Formation,
		goblin_states: Dictionary, ball: Ball, is_home: bool) -> void:
	var all_goblins: Array = formation.get_all()
	var assigned: Dictionary = {}  # GoblinData -> true (already assigned this tick)

	# 1. Ball carrier (auto-assigned)
	if ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		if bool(owner_gs["is_home"]) == is_home:
			_set_role(ball.owner, Role.BALL_CARRIER)
			assigned[ball.owner] = true

	# 2. Loose ball -> ANYONE chases (ball on the ground = survival, not formation)
	var is_loose: bool = ball.state == Ball.BallState.LOOSE or ball.state == Ball.BallState.DEAD
	if is_loose:
		var chaser := _find_nearest_unassigned(all_goblins, goblin_states, assigned, ball.x, ball.y)
		if chaser:
			_set_role(chaser, Role.LOOSE_CHASER)
			assigned[chaser] = true

	# 3. Opponent has ball -> ONE presser from attack/midfield zone only
	#    Defenders NEVER press. They hold the line. This is the #1 rule.
	var opponent_has_ball: bool = false
	if ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		opponent_has_ball = bool(owner_gs["is_home"]) != is_home

	if opponent_has_ball:
		var presser := _find_nearest_pressable(all_goblins, goblin_states, assigned, ball.x, ball.y)
		if presser:
			_set_role(presser, Role.PRESSER)
			assigned[presser] = true

	# 4. Everyone else -> holder (STATE 6 handles all defensive positioning)
	for goblin in all_goblins:
		if not assigned.has(goblin):
			_set_role(goblin, Role.HOLDER)
			assigned[goblin] = true

# ── Helpers ────────────────────────────────────────────────────────────────

func _set_role(goblin: GoblinData, role: Role) -> void:
	var current: Role = _roles.get(goblin, Role.HOLDER)
	var ticks_left: int = _role_ticks.get(goblin, 0)

	# Sticky: keep current role if not expired and no force reassign
	if not _force_reassign and ticks_left > 0 and current == role:
		return  # already has this role and it's sticky

	# If forcing a different role while sticky, only allow if force_reassign
	if not _force_reassign and ticks_left > 0 and current != role:
		# Keep the old role - stickiness wins
		return

	_roles[goblin] = role
	_role_ticks[goblin] = ROLE_STICKY_TICKS

func _find_nearest_pressable(goblins: Array, goblin_states: Dictionary,
		assigned: Dictionary, tx: float, ty: float) -> GoblinData:
	## Only attackers and midfielders can press/chase. Defenders hold the line.
	## Prefer goblins whose zone rect contains the ball.
	var best: GoblinData = null
	var best_score: float = 999.0
	for goblin in goblins:
		if assigned.has(goblin):
			continue
		if goblin.position == "keeper":
			continue
		# DEFENDERS NEVER PRESS
		var zone: String = PositionDatabase.get_zone(goblin.position)
		if zone == "defense":
			continue
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var d: float = _dist(float(gs["x"]), float(gs["y"]), tx, ty)

		# Prefer goblins whose zone contains the ball (big bonus)
		var is_left: bool = bool(gs.get("is_left_flank", false))
		var is_home: bool = bool(gs["is_home"])
		var rect: Array = PositionDatabase.get_zone_rect_flipped(
			goblin.position, false, is_home, is_left)
		var ball_in_zone: bool = (
			tx >= float(rect[0]) - 0.05 and tx <= float(rect[1]) + 0.05 and
			ty >= float(rect[2]) - 0.05 and ty <= float(rect[3]) + 0.05)
		var score: float = d + (0.0 if ball_in_zone else 0.5)

		if score < best_score:
			best_score = score
			best = goblin
	return best

func _find_nearest_unassigned(goblins: Array, goblin_states: Dictionary,
		assigned: Dictionary, tx: float, ty: float) -> GoblinData:
	var best: GoblinData = null
	var best_dist: float = 999.0
	for goblin in goblins:
		if assigned.has(goblin):
			continue
		if goblin.position == "keeper":
			continue
		if not goblin_states.has(goblin):
			continue
		var gs: Dictionary = goblin_states[goblin]
		var d: float = _dist(float(gs["x"]), float(gs["y"]), tx, ty)
		if d < best_dist:
			best_dist = d
			best = goblin
	return best

static func _dist(x1: float, y1: float, x2: float, y2: float) -> float:
	return sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
