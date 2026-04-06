extends Control
## End-of-run summary screen. Shows final record and match history.

@onready var title_label: Label = %TitleLabel
@onready var record_label: Label = %RecordLabel
@onready var details_label: RichTextLabel = %DetailsLabel
@onready var new_run_btn: Button = %NewRunBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	_display_results()

func _display_results() -> void:
	if RunManager.is_run_won():
		title_label.text = "RUN COMPLETE!"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		title_label.text = "ELIMINATED"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	record_label.text = str(RunManager.wins) + "W - " + str(RunManager.losses) + "L"

	details_label.clear()
	details_label.append_text("[center]")
	for i in range(RunManager.match_results.size()):
		var result: Dictionary = RunManager.match_results[i]
		var opp_info := FactionSystem.get_faction_info(result["opponent_faction"])
		var opp_color := opp_info["color"] as Color
		var color_hex := opp_color.to_html(false)
		var outcome: String
		if result["won"]:
			outcome = "[color=green]W[/color]"
		else:
			outcome = "[color=red]L[/color]"
		details_label.append_text(
			"Match " + str(i + 1) + ": " + outcome +
			"  " + str(result["player_goals"]) + "-" + str(result["opponent_goals"]) +
			"  vs [color=#" + color_hex + "]" + opp_info["name"] + "[/color]" +
			" (" + opp_info["style"] + ")\n"
		)

	details_label.append_text("\nFinal deck: " + str(RunManager.run_deck_cards.size()) + " cards")

	var p_info := FactionSystem.get_faction_info(RunManager.player_faction)
	if RunManager.player_faction != FactionSystem.Faction.NONE:
		details_label.append_text("\nYour faction: " + p_info["name"])
	details_label.append_text("[/center]")

func _on_new_run() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")
