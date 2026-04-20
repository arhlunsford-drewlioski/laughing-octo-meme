class_name SorcererArchetypes
extends RefCounted
## 10 opponent sorcerer archetypes with themed spell loadouts and personalities.
## Each archetype picks spells from SpellDatabase and has casting AI behavior.

# Casting personality parameters
# - aggression: 0-1, how eagerly they spend mana (high = spam, low = save)
# - target_priority: "best" (your best goblin), "ball" (carrier), "random"
# - counter_chance: 0-1, how likely they are to save mana for counters
# - min_mana_spend: only cast when you have >= this mana (hoarder behavior)

static func get_archetype(index: int) -> Dictionary:
	var archetypes: Array[Dictionary] = [
		pyromaniac(),
		protector(),
		necromancer(),
		trickster(),
		berserker(),
		storm_caller(),
		blood_mage(),
		tactician(),
		warden(),
		chaos_god(),
	]
	return archetypes[index % archetypes.size()]

static func all_archetypes() -> Array[Dictionary]:
	return [pyromaniac(), protector(), necromancer(), trickster(), berserker(),
		storm_caller(), blood_mage(), tactician(), warden(), chaos_god()]

static func random_archetype() -> Dictionary:
	var all := all_archetypes()
	return all[randi() % all.size()]

# ── ARCHETYPES ─────────────────────────────────────────────────────────────

static func pyromaniac() -> Dictionary:
	return {
		"name": "The Pyromaniac",
		"title": "Fire Lord",
		"description": "Spams fire. Doesn't care about friendly fire. Chaotic matches.",
		"color": Color(1.0, 0.35, 0.1),
		"icon": "🔥",
		"spells": [
			SpellDatabase.fireball(),
			SpellDatabase.fireball(),
			SpellDatabase.fireball(),
			SpellDatabase.meteor(),
			SpellDatabase.haste(),
		],
		"aggression": 0.9,
		"target_priority": "random",
		"counter_chance": 0.1,
		"min_mana_spend": 2,
	}

static func protector() -> Dictionary:
	return {
		"name": "The Protector",
		"title": "Warden of Goblins",
		"description": "Saves mana for counters and shields. Hard to break through.",
		"color": Color(0.3, 0.7, 1.0),
		"icon": "🛡",
		"spells": [
			SpellDatabase.shield_dome(),
			SpellDatabase.shield_dome(),
			SpellDatabase.mass_protect(),
			SpellDatabase.heal(),
			SpellDatabase.healing_wave(),
			SpellDatabase.fireball(),
		],
		"aggression": 0.4,
		"target_priority": "ball",
		"counter_chance": 0.0,
		"min_mana_spend": 2,
	}

static func necromancer() -> Dictionary:
	return {
		"name": "The Necromancer",
		"title": "Death Lord",
		"description": "Dead goblins come back. Long matches of attrition.",
		"color": Color(0.4, 0.2, 0.6),
		"icon": "💀",
		"spells": [
			SpellDatabase.rot_curse(),
			SpellDatabase.rot_curse(),
			SpellDatabase.resurrect(),
			SpellDatabase.hex(),
			SpellDatabase.fireball(),
		],
		"aggression": 0.6,
		"target_priority": "best",
		"counter_chance": 0.2,
		"min_mana_spend": 2,
	}

static func trickster() -> Dictionary:
	return {
		"name": "The Trickster",
		"title": "Chaos Weaver",
		"description": "Teleports, clones, swaps. Nothing makes sense.",
		"color": Color(0.9, 0.2, 0.9),
		"icon": "✨",
		"spells": [
			SpellDatabase.teleport(),
			SpellDatabase.teleport(),
			SpellDatabase.swap(),
			SpellDatabase.clone(),
			SpellDatabase.mind_control(),
		],
		"aggression": 0.8,
		"target_priority": "random",
		"counter_chance": 0.3,
		"min_mana_spend": 1,
	}

static func berserker() -> Dictionary:
	return {
		"name": "The Berserker",
		"title": "Blood God",
		"description": "Buffs team to insane stats. Suicidal attacks.",
		"color": Color(0.9, 0.2, 0.1),
		"icon": "⚔",
		"spells": [
			SpellDatabase.rage_potion(),
			SpellDatabase.rage_potion(),
			SpellDatabase.blood_pact(),
			SpellDatabase.war_cry(),
			SpellDatabase.haste(),
		],
		"aggression": 0.85,
		"target_priority": "ball",
		"counter_chance": 0.1,
		"min_mana_spend": 2,
	}

static func storm_caller() -> Dictionary:
	return {
		"name": "The Storm Caller",
		"title": "Sky Tyrant",
		"description": "Precision lightning kills. Disrupts with earthquakes.",
		"color": Color(0.6, 0.85, 1.0),
		"icon": "⚡",
		"spells": [
			SpellDatabase.lightning_bolt(),
			SpellDatabase.lightning_bolt(),
			SpellDatabase.earthquake(),
			SpellDatabase.chain_lightning(),
			SpellDatabase.haste(),
		],
		"aggression": 0.6,
		"target_priority": "best",
		"counter_chance": 0.4,
		"min_mana_spend": 3,
	}

static func blood_mage() -> Dictionary:
	return {
		"name": "The Blood Mage",
		"title": "Scarlet Sorcerer",
		"description": "Sacrifices own goblins for massive power.",
		"color": Color(0.7, 0.1, 0.2),
		"icon": "🩸",
		"spells": [
			SpellDatabase.blood_pact(),
			SpellDatabase.blood_pact(),
			SpellDatabase.rot_curse(),
			SpellDatabase.meteor(),
			SpellDatabase.fireball(),
		],
		"aggression": 0.75,
		"target_priority": "best",
		"counter_chance": 0.15,
		"min_mana_spend": 3,
	}

static func tactician() -> Dictionary:
	return {
		"name": "The Tactician",
		"title": "Grand Strategist",
		"description": "Debuffs your stars. Hex everything that moves.",
		"color": Color(0.85, 0.7, 0.3),
		"icon": "🎯",
		"spells": [
			SpellDatabase.hex(),
			SpellDatabase.hex(),
			SpellDatabase.swap(),
			SpellDatabase.teleport(),
			SpellDatabase.shield_dome(),
			SpellDatabase.haste(),
		],
		"aggression": 0.5,
		"target_priority": "best",
		"counter_chance": 0.0,
		"min_mana_spend": 2,
	}

static func warden() -> Dictionary:
	return {
		"name": "The Warden",
		"title": "Guardian of the Green",
		"description": "Healer and buffer. Hard to break, boring to face.",
		"color": Color(0.3, 0.8, 0.4),
		"icon": "🍃",
		"spells": [
			SpellDatabase.heal(),
			SpellDatabase.heal(),
			SpellDatabase.war_cry(),
			SpellDatabase.haste(),
			SpellDatabase.mass_protect(),
		],
		"aggression": 0.5,
		"target_priority": "ball",
		"counter_chance": 0.3,
		"min_mana_spend": 1,
	}

static func chaos_god() -> Dictionary:
	return {
		"name": "The Chaos God",
		"title": "Wildcard Entity",
		"description": "Random spell every cast. Could be anything.",
		"color": Color(1.0, 0.7, 0.2),
		"icon": "🎲",
		"spells": SpellDatabase.all_spells(),  # draws from everything
		"aggression": 0.7,
		"target_priority": "random",
		"counter_chance": 0.2,
		"min_mana_spend": 1,
	}
