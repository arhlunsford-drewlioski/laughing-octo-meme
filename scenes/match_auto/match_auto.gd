extends Control
## Autobattler match controller. Cards buff goblins, rounds auto-resolve.

const AutoEngineClass = preload("res://scripts/auto_engine.gd")
const BuffCardDB = preload("res://scripts/buff_card_database.gd")

# -- UI references --
@onready var score_display: HBoxContainer = %ScoreDisplay
@onready var momentum_bar: Control = %MomentumBar
@onready var zone_display: VBoxContainer = %ZoneDisplay
@onready var pitch_display: Control = %PitchDisplay
@onready var hand_panel: HBoxContainer = %HandPanel
@onready var toast_manager: VBoxContainer = %ToastManager
@onready var resolve_btn: Button = %ResolveBtn
@onready var buff_label: Label = %BuffLabel
@onready var deck_label: Label = %DeckLabel

# -- Game systems --
var player_deck: Deck
var opponent_deck: Deck
var auto_engine: RefCounted
var selected_card: CardData = null
var selected_hand_index: int = -1

func _ready() -> void:
	hand_panel.card_selected.connect(_on_card_selected)
	resolve_btn.pressed.connect(_on_resolve_pressed)

	UITheme.style_button(resolve_btn)

	buff_label.add_theme_color_override("font_color", UITheme.CREAM)
	buff_label.add_theme_font_size_override("font_size", 12)

	var deck_panel: PanelContainer = deck_label.get_parent()
	deck_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BG_PANEL, UITheme.GOLD, 1))
	deck_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	deck_label.add_theme_font_size_override("font_size", 14)

	_setup_match()
	_start_match()

func _setup_match() -> void:
	GameManager.reset_match()

	# Use default rosters (skip draft for testing)
	var player_roster: Array[GoblinData] = GoblinDatabase.full_roster().slice(0, 6)
	var opponent_roster: Array[GoblinData] = GoblinDatabase.opponent_roster()

	GameManager.player_formation = GoblinDatabase.build_default_formation(player_roster)
	GameManager.opponent_formation = GoblinDatabase.build_default_formation(opponent_roster)

	player_deck = Deck.new()
	player_deck.initialize(BuffCardDB.starter_deck())

	opponent_deck = Deck.new()
	opponent_deck.initialize(BuffCardDB.opponent_starter_deck())

	auto_engine = AutoEngineClass.new()

	pitch_display.setup(GameManager.player_formation, GameManager.opponent_formation, false)
	GameManager.formation_changed.emit()

func _start_match() -> void:
	_toast("AUTOBATTLER TEST", UITheme.GOLD_LIGHT)
	_toast("Play buff cards, then RESOLVE", UITheme.CREAM_DIM)
	_next_round()

func _next_round() -> void:
	if GameManager.current_round >= GameManager.MAX_ROUNDS:
		_end_match()
		return

	if GameManager.is_halftime():
		_toast("HALFTIME", UITheme.GOLD_LIGHT)
		# Skip halftime for prototype - just continue
		GameManager.set_phase(GameManager.Phase.ROUND_END)

	auto_engine.reset_round()
	selected_card = null
	selected_hand_index = -1

	GameManager.start_round()

	# Draw cards
	player_deck.discard_hand()
	player_deck.draw_cards(GameManager.HAND_DRAW_SIZE)

	opponent_deck.discard_hand()
	opponent_deck.draw_cards(GameManager.HAND_DRAW_SIZE)

	# AI applies buffs (shown to player)
	_ai_apply_buffs()

	_refresh_hand()
	_update_buff_display()
	_update_pitch_buffs()
	_update_deck_display()
	resolve_btn.disabled = false

	_toast("Round " + str(GameManager.current_round), UITheme.GOLD)

func _ai_apply_buffs() -> void:
	## AI plays its buff cards (face-up) and applies them.
	var hand_copy := opponent_deck.hand.duplicate()
	var remaining_energy: int = GameManager.ENERGY_PER_ROUND

	# Sort by value (possession_value or defense_value)
	hand_copy.sort_custom(func(a: CardData, b: CardData) -> bool:
		var va: int = a.possession_value if a.possession_value > 0 else a.defense_value
		var vb: int = b.possession_value if b.possession_value > 0 else b.defense_value
		return va > vb)

	var parts: Array[String] = []
	for card in hand_copy:
		if remaining_energy <= 0:
			break
		if not card.is_playable() or card.energy_cost > remaining_energy:
			continue

		var idx: int = opponent_deck.hand.find(card)
		if idx == -1:
			continue

		opponent_deck.play_card(idx)
		remaining_energy -= card.energy_cost
		auto_engine.apply_buff(card, false)

		match card.card_type:
			CardData.CardType.ATK_BUFF:
				parts.append("+" + str(card.possession_value) + " ATK")
			CardData.CardType.DEF_BUFF:
				parts.append("+" + str(card.defense_value) + " DEF")
			CardData.CardType.MID_BUFF:
				parts.append("+" + str(card.possession_value) + " MID")
			CardData.CardType.TACTICAL:
				parts.append("+" + str(card.possession_value) + " ATK/-2 DEF")

	if parts.size() > 0:
		_toast("OPP buffs: " + ", ".join(parts), UITheme.RED)
	else:
		_toast("OPP: No buffs", UITheme.CREAM_DIM)

func _on_card_selected(hand_index: int) -> void:
	if GameManager.current_phase != GameManager.Phase.PLAY_CARDS:
		return

	var card: CardData = player_deck.hand[hand_index]
	if not GameManager.spend_energy(card.energy_cost):
		_toast("Not enough energy!", UITheme.RED)
		return

	var played := player_deck.play_card(hand_index)
	if played == null:
		GameManager.refund_energy(card.energy_cost)
		return

	auto_engine.apply_buff(played, true)

	var msg: String = played.card_name + " ("
	match played.card_type:
		CardData.CardType.ATK_BUFF:
			msg += "+" + str(played.possession_value) + " ATK"
		CardData.CardType.DEF_BUFF:
			msg += "+" + str(played.defense_value) + " DEF"
		CardData.CardType.MID_BUFF:
			msg += "+" + str(played.possession_value) + " MID"
		CardData.CardType.TACTICAL:
			msg += "+" + str(played.possession_value) + " ATK, -2 DEF"
	msg += ")"

	var color: Color = UITheme.POSSESSION_BORDER
	match played.card_type:
		CardData.CardType.ATK_BUFF:
			color = UITheme.TEMPO_BORDER
		CardData.CardType.DEF_BUFF:
			color = UITheme.DEFENSE_BORDER
		CardData.CardType.MID_BUFF:
			color = UITheme.POSSESSION_BORDER
		CardData.CardType.TACTICAL:
			color = UITheme.GOLD

	_toast(msg, color)

	_refresh_hand()
	_update_buff_display()
	_update_pitch_buffs()
	_update_deck_display()

func _on_resolve_pressed() -> void:
	if GameManager.current_phase != GameManager.Phase.PLAY_CARDS:
		return

	resolve_btn.disabled = true
	GameManager.set_phase(GameManager.Phase.RESOLVING)

	var events: Array[Dictionary] = auto_engine.resolve_round(GameManager.player_formation, GameManager.opponent_formation, GameManager.momentum)

	# Animate events as toasts
	_animate_events(events)

func _animate_events(events: Array[Dictionary]) -> void:
	for event in events:
		match event["type"]:
			"midfield":
				var poss_pct: int = roundi(event["possession"] * 100)
				var winner: String = "YOU" if event["player_mid"] > event["opponent_mid"] else "OPP"
				_toast("Midfield: YOU " + str(event["player_mid"]) + " vs " + str(event["opponent_mid"]) + " OPP - " + winner + " controls! (" + str(poss_pct) + "%)", UITheme.POSSESSION_BORDER)
				await get_tree().create_timer(0.6).timeout

			"attack_phase":
				var side_name: String = "Your" if event["side"] == "player" else "Opponent"
				_toast(side_name + " attack: " + str(event["atk"]) + " ATK vs " + str(event["def"]) + " DEF - " + str(event["chances"]) + " chance(s)!", UITheme.CREAM)
				await get_tree().create_timer(0.5).timeout

			"goal":
				var side: String = "YOU" if event["side"] == "player" else "OPP"
				var is_player: bool = event["side"] == "player"
				GameManager.add_goal(is_player)
				_toast("GOAL! " + event["goblin"] + " scores! (" + str(roundi(event["threshold"] * 100)) + "%)", UITheme.GOLD_LIGHT)
				await get_tree().create_timer(0.8).timeout

			"save":
				_toast("SAVED! " + event["goblin"] + "'s shot stopped by the keeper!", UITheme.ENERGY_FILLED)
				await get_tree().create_timer(0.6).timeout

			"miss":
				var side: String = "YOU" if event["side"] == "player" else "OPP"
				_toast("MISS. " + event["goblin"] + " fires wide. (" + str(roundi(event["threshold"] * 100)) + "%)", UITheme.CREAM_DIM)
				await get_tree().create_timer(0.5).timeout

			"momentum":
				var shift: int = event["shift"]
				if shift != 0:
					GameManager.shift_momentum(shift)
					var direction: String = "toward you" if shift > 0 else "toward opponent"
					_toast("Momentum shifts " + direction, UITheme.MOMENTUM_MARKER)
				else:
					_toast("Momentum holds", UITheme.CREAM_DIM)
				await get_tree().create_timer(0.3).timeout

	GameManager.set_phase(GameManager.Phase.ROUND_END)
	_next_round()

func _end_match() -> void:
	GameManager.set_phase(GameManager.Phase.MATCH_END)
	resolve_btn.disabled = true

	_toast("FULL TIME", UITheme.GOLD_LIGHT)
	_toast("YOU " + str(GameManager.player_goals) + " - " + str(GameManager.opponent_goals) + " OPP", UITheme.CREAM)

	if GameManager.player_goals > GameManager.opponent_goals:
		_toast("VICTORY!", UITheme.GREEN)
	elif GameManager.player_goals < GameManager.opponent_goals:
		_toast("DEFEAT.", UITheme.RED)
	else:
		_toast("DRAW.", UITheme.GOLD)

	_toast("Press ESC or close to return", UITheme.CREAM_DIM)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/screens/main_menu.tscn")

# -- UI helpers --

func _refresh_hand() -> void:
	hand_panel.refresh(player_deck.hand)

func _update_buff_display() -> void:
	var parts: Array[String] = []
	if auto_engine.player_atk_buff != 0:
		parts.append("ATK+" + str(auto_engine.player_atk_buff))
	if auto_engine.player_mid_buff != 0:
		parts.append("MID+" + str(auto_engine.player_mid_buff))
	if auto_engine.player_def_buff != 0:
		parts.append("DEF+" + str(auto_engine.player_def_buff))
	if parts.is_empty():
		buff_label.text = "No buffs"
	else:
		buff_label.text = " ".join(parts)

func _update_pitch_buffs() -> void:
	var player_buffs: Dictionary = {
		"attack": auto_engine.player_atk_buff,
		"midfield": auto_engine.player_mid_buff,
		"defense": auto_engine.player_def_buff,
		"goal": 0,
	}
	var opp_buffs: Dictionary = {
		"attack": auto_engine.opponent_atk_buff,
		"midfield": auto_engine.opponent_mid_buff,
		"defense": auto_engine.opponent_def_buff,
		"goal": 0,
	}
	pitch_display.set_zone_buffs(player_buffs, opp_buffs)

func _update_deck_display() -> void:
	var draw_count: int = player_deck.draw_pile.size()
	var discard_count: int = player_deck.discard_pile.size()
	deck_label.text = "DECK\n" + str(draw_count) + " / " + str(discard_count)

func _toast(text: String, color: Color = UITheme.CREAM) -> void:
	toast_manager.show_toast(text, color)
