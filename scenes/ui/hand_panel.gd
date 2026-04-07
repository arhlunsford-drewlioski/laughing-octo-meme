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

func highlight_cards(indices: Array[int]) -> void:
	## Pulse-highlight cards at the given indices (for realtime mode response windows).
	for child in get_children():
		if child is PanelContainer and child.has_method("setup"):
			var idx: int = child.card_index if "card_index" in child else -1
			if idx in indices:
				var tween := child.create_tween().set_loops()
				tween.tween_property(child, "modulate", Color(1.3, 1.3, 0.8, 1.0), 0.3)
				tween.tween_property(child, "modulate", Color.WHITE, 0.3)
				child.set_meta("highlight_tween", tween)

func clear_highlights() -> void:
	## Stop all highlight tweens and reset modulate.
	for child in get_children():
		if child is PanelContainer and child.has_meta("highlight_tween"):
			var tween: Tween = child.get_meta("highlight_tween")
			if tween and tween.is_valid():
				tween.kill()
			child.remove_meta("highlight_tween")
			child.modulate = Color.WHITE

func _on_card_clicked(hand_index: int) -> void:
	card_selected.emit(hand_index)
