extends Control
## Watches a MatchSimulation play out visually on the AnimatedPitch.

const MatchDirectorClass = preload("res://scripts/match_director.gd")

@onready var animated_pitch: Control = %AnimatedPitch
@onready var score_label: Label = %ScoreLabel
@onready var clock_label: Label = %ClockLabel
@onready var speed_btn: Button = %SpeedBtn
@onready var event_log: RichTextLabel = %EventLog
@onready var back_btn: Button = %BackBtn

var sim: MatchSimulation
var home_formation: Formation
var away_formation: Formation
var _director: RefCounted
var _director_phase_label: String = ""

var _tick_accumulator: float = 0.0
var _speed_multiplier: float = 0.6
const SPEED_OPTIONS := [0.6, 1.0, 1.5, 2.0, 4.0]
var _speed_index: int = 0

# Spell system
var _spell_system: SpellSystem
var _spell_buttons: Array[Button] = []
var _mana_label: RichTextLabel
var _spell_container: HBoxContainer
var _targeting_spell_index: int = -1  # Which hand index is being targeted
var _targeting_mode: String = ""       # "pitch", "ally", "enemy"
var _paused: bool = false

# Wobble aiming
var _wobble_active: bool = false
var _wobble_x: float = 0.5
var _wobble_y: float = 0.5
var _wobble_time: float = 0.0
var _wobble_intensity: float = 0.06  # how much the reticle drifts

# Opponent casting UI
var _counter_btn: Button = null
var _opponent_cast_label: Label = null

# Possession tracking
var _home_possession_ticks: int = 0
var _away_possession_ticks: int = 0
var _last_ball_owner_team: String = ""

# Performance tracking for XP (keyed by goblin name)
var _perf: Dictionary = {}
var _last_passer_to: Dictionary = {}

# XP awards
const XP_PLAYED: int = 10
const XP_GOAL: int = 30
const XP_ASSIST: int = 20
const XP_TACKLE: int = 5
const XP_TAKE_ON: int = 5
const XP_INTERCEPTION: int = 10
const XP_SAVE: int = 10

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	speed_btn.pressed.connect(_cycle_speed)

	UITheme.style_button(back_btn, false)
	UITheme.style_button(speed_btn, false)
	score_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	clock_label.add_theme_color_override("font_color", UITheme.CREAM)
	speed_btn.text = _speed_text()

	# Build spell UI in the bottom bar
	var bottom_bar: HBoxContainer = %EventLog.get_parent()

	# Mana display
	_mana_label = RichTextLabel.new()
	_mana_label.bbcode_enabled = true
	_mana_label.fit_content = true
	_mana_label.custom_minimum_size = Vector2(40, 0)
	_mana_label.scroll_active = false
	_mana_label.add_theme_font_size_override("normal_font_size", 18)
	bottom_bar.add_child(_mana_label)
	bottom_bar.move_child(_mana_label, 0)

	# Spell hand container
	_spell_container = HBoxContainer.new()
	_spell_container.add_theme_constant_override("separation", 4)
	bottom_bar.add_child(_spell_container)
	bottom_bar.move_child(_spell_container, 1)

	# Counter-spell button (hidden until opponent starts casting)
	_counter_btn = Button.new()
	_counter_btn.text = "COUNTER! (1)"
	_counter_btn.custom_minimum_size = Vector2(120, 40)
	_counter_btn.add_theme_font_size_override("font_size", 16)
	_counter_btn.visible = false
	var counter_style := StyleBoxFlat.new()
	counter_style.bg_color = Color(0.6, 0.1, 0.1)
	counter_style.corner_radius_top_left = 6
	counter_style.corner_radius_top_right = 6
	counter_style.corner_radius_bottom_left = 6
	counter_style.corner_radius_bottom_right = 6
	_counter_btn.add_theme_stylebox_override("normal", counter_style)
	_counter_btn.add_theme_color_override("font_color", Color.WHITE)
	_counter_btn.pressed.connect(_on_counter_pressed)
	bottom_bar.add_child(_counter_btn)

	# Opponent cast label (shows what they're casting)
	_opponent_cast_label = Label.new()
	_opponent_cast_label.text = ""
	_opponent_cast_label.add_theme_font_size_override("font_size", 18)
	_opponent_cast_label.add_theme_color_override("font_color", UITheme.RED)
	_opponent_cast_label.visible = false
	add_child(_opponent_cast_label)
	_opponent_cast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_opponent_cast_label.position.y = 60

	animated_pitch.pitch_clicked.connect(_on_pitch_clicked)

	_setup_and_start()

func _setup_and_start() -> void:
	var player_roster: Array[GoblinData]
	var opponent_roster: Array[GoblinData]

	if RunManager.run_active:
		player_roster = GameManager.selected_roster.slice(0, 6)
		opponent_roster = RunManager.get_current_opponent_roster()
	else:
		player_roster = GoblinDatabase.full_roster().slice(0, 6)
		opponent_roster = GoblinDatabase.opponent_roster()

	home_formation = GoblinDatabase.build_default_formation(player_roster)
	away_formation = GoblinDatabase.build_default_formation(opponent_roster)

	# Init performance tracking for player goblins
	for g in player_roster:
		_perf[g.goblin_name] = {"goals": 0, "assists": 0, "tackles": 0, "take_ons": 0, "interceptions": 0, "saves": 0}

	# Init spell system
	_spell_system = SpellSystem.new()
	var spell_deck: Array[SpellData]
	if RunManager.run_active and RunManager.run_spell_deck.size() > 0:
		spell_deck = RunManager.run_spell_deck
	else:
		spell_deck = SpellDatabase.starter_deck()
	_spell_system.setup(spell_deck)
	_build_spell_hand_ui()
	_refresh_mana()

	await animated_pitch.setup(home_formation, away_formation)

	sim = MatchSimulation.new()
	sim.is_shielded = func(g: GoblinData) -> bool: return _spell_system.is_goblin_shielded(g)
	_director = MatchDirectorClass.new()
	_director.reset()
	var snapshot := sim.start_match(home_formation, away_formation)
	animated_pitch.apply_snapshot(snapshot)
	_apply_director(snapshot)
	_update_ui(snapshot)

	if RunManager.run_active:
		var opp_name := RunManager.get_current_opponent_name()
		var stage := RunManager.get_stage_name()
		_log("[color=yellow]%s - vs %s[/color]" % [stage, opp_name])
	_log("[color=yellow]KICK OFF[/color]")

func _process(delta: float) -> void:
	if sim == null or sim.is_match_over():
		return

	# Wobble aiming update (runs even when paused for targeting)
	if _wobble_active:
		_wobble_time += delta * 3.0
		_wobble_x += sin(_wobble_time * 2.7) * _wobble_intensity * delta * 2.0
		_wobble_y += cos(_wobble_time * 3.1) * _wobble_intensity * delta * 2.0
		_wobble_x = clampf(_wobble_x, 0.05, 0.95)
		_wobble_y = clampf(_wobble_y, 0.08, 0.92)
		animated_pitch.set_wobble_reticle(_wobble_x, _wobble_y)

	if _paused:
		return

	_tick_accumulator += delta * _speed_multiplier
	var tick_interval: float = 1.0 / MatchSimulation.TICKS_PER_SECOND

	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval

		# Tick spell system (mana regen, shields, opponent AI)
		_spell_system.tick()
		_spell_system.try_opponent_cast(home_formation, away_formation, sim.goblin_states)
		_check_opponent_cast_fired()

		var snapshot := sim.tick()
		animated_pitch.apply_snapshot(snapshot)
		_apply_director(snapshot)
		_process_events(snapshot)
		_update_ui(snapshot)
		_update_sorcerer_ui()
		_check_halftime(snapshot)

		if sim.is_match_over():
			_on_match_over(snapshot)
			break

# ── Spell Hand UI ──────────────────────────────────────────────────────────

func _build_spell_hand_ui() -> void:
	for child in _spell_container.get_children():
		child.queue_free()
	_spell_buttons.clear()

	for i in range(_spell_system.hand.size()):
		var spell: SpellData = _spell_system.hand[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 0)
		btn.add_theme_font_size_override("font_size", 13)
		_update_spell_button(btn, spell, i)
		btn.pressed.connect(_on_spell_pressed.bind(i))
		_spell_container.add_child(btn)
		_spell_buttons.append(btn)

func _update_spell_button(btn: Button, spell: SpellData, index: int) -> void:
	btn.text = "%s (%d)" % [spell.spell_name, spell.mana_cost]
	var can_afford := _spell_system.can_cast(index)
	btn.disabled = not can_afford
	var spell_color := _get_spell_color(spell)
	UITheme.style_button(btn, can_afford)
	btn.add_theme_color_override("font_color", spell_color)
	btn.add_theme_color_override("font_hover_color", spell_color.lightened(0.3))

func _refresh_spell_buttons() -> void:
	for i in range(_spell_buttons.size()):
		if i < _spell_system.hand.size():
			_update_spell_button(_spell_buttons[i], _spell_system.hand[i], i)

func _refresh_mana() -> void:
	var mana_int: int = int(_spell_system.mana)
	var mana_max: int = int(SpellSystem.MAX_MANA)
	_mana_label.text = ""
	_mana_label.append_text("[color=#4d99ff]%d[/color][color=#666688]/%d[/color]" % [mana_int, mana_max])

func _get_spell_color(spell: SpellData) -> Color:
	match spell.special_effect:
		"fireball":
			return Color(1.0, 0.4, 0.1)
		"shield_dome":
			return Color(0.3, 0.8, 1.0)
		"counter_spell":
			return Color(0.9, 0.2, 0.9)
		"haste":
			return Color(0.3, 1.0, 0.4)
		"shadow_wall":
			return Color(0.4, 0.5, 0.9)
		"hex":
			return Color(0.7, 0.2, 0.8)
		"blood_pact":
			return Color(0.9, 0.1, 0.2)
		"frenzy":
			return Color(1.0, 0.3, 0.3)
		"curse_of_post":
			return Color(0.6, 0.4, 0.7)
		_:
			# Dark Surge or others without special_effect
			if spell.stat_modifiers.has("shooting") and spell.stat_modifiers["shooting"] > 0:
				return Color(1.0, 0.6, 0.1)
			return UITheme.CREAM

func _on_spell_pressed(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= _spell_system.hand.size():
		return
	if not _spell_system.can_cast(hand_index):
		return

	# If already targeting, cancel
	if _targeting_spell_index >= 0:
		_cancel_targeting()

	var spell: SpellData = _spell_system.hand[hand_index]

	# Special spells get special targeting
	match spell.special_effect:
		"fireball":
			_start_wobble_targeting(hand_index)
		"shield_dome":
			_start_targeting(hand_index, "ally")
		"counter_spell":
			# Counter is handled by the counter button, not the spell hand
			_cast_spell_immediate(hand_index)
		_:
			# Default: check target type
			match spell.target_type:
				SpellData.TargetType.ALLY:
					_start_targeting(hand_index, "ally")
				SpellData.TargetType.ENEMY:
					_start_targeting(hand_index, "enemy")
				_:
					_cast_spell_immediate(hand_index)

func _start_targeting(hand_index: int, mode: String) -> void:
	_targeting_spell_index = hand_index
	_targeting_mode = mode
	_paused = true
	animated_pitch._targeting_active = true
	var spell: SpellData = _spell_system.hand[hand_index]

	match mode:
		"ally":
			_log("[color=#33ff55]Click one of your goblins to cast %s![/color]" % spell.spell_name)
		"enemy":
			_log("[color=#cc33ff]Click an enemy goblin to cast %s![/color]" % spell.spell_name)

	# Update button to show CANCEL
	if hand_index < _spell_buttons.size():
		_spell_buttons[hand_index].text = "CANCEL"

func _start_wobble_targeting(hand_index: int) -> void:
	## Start wobble aiming for AoE spells (Fireball, Meteor, etc.)
	_targeting_spell_index = hand_index
	_targeting_mode = "wobble"
	_paused = true
	_wobble_active = true
	_wobble_x = 0.5
	_wobble_y = 0.5
	_wobble_time = randf() * 10.0  # random start phase
	animated_pitch._targeting_active = true
	_log("[color=#ff6600][b]AIMING! Tap to fire at the wobbling reticle![/b][/color]")
	if hand_index < _spell_buttons.size():
		_spell_buttons[hand_index].text = "CANCEL"

func _cancel_targeting() -> void:
	_targeting_spell_index = -1
	_targeting_mode = ""
	_paused = false
	_wobble_active = false
	animated_pitch._targeting_active = false
	animated_pitch.clear_wobble_reticle()
	_refresh_spell_buttons()

func _on_counter_pressed() -> void:
	## Player presses counter-spell during opponent wind-up
	if _spell_system.counter_opponent_cast():
		_log("[color=#ff00ff][b]COUNTER SPELL! You cancel their magic![/b][/color]")
		_update_sorcerer_ui()
	else:
		_log("[color=#aaaaaa]Can't counter right now.[/color]")

func _check_opponent_cast_fired() -> void:
	## Check if opponent's wind-up completed and fire their spell
	if not _spell_system.opponent_casting:
		return
	if _spell_system.opponent_cast_progress < 1.0:
		return
	# Wind-up complete - fire the spell!
	var spell: SpellData = _spell_system.opponent_cast_spell
	_spell_system.opponent_casting = false
	_spell_system.opponent_cast_spell = null
	_spell_system.opponent_cast_progress = 0.0
	if spell == null:
		return
	var tx: float = _spell_system.opponent_cast_target_x
	var ty: float = _spell_system.opponent_cast_target_y
	match spell.special_effect:
		"fireball":
			sim.cast_fireball(1, tx, ty)
			_log("[color=#ff4400][b]ENEMY FIREBALL! Impact at the pitch![/b][/color]")
			animated_pitch.play_fireball_explosion(tx, ty)
		"shield_dome":
			# Shield a random away goblin
			var away_goblins: Array = away_formation.get_all()
			if not away_goblins.is_empty():
				var target: GoblinData = away_goblins[randi() % away_goblins.size()]
				_spell_system.apply_shield(target)
				_log("[color=#33ccff][b]ENEMY SHIELD DOME on %s![/b][/color]" % target.goblin_name)
		"haste":
			sim.cast_haste(1)
			_log("[color=#33ff55][b]ENEMY HASTE! Their goblins surge![/b][/color]")
		_:
			_log("[color=#ff6600]Enemy casts %s![/color]" % spell.spell_name)

func _update_sorcerer_ui() -> void:
	## Update opponent casting display, counter button, shield visuals
	if _spell_system.opponent_casting:
		_opponent_cast_label.visible = true
		var spell_name: String = _spell_system.opponent_cast_spell.spell_name if _spell_system.opponent_cast_spell else "???"
		var pct: int = int(_spell_system.opponent_cast_progress * 100)
		_opponent_cast_label.text = "OPPONENT CASTING: %s [%d%%]" % [spell_name.to_upper(), pct]
		_counter_btn.visible = _spell_system.mana >= 1.0
	else:
		_opponent_cast_label.visible = false
		_counter_btn.visible = false

	# Sync shield dome visuals
	animated_pitch._shielded_tokens = _spell_system.shielded_goblins.duplicate()
	animated_pitch.queue_redraw()

	_refresh_mana()

func _cast_spell_immediate(hand_index: int) -> void:
	var spell := _spell_system.cast(hand_index)
	if spell == null:
		return

	match spell.special_effect:
		"curse_of_post":
			sim.cast_curse_of_post(0)
		_:
			# Generic: apply stat_modifiers to all allies or all enemies
			if not spell.stat_modifiers.is_empty():
				var duration_ticks: int = int(spell.duration * MatchSimulation.TICKS_PER_SECOND) if spell.duration > 0.0 else 0
				var source: String = spell.special_effect if spell.special_effect != "" else spell.spell_name.to_lower().replace(" ", "_")
				var target_formation: Formation
				if spell.target_type == SpellData.TargetType.ALL_ENEMIES:
					target_formation = away_formation
				else:
					target_formation = home_formation
				for goblin in target_formation.get_all():
					if sim.goblin_states.has(goblin):
						for stat_name in spell.stat_modifiers:
							sim._apply_buff(goblin, stat_name, int(spell.stat_modifiers[stat_name]), duration_ticks, source)
				_log("[color=#ffcc33][b]%s cast![/b][/color]" % spell.spell_name)

	var snapshot := sim._build_snapshot()
	_apply_director(snapshot)
	_process_events(snapshot)
	_post_cast_cleanup(hand_index)

func _cast_spell_targeted(hand_index: int, target: GoblinData) -> void:
	var spell := _spell_system.cast(hand_index)
	if spell == null:
		return

	# Handle special effects first, then fall through to generic buff
	match spell.special_effect:
		"shield_dome":
			_spell_system.apply_shield(target)
			_log("[color=#33ccff][b]SHIELD DOME! %s is invincible![/b][/color]" % target.goblin_name)
		"hex":
			sim.cast_hex(0, target)
		"blood_pact":
			sim.cast_blood_pact(0, target)
			_spell_system.blood_pact_targets.append(target)
		"dark_ascension":
			_spell_system.dark_ascension_targets.append(target)
			_log("[color=#ff00ff][b]DARK ASCENSION! %s transcends... but at what cost?[/b][/color]" % target.goblin_name)
		_:
			# Generic: apply all stat_modifiers as buffs to the target
			var duration_ticks: int = int(spell.duration * MatchSimulation.TICKS_PER_SECOND) if spell.duration > 0.0 else 0
			var source: String = spell.special_effect if spell.special_effect != "" else spell.spell_name.to_lower().replace(" ", "_")
			for stat_name in spell.stat_modifiers:
				sim._apply_buff(target, stat_name, int(spell.stat_modifiers[stat_name]), duration_ticks, source)
			_log("[color=#ffcc33][b]%s cast on %s![/b][/color]" % [spell.spell_name, target.goblin_name])

	var snapshot := sim._build_snapshot()
	_apply_director(snapshot)
	_process_events(snapshot)
	_post_cast_cleanup(hand_index)

func _post_cast_cleanup(_hand_index: int) -> void:
	# Rebuild spell buttons since hand changed
	_build_spell_hand_ui()
	_refresh_mana()

func _on_pitch_clicked(pitch_x: float, pitch_y: float) -> void:
	if _targeting_spell_index < 0:
		return

	if _targeting_mode == "wobble":
		# Fireball fires at the WOBBLE position, not where you clicked
		var idx := _targeting_spell_index
		var fire_x: float = _wobble_x
		var fire_y: float = _wobble_y
		_cancel_targeting()
		var spell := _spell_system.cast(idx)
		if spell:
			sim.cast_fireball(0, fire_x, fire_y)
			_log("[color=#ff6600][b]FIREBALL! Impact at the pitch![/b][/color]")
			animated_pitch.play_fireball_explosion(fire_x, fire_y)
			var snapshot := sim._build_snapshot()
			_apply_director(snapshot)
			_process_events(snapshot)
			_post_cast_cleanup(idx)
	elif _targeting_mode == "ally" or _targeting_mode == "enemy":
		# Find nearest goblin to click
		var target := _find_nearest_goblin(pitch_x, pitch_y, _targeting_mode == "ally")
		if target:
			var idx := _targeting_spell_index
			_targeting_spell_index = -1
			_targeting_mode = ""
			_paused = false
			animated_pitch._targeting_active = false
			_cast_spell_targeted(idx, target)
		else:
			_log("[color=#aaaaaa]No valid target there. Click a goblin or press ESC to cancel.[/color]")

func _find_nearest_goblin(px: float, py: float, ally: bool) -> GoblinData:
	var formation: Formation = home_formation if ally else away_formation
	var best: GoblinData = null
	var best_dist: float = 0.15  # Max click distance (generous - tokens are big)
	for goblin in formation.get_all():
		if not sim.goblin_states.has(goblin):
			continue
		var gs: Dictionary = sim.goblin_states[goblin]
		var gx: float = float(gs["x"])
		var gy: float = float(gs["y"])
		var d: float = sqrt((gx - px) * (gx - px) + (gy - py) * (gy - py))
		if d < best_dist:
			best_dist = d
			best = goblin
	return best

func _apply_director(snapshot: Dictionary) -> void:
	if _director == null:
		return
	var direction: Dictionary = _director.update(snapshot)
	_director_phase_label = str(direction.get("phase_label", ""))
	for line in direction.get("log_lines", []):
		_log(str(line))

# ── Event Processing ──────────────────────────────────────────────────────

func _process_events(snapshot: Dictionary) -> void:
	var clock_min: int = int(snapshot["clock"])
	for event: Dictionary in snapshot["events"]:
		_track_perf(event)
		var etype: String = str(event["type"])
		match etype:
			# ── Big moments ──
			"goal":
				var sc: Array = event["score"]
				_log("[color=lime][b]%d' GOAL! %s! (%d-%d)[/b][/color]" % [clock_min, event["goblin"], sc[0], sc[1]])
				_flash_token(str(event["goblin"]), "goal")
			"shot":
				_log("[color=white]%d' Shot: %s[/color]" % [clock_min, event["goblin"]])
				_flash_token(str(event["goblin"]), "shot")
			"save":
				_log("[color=orange]%d' Save! %s stops %s[/color]" % [clock_min, event["keeper"], event["shooter"]])
				_flash_token(str(event["keeper"]), "save")
			"miss":
				_log("[color=gray]%d' Miss: %s fires wide[/color]" % [clock_min, event["goblin"]])
			"block":
				_log("[color=#b080ff]%d' Block! %s gets in the way[/color]" % [clock_min, event["goblin"]])
				_flash_token(str(event["goblin"]), "block")

			# ── Passing / build-up ──
			"pass":
				var to_name: String = str(event.get("to", ""))
				var from_name: String = str(event.get("from", ""))
				if to_name != "":
					_log("[color=#aaaaaa]%d' %s > %s[/color]" % [clock_min, from_name, to_name])
					animated_pitch.show_pass_line(from_name, to_name, Color(0.80, 0.86, 0.92, 0.55))
			"pass_received":
				var who: String = str(event.get("goblin", ""))
				if who != "":
					_flash_token(who, "pass")
			"cross":
				var who: String = str(event.get("goblin", ""))
				_log("[color=#aaddaa]%d' Cross: %s whips it in[/color]" % [clock_min, who])
				_flash_token(who, "cross")
			"kickoff_pass":
				var from_name: String = str(event.get("from", ""))
				var to_name: String = str(event.get("to", ""))
				_log("[color=yellow]%d' Kick off: %s > %s[/color]" % [clock_min, from_name, to_name])
				animated_pitch.show_pass_line(from_name, to_name, Color(1.0, 0.9, 0.35, 0.7))

			# ── Turnovers / drama ──
			"interception":
				var who: String = str(event.get("goblin", ""))
				var from_name: String = str(event.get("from", ""))
				_log("[color=#55ccff]%d' Intercepted! %s reads %s's pass[/color]" % [clock_min, who, from_name])
				_flash_token(who, "interception")
			"bad_touch":
				var who: String = str(event.get("goblin", ""))
				_log("[color=#cc8844]%d' Bad touch: %s loses control[/color]" % [clock_min, who])
				_flash_token(who, "bad_touch")
			"ball_recovery":
				var who: String = str(event.get("goblin", ""))
				_log("[color=#88bbbb]%d' %s recovers the ball[/color]" % [clock_min, who])
			"dispossessed":
				var who: String = str(event.get("goblin", ""))
				var by: String = str(event.get("by", ""))
				_log("[color=#cc8844]%d' %s dispossessed by %s![/color]" % [clock_min, who, by])
				_flash_token(who, "dispossessed")
				_flash_token(by, "tackle")

			# ── Tackles / fouls ──
			"tackle":
				_log("[color=silver]%d' Tackle: %s wins it from %s[/color]" % [clock_min, event["goblin"], event["victim"]])
				_flash_token(str(event["goblin"]), "tackle")
			"tackle_failed":
				_log("[color=#777777]%d' %s lunges in... misses![/color]" % [clock_min, event["goblin"]])
			"foul":
				_log("[color=red][b]%d' FOUL! %s on %s[/b][/color]" % [clock_min, event["goblin"], event["victim"]])
				_flash_token(str(event["goblin"]), "foul")

			# ── Dribbles / skill ──
			"take_on":
				var who: String = str(event.get("goblin", ""))
				var beaten: String = str(event.get("beaten", ""))
				_log("[color=#aaddff]%d' %s beats %s![/color]" % [clock_min, who, beaten])
				_flash_token(who, "take_on")
			"challenge":
				pass

			# ── Clearances / aerials ──
			"clearance":
				var who2: String = str(event.get("goblin", ""))
				_log("[color=#aaaaaa]%d' %s clears the danger[/color]" % [clock_min, who2])
			"aerial":
				var winner2: String = str(event.get("winner", ""))
				var loser: String = str(event.get("loser", ""))
				_log("[color=#bbbbdd]%d' Aerial duel: %s wins it over %s[/color]" % [clock_min, winner2, loser])

			# ── Keeper events ──
			"keeper_claim":
				var keeper2: String = str(event.get("keeper", ""))
				_log("[color=orange]%d' %s claims the ball[/color]" % [clock_min, keeper2])
				_flash_token(keeper2, "save")
			"keeper_punch":
				var keeper3: String = str(event.get("keeper", ""))
				_log("[color=orange]%d' %s punches it clear![/color]" % [clock_min, keeper3])
				_flash_token(keeper3, "save")

			# ── Set pieces ──
			"post":
				var who3: String = str(event.get("goblin", ""))
				_log("[color=yellow][b]%d' OFF THE POST! %s hits the frame[/b][/color]" % [clock_min, who3])
			"corner_awarded":
				var team2: String = str(event.get("team", ""))
				_log("[color=#aaddaa]%d' Corner to %s[/color]" % [clock_min, team2])
			"out":
				pass

			# ── Violence ──
			"injury":
				var who4: String = str(event.get("goblin", ""))
				var sev: String = str(event.get("severity", ""))
				var by2: String = str(event.get("by", ""))
				if sev == "minor":
					_log("[color=orange]%d' %s injured by %s (minor)[/color]" % [clock_min, who4, by2])
				elif sev == "major":
					_log("[color=red]%d' %s BADLY HURT by %s![/color]" % [clock_min, who4, by2])
				_flash_token(who4, "injury")
			"death":
				var who5: String = str(event.get("goblin", ""))
				var by3: String = str(event.get("by", ""))
				_log("[color=red][b]%d' %s KILLED by %s!!![/b][/color]" % [clock_min, who5, by3])
				_flash_token(who5, "death")
			"goblin_removed":
				var who6: String = str(event.get("goblin", ""))
				animated_pitch.remove_goblin_token(who6)
			"team_eliminated":
				var team3: String = str(event.get("team", ""))
				_log("[color=red][b]%s TEAM WIPED OUT![/b][/color]" % [team3.to_upper()])

			# ── Spell events ──
			"haste":
				_log("[color=#33ff55][b]%d' HASTE! Your goblins surge with speed![/b][/color]" % [clock_min])
			"haste_expired":
				_log("[color=#aaaaaa]%d' Haste wears off...[/color]" % [clock_min])
			"dark_surge":
				var ds_gob: String = str(event.get("goblin", ""))
				_log("[color=#ff9933][b]%d' DARK SURGE! %s's shooting is supercharged![/b][/color]" % [clock_min, ds_gob])
			"dark_surge_expired":
				var ds_gob2: String = str(event.get("goblin", ""))
				_log("[color=#aaaaaa]%d' Dark Surge fades from %s[/color]" % [clock_min, ds_gob2])
			"shadow_wall":
				_log("[color=#6677cc][b]%d' SHADOW WALL! Defenders harden![/b][/color]" % [clock_min])
			"shadow_wall_expired":
				_log("[color=#aaaaaa]%d' Shadow Wall crumbles...[/color]" % [clock_min])
			"hex":
				var hex_gob: String = str(event.get("goblin", ""))
				_log("[color=#bb44ee][b]%d' HEX! %s is cursed! -2 all stats![/b][/color]" % [clock_min, hex_gob])
			"hex_expired":
				var hex_gob2: String = str(event.get("goblin", ""))
				_log("[color=#aaaaaa]%d' Hex lifts from %s[/color]" % [clock_min, hex_gob2])
			"blood_pact":
				var bp_gob: String = str(event.get("goblin", ""))
				_log("[color=#ee2233][b]%d' BLOOD PACT! %s gains terrible power![/b][/color]" % [clock_min, bp_gob])
			"frenzy":
				_log("[color=#ff4444][b]%d' FRENZY! All goblins go berserk![/b][/color]" % [clock_min])
			"curse_of_post":
				_log("[color=#8866bb][b]%d' CURSE OF THE POST! The next opponent shot will fail![/b][/color]" % [clock_min])
			"curse_triggered":
				var ct_gob: String = str(event.get("goblin", ""))
				_log("[color=#8866bb]%d' The curse strikes! %s's shot is deflected![/color]" % [clock_min, ct_gob])

func _track_perf(event: Dictionary) -> void:
	var etype: String = str(event.get("type", ""))
	var gname: String = str(event.get("goblin", ""))
	match etype:
		"goal":
			if gname in _perf:
				_perf[gname]["goals"] += 1
				if gname in _last_passer_to and _last_passer_to[gname] in _perf:
					_perf[_last_passer_to[gname]]["assists"] += 1
		"tackle":
			if gname in _perf:
				_perf[gname]["tackles"] += 1
		"take_on":
			if gname in _perf:
				_perf[gname]["take_ons"] += 1
		"interception":
			if gname in _perf:
				_perf[gname]["interceptions"] += 1
		"save":
			var keeper: String = str(event.get("keeper", ""))
			if keeper in _perf:
				_perf[keeper]["saves"] += 1
		"pass":
			var from_name: String = str(event.get("from", ""))
			var to_name: String = str(event.get("to", ""))
			if to_name != "":
				_last_passer_to[to_name] = from_name
		"dispossessed":
			var by: String = str(event.get("by", ""))
			if by in _perf:
				_perf[by]["tackles"] += 1

func _flash_token(goblin_name: String, event_type: String) -> void:
	var token: Control = animated_pitch.get_goblin_token(goblin_name)
	if token:
		token.flash_event(event_type)

func _update_ui(snapshot: Dictionary) -> void:
	var sc: Array = snapshot["score"]
	var phase_suffix: String = ""
	if _director_phase_label != "":
		phase_suffix = "  %s" % _director_phase_label
	clock_label.text = "%d'%s" % [int(snapshot["clock"]), phase_suffix]

	# Track possession
	for gdata: Dictionary in snapshot["goblins"]:
		if bool(gdata.get("has_ball", false)):
			var team: String = str(gdata.get("team", ""))
			if team == "home":
				_home_possession_ticks += 1
			elif team == "away":
				_away_possession_ticks += 1
			_last_ball_owner_team = team
			break

	# Build score line with possession
	var total: int = _home_possession_ticks + _away_possession_ticks
	var poss_str: String = ""
	if total > 20:
		var home_pct: int = int(round(float(_home_possession_ticks) / float(total) * 100.0))
		poss_str = "  (%d%%-%d%%)" % [home_pct, 100 - home_pct]
	score_label.text = "HOME %d - %d AWAY%s" % [sc[0], sc[1], poss_str]

	# Hide spell buttons when match is over
	if sim.is_match_over():
		_spell_container.visible = false
		_mana_label.visible = false

var _halftime_logged: bool = false

func _check_halftime(snapshot: Dictionary) -> void:
	if _halftime_logged:
		return
	if int(snapshot["clock"]) >= 45:
		_halftime_logged = true
		var sc: Array = snapshot["score"]
		_log("")
		_log("[color=yellow]--- HALF TIME: %d - %d ---[/color]" % [sc[0], sc[1]])
		_log("")

func _on_match_over(snapshot: Dictionary) -> void:
	var sc: Array = snapshot["score"]
	var total: int = _home_possession_ticks + _away_possession_ticks
	var home_pct: int = 50
	if total > 0:
		home_pct = int(round(float(_home_possession_ticks) / float(total) * 100.0))
	_log("")
	_log("[color=yellow][b]FULL TIME: %d - %d[/b][/color]" % [sc[0], sc[1]])
	_log("[color=#aaaaaa]Possession: %d%% - %d%%[/color]" % [home_pct, 100 - home_pct])
	if sc[0] > sc[1]:
		_log("[color=lime]HOME WINS![/color]")
	elif sc[1] > sc[0]:
		_log("[color=red]AWAY WINS![/color]")
	else:
		_log("[color=yellow]DRAW![/color]")

	if RunManager.run_active:
		# Apply Blood Pact post-match injuries
		_spell_system.apply_post_match_injuries()
		for g in sim.get_blood_pact_targets():
			if g.is_alive() and g.injury == GoblinData.InjuryState.HEALTHY:
				g.apply_injury(GoblinData.InjuryState.MINOR)
				_log("[color=#ee2233]%s suffers from the Blood Pact![/color]" % g.goblin_name)

		# Apply Dark Ascension post-match deaths
		for g in _spell_system.dark_ascension_targets:
			if g.is_alive():
				g.apply_injury(GoblinData.InjuryState.DEAD)
				_log("[color=#ff00ff][b]%s is consumed by the dark magic. Gone forever.[/b][/color]" % g.goblin_name)

		var prev_gold: int = RunManager.gold
		RunManager.record_match_result(int(sc[0]), int(sc[1]))
		RunManager.simulate_remaining_group_matches()
		RunManager.advance_tournament()
		var gold_earned: int = RunManager.gold - prev_gold
		_log("[color=#ffd700]Gold earned: %d (Total: %d)[/color]" % [gold_earned, RunManager.gold])
		_award_xp()
		back_btn.text = "CONTINUE"
	else:
		back_btn.text = "PLAY AGAIN"

func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_OPTIONS.size()
	_speed_multiplier = SPEED_OPTIONS[_speed_index]
	speed_btn.text = _speed_text()

func _speed_text() -> String:
	return "%.1fx" % _speed_multiplier if _speed_multiplier < 1.0 or fmod(_speed_multiplier, 1.0) != 0.0 else "%dx" % int(_speed_multiplier)

func _log(text: String) -> void:
	event_log.append_text(text + "\n")
	event_log.call_deferred("scroll_to_line", maxi(event_log.get_line_count() - 1, 0))

func _award_xp() -> void:
	_log("")
	_log("[color=#aaddff]— XP Gains —[/color]")
	var player_roster: Array[GoblinData] = GameManager.selected_roster
	for g in player_roster:
		if not g.is_alive():
			continue
		var stats: Dictionary = _perf.get(g.goblin_name, {})
		var goals: int = stats.get("goals", 0)
		var assists: int = stats.get("assists", 0)
		var tackles: int = stats.get("tackles", 0)
		var take_ons: int = stats.get("take_ons", 0)
		var interceptions: int = stats.get("interceptions", 0)
		var saves: int = stats.get("saves", 0)

		var total_xp := XP_PLAYED
		total_xp += goals * XP_GOAL
		total_xp += assists * XP_ASSIST
		total_xp += tackles * XP_TACKLE
		total_xp += take_ons * XP_TAKE_ON
		total_xp += interceptions * XP_INTERCEPTION
		total_xp += saves * XP_SAVE

		var prev_level := g.level
		var levels_gained := g.add_xp(total_xp)

		var parts: Array[String] = []
		if goals > 0: parts.append("%dG" % goals)
		if assists > 0: parts.append("%dA" % assists)
		if tackles > 0: parts.append("%dT" % tackles)
		if take_ons > 0: parts.append("%dTO" % take_ons)
		if interceptions > 0: parts.append("%dI" % interceptions)
		if saves > 0: parts.append("%dS" % saves)
		var detail := " (%s)" % ", ".join(parts) if parts.size() > 0 else ""

		if levels_gained > 0:
			_log("[color=lime]%s +%dxp%s → LEVEL %d![/color]" % [g.goblin_name, total_xp, detail, g.level])
		else:
			_log("[color=#aaaaaa]%s +%dxp%s (%d/%d)[/color]" % [g.goblin_name, total_xp, detail, g.xp, g.xp_to_next_level()])

func _on_back_pressed() -> void:
	if RunManager.run_active and sim != null and sim.is_match_over():
		get_tree().change_scene_to_file("res://scenes/screens/shop.tscn")
	elif sim != null and sim.is_match_over() and not RunManager.run_active:
		# Quick-play: replay another match immediately
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if _targeting_spell_index >= 0:
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			_cancel_targeting()
			return
	if event.is_action_pressed("ui_cancel"):
		if sim != null and sim.is_match_over():
			_on_back_pressed()
		elif not RunManager.run_active:
			get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")
