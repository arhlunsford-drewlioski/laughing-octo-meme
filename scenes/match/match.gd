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

# -- Game systems --
var player_deck: Deck
var opponent_deck: Deck
var engine: MatchEngine
var ai: AIOpponent

# Chance cards queued by the player this round
var player_queued_chances: Array[CardData] = []

func _ready() -> void:
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
	ai = AIOpponent.new(opponent_deck)

	# Connect UI
	hand_panel.card_selected.connect(_on_card_selected)
	end_round_btn.pressed.connect(_on_end_round_pressed)
	halftime_btn.pressed.connect(_on_halftime_continue)
	halftime_btn.visible = false

	formation_display.formation_changed.connect(_on_formation_changed)
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
	player_deck.draw_cards(GameManager.HAND_DRAW_SIZE)

	opponent_deck.discard_hand()
	opponent_deck.draw_cards(GameManager.HAND_DRAW_SIZE)

	_refresh_hand()
	_update_possession_display()
	end_round_btn.disabled = false

	# Show hand, hide halftime button
	halftime_btn.visible = false
	formation_display.set_interactive(false)

	_log("[color=yellow]-- Round " + str(GameManager.current_round) + " --[/color]")

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
	player_deck.draw_cards(GameManager.HAND_DRAW_SIZE)

	opponent_deck.discard_hand()
	opponent_deck.draw_cards(GameManager.HAND_DRAW_SIZE)

	_refresh_hand()
	_update_possession_display()
	end_round_btn.disabled = false

	_log("[color=yellow]-- Round " + str(GameManager.current_round) + " --[/color]")

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
			_log("Played [color=green]" + played.card_name + "[/color] (+" + str(played.possession_value) + " possession)")
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
				_log("Opponent played [color=red]" + card.card_name + "[/color]")
			CardData.CardType.CHANCE:
				_log("Opponent readied [color=red]" + card.card_name + "[/color]")

	# 1. Resolve possession
	_log("")
	_log("Possession: YOU " + str(engine.player_possession) + " vs " + str(engine.opponent_possession) + " OPP")
	var momentum_shift := engine.resolve_possession()
	if momentum_shift != 0:
		GameManager.shift_momentum(momentum_shift)
		var direction := "toward you" if momentum_shift > 0 else "toward opponent"
		_log("Momentum shifts " + direction + " (" + ("+" if momentum_shift > 0 else "") + str(momentum_shift) + ")")
	else:
		_log("Momentum holds.")

	# 2. Resolve chance cards
	var results := engine.resolve_all_chances(GameManager.momentum)
	for result in results:
		var card: CardData = result["card"]
		var is_player: bool = result["is_player"]
		var converted: bool = result["converted"]
		var threshold: float = result["threshold"]
		var side := "YOU" if is_player else "OPP"

		if converted:
			GameManager.add_goal(is_player)
			_log("[color=yellow]GOAL! " + side + " - " + card.card_name + " converts! (" + str(roundi(threshold * 100)) + "% chance)[/color]")
		else:
			_log(side + " - " + card.card_name + " misses. (" + str(roundi(threshold * 100)) + "% chance)")

	_log("")

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

# -- UI helpers --

func _refresh_hand() -> void:
	hand_panel.refresh(player_deck.hand)

func _update_possession_display() -> void:
	possession_label.text = "Possession: " + str(engine.player_possession)

func _log(text: String) -> void:
	log_label.append_text(text + "\n")
