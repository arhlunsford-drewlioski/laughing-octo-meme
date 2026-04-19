class_name SpellDatabase
extends RefCounted
## Sorcerer Duel spell definitions.
## The core loop is visible spell pressure on the pitch, not hidden stat math.

static func make_spell(p_name: String, p_desc: String, p_mana: int, p_target: SpellData.TargetType,
		p_modifiers: Dictionary = {}, p_special: String = "", p_duration: float = 0.0,
		p_post_injury: bool = false, p_rarity: SpellData.Rarity = SpellData.Rarity.COMMON,
		p_shop_cost: int = 40, p_post_death: bool = false) -> SpellData:
	var s := SpellData.new()
	s.spell_name = p_name
	s.description = p_desc
	s.mana_cost = p_mana
	s.target_type = p_target
	s.stat_modifiers = p_modifiers
	s.special_effect = p_special
	s.duration = p_duration
	s.post_match_injury = p_post_injury
	s.post_match_death = p_post_death
	s.rarity = p_rarity
	s.shop_cost = p_shop_cost
	return s

static func fireball() -> SpellData:
	return make_spell("Fireball", "Lob an explosive fireball onto the pitch. Big AoE. Hits both teams.",
		2, SpellData.TargetType.NONE, {}, "fireball", 0.0, false,
		SpellData.Rarity.UNCOMMON, 35)

static func chain_lightning() -> SpellData:
	return make_spell("Chain Lightning", "Blast an enemy and bounce through nearby goblins.",
		3, SpellData.TargetType.ENEMY, {}, "chain_lightning", 0.0, false,
		SpellData.Rarity.RARE, 50)

static func shield_dome() -> SpellData:
	return make_spell("Shield Dome", "Create a protective dome. Goblins inside ignore damage.",
		2, SpellData.TargetType.NONE, {}, "shield_dome", 18.0, false,
		SpellData.Rarity.UNCOMMON, 40)

static func healing_wave() -> SpellData:
	return make_spell("Healing Wave", "A healing surge that jumps between nearby allied goblins.",
		2, SpellData.TargetType.ALLY, {}, "healing_wave", 0.0, false,
		SpellData.Rarity.UNCOMMON, 40)

static func haste() -> SpellData:
	return make_spell("Haste", "+3 speed to all your goblins for 15 seconds.",
		1, SpellData.TargetType.ALL_ALLIES, {"speed": 3}, "haste", 15.0, false,
		SpellData.Rarity.COMMON, 25)

static func dark_surge() -> SpellData:
	return make_spell("Dark Surge", "+3 shooting to one goblin for 15 seconds.",
		1, SpellData.TargetType.ALLY, {"shooting": 3}, "dark_surge", 15.0, false,
		SpellData.Rarity.COMMON, 25)

static func hex() -> SpellData:
	return make_spell("Hex", "-2 all stats on one enemy for 20 seconds.",
		2, SpellData.TargetType.ENEMY,
		{"shooting": -2, "speed": -2, "defense": -2, "strength": -2, "health": -2, "chaos": -2},
		"hex", 20.0, false, SpellData.Rarity.UNCOMMON, 40)

static func all_spells() -> Array[SpellData]:
	return [
		fireball(),
		chain_lightning(),
		shield_dome(),
		healing_wave(),
		haste(),
		dark_surge(),
		hex(),
	]

static func starter_deck() -> Array[SpellData]:
	## The player starts with immediate answers plus one aggressive finisher.
	return [fireball(), shield_dome(), healing_wave(), haste(), dark_surge()]

static func shop_pool() -> Array[SpellData]:
	return [
		chain_lightning(),
		hex(),
		fireball(),
		shield_dome(),
		healing_wave(),
		haste(),
		dark_surge(),
	]
