extends VBoxContainer
## Compact notification toast system. Labels fade in, then fade to dim but persist.
## Scroll up in the parent ScrollContainer to see history.

const FADE_IN_TIME := 0.2
const VISIBLE_DURATION := 2.5
const FADE_DIM_TIME := 0.8
const DIM_ALPHA := 0.3
const MAX_TOASTS := 30

func show_toast(text: String, color: Color = UITheme.CREAM, duration: float = VISIBLE_DURATION) -> void:
	# Limit total toasts to avoid unbounded growth
	while get_child_count() >= MAX_TOASTS:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.0
	add_child(label)

	# Fade in, stay visible, then fade to dim (but don't remove)
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", DIM_ALPHA, FADE_DIM_TIME)

	# Auto-scroll to bottom after adding
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	var scroll := get_parent()
	if scroll is ScrollContainer:
		# Defer so layout updates first
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
