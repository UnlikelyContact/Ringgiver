class_name WinterScreen
extends Control
## The winter in the hall (docs/design/notes/winter.md): the band's winter
## quarters drawn behind, a header saying which step of the winter this is,
## the step's choices as rows to press, a running tally of silver and food,
## and Back / Go on. All of it is a face on Journey's winter calls
## (`winter_state`, `winter_choose`); after each press the screen reads the
## journey again. Opened over the map by `MapScreen.refresh` while the band
## winters; it closes itself when the spring begins.
##
## Every colour, size and box is set in `_style` alone, so the look can be
## pointed at a shared theme in one place.

## Design pixels a pressable thing is at least tall (about 44 px on a phone).
const TAP := 62.0

var journey: Journey
var map: Node
var _bar_title: Label
var _bar_where: Label
var _bar_tally: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _back: Button
var _next: Button
var _step_label: Label
var _step_seen := -1


## The look of every part of the screen, by role: the one place to change it.
static func _style(c: Control, role: String) -> void:
	var gold := Color("c9a227")
	var text := Color("e8e2d6")
	var dim := Color("a39c90")
	match role:
		"title":
			c.add_theme_font_size_override("font_size", 26)
			c.add_theme_color_override("font_color", gold)
		"where", "dim":
			c.add_theme_font_size_override("font_size", 15)
			c.add_theme_color_override("font_color", dim)
		"tally":
			c.add_theme_font_size_override("font_size", 17)
			c.add_theme_color_override("font_color", text)
		"body":
			c.add_theme_font_size_override("font_size", 17)
			c.add_theme_color_override("font_color", text)
		"note":
			c.add_theme_font_size_override("font_size", 16)
			c.add_theme_color_override("font_color", Color("e0b43a"))
		"row_title":
			c.add_theme_font_size_override("font_size", 19)
			c.add_theme_color_override("font_color", gold)
		"row_detail":
			c.add_theme_font_size_override("font_size", 16)
			c.add_theme_color_override("font_color", text)
		"tag":
			c.add_theme_font_size_override("font_size", 16)
			c.add_theme_color_override("font_color", Color("e4dccb"))
		"told_head":
			c.add_theme_font_size_override("font_size", 19)
			c.add_theme_color_override("font_color", gold)
		"told":
			c.add_theme_font_size_override("font_size", 16)
			c.add_theme_color_override("font_color", text)
		"bar":
			c.add_theme_stylebox_override("panel", _box(Color(0.09, 0.075, 0.06, 0.94), Color(gold, 0.45), 8))
		"sheet":
			c.add_theme_stylebox_override("panel", _box(Color(0.12, 0.105, 0.09, 0.82), Color(gold, 0.3), 10))
		"row":
			c.add_theme_stylebox_override("panel", _box(Color(0.17, 0.15, 0.13, 0.95), Color(0.35, 0.3, 0.24, 0.8), 8))
		"button", "button_on", "go":
			c.add_theme_font_size_override("font_size", 17)
			var base := Color("3a3026") if role == "button" else (Color("6b4a2e") if role == "button_on" else Color("8b2a24"))
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				var col := base
				if st == "hover":
					col = base.lightened(0.12)
				elif st == "pressed":
					col = base.darkened(0.2)
				elif st == "disabled":
					col = Color(0.16, 0.14, 0.12)
				var sb := _box(col, Color(gold, 0.7 if role != "button" else 0.35), 8)
				if st == "focus":
					sb.bg_color = Color(0, 0, 0, 0)
				c.add_theme_stylebox_override(st, sb)
			c.add_theme_color_override("font_color", text)
			c.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
			c.custom_minimum_size.y = TAP


static func _box(bg: Color, edge: Color, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	sb.set_corner_radius_all(3)
	return sb


## Opens the hall over `p_map` (or reads the journey again if it is open).
static func show_on(p_map: Node, p_journey: Journey) -> WinterScreen:
	for ch in p_map.get_children():
		if ch is WinterScreen:
			(ch as WinterScreen).refresh()
			return ch
	var w := WinterScreen.new()
	w.journey = p_journey
	w.map = p_map
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_map.add_child(w)
	w._build()
	w.refresh()
	return w


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var hall := HallBackdrop.new()
	hall.set_anchors_preset(Control.PRESET_FULL_RECT)
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hall)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	# The header: the step, where, the tally.
	var top := PanelContainer.new()
	_style(top, "bar")
	col.add_child(top)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	top.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_bar_title = Label.new()
	_style(_bar_title, "title")
	names.add_child(_bar_title)
	_bar_where = Label.new()
	_bar_where.clip_text = true
	_style(_bar_where, "where")
	names.add_child(_bar_where)
	_bar_tally = Label.new()
	_bar_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bar_tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style(_bar_tally, "tally")
	head.add_child(_bar_tally)

	# The step's content.
	var sheet := PanelContainer.new()
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style(sheet, "sheet")
	col.add_child(sheet)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	# Back, where in the winter, Go on.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 150
	_style(_back, "button")
	_back.pressed.connect(func() -> void: _press("back"))
	foot.add_child(_back)
	var mid := PanelContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(mid, "bar")
	foot.add_child(mid)
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_step_label.clip_text = true
	_style(_step_label, "where")
	mid.add_child(_step_label)
	_next = Button.new()
	_next.custom_minimum_size.x = 260
	_style(_next, "go")
	_next.pressed.connect(func() -> void: _press("next"))
	foot.add_child(_next)


func _press(id: String) -> void:
	journey.winter_choose(id)
	if not journey.in_winter():
		queue_free()
		if map != null and map.has_method("refresh"):
			map.call_deferred("refresh")
		return
	refresh()


## Reads the winter again and draws the step.
func refresh() -> void:
	var s := journey.winter_state()
	if s.is_empty():
		return
	var keep := _scroll.scroll_vertical if int(s.step) == _step_seen else 0
	_step_seen = int(s.step)
	_bar_title.text = str(s.title)
	_bar_where.text = "Winter of %d, %s" % [int(s.year), ("at " + str(s.where)) if not str(s.where).begins_with("a ") else ("in " + str(s.where))]
	var t: Dictionary = s.tally
	if s.resolved:
		_bar_tally.text = "Silver %d oz   Food %d\nMen %d" % [int(t.silver), int(t.food), int(t.men)]
	else:
		var spent := int(t.silver) - int(t.silver_after)
		_bar_tally.text = "Silver %d oz%s   Men %d\nFood %d, %s at the thaw" % [int(t.silver), (", spending %d" % spent) if spent > 0 else "", int(t.men), int(t.food),
				("%d left" % int(t.food_end)) if int(t.food_end) >= 0 else ("%d short" % -int(t.food_end))]
	_back.disabled = not s.can_back
	_next.text = str(s.next_label)
	var steps_n := (s.steps as Array).size()
	_step_label.text = "%d of %d%s" % [int(s.step) + 1, steps_n, ("   next: %s" % str(s.steps[int(s.step) + 1]).to_lower()) if int(s.step) + 1 < steps_n else ""]
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	if str(s.text) != "":
		_list.add_child(_label(str(s.text), "body"))
	for n in s.notes:
		_list.add_child(_label(str(n), "note"))
	if str(s.step_id) == "told":
		_told(s.told)
	for r in s.rows:
		_list.add_child(_row(r))
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = keep


func _label(text: String, role: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(l, role)
	return l


## The telling: headed parts, the lines under each.
func _told(lines: PackedStringArray) -> void:
	var buf := PackedStringArray()
	for line in lines:
		if line == "":
			continue
		if not line.begins_with("  "):
			if not buf.is_empty():
				_list.add_child(_label("\n".join(buf), "told"))
				buf.clear()
			_list.add_child(_label(line, "told_head"))
		else:
			buf.append(line.strip_edges())
	if not buf.is_empty():
		_list.add_child(_label("\n".join(buf), "told"))


## A row: its name and what it is on the left, how it stands now, then its
## buttons.
func _row(r: Dictionary) -> Control:
	var panel := PanelContainer.new()
	_style(panel, "row")
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var title := _label(str(r.title), "row_title")
	words.add_child(title)
	if str(r.detail) != "":
		words.add_child(_label(str(r.detail), "row_detail"))
	if str(r.tag) != "":
		var tag := Label.new()
		tag.text = str(r.tag)
		tag.custom_minimum_size.x = 132
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.size_flags_vertical = Control.SIZE_FILL
		_style(tag, "tag")
		line.add_child(tag)
	var btns: Array = r.buttons
	var chars := 0
	for b in btns:
		chars += str(b.label).length()
	if btns.size() > 2 or chars > 30:
		# Many buttons, or long ones: a flowing row under the words, so the
		# words keep their room and each button its whole label.
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		words.add_child(flow)
		for b in btns:
			var btn := _button(b)
			btn.autowrap_mode = TextServer.AUTOWRAP_OFF
			flow.add_child(btn)
	else:
		for b in btns:
			var btn := _button(b)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(btn)
	return panel


func _button(b: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = str(b.label)
	btn.disabled = not b.get("enabled", true)
	btn.custom_minimum_size.x = 118
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(btn, "button_on" if b.get("on", false) else "button")
	var id := str(b.id)
	btn.pressed.connect(func() -> void: _press(id))
	return btn


## The hall behind it all, drawn once: dark rafters, the long fire down the
## middle, benches either side, posts. Redrawn only when the size changes.
class HallBackdrop extends Control:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var smoke := Color("17120e")
		var wall := Color("2a1f16")
		var timber := Color("3a2a1c")
		var bench := Color("4a3626")
		var floor_col := Color("231a13")
		draw_rect(Rect2(0, 0, w, h), smoke)
		# The far gable and the floor running toward it.
		var vx := w * 0.5
		var vy := h * 0.42
		draw_colored_polygon(PackedVector2Array([Vector2(vx - w * 0.12, vy), Vector2(vx + w * 0.12, vy), Vector2(w, h), Vector2(0, h)]), floor_col)
		draw_colored_polygon(PackedVector2Array([Vector2(vx - w * 0.12, vy - h * 0.16), Vector2(vx + w * 0.12, vy - h * 0.16),
				Vector2(vx + w * 0.12, vy), Vector2(vx - w * 0.12, vy)]), wall)
		# Benches along both walls.
		for side: float in [-1.0, 1.0]:
			var near_in := vx + side * w * 0.3
			var near_out := vx + side * w * 0.5
			var far_in := vx + side * w * 0.075
			var far_out := vx + side * w * 0.12
			draw_colored_polygon(PackedVector2Array([Vector2(far_in, vy), Vector2(far_out, vy), Vector2(near_out, h), Vector2(near_in, h)]), bench)
		# Posts and rafters.
		for i in 5:
			var t := float(i) / 4.0
			var y := lerpf(vy, h, t * t)
			var half := lerpf(w * 0.12, w * 0.5, t * t)
			var post_w := lerpf(3.0, 14.0, t * t)
			for side: float in [-1.0, 1.0]:
				var x: float = vx + side * half * 0.88
				draw_rect(Rect2(x - post_w * 0.5, 0, post_w, y), timber)
			draw_line(Vector2(vx - half, lerpf(vy - h * 0.16, 0.0, t)), Vector2(vx, lerpf(vy - h * 0.3, -h * 0.2, t)), timber, post_w * 0.6)
			draw_line(Vector2(vx + half, lerpf(vy - h * 0.16, 0.0, t)), Vector2(vx, lerpf(vy - h * 0.3, -h * 0.2, t)), timber, post_w * 0.6)
		# The long fire down the middle: a glow, the hearth stones, embers.
		var glow := Color(0.9, 0.45, 0.15, 0.10)
		for k in 3:
			var g := 1.0 + k * 0.6
			draw_colored_polygon(PackedVector2Array([Vector2(vx - w * 0.02 * g, vy + 4), Vector2(vx + w * 0.02 * g, vy + 4),
					Vector2(vx + w * 0.11 * g, h), Vector2(vx - w * 0.11 * g, h)]), glow)
		draw_colored_polygon(PackedVector2Array([Vector2(vx - w * 0.012, vy + 6), Vector2(vx + w * 0.012, vy + 6),
				Vector2(vx + w * 0.07, h), Vector2(vx - w * 0.07, h)]), Color("5d5f62"))
		draw_colored_polygon(PackedVector2Array([Vector2(vx - w * 0.007, vy + 8), Vector2(vx + w * 0.007, vy + 8),
				Vector2(vx + w * 0.05, h), Vector2(vx - w * 0.05, h)]), Color("b5261e"))
		draw_colored_polygon(PackedVector2Array([Vector2(vx - w * 0.003, vy + 10), Vector2(vx + w * 0.003, vy + 10),
				Vector2(vx + w * 0.025, h), Vector2(vx - w * 0.025, h)]), Color("e0b43a"))
