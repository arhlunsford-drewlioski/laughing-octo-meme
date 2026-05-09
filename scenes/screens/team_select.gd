extends Control
## Pre-match war room. Pick exactly 6 from alive roster.
##
## Layout: Hero opponent strip across the top (the threat),
##         4-col compact roster grid (the picking surface),
##         6-slot lineup sidebar with live aggregate stats (the feedback).

const REQUIRED_COUNT := 6

var _shell: PageShell
var _roster_grid: GridContainer
var _slot_tiles: Array[PanelContainer] = []          # 6 slot wrappers
var _slot_portraits: Array[GoblinPortrait] = []      # 6 portrait widgets (or null)
var _stat_power_label: Label
var _stat_speed_label: Label
var _stat_defense_label: Label
var _stat_role_label: Label
var _confirm_btn: BigCTA
var _hint_label: Label
var _opponent_panel: PanelContainer

var _roster: Array[GoblinData] = []
var _selected: Array[GoblinData] = []
var _cards_by_goblin: Dictionary = {}
var _level_up_overlay: CanvasLayer = null


func _ready() -> void:
	_roster = RunManager.get_alive_roster()
	_build_ui()
	_refresh_roster_cards()
	_update_lineup()
	_update_confirm_state()


func _build_ui() -> void:
	_shell = PageShell.new()
	add_child(_shell)
	_shell.top_rail.bind_run_state()

	# ── Hero opponent strip ───────────────────────────────────────────
	_opponent_panel = PanelContainer.new()
	_opponent_panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg(UITheme.BG_PANEL, UITheme.GOLD_DEEP, 3))
	_shell.center_content.add_child(_opponent_panel)
	_build_opponent_panel()

	# ── Two-column body ──────────────────────────────────────────────
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	_shell.center_content.add_child(body)

	# LEFT: roster grid
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = 2.4
	left_box.add_theme_constant_override("separation", 6)
	body.add_child(left_box)

	var left_header := HBoxContainer.new()
	left_header.add_theme_constant_override("separation", 12)
	left_box.add_child(left_header)

	var roster_title := Label.new()
	roster_title.theme_type_variation = &"HeaderLabel"
	roster_title.text = "YOUR ROSTER"
	roster_title.add_theme_font_size_override("font_size", 22)
	left_header.add_child(roster_title)

	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"DimLabel"
	_hint_label.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.text = "Tap a card to add or remove."
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left_header.add_child(_hint_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(scroll)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 4
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_grid.add_theme_constant_override("h_separation", 10)
	_roster_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_roster_grid)

	# RIGHT: lineup sidebar
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_stretch_ratio = 1.0
	right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 8)
	body.add_child(right_box)

	var lineup_panel := PanelContainer.new()
	lineup_panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg(UITheme.BG_PANEL, UITheme.GOLD_DEEP, 3))
	lineup_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(lineup_panel)

	var lineup_inner := VBoxContainer.new()
	lineup_inner.add_theme_constant_override("separation", 10)
	lineup_panel.add_child(lineup_inner)

	var lineup_title := Label.new()
	lineup_title.theme_type_variation = &"HeaderLabel"
	lineup_title.text = "MATCHDAY SIX"
	lineup_title.add_theme_font_size_override("font_size", 22)
	lineup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lineup_inner.add_child(lineup_title)

	# Slot grid (3 cols × 2 rows = 6 slots)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 3
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.add_theme_constant_override("h_separation", 8)
	slot_grid.add_theme_constant_override("v_separation", 8)
	lineup_inner.add_child(slot_grid)

	_slot_tiles.clear()
	_slot_portraits.clear()
	for i in range(REQUIRED_COUNT):
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", _slot_style(false))
		var center := CenterContainer.new()
		tile.add_child(center)
		var portrait := GoblinPortrait.new()
		portrait.portrait_size = 64.0
		portrait.show_ring = true
		center.add_child(portrait)
		portrait.draw_empty_slot(i + 1)
		slot_grid.add_child(tile)
		_slot_tiles.append(tile)
		_slot_portraits.append(portrait)

	var slot_div := ColorRect.new()
	slot_div.color = UITheme.GOLD_DEEP
	slot_div.custom_minimum_size = Vector2(0, 1)
	lineup_inner.add_child(slot_div)

	# Live aggregated stats
	var stat_block := VBoxContainer.new()
	stat_block.add_theme_constant_override("separation", 4)
	lineup_inner.add_child(stat_block)

	_stat_power_label = _make_stat_line("TOTAL POWER", "—", UITheme.GOLD_LIGHT)
	stat_block.add_child(_stat_power_label.get_parent())
	_stat_speed_label = _make_stat_line("AVG SPEED", "—", UITheme.PARCHMENT)
	stat_block.add_child(_stat_speed_label.get_parent())
	_stat_defense_label = _make_stat_line("AVG DEFENSE", "—", UITheme.PARCHMENT)
	stat_block.add_child(_stat_defense_label.get_parent())

	_stat_role_label = Label.new()
	_stat_role_label.theme_type_variation = &"DimLabel"
	_stat_role_label.add_theme_color_override("font_color", UITheme.PARCHMENT_DEEP)
	_stat_role_label.add_theme_font_size_override("font_size", 11)
	_stat_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_role_label.text = "—"
	lineup_inner.add_child(_stat_role_label)

	# Action bar
	_shell.add_secondary_button("BACK", _on_back)
	_confirm_btn = _shell.add_primary_cta("MARCH TO BATTLE  0 / 6", _on_confirm)
	_confirm_btn.disabled = true


func _make_stat_line(label_text: String, value_text: String, value_color: Color) -> Label:
	## Builds a "LABEL ────── value" row. Returns the value Label so we can update it.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_l := Label.new()
	name_l.theme_type_variation = &"DimLabel"
	name_l.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.text = label_text
	row.add_child(name_l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val := Label.new()
	val.add_theme_color_override("font_color", value_color)
	val.add_theme_font_size_override("font_size", 18)
	val.text = value_text
	row.add_child(val)
	return val


func _slot_style(filled: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.BG_NIGHT if filled else UITheme.BG_DARK
	s.set_corner_radius_all(8)
	s.border_color = UITheme.GOLD if filled else UITheme.GOLD_DEEP
	s.border_width_left = 2 if filled else 1
	s.border_width_right = 2 if filled else 1
	s.border_width_top = 2 if filled else 1
	s.border_width_bottom = 2 if filled else 1
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _build_opponent_panel() -> void:
	for c in _opponent_panel.get_children():
		c.queue_free()

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_bottom", 12)
	_opponent_panel.add_child(inner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	inner.add_child(hbox)

	# Sorcerer "portrait" — book sigil in a gold-ringed circle
	var book = RunManager.get_current_opponent_spellbook()
	var sigil_color: Color = book.color if (book and book.color.a > 0.05) else UITheme.GOLD_LIGHT
	var sigil := PanelContainer.new()
	sigil.custom_minimum_size = Vector2(96, 96)
	var sigil_style := StyleBoxFlat.new()
	sigil_style.bg_color = UITheme.WINE_DEEP
	sigil_style.set_corner_radius_all(96)
	sigil_style.border_color = UITheme.GOLD
	sigil_style.border_width_left = 3
	sigil_style.border_width_right = 3
	sigil_style.border_width_top = 3
	sigil_style.border_width_bottom = 3
	sigil_style.shadow_color = Color(0, 0, 0, 0.5)
	sigil_style.shadow_size = 0
	sigil_style.shadow_offset = Vector2(0, 4)
	sigil_style.anti_aliasing = true
	sigil.add_theme_stylebox_override("panel", sigil_style)
	hbox.add_child(sigil)

	var sigil_center := CenterContainer.new()
	sigil.add_child(sigil_center)
	var sigil_icon := Label.new()
	sigil_icon.text = str(book.icon) if book else "?"
	sigil_icon.add_theme_font_size_override("font_size", 56)
	sigil_icon.add_theme_color_override("font_color", sigil_color)
	sigil_center.add_child(sigil_icon)

	# Right: text block
	var text_v := VBoxContainer.new()
	text_v.add_theme_constant_override("separation", 2)
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(text_v)

	var foe_eyebrow := Label.new()
	foe_eyebrow.theme_type_variation = &"DimLabel"
	foe_eyebrow.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	foe_eyebrow.add_theme_font_size_override("font_size", 12)
	foe_eyebrow.text = "✠   N E X T   F O E   ✠"
	text_v.add_child(foe_eyebrow)

	var arch := RunManager.get_current_opponent_archetype_name()
	var arch_l := Label.new()
	arch_l.theme_type_variation = &"HeaderLabel"
	arch_l.add_theme_font_size_override("font_size", 28)
	arch_l.text = arch.to_upper() if arch != "" else "RIVAL SORCERER"
	text_v.add_child(arch_l)

	var team_l := Label.new()
	team_l.add_theme_color_override("font_color", UITheme.PARCHMENT)
	team_l.add_theme_font_size_override("font_size", 16)
	team_l.text = RunManager.get_current_opponent_name()
	text_v.add_child(team_l)

	# Book line
	if book:
		var book_row := HBoxContainer.new()
		book_row.add_theme_constant_override("separation", 8)
		text_v.add_child(book_row)

		var book_name := Label.new()
		book_name.add_theme_color_override("font_color", sigil_color)
		book_name.add_theme_font_size_override("font_size", 14)
		book_name.text = "%s  ·  %d page%s bound" % [
			book.book_name, book.pages.size(),
			"" if book.pages.size() == 1 else "s"
		]
		book_row.add_child(book_name)

	# Stage badge (right-aligned, small)
	var stage_l := Label.new()
	stage_l.theme_type_variation = &"StageBadge"
	stage_l.add_theme_font_size_override("font_size", 16)
	stage_l.text = RunManager.get_stage_name().to_upper()
	stage_l.size_flags_horizontal = Control.SIZE_SHRINK_END
	stage_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(stage_l)


# ── Roster grid ──────────────────────────────────────────────────────

func _refresh_roster_cards() -> void:
	for c in _roster_grid.get_children():
		c.queue_free()
	_cards_by_goblin.clear()

	for g in _roster:
		var card := GoblinCard.new()
		_roster_grid.add_child(card)
		card.set_goblin(g, GoblinCard.Mode.COMPACT)
		card.set_selected(_selected.has(g))
		card.toggled.connect(_on_card_toggled.bind(g, card))
		_cards_by_goblin[g] = card


func _on_card_toggled(toggled: bool, g: GoblinData, card: GoblinCard) -> void:
	# If card has a pending level-up, force the picker before allowing selection.
	if toggled and g.has_method("has_pending_level_up") and g.has_pending_level_up():
		card.set_selected(false)
		_show_stat_picker(g)
		return

	if toggled:
		if _selected.size() >= REQUIRED_COUNT:
			card.set_selected(false)
			return
		if not _selected.has(g):
			_selected.append(g)
	else:
		_selected.erase(g)
	_update_lineup()
	_update_confirm_state()


# ── Lineup sidebar ───────────────────────────────────────────────────

func _update_lineup() -> void:
	for i in range(REQUIRED_COUNT):
		var tile: PanelContainer = _slot_tiles[i]
		var portrait: GoblinPortrait = _slot_portraits[i]
		if i < _selected.size():
			var g: GoblinData = _selected[i]
			tile.add_theme_stylebox_override("panel", _slot_style(true))
			portrait.set_goblin(g)
		else:
			tile.add_theme_stylebox_override("panel", _slot_style(false))
			portrait.draw_empty_slot(i + 1)

	# Aggregate stats
	if _selected.is_empty():
		_stat_power_label.text = "—"
		_stat_speed_label.text = "—"
		_stat_defense_label.text = "—"
		_stat_role_label.text = "Pick goblins to see live squad stats."
		return

	var power: int = 0
	var sum_speed: int = 0
	var sum_def: int = 0
	var roles: Dictionary = {"keeper": 0, "defender": 0, "midfielder": 0, "attacker": 0, "chaos": 0}
	for g in _selected:
		power += int(g.get_stat("shooting")) + int(g.get_stat("speed")) + int(g.get_stat("defense")) \
			+ int(g.get_stat("strength")) + int(g.get_stat("health")) + int(g.get_stat("chaos"))
		sum_speed += int(g.get_stat("speed"))
		sum_def += int(g.get_stat("defense"))
		var key: String = str(g.position)
		if roles.has(key):
			roles[key] += 1

	var n: int = _selected.size()
	_stat_power_label.text = str(power)
	_stat_speed_label.text = "%.1f" % (float(sum_speed) / float(n))
	_stat_defense_label.text = "%.1f" % (float(sum_def) / float(n))

	var role_chips: Array = []
	if int(roles["keeper"]) > 0: role_chips.append("%dK" % int(roles["keeper"]))
	if int(roles["defender"]) > 0: role_chips.append("%dD" % int(roles["defender"]))
	if int(roles["midfielder"]) > 0: role_chips.append("%dM" % int(roles["midfielder"]))
	if int(roles["attacker"]) > 0: role_chips.append("%dA" % int(roles["attacker"]))
	if int(roles["chaos"]) > 0: role_chips.append("%dC" % int(roles["chaos"]))
	_stat_role_label.text = "  ·  ".join(role_chips) if not role_chips.is_empty() else "—"


# ── Confirm + back ───────────────────────────────────────────────────

func _update_confirm_state() -> void:
	var any_pending := false
	for g in _roster:
		if g.has_pending_level_up():
			any_pending = true
			break
	if _selected.size() != REQUIRED_COUNT:
		_confirm_btn.text = "MARCH TO BATTLE  %d / %d" % [_selected.size(), REQUIRED_COUNT]
		_confirm_btn.disabled = true
		_hint_label.text = "Pick %d more." % (REQUIRED_COUNT - _selected.size())
		_hint_label.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	elif any_pending:
		_confirm_btn.text = "SPEND LEVEL-UPS FIRST"
		_confirm_btn.disabled = true
		_hint_label.text = "Tap any goblin with a ★ to spend their level-up."
		_hint_label.add_theme_color_override("font_color", UITheme.WINE_LIGHT)
	else:
		_confirm_btn.text = "MARCH TO BATTLE"
		_confirm_btn.disabled = false
		_hint_label.text = "Squad ready. The pitch awaits."
		_hint_label.add_theme_color_override("font_color", UITheme.EMERALD_LIGHT)


func _on_confirm() -> void:
	if _selected.size() != REQUIRED_COUNT:
		return
	for g in _roster:
		if g.has_pending_level_up():
			return
	GameManager.selected_roster = _selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/match_sim/match_sim_viewer.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")


# ── Level-up overlay ─────────────────────────────────────────────────

func _show_stat_picker(g: GoblinData) -> void:
	_close_stat_picker()

	_level_up_overlay = CanvasLayer.new()
	_level_up_overlay.layer = 100
	add_child(_level_up_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_level_up_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_up_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_parchment_card_style(UITheme.GOLD, 5))
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var title := Label.new()
	title.text = "%s LEVELED UP" % g.goblin_name.to_upper()
	title.add_theme_color_override("font_color", UITheme.WINE_DEEP)
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a stat to raise. Levelling heals injuries and clears fatigue."
	subtitle.add_theme_color_override("font_color", UITheme.INK_SOFT)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)

	var labels := {
		"shooting": "SHO", "speed": "SPD", "defense": "DEF",
		"strength": "STR", "health": "HP", "chaos": "CHA"
	}
	var primary: Array = PositionDatabase.get_primary_stats(g.position)
	for stat_name in GoblinData.STAT_KEYS:
		var current: int = g.get_stat(stat_name)
		var base: int = int(g.get(stat_name))
		var is_primary: bool = stat_name in primary
		var is_max: bool = base >= 10
		var btn := Button.new()
		btn.theme_type_variation = &"ParchmentButton" if is_primary else &"SecondaryButton"
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(150, 48)
		if is_max:
			btn.text = "%s %d (MAX)" % [labels[stat_name], current]
			btn.disabled = true
		else:
			btn.text = "%s  %d → %d" % [labels[stat_name], current, current + 1]
			btn.pressed.connect(_on_stat_chosen.bind(g, stat_name))
		grid.add_child(btn)

	var cancel := Button.new()
	cancel.theme_type_variation = &"SecondaryButton"
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(0, 40)
	cancel.pressed.connect(_close_stat_picker)
	v.add_child(cancel)


func _on_stat_chosen(g: GoblinData, stat_name: String) -> void:
	g.apply_stat_increase(stat_name)
	_close_stat_picker()
	_refresh_roster_cards()
	_update_lineup()
	_update_confirm_state()


func _close_stat_picker() -> void:
	if _level_up_overlay and is_instance_valid(_level_up_overlay):
		_level_up_overlay.queue_free()
	_level_up_overlay = null
