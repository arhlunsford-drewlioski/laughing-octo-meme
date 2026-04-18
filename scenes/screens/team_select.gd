extends Control
## Pick 6 goblins from the alive roster before each match.
## Also handles level-up stat choices (LEVEL UP badge on cards).

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var roster_grid: GridContainer = %RosterGrid
@onready var confirm_btn: Button = %ConfirmBtn
@onready var back_btn: Button = %BackBtn

const REQUIRED_COUNT := 6

var _goblin_buttons: Array[Button] = []
var _selected: Array[GoblinData] = []
var _roster: Array[GoblinData] = []
var _level_up_popup: PanelContainer = null  # Stat picker overlay

func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(_on_back)
	UITheme.style_button(confirm_btn)
	UITheme.style_button(back_btn, false)
	_roster = RunManager.get_alive_roster()
	_build_roster_ui()
	_update_confirm_state()

	# Show opponent info
	var opp_name := RunManager.get_current_opponent_name()
	var stage := RunManager.get_stage_name()
	subtitle_label.text = "%s - vs %s" % [stage, opp_name]
	subtitle_label.add_theme_color_override("font_color", UITheme.CREAM)
	subtitle_label.add_theme_font_size_override("font_size", 15)

func _build_roster_ui() -> void:
	for child in roster_grid.get_children():
		child.queue_free()
	_goblin_buttons.clear()

	for g in _roster:
		var card := _make_goblin_card(g)
		roster_grid.add_child(card)

func _make_goblin_card(g: GoblinData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 140)
	var style := UITheme.make_panel_style(UITheme.BG_CARD, UITheme.CREAM_DIM, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Name + level
	var name_label := Label.new()
	var level_text := "  Lv%d" % g.level if g.level > 1 else ""
	name_label.text = g.goblin_name + level_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	vbox.add_child(name_label)

	# Position + status tags
	var pos_text := g.position.capitalize()
	var status_color := UITheme.CREAM_DIM
	if g.injury == GoblinData.InjuryState.MAJOR:
		pos_text += "  [MAJOR INJURY]"
		status_color = Color.RED
	elif g.injury == GoblinData.InjuryState.MINOR:
		pos_text += "  [MINOR INJURY]"
		status_color = Color.ORANGE
	var pos_label := Label.new()
	pos_label.text = pos_text
	pos_label.add_theme_font_size_override("font_size", 13)
	pos_label.add_theme_color_override("font_color", status_color)
	vbox.add_child(pos_label)

	# Fatigue bar
	if g.fatigue > 0:
		var fatigue_label := Label.new()
		var bar := ""
		for i in 10:
			bar += "|" if i < g.fatigue else "."
		var tired_text := "TIRED " if g.is_fatigued() else ""
		fatigue_label.text = "%sFatigue: %s" % [tired_text, bar]
		fatigue_label.add_theme_font_size_override("font_size", 13)
		if g.is_fatigued():
			fatigue_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			fatigue_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		vbox.add_child(fatigue_label)

	# Stats line (get_stat already includes fatigue + injury + item bonuses)
	var stats_text := "SH:%d SP:%d DE:%d ST:%d HP:%d CH:%d" % [
		g.get_stat("shooting"), g.get_stat("speed"), g.get_stat("defense"),
		g.get_stat("strength"), g.get_stat("health"), g.get_stat("chaos")]
	var stats_label := Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 13)
	if g.is_fatigued() or g.injury != GoblinData.InjuryState.HEALTHY:
		stats_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		stats_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	vbox.add_child(stats_label)

	# Equipped item
	if g.has_item():
		var item: ItemData = g.equipped_item as ItemData
		var item_label := Label.new()
		item_label.text = item.item_name + " (" + item.get_short_stats() + ")"
		item_label.add_theme_font_size_override("font_size", 9)
		item_label.add_theme_color_override("font_color", item.get_rarity_color())
		vbox.add_child(item_label)

	# LEVEL UP button (if pending)
	if g.has_pending_level_up():
		var lvl_btn := Button.new()
		lvl_btn.text = "LEVEL UP! (+%d)" % g.pending_level_ups
		lvl_btn.custom_minimum_size = Vector2(0, 28)
		lvl_btn.add_theme_font_size_override("font_size", 14)
		lvl_btn.add_theme_color_override("font_color", Color.WHITE)
		# Green background for level up
		var lvl_style := StyleBoxFlat.new()
		lvl_style.bg_color = Color(0.15, 0.55, 0.15)
		lvl_style.corner_radius_top_left = 4
		lvl_style.corner_radius_top_right = 4
		lvl_style.corner_radius_bottom_left = 4
		lvl_style.corner_radius_bottom_right = 4
		lvl_btn.add_theme_stylebox_override("normal", lvl_style)
		var lvl_hover := StyleBoxFlat.new()
		lvl_hover.bg_color = Color(0.2, 0.7, 0.2)
		lvl_hover.corner_radius_top_left = 4
		lvl_hover.corner_radius_top_right = 4
		lvl_hover.corner_radius_bottom_left = 4
		lvl_hover.corner_radius_bottom_right = 4
		lvl_btn.add_theme_stylebox_override("hover", lvl_hover)
		lvl_btn.pressed.connect(_show_stat_picker.bind(g))
		vbox.add_child(lvl_btn)
	else:
		# Select button (only if no level-up pending)
		var btn := Button.new()
		btn.text = "SELECT"
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 14)
		UITheme.style_button(btn, false)
		btn.pressed.connect(_on_goblin_toggled.bind(g, btn, panel))
		vbox.add_child(btn)
		_goblin_buttons.append(btn)

	return panel

func _show_stat_picker(g: GoblinData) -> void:
	# Remove existing popup if any
	if _level_up_popup and is_instance_valid(_level_up_popup):
		_level_up_popup.queue_free()

	# Build stat picker overlay
	_level_up_popup = PanelContainer.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	popup_style.border_color = UITheme.GOLD
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.corner_radius_top_left = 8
	popup_style.corner_radius_top_right = 8
	popup_style.corner_radius_bottom_left = 8
	popup_style.corner_radius_bottom_right = 8
	popup_style.content_margin_left = 20
	popup_style.content_margin_right = 20
	popup_style.content_margin_top = 16
	popup_style.content_margin_bottom = 16
	_level_up_popup.add_theme_stylebox_override("panel", popup_style)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 8)
	_level_up_popup.add_child(popup_vbox)

	# Title
	var title := Label.new()
	title.text = "%s LEVELED UP!" % g.goblin_name.to_upper()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a stat to increase (+1)"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", UITheme.CREAM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_vbox.add_child(subtitle)

	# Stat buttons grid
	var stat_grid := GridContainer.new()
	stat_grid.columns = 3
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 6)
	popup_vbox.add_child(stat_grid)

	var stat_labels := {
		"shooting": "SHO", "speed": "SPD", "defense": "DEF",
		"strength": "STR", "health": "HP", "chaos": "CHA"
	}
	var primary_stats := PositionDatabase.get_primary_stats(g.position)

	for stat_name in GoblinData.STAT_KEYS:
		var current_val: int = g.get_stat(stat_name)
		var base_val: int = int(g.get(stat_name))
		var is_primary: bool = stat_name in primary_stats
		var is_maxed: bool = base_val >= 10

		var btn := Button.new()
		var label_short: String = stat_labels.get(stat_name, stat_name.to_upper())
		if is_maxed:
			btn.text = "%s %d (MAX)" % [label_short, current_val]
			btn.disabled = true
		else:
			btn.text = "%s %d -> %d" % [label_short, current_val, current_val + 1]
		btn.custom_minimum_size = Vector2(130, 36)
		btn.add_theme_font_size_override("font_size", 14)

		# Primary stats get gold highlight
		var btn_style := StyleBoxFlat.new()
		if is_primary:
			btn_style.bg_color = Color(0.35, 0.28, 0.12)
			btn.add_theme_color_override("font_color", UITheme.GOLD)
		else:
			btn_style.bg_color = Color(0.18, 0.18, 0.22)
			btn.add_theme_color_override("font_color", UITheme.CREAM)
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", btn_style)

		if not is_maxed:
			btn.pressed.connect(_on_stat_chosen.bind(g, stat_name))
		stat_grid.add_child(btn)

	# Primary stats hint
	var hint := Label.new()
	hint.text = "Gold = primary stats for %s" % g.position.capitalize()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_vbox.add_child(hint)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(0, 30)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	UITheme.style_button(cancel_btn, false)
	cancel_btn.pressed.connect(_close_stat_picker)
	popup_vbox.add_child(cancel_btn)

	# Center the popup on screen
	add_child(_level_up_popup)
	_level_up_popup.set_anchors_preset(Control.PRESET_CENTER)
	_level_up_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_level_up_popup.grow_vertical = Control.GROW_DIRECTION_BOTH

func _on_stat_chosen(g: GoblinData, stat_name: String) -> void:
	g.apply_stat_increase(stat_name)
	_close_stat_picker()
	# Rebuild UI to reflect changes (level-up badge may disappear, stats update)
	_build_roster_ui()
	_update_confirm_state()

func _close_stat_picker() -> void:
	if _level_up_popup and is_instance_valid(_level_up_popup):
		_level_up_popup.queue_free()
		_level_up_popup = null

func _on_goblin_toggled(g: GoblinData, btn: Button, panel: PanelContainer) -> void:
	if g in _selected:
		_selected.erase(g)
		btn.text = "SELECT"
		var style := UITheme.make_panel_style(UITheme.BG_CARD, UITheme.CREAM_DIM, 1)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)
	elif _selected.size() < REQUIRED_COUNT:
		_selected.append(g)
		btn.text = "DESELECT"
		var style := UITheme.make_panel_style(UITheme.BG_CARD, UITheme.GOLD, 2)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)
	_update_confirm_state()

func _update_confirm_state() -> void:
	var count := _selected.size()
	confirm_btn.text = "CONFIRM SQUAD (%d/%d)" % [count, REQUIRED_COUNT]
	confirm_btn.disabled = count != REQUIRED_COUNT

	# Block confirm if any goblin has pending level-ups
	var any_pending := false
	for g in _roster:
		if g.has_pending_level_up():
			any_pending = true
			break
	if any_pending:
		confirm_btn.disabled = true
		confirm_btn.text += " - Level up first!"

	if count < REQUIRED_COUNT:
		title_label.text = "SELECT YOUR SQUAD"
	elif any_pending:
		title_label.text = "ASSIGN LEVEL-UPS FIRST"
	else:
		title_label.text = "SQUAD READY"

func _on_confirm() -> void:
	if _selected.size() != REQUIRED_COUNT:
		return
	# Don't allow confirm with pending level-ups
	for g in _roster:
		if g.has_pending_level_up():
			return
	GameManager.selected_roster = _selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
