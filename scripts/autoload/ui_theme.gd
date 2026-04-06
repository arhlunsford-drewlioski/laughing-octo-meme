extends Node
## Global UI theme constants and helpers. Autoloaded as UITheme.

# -- Core palette --
const BG_DARK := Color(0.102, 0.102, 0.141)        # #1a1a24
const BG_PANEL := Color(0.165, 0.141, 0.114)        # #2a2420
const BG_CARD := Color(0.29, 0.216, 0.157)          # #4a3728
const GOLD := Color(0.788, 0.659, 0.298)            # #c9a84c
const GOLD_LIGHT := Color(1.0, 0.85, 0.2)           # bright gold for titles
const CREAM := Color(0.941, 0.902, 0.827)            # #f0e6d3
const CREAM_DIM := Color(0.706, 0.678, 0.631)       # muted cream for secondary text
const RED := Color(0.9, 0.25, 0.2)
const GREEN := Color(0.3, 0.85, 0.35)
const BLUE := Color(0.3, 0.6, 1.0)

# -- Card type colors --
const TEMPO_BG := Color(0.18, 0.35, 0.18)           # Dark green
const TEMPO_BORDER := Color(0.3, 0.6, 0.3)
const CHANCE_BG := Color(0.3, 0.15, 0.35)           # Dark purple
const CHANCE_BORDER := Color(0.55, 0.3, 0.65)
const EXHAUSTED_BG := Color(0.15, 0.15, 0.15)
const EXHAUSTED_BORDER := Color(0.3, 0.3, 0.3)

# -- Sizing --
const CORNER_RADIUS := 8
const BORDER_WIDTH := 2
const CARD_BORDER_WIDTH := 3

# -- Font sizes --
const FONT_TITLE := 36
const FONT_HEADER := 24
const FONT_BODY := 16
const FONT_SMALL := 13

# -- Momentum bar colors --
const MOMENTUM_PLAYER := Color(0.2, 0.55, 0.9)
const MOMENTUM_OPPONENT := Color(0.85, 0.25, 0.2)
const MOMENTUM_NEUTRAL := Color(0.25, 0.22, 0.2)
const MOMENTUM_MARKER := Color(1.0, 0.85, 0.2)

# -- Energy crystal colors --
const ENERGY_FILLED := Color(0.3, 0.6, 1.0)
const ENERGY_EMPTY := Color(0.2, 0.2, 0.25)

# -- Zone colors (formation display) --
const ZONE_ATTACK := Color(0.5, 0.18, 0.15, 0.5)
const ZONE_MIDFIELD := Color(0.18, 0.35, 0.18, 0.5)
const ZONE_DEFENSE := Color(0.15, 0.18, 0.4, 0.5)
const ZONE_GOAL := Color(0.3, 0.28, 0.12, 0.5)

# -- Table colors --
const TABLE_ROW_EVEN := Color(0.12, 0.11, 0.1, 0.6)
const TABLE_ROW_ODD := Color(0.16, 0.14, 0.12, 0.6)
const TABLE_HEADER_BG := Color(0.2, 0.17, 0.13, 0.8)

# -- Helpers --

## Create a standard panel StyleBox with the warm theme look.
static func make_panel_style(bg_color: Color = BG_PANEL, border_color: Color = GOLD, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
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

## Create a styled button StyleBox.
static func make_button_style(bg_color: Color, border_color: Color = GOLD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_left = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = border_color
	return style

## Apply themed button styles to a Button node.
static func style_button(btn: Button, primary: bool = true) -> void:
	var normal_bg := Color(0.29, 0.22, 0.16) if primary else Color(0.18, 0.16, 0.14)
	var hover_bg := Color(0.35, 0.27, 0.19) if primary else Color(0.22, 0.2, 0.17)
	var pressed_bg := Color(0.22, 0.17, 0.12) if primary else Color(0.14, 0.12, 0.1)
	var disabled_bg := Color(0.15, 0.14, 0.12)
	var border := GOLD if primary else Color(0.45, 0.4, 0.3)

	btn.add_theme_stylebox_override("normal", make_button_style(normal_bg, border))
	btn.add_theme_stylebox_override("hover", make_button_style(hover_bg, border))
	btn.add_theme_stylebox_override("pressed", make_button_style(pressed_bg, border))
	btn.add_theme_stylebox_override("disabled", make_button_style(disabled_bg, Color(0.3, 0.28, 0.25)))
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", GOLD_LIGHT)
	btn.add_theme_color_override("font_pressed_color", CREAM_DIM)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.38, 0.35))

## Apply gold header style to a Label.
static func style_header(label: Label, size: int = FONT_HEADER) -> void:
	label.add_theme_color_override("font_color", GOLD_LIGHT)
	label.add_theme_font_size_override("font_size", size)

## Apply cream body text style to a Label.
static func style_body(label: Label, size: int = FONT_BODY) -> void:
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_font_size_override("font_size", size)

## Apply dim secondary text style to a Label.
static func style_dim(label: Label, size: int = FONT_SMALL) -> void:
	label.add_theme_color_override("font_color", CREAM_DIM)
	label.add_theme_font_size_override("font_size", size)
