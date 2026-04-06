class_name ShopData
extends RefCounted
## Generates shop offerings and handles buy/remove transactions.

const REMOVE_COST: int = 3
const OFFERING_COUNT: int = 4

var offerings: Array[Dictionary] = []  # [{card: CardData, price: int}]

func generate_offerings() -> void:
	offerings.clear()
	var pool := CardPool.get_pool_for_stage()
	pool.shuffle()

	var count := mini(OFFERING_COUNT, pool.size())
	for i in range(count):
		offerings.append({
			"card": pool[i],
			"price": _price_for_card(pool[i]),
		})

static func _price_for_card(card: CardData) -> int:
	## Price based on energy cost and power. Range: 2-5g.
	match card.card_type:
		CardData.CardType.TEMPO:
			if card.base_conversion >= 0.50:
				return 5
			if card.base_conversion >= 0.40:
				return 4
			if card.energy_cost >= 2:
				return 3
			return 2
		CardData.CardType.POSSESSION:
			if card.possession_value >= 7:
				return 5
			if card.possession_value >= 5:
				return 4
			if card.energy_cost >= 2:
				return 3
			return 2
		CardData.CardType.DEFENSE:
			if card.defense_value >= 6:
				return 5
			if card.defense_value >= 4:
				return 4
			if card.energy_cost >= 2:
				return 3
			return 2
	return 2

func buy_card(index: int) -> bool:
	## Returns true if purchase succeeded.
	if index < 0 or index >= offerings.size():
		return false
	var offering: Dictionary = offerings[index]
	if not RunManager.spend_gold(offering["price"]):
		return false
	RunManager.add_reward_card(offering["card"])
	offerings.remove_at(index)
	return true

func can_afford_remove() -> bool:
	return RunManager.gold >= REMOVE_COST

func remove_card(deck_index: int) -> bool:
	## Returns true if removal succeeded.
	if not RunManager.spend_gold(REMOVE_COST):
		return false
	RunManager.remove_deck_card(deck_index)
	return true
