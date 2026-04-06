class_name BuffCardDatabase
extends RefCounted
## Buff card definitions for autobattler mode.

static func _make(p_name: String, p_type: CardData.CardType, p_cost: int, p_value: int, p_flavor: String) -> CardData:
	var card := CardData.new()
	card.card_name = p_name
	card.card_type = p_type
	card.energy_cost = p_cost
	# Store buff amount in possession_value for ATK/MID, defense_value for DEF
	match p_type:
		CardData.CardType.ATK_BUFF, CardData.CardType.MID_BUFF, CardData.CardType.TACTICAL:
			card.possession_value = p_value
		CardData.CardType.DEF_BUFF:
			card.defense_value = p_value
	card.flavor_text = p_flavor
	return card

static func starter_deck() -> Array[CardData]:
	var cards: Array[CardData] = []

	# ATK buffs (3)
	cards.append(_make("Sharpen the Attack", CardData.CardType.ATK_BUFF, 1, 2,
		"Pointy boots. Pointier elbows."))
	cards.append(_make("Forward Rush", CardData.CardType.ATK_BUFF, 2, 3,
		"Everyone up! Including the keeper. Wait, not the keeper."))
	cards.append(_make("Target Man", CardData.CardType.ATK_BUFF, 1, 2,
		"Aim at the big goblin. He'll head it somewhere."))

	# DEF buffs (3)
	cards.append(_make("Tighten the Line", CardData.CardType.DEF_BUFF, 1, 2,
		"Stand closer. No, closer. TOO CLOSE."))
	cards.append(_make("Park the Bus", CardData.CardType.DEF_BUFF, 2, 3,
		"An actual bus. On the pitch. The ref allows it."))
	cards.append(_make("Offside Trap", CardData.CardType.DEF_BUFF, 1, 2,
		"Step up together. Pray they time it wrong."))

	# MID buffs (3)
	cards.append(_make("Control the Tempo", CardData.CardType.MID_BUFF, 1, 2,
		"Slow it down. Speed it up. Nobody knows which."))
	cards.append(_make("Press High", CardData.CardType.MID_BUFF, 1, 2,
		"Chase everything. Catch nothing. Win anyway."))
	cards.append(_make("Midfield Engine", CardData.CardType.MID_BUFF, 2, 3,
		"One goblin does the running of three. Collapses at halftime."))

	# Tactical (1)
	cards.append(_make("All Out Attack", CardData.CardType.TACTICAL, 1, 3,
		"Throw everyone forward. Hope for the best. +3 ATK, -2 DEF."))

	return cards

static func opponent_starter_deck() -> Array[CardData]:
	var cards: Array[CardData] = []

	cards.append(_make("Charge!", CardData.CardType.ATK_BUFF, 1, 2, "Forward."))
	cards.append(_make("Big Push", CardData.CardType.ATK_BUFF, 2, 3, "Bigger forward."))
	cards.append(_make("Lump It", CardData.CardType.ATK_BUFF, 1, 2, "Just kick it."))

	cards.append(_make("Hold Firm", CardData.CardType.DEF_BUFF, 1, 2, "Don't move."))
	cards.append(_make("Bunker Down", CardData.CardType.DEF_BUFF, 2, 3, "Really don't move."))
	cards.append(_make("Clear It", CardData.CardType.DEF_BUFF, 1, 2, "Away. Just away."))

	cards.append(_make("Win the Ball", CardData.CardType.MID_BUFF, 1, 2, "Get it."))
	cards.append(_make("Keep Possession", CardData.CardType.MID_BUFF, 1, 2, "Keep it."))
	cards.append(_make("Dominate", CardData.CardType.MID_BUFF, 2, 3, "Own it."))

	cards.append(_make("Route One", CardData.CardType.TACTICAL, 1, 3, "+3 ATK, -2 DEF."))

	return cards
