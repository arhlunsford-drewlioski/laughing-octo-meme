class_name AIOpponent
extends RefCounted
## Scripted opponent for MVP. Plays cards from hand each round with simple logic.

var deck: Deck

func _init(opponent_deck: Deck) -> void:
	deck = opponent_deck

func play_round(engine: MatchEngine, energy_budget: int) -> Array[CardData]:
	## AI plays cards from hand up to energy budget. Returns cards played.
	var played: Array[CardData] = []
	var remaining_energy := energy_budget

	# Simple strategy: play highest-value playable cards first
	# Sort hand by value descending (Tempo by possession, Chance by conversion)
	var hand_copy := deck.hand.duplicate()
	hand_copy.sort_custom(_compare_card_value)

	for card in hand_copy:
		if remaining_energy <= 0:
			break
		if not card.is_playable():
			continue
		if card.energy_cost > remaining_energy:
			continue

		# Find the card's current index in the actual hand
		var idx := deck.hand.find(card)
		if idx == -1:
			continue

		var played_card := deck.play_card(idx)
		if played_card == null:
			continue

		remaining_energy -= played_card.energy_cost

		match played_card.card_type:
			CardData.CardType.TEMPO:
				engine.apply_tempo(played_card, false)
			CardData.CardType.CHANCE:
				engine.queue_chance(played_card, false)

		played.append(played_card)

	return played

func _compare_card_value(a: CardData, b: CardData) -> bool:
	return _card_value(a) > _card_value(b)

func _card_value(card: CardData) -> float:
	match card.card_type:
		CardData.CardType.TEMPO:
			return card.possession_value as float
		CardData.CardType.CHANCE:
			return card.base_conversion * 10.0
		_:
			return -1.0
