class_name CardData
extends Resource

enum CardType { TEMPO, POSSESSION, DEFENSE, EXHAUSTED, ATK_BUFF, DEF_BUFF, MID_BUFF, TACTICAL }

@export var card_name: String = ""
@export var card_type: CardType = CardType.POSSESSION
@export var energy_cost: int = 1
@export var flavor_text: String = ""

# Possession card: how much field control this card adds
@export var possession_value: int = 0

# Defense card: how much opponent possession this card blocks
@export var defense_value: int = 0

# Tempo card: base goal conversion rate before modifiers (0.0 to 1.0)
@export var base_conversion: float = 0.0

# If true, playing this card adds an Exhausted card to the deck
@export var adds_exhausted: bool = false

func is_playable() -> bool:
	return card_type != CardType.EXHAUSTED
