class_name SpellbookData
extends Resource
## A wizard's spellbook - one signature spell, plus pages that modify it.

@export var book_key: String = ""           # "fireball", "lightning", "divine_light"
@export var book_name: String = ""
@export var description: String = ""
@export var icon: String = ""               # emoji for now
@export var color: Color = Color.WHITE

## The base spell this book casts. Pages modify a copy of this.
@export var base_spell: SpellData = null

## Pages currently bound to the book.
@export var pages: Array[SpellPage] = []

## Maximum number of pages that can be bound. EXTRA_SLOT pages bump this.
@export var max_pages_base: int = 8

func max_pages() -> int:
	var bonus: int = 0
	for p in pages:
		if p and p.modifier_type == SpellPage.ModifierType.EXTRA_SLOT:
			bonus += int(p.modifier_value_num)
	return max_pages_base + bonus

func can_add_page() -> bool:
	return pages.size() < max_pages()

func add_page(page: SpellPage) -> bool:
	if not can_add_page():
		return false
	pages.append(page)
	return true

## Returns a fresh copy of the base spell with all page modifiers baked in.
func get_modified_spell() -> SpellData:
	if base_spell == null:
		return null
	var s: SpellData = base_spell.duplicate(true) as SpellData
	for page in pages:
		if page == null:
			continue
		_apply_page(s, page)
	# Clamp to sane minimums.
	s.mana_cost = maxi(s.mana_cost, 1)
	s.cooldown = maxf(s.cooldown, 1.0)
	return s

func _apply_page(spell: SpellData, page: SpellPage) -> void:
	match page.modifier_type:
		SpellPage.ModifierType.MANA_DISCOUNT:
			spell.mana_cost -= int(page.modifier_value_num)
		SpellPage.ModifierType.COOLDOWN_REDUCTION:
			spell.cooldown -= page.modifier_value_num
		SpellPage.ModifierType.DURATION_BONUS:
			spell.duration += page.modifier_value_num
		SpellPage.ModifierType.STAT_AMP:
			var amp: int = int(page.modifier_value_num)
			var new_mods: Dictionary = {}
			for k in spell.stat_modifiers.keys():
				var v: int = int(spell.stat_modifiers[k])
				new_mods[k] = v + (amp if v >= 0 else -amp)
			spell.stat_modifiers = new_mods
		SpellPage.ModifierType.EXTRA_SLOT:
			pass  # Handled in max_pages()
		SpellPage.ModifierType.TAG:
			# Stash tags in a meta dict on the spell for downstream hooks.
			var tags: Array = spell.get_meta("page_tags", []) if spell.has_meta("page_tags") else []
			tags.append(page.modifier_value_str)
			spell.set_meta("page_tags", tags)
		SpellPage.ModifierType.RADIUS_BONUS:
			var rb: float = spell.get_meta("radius_bonus", 0.0) if spell.has_meta("radius_bonus") else 0.0
			spell.set_meta("radius_bonus", rb + page.modifier_value_num)
		SpellPage.ModifierType.DAMAGE_BONUS:
			var db: int = spell.get_meta("damage_bonus", 0) if spell.has_meta("damage_bonus") else 0
			spell.set_meta("damage_bonus", db + int(page.modifier_value_num))
