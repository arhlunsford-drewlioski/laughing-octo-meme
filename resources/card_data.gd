class_name CardData
extends Resource

enum CardType { TEMPO, CHANCE, EXHAUSTED }

@export var card_name: String = ""
@export var card_type: CardType = CardType.TEMPO
@export var energy_cost: int = 1
@export var flavor_text: String = ""

# Tempo card: how much Possession this card adds
@export var possession_value: int = 0

# Chance card: base conversion rate before Momentum/zone modifiers (0.0 to 1.0)
@export var base_conversion: float = 0.0

# If true, playing this card adds an Exhausted card to the deck
@export var adds_exhausted: bool = false

func is_playable() -> bool:
	return card_type != CardType.EXHAUSTED
