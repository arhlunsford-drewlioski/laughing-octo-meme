extends Control
## Central tournament navigation screen.
## Two-column layout: left = standings/bracket, right = next-match scouting card.

var _shell: PageShell
var _left_content: VBoxContainer
var _opponent_name_l: Label
var _opponent_arch_l: Label
var _opponent_book_l: Label
var _opponent_book_icon: Label
var _next_match_btn: BigCTA


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	_shell = PageShell.new()
	add_child(_shell)
	_shell.top_rail.bind_run_state()

	# Header
	var head := Label.new()
	head.theme_type_variation = &"HeaderLabel"
	head.text = "TOURNAMENT"
	head.add_theme_font_size_override("font_size", 32)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shell.center_content.add_child(head)

	# Two-column body
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	_shell.center_content.add_child(body)

	# LEFT (~62%): standings/bracket scroll
	var left_panel := PanelContainer.new()
	left_panel.theme_type_variation = &"WoodPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.65
	body.add_child(left_panel)

	var left_inner := VBoxContainer.new()
	left_inner.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_inner)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_inner.add_child(left_scroll)

	_left_content = VBoxContainer.new()
	_left_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_content.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_left_content)

	# RIGHT (~38%): scouting card
	var right_panel := PanelContainer.new()
	right_panel.theme_type_variation = &"WoodPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	body.add_child(right_panel)

	var right_inner := VBoxContainer.new()
	right_inner.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_inner)

	var scouting_label := Label.new()
	scouting_label.theme_type_variation = &"HeaderLabel"
	scouting_label.text = "NEXT MATCH"
	scouting_label.add_theme_font_size_override("font_size", 22)
	scouting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_inner.add_child(scouting_label)

	var divider := ColorRect.new()
	divider.color = UITheme.GOLD_DEEP
	divider.custom_minimum_size = Vector2(0, 1)
	right_inner.add_child(divider)

	# Opponent portrait placeholder
	var portrait := PanelContainer.new()
	portrait.add_theme_stylebox_override("panel", UITheme.make_panel_bg(UITheme.WINE_DEEP, UITheme.GOLD, 3))
	portrait.custom_minimum_size = Vector2(0, 120)
	right_inner.add_child(portrait)

	var portrait_inner := VBoxContainer.new()
	portrait_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(portrait_inner)

	_opponent_book_icon = Label.new()
	_opponent_book_icon.text = "?"
	_opponent_book_icon.add_theme_font_size_override("font_size", 64)
	_opponent_book_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_inner.add_child(_opponent_book_icon)

	_opponent_name_l = Label.new()
	_opponent_name_l.theme_type_variation = &"HeaderLabel"
	_opponent_name_l.add_theme_font_size_override("font_size", 22)
	_opponent_name_l.text = ""
	_opponent_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opponent_name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_inner.add_child(_opponent_name_l)

	_opponent_arch_l = Label.new()
	_opponent_arch_l.theme_type_variation = &"SubheaderLabel"
	_opponent_arch_l.add_theme_color_override("font_color", UITheme.PARCHMENT)
	_opponent_arch_l.add_theme_font_size_override("font_size", 14)
	_opponent_arch_l.text = ""
	_opponent_arch_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_inner.add_child(_opponent_arch_l)

	_opponent_book_l = Label.new()
	_opponent_book_l.theme_type_variation = &"DimLabel"
	_opponent_book_l.add_theme_font_size_override("font_size", 13)
	_opponent_book_l.text = ""
	_opponent_book_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_inner.add_child(_opponent_book_l)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_inner.add_child(spacer)

	# Action bar — primary CTA
	_next_match_btn = _shell.add_primary_cta("MARSHAL THE ELEVEN", _on_next_match)


func _refresh() -> void:
	if not RunManager.tournament:
		return

	# Clear left
	for c in _left_content.get_children():
		c.queue_free()

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

	# Right scouting
	var fixture := RunManager.tournament.get_next_player_fixture()
	if fixture:
		var opp_name := RunManager.get_current_opponent_name()
		var arch_name := RunManager.get_current_opponent_archetype_name()
		var opp_book = RunManager.get_current_opponent_spellbook()
		_opponent_name_l.text = opp_name.to_upper()
		_opponent_arch_l.text = arch_name
		if opp_book:
			_opponent_book_icon.text = str(opp_book.icon)
			_opponent_book_l.text = "%s · %d page%s bound" % [
				opp_book.book_name, opp_book.pages.size(),
				"" if opp_book.pages.size() == 1 else "s"
			]
			var c: Color = opp_book.color if opp_book.color.a > 0.05 else UITheme.GOLD_LIGHT
			_opponent_book_l.add_theme_color_override("font_color", c)
		else:
			_opponent_book_icon.text = "✦"
			_opponent_book_l.text = ""
		_next_match_btn.visible = true
		_next_match_btn.disabled = false
	else:
		_opponent_name_l.text = ""
		_opponent_arch_l.text = ""
		_opponent_book_l.text = ""
		_next_match_btn.visible = false


func _show_eliminated() -> void:
	_next_match_btn.visible = false
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://scenes/screens/death_scene.tscn")


func _show_victory() -> void:
	_next_match_btn.visible = false
	await get_tree().create_timer(0.6).timeout
	get_tree().change_scene_to_file("res://scenes/screens/victory_scene.tscn")


# ── Group view ────────────────────────────────────────────────────────

func _build_group_view() -> void:
	var pg := RunManager.tournament.get_player_group()
	if pg:
		_left_content.add_child(_make_group_table(pg, true))

	var divider := Label.new()
	divider.theme_type_variation = &"DimLabel"
	divider.text = "OTHER GROUPS"
	divider.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	divider.add_theme_font_size_override("font_size", 13)
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_content.add_child(divider)

	for group in RunManager.tournament.groups:
		if group == pg:
			continue
		_left_content.add_child(_make_group_table(group, false))


func _make_group_table(group: GroupData, is_player_group: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.theme_type_variation = &"HeaderLabel"
	header.text = "GROUP %s" % group.group_letter
	header.add_theme_font_size_override("font_size", 20 if is_player_group else 14)
	if not is_player_group:
		header.add_theme_color_override("font_color", UITheme.PARCHMENT_DEEP)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(header)

	var panel := PanelContainer.new()
	var border: Color = UITheme.GOLD_LIGHT if is_player_group else UITheme.GOLD_DEEP
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg(UITheme.BG_PANEL, border, 2 if is_player_group else 1))
	v.add_child(panel)

	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 0)
	panel.add_child(table)

	# Column header
	table.add_child(_make_table_row("TEAM", "P", "W", "D", "L", "GD", "PTS",
		UITheme.GOLD_DEEP, is_player_group, true, 0))

	var sorted := group.get_sorted_standings()
	for i in range(sorted.size()):
		var s: StandingEntry = sorted[i]
		var team := RunManager.tournament.get_team(s.team_index)
		if not team:
			continue
		var name_text := team.team_name
		if name_text.length() > 18:
			name_text = name_text.left(16) + ".."

		var color: Color = UITheme.PARCHMENT
		if s.team_index == RunManager.tournament.player_team_index:
			color = UITheme.EMERALD_LIGHT
		elif i < 2 and group.get_sorted_standings()[0].played >= 3:
			color = UITheme.GOLD_LIGHT

		var row := _make_table_row(
			name_text,
			str(s.played), str(s.won), str(s.drawn), str(s.lost),
			("+" + str(s.goal_difference)) if s.goal_difference > 0 else str(s.goal_difference),
			str(s.points),
			color, is_player_group, false, i
		)
		table.add_child(row)

	return v


func _make_table_row(team_name: String, p: String, w: String, d: String, l: String,
		gd: String, pts: String, color: Color, large: bool, is_header: bool, row_index: int = 0) -> Control:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	if is_header:
		s.bg_color = UITheme.BG_DARK
	else:
		s.bg_color = UITheme.BG_PANEL.lightened(0.04) if row_index % 2 == 0 else UITheme.BG_PANEL
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", s)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	pc.add_child(hb)

	var fs := 14 if large else 12

	var name_l := Label.new()
	name_l.text = team_name
	name_l.add_theme_color_override("font_color", color)
	name_l.add_theme_font_size_override("font_size", fs)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(name_l)

	for col_text in [p, w, d, l, gd, pts]:
		var l_node := Label.new()
		l_node.text = col_text
		l_node.add_theme_color_override("font_color", color)
		l_node.add_theme_font_size_override("font_size", fs)
		l_node.custom_minimum_size = Vector2(36, 0)
		l_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(l_node)

	return pc


# ── Bracket view ──────────────────────────────────────────────────────

func _build_bracket_view() -> void:
	var bracket = RunManager.tournament.bracket
	var rounds := [
		["Round of 16", 0, 8],
		["Quarter Finals", 8, 12],
		["Semi Finals", 12, 14],
		["Final", 14, 15],
	]
	for round_info in rounds:
		var round_box := VBoxContainer.new()
		round_box.add_theme_constant_override("separation", 4)
		_left_content.add_child(round_box)

		var round_label := Label.new()
		round_label.theme_type_variation = &"HeaderLabel"
		round_label.text = str(round_info[0]).to_upper()
		round_label.add_theme_font_size_override("font_size", 18)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		round_box.add_child(round_label)

		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg(UITheme.BG_PANEL, UITheme.GOLD_DEEP, 1))
		round_box.add_child(panel)

		var fix_v := VBoxContainer.new()
		fix_v.add_theme_constant_override("separation", 2)
		panel.add_child(fix_v)

		for i in range(int(round_info[1]), int(round_info[2])):
			var f: FixtureData = bracket[i]
			fix_v.add_child(_make_fixture_label(f))


func _make_fixture_label(f: FixtureData) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)

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

	var color: Color = UITheme.PARCHMENT_DARK
	if f.involves_team(RunManager.tournament.player_team_index):
		color = UITheme.EMERALD_LIGHT
	elif f.played:
		color = UITheme.PARCHMENT

	var line := Label.new()
	line.add_theme_color_override("font_color", color)
	line.add_theme_font_size_override("font_size", 13)
	if f.played:
		line.text = "%s   %d - %d   %s" % [home_name, f.home_goals, f.away_goals, away_name]
	else:
		line.text = "%s   vs   %s" % [home_name, away_name]
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(line)

	return hb


func _on_next_match() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/team_select.tscn")
