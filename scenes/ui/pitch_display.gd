extends Control
## Sideways soccer pitch with both teams as circular goblin tokens.
## Your team on the left attacking right, opponent on the right.

signal formation_changed()

const TOKEN_RADIUS := 24.0
const TOKEN_FONT_SIZE := 11
const SELECTED_BORDER := Color(1.0, 0.85, 0.2, 1.0)

# Horizontal position ratios for each zone (left = 0, right = 1)
# Clear gap at center line (50%) - no overlap between teams
const PLAYER_X := { "goal": 0.06, "defense": 0.20, "midfield": 0.32, "attack": 0.43 }
const OPPONENT_X := { "attack": 0.57, "midfield": 0.68, "defense": 0.80, "goal": 0.94 }

# Pitch colors
const PITCH_GREEN := Color(0.15, 0.32, 0.12)
const PITCH_GREEN_LIGHT := Color(0.17, 0.35, 0.14)
const PITCH_LINE := Color(1, 1, 1, 0.25)
const PITCH_LINE_BOLD := Color(1, 1, 1, 0.35)

# Token colors
const PLAYER_TOKEN_BG := Color(0.18, 0.35, 0.22)
const PLAYER_TOKEN_BORDER := Color(0.788, 0.659, 0.298)  # UITheme.GOLD
const OPPONENT_TOKEN_BG := Color(0.35, 0.15, 0.15)
const OPPONENT_TOKEN_BORDER := Color(0.7, 0.25, 0.2)

var player_formation: Formation
var opponent_formation: Formation
var interactive: bool = false

# Drag state
var _dragging: bool = false
var _drag_goblin: GoblinData = null
var _drag_from_zone: String = ""
var _drag_pos: Vector2 = Vector2.ZERO

# Buff overlays: zone_name -> buff value (shown as +N badge on goblins in that zone)
var player_zone_buffs: Dictionary = {}   # { "attack": 3, "defense": 2, ... }
var opponent_zone_buffs: Dictionary = {} # same

# Cached token rects for click detection
var _player_tokens: Array[Dictionary] = []  # { "goblin": GoblinData, "pos": Vector2, "zone": String }
var _zone_areas: Dictionary = {}  # zone_name -> Rect2 for drop targets

func set_zone_buffs(player_buffs: Dictionary, opponent_buffs: Dictionary) -> void:
	## Set buff overlays. Dict format: { "attack": 3, "midfield": 0, "defense": 2, "goal": 0 }
	player_zone_buffs = player_buffs
	opponent_zone_buffs = opponent_buffs
	queue_redraw()

func clear_buffs() -> void:
	player_zone_buffs.clear()
	opponent_zone_buffs.clear()
	queue_redraw()

func setup(p_formation: Formation, o_formation: Formation, p_interactive: bool) -> void:
	player_formation = p_formation
	opponent_formation = o_formation
	interactive = p_interactive
	_dragging = false
	_drag_goblin = null
	player_zone_buffs.clear()
	opponent_zone_buffs.clear()
	# Defer cache until layout is ready (size may be zero during _ready)
	if size == Vector2.ZERO:
		await get_tree().process_frame
	_cache_positions()
	queue_redraw()

func set_interactive(value: bool) -> void:
	interactive = value
	_dragging = false
	_drag_goblin = null
	_cache_positions()
	queue_redraw()

func _cache_positions() -> void:
	_player_tokens.clear()
	_zone_areas.clear()
	if player_formation == null:
		return

	for zone in ["goal", "defense", "midfield", "attack"]:
		var goblins: Array[GoblinData] = player_formation.get_zone(zone)
		var positions := _get_token_positions(zone, goblins.size(), true)
		for i in goblins.size():
			_player_tokens.append({ "goblin": goblins[i], "pos": positions[i], "zone": zone })

		# Build zone click area (vertical strip) - each zone owns its column up to halfway to neighbors
		var x_ratio: float = PLAYER_X[zone]
		var cx: float = size.x * x_ratio
		# Use half the pitch (player side only = 0 to 50%)
		var half_w: float = size.x * 0.50
		var strip_w: float = half_w / 4.0
		var strip_x: float = cx - strip_w * 0.5
		_zone_areas[zone] = Rect2(strip_x, 0, strip_w, size.y)

func _get_token_positions(zone: String, count: int, is_player: bool) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var x_map: Dictionary = PLAYER_X if is_player else OPPONENT_X
	var px: float = size.x * x_map[zone]

	if count == 0:
		return positions
	elif count == 1:
		positions.append(Vector2(px, size.y * 0.5))
	else:
		var spacing := size.y * 0.6 / float(count)
		var start_y := size.y * 0.5 - spacing * (count - 1) * 0.5
		for i in count:
			positions.append(Vector2(px, start_y + spacing * i))

	return positions

func _draw() -> void:
	_draw_pitch()
	_draw_tokens()

func _draw_pitch() -> void:
	var w: float = size.x
	var h: float = size.y

	# Alternating grass stripes
	var stripe_count: int = 12
	var stripe_w: float = w / stripe_count
	for i in stripe_count:
		var color: Color = PITCH_GREEN if i % 2 == 0 else PITCH_GREEN_LIGHT
		draw_rect(Rect2(stripe_w * i, 0, stripe_w, h), color)

	# Outer boundary
	draw_rect(Rect2(0, 0, w, h), PITCH_LINE_BOLD, false, 2.0)

	# Center line
	draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h), PITCH_LINE_BOLD, 1.5)

	# Center circle
	draw_arc(Vector2(w * 0.5, h * 0.5), h * 0.15, 0, TAU, 48, PITCH_LINE, 1.5)

	# Center dot
	draw_circle(Vector2(w * 0.5, h * 0.5), 3, PITCH_LINE_BOLD)

	# Left penalty area
	var pen_w := w * 0.12
	var pen_h := h * 0.55
	var pen_y := (h - pen_h) * 0.5
	draw_rect(Rect2(0, pen_y, pen_w, pen_h), PITCH_LINE, false, 1.5)

	# Left goal box
	var goal_w := w * 0.05
	var goal_h := h * 0.3
	var goal_y := (h - goal_h) * 0.5
	draw_rect(Rect2(0, goal_y, goal_w, goal_h), PITCH_LINE, false, 1.5)

	# Right penalty area
	draw_rect(Rect2(w - pen_w, pen_y, pen_w, pen_h), PITCH_LINE, false, 1.5)

	# Right goal box
	draw_rect(Rect2(w - goal_w, goal_y, goal_w, goal_h), PITCH_LINE, false, 1.5)

	# Penalty spots
	draw_circle(Vector2(pen_w * 0.75, h * 0.5), 2, PITCH_LINE)
	draw_circle(Vector2(w - pen_w * 0.75, h * 0.5), 2, PITCH_LINE)

func _draw_tokens() -> void:
	if player_formation == null:
		return

	# When dragging, highlight valid drop zones
	if _dragging and interactive:
		for zone_name in _zone_areas:
			var area: Rect2 = _zone_areas[zone_name]
			draw_rect(area, Color(1, 1, 1, 0.08))

	# Draw player tokens
	for token in _player_tokens:
		var pos: Vector2 = token["pos"]
		var goblin: GoblinData = token["goblin"]
		var zone: String = token["zone"]
		# If dragging this goblin, draw a ghost at original pos and the real one at cursor
		if _dragging and _drag_goblin == goblin:
			_draw_goblin_token(pos, goblin, zone, true, false, 0.3)
			_draw_goblin_token(_drag_pos, goblin, zone, true, true)
		else:
			_draw_goblin_token(pos, goblin, zone, true, false)

	# Draw opponent tokens
	if opponent_formation:
		for zone in ["goal", "defense", "midfield", "attack"]:
			var goblins: Array[GoblinData] = opponent_formation.get_zone(zone)
			var positions := _get_token_positions(zone, goblins.size(), false)
			for i in goblins.size():
				_draw_goblin_token(positions[i], goblins[i], zone, false, false)

func _draw_goblin_token(pos: Vector2, goblin: GoblinData, zone: String, is_player: bool, is_selected: bool, alpha_override: float = -1.0) -> void:
	var bg_color: Color = PLAYER_TOKEN_BG if is_player else OPPONENT_TOKEN_BG
	var border_color: Color = PLAYER_TOKEN_BORDER if is_player else OPPONENT_TOKEN_BORDER
	if is_selected:
		border_color = SELECTED_BORDER
	var border_w: float = 3.0 if is_selected else 2.0
	var alpha: float = 1.0 if is_player else 0.7
	if alpha_override >= 0.0:
		alpha = alpha_override

	# Token circle background
	draw_circle(pos, TOKEN_RADIUS, Color(bg_color.r, bg_color.g, bg_color.b, alpha))

	# Token circle border
	draw_arc(pos, TOKEN_RADIUS, 0, TAU, 32, Color(border_color.r, border_color.g, border_color.b, alpha), border_w)

	# Goblin name (shortened) + rating
	var font: Font = ThemeDB.fallback_font
	var rating: int = goblin.get_rating_for_zone(zone)
	var name_short: String = goblin.goblin_name.split(" ")[0]
	if name_short.length() > 6:
		name_short = name_short.left(5) + "."

	var text_color: Color = Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, alpha)
	var rating_color: Color = Color(UITheme.GOLD_LIGHT.r, UITheme.GOLD_LIGHT.g, UITheme.GOLD_LIGHT.b, alpha)

	# Name above center
	var name_size := font.get_string_size(name_short, HORIZONTAL_ALIGNMENT_CENTER, -1, TOKEN_FONT_SIZE)
	draw_string(font, pos + Vector2(-name_size.x * 0.5, -2), name_short, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE, text_color)

	# Rating below center - show base + buff
	var buff_map: Dictionary = player_zone_buffs if is_player else opponent_zone_buffs
	var buff_val: int = buff_map.get(zone, 0)

	if buff_val > 0:
		# Show "base+buff" in green to indicate buffed
		var rating_str := str(rating) + "+" + str(buff_val)
		var buffed_color: Color = Color(0.3, 1.0, 0.3, alpha)
		var rating_size := font.get_string_size(rating_str, HORIZONTAL_ALIGNMENT_CENTER, -1, TOKEN_FONT_SIZE + 2)
		draw_string(font, pos + Vector2(-rating_size.x * 0.5, 12), rating_str, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE + 2, buffed_color)

		# Draw a green glow ring to show buffed state
		draw_arc(pos, TOKEN_RADIUS + 3, 0, TAU, 32, Color(0.3, 1.0, 0.3, 0.4 * alpha), 2.0)
	elif buff_val < 0:
		# Show debuffed in red
		var rating_str := str(rating) + str(buff_val)
		var debuff_color: Color = Color(1.0, 0.3, 0.3, alpha)
		var rating_size := font.get_string_size(rating_str, HORIZONTAL_ALIGNMENT_CENTER, -1, TOKEN_FONT_SIZE + 2)
		draw_string(font, pos + Vector2(-rating_size.x * 0.5, 12), rating_str, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE + 2, debuff_color)

		draw_arc(pos, TOKEN_RADIUS + 3, 0, TAU, 32, Color(1.0, 0.3, 0.3, 0.4 * alpha), 2.0)
	else:
		var rating_str := str(rating)
		var rating_size := font.get_string_size(rating_str, HORIZONTAL_ALIGNMENT_CENTER, -1, TOKEN_FONT_SIZE + 2)
		draw_string(font, pos + Vector2(-rating_size.x * 0.5, 12), rating_str, HORIZONTAL_ALIGNMENT_LEFT, -1, TOKEN_FONT_SIZE + 2, rating_color)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start drag if clicking on a player goblin
			var click_pos: Vector2 = event.position
			for token in _player_tokens:
				var pos: Vector2 = token["pos"]
				if click_pos.distance_to(pos) <= TOKEN_RADIUS + 6:
					_dragging = true
					_drag_goblin = token["goblin"]
					_drag_from_zone = token["zone"]
					_drag_pos = click_pos
					queue_redraw()
					return
		else:
			# Release - drop goblin into zone
			if _dragging and _drag_goblin != null:
				var drop_pos: Vector2 = event.position
				for zone_name in _zone_areas:
					var area: Rect2 = _zone_areas[zone_name]
					if area.has_point(drop_pos) and zone_name != _drag_from_zone:
						var moved := player_formation.move_goblin(_drag_goblin, zone_name)
						if moved:
							_cache_positions()
							formation_changed.emit()
						break
				_dragging = false
				_drag_goblin = null
				queue_redraw()

	if event is InputEventMouseMotion and _dragging:
		_drag_pos = event.position
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_cache_positions()
		queue_redraw()
