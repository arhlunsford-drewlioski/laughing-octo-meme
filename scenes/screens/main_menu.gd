extends Control
## Title screen with New Run button.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)

func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")
