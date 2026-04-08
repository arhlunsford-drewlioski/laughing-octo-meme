extends Control
## Watches a MatchSimulation play out visually on the AnimatedPitch.

@onready var animated_pitch: Control = %AnimatedPitch
@onready var score_label: Label = %ScoreLabel
@onready var clock_label: Label = %ClockLabel
@onready var speed_btn: Button = %SpeedBtn
@onready var event_log: RichTextLabel = %EventLog
@onready var back_btn: Button = %BackBtn

var sim: MatchSimulation
var home_formation: Formation
var away_formation: Formation

var _tick_accumulator: float = 0.0
var _speed_multiplier: float = 0.6
const SPEED_OPTIONS := [0.6, 1.0, 1.5, 2.0, 4.0]
var _speed_index: int = 0

# Spell targeting
var _fireball_targeting: bool = false
var _paused: bool = false
var _fireball_btn: Button
var _haste_btn: Button
var _multiball_btn: Button

# Possession tracking
var _home_possession_ticks: int = 0
var _away_possession_ticks: int = 0
var _last_ball_owner_team: String = ""

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	speed_btn.pressed.connect(_cycle_speed)

	UITheme.style_button(back_btn, false)
	UITheme.style_button(speed_btn, false)
	score_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	clock_label.add_theme_color_override("font_color", UITheme.CREAM)
	speed_btn.text = _speed_text()

	# Spell buttons
	var bottom_bar: HBoxContainer = %EventLog.get_parent()

	_fireball_btn = Button.new()
	_fireball_btn.text = "FIREBALL"
	_fireball_btn.custom_minimum_size = Vector2(90, 0)
	UITheme.style_button(_fireball_btn, false)
	_fireball_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	_fireball_btn.pressed.connect(_on_fireball_pressed)
	bottom_bar.add_child(_fireball_btn)
	bottom_bar.move_child(_fireball_btn, 0)

	_haste_btn = Button.new()
	_haste_btn.text = "HASTE"
	_haste_btn.custom_minimum_size = Vector2(70, 0)
	UITheme.style_button(_haste_btn, false)
	_haste_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_haste_btn.pressed.connect(_on_haste_pressed)
	bottom_bar.add_child(_haste_btn)
	bottom_bar.move_child(_haste_btn, 1)

	_multiball_btn = Button.new()
	_multiball_btn.text = "MULTIBALL"
	_multiball_btn.custom_minimum_size = Vector2(90, 0)
	UITheme.style_button(_multiball_btn, false)
	_multiball_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_multiball_btn.pressed.connect(_on_multiball_pressed)
	bottom_bar.add_child(_multiball_btn)
	bottom_bar.move_child(_multiball_btn, 2)

	animated_pitch.pitch_clicked.connect(_on_pitch_clicked)

	_setup_and_start()

func _setup_and_start() -> void:
	var player_roster: Array[GoblinData]
	var opponent_roster: Array[GoblinData]

	if RunManager.run_active:
		player_roster = GameManager.selected_roster.slice(0, 6)
		opponent_roster = RunManager.get_current_opponent_roster()
	else:
		player_roster = GoblinDatabase.full_roster().slice(0, 6)
		opponent_roster = GoblinDatabase.opponent_roster()

	home_formation = GoblinDatabase.build_default_formation(player_roster)
	away_formation = GoblinDatabase.build_default_formation(opponent_roster)

	await animated_pitch.setup(home_formation, away_formation)

	sim = MatchSimulation.new()
	var snapshot := sim.start_match(home_formation, away_formation)
	animated_pitch.apply_snapshot(snapshot)
	_update_ui(snapshot)

	if RunManager.run_active:
		var opp_name := RunManager.get_current_opponent_name()
		var stage := RunManager.get_stage_name()
		_log("[color=yellow]%s - vs %s[/color]" % [stage, opp_name])
	_log("[color=yellow]KICK OFF[/color]")

func _process(delta: float) -> void:
	if sim == null or sim.is_match_over():
		return
	if _paused:
		return

	_tick_accumulator += delta * _speed_multiplier
	var tick_interval: float = 1.0 / MatchSimulation.TICKS_PER_SECOND

	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		var snapshot := sim.tick()
		animated_pitch.apply_snapshot(snapshot)
		_process_events(snapshot)
		_update_ui(snapshot)
		_check_halftime(snapshot)

		if sim.is_match_over():
			_on_match_over(snapshot)
			break

func _process_events(snapshot: Dictionary) -> void:
	var clock_min: int = int(snapshot["clock"])
	for event: Dictionary in snapshot["events"]:
		var etype: String = str(event["type"])
		match etype:
			# ── Big moments ──
			"goal":
				var sc: Array = event["score"]
				_log("[color=lime][b]%d' GOAL! %s! (%d-%d)[/b][/color]" % [clock_min, event["goblin"], sc[0], sc[1]])
				_flash_token(str(event["goblin"]), "goal")
			"shot":
				_log("[color=white]%d' Shot: %s[/color]" % [clock_min, event["goblin"]])
				_flash_token(str(event["goblin"]), "shot")
			"save":
				_log("[color=orange]%d' Save! %s stops %s[/color]" % [clock_min, event["keeper"], event["shooter"]])
				_flash_token(str(event["keeper"]), "save")
			"miss":
				_log("[color=gray]%d' Miss: %s fires wide[/color]" % [clock_min, event["goblin"]])
			"block":
				_log("[color=#b080ff]%d' Block! %s gets in the way[/color]" % [clock_min, event["goblin"]])
				_flash_token(str(event["goblin"]), "block")

			# ── Passing / build-up ──
			"pass":
				var to_name: String = str(event.get("to", ""))
				var from_name: String = str(event.get("from", ""))
				if to_name != "":
					_log("[color=#aaaaaa]%d' %s > %s[/color]" % [clock_min, from_name, to_name])
			"pass_received":
				var who: String = str(event.get("goblin", ""))
				if who != "":
					_flash_token(who, "pass")
			"cross":
				var who: String = str(event.get("goblin", ""))
				_log("[color=#aaddaa]%d' Cross: %s whips it in[/color]" % [clock_min, who])
				_flash_token(who, "cross")
			"kickoff_pass":
				var from_name: String = str(event.get("from", ""))
				var to_name: String = str(event.get("to", ""))
				_log("[color=yellow]%d' Kick off: %s > %s[/color]" % [clock_min, from_name, to_name])

			# ── Turnovers / drama ──
			"interception":
				var who: String = str(event.get("goblin", ""))
				var from_name: String = str(event.get("from", ""))
				_log("[color=#55ccff]%d' Intercepted! %s reads %s's pass[/color]" % [clock_min, who, from_name])
				_flash_token(who, "interception")
			"bad_touch":
				var who: String = str(event.get("goblin", ""))
				_log("[color=#cc8844]%d' Bad touch: %s loses control[/color]" % [clock_min, who])
				_flash_token(who, "bad_touch")
			"ball_recovery":
				var who: String = str(event.get("goblin", ""))
				_log("[color=#88bbbb]%d' %s recovers the ball[/color]" % [clock_min, who])
			"dispossessed":
				var who: String = str(event.get("goblin", ""))
				var by: String = str(event.get("by", ""))
				_log("[color=#cc8844]%d' %s dispossessed by %s![/color]" % [clock_min, who, by])
				_flash_token(who, "dispossessed")
				_flash_token(by, "tackle")

			# ── Tackles / fouls ──
			"tackle":
				_log("[color=silver]%d' Tackle: %s wins it from %s[/color]" % [clock_min, event["goblin"], event["victim"]])
				_flash_token(str(event["goblin"]), "tackle")
			"tackle_failed":
				_log("[color=#777777]%d' %s lunges in... misses![/color]" % [clock_min, event["goblin"]])
			"foul":
				_log("[color=red][b]%d' FOUL! %s on %s[/b][/color]" % [clock_min, event["goblin"], event["victim"]])
				_flash_token(str(event["goblin"]), "foul")

			# ── Dribbles / skill ──
			"take_on":
				var who: String = str(event.get("goblin", ""))
				var beaten: String = str(event.get("beaten", ""))
				_log("[color=#aaddff]%d' %s beats %s![/color]" % [clock_min, who, beaten])
				_flash_token(who, "take_on")
			"challenge":
				pass  # Implicit in take_on - no separate log needed

			# ── Clearances / aerials ──
			"clearance":
				var who2: String = str(event.get("goblin", ""))
				_log("[color=#aaaaaa]%d' %s clears the danger[/color]" % [clock_min, who2])
			"aerial":
				var winner2: String = str(event.get("winner", ""))
				var loser: String = str(event.get("loser", ""))
				_log("[color=#bbbbdd]%d' Aerial duel: %s wins it over %s[/color]" % [clock_min, winner2, loser])

			# ── Keeper events ──
			"keeper_claim":
				var keeper2: String = str(event.get("keeper", ""))
				_log("[color=orange]%d' %s claims the ball[/color]" % [clock_min, keeper2])
				_flash_token(keeper2, "save")
			"keeper_punch":
				var keeper3: String = str(event.get("keeper", ""))
				_log("[color=orange]%d' %s punches it clear![/color]" % [clock_min, keeper3])
				_flash_token(keeper3, "save")

			# ── Set pieces ──
			"post":
				var who3: String = str(event.get("goblin", ""))
				_log("[color=yellow][b]%d' OFF THE POST! %s hits the frame[/b][/color]" % [clock_min, who3])
			"corner_awarded":
				var team2: String = str(event.get("team", ""))
				_log("[color=#aaddaa]%d' Corner to %s[/color]" % [clock_min, team2])
			"out":
				pass  # Don't spam the log with every out event

			# ── Violence ──
			"injury":
				var who4: String = str(event.get("goblin", ""))
				var sev: String = str(event.get("severity", ""))
				var by2: String = str(event.get("by", ""))
				if sev == "minor":
					_log("[color=orange]%d' %s injured by %s (minor)[/color]" % [clock_min, who4, by2])
				elif sev == "major":
					_log("[color=red]%d' %s BADLY HURT by %s![/color]" % [clock_min, who4, by2])
				_flash_token(who4, "injury")
			"death":
				var who5: String = str(event.get("goblin", ""))
				var by3: String = str(event.get("by", ""))
				_log("[color=red][b]%d' %s KILLED by %s!!![/b][/color]" % [clock_min, who5, by3])
				_flash_token(who5, "death")
			"goblin_removed":
				var who6: String = str(event.get("goblin", ""))
				animated_pitch.remove_goblin_token(who6)
			"team_eliminated":
				var team3: String = str(event.get("team", ""))
				_log("[color=red][b]%s TEAM WIPED OUT![/b][/color]" % [team3.to_upper()])
			"fireball":
				_log("[color=#ff6600][b]%d' FIREBALL! Impact on the pitch![/b][/color]" % [clock_min])
				var fx: float = float(event.get("x", 0.5))
				var fy: float = float(event.get("y", 0.5))
				animated_pitch.play_fireball_explosion(fx, fy)
			"haste":
				_log("[color=#33ff55][b]%d' HASTE! Your goblins surge with speed![/b][/color]" % [clock_min])
			"haste_expired":
				_log("[color=#aaaaaa]%d' Haste wears off...[/color]" % [clock_min])
			"multiball":
				_log("[color=#ffcc33][b]%d' MULTIBALL! Chaos unleashed![/b][/color]" % [clock_min])
			"multiball_goal":
				var mb_team: String = str(event.get("team", ""))
				var mb_sc: Array = event.get("score", [0, 0])
				_log("[color=#ffcc33][b]%d' MULTIBALL GOAL for %s! %d-%d[/b][/color]" % [clock_min, mb_team.to_upper(), mb_sc[0], mb_sc[1]])

func _flash_token(goblin_name: String, event_type: String) -> void:
	var token: Control = animated_pitch.get_goblin_token(goblin_name)
	if token:
		token.flash_event(event_type)

func _update_ui(snapshot: Dictionary) -> void:
	var sc: Array = snapshot["score"]
	clock_label.text = "%d'" % int(snapshot["clock"])

	# Spell button visibility
	_fireball_btn.visible = bool(snapshot.get("fireball_available", false))
	_haste_btn.visible = bool(snapshot.get("haste_available", false))
	_multiball_btn.visible = bool(snapshot.get("multiball_available", false))

	# Track possession
	for gdata: Dictionary in snapshot["goblins"]:
		if bool(gdata.get("has_ball", false)):
			var team: String = str(gdata.get("team", ""))
			if team == "home":
				_home_possession_ticks += 1
			elif team == "away":
				_away_possession_ticks += 1
			_last_ball_owner_team = team
			break

	# Build score line with possession
	var total: int = _home_possession_ticks + _away_possession_ticks
	var poss_str: String = ""
	if total > 20:
		var home_pct: int = int(round(float(_home_possession_ticks) / float(total) * 100.0))
		poss_str = "  (%d%%-%d%%)" % [home_pct, 100 - home_pct]
	score_label.text = "HOME %d - %d AWAY%s" % [sc[0], sc[1], poss_str]

var _halftime_logged: bool = false

func _check_halftime(snapshot: Dictionary) -> void:
	if _halftime_logged:
		return
	if int(snapshot["clock"]) >= 45:
		_halftime_logged = true
		var sc: Array = snapshot["score"]
		_log("")
		_log("[color=yellow]--- HALF TIME: %d - %d ---[/color]" % [sc[0], sc[1]])
		_log("")

func _on_match_over(snapshot: Dictionary) -> void:
	var sc: Array = snapshot["score"]
	var total: int = _home_possession_ticks + _away_possession_ticks
	var home_pct: int = 50
	if total > 0:
		home_pct = int(round(float(_home_possession_ticks) / float(total) * 100.0))
	_log("")
	_log("[color=yellow][b]FULL TIME: %d - %d[/b][/color]" % [sc[0], sc[1]])
	_log("[color=#aaaaaa]Possession: %d%% - %d%%[/color]" % [home_pct, 100 - home_pct])
	if sc[0] > sc[1]:
		_log("[color=lime]HOME WINS![/color]")
	elif sc[1] > sc[0]:
		_log("[color=red]AWAY WINS![/color]")
	else:
		_log("[color=yellow]DRAW![/color]")

	if RunManager.run_active:
		var prev_gold: int = RunManager.gold
		RunManager.record_match_result(int(sc[0]), int(sc[1]))
		RunManager.simulate_remaining_group_matches()
		RunManager.advance_tournament()
		var gold_earned: int = RunManager.gold - prev_gold
		_log("[color=#ffd700]Gold earned: %d (Total: %d)[/color]" % [gold_earned, RunManager.gold])
		back_btn.text = "CONTINUE"
	else:
		back_btn.text = "BACK"

func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_OPTIONS.size()
	_speed_multiplier = SPEED_OPTIONS[_speed_index]
	speed_btn.text = _speed_text()

func _speed_text() -> String:
	return "%.1fx" % _speed_multiplier if _speed_multiplier < 1.0 or fmod(_speed_multiplier, 1.0) != 0.0 else "%dx" % int(_speed_multiplier)

func _log(text: String) -> void:
	event_log.append_text(text + "\n")

# ── Fireball Targeting ─────────────────────────────────────────────────────

func _on_fireball_pressed() -> void:
	if _fireball_targeting:
		_cancel_fireball_targeting()
		return
	_fireball_targeting = true
	_paused = true
	_fireball_btn.text = "CANCEL"
	animated_pitch.set_fireball_targeting(true)
	_log("[color=#ff6600]Click anywhere on the pitch to launch fireball![/color]")

func _on_pitch_clicked(pitch_x: float, pitch_y: float) -> void:
	if not _fireball_targeting:
		return
	sim.cast_fireball(0, pitch_x, pitch_y)
	# Process the events immediately (sim didn't tick, but events were added)
	var snapshot := sim._build_snapshot()
	_process_events(snapshot)
	_cancel_fireball_targeting()

func _cancel_fireball_targeting() -> void:
	_fireball_targeting = false
	_paused = false
	_fireball_btn.text = "FIREBALL"
	animated_pitch.set_fireball_targeting(false)

func _on_haste_pressed() -> void:
	sim.cast_haste(0)
	var snapshot := sim._build_snapshot()
	_process_events(snapshot)

func _on_multiball_pressed() -> void:
	sim.cast_multiball(0)
	var snapshot := sim._build_snapshot()
	_process_events(snapshot)

func _on_back_pressed() -> void:
	if RunManager.run_active and sim != null and sim.is_match_over():
		get_tree().change_scene_to_file("res://scenes/screens/shop.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if _fireball_targeting:
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			_cancel_fireball_targeting()
			return
	if event.is_action_pressed("ui_cancel"):
		if sim != null and sim.is_match_over():
			_on_back_pressed()
		elif not RunManager.run_active:
			get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
