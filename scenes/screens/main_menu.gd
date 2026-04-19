extends Control
## Title screen with the two core entry points: tournament and direct spell test.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var auto_test_btn: Button = %AutoTestBtn
@onready var realtime_test_btn: Button = %RealtimeTestBtn
@onready var watch_match_btn: Button = %WatchMatchBtn
@onready var sim_test_btn: Button = %SimTestBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	watch_match_btn.pressed.connect(_on_watch_match)

	UITheme.style_header(title_label, 48)
	UITheme.style_dim(subtitle_label, 16)
	UITheme.style_button(new_run_btn)
	UITheme.style_button(watch_match_btn)

	subtitle_label.text = "Tournament mode or a loaded spell test match"
	watch_match_btn.text = "SPELL TEST MATCH"

	auto_test_btn.visible = false
	realtime_test_btn.visible = false
	sim_test_btn.visible = false

func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")

func _on_watch_match() -> void:
	RunManager.reset_run()
	GameManager.selected_roster = []
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")
