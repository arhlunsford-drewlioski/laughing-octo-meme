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
	return clampi(base + penalty + buff, 1, 15)

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
