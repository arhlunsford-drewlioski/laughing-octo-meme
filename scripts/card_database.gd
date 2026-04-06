class_name CardDatabase
extends RefCounted
## Card definitions. Starter decks and reward pool.

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

# -- Reward card pool --

static func reward_card_pool() -> Array[CardData]:
	## Slightly stronger cards offered as post-match rewards.
	return [
		make_card(
			"Tiki-Taka (But Goblins)", CardData.CardType.TEMPO, 2, 5, 0.0,
			"Short passes. Shorter attention spans. Somehow it works."),
		make_card(
			"The Nutmeg", CardData.CardType.CHANCE, 1, 0, 0.30,
			"Through the legs. Through the dignity."),
		make_card(
			"Wall of Green", CardData.CardType.TEMPO, 1, 3, 0.0,
			"A defensive shape that looks like a blob but functions like a fortress."),
		make_card(
			"Hoof and Hope", CardData.CardType.CHANCE, 2, 0, 0.45,
			"Boot it forward. Hope for the best. Surprisingly effective."),
		make_card(
			"Tactical Foul", CardData.CardType.TEMPO, 1, 4, 0.0,
			"It's only cheating if the ref sees it. The ref is also a goblin."),
		make_card(
			"Screamer from Distance", CardData.CardType.CHANCE, 2, 0, 0.35,
			"Launched from the halfway line with zero plan and maximum conviction."),
		make_card(
			"Counter-Attack Rush", CardData.CardType.TEMPO, 1, 4, 0.0,
			"They pushed up. We pushed back. Faster."),
		make_card(
			"Poacher's Instinct", CardData.CardType.CHANCE, 1, 0, 0.30,
			"Right place. Right time. Wrong goblin. Goal anyway.", true),
	]

# -- Tier 2: Unlocked at Round of 16 / Quarter Finals --

static func tier2_card_pool() -> Array[CardData]:
	return [
		make_card(
			"Gegenpressing Goblins", CardData.CardType.TEMPO, 2, 6, 0.0,
			"Win it back. Lose it again. Win it back harder."),
		make_card(
			"The Overlap Nobody Asked For", CardData.CardType.TEMPO, 1, 4, 0.0,
			"The fullback is in the box. Who's defending? Not our problem."),
		make_card(
			"False Nine (Actual Goblin)", CardData.CardType.TEMPO, 2, 5, 0.0,
			"He dropped deep. Then deeper. Then he was behind his own keeper."),
		make_card(
			"Controlled Fury", CardData.CardType.TEMPO, 1, 4, 0.0,
			"Disciplined rage. An oxymoron, but it works."),
		make_card(
			"Curler Into the Top Bin", CardData.CardType.CHANCE, 2, 0, 0.50,
			"Physics said no. The ball said maybe. The net said yes."),
		make_card(
			"One-Two Finish", CardData.CardType.CHANCE, 2, 0, 0.45,
			"Pass. Return. Shoot. Celebrate. Simple as that."),
		make_card(
			"Rabona (Why Not)", CardData.CardType.CHANCE, 1, 0, 0.35,
			"Completely unnecessary. Absolutely magnificent."),
		make_card(
			"Route One Thunderball", CardData.CardType.CHANCE, 2, 0, 0.40,
			"No buildup. No passing. Just violence toward the goal.", true),
	]

# -- Tier 3: Unlocked at Semi Finals / Final --

static func tier3_card_pool() -> Array[CardData]:
	return [
		make_card(
			"Total Football (Total Chaos)", CardData.CardType.TEMPO, 3, 8, 0.0,
			"Everyone plays everywhere. Nobody knows their position. Perfection."),
		make_card(
			"The Invincible Formation", CardData.CardType.TEMPO, 2, 6, 0.0,
			"Unbeaten in 47 matches. Untested against goblins. Until now."),
		make_card(
			"Tidal Press", CardData.CardType.TEMPO, 2, 7, 0.0,
			"They pushed up as one. The pitch shrank. The opponent panicked."),
		make_card(
			"Panenka Penalty", CardData.CardType.CHANCE, 2, 0, 0.55,
			"The audacity. The disrespect. The absolute scenes."),
		make_card(
			"Bicycle Kick Screamer", CardData.CardType.CHANCE, 3, 0, 0.60,
			"He went airborne. Time stopped. The crowd held its breath.", true),
		make_card(
			"Through Ball of Destiny", CardData.CardType.CHANCE, 2, 0, 0.50,
			"Threaded through seven defenders. The pass that changes everything."),
		make_card(
			"Last Minute Winner", CardData.CardType.CHANCE, 1, 0, 0.40,
			"Heartbreak and glory separated by a single goalpost."),
		make_card(
			"Goblin Galacticos", CardData.CardType.TEMPO, 2, 7, 0.0,
			"Every goblin cost a fortune. None of them pass to each other. Still winning."),
	]

static func get_random_rewards(count: int) -> Array[CardData]:
	## Returns count random cards from the reward pool.
	var pool := reward_card_pool()
	pool.shuffle()
	var result: Array[CardData] = []
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result
