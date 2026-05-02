extends Control
## Individual goblin token node. Can be tweened, highlighted, and later swapped for sprite art.
## Sprite rendering: drop PNGs in res://assets/goblins/ named "<position>_<NN>.png"
## (e.g. striker_01.png, winger_02.png). Token auto-picks one matching its position.
## If no matching sprite is found, falls back to the colored-circle look.

const TOKEN_RADIUS := 26.0
const SPRITE_DRAW_SIZE := 56.0  # rendered size on the pitch (a bit larger than the circle)
const TOKEN_FONT_SIZE := 12
const SPRITE_DIR := "res://assets/goblins/"
# Magenta auto-key: AI generators ignore "transparent background", so we ask
# for solid magenta and strip it at load time. Tolerant to JPEG-style edge
# bleed - any pixel close to the key color gets alpha=0.
const KEY_COLOR_R := 255
const KEY_COLOR_G := 0
const KEY_COLOR_B := 255
const KEY_TOLERANCE := 80  # 0-255: higher = more aggressive removal

const PLAYER_BG := Color(0.18, 0.35, 0.22)
const PLAYER_BORDER := Color(0.788, 0.659, 0.298)
const OPPONENT_BG := Color(0.35, 0.15, 0.15)
const OPPONENT_BORDER := Color(0.7, 0.25, 0.2)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2, 0.6)

# Animation tuning
const IDLE_BOB_AMPLITUDE: float = 1.5   # pixels of vertical bob when standing still
const IDLE_BOB_FREQ: float = 2.4        # Hz
const RUN_SQUASH_GAIN: float = 8.0      # how strongly velocity warps the sprite
const RUN_SQUASH_MAX: float = 0.18      # cap (so fast goblins don't go full pancake)
const RUN_TILT_GAIN: float = 0.8        # rad of forward lean per unit velocity
const RUN_TILT_MAX: float = 0.25        # cap on tilt (~14 deg)
const VELOCITY_SMOOTH: float = 0.25     # lerp factor on smoothed velocity
const STILL_SPEED_THRESHOLD: float = 8.0  # px/sec below which we count as "idle"

# Cached sprite list per position: position_name -> Array[Texture2D]
static var _sprite_cache: Dictionary = {}
static var _sprite_dir_scanned: bool = false

var goblin_data: GoblinData
var zone: String = ""
var is_player: bool = true
var base_position: Vector2 = Vector2.ZERO  # Home position (set by pitch)
var highlighted: bool = false
var has_ball: bool = false  # Ball carrier glow
var targetable: bool = false  # Fireball targeting mode
var ability_charge: float = 0.0  # 0-1, signature move fills up

var _sprite: Texture2D = null
var _facing: float = 1.0  # 1.0 = right, -1.0 = left (set from is_player at setup)
var _last_pos: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO  # smoothed px/sec
var _bob_phase: float = 0.0
var _highlight_tween: Tween
var _ball_glow_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(TOKEN_RADIUS * 2, TOKEN_RADIUS * 2)
	size = custom_minimum_size
	pivot_offset = Vector2(TOKEN_RADIUS, TOKEN_RADIUS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bob_phase = randf() * TAU  # desync goblin bobs so the team doesn't pulse in unison
	_last_pos = position
	set_process(true)

var _sprite_is_team_colored: bool = false  # true if we picked a team-specific variant

func setup(p_goblin: GoblinData, p_zone: String, p_is_player: bool) -> void:
	goblin_data = p_goblin
	zone = p_zone
	is_player = p_is_player
	_facing = 1.0 if p_is_player else -1.0
	var picked: Dictionary = _pick_sprite_for(p_goblin.position, p_is_player)
	_sprite = picked["sprite"] as Texture2D
	_sprite_is_team_colored = bool(picked.get("team_colored", false))
	queue_redraw()

# ── Sprite loading ──────────────────────────────────────────────────────────
# Scans res://assets/goblins/ once and caches textures keyed by position prefix.
# Naming: "<position>_<NN>.png" (e.g. striker_01.png). "_generic_<NN>.png" is a
# fallback used by any position that has no match.

static func _scan_sprite_dir() -> void:
	if _sprite_dir_scanned:
		return
	_sprite_dir_scanned = true
	var dir := DirAccess.open(SPRITE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.to_lower().ends_with(".png"):
			var stem: String = fname.get_basename()
			var prefix: String = stem
			var us: int = stem.rfind("_")
			if us > 0 and stem.substr(us + 1).is_valid_int():
				prefix = stem.substr(0, us)
			var tex: Texture2D = _load_keyed_texture(SPRITE_DIR + fname)
			if tex != null:
				if not _sprite_cache.has(prefix):
					_sprite_cache[prefix] = []
				(_sprite_cache[prefix] as Array).append(tex)
		fname = dir.get_next()
	dir.list_dir_end()

static func _load_keyed_texture(path: String) -> Texture2D:
	## Load a PNG and key out near-magenta pixels to alpha=0.
	## If the image already has transparency (no magenta detected), it's
	## passed through unchanged so pre-keyed art still works.
	var img := Image.load_from_file(path)
	if img == null:
		# Fallback to plain load - useful if the file is imported via Godot's pipeline.
		return load(path) as Texture2D
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = img.get_data()
	var n: int = data.size()
	var stripped: int = 0
	var i: int = 0
	while i < n:
		var r: int = data[i]
		var g: int = data[i + 1]
		var b: int = data[i + 2]
		if absi(r - KEY_COLOR_R) <= KEY_TOLERANCE \
				and absi(g - KEY_COLOR_G) <= KEY_TOLERANCE \
				and absi(b - KEY_COLOR_B) <= KEY_TOLERANCE:
			data[i + 3] = 0
			stripped += 1
		i += 4
	if stripped > 0:
		img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(img)

static func _pick_sprite_for(position_key: String, is_player: bool) -> Dictionary:
	## Returns {"sprite": Texture2D, "team_colored": bool}.
	## Lookup priority: position+team, generic+team, position-only, generic.
	## Drop a "<position>_blue_01.png" or "_generic_red_02.png" into the sprite dir
	## to add team-specific art - the picker will prefer it for that team.
	_scan_sprite_dir()
	var team_suffix: String = "_blue" if is_player else "_red"

	# Tier 1: position + team
	var pool: Array = _sprite_cache.get(position_key + team_suffix, []) as Array
	if not pool.is_empty():
		return {"sprite": pool[randi() % pool.size()] as Texture2D, "team_colored": true}

	# Tier 2: generic + team
	pool = _sprite_cache.get("_generic" + team_suffix, []) as Array
	if not pool.is_empty():
		return {"sprite": pool[randi() % pool.size()] as Texture2D, "team_colored": true}

	# Tier 3: position-only (no team variant)
	pool = _sprite_cache.get(position_key, []) as Array
	if not pool.is_empty():
		return {"sprite": pool[randi() % pool.size()] as Texture2D, "team_colored": false}

	# Tier 4: untyped generic fallback
	pool = _sprite_cache.get("_generic", []) as Array
	if not pool.is_empty():
		return {"sprite": pool[randi() % pool.size()] as Texture2D, "team_colored": false}

	return {"sprite": null, "team_colored": false}

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

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	# Velocity from the parent-driven position (animated_pitch.gd tweens us).
	var inst_vel: Vector2 = (position - _last_pos) / delta
	_last_pos = position
	_velocity = _velocity.lerp(inst_vel, VELOCITY_SMOOTH)
	# Track facing from horizontal movement so sprites flip when changing direction.
	if absf(_velocity.x) > STILL_SPEED_THRESHOLD:
		_facing = signf(_velocity.x)
	_bob_phase += delta * IDLE_BOB_FREQ * TAU
	queue_redraw()  # animation values are read in _draw

func _draw() -> void:
	if goblin_data == null:
		return

	var center := Vector2(TOKEN_RADIUS, TOKEN_RADIUS)
	var bg_color: Color = PLAYER_BG if is_player else OPPONENT_BG
	var border_color: Color = PLAYER_BORDER if is_player else OPPONENT_BORDER
	var alpha: float = 1.0 if is_player else 0.9

	# Compute idle bob + run squash. Used by both the circle fallback and the sprite.
	var speed: float = _velocity.length()
	var moving_factor: float = clampf(speed / 200.0, 0.0, 1.0)
	var bob_y: float = sin(_bob_phase) * IDLE_BOB_AMPLITUDE * (1.0 - moving_factor)
	var squash: float = clampf(speed * RUN_SQUASH_GAIN / 1000.0, 0.0, RUN_SQUASH_MAX)
	var sx: float = 1.0 + squash       # stretch along travel
	var sy: float = 1.0 - squash * 0.6 # squash perpendicular
	var tilt: float = clampf(_velocity.x * RUN_TILT_GAIN / 1000.0, -RUN_TILT_MAX, RUN_TILT_MAX)

	if _sprite != null:
		# Render the sprite with animation transforms applied around the center.
		# If the sprite is team-colored (e.g. a "_blue" or "_red" variant), pass it through
		# unchanged. Otherwise tint the opponent red as a fallback so teams stay visually distinct.
		var draw_size: float = SPRITE_DRAW_SIZE
		var team_tint: Color
		if _sprite_is_team_colored or is_player:
			team_tint = Color(1.0, 1.0, 1.0, alpha)
		else:
			team_tint = Color(1.45, 0.55, 0.45, alpha)
		draw_set_transform(center + Vector2(0, bob_y), tilt, Vector2(sx * _facing, sy))
		var rect := Rect2(-draw_size * 0.5, -draw_size * 0.5, draw_size, draw_size)
		draw_texture_rect(_sprite, rect, false, team_tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Circle fallback (no sprite for this position yet).
		draw_circle(center + Vector2(0, bob_y), TOKEN_RADIUS, Color(bg_color.r, bg_color.g, bg_color.b, alpha))
		var border_w: float = 2.0
		draw_arc(center + Vector2(0, bob_y), TOKEN_RADIUS, 0, TAU, 32, Color(border_color.r, border_color.g, border_color.b, alpha), border_w)

	# Ability charge ring (drawn on the border, fills clockwise)
	if ability_charge > 0.01:
		var charge_radius: float = TOKEN_RADIUS + 1.5
		var charge_angle: float = TAU * ability_charge
		var charge_start: float = -PI / 2.0  # start at top
		var charge_color: Color
		if ability_charge >= 0.9:
			# Almost ready - pulsing bright
			var pulse: float = 0.7 + sin(Time.get_ticks_msec() * 0.012) * 0.3
			charge_color = Color(1.0, 0.95, 0.3, pulse)
		elif ability_charge >= 0.5:
			charge_color = Color(0.9, 0.75, 0.2, 0.9)
		else:
			charge_color = Color(0.5, 0.7, 0.9, 0.8)
		draw_arc(center, charge_radius, charge_start, charge_start + charge_angle, 32, charge_color, 3.5)

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
