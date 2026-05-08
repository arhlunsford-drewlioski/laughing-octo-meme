extends Control
## Post-match page shop. Spend gold to bind a page to your spellbook.
## Hero band shows the match result; below is a row of 3 SpellCard PAGE cards.

const PAGE_CHOICES: int = 3

var _page_choices: Array[SpellPage] = []
var _book: SpellbookData = null

var _shell: PageShell
var _hero_title: Label
var _hero_score: Label
var _hero_progress: Label
var _card_row: HBoxContainer
var _bind_prompt: Label
var _continue_btn: BigCTA


func _ready() -> void:
	_book = RunManager.run_spellbook
	_build_ui()
	_show_match_result()
	_roll_choices()
	_build_page_row()
	RunManager.gold_changed.connect(_on_gold_changed)


func _build_ui() -> void:
	_shell = PageShell.new()
	add_child(_shell)
	_shell.top_rail.bind_run_state()

	# Hero band
	var hero := VBoxContainer.new()
	hero.add_theme_constant_override("separation", 4)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	_shell.center_content.add_child(hero)

	_hero_title = Label.new()
	_hero_title.theme_type_variation = &"HeaderLabel"
	_hero_title.add_theme_font_size_override("font_size", 56)
	_hero_title.text = "VICTORY"
	_hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(_hero_title)

	_hero_score = Label.new()
	_hero_score.theme_type_variation = &"SubheaderLabel"
	_hero_score.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	_hero_score.add_theme_font_size_override("font_size", 22)
	_hero_score.text = ""
	_hero_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(_hero_score)

	_hero_progress = Label.new()
	_hero_progress.theme_type_variation = &"DimLabel"
	_hero_progress.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	_hero_progress.add_theme_font_size_override("font_size", 14)
	_hero_progress.text = ""
	_hero_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(_hero_progress)

	# Bind prompt
	_bind_prompt = Label.new()
	_bind_prompt.theme_type_variation = &"SubheaderLabel"
	_bind_prompt.add_theme_color_override("font_color", UITheme.PARCHMENT)
	_bind_prompt.add_theme_font_size_override("font_size", 18)
	_bind_prompt.text = "Bind a page to your spellbook."
	_bind_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shell.center_content.add_child(_bind_prompt)

	# Card row
	var row_margin := MarginContainer.new()
	row_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_margin.add_theme_constant_override("margin_top", 12)
	_shell.center_content.add_child(row_margin)

	_card_row = HBoxContainer.new()
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.add_theme_constant_override("separation", 24)
	_card_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row_margin.add_child(_card_row)

	# Action bar
	_continue_btn = _shell.add_primary_cta("CONTINUE", _on_continue)


func _show_match_result() -> void:
	if RunManager.match_results.is_empty():
		_hero_title.text = "MATCH COMPLETE"
		_hero_score.text = ""
		_hero_progress.text = ""
		return

	var last := RunManager.match_results.back() as Dictionary
	var p: int = int(last.get("player_goals", 0))
	var o: int = int(last.get("opponent_goals", 0))
	var won: bool = bool(last.get("won", false))
	var opp_name: String = str(last.get("opponent_name", "?"))
	var gold_earned: int = int(last.get("gold_earned", 0))

	if won:
		_hero_title.text = "VICTORY"
		_hero_title.add_theme_color_override("font_color", UITheme.EMERALD_LIGHT)
	elif p == o:
		_hero_title.text = "DRAW"
		_hero_title.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	else:
		_hero_title.text = "DEFEAT"
		_hero_title.add_theme_color_override("font_color", UITheme.CRIMSON_LIGHT)

	_hero_score.text = "%d  -  %d  vs  %s   (+%d gold)" % [p, o, opp_name, gold_earned]
	_refresh_progress_label()


func _refresh_progress_label() -> void:
	var pages_count: int = 0
	var max_pages_v: int = 0
	var book_name := "—"
	if _book:
		pages_count = _book.pages.size()
		max_pages_v = _book.max_pages()
		book_name = _book.book_name
	_hero_progress.text = "Gold: %d   |   %s   %d/%d pages bound" % [
		RunManager.gold, book_name, pages_count, max_pages_v
	]


func _roll_choices() -> void:
	_page_choices.clear()
	if _book == null:
		return
	_page_choices = SpellbookDatabase.roll_pages(_book.book_key, PAGE_CHOICES)


func _build_page_row() -> void:
	for child in _card_row.get_children():
		child.queue_free()

	if _book and not _book.can_add_page():
		_bind_prompt.text = "Spellbook is full — %d/%d pages bound." % [_book.pages.size(), _book.max_pages()]
		_bind_prompt.add_theme_color_override("font_color", UITheme.PARCHMENT_DEEP)
	elif _book:
		_bind_prompt.text = "Bind a page to %s." % _book.book_name
		_bind_prompt.add_theme_color_override("font_color", UITheme.PARCHMENT)

	if _page_choices.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"DimLabel"
		empty.text = "(no pages available)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_row.add_child(empty)
		return

	for i in range(_page_choices.size()):
		var page: SpellPage = _page_choices[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		_card_row.add_child(box)

		var card := SpellCard.new()
		box.add_child(card)
		card.set_page(page, page.gold_cost)
		# Page card click selects-and-buys in one motion
		var idx := i
		card.toggled.connect(func(t):
			if t:
				_attempt_buy(idx, card)
		)

		var bind_btn := Button.new()
		bind_btn.theme_type_variation = &"GoldButton"
		bind_btn.text = "BIND  ·  %dg" % page.gold_cost
		bind_btn.custom_minimum_size = Vector2(0, 38)
		bind_btn.disabled = not RunManager.can_buy_page(page)
		bind_btn.pressed.connect(_attempt_buy.bind(i, card))
		box.add_child(bind_btn)


func _attempt_buy(index: int, card: SpellCard) -> void:
	if index < 0 or index >= _page_choices.size():
		return
	var page := _page_choices[index]
	if not RunManager.can_buy_page(page):
		card.set_selected(false)
		return
	if RunManager.buy_page(page):
		_page_choices.remove_at(index)
		_build_page_row()
		_refresh_progress_label()


func _on_gold_changed(_new_gold: int) -> void:
	_build_page_row()
	_refresh_progress_label()


func _on_continue() -> void:
	if RunManager.is_run_over():
		get_tree().change_scene_to_file("res://scenes/run_result/run_result.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
