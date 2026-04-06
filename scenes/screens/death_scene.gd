extends Control
## Comedic goblin elimination scene with dramatic fade-in and narration.

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
	"{name} tried to climb the goalpost. Got stuck. Is still stuck.",
	"{name} challenged the mascot to a fight. The mascot accepted.",
	"{name} blamed their boots. They were wearing sandals.",
	"{name} asked the ref for a do-over. The ref laughed for nine minutes.",
	"{name} swore the ball was cursed. Witnesses confirm the ball was normal.",
	"{name} wrote a strongly-worded letter to the football. No reply yet.",
	"{name} tried to sub themselves on after the final whistle.",
	"{name} fell asleep on the bench. Woke up in the wrong stadium.",
	"{name} was found hiding in the opponent's locker room. Eating their oranges.",
	"{name} tried to take a penalty after the match ended. Missed anyway.",
	"{name} asked the crowd if they saw that. Nobody saw anything.",
	"{name} has been banned from three stadiums. Two of them imaginary.",
	"{name} claims they scored. The scoreboard disagrees. Strongly.",
	"{name} tried to form a union mid-match. No takers.",
	"{name} attempted a slide tackle on the halfway line. Slid into the car park.",
]

@onready var title_label: Label = %TitleLabel
@onready var narration_box: VBoxContainer = %NarrationBox
@onready var try_again_btn: Button = %TryAgainBtn
@onready var fade_overlay: ColorRect = %FadeOverlay

var goblin_names: Array[String] = []
var lines_shown: int = 0
var selected_lines: Array[String] = []

func _ready() -> void:
	try_again_btn.pressed.connect(_on_try_again)
	try_again_btn.visible = false
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(0.5, 0.5)
	title_label.pivot_offset = title_label.size / 2.0

	# Apply theme styling
	UITheme.style_header(title_label, 32)
	UITheme.style_button(try_again_btn)

	# Start fully black
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.visible = true

	# Get player's goblin names
	if RunManager.tournament:
		var player_team := RunManager.tournament.get_team(RunManager.tournament.player_team_index)
		if player_team:
			for g in player_team.roster:
				goblin_names.append(g.goblin_name)

	if goblin_names.is_empty():
		goblin_names = ["Some Goblin", "Another Goblin", "That Goblin"]

	_generate_lines()
	_play_intro()

func _generate_lines() -> void:
	var templates := DEATH_TEMPLATES.duplicate()
	templates.shuffle()
	var names := goblin_names.duplicate()
	names.shuffle()

	selected_lines.clear()
	for i in range(mini(4, templates.size())):
		var name_to_use: String = names[i % names.size()]
		selected_lines.append(templates[i].replace("{name}", name_to_use))

func _play_intro() -> void:
	await get_tree().create_timer(0.8).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, 1.2).set_ease(Tween.EASE_OUT)
	await fade_tween.finished
	fade_overlay.visible = false

	await get_tree().create_timer(0.4).timeout
	_show_title()

func _show_title() -> void:
	title_label.text = "YOUR GOBLINS HAVE\nBEEN ELIMINATED"

	var title_tween := create_tween().set_parallel(true)
	title_tween.tween_property(title_label, "scale", Vector2.ONE, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT)
	await title_tween.finished

	await get_tree().create_timer(1.0).timeout
	_show_next_line()

func _show_next_line() -> void:
	if lines_shown >= selected_lines.size():
		try_again_btn.modulate.a = 0.0
		try_again_btn.visible = true
		var btn_tween := create_tween()
		btn_tween.tween_property(try_again_btn, "modulate:a", 1.0, 0.4)
		return

	var line_label := Label.new()
	line_label.text = selected_lines[lines_shown]
	line_label.add_theme_font_size_override("font_size", 16)
	line_label.add_theme_color_override("font_color", UITheme.CREAM)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.modulate.a = 0.0
	narration_box.add_child(line_label)

	var line_tween := create_tween()
	line_tween.tween_property(line_label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

	lines_shown += 1
	await get_tree().create_timer(2.0).timeout
	_show_next_line()

func _on_try_again() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
