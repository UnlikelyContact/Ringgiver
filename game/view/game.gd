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
## The last saga that came to an end (Chronicle.saga's values), for the
## title's "Read the last saga"; kept in the config between visits.
var last_saga := {}
## Saving (sim/save/, docs/design/notes/save.md): the saga goes to the
## autosave at its natural beats (`autosave`: arriving, a decision, a deed,
## a winter step, a fight begun or over), every TRAVEL_SAVE_MS at most while
## the band is under way (`autosave_travel`), and when the window loses the
## player (closed, hidden, put behind another). Never while the battle
## screen is up: a saga saved in a fight resumes at the fight's start, the
## save made as it began. Tools turn it off, or point SaveStore.dir away.
var autosave_on := true
## The least time between two autosaves; a beat inside it is saved when it
## has passed.
const SAVE_GAP_MS := 1500
const TRAVEL_SAVE_MS := 20000
var _save_due := false
var _last_save_ms := -1000000
## What went wrong with the last save, or "".
var last_save_error := ""


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
	if not use_config:
		autosave_on = false
	show_title()


func _process(_delta: float) -> void:
	if _save_due and Time.get_ticks_msec() - _last_save_ms >= SAVE_GAP_MS:
		save_now()


## The window is losing the player: what he has is saved at once. On the
## web a closed tab may not wait for it, which is why the beats save too.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
				NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if journey != null and battle_node == null and autosave_on:
				save_now()


# --- Saving and loading (sim/save/save_store.gd, view/saves_modal.gd) --------------

## A natural beat: the saga is saved as soon as the gap allows.
func autosave() -> void:
	if journey != null and autosave_on:
		_save_due = true


## The band under way: saved now and then, not at every day.
func autosave_travel() -> void:
	if Time.get_ticks_msec() - _last_save_ms >= TRAVEL_SAVE_MS:
		autosave()


## Writes the saga to `slot` now. The autosave is not written while the
## battle screen is up. Returns "" or what went wrong.
func save_now(slot := SaveStore.AUTO) -> String:
	if slot == SaveStore.AUTO:
		_save_due = false
		if not autosave_on or journey == null or battle_node != null:
			return ""
	if journey == null:
		return "there is no saga to save"
	var err := SaveStore.write(slot, journey, view_state())
	_last_save_ms = Time.get_ticks_msec()
	last_save_error = err
	if err != "":
		push_warning("Saving the saga: " + err)
	return err


## What the screens keep beside the saga: the hints read, and where the
## map looked and what was picked on it. The settings stay in the config.
func view_state() -> Dictionary:
	var v := {}
	if hints != null:
		v["hints"] = hints.seen.keys()
	if map != null and is_instance_valid(map):
		v["map"] = map.view_state()
	return v


## Loads the saga in `slot` and goes on with it where it was: the map as it
## was looked at, the hints already read; a winter in its step, a fight
## at its start. Returns "" or what is wrong with the save.
func load_saga(slot: String) -> String:
	var r := SaveStore.read(slot)
	if r.has("error"):
		return str(r.error)
	_drop_battle()
	journey = r.journey
	hints = Hints.new(journey)
	var v: Dictionary = r.view
	for id in v.get("hints", []):
		hints.seen[str(id)] = true
	_last_save_ms = Time.get_ticks_msec()
	if slot != SaveStore.AUTO and autosave_on:
		save_now()  # the saga taken up is the one the autosave keeps now
	show_map()
	var mv: Variant = v.get("map", {})
	if map != null and mv is Dictionary and not (mv as Dictionary).is_empty():
		map.restore_view(mv)
	return ""


## The autosave a "Continue" would take up: the last, or the one before it
## when the last cannot be read; "" when there is no saga to go on with.
func continue_slot() -> String:
	for slot in [SaveStore.AUTO, SaveStore.BACKUP]:
		var h := SaveStore.head(slot)
		if h.is_empty():
			if slot == SaveStore.AUTO:
				return ""  # no autosave: the one before belongs to an older saga
			continue
		if h.has("error"):
			continue
		return "" if bool((h.get("summary", {}) as Dictionary).get("over", false)) else slot
	return ""


func continue_saga(slot: String) -> void:
	var err := load_saga(slot)
	if err != "":
		_note_on_title("The saga could not be taken up: %s." % err)


func _note_on_title(text: String) -> void:
	if screen == null:
		return
	var m := UiModal.new()
	m.max_width = 560.0
	screen.add_child(m)
	m.open("The saga")
	m.body.add_child(UiTheme.label(text))
	m.add_button("Back", func() -> void: m.queue_free(), "PrimaryButton", 160.0)


## A new beginning would take the autosave's place: asked first, while a
## saga is there to be lost.
func _ask_before_new(then: Callable) -> void:
	var slot := continue_slot()
	if slot == "" or screen == null:
		then.call()
		return
	var h := SaveStore.head(slot)
	var m := UiModal.new()
	m.name = "BeginAnew"
	m.max_width = 640.0
	screen.add_child(m)
	m.open("Begin a new saga?")
	m.body.add_child(UiTheme.label("Your saga is kept in the autosave: %s. A new saga is saved over it; the one before is kept a little while, then it is gone. To keep it, put it in a slot under Sagas first." % SaveStore.summary_line(h.get("summary", {})), "SagaLabel"))
	m.add_button("Begin anew", func() -> void:
		m.queue_free()
		then.call(), "PrimaryButton", 200.0)
	m.add_button("Sagas", func() -> void:
		m.queue_free()
		SavesModal.open(screen, self), "", 150.0)
	m.add_button("Back", func() -> void: m.queue_free(), "", 120.0)


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
	# A saga to go on with comes first, and says where it stands.
	var cont := continue_slot() if autosave_on else ""
	var bad := SaveStore.head(SaveStore.AUTO) if autosave_on else {}
	if cont != "":
		ring.custom_minimum_size.y = 96
		var go_on := UiTheme.primary("Continue the saga", func() -> void: continue_saga(cont), 340.0)
		go_on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go_on.name = "Continue"
		box.add_child(go_on)
		var line := _centred(SaveStore.summary_line(SaveStore.head(cont).get("summary", {})), "SmallLabel")
		line.name = "ContinueLine"
		box.add_child(line)
	if bad.has("error"):
		var warn := _centred("The last save could not be read: %s." % bad.error, "SmallLabel")
		warn.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.2))
		box.add_child(warn)
	var begin: Button
	if cont != "":
		begin = UiTheme.secondary("Begin a saga", func() -> void: _ask_before_new(show_name), 340.0)
	else:
		begin = UiTheme.primary("Begin a saga", show_name, 340.0)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.name = "Begin"
	box.add_child(begin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTheme.S3)
	box.add_child(row)
	var other := UiTheme.secondary("Another beginning", func() -> void: _ask_before_new(show_origins), 220.0)
	other.tooltip_text = "Begin as a younger son or a freedman, on the map"
	row.add_child(other)
	var skirmish := UiTheme.secondary("A single fight", start_skirmish, 220.0)
	skirmish.tooltip_text = "The battle on its own: a band, a field, an enemy"
	row.add_child(skirmish)
	if not saved_saga().is_empty():
		var read := UiTheme.secondary("Read the last saga", show_last_saga, 220.0)
		read.name = "ReadLastSaga"
		read.tooltip_text = "The saga that ended last, told from its beginning"
		row.add_child(read)
	if autosave_on:
		var sagas := UiTheme.secondary("Sagas", func() -> void: SavesModal.open(screen, self), 140.0)
		sagas.name = "Sagas"
		sagas.tooltip_text = "The sagas kept: load, keep in a slot, copy to another device"
		row.add_child(sagas)
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


## Keeps an ended saga for the title (the config, or this visit only when
## the tools keep the config out).
func remember_saga(saga: Dictionary) -> void:
	last_saga = saga
	if not use_config:
		return
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # missing is fine: a new file
	cfg.set_value("saga", "last", saga)
	cfg.save(CONFIG_PATH)


func saved_saga() -> Dictionary:
	if not last_saga.is_empty() or not use_config:
		return last_saga
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return {}
	var v: Variant = cfg.get_value("saga", "last", {})
	return v if v is Dictionary else {}


## The last saga told, over the title (SagaScreen).
func show_last_saga() -> void:
	var told := saved_saga()
	if told.is_empty() or screen == null:
		return
	var m := UiModal.new()
	m.max_width = 1000.0
	screen.add_child(m)
	SagaScreen.fill(m, told, [["Back", func() -> void: m.queue_free(), "PrimaryButton"]])


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
	save_now()  # the fight's start: what a saga saved in the fight resumes at
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
	autosave()
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
