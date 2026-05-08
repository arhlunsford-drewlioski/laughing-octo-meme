extends Control
## Draft screen: pick 10 goblins from a pool of 20.
## CR-style carousel of 5 illuminated goblin cards per page.

const TEAM_SIZE: int = 10
const CARDS_PER_PAGE: int = 5

var _full_roster: Array[GoblinData] = []
var _selected: Array[GoblinData] = []
var _page: int = 0

var _shell: PageShell
var _count_badge: Label
var _hint: Label
var _card_row: HBoxContainer
var _left_btn: Button
var _right_btn: Button
var _page_dots: HBoxContainer
var _start_btn: BigCTA


func _ready() -> void:
	_full_roster = GoblinGenerator.generate_draft_pool(20)
	_build_ui()
	_show_page()
	_update_state()


func _build_ui() -> void:
	_shell = PageShell.new()
	_shell.show_top_rail = true
	add_child(_shell)
	_shell.top_rail.set_stage("DRAFT")
	_shell.top_rail.set_book(null)
	_shell.top_rail.set_gold(0)
	_shell.top_rail.set_record(0, 0, 0)

	# ── Header ────────────────────────────────────────────────────────
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_shell.center_content.add_child(header)

	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "ASSEMBLE YOUR ROSTER"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	# Big chunky selection counter (CR-style)
	var counter_row := HBoxContainer.new()
	counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_row.add_theme_constant_override("separation", 8)
	header.add_child(counter_row)

	var pc := PanelContainer.new()
	var ps := UITheme.make_panel_bg(UITheme.WINE_DEEP, UITheme.GOLD)
	ps.content_margin_left = 22
	ps.content_margin_right = 22
	ps.content_margin_top = 6
	ps.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", ps)
	counter_row.add_child(pc)
	_count_badge = Label.new()
	_count_badge.theme_type_variation = &"WaxSealBadge"
	_count_badge.add_theme_font_size_override("font_size", 30)
	_count_badge.text = "0 / %d" % TEAM_SIZE
	pc.add_child(_count_badge)

	_hint = Label.new()
	_hint.theme_type_variation = &"DimLabel"
	_hint.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.text = "Pick ten. Field six per match."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_hint)

	# ── Carousel ──────────────────────────────────────────────────────
	var carousel := HBoxContainer.new()
	carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.add_theme_constant_override("separation", 12)
	_shell.center_content.add_child(carousel)

	_left_btn = Button.new()
	_left_btn.theme_type_variation = &"SecondaryButton"
	_left_btn.text = "◀"
	_left_btn.custom_minimum_size = Vector2(48, 84)
	_left_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left_btn.add_theme_font_size_override("font_size", 28)
	_left_btn.pressed.connect(_on_prev_page)
	carousel.add_child(_left_btn)

	_card_row = HBoxContainer.new()
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_row.add_theme_constant_override("separation", 10)
	carousel.add_child(_card_row)

	_right_btn = Button.new()
	_right_btn.theme_type_variation = &"SecondaryButton"
	_right_btn.text = "▶"
	_right_btn.custom_minimum_size = Vector2(48, 84)
	_right_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_btn.add_theme_font_size_override("font_size", 28)
	_right_btn.pressed.connect(_on_next_page)
	carousel.add_child(_right_btn)

	# Page dots
	_page_dots = HBoxContainer.new()
	_page_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_dots.add_theme_constant_override("separation", 8)
	_shell.center_content.add_child(_page_dots)

	# ── Action bar ────────────────────────────────────────────────────
	_shell.add_secondary_button("BACK", _on_back)
	_start_btn = _shell.add_primary_cta("LOCK IN ROSTER", _on_start_match)
	_start_btn.disabled = true


func _total_pages() -> int:
	return ceili(float(_full_roster.size()) / CARDS_PER_PAGE)


func _on_prev_page() -> void:
	_page = maxi(_page - 1, 0)
	_show_page()


func _on_next_page() -> void:
	_page = mini(_page + 1, _total_pages() - 1)
	_show_page()


func _show_page() -> void:
	for c in _card_row.get_children():
		c.queue_free()

	var start_idx: int = _page * CARDS_PER_PAGE
	var end_idx: int = mini(start_idx + CARDS_PER_PAGE, _full_roster.size())

	for i in range(start_idx, end_idx):
		var goblin: GoblinData = _full_roster[i]
		var card := GoblinCard.new()
		_card_row.add_child(card)
		# Set goblin AFTER it's in tree so _ready runs first
		card.set_goblin(goblin, GoblinCard.Mode.FULL)
		card.set_selected(_selected.has(goblin))
		card.toggled.connect(_on_card_toggled.bind(goblin, card))

	_left_btn.disabled = _page <= 0
	_right_btn.disabled = _page >= _total_pages() - 1
	_rebuild_page_dots()


func _rebuild_page_dots() -> void:
	for c in _page_dots.get_children():
		c.queue_free()
	for i in range(_total_pages()):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = UITheme.GOLD if i == _page else UITheme.GOLD_DEEP
		_page_dots.add_child(dot)


func _on_card_toggled(toggled: bool, goblin: GoblinData, card: GoblinCard) -> void:
	if toggled:
		if _selected.size() >= TEAM_SIZE:
			# Roster full — refuse the toggle
			card.set_selected(false)
			return
		if not _selected.has(goblin):
			_selected.append(goblin)
	else:
		_selected.erase(goblin)
	_update_state()


func _update_state() -> void:
	_count_badge.text = "%d / %d" % [_selected.size(), TEAM_SIZE]
	if _selected.size() == TEAM_SIZE:
		_hint.text = "Roster ready. Bind your spellbook next."
		_hint.add_theme_color_override("font_color", UITheme.EMERALD_LIGHT)
	else:
		_hint.text = "Pick %d more goblin%s." % [TEAM_SIZE - _selected.size(), "" if (TEAM_SIZE - _selected.size()) == 1 else "s"]
		_hint.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	_start_btn.disabled = _selected.size() != TEAM_SIZE


func _on_start_match() -> void:
	GameManager.selected_roster = _selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/screens/book_select.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
