extends Control
## Real-time coach mode with FM-style animated 2D pitch.

const RealtimeEngineClass = preload("res://scripts/realtime_engine.gd")
const BuffCardDB = preload("res://scripts/buff_card_database.gd")
const ChoreographerClass = preload("res://scripts/match_choreographer.gd")

# Match timing
const HALF_DURATION: float = 120.0  # 2 min per half
const EVENT_INTERVAL_MIN: float = 5.0
const EVENT_INTERVAL_MAX: float = 15.0
const FIRST_EVENT_MIN: float = 3.0
const FIRST_EVENT_MAX: float = 6.0

# -- UI references --
@onready var score_display: HBoxContainer = %ScoreDisplay
@onready var momentum_bar: Control = %MomentumBar
@onready var animated_pitch: Control = %AnimatedPitch
@onready var hand_panel: HBoxContainer = %HandPanel
@onready var toast_manager: VBoxContainer = %ToastManager
@onready var clock_label: Label = %ClockLabel
@onready var event_panel: PanelContainer = %EventPanel
@onready var event_label: Label = %EventLabel
@onready var event_hint_label: Label = %EventHintLabel
@onready var response_bar: ProgressBar = %ResponseBar
@onready var deck_label: Label = %DeckLabel

# -- Game state --
var match_clock: float = 0.0
var half: int = 1
var match_running: bool = false
var event_active: bool = false
var animating: bool = false  # True during choreography (prevent overlaps)
var current_event: Dictionary = {}
var response_timer: float = 0.0
var next_event_timer: float = 0.0
var player_deck: Deck
var realtime_engine: RefCounted  # RealtimeEngine
var choreographer: RefCounted    # MatchChoreographer
var halftime_done: bool = false

func _ready() -> void:
	hand_panel.card_selected.connect(_on_card_selected)

	# Style clock label
	clock_label.add_theme_color_override("font_color", UITheme.CREAM)

	# Style event panel
	var panel_style := UITheme.make_panel_style(Color(0.08, 0.08, 0.12, 0.92), UITheme.GOLD, 2)
	event_panel.add_theme_stylebox_override("panel", panel_style)
	event_label.add_theme_color_override("font_color", UITheme.CREAM)
	event_hint_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)

	# Style response bar
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = UITheme.BG_DARK
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	response_bar.add_theme_stylebox_override("background", bar_bg)
	_update_bar_fill(UITheme.GOLD_LIGHT)

	# Style deck panel
	var deck_panel: PanelContainer = deck_label.get_parent()
	deck_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BG_PANEL, UITheme.GOLD, 1))
	deck_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	deck_label.add_theme_font_size_override("font_size", 14)

	_setup_match()
	_start_match()

func _setup_match() -> void:
	GameManager.reset_match()

	# Default rosters (skip draft for testing)
	var player_roster: Array[GoblinData] = GoblinDatabase.full_roster().slice(0, 6)
	var opponent_roster: Array[GoblinData] = GoblinDatabase.opponent_roster()

	GameManager.player_formation = GoblinDatabase.build_default_formation(player_roster)
	GameManager.opponent_formation = GoblinDatabase.build_default_formation(opponent_roster)

	player_deck = Deck.new()
	player_deck.initialize(BuffCardDB.starter_deck())

	realtime_engine = RealtimeEngineClass.new()

	# Setup animated pitch with formations
	animated_pitch.setup(GameManager.player_formation, GameManager.opponent_formation)
	GameManager.formation_changed.emit()

	# Create choreographer
	choreographer = ChoreographerClass.new(animated_pitch)

	# Hide round label from score display (not applicable in realtime mode)
	var round_label := score_display.find_child("RoundLabel", true, false)
	if round_label:
		round_label.visible = false

func _start_match() -> void:
	_toast("REAL-TIME COACH MODE", UITheme.GOLD_LIGHT)
	_toast("React to events with cards!", UITheme.CREAM_DIM)

	# Draw initial hand
	player_deck.draw_cards(GameManager.HAND_DRAW_SIZE)
	_refresh_hand()
	_update_deck_display()

	match_clock = 0.0
	half = 1
	match_running = true
	event_active = false
	animating = false
	next_event_timer = randf_range(FIRST_EVENT_MIN, FIRST_EVENT_MAX)

	_update_clock_display()

func _process(delta: float) -> void:
	if not match_running:
		return

	# Always tick clock (match time doesn't pause for animations)
	match_clock += delta
	_update_clock_display()

	# Check halftime / end
	if match_clock >= HALF_DURATION:
		if half == 1 and not animating:
			_halftime()
			return
		elif half == 2 and not animating:
			_end_match()
			return

	if animating:
		return  # Don't fire events or tick response during choreography

	if event_active:
		# Count down response window
		response_timer -= delta
		response_bar.value = maxf(response_timer, 0.0)

		# Urgency color
		if response_timer <= 1.0:
			_update_bar_fill(UITheme.RED)
		elif response_timer <= 2.0:
			_update_bar_fill(UITheme.GOLD)

		if response_timer <= 0.0:
			_resolve_current_event(null)  # Timed out
	else:
		# Count down to next event
		next_event_timer -= delta
		if next_event_timer <= 0.0:
			_fire_event()

func _fire_event() -> void:
	current_event = realtime_engine.generate_event(
		GameManager.player_formation,
		GameManager.opponent_formation,
		GameManager.momentum
	)

	# Choreograph the event intro (ball moves, goblins shift)
	animating = true
	await choreographer.choreograph_event(current_event)
	animating = false

	# Now show the response window
	event_active = true
	response_timer = current_event["response_time"]

	event_label.text = current_event["description"]
	event_hint_label.text = current_event["hint"]
	response_bar.max_value = response_timer
	response_bar.value = response_timer
	_update_bar_fill(UITheme.GOLD_LIGHT)

	# Color panel border by event zone
	var border_color: Color
	match current_event["relevant_zone"]:
		"attack":
			border_color = UITheme.TEMPO_BORDER
		"defense":
			border_color = UITheme.DEFENSE_BORDER
		"midfield":
			border_color = UITheme.POSSESSION_BORDER
		_:
			border_color = UITheme.GOLD
	var panel_style := UITheme.make_panel_style(Color(0.08, 0.08, 0.12, 0.92), border_color, 2)
	event_panel.add_theme_stylebox_override("panel", panel_style)
	event_panel.visible = true

	# Highlight relevant cards
	_highlight_relevant_cards()

func _on_card_selected(hand_index: int) -> void:
	if not event_active or animating:
		return

	if hand_index < 0 or hand_index >= player_deck.hand.size():
		return

	var card: CardData = player_deck.hand[hand_index]
	if not card.is_playable():
		return

	var played := player_deck.play_card(hand_index)
	if played == null:
		return

	var relevant: bool = realtime_engine.is_card_relevant(played, current_event["relevant_zone"])
	var play_color: Color = UITheme.GOLD_LIGHT if relevant else UITheme.CREAM_DIM
	_toast(played.card_name + ("!" if relevant else " (off-target)"), play_color)

	_resolve_current_event(played)

func _resolve_current_event(card: CardData) -> void:
	# Hide event panel immediately
	event_panel.visible = false
	event_active = false
	hand_panel.clear_highlights()

	var result: Dictionary = realtime_engine.resolve_event(
		current_event,
		card,
		GameManager.player_formation,
		GameManager.opponent_formation,
		GameManager.momentum
	)

	# Apply game state changes
	var outcome: String = result["outcome"]
	match outcome:
		"goal_player":
			GameManager.add_goal(true)
			_toast(result["description"], UITheme.GOLD_LIGHT)
		"goal_opponent":
			GameManager.add_goal(false)
			_toast(result["description"], UITheme.RED)
		"save":
			_toast(result["description"], UITheme.ENERGY_FILLED)
		"miss":
			_toast(result["description"], UITheme.CREAM_DIM)
		"momentum_player":
			_toast(result["description"], UITheme.GREEN)
		"momentum_opponent":
			_toast(result["description"], UITheme.RED)
		"nothing":
			_toast(result["description"], UITheme.CREAM_DIM)

	var mom_shift: int = result["momentum_shift"]
	if mom_shift != 0:
		GameManager.shift_momentum(mom_shift)

	# Choreograph the result (goal flash, save deflect, etc.)
	animating = true
	await choreographer.choreograph_result(current_event, result)
	animating = false

	# Refresh hand and schedule next event
	_refresh_hand()
	_update_deck_display()
	next_event_timer = randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)

func _halftime() -> void:
	match_running = false
	event_active = false
	animating = false
	event_panel.visible = false
	hand_panel.clear_highlights()

	_toast("HALFTIME", UITheme.GOLD_LIGHT)

	# Refresh hand for second half
	player_deck.discard_hand()
	player_deck.draw_cards(GameManager.HAND_DRAW_SIZE)
	_refresh_hand()
	_update_deck_display()

	await get_tree().create_timer(2.0).timeout

	half = 2
	match_clock = 0.0
	halftime_done = true
	match_running = true
	next_event_timer = randf_range(FIRST_EVENT_MIN, FIRST_EVENT_MAX)

	_toast("SECOND HALF", UITheme.GOLD_LIGHT)
	_update_clock_display()

func _end_match() -> void:
	match_running = false
	event_active = false
	animating = false
	event_panel.visible = false
	hand_panel.clear_highlights()

	GameManager.set_phase(GameManager.Phase.MATCH_END)

	_toast("FULL TIME", UITheme.GOLD_LIGHT)
	_toast("YOU " + str(GameManager.player_goals) + " - " + str(GameManager.opponent_goals) + " OPP", UITheme.CREAM)

	if GameManager.player_goals > GameManager.opponent_goals:
		_toast("VICTORY!", UITheme.GREEN)
	elif GameManager.player_goals < GameManager.opponent_goals:
		_toast("DEFEAT.", UITheme.RED)
	else:
		_toast("DRAW.", UITheme.GOLD)

	_toast("Press ESC to return", UITheme.CREAM_DIM)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")

# -- UI helpers --

func _refresh_hand() -> void:
	hand_panel.refresh(player_deck.hand)

func _update_deck_display() -> void:
	var draw_count: int = player_deck.draw_pile.size()
	var discard_count: int = player_deck.discard_pile.size()
	deck_label.text = "DECK\n" + str(draw_count) + " / " + str(discard_count)

func _update_clock_display() -> void:
	var minutes: int = int(match_clock) / 60
	var seconds: int = int(match_clock) % 60
	var half_label: String = "1H" if half == 1 else "2H"
	clock_label.text = half_label + " %02d:%02d" % [minutes, seconds]

func _update_bar_fill(color: Color) -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = color
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	response_bar.add_theme_stylebox_override("fill", bar_fill)

func _highlight_relevant_cards() -> void:
	if not current_event.has("relevant_zone"):
		return

	var relevant_indices: Array[int] = []
	for i in player_deck.hand.size():
		var card: CardData = player_deck.hand[i]
		if card.is_playable() and realtime_engine.is_card_relevant(card, current_event["relevant_zone"]):
			relevant_indices.append(i)

	hand_panel.highlight_cards(relevant_indices)

func _toast(text: String, color: Color = UITheme.CREAM) -> void:
	toast_manager.show_toast(text, color)
