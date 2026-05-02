extends Control
## Post-match page shop. Spend gold to bind a page to your spellbook.

const PAGE_CHOICES: int = 3

var _page_choices: Array[SpellPage] = []
var _book: SpellbookData = null

@onready var title_label: Label = %TitleLabel
@onready var result_label: Label = %ResultLabel
@onready var progress_label: Label = %ProgressLabel
@onready var card_row: HBoxContainer = %CardRow
@onready var skip_btn: Button = %SkipBtn

# Optional sibling label set by the .tscn ("Pick a card to add..."). Re-used for prompt.
var _pick_label: Label = null

func _ready() -> void:
	skip_btn.pressed.connect(_on_continue)
	skip_btn.text = "CONTINUE"
	UITheme.style_button(skip_btn)

	_pick_label = get_node_or_null("MainLayout/PickLabel") as Label

	_book = RunManager.run_spellbook
	_show_match_result()
	_roll_choices()
	_build_page_row()

	# Update prompt + re-emit gold listener so live changes refresh affordability.
	RunManager.gold_changed.connect(_on_gold_changed)

func _show_match_result() -> void:
	if RunManager.match_results.is_empty():
		title_label.text = "Match Complete"
		result_label.text = ""
		progress_label.text = ""
		return

	var last := RunManager.match_results.back() as Dictionary
	var p: int = last.get("player_goals", 0)
	var o: int = last.get("opponent_goals", 0)
	var won: bool = last.get("won", false)
	var opp_name: String = str(last.get("opponent_name", "?"))
	var gold_earned: int = last.get("gold_earned", 0)

	if won:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", UITheme.GREEN)
	elif p == o:
		title_label.text = "DRAW"
		title_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	else:
		title_label.text = "DEFEAT"
		title_label.add_theme_color_override("font_color", UITheme.RED)
	title_label.add_theme_font_size_override("font_size", 32)

	result_label.text = "%d - %d vs %s   (+%d gold)" % [p, o, opp_name, gold_earned]
	result_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	result_label.add_theme_font_size_override("font_size", 18)

	_refresh_progress_label()

func _refresh_progress_label() -> void:
	var pages_count: int = 0
	var max_pages: int = 0
	var book_name := "—"
	if _book:
		pages_count = _book.pages.size()
		max_pages = _book.max_pages()
		book_name = _book.book_name
	progress_label.text = "Gold: %d   |   %s   %d/%d pages" % [
		RunManager.gold, book_name, pages_count, max_pages
	]
	progress_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	progress_label.add_theme_font_size_override("font_size", 15)

func _roll_choices() -> void:
	_page_choices.clear()
	if _book == null:
		return
	_page_choices = SpellbookDatabase.roll_pages(_book.book_key, PAGE_CHOICES)

func _build_page_row() -> void:
	for child in card_row.get_children():
		child.queue_free()

	if _pick_label:
		if _book and not _book.can_add_page():
			_pick_label.text = "Spellbook is full - %d/%d pages bound." % [_book.pages.size(), _book.max_pages()]
		elif _book:
			_pick_label.text = "Bind a page to %s" % _book.book_name
		_pick_label.add_theme_color_override("font_color", UITheme.CREAM)
		_pick_label.add_theme_font_size_override("font_size", 16)

	if _page_choices.is_empty():
		var empty := Label.new()
		empty.text = "(no pages available)"
		empty.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		card_row.add_child(empty)
		return

	for i in range(_page_choices.size()):
		var widget := _make_page_widget(_page_choices[i], i)
		card_row.add_child(widget)

func _make_page_widget(page: SpellPage, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 280)
	var border_color := _rarity_color(page.rarity)
	var style := UITheme.make_panel_style(UITheme.BG_CARD, border_color, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = page.page_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", border_color)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = _rarity_text(page.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	rarity_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(rarity_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var desc := Label.new()
	desc.text = page.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", UITheme.CREAM)
	desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var cost_label := Label.new()
	cost_label.text = "%d gold" % page.gold_cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	cost_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cost_label)

	var buy_btn := Button.new()
	buy_btn.text = "BIND"
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.disabled = not RunManager.can_buy_page(page)
	UITheme.style_button(buy_btn, buy_btn.disabled == false)
	buy_btn.pressed.connect(_on_buy.bind(index))
	vbox.add_child(buy_btn)

	return panel

func _on_buy(index: int) -> void:
	if index < 0 or index >= _page_choices.size():
		return
	var page := _page_choices[index]
	if RunManager.buy_page(page):
		# Remove that page from choices so it can't double-buy.
		_page_choices.remove_at(index)
		_build_page_row()
		_refresh_progress_label()

func _on_gold_changed(_new_gold: int) -> void:
	# Re-evaluate buy buttons.
	_build_page_row()
	_refresh_progress_label()

func _on_continue() -> void:
	if RunManager.is_run_over():
		get_tree().change_scene_to_file("res://scenes/run_result/run_result.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")

func _rarity_color(rarity: int) -> Color:
	match rarity:
		SpellPage.Rarity.RARE:
			return Color(0.85, 0.55, 1.0)
		SpellPage.Rarity.UNCOMMON:
			return Color(0.4, 0.85, 1.0)
	return UITheme.CREAM_DIM

func _rarity_text(rarity: int) -> String:
	match rarity:
		SpellPage.Rarity.RARE:
			return "RARE"
		SpellPage.Rarity.UNCOMMON:
			return "UNCOMMON"
	return "COMMON"
