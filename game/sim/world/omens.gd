class_name Omens
extends RefCounted
## Omens and the seer (concept.md: "belief shows up as omens and luck").
## Before this `Leader.on_omen_ignored` had no caller.
##
## A spring may bring an omen as the band goes out (a raven on the right
## hand, a stumble at the threshold, a dream told by the wife or an old man
## in the hall), and a raid may (a fetch walking before the band, an eagle
## over it): each a short decision (kind "omen"). Heeding an ill omen costs
## days, silver or the raid itself, and keeps the men's nerve; ignoring it
## goes on, and the omen may come true (Leader.on_omen_ignored: luck), and
## the men are uneasy (loyalty). A good omen heeded is luck and heart.
## Another package wires luck into the battle's morale; here luck and the
## men's goodwill move, and the chronicle says so.
##
## A seer (völva) may come to the hall in winter; asked, for a price, she
## tells true of the year ahead: the year's fate is drawn from the seed
## whether she is asked or not (`fate`), an early winter, a farm the
## raiders will burn, a house's men out on the roads after the band, and
## the spring makes it so (`spring`).

const SPRING := [
	{"id": "raven", "good": true, "text": "As %s goes down to the ships a raven flies up on his right hand and goes before him over the water.",
		"heed": "Go at once, while the sign holds", "ignore": "Pay it no heed"},
	{"id": "stumble", "good": false, "text": "%s stumbles on the threshold as he goes out, and falls to his knee. The old men look at one another.",
		"heed": "Stay %d days, and go out again", "ignore": "Laugh, and go on"},
	{"id": "dream", "good": false, "text": "%s is told a dream in the night: wolves at the ship's prow, and the sea red under them.",
		"heed": "Make a sacrifice (%d oz)", "ignore": "Dreams are dreams"},
]
const RAID := [
	{"id": "fetch", "good": false, "text": "On the eve of the raid a man of the band sees a woman in a bloody kirtle walking before you on the road, and the men grow quiet.",
		"heed": "Turn back from it", "ignore": "Go on"},
	{"id": "eagle", "good": true, "text": "An eagle comes down the wind and circles over the band before the raid, and goes the way you go.",
		"heed": "Go in at once, with the sign", "ignore": "Pay it no heed"},
]


## The leader's luck in words, wherever it is shown.
static func luck_words(luck: int) -> String:
	if luck >= 8:
		return "the gods are with him"
	if luck >= 6:
		return "his luck is good"
	if luck >= 4:
		return "his luck holds"
	if luck >= 2:
		return "his luck runs thin"
	return "his luck has left him"


# --- The omens --------------------------------------------------------------------------

## The spring's omen, now and then; and the fate the seer told of, made so.
static func spring(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	_fate_comes(j)
	if j.first_summer():
		return  # the first days are the burning's and the king's word: no dream on top of them
	var r := Landtake.fork(j, "omen")
	if r.randf() >= wr.spring_omen_chance:
		return
	var o: Dictionary = SPRING[r.randi_range(0, SPRING.size() - 1)]
	var who := band.leader.display_name
	var text := str(o.text) % who
	if str(o.id) == "dream":
		text = ("%s's wife tells him of a dream: wolves at the ship's prow, and the sea red under them." % who) if band.wife != "" \
				else "An old man in the hall tells %s of a dream: wolves at the ship's prow, and the sea red under them." % who
	j.decisions.append(_decision(j, o, text, "spring"))


## A raid about to be fought: an omen, now and then, before the fight's
## own choice.
static func before_raid(j: Journey) -> void:
	var r := Landtake.fork(j, "raid_omen")
	if r.randf() >= j.c.world_rules.raid_omen_chance:
		return
	var o: Dictionary = RAID[r.randi_range(0, RAID.size() - 1)]
	j.decisions.push_front(_decision(j, o, str(o.text), "raid"))


static func _decision(j: Journey, o: Dictionary, text: String, when: String) -> Dictionary:
	var wr := j.c.world_rules
	var heed := str(o.heed)
	var hint := ""
	match str(o.id):
		"stumble":
			heed = heed % wr.omen_wait_days
			hint = "%d days lost; the men go out easy in their minds." % wr.omen_wait_days
		"dream":
			heed = heed % wr.sacrifice_ounces
			hint = "Silver to the gods; the men go out easy in their minds."
		"fetch":
			hint = "The raid is not made this year."
		_:
			hint = "Luck and heart for the band."
	var ignore_hint := "It may come true: luck, and the men uneasy." if not bool(o.good) else "Nothing lost, nothing gained."
	return {"kind": "omen", "step": when, "omen": str(o.id), "good": bool(o.good), "title": "An omen",
			"text": text, "detail": "Luck: %s." % luck_words(j.c.band.luck),
			"options": [{"id": "heed", "label": heed, "hint": hint, "enabled": str(o.id) != "dream" or j.c.band.silver >= wr.sacrifice_ounces},
				{"id": "ignore", "label": str(o.ignore), "hint": ignore_hint}]}


static func answer(j: Journey, d: Dictionary, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var cr := j.c.rules
	var who := band.leader.display_name
	var good := bool(d.good)
	if id == "heed":
		match str(d.omen):
			"stumble":
				j._pass(float(wr.omen_wait_days))
				j._say("%s stays %d days, and goes out again with the old men's blessing." % [who, wr.omen_wait_days])
			"dream":
				band.silver -= mini(wr.sacrifice_ounces, band.silver)
				j._say("%s makes a sacrifice of %d oz, and the dream is turned." % [who, wr.sacrifice_ounces])
			"fetch":
				if not j.decisions.is_empty() and str(j.decisions[0].kind) == "fight" and str((j.decisions[0].ctx as Dictionary).get("kind", "")) == "raid":
					j.decisions.pop_front()
				j._say("%s turns back from the raid, and no man of his says a word against it." % who)
				j._pass(1.0)
			_:
				band.luck = clampi(band.luck + 1, Leader.LUCK_MIN, Leader.LUCK_MAX)
				j._say("%s goes with the sign, and the men take heart from it." % who)
		for m in band.living_men():
			Loyalty.adjust(m, 1 if not good else wr.omen_nerve)
		band.log("%s heeded an omen" % who)
		return
	if good:
		j._say("%s pays the sign no heed." % who)
		return
	var log := PackedStringArray()
	var before := band.luck
	Leader.on_omen_ignored(Landtake.fork(j, "omen_true"), cr, band, log)
	for line in log:
		j._say(Journey._cap(line) + ".")
		band.log(line)
	if band.luck < before:
		for m in band.living_men():
			Loyalty.adjust(m, -wr.omen_nerve)
		j._say("The men are uneasy, and say the omen was plain enough.")


# --- The fate of the year, and the seer ----------------------------------------------------

## The fate of a year, drawn from the seed alone: whether the winter comes
## early, the farm the raiders will burn, and the house whose men will be
## out after the band (when it has a feud). The same whether the seer is
## asked or not: what she tells is true.
static func fate(j: Journey, year: int) -> Dictionary:
	var r := j.c.rng.fork("fate:%d" % year)
	var wr := j.c.world_rules
	var out := {"year": year, "early": r.randf() < 0.25, "raid_at": "", "hunters": ""}
	var farms: Array[String] = []
	var ids: Array = j.c.world.places.keys()
	ids.sort()
	for id in ids:
		var p: Place = j.c.world.places[id]
		if p.kind == WorldTypes.PlaceKind.FARMSTEAD and Families.HOME_REGIONS.has(p.region) and p.base_wealth >= wr.raid_min_wealth:
			farms.append(id)
	if not farms.is_empty():
		out.raid_at = farms[r.randi_range(0, farms.size() - 1)]
	var feuds := j.c.band.unsettled_feuds()
	if not feuds.is_empty() and r.randf() < 0.6:
		var f: Dictionary = feuds[r.randi_range(0, feuds.size() - 1)]
		out.hunters = str(f.get("family", f.get("against", "")))
	return out


## The days the summer is short this year (an early winter), or 0.
static func short_summer(j: Journey) -> int:
	var key := "fate_early:%d" % j.c.cal.year
	if not j.life.has(key):
		j.life[key] = bool(fate(j, j.c.cal.year).early)
	return j.c.world_rules.early_winter_days if bool(j.life[key]) else 0


## The year's fate made so in the spring: the raiders turn for the farm,
## the house's men go out after the band.
static func _fate_comes(j: Journey) -> void:
	var f := fate(j, j.c.cal.year)
	if str(f.raid_at) != "":
		j.life["fated_raid"] = str(f.raid_at)
		j.life.erase("fated_raid_done")
	var fam := str(f.hunters)
	var fs := j.c.world.families
	if fam != "" and fs != null and fs.houses.has(fam) and not Feud.find(j.c.band, fam).is_empty() and not j.first_summer():
		var sent := false
		for p in j.roam.parties:
			if p.kind == "avengers" and p.family == fam:
				sent = true
		if not sent:
			var h := fs.house(fam)
			if j.roam.add_avengers(j.c.world_rules, j.c.world, fam, h.seat, mini(j.c.world_rules.avenger_men, h.strength), j.c.band.ship != null) != null:
				j._say("Word comes that %s have sent men out to look for you." % fam)


## The summer's first raid falls where the year's fate says: the first
## raider ship to turn for a farm turns for that one instead. No raid is
## added that the world would not have made.
static func tick(j: Journey) -> void:
	var at := str(j.life.get("fated_raid", ""))
	if at == "" or j.life.has("fated_raid_done"):
		return
	var target := j.c.world.place(at)
	for p in j.roam.parties:
		if p.kind != "raiders" or p.strike == "" or p.raiding_until >= 0.0:
			continue
		j.life["fated_raid_done"] = true
		if target != null and p.family != target.family:
			p.strike = at
		return


## The seer's card in the winter hall (WinterHall's talk), now and then.
static func volva_card(j: Journey, r: SimRng) -> Dictionary:
	var wr := j.c.world_rules
	if r.randf() >= wr.volva_chance:
		return {}
	return {"kind": "volva", "text": "A seer comes to the hall, a völva who goes from farm to farm in the dark of the year with her staff and her cloak of lambskin, and is feasted where she comes.",
			"options": [{"id": "ask", "label": "Feast her, and ask what the year holds", "silver": -wr.volva_fee,
				"hint": "What she tells is true."},
				{"id": "feast", "label": "Feast her, and ask nothing", "silver": -wr.volva_fee / 2, "hint": "The men think it well done."},
				{"id": "away", "label": "Send her on her way", "hint": "Some say it is unlucky."}]}


## The seer's card answered (WinterHall.resolve): what she tells of the
## next year, true for the seed.
static func resolve_volva(j: Journey, _card: Dictionary, choice: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	match choice:
		"ask":
			if band.silver < wr.volva_fee:
				return
			band.silver -= wr.volva_fee
			var next := j.c.cal.year + 1
			var f := fate(j, next)
			var told := PackedStringArray()
			if bool(f.early):
				told.append("the winter will come early, before the leaves are down: the summer will be short")
			else:
				told.append("the summer will be long, and the snow late")
			if str(f.raid_at) != "":
				told.append("there will be smoke over %s, and ships drawn up on the strand below it" % j.c.world.place(str(f.raid_at)).display_name)
			if str(f.hunters) != "":
				told.append("men of %s will be on the roads in the spring, asking where you are" % f.hunters)
			band.foretold = {"year": next, "early": bool(f.early), "raid_at": str(f.raid_at), "hunters": str(f.hunters)}
			j._say("The seer is feasted, and sits on her high seat, and tells %s what she sees: %s." % [band.leader.display_name, "; ".join(told)])
			band.log("a seer told %s what the year %d held" % [band.leader.display_name, next])
		"feast":
			band.silver -= mini(wr.volva_fee / 2, band.silver)
			for m in band.living_men():
				Loyalty.adjust(m, 1)
			j._say("The seer is feasted and goes on her way; the men think it well done.")
		_:
			band.luck = clampi(band.luck - (1 if Landtake.fork(j, "volva_away").randf() < 0.3 else 0), Leader.LUCK_MIN, Leader.LUCK_MAX)
			j._say("The seer is sent on her way, and some of the men look after her.")


# --- The stand-in player -------------------------------------------------------------------

## A man of his bent and an omen: the skald and the law-wise heed what
## can be heeded cheaply, the berserk never, the others when the silver or
## the days can be spared.
static func bot(j: Journey, d: Dictionary, bent: int) -> String:
	if bent == Way.Id.BERSERK:
		return "ignore"
	if bool(d.good):
		return "heed"
	if str(d.omen) == "fetch":
		return "heed" if bent == Way.Id.SKALD or bent == Way.Id.LAWMAN else "ignore"
	for o in d.options:
		if str(o.id) == "heed" and o.get("enabled", true):
			return "heed"
	return "ignore"
