extends Control
## Title screen with New Run and Auto Test buttons.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var auto_test_btn: Button = %AutoTestBtn
@onready var realtime_test_btn: Button = %RealtimeTestBtn
@onready var watch_match_btn: Button = %WatchMatchBtn
@onready var sim_test_btn: Button = %SimTestBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	auto_test_btn.pressed.connect(_on_auto_test)
	realtime_test_btn.pressed.connect(_on_realtime_test)
	watch_match_btn.pressed.connect(_on_watch_match)
	sim_test_btn.pressed.connect(_on_sim_test)

	UITheme.style_header(title_label, 48)
	UITheme.style_dim(subtitle_label, 16)
	UITheme.style_button(new_run_btn)
	UITheme.style_button(auto_test_btn, false)
	UITheme.style_button(realtime_test_btn, false)
	UITheme.style_button(watch_match_btn, false)
	UITheme.style_button(sim_test_btn, false)

func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")

func _on_auto_test() -> void:
	get_tree().change_scene_to_file("res://scenes/match_auto/match_auto.tscn")

func _on_realtime_test() -> void:
	get_tree().change_scene_to_file("res://scenes/match_realtime/match_realtime.tscn")

func _on_watch_match() -> void:
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")

func _on_sim_test() -> void:
	# Switch to the sim log scene
	var log_scene := preload("res://scenes/screens/sim_log.tscn")
	get_tree().change_scene_to_packed(log_scene)
