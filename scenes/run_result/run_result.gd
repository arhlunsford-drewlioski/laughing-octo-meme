extends Control
## End-of-run summary. Hero band with giant W-D-L numerals, then a vertical
## list of compact match cards, then the spellbook coda.

var _shell: PageShell


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_shell = PageShell.new()
	add_child(_shell)
	_shell.top_rail.bind_run_state()

	# Determine outcome
	var won_run := RunManager.has_won_tournament()
	var verdict_text := "TRIUMPHANT" if won_run else "ELIMINATED"
	var verdict_color: Color = UITheme.GOLD_LIGHT if won_run else UITheme.CRIMSON_LIGHT

	# Hero band — verdict word + huge W-D-L numerals
	var hero := VBoxContainer.new()
	hero.add_theme_constant_override("separation", 4)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	_shell.center_content.add_child(hero)

	var verdict := Label.new()
	verdict.theme_type_variation = &"HeaderLabel"
	verdict.add_theme_color_override("font_color", verdict_color)
	verdict.add_theme_font_size_override("font_size", 64)
	verdict.text = verdict_text
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(verdict)

	# Compute record
	var wins := 0
	var draws := 0
	var losses := 0
	var total_goals := 0
	for r in RunManager.match_results:
		if bool(r.get("won", false)):
			wins += 1
		elif int(r.get("player_goals", 0)) == int(r.get("opponent_goals", 0)):
			draws += 1
		else:
			losses += 1
		total_goals += int(r.get("player_goals", 0))

	# Huge numeral row
	var numeral_row := HBoxContainer.new()
	numeral_row.alignment = BoxContainer.ALIGNMENT_CENTER
	numeral_row.add_theme_constant_override("separation", 24)
	hero.add_child(numeral_row)
	numeral_row.add_child(_make_huge_stat(str(wins), "WINS", UITheme.EMERALD_LIGHT))
	numeral_row.add_child(_make_huge_stat(str(draws), "DRAWS", UITheme.GOLD_LIGHT))
	numeral_row.add_child(_make_huge_stat(str(losses), "LOSSES", UITheme.CRIMSON_LIGHT))
	numeral_row.add_child(_make_huge_stat(str(total_goals), "GOALS", UITheme.PARCHMENT))

	# Match log — vertical list of compact cards
	var log_panel := PanelContainer.new()
	log_panel.theme_type_variation = &"WoodPanel"
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.center_content.add_child(log_panel)

	var log_inner := VBoxContainer.new()
	log_inner.add_theme_constant_override("separation", 6)
	log_panel.add_child(log_inner)

	var log_header := Label.new()
	log_header.theme_type_variation = &"HeaderLabel"
	log_header.text = "THE PATH"
	log_header.add_theme_font_size_override("font_size", 22)
	log_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_inner.add_child(log_header)

	var log_div := ColorRect.new()
	log_div.color = UITheme.GOLD_DEEP
	log_div.custom_minimum_size = Vector2(0, 1)
	log_inner.add_child(log_div)

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_inner.add_child(log_scroll)

	var log_list := VBoxContainer.new()
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_list.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_list)

	for i in range(RunManager.match_results.size()):
		var r: Dictionary = RunManager.match_results[i]
		log_list.add_child(_make_match_row(i + 1, r))

	# Spellbook coda
	if RunManager.run_spellbook != null:
		var coda := Label.new()
		coda.theme_type_variation = &"SubheaderLabel"
		coda.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
		coda.add_theme_font_size_override("font_size", 16)
		coda.text = "%s  ·  %s  ·  %d page%s bound" % [
			RunManager.run_spellbook.icon, RunManager.run_spellbook.book_name,
			RunManager.run_spellbook.pages.size(),
			"" if RunManager.run_spellbook.pages.size() == 1 else "s"
		]
		coda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shell.center_content.add_child(coda)

	# Action bar
	_shell.add_primary_cta("BEGIN A NEW TOURNAMENT", _on_new_run)


func _make_huge_stat(value: String, label_text: String, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)

	var num := Label.new()
	num.theme_type_variation = &"HugeNumeral"
	num.add_theme_color_override("font_color", color)
	num.add_theme_font_size_override("font_size", 84)
	num.text = value
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)

	var lbl := Label.new()
	lbl.theme_type_variation = &"DimLabel"
	lbl.add_theme_color_override("font_color", UITheme.PARCHMENT_DEEP)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)

	return v


func _make_match_row(index: int, r: Dictionary) -> Control:
	var pc := PanelContainer.new()
	var bg: Color = UITheme.BG_CARD
	pc.add_theme_stylebox_override("panel", UITheme.make_panel_bg(bg, UITheme.GOLD_DEEP, 1))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	pc.add_child(hb)

	var num := Label.new()
	num.text = "M%d" % index
	num.theme_type_variation = &"DimLabel"
	num.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	num.add_theme_font_size_override("font_size", 14)
	num.custom_minimum_size = Vector2(40, 0)
	hb.add_child(num)

	var stage_l := Label.new()
	stage_l.text = str(r.get("stage", "")).to_upper()
	stage_l.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	stage_l.add_theme_font_size_override("font_size", 13)
	stage_l.custom_minimum_size = Vector2(140, 0)
	hb.add_child(stage_l)

	var p: int = int(r.get("player_goals", 0))
	var o: int = int(r.get("opponent_goals", 0))
	var won: bool = bool(r.get("won", false))
	var draw: bool = (p == o)
	var pip := Label.new()
	if won:
		pip.text = "W"
		pip.add_theme_color_override("font_color", UITheme.EMERALD_LIGHT)
	elif draw:
		pip.text = "D"
		pip.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	else:
		pip.text = "L"
		pip.add_theme_color_override("font_color", UITheme.CRIMSON_LIGHT)
	pip.add_theme_font_size_override("font_size", 18)
	pip.custom_minimum_size = Vector2(28, 0)
	pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(pip)

	var score_l := Label.new()
	score_l.text = "%d - %d" % [p, o]
	score_l.add_theme_color_override("font_color", UITheme.PARCHMENT)
	score_l.add_theme_font_size_override("font_size", 18)
	score_l.custom_minimum_size = Vector2(60, 0)
	hb.add_child(score_l)

	var vs := Label.new()
	vs.text = "vs %s" % str(r.get("opponent_name", "?"))
	vs.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	vs.add_theme_font_size_override("font_size", 14)
	vs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(vs)

	return pc


func _on_new_run() -> void:
	RunManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")
