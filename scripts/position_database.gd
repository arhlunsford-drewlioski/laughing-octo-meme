class_name PositionDatabase
extends RefCounted
## Five roles. That's it.
## keeper / defender / midfielder / attacker / chaos.
## Chaos is the wildcard - high variance, fly-kick instinct, ignores formation.

# ── Position Entry Structure ─────────────────────────────────────────────────
# {
#   "name": "Defender",
#   "key": "defender",
#   "zone": "attack" | "midfield" | "defense" | "goal",
#   "primary_stats": ["defense", "strength"],
#   "identity": "Wall in front of the keeper",
#   "tendency_with_ball": "clear_to_safety",
#   "tendency_own_team": "block_central",
#   "tendency_opponent": "block_central",
# }

static var _positions: Dictionary = {}
static var _initialized: bool = false

# Legacy → new role aliases for any GoblinData saved before the collapse.
const _LEGACY_ALIASES: Dictionary = {
	"striker": "attacker",
	"winger": "chaos",
	"poacher": "attacker",
	"shadow_striker": "chaos",
	"target_man": "attacker",
	"false_nine": "chaos",
	"attacking_mid": "midfielder",
	"box_to_box": "midfielder",
	"playmaker": "midfielder",
	"trequartista": "chaos",
	"sweeper": "defender",
	"anchor": "defender",
	"enforcer": "defender",
	"wing_back": "defender",
}

static func resolve_key(key: String) -> String:
	## Translate any legacy or unknown key to one of the 5 roles.
	_ensure_init()
	if _positions.has(key):
		return key
	if _LEGACY_ALIASES.has(key):
		return _LEGACY_ALIASES[key]
	return "midfielder"

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	_add("keeper", {
		"name": "Keeper",
		"zone": "goal",
		"primary_stats": ["strength", "defense", "health"],
		"identity": "Last line. Goblin in the box.",
		"tendency_with_ball": "distribute_quickly",
		"tendency_own_team": "stay_in_goal",
		"tendency_opponent": "stay_in_goal",
	})
	_add("defender", {
		"name": "Defender",
		"zone": "defense",
		"primary_stats": ["defense", "strength"],
		"identity": "Wall in front of the keeper.",
		"tendency_with_ball": "clear_to_safety",
		"tendency_own_team": "block_central",
		"tendency_opponent": "block_central",
	})
	_add("midfielder", {
		"name": "Midfielder",
		"zone": "midfield",
		"primary_stats": ["defense", "speed"],
		"identity": "Engine room. Does a bit of everything.",
		"tendency_with_ball": "pass_forward",
		"tendency_own_team": "fill_gaps",
		"tendency_opponent": "press_win_ball",
	})
	_add("attacker", {
		"name": "Attacker",
		"zone": "attack",
		"primary_stats": ["shooting", "speed"],
		"identity": "Finisher. Lives near the box.",
		"tendency_with_ball": "shoot_or_dribble",
		"tendency_own_team": "hold_high_line",
		"tendency_opponent": "press_lazy",
	})
	_add("chaos", {
		"name": "Chaos",
		"zone": "attack",  # default - the chaos goblin starts wide and high
		"primary_stats": ["chaos", "speed"],
		"identity": "Will attempt a fly-kick. Apologies in advance.",
		"tendency_with_ball": "fly_kick",
		"tendency_own_team": "yolo_charge",
		"tendency_opponent": "yolo_charge",
	})

static func _add(key: String, data: Dictionary) -> void:
	data["key"] = key
	_positions[key] = data

# ── Public API ───────────────────────────────────────────────────────────────

static func get_position(key: String) -> Dictionary:
	_ensure_init()
	return _positions.get(resolve_key(key), {})

static func get_all_keys() -> Array:
	_ensure_init()
	return _positions.keys()

# Legacy callers still ask for base/hybrid distinction; collapse them all to the same list.
static func get_base_keys() -> Array:
	return get_all_keys()

static func get_hybrid_keys() -> Array:
	return []

static func get_positions_for_zone(zone: String) -> Array:
	_ensure_init()
	return _positions.keys().filter(func(k): return _positions[k]["zone"] == zone)

static func get_primary_stats(key: String) -> Array:
	var pos := get_position(key)
	return pos.get("primary_stats", [])

static func get_zone(key: String) -> String:
	var pos := get_position(key)
	return pos.get("zone", "midfield")

static func get_display_name(key: String) -> String:
	var pos := get_position(key)
	return pos.get("name", key)

# ── Zone Rects ──────────────────────────────────────────────────────────────
# Roaming rectangles per role: {x_min, x_max, y_min, y_max}
# HOME perspective (attacking right). Caller flips x for away team.

static var _zone_rects: Dictionary = {}
static var _zone_rects_init: bool = false

static func _ensure_zones() -> void:
	if _zone_rects_init:
		return
	_zone_rects_init = true

	_zone_rects = {
		# "in" = team has possession (pushed up)
		# "out" = defending (dropped back)
		"keeper":     { "in": [0.02, 0.10, 0.35, 0.65], "out": [0.02, 0.08, 0.35, 0.65] },
		"defender":   { "in": [0.12, 0.38, 0.18, 0.82], "out": [0.06, 0.26, 0.20, 0.80] },
		"midfielder": { "in": [0.30, 0.62, 0.15, 0.85], "out": [0.20, 0.45, 0.18, 0.82] },
		"attacker":   { "in": [0.55, 0.88, 0.20, 0.80], "out": [0.40, 0.62, 0.22, 0.78] },
		# Chaos: extreme range. Goes far. Comes back. Mostly far.
		"chaos":      { "in": [0.30, 0.92, 0.05, 0.95], "out": [0.20, 0.65, 0.10, 0.90] },
		"_default":   { "in": [0.25, 0.55, 0.18, 0.82], "out": [0.15, 0.40, 0.20, 0.80] },
	}

static func get_zone_rect(position_key: String, in_possession: bool, _is_left_flank: bool = false) -> Array:
	## Returns [x_min, x_max, y_min, y_max] for the role's roaming area.
	_ensure_zones()
	var lookup_key: String = resolve_key(position_key)
	var entry: Dictionary = _zone_rects.get(lookup_key, _zone_rects["_default"])
	return entry["in"] if in_possession else entry["out"]

static func get_zone_rect_flipped(position_key: String, in_possession: bool, is_home: bool, is_left_flank: bool = false) -> Array:
	var rect: Array = get_zone_rect(position_key, in_possession, is_left_flank)
	if is_home:
		return rect
	return [1.0 - rect[1], 1.0 - rect[0], rect[2], rect[3]]
