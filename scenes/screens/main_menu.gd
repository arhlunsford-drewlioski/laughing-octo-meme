extends Control
## Title screen with the two core entry points: tournament and direct spell test.

@onready var new_run_btn: Button = %NewRunBtn
@onready var watch_match_btn: Button = %WatchMatchBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	watch_match_btn.pressed.connect(_on_watch_match)

	# Hide the dev-only row by default; toggle on for debug builds.
	var dev_row := get_node_or_null("CenterContainer/Tome/Margin/VBox/DevButtonRow")
	if dev_row:
		dev_row.visible = false

func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")

func _on_watch_match() -> void:
	RunManager.reset_run()
	GameManager.selected_roster = []
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")
