extends HBoxContainer
## Displays the player's current hand of cards as a horizontal scrollable row.

signal card_selected(hand_index: int)

const CardUIScene := preload("res://scenes/ui/card_ui.tscn")

func refresh(hand: Array[CardData]) -> void:
	# Clear existing cards
	for child in get_children():
		child.queue_free()

	# Create a CardUI for each card in hand
	for i in hand.size():
		var card_ui: PanelContainer = CardUIScene.instantiate()
		add_child(card_ui)
		card_ui.setup(hand[i], i)
		card_ui.card_clicked.connect(_on_card_clicked)

func _on_card_clicked(hand_index: int) -> void:
	card_selected.emit(hand_index)
