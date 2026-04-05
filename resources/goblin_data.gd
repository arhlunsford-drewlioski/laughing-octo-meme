class_name GoblinData
extends Resource
## A goblin on the roster. Flex-slotted: zone contribution depends on assigned position.

@export var goblin_name: String = ""
@export var personality: String = ""
@export var passive_description: String = ""

## Zone contribution ratings. When assigned to a zone, the goblin contributes that zone's value.
@export var attack_rating: int = 0
@export var midfield_rating: int = 0
@export var defense_rating: int = 0
@export var goal_rating: int = 0

## If true, this goblin is a keeper and is locked to the Goal zone.
@export var keeper: bool = false

func get_rating_for_zone(zone: String) -> int:
	match zone:
		"attack":
			return attack_rating
		"midfield":
			return midfield_rating
		"defense":
			return defense_rating
		"goal":
			return goal_rating
		_:
			return 0
