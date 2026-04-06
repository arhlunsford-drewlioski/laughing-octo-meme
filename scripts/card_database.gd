class_name CardDatabase
extends RefCounted
## Card definitions. Starter decks and reward pools. TPD: Tempo/Possession/Defense.

static func make_tempo(p_name: String, p_cost: int, p_conversion: float, p_flavor: String, p_exhausts: bool = false) -> CardData:
	var card := CardData.new()
	card.card_name = p_name
	card.card_type = CardData.CardType.TEMPO
	card.energy_cost = p_cost
	card.base_conversion = p_conversion
	card.flavor_text = p_flavor
	card.adds_exhausted = p_exhausts
	return card

static func make_possession(p_name: String, p_cost: int, p_value: int, p_flavor: String, p_exhausts: bool = false) -> CardData:
	var card := CardData.new()
	card.card_name = p_name
	card.card_type = CardData.CardType.POSSESSION
	card.energy_cost = p_cost
	card.possession_value = p_value
	card.flavor_text = p_flavor
	card.adds_exhausted = p_exhausts
	return card

static func make_defense(p_name: String, p_cost: int, p_value: int, p_flavor: String, p_exhausts: bool = false) -> CardData:
	var card := CardData.new()
	card.card_name = p_name
	card.card_type = CardData.CardType.DEFENSE
	card.energy_cost = p_cost
	card.defense_value = p_value
	card.flavor_text = p_flavor
	card.adds_exhausted = p_exhausts
	return card

static func player_starter_deck() -> Array[CardData]:
	var cards: Array[CardData] = []

	# -- Tempo cards (3) - goal attempts --
	cards.append(make_tempo(
		"Gribbix Runs At Goal", 2, 0.30,
		"He doesn't know where the goal is. He'll find out."))
	cards.append(make_tempo(
		"Accidental Brilliance", 1, 0.20,
		"The ball went exactly where it wasn't supposed to. Goal."))
	cards.append(make_tempo(
		"Desperation Lob", 1, 0.20,
		"A prayer in ball form."))

	# -- Possession cards (4) - field control --
	cards.append(make_possession(
		"Incomprehensible Tactical Diagram", 1, 3,
		"Nobody on the team understood it. They won anyway."))
	cards.append(make_possession(
		"Midfield Congestion", 1, 3,
		"There are too many goblins in one place. This is somehow advantageous."))
	cards.append(make_possession(
		"Quick Feet Slow Brain", 1, 2,
		"Gribbix moved before he thought. His legs were right."))
	cards.append(make_possession(
		"Someone Told Gribbix To Pass", 1, 2,
		"And he did. Everyone was shocked."))

	# -- Defense cards (3) - blocks --
	cards.append(make_defense(
		"Wall of Green", 1, 3,
		"A defensive shape that looks like a blob but functions like a fortress."))
	cards.append(make_defense(
		"Sideline Shouting", 1, 2,
		"The coach is making sounds. Some of them might be words."))
	cards.append(make_defense(
		"Run Directly At Them", 1, 2,
		"Sometimes the simplest plans work. This is not one of those times."))

	return cards

static func opponent_starter_deck() -> Array[CardData]:
	var cards: Array[CardData] = []

	# Tempo (3)
	cards.append(make_tempo("Snap Shot", 2, 0.30, "Quick and hopeful."))
	cards.append(make_tempo("Header From Corner", 1, 0.20, "Bonk."))
	cards.append(make_tempo("Lucky Bounce", 1, 0.20, "Off the post. Off a shin. In."))

	# Possession (4)
	cards.append(make_possession("Push Up", 1, 3, "They're pushing."))
	cards.append(make_possession("Charge Forward", 1, 2, "They're coming."))
	cards.append(make_possession("Wing Play", 1, 3, "Down the side."))
	cards.append(make_possession("Simple Pass", 1, 2, "Nothing fancy."))

	# Defense (3)
	cards.append(make_defense("Hold Position", 1, 3, "They're staying."))
	cards.append(make_defense("Crowd The Box", 1, 2, "Many goblins, small area."))
	cards.append(make_defense("Boot It", 1, 2, "Boot it."))

	return cards

# -- Reward card pool (Tier 1) --

static func reward_card_pool() -> Array[CardData]:
	return [
		make_tempo(
			"Screamer from Distance", 2, 0.35,
			"Launched from the halfway line with zero plan and maximum conviction."),
		make_tempo(
			"The Plan Nobody Agreed To", 2, 0.35,
			"It worked because nobody expected it. Including the team."),
		make_possession(
			"Tiki-Taka (But Goblins)", 2, 5,
			"Short passes. Shorter attention spans. Somehow it works."),
		make_possession(
			"Counter-Attack Rush", 1, 4,
			"They pushed up. We pushed back. Faster."),
		make_possession(
			"Tactical Foul", 1, 3,
			"It's only cheating if the ref sees it. The ref is also a goblin."),
		make_defense(
			"Iron Curtain", 1, 4,
			"Nothing gets through. Not the ball. Not hope."),
		make_defense(
			"The Nutmeg Block", 1, 3,
			"Through the legs? Not today."),
		make_defense(
			"Organized Retreat", 2, 5,
			"Fall back! Fall back beautifully!"),
	]

# -- Tier 2: Unlocked at Round of 16 / Quarter Finals --

static func tier2_card_pool() -> Array[CardData]:
	return [
		make_tempo(
			"Curler Into the Top Bin", 2, 0.45,
			"Physics said no. The ball said maybe. The net said yes."),
		make_tempo(
			"One-Two Finish", 2, 0.40,
			"Pass. Return. Shoot. Celebrate. Simple as that."),
		make_tempo(
			"Rabona (Why Not)", 1, 0.30,
			"Completely unnecessary. Absolutely magnificent."),
		make_possession(
			"Gegenpressing Goblins", 2, 6,
			"Win it back. Lose it again. Win it back harder."),
		make_possession(
			"False Nine (Actual Goblin)", 2, 5,
			"He dropped deep. Then deeper. Then behind his own keeper."),
		make_possession(
			"The Overlap Nobody Asked For", 1, 4,
			"The fullback is in the box. Who's defending? Not our problem."),
		make_defense(
			"Controlled Fury", 1, 4,
			"Disciplined rage. An oxymoron, but it works."),
		make_defense(
			"Sweeper Keeper Madness", 2, 6,
			"The keeper is at the halfway line. This is fine.", true),
	]

# -- Tier 3: Unlocked at Semi Finals / Final --

static func tier3_card_pool() -> Array[CardData]:
	return [
		make_tempo(
			"Bicycle Kick Screamer", 3, 0.55,
			"He went airborne. Time stopped. The crowd held its breath.", true),
		make_tempo(
			"Panenka Penalty", 2, 0.50,
			"The audacity. The disrespect. The absolute scenes."),
		make_tempo(
			"Through Ball of Destiny", 2, 0.45,
			"Threaded through seven defenders. The pass that changes everything."),
		make_possession(
			"Total Football (Total Chaos)", 3, 8,
			"Everyone plays everywhere. Nobody knows their position. Perfection."),
		make_possession(
			"Tidal Press", 2, 7,
			"They pushed up as one. The pitch shrank. The opponent panicked."),
		make_defense(
			"The Invincible Formation", 2, 7,
			"Unbeaten in 47 matches. Untested against goblins. Until now."),
		make_defense(
			"Last Minute Block", 1, 4,
			"Heartbreak denied. The defender gave everything."),
		make_possession(
			"Goblin Galacticos", 2, 7,
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
