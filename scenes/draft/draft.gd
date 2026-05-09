extends Control
## Draft screen: pick 10 goblins from a pool of 20.
## Layout mirrors team_select: 4-col compact card grid + 10-slot sidebar
## with live aggregate stats. Same UX pattern across both screens.

const TEAM_SIZE: int = 10
const POOL_SIZE: int = 20

var _full_roster: Array[GoblinData] = []
var _selected: Array[GoblinData] = []

var _shell: PageShell
var _count_badge: Label
var _hint: Label
var _roster_grid: GridContainer
var _slot_tiles: Array[PanelContainer] = []
var _slot_portraits: Array[GoblinPortrait] = []
var _stat_power_label: Label
var _stat_speed_label: Label
var _stat_defense_label: Label
var _stat_role_label: Label
var _start_btn: BigCTA


func _ready() -> void:
	_full_roster = GoblinGenerator.generate_draft_pool(POOL_SIZE)
	_build_ui()
	_refresh_roster_cards()
	_update_lineup()
	_update_state()


func _build_ui() -> void:
	_shell = PageShell.new()
	add_child(_shell)
	_shell.top_rail.set_stage("DRAFT")
	_shell.top_rail.set_book(null)
	_shell.top_rail.set_gold(0)
	_shell.top_rail.set_record(0, 0, 0)

	# ── Header strip ─────────────────────────────────────────────────
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	_shell.center_content.add_child(header)

	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "ASSEMBLE YOUR ROSTER"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var counter_row := HBoxContainer.new()
	counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_row.add_theme_constant_override("separation", 8)
	header.add_child(counter_row)

	var pc := PanelContainer.new()
	var ps := UITheme.make_panel_bg(UITheme.WINE_DEEP, UITheme.GOLD)
	ps.content_margin_left = 22
	ps.content_margin_right = 22
	ps.content_margin_top = 4
	ps.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", ps)
	counter_row.add_child(pc)
	_count_badge = Label.new()
	_count_badge.theme_type_variation = &"WaxSealBadge"
	_count_badge.add_theme_font_size_override("font_size", 26)
	_count_badge.text = "0 / %d" % TEAM_SIZE
	pc.add_child(_count_badge)

	_hint = Label.new()
	_hint.theme_type_variation = &"DimLabel"
	_hint.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.text = "Pick ten. Field six per match."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_hint)

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
	left_box.add_child(left_header)
	var pool_l := Label.new()
	pool_l.theme_type_variation = &"DimLabel"
	pool_l.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	pool_l.add_theme_font_size_override("font_size", 12)
	pool_l.text = "DRAFT POOL  ·  %d goblins" % POOL_SIZE
	left_header.add_child(pool_l)

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

	# RIGHT: roster sidebar (10 slots, 5x2 grid)
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
	lineup_title.text = "YOUR ROSTER"
	lineup_title.add_theme_font_size_override("font_size", 22)
	lineup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lineup_inner.add_child(lineup_title)

	# 10-slot grid: 5 columns × 2 rows (fits the narrow sidebar)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 5
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.add_theme_constant_override("h_separation", 6)
	slot_grid.add_theme_constant_override("v_separation", 6)
	lineup_inner.add_child(slot_grid)

	_slot_tiles.clear()
	_slot_portraits.clear()
	for i in range(TEAM_SIZE):
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", _slot_style(false))
		var center := CenterContainer.new()
		tile.add_child(center)
		var portrait := GoblinPortrait.new()
		portrait.portrait_size = 52.0
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
	_start_btn = _shell.add_primary_cta("LOCK IN ROSTER  0 / %d" % TEAM_SIZE, _on_start_match)
	_start_btn.disabled = true


func _make_stat_line(label_text: String, value_text: String, value_color: Color) -> Label:
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
	s.set_corner_radius_all(6)
	s.border_color = UITheme.EMERALD_LIGHT if filled else UITheme.GOLD_DEEP
	s.border_width_left = 2 if filled else 1
	s.border_width_right = 2 if filled else 1
	s.border_width_top = 2 if filled else 1
	s.border_width_bottom = 2 if filled else 1
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


# ── Roster grid ──────────────────────────────────────────────────────

func _refresh_roster_cards() -> void:
	for c in _roster_grid.get_children():
		c.queue_free()
	for goblin in _full_roster:
		var card := GoblinCard.new()
		_roster_grid.add_child(card)
		card.set_goblin(goblin, GoblinCard.Mode.COMPACT)
		card.set_selected(_selected.has(goblin))
		card.toggled.connect(_on_card_toggled.bind(goblin, card))


func _on_card_toggled(toggled: bool, goblin: GoblinData, card: GoblinCard) -> void:
	if toggled:
		if _selected.size() >= TEAM_SIZE:
			card.set_selected(false)
			return
		if not _selected.has(goblin):
			_selected.append(goblin)
	else:
		_selected.erase(goblin)
	_update_lineup()
	_update_state()


# ── Lineup sidebar ───────────────────────────────────────────────────

func _update_lineup() -> void:
	for i in range(TEAM_SIZE):
		var tile: PanelContainer = _slot_tiles[i]
		var portrait: GoblinPortrait = _slot_portraits[i]
		if i < _selected.size():
			tile.add_theme_stylebox_override("panel", _slot_style(true))
			portrait.set_goblin(_selected[i])
		else:
			tile.add_theme_stylebox_override("panel", _slot_style(false))
			portrait.draw_empty_slot(i + 1)

	if _selected.is_empty():
		_stat_power_label.text = "—"
		_stat_speed_label.text = "—"
		_stat_defense_label.text = "—"
		_stat_role_label.text = "Pick goblins to see live roster stats."
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

func _update_state() -> void:
	_count_badge.text = "%d / %d" % [_selected.size(), TEAM_SIZE]
	if _selected.size() == TEAM_SIZE:
		_hint.text = "Roster ready. Bind your spellbook next."
		_hint.add_theme_color_override("font_color", UITheme.EMERALD_LIGHT)
		_start_btn.text = "LOCK IN ROSTER"
		_start_btn.disabled = false
	else:
		var remaining: int = TEAM_SIZE - _selected.size()
		_hint.text = "Pick %d more." % remaining
		_hint.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
		_start_btn.text = "LOCK IN ROSTER  %d / %d" % [_selected.size(), TEAM_SIZE]
		_start_btn.disabled = true


func _on_start_match() -> void:
	GameManager.selected_roster = _selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/screens/book_select.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
