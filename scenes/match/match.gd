extends Control
## Main match controller. Orchestrates the 6-round MVP match loop.

# -- UI references --
@onready var score_display: HBoxContainer = %ScoreDisplay
@onready var momentum_bar: Control = %MomentumBar
@onready var zone_display: HBoxContainer = %ZoneDisplay
@onready var formation_display: VBoxContainer = %FormationDisplay
@onready var hand_panel: HBoxContainer = %HandPanel
@onready var log_label: RichTextLabel = %LogLabel
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

	_setup_match()
	_start_match()

# -- Setup --

func _setup_match() -> void:
	GameManager.reset_match()

	# Build rosters and formations
	var player_roster := GoblinDatabase.player_roster()
	var opponent_roster := GoblinDatabase.opponent_roster()
	GameManager.player_formation = GoblinDatabase.build_default_formation(player_roster)
	GameManager.opponent_formation = GoblinDatabase.build_default_formation(opponent_roster)

	# Build decks
	player_deck = Deck.new()
	player_deck.initialize(CardDatabase.player_starter_deck())

	opponent_deck = Deck.new()
	opponent_deck.initialize(CardDatabase.opponent_starter_deck())

	engine = MatchEngine.new()
	passives = PassiveSystem.new()
	engine.passives = passives
	ai = AIOpponent.new(opponent_deck)

	# Reset UI state
	halftime_btn.visible = false
	play_again_btn.visible = false

	formation_display.setup(GameManager.player_formation, false)

func _start_match() -> void:
	_log("[color=yellow]GOALS AND GOBLINS[/color]")
	_log("6 rounds. Most goals wins. Play cards, build possession, score goals.")
	_log("")
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

	_log("[color=yellow]-- Round " + str(GameManager.current_round) + " --[/color]")
	if player_draw > GameManager.HAND_DRAW_SIZE:
		_log("[color=cyan]Whizzik's speed draws " + str(player_draw - GameManager.HAND_DRAW_SIZE) + " extra card(s)![/color]")

# -- Halftime --

func _start_halftime() -> void:
	GameManager.set_phase(GameManager.Phase.HALFTIME)

	_log("[color=yellow]========== HALFTIME ==========[/color]")
	_log("Rearrange your formation. Tap a goblin, then tap a zone to move them.")
	_log("")

	# Enable formation editing
	formation_display.set_interactive(true)

	# Show continue button, hide end round
	halftime_btn.visible = true
	end_round_btn.disabled = true

func _on_halftime_continue() -> void:
	halftime_btn.visible = false
	formation_display.set_interactive(false)

	_log("[color=yellow]Formation locked. Second half begins.[/color]")
	_log("")

	# Resume match - clear halftime state so _next_round proceeds
	GameManager.set_phase(GameManager.Phase.ROUND_END)
	# Temporarily bump past halftime check by clearing round_end state
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

	_log("[color=yellow]-- Round " + str(GameManager.current_round) + " --[/color]")
	if player_draw > GameManager.HAND_DRAW_SIZE:
		_log("[color=cyan]Whizzik's speed draws " + str(player_draw - GameManager.HAND_DRAW_SIZE) + " extra card(s)![/color]")

func _on_formation_changed() -> void:
	GameManager.formation_changed.emit()
	formation_display.setup(GameManager.player_formation, true)

# -- Card play --

func _on_card_selected(hand_index: int) -> void:
	if GameManager.current_phase != GameManager.Phase.PLAY_CARDS:
		return

	var card: CardData = player_deck.hand[hand_index]
	if not GameManager.spend_energy(card.energy_cost):
		_log("[color=red]Not enough energy![/color]")
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
			_log("Played [color=green]" + played.card_name + "[/color] (+" + str(played.possession_value) + " possession" + ("+" + str(tempo_bonus) + " passive" if tempo_bonus > 0 else "") + ")")
		CardData.CardType.CHANCE:
			engine.queue_chance(played, true)
			player_queued_chances.append(played)
			_log("Readied [color=purple]" + played.card_name + "[/color] (" + str(roundi(played.base_conversion * 100)) + "% base)")

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
				_log("Opponent played [color=red]" + card.card_name + "[/color]")
			CardData.CardType.CHANCE:
				_log("Opponent readied [color=red]" + card.card_name + "[/color]")

	await get_tree().create_timer(0.4).timeout

	# 1. Resolve possession
	_log("")
	var poss_diff := engine.player_possession - engine.opponent_possession
	var poss_bar := _possession_bar(engine.player_possession, engine.opponent_possession)
	_log("[color=white]Possession:[/color] " + poss_bar)
	_log("  YOU " + str(engine.player_possession) + " vs " + str(engine.opponent_possession) + " OPP" + (" [color=green](+" + str(poss_diff) + ")[/color]" if poss_diff > 0 else " [color=red](" + str(poss_diff) + ")[/color]" if poss_diff < 0 else " (even)"))

	var momentum_shift := engine.resolve_possession()
	if momentum_shift != 0:
		GameManager.shift_momentum(momentum_shift)
		var direction := "[color=green]toward you[/color]" if momentum_shift > 0 else "[color=red]toward opponent[/color]"
		_log("Momentum shifts " + direction + " (" + ("+" if momentum_shift > 0 else "") + str(momentum_shift) + ") [Momentum: " + str(GameManager.momentum) + "]")
	else:
		_log("Momentum holds. [Momentum: " + str(GameManager.momentum) + "]")

	await get_tree().create_timer(0.5).timeout

	# 2. Resolve chance cards
	var results := engine.resolve_all_chances(GameManager.momentum)
	if results.is_empty():
		_log("[color=gray]No shots this round.[/color]")
	else:
		_log("[color=white]-- Shots --[/color]")
		for result in results:
			await get_tree().create_timer(0.6).timeout

			var card: CardData = result["card"]
			var is_player: bool = result["is_player"]
			var converted: bool = result["converted"]
			var threshold: float = result["threshold"]
			var saved: bool = result["saved"]
			var side := "YOU" if is_player else "OPP"

			if saved:
				_log("[color=cyan]  SAVED! " + side + " - " + card.card_name + " beaten by the keeper! (" + str(roundi(threshold * 100)) + "%)[/color]")
			elif converted:
				GameManager.add_goal(is_player)
				_log("[color=yellow]  GOAL! " + side + " - " + card.card_name + " converts! (" + str(roundi(threshold * 100)) + "%)[/color]")
			else:
				_log("  MISS. " + side + " - " + card.card_name + " (" + str(roundi(threshold * 100)) + "%)")

	_log("")

	await get_tree().create_timer(0.3).timeout

	# 3. End of round
	GameManager.set_phase(GameManager.Phase.ROUND_END)
	_next_round()

# -- Match end --

func _end_match() -> void:
	GameManager.set_phase(GameManager.Phase.MATCH_END)
	end_round_btn.disabled = true

	_log("[color=yellow]========== FULL TIME ==========[/color]")
	_log("YOU " + str(GameManager.player_goals) + " - " + str(GameManager.opponent_goals) + " OPP")

	if GameManager.player_goals > GameManager.opponent_goals:
		_log("[color=green]VICTORY! Your goblins live to fight another day.[/color]")
	elif GameManager.player_goals < GameManager.opponent_goals:
		_log("[color=red]DEFEAT. Your goblins have been eliminated.[/color]")
	else:
		_log("[color=yellow]DRAW. Nobody dies today. Probably.[/color]")

	play_again_btn.visible = true

func _on_play_again_pressed() -> void:
	play_again_btn.visible = false
	log_label.clear()
	_setup_match()
	_start_match()

# -- UI helpers --

func _refresh_hand() -> void:
	hand_panel.refresh(player_deck.hand)

func _update_possession_display() -> void:
	possession_label.text = "Possession: " + str(engine.player_possession)

func _log(text: String) -> void:
	log_label.append_text(text + "\n")

func _possession_bar(player: int, opponent: int) -> String:
	var total := player + opponent
	if total == 0:
		return "[color=gray]------[/color]"
	var player_ratio := float(player) / float(total)
	var bar_len := 20
	var player_ticks := roundi(player_ratio * bar_len)
	var opp_ticks := bar_len - player_ticks
	return "[color=green]" + "|".repeat(player_ticks) + "[/color][color=red]" + "|".repeat(opp_ticks) + "[/color]"
