class_name BigCTA
extends Button
## Chunky gold call-to-action button. Bouncy press, gold shine sweep on hover.
## Drop in anywhere a primary action lives. Inherits the GoldButton variation.

@export var shine_enabled: bool = true
@export var bounce_enabled: bool = true
## Override the default GoldButton font size (28). 0 = use theme default.
@export var label_size: int = 0

var _shine: ColorRect = null
var _shine_tween: Tween = null
var _bounce_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	theme_type_variation = &"GoldButton"
	custom_minimum_size.y = max(custom_minimum_size.y, 60.0)
	if label_size > 0:
		add_theme_font_size_override("font_size", label_size)

	pivot_offset = size / 2.0
	resized.connect(_recenter_pivot)
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	button_down.connect(_on_press)
	button_up.connect(_on_release)
	pressed.connect(_on_pressed_burst)

	# Build the shine overlay
	_shine = ColorRect.new()
	_shine.name = "ShineOverlay"
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.color = Color(1.0, 0.95, 0.65, 0.0)
	_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shine)


func _recenter_pivot() -> void:
	pivot_offset = size / 2.0


func _on_hover_in() -> void:
	if bounce_enabled:
		_tween_scale(Vector2(1.04, 1.04), 0.12)
	if shine_enabled:
		_play_shine()


func _on_hover_out() -> void:
	if bounce_enabled:
		_tween_scale(Vector2.ONE, 0.18)


func _on_press() -> void:
	if bounce_enabled:
		_tween_scale(Vector2(0.95, 0.95), 0.06)


func _on_release() -> void:
	if bounce_enabled:
		_tween_scale(Vector2(1.04, 1.04) if is_hovered() else Vector2.ONE, 0.18)


func _on_pressed_burst() -> void:
	if shine_enabled:
		_play_shine()


func is_hovered() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _tween_scale(target: Vector2, duration: float) -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", target, duration)


func _play_shine() -> void:
	if _shine == null:
		return
	if _shine_tween and _shine_tween.is_valid():
		_shine_tween.kill()
	_shine.color.a = 0.0
	_shine_tween = create_tween()
	_shine_tween.tween_property(_shine, "color:a", 0.55, 0.10).set_ease(Tween.EASE_OUT)
	_shine_tween.tween_property(_shine, "color:a", 0.0, 0.40).set_ease(Tween.EASE_IN)
