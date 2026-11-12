class_name Hints
extends RefCounted
## The first days on the map, guided with a light hand (docs/design/notes/
## tutorial.md): a queue of short hints, each shown once a saga when the
## journey comes to it, one at a time, in a small card over the map's top
## corner that never covers the side panel and goes away on "Go on". A
## hint waits while a choice or a side panel is open. The "?" button lists
## what has been learned so far.
##
## One Hints lives with the saga (view/game.gd keeps it), so a hint seen
## before a fight is not shown again after it; `attach` puts its card and
## its button on each new MapScreen. The order and the conditions are
## `ORDER` and `due`, and read only the Journey, so the tests can walk
## them (tests/test_escape.gd).

const ORDER := ["where", "walk", "actions", "rest", "ways", "ship", "parties", "winter"]
## Days of summer left when the winter hint comes.
const WINTER_DAYS := 60

var journey: Journey
## Hint id -> true once the player has dismissed it.
var seen := {}
## The hint on the card now, or "".
var showing := ""

var _map: Control = null
var _card: PanelContainer
var _card_text: Label
var _list: UiModal
var _timer: Timer


func _init(p_journey: Journey = null) -> void:
	journey = p_journey


## The words of a hint, one sentence, in the saga's voice.
func text(id: String) -> String:
	var j := journey
	var band := j.c.band
	var wr := j.c.world_rules
	match id:
		"where":
			var at := j.here().display_name if j.here() != null else "the wilds"
			match band.origin:
				"burned_hall":
					return "You are at %s, where your father's kin have taken you in: here your saga begins." % at
				"younger_son":
					return "You are at %s, by your brother's door: here your saga begins." % at
				"freedman":
					return "You are at %s, where you were a thrall until Yule: here your saga begins, free." % at
			return "You are at %s: here your saga begins." % at
		"walk":
			return "Tap the map to walk there: the days pass as you go, and stop when you stop."
		"actions":
			return "What a place offers is on the right: each deed there costs days, and some cost silver."
		"rest":
			return "Your men are hurt: Rest and mend, under a roof, lets the wounds heal before the next fight."
		"ways":
			return "You have a point to spend: Your ways shows the paths a man may take, raider, trader, law-wise man and more, and any one or any mixture of them is open to you."
		"ship":
			return "You have no ship: a faering costs %d oz at a hall or a town, and until then you can buy passage on another man's." % int(wr.ship_price[WorldTypes.ShipKind.FAERING])
		"parties":
			return "Others are abroad on the map, merchants, raiders and outlaws, and when they come at you, you may fade away rather than fight."
		"winter":
			return "The summer is short: when its days run out the band must winter under a roof, and a guest pays %d oz a man." % wr.guest_winter_per_man
	return ""


## Whether the journey has come to hint `id`.
func due(id: String) -> bool:
	var j := journey
	var band := j.c.band
	match id:
		"where":
			return true
		"walk":
			return seen.has("where")
		"actions":
			return j.here() != null and j.can_act() and not j.actions().is_empty()
		"rest":
			if j.here() == null or not j.can_act():
				return false
			for a in j.actions():
				if str(a.id) == "rest":
					return true
			return false
		"ways":
			return Way.points_free(band) > 0
		"ship":
			return band.ship == null and seen.has("walk")
		"parties":
			var sight: float = j.c.world_rules.sight_leagues
			for p in j.roam.parties:
				if p.pos.distance_to(j.roam.pos) <= sight:
					return true
			return j.current().get("kind", "") == "fight"
		"winter":
			return j.days_left() <= WINTER_DAYS
	return false


## The next hint to show, or "": the first in `ORDER` not yet seen whose
## time has come.
func next_hint() -> String:
	if journey == null or journey.c.over:
		return ""
	for id in ORDER:
		if not seen.has(id) and due(id):
			return id
	return ""


## The player has read the hint on the card.
func dismiss() -> void:
	if showing != "":
		seen[showing] = true
	showing = ""


## What has been learned, in the order it was taught.
func learned() -> PackedStringArray:
	var out := PackedStringArray()
	for id in ORDER:
		if seen.has(id):
			out.append(text(id))
	return out


# --- On the map ----------------------------------------------------------------

## Puts the card, the "?" button and a slow look at the journey on `map`
## (a MapScreen). The nodes go with the map; what was seen stays here. The
## card is a slip of parchment under the map's time controls, the "?" the
## last of those controls.
func attach(map: Control) -> void:
	_map = map
	showing = ""
	var panel_w := MapScreen.PANEL_W
	var ask := UiTheme.button("?", _show_list, "ToolButton", Vector2(UiTheme.TOUCH, UiTheme.TOUCH))
	ask.tooltip_text = "What you have learned"
	ask.add_theme_font_size_override("font_size", UiTheme.fs(24))
	var bar = map.get("time_bar")
	if bar != null:
		(bar as Control).add_child(UiTheme.gap(0, 6))
		(bar as Control).add_child(ask)
	else:
		ask.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		ask.offset_left = -panel_w - UiTheme.TOUCH - UiTheme.S2
		ask.offset_right = -panel_w - UiTheme.S2
		ask.offset_top = UiTheme.S2
		ask.offset_bottom = UiTheme.S2 + UiTheme.TOUCH
		map.add_child(ask)
	_card = UiTheme.panel("ParchmentPanel")
	_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card.offset_left = UiTheme.EDGE
	_card.offset_top = UiTheme.S2 + UiTheme.TOUCH + UiTheme.S2  # under the map's controls
	_card.custom_minimum_size = Vector2(minf(540.0, 1169.0 - panel_w - 40.0), 0)
	_card.visible = false
	map.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S3)
	_card.add_child(row)
	_card_text = UiTheme.label("", "InkLabel")
	_card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_text.custom_minimum_size = Vector2(300, 0)
	row.add_child(_card_text)
	var ok := UiTheme.button("Go on", func() -> void:
		dismiss()
		check(), "PrimaryButton", Vector2(110, UiTheme.ROW))
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ok)
	_list = UiModal.new()
	_list.max_width = 720.0
	map.add_child(_list)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.timeout.connect(check)
	map.add_child(_timer)
	check()


## Shows the next hint whose time has come, unless something the player
## must read or answer is open; hides the card while it is.
func check() -> void:
	if _map == null or not is_instance_valid(_map) or _card == null:
		return
	var busy := _list.visible
	for name in ["modal", "side_panel"]:
		var p = _map.get(name)
		if p != null and (p as Control).visible:
			busy = true
	if busy:
		_card.visible = false
		return
	if showing == "":
		showing = next_hint()
	if showing == "":
		_card.visible = false
		return
	_card_text.text = text(showing)
	_card.visible = true
	_card.size = Vector2(_card.size.x, 0.0)  # as tall as the words now


func _show_list() -> void:
	_card.visible = false
	_list.open("What you have learned")
	var lines := learned()
	if lines.is_empty():
		_list.body.add_child(UiTheme.label("Nothing yet: the hints come as you go.", "SmallLabel"))
	for line in lines:
		var p := UiTheme.panel("CardPanel")
		p.add_child(UiTheme.label(line))
		_list.body.add_child(p)
	_list.add_button("Back to the map", func() -> void:
		_list.close()
		check(), "PrimaryButton", 220.0)
