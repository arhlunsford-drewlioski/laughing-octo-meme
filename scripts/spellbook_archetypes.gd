class_name SpellbookArchetypes
extends RefCounted
## Opponent wizard archetypes. Each archetype = one of the 3 starter books +
## a curated page list. Difficulty scales the number of pages bound at run time.
##
## Page-count guidance per archetype tier:
##   tier 0 (early group stage):    base book + 0-1 pages
##   tier 1 (late group stage):     2-3 pages
##   tier 2 (round of 16 / quarter): 3-4 pages
##   tier 3 (semi / final):          all listed pages

const BOOK_FIREBALL: String = SpellbookDatabase.BOOK_FIREBALL
const BOOK_LIGHTNING: String = SpellbookDatabase.BOOK_LIGHTNING
const BOOK_DIVINE: String = SpellbookDatabase.BOOK_DIVINE

# ── Public API ──────────────────────────────────────────────────────────────

static func all_archetypes() -> Array[Dictionary]:
	return [
		pyromaniac(), quickwick_cultist(), glass_cannon(),
		stormcaller(), forked_prophet(), thunderclap_priest(),
		warden(), acolyte_of_light(), crowned_apostle(),
		fledgling_apprentice(),
	]

static func roll_archetype(difficulty: float) -> Dictionary:
	## Pick a random archetype. Higher difficulty doesn't gate which archetype
	## you face - just how many pages they bring. Variety stays even at the top.
	var pool := all_archetypes()
	return pool[randi() % pool.size()]

static func build_spellbook(archetype: Dictionary, difficulty: float) -> SpellbookData:
	## Materialize an archetype into a real SpellbookData with pages bound,
	## scaled by difficulty (0.0 = first match, 1.0 = final).
	var book_key: String = str(archetype.get("book", BOOK_FIREBALL))
	var book: SpellbookData = SpellbookDatabase.get_book(book_key)
	if book == null:
		return null

	var page_pool: Array = archetype.get("pages", [])
	var max_pages: int = page_pool.size()
	# Scale page count from 0-1 of the listed pool depending on difficulty.
	var target_count: int = int(round(lerpf(0.0, float(max_pages), clampf(difficulty, 0.0, 1.0))))
	# Always grant at least 1 page to mid+ opponents so they feel different from base.
	if difficulty >= 0.35 and target_count == 0:
		target_count = 1
	target_count = mini(target_count, max_pages)

	var page_db := SpellbookDatabase.get_page_pool(book_key)
	for i in target_count:
		var page_name: String = str(page_pool[i])
		var page: SpellPage = _find_page_by_name(page_db, page_name)
		if page != null:
			book.add_page(page)
	return book

static func _find_page_by_name(page_db: Array[SpellPage], page_name: String) -> SpellPage:
	for p in page_db:
		if p.page_name == page_name:
			return p
	return null

# ── Archetype Definitions ───────────────────────────────────────────────────
# Each archetype: { "name", "book", "pages": [page names in priority order] }

# ── Fireball line ──
static func pyromaniac() -> Dictionary:
	return {
		"name": "The Pyromaniac",
		"book": BOOK_FIREBALL,
		"pages": ["Twin Wick", "Wider Fuse", "Searing Core", "Pyromancer's Fervor"],
	}

static func quickwick_cultist() -> Dictionary:
	return {
		"name": "The Quickwick Cultist",
		"book": BOOK_FIREBALL,
		"pages": ["Volatile Powder", "Quickwick", "Pyromancer's Fervor", "Heretic's Margin"],
	}

static func glass_cannon() -> Dictionary:
	return {
		"name": "The Glass Cannon",
		"book": BOOK_FIREBALL,
		"pages": ["Searing Core", "Wider Fuse", "Twin Wick", "Heretic's Margin"],
	}

# ── Lightning line ──
static func stormcaller() -> Dictionary:
	return {
		"name": "The Stormcaller",
		"book": BOOK_LIGHTNING,
		"pages": ["Static Charge", "Voltaic Surge", "Heaven's Wrath", "Stormwright's Margin"],
	}

static func forked_prophet() -> Dictionary:
	return {
		"name": "The Forked Prophet",
		"book": BOOK_LIGHTNING,
		"pages": ["Forked Bolt", "Voltaic Surge", "Thunderclap", "Stormwright's Margin"],
	}

static func thunderclap_priest() -> Dictionary:
	return {
		"name": "The Thunderclap Priest",
		"book": BOOK_LIGHTNING,
		"pages": ["Thunderclap", "Forked Bolt", "Copper Conduit", "Voltaic Surge"],
	}

# ── Divine line ──
static func warden() -> Dictionary:
	return {
		"name": "The Warden",
		"book": BOOK_DIVINE,
		"pages": ["Crowned Verse", "Lingering Glow", "Reverberant Hymn", "Acolyte's Margin"],
	}

static func acolyte_of_light() -> Dictionary:
	return {
		"name": "The Acolyte",
		"book": BOOK_DIVINE,
		"pages": ["Saint's Whisper", "Radiant Vigor", "Wider Aurora", "Acolyte's Margin"],
	}

static func crowned_apostle() -> Dictionary:
	return {
		"name": "The Crowned Apostle",
		"book": BOOK_DIVINE,
		"pages": ["Lingering Glow", "Crowned Verse", "Wider Aurora", "Reverberant Hymn"],
	}

# ── Generic / first-match opponents ──
static func fledgling_apprentice() -> Dictionary:
	## Random book, base spell only - the easiest possible opponent.
	var books := [BOOK_FIREBALL, BOOK_LIGHTNING, BOOK_DIVINE]
	var roll: int = randi() % books.size()
	return {
		"name": "The Apprentice",
		"book": books[roll],
		"pages": [],
	}
