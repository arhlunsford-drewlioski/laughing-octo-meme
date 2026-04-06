class_name AIOpponent
extends RefCounted
## Scripted opponent. Plans cards face-up, then executes them.

var deck: Deck
var planned_cards: Array[CardData] = []

func _init(opponent_deck: Deck) -> void:
	deck = opponent_deck

func plan_round(energy_budget: int) -> Array[CardData]:
	## AI decides which cards to play (returned for face-up display).
	## Does NOT apply them to the engine yet.
	planned_cards.clear()
	var remaining_energy: int = energy_budget

	# Sort hand by value descending
	var hand_copy := deck.hand.duplicate()
	hand_copy.sort_custom(_compare_card_value)

	for card in hand_copy:
		if remaining_energy <= 0:
			break
		if not card.is_playable():
			continue
		if card.energy_cost > remaining_energy:
			continue
		remaining_energy -= card.energy_cost
		planned_cards.append(card)

	return planned_cards

func execute_plan(engine: MatchEngine) -> Array[CardData]:
	## Apply the planned cards to the engine. Returns cards played.
	var played: Array[CardData] = []

	for card in planned_cards:
		var idx: int = deck.hand.find(card)
		if idx == -1:
			continue
		var played_card := deck.play_card(idx)
		if played_card == null:
			continue

		match played_card.card_type:
			CardData.CardType.POSSESSION:
				engine.apply_possession(played_card, false)
			CardData.CardType.DEFENSE:
				engine.apply_defense(played_card, false)
			CardData.CardType.TEMPO:
				engine.queue_tempo(played_card, false)

		played.append(played_card)

	planned_cards.clear()
	return played

func _compare_card_value(a: CardData, b: CardData) -> bool:
	return _card_value(a) > _card_value(b)

func _card_value(card: CardData) -> float:
	match card.card_type:
		CardData.CardType.TEMPO:
			return card.base_conversion * 12.0
		CardData.CardType.POSSESSION:
			return card.possession_value as float
		CardData.CardType.DEFENSE:
			return card.defense_value * 0.8
		_:
			return -1.0
