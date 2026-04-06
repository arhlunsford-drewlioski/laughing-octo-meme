extends Control
## Main match controller. Orchestrates the 6-round match loop with run awareness.

# -- UI references --
@onready var score_display: HBoxContainer = %ScoreDisplay
@onready var momentum_bar: Control = %MomentumBar
@onready var zone_display: HBoxContainer = %ZoneDisplay
@onready var formation_display: VBoxContainer = %FormationDisplay
@onready var hand_panel: HBoxContainer = %HandPanel
@onready var toast_manager: VBoxContainer = %ToastManager
@onready var end_round_btn: Button = %EndRoundBtn
@onready var possession_label: Label = %PossessionLabel
@onready var halftime_btn: Button = %HalftimeBtn
@onready var play_again_btn: Button = %PlayAgainBtn

# -- Game systems --
var player_deck: Deck
var opponent_deck: Deck
var engine: MatchEngine
var ai: AIOpponent
var passives: PassiveSystem

# Chance cards queued by the player this round
var player_queued_chances: Array[CardData] = []

func _ready() -> void:
	# Connect UI signals once
	hand_panel.card_selected.connect(_on_card_selected)
	end_round_btn.pressed.connect(_on_end_round_pressed)
	halftime_btn.pressed.connect(_on_halftime_continue)
	play_again_btn.pressed.connect(_on_play_again_pressed)
	formation_display.formation_changed.connect(_on_formation_changed)

	# Style buttons
	UITheme.style_button(end_round_btn)
	UITheme.style_button(halftime_btn)
	UITheme.style_button(play_again_btn)

	# Style possession label
	possession_label.add_theme_color_override("font_color", UITheme.CREAM)
	possession_label.add_theme_font_size_override("font_size", 14)

	_setup_match()
	_start_match()

# -- Setup --

func _setup_match() -> void:
	GameManager.reset_match()

	# Build rosters and formations
	var player_roster := GameManager.selected_roster
	var opponent_roster: Array[GoblinData]

	if RunManager.run_active:
		opponent_roster = RunManager.get_current_opponent_roster()
		GameManager.player_faction = RunManager.player_faction
		GameManager.opponent_faction = RunManager.get_current_opponent_faction()
	else:
		opponent_roster = GoblinDatabase.opponent_roster()
		GameManager.player_faction = 0
		GameManager.opponent_faction = 0

	GameManager.player_formation = GoblinDatabase.build_default_formation(player_roster)
	GameManager.opponent_formation = GoblinDatabase.build_default_formation(opponent_roster)

	# Build decks - use persistent run deck or fresh starter
	player_deck = Deck.new()
	if RunManager.run_active:
		player_deck.initialize(RunManager.run_deck_cards.duplicate())
	else:
		player_deck.initialize(CardDatabase.player_starter_deck())

	opponent_deck = Deck.new()
	opponent_deck.initialize(CardDatabase.opponent_starter_deck())

	engine = MatchEngine.new()
	passives = PassiveSystem.new()
	engine.passives = passives
	engine.set_faction_matchup(GameManager.player_faction, GameManager.opponent_faction)
	ai = AIOpponent.new(opponent_deck)

	# Reset UI state
	halftime_btn.visible = false
	play_again_btn.visible = false

	formation_display.setup(GameManager.player_formation, false)

func _start_match() -> void:
	_toast("GOALS AND GOBLINS", UITheme.GOLD_LIGHT)

	if RunManager.run_active:
		var p_info := FactionSystem.get_faction_info(GameManager.player_faction)
		var o_info := FactionSystem.get_faction_info(GameManager.opponent_faction)
		_toast(RunManager.get_stage_name() + " - " + RunManager.get_current_opponent_name(), UITheme.CREAM)
		_toast(p_info["name"] + " vs " + o_info["name"], UITheme.CREAM_DIM)
		var counter := engine.faction_counter_result
		if counter > 0:
			_toast("Faction advantage! -10% Chance, -1 Momentum for opponent", UITheme.GREEN)
		elif counter < 0:
			_toast("Faction disadvantage! -10% Chance, -1 Momentum for you", UITheme.RED)

	_next_round()

# -- Round flow --

func _next_round() -> void:
	if GameManager.current_round >= GameManager.MAX_ROUNDS:
		_end_match()
		return

	# Check for halftime
	if GameManager.is_halftime():
		_start_halftime()
		return

	engine.reset_round()
	player_queued_chances.clear()

	GameManager.start_round()

	# Draw cards
	player_deck.discard_hand()
	var player_draw := GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(true)
	player_deck.draw_cards(player_draw)

	opponent_deck.discard_hand()
	var opp_draw := GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(false)
	opponent_deck.draw_cards(opp_draw)

	_refresh_hand()
	_update_possession_display()
	end_round_btn.disabled = false

	# Show hand, hide halftime button
	halftime_btn.visible = false
	formation_display.set_interactive(false)

	_toast("Round " + str(GameManager.current_round), UITheme.GOLD)
	if player_draw > GameManager.HAND_DRAW_SIZE:
		_toast("Whizzik draws " + str(player_draw - GameManager.HAND_DRAW_SIZE) + " extra!", UITheme.ENERGY_FILLED)

# -- Halftime --

func _start_halftime() -> void:
	GameManager.set_phase(GameManager.Phase.HALFTIME)

	_toast("HALFTIME", UITheme.GOLD_LIGHT)
	_toast("Rearrange your formation", UITheme.CREAM_DIM)

	# Enable formation editing
	formation_display.set_interactive(true)

	# Show continue button, hide end round
	halftime_btn.visible = true
	end_round_btn.disabled = true

func _on_halftime_continue() -> void:
	halftime_btn.visible = false
	formation_display.set_interactive(false)
	passives.past_halftime = true

	_toast("Formation locked. Second half!", UITheme.GOLD)

	# Resume match
	GameManager.set_phase(GameManager.Phase.ROUND_END)
	_next_round_post_halftime()

func _next_round_post_halftime() -> void:
	engine.reset_round()
	player_queued_chances.clear()

	GameManager.start_round()

	player_deck.discard_hand()
	var player_draw := GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(true)
	player_deck.draw_cards(player_draw)

	opponent_deck.discard_hand()
	var opp_draw := GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(false)
	opponent_deck.draw_cards(opp_draw)

	_refresh_hand()
	_update_possession_display()
	end_round_btn.disabled = false

	_toast("Round " + str(GameManager.current_round), UITheme.GOLD)
	if player_draw > GameManager.HAND_DRAW_SIZE:
		_toast("Whizzik draws " + str(player_draw - GameManager.HAND_DRAW_SIZE) + " extra!", UITheme.ENERGY_FILLED)

func _on_formation_changed() -> void:
	GameManager.formation_changed.emit()
	formation_display.setup(GameManager.player_formation, true)

# -- Card play --

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

	match played.card_type:
		CardData.CardType.TEMPO:
			engine.apply_tempo(played, true)
			var tempo_bonus := passives.tempo_possession_bonus(true)
			if tempo_bonus > 0:
				engine.player_possession += tempo_bonus
			var disruption := passives.tempo_disruption_penalty(true)
			if disruption > 0:
				engine.player_possession = maxi(0, engine.player_possession - disruption)
			var msg := played.card_name + " (+" + str(played.possession_value) + " poss"
			if tempo_bonus > 0:
				msg += " +" + str(tempo_bonus) + " passive"
			if disruption > 0:
				msg += " -" + str(disruption) + " disrupted"
			msg += ")"
			_toast(msg, UITheme.TEMPO_BORDER)
		CardData.CardType.CHANCE:
			engine.queue_chance(played, true)
			player_queued_chances.append(played)
			_toast(played.card_name + " readied (" + str(roundi(played.base_conversion * 100)) + "%)", UITheme.CHANCE_BORDER)

	if played.adds_exhausted:
		player_deck.add_exhausted_card()

	_refresh_hand()
	_update_possession_display()

# -- Round resolution --

func _on_end_round_pressed() -> void:
	if GameManager.current_phase != GameManager.Phase.PLAY_CARDS:
		return

	end_round_btn.disabled = true
	GameManager.set_phase(GameManager.Phase.RESOLVING)

	# AI plays cards
	var ai_played := ai.play_round(engine, GameManager.ENERGY_PER_ROUND)
	for card in ai_played:
		match card.card_type:
			CardData.CardType.TEMPO:
				var tempo_bonus := passives.tempo_possession_bonus(false)
				if tempo_bonus > 0:
					engine.opponent_possession += tempo_bonus
				var disruption := passives.tempo_disruption_penalty(false)
				if disruption > 0:
					engine.opponent_possession = maxi(0, engine.opponent_possession - disruption)
				_toast("OPP: " + card.card_name, UITheme.RED)
			CardData.CardType.CHANCE:
				_toast("OPP readied: " + card.card_name, UITheme.RED)

	await get_tree().create_timer(0.4).timeout

	# 1. Resolve possession
	var poss_diff := engine.player_possession - engine.opponent_possession
	var diff_text := ""
	if poss_diff > 0:
		diff_text = " (+" + str(poss_diff) + ")"
	elif poss_diff < 0:
		diff_text = " (" + str(poss_diff) + ")"
	_toast("Possession: YOU " + str(engine.player_possession) + " vs " + str(engine.opponent_possession) + " OPP" + diff_text, UITheme.CREAM)

	var momentum_shift := engine.resolve_possession()
	if momentum_shift != 0:
		GameManager.shift_momentum(momentum_shift)
		var direction := "toward you" if momentum_shift > 0 else "toward opponent"
		_toast("Momentum shifts " + direction + " (" + ("+" if momentum_shift > 0 else "") + str(momentum_shift) + ")", UITheme.MOMENTUM_MARKER)
	else:
		_toast("Momentum holds", UITheme.CREAM_DIM)

	await get_tree().create_timer(0.5).timeout

	# 2. Resolve chance cards
	var results := engine.resolve_all_chances(GameManager.momentum)
	if results.is_empty():
		_toast("No shots this round", UITheme.CREAM_DIM)
	else:
		for result in results:
			await get_tree().create_timer(0.6).timeout

			var card: CardData = result["card"]
			var is_player: bool = result["is_player"]
			var converted: bool = result["converted"]
			var threshold: float = result["threshold"]
			var saved: bool = result["saved"]
			var side := "YOU" if is_player else "OPP"

			if saved:
				_toast("SAVED! " + side + " - " + card.card_name + " (" + str(roundi(threshold * 100)) + "%)", UITheme.ENERGY_FILLED)
			elif converted:
				GameManager.add_goal(is_player)
				_toast("GOAL! " + side + " - " + card.card_name + " (" + str(roundi(threshold * 100)) + "%)", UITheme.GOLD_LIGHT)
				var goal_mom := passives.goal_momentum_bonus(is_player)
				if goal_mom > 0:
					var shift := goal_mom if is_player else -goal_mom
					GameManager.shift_momentum(shift)
					_toast("Blix frenzy +" + str(goal_mom) + " momentum!", UITheme.ENERGY_FILLED)
			else:
				_toast("MISS. " + side + " - " + card.card_name + " (" + str(roundi(threshold * 100)) + "%)", UITheme.CREAM_DIM)

	await get_tree().create_timer(0.3).timeout

	# 3. End of round
	GameManager.set_phase(GameManager.Phase.ROUND_END)
	_next_round()

# -- Match end --

func _end_match() -> void:
	# Check for knockout draw
	var is_knockout := RunManager.run_active and RunManager.tournament and not RunManager.tournament.is_player_in_group_stage()
	if is_knockout and GameManager.player_goals == GameManager.opponent_goals:
		_toast("EXTRA TIME!", UITheme.GOLD_LIGHT)
		_toast("Knockout - one more round!", UITheme.CREAM)
		GameManager.current_round -= 1
		_next_round()
		return

	GameManager.set_phase(GameManager.Phase.MATCH_END)
	end_round_btn.disabled = true

	_toast("FULL TIME", UITheme.GOLD_LIGHT)
	_toast("YOU " + str(GameManager.player_goals) + " - " + str(GameManager.opponent_goals) + " OPP", UITheme.CREAM)

	if GameManager.player_goals > GameManager.opponent_goals:
		_toast("VICTORY!", UITheme.GREEN)
	elif GameManager.player_goals < GameManager.opponent_goals:
		_toast("DEFEAT.", UITheme.RED)
	else:
		_toast("DRAW.", UITheme.GOLD)

	if RunManager.run_active:
		RunManager.record_match_result(GameManager.player_goals, GameManager.opponent_goals)
		RunManager.simulate_remaining_group_matches()
		RunManager.advance_tournament()
		play_again_btn.text = "CONTINUE"
	else:
		play_again_btn.text = "PLAY AGAIN"

	play_again_btn.visible = true

func _on_play_again_pressed() -> void:
	if RunManager.run_active:
		get_tree().change_scene_to_file("res://scenes/screens/shop.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/draft/draft.tscn")

# -- UI helpers --

func _refresh_hand() -> void:
	hand_panel.refresh(player_deck.hand)

func _update_possession_display() -> void:
	possession_label.text = "Possession: " + str(engine.player_possession)

func _toast(text: String, color: Color = UITheme.CREAM) -> void:
	toast_manager.show_toast(text, color)
