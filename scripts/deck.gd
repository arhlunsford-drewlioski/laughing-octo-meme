class_name Deck
extends RefCounted
## Manages draw pile, hand, and discard pile for one side.

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []

func initialize(cards: Array[CardData]) -> void:
	draw_pile = cards.duplicate()
	hand.clear()
	discard_pile.clear()
	shuffle_draw()

func shuffle_draw() -> void:
	draw_pile.shuffle()

func draw_cards(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			_reshuffle_discard()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())

func play_card(hand_index: int) -> CardData:
	if hand_index < 0 or hand_index >= hand.size():
		return null
	var card := hand[hand_index]
	hand.remove_at(hand_index)
	discard_pile.append(card)
	return card

func return_to_hand(card: CardData) -> void:
	## Used when a card play is reverted (e.g. not enough energy).
	if discard_pile.has(card):
		discard_pile.erase(card)
	hand.append(card)

func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()

func add_exhausted_card() -> void:
	var exhausted := CardData.new()
	exhausted.card_name = "Exhausted"
	exhausted.card_type = CardData.CardType.EXHAUSTED
	exhausted.energy_cost = 0
	exhausted.flavor_text = "Gribbix needs a minute."
	discard_pile.append(exhausted)

func _reshuffle_discard() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle_draw()
