class_name TopRail
extends PanelContainer
## Persistent header strip for every screen.
## Left: stage badge. Center: spellbook sigil + name. Right: gold pouch + record.

const RAIL_HEIGHT := 64

var _stage_label: Label = null
var _book_icon: Label = null
var _book_name: Label = null
var _gold_label: Label = null
var _record_label: Label = null
var _back_btn: Button = null
var _back_callback: Callable = Callable()


func _ready() -> void:
	custom_minimum_size.y = RAIL_HEIGHT
	# Wood-panel style with gold-leaf bottom accent
	var s: StyleBoxFlat = UITheme.make_panel_bg(UITheme.BG_DARK, UITheme.GOLD_DEEP, 3)
	s.border_width_left = 0
	s.border_width_right = 0
	s.border_width_top = 0
	s.border_width_bottom = 4
	s.set_corner_radius_all(0)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	add_theme_stylebox_override("panel", s)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	# ── LEFT: optional back button + stage badge ──────────────────────────
	var left_box := HBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 12)
	hbox.add_child(left_box)

	_back_btn = Button.new()
	_back_btn.theme_type_variation = &"SecondaryButton"
	_back_btn.text = "<"
	_back_btn.custom_minimum_size = Vector2(48, 44)
	_back_btn.add_theme_font_size_override("font_size", 22)
	_back_btn.visible = false
	_back_btn.pressed.connect(_on_back_pressed)
	left_box.add_child(_back_btn)

	_stage_label = Label.new()
	_stage_label.theme_type_variation = &"StageBadge"
	_stage_label.text = ""
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_box.add_child(_stage_label)

	# ── CENTER: spellbook sigil + name ────────────────────────────────────
	var center_box := HBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 8)
	hbox.add_child(center_box)

	_book_icon = Label.new()
	_book_icon.text = ""
	_book_icon.add_theme_font_size_override("font_size", 32)
	_book_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_box.add_child(_book_icon)

	_book_name = Label.new()
	_book_name.theme_type_variation = &"HeaderLabel"
	_book_name.add_theme_font_size_override("font_size", 22)
	_book_name.text = ""
	_book_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_box.add_child(_book_name)

	# ── RIGHT: gold pouch + run record ────────────────────────────────────
	var right_box := HBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.alignment = BoxContainer.ALIGNMENT_END
	right_box.add_theme_constant_override("separation", 16)
	hbox.add_child(right_box)

	_record_label = Label.new()
	_record_label.theme_type_variation = &"DimLabel"
	_record_label.add_theme_font_size_override("font_size", 16)
	_record_label.text = ""
	_record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_box.add_child(_record_label)

	_gold_label = Label.new()
	_gold_label.theme_type_variation = &"WaxSealBadge"
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.text = "0g"
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_box.add_child(_gold_label)


# ── Public API ─────────────────────────────────────────────────────────

func set_stage(name: String) -> void:
	if _stage_label:
		_stage_label.text = name.to_upper()


func set_book(book) -> void:
	## book is SpellbookData or null. Sets icon, name, and tints both.
	if _book_icon == null or _book_name == null:
		return
	if book == null:
		_book_icon.text = ""
		_book_name.text = ""
		return
	_book_icon.text = str(book.icon)
	_book_name.text = str(book.book_name)
	var c: Color = book.color
	if c.a < 0.05:
		c = UITheme.GOLD_LIGHT
	_book_name.add_theme_color_override("font_color", c)


func set_gold(amount: int) -> void:
	if _gold_label:
		_gold_label.text = "%dg" % amount


func set_record(wins: int, draws: int, losses: int) -> void:
	if _record_label:
		_record_label.text = "%dW %dD %dL" % [wins, draws, losses]


func set_back_callback(cb: Callable) -> void:
	_back_callback = cb
	if _back_btn:
		_back_btn.visible = cb.is_valid()


func _on_back_pressed() -> void:
	if _back_callback.is_valid():
		_back_callback.call()


## Pull all the standard slots from RunManager / current run state in one call.
func bind_run_state() -> void:
	if not RunManager:
		return
	if RunManager.tournament:
		set_stage(RunManager.get_stage_name())
		set_book(RunManager.run_spellbook)
		set_gold(RunManager.gold)
		var w := 0
		var d := 0
		var l := 0
		for r in RunManager.match_results:
			if bool(r.get("won", false)):
				w += 1
			elif int(r.get("player_goals", 0)) == int(r.get("opponent_goals", 0)):
				d += 1
			else:
				l += 1
		set_record(w, d, l)
	else:
		set_stage("")
		set_book(null)
		set_gold(0)
		_record_label.text = ""
