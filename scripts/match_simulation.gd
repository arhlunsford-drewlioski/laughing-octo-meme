class_name MatchSimulation
extends RefCounted
## Core headless match engine. Ticks 10x/sec, emits state snapshots.
## FM-style: every goblin always moves toward a smoothly-updating ideal position.
## Decisions (pass/shoot/tackle) are instant events on top of continuous movement.

# ── Constants ───────────────────────────────────────────────────────────────

const TICKS_PER_SECOND: float = 10.0
const TICK_DELTA: float = 1.0 / TICKS_PER_SECOND  # 0.1s real time
const MATCH_DURATION: float = 90.0  # match minutes
const MINUTES_PER_TICK: float = 0.08  # ~3 min real-time at default 0.6x speed
const MOVEMENT_SPEED: float = 0.0090  # base jog speed
const SPRINT_MULTIPLIER: float = 1.40  # sprinting - visibly faster than jogging
const PASS_SPEED: float = 0.80  # readable pass speed
const SHOT_SPEED: float = 1.20
const LOOSE_BALL_RANGE: float = 0.09  # close enough to pick up a loose ball
const TACKLE_RANGE: float = 0.055  # tight - must be very close
const CHALLENGE_RANGE: float = 0.075  # wider - shoulder-to-shoulder dribble contests
const SHOT_RANGE: float = 0.30
const PASS_RECEIVE_RADIUS: float = 0.06
const PASS_INTERCEPT_RADIUS: float = 0.04
const PASS_SEGMENT_RADIUS: float = 0.025
const RECEIVE_LOOKAHEAD: float = 0.18
const POSSESSION_PROGRESS_STEP: float = 0.05
const KICKOFF_HOLD_DURATION: int = 10  # 1.0s hold before kickoff pass
const GOAL_CELEBRATION_TICKS: int = 20  # 2.0s celebration freeze after goal

# Velocity / momentum
const ACCEL_RATE: float = 0.32          # lerp toward max speed per tick (weighted, not snappy)
const DECEL_RATE: float = 0.55          # lerp for braking - softer stops
const STEER_RATE: float = 0.28          # lerp for direction change per tick (curves, not snaps)
const DIRECTION_CHANGE_THRESHOLD: float = 0.10  # dot product < this = big turn
const COMMIT_TICKS_ON_TURN: int = 3     # brief slowdown on direction change
const COMMIT_TICKS_CHASE: int = 2       # brief lock for loose ball chaser
const COMMIT_SPEED_FACTOR: float = 0.55 # speed during commitment



# Arrival behavior
const SLOWDOWN_RADIUS: float = 0.06
const ARRIVAL_RADIUS: float = 0.006
const MIN_DRIFT_SPEED: float = 0.0  # no drift - stop cleanly at target
const IDEAL_DEAD_ZONE: float = 0.020  # tight dead zone - goblins react to small offset changes

# Collision / Separation
const SEPARATION_DIST: float = 0.10   # same-team spacing (don't bunch)
const SEPARATION_FORCE: float = 0.06  # soft push for teammates
const COLLISION_RADIUS: float = 0.055 # body radius - goblins can't overlap
const COLLISION_FORCE: float = 0.15   # hard push for opposing players

# Soft Zone Pull (replaces hard zone clamp)
const ZONE_PULL_BASE: float = 0.15           # base spring strength toward zone center
const ZONE_PULL_DISTANCE_SCALE: float = 2.5  # pull grows with distance from zone edge
const ZONE_PULL_MAX: float = 0.70            # cap so pull never fully overrides target
const ZONE_PULL_IN_POSSESSION: float = 0.6   # weaker pull when attacking (spread out)
const ZONE_PULL_OUT_POSSESSION: float = 1.0  # full pull when defending (hold shape)
const ZONE_PULL_FAR_THRESHOLD: float = 0.15  # distance from zone edge where extra pull kicks in
const ZONE_PULL_FAR_MULTIPLIER: float = 1.8  # extra pull when very far from zone

# Carrier Zone Pull (soft rubber band on ball carrier)
const CARRIER_ZONE_PULL_BASE: float = 0.05   # weak base pull
const CARRIER_ZONE_PULL_SCALE: float = 1.8   # pull grows with distance from zone edge
const CARRIER_ZONE_PULL_MAX: float = 0.40    # cap - carrier can still dribble through

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
	2: [0.30, 0.70],
	3: [0.18, 0.50, 0.82],
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

# Possession tracking
var _prev_home_has_ball: bool = false
var _prev_away_has_ball: bool = false
var _possession_team_idx: int = -1
var _team_possession_time: float = 0.0
var _stale_possession_time: float = 0.0
var _possession_progress_anchor_x: float = 0.5

# Transient action targets (consumed by _update_ideal_positions each tick)
var _action_targets: Dictionary = {}
# Persistent carrier target - survives cooldown so carrier keeps moving
var _carrier_target: Dictionary = {}  # {"x": float, "y": float}
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

# Generic buff tracking: [{goblin: GoblinData, stat: String, amount: int, ticks: int, source: String}]
var _active_buffs: Array[Dictionary] = []

# Curse of the Post tracking (per team: how many opponent shots auto-miss)
var _curse_charges: Array[int] = [0, 0]

# Blood Pact targets (goblins that will take post-match injury)
var _blood_pact_targets: Array[GoblinData] = []

# Frenzy active (permanent for rest of match, no tick tracking needed)
var _frenzy_active: Array[bool] = [false, false]

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
	_action_targets.clear()
	_carrier_target.clear()
	_ball_intent.clear()
	_pending_removals.clear()
	fireball_available = [true, false]
	haste_available = [true, false]
	multiball_available = [true, false]
	_haste_ticks = [0, 0]
	_haste_targets = [[], []]
	_extra_balls.clear()
	_active_buffs.clear()
	_curse_charges = [0, 0]
	_blood_pact_targets.clear()
	_frenzy_active = [false, false]
	_kickoff_hold_ticks = 0
	_kickoff_kicker = null
	_kickoff_outlet = null
	_celebration_ticks = 0
	_celebration_scorer = null
	_celebration_kicking_team = -1
	_possession_team_idx = -1
	_team_possession_time = 0.0
	_stale_possession_time = 0.0
	_possession_progress_anchor_x = 0.5

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
				"run_target_x": spawn.x,
				"run_target_y": spawn.y,
				"run_ticks": 0,
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
				"is_left_flank": spawn.y < 0.5,
				"chaos_wander_x": 0.0,
				"chaos_wander_y": 0.0,
				"chaos_wander_ticks": 0,
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
			gs["run_target_x"] = spawn.x
			gs["run_target_y"] = spawn.y
			gs["run_ticks"] = 0
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

	# 3b. Track whether possession is progressing or bogged down.
	_update_possession_flow()

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
			# IDLE gets a short wait to prevent re-evaluating every tick.
			# MOVE_TO_POSITION and action roles (CHASE_BALL, TACKLE) get NO wait
			# so pressers/markers stay responsive.
			var last_action: int = int(gs["action"])
			if last_action == GoblinAI.Action.IDLE:
				gs["decide_wait"] = 0.15  # re-evaluate every 0.15s

	# 5b. Process deferred removals (goblins killed during tackles/spells)
	_process_pending_removals()

	# 6. Update ideal positions for ALL goblins (smooth targets)
	_update_ideal_positions()

	# 7. Move ALL goblins toward their ideal positions (arrival behavior)
	_move_all_goblins()

	# 7b. Proximity challenge: any opponent near the ball carrier can contest
	_check_proximity_challenges()

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

	# 11. Tick generic buffs (Dark Surge, Shadow Wall, Hex, etc.)
	_tick_buffs()

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

func _reset_possession_flow() -> void:
	_possession_team_idx = -1
	_team_possession_time = 0.0
	_stale_possession_time = 0.0
	_possession_progress_anchor_x = ball.x

func _update_possession_flow() -> void:
	if ball.state == Ball.BallState.DEAD:
		_reset_possession_flow()
		return
	if ball.owner == null or not goblin_states.has(ball.owner):
		return

	var owner_gs: Dictionary = goblin_states[ball.owner]
	var team_idx: int = 0 if _gb(owner_gs, "is_home") else 1
	if team_idx != _possession_team_idx:
		_possession_team_idx = team_idx
		_team_possession_time = 0.0
		_stale_possession_time = 0.0
		_possession_progress_anchor_x = ball.x
		return

	_team_possession_time += TICK_DELTA
	var forward_progress: float = ball.x - _possession_progress_anchor_x if team_idx == 0 else _possession_progress_anchor_x - ball.x
	if forward_progress >= POSSESSION_PROGRESS_STEP:
		_possession_progress_anchor_x = ball.x
		_stale_possession_time = maxf(0.0, _stale_possession_time - TICK_DELTA * 2.0)
	else:
		_stale_possession_time += TICK_DELTA

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
			# Transient only - cleared each tick, goblin returns to STATE 7 next tick
			_set_action_target(goblin, decision.target_x, decision.target_y)
		GoblinAI.Action.IDLE:
			pass  # Fall through to STATE 7 (hold position + offsets)

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

	# Curse of the Post: auto-miss the opponent's shot
	var curse_team: int = 1 if is_home else 0  # The team that cast the curse benefits
	if _curse_charges[curse_team] > 0:
		_curse_charges[curse_team] -= 1
		_tick_events.append({"type": "post", "goblin": goblin.goblin_name})
		_tick_events.append({"type": "curse_triggered", "goblin": goblin.goblin_name})
		ball.set_loose(goal_x, randf_range(0.3, 0.7))
		return

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
		if _dist(_gf(gs, "x"), _gf(gs, "y"), _gf(opp_gs, "x"), _gf(opp_gs, "y")) < CHALLENGE_RANGE:
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
	var injury_chance: float = (float(tackler.get_stat("strength")) + float(tackler.get_stat("chaos"))) * 0.022
	if was_foul:
		injury_chance += 0.15
	if tackler.position == "enforcer":
		injury_chance += 0.08
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
	_action_targets.erase(goblin)
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

# ── Generic Buff System ───────────────────────────────────────────────────

func _tick_buffs() -> void:
	var expired_indices: Array[int] = []
	for i in _active_buffs.size():
		var buff: Dictionary = _active_buffs[i]
		if int(buff["ticks"]) <= 0:
			continue  # permanent buff (frenzy)
		buff["ticks"] = int(buff["ticks"]) - 1
		if int(buff["ticks"]) == 0:
			expired_indices.append(i)
			# Remove the effect from the goblin
			var goblin: GoblinData = buff["goblin"] as GoblinData
			var idx_to_remove: int = -1
			for j in goblin.active_effects.size():
				if goblin.active_effects[j].get("stat", "") == buff["stat"] and goblin.active_effects[j].get("amount", 0) == int(buff["amount"]):
					idx_to_remove = j
					break
			if idx_to_remove >= 0:
				goblin.active_effects.remove_at(idx_to_remove)
			var source: String = str(buff.get("source", ""))
			if source != "":
				_tick_events.append({"type": source + "_expired", "goblin": goblin.goblin_name})

	expired_indices.sort()
	expired_indices.reverse()
	for idx in expired_indices:
		_active_buffs.remove_at(idx)

func _apply_buff(goblin: GoblinData, stat_name: String, amount: int, duration_ticks: int, source: String) -> void:
	goblin.active_effects.append({"stat": stat_name, "amount": amount})
	if duration_ticks > 0:
		_active_buffs.append({"goblin": goblin, "stat": stat_name, "amount": amount, "ticks": duration_ticks, "source": source})

# ── New Spell Casts ──────────────────────────────────────────────────────

func cast_dark_surge(team_index: int, target_goblin: GoblinData) -> bool:
	## +3 shooting to one allied goblin for 15 seconds.
	if not goblin_states.has(target_goblin):
		return false
	var duration_ticks: int = 150  # 15 sec at 10 ticks/sec
	_apply_buff(target_goblin, "shooting", 3, duration_ticks, "dark_surge")
	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "dark_surge", "team": team_name, "goblin": target_goblin.goblin_name})
	return true

func cast_shadow_wall(team_index: int) -> bool:
	## +3 defense to all allied goblins for 10 seconds.
	var formation: Formation = home_formation if team_index == 0 else away_formation
	var duration_ticks: int = 100  # 10 sec
	for goblin in formation.get_all():
		if goblin_states.has(goblin):
			_apply_buff(goblin, "defense", 3, duration_ticks, "shadow_wall")
	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "shadow_wall", "team": team_name})
	return true

func cast_hex(team_index: int, target_goblin: GoblinData) -> bool:
	## -2 all stats on one opponent for 30 seconds.
	if not goblin_states.has(target_goblin):
		return false
	var duration_ticks: int = 300  # 30 sec
	for stat_name in GoblinData.STAT_KEYS:
		_apply_buff(target_goblin, stat_name, -2, duration_ticks, "hex")
	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "hex", "team": team_name, "goblin": target_goblin.goblin_name})
	return true

func cast_blood_pact(team_index: int, target_goblin: GoblinData) -> bool:
	## Double shooting (+5) for one goblin. They take injury post-match.
	if not goblin_states.has(target_goblin):
		return false
	# Permanent buff for this match (ticks = 0 means permanent)
	_apply_buff(target_goblin, "shooting", 5, 0, "blood_pact")
	_blood_pact_targets.append(target_goblin)
	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "blood_pact", "team": team_name, "goblin": target_goblin.goblin_name})
	return true

func cast_frenzy(team_index: int) -> bool:
	## All goblins +2 speed +2 shooting -3 defense for rest of match.
	if _frenzy_active[team_index]:
		return false
	_frenzy_active[team_index] = true
	var formation: Formation = home_formation if team_index == 0 else away_formation
	for goblin in formation.get_all():
		if goblin_states.has(goblin):
			_apply_buff(goblin, "speed", 2, 0, "")
			_apply_buff(goblin, "shooting", 2, 0, "")
			_apply_buff(goblin, "defense", -3, 0, "")
	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "frenzy", "team": team_name})
	return true

func cast_curse_of_post(team_index: int) -> bool:
	## Opponent's next shot auto-misses.
	_curse_charges[team_index] += 1
	var team_name: String = "home" if team_index == 0 else "away"
	_tick_events.append({"type": "curse_of_post", "team": team_name})
	return true

func get_blood_pact_targets() -> Array[GoblinData]:
	return _blood_pact_targets

# ── Action Target (transient, consumed by ideal position update) ──────────

func _set_action_target(goblin: GoblinData, tx: float, ty: float) -> void:
	_action_targets[goblin] = {"x": clampf(tx, 0.02, 0.98), "y": clampf(ty, 0.05, 0.95)}

# ── Ideal Position Update ──────────────────────────────────────────────────

func _update_ideal_positions() -> void:
	## Hockey-style positioning: fixed base positions + simple offsets.
	## Every goblin stands at their formation spot unless they have a reason to move.

	# ── Who has the ball? ──
	var home_has_ball: bool = false
	var away_has_ball: bool = false
	if ball.owner and goblin_states.has(ball.owner):
		if _gb(goblin_states[ball.owner], "is_home"):
			home_has_ball = true
		else:
			away_has_ball = true
	var is_loose: bool = ball.state == Ball.BallState.LOOSE or ball.state == Ball.BallState.DEAD

	# Detect turnovers
	var home_lost_ball: bool = _prev_home_has_ball and not home_has_ball and not is_loose
	var away_lost_ball: bool = _prev_away_has_ball and not away_has_ball and not is_loose
	_prev_home_has_ball = home_has_ball
	_prev_away_has_ball = away_has_ball

	# Cancel runs on turnover + sprint-back for track_back / sprint_back_defend
	if home_lost_ball or away_lost_ball:
		for goblin in goblin_states:
			var gs2: Dictionary = goblin_states[goblin]
			var is_h: bool = _gb(gs2, "is_home")
			var lost: bool = (home_lost_ball and is_h) or (away_lost_ball and not is_h)
			if not lost:
				continue
			# Cancel any forward runs
			if int(gs2.get("run_ticks", 0)) > 0:
				gs2["run_ticks"] = 0
			# Tendency: sprint back on turnover
			var td_opp: String = PositionDatabase.get_position(goblin.position).get("tendency_opponent", "")
			if td_opp == "track_back" or td_opp == "sprint_back_defend":
				gs2["sprint_back_ticks"] = 15  # sprint back for 1.5 seconds

	var carrier_x: float = ball.x
	var carrier_y: float = ball.y
	var carrier_is_home: bool = false
	if ball.owner and goblin_states.has(ball.owner):
		var ogs: Dictionary = goblin_states[ball.owner]
		carrier_x = _gf(ogs, "x")
		carrier_y = _gf(ogs, "y")
		carrier_is_home = _gb(ogs, "is_home")

	# Count runners for run trigger cap
	var home_runners: int = 0
	var away_runners: int = 0
	for goblin in goblin_states:
		if int(goblin_states[goblin].get("run_ticks", 0)) > 0:
			if _gb(goblin_states[goblin], "is_home"):
				home_runners += 1
			else:
				away_runners += 1

	# ── Per goblin ──
	for goblin in goblin_states:
		var gs: Dictionary = goblin_states[goblin]
		var is_home: bool = _gb(gs, "is_home")
		var my_team_has_ball: bool = (home_has_ball and is_home) or (away_has_ball and not is_home)
		gs["sprinting"] = false

		# ── STATE 1: Ball carrier (with soft zone pull) ──
		if ball.owner == goblin:
			if goblin.position == "keeper":
				gs["ideal_x"] = _gf(gs, "home_x")
				gs["ideal_y"] = clampf(_gf(gs, "y"), 0.40, 0.60)
			elif _action_targets.has(goblin):
				_carrier_target = _action_targets[goblin].duplicate()
				var cp: Vector2 = _apply_carrier_zone_pull(goblin, gs,
					_gf(_carrier_target, "x"), _gf(_carrier_target, "y"), is_home)
				gs["ideal_x"] = cp.x
				gs["ideal_y"] = cp.y
			elif not _carrier_target.is_empty():
				var cp2: Vector2 = _apply_carrier_zone_pull(goblin, gs,
					_gf(_carrier_target, "x"), _gf(_carrier_target, "y"), is_home)
				gs["ideal_x"] = cp2.x
				gs["ideal_y"] = cp2.y
			else:
				var fwd: float = 1.0 if is_home else -1.0
				gs["ideal_x"] = clampf(_gf(gs, "x") + fwd * 0.15, 0.05, 0.95)
				gs["ideal_y"] = _gf(gs, "y")
			if goblin.position != "keeper":
				gs["sprinting"] = true
			continue

		# ── STATE 2: Pass receiver ──
		if ball.state == Ball.BallState.TRAVELLING and _ball_intent.get("target_goblin", null) == goblin:
			var rt := _get_receive_target()
			gs["ideal_x"] = rt.x
			gs["ideal_y"] = rt.y
			gs["sprinting"] = true
			continue

		# ── STATE 2B: Support runner on pass ──
		# When ball is travelling, 1-2 nearest non-receiver teammates create passing options
		if ball.state == Ball.BallState.TRAVELLING and my_team_has_ball and not _gb(gs, "is_support_runner"):
			var target_g: GoblinData = _ball_intent.get("target_goblin", null)
			if target_g != null and target_g != goblin and goblin.position != "keeper":
				var tgt_x: float = float(_ball_intent.get("target_x", ball.x))
				var tgt_y: float = float(_ball_intent.get("target_y", ball.y))
				var dist_to_tgt: float = sqrt((_gf(gs, "x") - tgt_x) ** 2 + (_gf(gs, "y") - tgt_y) ** 2)
				# Only nearby teammates (within 0.25) who aren't already on a run
				if dist_to_tgt < 0.25 and int(gs.get("run_ticks", 0)) <= 0:
					var p_data: Dictionary = PositionDatabase.get_position(goblin.position)
					var t_own: String = p_data.get("tendency_own_team", "")
					# Filter: formation holders don't support
					if t_own != "block_central" and t_own != "stay_in_goal":
						# Prefer goblins with supportive tendencies
						var is_preferred: bool = t_own in ["fill_gaps", "roam_find_space", "push_attacking_third", "overlap_flank"]
						if is_preferred or dist_to_tgt < 0.15:
							var fwd2: float = 1.0 if is_home else -1.0
							# Even slots: lay-off (ahead + wide), odd: recycle (behind)
							var support_idx: int = goblin.get_instance_id() % 2
							var sup_x: float
							var sup_y: float
							if support_idx % 2 == 0:
								sup_x = tgt_x + fwd2 * 0.10
								sup_y = tgt_y + (0.08 if _gf(gs, "y") > tgt_y else -0.08)
							else:
								sup_x = tgt_x - fwd2 * 0.05
								sup_y = tgt_y
							# Clamp to zone rect
							var s_in_poss: bool = my_team_has_ball and not is_loose
							var s_rect: Array = PositionDatabase.get_zone_rect_flipped(
								goblin.position, s_in_poss, is_home, _gb(gs, "is_left_flank"))
							gs["ideal_x"] = clampf(sup_x, float(s_rect[0]), float(s_rect[1]))
							gs["ideal_y"] = clampf(sup_y, float(s_rect[2]), float(s_rect[3]))
							gs["is_support_runner"] = true
							# Don't sprint - positional adjustment, not a run
							continue
		gs["is_support_runner"] = false

		# ── STATE 3: Active roles - computed directly every tick ──
		# These bypass action_targets (which only last 1 tick and cause oscillation)
		var goblin_role: int = coordinator.get_role(goblin)

		# LOOSE_CHASER: sprint directly at the ball - no zone restriction
		if goblin_role == TeamCoordinator.Role.LOOSE_CHASER:
			gs["ideal_x"] = ball.x
			gs["ideal_y"] = ball.y
			gs["sprinting"] = true
			continue

		# Nearby goblins also chase loose balls (not just the designated chaser)
		if is_loose and goblin.position != "keeper":
			var dist_to_loose: float = sqrt((_gf(gs, "x") - ball.x) ** 2 + (_gf(gs, "y") - ball.y) ** 2)
			if dist_to_loose < 0.15:
				gs["ideal_x"] = ball.x
				gs["ideal_y"] = ball.y
				gs["sprinting"] = true
				continue

		# PRESSER: chase ball carrier - zone expands toward ball in post-movement clamp
		if goblin_role == TeamCoordinator.Role.PRESSER and not my_team_has_ball:
			gs["ideal_x"] = ball.x
			gs["ideal_y"] = ball.y
			gs["sprinting"] = true
			continue

		# AI action targets (for dribble targets, pass targets, etc.)
		if _action_targets.has(goblin):
			gs["ideal_x"] = _gf(_action_targets[goblin], "x")
			gs["ideal_y"] = _gf(_action_targets[goblin], "y")
			gs["sprinting"] = true
			continue

		# ── STATE 3B: Sweeper through-ball interception ──
		# Sweepers with intercept_through_balls tendency can break zone to cut out passes
		if ball.state == Ball.BallState.TRAVELLING and not my_team_has_ball:
			var sw_tend: String = PositionDatabase.get_position(goblin.position).get("tendency_opponent", "")
			if sw_tend == "intercept_through_balls":
				# Check if ball is heading toward our defensive zone
				var ball_heading_home: bool = (is_home and ball.vx < -0.01) or (not is_home and ball.vx > 0.01)
				if ball_heading_home:
					# Find nearest point on ball trajectory that we can reach
					var ball_future_x: float = ball.x + ball.vx * 3.0  # 3 ticks ahead
					var ball_future_y: float = ball.y + ball.vy * 3.0
					var intercept_dist: float = sqrt(
						(_gf(gs, "x") - ball_future_x) ** 2 +
						(_gf(gs, "y") - ball_future_y) ** 2)
					if intercept_dist < 0.18:  # close enough to intercept
						gs["ideal_x"] = ball_future_x
						gs["ideal_y"] = ball_future_y
						gs["sprinting"] = true
						continue

		# ── STATE 4: Tactical run (ticking down) ──
		var run_ticks: int = int(gs.get("run_ticks", 0))
		if run_ticks > 0:
			gs["run_ticks"] = run_ticks - 1
			gs["ideal_x"] = _gf(gs, "run_target_x")
			gs["ideal_y"] = _gf(gs, "run_target_y")
			gs["sprinting"] = true
			continue

		# ── STATE 5: Check if a new run should start ──
		var team_runners: int = home_runners if is_home else away_runners
		if goblin.position != "keeper" and my_team_has_ball and not is_loose and team_runners < 2 and carrier_is_home == is_home:
			if _check_run_trigger(goblin, gs, is_home, carrier_x, carrier_y):
				if is_home: home_runners += 1
				else: away_runners += 1
				gs["sprinting"] = true
				continue

		# ── STATE 5B: Sprint back on turnover (track_back / sprint_back_defend) ──
		var sprint_back: int = int(gs.get("sprint_back_ticks", 0))
		if sprint_back > 0:
			gs["sprint_back_ticks"] = sprint_back - 1
			# Use out-of-possession rect (defensive position)
			var sb_rect: Array = PositionDatabase.get_zone_rect_flipped(
				goblin.position, false, is_home, _gb(gs, "is_left_flank"))
			var sb_cx: float = (float(sb_rect[0]) + float(sb_rect[1])) * 0.5
			var sb_cy: float = (float(sb_rect[2]) + float(sb_rect[3])) * 0.5
			gs["ideal_x"] = sb_cx
			gs["ideal_y"] = sb_cy
			gs["sprinting"] = true
			continue

		# ── STATE 6: FORMATION POSITIONING ──
		# Pure lerp: target = lerp(home_position, ball_position, weight)
		# No zone rects. No clamping. The lerp weight IS the leash.
		# This is what FM and every shipped 2D football game uses.
		if goblin.position == "keeper":
			gs["ideal_x"] = _gf(gs, "home_x")
			gs["ideal_y"] = clampf(lerpf(0.5, ball.y, 0.25), 0.38, 0.62)
		else:
			var home_x: float = _gf(gs, "home_x")
			var home_y: float = _gf(gs, "home_y")

			# Weight determines how much the goblin shifts toward the ball
			# Higher = closer to ball, lower = stays near home position
			var weight: float
			if my_team_has_ball and not is_loose:
				# IN POSSESSION: hold shape, create passing options
				weight = 0.10
			else:
				# DEFENDING: compress toward ball as a team
				var pos_zone: String = PositionDatabase.get_zone(goblin.position)
				match pos_zone:
					"defense":
						weight = 0.20  # defenders shift slightly
					"midfield":
						weight = 0.30  # midfielders shift more
					"attack":
						weight = 0.15  # attackers stay high, don't track back much
					_:
						weight = 0.20

			gs["ideal_x"] = lerpf(home_x, ball.x, weight)
			gs["ideal_y"] = lerpf(home_y, ball.y, weight)

		# Sprint back if far from target (recovery runs)
		var dist_to_target: float = sqrt(
			(_gf(gs, "x") - _gf(gs, "ideal_x")) ** 2 +
			(_gf(gs, "y") - _gf(gs, "ideal_y")) ** 2)
		if dist_to_target > 0.12:
			gs["sprinting"] = true

	_action_targets.clear()

func _check_run_trigger(goblin: GoblinData, gs: Dictionary, is_home: bool,
		carrier_x: float, carrier_y: float) -> bool:
	## Contextual run trigger: runs happen at tactically appropriate moments into real space.
	var zone: String = PositionDatabase.get_zone(goblin.position)
	if zone != "attack" and zone != "midfield":
		return false

	var fwd: float = 1.0 if is_home else -1.0
	var speed: float = float(goblin.get_stat("speed"))
	var gx: float = _gf(gs, "x")
	var gy: float = _gf(gs, "y")

	# Base chance: much lower than before, boosted by context
	var base_chance: float = 0.008 if zone == "attack" else 0.004

	# Context multipliers
	var mult: float = 1.0
	# Carrier facing runner's side of pitch
	var carrier_to_runner_x: float = (gx - carrier_x) * fwd
	if carrier_to_runner_x > 0.05:
		mult *= 2.0
	# Carrier under pressure (nearest opponent within 0.15)
	var carrier_pressured: bool = false
	for opp in goblin_states:
		if _gb(goblin_states[opp], "is_home") == is_home:
			continue
		var odist: float = sqrt((_gf(goblin_states[opp], "x") - carrier_x) ** 2 + (_gf(goblin_states[opp], "y") - carrier_y) ** 2)
		if odist < 0.15:
			carrier_pressured = true
			break
	if carrier_pressured:
		mult *= 1.5
	# Speed bonus
	if speed >= 6.0:
		mult *= 1.3
	# Tendency bonus
	var pos_data: Dictionary = PositionDatabase.get_position(goblin.position)
	var tend_own: String = pos_data.get("tendency_own_team", "")
	if tend_own == "hold_high_line":
		mult *= 1.5
	elif tend_own == "lurk_last_defender":
		# Poacher: only run when near last defender - handled via space finding below
		mult *= 0.8

	if randf() >= base_chance * mult:
		return false

	# Calculate run direction: find space between defenders
	var goal_x: float = (1.0 if is_home else 0.0)
	var opp_defenders: Array = []
	for opp in goblin_states:
		var ogs: Dictionary = goblin_states[opp]
		if _gb(ogs, "is_home") == is_home:
			continue
		var opp_zone: String = PositionDatabase.get_zone(opp.position)
		if opp_zone == "defense" or opp_zone == "goal":
			opp_defenders.append({"x": _gf(ogs, "x"), "y": _gf(ogs, "y")})

	var run_y: float = gy
	if opp_defenders.size() >= 2:
		# Find the largest gap between defenders (sorted by y)
		opp_defenders.sort_custom(func(a, b): return a["y"] < b["y"])
		var best_gap: float = 0.0
		var best_mid_y: float = gy
		for i in range(opp_defenders.size() - 1):
			var gap: float = opp_defenders[i + 1]["y"] - opp_defenders[i]["y"]
			if gap > best_gap:
				best_gap = gap
				best_mid_y = (opp_defenders[i]["y"] + opp_defenders[i + 1]["y"]) * 0.5
		# Also check edges
		if opp_defenders[0]["y"] > best_gap:
			best_gap = opp_defenders[0]["y"]
			best_mid_y = opp_defenders[0]["y"] * 0.3
		var edge_gap: float = 1.0 - opp_defenders[-1]["y"]
		if edge_gap > best_gap:
			best_mid_y = opp_defenders[-1]["y"] + edge_gap * 0.7
		run_y = lerpf(gy, best_mid_y, 0.6)
	else:
		run_y = gy + randf_range(-0.06, 0.06)

	# Tendency: wingers run along touchline
	if tend_own == "hug_touchline" or tend_own == "overlap_flank":
		run_y = _gf(gs, "home_y")  # stay on their flank

	var run_x: float
	if zone == "attack":
		run_x = lerpf(gx, goal_x, 0.40)
	else:
		run_x = gx + fwd * 0.15

	# Clamp to in-possession zone rect
	var is_left: bool = _gb(gs, "is_left_flank")
	var rect: Array = PositionDatabase.get_zone_rect_flipped(
		goblin.position, true, is_home, is_left)
	run_x = clampf(run_x, float(rect[0]), float(rect[1]))
	run_y = clampf(run_y, float(rect[2]), float(rect[3]))

	# Passing lane validation: abort if no clear lane from carrier to run target
	var lane_blocked: bool = false
	for opp in goblin_states:
		if _gb(goblin_states[opp], "is_home") == is_home:
			continue
		var ox: float = _gf(goblin_states[opp], "x")
		var oy: float = _gf(goblin_states[opp], "y")
		# Only check opponents between carrier and run target
		var min_x: float = minf(carrier_x, run_x)
		var max_x: float = maxf(carrier_x, run_x)
		if ox >= min_x - 0.03 and ox <= max_x + 0.03:
			var seg_dist: float = _distance_to_segment(ox, oy, carrier_x, carrier_y, run_x, run_y)
			if seg_dist < 0.06:
				# Try shifting run laterally
				var alt_y: float = run_y + (0.10 if run_y < 0.5 else -0.10)
				alt_y = clampf(alt_y, float(rect[2]), float(rect[3]))
				var alt_dist: float = _distance_to_segment(ox, oy, carrier_x, carrier_y, run_x, alt_y)
				if alt_dist < 0.06:
					lane_blocked = true
					break
				else:
					run_y = alt_y
				break
	if lane_blocked:
		return false

	gs["run_target_x"] = run_x
	gs["run_target_y"] = run_y
	gs["run_ticks"] = randi_range(12, 20) if zone == "attack" else randi_range(10, 16)
	gs["ideal_x"] = run_x
	gs["ideal_y"] = run_y
	return true

func _apply_carrier_zone_pull(goblin: GoblinData, gs: Dictionary,
		target_x: float, target_y: float, is_home: bool) -> Vector2:
	## Soft rubber-band pull on ball carrier toward their zone center.
	## Weak enough to allow dribbling through midfield, strong enough to prevent
	## running to the corner and camping there.
	var is_left: bool = _gb(gs, "is_left_flank")
	var rect: Array = PositionDatabase.get_zone_rect_flipped(
		goblin.position, true, is_home, is_left)  # always use in-possession rect
	var zone_cx: float = (float(rect[0]) + float(rect[1])) * 0.5
	var zone_cy: float = (float(rect[2]) + float(rect[3])) * 0.5

	# How far is the target from the zone edge?
	var clamped_x: float = clampf(target_x, float(rect[0]), float(rect[1]))
	var clamped_y: float = clampf(target_y, float(rect[2]), float(rect[3]))
	var dx_out: float = target_x - clamped_x
	var dy_out: float = target_y - clamped_y
	var dist_outside: float = sqrt(dx_out * dx_out + dy_out * dy_out)

	if dist_outside < 0.001:
		return Vector2(target_x, target_y)  # inside zone, no pull

	var pull: float = CARRIER_ZONE_PULL_BASE + dist_outside * CARRIER_ZONE_PULL_SCALE
	pull = minf(pull, CARRIER_ZONE_PULL_MAX)

	var pulled_x: float = lerpf(target_x, zone_cx, pull)
	var pulled_y: float = lerpf(target_y, zone_cy, pull)
	return Vector2(clampf(pulled_x, 0.02, 0.98), clampf(pulled_y, 0.05, 0.95))

func _get_receive_target() -> Vector2:
	var lead_x: float = ball.x + ball.vx * RECEIVE_LOOKAHEAD
	var lead_y: float = ball.y + ball.vy * RECEIVE_LOOKAHEAD
	var target_x: float = float(_ball_intent.get("target_x", lead_x))
	var target_y: float = float(_ball_intent.get("target_y", lead_y))
	return Vector2(
		clampf(lerpf(lead_x, target_x, 0.4), 0.02, 0.98),
		clampf(lerpf(lead_y, target_y, 0.4), 0.05, 0.95)
	)

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

func _check_proximity_challenges() -> void:
	## Every tick: any opponent close to the ball carrier gets a tackle contest.
	## This is the main mechanic for possession changes in real football games.
	if ball.state != Ball.BallState.CONTROLLED or ball.owner == null:
		return
	if not goblin_states.has(ball.owner):
		return
	var carrier: GoblinData = ball.owner
	var carrier_gs: Dictionary = goblin_states[carrier]
	var cx: float = _gf(carrier_gs, "x")
	var cy: float = _gf(carrier_gs, "y")
	var is_home: bool = _gb(carrier_gs, "is_home")

	# Check all opponents for proximity
	var opp_formation: Formation = away_formation if is_home else home_formation
	for opp in opp_formation.get_all():
		if not goblin_states.has(opp):
			continue
		var opp_gs: Dictionary = goblin_states[opp]
		if _gf(opp_gs, "cooldown") > 0.0:
			continue
		if opp.position == "keeper":
			continue
		var dist: float = _dist(_gf(opp_gs, "x"), _gf(opp_gs, "y"), cx, cy)
		if dist < CHALLENGE_RANGE:
			# Proximity contest: defender vs carrier
			var def_stat: float = opp.get_stat("defense") + opp.get_stat("strength") * 0.4
			var carry_stat: float = carrier.get_stat("speed") * 0.6 + carrier.get_stat("strength") * 0.4
			var result: float = _stat_contest(def_stat, carry_stat,
				float(opp.get_stat("chaos")), float(carrier.get_stat("chaos")))
			if result > 0.05:  # defender wins
				_clear_ball_intent()
				ball.set_loose(cx, cy)
				_tick_events.append({"type": "dispossessed", "goblin": carrier.goblin_name, "by": opp.goblin_name})
				opp_gs["cooldown"] = 0.3
				_roll_tackle_injury(opp, carrier, false)
				return  # one challenge per tick max
			else:
				# Carrier keeps ball but defender is committed
				opp_gs["cooldown"] = 0.4

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
				# Steer toward desired direction (fast goblins turn quicker)
				var speed_stat: float = float(goblin.get_stat("speed"))
				var steer: float = STEER_RATE + (0.06 if speed_stat >= 7.0 else 0.0)
				var new_dir_x: float = lerpf(cur_dir_x, desired_dir_x, steer)
				var new_dir_y: float = lerpf(cur_dir_y, desired_dir_y, steer)
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

		# No zone clamping - lerp weight in STATE 6 is the only leash

		# Update facing: moving = face movement direction, still = face the ball
		if absf(vel_x) > 0.001:
			gs["facing"] = 1.0 if vel_x > 0 else -1.0
		else:
			var ball_dx: float = ball.x - _gf(gs, "x")
			if absf(ball_dx) > 0.02:
				gs["facing"] = 1.0 if ball_dx > 0 else -1.0

	# Collision: ALL goblins have physical bodies - no overlapping, both teams.
	# Same-team = soft separation (maintain spacing). Opposing = hard collision (shoulder to shoulder).
	var all_goblins: Array = goblin_states.keys()
	for i in all_goblins.size():
		for j in range(i + 1, all_goblins.size()):
			var ga: GoblinData = all_goblins[i]
			var gb_gob: GoblinData = all_goblins[j]
			var gsa: Dictionary = goblin_states[ga]
			var gsb: Dictionary = goblin_states[gb_gob]

			var sep_dx: float = _gf(gsa, "x") - _gf(gsb, "x")
			var sep_dy: float = _gf(gsa, "y") - _gf(gsb, "y")
			var sep_dist: float = sqrt(sep_dx * sep_dx + sep_dy * sep_dy)
			var same_team: bool = _gb(gsa, "is_home") == _gb(gsb, "is_home")

			# Same team: soft separation at wider distance (don't bunch)
			# Opposing: hard collision at body radius (can't walk through)
			var collision_dist: float = SEPARATION_DIST if same_team else COLLISION_RADIUS
			var push_strength: float = SEPARATION_FORCE if same_team else COLLISION_FORCE

			if sep_dist < collision_dist and sep_dist > 0.001:
				var overlap: float = collision_dist - sep_dist
				var push: float = overlap * push_strength / sep_dist

				# Strength determines who gives ground
				var resist_a: float = float(ga.get_stat("strength")) * 0.60 + float(ga.get_stat("defense")) * 0.40
				var resist_b: float = float(gb_gob.get_stat("strength")) * 0.60 + float(gb_gob.get_stat("defense")) * 0.40
				# Ball carrier is harder to push
				if ball.owner == ga:
					resist_a *= 1.5
				elif ball.owner == gb_gob:
					resist_b *= 1.5
				var total_resist: float = maxf(1.0, resist_a + resist_b)
				var a_share: float = resist_b / total_resist
				var b_share: float = resist_a / total_resist

				# Hard position correction (no overlap allowed)
				gsa["x"] = clampf(_gf(gsa, "x") + sep_dx * push * a_share, 0.02, 0.98)
				gsa["y"] = clampf(_gf(gsa, "y") + sep_dy * push * a_share, 0.05, 0.95)
				gsb["x"] = clampf(_gf(gsb, "x") - sep_dx * push * b_share, 0.02, 0.98)
				gsb["y"] = clampf(_gf(gsb, "y") - sep_dy * push * b_share, 0.05, 0.95)

				# Velocity bounce - players physically bump off each other
				var vel_push: float = push * (0.5 if not same_team else 0.3)
				gsa["vel_x"] = _gf(gsa, "vel_x") + sep_dx * vel_push * a_share
				gsa["vel_y"] = _gf(gsa, "vel_y") + sep_dy * vel_push * a_share
				gsb["vel_x"] = _gf(gsb, "vel_x") - sep_dx * vel_push * b_share
				gsb["vel_y"] = _gf(gsb, "vel_y") - sep_dy * vel_push * b_share

				# Collision aggression: high-chaos goblins hurt opponents on contact
				if not same_team:
					var chaos_a: float = float(ga.get_stat("chaos"))
					var chaos_b: float = float(gb_gob.get_stat("chaos"))
					if chaos_a >= 6.0 and randf() < chaos_a * 0.006:
						_roll_tackle_injury(ga, gb_gob, false)
					if chaos_b >= 6.0 and randf() < chaos_b * 0.006:
						_roll_tackle_injury(gb_gob, ga, false)

	# Hard clamp keeper positions - stay between the posts, on the line
	for goblin3 in goblin_states:
		if goblin3.position == "keeper":
			var kgs2: Dictionary = goblin_states[goblin3]
			var kh_x: float = _gf(kgs2, "home_x")
			kgs2["y"] = clampf(_gf(kgs2, "y"), 0.38, 0.62)
			kgs2["x"] = clampf(_gf(kgs2, "x"), kh_x - 0.015, kh_x + 0.015)

# ── Kickoff Reset ───────────────────────────────────────────────────────────

func _reset_positions_for_kickoff(kicking_team_idx: int) -> void:
	_action_targets.clear()
	_carrier_target.clear()
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
		kgs["run_ticks"] = 0

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
			ogs["run_ticks"] = 0

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

	# Zone rect for leash checks (presser zone restriction)
	var is_left: bool = _gb(gs, "is_left_flank")
	ctx.zone_rect = PositionDatabase.get_zone_rect_flipped(
		goblin.position, ctx.team_has_ball, _gb(gs, "is_home"), is_left)

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
	if ctx.team_has_ball and _possession_team_idx == (0 if is_home else 1):
		ctx.team_possession_time = _team_possession_time
		ctx.stale_possession_time = _stale_possession_time

	# Tendency data from position database
	var pos_data: Dictionary = PositionDatabase.get_position(goblin.position)
	ctx.tendency_with_ball = pos_data.get("tendency_with_ball", "")
	ctx.tendency_own_team = pos_data.get("tendency_own_team", "")
	ctx.tendency_opponent = pos_data.get("tendency_opponent", "")

	# Teammate run states (for through-ball targeting)
	ctx.teammate_run_states = {}
	for t in my_formation.get_all():
		if goblin_states.has(t):
			var rt: int = int(goblin_states[t].get("run_ticks", 0))
			if rt > 0:
				ctx.teammate_run_states[t] = rt
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
		"curse_charges": _curse_charges.duplicate(),
		"frenzy_active": _frenzy_active.duplicate(),
	}
