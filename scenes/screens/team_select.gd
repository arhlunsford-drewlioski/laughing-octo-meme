extends Control
## Pre-match lineup screen. Pick exactly 6 from alive roster.
## Also handles per-goblin level-up stat picker overlay.

const REQUIRED_COUNT := 6

var _shell: PageShell
var _roster_grid: GridContainer
var _lineup_strip: VBoxContainer
var _lineup_count_label: Label
var _confirm_btn: BigCTA
var _hint_label: Label
var _opponent_panel: PanelContainer

var _roster: Array[GoblinData] = []
var _selected: Array[GoblinData] = []
var _cards_by_goblin: Dictionary = {}  # goblin -> GoblinCard
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

	# ── Header strip with opponent scouting ──────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_shell.center_content.add_child(header)

	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "MARSHAL YOUR SIX"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_opponent_panel = PanelContainer.new()
	_opponent_panel.theme_type_variation = &"WoodPanel"
	_opponent_panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg(UITheme.BG_PANEL, UITheme.GOLD_DEEP, 2))
	header.add_child(_opponent_panel)
	_build_opponent_panel()

	# ── Two-column body ──────────────────────────────────────────────
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	_shell.center_content.add_child(body)

	# LEFT: roster scroll
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = 2.4
	left_box.add_theme_constant_override("separation", 6)
	body.add_child(left_box)

	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"DimLabel"
	_hint_label.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.text = "Tap a card to add or remove."
	left_box.add_child(_hint_label)

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
	lineup_panel.theme_type_variation = &"WoodPanel"
	lineup_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(lineup_panel)

	var lineup_inner := VBoxContainer.new()
	lineup_inner.add_theme_constant_override("separation", 8)
	lineup_panel.add_child(lineup_inner)

	var lineup_title := Label.new()
	lineup_title.theme_type_variation = &"HeaderLabel"
	lineup_title.text = "MATCHDAY SIX"
	lineup_title.add_theme_font_size_override("font_size", 22)
	lineup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lineup_inner.add_child(lineup_title)

	_lineup_count_label = Label.new()
	_lineup_count_label.theme_type_variation = &"WaxSealBadge"
	_lineup_count_label.add_theme_font_size_override("font_size", 28)
	_lineup_count_label.text = "0 / %d" % REQUIRED_COUNT
	_lineup_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lineup_inner.add_child(_lineup_count_label)

	var lineup_div := ColorRect.new()
	lineup_div.color = UITheme.GOLD_DEEP
	lineup_div.custom_minimum_size = Vector2(0, 1)
	lineup_inner.add_child(lineup_div)

	var lineup_scroll := ScrollContainer.new()
	lineup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lineup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lineup_inner.add_child(lineup_scroll)

	_lineup_strip = VBoxContainer.new()
	_lineup_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lineup_strip.add_theme_constant_override("separation", 6)
	lineup_scroll.add_child(_lineup_strip)

	# Action bar
	_shell.add_secondary_button("BACK", _on_back)
	_confirm_btn = _shell.add_primary_cta("MARCH TO BATTLE (0/6)", _on_confirm)
	_confirm_btn.disabled = true


func _build_opponent_panel() -> void:
	for c in _opponent_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_opponent_panel.add_child(v)

	var label := Label.new()
	label.theme_type_variation = &"DimLabel"
	label.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	label.add_theme_font_size_override("font_size", 12)
	label.text = "NEXT FOE"
	v.add_child(label)

	var name_l := Label.new()
	name_l.theme_type_variation = &"HeaderLabel"
	name_l.add_theme_font_size_override("font_size", 22)
	name_l.text = RunManager.get_current_opponent_name()
	v.add_child(name_l)

	var arch := RunManager.get_current_opponent_archetype_name()
	if arch != "":
		var arch_l := Label.new()
		arch_l.add_theme_color_override("font_color", UITheme.PARCHMENT)
		arch_l.add_theme_font_size_override("font_size", 14)
		arch_l.text = arch
		v.add_child(arch_l)

	var book = RunManager.get_current_opponent_spellbook()
	if book:
		var book_row := HBoxContainer.new()
		book_row.add_theme_constant_override("separation", 6)
		v.add_child(book_row)
		var icon_l := Label.new()
		icon_l.text = str(book.icon)
		icon_l.add_theme_font_size_override("font_size", 20)
		book_row.add_child(icon_l)
		var bn := Label.new()
		bn.text = "%s · %d page%s" % [book.book_name, book.pages.size(), "" if book.pages.size() == 1 else "s"]
		bn.add_theme_color_override("font_color", book.color if book.color.a > 0.05 else UITheme.GOLD_LIGHT)
		bn.add_theme_font_size_override("font_size", 13)
		book_row.add_child(bn)


# ── Roster grid ──────────────────────────────────────────────────────

func _refresh_roster_cards() -> void:
	for c in _roster_grid.get_children():
		c.queue_free()
	_cards_by_goblin.clear()

	for g in _roster:
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 4)
		_roster_grid.add_child(wrap)

		var card := GoblinCard.new()
		wrap.add_child(card)
		card.set_goblin(g, GoblinCard.Mode.COMPACT)
		card.set_selected(_selected.has(g))
		card.toggled.connect(_on_card_toggled.bind(g, card))
		_cards_by_goblin[g] = card

		# If this goblin has a pending level-up, intercept the toggle to
		# show the picker instead. We do that by adding a "Spend Level-Up"
		# overlay button below the card.
		if g.has_pending_level_up():
			var lvl_btn := Button.new()
			lvl_btn.theme_type_variation = &"GoldButton"
			lvl_btn.text = "★ SPEND LEVEL-UP (+%d)" % int(g.pending_level_ups)
			lvl_btn.add_theme_font_size_override("font_size", 13)
			lvl_btn.custom_minimum_size = Vector2(0, 36)
			lvl_btn.pressed.connect(_show_stat_picker.bind(g))
			wrap.add_child(lvl_btn)


func _on_card_toggled(toggled: bool, g: GoblinData, card: GoblinCard) -> void:
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
	for c in _lineup_strip.get_children():
		c.queue_free()
	_lineup_count_label.text = "%d / %d" % [_selected.size(), REQUIRED_COUNT]

	if _selected.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"DimLabel"
		empty.add_theme_color_override("font_color", UITheme.PARCHMENT_DEEP)
		empty.add_theme_font_size_override("font_size", 12)
		empty.text = "No goblins picked yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lineup_strip.add_child(empty)
		return

	for g in _selected:
		var mini := GoblinCard.new()
		_lineup_strip.add_child(mini)
		mini.set_goblin(g, GoblinCard.Mode.MINI)
		mini.set_selected(true)
		mini.disabled = true  # purely informational here


# ── Confirm + back ───────────────────────────────────────────────────

func _update_confirm_state() -> void:
	var any_pending := false
	for g in _roster:
		if g.has_pending_level_up():
			any_pending = true
			break
	if _selected.size() != REQUIRED_COUNT:
		_confirm_btn.text = "MARCH TO BATTLE (%d/%d)" % [_selected.size(), REQUIRED_COUNT]
		_confirm_btn.disabled = true
		_hint_label.text = "Pick %d more goblin%s." % [REQUIRED_COUNT - _selected.size(), "" if (REQUIRED_COUNT - _selected.size()) == 1 else "s"]
		_hint_label.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	elif any_pending:
		_confirm_btn.text = "SPEND LEVEL-UPS FIRST"
		_confirm_btn.disabled = true
		_hint_label.text = "Some goblins have unspent level-ups. Spend them before matching."
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
