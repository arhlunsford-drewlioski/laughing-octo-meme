class_name GoblinPortrait
extends Control
## Procedural goblin portrait. Deterministic from goblin name hash.
## Composes: round skin panel + hair tuft + eyes + mouth + role-tinted ring.
## Variations come from hashing the goblin's name so the same goblin always
## looks the same. Stylized chibi shapes — no face art needed.

const ROLE_RING_COLOR := {
	"keeper":     Color(0.40, 0.65, 0.85),  # cool blue
	"defender":   Color(0.45, 0.55, 0.75),  # steel
	"midfielder": Color(0.85, 0.70, 0.30),  # gold-yellow
	"attacker":   Color(0.85, 0.32, 0.28),  # vermillion
	"chaos":      Color(0.55, 0.30, 0.75),  # purple
}

const SKIN_PALETTE := [
	Color(0.40, 0.55, 0.30),  # mossy green
	Color(0.45, 0.50, 0.25),  # olive
	Color(0.55, 0.60, 0.35),  # pale lime
	Color(0.35, 0.45, 0.30),  # dark forest
	Color(0.50, 0.45, 0.30),  # mottled
]

const HAIR_PALETTE := [
	Color(0.20, 0.12, 0.06),  # near-black
	Color(0.55, 0.25, 0.10),  # rust
	Color(0.85, 0.65, 0.20),  # blond-gold
	Color(0.15, 0.08, 0.04),  # very dark
	Color(0.65, 0.20, 0.20),  # red-mane
	Color(0.30, 0.30, 0.40),  # silver-grey
]

const MOUTH_STYLES := ["smile", "scowl", "smirk", "neutral", "open"]

@export var portrait_size: float = 96.0
@export var show_ring: bool = true

var _goblin = null
var _injured: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func _ready() -> void:
	custom_minimum_size = Vector2(portrait_size, portrait_size)
	if _goblin:
		_rebuild()


func set_goblin(g) -> void:
	_goblin = g
	if is_inside_tree():
		_rebuild()


func set_size_px(px: float) -> void:
	portrait_size = px
	custom_minimum_size = Vector2(px, px)
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _goblin == null:
		return

	var seed_v: int = abs(_goblin.goblin_name.hash())
	var skin: Color = SKIN_PALETTE[seed_v % SKIN_PALETTE.size()]
	var hair: Color = HAIR_PALETTE[(seed_v / 3) % HAIR_PALETTE.size()]
	var mouth_style: String = MOUTH_STYLES[(seed_v / 7) % MOUTH_STYLES.size()]
	var ring: Color = ROLE_RING_COLOR.get(_goblin.position, UITheme.GOLD)

	# Status overrides
	_injured = int(_goblin.injury) >= int(GoblinData.InjuryState.MINOR)
	if not _goblin.is_alive():
		skin = Color(0.30, 0.30, 0.32)
		hair = Color(0.20, 0.20, 0.22)

	var size_v: Vector2 = Vector2(portrait_size, portrait_size)
	custom_minimum_size = size_v

	# ── Outer ring (heraldic role color + gold inner) ─────────────────
	if show_ring:
		var ring_panel := PanelContainer.new()
		ring_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rs := StyleBoxFlat.new()
		rs.bg_color = ring
		rs.set_corner_radius_all(int(portrait_size))
		rs.border_color = UITheme.GOLD_DEEP
		rs.border_width_left = 2
		rs.border_width_right = 2
		rs.border_width_top = 2
		rs.border_width_bottom = 2
		rs.shadow_color = Color(0, 0, 0, 0.45)
		rs.shadow_size = 0
		rs.shadow_offset = Vector2(0, 3)
		rs.anti_aliasing = true
		ring_panel.add_theme_stylebox_override("panel", rs)
		add_child(ring_panel)

	# ── Skin disc (inset from ring) ──────────────────────────────────
	var inset: float = portrait_size * 0.10
	var skin_panel := PanelContainer.new()
	skin_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	skin_panel.offset_left = inset
	skin_panel.offset_right = -inset
	skin_panel.offset_top = inset
	skin_panel.offset_bottom = -inset
	skin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := StyleBoxFlat.new()
	ss.bg_color = skin
	ss.set_corner_radius_all(int(portrait_size))
	ss.anti_aliasing = true
	skin_panel.add_theme_stylebox_override("panel", ss)
	add_child(skin_panel)

	# ── Hair tuft (top arc of head) ──────────────────────────────────
	var hair_arc := PanelContainer.new()
	hair_arc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hair_arc.offset_left = inset + 2
	hair_arc.offset_right = -(inset + 2)
	hair_arc.offset_top = inset + 2
	hair_arc.offset_bottom = -(portrait_size * 0.62)
	hair_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := StyleBoxFlat.new()
	hs.bg_color = hair
	# Top corners more rounded than bottom = arc/cap shape
	hs.corner_radius_top_left = int(portrait_size)
	hs.corner_radius_top_right = int(portrait_size)
	hs.corner_radius_bottom_left = 4
	hs.corner_radius_bottom_right = 4
	hs.anti_aliasing = true
	hair_arc.add_theme_stylebox_override("panel", hs)
	add_child(hair_arc)

	# ── Eyes ─────────────────────────────────────────────────────────
	var eye_y: float = portrait_size * 0.45
	var eye_size: float = portrait_size * 0.10
	var eye_gap: float = portrait_size * 0.18
	var eye_color: Color = Color(0.05, 0.05, 0.05)
	var angry: bool = (seed_v / 11) % 3 == 0  # ~33% chance angry slits

	for side in [-1, 1]:
		var eye := ColorRect.new()
		eye.color = eye_color
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eye.set_anchors_preset(Control.PRESET_TOP_LEFT)
		eye.anchor_left = 0.5
		eye.anchor_right = 0.5
		eye.anchor_top = 0.0
		eye.anchor_bottom = 0.0
		eye.offset_left = side * eye_gap - eye_size * 0.5
		eye.offset_right = side * eye_gap + eye_size * 0.5
		eye.offset_top = eye_y - (eye_size * 0.3 if angry else eye_size * 0.5)
		eye.offset_bottom = eye_y + (eye_size * 0.3 if angry else eye_size * 0.5)
		add_child(eye)

	# ── Mouth ────────────────────────────────────────────────────────
	var mouth := ColorRect.new()
	mouth.color = Color(0.20, 0.10, 0.10)
	mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouth.anchor_left = 0.5
	mouth.anchor_right = 0.5
	mouth.anchor_top = 0.0
	mouth.anchor_bottom = 0.0
	var mouth_w: float = portrait_size * 0.18
	var mouth_h: float = portrait_size * 0.04
	var mouth_y: float = portrait_size * 0.66
	mouth.offset_left = -mouth_w * 0.5
	mouth.offset_right = mouth_w * 0.5
	mouth.offset_top = mouth_y
	mouth.offset_bottom = mouth_y + mouth_h
	if mouth_style == "open":
		mouth.color = Color(0.25, 0.05, 0.05)
		mouth.offset_top = mouth_y - mouth_h * 0.5
		mouth.offset_bottom = mouth_y + mouth_h * 1.5
	add_child(mouth)

	# Add a tiny tooth for "smirk" / "smile" mouths
	if mouth_style == "smile" or mouth_style == "smirk":
		var tooth := ColorRect.new()
		tooth.color = UITheme.PARCHMENT
		tooth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooth.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tooth.anchor_left = 0.5
		tooth.anchor_right = 0.5
		tooth.anchor_top = 0.0
		tooth.anchor_bottom = 0.0
		var tw: float = portrait_size * 0.04
		var th: float = portrait_size * 0.06
		var t_offset: float = portrait_size * 0.04 if mouth_style == "smirk" else 0
		tooth.offset_left = t_offset - tw * 0.5
		tooth.offset_right = t_offset + tw * 0.5
		tooth.offset_top = mouth_y - th * 0.4
		tooth.offset_bottom = mouth_y + th * 0.6
		add_child(tooth)

	# ── Status overlays ───────────────────────────────────────────────
	if not _goblin.is_alive():
		_add_status_stamp("DEAD", UITheme.CRIMSON)
	elif int(_goblin.injury) == int(GoblinData.InjuryState.MAJOR):
		_add_status_stamp("INJ", UITheme.WINE)


func _add_status_stamp(text: String, color: Color) -> void:
	var stamp := Label.new()
	stamp.text = text
	stamp.set_anchors_preset(Control.PRESET_CENTER)
	stamp.add_theme_color_override("font_color", color)
	stamp.add_theme_color_override("font_outline_color", UITheme.INK)
	stamp.add_theme_constant_override("outline_size", 4)
	stamp.add_theme_font_size_override("font_size", int(portrait_size * 0.32))
	stamp.rotation = -0.18  # slight tilt = "rubber stamp"
	stamp.modulate.a = 0.85
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp)


## Draw an empty slot (for unfilled lineup positions). No goblin needed.
func draw_empty_slot(slot_number: int) -> void:
	for child in get_children():
		child.queue_free()
	_goblin = null

	var size_v: Vector2 = Vector2(portrait_size, portrait_size)
	custom_minimum_size = size_v

	var ring_panel := PanelContainer.new()
	ring_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = UITheme.BG_PANEL
	rs.set_corner_radius_all(int(portrait_size))
	rs.border_color = UITheme.GOLD_DEEP
	rs.border_width_left = 2
	rs.border_width_right = 2
	rs.border_width_top = 2
	rs.border_width_bottom = 2
	rs.anti_aliasing = true
	ring_panel.add_theme_stylebox_override("panel", rs)
	add_child(ring_panel)

	var num := Label.new()
	num.text = str(slot_number)
	num.set_anchors_preset(Control.PRESET_CENTER)
	num.theme_type_variation = &"WaxSealBadge"
	num.add_theme_color_override("font_color", UITheme.GOLD_DEEP)
	num.add_theme_constant_override("outline_size", 0)
	num.add_theme_font_size_override("font_size", int(portrait_size * 0.42))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(num)
