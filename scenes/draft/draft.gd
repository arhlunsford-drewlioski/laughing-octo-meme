extends Control
## Pre-match draft screen. Pick 6 goblins from the full pool.

const TEAM_SIZE: int = 6
const SELECTED_COLOR := Color(0.2, 0.6, 0.3, 1.0)
const UNSELECTED_COLOR := Color(0.15, 0.15, 0.2, 1.0)
const HOVER_COLOR := Color(0.2, 0.2, 0.3, 1.0)

var full_roster: Array[GoblinData] = []
var selected: Array[GoblinData] = []
var goblin_panels: Dictionary = {}  # GoblinData -> PanelContainer

@onready var grid: GridContainer = %GoblinGrid
@onready var start_btn: Button = %StartMatchBtn
@onready var count_label: Label = %CountLabel
@onready var title_label: Label = %TitleLabel

func _ready() -> void:
	full_roster = GoblinDatabase.full_roster()
	start_btn.pressed.connect(_on_start_match)
	start_btn.disabled = true
	_build_roster_display()
	_update_count()

func _build_roster_display() -> void:
	for child in grid.get_children():
		child.queue_free()
	goblin_panels.clear()

	for goblin in full_roster:
		var panel := _build_goblin_panel(goblin)
		grid.add_child(panel)
		goblin_panels[goblin] = panel

func _build_goblin_panel(goblin: GoblinData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 130)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = UNSELECTED_COLOR
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.3, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Name
	var name_label := Label.new()
	name_label.text = goblin.goblin_name
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Personality
	var pers_label := Label.new()
	pers_label.text = goblin.personality
	pers_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	pers_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(pers_label)

	# Stats row
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	vbox.add_child(stats)

	for stat in [["ATK", goblin.attack_rating], ["MID", goblin.midfield_rating], ["DEF", goblin.defense_rating], ["GK", goblin.goal_rating]]:
		var stat_label := Label.new()
		stat_label.text = stat[0] + " " + str(stat[1])
		var color := Color.WHITE
		if stat[1] >= 5:
			color = Color(0.3, 1.0, 0.3)
		elif stat[1] >= 3:
			color = Color(1.0, 0.9, 0.3)
		elif stat[1] <= 1:
			color = Color(0.6, 0.4, 0.4)
		stat_label.add_theme_color_override("font_color", color)
		stat_label.add_theme_font_size_override("font_size", 14)
		stats.add_child(stat_label)

	# Passive
	var passive_label := Label.new()
	passive_label.text = goblin.passive_description
	passive_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	passive_label.add_theme_font_size_override("font_size", 13)
	passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(passive_label)

	# Make clickable
	panel.gui_input.connect(_on_panel_input.bind(goblin))
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return panel

func _on_panel_input(event: InputEvent, goblin: GoblinData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected.has(goblin):
			selected.erase(goblin)
		elif selected.size() < TEAM_SIZE:
			selected.append(goblin)
		_update_visuals()
		_update_count()

func _update_visuals() -> void:
	for goblin in full_roster:
		var panel: PanelContainer = goblin_panels[goblin]
		var stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if selected.has(goblin):
			stylebox.bg_color = SELECTED_COLOR
			stylebox.border_color = Color(0.3, 1.0, 0.4)
		else:
			stylebox.bg_color = UNSELECTED_COLOR
			stylebox.border_color = Color(0.3, 0.3, 0.3)
		panel.queue_redraw()

func _update_count() -> void:
	count_label.text = str(selected.size()) + " / " + str(TEAM_SIZE) + " selected"
	start_btn.disabled = selected.size() != TEAM_SIZE

func _on_start_match() -> void:
	GameManager.selected_roster = selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/match/match.tscn")
