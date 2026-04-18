class_name SpellDatabase
extends RefCounted
## All spell card definitions and starter deck generation.
## Spells are buff/debuff only - no AoE damage or chaos effects.

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

# ── Spell Cards (15 total, buff/debuff only) ──────────────────────────────

# --- 1 Mana (cheap utility) ---

static func haste() -> SpellData:
	return make_spell("Haste", "+3 speed to all your goblins for 15 seconds.",
		1, SpellData.TargetType.ALL_ALLIES, {"speed": 3}, "haste", 15.0, false,
		SpellData.Rarity.COMMON, 20)

static func dark_surge() -> SpellData:
	return make_spell("Dark Surge", "+3 shooting to one goblin for 15 seconds.",
		1, SpellData.TargetType.ALLY, {"shooting": 3}, "", 15.0, false,
		SpellData.Rarity.COMMON, 20)

static func curse_of_the_post() -> SpellData:
	return make_spell("Curse of the Post", "Opponent's next shot auto-misses.",
		1, SpellData.TargetType.NONE, {}, "curse_of_post", 0.0, false,
		SpellData.Rarity.COMMON, 25)

static func iron_skin() -> SpellData:
	return make_spell("Iron Skin", "+4 health to one goblin for 20 seconds. Protects from injuries.",
		1, SpellData.TargetType.ALLY, {"health": 4}, "", 20.0, false,
		SpellData.Rarity.COMMON, 20)

static func hobble() -> SpellData:
	return make_spell("Hobble", "-4 speed to one opponent for 20 seconds.",
		1, SpellData.TargetType.ENEMY, {"speed": -4}, "", 20.0, false,
		SpellData.Rarity.COMMON, 25)

static func tunnel_vision() -> SpellData:
	return make_spell("Tunnel Vision", "+4 shooting but -2 speed to one goblin for 10 seconds.",
		1, SpellData.TargetType.ALLY, {"shooting": 4, "speed": -2}, "", 10.0, false,
		SpellData.Rarity.UNCOMMON, 30)

# --- 2 Mana (mid-range) ---

static func shadow_wall() -> SpellData:
	return make_spell("Shadow Wall", "+3 defense to all your goblins for 10 seconds.",
		2, SpellData.TargetType.ALL_ALLIES, {"defense": 3}, "shadow_wall", 10.0, false,
		SpellData.Rarity.COMMON, 30)

static func hex() -> SpellData:
	return make_spell("Hex", "-2 all stats on one opponent for 30 seconds.",
		2, SpellData.TargetType.ENEMY,
		{"shooting": -2, "speed": -2, "defense": -2, "strength": -2, "health": -2, "chaos": -2},
		"hex", 30.0, false, SpellData.Rarity.UNCOMMON, 40)

static func war_cry() -> SpellData:
	return make_spell("War Cry", "+2 strength to all your goblins for 15 seconds.",
		2, SpellData.TargetType.ALL_ALLIES, {"strength": 2}, "", 15.0, false,
		SpellData.Rarity.COMMON, 30)

static func goblin_rage() -> SpellData:
	return make_spell("Goblin Rage", "+3 strength +3 chaos -2 defense to one goblin for 15 seconds.",
		2, SpellData.TargetType.ALLY, {"strength": 3, "chaos": 3, "defense": -2}, "", 15.0, false,
		SpellData.Rarity.UNCOMMON, 35)

static func second_wind() -> SpellData:
	return make_spell("Second Wind", "+2 speed +2 defense to one tired goblin for rest of match.",
		2, SpellData.TargetType.ALLY, {"speed": 2, "defense": 2}, "", 0.0, false,
		SpellData.Rarity.UNCOMMON, 35)

# --- 3 Mana (power spells) ---

static func blood_pact() -> SpellData:
	return make_spell("Blood Pact", "Double shooting for one goblin, but they take injury post-match.",
		3, SpellData.TargetType.ALLY, {"shooting": 5}, "blood_pact", 0.0, true,
		SpellData.Rarity.RARE, 50)

static func frenzy() -> SpellData:
	return make_spell("Frenzy", "All goblins +2 speed +2 shooting -3 defense for rest of match.",
		3, SpellData.TargetType.ALL_ALLIES,
		{"speed": 2, "shooting": 2, "defense": -3}, "frenzy", 0.0, false,
		SpellData.Rarity.UNCOMMON, 45)

static func fog_of_war() -> SpellData:
	return make_spell("Fog of War", "-3 speed to all opponents for 10 seconds.",
		3, SpellData.TargetType.ALL_ENEMIES, {"speed": -3}, "", 10.0, false,
		SpellData.Rarity.RARE, 50)

static func adrenaline() -> SpellData:
	return make_spell("Adrenaline", "+3 speed +3 shooting to one goblin for 10 seconds.",
		3, SpellData.TargetType.ALLY, {"speed": 3, "shooting": 3}, "", 10.0, false,
		SpellData.Rarity.RARE, 50)

# --- 4 Mana (legendary) ---

static func dark_ascension() -> SpellData:
	return make_spell("Dark Ascension", "+3 ALL stats for rest of match. Goblin dies after the game.",
		4, SpellData.TargetType.ALLY,
		{"shooting": 3, "speed": 3, "defense": 3, "strength": 3, "health": 3, "chaos": 3},
		"dark_ascension", 0.0, false, SpellData.Rarity.LEGENDARY, 60, true)

# ── Deck Generation ─────────────────────────────────────────────────────────

static func all_spells() -> Array[SpellData]:
	return [haste(), dark_surge(), curse_of_the_post(), iron_skin(), hobble(), tunnel_vision(),
		shadow_wall(), hex(), war_cry(), goblin_rage(), second_wind(),
		blood_pact(), frenzy(), fog_of_war(), adrenaline(), dark_ascension()]

static func starter_deck() -> Array[SpellData]:
	## Starting spell deck: 4 basic spells.
	return [haste(), dark_surge(), shadow_wall(), curse_of_the_post()]

static func shop_pool() -> Array[SpellData]:
	## All spells available for purchase (including duplicates of starters).
	return [iron_skin(), hobble(), tunnel_vision(),
		hex(), war_cry(), goblin_rage(), second_wind(),
		blood_pact(), frenzy(), fog_of_war(), adrenaline(),
		dark_ascension(),
		# Duplicates of starters
		haste(), dark_surge(), shadow_wall(), curse_of_the_post()]
