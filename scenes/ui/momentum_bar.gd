extends Control
## Horizontal tug-of-war bar. 11 ticks, -5 to +5. Center = neutral.

const TICK_COUNT: int = 11
const PLAYER_COLOR := Color(0.2, 0.6, 1.0)   # Blue
const OPPONENT_COLOR := Color(1.0, 0.3, 0.2)  # Red
const NEUTRAL_COLOR := Color(0.3, 0.3, 0.3)   # Gray
const MARKER_COLOR := Color(1.0, 0.9, 0.2)    # Yellow marker

var current_momentum: int = 0

func _ready() -> void:
	GameManager.momentum_changed.connect(_on_momentum_changed)
	custom_minimum_size.y = 60

func _on_momentum_changed(new_value: int) -> void:
	current_momentum = new_value
	queue_redraw()

func _draw() -> void:
	var bar_rect := Rect2(Vector2.ZERO, size)
	var tick_width: float = size.x / TICK_COUNT

	for i in TICK_COUNT:
		var tick_value: int = i - 5  # Maps 0..10 to -5..+5
		var rect := Rect2(i * tick_width, 0, tick_width - 2, size.y)

		var color: Color
		if tick_value < 0:
			color = OPPONENT_COLOR.lerp(NEUTRAL_COLOR, 1.0 - absf(tick_value) / 5.0)
		elif tick_value > 0:
			color = PLAYER_COLOR.lerp(NEUTRAL_COLOR, 1.0 - absf(tick_value) / 5.0)
		else:
			color = NEUTRAL_COLOR

		draw_rect(rect, color)

	# Draw current position marker
	var marker_index: int = current_momentum + 5  # Convert -5..+5 to 0..10
	var marker_x: float = marker_index * tick_width + tick_width * 0.5
	var marker_rect := Rect2(marker_x - 6, 2, 12, size.y - 4)
	draw_rect(marker_rect, MARKER_COLOR)
