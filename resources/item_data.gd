class_name ItemData
extends Resource
## An equippable item for a goblin. One slot per goblin.

@export var item_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON

## Stat bonuses: {"shooting": 1, "speed": 2, ...}
@export var stat_bonuses: Dictionary = {}

## Special effect key (empty = pure stat item)
@export var special_effect: String = ""

enum Rarity { COMMON, UNCOMMON, RARE }

func get_stat_bonus(stat_name: String) -> int:
	return stat_bonuses.get(stat_name, 0)

func get_total_bonus() -> int:
	var total := 0
	for val in stat_bonuses.values():
		total += val
	return total

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.7, 0.7, 0.65)
		Rarity.UNCOMMON:
			return Color(0.3, 0.75, 0.4)
		Rarity.RARE:
			return Color(0.55, 0.4, 0.9)
	return Color.WHITE

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
	return ""

func get_price() -> int:
	match rarity:
		Rarity.COMMON:
			return 30
		Rarity.UNCOMMON:
			return 50
		Rarity.RARE:
			return 70
	return 30

func get_short_stats() -> String:
	var parts: Array[String] = []
	for stat_name in stat_bonuses:
		var val: int = stat_bonuses[stat_name]
		if val != 0:
			var prefix := "+" if val > 0 else ""
			parts.append(stat_name.left(3).to_upper() + prefix + str(val))
	if special_effect != "":
		parts.append(special_effect)
	return " ".join(parts)
