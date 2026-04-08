extends Control
## Central tournament navigation screen. Shows group standings or knockout bracket.

@onready var stage_label: Label = %StageLabel
@onready var gold_label: Label = %GoldLabel
@onready var content_area: VBoxContainer = %ContentArea
@onready var next_match_btn: Button = %NextMatchBtn
@onready var opponent_label: Label = %OpponentLabel

func _ready() -> void:
	next_match_btn.pressed.connect(_on_next_match)
	UITheme.style_button(next_match_btn)
	UITheme.style_header(stage_label, UITheme.FONT_HEADER)
	_refresh()

func _refresh() -> void:
	if not RunManager.tournament:
		return

	stage_label.text = RunManager.get_stage_name()
	gold_label.text = "Gold: " + str(RunManager.gold)
	gold_label.add_theme_color_override("font_color", UITheme.GOLD)
	gold_label.add_theme_font_size_override("font_size", 16)

	# Clear content
	for child in content_area.get_children():
		child.queue_free()

	if RunManager.is_eliminated():
		_show_eliminated()
		return

	if RunManager.has_won_tournament():
		_show_victory()
		return

	if RunManager.tournament.is_player_in_group_stage():
		_build_group_view()
	else:
		_build_bracket_view()

	# Show next opponent
	var fixture := RunManager.tournament.get_next_player_fixture()
	if fixture:
		var opp_name := RunManager.get_current_opponent_name()
		var opp_faction := RunManager.get_current_opponent_faction()
		var faction_info := FactionSystem.get_faction_info(opp_faction)
		opponent_label.text = "Next: " + opp_name + " (" + faction_info["name"] + ")"
		opponent_label.add_theme_color_override("font_color", faction_info["color"])
		opponent_label.add_theme_font_size_override("font_size", 15)
		next_match_btn.visible = true
		next_match_btn.disabled = false
	else:
		opponent_label.text = ""
		next_match_btn.visible = false

func _show_eliminated() -> void:
	next_match_btn.visible = false
	opponent_label.text = ""
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/screens/death_scene.tscn")

func _show_victory() -> void:
	next_match_btn.visible = false
	opponent_label.text = ""
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/screens/victory_scene.tscn")

func _build_group_view() -> void:
	# Show player's group prominently
	var pg := RunManager.tournament.get_player_group()
	if pg:
		_add_group_table(pg, true)

	# Show other groups smaller
	var other_label := Label.new()
	other_label.text = "Other Groups"
	other_label.add_theme_font_size_override("font_size", 16)
	other_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	other_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_area.add_child(other_label)

	for group in RunManager.tournament.groups:
		if group == pg:
			continue
		_add_group_table(group, false)

func _add_group_table(group: GroupData, is_player_group: bool) -> void:
	# Group header
	var header := Label.new()
	header.text = "Group " + group.group_letter
	header.add_theme_font_size_override("font_size", 20 if is_player_group else 14)
	header.add_theme_color_override("font_color", UITheme.GOLD_LIGHT if is_player_group else UITheme.CREAM_DIM)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_area.add_child(header)

	# Table container with background
	var table_panel := PanelContainer.new()
	var table_style := UITheme.make_panel_style(UITheme.TABLE_HEADER_BG, UITheme.GOLD, 1)
	table_style.content_margin_left = 8
	table_style.content_margin_right = 8
	table_style.content_margin_top = 4
	table_style.content_margin_bottom = 4
	table_panel.add_theme_stylebox_override("panel", table_style)
	content_area.add_child(table_panel)

	var table_vbox := VBoxContainer.new()
	table_vbox.add_theme_constant_override("separation", 0)
	table_panel.add_child(table_vbox)

	# Column headers
	var col_header := _make_styled_row("TEAM", "P", "W", "D", "L", "GD", "PTS", is_player_group)
	col_header.add_theme_color_override("font_color", UITheme.GOLD)
	table_vbox.add_child(col_header)

	var sorted := group.get_sorted_standings()
	for i in range(sorted.size()):
		var s: StandingEntry = sorted[i]
		var team := RunManager.tournament.get_team(s.team_index)
		if not team:
			continue

		# Create row with alternating background
		var row_panel := PanelContainer.new()
		var row_bg := UITheme.TABLE_ROW_EVEN if i % 2 == 0 else UITheme.TABLE_ROW_ODD
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = row_bg
		row_style.content_margin_left = 4
		row_style.content_margin_right = 4
		row_style.content_margin_top = 2
		row_style.content_margin_bottom = 2
		if i == sorted.size() - 1:
			row_style.corner_radius_bottom_left = UITheme.CORNER_RADIUS
			row_style.corner_radius_bottom_right = UITheme.CORNER_RADIUS
		row_panel.add_theme_stylebox_override("panel", row_style)
		table_vbox.add_child(row_panel)

		var name_text := team.team_name
		if name_text.length() > 18:
			name_text = name_text.left(16) + ".."

		var row := _make_styled_row(
			name_text,
			str(s.played), str(s.won), str(s.drawn), str(s.lost),
			str(s.goal_difference) if s.goal_difference <= 0 else "+" + str(s.goal_difference),
			str(s.points),
			is_player_group
		)

		# Color the team name based on status
		if s.team_index == RunManager.tournament.player_team_index:
			row.add_theme_color_override("font_color", UITheme.GREEN)
		elif i < 2 and group.get_sorted_standings()[0].played >= 3:
			row.add_theme_color_override("font_color", UITheme.BLUE)
		else:
			# Faction-colored team name
			var faction_info := FactionSystem.get_faction_info(team.faction)
			row.add_theme_color_override("font_color", faction_info["color"])

		row_panel.add_child(row)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content_area.add_child(spacer)

func _make_styled_row(team_name: String, p: String, w: String, d: String, l: String, gd: String, pts: String, large: bool) -> Label:
	var label := Label.new()
	var font_size := 14 if large else 11
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UITheme.CREAM)
	label.text = _pad(team_name, 18) + _pad(p, 3) + _pad(w, 3) + _pad(d, 3) + _pad(l, 3) + _pad(gd, 4) + _pad(pts, 3)
	return label

func _pad(text: String, width: int) -> String:
	while text.length() < width:
		text += " "
	return text

func _build_bracket_view() -> void:
	var bracket := RunManager.tournament.bracket
	var rounds := [
		["Round of 16", 0, 8],
		["Quarter Finals", 8, 12],
		["Semi Finals", 12, 14],
		["Final", 14, 15],
	]
	for round_info in rounds:
		# Round header
		var round_label := Label.new()
		round_label.text = round_info[0]
		round_label.add_theme_font_size_override("font_size", 16)
		round_label.add_theme_color_override("font_color", UITheme.GOLD)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_area.add_child(round_label)

		# Bracket panel
		var bracket_panel := PanelContainer.new()
		var bp_style := UITheme.make_panel_style(Color(UITheme.BG_PANEL.r, UITheme.BG_PANEL.g, UITheme.BG_PANEL.b, 0.4), UITheme.GOLD, 1)
		bp_style.content_margin_left = 8
		bp_style.content_margin_right = 8
		bp_style.content_margin_top = 4
		bp_style.content_margin_bottom = 4
		bracket_panel.add_theme_stylebox_override("panel", bp_style)
		content_area.add_child(bracket_panel)

		var fixture_vbox := VBoxContainer.new()
		fixture_vbox.add_theme_constant_override("separation", 2)
		bracket_panel.add_child(fixture_vbox)

		for i in range(round_info[1], round_info[2]):
			var f: FixtureData = bracket[i]
			var fixture_label := Label.new()
			fixture_label.text = _format_bracket_fixture(f)
			fixture_label.add_theme_font_size_override("font_size", 13)
			fixture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

			if f.involves_team(RunManager.tournament.player_team_index):
				fixture_label.add_theme_color_override("font_color", UITheme.GREEN)
			elif f.played:
				fixture_label.add_theme_color_override("font_color", UITheme.CREAM)
			else:
				fixture_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
			fixture_vbox.add_child(fixture_label)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		content_area.add_child(spacer)

func _format_bracket_fixture(f: FixtureData) -> String:
	var home_name := "TBD"
	var away_name := "TBD"
	if f.home_index >= 0:
		var ht := RunManager.tournament.get_team(f.home_index)
		if ht:
			home_name = ht.team_name
	if f.away_index >= 0:
		var at := RunManager.tournament.get_team(f.away_index)
		if at:
			away_name = at.team_name
	if f.played:
		return home_name + "  " + str(f.home_goals) + " - " + str(f.away_goals) + "  " + away_name
	return home_name + "  vs  " + away_name

func _on_next_match() -> void:
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")
