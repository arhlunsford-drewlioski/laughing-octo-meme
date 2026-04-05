extends PanelContainer
## Visual representation of a single card. Colored rectangle + text labels.

signal card_clicked(card_index: int)

const TEMPO_COLOR := Color(0.2, 0.5, 0.2)    # Green
const CHANCE_COLOR := Color(0.6, 0.2, 0.6)   # Purple
const EXHAUSTED_COLOR := Color(0.25, 0.25, 0.25)  # Dark gray
const HOVER_BRIGHTEN := 0.15

var card_data: CardData
var card_index: int = -1

@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var cost_label: Label = %CostLabel
@onready var value_label: Label = %ValueLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var bg: ColorRect = %Background

func setup(data: CardData, index: int) -> void:
	card_data = data
	card_index = index
	_update_display()

func _update_display() -> void:
	if card_data == null:
		return

	name_label.text = card_data.card_name
	cost_label.text = "E:" + str(card_data.energy_cost) if card_data.is_playable() else ""

	match card_data.card_type:
		CardData.CardType.TEMPO:
			type_label.text = "TEMPO"
			value_label.text = "+" + str(card_data.possession_value) + " Possession"
			bg.color = TEMPO_COLOR
		CardData.CardType.CHANCE:
			type_label.text = "CHANCE"
			value_label.text = str(roundi(card_data.base_conversion * 100)) + "% Base"
			bg.color = CHANCE_COLOR
		CardData.CardType.EXHAUSTED:
			type_label.text = "EXHAUSTED"
			value_label.text = "Unplayable"
			bg.color = EXHAUSTED_COLOR

	flavor_label.text = card_data.flavor_text

func play_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.15).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_data and card_data.is_playable():
			card_clicked.emit(card_index)
