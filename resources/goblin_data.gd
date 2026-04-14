class_name GoblinData
extends Resource
## A goblin in the roguelike roster. 6 hex stats, position, items, injury/death tracking.

# ── Identity ──────────────────────────────────────────────────────────────────
@export var goblin_name: String = ""
@export var personality: String = ""
@export var faction: int = 0

# ── Six Hex Stats (1-10 scale) ────────────────────────────────────────────────
@export_range(1, 10) var shooting: int = 3
@export_range(1, 10) var speed: int = 3
@export_range(1, 10) var defense: int = 3
@export_range(1, 10) var strength: int = 3
@export_range(1, 10) var health: int = 3
@export_range(1, 10) var chaos: int = 3

# ── Position ──────────────────────────────────────────────────────────────────
## Position key from PositionDatabase (e.g. "striker", "enforcer", "keeper")
@export var position: String = "midfielder"

# ── Equipment (1 item slot) ──────────────────────────────────────────────────
## Equipped item resource (null = empty slot)
var equipped_item: Resource = null

# ── Injury / Death ────────────────────────────────────────────────────────────
enum InjuryState { HEALTHY, MINOR, MAJOR, DEAD }
var injury: InjuryState = InjuryState.HEALTHY

## Stat penalties applied by current injury (-1 per minor, -2 per major)
var injury_stat_penalties: Dictionary = {}

# ── XP / Leveling ───────────────────────────────────────────────────────────
var xp: int = 0
var level: int = 1

const XP_PER_LEVEL_BASE: int = 100  # XP needed = XP_PER_LEVEL_BASE * level

func xp_to_next_level() -> int:
	return XP_PER_LEVEL_BASE * level

func add_xp(amount: int) -> int:
	## Add XP and auto-level. Returns number of levels gained.
	xp += amount
	var levels_gained := 0
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_apply_level_up()
		levels_gained += 1
	return levels_gained

func _apply_level_up() -> void:
	## +1 to a stat, weighted toward position's primary stats.
	var primary_stats := PositionDatabase.get_primary_stats(position)
	var pool: Array[String] = []
	for stat_name in STAT_KEYS:
		pool.append(stat_name)
		if stat_name in primary_stats:
			pool.append(stat_name)  # Double weight for primary stats
	pool.shuffle()
	var chosen: String = pool[0]
	set(chosen, mini(get(chosen) + 1, 10))

# ── Fatigue (0-10) ───────────────────────────────────────────────────────────
## 0 = fresh, 10 = exhausted. Playing a match adds FATIGUE_PER_MATCH, resting removes FATIGUE_REST.
## At fatigue >= FATIGUE_PENALTY_THRESHOLD, speed and defense get -1 each.
var fatigue: int = 0
const FATIGUE_PER_MATCH: int = 3
const FATIGUE_REST: int = 2
const FATIGUE_PENALTY_THRESHOLD: int = 5

# ── Morale (1-10) ────────────────────────────────────────────────────────────
var morale: int = 7

# ── Match-only transient state ────────────────────────────────────────────────
var active_effects: Array = []  # SpellData effects currently on this goblin
var stamina: float = 100.0      # Drains during match, refills between

# ── Appearance (procedural, future use) ──────────────────────────────────────
@export var appearance: Dictionary = {}

# ── Stat Access ──────────────────────────────────────────────────────────────

const STAT_KEYS := ["shooting", "speed", "defense", "strength", "health", "chaos"]

func get_stat(stat_name: String) -> int:
	var base: int = get(stat_name) if stat_name in STAT_KEYS else 0
	var penalty: int = injury_stat_penalties.get(stat_name, 0)
	var buff: int = _get_effect_modifier(stat_name)
	var fatigue_penalty: int = _get_fatigue_penalty(stat_name)
	var item_bonus: int = _get_item_bonus(stat_name)
	return clampi(base + penalty + buff + fatigue_penalty + item_bonus, 1, 15)

func get_stat_dict() -> Dictionary:
	var d := {}
	for key in STAT_KEYS:
		d[key] = get_stat(key)
	return d

func _get_effect_modifier(stat_name: String) -> int:
	var total := 0
	for effect in active_effects:
		if effect.has("stat") and effect["stat"] == stat_name:
			total += effect.get("amount", 0)
	return total

# ── Equipment helpers ────────────────────────────────────────────────────────

func _get_item_bonus(stat_name: String) -> int:
	if equipped_item and equipped_item is ItemData:
		return equipped_item.get_stat_bonus(stat_name)
	return 0

func equip_item(item: ItemData) -> ItemData:
	## Equip an item, returning the previously equipped item (or null).
	var old := equipped_item as ItemData
	equipped_item = item
	return old

func unequip_item() -> ItemData:
	## Remove and return the equipped item.
	var old := equipped_item as ItemData
	equipped_item = null
	return old

func has_item() -> bool:
	return equipped_item != null and equipped_item is ItemData

# ── Fatigue helpers ──────────────────────────────────────────────────────────

func _get_fatigue_penalty(stat_name: String) -> int:
	if fatigue >= FATIGUE_PENALTY_THRESHOLD and stat_name in ["speed", "defense"]:
		return -1
	return 0

func add_match_fatigue() -> void:
	fatigue = mini(fatigue + FATIGUE_PER_MATCH, 10)

func rest() -> void:
	fatigue = maxi(fatigue - FATIGUE_REST, 0)

func is_fatigued() -> bool:
	return fatigue >= FATIGUE_PENALTY_THRESHOLD

# ── Injury helpers ───────────────────────────────────────────────────────────

func apply_injury(severity: InjuryState) -> void:
	if severity <= injury:
		return  # Already at this severity or worse
	injury = severity
	injury_stat_penalties.clear()
	match injury:
		InjuryState.MINOR:
			# -1 to two random stats
			var stats := STAT_KEYS.duplicate()
			stats.shuffle()
			injury_stat_penalties[stats[0]] = -1
			injury_stat_penalties[stats[1]] = -1
		InjuryState.MAJOR:
			# -2 to three random stats
			var stats := STAT_KEYS.duplicate()
			stats.shuffle()
			for i in 3:
				injury_stat_penalties[stats[i]] = -2
		InjuryState.DEAD:
			pass  # Dead goblins are removed from the roster

func heal_injury() -> void:
	injury = InjuryState.HEALTHY
	injury_stat_penalties.clear()

func is_alive() -> bool:
	return injury != InjuryState.DEAD

func is_available() -> bool:
	return is_alive() and injury != InjuryState.MAJOR

# ── Match reset ──────────────────────────────────────────────────────────────

func reset_for_match() -> void:
	active_effects.clear()
	stamina = 100.0
	# Note: fatigue is NOT reset here - it persists across matches
