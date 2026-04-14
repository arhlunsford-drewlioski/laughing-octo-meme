class_name ItemDatabase
extends RefCounted
## Item definitions and shop generation for the equipment system.

static func make_item(p_name: String, p_desc: String, p_rarity: ItemData.Rarity, p_bonuses: Dictionary, p_special: String = "") -> ItemData:
	var item := ItemData.new()
	item.item_name = p_name
	item.description = p_desc
	item.rarity = p_rarity
	item.stat_bonuses = p_bonuses
	item.special_effect = p_special
	return item

# ── Item Pool ────────────────────────────────────────────────────────────────

static func _common_items() -> Array[ItemData]:
	return [
		make_item("Rusty Cleats", "Slightly faster. Slightly tetanus.", ItemData.Rarity.COMMON,
			{"speed": 1}),
		make_item("Padded Shinguards", "For goblins who like having shins.", ItemData.Rarity.COMMON,
			{"defense": 1}),
		make_item("Lucky Pebble", "Found it on the pitch. Must be lucky.", ItemData.Rarity.COMMON,
			{"chaos": 1}),
		make_item("Wrist Tape", "Grip improved. Attitude unchanged.", ItemData.Rarity.COMMON,
			{"shooting": 1}),
		make_item("Thick Headband", "Absorbs sweat and minor head injuries.", ItemData.Rarity.COMMON,
			{"health": 1}),
		make_item("Iron Wristguard", "Punches harder in 'fair' challenges.", ItemData.Rarity.COMMON,
			{"strength": 1}),
		make_item("Tattered Scarf", "Worn by a goblin who survived three tournaments.", ItemData.Rarity.COMMON,
			{"health": 1, "defense": 1}, "injury_resist"),
		make_item("Mud-Caked Boots", "Heavy but grippy. Good for tackles.", ItemData.Rarity.COMMON,
			{"defense": 1, "strength": 1}),
	]

static func _uncommon_items() -> Array[ItemData]:
	return [
		make_item("Spiked Boots", "Faster and angrier.", ItemData.Rarity.UNCOMMON,
			{"speed": 2}),
		make_item("Enchanted Gloves", "The ball sticks. So does everything else.", ItemData.Rarity.UNCOMMON,
			{"shooting": 1, "chaos": 1}),
		make_item("Bone Plating", "Harvested from a previous opponent.", ItemData.Rarity.UNCOMMON,
			{"defense": 1, "health": 1}),
		make_item("Goblin Brew Flask", "One sip and nothing hurts. For a while.", ItemData.Rarity.UNCOMMON,
			{"strength": 2}),
		make_item("Featherweight Tunic", "Light as air. Durable as wet paper.", ItemData.Rarity.UNCOMMON,
			{"speed": 1, "shooting": 1}),
		make_item("Warpaint of Fury", "Looks terrifying. Smells worse.", ItemData.Rarity.UNCOMMON,
			{"chaos": 1, "strength": 1}),
		make_item("Reinforced Kneepads", "For the goblin who slides into everything.", ItemData.Rarity.UNCOMMON,
			{"defense": 2}),
		make_item("Seer's Monocle", "Sees openings others miss.", ItemData.Rarity.UNCOMMON,
			{"shooting": 2}),
	]

static func _rare_items() -> Array[ItemData]:
	return [
		make_item("Berserker Helm", "Stops thinking. Starts destroying.", ItemData.Rarity.RARE,
			{"strength": 2, "chaos": 2, "defense": -1}),
		make_item("Phantom Boots", "The pitch doesn't touch them. They don't touch the pitch.", ItemData.Rarity.RARE,
			{"speed": 3}),
		make_item("Dark Iron Vest", "Forged in a volcano. Probably.", ItemData.Rarity.RARE,
			{"defense": 2, "health": 2}),
		make_item("Crown of the Goblin King", "Grants authority. And delusions.", ItemData.Rarity.RARE,
			{"shooting": 2, "speed": 1, "chaos": 1}),
		make_item("Blood Amulet", "Heals what it hurts. Hurts what it heals.", ItemData.Rarity.RARE,
			{"health": 3}),
		make_item("Chaos Orb", "Nobody knows what it does. That's the point.", ItemData.Rarity.RARE,
			{"chaos": 3}),
		make_item("Titan Gauntlets", "For goblins who think strength is a personality.", ItemData.Rarity.RARE,
			{"strength": 2, "shooting": 1}),
		make_item("Windrunner Cape", "Built for speed. Everything else is optional.", ItemData.Rarity.RARE,
			{"speed": 2, "shooting": 1}),
	]

static func generate_shop_items(count: int = 3) -> Array[ItemData]:
	## Generate random items for the shop. Weighted toward common.
	var pool: Array[ItemData] = []
	var items: Array[ItemData] = []

	for i in count:
		var roll := randf()
		var rarity_pool: Array[ItemData]
		if roll < 0.55:
			rarity_pool = _common_items()
		elif roll < 0.85:
			rarity_pool = _uncommon_items()
		else:
			rarity_pool = _rare_items()

		# Pick one not already chosen
		rarity_pool.shuffle()
		var picked := false
		for item in rarity_pool:
			var dupe := false
			for existing in items:
				if existing.item_name == item.item_name:
					dupe = true
					break
			if not dupe:
				items.append(item)
				picked = true
				break
		if not picked and rarity_pool.size() > 0:
			items.append(rarity_pool[0])

	return items
