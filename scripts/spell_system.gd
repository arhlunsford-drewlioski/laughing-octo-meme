class_name SpellSystem
extends RefCounted
## Manages the spell deck, hand, and mana pool during a match.

const MAX_HAND_SIZE: int = 5
const STARTING_MANA: int = 5

var deck: Array[SpellData] = []     # Full deck (persists across matches)
var hand: Array[SpellData] = []     # Current hand (drawn at match start)
var mana: int = STARTING_MANA      # Current mana (no regen)

# Track which spells have been cast (for one-time-per-match effects)
var _cast_this_match: Array[String] = []

# Blood Pact targets: goblins that will take injury post-match
var blood_pact_targets: Array[GoblinData] = []

# Curse of the Post: number of shots to auto-miss
var curse_charges: int = 0

func setup(spell_deck: Array[SpellData]) -> void:
	## Initialize for a new match. Shuffles deck, draws hand, resets mana.
	deck = spell_deck.duplicate()
	mana = STARTING_MANA
	_cast_this_match.clear()
	blood_pact_targets.clear()
	curse_charges = 0
	_draw_hand()

func _draw_hand() -> void:
	## Draw up to MAX_HAND_SIZE from the deck (random selection, deck not consumed).
	hand.clear()
	if deck.is_empty():
		return
	var pool := deck.duplicate()
	pool.shuffle()
	var draw_count := mini(MAX_HAND_SIZE, pool.size())
	for i in draw_count:
		hand.append(pool[i])

func can_cast(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	return hand[index].mana_cost <= mana

func cast(index: int) -> SpellData:
	## Remove spell from hand and spend mana. Returns the spell, or null if can't cast.
	if not can_cast(index):
		return null
	var spell := hand[index]
	mana -= spell.mana_cost
	hand.remove_at(index)
	_cast_this_match.append(spell.spell_name)
	return spell

func get_mana_display() -> String:
	var filled := ""
	for i in STARTING_MANA:
		filled += "[color=#4d99ff]◆[/color]" if i < mana else "[color=#333344]◇[/color]"
	return filled

func apply_post_match_injuries() -> void:
	## Apply Blood Pact injuries after the match ends.
	for g in blood_pact_targets:
		if g.is_alive():
			g.apply_injury(GoblinData.InjuryState.MINOR)
