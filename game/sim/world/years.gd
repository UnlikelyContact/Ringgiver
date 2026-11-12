class_name Years
extends RefCounted
## Letting the years pass (concept.md, "Saga pacing: quiet years"): the
## saga's own device, "Then nothing is told of him for three winters". At
## the spring step of the winter (WinterHall, `_state_spring`) the player
## may stay at home and let one, three or up to ten years go by. Each such
## year the band sits at home: the men are kept (silver for their ale and
## share, the summer's hay and fishing for the store), the idle grow
## restless and fame fades; then the winter is lived with the old sensible
## plan (Campaign.winter), the thaw ages everyone, children are born and
## grow, and the world goes on (the houses' year, the factions' moves).
## The years stop at the spring of a year that needs him: a spine event
## with a choice, a house's ask, his hall attacked by a house at feud, a son
## coming to fostering age or of age, a daughter to marry, a vow to keep,
## stores run out, or his death (the grave-ale follows).
##
## Journey's winter hands over here (`after_winter`, from `winter_end`) and
## the summer of the year where the years stopped begins as usual. What
## the passed years told is left in `Journey.years_told` for the screen.
## Sandbox.pass_years (the AI's) is a plainer cousin: it stops on any feud.

## The standing word left with the hall for offers that come while the
## years pass (WinterHall.years_offers): wergild offered for a feud and a
## friend's daughter offered in marriage are answered so and the years go
## on; only a call for help from his own kin, an attack, a matter of the
## realm, his children and his vow still stop them. "" stops for each.
const OFFERS := {
	"": "Send for him for every offer.",
	"accept": "Take fair wergild and a friend's daughter.",
	"refuse": "Let every offer lie unanswered.",
}

## Why the years stopped, in words for the screen.
const STOP_WORDS := {
	"spine": "Great matters are afoot in the land, and he is needed.",
	"house": "A house sends word, and will have an answer.",
	"attack": "Men are coming against his hall.",
	"son": "A son of the house comes to an age when something must be decided.",
	"daughter": "A daughter of the house is of an age to marry.",
	"vow": "He has a vow to keep this summer.",
	"stores": "The stores and the chest are running out.",
	"death": "Death came to the hall.",
	"over": "The saga is ended.",
	"done": "",
}


## Why the years cannot pass now ("" when they can): only from his own
## roof or a friend's, never while a death waits or the saga is over.
static func blocked(j: Journey) -> String:
	var c := j.c
	var h := j.winter_hall
	if c.over:
		return "The saga is ended."
	if not c.pending_death.is_empty() or (c.band.leader != null and not c.band.leader.alive):
		return "The dead must be honoured first."
	if h == null or h.lodging == "camp":
		return "A man lets the years pass under a roof, not in a camp in the wilds."
	if c._pending_vow != "":
		return "He has a vow to keep this summer."
	return ""


## The spring step's part (WinterHall._state_spring): the years to let
## pass as a row of buttons with what it would mean, and an old leader's
## stepping down for his son.
static func spring_rows(j: Journey, h: WinterHall, s: Dictionary) -> void:
	var c := j.c
	var why := blocked(j)
	var n := h.years
	var btns: Array = []
	for k in [1, 3, c.rules.years_max]:
		btns.append(h._btn("years:%d" % k, "%d year%s" % [k, "" if k == 1 else "s"], why == "", n == k))
	if n > 0:
		btns.append(h._btn("years:0", "Play the summer", true, false))
	var detail := "Then nothing is told of him for a time: he stays at home and the years go by, until something needs him."
	if why != "":
		detail = why
	h.years = n if why == "" else 0
	s.rows.append(h._row("Let the years pass", detail, ("%d years" % n) if n > 1 else ("one year" if n == 1 else ""), btns))
	if h.years > 0:
		var obtns: Array = []
		for k in ["", "accept", "refuse"]:
			obtns.append(h._btn("offers:" + k, {"": "Ask me", "accept": "Accept fair offers", "refuse": "Refuse offers"}[k], true, h.years_offers == k))
		s.rows.append(h._row("Offers while he sits at home", "Wergild offered and a friend's daughter: %s A burned hall's wergild is never taken unasked." % str(OFFERS[h.years_offers]),
				"", obtns))
		for line in preview(j, h.years):
			s.notes.append(line)
		s.next_label = "Let the years pass"
	# An old leader with a son of age may step down.
	var leader := c.band.leader
	if leader != null and leader.alive and leader.age >= c.rules.step_down_age and c.pending_death.is_empty():
		for cand in Succession.candidates(c):
			if str(cand.kind) != "son":
				continue
			var on := h.step_down == str(cand.id)
			s.rows.append(h._row("Step down for %s" % cand.name, "%s is %d winters old. %s gives %s the high seat and sits by the fire as the old man of the hall, giving counsel. No grave-ale: the saga goes on with the son." % [
					leader.display_name, leader.age, leader.display_name, cand.name], "to step down" if on else "",
					[h._btn("stepdown:" + str(cand.id), "Undo" if on else "Step down", true, on)]))
			if on:
				s.next_label = "Give him the high seat"
			break


## A spring-step choice: "years" (n, 0 to play the summer) or "stepdown"
## (a candidate's id, again to undo).
static func choose(j: Journey, h: WinterHall, key: String, arg: String) -> void:
	match key:
		"years":
			h.years = clampi(int(arg), 0, j.c.rules.years_max) if blocked(j) == "" else 0
			if h.years > 0:
				h.step_down = ""
		"stepdown":
			h.step_down = "" if h.step_down == arg else arg
			if h.step_down != "":
				h.years = 0
		"offers":
			h.years_offers = arg if OFFERS.has(arg) else ""


## What `n` years at home would mean, in a few lines (an estimate: what
## comes of them is not known until they are lived).
static func preview(j: Journey, n: int) -> PackedStringArray:
	var c := j.c
	var rules := c.rules
	var band := c.band
	var out := PackedStringArray()
	var leader := band.leader
	var men := band.living_men().size()
	var y0 := c.cal.year + 1
	var age_line := "%s is %d winters old; after %d year%s he would be %d." % [leader.display_name, leader.age, n, "" if n == 1 else "s", leader.age + n]
	if leader.age + n >= rules.old_age:
		age_line += " Old age: any winter may take him in his bed."
	elif leader.age + n >= rules.decline_age:
		age_line += " His strength begins to go."
	out.append(age_line)
	var upkeep := rules.years_upkeep_per_man * men
	var land := band.land * c.world_rules.land_silver_per_unit
	out.append("Each year at home his %d men cost about %d oz in ale and shares, and bring in about %d rations from the hay and the nets%s." % [
			men, upkeep, rules.years_food_per_man * men, (", and his land yields %d oz" % land) if land > 0 else ""])
	if j.winter_hall != null and j.winter_hall.lodging == "guest":
		upkeep += c.world_rules.guest_winter_per_man * (men + 1)
		out.append("As guests at %s they pay %d oz a winter for the lodging." % [j.winter_hall.place_name, c.world_rules.guest_winter_per_man * (men + 1)])
	out.append("The chest holds %d oz now: about %d after %d year%s, if nothing else happens. Fame fades by about %d when nothing is told." % [
			band.silver, maxi(0, band.silver + n * (land - upkeep)), n, "" if n == 1 else "s", rules.years_fame_fade * n])
	var restless := PackedStringArray()
	for m in band.living_men():
		if (m.ambition == CampaignTypes.Ambition.SILVER or m.ambition == CampaignTypes.Ambition.FAME) \
				and m.loyalty - rules.years_idle_loyalty * n < rules.loyalty_leave_below + 10:
			restless.append(m.display_name)
	if not restless.is_empty():
		out.append("Men who want silver or fame sit ill at home: %s may go off to find another lord." % ", ".join(restless.slice(0, 5)))
	var kids := PackedStringArray()
	for child in band.sons:
		if not child.get("alive", true) or child.get("seat", false):
			continue
		var age := y0 - 1 - int(child.get("born", y0))
		kids.append("%s would be %d" % [str(child.name), age + n])
	if not kids.is_empty():
		out.append("The children grow: %s. The years stop when a son comes to fostering age or of age, or a daughter to marry." % ", ".join(kids))
	var feuds := band.unsettled_feuds()
	if not feuds.is_empty():
		var names := PackedStringArray()
		for f in feuds:
			names.append(str(f.get("family", f.get("against", ""))))
		out.append("Open feuds with %s: a house at feud may come against his hall, and then the years stop." % ", ".join(names))
	for ev in c.world_rules.spine:
		var y := int(ev.year)
		if y >= y0 and y < y0 + n and (ev.get("options", ["ignore"]) as Array).size() > 1 and not c.world.timeline_state.get(ev.id, false):
			var what := str(ev.text)
			if what.find(".") > 0:
				what = what.left(what.find("."))
			out.append("In %d: %s. The years stop before it." % [y, what])
			break
	out.append("The houses live their years and the kings theirs; he will hear the tidings.")
	return out


## The winter is over (Journey.winter_end, after the calendar turns): an
## old leader steps down if he chose to, or the years he chose pass. Returns
## true when it began the summer itself (Journey then does not).
static func after_winter(j: Journey, h: WinterHall) -> bool:
	var c := j.c
	if c.over or not c.pending_death.is_empty():
		return false
	if h.step_down != "":
		for cand in Succession.candidates(c):
			if str(cand.id) == h.step_down:
				var lines := Succession.step_down(c, cand, c.log)
				for l in lines:
					j._say(l)
				break
		return false
	if h.years <= 0:
		return false
	let_pass(j, h.years, h.lodging, h.years_offers)
	return true


## Lets up to `n` years pass, from the spring of the current year (a guest
## pays his lodging each of them), and
## begins the summer of the year they stop at. Returns what they told (also
## left in `j.years_told`): {from, to, passed, stopped, why, lines, tidings}.
static func let_pass(j: Journey, n: int, lodging := "home", offers := "") -> Dictionary:
	var c := j.c
	var band := c.band
	var from := c.cal.year
	var told := {"from": from, "to": from, "passed": 0, "stopped": "done", "why": "", "lines": PackedStringArray(), "tidings": PackedStringArray()}
	var extra := {}
	var lines := PackedStringArray()
	var tidings := PackedStringArray()
	for i in mini(n, c.rules.years_max):
		var y := c.cal.year
		band.year = y
		c.world.year = y
		var stop := _stop(j, y, offers)
		if not stop.is_empty():
			told.stopped = str(stop.kind)
			told.why = str(stop.get("text", STOP_WORDS.get(stop.kind, "")))
			extra = stop
			break
		var chron := band.chronicle.size()
		_quiet_year(j, y, lodging == "guest")
		told.passed = int(told.passed) + 1
		told.to = y
		for k in range(chron, band.chronicle.size()):
			lines.append(band.chronicle[k])
		if c.world.families != null:
			for t in c.world.families.tidings_of(y):
				tidings.append("%d: %s" % [y, t])
		c.cal.next_year()
		band.year = c.cal.year
		if c.over:
			told.stopped = "over"
			break
		if not c.pending_death.is_empty():
			told.stopped = "death"
			told.why = "%s died in the winter of %d." % [str(c.pending_death.name), y]
			break
	told.lines = lines
	told.tidings = tidings
	if str(told.stopped) == "done":
		told.why = "The years he chose have passed."
	c.tally.years_passed = int(c.tally.get("years_passed", 0)) + int(told.passed)
	var stops: Dictionary = c.tally.get("years_stops", {})
	stops[str(told.stopped)] = int(stops.get(str(told.stopped), 0)) + 1
	c.tally["years_stops"] = stops
	j.years_told = told
	if c.over:
		return told
	j.begin_summer()
	_after_stop(j, extra)
	return told


## Whether the year `y` needs him, before its summer is let pass: {} when
## it does not, else {kind, text, ...}.
static func _stop(j: Journey, y: int, offers := "") -> Dictionary:
	var c := j.c
	var band := c.band
	var rules := c.rules
	var wr := c.world_rules
	if c._pending_vow != "":
		return {"kind": "vow"}
	for ev in Timeline.pending(wr, c.world, y):
		if Timeline.outcome_options(ev).size() > 1:
			return {"kind": "spine", "text": "In %d: %s" % [y, str(ev.text)]}
	var who := band.leader.display_name if band.leader != null else ""
	for child in band.sons:
		if not child.get("alive", true) or child.get("seat", false):
			continue
		var age := y - int(child.get("born", y))
		var mine := str(child.get("father", who)) == who
		if Family.is_son(child):
			if mine and age == rules.foster_min_age and str(child.get("fostered_with", "")) == "":
				return {"kind": "son", "text": "%s is %d winters old this year: is he to be fostered?" % [str(child.name), age]}
			if age == rules.son_join_age and int(child.get("man_id", -1)) < 0 and str(child.get("decided", "")) == "":
				return {"kind": "son", "text": "%s comes of age this year." % str(child.name)}
		elif mine and age == rules.daughter_marry_age and str(child.get("married_to", "")) == "":
			return {"kind": "daughter", "text": "%s is %d winters old this year, and men will ask after her." % [str(child.name), age]}
	var r := c.rng.fork("years:%d" % y)
	for f in band.unsettled_feuds():
		var fam := str(f.get("family", f.get("against", "")))
		var level := int(f.get("level", 1))
		if r.fork("attack:" + fam).randf() < rules.years_attack_chance * level:
			return {"kind": "attack", "family": fam, "level": level,
					"text": "In the spring of %d word comes that %s are gathering men to come against the hall." % [y, fam]}
	if c.world.families != null:
		var asks := c.world.families.asks(r.fork("asks"), wr, c.world, band, y)
		var wanted: Array[Dictionary] = []
		for d in asks:
			# Wergild offered, a friend's daughter, or a call for help from a
			# house bound to his by blood or marriage will not wait (unless he
			# left word for offers, OFFERS); a fostering house's call and other
			# houses' asks can go unheard for a year.
			var ties: Array = band.house_ties.get(str(d.house), [])
			var bound := ties.has("kin") or ties.has("marriage")
			var offer := str(d.ask) == "compensation" or (str(d.ask) == "marry" and Families.is_friend(wr, band, str(d.house)))
			if offer and offers != "" and not (str(d.ask) == "compensation" and str(d.house) == band.vengeance):
				_standing_answer(j, d, offers)
				continue
			if offer or (str(d.ask) == "help" and bound):
				wanted.append(d)
		if not wanted.is_empty():
			return {"kind": "house", "asks": wanted, "text": "In %d %s sends word." % [y, str(wanted[0].house)]}
	var men := band.living_men().size()
	var eat := (men + 1) * 4
	var have := band.food + rules.years_food_per_man * men + band.land * wr.land_food_per_unit
	var cost := rules.years_upkeep_per_man * men + maxi(0, eat - have) * wr.farm_food_price
	if band.silver + band.land * wr.land_silver_per_unit < cost:
		return {"kind": "stores"}
	return {}


## An offer answered by the word left with the hall: wergild taken (or let
## lie, the feud still open), a marriage made or declined with thanks.
static func _standing_answer(j: Journey, d: Dictionary, offers: String) -> void:
	var band := j.c.band
	var who := band.leader.display_name
	match str(d.ask):
		"compensation":
			if offers == "accept":
				j._answer_house(d, "take")
			else:
				band.log("%s let the wergild offered by %s lie unanswered" % [who, str(d.house)])
		"marry":
			if offers == "accept" and band.wife == "":
				j._answer_house(d, "accept")
				band.log("%s married into %s while he sat at home" % [who, str(d.house)])
			else:
				j._answer_house(d, "decline")
	var answered: Dictionary = j.c.tally.get("years_answered", {})
	answered[str(d.ask)] = int(answered.get(str(d.ask), 0)) + 1
	j.c.tally["years_answered"] = answered


## One summer at home and its winter.
static func _quiet_year(j: Journey, y: int, guest: bool) -> void:
	var c := j.c
	var band := c.band
	var rules := c.rules
	var wr := c.world_rules
	var who := band.leader.display_name
	c.cal.day = 1
	c._summer_wins = 0
	# Spine events that ask nothing of him come and go.
	for ev in Timeline.pending(wr, c.world, y):
		Timeline.fire(c.rng.fork("years_spine:%s" % ev.id), wr, c.world, band, ev, "ignore", c.log)
	var at := j.here()
	var where := at.display_name if at != null else "home"
	band.log("%s sat at home at %s that summer, and nothing is told of him" % [who, where])
	Chronicle.quiet_year(band, y)
	# The men are kept: their ale and shares; the summer's hay and nets.
	var men := band.living_men()
	var upkeep := rules.years_upkeep_per_man * men.size()
	if guest:
		# A guest pays his lodging every winter he stays.
		upkeep += wr.guest_winter_per_man * (men.size() + 1)
	var paid := mini(upkeep, band.silver)
	band.silver -= paid
	band.food += rules.years_food_per_man * men.size()
	for m in men:
		var idle := rules.years_idle_loyalty if (m.ambition == CampaignTypes.Ambition.SILVER or m.ambition == CampaignTypes.Ambition.FAME) \
				else rules.years_idle_loyalty_other
		if paid < upkeep:
			idle += rules.years_idle_loyalty
		Loyalty.adjust(m, -idle)
		# A man who wanted a home, or a wife, finds them in the quiet years.
		if m.ambition == CampaignTypes.Ambition.HOME or m.ambition == CampaignTypes.Ambition.WIFE:
			Loyalty.ambition_progress(rules, band, m, rules.ambition_per_win, c.log)
	band.fame = clampi(band.fame - rules.years_fame_fade, Leader.REP_MIN, Leader.REP_MAX)
	# Rations bought for the winter from the farms about, while the chest allows.
	var need := (band.living_men().size() + 1) * 4
	if band.food < need:
		var buy := mini(need - band.food, band.silver / maxi(1, wr.farm_food_price))
		band.silver -= buy * wr.farm_food_price
		band.food += buy
	# The winter, lived the old sensible way; the thaw moves the world.
	c.winter()


## What the stop leaves for the summer: a house's asks are put before him
## (if the spring did not draw them already), an attack on the hall is a
## fight at his own door.
static func _after_stop(j: Journey, stop: Dictionary) -> void:
	var c := j.c
	match str(stop.get("kind", "")):
		"house":
			var have := {}
			for d in j.decisions:
				if str(d.kind) == "house":
					have[str(d.house)] = true
			for d in stop.asks:
				if not have.has(str(d.house)):
					j.decisions.append(d)
		"attack":
			var wr := c.world_rules
			var fam := str(stop.family)
			var level := int(stop.level)
			j._offer_fight("feud_ambush", wr.feud_tier, Sandbox._forced(c, wr.feud_ambush_men + (wr.hired_blades if level >= 3 else 0)), false,
					wr.feud_stat_base + level - 1, false, true, {"kind": "feud", "family": fam},
					"%s come against the hall at %s." % [fam, j.whereabouts()], true)
