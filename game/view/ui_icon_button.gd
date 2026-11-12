class_name UiIconButton
extends Button
## A small square button that shows a drawn sign rather than a word (the
## map's time and view controls): "pause", "play", "fast", "stop", "plus",
## "minus", "follow", "book". The sign takes the button's font colour for
## its state, and is drawn only when the button is (on a state change).
## The word is the tooltip.

var glyph := "":
	set(v):
		glyph = v
		queue_redraw()


func _init(p_glyph := "", tip := "") -> void:
	glyph = p_glyph
	tooltip_text = tip
	theme_type_variation = "ToolButton"
	custom_minimum_size = Vector2(UiTheme.ROW, UiTheme.ROW)
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var col := get_theme_color("font_color")
	if disabled:
		col = get_theme_color("font_disabled_color")
	elif button_pressed:
		col = get_theme_color("font_pressed_color")
	elif is_hovered():
		col = get_theme_color("font_hover_color")
	var c := (size / 2.0).floor() + (Vector2(0, 1) if button_pressed else Vector2.ZERO)
	var u := minf(size.x, size.y) * 0.16  # the sign's unit
	match glyph:
		"pause":
			draw_rect(Rect2(c + Vector2(-u * 1.1, -u * 1.3), Vector2(u * 0.75, u * 2.6)), col)
			draw_rect(Rect2(c + Vector2(u * 0.35, -u * 1.3), Vector2(u * 0.75, u * 2.6)), col)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.9, -u * 1.4), c + Vector2(u * 1.4, 0), c + Vector2(-u * 0.9, u * 1.4)]), col)
		"fast":
			for dx in [-u * 1.3, u * 0.1]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(dx, -u * 1.1), c + Vector2(dx + u * 1.3, 0), c + Vector2(dx, u * 1.1)]), col)
		"stop":
			draw_rect(Rect2(c - Vector2(u, u) * 1.05, Vector2(u, u) * 2.1), col)
		"plus":
			draw_rect(Rect2(c + Vector2(-u * 1.3, -u * 0.22), Vector2(u * 2.6, u * 0.44)), col)
			draw_rect(Rect2(c + Vector2(-u * 0.22, -u * 1.3), Vector2(u * 0.44, u * 2.6)), col)
		"minus":
			draw_rect(Rect2(c + Vector2(-u * 1.3, -u * 0.22), Vector2(u * 2.6, u * 0.44)), col)
		"follow":
			draw_arc(c, u * 1.1, 0, TAU, 24, col, u * 0.35, true)
			draw_circle(c, u * 0.38, col)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * u * 1.35, c + d * u * 1.9, col, u * 0.35)
		"book":
			var w := u * 1.2
			draw_rect(Rect2(c + Vector2(-w * 1.15, -u * 1.1), Vector2(w, u * 2.2)), col, false, u * 0.3)
			draw_rect(Rect2(c + Vector2(w * 0.15, -u * 1.1), Vector2(w, u * 2.2)), col, false, u * 0.3)
			for i in 3:
				var y := -u * 0.5 + i * u * 0.5
				draw_line(c + Vector2(-w * 0.9, y), c + Vector2(-w * 0.3, y), col, 1.0)
				draw_line(c + Vector2(w * 0.4, y), c + Vector2(w * 1.0, y), col, 1.0)
