extends TestCase
## The interface's one look (view/ui_theme.gd, docs/design/notes/ui.md):
## the theme builds with every variation the screens ask for, the type
## keeps to its floor, the touch targets to theirs, and the modal frame is
## never taller than the screen.


func test_the_theme_has_every_variation_the_screens_use() -> void:
	var t := UiTheme.theme()
	for v in ["DisplayLabel", "TitleLabel", "HeadingLabel", "BodyLabel", "StrongLabel", "SmallLabel", "KeyLabel",
			"ValueLabel", "SagaLabel", "InkLabel", "InkSmallLabel", "InkHeadingLabel", "DangerLabel"]:
		assert_eq(t.get_type_variation_base(v), &"Label", v)
		assert_true(t.get_font_size("font_size", v) >= UiTheme.KEY, "%s is no smaller than the stat keys" % v)
	for v in ["PrimaryButton", "QuietButton", "RowButton", "CommandButton", "ToolButton", "CardButton"]:
		assert_eq(t.get_type_variation_base(v), &"Button", v)
		assert_true(t.has_stylebox("disabled", v), "%s shows when it cannot be pressed" % v)
		assert_true(t.has_stylebox("pressed", v), "%s shows a press" % v)
	for v in ["FramePanel", "SidePanel", "CardPanel", "WellPanel", "ParchmentPanel", "StripPanel", "ChipPanel"]:
		assert_eq(t.get_type_variation_base(v), &"PanelContainer", v)
	assert_true(UiTheme.theme() == t, "built once")


func test_reading_sizes_hold_on_a_phone() -> void:
	# 390 screen pixels to 540 design pixels: the body must come out at
	# about 12 screen pixels or more, the smallest read text at 10.
	var k := 390.0 / 540.0
	assert_true(UiTheme.BODY * k >= 12.0, "the body is readable on a phone")
	assert_true(UiTheme.SMALL * k >= 10.0, "the small size is readable on a phone")
	assert_true(UiTheme.TOUCH * k >= 44.0, "a primary control is a thumb's width")


func test_the_helpers_make_what_they_say() -> void:
	var p := UiTheme.primary("Go on", Callable())
	assert_eq(p.theme_type_variation, &"PrimaryButton")
	assert_true(p.custom_minimum_size.y >= UiTheme.TOUCH)
	var q := UiTheme.quiet("Back")
	assert_eq(q.theme_type_variation, &"QuietButton")
	var row := UiTheme.list_row("Rest and mend", "Five days under a roof.", Callable(), false, "Not here.")
	assert_true(row.disabled, "a deed that cannot be done is shown greyed")
	assert_true(row.custom_minimum_size.y >= UiTheme.ROW)
	var s := UiTheme.stat("silver", "10 oz")
	UiTheme.set_stat(s, "12 oz")
	assert_eq((s.get_meta("value") as Label).text, "12 oz")
	var tp := UiTheme.titled_panel("The market")
	assert_true(tp.get_meta("body") is VBoxContainer)
	for n in [p, q, row, s, tp]:
		(n as Node).free()


func test_standing_runs_from_blood_to_friend() -> void:
	var enemy := UiTheme.standing_color(-100)
	var friend := UiTheme.standing_color(100)
	assert_true(enemy.r > enemy.g, "a blood-enemy is red")
	assert_true(friend.g > friend.r * 0.95, "a sworn friend is green-gold")
	assert_eq(UiTheme.standing_color(0), Palette.UI_MUTED, "a stranger is neither")


func test_the_modal_is_never_taller_than_the_screen() -> void:
	var m := UiModal.new()
	m.theme = UiTheme.theme()
	m.set_anchors_preset(Control.PRESET_TOP_LEFT)  # sized by hand, not by a parent
	m.size = Vector2(1169, 540)
	m.open("The winter of 866")
	var long := PackedStringArray()
	for i in 80:
		long.append("866, Yule: a long line of what the winter did to the band and its men.")
	m.body.add_child(UiTheme.label("\n".join(long)))
	m.add_button("Spring", Callable(), "PrimaryButton")
	m._fit()
	assert_true(m.frame.size.y <= 540.0 - m.margin.y * 2.0 + 0.5, "the frame keeps within the screen (%.0f)" % m.frame.size.y)
	assert_true(m.frame.size.x <= m.max_width + 0.5)
	m.open("Word comes")
	m.body.add_child(UiTheme.label("Harald vows to neither cut nor comb his hair."))
	m._fit()
	assert_true(m.frame.size.y < 400.0, "a short matter makes a short frame (%.0f)" % m.frame.size.y)
	m.free()
