class_name GoblinCard
extends Button
## Illuminated-manuscript goblin card. The card visual signature of the game.
## Anatomy: gold-leaf parchment frame, role icon art window, name banner,
## 6-stat 2x3 grid, wax-seal OVR badge in top-right, level pip top-left,
## fatigue/injury ribbon at bottom. Composable via display modes.
##
## Use:
##   var card := GoblinCard.new()
##   card.set_goblin(goblin_data, GoblinCard.Mode.FULL)
##   card.set_selected(true)
##   card.toggled.connect(...)

enum Mode { COMPACT, FULL, MINI }

const SIZE_FULL := Vector2(192, 320)
const SIZE_COMPACT := Vector2(176, 224)
const SIZE_MINI := Vector2(180, 60)
const PORTRAIT_FULL_PX := 88.0
const PORTRAIT_COMPACT_PX := 56.0

var _mode: Mode = Mode.FULL
var _goblin = null
var _selected: bool = false
var _hover_active: bool = false

# Built nodes (rebuilt when goblin/mode changes)
var _frame: PanelContainer = null
var _vbox: VBoxContainer = null
var _shine: ColorRect = null
var _bounce_tween: Tween = null
var _shine_tween: Tween = null


func _init() -> void:
	flat = true
	toggle_mode = true
	clip_contents = false
	custom_minimum_size = SIZE_FULL
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_color_override("font_color", Color(0, 0, 0, 0))  # hide native button label


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	toggled.connect(_on_toggled)


func set_goblin(g, mode: Mode = Mode.FULL) -> void:
	_goblin = g
	_mode = mode
	custom_minimum_size = _size_for_mode(mode)
	_rebuild()


func set_selected(selected: bool) -> void:
	if button_pressed != selected:
		set_pressed_no_signal(selected)
	_selected = selected
	if _frame:
		_apply_frame_style()


func _on_toggled(pressed_now: bool) -> void:
	_selected = pressed_now
	if _frame:
		_apply_frame_style()


# ── Build ──────────────────────────────────────────────────────────────

func _size_for_mode(mode: Mode) -> Vector2:
	match mode:
		Mode.MINI:
			return SIZE_MINI
		Mode.COMPACT:
			return SIZE_COMPACT
		_:
			return SIZE_FULL


func _rebuild() -> void:
	# Tear down old children (not the button's text label — there isn't one visible)
	for child in get_children():
		child.queue_free()
	if _goblin == null:
		return

	# Frame (the parchment card)
	_frame = PanelContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_apply_frame_style()

	match _mode:
		Mode.MINI:
			_build_mini()
		Mode.COMPACT:
			_build_compact()
		_:
			_build_full()

	# Shine overlay (used on hover)
	_shine = ColorRect.new()
	_shine.color = Color(1.0, 0.95, 0.65, 0.0)
	_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shine)


func _apply_frame_style() -> void:
	if _frame == null:
		return
	var border: Color = UITheme.GOLD_LIGHT if _selected else UITheme.GOLD
	var bw := 5 if _selected else 3
	var s: StyleBoxFlat = UITheme.make_parchment_card_style(border, bw)
	if _selected:
		s.bg_color = Color(0.98, 0.92, 0.78)
	_frame.add_theme_stylebox_override("panel", s)


func _build_full() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(_vbox)

	# Portrait centered at top
	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(portrait_row)
	var portrait := GoblinPortrait.new()
	portrait.portrait_size = PORTRAIT_FULL_PX
	portrait_row.add_child(portrait)
	portrait.set_goblin(_goblin)

	var name_label := Label.new()
	name_label.theme_type_variation = &"ParchmentLabel"
	name_label.text = str(_goblin.goblin_name)
	name_label.add_theme_color_override("font_color", UITheme.WINE_DEEP)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_vbox.add_child(name_label)

	# Position + level row
	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 6)
	_vbox.add_child(pos_row)

	var pos_text := Label.new()
	pos_text.theme_type_variation = &"ParchmentLabel"
	pos_text.text = PositionDatabase.get_display_name(_goblin.position).to_upper()
	pos_text.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	pos_text.add_theme_font_size_override("font_size", 13)
	pos_row.add_child(pos_text)

	if int(_goblin.level) > 1:
		var lvl := Label.new()
		lvl.theme_type_variation = &"ParchmentLabel"
		lvl.text = "  ·  Lv %d" % int(_goblin.level)
		lvl.add_theme_color_override("font_color", UITheme.INK_SOFT)
		lvl.add_theme_font_size_override("font_size", 13)
		pos_row.add_child(lvl)

	# Divider flourish
	_vbox.add_child(_make_flourish())

	# Stat grid
	_vbox.add_child(_build_stat_grid())

	# Spacer pushes the bottom ribbon to the bottom of the card
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(fill)

	# Bottom: item / status ribbon
	var bottom := _build_bottom_ribbon()
	if bottom:
		_vbox.add_child(_make_thin_divider())
		_vbox.add_child(bottom)

	# Wax-seal OVR badge (top-right, anchored)
	add_child(_build_wax_seal(UITheme.compute_overall(_goblin), UITheme.WINE))
	if _goblin.has_method("has_pending_level_up") and _goblin.has_pending_level_up():
		add_child(_build_levelup_star())


func _build_compact() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_frame.add_child(_vbox)

	# Portrait centered at top
	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(portrait_row)
	var portrait := GoblinPortrait.new()
	portrait.portrait_size = PORTRAIT_COMPACT_PX
	portrait_row.add_child(portrait)
	portrait.set_goblin(_goblin)

	var name_label := Label.new()
	name_label.text = str(_goblin.goblin_name)
	name_label.add_theme_color_override("font_color", UITheme.WINE_DEEP)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(name_label)

	var pos_label := Label.new()
	pos_label.text = PositionDatabase.get_display_name(_goblin.position).to_upper()
	pos_label.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	pos_label.add_theme_font_size_override("font_size", 10)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if int(_goblin.level) > 1:
		pos_label.text += "  ·  L%d" % int(_goblin.level)
	_vbox.add_child(pos_label)

	_vbox.add_child(_make_thin_divider())
	_vbox.add_child(_build_stat_grid())

	var bottom := _build_bottom_ribbon()
	if bottom:
		_vbox.add_child(bottom)

	add_child(_build_wax_seal(UITheme.compute_overall(_goblin), UITheme.WINE))
	if _goblin.has_method("has_pending_level_up") and _goblin.has_pending_level_up():
		add_child(_build_levelup_star())


func _build_mini() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_frame.add_child(hbox)

	var portrait := GoblinPortrait.new()
	portrait.portrait_size = 44.0
	hbox.add_child(portrait)
	portrait.set_goblin(_goblin)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	hbox.add_child(v)

	var name_label := Label.new()
	name_label.text = str(_goblin.goblin_name)
	name_label.add_theme_color_override("font_color", UITheme.WINE_DEEP)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_label)

	var pos := Label.new()
	pos.text = PositionDatabase.get_display_name(_goblin.position).to_upper()
	pos.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	pos.add_theme_font_size_override("font_size", 10)
	v.add_child(pos)

	var ovr := Label.new()
	ovr.theme_type_variation = &"WaxSealBadge"
	ovr.add_theme_font_size_override("font_size", 22)
	ovr.text = str(UITheme.compute_overall(_goblin))
	ovr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(ovr)


# ── Sub-builders ───────────────────────────────────────────────────────

func _build_stat_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)

	var primary: Array = PositionDatabase.get_primary_stats(_goblin.position)
	var stats := [
		["SHO", "shooting"], ["SPD", "speed"], ["DEF", "defense"],
		["STR", "strength"], ["HP", "health"], ["CHA", "chaos"]
	]
	for entry in stats:
		var lbl: String = entry[0]
		var key: String = entry[1]
		var val: int = int(_goblin.get_stat(key))
		var is_primary: bool = key in primary
		grid.add_child(_make_stat_chip(lbl, val, is_primary))
	return grid


func _make_stat_chip(label_text: String, value: int, primary: bool) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.make_stat_chip_style(primary))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)

	var name_l := Label.new()
	name_l.text = label_text
	name_l.add_theme_color_override("font_color", UITheme.GOLD_LIGHT if primary else UITheme.PARCHMENT_DARK)
	name_l.add_theme_font_size_override("font_size", 12)
	row.add_child(name_l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val_l := Label.new()
	val_l.text = str(value)
	val_l.add_theme_font_size_override("font_size", 16)
	UITheme.tint_stat_label(val_l, value)
	row.add_child(val_l)

	return chip


func _build_bottom_ribbon() -> Control:
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 2)

	var any := false

	# Injury / fatigue
	var status_text: String = ""
	var status_color: Color = UITheme.INK_SOFT
	if int(_goblin.injury) == int(GoblinData.InjuryState.MAJOR):
		status_text = "MAJOR INJURY"
		status_color = UITheme.CRIMSON
	elif int(_goblin.injury) == int(GoblinData.InjuryState.MINOR):
		status_text = "MINOR INJURY"
		status_color = UITheme.WINE
	elif int(_goblin.fatigue) >= 5:
		status_text = "EXHAUSTED"
		status_color = UITheme.WINE
	elif int(_goblin.fatigue) >= 3:
		status_text = "TIRED"
		status_color = UITheme.GOLD_DEEP

	if status_text != "":
		var status_l := Label.new()
		status_l.text = status_text
		status_l.add_theme_color_override("font_color", status_color)
		status_l.add_theme_font_size_override("font_size", 11)
		status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bottom.add_child(status_l)
		any = true

	# Equipped item
	if _goblin.has_method("has_item") and _goblin.has_item():
		var item = _goblin.equipped_item
		var item_l := Label.new()
		item_l.text = "⚜ %s" % item.item_name
		var ic: Color = UITheme.INK_SOFT
		if item.has_method("get_rarity_color"):
			ic = item.get_rarity_color()
		item_l.add_theme_color_override("font_color", ic)
		item_l.add_theme_font_size_override("font_size", 11)
		item_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bottom.add_child(item_l)
		any = true

	# Pending level-up dot
	if _goblin.has_method("has_pending_level_up") and _goblin.has_pending_level_up():
		var lvl_l := Label.new()
		lvl_l.text = "★ LEVEL-UP READY (+%d)" % int(_goblin.pending_level_ups)
		lvl_l.add_theme_color_override("font_color", UITheme.EMERALD)
		lvl_l.add_theme_font_size_override("font_size", 11)
		lvl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bottom.add_child(lvl_l)
		any = true

	if not any:
		# Personality flavor (truncated)
		var pers := str(_goblin.personality)
		if pers != "":
			var pl := Label.new()
			pl.text = pers
			pl.add_theme_color_override("font_color", UITheme.INK_SOFT)
			pl.add_theme_font_size_override("font_size", 10)
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom.add_child(pl)
			any = true

	if not any:
		return null
	return bottom


func _build_levelup_star() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.make_wax_seal_style(UITheme.EMERALD, UITheme.GOLD_LIGHT))
	pc.custom_minimum_size = Vector2(40, 40)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pc.position.x = -8
	pc.position.y = -8

	var lbl := Label.new()
	lbl.text = "★"
	lbl.theme_type_variation = &"WaxSealBadge"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(lbl)
	return pc


func _build_wax_seal(value: int, seal_color: Color) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.make_wax_seal_style(seal_color, UITheme.GOLD))
	pc.custom_minimum_size = Vector2(58, 58)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor to top-right corner of the card and offset a bit outside
	pc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pc.position.x = -58 - 4
	pc.position.y = -6

	var lbl := Label.new()
	lbl.text = str(value)
	lbl.theme_type_variation = &"WaxSealBadge"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(lbl)

	return pc


func _make_flourish() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var ll := ColorRect.new()
	ll.color = UITheme.GOLD_DEEP
	ll.custom_minimum_size = Vector2(60, 2)
	ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ll)

	var diamond := Label.new()
	diamond.text = "✦"
	diamond.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	diamond.add_theme_font_size_override("font_size", 14)
	row.add_child(diamond)

	var lr := ColorRect.new()
	lr.color = UITheme.GOLD_DEEP
	lr.custom_minimum_size = Vector2(60, 2)
	lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lr)

	return row


func _make_thin_divider() -> Control:
	var div := ColorRect.new()
	div.color = UITheme.GOLD_DEEP
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return div


# ── Hover juice ────────────────────────────────────────────────────────

func _on_hover_in() -> void:
	_hover_active = true
	_tween_scale(Vector2(1.04, 1.04), 0.14)
	_play_shine()


func _on_hover_out() -> void:
	_hover_active = false
	_tween_scale(Vector2.ONE, 0.18)


func _tween_scale(target: Vector2, duration: float) -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", target, duration)


func _play_shine() -> void:
	if _shine == null:
		return
	if _shine_tween and _shine_tween.is_valid():
		_shine_tween.kill()
	_shine.color.a = 0.0
	_shine_tween = create_tween()
	_shine_tween.tween_property(_shine, "color:a", 0.30, 0.10).set_ease(Tween.EASE_OUT)
	_shine_tween.tween_property(_shine, "color:a", 0.0, 0.40).set_ease(Tween.EASE_IN)
