extends VBoxContainer
## Vertical zone rating sidebar. Stacks F / M / D / GK cards on the right side.

const ZONE_NAMES := ["attack", "midfield", "defense", "goal"]
const ZONE_LABELS := ["F", "M", "D", "GK"]

func _ready() -> void:
	GameManager.formation_changed.connect(_build_display)
	_build_display()

func _build_display() -> void:
	for child in get_children():
		child.queue_free()

	var player_zones := GameManager.get_player_zones()
	var opponent_zones := GameManager.get_opponent_zones()

	for i in ZONE_NAMES.size():
		var zone_name: String = ZONE_NAMES[i]
		var zone_label: String = ZONE_LABELS[i]
		var player_val: int = player_zones[zone_name]
		var opp_val: int = opponent_zones[zone_name]

		var panel := PanelContainer.new()
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var style := UITheme.make_panel_style(UITheme.BG_PANEL, UITheme.GOLD, 1)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)
		panel.add_child(vbox)

		var header := Label.new()
		header.text = zone_label
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_color_override("font_color", UITheme.GOLD)
		header.add_theme_font_size_override("font_size", 13)
		vbox.add_child(header)

		var player_label := Label.new()
		player_label.text = str(player_val)
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_label.add_theme_color_override("font_color", UITheme.BLUE)
		player_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(player_label)

		var vs_label := Label.new()
		vs_label.text = "vs"
		vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vs_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		vs_label.add_theme_font_size_override("font_size", 9)
		vbox.add_child(vs_label)

		var opp_label := Label.new()
		opp_label.text = str(opp_val)
		opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opp_label.add_theme_color_override("font_color", UITheme.RED)
		opp_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(opp_label)
