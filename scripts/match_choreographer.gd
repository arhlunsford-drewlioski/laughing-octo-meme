class_name MatchChoreographer
extends RefCounted
## Translates RealtimeEngine events into tween animation sequences on AnimatedPitch.

var pitch: Control  # AnimatedPitch reference
var _active_tweens: Array[Tween] = []

func _init(p_pitch: Control) -> void:
	pitch = p_pitch

func choreograph_event(event: Dictionary) -> void:
	## Animate the event intro (ball movement, token shifts). Await this.
	pitch.idle_paused = true
	_kill_active_tweens()

	var event_id: String = event["event_id"]
	var side: String = event["side"]
	var actor_name: String = event.get("actor", "")

	match event_id:
		"player_attack":
			await _choreograph_attack(true, actor_name)
		"opp_attack":
			await _choreograph_attack(false, actor_name)
		"counter_attack":
			await _choreograph_counter(actor_name)
		"midfield_battle":
			await _choreograph_midfield()
		"set_piece":
			await _choreograph_set_piece(side)
		"momentum_shift":
			await _choreograph_momentum_shift(side)

func choreograph_result(event: Dictionary, result: Dictionary) -> void:
	## Animate the result (goal flash, save deflect, etc). Await this.
	var outcome: String = result["outcome"]
	var goblin_name: String = result.get("goblin_name", "")

	match outcome:
		"goal_player":
			await _choreograph_goal(true, goblin_name)
		"goal_opponent":
			await _choreograph_goal(false, goblin_name)
		"save":
			await _choreograph_save(event["side"] == "player")
		"miss":
			await _choreograph_miss(event["side"] == "player")
		"momentum_player":
			await _choreograph_momentum_result(true)
		"momentum_opponent":
			await _choreograph_momentum_result(false)
		_:
			await _brief_pause(0.3)

	# Return tokens to base and resume idle
	await _reset_all_tokens(0.4)
	pitch.idle_paused = false

# -- Event choreographies --

func _choreograph_attack(is_player: bool, actor_name: String) -> void:
	var ball := pitch.get_ball()
	var target_zone := "attack" if is_player else "defense"
	var target_x := pitch.PLAYER_X[target_zone] if is_player else pitch.OPPONENT_X["attack"]

	# Move ball toward the attacking third
	var ball_target: Vector2 = pitch.get_zone_center(target_zone if is_player else "attack", not is_player if not is_player else true)
	# Offset Y slightly for variety
	ball_target.y += randf_range(-30, 30)

	var tween := _create_tween()
	tween.tween_property(ball, "position",
		ball_target - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), 0.7
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Shift the actor forward
	if actor_name != "":
		var token := pitch.get_goblin_token(actor_name)
		if token:
			token.set_highlight(true)
			var forward := Vector2(15.0 if is_player else -15.0, 0)
			tween.parallel().tween_property(token, "position",
				token.base_position + forward, 0.6
			).set_ease(Tween.EASE_OUT)

	await tween.finished

func _choreograph_counter(actor_name: String) -> void:
	var ball := pitch.get_ball()
	# Fast sweep from defense to attack
	var start := pitch.get_zone_center("defense", true)
	var target := pitch.get_zone_center("attack", true)
	target.y += randf_range(-25, 25)

	pitch.set_ball_center(start)

	var tween := _create_tween()
	tween.tween_property(ball, "position",
		target - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), 0.5
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if actor_name != "":
		var token := pitch.get_goblin_token(actor_name)
		if token:
			token.set_highlight(true)
			var forward := Vector2(20.0, 0)
			tween.parallel().tween_property(token, "position",
				token.base_position + forward, 0.5
			).set_ease(Tween.EASE_OUT)

	await tween.finished

func _choreograph_midfield() -> void:
	var ball := pitch.get_ball()
	var center := pitch.get_zone_center("midfield", true)

	# Ball oscillates around center
	var tween := _create_tween()
	tween.tween_property(ball, "position",
		center + Vector2(15, -10) - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), 0.25
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ball, "position",
		center + Vector2(-15, 10) - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), 0.25
	).set_ease(Tween.EASE_IN_OUT)

	# Midfield tokens shift toward center
	for token in pitch.get_all_player_tokens():
		if token.zone == "midfield":
			token.set_highlight(true)
			tween.parallel().tween_property(token, "position",
				token.base_position + Vector2(8, 0), 0.4
			).set_ease(Tween.EASE_IN_OUT)
	for token in pitch.get_all_opponent_tokens():
		if token.zone == "midfield":
			tween.parallel().tween_property(token, "position",
				token.base_position + Vector2(-8, 0), 0.4
			).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

func _choreograph_set_piece(side: String) -> void:
	var ball := pitch.get_ball()
	var is_player := side == "player"

	# Ball placed near penalty area
	var pen_zone := "attack" if is_player else "defense"
	var target := pitch.get_zone_center(pen_zone, is_player)
	target.y += randf_range(-40, 40)

	var tween := _create_tween()
	tween.tween_property(ball, "position",
		target - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), 0.5
	).set_ease(Tween.EASE_OUT)

	await tween.finished

func _choreograph_momentum_shift(side: String) -> void:
	# Pulse the dominant team's tokens
	var tokens: Array[Control] = pitch.get_all_player_tokens() if side != "opponent" else pitch.get_all_opponent_tokens()
	var tween := _create_tween()
	for token in tokens:
		tween.parallel().tween_property(token, "modulate", Color(1.3, 1.2, 0.8), 0.25)
	tween.tween_property(tokens[0], "modulate", Color.WHITE, 0.0)  # Dummy to chain
	for token in tokens:
		tween.parallel().tween_property(token, "modulate", Color.WHITE, 0.25)

	await tween.finished

# -- Result choreographies --

func _choreograph_goal(is_player: bool, goblin_name: String) -> void:
	var ball := pitch.get_ball()
	var goal_pos := pitch.get_goal_mouth_pos(not is_player)  # Ball goes into OPPONENT's goal

	# Ball into goal
	var tween := _create_tween()
	tween.tween_property(ball, "position",
		goal_pos - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), 0.4
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	await tween.finished

	# Scorer celebration: scale bounce
	if goblin_name != "":
		var token := pitch.get_goblin_token(goblin_name)
		if token:
			var cel_tween := _create_tween()
			cel_tween.tween_property(token, "scale", Vector2(1.4, 1.4), 0.15).set_ease(Tween.EASE_OUT)
			cel_tween.tween_property(token, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN)

			# Gold flash on scorer
			cel_tween.parallel().tween_property(token, "modulate", Color(1.5, 1.3, 0.5), 0.15)
			cel_tween.tween_property(token, "modulate", Color.WHITE, 0.3)
			await cel_tween.finished

	await _brief_pause(0.3)

func _choreograph_save(attacker_is_player: bool) -> void:
	var ball := pitch.get_ball()
	# Ball deflects away at an angle
	var deflect_dir := Vector2(-40 if attacker_is_player else 40, randf_range(-30, 30))
	var current := ball.position

	var tween := _create_tween()
	tween.tween_property(ball, "position", current + deflect_dir, 0.3).set_ease(Tween.EASE_OUT)

	# Keeper glow
	var keeper_side := not attacker_is_player
	var keeper_tokens := pitch.get_all_player_tokens() if keeper_side else pitch.get_all_opponent_tokens()
	for token in keeper_tokens:
		if token.zone == "goal":
			tween.parallel().tween_property(token, "modulate", Color(0.5, 1.5, 0.5), 0.2)
			tween.tween_property(token, "modulate", Color.WHITE, 0.3)

	await tween.finished

func _choreograph_miss(attacker_is_player: bool) -> void:
	var ball := pitch.get_ball()
	# Ball drifts past goal at an angle
	var miss_offset := Vector2(30 if attacker_is_player else -30, randf_range(-50, 50))
	var current := ball.position

	var tween := _create_tween()
	tween.tween_property(ball, "position", current + miss_offset, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)

	await tween.finished

func _choreograph_momentum_result(is_player: bool) -> void:
	# Winning team shifts forward slightly
	var tokens: Array[Control] = pitch.get_all_player_tokens() if is_player else pitch.get_all_opponent_tokens()
	var dir := Vector2(5.0, 0) if is_player else Vector2(-5.0, 0)

	var tween := _create_tween()
	for token in tokens:
		if token.zone != "goal":
			tween.parallel().tween_property(token, "position",
				token.base_position + dir, 0.3
			).set_ease(Tween.EASE_OUT)

	await tween.finished

# -- Utilities --

func _reset_all_tokens(duration: float) -> void:
	var tween := _create_tween()
	var all_tokens: Array = []
	all_tokens.append_array(pitch.get_all_player_tokens())
	all_tokens.append_array(pitch.get_all_opponent_tokens())

	for token in all_tokens:
		if not is_instance_valid(token):
			continue
		token.set_highlight(false)
		tween.parallel().tween_property(token, "position", token.base_position, duration).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(token, "scale", Vector2.ONE, duration * 0.5)
		tween.parallel().tween_property(token, "modulate", Color.WHITE, duration * 0.5)

	# Return ball to center
	var ball := pitch.get_ball()
	var center := pitch.get_zone_center("midfield", true)
	tween.parallel().tween_property(ball, "position",
		center - Vector2(pitch.BALL_RADIUS, pitch.BALL_RADIUS), duration
	).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

func _brief_pause(duration: float) -> void:
	await pitch.get_tree().create_timer(duration).timeout

func _create_tween() -> Tween:
	var tween := pitch.create_tween()
	_active_tweens.append(tween)
	return tween

func _kill_active_tweens() -> void:
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
