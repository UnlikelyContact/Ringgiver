extends TestCase
## The player's settings (view/settings.gd, docs/design/notes/shell.md):
## they keep in the config file beside the tutorial's flag and come back
## as they were, they apply at once (the words' size rebuilds the one
## theme, the colours for colour-blind eyes part the two sides in
## lightness), and "show the hints again" forgets the hints.

const TEST_PATH := "user://test_settings.cfg"


func _with_file(body: Callable) -> void:
	var was_persist := Settings.persist
	var was_path := Settings.path
	Settings.persist = true
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	body.call()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.persist = was_persist
	Settings.path = was_path
	Settings.reset()


func test_settings_round_trip_through_the_file() -> void:
	_with_file(func() -> void:
		var cfg := ConfigFile.new()
		cfg.set_value("tutorial", "escape_done", true)
		cfg.save(TEST_PATH)
		Settings.set_value("master", 0.35)
		Settings.set_value("music", false)
		Settings.set_value("battle_pulse", 2.5)
		Settings.set_value("auto_pause", false)
		Settings.set_value("large_text", true)
		Settings.set_value("show_numbers", true)
		Settings.reset()
		assert_eq(Settings.master, 0.8, "reset to the default")
		Settings.load_file()
		assert_between(Settings.master, 0.349, 0.351, "the loudness came back")
		assert_eq(Settings.music, false)
		assert_eq(Settings.battle_pulse, 2.5)
		assert_eq(Settings.auto_pause, false)
		assert_eq(Settings.large_text, true)
		assert_eq(Settings.show_numbers, true)
		assert_eq(Settings.sound, true, "what was not set is the default")
		var back := ConfigFile.new()
		assert_eq(back.load(TEST_PATH), OK)
		assert_eq(back.get_value("tutorial", "escape_done", false), true, "the tutorial's flag is kept")
		assert_true(back.has_section("settings")))


func test_a_missing_file_is_the_defaults() -> void:
	_with_file(func() -> void:
		Settings.load_file()
		for k in Settings.KEYS:
			assert_eq(Settings.get_value(k), Settings.DEFAULTS[k], k))


func test_nothing_is_written_when_not_kept() -> void:
	var was := Settings.persist
	Settings.persist = false
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.set_value("sound", false)
	assert_true(not FileAccess.file_exists(TEST_PATH), "a tool's run leaves no file")
	Settings.persist = was
	Settings.path = Settings.PATH
	Settings.reset()


func test_values_are_kept_in_their_bounds() -> void:
	Settings.set_value("master", 7.0, false)
	assert_eq(Settings.master, 1.0)
	Settings.set_value("battle_pulse", -3.0, false)
	assert_eq(Settings.battle_pulse, 0.0)
	Settings.reset()


func test_large_words_rebuild_the_one_theme() -> void:
	var t := UiTheme.theme()
	var small := t.get_font_size("font_size", "SmallLabel")
	assert_eq(small, UiTheme.SMALL)
	Settings.set_value("large_text", true, false)
	assert_true(UiTheme.theme() == t, "the same theme, rebuilt in place")
	assert_eq(t.get_font_size("font_size", "SmallLabel"), int(round(UiTheme.SMALL * Settings.LARGE)))
	assert_eq(t.get_font_size("font_size", "TitleLabel"), int(round(UiTheme.TITLE * Settings.LARGE)))
	assert_true(t.has_stylebox("pressed", "PrimaryButton"), "the variations are all there again")
	Settings.set_value("large_text", false, false)
	assert_eq(t.get_font_size("font_size", "SmallLabel"), UiTheme.SMALL)
	Settings.reset()


func test_colours_for_colour_blind_eyes_differ_in_lightness() -> void:
	var lum := func(c: Color) -> float: return c.get_luminance()
	Settings.set_value("colour_safe", true, false)
	var ours: Color = Palette.side_color(0)
	var theirs: Color = Palette.side_color(1)
	assert_true(absf(lum.call(ours) - lum.call(theirs)) > 0.2, "the shields differ in lightness")
	assert_true(absf(lum.call(Palette.ui_side(0)) - lum.call(Palette.ui_side(1))) > 0.1, "so do the strip's words")
	var enemy := UiTheme.standing_color(-100)
	var friend := UiTheme.standing_color(100)
	assert_true(absf(lum.call(enemy) - lum.call(friend)) > 0.3, "a blood-enemy is dark, a friend light")
	assert_true(friend.b > friend.r, "and the friend is blue, not green")
	Settings.set_value("colour_safe", false, false)
	assert_eq(Palette.side_color(0), Palette.MADDER, "off again: madder and woad")
	Settings.reset()


func test_less_motion_stops_the_fades() -> void:
	Settings.set_value("reduce_motion", true, false)
	assert_true(UiTheme.reduce_motion)
	Settings.reset()
	assert_true(not UiTheme.reduce_motion)


class FakeGame:
	extends Node
	var hints: Hints = null
	var forgot := false

	func forget_escape() -> void:
		forgot = true


func test_show_the_hints_again_forgets_them() -> void:
	_with_file(func() -> void:
		var cfg := ConfigFile.new()
		cfg.set_value("tutorial", "escape_done", true)
		cfg.save(TEST_PATH)
		var game := FakeGame.new()
		game.hints = Hints.new(Journey.begin(7, "younger_son", "Egil"))
		game.hints.seen["where"] = true
		game.hints.showing = "walk"
		Settings.reset_hints(game)
		var back := ConfigFile.new()
		back.load(TEST_PATH)
		assert_eq(back.get_value("tutorial", "escape_done", true), false, "the burned hall is taught again")
		assert_true(game.forgot, "and the game forgets it too")
		assert_true(game.hints.seen.is_empty(), "this saga's hints come again")
		assert_eq(game.hints.showing, "")
		game.free())


func test_nothing_read_is_under_sixteen_design_pixels() -> void:
	# The audit's floor: 16 design pixels is about 11.6 on a phone held
	# sideways (390 high); the stat keys alone go under it.
	assert_true(UiTheme.SMALL >= 16, "the small size")
	assert_true(UiTheme.BODY >= 16, "the body")
	assert_true(UiTheme.TOUCH * 390.0 / 540.0 >= 44.0, "a main control is 44 screen pixels")
