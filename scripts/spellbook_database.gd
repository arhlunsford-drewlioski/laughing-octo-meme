class_name SpellbookDatabase
extends RefCounted
## The three starter spellbooks the wizard chooses from at run start.
## Each book has a base spell + a curated pool of pages that modify it.

# ── Book Keys ───────────────────────────────────────────────────────────────
const BOOK_FIREBALL: String = "fireball"
const BOOK_LIGHTNING: String = "lightning"
const BOOK_DIVINE: String = "divine_light"

# ── Public API ──────────────────────────────────────────────────────────────

static func all_books() -> Array[SpellbookData]:
	return [fireball_book(), lightning_book(), divine_light_book()]

static func get_book(key: String) -> SpellbookData:
	match key:
		BOOK_FIREBALL: return fireball_book()
		BOOK_LIGHTNING: return lightning_book()
		BOOK_DIVINE: return divine_light_book()
	return fireball_book()

## Curated page pool for the given book. Used to roll choices in the page shop.
static func get_page_pool(book_key: String) -> Array[SpellPage]:
	match book_key:
		BOOK_FIREBALL: return _fireball_pages()
		BOOK_LIGHTNING: return _lightning_pages()
		BOOK_DIVINE: return _divine_pages()
	return []

## Roll N random pages from the book's pool (with replacement allowed - pages can stack).
static func roll_pages(book_key: String, count: int) -> Array[SpellPage]:
	var pool := get_page_pool(book_key)
	var out: Array[SpellPage] = []
	if pool.is_empty():
		return out
	var indices: Array[int] = []
	for i in range(pool.size()):
		indices.append(i)
	indices.shuffle()
	for i in range(mini(count, indices.size())):
		out.append(pool[indices[i]])
	return out

# ── Books ───────────────────────────────────────────────────────────────────

static func fireball_book() -> SpellbookData:
	var b := SpellbookData.new()
	b.book_key = BOOK_FIREBALL
	b.book_name = "Tome of Cinders"
	b.description = "Hurl explosive fire. Pages bend the blast - bigger, cheaper, more relentless."
	b.icon = "🔥"
	b.color = Color(1.0, 0.45, 0.15)
	b.base_spell = SpellDatabase.fireball()
	return b

static func lightning_book() -> SpellbookData:
	var b := SpellbookData.new()
	b.book_key = BOOK_LIGHTNING
	b.book_name = "Stormwrit Codex"
	b.description = "Surgical lightning strikes. Pages chain, hasten, and refine the bolt."
	b.icon = "⚡"
	b.color = Color(0.6, 0.85, 1.0)
	b.base_spell = SpellDatabase.lightning_bolt()
	return b

static func divine_light_book() -> SpellbookData:
	var b := SpellbookData.new()
	b.book_key = BOOK_DIVINE
	b.book_name = "Aurora Verses"
	b.description = "Holy light heals and shields your team. Pages amplify the blessing."
	b.icon = "✨"
	b.color = Color(1.0, 0.9, 0.55)
	b.base_spell = SpellDatabase.divine_light()
	return b

# ── Page Pools ──────────────────────────────────────────────────────────────

static func _make_page(book_key: String, p_name: String, p_desc: String,
		p_mod: SpellPage.ModifierType, p_value: float = 0.0, p_str: String = "",
		p_cost: int = 30, p_rarity: SpellPage.Rarity = SpellPage.Rarity.COMMON) -> SpellPage:
	var p := SpellPage.new()
	p.book_key = book_key
	p.page_name = p_name
	p.description = p_desc
	p.modifier_type = p_mod
	p.modifier_value_num = p_value
	p.modifier_value_str = p_str
	p.gold_cost = p_cost
	p.rarity = p_rarity
	return p

static func _fireball_pages() -> Array[SpellPage]:
	return [
		_make_page(BOOK_FIREBALL, "Volatile Powder",
			"-1 mana cost.", SpellPage.ModifierType.MANA_DISCOUNT, 1, "", 35),
		_make_page(BOOK_FIREBALL, "Quickwick",
			"Cooldown -2s.", SpellPage.ModifierType.COOLDOWN_REDUCTION, 2.0, "", 35),
		_make_page(BOOK_FIREBALL, "Wider Fuse",
			"Blast radius +25%.", SpellPage.ModifierType.RADIUS_BONUS, 0.25, "", 50,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_FIREBALL, "Searing Core",
			"+1 damage in the kill zone.", SpellPage.ModifierType.DAMAGE_BONUS, 1, "", 55,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_FIREBALL, "Twin Wick",
			"Fireballs split into two on impact.", SpellPage.ModifierType.TAG, 0, "split", 70,
			SpellPage.Rarity.RARE),
		_make_page(BOOK_FIREBALL, "Heretic's Margin",
			"+2 page slots.", SpellPage.ModifierType.EXTRA_SLOT, 2, "", 60,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_FIREBALL, "Pyromancer's Fervor",
			"Cooldown -1s and -1 mana cost.", SpellPage.ModifierType.MANA_DISCOUNT, 1, "", 60,
			SpellPage.Rarity.UNCOMMON),
	]

static func _lightning_pages() -> Array[SpellPage]:
	return [
		_make_page(BOOK_LIGHTNING, "Copper Conduit",
			"-1 mana cost.", SpellPage.ModifierType.MANA_DISCOUNT, 1, "", 35),
		_make_page(BOOK_LIGHTNING, "Static Charge",
			"Cooldown -2s.", SpellPage.ModifierType.COOLDOWN_REDUCTION, 2.0, "", 35),
		_make_page(BOOK_LIGHTNING, "Forked Bolt",
			"Bolt arcs to a second target.", SpellPage.ModifierType.TAG, 0, "chain", 55,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_LIGHTNING, "Thunderclap",
			"Adds shockwave radius.", SpellPage.ModifierType.RADIUS_BONUS, 0.15, "", 50,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_LIGHTNING, "Voltaic Surge",
			"+1 damage on direct hit.", SpellPage.ModifierType.DAMAGE_BONUS, 1, "", 55,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_LIGHTNING, "Stormwright's Margin",
			"+2 page slots.", SpellPage.ModifierType.EXTRA_SLOT, 2, "", 60,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_LIGHTNING, "Heaven's Wrath",
			"Cooldown -3s. Costly.", SpellPage.ModifierType.COOLDOWN_REDUCTION, 3.0, "", 75,
			SpellPage.Rarity.RARE),
	]

static func _divine_pages() -> Array[SpellPage]:
	return [
		_make_page(BOOK_DIVINE, "Saint's Whisper",
			"-1 mana cost.", SpellPage.ModifierType.MANA_DISCOUNT, 1, "", 35),
		_make_page(BOOK_DIVINE, "Lingering Glow",
			"Buff duration +10s.", SpellPage.ModifierType.DURATION_BONUS, 10.0, "", 40),
		_make_page(BOOK_DIVINE, "Radiant Vigor",
			"Buff strength +1 to all stats.", SpellPage.ModifierType.STAT_AMP, 1, "", 55,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_DIVINE, "Reverberant Hymn",
			"Cooldown -2s.", SpellPage.ModifierType.COOLDOWN_REDUCTION, 2.0, "", 40),
		_make_page(BOOK_DIVINE, "Wider Aurora",
			"Light reaches further.", SpellPage.ModifierType.RADIUS_BONUS, 0.2, "", 50,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_DIVINE, "Acolyte's Margin",
			"+2 page slots.", SpellPage.ModifierType.EXTRA_SLOT, 2, "", 60,
			SpellPage.Rarity.UNCOMMON),
		_make_page(BOOK_DIVINE, "Crowned Verse",
			"Buff strength +2 to all stats.", SpellPage.ModifierType.STAT_AMP, 2, "", 80,
			SpellPage.Rarity.RARE),
	]
