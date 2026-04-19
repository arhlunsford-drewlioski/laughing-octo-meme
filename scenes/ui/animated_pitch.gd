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

signal goblin_token_clicked(goblin_name: String)
signal pitch_clicked(pitch_x: float, pitch_y: float)

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
var _ball_state: String = "CONTROLLED"
var _ball_aerial: bool = false
var _ball_scale: float = 1.0            # current visual scale (lerps toward target)
var _ball_owner_name: String = ""       # current ball carrier for glow tracking
const BALL_AERIAL_SCALE: float = 1.8    # scale when ball is in the air (TRAVELLING)
const BALL_SCALE_LERP: float = 6.0      # how fast scale animates
const TOKEN_LERP_SPEED: float = 10.0   # smooth glide - readable movement, no teleporting
const BALL_LERP_SPEED: float = 14.0     # ball moves crisply but visibly

# Extra balls (multiball spell)
var _extra_ball_positions: Array = []  # [{x, y}] from snapshot
var _extra_ball_lerped: Array = []     # [Vector2] screen positions for smooth rendering
const EXTRA_BALL_COLOR := Color(1.0, 0.5, 0.1)  # orange chaos balls
const EXTRA_BALL_RADIUS := 4.0

# Haste visual
var _haste_active: bool = false

# Pass line visualization (disabled)
var _pass_lines: Array = []
const PASS_LINE_FADE: float = 0.45

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

func remove_goblin_token(goblin_name: String) -> void:
	## Animate a goblin dying and remove their token from the pitch.
	var token: Control = _token_map.get(goblin_name, null)
	if token == null:
		return
	_token_map.erase(goblin_name)
	_player_tokens.erase(token)
	_opponent_tokens.erase(token)
	_raw_targets.erase(goblin_name)
	# Death animation: shrink + fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(token, "scale", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(token, "modulate", Color(1, 0.2, 0, 0), 0.4)
	tween.chain().tween_callback(token.queue_free)

var _fireball_targeting: bool = false  # legacy, kept for compatibility
var _targeting_active: bool = false    # general targeting mode (any spell)

# Wobble reticle
var _wobble_reticle_active: bool = false
var _wobble_reticle_pos: Vector2 = Vector2.ZERO  # pitch coordinates

# Shield dome visuals: {GoblinData: true}
var _shielded_tokens: Dictionary = {}

# Fireball explosion effect
var _explosion_active: bool = false
var _explosion_center: Vector2 = Vector2.ZERO
var _explosion_time: float = 0.0
const EXPLOSION_DURATION: float = 0.6
const EXPLOSION_MAX_RADIUS: float = 100.0  # pixels
var _screen_shake: Vector2 = Vector2.ZERO

func screen_to_pitch(screen_pos: Vector2) -> Vector2:
	## Convert control-space position to pitch-relative coordinates (0-1).
	if _pitch_rect.size.x < 1 or _pitch_rect.size.y < 1:
		return Vector2(0.5, 0.5)
	var px: float = (screen_pos.x - _pitch_rect.position.x) / _pitch_rect.size.x
	var py: float = (screen_pos.y - _pitch_rect.position.y) / _pitch_rect.size.y
	return Vector2(clampf(px, 0.0, 1.0), clampf(py, 0.0, 1.0))

func set_wobble_reticle(pitch_x: float, pitch_y: float) -> void:
	_wobble_reticle_active = true
	_wobble_reticle_pos = _pitch_pos(pitch_x, pitch_y)
	queue_redraw()

func clear_wobble_reticle() -> void:
	_wobble_reticle_active = false
	queue_redraw()

func set_fireball_targeting(enabled: bool) -> void:
	## Toggle AoE fireball targeting - click anywhere on pitch.
	_fireball_targeting = enabled
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS

func play_fireball_explosion(pitch_x: float, pitch_y: float) -> void:
	## Trigger the visual explosion at a pitch coordinate.
	_explosion_center = _pitch_pos(pitch_x, pitch_y)
	_explosion_time = 0.0
	_explosion_active = true

func _gui_input(event: InputEvent) -> void:
	if (_fireball_targeting or _targeting_active) and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position
		var pitch_pos: Vector2 = screen_to_pitch(local_pos)
		pitch_clicked.emit(pitch_pos.x, pitch_pos.y)
		get_viewport().set_input_as_handled()

func set_opponent_targeting(enabled: bool) -> void:
	## Toggle targeting mode on individual opponent tokens.
	for token in _opponent_tokens:
		token.set_targetable(enabled)
		if enabled:
			if not token.gui_input.is_connected(_on_target_token_input):
				token.gui_input.connect(_on_target_token_input.bind(token))
		else:
			if token.gui_input.is_connected(_on_target_token_input):
				token.gui_input.disconnect(_on_target_token_input)

func _on_target_token_input(event: InputEvent, token: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		goblin_token_clicked.emit(token.goblin_data.goblin_name)

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

	# Update raw goblin targets and track ball carrier
	var goblins_arr: Array = snapshot["goblins"]
	var new_owner_name: String = ""
	for gdata: Dictionary in goblins_arr:
		var goblin_name: String = str(gdata["name"])
		if not _token_map.has(goblin_name):
			continue
		var token: Control = _token_map[goblin_name]
		var target_center: Vector2 = _pitch_pos(float(gdata["x"]), float(gdata["y"]))
		var target_pos: Vector2 = target_center - Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
		_raw_targets[goblin_name] = target_pos
		if bool(gdata.get("has_ball", false)):
			new_owner_name = goblin_name

	# Update ball carrier glow
	if new_owner_name != _ball_owner_name:
		if _ball_owner_name != "" and _token_map.has(_ball_owner_name):
			_token_map[_ball_owner_name].set_has_ball(false)
		if new_owner_name != "" and _token_map.has(new_owner_name):
			_token_map[new_owner_name].set_has_ball(true)
		_ball_owner_name = new_owner_name

	# Update raw ball target + state
	var ball_data: Dictionary = snapshot["ball"]
	_raw_ball_target = _pitch_pos(float(ball_data["x"]), float(ball_data["y"]))
	_ball_state = str(ball_data.get("state", "CONTROLLED"))
	_ball_aerial = bool(ball_data.get("aerial", false))

	# Extra balls (multiball)
	_extra_ball_positions = snapshot.get("extra_balls", [])
	# Grow/shrink lerped array to match
	while _extra_ball_lerped.size() < _extra_ball_positions.size():
		var eb: Dictionary = _extra_ball_positions[_extra_ball_lerped.size()]
		_extra_ball_lerped.append(_pitch_pos(float(eb["x"]), float(eb["y"])))
	while _extra_ball_lerped.size() > _extra_ball_positions.size():
		_extra_ball_lerped.pop_back()

	# Haste glow
	_haste_active = bool(snapshot.get("haste_active", false))

# -- Animation --

func show_pass_line(_from_name: String, _to_name: String, _line_color: Color = Color(1, 1, 1, 0.5)) -> void:
	if _from_name == "" or _to_name == "":
		return
	if not _token_map.has(_from_name) or not _token_map.has(_to_name):
		return
	_pass_lines.append({
		"from": _from_name,
		"to": _to_name,
		"color": _line_color,
		"ttl": PASS_LINE_FADE,
	})
	while _pass_lines.size() > 10:
		_pass_lines.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	if _snapshot_active:
		_process_snapshot_lerp(delta)
	elif not idle_paused:
		_process_idle(delta)

	var pass_lines_dirty: bool = false
	for i in range(_pass_lines.size() - 1, -1, -1):
		var line_data: Dictionary = _pass_lines[i]
		line_data["ttl"] = float(line_data.get("ttl", 0.0)) - delta
		if float(line_data["ttl"]) <= 0.0:
			_pass_lines.remove_at(i)
		else:
			_pass_lines[i] = line_data
		pass_lines_dirty = true
	if pass_lines_dirty:
		queue_redraw()

	# Explosion effect
	if _explosion_active:
		_explosion_time += delta
		if _explosion_time >= EXPLOSION_DURATION:
			_explosion_active = false
			_screen_shake = Vector2.ZERO
			position = Vector2.ZERO
		else:
			# Screen shake (decays over time)
			var shake_intensity: float = (1.0 - _explosion_time / EXPLOSION_DURATION) * 8.0
			_screen_shake = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
			position = _screen_shake
		queue_redraw()

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

		# Aerial visual: scale ball up when it's in the air (long passes, crosses, shots)
		var target_scale: float = BALL_AERIAL_SCALE if _ball_aerial else 1.0
		var scale_lerp: float = 1.0 - exp(-BALL_SCALE_LERP * delta)
		_ball_scale = lerpf(_ball_scale, target_scale, scale_lerp)
		var visual_scale := Vector2(_ball_scale, _ball_scale)
		if _ball.scale != visual_scale:
			_ball.scale = visual_scale
			_ball.pivot_offset = Vector2(BALL_RADIUS, BALL_RADIUS)

	# Extra balls (multiball) - lerp toward their targets
	for i in _extra_ball_lerped.size():
		if i < _extra_ball_positions.size():
			var eb: Dictionary = _extra_ball_positions[i]
			var target: Vector2 = _pitch_pos(float(eb["x"]), float(eb["y"]))
			_extra_ball_lerped[i] = _extra_ball_lerped[i].lerp(target, ball_lerp)
	if not _extra_ball_lerped.is_empty():
		queue_redraw()

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
	_draw_pass_lines()
	_draw_extra_balls()
	_draw_haste_glow()
	_draw_wobble_reticle()
	_draw_shield_domes()
	_draw_explosion()

func _draw_wobble_reticle() -> void:
	if not _wobble_reticle_active:
		return
	# Pulsing red crosshair at the wobble position
	var center: Vector2 = _wobble_reticle_pos
	var pulse: float = 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4
	var color := Color(1.0, 0.3, 0.1, pulse)
	draw_circle(center, 30, Color(1.0, 0.2, 0.0, 0.15))
	draw_circle(center, 20, Color(1.0, 0.3, 0.1, 0.25))
	draw_arc(center, 25, 0, TAU, 32, color, 2.5)
	# Crosshair lines
	draw_line(center + Vector2(-15, 0), center + Vector2(-6, 0), color, 2.0)
	draw_line(center + Vector2(6, 0), center + Vector2(15, 0), color, 2.0)
	draw_line(center + Vector2(0, -15), center + Vector2(0, -6), color, 2.0)
	draw_line(center + Vector2(0, 6), center + Vector2(0, 15), color, 2.0)

func _draw_shield_domes() -> void:
	# Draw blue bubble around shielded tokens
	for token in _player_tokens + _opponent_tokens:
		if not is_instance_valid(token):
			continue
		if not token.goblin_data:
			continue
		if _shielded_tokens.has(token.goblin_data):
			var center: Vector2 = token.position + Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
			var pulse: float = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.3
			draw_arc(center, token.TOKEN_RADIUS + 6, 0, TAU, 32, Color(0.2, 0.7, 1.0, pulse), 3.0)
			draw_circle(center, token.TOKEN_RADIUS + 4, Color(0.2, 0.6, 1.0, 0.1))

func _draw_pass_lines() -> void:
	for line_data in _pass_lines:
		var from_name: String = str(line_data.get("from", ""))
		var to_name: String = str(line_data.get("to", ""))
		if not _token_map.has(from_name) or not _token_map.has(to_name):
			continue
		var from_token: Control = _token_map[from_name]
		var to_token: Control = _token_map[to_name]
		if not is_instance_valid(from_token) or not is_instance_valid(to_token):
			continue
		var alpha: float = clampf(float(line_data.get("ttl", 0.0)) / PASS_LINE_FADE, 0.0, 1.0)
		var base_color: Color = line_data.get("color", Color(1, 1, 1, 0.45))
		var color := Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)
		var from_pos := from_token.position + Vector2(from_token.TOKEN_RADIUS, from_token.TOKEN_RADIUS)
		var to_pos := to_token.position + Vector2(to_token.TOKEN_RADIUS, to_token.TOKEN_RADIUS)
		draw_line(from_pos, to_pos, color, 2.0)
		draw_circle(to_pos, 3.0, color)

func _draw_extra_balls() -> void:
	for pos in _extra_ball_lerped:
		# Glowing orange chaos ball
		draw_circle(pos, EXTRA_BALL_RADIUS + 3, Color(1.0, 0.4, 0.0, 0.3))
		draw_circle(pos, EXTRA_BALL_RADIUS, EXTRA_BALL_COLOR)
		draw_circle(pos, EXTRA_BALL_RADIUS * 0.5, Color(1.0, 0.8, 0.3))

func _draw_haste_glow() -> void:
	if not _haste_active:
		return
	# Subtle green glow around all player tokens
	for token in _player_tokens:
		if is_instance_valid(token):
			var center: Vector2 = token.position + Vector2(token.TOKEN_RADIUS, token.TOKEN_RADIUS)
			draw_arc(center, token.TOKEN_RADIUS + 4, 0, TAU, 24, Color(0.2, 1.0, 0.3, 0.4), 2.0)

func _draw_explosion() -> void:
	if not _explosion_active:
		return
	var t: float = _explosion_time / EXPLOSION_DURATION  # 0 to 1
	var center: Vector2 = _explosion_center

	# Flash: bright white fill that fades fast
	if t < 0.15:
		var flash_alpha: float = (1.0 - t / 0.15) * 0.6
		var flash_radius: float = EXPLOSION_MAX_RADIUS * 0.4
		draw_circle(center, flash_radius, Color(1.0, 1.0, 0.9, flash_alpha))

	# Expanding fireball core (orange/red fill, fades out)
	var core_radius: float = EXPLOSION_MAX_RADIUS * 0.6 * t
	var core_alpha: float = (1.0 - t) * 0.7
	draw_circle(center, core_radius, Color(1.0, 0.4, 0.1, core_alpha))

	# Inner hot ring
	var inner_radius: float = EXPLOSION_MAX_RADIUS * 0.5 * t
	var inner_alpha: float = (1.0 - t) * 0.9
	draw_arc(center, inner_radius, 0, TAU, 32, Color(1.0, 0.8, 0.2, inner_alpha), 3.0)

	# Outer blast ring (expands faster, thinner)
	var outer_radius: float = EXPLOSION_MAX_RADIUS * t
	var outer_alpha: float = (1.0 - t) * 0.6
	draw_arc(center, outer_radius, 0, TAU, 48, Color(1.0, 0.3, 0.0, outer_alpha), 2.0)

	# Outermost shockwave ring
	if t > 0.1:
		var shock_t: float = (t - 0.1) / 0.9
		var shock_radius: float = EXPLOSION_MAX_RADIUS * 1.3 * shock_t
		var shock_alpha: float = (1.0 - shock_t) * 0.3
		draw_arc(center, shock_radius, 0, TAU, 48, Color(1.0, 0.6, 0.3, shock_alpha), 1.5)

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
