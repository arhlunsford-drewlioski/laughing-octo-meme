extends Control
## Pick your wizard's signature spellbook before the tournament starts.
## Three hero-card spellbooks. Tap one → confirm → tournament begins.

const TOURNAMENT_HUB := "res://scenes/screens/tournament_hub.tscn"
const DRAFT := "res://scenes/draft/draft.tscn"

var _books: Array[SpellbookData] = []
var _selected: SpellbookData = null
var _shell: PageShell
var _confirm_btn: BigCTA
var _book_cards: Array[SpellCard] = []
var _binding_label: Label


func _ready() -> void:
	_books = SpellbookDatabase.all_books()
	_build_ui()


func _build_ui() -> void:
	_shell = PageShell.new()
	add_child(_shell)
	_shell.top_rail.set_stage("BIND THE TOME")
	_shell.top_rail.set_book(null)
	_shell.top_rail.set_gold(0)
	_shell.top_rail.set_record(0, 0, 0)

	# Header
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "CHOOSE A SPELLBOOK"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shell.center_content.add_child(title)

	var subtitle := Label.new()
	subtitle.theme_type_variation = &"SubheaderLabel"
	subtitle.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.text = "Each match earns gold. Spend it on pages that bend your signature spell."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shell.center_content.add_child(subtitle)

	# Card row
	var row_margin := MarginContainer.new()
	row_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_margin.add_theme_constant_override("margin_top", 24)
	_shell.center_content.add_child(row_margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row_margin.add_child(row)

	for book in _books:
		var card := SpellCard.new()
		row.add_child(card)
		card.set_book(book)
		card.toggled.connect(_on_book_toggled.bind(book, card))
		_book_cards.append(card)

	# Binding preview line
	_binding_label = Label.new()
	_binding_label.theme_type_variation = &"DimLabel"
	_binding_label.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	_binding_label.add_theme_font_size_override("font_size", 15)
	_binding_label.text = "Tap a tome to bind it as your signature."
	_binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shell.center_content.add_child(_binding_label)

	# Action bar
	_shell.add_secondary_button("BACK TO DRAFT", _on_back)
	_confirm_btn = _shell.add_primary_cta("CONFIRM", _on_confirm)
	_confirm_btn.disabled = true


func _on_book_toggled(toggled: bool, book: SpellbookData, card: SpellCard) -> void:
	if not toggled:
		# If the user toggles off the currently-selected card, clear selection.
		if _selected == book:
			_selected = null
			_update_binding_label()
			_confirm_btn.disabled = true
		return
	# Toggle off all other cards
	for other in _book_cards:
		if other != card and other.button_pressed:
			other.set_selected(false)
	_selected = book
	_update_binding_label()
	_confirm_btn.disabled = false


func _update_binding_label() -> void:
	if _selected == null:
		_binding_label.text = "Tap a tome to bind it as your signature."
		_binding_label.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
		return
	var sig := _selected.base_spell.spell_name if _selected.base_spell else "—"
	_binding_label.text = "✦  Binding %s  ·  signature: %s  ✦" % [_selected.book_name, sig]
	_binding_label.add_theme_color_override("font_color", _selected.color if _selected.color.a > 0.05 else UITheme.GOLD_LIGHT)


func _on_confirm() -> void:
	if _selected == null:
		return
	var roster: Array[GoblinData] = []
	roster.assign(GameManager.selected_roster)
	if roster.is_empty():
		get_tree().change_scene_to_file(DRAFT)
		return
	RunManager.start_tournament(roster, _selected)
	get_tree().change_scene_to_file(TOURNAMENT_HUB)


func _on_back() -> void:
	get_tree().change_scene_to_file(DRAFT)
