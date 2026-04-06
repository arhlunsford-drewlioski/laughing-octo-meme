extends Control
## Main match controller. Orchestrates the 8-round TPD match loop with opponent intent.

# -- UI references --
@onready var score_display: HBoxContainer = %ScoreDisplay
@onready var momentum_bar: Control = %MomentumBar
@onready var zone_display: VBoxContainer = %ZoneDisplay
@onready var pitch_display: Control = %PitchDisplay
@onready var hand_panel: HBoxContainer = %HandPanel
@onready var toast_manager: VBoxContainer = %ToastManager
@onready var end_round_btn: Button = %EndRoundBtn
@onready var possession_label: Label = %PossessionLabel
@onready var halftime_btn: Button = %HalftimeBtn
@onready var play_again_btn: Button = %PlayAgainBtn
@onready var deck_label: Label = %DeckLabel

# -- Game systems --
var player_deck: Deck
var opponent_deck: Deck
var engine: MatchEngine
var ai: AIOpponent
var passives: PassiveSystem

# AI's planned cards for this round (shown face-up)
var ai_planned_cards: Array[CardData] = []

func _ready() -> void:
	hand_panel.card_selected.connect(_on_card_selected)
	end_round_btn.pressed.connect(_on_end_round_pressed)
	halftime_btn.pressed.connect(_on_halftime_continue)
	play_again_btn.pressed.connect(_on_play_again_pressed)
	pitch_display.formation_changed.connect(_on_formation_changed)

	UITheme.style_button(end_round_btn)
	UITheme.style_button(halftime_btn)
	UITheme.style_button(play_again_btn)

	possession_label.add_theme_color_override("font_color", UITheme.CREAM)
	possession_label.add_theme_font_size_override("font_size", 12)

	var deck_panel: PanelContainer = deck_label.get_parent()
	deck_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BG_PANEL, UITheme.GOLD, 1))
	deck_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	deck_label.add_theme_font_size_override("font_size", 14)

	_setup_match()
	_start_match()

# -- Setup --

func _setup_match() -> void:
	GameManager.reset_match()

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

	halftime_btn.visible = false
	play_again_btn.visible = false

	pitch_display.setup(GameManager.player_formation, GameManager.opponent_formation, false)
	_update_deck_display()
	GameManager.formation_changed.emit()

func _start_match() -> void:
	_toast("GOALS AND GOBLINS", UITheme.GOLD_LIGHT)

	if RunManager.run_active:
		var p_info := FactionSystem.get_faction_info(GameManager.player_faction)
		var o_info := FactionSystem.get_faction_info(GameManager.opponent_faction)
		_toast(RunManager.get_stage_name() + " - " + RunManager.get_current_opponent_name(), UITheme.CREAM)
		_toast(p_info["name"] + " vs " + o_info["name"], UITheme.CREAM_DIM)
		var counter := engine.faction_counter_result
		if counter > 0:
			_toast("Faction advantage! -10% Tempo, -1 Momentum for opponent", UITheme.GREEN)
		elif counter < 0:
			_toast("Faction disadvantage! -10% Tempo, -1 Momentum for you", UITheme.RED)

	_next_round()

# -- Round flow --

func _next_round() -> void:
	if GameManager.current_round >= GameManager.MAX_ROUNDS:
		_end_match()
		return

	if GameManager.is_halftime():
		_start_halftime()
		return

	engine.reset_round()
	ai_planned_cards.clear()

	GameManager.start_round()

	# Draw cards for both sides
	player_deck.discard_hand()
	var player_draw: int = GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(true)
	player_deck.draw_cards(player_draw)

	opponent_deck.discard_hand()
	var opp_draw: int = GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(false)
	opponent_deck.draw_cards(opp_draw)

	# AI plans cards face-up (doesn't apply yet)
	ai_planned_cards = ai.plan_round(GameManager.ENERGY_PER_ROUND)
	_show_opponent_intent()

	_refresh_hand()
	_update_possession_display()
	_update_deck_display()
	end_round_btn.disabled = false

	halftime_btn.visible = false
	pitch_display.set_interactive(false)

	_toast("Round " + str(GameManager.current_round), UITheme.GOLD)
	if player_draw > GameManager.HAND_DRAW_SIZE:
		_toast("Whizzik draws " + str(player_draw - GameManager.HAND_DRAW_SIZE) + " extra!", UITheme.ENERGY_FILLED)

func _show_opponent_intent() -> void:
	## Display what the opponent is planning to play this round.
	if ai_planned_cards.is_empty():
		_toast("OPP: No cards planned", UITheme.CREAM_DIM)
		return

	var summary: String = "OPP plans: "
	var parts: Array[String] = []
	for card in ai_planned_cards:
		match card.card_type:
			CardData.CardType.POSSESSION:
				parts.append("+" + str(card.possession_value) + " Ctrl")
			CardData.CardType.DEFENSE:
				parts.append("+" + str(card.defense_value) + " Block")
			CardData.CardType.TEMPO:
				parts.append(str(roundi(card.base_conversion * 100)) + "% Shot")
	summary += ", ".join(parts)
	_toast(summary, UITheme.RED)

# -- Halftime --

func _start_halftime() -> void:
	GameManager.set_phase(GameManager.Phase.HALFTIME)

	_toast("HALFTIME", UITheme.GOLD_LIGHT)
	_toast("Rearrange your formation", UITheme.CREAM_DIM)

	pitch_display.set_interactive(true)
	halftime_btn.visible = true
	end_round_btn.disabled = true

func _on_halftime_continue() -> void:
	halftime_btn.visible = false
	pitch_display.set_interactive(false)
	passives.past_halftime = true

	_toast("Formation locked. Second half!", UITheme.GOLD)

	GameManager.set_phase(GameManager.Phase.ROUND_END)
	_next_round_post_halftime()

func _next_round_post_halftime() -> void:
	engine.reset_round()
	ai_planned_cards.clear()

	GameManager.start_round()

	player_deck.discard_hand()
	var player_draw: int = GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(true)
	player_deck.draw_cards(player_draw)

	opponent_deck.discard_hand()
	var opp_draw: int = GameManager.HAND_DRAW_SIZE + passives.extra_draw_count(false)
	opponent_deck.draw_cards(opp_draw)

	ai_planned_cards = ai.plan_round(GameManager.ENERGY_PER_ROUND)
	_show_opponent_intent()

	_refresh_hand()
	_update_possession_display()
	_update_deck_display()
	end_round_btn.disabled = false

	_toast("Round " + str(GameManager.current_round), UITheme.GOLD)
	if player_draw > GameManager.HAND_DRAW_SIZE:
		_toast("Whizzik draws " + str(player_draw - GameManager.HAND_DRAW_SIZE) + " extra!", UITheme.ENERGY_FILLED)

func _on_formation_changed() -> void:
	GameManager.formation_changed.emit()
	pitch_display.setup(GameManager.player_formation, GameManager.opponent_formation, true)

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
		CardData.CardType.POSSESSION:
			engine.apply_possession(played, true)
			var poss_bonus: int = passives.possession_play_bonus(true)
			if poss_bonus > 0:
				engine.player_possession += poss_bonus
			var disruption: int = passives.possession_disruption_penalty(true)
			if disruption > 0:
				engine.player_possession = maxi(0, engine.player_possession - disruption)
			var msg: String = played.card_name + " (+" + str(played.possession_value) + " ctrl"
			if poss_bonus > 0:
				msg += " +" + str(poss_bonus) + " passive"
			if disruption > 0:
				msg += " -" + str(disruption) + " disrupted"
			msg += ")"
			_toast(msg, UITheme.POSSESSION_BORDER)
		CardData.CardType.DEFENSE:
			engine.apply_defense(played, true)
			_toast(played.card_name + " (+" + str(played.defense_value) + " block)", UITheme.DEFENSE_BORDER)
		CardData.CardType.TEMPO:
			engine.queue_tempo(played, true)
			_toast(played.card_name + " readied (" + str(roundi(played.base_conversion * 100)) + "% goal)", UITheme.TEMPO_BORDER)

	if played.adds_exhausted:
		player_deck.add_exhausted_card()

	_refresh_hand()
	_update_possession_display()
	_update_deck_display()

# -- Round resolution --

func _on_end_round_pressed() -> void:
	if GameManager.current_phase != GameManager.Phase.PLAY_CARDS:
		return

	end_round_btn.disabled = true
	GameManager.set_phase(GameManager.Phase.RESOLVING)

	# AI executes its planned cards
	var ai_played := ai.execute_plan(engine)
	for card in ai_played:
		match card.card_type:
			CardData.CardType.POSSESSION:
				var poss_bonus: int = passives.possession_play_bonus(false)
				if poss_bonus > 0:
					engine.opponent_possession += poss_bonus
				var disruption: int = passives.possession_disruption_penalty(false)
				if disruption > 0:
					engine.opponent_possession = maxi(0, engine.opponent_possession - disruption)
				_toast("OPP: " + card.card_name + " (+" + str(card.possession_value) + " ctrl)", UITheme.RED)
			CardData.CardType.DEFENSE:
				_toast("OPP: " + card.card_name + " (+" + str(card.defense_value) + " block)", UITheme.RED)
			CardData.CardType.TEMPO:
				_toast("OPP: " + card.card_name + " (" + str(roundi(card.base_conversion * 100)) + "% goal)", UITheme.RED)

	await get_tree().create_timer(0.4).timeout

	# 1. Resolve net possession
	var player_net: int = engine.get_net_possession(true)
	var opponent_net: int = engine.get_net_possession(false)
	var poss_diff: int = player_net - opponent_net
	var diff_text: String = ""
	if poss_diff > 0:
		diff_text = " (+" + str(poss_diff) + ")"
	elif poss_diff < 0:
		diff_text = " (" + str(poss_diff) + ")"
	_toast("Net Control: YOU " + str(player_net) + " vs " + str(opponent_net) + " OPP" + diff_text, UITheme.CREAM)

	var momentum_shift: int = engine.resolve_possession()
	if momentum_shift != 0:
		GameManager.shift_momentum(momentum_shift)
		var direction: String = "toward you" if momentum_shift > 0 else "toward opponent"
		_toast("Momentum shifts " + direction + " (" + ("+" if momentum_shift > 0 else "") + str(momentum_shift) + ")", UITheme.MOMENTUM_MARKER)
	else:
		_toast("Momentum holds", UITheme.CREAM_DIM)

	await get_tree().create_timer(0.5).timeout

	# 2. Resolve Tempo goal attempts
	var results := engine.resolve_all_tempo_goals(GameManager.momentum)
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
			var side: String = "YOU" if is_player else "OPP"

			if saved:
				_toast("SAVED! " + side + " - " + card.card_name + " (" + str(roundi(threshold * 100)) + "%)", UITheme.ENERGY_FILLED)
			elif converted:
				GameManager.add_goal(is_player)
				_toast("GOAL! " + side + " - " + card.card_name + " (" + str(roundi(threshold * 100)) + "%)", UITheme.GOLD_LIGHT)
				var goal_mom: int = passives.goal_momentum_bonus(is_player)
				if goal_mom > 0:
					var shift: int = goal_mom if is_player else -goal_mom
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
	var is_knockout: bool = RunManager.run_active and RunManager.tournament and not RunManager.tournament.is_player_in_group_stage()
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
	var my_ctrl: int = engine.player_possession
	var my_def: int = engine.player_defense
	var parts: Array[String] = []
	if my_ctrl > 0:
		parts.append("Poss:" + str(my_ctrl))
	if my_def > 0:
		parts.append("Def:" + str(my_def))
	if parts.is_empty():
		possession_label.text = "Poss: 0"
	else:
		possession_label.text = " ".join(parts)

	# Update pitch goblin stat overlays
	# In StS mode, show possession on midfield, defense on defense zone
	var player_buffs: Dictionary = {
		"attack": 0,
		"midfield": my_ctrl,
		"defense": my_def,
		"goal": 0,
	}
	# Show what opponent has committed (from their planned/played cards)
	var opp_buffs: Dictionary = {
		"attack": 0,
		"midfield": engine.opponent_possession,
		"defense": engine.opponent_defense,
		"goal": 0,
	}
	pitch_display.set_zone_buffs(player_buffs, opp_buffs)

func _update_deck_display() -> void:
	var draw_count: int = player_deck.draw_pile.size()
	var discard_count: int = player_deck.discard_pile.size()
	deck_label.text = "DECK\n" + str(draw_count) + " / " + str(discard_count)

func _toast(text: String, color: Color = UITheme.CREAM) -> void:
	toast_manager.show_toast(text, color)
