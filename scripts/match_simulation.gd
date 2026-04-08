class_name MatchSimulation
extends RefCounted
## Core headless match engine. Ticks 10x/sec, emits state snapshots.
## FM-style: every goblin always moves toward a smoothly-updating ideal position.
## Decisions (pass/shoot/tackle) are instant events on top of continuous movement.

# ── Constants ───────────────────────────────────────────────────────────────

const TICKS_PER_SECOND: float = 10.0
const TICK_DELTA: float = 1.0 / TICKS_PER_SECOND  # 0.1s real time
const MATCH_DURATION: float = 90.0  # match minutes
const MINUTES_PER_TICK: float = 0.14  # slower match clock so build-up reads on screen
const MOVEMENT_SPEED: float = 0.0095  # base jog speed (calmer)
const SPRINT_MULTIPLIER: float = 1.20  # sprinting
const PASS_SPEED: float = 1.30  # faster passes for better flow
const SHOT_SPEED: float = 1.70
const LOOSE_BALL_RANGE: float = 0.15  # auto-claim if ball rolls near player
const TACKLE_RANGE: float = 0.055  # tight - must be very close
const SHOT_RANGE: float = 0.30
const PASS_RECEIVE_RADIUS: float = 0.08
const PASS_INTERCEPT_RADIUS: float = 0.05
const PASS_SEGMENT_RADIUS: float = 0.035
const RECEIVE_LOOKAHEAD: float = 0.18
const KICKOFF_HOLD_DURATION: int = 10  # 1.0s hold before kickoff pass
const GOAL_CELEBRATION_TICKS: int = 20  # 2.0s celebration freeze after goal

# Velocity / momentum
const ACCEL_RATE: float = 0.45          # lerp toward max speed per tick (smoother ramp-up)
const DECEL_RATE: float = 0.40          # lerp for braking on direction change
const STEER_RATE: float = 0.30          # lerp for direction change per tick (less twitchy)
const DIRECTION_CHANGE_THRESHOLD: float = 0.15  # dot product < this = big turn (~80 degrees)
const COMMIT_TICKS_ON_TURN: int = 4     # ticks of reduced speed after major direction change
const COMMIT_TICKS_CHASE: int = 3       # ticks a loose ball chaser is locked to direction
const COMMIT_SPEED_FACTOR: float = 0.55 # speed multiplier during commitment

enum TeamPhase {
	BUILD_UP,
	FINAL_THIRD,
	COUNTER_ATTACK,
	DEFENSIVE_BLOCK,
	COUNTER_PRESS,
	LOOSE_BALL,
}

# Ideal position tracking - simulation snaps, visual layer smooths
const IDEAL_SMOOTH: float = 1.0    # snap to position (visual layer handles smoothing)
const URGENT_SMOOTH: float = 1.0   # chase/tackle/press - snap
const CARRIER_SMOOTH: float = 1.0  # carrier - snap

# Arrival behavior
const SLOWDOWN_RADIUS: float = 0.05
const ARRIVAL_RADIUS: float = 0.008
const MIN_DRIFT_SPEED: float = 0.0  # no drift - stop cleanly at target
const IDEAL_DEAD_ZONE: float = 0.020  # ignore ideal position changes smaller than this

# Separation
const SEPARATION_DIST: float = 0.055
const SEPARATION_FORCE: float = 0.02

# ── Home positions (normalized) ─────────────────────────────────────────────

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

const HOME_KICKOFF_ZONE_X := {
	"goal": 0.05,
	"defense": 0.18,
	"midfield": 0.34,
	"attack": 0.45,
}

const AWAY_KICKOFF_ZONE_X := {
	"goal": 0.95,
	"defense": 0.82,
	"midfield": 0.66,
	"attack": 0.55,
}

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
var _kickoff_hold_ticks: int = 0
var _kickoff_kicker: GoblinData = null
var _kickoff_outlet: GoblinData = null
var _celebration_ticks: int = 0
var _celebration_scorer: GoblinData = null
var _celebration_corner: Vector2 = Vector2.ZERO
var _celebration_kicking_team: int = -1  # which team kicks off after celebration

# Per-goblin runtime state
var goblin_states: Dictionary = {}

var _tick_events: Array = []

# Team coordinator (role assignment)
var coordinator: TeamCoordinator = TeamCoordinator.new()

# Off-ball runs
var _active_runs: Dictionary = {}
var _home_runners: int = 0
var _away_runners: int = 0
var _prev_home_has_ball: bool = false
var _prev_away_has_ball: bool = false
var _home_phase: TeamPhase = TeamPhase.BUILD_UP
var _away_phase: TeamPhase = TeamPhase.DEFENSIVE_BLOCK

# Transient action targets (consumed by _update_ideal_positions each tick)
var _action_targets: Dictionary = {}
# Persistent carrier target - survives cooldown so carrier keeps moving
var _carrier_target: Dictionary = {}  # {"x": float, "y": float}
# Persistent move targets - survive between AI decisions so goblins don't drift
var _move_targets: Dictionary = {}  # GoblinData -> {"x": float, "y": float}
# Ball intent while travelling: pass/cross metadata used for live contests
var _ball_intent: Dictionary = {}

# Spells (one-time use per match, home = player)
var fireball_available: Array[bool] = [true, false]
var haste_available: Array[bool] = [true, false]
var multiball_available: Array[bool] = [true, false]

# Haste tracking
var _haste_ticks: Array[int] = [0, 0]  # remaining ticks per team
var _haste_targets: Array = [[], []]  # goblins with active haste buffs per team
const HASTE_DURATION_TICKS: int = 100  # 10 seconds at 10 ticks/sec
const HASTE_SPEED_BOOST: int = 3

# Multiball tracking
var _extra_balls: Array = []  # [{ball: Ball, ticks_remaining: int}]
const MULTIBALL_COUNT: int = 3
const MULTIBALL_LIFETIME_TICKS: int = 100  # 10 seconds
const MULTIBALL_SPEED: float = 0.6

# Deferred removals (can't erase from goblin_states mid-iteration)
var _pending_removals: Array[GoblinData] = []

# Debug counters
var _debug_actions: Dictionary = {}
var _debug_ticks: int = 0

# ── Dictionary helpers ─────────────────────────────────────────────────────

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
	_active_runs.clear()
	_action_targets.clear()
	_carrier_target.clear()
	_move_targets.clear()
	_ball_intent.clear()
	_pending_removals.clear()
	fireball_available = [true, false]
	haste_available = [true, false]
	multiball_available = [true, false]
	_haste_ticks = [0, 0]
	_haste_targets = [[], []]
	_extra_balls.clear()
	_home_phase = TeamPhase.BUILD_UP
	_away_phase = TeamPhase.DEFENSIVE_BLOCK
	_kickoff_hold_ticks = 0
	_kickoff_kicker = null
	_kickoff_outlet = null
	_celebration_ticks = 0
	_celebration_scorer = null
	_celebration_kicking_team = -1

	_init_goblin_positions(home, true)
	_init_goblin_positions(away, false)

	for goblin in home.get_all():
		goblin.reset_for_match()
	for goblin in away.get_all():
		goblin.reset_for_match()

	_reset_positions_for_kickoff(0)

	return _build_snapshot()

func _init_goblin_positions(formation: Formation, is_home: bool) -> void:
	for zone_name in Formation.ZONES:
		var goblins: Array = formation.get_zone(zone_name)
		for i in goblins.size():
			var goblin: GoblinData = goblins[i]
			var spawn: Vector2 = _kickoff_spawn_position(goblin, zone_name, is_home, i, goblins.size())
			goblin_states[goblin] = {
				"x": spawn.x,
				"y": spawn.y,
				"home_x": spawn.x,
				"home_y": spawn.y,
				"ideal_x": spawn.x,
				"ideal_y": spawn.y,
				"roam_x": spawn.x,
				"roam_y": spawn.y,
				"roam_timer": randf_range(1.0, 2.5),
				"support_x": spawn.x,
				"support_y": spawn.y,
				"support_timer": randf_range(0.8, 1.8),
				"ball_control_time": 0.0,
				"settle_time": 0.0,
				"cooldown": 0.0,
				"decide_wait": randf_range(0.0, 0.2),
				"sprinting": false,
				"action": GoblinAI.Action.IDLE,
				"facing": 1.0 if is_home else -1.0,
				"is_home": is_home,
				"vel_x": 0.0,
				"vel_y": 0.0,
				"commit_ticks": 0,
			}

func _kickoff_spawn_position(goblin: GoblinData, zone_name: String, is_home: bool,
		slot_index: int, slot_count: int) -> Vector2:
	var zone_x_map: Dictionary = HOME_KICKOFF_ZONE_X if is_home else AWAY_KICKOFF_ZONE_X
	var y_positions: Array = ZONE_Y_SPREAD.get(slot_count, [0.5])
	var base_x: float = float(zone_x_map.get(zone_name, 0.5))
	var slot_y: float = float(y_positions[mini(slot_index, y_positions.size() - 1)])
	var x: float = base_x
	var y: float = slot_y

	match goblin.position:
		"winger", "wing_back":
			y = 0.14 if slot_y < 0.5 else 0.86
			x += 0.015 if is_home else -0.015
		"anchor", "sweeper", "enforcer":
			y = lerpf(y, 0.5, 0.35)
			x += -0.025 if is_home else 0.025
		"playmaker", "trequartista", "attacking_mid", "false_nine":
			y = lerpf(y, 0.5, 0.22)
			x += 0.010 if is_home else -0.010
		"box_to_box", "midfielder":
			x += 0.006 if is_home else -0.006
		"poacher", "striker", "target_man", "shadow_striker":
			x += 0.018 if is_home else -0.018
			y = lerpf(y, 0.5, 0.18)

	if zone_name == "attack":
		x = clampf(x, 0.40, 0.48) if is_home else clampf(x, 0.52, 0.60)
	elif zone_name == "midfield":
		x = clampf(x, 0.26, 0.41) if is_home else clampf(x, 0.59, 0.74)
	elif zone_name == "defense":
		x = clampf(x, 0.11, 0.24) if is_home else clampf(x, 0.76, 0.89)

	y = clampf(y, 0.10, 0.90)
	return Vector2(x, y)

func _apply_kickoff_reset(formation: Formation, is_home: bool) -> void:
	for zone_name in Formation.ZONES:
		var goblins: Array = formation.get_zone(zone_name)
		for i in goblins.size():
			var goblin: GoblinData = goblins[i]
			if not goblin_states.has(goblin):
				continue
			var gs: Dictionary = goblin_states[goblin]
			var spawn: Vector2 = _kickoff_spawn_position(goblin, zone_name, is_home, i, goblins.size())
			gs["x"] = spawn.x
			gs["y"] = spawn.y
			gs["home_x"] = spawn.x
			gs["home_y"] = spawn.y
			gs["ideal_x"] = spawn.x
			gs["ideal_y"] = spawn.y
			gs["roam_x"] = spawn.x
			gs["roam_y"] = spawn.y
			gs["roam_timer"] = randf_range(1.5, 3.0)
			gs["support_x"] = spawn.x
			gs["support_y"] = spawn.y
			gs["support_timer"] = randf_range(1.0, 2.0)
			gs["ball_control_time"] = 0.0
			gs["settle_time"] = 0.0
			gs["cooldown"] = 0.5
			gs["decide_wait"] = 0.0
			gs["sprinting"] = false
			gs["action"] = GoblinAI.Action.IDLE
			gs["facing"] = 1.0 if is_home else -1.0
			gs["vel_x"] = 0.0
			gs["vel_y"] = 0.0
			gs["commit_ticks"] = 0

# ── Tick ────────────────────────────────────────────────────────────────────

func tick() -> Dictionary:
	if not match_started or match_over:
		return _build_snapshot()

	_tick_events.clear()
	_debug_ticks += 1

	# 1. Advance clock
	clock += MINUTES_PER_TICK
	if clock >= MATCH_DURATION:
		clock = MATCH_DURATION
		match_over = true
		_tick_events.append({"type": "match_end", "score": score.duplicate()})
		return _build_snapshot()

	# 1a. Goal celebration - scorer runs to corner, everyone else freezes
	if _celebration_ticks > 0:
		_celebration_ticks -= 1
		# Move scorer toward corner flag
		if _celebration_scorer and goblin_states.has(_celebration_scorer):
			var sgs: Dictionary = goblin_states[_celebration_scorer]
			var sx: float = _gf(sgs, "x")
			var sy: float = _gf(sgs, "y")
			sgs["x"] = lerpf(sx, _celebration_corner.x, 0.15)
			sgs["y"] = lerpf(sy, _celebration_corner.y, 0.15)
		if _celebration_ticks == 0:
			# Celebration over - now do kickoff reset
			_reset_positions_for_kickoff(_celebration_kicking_team)
			_celebration_scorer = null
			_celebration_kicking_team = -1
		return _build_snapshot()

	# 1b. Kickoff hold - freeze all goblins, count down, then auto-pass
	if _kickoff_hold_ticks > 0:
		_kickoff_hold_ticks -= 1
		if _kickoff_hold_ticks == 0:
			_execute_kickoff_pass()
		if ball.owner and goblin_states.has(ball.owner):
			var ogs: Dictionary = goblin_states[ball.owner]
			ball.x = _gf(ogs, "x")
			ball.y = _gf(ogs, "y")
		return _build_snapshot()

	# 2. Update ball
	_update_ball()

	# 3. Check loose ball claims
	_check_loose_ball_claims()

	# 4. Update team coordinator roles
	coordinator.update(goblin_states, ball, home_formation, away_formation)

	# 5. Tick cooldowns + process AI decisions for all goblins
	#    Decision interval prevents re-evaluation spam (e.g., tackle loops)
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		if _gf(gs, "cooldown") > 0.0:
			gs["cooldown"] = _gf(gs, "cooldown") - TICK_DELTA
		elif _gf(gs, "decide_wait") > 0.0:
			gs["decide_wait"] = _gf(gs, "decide_wait") - TICK_DELTA
		else:
			_process_goblin_action(goblin)
			# Non-action decisions (IDLE, MOVE_TO_POSITION) get a short wait
			# to prevent re-evaluating every single tick
			var last_action: int = int(gs["action"])
			if last_action == GoblinAI.Action.IDLE or last_action == GoblinAI.Action.MOVE_TO_POSITION:
				gs["decide_wait"] = 0.2  # re-evaluate every 0.2s

	# 5b. Process deferred removals (goblins killed during tackles/spells)
	_process_pending_removals()

	# 6. Update ideal positions for ALL goblins (smooth targets)
	_update_ideal_positions()

	# 7. Move ALL goblins toward their ideal positions (arrival behavior)
	_move_all_goblins()

	# 8. Update ball position if controlled
	if ball.state == Ball.BallState.CONTROLLED and ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		owner_gs["ball_control_time"] = _gf(owner_gs, "ball_control_time") + TICK_DELTA
		ball.x = _gf(owner_gs, "x")
		ball.y = _gf(owner_gs, "y")

	# 9. Tick haste expiry
	_tick_haste()

	# 10. Tick extra balls (multiball)
	_tick_extra_balls()

	return _build_snapshot()

# ── Ball Update ─────────────────────────────────────────────────────────────

func _update_ball() -> void:
	var prev_x: float = ball.x
	var prev_y: float = ball.y
	var arrived := ball.update(TICK_DELTA)

	if ball.state == Ball.BallState.TRAVELLING:
		if _resolve_travelling_ball(prev_x, prev_y):
			return
		if arrived:
			_clear_ball_intent()
			ball.set_loose(ball.x, ball.y)

func _check_loose_ball_claims() -> void:
	if ball.state == Ball.BallState.DEAD:
		var nearest := _find_nearest_goblin_to(ball.x, ball.y, 999.0)
		if nearest:
			var ngs: Dictionary = goblin_states[nearest]
			_clear_ball_intent()
			_give_ball_control(nearest, _gf(ngs, "x"), _gf(ngs, "y"), false)
		return

	if ball.state != Ball.BallState.LOOSE:
		return
	var nearest := _find_nearest_goblin_to(ball.x, ball.y, LOOSE_BALL_RANGE)
	if nearest:
		_clear_ball_intent()
		_give_ball_control(nearest, ball.x, ball.y, true)
		_tick_events.append({"type": "ball_recovery", "goblin": nearest.goblin_name})

func _resolve_travelling_ball(prev_x: float, prev_y: float) -> bool:
	var same_team_best: GoblinData = null
	var same_team_score: float = -999.0
	var other_team_best: GoblinData = null
	var other_team_score: float = -999.0
	var intended: GoblinData = _ball_intent.get("target_goblin", null) as GoblinData
	var passer: GoblinData = _ball_intent.get("from", null) as GoblinData
	var passer_is_home: bool = bool(_ball_intent.get("is_home", true))

	for goblin in goblin_states:
		if goblin == passer:
			continue
		var gs: Dictionary = goblin_states[goblin]
		var gx: float = _gf(gs, "x")
		var gy: float = _gf(gs, "y")
		var dist_seg: float = _distance_to_segment(gx, gy, prev_x, prev_y, ball.x, ball.y)
		var dist_ball: float = _dist(gx, gy, ball.x, ball.y)
		var is_teammate: bool = _gb(gs, "is_home") == passer_is_home

		if is_teammate:
			var score := _receive_score(goblin, dist_seg, dist_ball, goblin == intended)
			if score > same_team_score:
				same_team_score = score
				same_team_best = goblin
		else:
			var score := _intercept_score(goblin, dist_seg, dist_ball)
			if score > other_team_score:
				other_team_score = score
				other_team_best = goblin

	var winner: GoblinData = null
	var intercepted: bool = false
	var is_aerial_duel: bool = ball.aerial and same_team_best != null and other_team_best != null and other_team_score > -999.0 and same_team_score > -999.0
	if other_team_best and other_team_score > same_team_score + 0.35:
		winner = other_team_best
		intercepted = true
	elif same_team_best:
		winner = same_team_best
	elif other_team_best and other_team_score > 0.0:
		winner = other_team_best
		intercepted = true

	if winner == null:
		return false

	# Emit aerial duel when both teams contested an aerial ball
	if is_aerial_duel:
		var loser: GoblinData = other_team_best if not intercepted else same_team_best
		if loser:
			_tick_events.append({
				"type": "aerial",
				"winner": winner.goblin_name,
				"loser": loser.goblin_name,
			})

	# Keeper winning an aerial cross: claim or punch
	var intent_type: String = String(_ball_intent.get("type", ""))
	if winner.position == "keeper" and ball.aerial and (intent_type == "cross" or intent_type == "clear"):
		_clear_ball_intent()
		if randf() < 0.6:
			# Clean claim
			_tick_events.append({"type": "keeper_claim", "keeper": winner.goblin_name})
			_give_ball_control(winner, ball.x, ball.y, true)
		else:
			# Punch clear
			_tick_events.append({"type": "keeper_punch", "keeper": winner.goblin_name})
			var punch_dir: float = 1.0 if goblin_states.has(winner) and _gb(goblin_states[winner], "is_home") else -1.0
			ball.set_kicked(ball.x, ball.y, ball.x + punch_dir * 0.15, ball.y + randf_range(-0.10, 0.10),
					PASS_SPEED * 1.1, Ball.GROUND_FRICTION, false)
			_set_ball_intent("punch", winner, null, ball.x + punch_dir * 0.15, ball.y, _gb(goblin_states[winner], "is_home") if goblin_states.has(winner) else true)
		return true

	if intercepted:
		_clear_ball_intent()
		_give_ball_control(winner, ball.x, ball.y, true)
		_tick_events.append({
			"type": "interception",
			"goblin": winner.goblin_name,
			"from": passer.goblin_name if passer else "",
			"target": intended.goblin_name if intended else "",
		})
		return true

	var miscontrol := _roll_first_touch(winner)
	if miscontrol:
		_clear_ball_intent()
		ball.set_loose(ball.x, ball.y)
		_tick_events.append({
			"type": "bad_touch",
			"goblin": winner.goblin_name,
			"target": intended.goblin_name if intended else "",
		})
		return true

	_clear_ball_intent()
	_give_ball_control(winner, ball.x, ball.y, true)
	_tick_events.append({
		"type": "pass_received",
		"goblin": winner.goblin_name,
		"target": intended.goblin_name if intended else "",
	})
	return true

func _receive_score(goblin: GoblinData, dist_seg: float, dist_ball: float, is_intended: bool) -> float:
	if dist_seg > PASS_SEGMENT_RADIUS and dist_ball > PASS_RECEIVE_RADIUS:
		return -999.0
	var speed: float = float(goblin.get_stat("speed"))
	var defense: float = float(goblin.get_stat("defense"))
	var strength: float = float(goblin.get_stat("strength"))
	var closeness: float = maxf(0.0, 1.0 - dist_ball / PASS_RECEIVE_RADIUS) * 2.5
	var lane_fit: float = maxf(0.0, 1.0 - dist_seg / PASS_SEGMENT_RADIUS) * 2.0
	var intended_bonus: float = 2.5 if is_intended else 0.0
	return speed * 0.50 + defense * 0.22 + strength * 0.18 + closeness + lane_fit + intended_bonus

func _intercept_score(goblin: GoblinData, dist_seg: float, dist_ball: float) -> float:
	if dist_seg > PASS_SEGMENT_RADIUS or dist_ball > PASS_INTERCEPT_RADIUS:
		return -999.0
	var defense: float = float(goblin.get_stat("defense"))
	var speed: float = float(goblin.get_stat("speed"))
	var lane_fit: float = maxf(0.0, 1.0 - dist_seg / PASS_SEGMENT_RADIUS) * 2.8
	var closeness: float = maxf(0.0, 1.0 - dist_ball / PASS_INTERCEPT_RADIUS) * 1.8
	return defense * 0.65 + speed * 0.35 + lane_fit + closeness

func _roll_first_touch(goblin: GoblinData) -> bool:
	var control: float = float(goblin.get_stat("speed")) * 0.45 + float(goblin.get_stat("defense")) * 0.33
	control += float(goblin.get_stat("strength")) * 0.22
	var speed_pressure: float = clampf(ball.get_speed() * 0.08, 0.0, 0.12)
	var chaos_penalty: float = float(goblin.get_stat("chaos")) * 0.004
	var miscontrol: float = clampf(0.16 - control * 0.018 + speed_pressure + chaos_penalty, 0.02, 0.15)
	return randf() < miscontrol

func _control_settle_time(goblin: GoblinData) -> float:
	var control: float = float(goblin.get_stat("defense")) * 0.55 + float(goblin.get_stat("strength")) * 0.45
	var settle: float = 0.22 - control * 0.018 + float(goblin.get_stat("chaos")) * 0.004
	if goblin.position == "playmaker" or goblin.position == "trequartista":
		settle -= 0.04
	elif goblin.position == "target_man" or goblin.position == "false_nine":
		settle += 0.02
	return clampf(settle, 0.06, 0.20)

func _give_ball_control(goblin: GoblinData, x: float, y: float, with_settle: bool = true) -> void:
	# Clear stale carrier target so new carrier doesn't inherit old dribble direction
	_carrier_target.clear()
	if not goblin_states.has(goblin):
		ball.set_controlled(goblin, x, y)
		return
	var gs: Dictionary = goblin_states[goblin]
	ball.set_controlled(goblin, x, y)
	gs["ball_control_time"] = 0.0
	var settle_time: float = 0.0
	if with_settle:
		settle_time = _control_settle_time(goblin)
	gs["settle_time"] = settle_time
	gs["decide_wait"] = maxf(_gf(gs, "decide_wait"), _gf(gs, "settle_time") * 0.5)

func _get_loose_ball_chase_target(goblin: GoblinData) -> Vector2:
	var gs: Dictionary = goblin_states[goblin]
	var gx: float = _gf(gs, "x")
	var gy: float = _gf(gs, "y")
	var chase_x: float = ball.x
	var chase_y: float = ball.y
	if ball.state == Ball.BallState.LOOSE or ball.state == Ball.BallState.TRAVELLING:
		var speed_factor: float = 0.16 + float(goblin.get_stat("speed")) * 0.012
		chase_x = ball.x + ball.vx * speed_factor
		chase_y = ball.y + ball.vy * speed_factor
		var dist_to_ball: float = _dist(gx, gy, ball.x, ball.y)
		if dist_to_ball < 0.10:
			chase_x = lerpf(chase_x, ball.x, 0.65)
			chase_y = lerpf(chase_y, ball.y, 0.65)
	return Vector2(clampf(chase_x, 0.02, 0.98), clampf(chase_y, 0.05, 0.95))

func _set_ball_intent(kind: String, from_goblin: GoblinData, target_goblin: GoblinData,
		target_x: float, target_y: float, is_home: bool) -> void:
	_ball_intent = {
		"type": kind,
		"from": from_goblin,
		"target_goblin": target_goblin,
		"target_x": target_x,
		"target_y": target_y,
		"is_home": is_home,
	}

func _clear_ball_intent() -> void:
	_ball_intent.clear()

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
		GoblinAI.Action.INTERCEPT, GoblinAI.Action.CHASE_BALL:
			var loose_target: Vector2 = _get_loose_ball_chase_target(goblin)
			_set_action_target(goblin, loose_target.x, loose_target.y)
			# Lock chase direction for a few ticks to prevent twitch-corrections
			if int(gs.get("commit_ticks", 0)) <= 0:
				gs["commit_ticks"] = COMMIT_TICKS_CHASE
		GoblinAI.Action.MOVE_TO_POSITION:
			_set_action_target(goblin, decision.target_x, decision.target_y)
			# Persist move target so it survives between AI re-evaluations
			_move_targets[goblin] = {"x": decision.target_x, "y": decision.target_y}
		GoblinAI.Action.IDLE:
			# Clear persistent target when idle (own team has ball)
			_move_targets.erase(goblin)
		_:
			_move_targets.erase(goblin)

func _execute_pass(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	var gs: Dictionary = goblin_states[goblin]
	var is_home: bool = _gb(gs, "is_home")

	var passer_control: float = goblin.get_stat("speed") * 0.40 + goblin.get_stat("defense") * 0.28
	passer_control += goblin.get_stat("strength") * 0.12 + goblin.get_stat("chaos") * 0.08
	var target_help: float = 0.0
	if decision.target_goblin:
		target_help = decision.target_goblin.get_stat("speed") * 0.015 + decision.target_goblin.get_stat("strength") * 0.008
	var pass_dist: float = _dist(_gf(gs, "x"), _gf(gs, "y"), decision.target_x, decision.target_y)
	var risk_penalty: float = maxf(0.0, pass_dist - 0.30) * clampf(0.55 - goblin.get_stat("chaos") * 0.012, 0.26, 0.55)
	var accuracy: float = clampf(0.50 + passer_control * 0.035 + target_help - risk_penalty, 0.52, 0.95)
	if decision.action == GoblinAI.Action.CLEAR:
		accuracy -= 0.08
	elif decision.action == GoblinAI.Action.HOLD_UP:
		accuracy += 0.04
	accuracy = clampf(accuracy, 0.38, 0.95)
	var chaos_var: float = goblin.get_stat("chaos") * 0.02
	accuracy += randf_range(-chaos_var, chaos_var)

	var tx: float = decision.target_x
	var ty: float = decision.target_y

	if randf() > accuracy:
		tx += randf_range(-0.1, 0.1)
		ty += randf_range(-0.1, 0.1)
		tx = clampf(tx, 0.0, 1.0)
		ty = clampf(ty, 0.0, 1.0)

	var kick_speed: float = PASS_SPEED
	var kick_friction: float = Ball.GROUND_FRICTION
	var kick_kind: String = "pass"
	if decision.action == GoblinAI.Action.CLEAR:
		kick_speed = PASS_SPEED * 1.25
		kick_friction = Ball.THROUGH_BALL_FRICTION
		kick_kind = "clear"
	elif decision.action == GoblinAI.Action.HOLD_UP:
		kick_speed = PASS_SPEED * 0.9

	var kick_dist: float = _dist(_gf(gs, "x"), _gf(gs, "y"), tx, ty)
	var is_aerial: bool = decision.action == GoblinAI.Action.CLEAR or kick_dist > 0.30
	ball.set_kicked(_gf(gs, "x"), _gf(gs, "y"), tx, ty, kick_speed, kick_friction, is_aerial)
	_set_ball_intent(kick_kind, goblin, decision.target_goblin, tx, ty, is_home)
	gs["cooldown"] = 0.3
	var to_name: String = decision.target_goblin.goblin_name if decision.target_goblin else ""
	if decision.action == GoblinAI.Action.CLEAR:
		_tick_events.append({"type": "clearance", "goblin": goblin.goblin_name})
	else:
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

	var dist_penalty: float = dist_to_goal * 2.0
	var shot_power: float = shooting + strength * 0.3 - dist_penalty + randf_range(-chaos * 0.3, chaos * 0.3)
	var shot_accuracy: float = shooting * 0.8 - dist_penalty + randf_range(-chaos * 0.3, chaos * 0.3)

	var opp_formation: Formation = away_formation if is_home else home_formation
	var keeper: GoblinData = opp_formation.get_keeper()
	var keeper_save: float = 0.0
	if keeper:
		keeper_save = float(keeper.get_stat("strength") + keeper.get_stat("defense")) * 0.45
		keeper_save += randf_range(-2.0, 2.0)

	var opp_goblins := opp_formation.get_all()
	for opp in opp_goblins:
		if not goblin_states.has(opp):
			continue
		var opp_gs: Dictionary = goblin_states[opp]
		var dist: float = _dist(_gf(opp_gs, "x"), _gf(opp_gs, "y"), _gf(gs, "x"), _gf(gs, "y"))
		if dist < 0.12 and opp != keeper:
			var block_chance: float = (opp.get_stat("defense") + opp.get_stat("strength")) * 0.012
			if randf() < block_chance:
				_tick_events.append({"type": "block", "goblin": opp.goblin_name, "shooter": goblin.goblin_name})
				ball.set_loose(_gf(opp_gs, "x") + randf_range(-0.05, 0.05), _gf(opp_gs, "y") + randf_range(-0.05, 0.05))
				gs["cooldown"] = 0.75
				return

	_tick_events.append({"type": "shot", "goblin": goblin.goblin_name, "power": shot_power, "accuracy": shot_accuracy})
	gs["cooldown"] = 0.75

	if shot_accuracy < 5.0 and randf() < (5.0 - shot_accuracy) * 0.12:
		# Off target: miss wide/high or hit the post
		if randf() < 0.25:
			_tick_events.append({"type": "post", "goblin": goblin.goblin_name})
			_tick_events.append({"type": "corner_awarded", "team": "home" if is_home else "away"})
		else:
			_tick_events.append({"type": "miss", "goblin": goblin.goblin_name})
			# Wide miss = goal kick; high miss = out
			if randf() < 0.5:
				_tick_events.append({"type": "out", "reason": "goal_kick"})
		ball.set_loose(goal_x, randf_range(0.3, 0.7))
	elif shot_power > keeper_save:
		var team_idx: int = 0 if is_home else 1
		score[team_idx] += 1
		_tick_events.append({"type": "goal", "goblin": goblin.goblin_name, "score": score.duplicate()})
		_clear_ball_intent()
		ball.set_dead(goal_x, 0.5)
		# Start celebration phase instead of immediate kickoff
		_celebration_ticks = GOAL_CELEBRATION_TICKS
		_celebration_scorer = goblin
		_celebration_kicking_team = 1 - team_idx
		# Move scorer toward corner flag
		var corner_y: float = 0.05 if _gf(gs, "y") < 0.5 else 0.95
		_celebration_corner = Vector2(goal_x, corner_y)
	else:
		var keeper_name: String = keeper.goblin_name if keeper else "unknown"
		_tick_events.append({"type": "save", "keeper": keeper_name, "shooter": goblin.goblin_name})
		var save_roll: float = randf()
		if save_roll < 0.25:
			# Parried out for a corner
			_tick_events.append({"type": "corner_awarded", "team": "home" if is_home else "away"})
			ball.set_loose(goal_x + (0.08 if not is_home else -0.08), randf_range(0.35, 0.65))
		elif save_roll < 0.45:
			# Spilled / parried into play
			ball.set_loose(goal_x + (0.08 if not is_home else -0.08), randf_range(0.35, 0.65))
		else:
			# Clean catch
			if keeper and goblin_states.has(keeper):
				var kgs: Dictionary = goblin_states[keeper]
				_tick_events.append({"type": "keeper_claim", "keeper": keeper_name})
				_give_ball_control(keeper, _gf(kgs, "x"), _gf(kgs, "y"), true)
			else:
				ball.set_loose(goal_x + (0.08 if not is_home else -0.08), 0.5)

func _execute_cross(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	var gs: Dictionary = goblin_states[goblin]
	var is_home: bool = _gb(gs, "is_home")
	ball.set_kicked(_gf(gs, "x"), _gf(gs, "y"), decision.target_x, decision.target_y,
			PASS_SPEED * 1.05, Ball.THROUGH_BALL_FRICTION, true)  # crosses are always aerial
	_set_ball_intent("cross", goblin, decision.target_goblin, decision.target_x, decision.target_y, is_home)
	gs["cooldown"] = 0.3
	_tick_events.append({"type": "cross", "goblin": goblin.goblin_name})

func _execute_dribble(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	if ball.owner != goblin:
		return
	_set_action_target(goblin, decision.target_x, decision.target_y)

	var gs: Dictionary = goblin_states[goblin]
	gs["cooldown"] = 0.3  # carry the ball for a readable beat

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
				_clear_ball_intent()
				ball.set_loose(_gf(gs, "x"), _gf(gs, "y"))
				_tick_events.append({"type": "dispossessed", "goblin": goblin.goblin_name, "by": opp.goblin_name})
				opp_gs["cooldown"] = 0.3
				# Small chance of hurting the dribbler during the challenge
				_roll_tackle_injury(opp, goblin, false)
			else:
				# Dribbler beats the defender
				_tick_events.append({"type": "take_on", "goblin": goblin.goblin_name, "beaten": opp.goblin_name})
				_tick_events.append({"type": "challenge", "goblin": opp.goblin_name, "by": goblin.goblin_name})
				opp_gs["cooldown"] = 0.5
			break

func _execute_tackle(goblin: GoblinData, decision: GoblinAI.Decision) -> void:
	var gs: Dictionary = goblin_states[goblin]
	_set_action_target(goblin, decision.target_x, decision.target_y)

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
		_clear_ball_intent()
		ball.set_loose(_gf(owner_gs, "x"), _gf(owner_gs, "y"))
		var was_foul: bool = false
		var foul_chance: float = goblin.get_stat("chaos") * 0.02 + (0.1 if goblin.position == "enforcer" else 0.0)
		if randf() < foul_chance:
			was_foul = true
			_tick_events.append({"type": "foul", "goblin": goblin.goblin_name, "victim": victim.goblin_name})
		# Goblin violence: chance of injury/death
		_roll_tackle_injury(goblin, victim, was_foul)
	else:
		_tick_events.append({"type": "tackle_failed", "goblin": goblin.goblin_name})
		gs["cooldown"] = 0.75

# ── Goblin Violence (Injury / Death / Removal) ──────────────────────────

func _roll_tackle_injury(tackler: GoblinData, victim: GoblinData, was_foul: bool) -> void:
	## After a successful tackle or foul, roll for injury/death.
	var injury_chance: float = (float(tackler.get_stat("strength")) + float(tackler.get_stat("chaos"))) * 0.015
	if was_foul:
		injury_chance += 0.10
	if tackler.position == "enforcer":
		injury_chance += 0.05
	if randf() >= injury_chance:
		return

	var severity_roll: float = randf() + float(tackler.get_stat("strength")) * 0.02
	var severity: int  # GoblinData.InjuryState
	if severity_roll >= 0.95:
		severity = GoblinData.InjuryState.DEAD
	elif severity_roll >= 0.70:
		severity = GoblinData.InjuryState.MAJOR
	else:
		severity = GoblinData.InjuryState.MINOR

	victim.apply_injury(severity)
	var severity_name: String
	match severity:
		GoblinData.InjuryState.MINOR:
			severity_name = "minor"
		GoblinData.InjuryState.MAJOR:
			severity_name = "major"
		GoblinData.InjuryState.DEAD:
			severity_name = "dead"
		_:
			severity_name = "minor"

	_tick_events.append({"type": "injury", "goblin": victim.goblin_name, "severity": severity_name, "by": tackler.goblin_name})
	if severity == GoblinData.InjuryState.DEAD:
		_tick_events.append({"type": "death", "goblin": victim.goblin_name, "by": tackler.goblin_name})
		_pending_removals.append(victim)

func _remove_goblin_from_match(goblin: GoblinData) -> void:
	## Remove a dead goblin from the pitch. Shared by tackle kills and fireball.
	if not goblin_states.has(goblin):
		return
	var gs: Dictionary = goblin_states[goblin]
	var is_home: bool = _gb(gs, "is_home")

	# Drop the ball if they had it
	if ball.owner == goblin:
		_clear_ball_intent()
		ball.set_loose(_gf(gs, "x"), _gf(gs, "y"))

	# Clean up all references
	goblin_states.erase(goblin)
	_active_runs.erase(goblin)
	_action_targets.erase(goblin)
	_move_targets.erase(goblin)
	coordinator._roles.erase(goblin)
	coordinator._role_ticks.erase(goblin)

	# Remove from formation
	var formation: Formation = home_formation if is_home else away_formation
	formation.remove_goblin(goblin)

	var team_name: String = "home" if is_home else "away"
	_tick_events.append({"type": "goblin_removed", "goblin": goblin.goblin_name, "team": team_name})

	# Check if team is wiped out
	if formation.get_all().is_empty():
		match_over = true
		_tick_events.append({"type": "team_eliminated", "team": team_name})

func _process_pending_removals() -> void:
	for goblin in _pending_removals:
		_remove_goblin_from_match(goblin)
	_pending_removals.clear()

const FIREBALL_KILL_RADIUS: float = 0.08   # instant death zone
const FIREBALL_BLAST_RADIUS: float = 0.16  # injury/death falloff zone

func cast_fireball(team_index: int, target_x: float, target_y: float) -> bool:
	## One-time AoE spell: hits all goblins in blast radius.
	## Center = instant kill, edge = injury chance. Hits both teams!
	if not fireball_available[team_index]:
		return false

	fireball_available[team_index] = false
	_tick_events.append({"type": "fireball", "x": target_x, "y": target_y, "team": "home" if team_index == 0 else "away"})

	# Check every goblin on the pitch
	var hit_goblins: Array = []
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		var d: float = _dist(_gf(gs, "x"), _gf(gs, "y"), target_x, target_y)
		if d < FIREBALL_BLAST_RADIUS:
			hit_goblins.append({"goblin": goblin, "dist": d})

	for entry in hit_goblins:
		var goblin: GoblinData = entry["goblin"]
		var d: float = float(entry["dist"])
		if not goblin_states.has(goblin):
			continue  # already removed by earlier hit this frame

		if d < FIREBALL_KILL_RADIUS:
			# Direct hit - instant death
			goblin.apply_injury(GoblinData.InjuryState.DEAD)
			_tick_events.append({"type": "death", "goblin": goblin.goblin_name, "by": "FIREBALL"})
			_remove_goblin_from_match(goblin)
		else:
			# Blast zone - severity based on distance (closer = worse)
			var intensity: float = 1.0 - (d - FIREBALL_KILL_RADIUS) / (FIREBALL_BLAST_RADIUS - FIREBALL_KILL_RADIUS)
			var roll: float = randf()
			if roll < intensity * 0.4:
				# Kill
				goblin.apply_injury(GoblinData.InjuryState.DEAD)
				_tick_events.append({"type": "death", "goblin": goblin.goblin_name, "by": "FIREBALL"})
				_remove_goblin_from_match(goblin)
			elif roll < intensity * 0.7:
				# Major injury
				goblin.apply_injury(GoblinData.InjuryState.MAJOR)
				_tick_events.append({"type": "injury", "goblin": goblin.goblin_name, "severity": "major", "by": "FIREBALL"})
			else:
				# Minor injury
				goblin.apply_injury(GoblinData.InjuryState.MINOR)
				_tick_events.append({"type": "injury", "goblin": goblin.goblin_name, "severity": "minor", "by": "FIREBALL"})

	return true

# ── Haste Spell ────────────────────────────────────────────────────────────

func cast_haste(team_index: int) -> bool:
	## One-time spell: +3 speed to all goblins on your team for 10 seconds.
	if not haste_available[team_index]:
		return false
	haste_available[team_index] = false
	_haste_ticks[team_index] = HASTE_DURATION_TICKS

	var formation: Formation = home_formation if team_index == 0 else away_formation
	var targets: Array = []
	for goblin in formation.get_all():
		if goblin_states.has(goblin):
			goblin.active_effects.append({"stat": "speed", "amount": HASTE_SPEED_BOOST})
			targets.append(goblin)
	_haste_targets[team_index] = targets

	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "haste", "team": team_name})
	return true

func _tick_haste() -> void:
	for i in 2:
		if _haste_ticks[i] <= 0:
			continue
		_haste_ticks[i] -= 1
		if _haste_ticks[i] == 0:
			# Remove speed buffs
			for goblin in _haste_targets[i]:
				var idx: int = -1
				for j in goblin.active_effects.size():
					if goblin.active_effects[j].get("stat", "") == "speed" and goblin.active_effects[j].get("amount", 0) == HASTE_SPEED_BOOST:
						idx = j
						break
				if idx >= 0:
					goblin.active_effects.remove_at(idx)
			_haste_targets[i].clear()
			var team_name: String = "home" if i == 0 else "away"
			_tick_events.append({"type": "haste_expired", "team": team_name})

# ── Multiball Spell ────────────────────────────────────────────────────────

func cast_multiball(team_index: int) -> bool:
	## One-time spell: spawn 3 chaotic extra balls that bounce around and can score.
	if not multiball_available[team_index]:
		return false
	multiball_available[team_index] = false

	for k in MULTIBALL_COUNT:
		var extra := Ball.new()
		var spawn_x: float = randf_range(0.30, 0.70)
		var spawn_y: float = randf_range(0.20, 0.80)
		var angle: float = randf() * TAU
		extra.set_kicked(spawn_x, spawn_y,
			spawn_x + cos(angle) * 0.3, spawn_y + sin(angle) * 0.3,
			MULTIBALL_SPEED, Ball.THROUGH_BALL_FRICTION, false)
		_extra_balls.append({"ball": extra, "ticks_remaining": MULTIBALL_LIFETIME_TICKS})

	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "multiball", "team": team_name})
	return true

func _tick_extra_balls() -> void:
	var expired: Array = []
	for i in _extra_balls.size():
		var entry: Dictionary = _extra_balls[i]
		var extra: Ball = entry["ball"] as Ball
		entry["ticks_remaining"] = int(entry["ticks_remaining"]) - 1

		# Update ball physics
		extra.update(TICK_DELTA)

		# Re-kick if it stopped (keep it bouncing)
		if extra.get_speed() < Ball.MIN_SPEED:
			var angle: float = randf() * TAU
			extra.set_kicked(extra.x, extra.y,
				extra.x + cos(angle) * 0.3, extra.y + sin(angle) * 0.3,
				MULTIBALL_SPEED * 0.8, Ball.THROUGH_BALL_FRICTION, false)

		# Check goal: did it enter the goal mouth?
		var in_goal_y: bool = extra.y > 0.38 and extra.y < 0.62
		if in_goal_y:
			if extra.x <= 0.02:
				# Goal for away team (scored on home goal)
				score[1] += 1
				_tick_events.append({"type": "multiball_goal", "team": "away", "score": score.duplicate()})
				expired.append(i)
				continue
			elif extra.x >= 0.98:
				# Goal for home team (scored on away goal)
				score[0] += 1
				_tick_events.append({"type": "multiball_goal", "team": "home", "score": score.duplicate()})
				expired.append(i)
				continue

		# Lifetime expiry
		if int(entry["ticks_remaining"]) <= 0:
			expired.append(i)

	# Remove expired (reverse order to preserve indices)
	expired.sort()
	expired.reverse()
	for idx in expired:
		_extra_balls.remove_at(idx)

# ── Action Target (transient, consumed by ideal position update) ──────────

func _set_action_target(goblin: GoblinData, tx: float, ty: float) -> void:
	_action_targets[goblin] = {"x": clampf(tx, 0.02, 0.98), "y": clampf(ty, 0.05, 0.95)}

# ── Ideal Position Update ──────────────────────────────────────────────────

func _update_ideal_positions() -> void:
	## Computes a raw target for every goblin, then smoothly lerps their
	## persistent ideal_x/ideal_y toward it. This is the core anti-yo-yo fix.

	# Determine possession
	var home_has_ball: bool = false
	var away_has_ball: bool = false
	if ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		if _gb(owner_gs, "is_home"):
			home_has_ball = true
		else:
			away_has_ball = true

	var is_loose: bool = ball.state == Ball.BallState.LOOSE or ball.state == Ball.BallState.DEAD

	# Detect turnovers
	var home_won_ball: bool = not _prev_home_has_ball and home_has_ball and not is_loose
	var away_won_ball: bool = not _prev_away_has_ball and away_has_ball and not is_loose
	var home_lost_ball: bool = _prev_home_has_ball and not home_has_ball and not is_loose
	var away_lost_ball: bool = _prev_away_has_ball and not away_has_ball and not is_loose
	_prev_home_has_ball = home_has_ball
	_prev_away_has_ball = away_has_ball

	# Tick down active runs
	_home_runners = 0
	_away_runners = 0
	var expired_runs: Array = []
	for goblin in _active_runs:
		var run: Dictionary = _active_runs[goblin]
		run["ticks_remaining"] = int(run["ticks_remaining"]) - 1
		if int(run["ticks_remaining"]) <= 0:
			expired_runs.append(goblin)
		else:
			if goblin_states.has(goblin) and _gb(goblin_states[goblin], "is_home"):
				_home_runners += 1
			else:
				_away_runners += 1
	for goblin in expired_runs:
		_active_runs.erase(goblin)

	# Cancel non-recovery runs on turnover
	if home_lost_ball or away_lost_ball:
		var cancel: Array = []
		for goblin in _active_runs:
			var run: Dictionary = _active_runs[goblin]
			if String(run["type"]) != "recovery":
				var gs2: Dictionary = goblin_states[goblin]
				var lost_home: bool = home_lost_ball and _gb(gs2, "is_home")
				var lost_away: bool = away_lost_ball and not _gb(gs2, "is_home")
				if lost_home or lost_away:
					cancel.append(goblin)
		for goblin in cancel:
			_active_runs.erase(goblin)

	# Pre-compute carrier info for run triggers
	var carrier_x: float = ball.x
	var carrier_y: float = ball.y
	var carrier_is_home: bool = false
	var carrier_under_pressure: bool = false
	var carrier_on_flank: bool = false
	var carrier_in_midfield: bool = false
	if ball.owner and goblin_states.has(ball.owner):
		var ogs: Dictionary = goblin_states[ball.owner]
		carrier_x = _gf(ogs, "x")
		carrier_y = _gf(ogs, "y")
		carrier_is_home = _gb(ogs, "is_home")
		carrier_on_flank = absf(carrier_y - 0.5) > 0.20
		carrier_in_midfield = carrier_x > 0.30 and carrier_x < 0.70
		var opp_formation2: Formation = away_formation if carrier_is_home else home_formation
		for opp in opp_formation2.get_all():
			if goblin_states.has(opp):
				var opgs: Dictionary = goblin_states[opp]
				if _dist(_gf(opgs, "x"), _gf(opgs, "y"), carrier_x, carrier_y) < 0.15:
					carrier_under_pressure = true
					break

	_home_phase = _determine_team_phase(true, home_has_ball, away_has_ball, home_won_ball, home_lost_ball,
			is_loose, carrier_x, carrier_under_pressure)
	_away_phase = _determine_team_phase(false, away_has_ball, home_has_ball, away_won_ball, away_lost_ball,
			is_loose, carrier_x, carrier_under_pressure)

	# Update each goblin's ideal position
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		var is_home: bool = _gb(gs, "is_home")
		var raw_x: float
		var raw_y: float
		var smooth: float = IDEAL_SMOOTH
		gs["sprinting"] = false  # default: jog

		# ── Priority 1: Ball carrier ──
		if ball.owner == goblin:
			# Keepers with ball: hold position, don't dribble upfield
			if goblin.position == "keeper":
				raw_x = _gf(gs, "home_x")
				raw_y = clampf(_gf(gs, "y"), 0.40, 0.60)
				smooth = CARRIER_SMOOTH
			elif _action_targets.has(goblin):
				# Fresh dribble target - save it and use it
				_carrier_target = _action_targets[goblin].duplicate()
				raw_x = _gf(_carrier_target, "x")
				raw_y = _gf(_carrier_target, "y")
			elif not _carrier_target.is_empty():
				# On cooldown - keep moving toward last dribble target
				raw_x = _gf(_carrier_target, "x")
				raw_y = _gf(_carrier_target, "y")
			else:
				# No target at all - dribble forward
				var fwd2: float = 1.0 if is_home else -1.0
				raw_x = clampf(_gf(gs, "x") + fwd2 * 0.15, 0.05, 0.95)
				raw_y = _gf(gs, "y")
			smooth = CARRIER_SMOOTH
			if goblin.position != "keeper":
				gs["sprinting"] = true
			gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
			gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)
			continue

		# ── Priority 2: AI action target (chase, tackle, etc.) ──
		if _action_targets.has(goblin):
			raw_x = _gf(_action_targets[goblin], "x")
			raw_y = _gf(_action_targets[goblin], "y")
			smooth = URGENT_SMOOTH
			gs["sprinting"] = true
			gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
			gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)
			continue

		# ── Priority 2a: Persistent move target (survives between AI ticks) ──
		if not _action_targets.has(goblin) and _move_targets.has(goblin):
			raw_x = _gf(_move_targets[goblin], "x")
			raw_y = _gf(_move_targets[goblin], "y")
			smooth = IDEAL_SMOOTH
			gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
			gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)
			continue

		# ── Priority 2b: intended receiver attacks the pass while it is travelling ──
		if ball.state == Ball.BallState.TRAVELLING and _ball_intent.get("target_goblin", null) == goblin:
			var receive_target := _get_receive_target()
			raw_x = receive_target.x
			raw_y = receive_target.y
			smooth = URGENT_SMOOTH
			gs["sprinting"] = true
			gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
			gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)
			continue

		# ── Priority 3: Active run ──
		if _active_runs.has(goblin):
			var run: Dictionary = _active_runs[goblin]
			raw_x = float(run["target_x"])
			raw_y = float(run["target_y"])
			gs["sprinting"] = true
			gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
			gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)
			continue

		# ── Check run triggers ──
		var my_team_has_ball: bool = (home_has_ball and is_home) or (away_has_ball and not is_home)
		var can_run: bool = goblin.position != "keeper"
		var team_runners: int = _home_runners if is_home else _away_runners
		var team_phase: TeamPhase = _home_phase if is_home else _away_phase
		var in_poss: bool = my_team_has_ball and not is_loose

		gs["roam_timer"] = _gf(gs, "roam_timer") - TICK_DELTA
		if _gf(gs, "roam_timer") <= 0.0:
			_refresh_roam_target(goblin, gs, is_home, in_poss, team_phase, carrier_x, carrier_y)
		gs["support_timer"] = _gf(gs, "support_timer") - TICK_DELTA
		if _gf(gs, "support_timer") <= 0.0:
			_refresh_support_target(goblin, gs, is_home, in_poss, team_phase, carrier_x, carrier_y)

		if can_run and my_team_has_ball and not is_loose and team_runners < 3 and carrier_is_home == is_home:
			var zone: String = PositionDatabase.get_zone(goblin.position)
			var fwd: float = 1.0 if is_home else -1.0
			var run_goal_x: float = 1.0 if is_home else 0.0
			var speed: float = float(goblin.get_stat("speed"))
			var shooting: float = float(goblin.get_stat("shooting"))
			var defense: float = float(goblin.get_stat("defense"))
			var chaos: float = float(goblin.get_stat("chaos"))

			# Forward run: any attacker/midfielder can make a run toward goal
			if zone == "attack":
				var run_pull: float = clampf(0.34 + speed * 0.018 + shooting * 0.014, 0.30, 0.62)
				if goblin.position == "poacher" or goblin.position == "shadow_striker":
					run_pull += 0.06
				elif goblin.position == "target_man" or goblin.position == "false_nine":
					run_pull -= 0.05
				var run_x: float = clampf(lerpf(_gf(gs, "x"), run_goal_x, run_pull), 0.10, 0.90)
				var lane_wobble: float = 0.06 + chaos * 0.007 + speed * 0.004
				var run_y: float = _gf(gs, "y") + randf_range(-lane_wobble, lane_wobble)
				_start_run(goblin, "forward", run_x, clampf(run_y, 0.08, 0.92), randi_range(10 + int(speed * 0.4), 16 + int(shooting * 0.5)), is_home)
			# Midfielders: run forward to support OR check to ball
			elif zone == "midfield":
				if carrier_under_pressure:
					var check_pull: float = clampf(0.36 + defense * 0.020, 0.34, 0.58)
					if goblin.position == "playmaker":
						check_pull += 0.08
					var check_x: float = lerpf(_gf(gs, "x"), carrier_x, check_pull)
					var check_y: float = lerpf(_gf(gs, "y"), carrier_y, 0.32 + chaos * 0.01)
					_start_run(goblin, "check_to_ball", check_x, check_y, randi_range(8, 13 + int(defense * 0.3)), is_home)
				else:
					var support_chance: float = 0.08 + speed * 0.018 + chaos * 0.010
					if goblin.position == "box_to_box" or goblin.position == "attacking_mid":
						support_chance += 0.15
					elif goblin.position == "playmaker":
						support_chance -= 0.03
					if randf() < support_chance:
						var run_x: float = clampf(_gf(gs, "x") + fwd * (0.12 + speed * 0.012), 0.10, 0.90)
						var run_y: float = _gf(gs, "y") + randf_range(-0.06 - chaos * 0.004, 0.06 + chaos * 0.004)
						_start_run(goblin, "forward", run_x, clampf(run_y, 0.08, 0.92), randi_range(9 + int(speed * 0.3), 16 + int(speed * 0.4)), is_home)
			# Overlap: defenders push up
			else:
				var overlap_chance: float = 0.04 + speed * 0.008 + chaos * 0.004
				if goblin.position == "wing_back":
					overlap_chance += 0.14
				elif goblin.position == "anchor" or goblin.position == "sweeper":
					overlap_chance -= 0.02
				if randf() < overlap_chance:
					var run_x: float = clampf(_gf(gs, "x") + fwd * (0.10 + speed * 0.010), 0.10, 0.90)
					_start_run(goblin, "overlap", run_x, _gf(gs, "home_y"), randi_range(9 + int(speed * 0.3), 14 + int(speed * 0.4)), is_home)

		# Recovery run on turnover
		if can_run and not my_team_has_ball and not is_loose:
			var my_team_lost: bool = (home_lost_ball and is_home) or (away_lost_ball and not is_home)
			var zone2: String = PositionDatabase.get_zone(goblin.position)
			if my_team_lost and zone2 == "attack" and not _active_runs.has(goblin):
				var own_goal_x2: float = 0.0 if is_home else 1.0
				var recover_pull: float = clampf(0.28 + float(goblin.get_stat("speed")) * 0.020 + float(goblin.get_stat("defense")) * 0.012, 0.28, 0.56)
				var recover_x: float = lerpf(_gf(gs, "x"), own_goal_x2, recover_pull)
				_start_run(goblin, "recovery", recover_x, _gf(gs, "home_y"), randi_range(9 + int(goblin.get_stat("speed") * 0.3), 14 + int(goblin.get_stat("defense") * 0.4)), is_home)

		# If a run just started, use it
		if _active_runs.has(goblin):
			var run: Dictionary = _active_runs[goblin]
			raw_x = float(run["target_x"])
			raw_y = float(run["target_y"])
			gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
			gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)
			continue

		# ── Priority 4: Slot-based positioning ──
		var slot: Vector2 = Vector2(_gf(gs, "support_x"), _gf(gs, "support_y"))
		raw_x = slot.x
		raw_y = slot.y

		# Loose ball: LOOSE_CHASER overrides
		if is_loose and coordinator.get_role(goblin) == TeamCoordinator.Role.LOOSE_CHASER:
			raw_x = ball.x
			raw_y = ball.y
			smooth = URGENT_SMOOTH
			gs["sprinting"] = true

		gs["ideal_x"] = lerpf(_gf(gs, "ideal_x"), raw_x, smooth)
		gs["ideal_y"] = lerpf(_gf(gs, "ideal_y"), raw_y, smooth)

	# Keeper hard clamp - stay between the posts, on the goal line
	for goblin2 in goblin_states:
		if goblin2.position == "keeper":
			var kgs: Dictionary = goblin_states[goblin2]
			kgs["ideal_y"] = clampf(_gf(kgs, "ideal_y"), 0.38, 0.62)
			var k_home_x: float = _gf(kgs, "home_x")
			kgs["ideal_x"] = clampf(_gf(kgs, "ideal_x"), k_home_x - 0.015, k_home_x + 0.015)

	# Clear transient action targets (consumed)
	_action_targets.clear()

func _start_run(goblin: GoblinData, type: String, tx: float, ty: float, ticks: int, is_home: bool) -> void:
	_active_runs[goblin] = {
		"type": type,
		"target_x": tx,
		"target_y": ty,
		"ticks_remaining": ticks,
	}
	if is_home:
		_home_runners += 1
	else:
		_away_runners += 1

func _get_receive_target() -> Vector2:
	var lead_x: float = ball.x + ball.vx * RECEIVE_LOOKAHEAD
	var lead_y: float = ball.y + ball.vy * RECEIVE_LOOKAHEAD
	var target_x: float = float(_ball_intent.get("target_x", lead_x))
	var target_y: float = float(_ball_intent.get("target_y", lead_y))
	return Vector2(
		clampf(lerpf(lead_x, target_x, 0.4), 0.02, 0.98),
		clampf(lerpf(lead_y, target_y, 0.4), 0.05, 0.95)
	)

func _roam_weight(goblin: GoblinData, in_poss: bool) -> float:
	match goblin.position:
		"playmaker", "trequartista", "box_to_box", "false_nine":
			return 0.55 if in_poss else 0.40
		"attacking_mid", "shadow_striker", "winger", "wing_back":
			return 0.48 if in_poss else 0.35
		"poacher", "striker", "midfielder", "target_man":
			return 0.42 if in_poss else 0.30
		"anchor", "sweeper", "enforcer":
			return 0.20 if in_poss else 0.14
		"keeper":
			return 0.0
		_:
			return 0.36 if in_poss else 0.26

func _shape_weight(goblin: GoblinData, team_phase: TeamPhase, in_poss: bool) -> float:
	match goblin.position:
		"keeper":
			return 0.95
		"anchor", "sweeper":
			return 0.62 if in_poss else 0.74
		"enforcer":
			return 0.55 if in_poss else 0.68
		"wing_back":
			return 0.40 if in_poss else 0.52
		"midfielder":
			return 0.35 if in_poss else 0.45
		"playmaker", "trequartista", "box_to_box", "false_nine":
			return 0.22 if in_poss else 0.30
		"attacking_mid", "shadow_striker", "winger":
			return 0.18 if in_poss else 0.26
		"poacher", "striker", "target_man":
			return 0.14 if in_poss else 0.22
		_:
			return 0.28 if in_poss else 0.36

func _support_shift_limit(goblin: GoblinData, in_poss: bool) -> Vector2:
	match goblin.position:
		"playmaker", "trequartista", "box_to_box", "false_nine":
			return Vector2(0.06, 0.07) if in_poss else Vector2(0.04, 0.05)
		"attacking_mid", "shadow_striker", "winger", "wing_back":
			return Vector2(0.06, 0.07) if in_poss else Vector2(0.04, 0.05)
		"poacher", "striker", "target_man", "midfielder":
			return Vector2(0.05, 0.06) if in_poss else Vector2(0.04, 0.05)
		"anchor", "sweeper", "enforcer":
			return Vector2(0.04, 0.05) if in_poss else Vector2(0.03, 0.04)
		"keeper":
			return Vector2(0.01, 0.02)
		_:
			return Vector2(0.05, 0.06)

func _support_refresh_time(goblin: GoblinData) -> float:
	match goblin.position:
		"playmaker", "trequartista", "box_to_box":
			return randf_range(1.0, 1.6)
		"winger", "wing_back", "shadow_striker", "attacking_mid":
			return randf_range(1.0, 1.8)
		"anchor", "sweeper", "enforcer", "keeper":
			return randf_range(1.6, 2.4)
		_:
			return randf_range(1.2, 2.0)

func _desired_support_target(goblin: GoblinData, gs: Dictionary, is_home: bool, in_poss: bool,
		team_phase: TeamPhase, carrier_x: float, carrier_y: float) -> Vector2:
	## All positions use the shape-aware slot system. This keeps formation
	## integrity and prevents drift from random roam targets.
	return _get_position_slot(goblin, gs, is_home, in_poss, team_phase, carrier_x, carrier_y)

func _expand_roam_rect(rect: Array, goblin: GoblinData, in_poss: bool) -> Array:
	var x_min: float = float(rect[0])
	var x_max: float = float(rect[1])
	var y_min: float = float(rect[2])
	var y_max: float = float(rect[3])
	var x_pad: float = 0.02
	var y_pad: float = 0.03

	match goblin.position:
		"playmaker", "trequartista", "box_to_box", "false_nine":
			x_pad += 0.03
			y_pad += 0.05
		"attacking_mid", "shadow_striker", "midfielder":
			x_pad += 0.02
			y_pad += 0.04
		"winger", "wing_back":
			x_pad += 0.01
			y_pad += 0.02
		"anchor", "sweeper", "enforcer":
			x_pad -= 0.01
			y_pad -= 0.01

	if in_poss:
		x_pad += 0.01
		y_pad += 0.02

	return [
		clampf(x_min - x_pad, 0.02, 0.98),
		clampf(x_max + x_pad, 0.02, 0.98),
		clampf(y_min - y_pad, 0.05, 0.95),
		clampf(y_max + y_pad, 0.05, 0.95),
	]

func _refresh_roam_target(goblin: GoblinData, gs: Dictionary, is_home: bool, in_poss: bool,
		team_phase: TeamPhase, carrier_x: float, carrier_y: float) -> void:
	if goblin.position == "keeper":
		gs["roam_x"] = _gf(gs, "home_x")
		gs["roam_y"] = _gf(gs, "home_y")
		gs["roam_timer"] = 2.0
		return

	var is_left_flank: bool = _gf(gs, "home_y") < 0.5
	var rect: Array = PositionDatabase.get_zone_rect_flipped(goblin.position, in_poss, is_home, is_left_flank)
	rect = _expand_roam_rect(rect, goblin, in_poss)
	var x_min: float = float(rect[0])
	var x_max: float = float(rect[1])
	var y_min: float = float(rect[2])
	var y_max: float = float(rect[3])
	var home_y: float = _gf(gs, "home_y")
	var lane_bias: float = home_y
	var ball_progress: float = _team_progress(carrier_x, is_home)
	var progress_center: float = lerpf(x_min, x_max, 0.5)
	var carry_pull: float = 0.0

	match team_phase:
		TeamPhase.BUILD_UP:
			carry_pull = 0.18
		TeamPhase.FINAL_THIRD:
			carry_pull = 0.26
		TeamPhase.COUNTER_ATTACK:
			carry_pull = 0.24
		TeamPhase.DEFENSIVE_BLOCK:
			carry_pull = -0.02
		TeamPhase.COUNTER_PRESS:
			carry_pull = 0.08
		_:
			carry_pull = 0.0

	if in_poss:
		progress_center = lerpf(progress_center, _from_progress(ball_progress + carry_pull, is_home), 0.22)
	else:
		progress_center = lerpf(progress_center, _from_progress(maxf(0.10, ball_progress - 0.06), is_home), 0.14)

	var target_x: float = clampf(randf_range(x_min, x_max), x_min, x_max)
	target_x = clampf(lerpf(target_x, progress_center, 0.28), x_min, x_max)

	var target_y: float = randf_range(y_min, y_max)
	target_y = lerpf(target_y, lane_bias, 0.20)
	target_y = lerpf(target_y, carrier_y, 0.08 if in_poss else 0.04)

	match goblin.position:
		"playmaker", "trequartista", "false_nine", "attacking_mid":
			target_y = lerpf(target_y, carrier_y, 0.12 if in_poss else 0.06)
		"winger", "wing_back":
			target_y = lerpf(target_y, lane_bias, 0.70)
		"anchor", "sweeper":
			target_y = lerpf(target_y, 0.5, 0.35)
		"poacher", "shadow_striker":
			target_x = lerpf(target_x, _from_progress(minf(0.92, ball_progress + 0.10), is_home), 0.18)

	# Space-seeking: bias roam target away from nearby teammate clusters
	var my_formation2: Formation = home_formation if is_home else away_formation
	var repel_x: float = 0.0
	var repel_y: float = 0.0
	var repel_count: int = 0
	for teammate in my_formation2.get_all():
		if teammate == goblin or teammate.position == "keeper":
			continue
		if not goblin_states.has(teammate):
			continue
		var tgs: Dictionary = goblin_states[teammate]
		var tdx: float = target_x - _gf(tgs, "x")
		var tdy: float = target_y - _gf(tgs, "y")
		var tdist: float = sqrt(tdx * tdx + tdy * tdy)
		if tdist < 0.15 and tdist > 0.001:
			repel_x += tdx / tdist
			repel_y += tdy / tdist
			repel_count += 1
	if repel_count > 0:
		var repel_strength: float = 0.04
		target_x += (repel_x / repel_count) * repel_strength
		target_y += (repel_y / repel_count) * repel_strength

	# Blend new target with current roam position (random walk, not teleport)
	var prev_roam_x: float = _gf(gs, "roam_x")
	var prev_roam_y: float = _gf(gs, "roam_y")
	var walk_blend: float = 0.55  # how much of the new target vs current position
	target_x = lerpf(prev_roam_x, target_x, walk_blend)
	target_y = lerpf(prev_roam_y, target_y, walk_blend)

	gs["roam_x"] = clampf(target_x, x_min, x_max)
	gs["roam_y"] = clampf(target_y, y_min, y_max)
	gs["roam_timer"] = randf_range(1.8, 3.2)
	if goblin.position == "playmaker" or goblin.position == "trequartista":
		gs["roam_timer"] = randf_range(1.4, 2.4)
	elif goblin.position == "anchor" or goblin.position == "sweeper":
		gs["roam_timer"] = randf_range(2.8, 4.5)

func _refresh_support_target(goblin: GoblinData, gs: Dictionary, is_home: bool, in_poss: bool,
		team_phase: TeamPhase, carrier_x: float, carrier_y: float) -> void:
	var desired: Vector2 = _desired_support_target(goblin, gs, is_home, in_poss, team_phase, carrier_x, carrier_y)
	var current := Vector2(_gf(gs, "support_x"), _gf(gs, "support_y"))
	var shift_limit: Vector2 = _support_shift_limit(goblin, in_poss)
	var target_x: float = move_toward(current.x, desired.x, shift_limit.x)
	var target_y: float = move_toward(current.y, desired.y, shift_limit.y)
	gs["support_x"] = clampf(target_x, 0.02, 0.98)
	gs["support_y"] = clampf(target_y, 0.05, 0.95)
	# Refresh a bit faster when defending for reactive positioning
	gs["support_timer"] = _support_refresh_time(goblin) * (0.7 if not in_poss else 1.0)

func _determine_team_phase(is_home: bool, team_has_ball: bool, opponent_has_ball: bool,
		won_ball: bool, lost_ball: bool, is_loose: bool, carrier_x: float,
		carrier_under_pressure: bool) -> TeamPhase:
	if is_loose:
		return TeamPhase.LOOSE_BALL

	var ball_progress: float = _team_progress(carrier_x, is_home)

	if team_has_ball:
		if won_ball and (ball_progress < 0.45 or carrier_under_pressure):
			return TeamPhase.COUNTER_ATTACK
		if ball_progress > 0.68:
			return TeamPhase.FINAL_THIRD
		return TeamPhase.BUILD_UP

	if opponent_has_ball:
		if lost_ball and ball_progress < 0.62:
			return TeamPhase.COUNTER_PRESS
		return TeamPhase.DEFENSIVE_BLOCK

	return TeamPhase.LOOSE_BALL

func _shape_profile(phase: TeamPhase) -> Dictionary:
	match phase:
		TeamPhase.BUILD_UP:
			return {"attack": 0.68, "midfield": 0.48, "defense": 0.29, "width": 1.22, "compact": 0.70, "ball_pull": 0.04}
		TeamPhase.FINAL_THIRD:
			return {"attack": 0.82, "midfield": 0.63, "defense": 0.40, "width": 1.30, "compact": 0.64, "ball_pull": 0.05}
		TeamPhase.COUNTER_ATTACK:
			return {"attack": 0.76, "midfield": 0.56, "defense": 0.34, "width": 1.16, "compact": 0.58, "ball_pull": 0.05}
		TeamPhase.COUNTER_PRESS:
			return {"attack": 0.54, "midfield": 0.42, "defense": 0.24, "width": 0.96, "compact": 0.60, "ball_pull": 0.10}
		TeamPhase.DEFENSIVE_BLOCK:
			return {"attack": 0.46, "midfield": 0.32, "defense": 0.17, "width": 0.95, "compact": 0.58, "ball_pull": 0.08}
		_:
			return {"attack": 0.56, "midfield": 0.40, "defense": 0.24, "width": 1.08, "compact": 0.56, "ball_pull": 0.05}

func _team_progress(x: float, is_home: bool) -> float:
	return clampf(x, 0.0, 1.0) if is_home else clampf(1.0 - x, 0.0, 1.0)

func _from_progress(progress: float, is_home: bool) -> float:
	return clampf(progress, 0.02, 0.98) if is_home else clampf(1.0 - progress, 0.02, 0.98)

# ── Zone-Rect Helpers ──────────────────────────────────────────────────────

func _get_position_slot(goblin: GoblinData, gs: Dictionary, is_home: bool, in_poss: bool,
		team_phase: TeamPhase, carrier_x: float, carrier_y: float) -> Vector2:
	## Shape-aware anchor positioning. Players keep lanes, but the whole side
	## shifts by phase, ball side, and position identity.
	var zone: String = PositionDatabase.get_zone(goblin.position)
	var home_y: float = _gf(gs, "home_y")
	var lane_offset: float = home_y - 0.5
	var shape: Dictionary = _shape_profile(team_phase)
	var ball_progress: float = _team_progress(carrier_x, is_home)
	if zone == "goal":
		var keeper_progress: float = 0.05 + maxf(0.0, ball_progress - 0.55) * 0.02
		return Vector2(_from_progress(keeper_progress, is_home), clampf(lerpf(0.5, ball.y, 0.25), 0.40, 0.60))
	var role_progress: float = float(shape[zone])
	var width_scale: float = float(shape["width"])
	var compactness: float = float(shape["compact"])
	var ball_pull: float = float(shape["ball_pull"])
	var progress: float = role_progress
	var target_y: float = 0.5 + lane_offset * width_scale

	if in_poss:
		match zone:
			"attack":
				progress = maxf(progress, ball_progress + 0.08)
				target_y = 0.5 + lane_offset * width_scale * 1.08 + (carrier_y - 0.5) * ball_pull * 0.65
			"midfield":
				progress = lerpf(progress, ball_progress + 0.02, 0.35)
				target_y = 0.5 + lane_offset * width_scale * 0.95 + (carrier_y - 0.5) * ball_pull
			"defense":
				progress += maxf(0.0, ball_progress - 0.45) * 0.22
				target_y = 0.5 + lane_offset * width_scale * 0.80 + (carrier_y - 0.5) * ball_pull * 0.55
	else:
		match zone:
			"attack":
				progress = lerpf(progress, 0.52, 0.35)
				target_y = lerpf(0.5 + lane_offset * width_scale * compactness, carrier_y, ball_pull * 0.45)
			"midfield":
				progress = lerpf(progress, maxf(0.20, ball_progress - 0.06), 0.35)
				target_y = lerpf(0.5 + lane_offset * width_scale * compactness, carrier_y, ball_pull)
			"defense":
				progress = lerpf(progress, maxf(0.12, ball_progress - 0.14), 0.40)
				target_y = lerpf(0.5 + lane_offset * width_scale * compactness * 0.9, carrier_y, ball_pull * 0.70)

	match goblin.position:
		"winger":
			target_y = 0.5 + lane_offset * width_scale * 1.22 + (carrier_y - 0.5) * 0.10
			if in_poss:
				progress += 0.03
		"wing_back":
			target_y = 0.5 + lane_offset * width_scale * 1.18 + (carrier_y - 0.5) * 0.12
			progress += 0.01 if in_poss else -0.01
		"playmaker", "trequartista", "attacking_mid":
			target_y = lerpf(target_y, carrier_y, 0.18)
			if in_poss:
				progress += 0.02
		"anchor":
			target_y = lerpf(target_y, 0.5, 0.30)
			progress -= 0.03
		"sweeper":
			target_y = lerpf(target_y, 0.5, 0.18)
			progress -= 0.04
		"box_to_box":
			progress += 0.03 if in_poss else -0.01
			target_y = lerpf(target_y, carrier_y, 0.10)
		"poacher", "shadow_striker", "target_man":
			progress += 0.04 if in_poss else 0.01
		"false_nine":
			progress -= 0.02 if in_poss else 0.00
			target_y = lerpf(target_y, carrier_y, 0.14)

	# Weak-side width: players on the opposite side of the ball hold wider
	var ball_side: float = signf(carrier_y - 0.5)
	var player_side: float = signf(home_y - 0.5)
	if ball_side != 0.0 and player_side != ball_side and zone != "goal":
		target_y += player_side * 0.03

	progress = clampf(progress, 0.08, 0.92)
	target_y = clampf(target_y, 0.08, 0.92)
	var anchor := Vector2(_from_progress(progress, is_home), target_y)
	var roam := Vector2(_gf(gs, "roam_x"), _gf(gs, "roam_y"))
	var shape_weight: float = _shape_weight(goblin, team_phase, in_poss)
	return roam.lerp(anchor, shape_weight)

# ── Movement (Arrival Behavior) ───────────────────────────────────────────

func _movement_profile(goblin: GoblinData, gs: Dictionary, dx: float, dy: float, dist: float) -> Dictionary:
	var speed: float = float(goblin.get_stat("speed"))
	var defense: float = float(goblin.get_stat("defense"))
	var strength: float = float(goblin.get_stat("strength"))
	var chaos: float = float(goblin.get_stat("chaos"))
	var sprint: float = SPRINT_MULTIPLIER if bool(gs.get("sprinting", false)) else 1.0
	var base_move: float = MOVEMENT_SPEED * (0.60 + speed * 0.085)
	var action_bonus: float = 1.0
	match int(gs["action"]):
		GoblinAI.Action.CHASE_BALL, GoblinAI.Action.INTERCEPT:
			action_bonus += defense * 0.018 + speed * 0.015
		GoblinAI.Action.TACKLE:
			action_bonus += defense * 0.015 + strength * 0.012
		GoblinAI.Action.DRIBBLE:
			action_bonus += speed * 0.017 + chaos * 0.010
		GoblinAI.Action.MOVE_TO_POSITION:
			action_bonus += defense * 0.009
	if ball.owner == goblin:
		action_bonus += strength * 0.010

	var turn_penalty: float = 1.0
	if dist > 0.001:
		var dir_x: float = dx / dist
		var dir_y: float = dy / dist
		if absf(dir_x) > 0.05 and dir_x * _gf(gs, "facing") < -0.10:
			turn_penalty = lerpf(0.78, 0.98, speed / 10.0)
		if absf(dir_y) > absf(dir_x) * 1.25:
			turn_penalty *= lerpf(0.88, 1.0, speed / 10.0)

	var slowdown_radius: float = SLOWDOWN_RADIUS * (0.95 + speed * 0.030 + strength * 0.010)
	return {
		"max_move": base_move * sprint * action_bonus * turn_penalty,
		"slowdown_radius": slowdown_radius,
	}

func _move_all_goblins() -> void:
	## Velocity-based movement: goblins accelerate/decelerate toward ideal_x/ideal_y
	## with direction commitment to prevent twitch-corrections.
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		var dx: float = _gf(gs, "ideal_x") - _gf(gs, "x")
		var dy: float = _gf(gs, "ideal_y") - _gf(gs, "y")
		var dist: float = sqrt(dx * dx + dy * dy)

		# Dead zone: ignore tiny ideal position changes to prevent micro-jitter.
		# Sprinting goblins (chasers, carriers, pressers) skip this for responsiveness.
		if dist < IDEAL_DEAD_ZONE and not bool(gs.get("sprinting", false)):
			gs["vel_x"] = lerpf(_gf(gs, "vel_x"), 0.0, DECEL_RATE)
			gs["vel_y"] = lerpf(_gf(gs, "vel_y"), 0.0, DECEL_RATE)
			continue

		var profile: Dictionary = _movement_profile(goblin, gs, dx, dy, dist)
		var max_move: float = _gf(profile, "max_move")
		var slowdown_radius: float = _gf(profile, "slowdown_radius")

		# Desired speed from arrival behavior
		var desired_speed: float
		if dist < ARRIVAL_RADIUS:
			desired_speed = MIN_DRIFT_SPEED
		elif dist < slowdown_radius:
			desired_speed = lerpf(MIN_DRIFT_SPEED, max_move, dist / slowdown_radius)
		else:
			desired_speed = max_move

		# Desired direction
		var desired_dir_x: float = 0.0
		var desired_dir_y: float = 0.0
		if dist > ARRIVAL_RADIUS:
			desired_dir_x = dx / dist
			desired_dir_y = dy / dist

		# Current velocity
		var vel_x: float = _gf(gs, "vel_x")
		var vel_y: float = _gf(gs, "vel_y")
		var cur_speed: float = sqrt(vel_x * vel_x + vel_y * vel_y)
		var cur_dir_x: float = 0.0
		var cur_dir_y: float = 0.0
		if cur_speed > 0.001:
			cur_dir_x = vel_x / cur_speed
			cur_dir_y = vel_y / cur_speed

		# Commitment: direction locked for a few ticks after big turns / chase commits
		# Skip commitment when very close to target - need precision, not momentum
		var commit: int = int(gs.get("commit_ticks", 0))
		if commit > 0 and dist > LOOSE_BALL_RANGE:
			gs["commit_ticks"] = commit - 1
			# Maintain current direction, reduce speed
			var commit_speed: float = lerpf(cur_speed, desired_speed * COMMIT_SPEED_FACTOR, DECEL_RATE)
			if cur_speed > 0.001:
				vel_x = cur_dir_x * commit_speed
				vel_y = cur_dir_y * commit_speed
			else:
				vel_x = desired_dir_x * commit_speed
				vel_y = desired_dir_y * commit_speed
		elif dist > ARRIVAL_RADIUS:
			# Clear stale commitment when close to target
			if commit > 0:
				gs["commit_ticks"] = 0
			# Direction change detection (only when far enough to matter)
			var dot: float = cur_dir_x * desired_dir_x + cur_dir_y * desired_dir_y
			if dot < DIRECTION_CHANGE_THRESHOLD and cur_speed > 0.003 and dist > LOOSE_BALL_RANGE:
				# Big turn: set commitment and start braking
				gs["commit_ticks"] = COMMIT_TICKS_ON_TURN
				var brake_speed: float = lerpf(cur_speed, desired_speed * COMMIT_SPEED_FACTOR, DECEL_RATE)
				vel_x = cur_dir_x * brake_speed
				vel_y = cur_dir_y * brake_speed
			else:
				# Steer toward desired direction
				var new_dir_x: float = lerpf(cur_dir_x, desired_dir_x, STEER_RATE)
				var new_dir_y: float = lerpf(cur_dir_y, desired_dir_y, STEER_RATE)
				var new_dir_len: float = sqrt(new_dir_x * new_dir_x + new_dir_y * new_dir_y)
				if new_dir_len > 0.001:
					new_dir_x /= new_dir_len
					new_dir_y /= new_dir_len
				# Accelerate / decelerate
				var rate: float = ACCEL_RATE if desired_speed >= cur_speed else DECEL_RATE
				var new_speed: float = lerpf(cur_speed, desired_speed, rate)
				vel_x = new_dir_x * new_speed
				vel_y = new_dir_y * new_speed
		else:
			# At target: decelerate to stop
			vel_x = lerpf(vel_x, 0.0, DECEL_RATE)
			vel_y = lerpf(vel_y, 0.0, DECEL_RATE)

		# Apply velocity to position
		var new_x: float = _gf(gs, "x") + vel_x
		var new_y: float = _gf(gs, "y") + vel_y

		# Snap to target if very close (prevents orbiting)
		if dist > 0.001 and dist <= sqrt(vel_x * vel_x + vel_y * vel_y) + 0.001:
			new_x = _gf(gs, "ideal_x")
			new_y = _gf(gs, "ideal_y")
			vel_x = 0.0
			vel_y = 0.0

		# Clamp to pitch + zero velocity into walls
		var clamped_x: float = clampf(new_x, 0.02, 0.98)
		var clamped_y: float = clampf(new_y, 0.05, 0.95)
		if clamped_x != new_x:
			vel_x = 0.0
		if clamped_y != new_y:
			vel_y = 0.0
		gs["x"] = clamped_x
		gs["y"] = clamped_y
		gs["vel_x"] = vel_x
		gs["vel_y"] = vel_y

		# Update facing
		if absf(vel_x) > 0.001:
			gs["facing"] = 1.0 if vel_x > 0 else -1.0

	# Separation: push apart same-team goblins that are too close
	var all_goblins: Array = goblin_states.keys()
	for i in all_goblins.size():
		for j in range(i + 1, all_goblins.size()):
			var ga: GoblinData = all_goblins[i]
			var gb_gob: GoblinData = all_goblins[j]
			var gsa: Dictionary = goblin_states[ga]
			var gsb: Dictionary = goblin_states[gb_gob]

			if _gb(gsa, "is_home") != _gb(gsb, "is_home"):
				continue

			var sep_dx: float = _gf(gsa, "x") - _gf(gsb, "x")
			var sep_dy: float = _gf(gsa, "y") - _gf(gsb, "y")
			var sep_dist: float = sqrt(sep_dx * sep_dx + sep_dy * sep_dy)

			if sep_dist < SEPARATION_DIST and sep_dist > 0.001:
				var overlap: float = SEPARATION_DIST - sep_dist
				var push: float = overlap * SEPARATION_FORCE / sep_dist
				var resist_a: float = float(ga.get_stat("strength")) * 0.60 + float(ga.get_stat("defense")) * 0.40
				var resist_b: float = float(gb_gob.get_stat("strength")) * 0.60 + float(gb_gob.get_stat("defense")) * 0.40
				var total_resist: float = maxf(1.0, resist_a + resist_b)
				var a_share: float = resist_b / total_resist
				var b_share: float = resist_a / total_resist
				# Push positions
				gsa["x"] = clampf(_gf(gsa, "x") + sep_dx * push * a_share, 0.02, 0.98)
				gsa["y"] = clampf(_gf(gsa, "y") + sep_dy * push * a_share, 0.05, 0.95)
				gsb["x"] = clampf(_gf(gsb, "x") - sep_dx * push * b_share, 0.02, 0.98)
				gsb["y"] = clampf(_gf(gsb, "y") - sep_dy * push * b_share, 0.05, 0.95)
				# Also nudge velocity so separation feels physical
				var vel_push: float = push * 0.3
				gsa["vel_x"] = _gf(gsa, "vel_x") + sep_dx * vel_push * a_share
				gsa["vel_y"] = _gf(gsa, "vel_y") + sep_dy * vel_push * a_share
				gsb["vel_x"] = _gf(gsb, "vel_x") - sep_dx * vel_push * b_share
				gsb["vel_y"] = _gf(gsb, "vel_y") - sep_dy * vel_push * b_share

	# Hard clamp keeper positions - stay between the posts, on the line
	for goblin3 in goblin_states:
		if goblin3.position == "keeper":
			var kgs2: Dictionary = goblin_states[goblin3]
			var kh_x: float = _gf(kgs2, "home_x")
			kgs2["y"] = clampf(_gf(kgs2, "y"), 0.38, 0.62)
			kgs2["x"] = clampf(_gf(kgs2, "x"), kh_x - 0.015, kh_x + 0.015)

# ── Kickoff Reset ───────────────────────────────────────────────────────────

func _reset_positions_for_kickoff(kicking_team_idx: int) -> void:
	_active_runs.clear()
	_action_targets.clear()
	_carrier_target.clear()
	_move_targets.clear()
	_clear_ball_intent()
	_apply_kickoff_reset(home_formation, true)
	_apply_kickoff_reset(away_formation, false)

	var is_home_kicking: bool = kicking_team_idx == 0
	var formation: Formation = home_formation if is_home_kicking else away_formation
	var fwd: float = 1.0 if is_home_kicking else -1.0
	var mids := formation.midfield
	if not mids.is_empty():
		var kicker: GoblinData = mids[0]
		_give_ball_control(kicker, 0.5, 0.5, false)
		var kgs: Dictionary = goblin_states[kicker]
		kgs["x"] = 0.5
		kgs["y"] = 0.5
		kgs["ideal_x"] = 0.5
		kgs["ideal_y"] = 0.5
		kgs["roam_x"] = 0.5
		kgs["roam_y"] = 0.5
		kgs["support_x"] = 0.5
		kgs["support_y"] = 0.5

		# Find outlet: prefer 2nd midfielder, fallback to nearest attacker
		var outlet: GoblinData = null
		if mids.size() > 1:
			outlet = mids[1]
		else:
			var attackers := formation.attack
			if not attackers.is_empty():
				outlet = attackers[0]
		if outlet and goblin_states.has(outlet):
			# Position outlet just behind center on own half as a short-pass option
			var ogs: Dictionary = goblin_states[outlet]
			var outlet_x: float = clampf(0.5 - fwd * 0.04, 0.10, 0.90)
			var outlet_y: float = clampf(0.5 + randf_range(-0.08, 0.08), 0.15, 0.85)
			ogs["x"] = outlet_x
			ogs["y"] = outlet_y
			ogs["ideal_x"] = outlet_x
			ogs["ideal_y"] = outlet_y
			ogs["roam_x"] = outlet_x
			ogs["roam_y"] = outlet_y
			ogs["support_x"] = outlet_x
			ogs["support_y"] = outlet_y

		# Set kickoff hold state
		_kickoff_hold_ticks = KICKOFF_HOLD_DURATION
		_kickoff_kicker = kicker
		_kickoff_outlet = outlet
	else:
		ball.set_dead(0.5, 0.5)
		_kickoff_hold_ticks = 0
		_kickoff_kicker = null
		_kickoff_outlet = null

func _execute_kickoff_pass() -> void:
	if _kickoff_kicker == null or not goblin_states.has(_kickoff_kicker):
		_kickoff_kicker = null
		_kickoff_outlet = null
		return
	if _kickoff_outlet == null or not goblin_states.has(_kickoff_outlet):
		# No outlet - just let the kicker play on
		_kickoff_kicker = null
		_kickoff_outlet = null
		return
	var ogs: Dictionary = goblin_states[_kickoff_outlet]
	var decision := GoblinAI.Decision.new(
		GoblinAI.Action.PASS,
		_gf(ogs, "x"),
		_gf(ogs, "y"),
		_kickoff_outlet
	)
	_execute_pass(_kickoff_kicker, decision)
	_tick_events.append({"type": "kickoff_pass", "from": _kickoff_kicker.goblin_name, "to": _kickoff_outlet.goblin_name})
	_kickoff_kicker = null
	_kickoff_outlet = null

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

	if ball.owner and goblin_states.has(ball.owner):
		var owner_gs: Dictionary = goblin_states[ball.owner]
		ctx.team_has_ball = _gb(owner_gs, "is_home") == _gb(gs, "is_home")
	else:
		ctx.team_has_ball = false

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

	var opp_keeper: GoblinData = opp_formation.get_keeper()
	if opp_keeper and goblin_states.has(opp_keeper):
		var kgs: Dictionary = goblin_states[opp_keeper]
		ctx.keeper_x = _gf(kgs, "x")
		ctx.keeper_y = _gf(kgs, "y")
	else:
		ctx.keeper_x = 0.95 if is_home else 0.05
		ctx.keeper_y = 0.5

	ctx.ball_control_time = _gf(gs, "ball_control_time")
	ctx.settle_time = _gf(gs, "settle_time")
	ctx.role = coordinator.get_role(goblin)
	return ctx

# ── Stat Contest ────────────────────────────────────────────────────────────

func _stat_contest(attacker_stat: float, defender_stat: float, atk_chaos: float, def_chaos: float) -> float:
	var base: float = (attacker_stat - defender_stat) / 10.0
	var chaos_range: float = (atk_chaos + def_chaos) * 0.03
	return base + randf_range(-chaos_range, chaos_range)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _dist(x1: float, y1: float, x2: float, y2: float) -> float:
	return sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)

func _distance_to_segment(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var abx: float = bx - ax
	var aby: float = by - ay
	var ab_len_sq: float = abx * abx + aby * aby
	if ab_len_sq <= 0.000001:
		return _dist(px, py, ax, ay)
	var t: float = ((px - ax) * abx + (py - ay) * aby) / ab_len_sq
	t = clampf(t, 0.0, 1.0)
	var cx: float = ax + abx * t
	var cy: float = ay + aby * t
	return _dist(px, py, cx, cy)

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
		"fireball_available": fireball_available[0],
		"haste_available": haste_available[0],
		"multiball_available": multiball_available[0],
		"haste_active": _haste_ticks[0] > 0,
		"extra_balls": _extra_balls.map(func(e): return {"x": (e["ball"] as Ball).x, "y": (e["ball"] as Ball).y}),
		"mana": mana.duplicate(),
	}
