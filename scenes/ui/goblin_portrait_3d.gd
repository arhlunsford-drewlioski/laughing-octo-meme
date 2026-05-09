class_name GoblinPortrait3D
extends Control
## 3D goblin portrait — Kenney Mini Dungeon orc rendered via SubViewport.
## Per-goblin variation: deterministic hue-shift + slight pose rotation
## from the goblin's name hash, so the same goblin always looks the same.
##
## Same API as GoblinPortrait (set_goblin, set_size_px, draw_empty_slot)
## so it's drop-in compatible.

const ORC_GLB := preload("res://assets/3d/kenney_mini_dungeon/character-orc.glb")
const ORIGINAL_COLORMAP := preload("res://assets/3d/kenney_mini_dungeon/Textures/colormap.png")

# Cached recolored colormap. Kenney's orc has cyan/teal skin which doesn't
# read as a goblin. We swap the cyan band of the palette atlas to green at
# runtime so the orc's skin renders green while the clothes stay original.
static var _green_colormap_cache: ImageTexture = null


static func _green_colormap() -> ImageTexture:
	if _green_colormap_cache != null:
		return _green_colormap_cache
	var src: Image = ORIGINAL_COLORMAP.get_image().duplicate()
	var w := src.get_width()
	var h := src.get_height()
	for x in range(w):
		for y in range(h):
			var c: Color = src.get_pixel(x, y)
			# Cyan/teal/light-blue range: blue dominates, red is well below.
			# This catches the orc's skin band (top-left of the palette) and
			# also a couple lavender lines next to it. Acceptable since
			# nothing else on the orc samples those.
			var is_cyan_skin: bool = c.b > 0.55 and c.b > c.r + 0.15 \
				and c.b >= c.g - 0.02 and c.a > 0.0
			if is_cyan_skin:
				# Map to goblin green: keep brightness, swap to green-dominant
				var brightness: float = max(c.r, max(c.g, c.b))
				var goblin := Color(
					brightness * 0.30,   # red — low (warty greens)
					brightness * 0.82,   # green — dominant
					brightness * 0.32,   # blue — low
					c.a
				)
				src.set_pixel(x, y, goblin)
	_green_colormap_cache = ImageTexture.create_from_image(src)
	return _green_colormap_cache

@export var portrait_size: float = 96.0

var _goblin = null
var _viewport: SubViewport = null
var _model_root: Node3D = null
var _camera: Camera3D = null
var _texture_rect: TextureRect = null
var _ring_panel: PanelContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	custom_minimum_size = Vector2(portrait_size, portrait_size)
	_build_chrome()
	_build_3d_scene()
	if _goblin:
		_apply_goblin_variation()


func set_goblin(g) -> void:
	_goblin = g
	if is_inside_tree():
		_apply_goblin_variation()


func set_size_px(px: float) -> void:
	portrait_size = px
	custom_minimum_size = Vector2(px, px)
	if _viewport:
		_viewport.size = Vector2i(int(px * 2), int(px * 2))  # 2x for crisp downsample


# ── Build ──────────────────────────────────────────────────────────────

func _build_chrome() -> void:
	# Outer ring (heraldic role tint, gold border) — same look as the
	# procedural portrait's ring so cards stay visually consistent.
	_ring_panel = PanelContainer.new()
	_ring_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring_panel)


func _build_3d_scene() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(portrait_size * 2), int(portrait_size * 2))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	# Camera framed on the model's head/upper body. Use look_at so we
	# don't have to compute pitch manually.
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.55, 0.85)
	_camera.fov = 45
	_viewport.add_child(_camera)
	# look_at must run after add_child (camera needs a valid global xform)
	_camera.look_at(Vector3(0, 0.40, 0))

	# Three-point-ish lighting for chibi readability
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40), deg_to_rad(35), 0)
	key.light_energy = 1.2
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-150), 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.85, 0.92, 1.0)
	_viewport.add_child(fill)

	# Model holder — we'll replace contents per goblin so we can swap pose
	_model_root = Node3D.new()
	_viewport.add_child(_model_root)

	# 2D output: TextureRect anchored full-rect, inset slightly so the ring shows
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset: float = portrait_size * 0.04
	_texture_rect.offset_left = inset
	_texture_rect.offset_right = -inset
	_texture_rect.offset_top = inset
	_texture_rect.offset_bottom = -inset
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.texture = _viewport.get_texture()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)


# ── Variation ──────────────────────────────────────────────────────────

func _apply_goblin_variation() -> void:
	if _goblin == null:
		return

	# Reset model
	for child in _model_root.get_children():
		child.queue_free()

	var instance := ORC_GLB.instantiate() as Node3D
	if instance == null:
		push_warning("GoblinPortrait3D: orc GLB did not instantiate as Node3D")
		return
	_model_root.add_child(instance)
	# Don't translate — let the model sit at origin. The camera is aimed
	# at y=0.40 which is roughly head/chest height for the chibi orc.

	# Recolor: cyan skin → goblin green via texture-atlas swap. Walks the
	# instance tree, finds every MeshInstance3D, overrides each surface's
	# material with one whose albedo_texture is our green colormap.
	_apply_skin_recolor(instance, _green_colormap())

	# Deterministic variation from name hash
	var seed_v: int = abs(_goblin.goblin_name.hash())
	var rotation_y: float = deg_to_rad(float(seed_v % 30) - 15.0)  # ±15° turn
	instance.rotation.y = rotation_y

	# Per-goblin hue shift via modulate on the texture rect.
	# Keep saturation/value near 1 so it's a tint, not a wash.
	var hue: float = float(seed_v % 360) / 360.0
	# Bias hue shift toward warm/cool-only (not green→pink) for sanity:
	# blend the deterministic hue toward cool blues / warm reds based on role.
	var role_warm: bool = _goblin.position in ["attacker", "chaos"]
	var tint_target: Color
	if role_warm:
		tint_target = Color.from_hsv(hue * 0.10 + 0.95, 0.18, 1.0)  # warm-side
	else:
		tint_target = Color.from_hsv(hue * 0.10 + 0.55, 0.18, 1.0)  # cool-side
	# Mix with white so tint stays subtle (~20% strength)
	_texture_rect.modulate = Color.WHITE.lerp(tint_target, 0.30)

	# Outer ring color follows role
	var ring_color: Color = GoblinPortrait.ROLE_RING_COLOR.get(_goblin.position, UITheme.GOLD)
	if not _goblin.is_alive():
		ring_color = Color(0.30, 0.30, 0.32)
	_apply_ring(ring_color)

	# Status overlays (injured / dead) — stamped over the rendered orc
	if not _goblin.is_alive():
		_add_status_stamp("DEAD", UITheme.CRIMSON)
	elif int(_goblin.injury) == int(GoblinData.InjuryState.MAJOR):
		_add_status_stamp("INJ", UITheme.WINE)


func _apply_skin_recolor(node: Node, texture: Texture2D) -> void:
	## Recursively walk the model and override every mesh surface's material
	## to use our recolored colormap as albedo_texture. Other PBR properties
	## are preserved by duplicating the original material.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var orig: Material = mesh.surface_get_material(i)
				var new_mat: StandardMaterial3D
				if orig is StandardMaterial3D:
					new_mat = (orig as StandardMaterial3D).duplicate()
				else:
					new_mat = StandardMaterial3D.new()
				new_mat.albedo_texture = texture
				mi.set_surface_override_material(i, new_mat)
	for child in node.get_children():
		_apply_skin_recolor(child, texture)


func _apply_ring(color: Color) -> void:
	var rs := StyleBoxFlat.new()
	rs.bg_color = color
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
	_ring_panel.add_theme_stylebox_override("panel", rs)


func _add_status_stamp(text: String, color: Color) -> void:
	# Remove old stamps
	for child in get_children():
		if child.get_meta("is_status_stamp", false):
			child.queue_free()

	var stamp := Label.new()
	stamp.set_meta("is_status_stamp", true)
	stamp.text = text
	stamp.set_anchors_preset(Control.PRESET_CENTER)
	stamp.add_theme_color_override("font_color", color)
	stamp.add_theme_color_override("font_outline_color", UITheme.INK)
	stamp.add_theme_constant_override("outline_size", 4)
	stamp.add_theme_font_size_override("font_size", int(portrait_size * 0.30))
	stamp.rotation = -0.18
	stamp.modulate.a = 0.85
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp)


## API parity with GoblinPortrait so it's a drop-in: empty slot = numbered
## rune ring, no model.
func draw_empty_slot(slot_number: int) -> void:
	_goblin = null
	if _viewport:
		# Hide the model
		for child in _model_root.get_children():
			child.queue_free()
	if _texture_rect:
		_texture_rect.modulate = Color.WHITE
	for child in get_children():
		if child.get_meta("is_status_stamp", false):
			child.queue_free()

	# Empty ring chrome
	var rs := StyleBoxFlat.new()
	rs.bg_color = UITheme.BG_PANEL
	rs.set_corner_radius_all(int(portrait_size))
	rs.border_color = UITheme.GOLD_DEEP
	rs.border_width_left = 2
	rs.border_width_right = 2
	rs.border_width_top = 2
	rs.border_width_bottom = 2
	rs.anti_aliasing = true
	if _ring_panel:
		_ring_panel.add_theme_stylebox_override("panel", rs)

	# Slot number stamp
	for child in get_children():
		if child.get_meta("is_slot_number", false):
			child.queue_free()
	var num := Label.new()
	num.set_meta("is_slot_number", true)
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
