extends Control
## Comedic goblin elimination scene.

const DEATH_TEMPLATES: Array[String] = [
	"{name} tried to eat the ball. The ball won.",
	"{name} sat in the centre circle until groundskeepers built around them.",
	"The team bus left without {name}. Nobody noticed for two days.",
	"{name} ran into a wall on the way out. Kept running.",
	"{name} insisted the referee was wrong. About everything. For three hours.",
	"{name}'s shins have been declared a protected landmark.",
	"{name} tried to take the corner flag home. It was bolted down. They tried anyway.",
	"{name} challenged the opposing keeper to a staring contest. Lost immediately.",
	"{name} is still arguing about the offside rule. Nobody is listening.",
	"{name} attempted a victory lap despite the loss. Got lapped by a pigeon.",
	"{name} blamed the pitch. The pitch was fine.",
	"{name} submitted a formal complaint about gravity.",
	"{name} was last seen headbutting the crossbar for luck.",
	"Nobody told {name} the match was over. They're still playing.",
	"{name} demanded a rematch. Against the ball.",
	"{name} tried to bribe the ref with a half-eaten sandwich.",
	"{name} claims they were fouled. By the wind.",
	"{name} has retired from football. Effective three minutes ago.",
	"{name} was carried off by a suspiciously organized flock of crows.",
	"{name} refused to leave the pitch. They live there now.",
]

@onready var title_label: Label = %TitleLabel
@onready var narration_box: VBoxContainer = %NarrationBox
@onready var try_again_btn: Button = %TryAgainBtn

var goblin_names: Array[String] = []
var lines_shown: int = 0
var selected_lines: Array[String] = []

func _ready() -> void:
	try_again_btn.pressed.connect(_on_try_again)
	try_again_btn.visible = false

	# Get player's goblin names
	if RunManager.tournament:
		var player_team := RunManager.tournament.get_team(RunManager.tournament.player_team_index)
		if player_team:
			for g in player_team.roster:
				goblin_names.append(g.goblin_name)

	if goblin_names.is_empty():
		goblin_names = ["Some Goblin", "Another Goblin", "That Goblin"]

	_generate_lines()
	_show_title()

func _generate_lines() -> void:
	var templates := DEATH_TEMPLATES.duplicate()
	templates.shuffle()
	var names := goblin_names.duplicate()
	names.shuffle()

	selected_lines.clear()
	for i in range(mini(4, templates.size())):
		var name_to_use: String = names[i % names.size()]
		selected_lines.append(templates[i].replace("{name}", name_to_use))

func _show_title() -> void:
	title_label.text = "YOUR GOBLINS HAVE\nBEEN ELIMINATED"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	# Start showing narration lines after a delay
	await get_tree().create_timer(1.5).timeout
	_show_next_line()

func _show_next_line() -> void:
	if lines_shown >= selected_lines.size():
		# All lines shown - show button
		try_again_btn.visible = true
		return

	var line_label := Label.new()
	line_label.text = selected_lines[lines_shown]
	line_label.add_theme_font_size_override("font_size", 16)
	line_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration_box.add_child(line_label)

	lines_shown += 1
	await get_tree().create_timer(2.0).timeout
	_show_next_line()

func _on_try_again() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
