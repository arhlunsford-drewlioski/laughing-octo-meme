extends HBoxContainer
## Shows current score, round info, and energy as crystal circles.

@onready var score_label: Label = %ScoreLabel
@onready var round_label: Label = %RoundLabel
@onready var energy_label: Label = %EnergyLabel

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.round_started.connect(_on_round_started)
	GameManager.energy_changed.connect(_on_energy_changed)
	_update_all()

func _update_all() -> void:
	_on_score_changed(GameManager.player_goals, GameManager.opponent_goals)
	_on_round_started(GameManager.current_round)
	_on_energy_changed(GameManager.energy)

func _on_score_changed(player: int, opponent: int) -> void:
	score_label.text = "YOU  " + str(player) + " - " + str(opponent) + "  OPP"
	score_label.add_theme_color_override("font_color", UITheme.CREAM)
	score_label.add_theme_font_size_override("font_size", 28)
	_flash_score()

func _on_round_started(round_num: int) -> void:
	round_label.text = "Round " + str(round_num) + "/" + str(GameManager.MAX_ROUNDS)
	round_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	round_label.add_theme_font_size_override("font_size", 14)

func _on_energy_changed(new_energy: int) -> void:
	var filled := new_energy
	var total := GameManager.ENERGY_PER_ROUND
	var crystals := ""
	for i in range(total):
		if i < filled:
			crystals += " \u25c6"
		else:
			crystals += " \u25c7"
	energy_label.text = crystals.strip_edges()
	energy_label.add_theme_color_override("font_color", UITheme.ENERGY_FILLED)
	energy_label.add_theme_font_size_override("font_size", 18)

func _flash_score() -> void:
	var original_color := score_label.modulate
	var tween := create_tween()
	tween.tween_property(score_label, "modulate", Color(1.0, 0.85, 0.2), 0.1)
	tween.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(score_label, "modulate", original_color, 0.3)
	tween.parallel().tween_property(score_label, "scale", Vector2.ONE, 0.3)
