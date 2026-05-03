extends Node
## Global UI theme + medieval styling. Autoloaded as UITheme.
## On _ready() builds a Theme resource and applies it to the scene tree root,
## so every Control inherits the look without per-screen wiring.
##
## Vibe: funny medieval - illuminated manuscript / aged tavern sign.
## Parchment cream + wine red + gold leaf, on dark wood / aged-tome backgrounds.
## Display font is MedievalSharp (calligraphic, has personality).
## Body font is IM FELL English (a 17th-century printer's type, slightly aged).

# -- Fonts --
const FONT_DISPLAY_RES := preload("res://assets/fonts/MedievalSharp-Regular.ttf")
const FONT_BODY_RES := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const FONT_BODY_ITALIC_RES := preload("res://assets/fonts/IMFellEnglish-Italic.ttf")

# -- Core palette (illuminated-manuscript medieval) --
const BG_DARK := Color(0.13, 0.09, 0.06)               # dark wood / aged leather
const BG_PANEL := Color(0.20, 0.13, 0.09)              # raised wood-panel
const BG_CARD := Color(0.27, 0.18, 0.12)               # warmer wood card
const BG_NIGHT := Color(0.08, 0.06, 0.04)              # near-black tavern depth

const PARCHMENT := Color(0.94, 0.86, 0.68)             # warm cream paper
const PARCHMENT_DARK := Color(0.80, 0.70, 0.50)        # parchment shadow
const PARCHMENT_DEEP := Color(0.62, 0.51, 0.34)        # aged stain

const INK := Color(0.13, 0.07, 0.04)                   # dark sepia ink (cartoon outline)
const INK_SOFT := Color(0.25, 0.16, 0.10)

const GOLD := Color(0.86, 0.66, 0.20)                  # gold leaf
const GOLD_LIGHT := Color(0.98, 0.83, 0.36)
const GOLD_DEEP := Color(0.62, 0.42, 0.08)

const WINE := Color(0.55, 0.10, 0.12)                  # heraldic wine red
const WINE_LIGHT := Color(0.72, 0.18, 0.18)
const WINE_DEEP := Color(0.36, 0.05, 0.07)

const FOREST := Color(0.18, 0.34, 0.16)                # heraldic green
const ROYAL := Color(0.13, 0.20, 0.50)                 # heraldic blue
const PURPLE := Color(0.32, 0.10, 0.40)

# In-match feedback colors (toasts, victory/defeat, errors). Kept vivid so
# they pop on the dark match background - these are status signals, not palette.
const RED := Color(0.92, 0.30, 0.28)
const GREEN := Color(0.45, 0.85, 0.40)
const BLUE := Color(0.40, 0.60, 1.00)

const CREAM := Color(0.96, 0.90, 0.78)                 # text on dark
const CREAM_DIM := Color(0.78, 0.70, 0.55)

# -- Card type colors (kept for compatibility with existing screens) --
const TEMPO_BG := Color(0.40, 0.12, 0.12)
const TEMPO_BORDER := Color(0.85, 0.30, 0.30)
const POSSESSION_BG := Color(0.12, 0.18, 0.40)
const POSSESSION_BORDER := Color(0.35, 0.55, 0.90)
const DEFENSE_BG := Color(0.35, 0.28, 0.10)
const DEFENSE_BORDER := Color(0.75, 0.55, 0.20)
const EXHAUSTED_BG := Color(0.12, 0.12, 0.12)
const EXHAUSTED_BORDER := Color(0.30, 0.30, 0.30)

# -- Sizing --
const CORNER_RADIUS := 6           # parchment corners are not very round
const CORNER_RADIUS_SMALL := 3
const BORDER_WIDTH := 3
const CARD_BORDER_WIDTH := 3

# -- Font sizes --
const FONT_TITLE := 72
const FONT_HEADER := 36
const FONT_SUBHEADER := 24
const FONT_BODY := 18
const FONT_SMALL := 14
const FONT_TINY := 11

# -- Momentum bar colors --
const MOMENTUM_PLAYER := Color(0.30, 0.65, 1.00)
const MOMENTUM_OPPONENT := Color(1.00, 0.35, 0.30)
const MOMENTUM_NEUTRAL := Color(0.18, 0.16, 0.22)
const MOMENTUM_MARKER := Color(1.00, 0.90, 0.30)

# -- Energy crystal colors --
const ENERGY_FILLED := Color(0.35, 0.65, 1.00)
const ENERGY_EMPTY := Color(0.18, 0.18, 0.25)

# -- Zone colors (formation display) --
const ZONE_ATTACK := Color(0.55, 0.15, 0.12, 0.55)
const ZONE_MIDFIELD := Color(0.15, 0.40, 0.15, 0.55)
const ZONE_DEFENSE := Color(0.12, 0.15, 0.45, 0.55)
const ZONE_GOAL := Color(0.35, 0.30, 0.10, 0.55)

# -- Table colors --
const TABLE_ROW_EVEN := Color(0.10, 0.10, 0.14, 0.7)
const TABLE_ROW_ODD := Color(0.14, 0.13, 0.18, 0.7)
const TABLE_HEADER_BG := Color(0.18, 0.16, 0.22, 0.85)


func _ready() -> void:
	# Apply the medieval theme to the entire scene tree root so every Control
	# inherits it. Per-screen scripts can still override via theme_overrides.
	get_tree().root.theme = build_default_theme()


# ============================================================================
#  Theme construction
# ============================================================================

static func build_default_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_BODY_RES
	t.default_font_size = FONT_BODY

	# ---- Button (default = wine-red banner button with gold trim) ----
	t.set_stylebox("normal", "Button", make_button_bg(WINE, GOLD, 0))
	t.set_stylebox("hover", "Button", make_button_bg(WINE_LIGHT, GOLD_LIGHT, -2))
	t.set_stylebox("pressed", "Button", make_button_bg(WINE_DEEP, GOLD_DEEP, 2))
	t.set_stylebox("disabled", "Button", make_button_bg(Color(0.30, 0.24, 0.20), PARCHMENT_DEEP, 0))
	t.set_stylebox("focus", "Button", _make_focus_style())
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color(1, 0.96, 0.85))
	t.set_color("font_pressed_color", "Button", PARCHMENT_DARK)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.50, 0.42))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 4)
	t.set_font("font", "Button", FONT_DISPLAY_RES)
	t.set_font_size("font_size", "Button", 24)

	# ---- "GoldButton" variation: prime call-to-action (parchment-gold) ----
	t.set_type_variation("GoldButton", "Button")
	t.set_stylebox("normal", "GoldButton", make_button_bg(GOLD, INK, 0))
	t.set_stylebox("hover", "GoldButton", make_button_bg(GOLD_LIGHT, INK, -2))
	t.set_stylebox("pressed", "GoldButton", make_button_bg(GOLD_DEEP, INK, 2))
	t.set_color("font_color", "GoldButton", INK)
	t.set_color("font_hover_color", "GoldButton", INK)
	t.set_color("font_pressed_color", "GoldButton", INK)
	t.set_color("font_outline_color", "GoldButton", GOLD_LIGHT)
	t.set_constant("outline_size", "GoldButton", 0)
	t.set_font_size("font_size", "GoldButton", 28)

	# ---- "ParchmentButton": cream parchment with wine border (alt secondary) ----
	t.set_type_variation("ParchmentButton", "Button")
	t.set_stylebox("normal", "ParchmentButton", make_button_bg(PARCHMENT, WINE_DEEP, 0))
	t.set_stylebox("hover", "ParchmentButton", make_button_bg(Color(0.98, 0.92, 0.78), WINE, -2))
	t.set_stylebox("pressed", "ParchmentButton", make_button_bg(PARCHMENT_DARK, WINE_DEEP, 2))
	t.set_color("font_color", "ParchmentButton", INK)
	t.set_color("font_hover_color", "ParchmentButton", WINE_DEEP)
	t.set_color("font_pressed_color", "ParchmentButton", INK)
	t.set_constant("outline_size", "ParchmentButton", 0)
	t.set_font_size("font_size", "ParchmentButton", 22)

	# ---- "SecondaryButton": muted wood, for back/cancel ----
	t.set_type_variation("SecondaryButton", "Button")
	t.set_stylebox("normal", "SecondaryButton", make_button_bg(BG_PANEL, PARCHMENT_DEEP, 0))
	t.set_stylebox("hover", "SecondaryButton", make_button_bg(BG_CARD, PARCHMENT_DARK, -2))
	t.set_stylebox("pressed", "SecondaryButton", make_button_bg(BG_NIGHT, PARCHMENT_DEEP, 2))
	t.set_color("font_color", "SecondaryButton", PARCHMENT)
	t.set_font_size("font_size", "SecondaryButton", 20)

	# ---- Label (body text on dark backgrounds) ----
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_font("font", "Label", FONT_BODY_RES)
	t.set_font_size("font_size", "Label", FONT_BODY)

	# ---- Title label variation: huge calligraphic, gold with ink outline ----
	t.set_type_variation("TitleLabel", "Label")
	t.set_color("font_color", "TitleLabel", GOLD_LIGHT)
	t.set_color("font_outline_color", "TitleLabel", INK)
	t.set_constant("outline_size", "TitleLabel", 8)
	t.set_font("font", "TitleLabel", FONT_DISPLAY_RES)
	t.set_font_size("font_size", "TitleLabel", FONT_TITLE)

	# ---- Header label variation ----
	t.set_type_variation("HeaderLabel", "Label")
	t.set_color("font_color", "HeaderLabel", GOLD_LIGHT)
	t.set_color("font_outline_color", "HeaderLabel", INK)
	t.set_constant("outline_size", "HeaderLabel", 4)
	t.set_font("font", "HeaderLabel", FONT_DISPLAY_RES)
	t.set_font_size("font_size", "HeaderLabel", FONT_HEADER)

	# ---- Subheader (italic body, like a caption / book subtitle) ----
	t.set_type_variation("SubheaderLabel", "Label")
	t.set_color("font_color", "SubheaderLabel", PARCHMENT_DARK)
	t.set_constant("outline_size", "SubheaderLabel", 0)
	t.set_font("font", "SubheaderLabel", FONT_BODY_ITALIC_RES)
	t.set_font_size("font_size", "SubheaderLabel", FONT_SUBHEADER)

	# ---- Dim / secondary text ----
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", PARCHMENT_DEEP)
	t.set_font_size("font_size", "DimLabel", FONT_SMALL)

	# ---- ParchmentLabel: dark text on cream (for use inside parchment panels) ----
	t.set_type_variation("ParchmentLabel", "Label")
	t.set_color("font_color", "ParchmentLabel", INK)
	t.set_font("font", "ParchmentLabel", FONT_BODY_RES)
	t.set_font_size("font_size", "ParchmentLabel", FONT_BODY)

	# ---- Panel & PanelContainer ----
	t.set_stylebox("panel", "Panel", make_panel_bg(BG_PANEL, INK))
	t.set_stylebox("panel", "PanelContainer", make_panel_bg(BG_PANEL, INK))

	# ---- Card / parchment variations ----
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", make_panel_bg(BG_CARD, INK))

	t.set_type_variation("ParchmentPanel", "PanelContainer")
	t.set_stylebox("panel", "ParchmentPanel", make_panel_bg(PARCHMENT, INK))

	t.set_type_variation("WoodPanel", "PanelContainer")
	t.set_stylebox("panel", "WoodPanel", make_panel_bg(BG_DARK, GOLD_DEEP, 4))

	# ---- ScrollContainer chrome ----
	t.set_stylebox("scroll", "VScrollBar", _make_scroll_track())
	t.set_stylebox("grabber", "VScrollBar", _make_scroll_grabber(false))
	t.set_stylebox("grabber_highlight", "VScrollBar", _make_scroll_grabber(true))
	t.set_stylebox("grabber_pressed", "VScrollBar", _make_scroll_grabber(true))
	t.set_stylebox("scroll", "HScrollBar", _make_scroll_track())
	t.set_stylebox("grabber", "HScrollBar", _make_scroll_grabber(false))
	t.set_stylebox("grabber_highlight", "HScrollBar", _make_scroll_grabber(true))
	t.set_stylebox("grabber_pressed", "HScrollBar", _make_scroll_grabber(true))

	return t


# ============================================================================
#  StyleBox factories
# ============================================================================

## Banner-style button. Slightly raised / pressed feel via content-margin shift.
static func make_button_bg(bg: Color, border: Color, y_offset: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(CORNER_RADIUS)
	s.border_color = border
	s.border_width_left = BORDER_WIDTH
	s.border_width_right = BORDER_WIDTH
	s.border_width_top = BORDER_WIDTH
	s.border_width_bottom = BORDER_WIDTH
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12 + y_offset
	s.content_margin_bottom = 12 - y_offset
	s.shadow_color = Color(0, 0, 0, 0.40)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 4 - y_offset)
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.0
	return s


## Parchment / card panel. Square-ish corners, ink border, soft drop shadow.
static func make_panel_bg(bg: Color, border: Color, border_width: int = CARD_BORDER_WIDTH) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(CORNER_RADIUS)
	s.border_color = border
	s.border_width_left = border_width
	s.border_width_right = border_width
	s.border_width_top = border_width
	s.border_width_bottom = border_width
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 5)
	s.anti_aliasing = true
	return s


static func _make_focus_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_corner_radius_all(CORNER_RADIUS + 2)
	s.border_color = GOLD_LIGHT
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 3
	s.expand_margin_bottom = 3
	return s


static func _make_scroll_track() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.30)
	s.set_corner_radius_all(4)
	return s


static func _make_scroll_grabber(highlighted: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = GOLD_LIGHT if highlighted else GOLD
	s.set_corner_radius_all(4)
	s.border_color = INK
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	return s


# ============================================================================
#  Legacy helpers (kept so existing screens compile)
# ============================================================================

static func make_panel_style(bg_color: Color = BG_PANEL, border_color: Color = INK, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_color = border_color
	return style


static func make_button_style(bg_color: Color, border_color: Color = INK) -> StyleBoxFlat:
	return make_button_bg(bg_color, border_color, 0)


static func style_button(btn: Button, primary: bool = true) -> void:
	if not primary:
		btn.theme_type_variation = &"SecondaryButton"


static func style_header(label: Label, size: int = FONT_HEADER) -> void:
	label.theme_type_variation = &"HeaderLabel"
	if size != FONT_HEADER:
		label.add_theme_font_size_override("font_size", size)


static func style_body(label: Label, size: int = FONT_BODY) -> void:
	label.add_theme_color_override("font_color", PARCHMENT)
	label.add_theme_font_size_override("font_size", size)


static func style_dim(label: Label, size: int = FONT_SMALL) -> void:
	label.theme_type_variation = &"DimLabel"
	if size != FONT_SMALL:
		label.add_theme_font_size_override("font_size", size)
