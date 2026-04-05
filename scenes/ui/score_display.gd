extends HBoxContainer
## Shows current score and round info at top of screen.

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
	_flash_score()

func _on_round_started(round_num: int) -> void:
	round_label.text = "Round " + str(round_num) + "/" + str(GameManager.MAX_ROUNDS)

func _on_energy_changed(new_energy: int) -> void:
	energy_label.text = "Energy: " + str(new_energy) + "/" + str(GameManager.ENERGY_PER_ROUND)

func _flash_score() -> void:
	var original_color := score_label.modulate
	var tween := create_tween()
	tween.tween_property(score_label, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(score_label, "modulate", original_color, 0.3)
	tween.parallel().tween_property(score_label, "scale", Vector2.ONE, 0.3)
