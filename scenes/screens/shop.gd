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

	shop = ShopData.new()
	shop.generate_offerings()

	deck_panel.visible = false
	removing = false

	_refresh_gold()
	_refresh_offerings()
	_refresh_remove_btn()
	tier_label.text = CardPool.get_tier_label()
	tier_label.add_theme_color_override("font_color", UITheme.ENERGY_FILLED)

func _refresh_gold() -> void:
	gold_label.text = str(RunManager.gold) + "g"

func _on_gold_changed(_new_gold: int) -> void:
	_refresh_gold()
	_refresh_remove_btn()

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

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/tournament_hub.tscn")
