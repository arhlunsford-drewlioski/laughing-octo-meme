class_name SpellData
extends Resource
## A spell the sorcerer can cast during matches. Replaces CardData.

enum TargetType { NONE, ALLY, ENEMY, ALL_ALLIES, ALL_ENEMIES, SELF }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var spell_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON

# ── Cost & Timing ────────────────────────────────────────────────────────────
@export var mana_cost: int = 1
@export var cooldown: float = 10.0   # Seconds before castable again
@export var duration: float = 15.0   # 0 = instant effect

# ── Targeting ────────────────────────────────────────────────────────────────
@export var target_type: TargetType = TargetType.ALLY

# ── Effect ───────────────────────────────────────────────────────────────────
## Stat modifiers applied for duration: { "shooting": 3, "defense": -2 }
@export var stat_modifiers: Dictionary = {}

## Special effect key for non-stat spells (e.g. "soul_swap", "curse_of_post")
@export var special_effect: String = ""

## If true, causes an injury to the target goblin after the match
@export var post_match_injury: bool = false

## If true, the target goblin DIES after the match (Dark Ascension)
@export var post_match_death: bool = false

# ── Shop ─────────────────────────────────────────────────────────────────────
@export var shop_cost: int = 50
