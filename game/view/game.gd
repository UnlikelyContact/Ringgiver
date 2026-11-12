extends Node
## The game's root: the title, the beginning (the burned hall: a name,
## the night told in a few cards, and the escape fought and taught on the
## battle screen), another beginning, the summer on the map, and the battle
## screen for the fights of the saga. The skirmish prototype
## (view/main.tscn on its own) is still here behind a button.

var journey: Journey = null
var layer: CanvasLayer
var screen: Control = null
var map: MapScreen = null
var battle_node: Node = null
## Tools set these so a run is repeatable.
var fixed_seed := false
var seed_in := 7
## The first days' hints (view/hints.gd), one for each saga.
var hints: Hints = null
## The player's own settings, kept between visits (on the web build the
## browser keeps user:// in IndexedDB): whether he has been through the
## burned hall before, so the escape may be skipped.
const CONFIG_PATH := "user://ringgiver.cfg"
## Tools set this to keep the player's config out of a run.
var use_config := true
var _escape_done_override := -1
## A setting changed that the screen now up must be built again for (the
## size of the words, the colours): done when the settings close.
var _rebuild := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.UI_NIGHT)
	# The player's settings (view/settings.gd), kept beside the tutorial's
	# flag; a tool's run keeps to the defaults.
	Settings.persist = use_config
	Settings.load_file()
	# The one look (view/ui_theme.gd): on the window, for tooltips and
	# pickers, and on every screen's root, since a CanvasLayer does not pass
	# a theme down.
	get_tree().root.theme = UiTheme.theme()
	UiTheme.motion = not fixed_seed  # a repeatable run (the tools) takes its stills at once
	layer = CanvasLayer.new()
	add_child(layer)
	show_title()


func _swap(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	map = null
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(c)
	layer.add_child(c)
	UiTheme.fade_in(c)


## A screen of the opening: the night and its fire behind, and a column in
## the middle at most `width` wide. Returns the column.
func _opening(fire: float, width := 760.0) -> VBoxContainer:
	var root := Control.new()
	_swap(root)
	root.add_child(UiEmbers.new(fire))
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_left = UiTheme.EDGE + 20
	centre.offset_right = -UiTheme.EDGE - 20
	centre.offset_top = UiTheme.S3
	centre.offset_bottom = -UiTheme.S3
	root.add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UiTheme.S4)
	centre.add_child(box)
	return box


func _centred(text: String, variant: String) -> Label:
	var l := UiTheme.label(text, variant)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- The title -----------------------------------------------------------------

func show_title() -> void:
	_drop_battle()
	journey = null
	var box := _opening(0.45, 560.0)
	Audio.scene("title")
	box.add_theme_constant_override("separation", UiTheme.S2)
	var ring := UiOrnament.new()
	ring.kind = UiOrnament.Kind.RING
	ring.custom_minimum_size = Vector2(0, 150)
	box.add_child(ring)
	var title := _centred("RING-GIVER", "DisplayLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var band := UiOrnament.new()
	band.kind = UiOrnament.Kind.INTERLACE
	band.custom_minimum_size = Vector2(300, 12)
	band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(band)
	box.add_child(_centred("A saga of Norway in the days of Harald Fairhair", "SmallLabel"))
	box.add_child(UiTheme.gap(UiTheme.S3))
	var begin := UiTheme.primary("Begin a saga", show_name, 340.0)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.name = "Begin"
	box.add_child(begin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTheme.S3)
	box.add_child(row)
	var other := UiTheme.secondary("Another beginning", show_origins, 220.0)
	other.tooltip_text = "Begin as a younger son or a freedman, on the map"
	row.add_child(other)
	var skirmish := UiTheme.secondary("A single fight", start_skirmish, 220.0)
	skirmish.tooltip_text = "The battle on its own: a band, a field, an enemy"
	row.add_child(skirmish)
	var stamp := UiTheme.label("build " + UiTheme.build_stamp(), "KeyLabel", false)
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stamp.offset_right = -UiTheme.EDGE - 6
	stamp.offset_bottom = -UiTheme.S2
	stamp.add_theme_color_override("font_color", Palette.UI_FAINT)
	screen.add_child(stamp)
	var gear := Settings.gear(func() -> void: Settings.open(screen, self))
	gear.position = Vector2(UiTheme.EDGE, UiTheme.S2)
	screen.add_child(gear)


# --- The beginning: the burned hall -------------------------------------------------

## A card in the middle of the screen: `text` and the buttons under it
## ([label, Callable] pairs, the first the main one). Returns the row the
## buttons are in.
func _card(text: String, buttons: Array, title := "", kicker := "") -> HBoxContainer:
	var box := _opening(1.0)
	Audio.scene("opening")
	if kicker != "":
		box.add_child(_centred(kicker.to_upper(), "KeyLabel"))
	if title != "":
		box.add_child(_centred(title, "TitleLabel"))
		var r := UiTheme.rule(true)
		r.custom_minimum_size.x = 240
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(r)
	if text != "":
		box.add_child(_centred(text, "SagaLabel"))
	box.add_child(UiTheme.gap(UiTheme.S1))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTheme.S3)
	box.add_child(row)
	var first := true
	for b in buttons:
		var btn := UiTheme.primary(str(b[0]), b[1], 260.0) if first else UiTheme.secondary(str(b[0]), b[1], 220.0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
		first = false
	return row


## Who you are: the name, then the night.
func show_name() -> void:
	var row := _card("Your name, son of the hall at Hardanger:", [], "Who are you?", "A saga begins")
	var name_edit := LineEdit.new()
	name_edit.text = "Egil"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(240, UiTheme.TOUCH)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_edit)
	var on := func() -> void:
		var who := name_edit.text.strip_edges()
		show_night(who if who != "" else "Egil", 0)
	var go := UiTheme.primary("Go on", on, 160.0)
	name_edit.text_submitted.connect(func(_t: String) -> void: on.call())
	row.add_child(go)
	row.add_child(UiTheme.quiet("Back", show_title, 100.0))


## The night the hall burned, a card at a time; the last leads out into
## the yard (the escape, taught), or, for a man who has been through it
## before, lets the saga tell it.
func show_night(who: String, i: int) -> void:
	var cards: Array = Origins.def("burned_hall").get("night", [])
	if i >= cards.size():
		begin_escape(who, false)
		return
	var buttons: Array = []
	if i < cards.size() - 1:
		buttons.append(["Go on", func() -> void: show_night(who, i + 1)])
	else:
		buttons.append(["Out into the yard", func() -> void: begin_escape(who, false)])
		if escape_done():
			buttons.append(["Let the saga tell it", func() -> void: begin_escape(who, true)])
	_card(str(cards[i]), buttons, "", "The night the hall burned   %d of %d" % [i + 1, cards.size()])


## The saga begins in the burning hall: the escape is fought on the battle
## screen and taught there, or (`skip`) told by the dice, and then the map.
func begin_escape(who: String, skip: bool) -> void:
	if not fixed_seed:
		seed_in = randi_range(1, 999999)
	journey = Journey.begin(seed_in, "burned_hall", who, true)
	hints = Hints.new(journey)
	if skip:
		var lines := journey.skip_escape()
		remember_escape()
		_card(" ".join(lines), [["Go on", show_map]], "You got out")
		return
	start_battle()


## Whether the player has been through the burned hall before (the config).
func escape_done() -> bool:
	if _escape_done_override >= 0:
		return _escape_done_override == 1
	if not use_config:
		return false
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return false
	return bool(cfg.get_value("tutorial", "escape_done", false))


## Forgets it (Settings' "show the hints again"): the escape is taught again.
func forget_escape() -> void:
	_escape_done_override = 0 if not use_config else -1


## Remembers that the player has been through the burned hall.
func remember_escape() -> void:
	if not use_config:
		_escape_done_override = 1
		return
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # missing is fine: a new file
	cfg.set_value("tutorial", "escape_done", true)
	cfg.save(CONFIG_PATH)


# --- Another beginning -------------------------------------------------------------

func show_origins() -> void:
	var root := Control.new()
	_swap(root)
	Audio.scene("opening")
	root.add_child(UiEmbers.new(0.25))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = UiTheme.EDGE + 10
	box.offset_right = -UiTheme.EDGE - 10
	box.offset_top = UiTheme.S3
	box.offset_bottom = -UiTheme.S3
	box.add_theme_constant_override("separation", UiTheme.S2)
	root.add_child(box)
	box.add_child(UiTheme.label("Another beginning", "TitleLabel"))
	box.add_child(UiTheme.label("You start with little and no ship. How you live, raider or trader, law-wise man or berserk, skald or king's man, you choose as you go, in any mixture.", "SmallLabel"))
	var over := Control.new()
	over.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(over)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", UiTheme.S3)
	box.add_child(grid)
	var under := Control.new()
	under.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(under)
	var group := ButtonGroup.new()
	var cards: Array[Button] = []
	for d in Origins.DEFS:
		if bool(d.get("escape", false)):
			continue  # the burned hall is the main beginning, from the title
		var b := Button.new()
		b.theme_type_variation = "CardButton"
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_FILL
		b.clip_contents = true
		var men := int(d.followers)
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, UiTheme.S4)
		b.add_child(m)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", UiTheme.S2)
		m.add_child(col)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)
		var nm := UiTheme.label(Journey._cap(str(d.name)), "HeadingLabel", false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		var chosen := UiTheme.chip("Chosen", Palette.UI_GOLD)
		head.add_child(chosen)
		col.add_child(UiTheme.rule(false))
		var blurb := UiTheme.label(str(d.blurb))
		col.add_child(blurb)
		col.add_child(UiTheme.label("You start %s, with %d oz of silver, on foot." % [
				"alone" if men == 0 else ("with one man" if men == 1 else "with %d men" % men), int(d.silver)], "SmallLabel"))
		for l in [nm, blurb]:
			(l as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		chosen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.toggled.connect(func(on: bool) -> void: chosen.visible = on)
		m.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = m.get_combined_minimum_size().y)
		b.button_pressed = cards.is_empty()
		chosen.visible = b.button_pressed
		b.set_meta("origin", str(d.key))
		grid.add_child(b)
		cards.append(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S3)
	box.add_child(row)
	var who_l := UiTheme.label("Your name", "SmallLabel", false)
	who_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who_l)
	var name_edit := LineEdit.new()
	name_edit.text = "Egil"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(220, UiTheme.ROW)
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_edit)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	var back := UiTheme.quiet("Back", show_title, 100.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)
	var go := UiTheme.primary("Begin", func() -> void:
		var origin := str(cards[0].get_meta("origin"))
		for c in cards:
			if c.button_pressed:
				origin = str(c.get_meta("origin"))
		var who := name_edit.text.strip_edges()
		begin_saga(origin, who if who != "" else "Egil"), 220.0)
	row.add_child(go)


# --- The saga -------------------------------------------------------------------

func begin_saga(origin: String, leader_name: String) -> void:
	if not fixed_seed:
		seed_in = randi_range(1, 999999)
	journey = Journey.begin(seed_in, origin, leader_name)
	hints = Hints.new(journey)
	show_map()


func show_map() -> void:
	_drop_battle()
	var m := MapScreen.new()
	_swap(m)
	map = m
	m.setup(journey, self)


## The map has a fight for the battle screen (Journey.fight).
func start_battle() -> void:
	if journey == null or journey.fight.is_empty():
		return
	layer.visible = false
	battle_node = preload("res://view/main.tscn").instantiate()
	battle_node.host = self
	battle_node.teach = journey.escape_pending()  # the burned hall is taught
	add_child(battle_node)
	var shouts: Array = []
	for s in journey.c.band.custom_shouts:
		shouts.append(s)
	battle_node.start_hosted(journey.fight.built, shouts)


## The battle screen's fight is over: what it left behind, for its panel.
func fight_over(result: BattleResult) -> PackedStringArray:
	if journey.escape_pending():
		remember_escape()
	return journey.fight_done(result)


## Back to the map from the battle screen.
func leave_battle() -> void:
	_drop_battle()
	layer.visible = true
	if map != null:
		map.refresh()
	elif journey != null:
		show_map()  # out of the burned hall: the first sight of the map


func _drop_battle() -> void:
	if battle_node != null:
		battle_node.queue_free()
		battle_node = null
	layer.visible = true


# --- The single fight ---------------------------------------------------------------

func start_skirmish() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	map = null
	battle_node = preload("res://view/main.tscn").instantiate()
	add_child(battle_node)


# --- The settings (view/settings.gd) -----------------------------------------------

## A setting changed while the settings are open over a screen of the game.
func settings_changed(key: String) -> void:
	match key:
		"large_text", "colour_safe":
			_rebuild = true
		"map_fast":
			if map != null:
				map.fast = Settings.map_fast
				map._time_buttons()


## The settings closed: build the screen again if the words or the colours
## changed (what is set on a node, not through the theme, follows then).
func settings_closed() -> void:
	if not _rebuild:
		return
	_rebuild = false
	if map != null:
		show_map()
	elif journey == null and battle_node == null:
		show_title()
