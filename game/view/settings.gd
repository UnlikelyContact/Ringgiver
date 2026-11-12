class_name Settings
extends RefCounted
## The player's own settings (docs/design/notes/shell.md): how loud, sound
## and music, the battle's pace and whether it stops when it matters, the
## map's pace, the size of the words, less motion, colours kinder to
## colour-blind eyes, a man's numbers shown or not, the hints again, and a
## word about the game. Kept in user://ringgiver.cfg under [settings] (the
## web build keeps user:// in the browser's IndexedDB), beside the
## [tutorial] section game.gd keeps there. Every change applies at once.
##
##   Settings.load_file()           # once, at the start (game.gd)
##   Settings.set_value("music", false)
##   Settings.open(host, game)      # the modal, over any full-screen Control

const PATH := "user://ringgiver.cfg"
const SECTION := "settings"
## The large text: every size of type this much bigger.
const LARGE := 1.15

## How loud everything is, 0..1.
static var master := 0.8
static var sound := true
static var music := true
## Seconds between rounds in battle when they go by on their own; 0 is
## turn by turn (the HUD's pulse slider starts here).
static var battle_pulse := 0.0
## Whether a battle whose rounds go by on their own stops when one of your
## men goes down, a man flees, you are flanked or their leader shouts.
static var auto_pause := true
## Whether the days run fast on the map from the start.
static var map_fast := false
static var large_text := false
static var reduce_motion := false
static var colour_safe := false
## Whether a man's card shows his numbers beside the words.
static var show_numbers := false

## Whether the settings are kept in the file (the tools and the tests turn
## it off, or point `path` elsewhere).
static var persist := true
static var path := PATH
static var loaded := false

const KEYS := ["master", "sound", "music", "battle_pulse", "auto_pause", "map_fast", "large_text",
	"reduce_motion", "colour_safe", "show_numbers"]
const DEFAULTS := {"master": 0.8, "sound": true, "music": true, "battle_pulse": 0.0, "auto_pause": true,
	"map_fast": false, "large_text": false, "reduce_motion": false, "colour_safe": false, "show_numbers": false}


# --- Kept and applied ------------------------------------------------------------

## Reads the file (missing is fine: the defaults) and applies what it says.
static func load_file() -> void:
	loaded = true
	if persist:
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			for k in KEYS:
				_put(k, cfg.get_value(SECTION, k, DEFAULTS[k]))
	apply()


## Writes the settings into the file, keeping whatever else it holds.
static func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(path)  # missing is fine: a new file
	for k in KEYS:
		cfg.set_value(SECTION, k, get_value(k))
	cfg.save(path)


static func get_value(key: String) -> Variant:
	match key:
		"master": return master
		"sound": return sound
		"music": return music
		"battle_pulse": return battle_pulse
		"auto_pause": return auto_pause
		"map_fast": return map_fast
		"large_text": return large_text
		"reduce_motion": return reduce_motion
		"colour_safe": return colour_safe
		"show_numbers": return show_numbers
	return null


## Sets one setting and applies it; keeps it in the file unless `keep` is
## false (a slider being dragged: the modal keeps it when it closes).
static func set_value(key: String, v: Variant, keep := true) -> void:
	_put(key, v)
	if keep:
		save()
	apply()


static func _put(key: String, v: Variant) -> void:
	match key:
		"master": master = clampf(float(v), 0.0, 1.0)
		"sound": sound = bool(v)
		"music": music = bool(v)
		"battle_pulse": battle_pulse = clampf(float(v), 0.0, 8.0)
		"auto_pause": auto_pause = bool(v)
		"map_fast": map_fast = bool(v)
		"large_text": large_text = bool(v)
		"reduce_motion": reduce_motion = bool(v)
		"colour_safe": colour_safe = bool(v)
		"show_numbers": show_numbers = bool(v)


## Back to how the game came.
static func reset() -> void:
	for k in KEYS:
		_put(k, DEFAULTS[k])
	apply()


## Puts the settings into effect: the sound's levels, the theme's type and
## its colours, motion. The battle's and the map's paces are read when a
## fight or a map begins (main.gd, map_screen.gd).
static func apply() -> void:
	Audio.master = master
	Audio.sound_on = sound
	Audio.music_on = music
	Audio.refresh()
	UiTheme.reduce_motion = reduce_motion
	UiTheme.colour_safe = colour_safe
	Palette.colour_safe = colour_safe
	UiTheme.set_text_scale(LARGE if large_text else 1.0)


# --- The modal ---------------------------------------------------------------------

## A drawn gear on a tool button, `side` square: the way to the settings.
static func gear(on: Callable, side := float(UiTheme.TOUCH)) -> Button:
	var b := UiTheme.button("", on, "ToolButton", Vector2(side, side))
	b.tooltip_text = "Settings"
	b.focus_mode = Control.FOCUS_NONE
	b.name = "Gear"
	b.draw.connect(func() -> void:
		var col := b.get_theme_color("font_pressed_color" if b.button_pressed else ("font_hover_color" if b.is_hovered() else "font_color"))
		var c := (b.size / 2.0).floor()
		var r := minf(b.size.x, b.size.y) * 0.24
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			var tooth := 1.0 if (i % 4) < 2 else 0.74
			pts.append(c + Vector2(cos(a), sin(a)) * r * tooth)
		b.draw_colored_polygon(pts, col)
		b.draw_circle(c, r * 0.36, Color(Palette.UI_NIGHT, 0.95)))
	return b


## Opens the settings over `host` (a full-screen Control). `game` is the
## game's root (view/game.gd) or null; it is told when a change needs a
## screen rebuilt (`settings_changed(key)`), and resets the hints.
static func open(host: Control, game: Node = null) -> UiModal:
	var m := UiModal.new()
	m.max_width = 900.0
	m.name = "Settings"
	host.add_child(m)
	_fill(m, game)
	Audio.duck(true)
	m.closed.connect(func() -> void:
		save()
		Audio.duck(false)
		if game != null and game.has_method("settings_closed"):
			game.settings_closed()
		m.queue_free())
	return m


static func _fill(m: UiModal, game: Node) -> void:
	m.open("Settings")
	var wide := m.get_parent() != null and (m.get_parent() as Control).size.x > 800.0
	var grid := GridContainer.new()
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", UiTheme.S3)
	grid.add_theme_constant_override("v_separation", UiTheme.S3)
	m.body.add_child(grid)
	var changed := func(key: String) -> void:
		if game != null and game.has_method("settings_changed"):
			game.settings_changed(key)

	var hear := _section(grid, "Sound")
	hear.add_child(_slider_row("Loudness", "", 0.0, 1.0, 0.05, master,
			func(v: float) -> String: return "%d%%" % int(round(v * 100.0)),
			func(v: float) -> void: set_value("master", v, false)))
	hear.add_child(_tick_row("Sound", "The sea, the fire, the fight.", sound, func(on: bool) -> void: set_value("sound", on)))
	hear.add_child(_tick_row("Music", "The lyre and the drone, on the title and in winter.", music, func(on: bool) -> void: set_value("music", on)))

	var play := _section(grid, "Pace")
	play.add_child(_slider_row("Rounds in battle", "Turn by turn, or on their own every so many seconds.", 0.0, 8.0, 0.5, battle_pulse,
			func(v: float) -> String: return "Turn by turn" if v <= 0.0 else "Every %.1f s" % v,
			func(v: float) -> void:
				set_value("battle_pulse", v, false)
				changed.call("battle_pulse")))
	play.add_child(_tick_row("Stop when it matters", "A fight that runs on its own stops when a man goes down or you are flanked.", auto_pause,
			func(on: bool) -> void:
				set_value("auto_pause", on)
				changed.call("auto_pause")))
	play.add_child(_tick_row("Days go fast on the map", "How the days run when a summer begins.", map_fast,
			func(on: bool) -> void:
				set_value("map_fast", on)
				changed.call("map_fast")))

	var read := _section(grid, "Reading")
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", UiTheme.S2)
	var group := ButtonGroup.new()
	for spec in [["Normal words", false], ["Large words", true]]:
		var big: bool = spec[1]
		var b := UiTheme.button(str(spec[0]), Callable(), "", Vector2(150, UiTheme.ROW))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = big == large_text
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(func(on: bool) -> void:
			if on and big != large_text:
				set_value("large_text", big)
				changed.call("large_text"))
		sizes.add_child(b)
	read.add_child(sizes)
	read.add_child(_tick_row("Less motion", "Screens and panels appear at once.", reduce_motion, func(on: bool) -> void: set_value("reduce_motion", on)))
	read.add_child(_tick_row("Colours for colour-blind eyes", "The two sides and the houses told apart by lightness too.", colour_safe,
			func(on: bool) -> void:
				set_value("colour_safe", on)
				changed.call("colour_safe")))
	read.add_child(_tick_row("A man's numbers", "Show the numbers behind the words on a man's card.", show_numbers,
			func(on: bool) -> void: set_value("show_numbers", on)))

	var more := _section(grid, "The saga")
	var said := UiTheme.label("", "SmallLabel")
	var again := UiTheme.secondary("Show the hints again", func() -> void:
		reset_hints(game)
		said.text = "The hints will come again as you go, and the burned hall will be taught again.", 0.0)
	more.add_child(again)
	more.add_child(said)
	more.add_child(UiTheme.quiet("About the game", func() -> void: _about(m, game), 0.0))
	m.add_button("Done", m.close, "PrimaryButton", 200.0)


static func _about(m: UiModal, game: Node) -> void:
	m.open("About Ring-Giver")
	var p := UiTheme.panel("ParchmentPanel")
	p.add_child(UiTheme.label("Here is told of a man who lost his father's hall in the days of Harald Fairhair, and of the men who followed him: how they went about Norway by farm and fjord and Thing, what silver and what enemies they won, and what the saga came to say of them. It is told a summer at a time, and no two sagas are told alike. Every sound in it is made by the game as it runs, from numbers alone.", "InkLabel"))
	m.body.add_child(p)
	m.body.add_child(UiTheme.label("Build %s." % UiTheme.build_stamp(), "SmallLabel"))
	m.add_button("Back", func() -> void: _fill(m, game), "", 150.0)
	m.add_button("Done", m.close, "PrimaryButton", 200.0)


## The hints of the first days come again (this saga's, and every new
## one's), and the burned hall is taught again rather than skippable.
static func reset_hints(game: Node) -> void:
	if persist:
		var cfg := ConfigFile.new()
		cfg.load(path)
		cfg.set_value("tutorial", "escape_done", false)
		cfg.save(path)
	if game == null:
		return
	if game.has_method("forget_escape"):
		game.forget_escape()
	var h = game.get("hints")
	if h != null:
		(h as Hints).seen.clear()
		(h as Hints).showing = ""


static func _section(grid: GridContainer, title: String) -> VBoxContainer:
	var p := UiTheme.titled_panel(title)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(p)
	return p.get_meta("body")


## A setting that is on or off: its name and what it does, and the box.
static func _tick_row(title: String, hint: String, on: bool, set_to: Callable) -> Control:
	var box := CheckBox.new()
	box.button_pressed = on
	box.custom_minimum_size = Vector2(0, UiTheme.ROW)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.toggled.connect(set_to)
	box.text = title
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(box)
	if hint != "":
		var h := UiTheme.label(hint, "SmallLabel")
		h.custom_minimum_size.x = 200
		col.add_child(h)
	return col


## A setting along a scale: its name, its value in words, the slider.
static func _slider_row(title: String, hint: String, lo: float, hi: float, step: float, value: float, words: Callable, set_to: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	var t := UiTheme.label(title, "StrongLabel", false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var v := UiTheme.label(str(words.call(value)), "StrongLabel", false)
	v.add_theme_color_override("font_color", Palette.UI_GOLD)
	top.add_child(v)
	col.add_child(top)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(200, UiTheme.ROW - 8)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(x: float) -> void:
		v.text = str(words.call(x))
		set_to.call(x))
	col.add_child(s)
	if hint != "":
		col.add_child(UiTheme.label(hint, "SmallLabel"))
	return col
