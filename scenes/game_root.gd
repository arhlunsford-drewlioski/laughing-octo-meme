extends Control
## Root scene. Manages screen transitions for the entire game.

func _ready() -> void:
	# Start at main menu
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
