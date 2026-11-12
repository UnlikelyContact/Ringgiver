class_name SagaScreen
extends RefCounted
## The saga as a thing to read and to share (docs/design/notes/generations.md):
## told generation by generation on parchment, a chapter for each leader,
## with "Copy the saga" so a player can pass it on; and the closing card
## when the saga ends, with its reckoning in words. Built in a UiModal with
## the shared look (UiTheme, docs/design/notes/ui.md): the map's side
## panel, the map's modal at an ending, or a modal of its own over the
## title. The words come from Chronicle.saga (Journey.saga) as plain values.


## Fills `m` with the saga `saga` ({title, chapters, closing, text}) and
## opens it. `buttons` are [label, Callable, variant] after "Copy the saga".
static func fill(m: UiModal, saga: Dictionary, buttons: Array = []) -> void:
	m.open(str(saga.get("title", "The saga")))
	var tale := UiTheme.panel("ParchmentPanel")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.S3)
	tale.add_child(col)
	m.body.add_child(tale)
	for ch in saga.get("chapters", []):
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", UiTheme.S3)
		var h := UiTheme.label(str(ch.heading), "InkHeadingLabel")
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(h)
		var yrs := UiTheme.label(str(ch.years), "InkSmallLabel", false)
		yrs.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(yrs)
		col.add_child(head)
		for p in ch.paragraphs:
			col.add_child(UiTheme.label(str(p), "InkLabel"))
	var closing: PackedStringArray = saga.get("closing", PackedStringArray())
	if not closing.is_empty():
		col.add_child(UiTheme.label("Here the saga ends.", "InkHeadingLabel"))
		col.add_child(UiTheme.label(" ".join(closing), "InkLabel"))
	var note := UiTheme.label("", "SmallLabel")
	note.visible = false
	m.body.add_child(note)
	var text := str(saga.get("text", ""))
	m.add_button("Copy the saga", func() -> void: copy(m, text, note), "", 180.0)
	for b in buttons:
		m.add_button(str(b[0]), b[1], str(b[2]) if b.size() > 2 else "", 180.0)


## Puts the saga on the clipboard; where the clipboard cannot be reached
## (a browser that will not allow it), the words are shown to be selected
## and copied by hand.
static func copy(m: UiModal, text: String, note: Label) -> void:
	var can := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	if can:
		DisplayServer.clipboard_set(text)
	note.visible = true
	if can and not OS.has_feature("web"):
		note.text = "The saga is copied: paste it wherever you will tell it."
		return
	note.text = "The saga is below: select it and copy it." if not can else "The saga is copied. If it was not, select it below and copy it."
	if m.body.has_node("SagaText"):
		return
	var box := TextEdit.new()
	box.name = "SagaText"
	box.text = text
	box.editable = false
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.custom_minimum_size = Vector2(0, 220)
	m.body.add_child(box)
	box.select_all()
	m.scroll.set_deferred("scroll_vertical", 1 << 20)


## The closing card of an ended saga: how it ended, the reckoning in words,
## the verdict; "Read the saga" and the other `buttons` ([label, Callable,
## variant]) under it.
static func ending(m: UiModal, j: Journey, buttons: Array) -> void:
	var c := j.c
	var r := Chronicle.reckoning(c.band, c.rules)
	m.open("The saga of %s is ended" % Way.title(c.band))
	var first := UiTheme.label(str(r.ending), "SagaLabel")
	first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.body.add_child(first)
	var tale := UiTheme.panel("ParchmentPanel")
	tale.add_child(UiTheme.label(" ".join(r.lines), "InkLabel"))
	m.body.add_child(tale)
	var verdict := UiTheme.label(str(r.verdict), "HeadingLabel")
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.add_theme_color_override("font_color", Palette.UI_GOLD)
	m.body.add_child(verdict)
	for b in buttons:
		m.add_button(str(b[0]), b[1], str(b[2]) if b.size() > 2 else "", 200.0)


## The years let pass, told (Journey.years_told): the line the saga gives
## them, what the chronicle kept of each, the houses' tidings, why they
## stopped.
static func years(m: UiModal, j: Journey, on_go: Callable) -> void:
	var t := j.years_told
	var passed := int(t.get("passed", 0))
	var who := j.c.band.leader.display_name if j.c.band.leader != null else "him"
	m.open("The years pass" if passed != 1 else "A year passes")
	var head := ""
	if passed == 0:
		head = "The years would not wait: something needed %s at once." % who
	else:
		head = "Then nothing is told of %s for %s." % [who, "a winter" if passed == 1 else "%s winters" % Chronicle._number(passed)]
	m.body.add_child(UiTheme.label(head, "SagaLabel"))
	var lines := PackedStringArray()
	for l in t.get("lines", PackedStringArray()):
		var at := str(l).find(": ")
		lines.append("%s  %s" % [str(l).left(at), Chronicle._sentence(str(l).substr(at + 2))] if at > 0 else str(l))
	if not lines.is_empty():
		var tale := UiTheme.panel("ParchmentPanel")
		tale.add_child(UiTheme.label("\n".join(lines), "InkLabel"))
		m.body.add_child(tale)
	var tidings: PackedStringArray = t.get("tidings", PackedStringArray())
	if not tidings.is_empty():
		m.body.add_child(UiTheme.section("Tidings of the houses"))
		m.body.add_child(UiTheme.label("\n".join(tidings), "SmallLabel"))
	if str(t.get("why", "")) != "":
		var why := UiTheme.label("%s It is the spring of %d." % [str(t.why), j.c.cal.year], "StrongLabel")
		m.body.add_child(why)
	m.add_button("Go on", on_go, "PrimaryButton", 200.0)
