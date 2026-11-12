class_name MenPanel
extends RefCounted
## "Your men" as the saga would tell them (docs/design/notes/shell.md): a
## list of the band (each man's name, what he is, how he is hurt, and the
## one thing he is known for) that opens a man's card: his nature and the
## traits he has earned, his strengths in words (the numbers behind them
## only with Settings.show_numbers), what he may yet become as the judge
## of men can see it (Potential.hints), his deeds, his oath and what he
## wants, who he is sworn to and who he hates, how long he has been with
## you; and for the leader his name in the world, his ways and his
## household. It reads the sim and changes nothing.
##
## It fills the map's side panel (MapScreen.side_panel, a UiModal).

var map: Node
var journey: Journey

## A stat in four steps of words, low to high (CombatTypes.Stat order).
const STEPS := [
	["weak in the arm", "fair in the arm", "strong", "mighty"],
	["clumsy with a blade", "able with a blade", "skilled", "a master of arms"],
	["soon spent", "hardy enough", "hard to tire", "tireless"],
	["easily shaken", "steady enough", "bold", "fearless"],
	["slow", "sensible", "quick-witted", "shrewd"],
]
## The highest stat value of each step but the last.
const STEP_TOPS := [3, 5, 7]
## A woman's birth, by CampaignTypes.Origin: whose daughter she is.
const DAUGHTER_OF := ["fisherman's house", "farmer's house", "house of outlaws", "freedman's house", "jarl's house"]
## His nature (CombatTypes.Personality): a word, and what it means.
const NATURES := [
	["steady", "keeps his place in the line when others would not"],
	["reckless", "goes in before the order and will not wait for the wall"],
	["grim", "says little, laughs less, and does not frighten"],
	["boastful", "boasts in the hall and must make the boast good"],
	["greedy", "keeps a close eye on the sharing of the silver"],
	["superstitious", "reads an omen in everything and fears the ones he reads"],
]


func _init(p_map: Node) -> void:
	map = p_map
	journey = map.journey


## The band in the order it is told: the leader, then his men as they came.
static func people(band: Band) -> Array[Man]:
	var out: Array[Man] = []
	if band.leader != null and band.leader.alive:
		out.append(band.leader)
	for m in band.living_men():
		out.append(m)
	return out


# --- Words -----------------------------------------------------------------------

## The step (0..3) a stat value stands on.
static func step_of(value: int) -> int:
	for i in STEP_TOPS.size():
		if value <= STEP_TOPS[i]:
			return i
	return STEP_TOPS.size()


static func stat_words(stat: int, value: int) -> String:
	return str(STEPS[stat][step_of(value)])


## The stat he is best at: ties go to the earlier.
static func best_stat(m: Man) -> int:
	var best := 0
	for s in 5:
		if m.stats[s] > m.stats[best]:
			best = s
	return best


## How the judge of men in the band (the leader, by his wits) can see what
## a man may become: Potential's judge level, 1 to 3.
static func judge_level(band: Band) -> int:
	var w := band.leader.stats[CombatTypes.Stat.WITS] if band.leader != null else 3
	if w >= 7:
		return 3
	if w >= 4:
		return 2
	return 1


static func loyalty_words(rules: CampaignRules, m: Man) -> String:
	var he := m.he(true)
	if m.loyalty < rules.loyalty_leave_below:
		return "%s will leave at the thaw unless something changes." % he
	if m.loyalty < 35:
		return "%s grumbles, and %s oath sits loosely on %s." % [he, m.his(), m.him()]
	if m.loyalty < 60:
		return "%s serves you, as %s swore to." % [he, m.he()]
	if m.loyalty < 80:
		return "%s is loyal to you." % he
	return "%s would die at your side." % he


static func ambition_words(rules: CampaignRules, m: Man) -> String:
	var want: String = CampaignTypes.AMBITION_NAMES[m.ambition]
	var head := "%s wants %s" % [m.he(true), want]
	if m.ambition == CampaignTypes.Ambition.HOME:
		head = "%s wants to go home" % m.he(true)
	if m.ambition_met:
		return "%s, and has had it in your service." % head
	var part := float(m.ambition_progress) / maxf(1.0, float(rules.ambition_fulfilled))
	if part <= 0.0:
		return "%s; nothing has come of it yet." % head
	if part < 0.5:
		return "%s, and has had a little of it." % head
	return "%s, and has come near it." % head


static func fame_words(fame: int) -> String:
	if fame < 10:
		return "unknown beyond his own farm"
	if fame < 25:
		return "known in his own fjord"
	if fame < 50:
		return "known along the coast"
	if fame < 75:
		return "known across Norway"
	return "known in every hall of the north"


static func honor_words(honor: int) -> String:
	if honor < 20:
		return "men call him faithless"
	if honor < 40:
		return "his word is doubted"
	if honor < 60:
		return "a man of his word"
	if honor < 80:
		return "honourable"
	return "his word is as good as an oath"


static func luck_words(rules: CampaignRules, luck: int) -> String:
	if luck <= rules.luck_low:
		return "his luck runs thin"
	if luck >= rules.luck_high:
		return "lucky: men say fortune follows him"
	return "his luck holds"


static func years_words(band: Band, m: Man) -> String:
	if m.is_leader:
		return ""
	var y := band.year - m.joined_year
	if y <= 0:
		return "came to you this year"
	if y == 1:
		return "has been with you a year"
	return "has been with you %d years" % y


## The one thing he is known for, for the list: a deed if he has one, or
## his kills, or a trait he earned (not the one his birth gave him), or
## his nature and his best gift.
static func known_for(rules: CampaignRules, m: Man) -> String:
	var born: String = rules.origin_traits.get(m.origin, "")
	if not m.deeds.is_empty():
		return "Known for this: %s %s." % [m.he(), m.deeds[m.deeds.size() - 1]]
	if m.kills >= 2:
		return "Has put down %d men." % m.kills
	for t in m.traits:
		if not str(t).begins_with("son of") and str(t) != born:
			return Journey._cap(str(t)) + "."
	var bits := PackedStringArray()
	if not m.personality.is_empty():
		bits.append(str(NATURES[m.personality[0]][0]))
	bits.append(stat_words(best_stat(m), m.stats[best_stat(m)]))
	if m.battles_survived == 0 and m.kills == 0:
		bits.append("untried")
	return Journey._cap(", ".join(bits)) + "."


## What he is, in a few words: "22, a green shield-man".
static func what_he_is(m: Man) -> String:
	if m.is_leader:
		return "%d, leader of the band" % m.age
	if m.woman:
		return "%d, a %s shieldmaiden%s" % [m.age, CombatTypes.TIER_NAMES[m.tier], ["", " of the second rank", " with the bow"][m.role]]
	var role := ["shield-man", "spearman", "bowman"][m.role] as String
	return "%d, a %s %s" % [m.age, CombatTypes.TIER_NAMES[m.tier], role]


# --- The list ----------------------------------------------------------------------

func show_list() -> void:
	var c := journey.c
	var band := c.band
	var box: VBoxContainer = map._open_side("%s and his men" % Way.title(band))
	box.add_child(UiTheme.label("Touch a man to hear what is told of him. A man too hurt stays behind when it comes to a fight.", "SmallLabel"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", UiTheme.S1 + 2)
	box.add_child(list)
	for m in people(band):
		list.add_child(_row(m))
	var more := PackedStringArray()
	if not band.friends.is_empty():
		more.append("Friends won by counsel and deeds: %s." % ", ".join(band.friends.keys()))
	for f in band.unsettled_feuds():
		more.append("Feud with %s (%s)." % [str(f.get("family", f.get("against", ""))), str(f.get("cause", ""))])
	if not more.is_empty():
		box.add_child(UiTheme.label("\n".join(more), "SmallLabel"))
	map._close_side(box)


func _row(m: Man) -> Button:
	var c := journey.c
	var band := c.band
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	b.clip_contents = true
	b.name = "Man%d" % m.id
	b.pressed.connect(func() -> void: show_man(m))
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", UiTheme.S3 + 2)
	pad.add_theme_constant_override("margin_right", UiTheme.S3)
	pad.add_theme_constant_override("margin_top", UiTheme.S2 - 1)
	pad.add_theme_constant_override("margin_bottom", UiTheme.S2 - 1)
	b.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 1)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(who)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTheme.S2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(top)
	var title := m.display_name
	if m == band.leader and Way.epithet(band) != "":
		title = Way.title(band)
	top.add_child(_quiet(UiTheme.label(title, "StrongLabel", false)))
	if m == band.leader:
		top.add_child(_quiet(UiTheme.chip("You", Palette.UI_GOLD)))
	elif m.woman:
		top.add_child(_quiet(UiTheme.chip("Shieldmaiden", Palette.UI_TEAL)))
	top.add_child(_quiet(UiTheme.label(what_he_is(m), "SmallLabel", false)))
	var line := UiTheme.label(known_for(c.rules, m), "SmallLabel")
	line.add_theme_color_override("font_color", Palette.UI_TEXT.darkened(0.12))
	who.add_child(_quiet(line))
	var state := VBoxContainer.new()
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(state)
	var chip := _wound_chip(m)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	state.add_child(_quiet(chip))
	if m.too_hurt_to_fight(c.rules) and m != band.leader:
		var stays := UiTheme.label("stays behind", "SmallLabel", false)
		stays.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.25))
		state.add_child(_quiet(stays))
	pad.minimum_size_changed.connect(func() -> void:
		b.custom_minimum_size.y = maxf(UiTheme.TOUCH, pad.get_combined_minimum_size().y))
	return b


func _quiet(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _wound_chip(m: Man) -> PanelContainer:
	var w := m.current_wound(journey.c.rules)
	if w == CombatTypes.Wound.UNHURT:
		return UiTheme.chip("Unhurt", Palette.UI_TEAL)
	var col := Palette.UI_GOLD if w == CombatTypes.Wound.BRUISED else Palette.UI_BLOOD
	return UiTheme.chip(str(CombatTypes.WOUND_NAMES[w]).capitalize(), col)


# --- A man's card ----------------------------------------------------------------

func show_man(m: Man) -> void:
	var c := journey.c
	var band := c.band
	var rules := c.rules
	var leader := m == band.leader
	var title := Way.title(band) if leader else m.display_name
	var side: UiModal = map.side_panel
	var box: VBoxContainer = map._open_side(title)
	# Under the name: what he is, where he came from, how long with you.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.S2)
	box.add_child(head)
	var about := PackedStringArray([what_he_is(m), ("of a %s" % DAUGHTER_OF[m.origin]) if m.woman else "born a %s" % CampaignTypes.ORIGIN_NAMES[m.origin]])
	var with_you := years_words(band, m)
	if with_you != "":
		about.append(with_you)
	if m.is_banner:
		about.append("%s carries the banner" % m.he())
	if m.is_horn:
		about.append("%s blows the horn" % m.he())
	if band.sworn_second_id == m.id and not leader:
		about.append("your sworn second")
	var al := UiTheme.label(Journey._cap(", ".join(about)) + ".", "SmallLabel")
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(al)
	head.add_child(_wound_chip(m))

	var grid := GridContainer.new()
	var wide := side.size.x <= 0.0 or side.size.x > 900.0
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", UiTheme.S2)
	grid.add_theme_constant_override("v_separation", UiTheme.S2)
	box.add_child(grid)

	# His nature, and what life has put on him. The leader's own (Natures),
	# with what each trait does; a man's personality, in words.
	var nature := _card(grid, "%s nature" % m.his(true))
	for k in m.natures:
		nature.add_child(UiTheme.label(Natures.name_of(k), "StrongLabel"))
		var nl := UiTheme.label(Natures.line(rules, k), "SmallLabel")
		nature.add_child(nl)
	if m.personality.is_empty() and m.natures.is_empty():
		nature.add_child(UiTheme.label("Nothing in %s stands out yet: an even-tempered %s." % [m.him(), m.man_word()], "BodyLabel"))
	for p in m.personality:
		var n: Array = NATURES[p]
		var says := str(n[1]).replace("his ", m.his() + " ").replace(" he ", " %s " % m.he())
		nature.add_child(UiTheme.label("%s: %s %s." % [Journey._cap(str(n[0])), m.he(), says]))
	var earned := PackedStringArray()
	for t in m.traits:
		earned.append(str(t))
	for mm in m.maims:
		earned.append("%s carries %s" % [m.he(), CampaignTypes.MAIM_NAMES[mm]])
	if not earned.is_empty():
		nature.add_child(UiTheme.label(Journey._cap("; ".join(earned)) + ".", "SmallLabel"))

	# His strengths, in words; the numbers only if asked for.
	var strength := _card(grid, "%s strength" % m.his(true))
	for s in 5:
		strength.add_child(_stat_line(s, m.stats[s]))

	# What he may become, as far as the leader can judge it.
	var may := _card(grid, "What %s may become" % m.he())
	var judge := judge_level(band)
	var hints := Potential.hints(rules, m, judge)
	var lines := PackedStringArray()
	for h in hints:
		lines.append(str(h))
	may.add_child(UiTheme.label(Journey._cap("; ".join(lines)) + ".", "BodyLabel"))
	if Potential.is_coal_biter(rules, m) and judge >= 2:
		may.add_child(UiTheme.label("Some would call %s a coal-biter: little now, more later." % m.him(), "SmallLabel"))
	var judged := ["not at all", "only by guessing", "fairly well", "well"][judge] as String
	may.add_child(UiTheme.label("%s %s, by your wits." % ["You know yourself" if leader else "You read %s" % m.him(), judged], "SmallLabel"))

	# His deeds.
	var he := m.he(true)
	var deeds := _card(grid, "%s deeds" % m.his(true))
	var told := PackedStringArray()
	if m.battles_survived > 0:
		told.append("%s has come through %s." % [he, _count(m.battles_survived, "fight", "fights")])
	else:
		told.append("%s has not yet stood in a fight with you." % he)
	if m.kills > 0:
		told.append("%s has put down %s." % [he, _count(m.kills, "man", "men")])
	if m.broke_count > 0:
		told.append("%s has broken and run %s." % [he, _count(m.broke_count, "time", "times").replace("1 time", "once").replace("2 times", "twice")])
	for d in m.deeds:
		told.append("%s %s." % [he, d])
	var wound := m.current_wound(rules)
	if wound != CombatTypes.Wound.UNHURT:
		told.append("%s is %s now, and has %s of healing to do." % [he, CombatTypes.WOUND_NAMES[wound], _count(m.healing_turns, "turn", "turns")])
	for t in told:
		deeds.add_child(UiTheme.label(t))

	if not leader:
		# His oath, and what he wants of it.
		var oath := _card(grid, "%s oath" % m.his(true))
		var ll := UiTheme.label(loyalty_words(rules, m), "StrongLabel")
		if m.loyalty < rules.loyalty_leave_below:
			ll.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.25))
		oath.add_child(ll)
		oath.add_child(UiTheme.label(ambition_words(rules, m)))
		if Settings.show_numbers:
			oath.add_child(UiTheme.label("Loyalty %d of 100." % m.loyalty, "SmallLabel"))

	# His bonds in the band.
	var bonds := _card(grid, "%s bonds" % m.his(true))
	var brothers := Bonds.oath_brothers(band, m)
	var rivals := Bonds.rivals(band, m)
	if not brothers.is_empty():
		bonds.add_child(UiTheme.label("Sworn brother of %s: they mixed their blood under the turf." % _names(brothers)))
	if not rivals.is_empty():
		var rl := UiTheme.label("There is bad blood between %s and %s." % [m.him(), _names(rivals)])
		rl.add_theme_color_override("font_color", Palette.UI_BLOOD.lightened(0.3))
		bonds.add_child(rl)
	var close := PackedStringArray()
	for other in people(band):
		if other != m and not brothers.has(other) and not rivals.has(other) and band.bond(m, other) >= 25:
			close.append(other.display_name)
	if not close.is_empty():
		bonds.add_child(UiTheme.label("%s stands closest to %s." % [he, ", ".join(close)], "SmallLabel"))
	if brothers.is_empty() and rivals.is_empty() and close.is_empty():
		bonds.add_child(UiTheme.label("%s has sworn no brotherhood and made no enemy in the band." % he, "SmallLabel"))

	_gear_card(grid, m)
	if leader:
		_leader_cards(grid)

	map._close_side(box)
	side.add_button("Back to your men", show_list, "", 200.0)
	# The way back to the list first in the footer; the map last.
	side.footer.move_child(side.footer.get_child(side.footer.get_child_count() - 1), 0)


## The leader's name in the world, his ways, his household.
func _leader_cards(grid: GridContainer) -> void:
	var c := journey.c
	var band := c.band
	var known := _card(grid, "His name in the world")
	var e := Way.epithet(band)
	known.add_child(UiTheme.label("The saga calls him %s." % Way.title(band) if e != "" else "The saga has not yet given him a name.", "StrongLabel"))
	var rep := PackedStringArray([
		"He is %s." % fame_words(band.fame),
		Journey._cap(honor_words(band.honor)) + ".",
		Journey._cap(luck_words(c.rules, band.luck)) + ".",
	])
	known.add_child(UiTheme.label(" ".join(rep)))
	if Settings.show_numbers:
		known.add_child(UiTheme.label("Fame %d, honor %d, luck %d." % [band.fame, band.honor, band.luck], "SmallLabel"))
	var ways := _card(grid, "His ways")
	var taken := PackedStringArray()
	for way in Way.Id.values():
		var r := Way.rank(band, way)
		if r <= 0:
			continue
		var d := Way.def(way)
		var steps := PackedStringArray()
		for i in r:
			steps.append(str(d.ranks[i].name))
		taken.append("%s: %s" % [str(d.name), ", ".join(steps)])
	if taken.is_empty():
		ways.add_child(UiTheme.label("He has taken no step down any way of life yet.", "SmallLabel"))
	for t in taken:
		ways.add_child(UiTheme.label(t))
	var home := _card(grid, "His household")
	if band.wife != "":
		home.add_child(UiTheme.label("He is married to %s." % band.wife))
	else:
		home.add_child(UiTheme.label("He has no wife.", "SmallLabel"))
	var kids := PackedStringArray()
	for child in band.sons:
		if not bool(child.get("alive", true)):
			continue
		var age := Family.age_of(child, c.cal)
		var what := "a daughter" if bool(child.get("daughter", false)) else "a son"
		var line := "%s, %s of %d" % [str(child.get("name", "")), what, age]
		if str(child.get("fostered_with", "")) != "":
			line += ", fostered with %s" % child.fostered_with
		kids.append(line)
	if not kids.is_empty():
		home.add_child(UiTheme.label("His children: %s." % "; ".join(kids)))
	elif band.wife != "":
		home.add_child(UiTheme.label("No child of his lives yet.", "SmallLabel"))
	var second := band.man_by_id(band.sworn_second_id) if band.sworn_second_id >= 0 else null
	if second != null and second.alive:
		home.add_child(UiTheme.label("His sworn second is %s." % second.display_name, "SmallLabel"))


## His arms, and what may be given him now (Journey.gift_options): silver
## as at Yule, or arms from the chest, once a summer a man. The smith is
## at the market towns and kings' halls (EstatePanel).
func _gear_card(grid: GridContainer, m: Man) -> void:
	var c := journey.c
	var leader := m == c.band.leader
	var card := _card(grid, "%s arms" % m.his(true))
	card.add_child(UiTheme.label("%s %s." % ["You have" if leader else "%s has" % m.he(true), Estate.gear_words(m)]))
	if m.sword_name != "":
		card.add_child(UiTheme.label("The sword %s is talked of wherever %s goes." % [m.sword_name, "you go" if leader else m.he()], "SmallLabel"))
	if leader:
		return
	var opts := journey.gift_options(m.id)
	if opts.is_empty():
		return
	card.add_child(UiTheme.label("Give %s..." % m.him(), "StrongLabel"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", UiTheme.S2)
	flow.add_theme_constant_override("v_separation", UiTheme.S2)
	card.add_child(flow)
	var why := ""
	for o in opts:
		var what := str(o.id)
		var b := UiTheme.secondary(str(o.label), func() -> void:
			if journey.give(m.id, what):
				Audio.play("coin")
				map.refresh()
				show_man(m))
		b.custom_minimum_size.y = UiTheme.TOUCH
		b.disabled = not bool(o.enabled)
		b.tooltip_text = str(o.get("hint", ""))
		flow.add_child(b)
		if not bool(o.enabled) and why == "":
			why = str(o.get("hint", ""))
	if why != "":
		card.add_child(UiTheme.label(why, "SmallLabel"))
	elif Estate.of(c.band).chest.is_empty():
		card.add_child(UiTheme.label("Arms bought at a smith for the chest can be given from here.", "SmallLabel"))


## A titled card in the grid; returns its body.
func _card(grid: GridContainer, title: String) -> VBoxContainer:
	var p := UiTheme.titled_panel(title)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_FILL
	grid.add_child(p)
	return p.get_meta("body")


## A stat as a line: its name, its words, four pips for the step, and the
## number when the player asked for numbers.
func _stat_line(stat: int, value: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S2)
	var k := UiTheme.label(str(CombatTypes.STAT_NAMES[stat]).to_upper(), "KeyLabel", false)
	k.custom_minimum_size.x = 64
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(k)
	var w := UiTheme.label(stat_words(stat, value), "StrongLabel", false)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(w)
	var pips := UiOrnament.new()
	pips.kind = UiOrnament.Kind.PIPS
	pips.count = 4
	pips.filled = step_of(value) + 1
	pips.custom_minimum_size = Vector2(70, 20)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	if Settings.show_numbers:
		var n := UiTheme.label(str(value), "ValueLabel", false)
		n.custom_minimum_size.x = 26
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
	return row


static func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


static func _names(men: Array[Man]) -> String:
	var out := PackedStringArray()
	for m in men:
		out.append(m.display_name)
	if out.size() <= 1:
		return "".join(out)
	return "%s and %s" % [", ".join(out.slice(0, out.size() - 1)), out[out.size() - 1]]
