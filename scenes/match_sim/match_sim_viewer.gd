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

func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn"))
	speed_btn.pressed.connect(_cycle_speed)

	UITheme.style_button(back_btn, false)
	UITheme.style_button(speed_btn, false)
	score_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	clock_label.add_theme_color_override("font_color", UITheme.CREAM)
	speed_btn.text = _speed_text()

	_setup_and_start()

func _setup_and_start() -> void:
	var player_roster := GoblinDatabase.full_roster().slice(0, 6)
	var opponent_roster := GoblinDatabase.opponent_roster()
	home_formation = GoblinDatabase.build_default_formation(player_roster)
	away_formation = GoblinDatabase.build_default_formation(opponent_roster)

	await animated_pitch.setup(home_formation, away_formation)

	sim = MatchSimulation.new()
	var snapshot := sim.start_match(home_formation, away_formation)
	animated_pitch.apply_snapshot(snapshot)
	_update_ui(snapshot)

	_log("[color=yellow]KICK OFF[/color]")

func _process(delta: float) -> void:
	if sim == null or sim.is_match_over():
		return

	_tick_accumulator += delta * _speed_multiplier
	var tick_interval: float = 1.0 / MatchSimulation.TICKS_PER_SECOND

	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		var snapshot := sim.tick()
		animated_pitch.apply_snapshot(snapshot)
		_process_events(snapshot)
		_update_ui(snapshot)

		if sim.is_match_over():
			_on_match_over(snapshot)
			break

func _process_events(snapshot: Dictionary) -> void:
	var clock_min: int = int(snapshot["clock"])
	for event: Dictionary in snapshot["events"]:
		var etype: String = str(event["type"])
		match etype:
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
				_log("[color=gray]%d' Miss: %s[/color]" % [clock_min, event["goblin"]])
			"block":
				_log("[color=orange]%d' Block: %s[/color]" % [clock_min, event["goblin"]])
			"tackle":
				_log("[color=silver]%d' Tackle: %s on %s[/color]" % [clock_min, event["goblin"], event["victim"]])
				_flash_token(str(event["goblin"]), "tackle")
			"foul":
				_log("[color=red]%d' FOUL: %s on %s[/color]" % [clock_min, event["goblin"], event["victim"]])
				_flash_token(str(event["goblin"]), "foul")

func _flash_token(goblin_name: String, event_type: String) -> void:
	var token: Control = animated_pitch.get_goblin_token(goblin_name)
	if token:
		token.flash_event(event_type)

func _update_ui(snapshot: Dictionary) -> void:
	var sc: Array = snapshot["score"]
	score_label.text = "HOME %d - %d AWAY" % [sc[0], sc[1]]
	clock_label.text = "%d'" % int(snapshot["clock"])

func _on_match_over(snapshot: Dictionary) -> void:
	var sc: Array = snapshot["score"]
	_log("")
	_log("[color=yellow][b]FULL TIME: %d - %d[/b][/color]" % [sc[0], sc[1]])
	if sc[0] > sc[1]:
		_log("[color=lime]HOME WINS![/color]")
	elif sc[1] > sc[0]:
		_log("[color=red]AWAY WINS![/color]")
	else:
		_log("[color=yellow]DRAW![/color]")

func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_OPTIONS.size()
	_speed_multiplier = SPEED_OPTIONS[_speed_index]
	speed_btn.text = _speed_text()

func _speed_text() -> String:
	return "%.1fx" % _speed_multiplier if _speed_multiplier < 1.0 or fmod(_speed_multiplier, 1.0) != 0.0 else "%dx" % int(_speed_multiplier)

func _log(text: String) -> void:
	event_log.append_text(text + "\n")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
