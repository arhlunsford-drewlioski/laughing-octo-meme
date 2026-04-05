extends VBoxContainer
## Visual pitch layout. Attack (top) -> Midfield -> Defense -> GK (bottom).
## Tap a goblin to select, tap a zone row to move them there.

signal formation_changed()

const ZONE_COLORS := {
	"attack": Color(0.6, 0.2, 0.2, 0.4),
	"midfield": Color(0.2, 0.4, 0.2, 0.4),
	"defense": Color(0.2, 0.2, 0.5, 0.4),
	"goal": Color(0.3, 0.3, 0.1, 0.4),
}
const SELECTED_COLOR := Color(1.0, 0.9, 0.2, 0.8)
const GOBLIN_COLOR := Color(0.25, 0.25, 0.3)

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

	var ratings := formation.get_zone_ratings()

	for zone in ["attack", "midfield", "defense", "goal"]:
		var row := _build_zone_row(zone, ratings[zone])
		add_child(row)
		zone_rows[zone] = row

func _build_zone_row(zone: String, total_rating: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = ZONE_COLORS[zone]
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	stylebox.content_margin_left = 8
	stylebox.content_margin_right = 8
	stylebox.content_margin_top = 4
	stylebox.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", stylebox)
	panel.custom_minimum_size.y = 70 if zone != "goal" else 56

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var zone_label := Label.new()
	zone_label.text = zone.to_upper()
	zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(zone_label)

	var total_label := Label.new()
	total_label.text = "Total: " + str(total_rating)
	header.add_child(total_label)

	var goblin_row := HBoxContainer.new()
	goblin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(goblin_row)

	var goblins: Array[GoblinData] = formation.get_zone(zone)

	for goblin in goblins:
		var btn := _build_goblin_button(goblin, zone)
		goblin_row.add_child(btn)
		goblin_buttons[goblin] = btn

	# If interactive, make the zone tappable to move selected goblin here
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

func _build_goblin_button(goblin: GoblinData, zone: String) -> Button:
	var btn := Button.new()
	var rating := goblin.get_rating_for_zone(zone)
	btn.text = goblin.goblin_name.split(" ")[0] + "\n" + str(rating)
	btn.custom_minimum_size = Vector2(90, 44)

	if interactive:
		btn.pressed.connect(_on_goblin_clicked.bind(goblin))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if selected_goblin == goblin:
		var style := StyleBoxFlat.new()
		style.bg_color = SELECTED_COLOR
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)

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
