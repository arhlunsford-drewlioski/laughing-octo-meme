extends Control
## Draft screen with carousel navigation and FIFA-style goblin cards.
## Pick 10 goblins from a pool of 20 to form your squad.

const TEAM_SIZE: int = 10
const CARDS_PER_PAGE: int = 5

var full_roster: Array[GoblinData] = []
var selected: Array[GoblinData] = []
var _page: int = 0

@onready var card_row: HBoxContainer = %CardRow
@onready var left_btn: Button = %LeftBtn
@onready var right_btn: Button = %RightBtn
@onready var page_label: Label = %PageLabel
@onready var start_btn: Button = %StartMatchBtn
@onready var count_label: Label = %CountLabel
@onready var title_label: Label = %TitleLabel
@onready var faction_label: Label = %FactionLabel

func _ready() -> void:
	full_roster = GoblinGenerator.generate_draft_pool(20)
	start_btn.pressed.connect(_on_start_match)
	left_btn.pressed.connect(_on_prev_page)
	right_btn.pressed.connect(_on_next_page)
	UITheme.style_button(start_btn)
	UITheme.style_button(left_btn, false)
	UITheme.style_button(right_btn, false)
	start_btn.disabled = true
	_show_page()
	_update_count()

func _total_pages() -> int:
	return ceili(float(full_roster.size()) / CARDS_PER_PAGE)

func _on_prev_page() -> void:
	_page = maxi(_page - 1, 0)
	_show_page()

func _on_next_page() -> void:
	_page = mini(_page + 1, _total_pages() - 1)
	_show_page()

func _show_page() -> void:
	for child in card_row.get_children():
		child.queue_free()

	var start_idx: int = _page * CARDS_PER_PAGE
	var end_idx: int = mini(start_idx + CARDS_PER_PAGE, full_roster.size())

	for i in range(start_idx, end_idx):
		var goblin: GoblinData = full_roster[i]
		var card := _build_fifa_card(goblin)
		card_row.add_child(card)

	left_btn.disabled = _page <= 0
	right_btn.disabled = _page >= _total_pages() - 1
	page_label.text = "%d / %d" % [_page + 1, _total_pages()]

func _build_fifa_card(goblin: GoblinData) -> PanelContainer:
	var is_selected: bool = selected.has(goblin)

	# Card container
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # don't stretch to fill

	var card_bg: Color = Color(0.22, 0.18, 0.12) if is_selected else Color(0.12, 0.11, 0.16)
	var card_border: Color = UITheme.GREEN if is_selected else UITheme.GOLD
	var style := StyleBoxFlat.new()
	style.bg_color = card_bg
	style.border_color = card_border
	style.border_width_left = 3 if is_selected else 2
	style.border_width_right = 3 if is_selected else 2
	style.border_width_top = 3 if is_selected else 2
	style.border_width_bottom = 3 if is_selected else 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Name (top of card)
	var name_label := Label.new()
	name_label.text = goblin.goblin_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", UITheme.CREAM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(name_label)

	# Position + OVR row
	var all_stats: Array[int] = [goblin.shooting, goblin.speed, goblin.defense,
		goblin.strength, goblin.health, goblin.chaos]
	all_stats.sort()
	var top3: float = (all_stats[-1] + all_stats[-2] + all_stats[-3]) / 3.0
	var ovr: int = clampi(roundi(top3 * 10), 10, 99)

	var pos_name: String = PositionDatabase.get_display_name(goblin.position)
	var pos_ovr_label := Label.new()
	pos_ovr_label.text = "%s  %d" % [pos_name.to_upper(), ovr]
	pos_ovr_label.add_theme_font_size_override("font_size", 18)
	pos_ovr_label.add_theme_color_override("font_color", UITheme.GOLD)
	pos_ovr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pos_ovr_label)

	# Divider
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.3))
	vbox.add_child(divider)

	# Stats grid (2 columns, FIFA style)
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 6)
	stats_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(stats_grid)

	var stat_entries := [
		["SHO", goblin.shooting], ["SPD", goblin.speed],
		["DEF", goblin.defense], ["STR", goblin.strength],
		["HP", goblin.health], ["CHA", goblin.chaos]
	]
	var primary_stats := PositionDatabase.get_primary_stats(goblin.position)

	for entry in stat_entries:
		var stat_name_raw: String = {"SHO": "shooting", "SPD": "speed", "DEF": "defense",
			"STR": "strength", "HP": "health", "CHA": "chaos"}.get(entry[0], "")
		var is_primary: bool = stat_name_raw in primary_stats
		var val: int = entry[1]

		var stat_row := HBoxContainer.new()
		stat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_row.add_theme_constant_override("separation", 4)
		stats_grid.add_child(stat_row)

		var val_label := Label.new()
		val_label.text = str(val)
		val_label.add_theme_font_size_override("font_size", 18)
		val_label.custom_minimum_size = Vector2(24, 0)
		var val_color: Color
		if val >= 8:
			val_color = UITheme.GREEN
		elif val >= 6:
			val_color = UITheme.GOLD_LIGHT if is_primary else UITheme.GOLD
		elif val >= 4:
			val_color = UITheme.CREAM
		else:
			val_color = Color(0.7, 0.4, 0.4)
		val_label.add_theme_color_override("font_color", val_color)
		stat_row.add_child(val_label)

		var name_l := Label.new()
		name_l.text = entry[0]
		name_l.add_theme_font_size_override("font_size", 14)
		name_l.add_theme_color_override("font_color", UITheme.CREAM_DIM if not is_primary else UITheme.GOLD)
		stat_row.add_child(name_l)

	# Personality (small flavor text)
	var pers_label := Label.new()
	pers_label.text = goblin.personality
	pers_label.add_theme_font_size_override("font_size", 10)
	pers_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	pers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pers_label.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(pers_label)

	# Select/Deselect button
	var btn := Button.new()
	btn.text = "SELECTED" if is_selected else "DRAFT"
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 14)
	if is_selected:
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.45, 0.15)
		btn_style.corner_radius_top_left = 6
		btn_style.corner_radius_top_right = 6
		btn_style.corner_radius_bottom_left = 6
		btn_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		UITheme.style_button(btn, false)
	btn.pressed.connect(_on_card_pressed.bind(goblin))
	vbox.add_child(btn)

	return card

func _on_card_pressed(goblin: GoblinData) -> void:
	if selected.has(goblin):
		selected.erase(goblin)
	elif selected.size() < TEAM_SIZE:
		selected.append(goblin)
	_show_page()  # Rebuild to update visual state
	_update_count()

func _update_count() -> void:
	count_label.text = "%d / %d selected" % [selected.size(), TEAM_SIZE]
	start_btn.disabled = selected.size() != TEAM_SIZE

	if selected.size() > 0:
		var faction := FactionSystem.get_majority_faction(selected)
		if faction != FactionSystem.Faction.NONE:
			var info := FactionSystem.get_faction_info(faction)
			faction_label.text = info["name"] + " - " + info["style"]
			faction_label.add_theme_color_override("font_color", info["color"])
		else:
			faction_label.text = "Mixed squad (no faction majority)"
			faction_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	else:
		faction_label.text = ""

func _on_start_match() -> void:
	GameManager.selected_roster = selected.duplicate()
	RunManager.start_tournament(selected.duplicate())
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
