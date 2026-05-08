class_name PageShell
extends Control
## Standard screen shell: TopRail → CenterContent → ActionBar.
## Every screen drops its content into the @CenterContent node.
## This kills the "every screen reinvents margins" disease.

@export var show_top_rail: bool = true
@export var content_margin: int = 24
@export var action_bar_height: int = 80

var top_rail: TopRail = null
var center_content: VBoxContainer = null   # screens fill this
var action_bar: HBoxContainer = null       # screens fill this with buttons

var _backdrop: ColorRect = null
var _vignette: TextureRect = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Dark tome backdrop
	_backdrop = ColorRect.new()
	_backdrop.color = UITheme.BG_NIGHT
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Subtle radial vignette: a Gradient → GradientTexture2D
	_vignette = TextureRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0, 0, 0, 0.0))
	grad.add_point(1.0, Color(0, 0, 0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	_vignette.texture = tex
	add_child(_vignette)

	# Outer thin gold frame (so the screen feels bound)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = UITheme.GOLD_DEEP
	fs.border_width_left = 2
	fs.border_width_right = 2
	fs.border_width_top = 2
	fs.border_width_bottom = 2
	frame.add_theme_stylebox_override("panel", fs)
	add_child(frame)

	# Main vertical stack
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	add_child(stack)

	# Top rail
	top_rail = TopRail.new()
	stack.add_child(top_rail)
	top_rail.visible = show_top_rail

	# Center content area (margin-wrapped)
	var center_margin := MarginContainer.new()
	center_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_margin.add_theme_constant_override("margin_left", content_margin)
	center_margin.add_theme_constant_override("margin_right", content_margin)
	center_margin.add_theme_constant_override("margin_top", 18)
	center_margin.add_theme_constant_override("margin_bottom", 12)
	stack.add_child(center_margin)

	center_content = VBoxContainer.new()
	center_content.name = "CenterContent"
	center_content.add_theme_constant_override("separation", 14)
	center_margin.add_child(center_content)

	# Action bar (CTA row at the bottom)
	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", content_margin)
	action_margin.add_theme_constant_override("margin_right", content_margin)
	action_margin.add_theme_constant_override("margin_top", 4)
	action_margin.add_theme_constant_override("margin_bottom", 16)
	action_margin.custom_minimum_size.y = action_bar_height
	stack.add_child(action_margin)

	action_bar = HBoxContainer.new()
	action_bar.name = "ActionBar"
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	action_bar.add_theme_constant_override("separation", 12)
	action_margin.add_child(action_bar)


## Convenience: drop a primary BigCTA into the action bar.
func add_primary_cta(text: String, callback: Callable) -> BigCTA:
	var btn := BigCTA.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 64)
	btn.pressed.connect(callback)
	action_bar.add_child(btn)
	return btn


## Convenience: drop a secondary (back/cancel) button into the action bar.
func add_secondary_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"SecondaryButton"
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 56)
	btn.pressed.connect(callback)
	action_bar.add_child(btn)
	# Push it to the start of the row so it sits on the left
	action_bar.move_child(btn, 0)
	return btn
