extends Control
## Title screen. Three hero cards (CR-style) over a dark tome backdrop.
## Click "Begin a Tournament" to enter draft. Other cards are flavor / dev.

const DRAFT_SCENE := "res://scenes/draft/draft.tscn"
const SIM_VIEWER := "res://scenes/match_sim/match_sim_viewer.tscn"

const CARD_DATA := [
	{
		"key": "tournament",
		"icon": "🏆",
		"title": "Begin a Tournament",
		"subtitle": "Draft 10 goblins. Bind a spellbook. Survive five stages.",
		"primary": true,
	},
	{
		"key": "spell_test",
		"icon": "🔥",
		"title": "Spell Test Match",
		"subtitle": "Quick duel with no run state. Try the spell hand.",
		"primary": false,
	},
	{
		"key": "lore",
		"icon": "📖",
		"title": "On Goblins & Goals",
		"subtitle": "A field-wizard's manifesto. (Coming soon.)",
		"primary": false,
	},
]


func _ready() -> void:
	# ── Backdrop ───────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = UITheme.BG_NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.18, 0.10, 0.06, 0.0))
	grad.add_point(1.0, Color(0, 0, 0, 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.4)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	vignette.texture = tex
	add_child(vignette)

	# Outer thin gold frame
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = UITheme.GOLD_DEEP
	fs.border_width_left = 3
	fs.border_width_right = 3
	fs.border_width_top = 3
	fs.border_width_bottom = 3
	frame.add_theme_stylebox_override("panel", fs)
	add_child(frame)

	# ── Main vertical stack ───────────────────────────────────────────
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 12)
	add_child(stack)

	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 56)
	stack.add_child(top_pad)

	# Eyebrow
	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"DimLabel"
	eyebrow.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.text = "✠   A   T O M E   O F   F O O T B A L L   ✠"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)

	# Title
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	title.add_theme_color_override("font_outline_color", UITheme.WINE_DEEP)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_font_size_override("font_size", 92)
	title.text = "Goals & Goblins"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)

	# Flourish divider
	var flourish := HBoxContainer.new()
	flourish.alignment = BoxContainer.ALIGNMENT_CENTER
	flourish.add_theme_constant_override("separation", 12)
	stack.add_child(flourish)
	var ll := ColorRect.new()
	ll.color = UITheme.GOLD_DEEP
	ll.custom_minimum_size = Vector2(220, 3)
	ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flourish.add_child(ll)
	var diamond := Label.new()
	diamond.text = "✦"
	diamond.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	diamond.add_theme_font_size_override("font_size", 22)
	flourish.add_child(diamond)
	var lr := ColorRect.new()
	lr.color = UITheme.GOLD_DEEP
	lr.custom_minimum_size = Vector2(220, 3)
	lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flourish.add_child(lr)

	# Subtitle
	var subtitle := Label.new()
	subtitle.theme_type_variation = &"SubheaderLabel"
	subtitle.add_theme_color_override("font_color", UITheme.PARCHMENT_DARK)
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.text = "Wherein two & thirty teams of goblins doe contest for the cup."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	stack.add_child(spacer)

	# ── Hero card row ─────────────────────────────────────────────────
	var card_row_margin := MarginContainer.new()
	card_row_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_row_margin.add_theme_constant_override("margin_left", 64)
	card_row_margin.add_theme_constant_override("margin_right", 64)
	stack.add_child(card_row_margin)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 24)
	card_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_row_margin.add_child(card_row)

	for entry in CARD_DATA:
		card_row.add_child(_make_hero_card(entry))

	# ── Footer (dev row + version) ────────────────────────────────────
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	stack.add_child(footer)

	# Dev row hidden by default (matches old behavior; toggled per-build)
	var dev_row := HBoxContainer.new()
	dev_row.name = "DevButtonRow"
	dev_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dev_row.add_theme_constant_override("separation", 8)
	dev_row.visible = false
	stack.add_child(dev_row)

	var version := Label.new()
	version.theme_type_variation = &"DimLabel"
	version.add_theme_color_override("font_color", UITheme.PARCHMENT_DEEP)
	version.add_theme_font_size_override("font_size", 14)
	version.text = "v0.1  ·  anno mmxxvi"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(version)

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 16)
	stack.add_child(bottom_pad)


func _make_hero_card(entry: Dictionary) -> Control:
	var key: String = entry["key"]
	var card := Button.new()
	card.flat = true
	card.toggle_mode = false
	card.clip_contents = false
	card.custom_minimum_size = Vector2(280, 360)
	card.add_theme_color_override("font_color", Color(0, 0, 0, 0))  # hide default text
	card.pivot_offset = Vector2(140, 180)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border: Color = UITheme.GOLD_LIGHT if entry.get("primary", false) else UITheme.GOLD_DEEP
	frame.add_theme_stylebox_override("panel", UITheme.make_parchment_card_style(border, 5 if entry.get("primary", false) else 3))
	card.add_child(frame)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	frame.add_child(v)

	var icon := Label.new()
	icon.text = str(entry["icon"])
	icon.add_theme_font_size_override("font_size", 96)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	# Tiny flourish under icon
	var fl := HBoxContainer.new()
	fl.alignment = BoxContainer.ALIGNMENT_CENTER
	fl.add_theme_constant_override("separation", 6)
	v.add_child(fl)
	var f1 := ColorRect.new()
	f1.color = UITheme.GOLD_DEEP
	f1.custom_minimum_size = Vector2(60, 2)
	f1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fl.add_child(f1)
	var fd := Label.new()
	fd.text = "✦"
	fd.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	fd.add_theme_font_size_override("font_size", 14)
	fl.add_child(fd)
	var f2 := ColorRect.new()
	f2.color = UITheme.GOLD_DEEP
	f2.custom_minimum_size = Vector2(60, 2)
	f2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fl.add_child(f2)

	var title_l := Label.new()
	title_l.text = str(entry["title"]).to_upper()
	title_l.add_theme_color_override("font_color", UITheme.WINE_DEEP)
	title_l.add_theme_font_size_override("font_size", 22)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title_l)

	var subtitle_l := Label.new()
	subtitle_l.text = str(entry["subtitle"])
	subtitle_l.add_theme_color_override("font_color", UITheme.INK_SOFT)
	subtitle_l.add_theme_font_size_override("font_size", 13)
	subtitle_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(subtitle_l)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# CTA chip at bottom
	var cta := Label.new()
	if entry.get("primary", false):
		cta.text = "▶  ENTER"
		cta.add_theme_color_override("font_color", UITheme.GOLD)
	else:
		cta.text = "TAP TO OPEN"
		cta.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	cta.add_theme_font_size_override("font_size", 14)
	cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cta)

	# Wax seal (top-right) only on primary
	if entry.get("primary", false):
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.make_wax_seal_style(UITheme.WINE, UITheme.GOLD_LIGHT))
		pc.custom_minimum_size = Vector2(58, 58)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pc.position.x = -58 - 4
		pc.position.y = -6
		var seal_lbl := Label.new()
		seal_lbl.text = "I"
		seal_lbl.theme_type_variation = &"WaxSealBadge"
		seal_lbl.add_theme_font_size_override("font_size", 26)
		seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seal_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(seal_lbl)
		card.add_child(pc)

	# Hover juice
	var shine := ColorRect.new()
	shine.color = Color(1.0, 0.95, 0.65, 0.0)
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shine)

	card.mouse_entered.connect(func():
		var t := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2(1.04, 1.04), 0.15)
		var st := card.create_tween()
		st.tween_property(shine, "color:a", 0.30, 0.10)
		st.tween_property(shine, "color:a", 0.0, 0.40)
	)
	card.mouse_exited.connect(func():
		var t := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2.ONE, 0.18)
	)
	card.button_down.connect(func():
		var t := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2(0.96, 0.96), 0.06)
	)
	card.button_up.connect(func():
		var t := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "scale", Vector2.ONE, 0.16)
	)
	card.pressed.connect(_on_card_pressed.bind(key))

	return card


func _on_card_pressed(key: String) -> void:
	match key:
		"tournament":
			get_tree().change_scene_to_file(DRAFT_SCENE)
		"spell_test":
			RunManager.reset_run()
			GameManager.selected_roster = []
			get_tree().change_scene_to_file(SIM_VIEWER)
		"lore":
			pass  # no-op; lore screen TBD
