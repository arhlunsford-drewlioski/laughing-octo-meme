extends Control
## Post-match shop screen. Buy cards or remove cards from your deck.

const CARD_UI_SCENE := preload("res://scenes/ui/card_ui.tscn")

var shop: ShopData
var removing: bool = false

@onready var gold_label: Label = %GoldLabel
@onready var tier_label: Label = %TierLabel
@onready var card_row: HBoxContainer = %CardRow
@onready var remove_btn: Button = %RemoveBtn
@onready var continue_btn: Button = %ContinueBtn
@onready var deck_panel: PanelContainer = %DeckPanel
@onready var deck_row: HBoxContainer = %DeckRow
@onready var deck_close_btn: Button = %DeckCloseBtn
@onready var shop_label: Label = %ShopLabel
@onready var heal_label: Label = %HealLabel
@onready var heal_row: HBoxContainer = %HealRow
@onready var recruit_label: Label = %RecruitLabel
@onready var recruit_row: HBoxContainer = %RecruitRow
@onready var item_label: Label = %ItemLabel
@onready var item_row: HBoxContainer = %ItemRow
@onready var spell_label: Label = %SpellLabel
@onready var spell_row: HBoxContainer = %SpellRow

# Recruitment offerings: [{goblin: GoblinData, price: int}]
var recruit_offerings: Array[Dictionary] = []

# Item offerings: Array[ItemData]
var item_offerings: Array[ItemData] = []

# Item equip state: which item is waiting to be assigned to a goblin
var _pending_item: ItemData = null

# Spell offerings: Array[SpellData]
var spell_offerings: Array[SpellData] = []

func _ready() -> void:
	remove_btn.pressed.connect(_on_remove_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	deck_close_btn.pressed.connect(_on_deck_close)
	RunManager.gold_changed.connect(_on_gold_changed)

	# Apply theme styling
	UITheme.style_button(remove_btn, false)
	UITheme.style_button(continue_btn)
	UITheme.style_button(deck_close_btn, false)
	UITheme.style_header(shop_label, UITheme.FONT_HEADER)
	UITheme.style_header(heal_label, 20)
	UITheme.style_header(recruit_label, 20)
	UITheme.style_header(item_label, 20)
	UITheme.style_header(spell_label, 20)

	shop = ShopData.new()
	shop.generate_offerings()
	_generate_recruits()
	_generate_items()
	_generate_spells()

	deck_panel.visible = false
	removing = false

	_refresh_gold()
	_refresh_offerings()
	_refresh_remove_btn()
	_refresh_healing()
	_refresh_recruits()
	_refresh_items()
	_refresh_spells()
	tier_label.text = CardPool.get_tier_label()
	tier_label.add_theme_color_override("font_color", UITheme.ENERGY_FILLED)

func _refresh_gold() -> void:
	gold_label.text = str(RunManager.gold) + "g"

func _on_gold_changed(_new_gold: int) -> void:
	_refresh_gold()
	_refresh_remove_btn()
	_refresh_healing()
	_refresh_recruits()
	_refresh_items()
	_refresh_spells()

func _refresh_offerings() -> void:
	for child in card_row.get_children():
		child.queue_free()

	if shop.offerings.is_empty():
		var empty := Label.new()
		empty.text = "Sold out!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		card_row.add_child(empty)
		return

	for i in range(shop.offerings.size()):
		var offering: Dictionary = shop.offerings[i]
		var card: CardData = offering["card"]
		var price: int = offering["price"]

		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var card_ui := CARD_UI_SCENE.instantiate()
		container.add_child(card_ui)
		card_ui.setup(card, i)
		card_ui.card_clicked.connect(_on_buy_card)

		var price_label := Label.new()
		price_label.text = str(price) + "g"
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 18)
		if RunManager.gold < price:
			price_label.add_theme_color_override("font_color", UITheme.RED)
		else:
			price_label.add_theme_color_override("font_color", UITheme.GOLD)
		container.add_child(price_label)

		card_row.add_child(container)

func _on_buy_card(index: int) -> void:
	if removing:
		return
	if shop.buy_card(index):
		_refresh_offerings()

func _refresh_remove_btn() -> void:
	remove_btn.text = "Remove a Card (" + str(ShopData.REMOVE_COST) + "g)"
	remove_btn.disabled = not shop.can_afford_remove() or RunManager.run_deck_cards.size() <= 1

func _on_remove_pressed() -> void:
	if not shop.can_afford_remove():
		return
	removing = true
	deck_panel.visible = true
	shop_label.text = "Tap a card to remove it"
	_refresh_deck_view()

func _refresh_deck_view() -> void:
	for child in deck_row.get_children():
		child.queue_free()

	for i in range(RunManager.run_deck_cards.size()):
		var card: CardData = RunManager.run_deck_cards[i]
		var card_ui := CARD_UI_SCENE.instantiate()
		deck_row.add_child(card_ui)
		card_ui.setup(card, i)
		card_ui.card_clicked.connect(_on_remove_card)

func _on_remove_card(index: int) -> void:
	if not removing:
		return
	if shop.remove_card(index):
		removing = false
		deck_panel.visible = false
		shop_label.text = "SHOP"
		_refresh_offerings()
		_refresh_remove_btn()

func _on_deck_close() -> void:
	removing = false
	deck_panel.visible = false
	shop_label.text = "SHOP"

func _refresh_healing() -> void:
	for child in heal_row.get_children():
		child.queue_free()

	var injured: Array[GoblinData] = []
	for g in RunManager.get_player_roster():
		if g.injury == GoblinData.InjuryState.MINOR or g.injury == GoblinData.InjuryState.MAJOR:
			injured.append(g)

	if injured.is_empty():
		heal_label.visible = false
		heal_row.get_parent().visible = false
		return

	heal_label.visible = true
	heal_row.get_parent().visible = true

	for g in injured:
		var is_major := g.injury == GoblinData.InjuryState.MAJOR
		var cost := RunManager.HEAL_MAJOR_COST if is_major else RunManager.HEAL_MINOR_COST
		var severity_text := "MAJOR" if is_major else "MINOR"
		var severity_color: Color = Color.RED if is_major else Color.ORANGE

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(160, 100)
		var style := UITheme.make_panel_style(UITheme.BG_CARD, severity_color, 1)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		var name_label := Label.new()
		name_label.text = g.goblin_name
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
		vbox.add_child(name_label)

		var injury_label := Label.new()
		injury_label.text = severity_text + " INJURY"
		injury_label.add_theme_font_size_override("font_size", 11)
		injury_label.add_theme_color_override("font_color", severity_color)
		vbox.add_child(injury_label)

		# Show affected stats
		var penalty_text := ""
		for stat_name in g.injury_stat_penalties:
			var val: int = g.injury_stat_penalties[stat_name]
			penalty_text += stat_name.left(3).to_upper() + str(val) + " "
		if penalty_text != "":
			var penalty_label := Label.new()
			penalty_label.text = penalty_text.strip_edges()
			penalty_label.add_theme_font_size_override("font_size", 10)
			penalty_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
			vbox.add_child(penalty_label)

		var heal_btn := Button.new()
		heal_btn.text = "HEAL (" + str(cost) + "g)"
		heal_btn.custom_minimum_size = Vector2(0, 30)
		heal_btn.add_theme_font_size_override("font_size", 12)
		heal_btn.disabled = RunManager.gold < cost
		UITheme.style_button(heal_btn, RunManager.gold >= cost)
		heal_btn.pressed.connect(_on_heal_goblin.bind(g, cost))
		vbox.add_child(heal_btn)

		heal_row.add_child(panel)

func _on_heal_goblin(g: GoblinData, cost: int) -> void:
	if RunManager.spend_gold(cost):
		g.heal_injury()
		_refresh_healing()

# ── Recruitment ──────────────────────────────────────────────────────────────

func _generate_recruits() -> void:
	recruit_offerings.clear()
	var recruits := GoblinDatabase.generate_recruits(3)
	for g in recruits:
		var price := randi_range(RunManager.RECRUIT_COST_MIN, RunManager.RECRUIT_COST_MAX)
		recruit_offerings.append({"goblin": g, "price": price})

func _refresh_recruits() -> void:
	for child in recruit_row.get_children():
		child.queue_free()

	if recruit_offerings.is_empty():
		recruit_label.visible = false
		recruit_row.get_parent().visible = false
		return

	recruit_label.visible = true
	recruit_row.get_parent().visible = true

	var roster_count := RunManager.get_player_roster().size()
	recruit_label.text = "RECRUITMENT (Roster: %d)" % roster_count

	for i in range(recruit_offerings.size()):
		var offering: Dictionary = recruit_offerings[i]
		var g: GoblinData = offering["goblin"]
		var price: int = offering["price"]

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(170, 130)
		var faction_info := FactionSystem.get_faction_info(g.faction)
		var border_color: Color = faction_info["color"]
		var style := UITheme.make_panel_style(UITheme.BG_CARD, border_color, 1)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		# Name
		var name_label := Label.new()
		name_label.text = g.goblin_name
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
		vbox.add_child(name_label)

		# Position + faction
		var pos_label := Label.new()
		pos_label.text = g.position.capitalize() + " (" + faction_info["name"] + ")"
		pos_label.add_theme_font_size_override("font_size", 10)
		pos_label.add_theme_color_override("font_color", border_color)
		vbox.add_child(pos_label)

		# Stats
		var stats_text := "SH:%d SP:%d DE:%d ST:%d HP:%d CH:%d" % [
			g.get_stat("shooting"), g.get_stat("speed"), g.get_stat("defense"),
			g.get_stat("strength"), g.get_stat("health"), g.get_stat("chaos")]
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 10)
		stats_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		vbox.add_child(stats_label)

		# Personality
		var pers_label := Label.new()
		pers_label.text = g.personality
		pers_label.add_theme_font_size_override("font_size", 9)
		pers_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
		pers_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(pers_label)

		# Recruit button
		var recruit_btn := Button.new()
		recruit_btn.text = "RECRUIT (" + str(price) + "g)"
		recruit_btn.custom_minimum_size = Vector2(0, 30)
		recruit_btn.add_theme_font_size_override("font_size", 12)
		recruit_btn.disabled = RunManager.gold < price
		UITheme.style_button(recruit_btn, RunManager.gold >= price)
		recruit_btn.pressed.connect(_on_recruit_goblin.bind(i))
		vbox.add_child(recruit_btn)

		recruit_row.add_child(panel)

func _on_recruit_goblin(index: int) -> void:
	if index < 0 or index >= recruit_offerings.size():
		return
	var offering: Dictionary = recruit_offerings[index]
	var g: GoblinData = offering["goblin"]
	var price: int = offering["price"]
	if RunManager.spend_gold(price):
		RunManager.get_player_roster().append(g)
		recruit_offerings.remove_at(index)
		_refresh_recruits()

# ── Items ────────────────────────────────────────────────────────────────────

func _generate_items() -> void:
	item_offerings = ItemDatabase.generate_shop_items(3)

func _refresh_items() -> void:
	for child in item_row.get_children():
		child.queue_free()

	if item_offerings.is_empty() and _pending_item == null:
		item_label.visible = false
		item_row.get_parent().visible = false
		return

	item_label.visible = true
	item_row.get_parent().visible = true

	if _pending_item != null:
		# Show goblin picker for equipping
		item_label.text = "EQUIP: %s - Pick a goblin" % _pending_item.item_name
		var roster := RunManager.get_alive_roster()
		for g in roster:
			var panel := _make_equip_target_panel(g)
			item_row.add_child(panel)
		return

	item_label.text = "EQUIPMENT"
	for i in range(item_offerings.size()):
		var item: ItemData = item_offerings[i]
		var panel := _make_item_panel(item, i)
		item_row.add_child(panel)

func _make_item_panel(item: ItemData, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 120)
	var border_color := item.get_rarity_color()
	var style := UITheme.make_panel_style(UITheme.BG_CARD, border_color, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = item.item_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", border_color)
	vbox.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = item.get_rarity_name()
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	vbox.add_child(rarity_label)

	var stats_label := Label.new()
	stats_label.text = item.get_short_stats()
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", UITheme.CREAM)
	vbox.add_child(stats_label)

	var desc_label := Label.new()
	desc_label.text = item.description
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var price := item.get_price()
	var buy_btn := Button.new()
	buy_btn.text = "BUY (" + str(price) + "g)"
	buy_btn.custom_minimum_size = Vector2(0, 30)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.disabled = RunManager.gold < price
	UITheme.style_button(buy_btn, RunManager.gold >= price)
	buy_btn.pressed.connect(_on_buy_item.bind(index))
	vbox.add_child(buy_btn)

	return panel

func _on_buy_item(index: int) -> void:
	if index < 0 or index >= item_offerings.size():
		return
	var item: ItemData = item_offerings[index]
	var price := item.get_price()
	if RunManager.spend_gold(price):
		item_offerings.remove_at(index)
		_pending_item = item
		_refresh_items()

func _make_equip_target_panel(g: GoblinData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 100)
	var style := UITheme.make_panel_style(UITheme.BG_CARD, UITheme.CREAM_DIM, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = g.goblin_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UITheme.GOLD_LIGHT)
	vbox.add_child(name_label)

	var pos_label := Label.new()
	pos_label.text = g.position.capitalize()
	pos_label.add_theme_font_size_override("font_size", 10)
	pos_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	vbox.add_child(pos_label)

	if g.has_item():
		var old_item: ItemData = g.equipped_item as ItemData
		var old_label := Label.new()
		old_label.text = "Has: " + old_item.item_name
		old_label.add_theme_font_size_override("font_size", 9)
		old_label.add_theme_color_override("font_color", old_item.get_rarity_color())
		vbox.add_child(old_label)

	var equip_btn := Button.new()
	equip_btn.text = "EQUIP HERE"
	if g.has_item():
		equip_btn.text = "REPLACE"
	equip_btn.custom_minimum_size = Vector2(0, 30)
	equip_btn.add_theme_font_size_override("font_size", 12)
	UITheme.style_button(equip_btn)
	equip_btn.pressed.connect(_on_equip_to_goblin.bind(g))
	vbox.add_child(equip_btn)

	return panel

func _on_equip_to_goblin(g: GoblinData) -> void:
	if _pending_item == null:
		return
	g.equip_item(_pending_item)  # Old item is discarded (replaced)
	_pending_item = null
	_refresh_items()

# ── Spells ───────────────────────────────────────────────────────────────────

func _generate_spells() -> void:
	spell_offerings.clear()
	var pool := SpellDatabase.shop_pool()
	pool.shuffle()
	var count := mini(3, pool.size())
	for i in count:
		spell_offerings.append(pool[i])

func _refresh_spells() -> void:
	for child in spell_row.get_children():
		child.queue_free()

	if spell_offerings.is_empty():
		spell_label.visible = false
		spell_row.get_parent().visible = false
		return

	spell_label.visible = true
	spell_row.get_parent().visible = true
	spell_label.text = "SPELLS (Deck: %d)" % RunManager.run_spell_deck.size()

	for i in range(spell_offerings.size()):
		var spell: SpellData = spell_offerings[i]
		var panel := _make_spell_panel(spell, i)
		spell_row.add_child(panel)

func _make_spell_panel(spell: SpellData, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 130)
	var border_color := _get_spell_rarity_color(spell)
	var style := UITheme.make_panel_style(UITheme.BG_CARD, border_color, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Name
	var name_label := Label.new()
	name_label.text = spell.spell_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", border_color)
	vbox.add_child(name_label)

	# Mana cost + rarity
	var mana_label := Label.new()
	var rarity_text := _get_spell_rarity_name(spell)
	mana_label.text = "%d Mana  %s" % [spell.mana_cost, rarity_text]
	mana_label.add_theme_font_size_override("font_size", 10)
	mana_label.add_theme_color_override("font_color", UITheme.ENERGY_FILLED)
	vbox.add_child(mana_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = spell.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", UITheme.CREAM_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Stat modifiers
	if not spell.stat_modifiers.is_empty():
		var mod_parts: Array[String] = []
		for stat_name in spell.stat_modifiers:
			var val: int = spell.stat_modifiers[stat_name]
			var prefix := "+" if val > 0 else ""
			mod_parts.append(stat_name.left(3).to_upper() + prefix + str(val))
		var mod_label := Label.new()
		mod_label.text = " ".join(mod_parts)
		mod_label.add_theme_font_size_override("font_size", 10)
		mod_label.add_theme_color_override("font_color", UITheme.CREAM)
		vbox.add_child(mod_label)

	# Buy button
	var price: int = spell.shop_cost
	var buy_btn := Button.new()
	buy_btn.text = "BUY (" + str(price) + "g)"
	buy_btn.custom_minimum_size = Vector2(0, 30)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.disabled = RunManager.gold < price
	UITheme.style_button(buy_btn, RunManager.gold >= price)
	buy_btn.pressed.connect(_on_buy_spell.bind(index))
	vbox.add_child(buy_btn)

	return panel

func _on_buy_spell(index: int) -> void:
	if index < 0 or index >= spell_offerings.size():
		return
	var spell: SpellData = spell_offerings[index]
	var price: int = spell.shop_cost
	if RunManager.spend_gold(price):
		RunManager.add_spell_card(spell)
		spell_offerings.remove_at(index)
		_refresh_spells()

func _get_spell_rarity_color(spell: SpellData) -> Color:
	match spell.rarity:
		SpellData.Rarity.COMMON:
			return Color(0.5, 0.7, 1.0)
		SpellData.Rarity.UNCOMMON:
			return Color(0.4, 0.85, 0.5)
		SpellData.Rarity.RARE:
			return Color(0.7, 0.4, 0.95)
	return UITheme.CREAM

func _get_spell_rarity_name(spell: SpellData) -> String:
	match spell.rarity:
		SpellData.Rarity.COMMON:
			return "Common"
		SpellData.Rarity.UNCOMMON:
			return "Uncommon"
		SpellData.Rarity.RARE:
			return "Rare"
	return ""

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
