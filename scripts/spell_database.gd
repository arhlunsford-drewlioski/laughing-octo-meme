class_name SpellDatabase
extends RefCounted
## All 10 spell card definitions and starter deck generation.

static func make_spell(p_name: String, p_desc: String, p_mana: int, p_target: SpellData.TargetType,
		p_modifiers: Dictionary = {}, p_special: String = "", p_duration: float = 0.0,
		p_post_injury: bool = false, p_rarity: SpellData.Rarity = SpellData.Rarity.COMMON,
		p_shop_cost: int = 40) -> SpellData:
	var s := SpellData.new()
	s.spell_name = p_name
	s.description = p_desc
	s.mana_cost = p_mana
	s.target_type = p_target
	s.stat_modifiers = p_modifiers
	s.special_effect = p_special
	s.duration = p_duration
	s.post_match_injury = p_post_injury
	s.rarity = p_rarity
	s.shop_cost = p_shop_cost
	return s

# ── The 10 Spell Cards ──────────────────────────────────────────────────────

static func fireball() -> SpellData:
	return make_spell("Fireball", "AoE blast - kills/injures goblins in radius (both teams!)",
		3, SpellData.TargetType.NONE, {}, "fireball", 0.0, false,
		SpellData.Rarity.UNCOMMON, 40)

static func haste() -> SpellData:
	return make_spell("Haste", "+3 speed to all your goblins for 15 seconds.",
		1, SpellData.TargetType.ALL_ALLIES, {"speed": 3}, "haste", 15.0, false,
		SpellData.Rarity.COMMON, 20)

static func dark_surge() -> SpellData:
	return make_spell("Dark Surge", "+3 shooting to one goblin for 15 seconds.",
		1, SpellData.TargetType.ALLY, {"shooting": 3}, "", 15.0, false,
		SpellData.Rarity.COMMON, 20)

static func shadow_wall() -> SpellData:
	return make_spell("Shadow Wall", "+3 defense to all your goblins for 10 seconds.",
		2, SpellData.TargetType.ALL_ALLIES, {"defense": 3}, "shadow_wall", 10.0, false,
		SpellData.Rarity.COMMON, 30)

static func hex() -> SpellData:
	return make_spell("Hex", "-2 all stats on one opponent for 30 seconds.",
		2, SpellData.TargetType.ENEMY,
		{"shooting": -2, "speed": -2, "defense": -2, "strength": -2, "health": -2, "chaos": -2},
		"hex", 30.0, false, SpellData.Rarity.UNCOMMON, 40)

static func blood_pact() -> SpellData:
	return make_spell("Blood Pact", "Double shooting for one goblin, but they take injury post-match.",
		3, SpellData.TargetType.ALLY, {"shooting": 5}, "blood_pact", 0.0, true,
		SpellData.Rarity.RARE, 50)

static func necromancy() -> SpellData:
	return make_spell("Necromancy", "Revive a dead goblin at half stats, this match only.",
		4, SpellData.TargetType.NONE, {}, "necromancy", 0.0, false,
		SpellData.Rarity.RARE, 60)

static func frenzy() -> SpellData:
	return make_spell("Frenzy", "All goblins +2 speed +2 shooting -3 defense for rest of match.",
		3, SpellData.TargetType.ALL_ALLIES,
		{"speed": 2, "shooting": 2, "defense": -3}, "frenzy", 0.0, false,
		SpellData.Rarity.UNCOMMON, 45)

static func multiball() -> SpellData:
	return make_spell("Multiball", "3 chaos balls on the pitch for 10 seconds.",
		2, SpellData.TargetType.NONE, {}, "multiball", 10.0, false,
		SpellData.Rarity.UNCOMMON, 35)

static func curse_of_the_post() -> SpellData:
	return make_spell("Curse of the Post", "Opponent's next shot auto-misses.",
		1, SpellData.TargetType.NONE, {}, "curse_of_post", 0.0, false,
		SpellData.Rarity.COMMON, 25)

# ── Deck Generation ─────────────────────────────────────────────────────────

static func all_spells() -> Array[SpellData]:
	return [fireball(), haste(), dark_surge(), shadow_wall(), hex(),
		blood_pact(), necromancy(), frenzy(), multiball(), curse_of_the_post()]

static func starter_deck() -> Array[SpellData]:
	## Starting spell deck: 5 basic spells.
	return [fireball(), haste(), dark_surge(), shadow_wall(), multiball()]

static func shop_pool() -> Array[SpellData]:
	## All spells available for purchase (excluding ones in starter deck by name).
	return [hex(), blood_pact(), necromancy(), frenzy(), curse_of_the_post(),
		# Duplicates of starter spells also available for purchase
		dark_surge(), shadow_wall(), haste()]
