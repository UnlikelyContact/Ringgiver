class_name MapScreen
extends Control
## The summer on the free-roam map: the land and the water on the left,
## with the band, its ship and whoever else is abroad moving on it as the
## days pass; the band, the place and what can be done there on the right.
## Tap the map to go there. All of it is a face on Journey: every button
## is one of its calls, and after each the screen reads the journey again
## (`refresh`).

const PANEL_W := 430.0
## Days that pass in a second of travelling, at the plain pace.
const DAYS_PER_SECOND := 1.5

var journey: Journey
var host: Node
var selected := ""
var canvas: MapCanvas
var status_label: Label
var place_box: VBoxContainer
var log_label: Label
var modal: PanelContainer
var side_panel: PanelContainer
var ways_btn: Button
var pause_btn: Button
var speed_btn: Button
var quick_box: CheckBox
var paused := false
var fast := false
var _quick := false
var _seen := ""  # what the panel was last drawn for, so it is redrawn only on a change


func setup(p_journey: Journey, p_host: Node) -> void:
	journey = p_journey
	host = p_host
	selected = journey.c.band.location
	canvas = MapCanvas.new()
	canvas.screen = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.offset_right = -PANEL_W
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.clip_contents = true
	add_child(canvas)
	canvas.centre_on(journey.roam.pos)

	# Time and the view, over the map's top edge.
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.offset_left = 8
	bar.offset_top = 6
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	pause_btn = _small("Pause", func() -> void:
		paused = not paused
		_time_buttons())
	bar.add_child(pause_btn)
	speed_btn = _small("Faster", func() -> void:
		fast = not fast
		_time_buttons())
	bar.add_child(speed_btn)
	bar.add_child(_small("Stop", func() -> void:
		journey.roam.stop()
		refresh()))
	bar.add_child(_small("+", func() -> void: canvas.zoom_by(1.3)))
	bar.add_child(_small("-", func() -> void: canvas.zoom_by(1.0 / 1.3)))
	bar.add_child(_small("Follow", func() -> void:
		canvas.follow = true
		canvas.queue_redraw()))

	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_label.anchor_right = 1.0
	log_label.offset_left = 10
	log_label.offset_right = -PANEL_W - 10
	log_label.offset_top = -118
	log_label.offset_bottom = -6
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.add_theme_color_override("font_color", Palette.TEXT)
	log_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var men_btn := Button.new()
	men_btn.text = "Your men"
	men_btn.custom_minimum_size = Vector2(110, 36)
	men_btn.pressed.connect(_show_men)
	row.add_child(men_btn)
	ways_btn = Button.new()
	ways_btn.text = "Your ways"
	ways_btn.custom_minimum_size = Vector2(150, 36)
	ways_btn.pressed.connect(_show_ways)
	row.add_child(ways_btn)
	var houses_btn := Button.new()
	houses_btn.text = "Families"
	houses_btn.custom_minimum_size = Vector2(110, 36)
	houses_btn.pressed.connect(_show_families)
	row.add_child(houses_btn)
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
	side_panel = PanelContainer.new()
	side_panel.anchor_left = 0.06
	side_panel.anchor_right = 0.94
	side_panel.anchor_top = 0.06
	side_panel.anchor_bottom = 0.94
	side_panel.visible = false
	side_panel.add_theme_stylebox_override("panel", _plate(Color("1f2226"), 16))
	add_child(side_panel)
	_time_buttons()
	refresh()
	if host != null and host.get("hints") != null:
		(host.hints as Hints).attach(self)  # the first days' hints (view/hints.gd)


func _small(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(54, 34)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(on)
	return b


func _time_buttons() -> void:
	pause_btn.text = "Go on" if paused else "Pause"
	speed_btn.text = "Slower" if fast else "Faster"


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


# --- The days passing ---------------------------------------------------------------

func _process(delta: float) -> void:
	if journey == null or not visible or host == null:
		return
	if modal.visible or side_panel.visible or paused or not journey.moving():
		return
	journey.advance(delta * DAYS_PER_SECOND * (3.0 if fast else 1.0))
	if not journey.fight.is_empty():
		refresh()
		return
	_status()
	var now := _state_key()
	if now != _seen:
		if journey.c.band.location != "":
			selected = journey.c.band.location
		refresh()
	else:
		log_label.text = "\n".join(journey.said.slice(maxi(0, journey.said.size() - 5)))
		canvas.queue_redraw()


## What the right-hand panel depends on: redrawn when this changes.
func _state_key() -> String:
	return "%s|%d|%s|%s|%d|%s" % [journey.c.band.location, journey.decisions.size(), journey.moving(), selected,
			journey.winter_report.size(), journey.c.over]


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
	if selected != "" and (journey.c.world.place(selected) == null or not band.knows(selected)):
		selected = band.location
	_status()
	log_label.text = "\n".join(journey.said.slice(maxi(0, journey.said.size() - 5)))
	_fill_place()
	_fill_modal()
	_seen = _state_key()
	canvas.queue_redraw()


func _status() -> void:
	var s := journey.status()
	var lines := PackedStringArray()
	lines.append("%s%s" % [s.title, (", " + str(s.way)) if str(s.way) != "" else ""])
	lines.append("%d, day %d (%d days of summer left)   %s" % [s.year, s.day, s.days_left, Journey._cap(str(s.where))])
	lines.append("Silver %d oz   Food %d   Men %d%s" % [s.silver, s.food, s.men, (" (+%d hurt)" % s.hurt) if int(s.hurt) > 0 else ""])
	var ship := "No ship: you go on foot"
	if str(s.ship) != "no ship":
		ship = "%s%s, %s" % [Journey._cap(str(s.ship)), (" (hurt %d)" % s.ship_damage) if int(s.ship_damage) > 0 else "",
				"with you" if s.ship_with else "left on the beach"]
		if str(s.ship_trouble) != "":
			ship += ": " + str(s.ship_trouble)
	lines.append(ship)
	lines.append("Fame %d   Honor %d   Luck %d   %s%s%s" % [s.fame, s.honor, s.luck, str(s.rank).capitalize(),
			"   OUTLAW" if s.outlaw else "", ("   Feuds %d" % s.feuds) if int(s.feuds) > 0 else ""])
	var hold := "Carrying: %s (room for %d)" % [s.cargo if str(s.cargo) != "" else "nothing", s.cargo_room]
	if int(s.captives) > 0:
		hold += "   Captives %d" % s.captives
	lines.append(hold)
	if str(s.work) != "":
		lines.append("Work in hand: %s" % s.work)
	status_label.text = "\n".join(lines)
	ways_btn.text = "Your ways (%d to spend)" % int(s.points) if int(s.points) > 0 else "Your ways"


func _fill_place() -> void:
	for ch in place_box.get_children():
		ch.queue_free()
	var world := journey.c.world
	var band := journey.c.band
	var p := world.place(selected) if selected != "" else null
	var here := p != null and p.id == band.location
	if p == null:
		# The wilds, or the water.
		place_box.add_child(_text(Journey._cap(journey.whereabouts()), 18, Palette.GOLD))
		place_box.add_child(_text("Tap the map to go there: the land on foot, the water if you have a ship. Tap a place to make for it.", 13, Palette.DIM))
		if journey.moving():
			place_box.add_child(_text("On your way.", 13, Palette.TEXT))
		_add_actions()
		return
	place_box.add_child(_text(Journey._cap(p.display_name.trim_prefix("the ")), 18, Palette.GOLD))
	var lord := FactionAI.ruler_of(world, p.id)
	var about := "A %s in %s" % [WorldTypes.PLACE_KIND_NAMES[p.kind], WorldTypes.REGION_NAMES[p.region]]
	if lord != null and lord.alive:
		about += ", under %s" % lord.leader
	if p.family != "":
		about += ". Home of %s" % p.family
	about += "."
	if p.id == band.home:
		about += " You wintered here."
	about += _house_line(p)
	if not Feud.find(band, p.family).is_empty():
		about += " There is a feud between you."
	place_box.add_child(_text(about, 13, Palette.DIM))
	if band.gift("price_talk", false) and p.has_market and not here:
		var talk := PackedStringArray()
		for g in WorldTypes.Good.values():
			if int(p.stock.get(g, 0)) > 0 and g != WorldTypes.Good.GRAIN:
				talk.append("%s %d" % [WorldTypes.GOOD_NAMES[g], Market.price(journey.c.world_rules, p, g)])
		place_box.add_child(_text("Prices there, as you hear them: %s." % ", ".join(talk), 12, Palette.TEXT))
	if not here:
		var days := journey.days_to(p.id)
		var go := Button.new()
		go.text = ("Make for it (%d days)" % days) if days >= 0 else "No way there: it needs a ship"
		if journey.moving():
			go.text = "On your way (%d days)" % days if days >= 0 else go.text
		go.disabled = days < 0 or not journey.can_act()
		go.custom_minimum_size = Vector2(0, 46)
		go.add_theme_font_size_override("font_size", 16)
		go.pressed.connect(func() -> void:
			journey.go_to_place(p.id)
			refresh())
		place_box.add_child(go)
		return
	# The market first, then the deeds.
	place_box.add_child(_small("What sells where, and men for hire", _show_trade))
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
	_add_actions()


func _add_actions() -> void:
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
			canvas.follow = true
			canvas.centre_on(journey.roam.pos)
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
		box.add_child(_scrolling("%s.\n\n%s" % [Journey._cap(c.over_reason), "\n".join(told)]))
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
			canvas.follow = true
			canvas.centre_on(journey.roam.pos)
			refresh())
		box.add_child(spring)
		return
	var d := journey.current()
	if d.is_empty():
		return
	modal.visible = true
	modal.add_child(box)
	var titles := {"fight": "A fight offers", "merchant": "A sail on the sea", "spine": "Word comes", "demand": "A feud", "house": "A house sends word"}
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


# --- Your men, your ways ----------------------------------------------------------------

func _open_side(title: String) -> VBoxContainer:
	for ch in side_panel.get_children():
		ch.queue_free()
	side_panel.visible = true
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	side_panel.add_child(box)
	box.add_child(_text(title, 22, Palette.GOLD))
	return box


func _close_side(box: VBoxContainer) -> void:
	var close := Button.new()
	close.text = "Back to the map"
	close.custom_minimum_size = Vector2(200, 44)
	close.pressed.connect(func() -> void:
		side_panel.visible = false
		refresh())
	box.add_child(close)


func _show_men() -> void:
	var c := journey.c
	var band := c.band
	var box := _open_side("%s and his men" % Way.title(band))
	var lines := PackedStringArray()
	lines.append("Might, Skill, Grit, Nerve, Wits. A man too hurt stays behind when it comes to a fight.")
	for m in band.fighters():
		var w := m.current_wound(c.rules)
		var bits := PackedStringArray()
		bits.append("%s%s" % [m.display_name, " (you)" if m == band.leader else ""])
		bits.append("%d, %s %s" % [m.age, CombatTypes.TIER_NAMES[m.tier], CombatTypes.ROLE_NAMES[m.role]])
		bits.append("M%d S%d G%d N%d W%d" % [m.stats[0], m.stats[1], m.stats[2], m.stats[3], m.stats[4]])
		if m != band.leader:
			bits.append("loyalty %d, wants %s" % [m.loyalty, CampaignTypes.AMBITION_NAMES[m.ambition]])
		if w != CombatTypes.Wound.UNHURT:
			bits.append(CombatTypes.WOUND_NAMES[w] + (" (stays behind)" if m.too_hurt_to_fight(c.rules) and m != band.leader else ""))
		for mm in m.maims:
			bits.append(CampaignTypes.MAIM_NAMES[mm])
		if m.kills > 0:
			bits.append("%d put down" % m.kills)
		for t in m.traits:
			bits.append(t)
		lines.append("  ·  ".join(bits))
	lines.append("")
	if not band.friends.is_empty():
		lines.append("Friends won by counsel and deeds: %s." % ", ".join(band.friends.keys()))
	for f in band.unsettled_feuds():
		lines.append("Feud with %s (%s)." % [str(f.get("family", f.get("against", ""))), str(f.get("cause", ""))])
	box.add_child(_scrolling("\n".join(lines)))
	_close_side(box)


## The ways of life: the deeds done, the points they have earned, and the
## steps to be taken down any path, in any mixture.
func _show_ways() -> void:
	var band := journey.c.band
	var box := _open_side("Your ways")
	var free := Way.points_free(band)
	var deeds := PackedStringArray()
	for way in Way.Id.values():
		var pts := int(band.deeds.get(way, 0))
		if pts > 0:
			deeds.append("%s %d" % [Way.name_of(way).to_lower(), pts])
	box.add_child(_text("Points to spend: %d. A point comes with every %d deeds of any kind, and you take steps down whichever ways you like. Deeds so far: %s. The saga names a man at %d deeds of one kind." % [
			free, Way.POINT_DEEDS, ", ".join(deeds) if not deeds.is_empty() else "none yet", Way.EPITHET_DEEDS], 13, Palette.TEXT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for way in Way.Id.values():
		var d := Way.def(way)
		var r := Way.rank(band, way)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var name := _text("%s (%d of %d)   %s" % [str(d.name), r, Way.MAX_RANK, d.blurb], 15, Palette.GOLD)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		var cost := Way.next_cost(band, way)
		if cost > 0:
			var b := Button.new()
			b.text = "%s (%d)" % [d.ranks[r].name, cost]
			b.disabled = not Way.can_invest(band, way)
			b.custom_minimum_size = Vector2(170, 38)
			var w: int = way
			b.pressed.connect(func() -> void:
				journey.invest(w)
				_show_ways())
			head.add_child(b)
		list.add_child(head)
		for i in Way.MAX_RANK:
			var step: Dictionary = d.ranks[i]
			list.add_child(_text("    %s: %s" % [step.name, step.text], 12, Palette.TEXT if i < r else Palette.DIM))
	_close_side(box)


## The families: every house with its head, its seat, how it stands toward
## you and its ties and feuds, then this year's tidings of the houses.
func _show_families() -> void:
	var c := journey.c
	var box := _open_side("The families")
	var fs := c.world.families
	if fs == null:
		_close_side(box)
		return
	box.add_child(_text("How each house stands toward you, from blood-enemy to sworn friend. What you do to one house its kin and friends feel too, and its enemies the other way.", 13, Palette.DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var told := fs.tidings_of()
	if not told.is_empty():
		list.add_child(_text("Tidings of the houses", 15, Palette.GOLD))
		list.add_child(_text("\n".join(told), 12, Palette.TEXT))
	for r in fs.report(c.world_rules, c.world, c.band):
		if not r.known and int(r.standing) == 0 and str(r.feud) == "" and not r.western:
			continue
		list.add_child(_text("%s   %s (%+d)" % [r.name, str(r.step).capitalize(), int(r.standing)], 15,
				Palette.GOLD if int(r.standing) >= 0 else Palette.TEXT))
		var about := "%s holds %s; %s is his heir. A %s house, %d men, honor %d." % [r.head, r.seat_name, r.heir, r.temper, int(r.strength), int(r.honor)]
		if not (r.your_ties as PackedStringArray).is_empty():
			about += " Yours by %s." % " and ".join(r.your_ties)
		if str(r.feud) != "":
			about += " %s." % Journey._cap(str(r.feud))
		list.add_child(_text(about, 12, Palette.TEXT))
		if not (r.ties as PackedStringArray).is_empty():
			list.add_child(_text("; ".join(r.ties), 12, Palette.DIM))
	_close_side(box)


## What sells where (Journey.price_book) and the men for hire where the
## band stands (Journey.men_for_hire): plain values from the sim, read
## out. Hiring itself is among the place's deeds.
func _show_trade() -> void:
	var box := _open_side("What sells where")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var book := journey.price_book()
	var runs := PackedStringArray()
	for r in (book.runs as Array).slice(0, 6):
		runs.append("%s: buy at %s for %d, sell at %s for %d" % [str(r.name).capitalize(), r.from_name, int(r.buy), r.to_name, int(r.sell)])
	list.add_child(_text("The best carries you know of", 15, Palette.GOLD))
	list.add_child(_text("\n".join(runs) if not runs.is_empty() else "You have seen too few prices yet. Every market and farm stall you come to is remembered.", 12, Palette.TEXT))
	for pl in book.places:
		var goods := PackedStringArray()
		for row in pl.rows:
			goods.append("%s %s/%s" % [row.name, str(row.buy) if int(row.buy) > 0 else "-", str(row.sell) if int(row.sell) > 0 else "-"])
		list.add_child(_text("%s (%s): %s" % [Journey._cap(str(pl.name)), pl.when, ", ".join(goods)], 12, Palette.DIM))
	var men := journey.men_for_hire()
	if not men.is_empty():
		list.add_child(_text("Men for hire here", 15, Palette.GOLD))
		for o in men:
			list.add_child(_text("%s, %d oz and %d a month, %s" % [o.text, int(o.price), int(o.wage), o.tier], 12, Palette.TEXT))
	_close_side(box)


## The ruling family of a place and how it stands toward you, for the
## place panel.
func _house_line(p: Place) -> String:
	var fs := journey.c.world.families
	if fs == null or not fs.houses.has(p.family):
		return ""
	var h := fs.house(p.family)
	return " %s is head of it; they think of you as %s (%+d)." % [h.head,
			Families.step_phrase(Families.step_of(journey.c.world_rules, journey.c.band, h.name)), Families.standing(journey.c.band, h.name)]


# --- The map itself ------------------------------------------------------------------

## A tap on the map at `at` (canvas pixels): a place the band knows, or
## the ground or water there. Either way the band makes for it.
func tap_map(at: Vector2) -> void:
	if not journey.can_act():
		return
	var best := ""
	var best_d := 20.0
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
		if best != journey.c.band.location:
			journey.go_to_place(best)
	else:
		selected = ""
		journey.go_to_point(canvas.from_px(at))
	canvas.follow = true
	refresh()
