class_name Ball
extends RefCounted
## Ball state machine for match simulation. Pure data, no Node.
## Position is normalized 0.0-1.0 on both axes.

enum BallState { CONTROLLED, LOOSE, CONTESTED, TRAVELLING, DEAD }

var x: float = 0.5
var y: float = 0.5
var state: BallState = BallState.DEAD
var owner: GoblinData = null

# TRAVELLING state
var target_x: float = 0.0
var target_y: float = 0.0
var travel_speed: float = 2.0  # normalized units per second

# LOOSE state
var loose_timer: float = 0.0
const LOOSE_TIMEOUT: float = 4.0  # seconds before going dead (goal kick)

# ── State Transitions ───────────────────────────────────────────────────────

func set_controlled(goblin: GoblinData, gx: float, gy: float) -> void:
	state = BallState.CONTROLLED
	owner = goblin
	x = gx
	y = gy
	loose_timer = 0.0

func set_loose(lx: float, ly: float) -> void:
	state = BallState.LOOSE
	owner = null
	x = lx
	y = ly
	loose_timer = LOOSE_TIMEOUT

func set_contested(cx: float, cy: float) -> void:
	state = BallState.CONTESTED
	owner = null
	x = cx
	y = cy
	loose_timer = 0.0

func set_travelling(from_x: float, from_y: float, to_x: float, to_y: float, spd: float = 2.0) -> void:
	state = BallState.TRAVELLING
	owner = null
	x = from_x
	y = from_y
	target_x = to_x
	target_y = to_y
	travel_speed = spd

func set_dead(dx: float, dy: float) -> void:
	state = BallState.DEAD
	owner = null
	x = dx
	y = dy
	loose_timer = 0.0

# ── Tick Update ─────────────────────────────────────────────────────────────

## Returns true if ball arrived at target (TRAVELLING -> needs resolution)
func update(delta: float) -> bool:
	match state:
		BallState.TRAVELLING:
			var dist := sqrt((target_x - x) ** 2 + (target_y - y) ** 2)
			var step := travel_speed * delta
			if step >= dist:
				x = target_x
				y = target_y
				_bounce_walls()
				return true  # arrived
			var ratio := step / dist
			x += (target_x - x) * ratio
			y += (target_y - y) * ratio
			_bounce_walls()
		BallState.LOOSE:
			loose_timer -= delta
			if loose_timer <= 0.0:
				# Arena mode: ball stays loose, doesn't go dead
				loose_timer = LOOSE_TIMEOUT
			_bounce_walls()
		BallState.CONTROLLED:
			pass  # Position updated by simulation when owner moves
		_:
			pass
	return false

func _bounce_walls() -> void:
	## Arena mode: clamp ball to pitch and reflect target if needed.
	# Side walls (y-axis)
	if y < 0.02:
		y = 0.02
		target_y = absf(target_y - y) + y  # reflect
	elif y > 0.98:
		y = 0.98
		target_y = y - absf(target_y - y)  # reflect
	# End walls (x-axis) - but not into goal mouth area (y: 0.38-0.62)
	var in_goal_mouth: bool = y > 0.38 and y < 0.62
	if not in_goal_mouth:
		if x < 0.02:
			x = 0.02
			target_x = absf(target_x - x) + x
		elif x > 0.98:
			x = 0.98
			target_x = x - absf(target_x - x)

# ── Helpers ─────────────────────────────────────────────────────────────────

func is_free() -> bool:
	return state == BallState.LOOSE or state == BallState.DEAD

func to_dict() -> Dictionary:
	return {
		"x": x,
		"y": y,
		"state": BallState.keys()[state],
		"owner_name": owner.goblin_name if owner else "",
	}
