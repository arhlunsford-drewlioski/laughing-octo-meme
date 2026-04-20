class_name SpellDatabase
extends RefCounted
## All 20 spell cards for the sorcerer duel.
## Every spell is DRAMATIC - you should feel it when it happens.

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

# ── OFFENSIVE (kill/damage) ─────────────────────────────────────────────────

static func fireball() -> SpellData:
	return make_spell("Fireball", "AoE blast - kills/injures goblins in radius. BOTH TEAMS. Wobble aim.",
		2, SpellData.TargetType.NONE, {}, "fireball", 0.0, false,
		SpellData.Rarity.COMMON, 30)

static func lightning_bolt() -> SpellData:
	return make_spell("Lightning Bolt", "Single target, instant kill. Small wobble.",
		3, SpellData.TargetType.NONE, {}, "lightning_bolt", 0.0, false,
		SpellData.Rarity.UNCOMMON, 45)

static func chain_lightning() -> SpellData:
	return make_spell("Chain Lightning", "Arcs through nearby goblins. Damages multiple.",
		3, SpellData.TargetType.NONE, {}, "chain_lightning", 0.0, false,
		SpellData.Rarity.UNCOMMON, 45)

static func meteor() -> SpellData:
	return make_spell("Meteor", "Massive AoE, kills anything in a huge radius. BIG wobble.",
		4, SpellData.TargetType.NONE, {}, "meteor", 0.0, false,
		SpellData.Rarity.RARE, 55)

static func earthquake() -> SpellData:
	return make_spell("Earthquake", "Everyone stumbles, ball goes loose. Total chaos.",
		2, SpellData.TargetType.NONE, {}, "earthquake", 0.0, false,
		SpellData.Rarity.UNCOMMON, 35)

static func rot_curse() -> SpellData:
	return make_spell("Rot Curse", "Target slowly decays. Dies in 20s unless healed.",
		2, SpellData.TargetType.ENEMY, {}, "rot_curse", 20.0, false,
		SpellData.Rarity.UNCOMMON, 40)

# ── DEFENSIVE (protect/heal) ────────────────────────────────────────────────

static func shield_dome() -> SpellData:
	return make_spell("Shield Dome", "One goblin invincible for 20 seconds.",
		2, SpellData.TargetType.ALLY, {}, "shield_dome", 20.0, false,
		SpellData.Rarity.COMMON, 30)

static func heal() -> SpellData:
	return make_spell("Heal", "Cure one goblin's injury instantly.",
		1, SpellData.TargetType.ALLY, {}, "heal", 0.0, false,
		SpellData.Rarity.COMMON, 20)

static func healing_wave() -> SpellData:
	return make_spell("Healing Wave", "Restores goblins in an area. Gives temp defense buff.",
		2, SpellData.TargetType.NONE, {}, "healing_wave", 0.0, false,
		SpellData.Rarity.UNCOMMON, 35)

static func resurrect() -> SpellData:
	return make_spell("Resurrect", "Revive a dead goblin at half stats. This match only.",
		4, SpellData.TargetType.NONE, {}, "resurrect", 0.0, false,
		SpellData.Rarity.RARE, 55)

static func counter_spell() -> SpellData:
	return make_spell("Counter Spell", "Cancel the opponent sorcerer's current cast.",
		1, SpellData.TargetType.NONE, {}, "counter_spell", 0.0, false,
		SpellData.Rarity.COMMON, 25)

static func mass_protect() -> SpellData:
	return make_spell("Mass Protect", "ALL your goblins invincible for 5 seconds.",
		3, SpellData.TargetType.ALL_ALLIES, {}, "mass_protect", 5.0, false,
		SpellData.Rarity.RARE, 50)

# ── CHAOS (weird/unpredictable) ──────────────────────────────────────────────

static func teleport() -> SpellData:
	return make_spell("Teleport", "Move any goblin to any spot on the pitch.",
		1, SpellData.TargetType.ALLY, {}, "teleport", 0.0, false,
		SpellData.Rarity.COMMON, 25)

static func clone() -> SpellData:
	return make_spell("Clone", "Duplicate one of your goblins. 7v6 for rest of match.",
		3, SpellData.TargetType.ALLY, {}, "clone", 0.0, false,
		SpellData.Rarity.RARE, 55)

static func mind_control() -> SpellData:
	return make_spell("Mind Control", "An enemy goblin plays for YOU for 30 seconds.",
		3, SpellData.TargetType.ENEMY, {}, "mind_control", 30.0, false,
		SpellData.Rarity.RARE, 55)

static func swap() -> SpellData:
	return make_spell("Swap", "Switch positions of any two goblins on the pitch.",
		1, SpellData.TargetType.NONE, {}, "swap", 0.0, false,
		SpellData.Rarity.COMMON, 20)

static func rage_potion() -> SpellData:
	return make_spell("Rage Potion", "+5 all stats on one goblin but they attack EVERYONE.",
		2, SpellData.TargetType.ALLY,
		{"shooting": 5, "speed": 5, "defense": 5, "strength": 5, "chaos": 5},
		"rage_potion", 15.0, false, SpellData.Rarity.UNCOMMON, 40)

# ── BUFFS / DEBUFFS ─────────────────────────────────────────────────────────

static func haste() -> SpellData:
	return make_spell("Haste", "+3 speed to one goblin for 15 seconds.",
		1, SpellData.TargetType.ALLY, {"speed": 3}, "haste", 15.0, false,
		SpellData.Rarity.COMMON, 20)

static func dark_surge() -> SpellData:
	return make_spell("Dark Surge", "+3 shooting to one goblin for 15 seconds.",
		1, SpellData.TargetType.ALLY, {"shooting": 3}, "dark_surge", 15.0, false,
		SpellData.Rarity.COMMON, 20)

static func hex() -> SpellData:
	return make_spell("Hex", "-2 all stats on one enemy for 30 seconds.",
		2, SpellData.TargetType.ENEMY,
		{"shooting": -2, "speed": -2, "defense": -2, "strength": -2, "health": -2, "chaos": -2},
		"hex", 30.0, false, SpellData.Rarity.UNCOMMON, 35)

static func war_cry() -> SpellData:
	return make_spell("War Cry", "+2 strength to all your goblins for 15 seconds.",
		2, SpellData.TargetType.ALL_ALLIES, {"strength": 2}, "war_cry", 15.0, false,
		SpellData.Rarity.COMMON, 30)

static func blood_pact() -> SpellData:
	return make_spell("Blood Pact", "+5 shooting to one goblin. They take injury post-match.",
		3, SpellData.TargetType.ALLY, {"shooting": 5}, "blood_pact", 0.0, true,
		SpellData.Rarity.RARE, 50)

# ── Lookups ─────────────────────────────────────────────────────────────────

static func all_spells() -> Array[SpellData]:
	return [fireball(), lightning_bolt(), chain_lightning(), meteor(), earthquake(), rot_curse(),
		shield_dome(), heal(), healing_wave(), resurrect(), mass_protect(),
		teleport(), clone(), mind_control(), swap(), rage_potion(),
		haste(), dark_surge(), hex(), war_cry(), blood_pact()]

static func starter_deck() -> Array[SpellData]:
	## Starting deck: essentials for a sorcerer duel.
	return [fireball(), shield_dome(), heal(), haste(), dark_surge()]

static func shop_pool() -> Array[SpellData]:
	## All spells available in shop.
	return all_spells()

static func get_by_name(spell_name: String) -> SpellData:
	for s in all_spells():
		if s.spell_name == spell_name:
			return s
	return null
