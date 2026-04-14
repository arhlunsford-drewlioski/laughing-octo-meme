class_name MatchDirector
extends RefCounted
## Interprets raw sim state into higher-level match phases and commentary beats.

enum Phase {
	KICKOFF,
	BUILD_UP,
	ATTACK,
	PRESSURE,
	COUNTER,
	SET_PIECE,
	SCRAMBLE,
	SPELL_CHAOS,
	BIG_CHANCE,
}

const COUNTER_DURATION_TICKS: int = 12
const SET_PIECE_DURATION_TICKS: int = 10
const SPELL_DURATION_TICKS: int = 9
const BIG_CHANCE_DURATION_TICKS: int = 7
const LOG_COOLDOWN_TICKS: int = 10

var _phase: int = Phase.KICKOFF
var _phase_team: String = ""
var _ticks: int = 0
var _last_log_tick: int = -LOG_COOLDOWN_TICKS
var _last_owner_team: String = ""

var _counter_ticks: int = 0
var _counter_team: String = ""
var _set_piece_ticks: int = 0
var _set_piece_team: String = ""
var _spell_ticks: int = 0
var _big_chance_ticks: int = 0
var _big_chance_team: String = ""

func reset() -> void:
	_phase = Phase.KICKOFF
	_phase_team = ""
	_ticks = 0
	_last_log_tick = -LOG_COOLDOWN_TICKS
	_last_owner_team = ""
	_counter_ticks = 0
	_counter_team = ""
	_set_piece_ticks = 0
	_set_piece_team = ""
	_spell_ticks = 0
	_big_chance_ticks = 0
	_big_chance_team = ""

func update(snapshot: Dictionary) -> Dictionary:
	_ticks += 1

	var team_lookup: Dictionary = _build_team_lookup(snapshot)
	var owner_team: String = _extract_owner_team(snapshot, team_lookup)
	if owner_team != "" and owner_team != _last_owner_team:
		_counter_ticks = COUNTER_DURATION_TICKS
		_counter_team = owner_team
	_last_owner_team = owner_team

	var events: Array = snapshot.get("events", [])
	_consume_events(events, team_lookup, owner_team)

	var next_phase: int = _classify_phase(snapshot, owner_team)
	var next_team: String = _classify_team(owner_team)
	var log_lines: Array[String] = _phase_change_lines(next_phase, next_team)
	var phase_label: String = _phase_label(next_phase, next_team)

	_decay_timers()

	return {
		"phase": next_phase,
		"team": next_team,
		"phase_label": phase_label,
		"log_lines": log_lines,
	}

func _consume_events(events: Array, team_lookup: Dictionary, owner_team: String) -> void:
	for event in events:
		var etype: String = str(event.get("type", ""))
		match etype:
			"goal", "shot", "save", "miss", "post", "block":
				_big_chance_ticks = BIG_CHANCE_DURATION_TICKS
				_big_chance_team = _team_for_event(event, team_lookup, owner_team)
			"corner_awarded":
				_set_piece_ticks = SET_PIECE_DURATION_TICKS
				_set_piece_team = str(event.get("team", owner_team))
			"foul":
				_set_piece_ticks = SET_PIECE_DURATION_TICKS
				_set_piece_team = owner_team
			"fireball", "haste", "multiball", "dark_surge", "shadow_wall", "hex", "blood_pact", "frenzy", "curse_of_post", "curse_triggered":
				_spell_ticks = SPELL_DURATION_TICKS

func _classify_phase(snapshot: Dictionary, owner_team: String) -> int:
	var ball_data: Dictionary = snapshot.get("ball", {})
	var ball_state: String = str(ball_data.get("state", "DEAD"))
	var ball_x: float = float(ball_data.get("x", 0.5))

	if _spell_ticks > 0:
		return Phase.SPELL_CHAOS
	if _big_chance_ticks > 0:
		return Phase.BIG_CHANCE
	if _set_piece_ticks > 0:
		return Phase.SET_PIECE
	if ball_state != "CONTROLLED" or owner_team == "":
		return Phase.SCRAMBLE

	var in_attacking_half: bool = (owner_team == "home" and ball_x > 0.54) or (owner_team == "away" and ball_x < 0.46)
	var in_final_third: bool = (owner_team == "home" and ball_x > 0.72) or (owner_team == "away" and ball_x < 0.28)

	if _counter_ticks > 0 and owner_team == _counter_team and in_attacking_half:
		return Phase.COUNTER
	if in_final_third:
		return Phase.PRESSURE
	if in_attacking_half:
		return Phase.ATTACK
	return Phase.BUILD_UP

func _classify_team(owner_team: String) -> String:
	match _classify_team_source():
		"big_chance":
			return _big_chance_team
		"set_piece":
			return _set_piece_team
		"counter":
			return _counter_team
		_:
			return owner_team

func _classify_team_source() -> String:
	if _spell_ticks > 0:
		return "spell"
	if _big_chance_ticks > 0:
		return "big_chance"
	if _set_piece_ticks > 0:
		return "set_piece"
	if _counter_ticks > 0:
		return "counter"
	return "owner"

func _phase_change_lines(next_phase: int, next_team: String) -> Array[String]:
	var lines: Array[String] = []
	if next_phase == _phase and next_team == _phase_team:
		return lines
	if _ticks > 1 and _should_log(next_phase):
		var line: String = _phase_line(next_phase, next_team)
		if line != "":
			lines.append(line)
			_last_log_tick = _ticks
	_phase = next_phase
	_phase_team = next_team
	return lines

func _should_log(next_phase: int) -> bool:
	if next_phase in [Phase.COUNTER, Phase.PRESSURE, Phase.SET_PIECE, Phase.SPELL_CHAOS, Phase.BIG_CHANCE]:
		return true
	return _ticks - _last_log_tick >= LOG_COOLDOWN_TICKS

func _phase_line(phase: int, team: String) -> String:
	var team_name: String = _team_name(team)
	match phase:
		Phase.BUILD_UP:
			return "[color=#9fb3c8]%s settle into build-up.[/color]" % team_name
		Phase.ATTACK:
			return "[color=#d9d39b]%s work the ball into attack.[/color]" % team_name
		Phase.PRESSURE:
			return "[color=#ffd966][b]%s pin them back.[/b][/color]" % team_name
		Phase.COUNTER:
			return "[color=#ffb347][b]%s break at speed![/b][/color]" % team_name
		Phase.SET_PIECE:
			return "[color=#98d37f]%s have a set-piece chance.[/color]" % team_name
		Phase.SPELL_CHAOS:
			return "[color=#cf9cff][b]The match warps under dark magic![/b][/color]"
		Phase.BIG_CHANCE:
			return "[color=#fff19a][b]Big chance for %s![/b][/color]" % team_name
	return ""

func _phase_label(phase: int, team: String) -> String:
	var team_name: String = _team_prefix(team)
	match phase:
		Phase.KICKOFF:
			return "KICK OFF"
		Phase.BUILD_UP:
			return ("%s BUILD-UP" % team_name) if team_name != "" else "BUILD-UP"
		Phase.ATTACK:
			return ("%s ATTACK" % team_name) if team_name != "" else "ATTACK"
		Phase.PRESSURE:
			return ("%s PRESSURE" % team_name) if team_name != "" else "PRESSURE"
		Phase.COUNTER:
			return ("%s COUNTER" % team_name) if team_name != "" else "COUNTER"
		Phase.SET_PIECE:
			return ("%s SET PIECE" % team_name) if team_name != "" else "SET PIECE"
		Phase.SCRAMBLE:
			return "SCRAMBLE"
		Phase.SPELL_CHAOS:
			return "SPELL CHAOS"
		Phase.BIG_CHANCE:
			return ("%s CHANCE" % team_name) if team_name != "" else "BIG CHANCE"
	return ""

func _build_team_lookup(snapshot: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	var goblins: Array = snapshot.get("goblins", [])
	for entry in goblins:
		lookup[str(entry.get("name", ""))] = str(entry.get("team", ""))
	return lookup

func _extract_owner_team(snapshot: Dictionary, team_lookup: Dictionary) -> String:
	var ball_data: Dictionary = snapshot.get("ball", {})
	var owner_name: String = str(ball_data.get("owner_name", ""))
	if owner_name != "" and team_lookup.has(owner_name):
		return str(team_lookup[owner_name])
	for entry in snapshot.get("goblins", []):
		if bool(entry.get("has_ball", false)):
			return str(entry.get("team", ""))
	return ""

func _team_for_event(event: Dictionary, team_lookup: Dictionary, owner_team: String) -> String:
	for key in ["goblin", "shooter", "keeper", "from", "winner"]:
		var name: String = str(event.get(key, ""))
		if name != "" and team_lookup.has(name):
			return str(team_lookup[name])
	var event_team: String = str(event.get("team", ""))
	if event_team != "":
		return event_team
	return owner_team

func _team_name(team: String) -> String:
	if team == "":
		return "BOTH SIDES"
	if team == "away":
		return "AWAY"
	return "HOME"

func _team_prefix(team: String) -> String:
	if team == "":
		return ""
	return _team_name(team)

func _decay_timers() -> void:
	_counter_ticks = maxi(0, _counter_ticks - 1)
	_set_piece_ticks = maxi(0, _set_piece_ticks - 1)
	_spell_ticks = maxi(0, _spell_ticks - 1)
	_big_chance_ticks = maxi(0, _big_chance_ticks - 1)
