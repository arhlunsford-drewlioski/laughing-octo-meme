extends VBoxContainer
## Visual pitch layout. Attack (top) -> Midfield -> Defense -> GK (bottom).
## Tap a goblin to select, tap a zone row to move them there.

signal formation_changed()

const ZONE_COLORS := {
	"attack": Color(0.5, 0.18, 0.15, 0.5),
	"midfield": Color(0.18, 0.35, 0.18, 0.5),
	"defense": Color(0.15, 0.18, 0.4, 0.5),
	"goal": Color(0.3, 0.28, 0.12, 0.5),
}
const SELECTED_COLOR := Color(1.0, 0.85, 0.2, 0.9)

var formation: Formation
var interactive: bool = false
var selected_goblin: GoblinData = null

var zone_rows: Dictionary = {}
var goblin_buttons: Dictionary = {}

func setup(p_formation: Formation, p_interactive: bool) -> void:
	formation = p_formation
	interactive = p_interactive
	selected_goblin = null
	_rebuild()

func set_interactive(value: bool) -> void:
	interactive = value
	selected_goblin = null
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	zone_rows.clear()
	goblin_buttons.clear()

	if formation == null:
		return

	for zone in ["attack", "midfield", "defense", "goal"]:
		var row := _build_zone_row(zone)
		add_child(row)
		zone_rows[zone] = row

func _build_zone_row(zone: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = ZONE_COLORS[zone]
	stylebox.corner_radius_top_left = UITheme.CORNER_RADIUS
	stylebox.corner_radius_top_right = UITheme.CORNER_RADIUS
	stylebox.corner_radius_bottom_left = UITheme.CORNER_RADIUS
	stylebox.corner_radius_bottom_right = UITheme.CORNER_RADIUS
	stylebox.content_margin_left = 8
	stylebox.content_margin_right = 8
	stylebox.content_margin_top = 4
	stylebox.content_margin_bottom = 4
	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.3)
	panel.add_theme_stylebox_override("panel", stylebox)
	panel.custom_minimum_size.y = 70 if zone != "goal" else 56

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var zone_label := Label.new()
	zone_label.text = zone.to_upper()
	zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_label.add_theme_color_override("font_color", UITheme.GOLD)
	zone_label.add_theme_font_size_override("font_size", 12)
	header.add_child(zone_label)

	var count_label := Label.new()
	count_label.text = str(formation.get_zone(zone).size()) + " goblins"
	count_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	count_label.add_theme_font_size_override("font_size", 12)
	header.add_child(count_label)

	var goblin_row := HBoxContainer.new()
	goblin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(goblin_row)

	var goblins: Array[GoblinData] = formation.get_zone(zone)

	for goblin in goblins:
		var btn := _build_goblin_button(goblin, zone)
		goblin_row.add_child(btn)
		goblin_buttons[goblin] = btn

	if interactive:
		var click_area := Button.new()
		click_area.flat = true
		click_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		click_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click_area.pressed.connect(_on_zone_clicked.bind(zone))
		click_area.tooltip_text = "Move selected goblin here"
		goblin_row.add_child(click_area)
		goblin_row.move_child(click_area, 0)

	return panel

func _build_goblin_button(goblin: GoblinData, _zone: String) -> Button:
	var btn := Button.new()
	var pos_short := PositionDatabase.get_display_name(goblin.position)
	btn.text = goblin.goblin_name.split(" ")[0] + "\n" + pos_short
	btn.custom_minimum_size = Vector2(90, 44)

	# Style the button
	var normal_bg := Color(0.2, 0.18, 0.15)
	var style := UITheme.make_button_style(normal_bg, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.4))
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", UITheme.CREAM)
	btn.add_theme_font_size_override("font_size", 12)

	var hover_style := UITheme.make_button_style(Color(0.25, 0.22, 0.18), UITheme.GOLD)
	hover_style.content_margin_top = 4
	hover_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", hover_style)

	if interactive:
		btn.pressed.connect(_on_goblin_clicked.bind(goblin))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if selected_goblin == goblin:
		var sel_style := UITheme.make_button_style(Color(0.4, 0.35, 0.15), SELECTED_COLOR)
		sel_style.content_margin_top = 4
		sel_style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", sel_style)
		btn.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)

	return btn

func _on_goblin_clicked(goblin: GoblinData) -> void:
	if not interactive:
		return
	if selected_goblin == goblin:
		selected_goblin = null
	else:
		selected_goblin = goblin
	_rebuild()

func _on_zone_clicked(zone: String) -> void:
	if not interactive or selected_goblin == null:
		return

	var moved := formation.move_goblin(selected_goblin, zone)
	if moved:
		selected_goblin = null
		formation_changed.emit()
		_rebuild()
