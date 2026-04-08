class_name Ball
extends RefCounted
## Ball with velocity-based physics. Position normalized 0.0-1.0.

enum BallState { CONTROLLED, LOOSE, TRAVELLING, DEAD }

var x: float = 0.5
var y: float = 0.5
var state: BallState = BallState.DEAD
var owner: GoblinData = null

# Velocity (normalized units per second)
var vx: float = 0.0
var vy: float = 0.0

# Physics constants
const GROUND_FRICTION: float = 0.88      # per-tick decay (retains 28% after 1 sec, stops in ~2s)
const THROUGH_BALL_FRICTION: float = 0.92 # runs a bit further
const SHOT_FRICTION: float = 0.90         # fast initial, stops in ~2.5s
const MIN_SPEED: float = 0.01             # below this, ball stops
const WALL_BOUNCE: float = 0.5            # velocity retained on wall bounce

# LOOSE state
var loose_timer: float = 0.0
const LOOSE_TIMEOUT: float = 4.0
var _friction: float = GROUND_FRICTION

# ── State Transitions ───────────────────────────────────────────────────────

func set_controlled(goblin: GoblinData, gx: float, gy: float) -> void:
	state = BallState.CONTROLLED
	owner = goblin
	x = gx
	y = gy
	vx = 0.0
	vy = 0.0
	loose_timer = 0.0

func set_loose(lx: float, ly: float) -> void:
	state = BallState.LOOSE
	owner = null
	x = lx
	y = ly
	# Keep existing velocity (ball rolls away from tackle/dispossession)
	loose_timer = LOOSE_TIMEOUT
	_friction = GROUND_FRICTION

func set_kicked(from_x: float, from_y: float, to_x: float, to_y: float, speed: float, friction: float = GROUND_FRICTION) -> void:
	## Kick ball with velocity toward target point at given speed.
	state = BallState.TRAVELLING
	owner = null
	x = from_x
	y = from_y
	var dx: float = to_x - from_x
	var dy: float = to_y - from_y
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist > 0.001:
		vx = (dx / dist) * speed
		vy = (dy / dist) * speed
	else:
		vx = 0.0
		vy = 0.0
	_friction = friction

func set_dead(dx: float, dy: float) -> void:
	state = BallState.DEAD
	owner = null
	x = dx
	y = dy
	vx = 0.0
	vy = 0.0
	loose_timer = 0.0

# Compatibility: old code calls set_travelling, redirect to set_kicked
func set_travelling(from_x: float, from_y: float, to_x: float, to_y: float, spd: float = 0.8) -> void:
	set_kicked(from_x, from_y, to_x, to_y, spd, GROUND_FRICTION)

# ── Tick Update ─────────────────────────────────────────────────────────────

## Returns true if ball has slowed to a stop (TRAVELLING -> needs resolution)
func update(delta: float) -> bool:
	match state:
		BallState.TRAVELLING:
			# Apply velocity
			x += vx * delta
			y += vy * delta
			# Apply friction
			vx *= _friction
			vy *= _friction
			# Bounce off walls
			_bounce_walls()
			# Check if stopped
			var speed: float = sqrt(vx * vx + vy * vy)
			if speed < MIN_SPEED:
				vx = 0.0
				vy = 0.0
				return true  # ball stopped - needs receiver check
			return false
		BallState.LOOSE:
			# Loose ball still has momentum (rolls)
			x += vx * delta
			y += vy * delta
			vx *= _friction
			vy *= _friction
			if sqrt(vx * vx + vy * vy) < MIN_SPEED:
				vx = 0.0
				vy = 0.0
			_bounce_walls()
			loose_timer -= delta
			if loose_timer <= 0.0:
				loose_timer = LOOSE_TIMEOUT
		BallState.CONTROLLED:
			pass  # Position updated by simulation
		_:
			pass
	return false

func _bounce_walls() -> void:
	# Side walls (y-axis)
	if y < 0.02:
		y = 0.04 - y  # reflect position
		y = maxf(y, 0.02)
		vy = absf(vy) * WALL_BOUNCE
	elif y > 0.98:
		y = 1.96 - y  # reflect position
		y = minf(y, 0.98)
		vy = -absf(vy) * WALL_BOUNCE
	# End walls (x-axis) - not in goal mouth (y: 0.38-0.62)
	var in_goal_mouth: bool = y > 0.38 and y < 0.62
	if not in_goal_mouth:
		if x < 0.02:
			x = 0.04 - x
			x = maxf(x, 0.02)
			vx = absf(vx) * WALL_BOUNCE
		elif x > 0.98:
			x = 1.96 - x
			x = minf(x, 0.98)
			vx = -absf(vx) * WALL_BOUNCE
	# Hard clamp as safety net
	x = clampf(x, 0.02, 0.98)
	y = clampf(y, 0.02, 0.98)

# ── Helpers ─────────────────────────────────────────────────────────────────

func is_free() -> bool:
	return state == BallState.LOOSE or state == BallState.DEAD

func get_speed() -> float:
	return sqrt(vx * vx + vy * vy)

func to_dict() -> Dictionary:
	return {
		"x": x,
		"y": y,
		"state": BallState.keys()[state],
		"owner_name": owner.goblin_name if owner else "",
	}
