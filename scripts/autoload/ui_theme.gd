extends Node
## Global UI theme constants and helpers. Autoloaded as UITheme.

# -- Core palette (vibrant dark fantasy) --
const BG_DARK := Color(0.08, 0.08, 0.12)              # deep navy-black
const BG_PANEL := Color(0.12, 0.11, 0.16)              # slightly lighter panel
const BG_CARD := Color(0.16, 0.14, 0.22)               # card background - purple tint
const GOLD := Color(0.95, 0.78, 0.25)                  # vivid gold
const GOLD_LIGHT := Color(1.0, 0.9, 0.35)              # bright gold for titles
const CREAM := Color(0.96, 0.94, 0.9)                  # near-white for body text
const CREAM_DIM := Color(0.75, 0.72, 0.68)             # secondary text - still readable
const RED := Color(1.0, 0.3, 0.25)                     # vivid red
const GREEN := Color(0.3, 0.95, 0.4)                   # vivid green
const BLUE := Color(0.35, 0.65, 1.0)                   # vivid blue

# -- Card type colors --
const TEMPO_BG := Color(0.4, 0.12, 0.12)
const TEMPO_BORDER := Color(0.85, 0.3, 0.3)
const POSSESSION_BG := Color(0.12, 0.18, 0.4)
const POSSESSION_BORDER := Color(0.35, 0.55, 0.9)
const DEFENSE_BG := Color(0.35, 0.28, 0.1)
const DEFENSE_BORDER := Color(0.75, 0.55, 0.2)
const EXHAUSTED_BG := Color(0.12, 0.12, 0.12)
const EXHAUSTED_BORDER := Color(0.3, 0.3, 0.3)

# -- Sizing --
const CORNER_RADIUS := 6
const BORDER_WIDTH := 2
const CARD_BORDER_WIDTH := 2

# -- Font sizes (bumped up for readability) --
const FONT_TITLE := 40
const FONT_HEADER := 28
const FONT_BODY := 18
const FONT_SMALL := 14
const FONT_TINY := 11

# -- Momentum bar colors --
const MOMENTUM_PLAYER := Color(0.25, 0.6, 1.0)
const MOMENTUM_OPPONENT := Color(1.0, 0.3, 0.25)
const MOMENTUM_NEUTRAL := Color(0.2, 0.2, 0.22)
const MOMENTUM_MARKER := Color(1.0, 0.9, 0.3)

# -- Energy crystal colors --
const ENERGY_FILLED := Color(0.35, 0.65, 1.0)
const ENERGY_EMPTY := Color(0.18, 0.18, 0.25)

# -- Zone colors (formation display) --
const ZONE_ATTACK := Color(0.55, 0.15, 0.12, 0.55)
const ZONE_MIDFIELD := Color(0.15, 0.4, 0.15, 0.55)
const ZONE_DEFENSE := Color(0.12, 0.15, 0.45, 0.55)
const ZONE_GOAL := Color(0.35, 0.3, 0.1, 0.55)

# -- Table colors --
const TABLE_ROW_EVEN := Color(0.1, 0.1, 0.14, 0.7)
const TABLE_ROW_ODD := Color(0.14, 0.13, 0.18, 0.7)
const TABLE_HEADER_BG := Color(0.18, 0.16, 0.22, 0.85)

# -- Helpers --

## Create a standard panel StyleBox.
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
	var normal_bg := Color(0.18, 0.15, 0.25) if primary else Color(0.14, 0.13, 0.18)
	var hover_bg := Color(0.25, 0.2, 0.35) if primary else Color(0.2, 0.18, 0.25)
	var pressed_bg := Color(0.12, 0.1, 0.18) if primary else Color(0.1, 0.09, 0.14)
	var disabled_bg := Color(0.12, 0.12, 0.14)
	var border := GOLD if primary else Color(0.5, 0.45, 0.35)

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
