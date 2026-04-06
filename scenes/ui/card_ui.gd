extends PanelContainer
## Visual representation of a single card. Gold-bordered, type-colored, with hover/play tweens.

signal card_clicked(card_index: int)

const HOVER_SCALE := Vector2(1.05, 1.05)
const HOVER_DURATION := 0.12

var card_data: CardData
var card_index: int = -1
var _hover_tween: Tween

@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var cost_label: Label = %CostLabel
@onready var cost_badge: PanelContainer = %CostBadge
@onready var value_label: Label = %ValueLabel
@onready var flavor_label: Label = %FlavorLabel

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(data: CardData, index: int) -> void:
	card_data = data
	card_index = index
	_update_display()

func _update_display() -> void:
	if card_data == null:
		return

	name_label.text = card_data.card_name
	name_label.add_theme_color_override("font_color", UITheme.CREAM)
	name_label.add_theme_font_size_override("font_size", 15)

	flavor_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	flavor_label.add_theme_font_size_override("font_size", 12)
	flavor_label.text = card_data.flavor_text

	type_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", UITheme.CREAM)
	value_label.add_theme_font_size_override("font_size", 13)

	var bg_color: Color
	var border_color: Color

	match card_data.card_type:
		CardData.CardType.TEMPO:
			type_label.text = "TEMPO"
			type_label.add_theme_color_override("font_color", UITheme.TEMPO_BORDER)
			value_label.text = str(roundi(card_data.base_conversion * 100)) + "% Goal"
			bg_color = UITheme.TEMPO_BG
			border_color = UITheme.TEMPO_BORDER
		CardData.CardType.POSSESSION:
			type_label.text = "POSSESSION"
			type_label.add_theme_color_override("font_color", UITheme.POSSESSION_BORDER)
			value_label.text = "+" + str(card_data.possession_value) + " Control"
			bg_color = UITheme.POSSESSION_BG
			border_color = UITheme.POSSESSION_BORDER
		CardData.CardType.DEFENSE:
			type_label.text = "DEFENSE"
			type_label.add_theme_color_override("font_color", UITheme.DEFENSE_BORDER)
			value_label.text = "+" + str(card_data.defense_value) + " Block"
			bg_color = UITheme.DEFENSE_BG
			border_color = UITheme.DEFENSE_BORDER
		CardData.CardType.ATK_BUFF:
			type_label.text = "ATK BUFF"
			type_label.add_theme_color_override("font_color", UITheme.TEMPO_BORDER)
			value_label.text = "+" + str(card_data.possession_value) + " ATK"
			bg_color = UITheme.TEMPO_BG
			border_color = UITheme.TEMPO_BORDER
		CardData.CardType.DEF_BUFF:
			type_label.text = "DEF BUFF"
			type_label.add_theme_color_override("font_color", UITheme.DEFENSE_BORDER)
			value_label.text = "+" + str(card_data.defense_value) + " DEF"
			bg_color = UITheme.DEFENSE_BG
			border_color = UITheme.DEFENSE_BORDER
		CardData.CardType.MID_BUFF:
			type_label.text = "MID BUFF"
			type_label.add_theme_color_override("font_color", UITheme.POSSESSION_BORDER)
			value_label.text = "+" + str(card_data.possession_value) + " MID"
			bg_color = UITheme.POSSESSION_BG
			border_color = UITheme.POSSESSION_BORDER
		CardData.CardType.TACTICAL:
			type_label.text = "TACTICAL"
			type_label.add_theme_color_override("font_color", UITheme.GOLD)
			value_label.text = "+" + str(card_data.possession_value) + " ATK, -2 DEF"
			bg_color = Color(0.25, 0.2, 0.1)
			border_color = UITheme.GOLD
		CardData.CardType.EXHAUSTED:
			type_label.text = "EXHAUSTED"
			type_label.add_theme_color_override("font_color", UITheme.EXHAUSTED_BORDER)
			value_label.text = "Unplayable"
			bg_color = UITheme.EXHAUSTED_BG
			border_color = UITheme.EXHAUSTED_BORDER

	# Card panel style with gold outer border and type-colored fill
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = bg_color
	card_style.corner_radius_top_left = UITheme.CORNER_RADIUS
	card_style.corner_radius_top_right = UITheme.CORNER_RADIUS
	card_style.corner_radius_bottom_left = UITheme.CORNER_RADIUS
	card_style.corner_radius_bottom_right = UITheme.CORNER_RADIUS
	card_style.content_margin_left = 10
	card_style.content_margin_right = 10
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card_style.border_width_left = UITheme.CARD_BORDER_WIDTH
	card_style.border_width_right = UITheme.CARD_BORDER_WIDTH
	card_style.border_width_top = UITheme.CARD_BORDER_WIDTH
	card_style.border_width_bottom = UITheme.CARD_BORDER_WIDTH
	card_style.border_color = UITheme.GOLD
	add_theme_stylebox_override("panel", card_style)

	# Energy cost badge - circular blue badge
	if card_data.is_playable():
		cost_label.text = str(card_data.energy_cost)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_font_size_override("font_size", 16)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = UITheme.ENERGY_FILLED
		badge_style.corner_radius_top_left = 16
		badge_style.corner_radius_top_right = 16
		badge_style.corner_radius_bottom_left = 16
		badge_style.corner_radius_bottom_right = 16
		badge_style.content_margin_left = 4
		badge_style.content_margin_right = 4
		badge_style.content_margin_top = 2
		badge_style.content_margin_bottom = 2
		cost_badge.add_theme_stylebox_override("panel", badge_style)
		cost_badge.visible = true
	else:
		cost_badge.visible = false

func play_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 40, 0.15).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)

func _on_mouse_entered() -> void:
	if card_data and card_data.is_playable():
		if _hover_tween:
			_hover_tween.kill()
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", HOVER_SCALE, HOVER_DURATION).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE, HOVER_DURATION).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_data and card_data.is_playable():
			card_clicked.emit(card_index)
