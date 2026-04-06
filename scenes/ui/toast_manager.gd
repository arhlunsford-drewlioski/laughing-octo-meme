extends VBoxContainer
## Compact notification toast system. Labels fade in at center and fade out after duration.

const DEFAULT_DURATION := 2.0
const FADE_IN_TIME := 0.2
const FADE_OUT_TIME := 0.5
const MAX_TOASTS := 6

func show_toast(text: String, color: Color = UITheme.CREAM, duration: float = DEFAULT_DURATION) -> void:
	# Limit visible toasts - remove oldest immediately
	while get_child_count() >= MAX_TOASTS:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.0
	add_child(label)

	# Bind tween to the label so it auto-dies if the label is freed
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_remove_toast.bind(label))

func _remove_toast(label: Label) -> void:
	if is_instance_valid(label) and label.get_parent() == self:
		remove_child(label)
		label.queue_free()

func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
