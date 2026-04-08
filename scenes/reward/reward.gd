extends Control
## Post-match card reward screen. Pick 1 of 3 cards to add to your run deck.

const CARD_UI_SCENE := preload("res://scenes/ui/card_ui.tscn")

var reward_choices: Array[CardData] = []

@onready var title_label: Label = %TitleLabel
@onready var result_label: Label = %ResultLabel
@onready var progress_label: Label = %ProgressLabel
@onready var card_row: HBoxContainer = %CardRow
@onready var skip_btn: Button = %SkipBtn

func _ready() -> void:
	skip_btn.pressed.connect(_on_skip)

	# Apply theme styling
	UITheme.style_button(skip_btn, false)
	UITheme.style_dim(progress_label, 14)

	_show_match_result()
	_generate_rewards()
	_display_rewards()

func _show_match_result() -> void:
	var last := RunManager.match_results.back() as Dictionary
	var p: int = last["player_goals"]
	var o: int = last["opponent_goals"]
	var won: bool = last["won"]
	var opp_info := FactionSystem.get_faction_info(last["opponent_faction"])

	if won:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", UITheme.GREEN)
		title_label.add_theme_font_size_override("font_size", 32)
	else:
		title_label.text = "DEFEAT"
		title_label.add_theme_color_override("font_color", UITheme.RED)
		title_label.add_theme_font_size_override("font_size", 32)

	result_label.text = str(p) + " - " + str(o) + " vs " + opp_info["name"]
	result_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	result_label.add_theme_font_size_override("font_size", 18)

	progress_label.text = "Run: " + str(RunManager.wins) + "W - " + str(RunManager.losses) + "L  |  Deck: " + str(RunManager.run_deck_cards.size()) + " cards"

func _generate_rewards() -> void:
	reward_choices = CardDatabase.get_random_rewards(3)

func _display_rewards() -> void:
	for child in card_row.get_children():
		child.queue_free()

	for i in range(reward_choices.size()):
		var card_ui := CARD_UI_SCENE.instantiate()
		card_row.add_child(card_ui)
		card_ui.setup(reward_choices[i], i)
		card_ui.card_clicked.connect(_on_reward_picked)

func _on_reward_picked(index: int) -> void:
	if index < 0 or index >= reward_choices.size():
		return
	RunManager.add_reward_card(reward_choices[index])
	_advance()

func _on_skip() -> void:
	_advance()

func _advance() -> void:
	if RunManager.is_run_over():
		get_tree().change_scene_to_file("res://scenes/run_result/run_result.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
