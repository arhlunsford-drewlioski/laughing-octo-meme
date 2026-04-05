class_name CardDatabase
extends RefCounted
## MVP card definitions. Hardcoded starter decks for player and opponent.

static func make_card(p_name: String, p_type: CardData.CardType, p_cost: int, p_possession: int, p_conversion: float, p_flavor: String, p_exhausts: bool = false) -> CardData:
	var card := CardData.new()
	card.card_name = p_name
	card.card_type = p_type
	card.energy_cost = p_cost
	card.possession_value = p_possession
	card.base_conversion = p_conversion
	card.flavor_text = p_flavor
	card.adds_exhausted = p_exhausts
	return card

static func player_starter_deck() -> Array[CardData]:
	var cards: Array[CardData] = []

	# -- Tempo cards (8) --
	cards.append(make_card(
		"Incomprehensible Tactical Diagram", CardData.CardType.TEMPO, 1, 3, 0.0,
		"Nobody on the team understood it. They won anyway."))
	cards.append(make_card(
		"Run Directly At Them", CardData.CardType.TEMPO, 1, 2, 0.0,
		"Sometimes the simplest plans work. This is not one of those times."))
	cards.append(make_card(
		"Someone Told Gribbix To Pass", CardData.CardType.TEMPO, 1, 2, 0.0,
		"And he did. Everyone was shocked."))
	cards.append(make_card(
		"Organized Chaos", CardData.CardType.TEMPO, 2, 5, 0.0,
		"The formation looks wrong from every angle. It works from exactly one."))
	cards.append(make_card(
		"Sideline Shouting", CardData.CardType.TEMPO, 1, 2, 0.0,
		"The coach is making sounds. Some of them might be words."))
	cards.append(make_card(
		"Midfield Congestion", CardData.CardType.TEMPO, 1, 3, 0.0,
		"There are too many goblins in one place. This is somehow advantageous."))
	cards.append(make_card(
		"Quick Feet Slow Brain", CardData.CardType.TEMPO, 1, 2, 0.0,
		"Gribbix moved before he thought. His legs were right."))
	cards.append(make_card(
		"The Long Ball", CardData.CardType.TEMPO, 2, 4, 0.0,
		"Launched with optimism. Received with confusion."))

	# -- Chance cards (4) --
	cards.append(make_card(
		"Gribbix Runs Very Fast Directly At Goal", CardData.CardType.CHANCE, 2, 0, 0.35,
		"He doesn't know where the goal is. He'll find out."))
	cards.append(make_card(
		"The Plan Nobody Agreed To", CardData.CardType.CHANCE, 2, 0, 0.40,
		"It worked because nobody expected it. Including the team."))
	cards.append(make_card(
		"Accidental Brilliance", CardData.CardType.CHANCE, 1, 0, 0.25,
		"The ball went exactly where it wasn't supposed to. Goal."))
	cards.append(make_card(
		"Desperation Lob", CardData.CardType.CHANCE, 1, 0, 0.20,
		"A prayer in ball form."))

	return cards

static func opponent_starter_deck() -> Array[CardData]:
	var cards: Array[CardData] = []

	# Simpler deck for scripted opponent
	cards.append(make_card("Charge Forward", CardData.CardType.TEMPO, 1, 2, 0.0, "They're coming."))
	cards.append(make_card("Hold Position", CardData.CardType.TEMPO, 1, 2, 0.0, "They're staying."))
	cards.append(make_card("Push Up", CardData.CardType.TEMPO, 1, 3, 0.0, "They're pushing."))
	cards.append(make_card("Crowd The Box", CardData.CardType.TEMPO, 2, 4, 0.0, "Many goblins, small area."))
	cards.append(make_card("Simple Pass", CardData.CardType.TEMPO, 1, 2, 0.0, "Nothing fancy."))
	cards.append(make_card("Boot It", CardData.CardType.TEMPO, 1, 2, 0.0, "Boot it."))
	cards.append(make_card("Wing Play", CardData.CardType.TEMPO, 1, 3, 0.0, "Down the side."))
	cards.append(make_card("Snap Shot", CardData.CardType.CHANCE, 2, 0, 0.30, "Quick and hopeful."))
	cards.append(make_card("Header From Corner", CardData.CardType.CHANCE, 2, 0, 0.35, "Bonk."))
	cards.append(make_card("Lucky Bounce", CardData.CardType.CHANCE, 1, 0, 0.20, "Off the post. Off a shin. In."))

	return cards
