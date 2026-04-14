extends Control
## Pick 6 goblins from the alive roster before each match.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var roster_grid: GridContainer = %RosterGrid
@onready var confirm_btn: Button = %ConfirmBtn
@onready var back_btn: Button = %BackBtn

const REQUIRED_COUNT := 6

var _goblin_buttons: Array[Button] = []
var _selected: Array[GoblinData] = []
var _roster: Array[GoblinData] = []

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
	panel.custom_minimum_size = Vector2(170, 120)
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
	name_label.add_theme_font_size_override("font_size", 14)
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
	pos_label.add_theme_font_size_override("font_size", 11)
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
		fatigue_label.add_theme_font_size_override("font_size", 10)
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
	stats_label.add_theme_font_size_override("font_size", 10)
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

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 12)
	UITheme.style_button(btn, false)
	btn.pressed.connect(_on_goblin_toggled.bind(g, btn, panel))
	vbox.add_child(btn)

	_goblin_buttons.append(btn)

	# Auto-select available goblins if roster is exactly 6
	# (handled after all cards built)

	return panel

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

	if count < REQUIRED_COUNT:
		title_label.text = "SELECT YOUR SQUAD"
	else:
		title_label.text = "SQUAD READY"

func _on_confirm() -> void:
	if _selected.size() != REQUIRED_COUNT:
		return
	GameManager.selected_roster = _selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
