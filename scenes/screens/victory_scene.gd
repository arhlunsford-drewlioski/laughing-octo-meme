extends Control
## Tournament victory celebration with stats summary.

@onready var title_label: Label = %TitleLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var new_run_btn: Button = %NewRunBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	_display_victory()

func _display_victory() -> void:
	title_label.text = "WORLD CUP CHAMPIONS!"

	stats_label.clear()
	stats_label.append_text("[center]")
	stats_label.append_text("Your goblins have conquered the world.\n")
	stats_label.append_text("Against all odds. Against all logic.\n\n")

	# Match history
	for i in range(RunManager.match_results.size()):
		var result: Dictionary = RunManager.match_results[i]
		var outcome := "[color=green]W[/color]" if result["won"] else "[color=red]L[/color]"
		if result["player_goals"] == result["opponent_goals"]:
			outcome = "[color=yellow]D[/color]"
		stats_label.append_text(
			result["stage"] + ": " + outcome +
			" " + str(result["player_goals"]) + "-" + str(result["opponent_goals"]) +
			" vs " + result["opponent_name"] + "\n"
		)

	stats_label.append_text("\nFinal deck: " + str(RunManager.run_deck_cards.size()) + " cards")
	stats_label.append_text("\nGold earned: " + str(RunManager.gold))

	var p_info := FactionSystem.get_faction_info(RunManager.player_faction)
	if RunManager.player_faction != FactionSystem.Faction.NONE:
		stats_label.append_text("\nYour faction: " + p_info["name"])
	stats_label.append_text("[/center]")

func _on_new_run() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
