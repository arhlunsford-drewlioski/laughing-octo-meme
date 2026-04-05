extends Control
## Horizontal tug-of-war bar. 11 ticks, -5 to +5. Center = neutral.

const TICK_COUNT: int = 11
const PLAYER_COLOR := Color(0.2, 0.6, 1.0)   # Blue
const OPPONENT_COLOR := Color(1.0, 0.3, 0.2)  # Red
const NEUTRAL_COLOR := Color(0.3, 0.3, 0.3)   # Gray
const MARKER_COLOR := Color(1.0, 0.9, 0.2)    # Yellow marker
const SLIDE_DURATION: float = 0.4

var current_momentum: int = 0
var display_momentum: float = 0.0  # Animated value for smooth sliding

func _ready() -> void:
	GameManager.momentum_changed.connect(_on_momentum_changed)
	custom_minimum_size.y = 60

func _on_momentum_changed(new_value: int) -> void:
	current_momentum = new_value
	var tween := create_tween()
	tween.tween_property(self, "display_momentum", float(new_value), SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(queue_redraw)
	# Redraw every frame during tween
	tween.set_loops(1)
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
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

	# Draw current position marker (uses animated display_momentum)
	var marker_pos: float = display_momentum + 5.0  # Convert -5..+5 to 0..10
	var marker_x: float = marker_pos * tick_width + tick_width * 0.5
	var marker_rect := Rect2(marker_x - 6, 2, 12, size.y - 4)
	draw_rect(marker_rect, MARKER_COLOR)

	# Stop processing when animation is done
	if absf(display_momentum - float(current_momentum)) < 0.01:
		set_process(false)
