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
	_offer_hint()
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
	lines.append_array(learned_in_battle())
	if lines.is_empty():
		_list.body.add_child(UiTheme.label("Nothing yet: the hints come as you go.", "SmallLabel"))
	for line in lines:
		var p := UiTheme.panel("CardPanel")
		p.add_child(UiTheme.label(line))
		_list.body.add_child(p)
	_list.add_button("Back to the map", func() -> void:
		_list.close()
		check(), "PrimaryButton", 220.0)


# --- In battle (docs/design/notes/first-fight.md) -------------------------------
## The rest of the battle, taught lightly in the saga's real fights after
## the burned hall: one hint per control or matter, the first time it
## bears on the fight, on a card on the battle screen that keeps clear of
## the control it names (BattleHints, view/battle_hints.gd). Seen ones are
## kept in `seen` with the map's, so the "?" lists them too. And one on the
## map: the fight offer's choices, the first time a fight offers.

const BATTLE_ORDER := ["b_clock", "b_form", "b_tap", "b_tome", "b_wheel", "b_hold", "b_advance", "b_taunt", "b_break", "b_withdraw", "b_pulse"]
## The HUD control each battle hint names (view/hud.gd `controls`, and
## "pulse" for the pace slider), or "" for the board itself; the card
## stands away from it and rings it.
static func battle_control(id: String) -> String:
	match id:
		"b_form":
			return "form"
		"b_tome":
			return "shout:%d" % CombatTypes.Shout.TO_ME
		"b_wheel":
			return "wheel_l"
		"b_hold":
			return "shout:%d" % CombatTypes.Shout.HOLD
		"b_advance":
			return "advance"
		"b_taunt":
			return "shout:%d" % CombatTypes.Shout.TAUNT
		"b_break":
			return "shout:%d" % CombatTypes.Shout.BREAK_THEM
		"b_withdraw":
			return "withdraw"
		"b_pulse":
			return "pulse"
	return ""


## Rounds into a fight before the pace hint comes.
const PULSE_ROUND := 4


## The words of a battle hint, or of the fight offer's ("offer").
static func battle_text(id: String) -> String:
	match id:
		"b_clock":
			return "This fight is over something: the top line says what, and the clock how many rounds are left once the lines meet. When it runs out, the side that holds wins."
		"b_form":
			return "Form sets the shape your men take when they form up, a line, ranks or a wedge. Choose it before the first round."
		"b_tap":
			return "Tap a hex beside your man to step there, or an enemy at arm's length to strike him. Tap your man again to fight with the line."
		"b_tome":
			return "A man out of the wall is a man alone: To Me calls your men in to your side, and puts heart back in them."
		"b_wheel":
			return "They are round your flank: Wheel L or Wheel R turns your whole wall to face them."
		"b_hold":
			return "They are coming on: Hold keeps your wall where it stands, so they tire themselves on your shields."
		"b_advance":
			return "Advance takes your wall one hex forward as one, without the shove of Push: for closing up to them in good order."
		"b_taunt":
			return "They stand and wait for you: Taunt jeers at them across the field, and men who are only standing there lose heart."
		"b_break":
			return "Their heart is going: Break Them sends every man of yours at the nearest of them. Given too soon, it throws your wall away."
		"b_withdraw":
			return "Out of their reach you may Withdraw. Leaving the field costs standing, not blood: it is a choice, not a defeat."
		"b_pulse":
			return "The slider by the gear lets the rounds go by on their own, every so many seconds. At the far left you fight turn by turn."
		"offer":
			return "Before a fight you choose how to meet it: take the field as it lies, hold ground of your own and let them come to you, lie in wait if your scout saw them first, or fade away, which costs standing and not blood."
	return ""


## Whether battle hint `id` bears on `b` as it stands (side 0 is yours).
## Never in the burned hall, which teaches itself (view/tutorial.gd).
static func battle_due(id: String, b: Battle) -> bool:
	if b == null or b.is_over():
		return false
	if b.objective != null and b.objective.kind == Objective.Kind.ESCAPE and b.objective.attacker == 0:
		return false
	var l := b.leader_of(0)
	if l == null:
		return false
	var met := b.lines_met()
	match id:
		"b_clock":
			return b.objective != null and b.objective.clock_text(b) != ""
		"b_form":
			return b.round == 0
		"b_tap":
			return b.round >= 1
		"b_tome":
			if b.round < 1:
				return false
			for w in b.active(0):
				if w != l and not w.broken and w.role != CombatTypes.Role.MISSILE and BattleGrid.chebyshev(w.pos, l.pos) >= 3 \
						and b.grid.adjacent_warriors(w.pos, 1).is_empty():
					return true
			return false
		"b_wheel":
			for w in b.wall_members(0):
				if Morale.is_flanked(b.grid, w):
					return true
			return false
		"b_hold":
			var theirs := b.standing_order(1)
			return not met and b.round >= 1 and (theirs == CombatTypes.Shout.PUSH or theirs == CombatTypes.Shout.BREAK_THEM) \
					and _nearest_foe(b, l) <= 4
		"b_advance":
			return not met and b.round >= 1 and b.wall_members(0).size() >= 2 and _nearest_foe(b, l) >= 3
		"b_taunt":
			var theirs2 := b.standing_order(1)
			return not met and b.round >= 2 and (theirs2 == CombatTypes.Shout.HOLD or theirs2 == CombatTypes.Shout.SHIELD_WALL) \
					and _nearest_foe(b, l) <= b.rules.taunt_range
		"b_break":
			var n := 0
			var thin := 0
			for w in b.active(1):
				n += 1
				if w.broken or w.morale <= b.rules.morale_break_threshold + 1:
					thin += 1
			return met and n > 0 and thin * 3 >= n
		"b_withdraw":
			return b.round >= 1 and b.can_withdraw(0) and b.active(0).size() < b.active(1).size()
		"b_pulse":
			return b.round >= PULSE_ROUND
	return false


static func _nearest_foe(b: Battle, l: Warrior) -> int:
	var best := 99
	for e in b.active(1):
		if not e.broken:
			best = mini(best, BattleGrid.distance(e.pos, l.pos))
	return best


## The next battle hint to show on `b`, or "": the first in BATTLE_ORDER not
## yet seen that bears on the fight now.
func next_battle_hint(b: Battle) -> String:
	for id in BATTLE_ORDER:
		if not seen.has(id) and battle_due(id, b):
			return id
	return ""


## What has been learned in battle, in order, for the battle screen's "?".
func learned_in_battle() -> PackedStringArray:
	var out := PackedStringArray()
	for id in BATTLE_ORDER:
		if seen.has(id):
			out.append(battle_text(id))
	if seen.has("offer"):
		out.append(battle_text("offer"))
	return out


## The fight offer's hint, on the map: the first time a fight offers, a
## slip of parchment at the top of the offer itself (the card would hide
## behind it), seen once the offer is answered.
func _offer_hint() -> void:
	var modal = _map.get("modal") if _map != null else null
	var open: bool = modal != null and (modal as Control).visible and journey != null \
			and str(journey.current().get("kind", "")) == "fight"
	if not open:
		if _offer_body != null:
			seen["offer"] = true  # the offer was answered with the hint before it
			_offer_body = null
		return
	if seen.has("offer"):
		return
	var body: Control = (modal as UiModal).body
	if body.get_node_or_null("OfferHint") != null:
		return
	var p := UiTheme.panel("ParchmentPanel")
	p.name = "OfferHint"
	p.add_child(UiTheme.label(battle_text("offer"), "InkSmallLabel"))
	body.add_child(p)
	body.move_child(p, 0)
	_offer_body = body


var _offer_body: Control = null
