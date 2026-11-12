class_name MapScreen
extends Control
## The summer on the map: the coast and its places on the left, the band,
## the place and what can be done there on the right. All of it is a face
## on Journey: every button is one of its calls, and after each the screen
## reads the journey again (`refresh`).

const PANEL_W := 430.0
const SEA := Color("263a4f")
const LAND := Color("4d5548")
const LAND_EDGE := Color("3a4038")

## Rough shores, in the map's leagues (x east, y south), for the eye only.
const SHORES := [
	# Norway and the Swedish lands
	[Vector2(36, 83), Vector2(30, 77), Vector2(24, 73), Vector2(21, 65), Vector2(20, 56), Vector2(21, 48), Vector2(24, 42),
		Vector2(25, 36), Vector2(27, 30), Vector2(33, 26), Vector2(41, 21), Vector2(45, 17), Vector2(51, 10), Vector2(55, 3),
		Vector2(59, -4), Vector2(66, -7), Vector2(74, -5), Vector2(80, 4), Vector2(86, 16), Vector2(92, 30), Vector2(98, 42),
		Vector2(106, 52), Vector2(111, 60), Vector2(110, 68), Vector2(104, 76), Vector2(97, 82), Vector2(91, 91), Vector2(84, 96),
		Vector2(78, 91), Vector2(73, 83), Vector2(68, 76), Vector2(65, 68), Vector2(63, 61), Vector2(61, 64), Vector2(62, 72),
		Vector2(57, 77), Vector2(49, 81), Vector2(42, 82)],
	# Jutland
	[Vector2(47, 101), Vector2(53, 97), Vector2(60, 99), Vector2(64, 105), Vector2(66, 113), Vector2(60, 119), Vector2(52, 119), Vector2(46, 111)],
	# Britain
	[Vector2(-7, 57), Vector2(1, 55), Vector2(6, 61), Vector2(10, 71), Vector2(14, 81), Vector2(12, 97), Vector2(0, 101),
		Vector2(-8, 91), Vector2(-12, 77), Vector2(-13, 66)],
	# Ireland
	[Vector2(-37, 72), Vector2(-28, 70), Vector2(-24, 78), Vector2(-26, 89), Vector2(-35, 93), Vector2(-41, 84)],
	# Iceland
	[Vector2(-51, 6), Vector2(-41, 2), Vector2(-30, 6), Vector2(-32, 14), Vector2(-44, 17)],
	# Gotland
	[Vector2(110, 76), Vector2(113, 77), Vector2(114, 83), Vector2(111, 85), Vector2(109, 81)],
]

var journey: Journey
var host: Node
var selected := ""
var canvas: MapCanvas
var status_label: Label
var place_box: VBoxContainer
var log_label: Label
var modal: PanelContainer
var men_panel: PanelContainer
var quick_box: CheckBox
var _quick := false


func setup(p_journey: Journey, p_host: Node) -> void:
	journey = p_journey
	host = p_host
	selected = journey.c.band.location
	canvas = MapCanvas.new()
	canvas.screen = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.offset_right = -PANEL_W
	add_child(canvas)

	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_label.anchor_right = 1.0
	log_label.offset_left = 10
	log_label.offset_right = -PANEL_W - 10
	log_label.offset_top = -132
	log_label.offset_bottom = -6
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.add_theme_color_override("font_color", Palette.TEXT)
	log_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	log_label.add_theme_constant_override("shadow_offset_x", 1)
	log_label.add_theme_constant_override("shadow_offset_y", 1)
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_label)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W
	panel.add_theme_stylebox_override("panel", _plate(Color("2b2e33"), 10))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Palette.TEXT)
	col.add_child(status_label)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	col.add_child(bar)
	var men_btn := Button.new()
	men_btn.text = "Your men"
	men_btn.custom_minimum_size = Vector2(110, 36)
	men_btn.pressed.connect(_show_men)
	bar.add_child(men_btn)
	var here_btn := Button.new()
	here_btn.text = "Where you are"
	here_btn.custom_minimum_size = Vector2(130, 36)
	here_btn.pressed.connect(func() -> void:
		selected = journey.c.band.location
		refresh())
	bar.add_child(here_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	place_box = VBoxContainer.new()
	place_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_box.add_theme_constant_override("separation", 6)
	scroll.add_child(place_box)

	modal = PanelContainer.new()
	modal.anchor_left = 0.14
	modal.anchor_right = 0.86
	modal.anchor_top = 0.1
	modal.anchor_bottom = 0.9
	modal.visible = false
	modal.add_theme_stylebox_override("panel", _plate(Color("1f2226"), 16))
	add_child(modal)
	men_panel = PanelContainer.new()
	men_panel.add_theme_stylebox_override("panel", _plate(Color("1f2226"), 16))
	men_panel.anchor_left = 0.06
	men_panel.anchor_right = 0.94
	men_panel.anchor_top = 0.06
	men_panel.anchor_bottom = 0.94
	men_panel.visible = false
	add_child(men_panel)
	refresh()


## A flat, opaque plate for a panel, with a gold hairline and some margin.
func _plate(color: Color, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(Palette.GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# --- Reading the journey ---------------------------------------------------------

## Draws everything again from the journey, and hands a waiting fight to
## the battle screen.
func refresh() -> void:
	if journey == null:
		return
	if not journey.fight.is_empty():
		host.start_battle()
		return
	var band := journey.c.band
	if journey.c.world.place(selected) == null or not band.knows(selected):
		selected = band.location
	var s := journey.status()
	var lines := PackedStringArray()
	lines.append("%s%s    %d, day %d  (%d days of summer left)" % [s.title, (", " + str(s.way).to_lower()) if str(s.way) != "" else "",
			s.year, s.day, s.days_left])
	lines.append("Silver %d oz   Food %d   Men %d%s   %s%s" % [s.silver, s.food, s.men, (" (+%d hurt)" % s.hurt) if int(s.hurt) > 0 else "",
			str(s.ship).capitalize(), (" (hurt %d)" % s.ship_damage) if int(s.ship_damage) > 0 else ""])
	lines.append("Fame %d   Honor %d   Luck %d   %s%s%s" % [s.fame, s.honor, s.luck, str(s.rank).capitalize(),
			"   OUTLAW" if s.outlaw else "", ("   Feuds %d" % s.feuds) if int(s.feuds) > 0 else ""])
	var hold := "Hold: %s (room for %d)" % [s.cargo if str(s.cargo) != "" else "empty", s.cargo_room]
	if int(s.captives) > 0:
		hold += "   Captives %d" % s.captives
	lines.append(hold)
	if str(s.work) != "":
		lines.append("Work in hand: %s" % s.work)
	status_label.text = "\n".join(lines)
	log_label.text = "\n".join(journey.said.slice(maxi(0, journey.said.size() - 6)))
	_fill_place()
	_fill_modal()
	canvas.queue_redraw()


func _fill_place() -> void:
	for ch in place_box.get_children():
		ch.queue_free()
	var world := journey.c.world
	var band := journey.c.band
	var p := world.place(selected)
	if p == null:
		return
	var here := p.id == band.location
	place_box.add_child(_text(Journey._cap(p.display_name.trim_prefix("the ")), 18, Palette.GOLD))
	var lord := FactionAI.ruler_of(world, p.id)
	var about := "A %s in %s" % [WorldTypes.PLACE_KIND_NAMES[p.kind], WorldTypes.REGION_NAMES[p.region]]
	if lord != null and lord.alive:
		about += ", under %s" % lord.leader
	if p.family != "":
		about += ". Home of %s" % p.family
	about += "."
	if p.id == band.home:
		about += " Your own hall is here."
	if band.friends.has(p.family):
		about += " They are your friends."
	if not Feud.find(band, p.family).is_empty():
		about += " There is a feud between you."
	place_box.add_child(_text(about, 13, Palette.DIM))
	if not here:
		var days := journey.days_to(p.id)
		var sail := Button.new()
		sail.text = ("Sail here (%d days)" % days) if days >= 0 else "No way there is known"
		sail.disabled = days < 0 or not journey.can_act()
		sail.custom_minimum_size = Vector2(0, 46)
		sail.add_theme_font_size_override("font_size", 16)
		sail.pressed.connect(func() -> void:
			journey.sail(p.id)
			selected = journey.c.band.location
			refresh())
		place_box.add_child(sail)
		return
	# The market first, then the deeds.
	var goods := journey.market()
	if not goods.is_empty():
		place_box.add_child(_text("The market (what you pay / what you are paid, an ounce a unit):", 13, Palette.TEXT))
		for row in goods:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 4)
			var lab := Label.new()
			lab.text = "%s  %d/%d  (%d here, %d yours)" % [str(row.name).capitalize(), row.buy, row.sell, row.stock, row.have]
			lab.add_theme_font_size_override("font_size", 13)
			lab.add_theme_color_override("font_color", Palette.TEXT)
			lab.clip_text = true
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(lab)
			for spec in [["+1", 1, true], ["+5", 5, true], ["-1", 1, false], ["all", 999, false]]:
				var b := Button.new()
				b.text = str(spec[0])
				b.custom_minimum_size = Vector2(40, 34)
				b.add_theme_font_size_override("font_size", 13)
				var buying: bool = spec[2]
				b.disabled = (int(row.stock) <= 0 or journey.c.band.silver < int(row.buy)) if buying else int(row.have) <= 0
				var good: int = row.good
				var n: int = spec[1]
				b.pressed.connect(func() -> void:
					if buying:
						journey.buy(good, n)
					else:
						journey.sell(good, n)
					refresh())
				line.add_child(b)
			place_box.add_child(line)
	for a in journey.actions():
		var b := Button.new()
		b.text = str(a.label)
		b.disabled = not a.get("enabled", true)
		b.custom_minimum_size = Vector2(0, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 15)
		var id := str(a.id)
		b.pressed.connect(func() -> void:
			journey.act(id)
			selected = journey.c.band.location
			refresh())
		place_box.add_child(b)
		if str(a.get("hint", "")) != "":
			place_box.add_child(_text(str(a.hint), 12, Palette.DIM))


# --- What must be answered ---------------------------------------------------------

func _fill_modal() -> void:
	for ch in modal.get_children():
		ch.queue_free()
	modal.visible = false
	var c := journey.c
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	if c.over:
		modal.visible = true
		modal.add_child(box)
		box.add_child(_text("The saga of %s is ended" % Way.title(c.band), 24, Palette.GOLD))
		var told := PackedStringArray()
		for line in c.band.chronicle.slice(maxi(0, c.band.chronicle.size() - 12)):
			told.append(line)
		box.add_child(_scrolling("%s.\n\n%s" % [c.over_reason.capitalize(), "\n".join(told)]))
		var again := Button.new()
		again.text = "Another saga"
		again.custom_minimum_size = Vector2(200, 46)
		again.pressed.connect(func() -> void: host.show_title())
		box.add_child(again)
		return
	if not journey.winter_report.is_empty():
		modal.visible = true
		modal.add_child(box)
		box.add_child(_text("The winter of %d" % (c.cal.year - 1), 24, Palette.GOLD))
		box.add_child(_scrolling("\n".join(journey.winter_report)))
		var spring := Button.new()
		spring.text = "Spring"
		spring.custom_minimum_size = Vector2(200, 46)
		spring.pressed.connect(func() -> void:
			journey.winter_report = PackedStringArray()
			selected = journey.c.band.location
			refresh())
		box.add_child(spring)
		return
	var d := journey.current()
	if d.is_empty():
		return
	modal.visible = true
	modal.add_child(box)
	var titles := {"fight": "A fight offers", "merchant": "A sail on the sea", "spine": "Word comes", "demand": "A feud"}
	box.add_child(_text(str(titles.get(d.kind, "A choice")), 24, Palette.GOLD))
	var body := _text(str(d.text).strip_edges(), 15, Palette.TEXT)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	if d.kind == "fight":
		quick_box = CheckBox.new()
		quick_box.text = "Let the saga tell it (do not fight it yourself)"
		quick_box.button_pressed = _quick
		quick_box.toggled.connect(func(on: bool) -> void: _quick = on)
		box.add_child(quick_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for o in d.options:
		var b := Button.new()
		b.text = str(o.label)
		b.disabled = not o.get("enabled", true)
		b.custom_minimum_size = Vector2(150, 48)
		b.add_theme_font_size_override("font_size", 15)
		var id := str(o.id)
		b.pressed.connect(func() -> void:
			journey.quick = _quick
			journey.answer(id)
			selected = journey.c.band.location
			refresh())
		row.add_child(b)


func _scrolling(text: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var l := _text(text, 14, Palette.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(l)
	return scroll


# --- Your men ------------------------------------------------------------------------

func _show_men() -> void:
	for ch in men_panel.get_children():
		ch.queue_free()
	men_panel.visible = true
	var c := journey.c
	var band := c.band
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	men_panel.add_child(box)
	box.add_child(_text("%s and his men" % Way.title(band), 22, Palette.GOLD))
	var lines := PackedStringArray()
	lines.append("Might, Skill, Grit, Nerve, Wits. A man too hurt stays with the ship.")
	for m in band.fighters():
		var w := m.current_wound(c.rules)
		var bits := PackedStringArray()
		bits.append("%s%s" % [m.display_name, " (you)" if m == band.leader else ""])
		bits.append("%d, %s %s" % [m.age, CombatTypes.TIER_NAMES[m.tier], CombatTypes.ROLE_NAMES[m.role]])
		bits.append("M%d S%d G%d N%d W%d" % [m.stats[0], m.stats[1], m.stats[2], m.stats[3], m.stats[4]])
		if m != band.leader:
			bits.append("loyalty %d, wants %s" % [m.loyalty, CampaignTypes.AMBITION_NAMES[m.ambition]])
		if w != CombatTypes.Wound.UNHURT:
			bits.append(CombatTypes.WOUND_NAMES[w] + (" (with the ship)" if m.too_hurt_to_fight(c.rules) and m != band.leader else ""))
		for mm in m.maims:
			bits.append(CampaignTypes.MAIM_NAMES[mm])
		if m.kills > 0:
			bits.append("%d put down" % m.kills)
		for t in m.traits:
			bits.append(t)
		lines.append("  ·  ".join(bits))
	var deeds := PackedStringArray()
	for way in Way.Id.values():
		var pts := int(band.deeds.get(way, 0))
		if pts > 0:
			deeds.append("%s %d" % [Way.name_of(way).to_lower(), pts])
	lines.append("")
	lines.append("Deeds the saga counts: %s. A name comes at %d." % [", ".join(deeds) if not deeds.is_empty() else "none yet", Way.EPITHET_DEEDS])
	if not band.friends.is_empty():
		lines.append("Friends won by counsel and deeds: %s." % ", ".join(band.friends.keys()))
	for f in band.unsettled_feuds():
		lines.append("Feud with %s (%s)." % [str(f.get("family", f.get("against", ""))), str(f.get("cause", ""))])
	box.add_child(_scrolling("\n".join(lines)))
	var close := Button.new()
	close.text = "Back to the map"
	close.custom_minimum_size = Vector2(200, 44)
	close.pressed.connect(func() -> void: men_panel.visible = false)
	box.add_child(close)


# --- The map itself ------------------------------------------------------------------

## A tap on the map at `at` (canvas pixels): the nearest known place.
func tap_map(at: Vector2) -> void:
	var best := ""
	var best_d := 26.0
	for id in journey.c.band.known_places:
		var p := journey.c.world.place(id)
		if p == null or not p.is_open(journey.c.world.year):
			continue
		var d := canvas.to_px(p.pos).distance_to(at)
		if d < best_d:
			best_d = d
			best = id
	if best != "":
		selected = best
		refresh()


class MapCanvas:
	extends Control
	var screen: MapScreen
	var _origin := Vector2.ZERO
	var _scale := 1.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			screen.tap_map(event.position)

	func to_px(leagues: Vector2) -> Vector2:
		return _origin + leagues * _scale

	func _fit() -> void:
		var band := screen.journey.c.band
		var world := screen.journey.c.world
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for id in band.known_places:
			var p := world.place(id)
			if p == null or not p.is_open(world.year):
				continue
			lo = lo.min(p.pos)
			hi = hi.max(p.pos)
		if lo.x == INF:
			lo = Vector2.ZERO
			hi = Vector2(40, 40)
		var pad := 9.0
		lo -= Vector2(pad, pad)
		hi += Vector2(pad + 14.0, pad)  # room for the names on the right
		var span := (hi - lo).max(Vector2(44, 44))
		var centre := (lo + hi) / 2.0
		_scale = minf(size.x / span.x, size.y / span.y)
		_origin = size / 2.0 - centre * _scale

	func _draw() -> void:
		if screen == null or screen.journey == null:
			return
		_fit()
		var j := screen.journey
		var band := j.c.band
		var world := j.c.world
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), MapScreen.SEA)
		for shore in MapScreen.SHORES:
			var pts := PackedVector2Array()
			for v in shore:
				pts.append(to_px(v))
			draw_colored_polygon(pts, MapScreen.LAND)
			pts.append(pts[0])
			draw_polyline(pts, MapScreen.LAND_EDGE, 1.5)
		# The sea lanes between places the band knows.
		var ids: Array = band.known_places.keys()
		ids.sort()
		for id in ids:
			var a := world.place(id)
			if a == null or not a.is_open(world.year):
				continue
			for n in world.neighbours(id):
				if n <= id or not band.knows(n):
					continue
				var b := world.place(n)
				if b == null or not b.is_open(world.year):
					continue
				var col := Color(Palette.UNDYED, 0.35)
				if world.lane_is_open_sea(id, n):
					draw_dashed_line(to_px(a.pos), to_px(b.pos), col, 1.5, 6.0)
				else:
					draw_line(to_px(a.pos), to_px(b.pos), col, 1.5)
		# The way to the place picked.
		if screen.selected != band.location:
			var route := Voyage.plan(world, band.location, screen.selected, band.known_places)
			for i in range(1, route.size()):
				draw_line(to_px(world.place(route[i - 1]).pos), to_px(world.place(route[i]).pos), Palette.GOLD, 2.5)
		for id in ids:
			var p := world.place(id)
			if p == null or not p.is_open(world.year):
				continue
			var at := to_px(p.pos)
			var picked: bool = id == screen.selected
			match p.kind:
				WorldTypes.PlaceKind.TOWN:
					draw_circle(at, 7.0, Palette.OUTLINE)
					draw_circle(at, 5.5, Palette.BONE)
				WorldTypes.PlaceKind.HALL:
					draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), Palette.OUTLINE)
					draw_rect(Rect2(at - Vector2(4.5, 4.5), Vector2(9, 9)), Palette.GOLD)
				WorldTypes.PlaceKind.THING_SITE:
					draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 6), at + Vector2(-7, 6)]), Palette.OUTLINE)
					draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4.5), at + Vector2(4.5, 4.5), at + Vector2(-4.5, 4.5)]), Palette.UNDYED)
				WorldTypes.PlaceKind.BAY:
					draw_arc(at, 4.0, 0.0, TAU, 16, Palette.UNDYED, 1.5)
				_:
					draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Palette.OUTLINE)
					draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Palette.UNDYED)
			if p.has_market:
				draw_circle(at + Vector2(0, -10), 2.5, Palette.WARN)
			if not Feud.find(band, p.family).is_empty():
				draw_circle(at + Vector2(-10, 0), 3.0, Palette.BLOOD)
			if id == band.home:
				draw_arc(at, 11.0, 0.0, TAU, 20, Palette.HEARD, 1.5)
			if picked:
				draw_arc(at, 14.0, 0.0, TAU, 24, Palette.GOLD, 2.0)
			var name := p.display_name.trim_prefix("the ")
			draw_string(font, at + Vector2(12, 4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.TEXT if picked or id == band.location else Color(Palette.TEXT, 0.7))
		# The ship, where the band is.
		var here := world.place(band.location)
		if here != null:
			var s := to_px(here.pos) + Vector2(-13, -12)
			draw_colored_polygon(PackedVector2Array([s + Vector2(-8, 0), s + Vector2(8, 0), s + Vector2(5, 5), s + Vector2(-5, 5)]), Palette.TIMBER)
			draw_line(s + Vector2(0, 0), s + Vector2(0, -10), Palette.BONE, 1.5)
			draw_colored_polygon(PackedVector2Array([s + Vector2(-5, -9), s + Vector2(5, -9), s + Vector2(5, -3), s + Vector2(-5, -3)]), Palette.MADDER)
