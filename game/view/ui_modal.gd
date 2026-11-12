class_name UiModal
extends Container
## One frame for everything that must be read or answered over a screen
## (docs/design/notes/ui.md): the screen dimmed behind, a framed panel in
## the middle with a title, a body that scrolls when it is long, and the
## buttons pinned at the bottom. The panel is as tall as its words and
## never taller than the screen (less EDGE all round).
##
##   var m := UiTheme.modal(self, "Word comes")        # added and opened
##   m.body.add_child(UiTheme.label(text))
##   m.add_button("Serve him", func() -> void: ...)
##   m.add_button("Go on", m.close, "PrimaryButton")
##
## Or keep one and fill it again: `open(title)` clears the body and the
## footer and shows it; `close()` hides it (and says `closed`).

signal closed

## The widest the panel grows, in design pixels.
var max_width := 760.0
## Kept clear between the panel and the screen's edges.
var margin := Vector2(UiTheme.EDGE + 6, UiTheme.EDGE)
## How dark the screen behind goes.
var dim := 0.6

var frame: PanelContainer
var title_label: Label
var title_rule: UiOrnament
var scroll: ScrollContainer
var body: VBoxContainer
var footer: HFlowContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the screen behind cannot be touched
	visible = false
	frame = PanelContainer.new()
	frame.theme_type_variation = "FramePanel"
	add_child(frame)
	frame.draw.connect(_draw_corners)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.S2)
	frame.add_child(col)
	title_label = UiTheme.label("", "TitleLabel")
	col.add_child(title_label)
	title_rule = UiTheme.rule(true)
	col.add_child(title_rule)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", UiTheme.S3)
	scroll = UiTheme.scroll(body)
	col.add_child(scroll)
	footer = HFlowContainer.new()
	footer.alignment = FlowContainer.ALIGNMENT_END
	footer.add_theme_constant_override("h_separation", UiTheme.S3)
	footer.add_theme_constant_override("v_separation", UiTheme.S2)
	col.add_child(footer)
	body.minimum_size_changed.connect(queue_sort)
	footer.minimum_size_changed.connect(queue_sort)


## Clears the body and the footer, sets the title and shows the modal.
func open(title := "") -> UiModal:
	clear()
	title_label.text = title
	title_label.visible = title != ""
	title_rule.visible = title != ""
	var was := visible
	visible = true
	scroll.scroll_vertical = 0
	if not was:
		UiTheme.fade_in(self, 0.14)
	return self


func clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	for c in footer.get_children():
		footer.remove_child(c)
		c.queue_free()


func close() -> void:
	visible = false
	closed.emit()


## A button in the footer. `variant` as UiTheme.button; at least 150 wide.
func add_button(text: String, on := Callable(), variant := "", width := 150.0) -> Button:
	var b := UiTheme.button(text, on, variant, Vector2(width, UiTheme.TOUCH if variant == "PrimaryButton" else UiTheme.ROW))
	footer.add_child(b)
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_fit()


func _fit() -> void:
	if frame == null:
		return
	var avail := size - margin * 2.0
	var w := minf(max_width, avail.x)
	# As tall as the words (the frame without its scroll, plus what the
	# scroll holds), no taller than the screen.
	var need := frame.get_combined_minimum_size().y + body.get_combined_minimum_size().y
	var h := clampf(need, 0.0, avail.y)
	fit_child_in_rect(frame, Rect2(((size - Vector2(w, h)) / 2.0).floor(), Vector2(w, h)))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.UI_NIGHT, dim))


## Gold brackets at the frame's corners: the carved look, drawn once a
## resize.
func _draw_corners() -> void:
	UiOrnament.corners(frame, Rect2(Vector2.ZERO, frame.size), Palette.UI_GOLD, 14.0)
