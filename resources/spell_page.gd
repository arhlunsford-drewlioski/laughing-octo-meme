class_name SpellPage
extends Resource
## A page added to a Spellbook. Modifies the book's signature spell.
## Pages stack additively when multiple copies are bought.

enum ModifierType {
	MANA_DISCOUNT,        # value: int, subtracted from mana_cost (min 0)
	COOLDOWN_REDUCTION,   # value: float seconds shaved off cooldown
	DURATION_BONUS,       # value: float seconds added to duration
	STAT_AMP,             # value: int added to every stat in stat_modifiers (sign-aware)
	RADIUS_BONUS,         # value: float fraction added to AoE radius (Phase 1.5 hook)
	DAMAGE_BONUS,         # value: int added to damage falloff (Phase 1.5 hook)
	EXTRA_SLOT,           # value: int max_pages bonus
	TAG,                  # value: string tag added to the spell (for special FX hooks)
}

enum Rarity { COMMON, UNCOMMON, RARE }

@export var page_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var gold_cost: int = 30

## Which book this page belongs to (matches SpellbookData.book_key).
@export var book_key: String = ""

@export var modifier_type: ModifierType = ModifierType.MANA_DISCOUNT
@export var modifier_value_num: float = 0.0
@export var modifier_value_str: String = ""
