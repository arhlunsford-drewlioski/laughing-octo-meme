extends Control
## Individual goblin token node. Can be tweened, highlighted, and later swapped for sprite art.

const TOKEN_RADIUS := 18.0
const TOKEN_FONT_SIZE := 10

const PLAYER_BG := Color(0.18, 0.35, 0.22)
const PLAYER_BORDER := Color(0.788, 0.659, 0.298)
const OPPONENT_BG := Color(0.35, 0.15, 0.15)
const OPPONENT_BORDER := Color(0.7, 0.25, 0.2)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2, 0.6)

var goblin_data: GoblinData
var zone: String = ""
var is_player: bool = true
var base_position: Vector2 = Vector2.ZERO  # Home position (set by pitch)
var highlighted: bool = false
var has_ball: bool = false  # Ball carrier glow
var targetable: bool = false  # Fireball targeting mode

var _highlight_tween: Tween
var _ball_glow_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(TOKEN_RADIUS * 2, TOKEN_RADIUS * 2)
	size = custom_minimum_size
	pivot_offset = Vector2(TOKEN_RADIUS, TOKEN_RADIUS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(p_goblin: GoblinData, p_zone: String, p_is_player: bool) -> void:
	goblin_data = p_goblin
	zone = p_zone
	is_player = p_is_player
	queue_redraw()

func set_highlight(on: bool) -> void:
	if highlighted == on:
		return
	highlighted = on
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	if on:
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.tween_property(self, "modulate", Color(1.4, 1.2, 0.8, 1.0), 0.3)
		_highlight_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	else:
		modulate = Color.WHITE
	queue_redraw()

func set_has_ball(on: bool) -> void:
	if has_ball == on:
		return
	has_ball = on
	if _ball_glow_tween and _ball_glow_tween.is_valid():
		_ball_glow_tween.kill()
	if on:
		_ball_glow_tween = create_tween().set_loops()
		_ball_glow_tween.tween_property(self, "modulate", Color(1.25, 1.15, 0.85, 1.0), 0.4)
		_ball_glow_tween.tween_property(self, "modulate", Color(1.05, 1.0, 0.95, 1.0), 0.4)
	else:
		if not highlighted:
			modulate = Color.WHITE
	queue_redraw()

func flash_event(event_type: String) -> void:
	## Brief visual flash for match events.
	var flash_color: Color
	var do_bounce: bool = false
	match event_type:
		"goal":
			flash_color = Color(1.5, 1.3, 0.5)
			do_bounce = true
		"shot":
			flash_color = Color(1.3, 1.2, 0.8)
		"tackle", "foul":
			flash_color = Color(1.4, 0.4, 0.3)
		"save":
			flash_color = Color(0.5, 1.5, 0.5)
		"interception":
			flash_color = Color(0.4, 0.9, 1.4)
		"dispossessed", "bad_touch":
			flash_color = Color(1.2, 0.6, 0.3)
		"pass":
			flash_color = Color(1.1, 1.1, 1.0)
		"cross":
			flash_color = Color(1.0, 1.2, 0.8)
		"block":
			flash_color = Color(0.8, 0.5, 1.3)
		"take_on":
			flash_color = Color(0.7, 0.9, 1.4)
		"injury":
			flash_color = Color(1.4, 0.6, 0.2)
		"death", "fireball":
			flash_color = Color(1.5, 0.2, 0.1)
			do_bounce = true
		_:
			return

	var tween := create_tween()
	tween.tween_property(self, "modulate", flash_color, 0.1)
	if do_bounce:
		tween.parallel().tween_property(self, "scale", Vector2(1.4, 1.4), 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func set_targetable(on: bool) -> void:
	targetable = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func get_center() -> Vector2:
	## Returns the center of this token in parent coordinates.
	return position + Vector2(TOKEN_RADIUS, TOKEN_RADIUS)

func _draw() -> void:
	if goblin_data == null:
		return

	var center := Vector2(TOKEN_RADIUS, TOKEN_RADIUS)
	var bg_color: Color = PLAYER_BG if is_player else OPPONENT_BG
	var border_color: Color = PLAYER_BORDER if is_player else OPPONENT_BORDER
	var alpha: float = 1.0 if is_player else 0.75

	# Circle background
	draw_circle(center, TOKEN_RADIUS, Color(bg_color.r, bg_color.g, bg_color.b, alpha))

	# Circle border
	var border_w: float = 2.0
	draw_arc(center, TOKEN_RADIUS, 0, TAU, 32, Color(border_color.r, border_color.g, border_color.b, alpha), border_w)

	# Ball carrier ring
	if has_ball:
		draw_arc(center, TOKEN_RADIUS + 2, 0, TAU, 32, Color(1.0, 0.95, 0.6, 0.8), 2.5)
		draw_arc(center, TOKEN_RADIUS + 5, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.35), 1.5)

	# Highlight ring
	if highlighted:
		draw_arc(center, TOKEN_RADIUS + 3, 0, TAU, 32, HIGHLIGHT_COLOR, 2.0)

	# Targeting crosshair (fireball mode)
	if targetable:
		draw_arc(center, TOKEN_RADIUS + 4, 0, TAU, 32, Color(1.0, 0.3, 0.1, 0.8), 2.5)
		draw_arc(center, TOKEN_RADIUS + 7, 0, TAU, 32, Color(1.0, 0.2, 0.0, 0.4), 1.5)

	# Goblin name (shortened)
	var font: Font = ThemeDB.fallback_font
	var name_short: String = goblin_data.goblin_name.split(" ")[0]
	if name_short.length() > 6:
		name_short = name_short.left(5) + "."

	var text_color := Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, alpha)
	var name_size := font.get_string_size(name_short, HORIZONTAL_ALIGNMENT_CENTER, -1, TOKEN_FONT_SIZE)
	draw_string(font, center + Vector2(-name_size.x * 0.5, -2), name_short, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE, text_color)

	# Position abbreviation
	var pos_name: String = PositionDatabase.get_display_name(goblin_data.position)
	var pos_short: String = pos_name.left(3).to_upper()
	var rating_color := Color(UITheme.GOLD_LIGHT.r, UITheme.GOLD_LIGHT.g, UITheme.GOLD_LIGHT.b, alpha)
	var rating_size := font.get_string_size(pos_short, HORIZONTAL_ALIGNMENT_CENTER, -1, TOKEN_FONT_SIZE + 1)
	draw_string(font, center + Vector2(-rating_size.x * 0.5, 11), pos_short, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE + 1, rating_color)
