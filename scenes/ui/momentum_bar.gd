extends Control
## Gradient-fill momentum bar. Smooth tug-of-war from -5 to +5.

const SLIDE_DURATION: float = 0.4
const BAR_HEIGHT: float = 28.0
const NOTCH_COUNT: int = 11

var current_momentum: int = 0
var display_momentum: float = 0.0

func _ready() -> void:
	GameManager.momentum_changed.connect(_on_momentum_changed)
	custom_minimum_size.y = 40

func _on_momentum_changed(new_value: int) -> void:
	current_momentum = new_value
	var tween := create_tween()
	tween.tween_property(self, "display_momentum", float(new_value), SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()
	if absf(display_momentum - float(current_momentum)) < 0.01:
		set_process(false)

func _draw() -> void:
	var bar_y: float = (size.y - BAR_HEIGHT) / 2.0
	var bar_w: float = size.x
	var corner: float = UITheme.CORNER_RADIUS

	# Background track
	var bg_rect := Rect2(0, bar_y, bar_w, BAR_HEIGHT)
	draw_rect(bg_rect, UITheme.MOMENTUM_NEUTRAL)

	# Gradient fill based on momentum position
	# display_momentum: -5 to +5, map to 0..1
	var ratio: float = (display_momentum + 5.0) / 10.0
	ratio = clampf(ratio, 0.0, 1.0)
	var center_x: float = bar_w * 0.5
	var fill_x: float = bar_w * ratio

	if fill_x > center_x:
		# Player advantage - fill from center to right in blue
		var fill_rect := Rect2(center_x, bar_y, fill_x - center_x, BAR_HEIGHT)
		draw_rect(fill_rect, UITheme.MOMENTUM_PLAYER)
	elif fill_x < center_x:
		# Opponent advantage - fill from fill_x to center in red
		var fill_rect := Rect2(fill_x, bar_y, center_x - fill_x, BAR_HEIGHT)
		draw_rect(fill_rect, UITheme.MOMENTUM_OPPONENT)

	# Draw notch lines
	for i in range(1, NOTCH_COUNT):
		var nx: float = (float(i) / float(NOTCH_COUNT)) * bar_w
		var notch_color := Color(1, 1, 1, 0.15)
		if i == 5:
			notch_color = Color(1, 1, 1, 0.4)  # Center line brighter
		draw_line(Vector2(nx, bar_y), Vector2(nx, bar_y + BAR_HEIGHT), notch_color, 1.0)

	# Draw marker diamond at current position
	var marker_x: float = fill_x
	var marker_cy: float = bar_y + BAR_HEIGHT / 2.0
	var marker_size: float = 10.0
	var marker_points: PackedVector2Array = [
		Vector2(marker_x, marker_cy - marker_size),
		Vector2(marker_x + marker_size, marker_cy),
		Vector2(marker_x, marker_cy + marker_size),
		Vector2(marker_x - marker_size, marker_cy),
	]
	draw_colored_polygon(marker_points, UITheme.MOMENTUM_MARKER)

	# Draw border around the whole bar
	draw_rect(bg_rect, UITheme.GOLD, false, 2.0)

	# Labels at edges
	var font := ThemeDB.fallback_font
	var font_size := 11
	draw_string(font, Vector2(4, bar_y - 4), "OPP", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.MOMENTUM_OPPONENT)
	draw_string(font, Vector2(bar_w - 30, bar_y - 4), "YOU", HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, UITheme.MOMENTUM_PLAYER)
