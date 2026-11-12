class_name SavesModal
extends RefCounted
## "Sagas": the sagas kept (docs/design/notes/save.md). The autosave and
## the one before it, and three slots the player keeps: each with the line
## that says where its saga stands and when it was saved, and Load, Save
## here (with a saga in hand), Copy and Delete (asked first). Under them,
## "Paste a save" takes a saga copied on another device. Reached from the
## title and from the settings on the map. `game` is view/game.gd.
##
##   SavesModal.open(host, game)   # over any full-screen Control

const NAMES := {"auto": "The autosave", "auto_prev": "The save before it", "slot1": "Slot one", "slot2": "Slot two", "slot3": "Slot three"}


static func open(host: Control, game: Node) -> UiModal:
	var m := UiModal.new()
	m.name = "Sagas"
	m.max_width = 900.0
	host.add_child(m)
	list(m, game)
	m.closed.connect(func() -> void: m.queue_free())
	return m


## The list of saves.
static func list(m: UiModal, game: Node, note := "") -> void:
	m.open("Sagas")
	var in_hand: bool = game != null and game.get("journey") != null and game.get("battle_node") == null
	if note != "":
		m.body.add_child(UiTheme.label(note, "StrongLabel"))
	if not SaveStore.persistent():
		var warn := UiTheme.label("This browser does not keep what is saved between visits (a private window?): copy a saga to keep it.", "SmallLabel")
		warn.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.2))
		m.body.add_child(warn)
	for slot in [SaveStore.AUTO, SaveStore.BACKUP] + SaveStore.SLOTS:
		var h := SaveStore.head(slot)
		if slot == SaveStore.BACKUP and h.is_empty():
			continue
		m.body.add_child(_row(m, game, slot, h, in_hand))
	m.add_button("Paste a save", func() -> void: _paste(m, game), "", 180.0)
	m.add_button("Done", m.close, "PrimaryButton", 160.0)


static func _row(m: UiModal, game: Node, slot: String, h: Dictionary, in_hand: bool) -> Control:
	var p := UiTheme.panel("CardPanel")
	p.name = "Row_" + slot
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S2)
	p.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiTheme.label(str(NAMES.get(slot, slot)), "StrongLabel", false))
	var line := "Empty."
	if h.has("error"):
		line = "Cannot be read: %s." % h.error
	elif not h.is_empty():
		line = "%s. %s." % [SaveStore.summary_line(h.get("summary", {})), _when(int(h.get("saved_at", 0)))]
	var l := UiTheme.label(line, "SmallLabel")
	if h.has("error"):
		l.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.2))
	col.add_child(l)
	var ok := not h.is_empty() and not h.has("error")
	if ok:
		row.add_child(_small("Load", func() -> void:
			var err: String = game.load_saga(slot)
			if err != "":
				list(m, game, "That saga could not be loaded: %s." % err)
			else:
				m.close()))
	if in_hand and SaveStore.SLOTS.has(slot):
		row.add_child(_small("Save here", func() -> void:
			var err: String = game.save_now(slot)
			list(m, game, "Saved in %s." % str(NAMES[slot]).to_lower() if err == "" else "It could not be saved: %s." % err)))
	if not h.is_empty():
		if ok:
			row.add_child(_small("Copy", func() -> void: _copy(m, game, slot)))
		row.add_child(_small("Delete", func() -> void: _confirm_delete(m, game, slot, line)))
	return p


static func _small(text: String, on: Callable) -> Button:
	var b := UiTheme.button(text, on, "", Vector2(0, UiTheme.ROW))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.name = text.replace(" ", "")
	return b


## "Saved 12 Nov, 14:05", in the player's own time.
static func _when(unix: int) -> String:
	if unix <= 0:
		return "Saved at an unknown time"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "Saved %d %s, %02d:%02d" % [int(d.day), months[clampi(int(d.month) - 1, 0, 11)], int(d.hour), int(d.minute)]


static func _confirm_delete(m: UiModal, game: Node, slot: String, line: String) -> void:
	m.open("Delete this save?")
	m.body.add_child(UiTheme.label("%s: %s" % [NAMES.get(slot, slot), line], "SagaLabel"))
	m.body.add_child(UiTheme.label("It cannot be got back.", "SmallLabel"))
	var del := m.add_button("Delete it", func() -> void:
		SaveStore.remove(slot)
		list(m, game, "Deleted."), "PrimaryButton", 180.0)
	del.name = "DeleteIt"
	m.add_button("Keep it", func() -> void: list(m, game), "", 150.0)


## The save as text on the clipboard; where the browser will not allow
## it, the text is shown to be selected and copied by hand.
static func _copy(m: UiModal, game: Node, slot: String) -> void:
	var text := SaveStore.export_text(slot)
	m.open("Copy the save")
	var can := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	if can:
		DisplayServer.clipboard_set(text)
	var note := "The saga is copied (%d letters). On the other device, open Sagas and Paste a save." % text.length()
	if not can:
		note = "Select the text below and copy it. On the other device, open Sagas and Paste a save."
	elif OS.has_feature("web"):
		note = "The saga is copied. If it was not, select the text below and copy it. On the other device, open Sagas and Paste a save."
	m.body.add_child(UiTheme.label(note))
	if not can or OS.has_feature("web"):
		var box := TextEdit.new()
		box.name = "SaveText"
		box.text = text
		box.editable = false
		box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		box.custom_minimum_size = Vector2(0, 120)
		m.body.add_child(box)
		box.select_all()
	m.add_button("Back", func() -> void: list(m, game), "PrimaryButton", 150.0)


## A saga copied on another device: pasted in, checked, put in a slot.
static func _paste(m: UiModal, game: Node, error := "") -> void:
	m.open("Paste a save")
	m.body.add_child(UiTheme.label("Paste the text copied from Sagas on the other device, then choose the slot to keep it in.", "SmallLabel"))
	var box := TextEdit.new()
	box.name = "PasteText"
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.custom_minimum_size = Vector2(0, 110)
	box.placeholder_text = SaveStore.TEXT_PREFIX + "..."
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) and not OS.has_feature("web"):
		var clip := DisplayServer.clipboard_get()
		if clip.strip_edges().begins_with(SaveStore.TEXT_PREFIX):
			box.text = clip
	m.body.add_child(box)
	var said := UiTheme.label(error, "SmallLabel")
	said.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.2))
	m.body.add_child(said)
	for slot in SaveStore.SLOTS:
		var full := SaveStore.exists(slot)
		m.add_button("Into %s%s" % [str(NAMES[slot]).to_lower(), " (over it)" if full else ""], func() -> void:
			var r := SaveStore.parse_text(box.text)
			if r.has("error"):
				said.text = "That will not do: %s." % r.error
				return
			var err := SaveStore.write_bytes(slot, r.bytes)
			list(m, game, ("Kept in %s: %s." % [str(NAMES[slot]).to_lower(), SaveStore.summary_line((r.head as Dictionary).get("summary", {}))]) if err == "" else "It could not be kept: %s." % err), "", 0.0)
	m.add_button("Back", func() -> void: list(m, game), "PrimaryButton", 150.0)
