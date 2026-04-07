extends Control
## Pre-match draft screen. Pick 6 goblins from the full pool.

const TEAM_SIZE: int = 6
const SELECTED_COLOR := Color(0.2, 0.45, 0.2, 1.0)
const UNSELECTED_COLOR := Color(0.165, 0.141, 0.114, 1.0)

var full_roster: Array[GoblinData] = []
var selected: Array[GoblinData] = []
var goblin_panels: Dictionary = {}

@onready var grid: GridContainer = %GoblinGrid
@onready var start_btn: Button = %StartMatchBtn
@onready var count_label: Label = %CountLabel
@onready var title_label: Label = %TitleLabel
@onready var faction_label: Label = %FactionLabel

func _ready() -> void:
	full_roster = GoblinDatabase.full_roster()
	start_btn.pressed.connect(_on_start_match)
	start_btn.disabled = true

	# Apply theme styling
	UITheme.style_header(title_label, UITheme.FONT_HEADER)
	UITheme.style_dim(count_label, 16)
	UITheme.style_button(start_btn)

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
	panel.custom_minimum_size = Vector2(320, 150)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = UNSELECTED_COLOR
	stylebox.corner_radius_top_left = UITheme.CORNER_RADIUS
	stylebox.corner_radius_top_right = UITheme.CORNER_RADIUS
	stylebox.corner_radius_bottom_left = UITheme.CORNER_RADIUS
	stylebox.corner_radius_bottom_right = UITheme.CORNER_RADIUS
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	stylebox.border_width_left = UITheme.BORDER_WIDTH
	stylebox.border_width_right = UITheme.BORDER_WIDTH
	stylebox.border_width_top = UITheme.BORDER_WIDTH
	stylebox.border_width_bottom = UITheme.BORDER_WIDTH
	stylebox.border_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.3)
	panel.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Name
	var name_label := Label.new()
	name_label.text = goblin.goblin_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", UITheme.CREAM)
	vbox.add_child(name_label)

	# Faction
	var faction_info := FactionSystem.get_faction_info(goblin.faction)
	var f_label := Label.new()
	f_label.text = faction_info["name"] + " - " + faction_info["style"]
	f_label.add_theme_color_override("font_color", faction_info["color"])
	f_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(f_label)

	# Personality
	var pers_label := Label.new()
	pers_label.text = goblin.personality
	pers_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	pers_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(pers_label)

	# Stats row
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	vbox.add_child(stats)

	for stat in [["SHO", goblin.shooting], ["SPD", goblin.speed], ["DEF", goblin.defense],
			["STR", goblin.strength], ["HP", goblin.health], ["CHA", goblin.chaos]]:
		var stat_label := Label.new()
		stat_label.text = stat[0] + " " + str(stat[1])
		var color := UITheme.CREAM
		if stat[1] >= 7:
			color = UITheme.GREEN
		elif stat[1] >= 4:
			color = UITheme.GOLD
		elif stat[1] <= 2:
			color = Color(0.6, 0.4, 0.4)
		stat_label.add_theme_color_override("font_color", color)
		stat_label.add_theme_font_size_override("font_size", 14)
		stats.add_child(stat_label)

	# Position
	var pos_label := Label.new()
	pos_label.text = PositionDatabase.get_display_name(goblin.position)
	pos_label.add_theme_color_override("font_color", UITheme.ENERGY_FILLED)
	pos_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(pos_label)

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
			stylebox.border_color = UITheme.GREEN
		else:
			stylebox.bg_color = UNSELECTED_COLOR
			stylebox.border_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.3)
		panel.queue_redraw()

func _update_count() -> void:
	count_label.text = str(selected.size()) + " / " + str(TEAM_SIZE) + " selected"
	start_btn.disabled = selected.size() != TEAM_SIZE

	if selected.size() > 0:
		var faction := FactionSystem.get_majority_faction(selected)
		if faction != FactionSystem.Faction.NONE:
			var info := FactionSystem.get_faction_info(faction)
			faction_label.text = "Team: " + info["name"] + " (" + info["style"] + ")"
			faction_label.add_theme_color_override("font_color", info["color"])
		else:
			faction_label.text = "Team: Mixed (no faction bonus)"
			faction_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	else:
		faction_label.text = ""

func _on_start_match() -> void:
	GameManager.selected_roster = selected.duplicate()
	RunManager.start_tournament(selected.duplicate())
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
