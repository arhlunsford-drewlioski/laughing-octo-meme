extends Control
## FM-style animated pitch with FIFA proportions. Goblin tokens and ball are child nodes.

const GoblinTokenScene := preload("res://scenes/ui/goblin_token.tscn")

# FIFA standard: 105m x 68m
const PITCH_ASPECT := 105.0 / 68.0  # ~1.544

# Realistic zone X positions (proportion of pitch length)
const PLAYER_X := { "goal": 0.03, "defense": 0.18, "midfield": 0.35, "attack": 0.45 }
const OPPONENT_X := { "attack": 0.55, "midfield": 0.65, "defense": 0.82, "goal": 0.97 }

# FIFA-accurate pitch marking proportions
const PEN_AREA_LENGTH := 16.5 / 105.0   # ~0.157
const PEN_AREA_WIDTH := 40.32 / 68.0     # ~0.593
const GOAL_AREA_LENGTH := 5.5 / 105.0    # ~0.052
const GOAL_AREA_WIDTH := 18.32 / 68.0    # ~0.269
const CENTER_CIRCLE_R := 9.15 / 68.0     # ~0.135 of pitch height
const PEN_SPOT := 11.0 / 105.0           # ~0.105 from goal line
const GOAL_MOUTH_W := 3.0 / 105.0        # Net depth behind goal line
const GOAL_MOUTH_H := 7.32 / 68.0        # ~0.108 (goalpost to goalpost)

# Pitch colors
const PITCH_GREEN := Color(0.15, 0.32, 0.12)
const PITCH_GREEN_LIGHT := Color(0.17, 0.35, 0.14)
const PITCH_LINE := Color(1, 1, 1, 0.25)
const PITCH_LINE_BOLD := Color(1, 1, 1, 0.35)
const LETTERBOX_COLOR := Color(0.08, 0.08, 0.11)

# Ball
const BALL_RADIUS := 5.0
const BALL_COLOR := Color(0.95, 0.95, 0.9)

# State
var player_formation: Formation
var opponent_formation: Formation

var _pitch_rect: Rect2 = Rect2()  # Actual pitch area within this control
var _player_tokens: Array[Control] = []
var _opponent_tokens: Array[Control] = []
var _ball: Control  # Ball node
var _token_map: Dictionary = {}  # goblin_name -> token node

# Idle animation
var idle_paused: bool = false
var _idle_time: float = 0.0
var _jitter_timers: Dictionary = {}  # token -> next jitter time

# Snapshot-driven mode
var _snapshot_active: bool = false
var _raw_targets: Dictionary = {}      # goblin_name -> Vector2 (from sim, updated per tick)
var _raw_ball_target: Vector2 = Vector2.ZERO
const TOKEN_LERP_SPEED: float = 8.0    # direct token easing; less floaty than double smoothing
const BALL_LERP_SPEED: float = 6.0      # ball readable speed

func setup(p_formation: Formation, o_formation: Formation) -> void:
	player_formation = p_formation
	opponent_formation = o_formation

	if size == Vector2.ZERO:
		await get_tree().process_frame

	_calc_pitch_rect()
	_create_tokens()
	_create_ball()
	queue_redraw()

func _calc_pitch_rect() -> void:
	## Calculate letterboxed pitch rect maintaining FIFA aspect ratio.
	var available_w: float = size.x
	var available_h: float = size.y

	var pitch_w: float
	var pitch_h: float

	if available_w / available_h > PITCH_ASPECT:
		# Height-constrained: pitch fills height, narrower than available width
		pitch_h = available_h
		pitch_w = pitch_h * PITCH_ASPECT
	else:
		# Width-constrained: pitch fills width, shorter than available height
		pitch_w = available_w
		pitch_h = pitch_w / PITCH_ASPECT

	var offset_x: float = (available_w - pitch_w) * 0.5
	var offset_y: float = (available_h - pitch_h) * 0.5
	_pitch_rect = Rect2(offset_x, offset_y, pitch_w, pitch_h)

func _pitch_pos(x_ratio: float, y_ratio: float) -> Vector2:
	## Convert pitch-relative coordinates (0-1) to control-space position.
	return Vector2(
		_pitch_rect.position.x + _pitch_rect.size.x * x_ratio,
		_pitch_rect.position.y + _pitch_rect.size.y * y_ratio
	)

func _create_tokens() -> void:
	# Clear existing
	for t in _player_tokens:
		t.queue_free()
	for t in _opponent_tokens:
		t.queue_free()
	_player_tokens.clear()
	_opponent_tokens.clear()
	_token_map.clear()
	_jitter_timers.clear()

	# Create player tokens
	for zone_name in ["goal", "defense", "midfield", "attack"]:
		var goblins: Array[GoblinData] = player_formation.get_zone(zone_name)
		var positions := _get_zone_positions(zone_name, goblins.size(), true)
		for i in goblins.size():
			var token: Control = GoblinTokenScene.instantiate()
			add_child(token)
			token.setup(goblins[i], zone_name, true)
			var center_pos: Vector2 = positions[i]
			token.position = center_pos - Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
			token.base_position = token.position
			_player_tokens.append(token)
			_token_map[goblins[i].goblin_name] = token
			_jitter_timers[token] = randf_range(1.0, 3.0)

	# Create opponent tokens
	for zone_name in ["goal", "defense", "midfield", "attack"]:
		var goblins: Array[GoblinData] = opponent_formation.get_zone(zone_name)
		var positions := _get_zone_positions(zone_name, goblins.size(), false)
		for i in goblins.size():
			var token: Control = GoblinTokenScene.instantiate()
			add_child(token)
			token.setup(goblins[i], zone_name, false)
			var center_pos: Vector2 = positions[i]
			token.position = center_pos - Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
			token.base_position = token.position
			_opponent_tokens.append(token)
			_token_map[goblins[i].goblin_name] = token
			_jitter_timers[token] = randf_range(1.0, 3.0)

func _create_ball() -> void:
	if _ball:
		_ball.queue_free()
	_ball = Control.new()
	_ball.custom_minimum_size = Vector2(BALL_RADIUS * 2, BALL_RADIUS * 2)
	_ball.size = _ball.custom_minimum_size
	_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball.draw.connect(_draw_ball.bind(_ball))
	add_child(_ball)
	# Start at center
	var center := _pitch_pos(0.5, 0.5)
	_ball.position = center - Vector2(BALL_RADIUS, BALL_RADIUS)

func _draw_ball(ball_node: Control) -> void:
	ball_node.draw_circle(Vector2(BALL_RADIUS, BALL_RADIUS), BALL_RADIUS, BALL_COLOR)
	ball_node.draw_arc(Vector2(BALL_RADIUS, BALL_RADIUS), BALL_RADIUS, 0, TAU, 16, Color(0.3, 0.3, 0.3, 0.5), 1.0)

func get_ball() -> Control:
	return _ball

func get_ball_center() -> Vector2:
	return _ball.position + Vector2(BALL_RADIUS, BALL_RADIUS)

func set_ball_center(pos: Vector2) -> void:
	_ball.position = pos - Vector2(BALL_RADIUS, BALL_RADIUS)

func get_goblin_token(goblin_name: String) -> Control:
	return _token_map.get(goblin_name, null)

func get_all_player_tokens() -> Array[Control]:
	return _player_tokens

func get_all_opponent_tokens() -> Array[Control]:
	return _opponent_tokens

func get_zone_center(zone: String, is_player: bool) -> Vector2:
	## Get the center point of a zone.
	var x_map: Dictionary = PLAYER_X if is_player else OPPONENT_X
	return _pitch_pos(x_map[zone], 0.5)

func get_goal_mouth_pos(is_player_goal: bool) -> Vector2:
	## Position inside the goal mouth (for goal animations).
	if is_player_goal:
		return _pitch_pos(-0.01, 0.5)  # Just behind left goal line
	else:
		return _pitch_pos(1.01, 0.5)  # Just behind right goal line

func get_pitch_rect() -> Rect2:
	return _pitch_rect

func _get_zone_positions(zone: String, count: int, is_player: bool) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var x_map: Dictionary = PLAYER_X if is_player else OPPONENT_X
	var x_ratio: float = x_map[zone]

	if count == 0:
		return positions
	elif count == 1:
		positions.append(_pitch_pos(x_ratio, 0.5))
	else:
		var spread := 0.55  # Use 55% of pitch height
		var step := spread / float(count)
		var start_y := 0.5 - step * (count - 1) * 0.5
		for i in count:
			positions.append(_pitch_pos(x_ratio, start_y + step * i))

	return positions

# -- Snapshot application --

func apply_snapshot(snapshot: Dictionary) -> void:
	## Update raw target positions from a MatchSimulation state snapshot.
	## Tokens ease directly toward these in _process() so movement stays readable.
	_snapshot_active = true
	idle_paused = true

	# Update raw goblin targets (these jump each tick - that's fine)
	var goblins_arr: Array = snapshot["goblins"]
	for gdata: Dictionary in goblins_arr:
		var goblin_name: String = str(gdata["name"])
		if not _token_map.has(goblin_name):
			continue
		var token: Control = _token_map[goblin_name]
		var target_center: Vector2 = _pitch_pos(float(gdata["x"]), float(gdata["y"]))
		var target_pos: Vector2 = target_center - Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
		_raw_targets[goblin_name] = target_pos

	# Update raw ball target
	var ball_data: Dictionary = snapshot["ball"]
	_raw_ball_target = _pitch_pos(float(ball_data["x"]), float(ball_data["y"]))

# -- Animation --

func _process(delta: float) -> void:
	if _snapshot_active:
		_process_snapshot_lerp(delta)
	elif not idle_paused:
		_process_idle(delta)

func _process_snapshot_lerp(delta: float) -> void:
	## Single-stage interpolation keeps motion readable and avoids the
	## "pushed around by waves" look from double smoothing.
	var token_lerp: float = 1.0 - exp(-TOKEN_LERP_SPEED * delta)
	var ball_lerp: float = 1.0 - exp(-BALL_LERP_SPEED * delta)

	# Tokens move directly toward the latest sim position.
	for goblin_name: String in _raw_targets:
		if not _token_map.has(goblin_name):
			continue
		var token: Control = _token_map[goblin_name]
		var target: Vector2 = _raw_targets[goblin_name]
		token.position = token.position.lerp(target, token_lerp)
		token.base_position = target

	# Ball: single lerp only (no double-smooth - ball should travel in straight lines)
	if _ball:
		var current_center := get_ball_center()
		var new_center := current_center.lerp(_raw_ball_target, ball_lerp)
		set_ball_center(new_center)

func _process_idle(delta: float) -> void:
	_idle_time += delta

	# Ball idle: slow drift around midfield
	var ball_center := get_ball_center()
	var mid_center := _pitch_pos(0.5, 0.5)
	var drift_x := sin(_idle_time * 0.4) * _pitch_rect.size.x * 0.04
	var drift_y := cos(_idle_time * 0.6) * _pitch_rect.size.y * 0.06
	var target := mid_center + Vector2(drift_x, drift_y)
	var new_pos := ball_center.lerp(target, delta * 0.8)
	set_ball_center(new_pos)

	# Token jitter
	var all_tokens := _player_tokens + _opponent_tokens
	for token in all_tokens:
		if not is_instance_valid(token):
			continue
		if not _jitter_timers.has(token):
			continue
		_jitter_timers[token] -= delta
		if _jitter_timers[token] <= 0.0:
			_jitter_timers[token] = randf_range(1.5, 3.0)
			var jitter := Vector2(randf_range(-6, 6), randf_range(-6, 6))
			var tween := create_tween()
			tween.tween_property(token, "position", token.base_position + jitter, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# -- Drawing --

func _draw() -> void:
	# Letterbox background
	draw_rect(Rect2(Vector2.ZERO, size), LETTERBOX_COLOR)
	_draw_pitch()

func _draw_pitch() -> void:
	var r := _pitch_rect
	var w: float = r.size.x
	var h: float = r.size.y
	var ox: float = r.position.x
	var oy: float = r.position.y

	# Alternating grass stripes
	var stripe_count: int = 14
	var stripe_w: float = w / stripe_count
	for i in stripe_count:
		var color: Color = PITCH_GREEN if i % 2 == 0 else PITCH_GREEN_LIGHT
		draw_rect(Rect2(ox + stripe_w * i, oy, stripe_w, h), color)

	# Outer boundary
	draw_rect(r, PITCH_LINE_BOLD, false, 2.0)

	# Center line
	draw_line(Vector2(ox + w * 0.5, oy), Vector2(ox + w * 0.5, oy + h), PITCH_LINE_BOLD, 1.5)

	# Center circle
	draw_arc(Vector2(ox + w * 0.5, oy + h * 0.5), h * CENTER_CIRCLE_R, 0, TAU, 48, PITCH_LINE, 1.5)

	# Center dot
	draw_circle(Vector2(ox + w * 0.5, oy + h * 0.5), 3, PITCH_LINE_BOLD)

	# Left penalty area
	var pen_w := w * PEN_AREA_LENGTH
	var pen_h := h * PEN_AREA_WIDTH
	var pen_y := oy + (h - pen_h) * 0.5
	draw_rect(Rect2(ox, pen_y, pen_w, pen_h), PITCH_LINE, false, 1.5)

	# Left goal area
	var goal_area_w := w * GOAL_AREA_LENGTH
	var goal_area_h := h * GOAL_AREA_WIDTH
	var goal_area_y := oy + (h - goal_area_h) * 0.5
	draw_rect(Rect2(ox, goal_area_y, goal_area_w, goal_area_h), PITCH_LINE, false, 1.5)

	# Left goal mouth (net behind goal line)
	var mouth_w := w * GOAL_MOUTH_W
	var mouth_h := h * GOAL_MOUTH_H
	var mouth_y := oy + (h - mouth_h) * 0.5
	draw_rect(Rect2(ox - mouth_w, mouth_y, mouth_w, mouth_h), PITCH_LINE, false, 1.5)

	# Left penalty spot
	draw_circle(Vector2(ox + w * PEN_SPOT, oy + h * 0.5), 2, PITCH_LINE)

	# Left penalty arc (the D)
	var arc_center := Vector2(ox + w * PEN_SPOT, oy + h * 0.5)
	var arc_radius := h * CENTER_CIRCLE_R
	# Only draw the part outside the penalty area
	var arc_start := -asin((pen_h * 0.5) / arc_radius) if arc_radius > pen_h * 0.5 else -PI * 0.5
	var arc_end := -arc_start
	draw_arc(arc_center, arc_radius, arc_start, arc_end, 24, PITCH_LINE, 1.5)

	# Right penalty area (mirrored)
	draw_rect(Rect2(ox + w - pen_w, pen_y, pen_w, pen_h), PITCH_LINE, false, 1.5)

	# Right goal area
	draw_rect(Rect2(ox + w - goal_area_w, goal_area_y, goal_area_w, goal_area_h), PITCH_LINE, false, 1.5)

	# Right goal mouth
	draw_rect(Rect2(ox + w, mouth_y, mouth_w, mouth_h), PITCH_LINE, false, 1.5)

	# Right penalty spot
	draw_circle(Vector2(ox + w - w * PEN_SPOT, oy + h * 0.5), 2, PITCH_LINE)

	# Right penalty arc
	var r_arc_center := Vector2(ox + w - w * PEN_SPOT, oy + h * 0.5)
	draw_arc(r_arc_center, arc_radius, PI - arc_end, PI - arc_start, 24, PITCH_LINE, 1.5)

	# Corner arcs (quarter circles)
	var corner_r := h * 0.015
	draw_arc(Vector2(ox, oy), corner_r, 0, PI * 0.5, 8, PITCH_LINE, 1.0)
	draw_arc(Vector2(ox, oy + h), corner_r, -PI * 0.5, 0, 8, PITCH_LINE, 1.0)
	draw_arc(Vector2(ox + w, oy), corner_r, PI * 0.5, PI, 8, PITCH_LINE, 1.0)
	draw_arc(Vector2(ox + w, oy + h), corner_r, PI, PI * 1.5, 8, PITCH_LINE, 1.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calc_pitch_rect()
		# Reposition tokens if formations loaded
		if player_formation:
			_reposition_tokens()
		queue_redraw()

func _reposition_tokens() -> void:
	## Reposition all tokens to match new pitch rect without recreating them.
	var idx := 0
	for zone_name in ["goal", "defense", "midfield", "attack"]:
		var goblins: Array[GoblinData] = player_formation.get_zone(zone_name)
		var positions := _get_zone_positions(zone_name, goblins.size(), true)
		for i in goblins.size():
			if idx < _player_tokens.size():
				var token: Control = _player_tokens[idx]
				var center_pos: Vector2 = positions[i]
				token.position = center_pos - Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
				token.base_position = token.position
				idx += 1

	idx = 0
	for zone_name in ["goal", "defense", "midfield", "attack"]:
		var goblins: Array[GoblinData] = opponent_formation.get_zone(zone_name)
		var positions := _get_zone_positions(zone_name, goblins.size(), false)
		for i in goblins.size():
			if idx < _opponent_tokens.size():
				var token: Control = _opponent_tokens[idx]
				var center_pos: Vector2 = positions[i]
				token.position = center_pos - Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
				token.base_position = token.position
				idx += 1

	# Reset ball to center
	if _ball:
		var center := _pitch_pos(0.5, 0.5)
		_ball.position = center - Vector2(BALL_RADIUS, BALL_RADIUS)
