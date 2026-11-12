class_name UiTheme
extends RefCounted
## The interface's one look (docs/design/notes/ui.md): a Godot Theme built
## in code, from the default font and StyleBoxes only, and helpers for the
## pieces every screen repeats. Set it once on a screen's root Control
## (`apply`) and everything under it inherits; the helpers then only pick a
## variation by name.
##
## Sizes are design pixels: the design is 540 high, so on a phone held
## sideways (390 px) one design pixel is about 0.72 of a screen pixel.
##
##   var col := VBoxContainer.new()
##   col.add_child(UiTheme.label("The winter of 866", "TitleLabel"))
##   col.add_child(UiTheme.label("The ice is off the fjord."))
##   col.add_child(UiTheme.primary("Spring", func() -> void: ...))
##   var m := UiTheme.modal(self, "A house sends word")   # UiModal
##   m.body.add_child(UiTheme.label(text))
##   m.add_button("Go on", on_go, "PrimaryButton")

# --- Type ---------------------------------------------------------------------

## The title screen's name.
const DISPLAY := 60
## A screen's or a modal's title.
const TITLE := 26
## A section, a place's name, a card's name.
const HEADING := 20
## Everything that is read.
const BODY := 17
## What is said aside: hints under a row, a place's description. The least
## size that is read on a phone (about 11.6 screen pixels at 390 high);
## nothing smaller but the stat keys.
const SMALL := 16
## The keys over a stat's value (SILVER, FOOD), in spaced capitals.
const KEY := 13

# --- Spacing: a 4-pixel grid --------------------------------------------------

const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
## The height of a control the thumb must find on a phone: 62 design
## pixels is about 45 screen pixels at 390.
const TOUCH := 62
## A secondary control or a row in a list.
const ROW := 52
## Kept clear at the screen's left and right edges (a phone's rounded
## corners and its notch).
const EDGE := 14
const RADIUS := 3

## Whether screens and modals fade in. The tools turn it off, so their
## stills are taken on what has arrived.
static var motion := true
## The player asked for less motion (Settings): nothing fades in.
static var reduce_motion := false
## Every size of type is multiplied by this (Settings: normal 1, large
## Settings.LARGE). Change it with `set_text_scale`, which rebuilds the
## theme in place so every screen follows.
static var text_scale := 1.0
## The player asked for colours kinder to colour-blind eyes (Settings):
## the standing colours run from dark red to light blue, not red to green.
static var colour_safe := false
static var _theme: Theme = null
static var _fonts := {}


## The theme, built once.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## A type size in design pixels at the player's text scale. Use it for any
## size set on a node rather than through the theme.
static func fs(px: int) -> int:
	return int(round(px * text_scale))


## Sets the text scale and rebuilds the one theme in place: every control
## that has it is told and resizes its words.
static func set_text_scale(k: float) -> void:
	if is_equal_approx(k, text_scale):
		return
	text_scale = k
	if _theme != null:
		_theme.clear()
		_fill(_theme)


## Puts the theme on `root`: everything under it inherits.
static func apply(root: Control) -> void:
	root.theme = theme()


## The default font in a few cuts: "body", "bold", "display" (heavier, a
## little spaced), "caps" (spaced, for stat keys), "italic" (slanted).
static func font(kind := "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var base: Font = ThemeDB.fallback_font
	var f: Font = base
	match kind:
		"bold":
			var v := FontVariation.new()
			v.base_font = base
			v.variation_embolden = 0.45
			f = v
		"display":
			var v := FontVariation.new()
			v.base_font = base
			v.variation_embolden = 0.7
			v.spacing_glyph = 3
			f = v
		"caps":
			var v := FontVariation.new()
			v.base_font = base
			v.variation_embolden = 0.25
			v.spacing_glyph = 1
			f = v
		"italic":
			var v := FontVariation.new()
			v.base_font = base
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
			f = v
	_fonts[kind] = f
	return f


# --- StyleBoxes ---------------------------------------------------------------

## A flat box: `bg`, a `border` of `bw` pixels, corners of `radius`, and
## content margins (left/right `mx`, top/bottom `my`).
static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := RADIUS, mx := S3, my := S2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	sb.anti_aliasing = radius > 0
	return sb


static func _empty(mx := 0, my := 0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## A pressed face: the same box with its content a pixel lower, so a press
## is felt.
static func _pressed(sb: StyleBoxFlat) -> StyleBoxFlat:
	var p: StyleBoxFlat = sb.duplicate()
	p.content_margin_top += 2
	p.content_margin_bottom -= 2
	return p


static func _button_set(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox, focus: StyleBox,
		text: Color, text_hover: Color, text_pressed: Color, text_disabled: Color, size: int, f: Font) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text_hover)
	t.set_color("font_pressed_color", type, text_pressed)
	t.set_color("font_hover_pressed_color", type, text_pressed)
	t.set_color("font_focus_color", type, text)
	t.set_color("font_disabled_color", type, text_disabled)
	t.set_font_size("font_size", type, size)
	t.set_font("font", type, f)


static func _build() -> Theme:
	var t := Theme.new()
	_fill(t)
	return t


static func _fill(t: Theme) -> void:
	t.default_font = font("body")
	t.default_font_size = fs(BODY)
	var focus := box(Color(0, 0, 0, 0), Color(Palette.UI_GOLD, 0.55), 1, RADIUS + 1, 0, 0)
	focus.draw_center = false
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2

	# Labels.
	t.set_color("font_color", "Label", Palette.UI_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_font_size("font_size", "Label", fs(BODY))
	t.set_constant("line_spacing", "Label", 2)
	_label_type(t, "DisplayLabel", fs(DISPLAY), Palette.UI_GOLD, font("display"))
	t.set_color("font_outline_color", "DisplayLabel", Color("0b0806"))
	t.set_constant("outline_size", "DisplayLabel", 6)
	_label_type(t, "TitleLabel", fs(TITLE), Palette.UI_GOLD, font("bold"))
	_label_type(t, "HeadingLabel", fs(HEADING), Palette.UI_GOLD, font("bold"))
	_label_type(t, "BodyLabel", fs(BODY), Palette.UI_TEXT, font("body"))
	_label_type(t, "StrongLabel", fs(BODY), Palette.UI_TEXT, font("bold"))
	_label_type(t, "SmallLabel", fs(SMALL), Palette.UI_MUTED, font("body"))
	_label_type(t, "KeyLabel", fs(KEY), Palette.UI_MUTED, font("caps"))
	_label_type(t, "ValueLabel", fs(18), Palette.UI_TEXT, font("bold"))
	_label_type(t, "SagaLabel", fs(21), Palette.UI_TEXT, font("body"))
	t.set_constant("line_spacing", "SagaLabel", 6)
	_label_type(t, "InkLabel", fs(BODY), Palette.UI_INK, font("body"))
	_label_type(t, "InkSmallLabel", fs(SMALL), Palette.UI_INK_MUTED, font("body"))
	_label_type(t, "InkHeadingLabel", fs(HEADING), Palette.UI_INK, font("bold"))
	_label_type(t, "DangerLabel", fs(BODY), Palette.UI_BLOOD, font("bold"))
	t.set_color("default_color", "RichTextLabel", Palette.UI_MUTED)
	t.set_font_size("normal_font_size", "RichTextLabel", fs(SMALL))
	t.set_font_size("bold_font_size", "RichTextLabel", fs(SMALL))
	t.set_font("bold_font", "RichTextLabel", font("bold"))

	# Panels: wood with a gold rule (the default), and the variations.
	var wood := box(Palette.UI_WOOD, Palette.UI_RULE_DIM, 1, RADIUS, S4, S3)
	t.set_stylebox("panel", "PanelContainer", wood)
	t.set_stylebox("panel", "Panel", wood)
	_panel_type(t, "FramePanel", _frame())
	_panel_type(t, "SidePanel", _side())
	_panel_type(t, "CardPanel", box(Palette.UI_WOOD_RAISED.darkened(0.15), Palette.UI_RULE_DIM, 1, RADIUS, S3, S2))
	_panel_type(t, "WellPanel", box(Palette.UI_WELL, Color(0, 0, 0, 0), 0, RADIUS, S3, S2))
	var parch := box(Palette.UI_PARCHMENT, Palette.UI_PARCHMENT_EDGE, 1, 2, S4, S3)
	parch.shadow_color = Color(0, 0, 0, 0.45)
	parch.shadow_size = 6
	parch.shadow_offset = Vector2(0, 2)
	_panel_type(t, "ParchmentPanel", parch)
	var strip := box(Color(Palette.UI_NIGHT, 0.82), Color(Palette.UI_RULE_DIM, 0.9), 1, RADIUS, S3, S1 + 2)
	_panel_type(t, "StripPanel", strip)
	_panel_type(t, "ChipPanel", box(Color(Palette.UI_RULE, 0.18), Color(Palette.UI_RULE, 0.55), 1, 9, S2, 1))
	_panel_type(t, "ClearPanel", _empty())

	# Buttons. The plain button is the secondary: raised wood, a bronze rule.
	var sec := box(Palette.UI_WOOD_RAISED, Palette.UI_RULE, 1, RADIUS, S4, S2)
	var sec_h := box(Palette.UI_WOOD_HOVER, Palette.UI_GOLD_DEEP, 1, RADIUS, S4, S2)
	var sec_p := _pressed(box(Palette.UI_WELL, Palette.UI_GOLD, 1, RADIUS, S4, S2))
	var sec_d := box(Color(Palette.UI_WOOD_RAISED, 0.45), Palette.UI_RULE_DIM.darkened(0.3), 1, RADIUS, S4, S2)
	_button_set(t, "Button", sec, sec_h, sec_p, sec_d, focus, Palette.UI_TEXT, Color.WHITE, Palette.UI_GOLD, Palette.UI_FAINT, fs(BODY), font("bold"))
	t.set_constant("h_separation", "Button", S2)
	t.set_constant("outline_size", "Button", 0)
	# The primary: tarnished gold, dark letters; one to a screen.
	var pri := box(Palette.UI_GOLD_DEEP, Palette.UI_GOLD, 1, RADIUS, S5, S2)
	pri.shadow_color = Color(0, 0, 0, 0.4)
	pri.shadow_size = 3
	pri.shadow_offset = Vector2(0, 2)
	var pri_h := box(Palette.UI_GOLD_DEEP.lightened(0.12), Color("f0d590"), 1, RADIUS, S5, S2)
	pri_h.shadow_color = pri.shadow_color
	pri_h.shadow_size = 3
	pri_h.shadow_offset = Vector2(0, 2)
	var pri_p := _pressed(box(Palette.UI_GOLD_DEEP.darkened(0.25), Palette.UI_GOLD, 1, RADIUS, S5, S2))
	var pri_d := box(Color(Palette.UI_GOLD_DEEP, 0.3), Color(Palette.UI_GOLD, 0.25), 1, RADIUS, S5, S2)
	_variation(t, "PrimaryButton", "Button")
	_button_set(t, "PrimaryButton", pri, pri_h, pri_p, pri_d, focus, Color("1c140b"), Color("120c06"), Color("1c140b"), Color(Palette.UI_INK, 0.6), fs(19), font("bold"))
	# The quiet: no face until touched (Back, Close).
	var quiet := _empty(S3, S2)
	_variation(t, "QuietButton", "Button")
	_button_set(t, "QuietButton", quiet, box(Color(Palette.UI_RULE, 0.15), Color(0, 0, 0, 0), 0, RADIUS, S3, S2),
			_pressed(box(Color(Palette.UI_RULE, 0.28), Color(0, 0, 0, 0), 0, RADIUS, S3, S2)), quiet, focus,
			Palette.UI_MUTED, Palette.UI_GOLD, Palette.UI_GOLD, Palette.UI_FAINT, fs(BODY), font("bold"))
	# A row in a list: a title and a hint, the whole row pressed.
	var row := box(Color(Palette.UI_WOOD_RAISED, 0.55), Color(Palette.UI_RULE_DIM, 0.8), 1, RADIUS, S3, S2)
	row.border_width_left = 3
	row.border_color = Palette.UI_RULE_DIM
	var row_h := row.duplicate() as StyleBoxFlat
	row_h.bg_color = Palette.UI_WOOD_HOVER
	row_h.border_color = Palette.UI_GOLD_DEEP
	var row_p := _pressed(row_h)
	row_p.bg_color = Palette.UI_WELL
	row_p.border_color = Palette.UI_GOLD
	var row_d := row.duplicate() as StyleBoxFlat
	row_d.bg_color = Color(Palette.UI_WELL, 0.6)
	row_d.border_color = Color(Palette.UI_RULE_DIM, 0.5)
	_variation(t, "RowButton", "Button")
	_button_set(t, "RowButton", row, row_h, row_p, row_d, focus, Palette.UI_TEXT, Color.WHITE, Palette.UI_GOLD, Palette.UI_FAINT, fs(BODY), font("bold"))
	# The battle's commands: dark iron, the shout given marked in gold.
	var cmd := box(Color(Palette.UI_NIGHT, 0.94), Palette.UI_RULE_DIM, 1, RADIUS, S1, S1)
	var cmd_h := box(Color(Palette.UI_WOOD_HOVER, 0.95), Palette.UI_RULE, 1, RADIUS, S1, S1)
	var cmd_p := box(Color("4a3a1c"), Palette.UI_GOLD, 2, RADIUS, S1, S1)
	cmd_p.border_width_top = 4
	var cmd_d := box(Color(Palette.UI_NIGHT, 0.92), Color(Palette.UI_RULE_DIM, 0.4), 1, RADIUS, S1, S1)
	_variation(t, "CommandButton", "Button")
	_button_set(t, "CommandButton", cmd, cmd_h, cmd_p, cmd_d, focus, Palette.UI_TEXT, Color.WHITE, Palette.UI_GOLD, Color(Palette.UI_FAINT, 0.8), fs(16), font("bold"))
	# Small controls laid over the map or the field (the time cluster, the
	# battle's top row).
	var tool := box(Color(Palette.UI_NIGHT, 0.86), Palette.UI_RULE_DIM, 1, RADIUS, S2, S1)
	var tool_h := box(Color(Palette.UI_WOOD_HOVER, 0.95), Palette.UI_RULE, 1, RADIUS, S2, S1)
	var tool_p := _pressed(box(Color("4a3a1c"), Palette.UI_GOLD, 1, RADIUS, S2, S1))
	var tool_d := box(Color(Palette.UI_NIGHT, 0.6), Color(Palette.UI_RULE_DIM, 0.4), 1, RADIUS, S2, S1)
	_variation(t, "ToolButton", "Button")
	_button_set(t, "ToolButton", tool, tool_h, tool_p, tool_d, focus, Palette.UI_TEXT, Color.WHITE, Palette.UI_GOLD, Palette.UI_FAINT, fs(15), font("bold"))
	# A card to choose (another beginning): a raised panel, gold when chosen.
	var card := box(Palette.UI_WOOD, Palette.UI_RULE_DIM, 1, RADIUS, S4, S3)
	var card_h := box(Palette.UI_WOOD_RAISED, Palette.UI_RULE, 1, RADIUS, S4, S3)
	var card_p := box(Color("2e2518"), Palette.UI_GOLD, 2, RADIUS, S4, S3)
	_variation(t, "CardButton", "Button")
	_button_set(t, "CardButton", card, card_h, card_p, card, focus, Palette.UI_TEXT, Palette.UI_TEXT, Palette.UI_TEXT, Palette.UI_FAINT, fs(BODY), font("body"))

	# Text entry.
	var edit := box(Palette.UI_WELL, Palette.UI_RULE_DIM, 1, RADIUS, S3, S2)
	edit.border_width_bottom = 2
	edit.border_color = Palette.UI_RULE
	var edit_f := edit.duplicate() as StyleBoxFlat
	edit_f.border_color = Palette.UI_GOLD
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_f)
	t.set_stylebox("read_only", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", Palette.UI_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.UI_FAINT)
	t.set_color("caret_color", "LineEdit", Palette.UI_GOLD)
	t.set_color("selection_color", "LineEdit", Color(Palette.UI_GOLD, 0.35))
	t.set_font_size("font_size", "LineEdit", fs(20))
	t.set_font("font", "LineEdit", font("bold"))

	# Scroll bars: a thin bronze grip in a dark groove.
	for bar in ["VScrollBar", "HScrollBar"]:
		var groove := box(Color(Palette.UI_WELL, 0.8), Color(0, 0, 0, 0), 0, 4, 3, 3)
		var grip := box(Palette.UI_RULE, Color(0, 0, 0, 0), 0, 4, 3, 3)
		var grip_h := box(Palette.UI_GOLD_DEEP, Color(0, 0, 0, 0), 0, 4, 3, 3)
		t.set_stylebox("scroll", bar, groove)
		t.set_stylebox("scroll_focus", bar, groove)
		t.set_stylebox("grabber", bar, grip)
		t.set_stylebox("grabber_highlight", bar, grip_h)
		t.set_stylebox("grabber_pressed", bar, grip_h)
	t.set_stylebox("panel", "ScrollContainer", _empty())
	t.set_stylebox("focus", "ScrollContainer", _empty())

	# The slider (the battle's pulse).
	var groove := box(Palette.UI_WELL, Palette.UI_RULE_DIM, 1, 3, 0, 3)
	t.set_stylebox("slider", "HSlider", groove)
	var fill := box(Palette.UI_RULE, Color(0, 0, 0, 0), 0, 3, 0, 3)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _disc(18, Palette.UI_GOLD, Palette.UI_INK))
	t.set_icon("grabber_highlight", "HSlider", _disc(18, Color("f0d590"), Palette.UI_INK))
	t.set_icon("grabber_disabled", "HSlider", _disc(18, Palette.UI_FAINT, Palette.UI_INK))

	# The summer's bar, and any other.
	t.set_stylebox("background", "ProgressBar", box(Palette.UI_WELL, Palette.UI_RULE_DIM, 1, 3, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.UI_GOLD_DEEP, Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_font_size("font_size", "ProgressBar", fs(KEY))

	# A tick box (let the saga tell it).
	var cb := _empty(S1, S2)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(s, "CheckBox", cb)
	t.set_icon("unchecked", "CheckBox", _tick(26, false))
	t.set_icon("checked", "CheckBox", _tick(26, true))
	t.set_icon("unchecked_disabled", "CheckBox", _tick(26, false))
	t.set_icon("checked_disabled", "CheckBox", _tick(26, true))
	t.set_color("font_color", "CheckBox", Palette.UI_TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", Palette.UI_GOLD)
	t.set_color("font_hover_pressed_color", "CheckBox", Palette.UI_GOLD)
	t.set_color("font_focus_color", "CheckBox", Palette.UI_TEXT)
	t.set_font_size("font_size", "CheckBox", fs(17))
	t.set_constant("h_separation", "CheckBox", S3)

	# Rules between sections.
	var line := StyleBoxLine.new()
	line.color = Color(Palette.UI_RULE, 0.55)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", S2)
	var vline := StyleBoxLine.new()
	vline.color = Color(Palette.UI_RULE, 0.4)
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	t.set_constant("separation", "VSeparator", S3)

	# Tooltips (desktop) and the drill yard's pickers.
	t.set_stylebox("panel", "TooltipPanel", box(Palette.UI_WELL, Palette.UI_RULE, 1, RADIUS, S2, S1))
	t.set_color("font_color", "TooltipLabel", Palette.UI_TEXT)
	t.set_font_size("font_size", "TooltipLabel", fs(SMALL))
	t.set_stylebox("panel", "PopupMenu", box(Palette.UI_WELL, Palette.UI_RULE, 1, RADIUS, S1, S1))
	t.set_stylebox("hover", "PopupMenu", box(Palette.UI_WOOD_HOVER, Color(0, 0, 0, 0), 0, RADIUS, S2, S1))
	t.set_color("font_color", "PopupMenu", Palette.UI_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Palette.UI_GOLD)
	t.set_font_size("font_size", "PopupMenu", fs(BODY))
	_button_set(t, "OptionButton", sec, sec_h, sec_p, sec_d, focus, Palette.UI_TEXT, Color.WHITE, Palette.UI_GOLD, Palette.UI_FAINT, fs(BODY), font("bold"))

	# Containers keep to the grid.
	t.set_constant("separation", "VBoxContainer", S2)
	t.set_constant("separation", "HBoxContainer", S2)
	t.set_constant("h_separation", "HFlowContainer", S2)
	t.set_constant("v_separation", "HFlowContainer", S2)
	t.set_constant("h_separation", "GridContainer", S3)
	t.set_constant("v_separation", "GridContainer", S1)


static func _variation(t: Theme, name: String, base: String) -> void:
	t.set_type_variation(name, base)


static func _label_type(t: Theme, name: String, size: int, color: Color, f: Font) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	t.set_font("font", name, f)


static func _panel_type(t: Theme, name: String, sb: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, sb)


## A modal's frame: dark wood, a double rule (the outer gold, an inner
## shadow line), a drop shadow off the dimmed screen.
static func _frame() -> StyleBoxFlat:
	var sb := box(Palette.UI_WOOD, Palette.UI_RULE, 1, RADIUS + 1, S5, S4)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	return sb


## The map's side panel: wood to the screen's edge, a gold rule on its
## left only.
static func _side() -> StyleBoxFlat:
	var sb := box(Palette.UI_WOOD, Palette.UI_RULE, 0, 0, S4, S3)
	sb.border_width_left = 2
	sb.content_margin_right = S4 + 4  # clear of a phone's rounded corner
	return sb


## A round grip for the slider, drawn into a texture once.
static func _disc(d: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) / 2.0
	var r := d / 2.0 - 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - dist + 0.5, 0.0, 1.0)
			var col := fill if dist < r - 2.0 else ring
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


## A tick box, empty or marked, drawn into a texture once.
static func _tick(d: int, on: bool) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(1, 1, d - 2, d - 2), Palette.UI_RULE)
	img.fill_rect(Rect2i(3, 3, d - 6, d - 6), Palette.UI_WELL)
	if on:
		img.fill_rect(Rect2i(7, 7, d - 14, d - 14), Palette.UI_GOLD)
	return ImageTexture.create_from_image(img)


# --- Helpers: the recurring pieces --------------------------------------------

## A label. `variant` is one of the label variations: DisplayLabel,
## TitleLabel, HeadingLabel, BodyLabel (the default), StrongLabel,
## SmallLabel, KeyLabel, ValueLabel, SagaLabel, InkLabel, InkSmallLabel,
## InkHeadingLabel, DangerLabel. Wraps at word boundaries unless `wrap` is
## false.
static func label(text: String, variant := "", wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if variant != "":
		l.theme_type_variation = variant
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A button. `variant`: "" (the secondary), PrimaryButton, QuietButton,
## RowButton, CommandButton, ToolButton, CardButton. Its height is at least
## ROW (TOUCH for the primary) unless `min_size` says otherwise.
static func button(text: String, on := Callable(), variant := "", min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	if variant != "":
		b.theme_type_variation = variant
	var h := TOUCH if variant == "PrimaryButton" else ROW
	b.custom_minimum_size = Vector2(min_size.x, min_size.y if min_size.y > 0 else h)
	if on.is_valid():
		b.pressed.connect(on)
	return b


## The one main thing to do on a screen.
static func primary(text: String, on := Callable(), width := 0.0) -> Button:
	return button(text, on, "PrimaryButton", Vector2(width, TOUCH))


## Another thing to do, as weighty as any but the primary.
static func secondary(text: String, on := Callable(), width := 0.0) -> Button:
	return button(text, on, "", Vector2(width, ROW))


## Back, Close: present but not asking to be pressed.
static func quiet(text: String, on := Callable(), width := 0.0) -> Button:
	return button(text, on, "QuietButton", Vector2(width, ROW))


## A section's header: its name in gold and a rule running to the right.
static func section(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", S2)
	var l := label(text, "HeadingLabel", false)
	row.add_child(l)
	var r := UiOrnament.new()
	r.kind = UiOrnament.Kind.RULE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(16, 10)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(r)
	return row


## A gold rule with a small knot at its middle, as wide as its parent.
static func rule(knot := true) -> UiOrnament:
	var r := UiOrnament.new()
	r.kind = UiOrnament.Kind.KNOT_RULE if knot else UiOrnament.Kind.RULE
	r.custom_minimum_size = Vector2(0, 12 if knot else 6)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


## A stat in the strip: a small spaced key over its value. The value label
## is the box's `value` meta (set_stat changes it).
static func stat(key: String, value: String, color := Palette.UI_TEXT) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(label(key.to_upper(), "KeyLabel", false))
	var val := label(value, "ValueLabel", false)
	val.add_theme_color_override("font_color", color)
	val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(val)
	v.set_meta("value", val)
	return v


static func set_stat(stat_box: Control, value: String, color := Palette.UI_TEXT) -> void:
	var val: Label = stat_box.get_meta("value")
	val.text = value
	val.add_theme_color_override("font_color", color)


## A key on the left and its value on the right, on one line.
static func kv_row(key: String, value: String, value_color := Palette.UI_TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	var k := label(key, "SmallLabel", false)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := label(value, "StrongLabel", false)
	v.add_theme_color_override("font_color", value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row


## A small rounded tag in `color` (a rank, a standing, "Outlaw").
static func chip(text: String, color := Palette.UI_GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(color, 0.16), Color(color, 0.6), 1, 9, S2, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, "KeyLabel", false)
	l.add_theme_color_override("font_color", color.lightened(0.25))
	l.add_theme_font_size_override("font_size", fs(14))
	p.add_child(l)
	return p


## A row in a list that is pressed as a whole: its `title` and, under it,
## its `hint` (or, when it cannot be done, `reason` if given). The labels
## are the button's children, so they wrap; the row grows to hold them.
static func list_row(title: String, hint := "", on := Callable(), enabled := true, reason := "") -> Button:
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, ROW)
	b.clip_contents = true
	if on.is_valid():
		b.pressed.connect(on)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", S3 + 2)
	m.add_theme_constant_override("margin_right", S3)
	m.add_theme_constant_override("margin_top", S2 - 1)
	m.add_theme_constant_override("margin_bottom", S2 - 1)
	b.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(col)
	var t := label(title, "StrongLabel")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enabled:
		t.add_theme_color_override("font_color", Palette.UI_FAINT)
	col.add_child(t)
	var said := reason if (not enabled and reason != "") else hint
	if said != "":
		var h := label(said, "SmallLabel")
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not enabled:
			h.add_theme_color_override("font_color", Palette.UI_FAINT.lightened(0.1))
		col.add_child(h)
	# The button's own size follows its children's.
	m.minimum_size_changed.connect(func() -> void:
		b.custom_minimum_size.y = maxf(float(b.get_meta("min_h", ROW)), m.get_combined_minimum_size().y))
	b.set_meta("title", t)
	return b


## A panel of `variant` (a PanelContainer variation: FramePanel, SidePanel,
## CardPanel, WellPanel, ParchmentPanel, StripPanel, ChipPanel; "" is plain
## wood).
static func panel(variant := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variant != "":
		p.theme_type_variation = variant
	return p


## A panel with a title over a rule and a body under it. The body (a
## VBoxContainer) is the panel's `body` meta.
static func titled_panel(title: String, variant := "CardPanel") -> PanelContainer:
	var p := panel(variant)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", S2)
	p.add_child(col)
	col.add_child(label(title, "HeadingLabel"))
	col.add_child(rule(false))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", S2)
	col.add_child(body)
	p.set_meta("body", body)
	return p


## A modal over `host` (a full-screen Control): the screen dimmed, a framed
## panel in the middle with `title`, a body that scrolls when it is long,
## and buttons pinned at the bottom. It is no taller than the screen. See
## UiModal for its parts (`body`, `footer`, `add_button`, `close`).
static func modal(host: Control, title := "", max_width := 760.0) -> UiModal:
	var m := UiModal.new()
	m.max_width = max_width
	host.add_child(m)
	m.open(title)
	return m


## Lists a thumb can drag. Called for every node as it enters the tree
## (view/audio.gd, the one autoload that sees them all): a button or a
## panel inside a scroll passes the touch on to it, so a drag that begins
## on a row scrolls the list (the engine drops the row's press when the
## scroll begins), and the scroll forgives a thumb's tremble before it
## takes a tap for a drag. Without this a list made of rows cannot be
## dragged at all on a phone: a button keeps the touch to itself.
const SCROLL_DEADZONE := 10
static func touch_scroll(n: Node) -> void:
	if n is ScrollContainer:
		(n as ScrollContainer).scroll_deadzone = SCROLL_DEADZONE
		# What the rows pass on ends here, not at whatever lies behind the list.
		(n as ScrollContainer).mouse_filter = Control.MOUSE_FILTER_STOP
		return
	if not (n is BaseButton or n is PanelContainer):
		return
	var c := n as Control
	if c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		p = p.get_parent()


## A scroll that only scrolls up and down, round `child`.
static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


## An empty gap of `h` pixels in a column (or `w` in a row).
static func gap(h := S3, w := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fades `c` in over `seconds`: a screen arriving.
static func fade_in(c: CanvasItem, seconds := 0.22) -> void:
	if not motion or reduce_motion or seconds <= 0.0 or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The colour of a house's standing toward the band, from blood-enemy red
## through the stranger's bone to the sworn friend's gold-green; `standing`
## is Families.standing (about -100 to 100).
static func standing_color(standing: int) -> Color:
	var t := clampf(standing / 100.0, -1.0, 1.0)
	if colour_safe:
		# Dark red to light blue: they differ in lightness as well as hue.
		if t < 0.0:
			return Palette.UI_MUTED.lerp(Palette.UI_BLOOD.darkened(0.1), -t)
		return Palette.UI_MUTED.lerp(Palette.UI_SAFE_FRIEND, minf(1.0, t * 1.4))
	if t < 0.0:
		return Palette.UI_MUTED.lerp(Palette.UI_BLOOD.lightened(0.15), -t)
	return Palette.UI_MUTED.lerp(Palette.UI_FRIEND, minf(1.0, t * 1.4))


## The short commit the web build was made from (scripts/export-web.sh
## writes it); "dev" when running from the editor or a tool.
static func build_stamp() -> String:
	if FileAccess.file_exists("res://build.txt"):
		var f := FileAccess.open("res://build.txt", FileAccess.READ)
		if f != null:
			var text := f.get_as_text().strip_edges()
			if text != "":
				return text
	return "dev"
