class_name PositionDatabase
extends RefCounted
## Static database of all 16 positions: 4 base + 12 hybrid.
## Each entry defines primary stats, AI tendencies, and formation zone.

# ── Position Entry Structure ─────────────────────────────────────────────────
# {
#   "name": "Striker",
#   "key": "striker",
#   "zone": "attack" | "midfield" | "defense" | "goal",
#   "tier": "base" | "hybrid",
#   "primary_stats": ["shooting", "speed"],   # 2 for base, 3 for hybrid
#   "identity": "Fast finisher",
#   "tendency_with_ball": "Shoot or dribble toward goal",
#   "tendency_own_team": "Hold high line, find space",
#   "tendency_opponent": "Press opponent defense lazily",
# }

static var _positions: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	# ── 4 Base Positions (2 primary stats) ──────────────────────────────────
	_add("striker", {
		"name": "Striker",
		"zone": "attack",
		"tier": "base",
		"primary_stats": ["shooting", "speed"],
		"identity": "Fast finisher",
		"tendency_with_ball": "shoot_or_dribble",
		"tendency_own_team": "hold_high_line",
		"tendency_opponent": "press_lazy",
	})
	_add("winger", {
		"name": "Winger",
		"zone": "attack",
		"tier": "base",
		"primary_stats": ["speed", "chaos"],
		"identity": "Flanker and crosser",
		"tendency_with_ball": "cross_or_cut_inside",
		"tendency_own_team": "hug_touchline",
		"tendency_opponent": "track_back",
	})
	_add("midfielder", {
		"name": "Midfielder",
		"zone": "midfield",
		"tier": "base",
		"primary_stats": ["defense", "speed"],
		"identity": "Engine room workhorse",
		"tendency_with_ball": "pass_forward",
		"tendency_own_team": "sit_central",
		"tendency_opponent": "press_win_ball",
	})
	_add("keeper", {
		"name": "Keeper",
		"zone": "goal",
		"tier": "base",
		"primary_stats": ["strength", "defense"],
		"identity": "Last line of defense",
		"tendency_with_ball": "distribute_quickly",
		"tendency_own_team": "stay_in_goal",
		"tendency_opponent": "stay_in_goal",
	})

	# ── 12 Hybrid Positions (3 primary stats) ──────────────────────────────
	_add("false_nine", {
		"name": "False Nine",
		"zone": "attack",
		"tier": "hybrid",
		"primary_stats": ["shooting", "chaos", "strength"],
		"identity": "Drops deep, holds ball, unpredictable",
		"tendency_with_ball": "drop_deep_hold_create",
		"tendency_own_team": "pull_defenders_out",
		"tendency_opponent": "press_from_front",
	})
	_add("attacking_mid", {
		"name": "Attacking Mid",
		"zone": "midfield",
		"tier": "hybrid",
		"primary_stats": ["shooting", "speed", "defense"],
		"identity": "Complete player, scores and tracks back",
		"tendency_with_ball": "shoot_from_distance",
		"tendency_own_team": "push_attacking_third",
		"tendency_opponent": "track_back_reluctant",
	})
	_add("sweeper", {
		"name": "Sweeper",
		"zone": "defense",
		"tier": "hybrid",
		"primary_stats": ["defense", "strength", "speed"],
		"identity": "Last line, intercepts everything",
		"tendency_with_ball": "clear_to_safety",
		"tendency_own_team": "cover_behind_defense",
		"tendency_opponent": "intercept_through_balls",
	})
	_add("target_man", {
		"name": "Target Man",
		"zone": "attack",
		"tier": "hybrid",
		"primary_stats": ["shooting", "strength", "health"],
		"identity": "Tank, holds ball up, wins headers",
		"tendency_with_ball": "hold_up_lay_off",
		"tendency_own_team": "post_up_near_goal",
		"tendency_opponent": "minimal_pressing",
	})
	_add("box_to_box", {
		"name": "Box-to-Box",
		"zone": "midfield",
		"tier": "hybrid",
		"primary_stats": ["defense", "speed", "health"],
		"identity": "Tireless, covers the whole pitch",
		"tendency_with_ball": "simple_forward_pass",
		"tendency_own_team": "fill_gaps",
		"tendency_opponent": "cover_everywhere",
	})
	_add("playmaker", {
		"name": "Playmaker",
		"zone": "midfield",
		"tier": "hybrid",
		"primary_stats": ["chaos", "speed", "shooting"],
		"identity": "Creative genius, occasional disaster",
		"tendency_with_ball": "through_ball_creative",
		"tendency_own_team": "roam_find_space",
		"tendency_opponent": "avoid_defending",
	})
	_add("enforcer", {
		"name": "Enforcer",
		"zone": "defense",
		"tier": "hybrid",
		"primary_stats": ["defense", "strength", "chaos"],
		"identity": "Dirty tackles, intimidation, red card risk",
		"tendency_with_ball": "simple_pass_clear",
		"tendency_own_team": "track_best_player",
		"tendency_opponent": "hard_tackle_foul_risk",
	})
	_add("shadow_striker", {
		"name": "Shadow Striker",
		"zone": "attack",
		"tier": "hybrid",
		"primary_stats": ["shooting", "chaos", "health"],
		"identity": "Lurks, appears from nowhere, survives deep into runs",
		"tendency_with_ball": "quick_shot_first_time",
		"tendency_own_team": "drift_blind_spots",
		"tendency_opponent": "appear_after_rebounds",
	})
	_add("wing_back", {
		"name": "Wing-Back",
		"zone": "defense",
		"tier": "hybrid",
		"primary_stats": ["speed", "defense", "health"],
		"identity": "Attacks and defends the flank endlessly",
		"tendency_with_ball": "overlap_cross",
		"tendency_own_team": "overlap_flank",
		"tendency_opponent": "sprint_back_defend",
	})
	_add("anchor", {
		"name": "Anchor",
		"zone": "defense",
		"tier": "hybrid",
		"primary_stats": ["defense", "strength", "health"],
		"identity": "Immovable wall, never injured",
		"tendency_with_ball": "clear_danger",
		"tendency_own_team": "block_central",
		"tendency_opponent": "block_central",
	})
	_add("poacher", {
		"name": "Poacher",
		"zone": "attack",
		"tier": "hybrid",
		"primary_stats": ["shooting", "strength", "chaos"],
		"identity": "Ugly goals, rebounds, bulldozes keepers",
		"tendency_with_ball": "tap_in_rebound",
		"tendency_own_team": "lurk_last_defender",
		"tendency_opponent": "dont_press",
	})
	_add("trequartista", {
		"name": "Trequartista",
		"zone": "midfield",
		"tier": "hybrid",
		"primary_stats": ["shooting", "speed", "chaos"],
		"identity": "Pure flair, zero defensive effort",
		"tendency_with_ball": "dribble_shoot_flair",
		"tendency_own_team": "float_between_lines",
		"tendency_opponent": "dont_defend",
	})

static func _add(key: String, data: Dictionary) -> void:
	data["key"] = key
	_positions[key] = data

# ── Public API ───────────────────────────────────────────────────────────────

static func get_position(key: String) -> Dictionary:
	_ensure_init()
	return _positions.get(key, {})

static func get_all_keys() -> Array:
	_ensure_init()
	return _positions.keys()

static func get_base_keys() -> Array:
	_ensure_init()
	return _positions.keys().filter(func(k): return _positions[k]["tier"] == "base")

static func get_hybrid_keys() -> Array:
	_ensure_init()
	return _positions.keys().filter(func(k): return _positions[k]["tier"] == "hybrid")

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
# Roaming rectangles per position: {x_min, x_max, y_min, y_max}
# Defined for HOME team (attacking right). Flip x for away team.
# Flanked positions use "flank_left" / "flank_right" variants.

static var _zone_rects: Dictionary = {}
static var _zone_rects_init: bool = false

static func _ensure_zones() -> void:
	if _zone_rects_init:
		return
	_zone_rects_init = true

	# format: "key": { "in": [x_min, x_max, y_min, y_max], "out": [...] }
	_zone_rects = {
		# -- Base --
		"keeper":     { "in": [0.02, 0.12, 0.30, 0.70], "out": [0.02, 0.08, 0.25, 0.75] },
		"striker":    { "in": [0.50, 0.92, 0.15, 0.85], "out": [0.40, 0.65, 0.20, 0.80] },
		"midfielder": { "in": [0.25, 0.60, 0.15, 0.85], "out": [0.18, 0.45, 0.15, 0.85] },
		# Winger: flanked - y range depends on which side
		"winger_left":  { "in": [0.35, 0.85, 0.05, 0.35], "out": [0.25, 0.55, 0.05, 0.35] },
		"winger_right": { "in": [0.35, 0.85, 0.65, 0.95], "out": [0.25, 0.55, 0.65, 0.95] },
		# -- Hybrid --
		"false_nine":   { "in": [0.35, 0.85, 0.15, 0.85], "out": [0.35, 0.60, 0.20, 0.80] },
		"attacking_mid": { "in": [0.30, 0.80, 0.15, 0.85], "out": [0.20, 0.55, 0.15, 0.85] },
		"sweeper":      { "in": [0.10, 0.35, 0.15, 0.85], "out": [0.06, 0.25, 0.15, 0.85] },
		"target_man":   { "in": [0.55, 0.92, 0.25, 0.75], "out": [0.42, 0.65, 0.25, 0.75] },
		"box_to_box":   { "in": [0.15, 0.75, 0.10, 0.90], "out": [0.10, 0.55, 0.10, 0.90] },
		"playmaker":    { "in": [0.25, 0.80, 0.10, 0.90], "out": [0.20, 0.50, 0.15, 0.85] },
		"enforcer":     { "in": [0.12, 0.40, 0.15, 0.85], "out": [0.08, 0.30, 0.15, 0.85] },
		"shadow_striker": { "in": [0.45, 0.90, 0.10, 0.90], "out": [0.38, 0.60, 0.15, 0.85] },
		"anchor":       { "in": [0.10, 0.35, 0.25, 0.75], "out": [0.06, 0.28, 0.20, 0.80] },
		"poacher":      { "in": [0.60, 0.95, 0.20, 0.80], "out": [0.45, 0.65, 0.25, 0.75] },
		"trequartista": { "in": [0.30, 0.85, 0.10, 0.90], "out": [0.25, 0.50, 0.15, 0.85] },
		# Wing-back: flanked
		"wing_back_left":  { "in": [0.10, 0.70, 0.05, 0.35], "out": [0.06, 0.30, 0.05, 0.35] },
		"wing_back_right": { "in": [0.10, 0.70, 0.65, 0.95], "out": [0.06, 0.30, 0.65, 0.95] },
		# Generic defender (for positions not in this list)
		"_default":     { "in": [0.15, 0.45, 0.10, 0.90], "out": [0.08, 0.30, 0.10, 0.90] },
	}

static func get_zone_rect(position_key: String, in_possession: bool, is_left_flank: bool = false) -> Array:
	## Returns [x_min, x_max, y_min, y_max] for the given position and game phase.
	## For HOME team perspective. Caller must flip for away team.
	_ensure_zones()
	var lookup_key: String = position_key

	# Handle flanked positions
	if position_key == "winger":
		lookup_key = "winger_left" if is_left_flank else "winger_right"
	elif position_key == "wing_back":
		lookup_key = "wing_back_left" if is_left_flank else "wing_back_right"

	var entry: Dictionary = _zone_rects.get(lookup_key, _zone_rects["_default"])
	return entry["in"] if in_possession else entry["out"]

static func get_zone_rect_flipped(position_key: String, in_possession: bool, is_home: bool, is_left_flank: bool = false) -> Array:
	## Returns zone rect adjusted for team side. Away team gets x flipped.
	var rect: Array = get_zone_rect(position_key, in_possession, is_left_flank)
	if is_home:
		return rect
	else:
		# Flip x: 0.1 becomes 0.9, 0.9 becomes 0.1
		return [1.0 - rect[1], 1.0 - rect[0], rect[2], rect[3]]
