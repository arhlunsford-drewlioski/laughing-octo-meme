class_name SpellCard
extends Button
## Illuminated-manuscript spell/page card. Wax-seal mana cost in corner,
## emoji icon art window, name banner, body text, optional "page count" footer.
##
## Use:
##   var card := SpellCard.new()
##   card.set_spell(spell_data)        # SpellData
##   card.set_book(book_data)          # SpellbookData (book selection / shop)
##   card.set_page(page, gold_cost)    # SpellPage (post-match reward)

enum Mode { SPELL, BOOK_HERO, PAGE }

const SIZE_HERO := Vector2(280, 380)
const SIZE_SPELL := Vector2(200, 240)
const SIZE_PAGE := Vector2(220, 280)

var _mode: Mode = Mode.SPELL
var _data = null
var _selected: bool = false
var _meta_color: Color = UITheme.GOLD
var _shine: ColorRect = null
var _shine_tween: Tween = null
var _bounce_tween: Tween = null
var _frame: PanelContainer = null


func _init() -> void:
	flat = true
	toggle_mode = true
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SIZE_SPELL
	add_theme_color_override("font_color", Color(0, 0, 0, 0))


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	toggled.connect(_on_toggled)


func set_spell(spell) -> void:
	_data = spell
	_mode = Mode.SPELL
	_meta_color = _spell_color(spell)
	custom_minimum_size = SIZE_SPELL
	_rebuild()


func set_book(book) -> void:
	_data = book
	_mode = Mode.BOOK_HERO
	_meta_color = book.color if book and book.color.a > 0.05 else UITheme.GOLD
	custom_minimum_size = SIZE_HERO
	_rebuild()


func set_page(page, gold_cost: int = -1) -> void:
	_data = {"page": page, "cost": gold_cost}
	_mode = Mode.PAGE
	_meta_color = _rarity_color(page.rarity if page else 0)
	custom_minimum_size = SIZE_PAGE
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

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _data == null:
		return

	_frame = PanelContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_apply_frame_style()

	match _mode:
		Mode.BOOK_HERO:
			_build_book()
		Mode.PAGE:
			_build_page()
		_:
			_build_spell()

	_shine = ColorRect.new()
	_shine.color = Color(1.0, 0.95, 0.65, 0.0)
	_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shine)


func _apply_frame_style() -> void:
	if _frame == null:
		return
	var border: Color = _meta_color.lightened(0.2) if _selected else _meta_color
	var bw := 5 if _selected else 4
	_frame.add_theme_stylebox_override("panel", UITheme.make_parchment_card_style(border, bw))


func _build_spell() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_frame.add_child(v)

	# Icon row
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(icon_row)

	var icon := Label.new()
	icon.text = _spell_icon(_data)
	icon.add_theme_font_size_override("font_size", 56)
	icon_row.add_child(icon)

	# Name banner
	var name_l := Label.new()
	name_l.text = str(_data.spell_name).to_upper()
	name_l.add_theme_color_override("font_color", _meta_color)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)

	v.add_child(_make_thin_divider())

	# Description
	var desc := Label.new()
	desc.text = str(_data.description)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", UITheme.INK)
	desc.add_theme_font_size_override("font_size", 12)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Wax-seal mana cost (top-right)
	var seal := _build_cost_seal(int(_data.mana_cost), UITheme.ROYAL_PURPLE)
	add_child(seal)


func _build_book() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_frame.add_child(v)

	# Hero icon
	var icon := Label.new()
	icon.text = str(_data.icon)
	icon.add_theme_font_size_override("font_size", 84)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	# Book name
	var name_l := Label.new()
	name_l.text = str(_data.book_name).to_upper()
	name_l.add_theme_color_override("font_color", _meta_color)
	name_l.add_theme_color_override("font_outline_color", UITheme.INK)
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)

	v.add_child(_make_thin_divider())

	# Signature spell
	var spell = _data.base_spell
	if spell:
		var sig_label := Label.new()
		sig_label.text = "SIGNATURE  ·  %s" % spell.spell_name
		sig_label.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
		sig_label.add_theme_font_size_override("font_size", 13)
		sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sig_label)

		var sig_desc := Label.new()
		sig_desc.text = str(spell.description)
		sig_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sig_desc.add_theme_color_override("font_color", UITheme.INK)
		sig_desc.add_theme_font_size_override("font_size", 12)
		sig_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sig_desc)

	# Book lore
	var lore := Label.new()
	lore.text = str(_data.description)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.add_theme_color_override("font_color", UITheme.INK_SOFT)
	lore.add_theme_font_size_override("font_size", 12)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lore)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)


func _build_page() -> void:
	var page = _data.get("page")
	var cost: int = int(_data.get("cost", -1))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_frame.add_child(v)

	# Name
	var name_l := Label.new()
	name_l.text = str(page.page_name).to_upper()
	name_l.add_theme_color_override("font_color", _meta_color)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)

	# Rarity ribbon
	var rarity_l := Label.new()
	rarity_l.text = _rarity_text(page.rarity)
	rarity_l.add_theme_color_override("font_color", UITheme.INK_SOFT)
	rarity_l.add_theme_font_size_override("font_size", 10)
	rarity_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rarity_l)

	v.add_child(_make_thin_divider())

	# Description
	var desc := Label.new()
	desc.text = str(page.description)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", UITheme.INK)
	desc.add_theme_font_size_override("font_size", 12)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Footer cost
	if cost >= 0:
		var cost_l := Label.new()
		cost_l.text = "%d gold" % cost
		cost_l.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
		cost_l.add_theme_font_size_override("font_size", 14)
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cost_l)


func _build_cost_seal(cost: int, color: Color) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.make_wax_seal_style(color, UITheme.GOLD))
	pc.custom_minimum_size = Vector2(50, 50)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pc.position.x = -50 - 4
	pc.position.y = -6

	var lbl := Label.new()
	lbl.text = str(cost)
	lbl.theme_type_variation = &"WaxSealBadge"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(lbl)
	return pc


func _make_thin_divider() -> Control:
	var d := ColorRect.new()
	d.color = UITheme.GOLD_DEEP
	d.custom_minimum_size = Vector2(0, 1)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


# ── Helpers ────────────────────────────────────────────────────────────

static func _spell_icon(spell) -> String:
	if spell == null:
		return "✦"
	match str(spell.special_effect):
		"fireball": return "🔥"
		"shield_dome": return "🛡"
		"chain_lightning", "lightning_bolt": return "⚡"
		"healing_wave", "heal": return "✚"
		"haste": return "💨"
		"shadow_wall": return "🌑"
		"hex": return "👁"
		"blood_pact": return "🩸"
		"frenzy": return "🪓"
		"curse_of_post": return "☩"
		"meteor": return "☄"
		"earthquake": return "⛰"
		"divine_light": return "☀"
		"dark_surge": return "🌟"
		"resurrect": return "✦"
		"mass_protect": return "⛨"
		"rage_potion": return "🍷"
		"rot_curse": return "💀"
		"teleport": return "✷"
		"war_cry": return "📯"
	return "✦"


static func _spell_color(spell) -> Color:
	if spell == null:
		return UITheme.GOLD
	match str(spell.special_effect):
		"fireball", "meteor", "frenzy": return UITheme.WINE
		"shield_dome", "mass_protect": return UITheme.ROYAL
		"chain_lightning", "lightning_bolt": return UITheme.ROYAL_PURPLE_LIGHT
		"healing_wave", "heal", "divine_light": return UITheme.EMERALD
		"haste": return UITheme.GOLD
		"shadow_wall", "hex", "rot_curse": return UITheme.ROYAL_PURPLE
		"blood_pact", "rage_potion": return UITheme.WINE_DEEP
	return UITheme.GOLD


static func _rarity_color(rarity: int) -> Color:
	# SpellPage.Rarity: COMMON=0, UNCOMMON=1, RARE=2
	match rarity:
		2: return UITheme.ROYAL_PURPLE_LIGHT
		1: return UITheme.ROYAL
	return UITheme.GOLD


static func _rarity_text(rarity: int) -> String:
	match rarity:
		2: return "RARE"
		1: return "UNCOMMON"
	return "COMMON"


# ── Hover juice ────────────────────────────────────────────────────────

func _on_hover_in() -> void:
	_tween_scale(Vector2(1.05, 1.05), 0.12)
	_play_shine()


func _on_hover_out() -> void:
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
