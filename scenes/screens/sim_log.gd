extends Control
## In-game match simulation log. Runs headless sim and displays play-by-play.

@onready var log_label: RichTextLabel = %LogLabel
@onready var score_label: Label = %ScoreLabel
@onready var back_btn: Button = %BackBtn
@onready var rerun_btn: Button = %RerunBtn

func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn"))
	rerun_btn.pressed.connect(_run_sim)
	UITheme.style_button(back_btn, false)
	UITheme.style_button(rerun_btn)
	_run_sim()

func _run_sim() -> void:
	log_label.clear()
	score_label.text = "Simulating..."

	var player_roster := GoblinDatabase.full_roster().slice(0, 6)
	var opponent_roster := GoblinDatabase.opponent_roster()
	var home := GoblinDatabase.build_default_formation(player_roster)
	var away := GoblinDatabase.build_default_formation(opponent_roster)

	_log("[color=yellow]═══ MATCH SIMULATION ═══[/color]")
	_log("")

	# Print rosters
	_log("[color=cyan]HOME TEAM:[/color]")
	for g in home.get_all():
		_log("  %s [%s] SHO:%d SPD:%d DEF:%d STR:%d" % [
			g.goblin_name, g.position, g.shooting, g.speed, g.defense, g.strength])
	_log("")
	_log("[color=red]AWAY TEAM:[/color]")
	for g in away.get_all():
		_log("  %s [%s] SHO:%d SPD:%d DEF:%d STR:%d" % [
			g.goblin_name, g.position, g.shooting, g.speed, g.defense, g.strength])
	_log("")
	_log("[color=yellow]───── KICK OFF ─────[/color]")

	var sim := MatchSimulation.new()
	var snapshot: Dictionary = sim.start_match(home, away)

	var shot_count: int = 0
	var goal_count: int = 0
	var halftime_shown: bool = false

	while not sim.is_match_over():
		snapshot = sim.tick()
		var clock: float = float(snapshot["clock"])

		if not halftime_shown and clock >= 45.0:
			halftime_shown = true
			var sc: Array = snapshot["score"]
			_log("")
			_log("[color=yellow]───── HALF TIME %d-%d ─────[/color]" % [sc[0], sc[1]])
			_log("")

		var events: Array = snapshot["events"]
		for event: Dictionary in events:
			var m: int = int(clock)
			var etype: String = str(event["type"])
			match etype:
				"goal":
					goal_count += 1
					var sc: Array = event["score"]
					_log("[color=lime][b]%d' GOAL! %s! Score: %d-%d[/b][/color]" % [m, event["goblin"], sc[0], sc[1]])
				"shot":
					shot_count += 1
					_log("[color=white]%d' Shot by %s (pwr:%.1f acc:%.1f)[/color]" % [m, event["goblin"], event["power"], event["accuracy"]])
				"save":
					_log("[color=orange]%d' Save! %s stops %s[/color]" % [m, event["keeper"], event["shooter"]])
				"miss":
					_log("[color=gray]%d' Miss by %s[/color]" % [m, event["goblin"]])
				"block":
					_log("[color=orange]%d' Blocked! %s blocks %s[/color]" % [m, event["goblin"], event["shooter"]])
				"tackle":
					_log("[color=silver]%d' Tackle: %s wins ball from %s[/color]" % [m, event["goblin"], event["victim"]])
				"foul":
					_log("[color=red]%d' FOUL! %s on %s[/color]" % [m, event["goblin"], event["victim"]])
				"dispossessed":
					_log("[color=silver]%d' %s dispossessed by %s[/color]" % [m, event["goblin"], event["by"]])
				"match_end":
					var sc: Array = event["score"]
					_log("")
					_log("[color=yellow][b]FULL TIME: %d-%d[/b][/color]" % [sc[0], sc[1]])

	var sc: Array = snapshot["score"]
	_log("")
	_log("Shots: %d | Goals: %d" % [shot_count, goal_count])
	_log("")
	_log("[color=cyan]--- DEBUG ---[/color]")
	for line in sim.get_debug_summary().split("\n"):
		_log(line)
	score_label.text = "FINAL: %d - %d  (Shots: %d)" % [sc[0], sc[1], shot_count]

func _log(text: String) -> void:
	log_label.append_text(text + "\n")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
