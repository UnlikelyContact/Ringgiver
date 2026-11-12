class_name MapScreen
extends Control
## The summer on the free-roam map: the land and the water on the left,
## with the band, its ship and whoever else is abroad moving on it as the
## days pass; the band, the place and what can be done there on the right.
## Tap the map to go there. All of it is a face on Journey: every button
## is one of its calls, and after each the screen reads the journey again
## (`refresh`). The look is UiTheme's (docs/design/notes/ui.md).

const PANEL_W := 420.0
## Days that pass in a second of travelling, at the plain pace.
const DAYS_PER_SECOND := 1.5
## Lines of the saga shown over the map's foot; the rest in the chronicle.
const LOG_LINES := 3

var journey: Journey
var host: Node
var selected := ""
var canvas: MapCanvas
## The ship, the hold and the work in hand, under the stat strip.
var status_label: Label
var place_box: VBoxContainer
var log_label: Label
## Decisions, the winter, the saga's end (UiModal).
var modal: UiModal
## Your men, your ways, the families, the chronicle (UiModal).
var side_panel: UiModal
var ways_btn: Button
var pause_btn: UiIconButton
var speed_btn: UiIconButton
var quick_box: CheckBox
## The time and view controls over the map's top-left corner. An
## HBoxContainer the map's names keep out from under (MapCanvas); the
## hints put their "?" on its end.
var time_bar: HBoxContainer
## Whether the days stand. Set from anywhere (the tools set it), the
## controls follow.
var paused := false:
	set(v):
		paused = v
		if pause_btn != null:
			_time_buttons()
var fast := false
var _quick := false
var _seen := ""  # what the panel was last drawn for, so it is redrawn only on a change
var _name_label: Label
var _date_label: Label
var _rank_box: HBoxContainer
var _summer: ProgressBar
var _summer_label: Label
var _stats := {}
var _log_box: HBoxContainer
var _log_lines := -1  # how many of the saga's lines the log shows now
# What the sound last heard (view/audio.gd): the day, the place, the
# matter put to the player, the cell the band stood on.
var _heard_day := -1
var _heard_place := ""
var _heard_matter := ""
var _heard_cell := Vector2i(-999, -999)


func setup(p_journey: Journey, p_host: Node) -> void:
	journey = p_journey
	host = p_host
	selected = journey.c.band.location
	fast = Settings.map_fast
	_heard_place = journey.c.band.location
	canvas = MapCanvas.new()
	canvas.screen = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.offset_right = -PANEL_W
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.clip_contents = true
	add_child(canvas)
	canvas.centre_on(journey.roam.pos)

	# Time and the view, over the map's top edge: a tight cluster of signs.
	time_bar = HBoxContainer.new()
	time_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	time_bar.offset_left = UiTheme.EDGE
	time_bar.offset_top = UiTheme.S2
	time_bar.add_theme_constant_override("separation", 3)
	add_child(time_bar)
	pause_btn = _small("pause", "Let the days stand", func() -> void:
		paused = not paused
		_time_buttons())
	time_bar.add_child(pause_btn)
	speed_btn = _small("fast", "Faster", func() -> void:
		fast = not fast
		_time_buttons())
	time_bar.add_child(speed_btn)
	time_bar.add_child(_small("stop", "Halt the band where it is", func() -> void:
		journey.roam.stop()
		refresh()))
	time_bar.add_child(_gap(6))
	time_bar.add_child(_small("plus", "Nearer", func() -> void: canvas.zoom_by(1.3)))
	time_bar.add_child(_small("minus", "Further", func() -> void: canvas.zoom_by(1.0 / 1.3)))
	time_bar.add_child(_small("follow", "Follow the band", func() -> void:
		canvas.follow = true
		canvas.queue_redraw()))
	time_bar.add_child(_gap(6))
	time_bar.add_child(Settings.gear(func() -> void: Settings.open(self, host)))

	# The saga's last lines at the map's foot, on a backing that reads over
	# any ground, and the way into the whole chronicle.
	_log_box = HBoxContainer.new()
	_log_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_box.offset_left = UiTheme.EDGE
	_log_box.offset_bottom = -UiTheme.S2
	_log_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_box.add_theme_constant_override("separation", UiTheme.S2)
	_log_box.draw.connect(func() -> void:
		var sb := UiTheme.box(Color(Palette.UI_NIGHT, 0.8), Color(Palette.UI_RULE_DIM, 0.8), 1, UiTheme.RADIUS)
		_log_box.draw_style_box(sb, Rect2(Vector2(-UiTheme.S2, -UiTheme.S1 - 2), _log_box.size + Vector2(UiTheme.S2 + 4, UiTheme.S1 * 2 + 4))))
	add_child(_log_box)
	log_label = UiTheme.label("", "SmallLabel")
	log_label.add_theme_color_override("font_color", Palette.UI_TEXT.darkened(0.08))
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.max_lines_visible = LOG_LINES + 1
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.resized.connect(_skip_log)
	_log_box.add_child(log_label)
	var book := UiIconButton.new("book", "The chronicle: everything told so far")
	book.custom_minimum_size = Vector2(46, 46)
	book.size_flags_vertical = Control.SIZE_SHRINK_END
	book.pressed.connect(_show_chronicle)
	_log_box.add_child(book)
	resized.connect(_place_log)

	_build_panel()

	modal = UiModal.new()
	modal.max_width = 720.0
	add_child(modal)
	side_panel = UiModal.new()
	side_panel.max_width = 1000.0
	add_child(side_panel)
	_time_buttons()
	_place_log()
	refresh()
	if host != null and host.get("hints") != null:
		(host.hints as Hints).attach(self)  # the first days' hints (view/hints.gd)


## The right-hand panel: who and when, the band in a strip of numbers, the
## three lists, and the place with what can be done there.
func _build_panel() -> void:
	var panel := UiTheme.panel("SidePanel")
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W
	add_child(panel)
	# Kept tight, so that on a phone three of the place's deeds show under
	# it without scrolling: who, when and where, the band's numbers, the
	# three lists; the rest scrolls with the place.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.S1)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	_name_label = UiTheme.label("", "HeadingLabel", false)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	who.add_child(_name_label)
	_rank_box = HBoxContainer.new()
	_rank_box.add_theme_constant_override("separation", UiTheme.S1)
	_rank_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_rank_box)
	# The summer: the date and the place (wrapping, never cut, however long
	# the place's name), the days left beside them, and a thin bar of the
	# days gone under them.
	var when := HBoxContainer.new()
	when.add_theme_constant_override("separation", UiTheme.S2)
	_date_label = UiTheme.label("", "SmallLabel")
	_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	when.add_child(_date_label)
	_summer_label = UiTheme.label("", "KeyLabel", false)
	_summer_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	when.add_child(_summer_label)
	col.add_child(when)
	_summer = ProgressBar.new()
	_summer.show_percentage = false
	_summer.custom_minimum_size = Vector2(0, 5)
	_summer.tooltip_text = "The summer gone"
	col.add_child(_summer)
	var strip := UiTheme.panel("WellPanel")
	strip.add_theme_stylebox_override("panel", UiTheme.box(Palette.UI_WELL, Color(0, 0, 0, 0), 0, UiTheme.RADIUS, UiTheme.S3, 3))
	col.add_child(strip)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", UiTheme.S1)
	strip.add_child(stats)
	for k in ["silver", "food", "men", "fame", "honor", "luck"]:
		var st := UiTheme.stat(k, "-")
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.size_flags_stretch_ratio = 1.3 if k == "men" else 1.0
		# Never wider than its share: the large words must not push the
		# panel past the screen's edge.
		for l in [st.get_child(0), st.get_meta("value")]:
			(l as Label).clip_text = true
			(l as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		(st.get_child(0) as Label).add_theme_font_size_override("font_size", UiTheme.KEY)  # the keys keep theirs
		stats.add_child(st)
		_stats[k] = st
	# The ship and the hold: read with the place, at the head of the scroll.
	status_label = UiTheme.label("", "SmallLabel")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S2)
	col.add_child(row)
	var men_btn := UiTheme.secondary("Your men", _show_men)
	men_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(men_btn)
	ways_btn = UiTheme.secondary("Your ways", _show_ways)
	ways_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ways_btn)
	var houses_btn := UiTheme.secondary("Families", _show_families)
	houses_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(houses_btn)
	for b in [men_btn, ways_btn, houses_btn]:
		(b as Button).custom_minimum_size.y = 48
		(b as Button).add_theme_font_size_override("font_size", 16)  # short names: they keep their size in the large words
	col.add_child(UiTheme.rule(false))
	place_box = VBoxContainer.new()
	place_box.add_theme_constant_override("separation", UiTheme.S2)
	var scroll := UiTheme.scroll(place_box)
	col.add_child(scroll)


func _small(glyph: String, tip: String, on: Callable) -> UiIconButton:
	var b := UiIconButton.new(glyph, tip)
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)  # a thumb's width on a phone
	b.pressed.connect(on)
	return b


func _gap(w: int) -> Control:
	return UiTheme.gap(0, w)


## The time controls show the time's state: the pause sign lit gold while
## the days stand, the fast sign lit while they run fast.
func _time_buttons() -> void:
	pause_btn.toggle_mode = true
	speed_btn.toggle_mode = true
	pause_btn.set_pressed_no_signal(paused)
	speed_btn.set_pressed_no_signal(fast)
	pause_btn.glyph = "play" if paused else "pause"
	pause_btn.tooltip_text = "Let the days go on" if paused else "Let the days stand"
	speed_btn.tooltip_text = "Slower" if fast else "Faster"


func _text(text: String, size: int, color: Color) -> Label:
	var l := UiTheme.label(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _place_log() -> void:
	if _log_box == null:
		return
	var w := minf(620.0, size.x - PANEL_W - UiTheme.EDGE * 2 - 8)
	_log_box.offset_right = _log_box.offset_left + w
	_log_box.offset_top = _log_box.offset_bottom - 10


func _show_log() -> void:
	var n := journey.said.size()
	if n == _log_lines:
		return
	_log_lines = n
	_log_box.visible = n > 0
	_skip_log()


## The newest lines that fit whole in LOG_LINES + 1 lines at the label's
## width now: no sentence shown from its middle.
func _skip_log() -> void:
	if journey == null:
		return
	var said := journey.said
	var k := mini(LOG_LINES, said.size())
	log_label.lines_skipped = 0
	while k > 0:
		log_label.text = "\n".join(said.slice(said.size() - k))
		if k == 1 or log_label.get_line_count() <= LOG_LINES + 1:
			break
		k -= 1
	log_label.lines_skipped = maxi(0, log_label.get_line_count() - LOG_LINES - 1)
	_log_box.queue_redraw()


# --- The days passing ---------------------------------------------------------------

func _process(delta: float) -> void:
	if journey == null or not visible or host == null:
		return
	if host.get("battle_node") != null:
		return  # the battle screen is up over the map
	Audio.duck(modal.visible or side_panel.visible or has_node("Settings"))
	if modal.visible or side_panel.visible or paused or not journey.moving():
		return
	journey.advance(delta * DAYS_PER_SECOND * (3.0 if fast else 1.0))
	if not journey.fight.is_empty():
		refresh()
		return
	_status()
	_ambience()
	var now := _state_key()
	if now != _seen:
		if journey.c.band.location != "":
			selected = journey.c.band.location
		refresh()
	else:
		_show_log()
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
	_log_lines = -1
	_show_log()
	_fill_place()
	_fill_modal()
	_seen = _state_key()
	_ambience()
	var here := band.location
	if here != "" and here != _heard_place:
		Audio.play("arrive")
	_heard_place = here
	canvas.queue_redraw()


## The bed of sound for where the band is (view/audio.gd): the sea aboard,
## the wind ashore and the sea too on a shore, the hall's fire in winter.
func _ambience() -> void:
	if not journey.winter_report.is_empty():
		Audio.scene("winter")
		return
	var roam := journey.roam
	var cell := roam.cell()
	if cell == _heard_cell and Audio.get_audio() != null and Audio.get_audio()._scene.begins_with("map"):
		return
	_heard_cell = cell
	if roam.aboard:
		Audio.scene("map_sea")
		return
	var shore := false
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := cell + Vector2i(dx, dy)
			if MapGrid.inside(c) and roam.grid.is_sea(c):
				shore = true
	Audio.scene("map_shore" if shore else "map_land")


func _status() -> void:
	var s := journey.status()
	var t := str(s.title)
	_name_label.text = t
	if int(s.day) != _heard_day:
		if _heard_day >= 0 and journey.moving():
			Audio.play("tick")
		_heard_day = int(s.day)
	var where := Journey._cap(str(s.where))
	_date_label.text = "%d, day %d   %s" % [s.year, s.day, where]
	var total := int(s.day) + int(s.days_left)
	_summer.max_value = maxi(1, total)
	_summer.value = int(s.day)
	_summer_label.text = "%d DAYS LEFT" % int(s.days_left)
	_summer_label.tooltip_text = "Days of summer left before the band must winter"
	_summer_label.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.2) if int(s.days_left) <= Hints.WINTER_DAYS / 2 else Palette.UI_MUTED)
	var rank_key := "%s|%s|%s|%d" % [s.rank, s.way, s.outlaw, int(s.feuds)]
	if _rank_box.get_meta("key", "") != rank_key:
		_rank_box.set_meta("key", rank_key)
		for ch in _rank_box.get_children():
			ch.queue_free()
		if s.outlaw:
			_rank_box.add_child(UiTheme.chip("Outlaw", Palette.UI_BLOOD))
		if int(s.feuds) > 0:
			_rank_box.add_child(UiTheme.chip("Feuds %d" % int(s.feuds), Palette.UI_BLOOD))
		_rank_box.add_child(UiTheme.chip(str(s.rank).capitalize(), Palette.UI_GOLD))
	UiTheme.set_stat(_stats.silver, "%d oz" % int(s.silver))
	UiTheme.set_stat(_stats.food, str(int(s.food)), Palette.UI_BLOOD.lightened(0.2) if int(s.food) < int(s.men) * 3 else Palette.UI_TEXT)
	UiTheme.set_stat(_stats.men, ("%d +%d hurt" % [s.men, s.hurt]) if int(s.hurt) > 0 else str(int(s.men)))
	UiTheme.set_stat(_stats.fame, str(int(s.fame)))
	UiTheme.set_stat(_stats.honor, str(int(s.honor)))
	UiTheme.set_stat(_stats.luck, str(int(s.luck)))
	var lines := PackedStringArray()
	var ship := "No ship: you go on foot"
	if str(s.ship) != "no ship":
		ship = "%s%s, %s" % [Journey._cap(str(s.ship)), (" (hurt %d)" % s.ship_damage) if int(s.ship_damage) > 0 else "",
				"with you" if s.ship_with else "left on the beach"]
		if str(s.ship_trouble) != "":
			ship += ": " + str(s.ship_trouble)
	lines.append(ship + ".")
	var hold := "Carrying %s (room for %d)" % [s.cargo if str(s.cargo) != "" else "nothing", s.cargo_room]
	if int(s.captives) > 0:
		hold += ", %d captives" % s.captives
	lines.append(hold + ".")
	if str(s.work) != "":
		lines.append("Work in hand: %s" % s.work)
	status_label.text = "  ".join(lines)
	ways_btn.text = "Your ways (%d)" % int(s.points) if int(s.points) > 0 else "Your ways"
	ways_btn.theme_type_variation = "PrimaryButton" if int(s.points) > 0 else ""


func _fill_place() -> void:
	for ch in place_box.get_children():
		place_box.remove_child(ch)
		if ch != status_label:
			ch.queue_free()
	var world := journey.c.world
	var band := journey.c.band
	var p := world.place(selected) if selected != "" else null
	var here := p != null and p.id == band.location
	if p == null:
		# The wilds, or the water.
		place_box.add_child(UiTheme.label(Journey._cap(journey.whereabouts()), "TitleLabel"))
		if journey.moving():
			place_box.add_child(UiTheme.label("On your way.", "StrongLabel"))
		_add_actions()
		place_box.add_child(UiTheme.label("Tap the map to go there: the land on foot, the water if you have a ship. Tap a place to make for it.", "SmallLabel"))
		place_box.add_child(status_label)
		return
	var name_row := HBoxContainer.new()
	var nm := UiTheme.label(Journey._cap(p.display_name.trim_prefix("the ")), "TitleLabel")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nm)
	if here:
		name_row.add_child(UiTheme.chip("You are here", Palette.UI_TEAL))
	place_box.add_child(name_row)
	if here:
		# What may be done comes first, under the name, where a thumb finds
		# it; the market after; what the place is, last.
		_add_actions()
		var goods := journey.market()
		if not goods.is_empty():
			place_box.add_child(UiTheme.gap(UiTheme.S1))
			place_box.add_child(UiTheme.section("The market"))
			place_box.add_child(UiTheme.label("What you pay and what you are paid, an ounce a unit.", "SmallLabel"))
			for row in goods:
				place_box.add_child(_market_row(row))
		place_box.add_child(UiTheme.gap(UiTheme.S1))
		_about_place(p)
		place_box.add_child(status_label)
		return
	_about_place(p)
	var days := journey.days_to(p.id)
	var text := ("Make for it (%d days)" % days) if days >= 0 else "No way there: it needs a ship"
	if journey.moving():
		text = "On your way (%d days)" % days if days >= 0 else text
	var go := UiTheme.primary(text, func() -> void:
		journey.go_to_place(p.id)
		refresh())
	go.disabled = days < 0 or not journey.can_act()
	place_box.add_child(UiTheme.gap(UiTheme.S1))
	place_box.add_child(go)
	place_box.add_child(status_label)


## What a place is: its kind and region, who rules it, its house and how
## that house stands toward you, and (to a man with an ear for prices)
## its prices.
func _about_place(p: Place) -> void:
	var band := journey.c.band
	var world := journey.c.world
	var here := p.id == band.location
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", UiTheme.S1)
	tags.add_theme_constant_override("v_separation", UiTheme.S1)
	tags.add_child(UiTheme.chip(str(WorldTypes.PLACE_KIND_NAMES[p.kind]).capitalize(), Palette.UI_MUTED))
	tags.add_child(UiTheme.chip(str(WorldTypes.REGION_NAMES[p.region]), Palette.UI_MUTED))
	if p.id == band.home:
		tags.add_child(UiTheme.chip("You wintered here", Palette.UI_TEAL))
	if not Feud.find(band, p.family).is_empty():
		tags.add_child(UiTheme.chip("Feud", Palette.UI_BLOOD))
	place_box.add_child(tags)
	var lord := FactionAI.ruler_of(world, p.id)
	var about := "A %s in %s" % [WorldTypes.PLACE_KIND_NAMES[p.kind], WorldTypes.REGION_NAMES[p.region]]
	if lord != null and lord.alive:
		about += ", under %s" % lord.leader
	if p.family != "":
		about += ". Home of %s" % p.family
	about += "."
	if not Feud.find(band, p.family).is_empty():
		about += " There is a feud between you."
	place_box.add_child(UiTheme.label(about, "SmallLabel"))
	var house := _house_line(p)
	if house != "":
		var hl := UiTheme.label(house.strip_edges(), "SmallLabel")
		hl.add_theme_color_override("font_color", UiTheme.standing_color(_house_standing(p)).lightened(0.1))
		place_box.add_child(hl)
	if band.gift("price_talk", false) and p.has_market and not here:
		var talk := PackedStringArray()
		for g in WorldTypes.Good.values():
			if int(p.stock.get(g, 0)) > 0 and g != WorldTypes.Good.GRAIN:
				talk.append("%s %d" % [WorldTypes.GOOD_NAMES[g], Market.price(journey.c.world_rules, p, g)])
		place_box.add_child(UiTheme.label("Prices there, as you hear them: %s." % ", ".join(talk), "SmallLabel"))


## A good at the market: its name and prices, then buy one, buy five,
## sell one, sell all.
func _market_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var nm := UiTheme.label("%s   %d / %d" % [str(row.name).capitalize(), row.buy, row.sell], "StrongLabel", false)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var have := UiTheme.label("%d here, %d yours" % [row.stock, row.have], "SmallLabel", false)
	have.clip_text = true
	col.add_child(have)
	for spec in [["+1", 1, true], ["+5", 5, true], ["-1", 1, false], ["All", 999, false]]:
		var b := UiTheme.button(str(spec[0]), Callable(), "ToolButton", Vector2(UiTheme.ROW, UiTheme.ROW))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var buying: bool = spec[2]
		b.tooltip_text = ("Buy %d" % spec[1]) if buying else ("Sell %s" % ("all" if int(spec[1]) > 99 else str(spec[1])))
		b.disabled = (int(row.stock) <= 0 or journey.c.band.silver < int(row.buy)) if buying else int(row.have) <= 0
		var good: int = row.good
		var n: int = spec[1]
		b.pressed.connect(func() -> void:
			if buying:
				journey.buy(good, n)
			else:
				journey.sell(good, n)
			Audio.play("coin")
			refresh())
		line.add_child(b)
	return line


func _add_actions() -> void:
	var acts := journey.actions()
	if acts.is_empty():
		return
	place_box.add_child(UiTheme.gap(UiTheme.S1))
	place_box.add_child(UiTheme.section("What may be done"))
	for a in acts:
		var id := str(a.id)
		var b := UiTheme.list_row(str(a.label), str(a.get("hint", "")), func() -> void:
			var silver := journey.c.band.silver
			journey.act(id)
			if journey.c.band.silver != silver:
				Audio.play("coin")
			selected = journey.c.band.location
			canvas.follow = true
			canvas.centre_on(journey.roam.pos)
			refresh(), a.get("enabled", true))
		# A deed is a main thing to do: a thumb's height on a phone.
		b.set_meta("min_h", UiTheme.TOUCH)
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, UiTheme.TOUCH)
		place_box.add_child(b)


# --- What must be answered ---------------------------------------------------------

func _fill_modal() -> void:
	modal.clear()  # still shown, if it was: a new matter does not flash it
	var c := journey.c
	if c.over:
		modal.open("The saga of %s is ended" % Way.title(c.band))
		var told := PackedStringArray()
		for line in c.band.chronicle.slice(maxi(0, c.band.chronicle.size() - 12)):
			told.append(line)
		modal.body.add_child(UiTheme.label("%s." % Journey._cap(c.over_reason), "StrongLabel"))
		modal.body.add_child(_parchment("\n".join(told)))
		modal.add_button("Another saga", func() -> void: host.show_title(), "PrimaryButton", 220.0)
		return
	if not journey.winter_report.is_empty():
		modal.open("The winter of %d" % (c.cal.year - 1))
		Audio.scene("winter")
		modal.body.add_child(_parchment("\n".join(journey.winter_report)))
		modal.add_button("Spring", func() -> void:
			journey.winter_report = PackedStringArray()
			selected = journey.c.band.location
			canvas.follow = true
			canvas.centre_on(journey.roam.pos)
			refresh(), "PrimaryButton", 220.0)
		return
	var d := journey.current()
	if d.is_empty():
		modal.visible = false
		return
	var titles := {"fight": "A fight offers", "merchant": "A sail on the sea", "spine": "Word comes", "demand": "A feud", "house": "A house sends word"}
	modal.open(str(titles.get(d.kind, "A choice")))
	var matter := "%s|%s" % [d.kind, d.text]
	if matter != _heard_matter:
		_heard_matter = matter
		Audio.play("horn" if d.kind == "fight" else "page")
	modal.body.add_child(UiTheme.label(str(d.text).strip_edges(), "SagaLabel"))
	if d.kind == "fight":
		quick_box = CheckBox.new()
		quick_box.text = "Let the saga tell it (do not fight it yourself)"
		quick_box.button_pressed = _quick
		quick_box.toggled.connect(func(on: bool) -> void: _quick = on)
		modal.body.add_child(quick_box)
	for o in d.options:
		var id := str(o.id)
		var b := modal.add_button(str(o.label), func() -> void:
			journey.quick = _quick
			journey.answer(id)
			refresh(), "", 150.0)
		b.disabled = not o.get("enabled", true)


## Long reading on parchment: the winter's tale, the chronicle.
func _parchment(text: String) -> PanelContainer:
	var p := UiTheme.panel("ParchmentPanel")
	p.add_child(UiTheme.label(text, "InkLabel"))
	return p


func _scrolling(text: String) -> ScrollContainer:
	return UiTheme.scroll(UiTheme.label(text))


# --- Your men, your ways ----------------------------------------------------------------

## Opens the side panel with `title`; returns its body to fill.
func _open_side(title: String) -> VBoxContainer:
	if not side_panel.visible:
		Audio.play("page")
	side_panel.open(title)
	return side_panel.body


## The side panel's way back to the map. `box` is the body (kept for the
## callers' sake; the button goes in the panel's footer).
func _close_side(_box: VBoxContainer = null) -> void:
	side_panel.add_button("Back to the map", func() -> void:
		side_panel.close()
		refresh(), "", 200.0)


func _show_men() -> void:
	MenPanel.new(self).show_list()


## One man: his name and what he is, his five numbers, how he is hurt, and
## what else is known of him.
func _man_row(m: Man) -> Control:
	var c := journey.c
	var band := c.band
	var card := UiTheme.panel("CardPanel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S3)
	card.add_child(row)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTheme.S2)
	who.add_child(top)
	top.add_child(UiTheme.label(m.display_name, "StrongLabel", false))
	if m == band.leader:
		top.add_child(UiTheme.chip("You", Palette.UI_GOLD))
	var bits := PackedStringArray()
	bits.append("%d, %s %s" % [m.age, CombatTypes.TIER_NAMES[m.tier], CombatTypes.ROLE_NAMES[m.role]])
	if m != band.leader:
		bits.append("loyalty %d, wants %s" % [m.loyalty, CampaignTypes.AMBITION_NAMES[m.ambition]])
	for mm in m.maims:
		bits.append(CampaignTypes.MAIM_NAMES[mm])
	if m.kills > 0:
		bits.append("%d put down" % m.kills)
	for t in m.traits:
		bits.append(t)
	who.add_child(UiTheme.label(", ".join(bits), "SmallLabel"))
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", UiTheme.S2)
	nums.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nums)
	for i in 5:
		var s := UiTheme.stat("MSGNW"[i], str(m.stats[i]))
		s.custom_minimum_size.x = 22
		nums.add_child(s)
	var w := m.current_wound(c.rules)
	var state := VBoxContainer.new()
	state.custom_minimum_size.x = 118
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(state)
	var chip: Control
	if w == CombatTypes.Wound.UNHURT:
		chip = UiTheme.chip("Unhurt", Palette.UI_TEAL)
	else:
		var col := Palette.UI_GOLD if w == CombatTypes.Wound.BRUISED else Palette.UI_BLOOD
		chip = UiTheme.chip(str(CombatTypes.WOUND_NAMES[w]).capitalize(), col)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	state.add_child(chip)
	if w != CombatTypes.Wound.UNHURT:
		if m.too_hurt_to_fight(c.rules) and m != band.leader:
			var stays := UiTheme.label("stays behind", "SmallLabel", false)
			stays.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.25))
			state.add_child(stays)
	return card


## The ways of life: the deeds done, the points they have earned, and the
## steps to be taken down any path, in any mixture. Each path is a card:
## its three steps, the ones taken lit, and the next with its cost.
func _show_ways() -> void:
	var band := journey.c.band
	var box := _open_side("Your ways")
	var free := Way.points_free(band)
	var deeds := PackedStringArray()
	for way in Way.Id.values():
		var pts := int(band.deeds.get(way, 0))
		if pts > 0:
			deeds.append("%s %d" % [Way.name_of(way).to_lower(), pts])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.S3)
	box.add_child(head)
	var pts_chip := UiTheme.chip("%d %s to spend" % [free, "point" if free == 1 else "points"], Palette.UI_GOLD if free > 0 else Palette.UI_MUTED)
	head.add_child(pts_chip)
	var about := UiTheme.label("A point comes with every %d deeds of any kind, and you take steps down whichever ways you like. Deeds so far: %s. The saga names a man at %d deeds of one kind." % [
			Way.POINT_DEEDS, ", ".join(deeds) if not deeds.is_empty() else "none yet", Way.EPITHET_DEEDS], "SmallLabel")
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(about)
	var grid := GridContainer.new()
	grid.columns = 2 if side_panel.size.x <= 0.0 or side_panel.size.x > 900.0 else 1
	grid.add_theme_constant_override("h_separation", UiTheme.S2)
	grid.add_theme_constant_override("v_separation", UiTheme.S2)
	box.add_child(grid)
	for way in Way.Id.values():
		grid.add_child(_way_card(way))
	_close_side(box)


func _way_card(way: int) -> Control:
	var band := journey.c.band
	var d := Way.def(way)
	var r := Way.rank(band, way)
	var card := UiTheme.panel("CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.S1)
	card.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var nm := UiTheme.label(str(d.name), "HeadingLabel", false)
	top.add_child(nm)
	var pips := UiOrnament.new()
	pips.kind = UiOrnament.Kind.PIPS
	pips.count = Way.MAX_RANK
	pips.filled = r
	pips.custom_minimum_size = Vector2(54, 20)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pips)
	col.add_child(UiTheme.label(str(d.blurb), "SmallLabel"))
	for i in Way.MAX_RANK:
		var step: Dictionary = d.ranks[i]
		var line := UiTheme.label("%s: %s" % [step.name, step.text], "SmallLabel")
		if i < r:
			line.add_theme_color_override("font_color", Palette.UI_TEXT)
		elif i == r:
			line.add_theme_color_override("font_color", Palette.UI_MUTED)
		else:
			line.add_theme_color_override("font_color", Palette.UI_FAINT.lightened(0.1))
		col.add_child(line)
	var cost := Way.next_cost(band, way)
	if cost > 0:
		var w: int = way
		var b := UiTheme.button("Take the step: %s (%d)" % [d.ranks[r].name, cost], func() -> void:
			journey.invest(w)
			_show_ways(), "PrimaryButton" if Way.can_invest(band, way) else "", Vector2(0, 46))
		b.disabled = not Way.can_invest(band, way)
		b.add_theme_font_size_override("font_size", 16)
		col.add_child(b)
	else:
		col.add_child(UiTheme.label("Every step taken.", "SmallLabel"))
	return card


## The families: every house with its head, its seat, how it stands toward
## you and its ties and feuds, then this year's tidings of the houses.
func _show_families() -> void:
	var c := journey.c
	var box := _open_side("The families")
	var fs := c.world.families
	if fs == null:
		_close_side(box)
		return
	box.add_child(UiTheme.label("How each house stands toward you, from blood-enemy to sworn friend. What you do to one house its kin and friends feel too, and its enemies the other way.", "SmallLabel"))
	var told := fs.tidings_of()
	if not told.is_empty():
		box.add_child(UiTheme.section("Tidings of the houses"))
		box.add_child(_parchment("\n".join(told)))
		box.add_child(UiTheme.section("The houses"))
	var grid := GridContainer.new()
	grid.columns = 2 if side_panel.size.x <= 0.0 or side_panel.size.x > 900.0 else 1
	grid.add_theme_constant_override("h_separation", UiTheme.S2)
	grid.add_theme_constant_override("v_separation", UiTheme.S2)
	box.add_child(grid)
	for r in fs.report(c.world_rules, c.world, c.band):
		if not r.known and int(r.standing) == 0 and str(r.feud) == "" and not r.western:
			continue
		var card := UiTheme.panel("CardPanel")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", UiTheme.S1)
		card.add_child(col)
		var top := HBoxContainer.new()
		col.add_child(top)
		var nm := UiTheme.label(str(r.name), "HeadingLabel", false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(nm)
		var standing := int(r.standing)
		top.add_child(UiTheme.chip("%s %+d" % [str(r.step).capitalize(), standing], UiTheme.standing_color(standing)))
		var about := "%s holds %s; %s is his heir. A %s house, %d men, honor %d." % [r.head, r.seat_name, r.heir, r.temper, int(r.strength), int(r.honor)]
		if not (r.your_ties as PackedStringArray).is_empty():
			about += " Yours by %s." % " and ".join(r.your_ties)
		col.add_child(UiTheme.label(about))
		if str(r.feud) != "":
			var f := UiTheme.label("%s." % Journey._cap(str(r.feud)), "SmallLabel")
			f.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.25))
			col.add_child(f)
		if not (r.ties as PackedStringArray).is_empty():
			col.add_child(UiTheme.label("; ".join(r.ties), "SmallLabel"))
		grid.add_child(card)
	_close_side(box)


## Everything the saga has told this summer, on parchment.
func _show_chronicle() -> void:
	var box := _open_side("The chronicle")
	var lines := journey.said
	box.add_child(_parchment("\n".join(lines) if not lines.is_empty() else "Nothing is told yet."))
	_close_side(box)
	# The newest at the foot, where the eye is.
	side_panel.scroll.set_deferred("scroll_vertical", 1 << 20)


## The ruling family of a place and how it stands toward you, for the
## place panel.
func _house_line(p: Place) -> String:
	var fs := journey.c.world.families
	if fs == null or not fs.houses.has(p.family):
		return ""
	var h := fs.house(p.family)
	return " %s is head of it; they think of you as %s (%+d)." % [h.head,
			Families.step_phrase(Families.step_of(journey.c.world_rules, journey.c.band, h.name)), Families.standing(journey.c.band, h.name)]


## The standing of a place's ruling family toward the band (0 for none).
func _house_standing(p: Place) -> int:
	var fs := journey.c.world.families
	if fs == null or not fs.houses.has(p.family):
		return 0
	return Families.standing(journey.c.band, fs.house(p.family).name)


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
