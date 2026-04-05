extends HBoxContainer
## Shows zone ratings for both sides. Colored rectangles with numbers.

const ZONE_COLOR := Color(0.15, 0.15, 0.2)
const ZONE_NAMES := ["attack", "midfield", "defense", "goal"]
const ZONE_LABELS := ["ATK", "MID", "DEF", "GK"]

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

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(vbox)

		var header := Label.new()
		header.text = zone_label
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(header)

		var player_label := Label.new()
		player_label.text = str(player_val)
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
		vbox.add_child(player_label)

		var vs_label := Label.new()
		vs_label.text = "vs"
		vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(vs_label)

		var opp_label := Label.new()
		opp_label.text = str(opp_val)
		opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opp_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		vbox.add_child(opp_label)
