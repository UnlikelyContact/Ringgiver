class_name EstatePanel
extends RefCounted
## The smith and the works (docs/design/notes/men-silver.md), in the map's
## side panel like "Your men": what the smith has this year and for whom
## (a man of the band, the leader himself, or the chest), and what silver
## may be laid out where the band stands (the hall's buildings and its
## adornment, a skald, feasts, stones and mounds for the dead, the ship's
## fittings). It reads Journey.smith() / works() and calls buy_arms /
## do_work; the sim does the rest.

var map: Node
var journey: Journey


func _init(p_map: Node) -> void:
	map = p_map
	journey = map.journey


## Whether a place's deed `id` opens one of these screens.
static func opens(id: String) -> bool:
	return id == "smith" or id == "works"


func open(id: String) -> void:
	if id == "smith":
		show_smith()
	else:
		show_works()


func _done() -> void:
	Audio.play("coin")
	map.refresh()


# --- The smith ---------------------------------------------------------------------

func show_smith() -> void:
	var s := journey.smith()
	if s.is_empty():
		return
	var box: VBoxContainer = map._open_side("The smith at %s" % str(s.name))
	box.add_child(UiTheme.label(str(s.words), "SmallLabel"))
	box.add_child(_chest_line(s))
	if not (s.named as Dictionary).is_empty():
		var nd: Dictionary = s.named
		var card := UiTheme.titled_panel("A sword with a name")
		box.add_child(card)
		var body: VBoxContainer = card.get_meta("body")
		body.add_child(UiTheme.label("The smith has a sword called %s, pattern-welded, with a hilt of silver. Men remember such a sword and the man who bore it." % nd.name))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTheme.S2)
		body.add_child(row)
		var price := UiTheme.label("%d oz" % int(nd.price), "ValueLabel", false)
		price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(price)
		var b := _btn("Buy it for...", func() -> void: _pick("named", str(nd.name), s), int(s.silver) >= int(nd.price))
		row.add_child(b)
	box.add_child(UiTheme.section("This year's work"))
	for r in s.rows:
		box.add_child(_item_row(r, s))
	map._close_side(box)


func _chest_line(s: Dictionary) -> Label:
	var have := PackedStringArray()
	var chest: Dictionary = s.chest
	var items: Array = chest.keys()
	items.sort()
	for item in items:
		if int(chest[item]) > 0:
			have.append("%d %s" % [int(chest[item]), str(item) if int(chest[item]) == 1 else (str(item) + ("" if str(item).ends_with("s") else "s"))])
	var l := UiTheme.label("Your chest holds %d oz of silver%s." % [int(s.silver), (", and in it: " + ", ".join(have)) if not have.is_empty() else ""], "StrongLabel")
	return l


func _item_row(r: Dictionary, s: Dictionary) -> Control:
	var card := UiTheme.panel("CardPanel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S2)
	card.add_child(row)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	who.add_child(UiTheme.label(str(r.label), "StrongLabel", false))
	var left := int(r.left)
	var l := UiTheme.label("%d oz. %s" % [int(r.price), ("%d to be had" % left) if left > 0 else "None left this year"], "SmallLabel", false)
	if left <= 0:
		l.add_theme_color_override("font_color", Palette.UI_FAINT)
	who.add_child(l)
	var can := left > 0 and int(s.silver) >= int(r.price)
	var item := str(r.item)
	row.add_child(_btn("For the chest", func() -> void:
		if journey.buy_arms(item, -1):
			_done()
			show_smith(), can))
	row.add_child(_btn("For a man...", func() -> void: _pick(item, str(r.label), s), can))
	return card


## Who to buy `item` for: everyone in the band who lacks it, the leader first.
func _pick(item: String, label: String, s: Dictionary) -> void:
	var box: VBoxContainer = map._open_side("Who shall have it?")
	box.add_child(UiTheme.label("%s, for one of your band. Given to a man, it binds him to you; on yourself, it is your own." % label, "SmallLabel"))
	var any := false
	for p in s.people:
		if item != "named" and not (p.lacks as PackedStringArray).has(item):
			continue
		any = true
		var id := int(p.id)
		var b := UiTheme.list_row(str(p.name) + (" (yourself)" if bool(p.leader) else ""), "Has %s." % str(p.gear), func() -> void:
			if journey.buy_arms(item, id):
				_done()
				show_smith())
		b.set_meta("min_h", UiTheme.TOUCH)
		b.custom_minimum_size.y = UiTheme.TOUCH
		box.add_child(b)
	if not any:
		box.add_child(UiTheme.label("Every one of your band has one already.", "BodyLabel"))
	side().add_button("Back to the smith", show_smith, "", 200.0)
	map._close_side(box)
	side().footer.move_child(side().footer.get_child(side().footer.get_child_count() - 1), 0)


func side() -> UiModal:
	return map.side_panel


func _btn(text: String, on: Callable, enabled := true) -> Button:
	var b := UiTheme.secondary(text, on, 150.0)
	b.custom_minimum_size.y = UiTheme.TOUCH
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not enabled
	return b


# --- The works ---------------------------------------------------------------------

const GROUPS := [["hall", "Your hall"], ["feast", "Feasts"], ["dead", "For the dead"], ["ship", "The ship"]]


func show_works() -> void:
	var w := journey.works()
	var p := journey.here()
	if w.is_empty() or p == null:
		return
	var home := p.id == journey.c.band.hall_at
	var box: VBoxContainer = map._open_side("Your hall at %s" % p.display_name if home else "Silver at %s" % p.display_name)
	var est := journey.c.band.estate
	var now := PackedStringArray()
	if home:
		var hall := journey.c.band.hall as Hall
		if hall != null:
			now.append("%d benches" % hall.seats)
			for b in hall.buildings:
				if b != CampaignTypes.Building.BENCHES and not now.has(CampaignTypes.BUILDING_NAMES[b]):
					now.append(CampaignTypes.BUILDING_NAMES[b])
		if est != null and est.adorn > 0:
			now.append(str(journey.c.rules.hall_adorn[est.adorn - 1].name))
		if est != null and est.skald != "":
			now.append("the skald %s" % est.skald)
	var head := "Your chest holds %d oz." % journey.c.band.silver
	if not now.is_empty():
		head += " The hall has %s." % ", ".join(now)
	box.add_child(UiTheme.label(head, "StrongLabel"))
	for g in GROUPS:
		var rows: Array[Dictionary] = []
		for x in w:
			if str(x.group) == str(g[0]):
				rows.append(x)
		if rows.is_empty():
			continue
		box.add_child(UiTheme.section(str(g[1])))
		for x in rows:
			var id := str(x.id)
			var b := UiTheme.list_row(str(x.label), str(x.hint), func() -> void:
				if journey.do_work(id):
					_done()
					if not journey.works().is_empty():
						show_works()
					else:
						side().close(), bool(x.enabled))
			b.set_meta("min_h", UiTheme.TOUCH)
			b.custom_minimum_size.y = UiTheme.TOUCH
			box.add_child(b)
	map._close_side(box)
