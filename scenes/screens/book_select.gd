extends Control
## Pick your wizard's signature spellbook before the tournament starts.

const TOURNAMENT_HUB := "res://scenes/screens/tournament_hub.tscn"
const DRAFT := "res://scenes/draft/draft.tscn"

var _books: Array[SpellbookData] = []

func _ready() -> void:
	_books = SpellbookDatabase.all_books()
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 40
	root.offset_top = 30
	root.offset_right = -40
	root.offset_bottom = -30
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := Label.new()
	title.text = "CHOOSE YOUR SPELLBOOK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Each match earns gold. Spend it on pages that bend your signature spell."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	subtitle.add_theme_font_size_override("font_size", 14)
	root.add_child(subtitle)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	for book in _books:
		row.add_child(_make_book_card(book))

	var back := Button.new()
	back.text = "Back to Draft"
	back.custom_minimum_size = Vector2(180, 36)
	UITheme.style_button(back, false)
	back.pressed.connect(func(): get_tree().change_scene_to_file(DRAFT))
	var back_wrap := HBoxContainer.new()
	back_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	back_wrap.add_child(back)
	root.add_child(back_wrap)

func _make_book_card(book: SpellbookData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 360)
	var style := UITheme.make_panel_style(UITheme.BG_CARD, book.color, 2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var icon := Label.new()
	icon.text = book.icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = book.book_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", book.color)
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var spell := book.base_spell
	if spell:
		var spell_label := Label.new()
		spell_label.text = "Signature: %s" % spell.spell_name
		spell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_label.add_theme_color_override("font_color", UITheme.CREAM)
		spell_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(spell_label)

		var spell_desc := Label.new()
		spell_desc.text = spell.description
		spell_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spell_desc.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		spell_desc.add_theme_font_size_override("font_size", 12)
		vbox.add_child(spell_desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var book_desc := Label.new()
	book_desc.text = book.description
	book_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book_desc.add_theme_color_override("font_color", UITheme.CREAM)
	book_desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(book_desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var pick_btn := Button.new()
	pick_btn.text = "Choose This Book"
	pick_btn.custom_minimum_size = Vector2(0, 42)
	UITheme.style_button(pick_btn)
	pick_btn.pressed.connect(_on_pick.bind(book))
	vbox.add_child(pick_btn)

	return panel

func _on_pick(book: SpellbookData) -> void:
	var roster: Array[GoblinData] = []
	roster.assign(GameManager.selected_roster)
	if roster.is_empty():
		# Fallback to fresh draft if state was lost.
		get_tree().change_scene_to_file(DRAFT)
		return
	RunManager.start_tournament(roster, book)
	get_tree().change_scene_to_file(TOURNAMENT_HUB)
