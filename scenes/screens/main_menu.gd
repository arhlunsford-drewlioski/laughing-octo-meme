extends Control
## Title screen with New Run and Auto Test buttons.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var auto_test_btn: Button = %AutoTestBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	auto_test_btn.pressed.connect(_on_auto_test)

	UITheme.style_header(title_label, 48)
	UITheme.style_dim(subtitle_label, 16)
	UITheme.style_button(new_run_btn)
	UITheme.style_button(auto_test_btn, false)

func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")

func _on_auto_test() -> void:
	get_tree().change_scene_to_file("res://scenes/match_auto/match_auto.tscn")
