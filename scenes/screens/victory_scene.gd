extends Control
## Tournament victory celebration with stats summary and goblin chaos.

const LEGEND_TEMPLATES: Array[String] = [
	"{name} immediately demanded a statue. Made of cheese.",
	"{name} cried tears of joy. And then tears of confusion.",
	"{name} tried to drink from the trophy. Got stuck.",
	"{name} declared themselves captain. Nobody elected them.",
	"{name} is signing autographs. Nobody asked for one.",
	"{name} has already forgotten which sport this was.",
	"{name} started writing their autobiography. It's three pages of doodles.",
	"{name} is telling everyone they carried the team. They did not.",
	"{name} is wearing the trophy as a hat. It suits them.",
	"{name} sold the exclusive interview rights to a pigeon.",
]

@onready var title_label: Label = %TitleLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var fade_overlay: ColorRect = %FadeOverlay

var _pulse_tween: Tween

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	new_run_btn.visible = false
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(0.5, 0.5)
	title_label.pivot_offset = title_label.size / 2.0
	stats_label.modulate.a = 0.0

	# Apply theme styling
	UITheme.style_header(title_label, 32)
	UITheme.style_button(new_run_btn)

	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.visible = true

	_play_intro()

func _play_intro() -> void:
	await get_tree().create_timer(0.5).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	await fade_tween.finished
	fade_overlay.visible = false

	var title_tween := create_tween().set_parallel(true)
	title_tween.tween_property(title_label, "scale", Vector2.ONE, 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT)
	await title_tween.finished

	_start_title_pulse()

	await get_tree().create_timer(0.6).timeout

	_display_victory()
	var stats_tween := create_tween()
	stats_tween.tween_property(stats_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	await stats_tween.finished

	await get_tree().create_timer(0.5).timeout
	new_run_btn.modulate.a = 0.0
	new_run_btn.visible = true
	var btn_tween := create_tween()
	btn_tween.tween_property(new_run_btn, "modulate:a", 1.0, 0.4)

func _start_title_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(title_label, "scale", Vector2.ONE, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _display_victory() -> void:
	title_label.text = "WORLD CUP CHAMPIONS!"

	var gold_hex := UITheme.GOLD_LIGHT.to_html(false)
	var cream_hex := UITheme.CREAM.to_html(false)
	var dim_hex := UITheme.CREAM_DIM.to_html(false)

	stats_label.clear()
	stats_label.append_text("[center]")
	stats_label.append_text("[color=#" + gold_hex + "]Your goblins have conquered the world.[/color]\n")
	stats_label.append_text("[color=#" + dim_hex + "]Against all odds. Against all logic.[/color]\n\n")

	stats_label.append_text("[color=#" + gold_hex + "]-- TOURNAMENT PATH --[/color]\n\n")

	if RunManager.tournament:
		var pg := RunManager.tournament.get_player_group()
		if pg:
			var player_standing := pg.get_standing(RunManager.tournament.player_team_index)
			if player_standing:
				stats_label.append_text(
					"[color=#" + dim_hex + "]Group " + pg.group_letter + ":[/color] " +
					str(player_standing.won) + "W " +
					str(player_standing.drawn) + "D " +
					str(player_standing.lost) + "L " +
					"(" + str(player_standing.goals_for) + "-" + str(player_standing.goals_against) + ")\n\n"
				)

	var total_goals: int = 0
	for i in range(RunManager.match_results.size()):
		var result: Dictionary = RunManager.match_results[i]
		total_goals += result["player_goals"]
		var outcome := "[color=green]W[/color]" if result["won"] else "[color=red]L[/color]"
		if result["player_goals"] == result["opponent_goals"]:
			outcome = "[color=yellow]D[/color]"
		stats_label.append_text(
			"[color=#" + dim_hex + "]" + result["stage"] + ":[/color] " + outcome +
			" " + str(result["player_goals"]) + "-" + str(result["opponent_goals"]) +
			" vs " + result["opponent_name"] + "\n"
		)

	stats_label.append_text("\n[color=#" + gold_hex + "]Total goals scored: " + str(total_goals) + "[/color]\n")
	stats_label.append_text("[color=#" + cream_hex + "]Final deck: " + str(RunManager.run_deck_cards.size()) + " cards[/color]\n")
	stats_label.append_text("[color=#" + cream_hex + "]Gold earned: " + str(RunManager.gold) + "[/color]\n")

	var p_info := FactionSystem.get_faction_info(RunManager.player_faction)
	if RunManager.player_faction != FactionSystem.Faction.NONE:
		stats_label.append_text("[color=#" + cream_hex + "]Your faction: " + p_info["name"] + "[/color]\n")

	stats_label.append_text("\n[color=#" + gold_hex + "]-- YOUR GOBLINS ARE LEGENDS --[/color]\n\n")

	var goblin_names: Array[String] = []
	if RunManager.tournament:
		var player_team := RunManager.tournament.get_team(RunManager.tournament.player_team_index)
		if player_team:
			for g in player_team.roster:
				goblin_names.append(g.goblin_name)

	if goblin_names.is_empty():
		goblin_names = ["Some Goblin", "Another Goblin"]

	var templates := LEGEND_TEMPLATES.duplicate()
	templates.shuffle()
	var names := goblin_names.duplicate()
	names.shuffle()
	var legend_count := mini(mini(4, templates.size()), names.size())
	for i in range(legend_count):
		var line: String = templates[i].replace("{name}", names[i % names.size()])
		stats_label.append_text("[color=#" + cream_hex + "]" + line + "[/color]\n")

	stats_label.append_text("[/center]")

func _on_new_run() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
