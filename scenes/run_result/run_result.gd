extends Control
## End-of-run summary screen. Shows final record and match history.

@onready var title_label: Label = %TitleLabel
@onready var record_label: Label = %RecordLabel
@onready var details_label: RichTextLabel = %DetailsLabel
@onready var new_run_btn: Button = %NewRunBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)

	# Apply theme styling
	UITheme.style_button(new_run_btn)

	_display_results()

func _display_results() -> void:
	if RunManager.is_run_won():
		title_label.text = "RUN COMPLETE!"
		title_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	else:
		title_label.text = "ELIMINATED"
		title_label.add_theme_color_override("font_color", UITheme.RED)
	title_label.add_theme_font_size_override("font_size", 36)

	record_label.text = str(RunManager.wins) + "W - " + str(RunManager.losses) + "L"
	record_label.add_theme_color_override("font_color", UITheme.CREAM)
	record_label.add_theme_font_size_override("font_size", 28)

	var gold_hex := UITheme.GOLD.to_html(false)
	var cream_hex := UITheme.CREAM.to_html(false)
	var dim_hex := UITheme.CREAM_DIM.to_html(false)

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
			"[color=#" + dim_hex + "]Match " + str(i + 1) + ":[/color] " + outcome +
			"  " + str(result["player_goals"]) + "-" + str(result["opponent_goals"]) +
			"  vs [color=#" + color_hex + "]" + opp_info["name"] + "[/color]" +
			" [color=#" + dim_hex + "](" + opp_info["style"] + ")[/color]\n"
		)

	details_label.append_text("\n[color=#" + cream_hex + "]Final deck: " + str(RunManager.run_deck_cards.size()) + " cards[/color]")

	var p_info := FactionSystem.get_faction_info(RunManager.player_faction)
	if RunManager.player_faction != FactionSystem.Faction.NONE:
		details_label.append_text("\n[color=#" + cream_hex + "]Your faction: " + p_info["name"] + "[/color]")
	details_label.append_text("[/center]")

func _on_new_run() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")
