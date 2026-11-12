class_name ThingPlay
extends RefCounted
## A case at the Thing as the player pleads it (concept.md, "The Thing
## mini-game"): four short steps through the Journey's decision queue
## (kind "thing"), each showing the counts that matter in words.
##
## 1. *Support.* Who stands with the band and who with the other side (the
##    houses by name, Families.thing_backing; the men under arms on both
##    sides), the houses that stand with neither and what each wants (a
##    gift, a favour promised, a marriage), and the silver laid out for
##    oath-helpers.
## 2. *The law.* Plead it yourself, let a law-wise man of the band speak,
##    or hire the Thing's law-man by name (and keep him, if the silver is
##    there). A flaw in the pleading voids the band's case; the odds are
##    shown. A man who sits through cases beside the pleader learns the
##    law (the "law-wise" trait).
## 3. *The standoff.* Only when the verdict leans against the side with
##    more spears: back down, press (they yield, or it comes to blows: the
##    Thing brawl as before), or ask the house everyone owes to arbitrate.
## 4. *The verdict.* Won: ask wergild (fair: honor), lesser or full
##    outlawry (harsh: their kin resent it along the ties), a marriage to
##    seal the peace, or land; asked beyond what the case carries, it is
##    refused and resented. Lost: pay, defy the verdict and be outlawed, or
##    appeal to the king as his man.
##
## The case in hand is `j.life["case"]`: {tc, how, at, step, spent,
## bought, speaker, slip, their_slip, verdict}. `Thing.run` stays the
## automatic path for the sandbox AI and the old tests.

const STEPS := ["support", "law", "standoff", "verdict"]


# --- Opening a case -----------------------------------------------------------------

## Opens a case at the Thing the band is at. `how`: "" for a feud of the
## band's own (its cause decides who wronged whom), "theft" (the stolen
## ship), "land" (a boundary quarrel), "nid" (a verse taken for níð),
## "summons" (the band answers a house's summons), "speak" (the band speaks
## for `client` against `family`).
static func begin(j: Journey, family: String, how := "", client := "") -> bool:
	var wr := j.c.world_rules
	var band := j.c.band
	if j.life.has("case") or family == "":
		return false
	var kind := WorldTypes.CaseKind.KILLING
	var plaintiff := true
	var claim := Feud.wergild(wr, band.rank)
	var f := Feud.find(band, family)
	match how:
		"":
			if f.is_empty():
				return false
			var cause := str(f.get("cause", ""))
			if cause.contains("theft"):
				how = "theft"
				kind = WorldTypes.CaseKind.RAID
				claim = int(wr.ship_price.get(WorldTypes.ShipKind.KARVE, 60))
			else:
				var wronged := not (cause.begins_with("raid on") or cause.begins_with("strandhögg") or cause.begins_with("robbed"))
				kind = WorldTypes.CaseKind.KILLING if wronged else WorldTypes.CaseKind.RAID
				plaintiff = wronged
		"land":
			kind = WorldTypes.CaseKind.LAND
			claim = wr.land_price
		"nid":
			kind = WorldTypes.CaseKind.INSULT
			plaintiff = false
			claim = 20
		"summons":
			var cause2 := str(f.get("cause", "the killing of their men"))
			kind = WorldTypes.CaseKind.RAID if (cause2.begins_with("raid on") or cause2.begins_with("strandhögg") or cause2.begins_with("robbed")) \
					else WorldTypes.CaseKind.KILLING
			plaintiff = false
		"speak":
			claim = Feud.wergild(wr, WorldTypes.Rank.KARL)
	var tc := Thing.open_case(wr, band, kind, family, claim, plaintiff)
	tc.client = client
	if not f.is_empty():
		tc.victim_rank = int(f.get("rank", wr.default_victim_rank)) as WorldTypes.Rank
	var at := j.here().id if j.here() != null else ""
	j.life["case"] = {"tc": tc, "how": how, "at": at, "step": "support", "spent": 0, "bought": [], "speaker": "self",
			"slip": false, "their_slip": false, "verdict": WorldTypes.Verdict.PENDING, "year": j.c.cal.year}
	_preview(j)
	var pleaded: Dictionary = band.law.get("pleaded", {})
	pleaded[family] = j.c.cal.year
	band.law["pleaded"] = pleaded
	var where := j.here().display_name if j.here() != null else "the Thing"
	if tc.plaintiff_is_band or tc.client != "":
		j._say("At %s %s brings %s." % [where, band.leader.display_name, _case_words(j)])
	else:
		j._say("At %s %s answers %s." % [where, band.leader.display_name, _case_words(j)])
	_push(j, _support_decision(j))
	return true


## The case in words: "the case against X for the killing", etc.
static func _case_words(j: Journey) -> String:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var what: String = {WorldTypes.CaseKind.KILLING: "a killing", WorldTypes.CaseKind.RAID: "a raid", WorldTypes.CaseKind.LAND: "the bounds of land",
			WorldTypes.CaseKind.INSULT: "a verse said to be níð"}.get(tc.kind, "a wrong")
	if str(s.how) == "theft":
		what = "the theft of a ship"
	if tc.client != "":
		return "the case of %s against %s, for %s" % [tc.client, tc.against, what]
	if tc.plaintiff_is_band:
		return "a case against %s, for %s" % [tc.against, what]
	return "the case %s bring against him, for %s" % [tc.against, what]


static func _push(j: Journey, d: Dictionary) -> void:
	j.decisions.push_front(d)


# --- Step 1: support ----------------------------------------------------------------

## The counts as they stand: the houses' backing, the band's own, the other
## side's; set on the case (supporters, their_supporters, houses_with,
## houses_against). Silver laid out is counted, not yet spent.
static func _preview(j: Journey) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var keep := band.silver
	Thing.gather_support(_case_rng(j, "support"), wr, j.c.world, band, tc, 0, PackedStringArray())
	band.silver = keep
	tc.supporters += int(s.spent) / wr.ounces_per_supporter
	for h in s.bought:
		if not tc.houses_with.has(h):
			tc.houses_with.append(h)
			tc.supporters += 1
	tc.their_armed = wr.family_armed_men + 2 * tc.houses_against.size()


## A fork of the case's own: the same draw each time it is asked again, so
## the other side's count does not change while the player chooses.
static func _case_rng(j: Journey, label: String) -> SimRng:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	return j.c.rng.fork("thingplay:%d:%s:%s:%s" % [int(s.year), tc.against, str(s.at), label])


## Houses that stand with neither side and could be won: strangers to the
## band in Norway, not of the other side's kin or friends, not in debt to
## them, and what each wants (by its temper).
static func waverers(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fs := j.c.world.families
	if fs == null or not j.life.has("case"):
		return out
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var thing := j.c.world.place(str(s.at))
	var cands: Array[Dictionary] = []
	for name in fs.names():
		if name == tc.against or name == tc.client or tc.houses_with.has(name) or tc.houses_against.has(name) or (s.bought as Array).has(name):
			continue
		if fs.abroad(name) or Families.support_step(wr, band, name) != "" or Families.is_foe(wr, band, name):
			continue
		var h := fs.house(name)
		var seat := j.c.world.place(h.seat)
		if seat == null or thing == null:
			continue
		cands.append({"house": name, "d": seat.pos.distance_to(thing.pos)})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.d) < float(b.d) or (float(a.d) == float(b.d) and str(a.house) < str(b.house)))
	for c in cands.slice(0, wr.waverers_max):
		var h2 := fs.house(str(c.house))
		var wants := "gift"
		match h2.temper:
			"proud":
				wants = "promise"
			"steadfast":
				wants = "marry" if band.wife == "" else "promise"
			"peaceable":
				wants = "promise"
		out.append({"house": h2.name, "head": h2.head, "wants": wants, "temper": h2.temper})
	return out


static func _support_decision(j: Journey) -> Dictionary:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	_preview(j)
	var ours := band.fighters(j.c.rules).size()
	var lines := PackedStringArray()
	lines.append("With you: %s; %d oath-helpers for %d oz; %d of your men under arms." % [
			_houses_text(tc.houses_with, "no house"), int(s.spent) / wr.ounces_per_supporter, int(s.spent), ours])
	lines.append("With %s: %s; their household, %d under arms." % [tc.against, _houses_text(tc.houses_against, "no house of note"), tc.their_armed])
	lines.append("Supporters: about %d for you, %d for them. Luck: %s." % [tc.supporters, tc.their_supporters, Omens.luck_words(band.luck)])
	var opts: Array[Dictionary] = []
	for w in waverers(j):
		match str(w.wants):
			"gift":
				opts.append({"id": "gift:" + str(w.house), "label": "A gift to %s (%d oz)" % [w.head, wr.gift_ounces], "enabled": band.silver >= wr.gift_ounces,
						"hint": "%s stand with neither side; %s would take silver." % [w.house, w.head]})
			"promise":
				opts.append({"id": "promise:" + str(w.house), "label": "Promise %s a favour" % w.head,
						"hint": "%s stand with neither side. A favour owed is called in next spring: %d oz, or their goodwill." % [w.house, wr.favour_ounces]})
			"marry":
				opts.append({"id": "marry:" + str(w.house), "label": "Marry into %s" % w.house,
						"hint": "%s would stand with a man who took a wife of their house." % w.house})
	var more := _next_spend(wr, int(s.spent))
	if more > 0:
		opts.append({"id": "spend", "label": "Oath-helpers: %d oz more" % (more - int(s.spent)), "enabled": band.silver >= more,
				"hint": "Each %d oz brings a man to swear with you." % wr.ounces_per_supporter})
	opts.append({"id": "go", "label": "Go to the pleading", "hint": "The law-men hear the case."})
	opts.append({"id": "drop", "label": "Let the case drop",
			"hint": "Nothing is spent." if tc.plaintiff_is_band or tc.client != "" else "The Thing judges you without you."})
	return {"kind": "thing", "step": "support", "title": "The Thing: who stands with you",
			"text": "%s. Who stands where:" % Journey._cap(_case_words(j)), "detail": "\n".join(lines), "options": opts}


static func _houses_text(names: Array, none: String) -> String:
	if names.is_empty():
		return none
	return ", ".join(PackedStringArray(names))


static func _next_spend(rules: WorldRules, spent: int) -> int:
	for v in rules.thing_spend_steps:
		if int(v) > spent:
			return int(v)
	return 0


# --- Step 2: the law -------------------------------------------------------------------

## Who may plead: [{id, name, wits, odds, fee}]; odds are in tenths.
static func pleaders(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var diff: int = wr.procedure_difficulty.get(tc.kind, 10)
	var law := int(band.gift("law", 0))
	out.append({"id": "self", "name": band.leader.display_name, "wits": band.leader.stat(CombatTypes.Stat.WITS) + law, "fee": 0, "reroll": false})
	for m in band.living_men():
		if m.traits.has(wr.law_wise_trait):
			out.append({"id": "man:%d" % m.id, "name": m.display_name, "wits": m.stat(CombatTypes.Stat.WITS) + law, "fee": 0, "reroll": false})
	var lm := lawman_name(j)
	if lm != "":
		out.append({"id": "hire", "name": lm, "wits": wr.lawman_wits, "fee": wr.lawman_hire_fee, "reroll": true})
		out.append({"id": "keep", "name": lm, "wits": wr.lawman_wits, "fee": wr.lawman_keep_fee, "reroll": true})
	for o in out:
		var p := chance(int(o.wits), diff)
		if o.reroll:
			p = 1.0 - (1.0 - p) * (1.0 - p)
		o["odds"] = p
	return out


## The law-man who pleads for hire at the Thing the case is at, or "".
static func lawman_name(j: Journey) -> String:
	var s: Dictionary = j.life.case
	var name := str(j.c.world_rules.lawmen.get(str(s.at), ""))
	if name == "":
		return ""
	for m in j.c.band.living_men():
		if m.display_name == name:
			return ""  # he is in the band already
	return name


## The chance Wits + 2d6 reaches `need`.
static func chance(wits: int, need: int) -> float:
	var hits := 0
	for a in range(1, 7):
		for b in range(1, 7):
			if wits + a + b >= need:
				hits += 1
	return float(hits) / 36.0


## A chance in words: "about 7 times in 10".
static func odds_words(p: float) -> String:
	var tenths := clampi(roundi(p * 10.0), 0, 10)
	if tenths >= 10:
		return "all but surely"
	if tenths <= 0:
		return "hardly ever"
	return "about %d times in 10" % tenths


static func _law_decision(j: Journey) -> Dictionary:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var opts: Array[Dictionary] = []
	for o in pleaders(j):
		var label := ""
		var hint := ""
		match str(o.id):
			"self":
				label = "Plead it yourself"
				hint = "Your pleading holds %s." % odds_words(float(o.odds))
			"hire":
				label = "Hire %s (%d oz)" % [o.name, int(o.fee)]
				hint = "The law-man of this Thing; his pleading holds %s, and he mends one slip." % odds_words(float(o.odds))
			"keep":
				label = "Take %s into your band (%d oz)" % [o.name, int(o.fee)]
				hint = "He pleads this case and stays with you after, a law-wise man of your own."
			_:
				label = "Let %s plead" % o.name
				hint = "He knows the law; his pleading holds %s." % odds_words(float(o.odds))
		opts.append({"id": str(o.id), "label": label, "hint": hint, "enabled": band.silver >= int(o.fee)})
	var detail := "A flaw in the summons or the pleading voids a case, however strong. %s bring %d supporters, you %d." % [
			Journey._cap(tc.against), tc.their_supporters, tc.supporters]
	return {"kind": "thing", "step": "law", "title": "The Thing: the law", "text": "Who will plead %s?" % _case_words(j),
			"detail": detail, "options": opts}


## The pleading: the speaker's Wits and 2d6 against the case's difficulty
## (a hired law-man mends one slip); the other side's law-man pleads too.
static func _plead(j: Journey, who: String) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var pick := {}
	for o in pleaders(j):
		if str(o.id) == who:
			pick = o
	if pick.is_empty():
		pick = pleaders(j)[0]
	band.silver -= mini(int(pick.fee), band.silver)
	var name := str(pick.name)
	if str(pick.id) == "keep":
		_keep_lawman(j, name)
	if str(pick.id) == "hire" or str(pick.id) == "keep":
		tc.lawman_hired = true
	s.speaker = str(pick.id)
	var diff: int = wr.procedure_difficulty.get(tc.kind, 10)
	var r := _case_rng(j, "plead")
	var roll := int(pick.wits) + r.roll_2d6()
	if roll < diff and bool(pick.reroll):
		j._say("A step of %s's pleading goes wrong (%d against %d), and he mends it." % [name, roll, diff])
		roll = int(pick.wits) + r.roll_2d6()
	tc.procedure_ok = roll >= diff
	s.slip = not tc.procedure_ok
	if tc.procedure_ok:
		j._say("%s pleads, and the pleading holds (%d against %d)." % [name, roll, diff])
	else:
		j._say("%s pleads, but there is a flaw in it (%d against %d): the law-men will not hear the band's side." % [name, roll, diff])
	# The other side pleads too: their slip is the band's gain.
	var theirs := 5 + r.roll_2d6()
	s.their_slip = theirs < diff
	if s.their_slip:
		j._say("%s's pleading has a flaw of its own (%d against %d), and the law-men take note of it." % [tc.against, theirs, diff])
	_sat_through(j, str(pick.id))


## The law-man stays with the band: a man of the law, law-wise.
static func _keep_lawman(j: Journey, name: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var m := Recruits.make(_case_rng(j, "lawman"), j.c.rules, CampaignTypes.Origin.EXILED_JARLS_SON, 38, name, band.next_id())
	m.set_stat(CombatTypes.Stat.WITS, wr.lawman_wits)
	m.potential[CombatTypes.Stat.WITS] = maxi(m.potential[CombatTypes.Stat.WITS], wr.lawman_wits)
	m.traits.append(wr.law_wise_trait)
	m.loyalty = 60
	band.add_man(m)
	j.c._arm_new_men()
	j._say("%s takes %s into his band: a man who knows the law." % [band.leader.display_name, name])
	band.log("%s took %s the law-man into his band" % [band.leader.display_name, name])


## The band's best Wits after the pleader sits through the case; after
## `law_sat_cases` of them he knows the law.
static func _sat_through(j: Journey, speaker: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var best: Man = null
	for m in band.living_men():
		if m.traits.has(wr.law_wise_trait) or speaker == "man:%d" % m.id:
			continue
		if best == null or m.stat(CombatTypes.Stat.WITS) > best.stat(CombatTypes.Stat.WITS) \
				or (m.stat(CombatTypes.Stat.WITS) == best.stat(CombatTypes.Stat.WITS) and m.id < best.id):
			best = m
	if best == null:
		return
	var sat: Dictionary = band.law.get("sat", {})
	sat[best.id] = int(sat.get(best.id, 0)) + 1
	band.law["sat"] = sat
	if int(sat[best.id]) >= wr.law_sat_cases:
		best.traits.append(wr.law_wise_trait)
		sat.erase(best.id)
		j._say("%s has sat through enough cases beside %s to know the law himself: he is law-wise now." % [best.display_name, band.leader.display_name])
		band.log("%s learned the law at the Thing" % best.display_name)


# --- Step 3: the standoff -------------------------------------------------------------

## The weights, and which way the verdict leans: {us, them, ratio,
## for_band, ours, theirs (spears)}.
static func weigh(j: Journey) -> Dictionary:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var ours := j.c.band.fighters(j.c.rules).size()
	tc.weight_us = tc.supporters + ours * wr.arms_weight
	tc.weight_them = tc.their_supporters + tc.their_armed * wr.arms_weight
	var p_weight := tc.weight_us if tc.plaintiff_is_band else tc.weight_them
	var d_weight := tc.weight_them if tc.plaintiff_is_band else tc.weight_us
	var ratio := p_weight / maxf(d_weight, 0.5)
	if bool(s.slip) and tc.plaintiff_is_band:
		ratio = 0.0
	elif bool(s.slip):
		ratio = maxf(ratio, wr.win_ratio)  # the band's defence is not heard
	if bool(s.their_slip) and not bool(s.slip):
		ratio = maxf(ratio, wr.win_ratio) if tc.plaintiff_is_band else minf(ratio, wr.win_ratio - 0.01)
	var for_band := ratio >= wr.win_ratio if tc.plaintiff_is_band else ratio < wr.win_ratio
	return {"us": tc.weight_us, "them": tc.weight_them, "ratio": ratio, "for_band": for_band, "ours": ours, "theirs": tc.their_armed}


## Whether the verdict leans against the side with more spears: then
## there is a standoff to play.
static func standoff_due(j: Journey) -> bool:
	var w := weigh(j)
	var s: Dictionary = j.life.case
	if bool(s.slip) and (s.tc as ThingCase).plaintiff_is_band:
		return false  # a case thrown out is not stood over
	return (bool(w.for_band) and int(w.theirs) > int(w.ours)) or (not bool(w.for_band) and int(w.ours) > int(w.theirs))


## The chance the weaker side gives way when pressed.
static func yield_chance(rules: WorldRules, strong: int, weak: int) -> float:
	return clampf(rules.press_yield_base + float(strong - weak) / float(maxi(1, weak)) * 0.5, 0.1, 0.85)


static func _arbiter_ok(j: Journey) -> bool:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var fs := j.c.world.families
	var a := wr.arbiter_house
	return fs != null and fs.houses.has(a) and a != tc.against and a != tc.client and not Families.is_foe(wr, j.c.band, a)


static func _standoff_decision(j: Journey) -> Dictionary:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var w := weigh(j)
	var ours := int(w.ours)
	var theirs := int(w.theirs)
	var opts: Array[Dictionary] = []
	var text := ""
	if bool(w.for_band):
		text = "The law-men lean your way, but %s have %d spears at the Thing to your %d, and their hands are on them." % [tc.against, theirs, ours]
		opts.append({"id": "firm", "label": "Stand on the verdict",
				"hint": "They draw weapons %s; else they take the verdict." % odds_words(yield_chance(wr, theirs, ours))})
		opts.append({"id": "yield", "label": "Let it go, for the peace", "hint": "The case is dropped; nobody is outlawed, nothing is paid."})
	else:
		text = "The law-men lean to %s, but you have %d spears at the Thing to their %d." % [tc.against, ours, theirs]
		opts.append({"id": "back", "label": "Back down", "hint": "Let the law-men give their verdict."})
		opts.append({"id": "press", "label": "Press them with your spears",
				"hint": "They give way %s; else it comes to blows. Overbearing at the Thing: honor -%d." % [odds_words(yield_chance(wr, ours, theirs)), wr.press_honor]})
	if _arbiter_ok(j):
		var h := j.c.world.families.house(wr.arbiter_house)
		opts.append({"id": "arbiter", "label": "Ask %s to arbitrate (%d oz)" % [h.head, wr.arbiter_fee], "enabled": j.c.band.silver >= wr.arbiter_fee,
				"hint": "%s, whom every house owes, would make a settlement: half the wergild, nobody outlawed." % wr.arbiter_house})
	var detail := "Weight of the case: %.0f for you, %.0f for them (supporters and spears)." % [float(w.us), float(w.them)]
	return {"kind": "thing", "step": "standoff", "title": "The Thing: the standoff", "text": text, "detail": detail, "options": opts}


# --- Step 4: the verdict ---------------------------------------------------------------

## What the band may ask when the verdict is its own: [{id, label, need,
## hint}], `need` the weight ratio it takes.
static func asks(j: Journey) -> Array[Dictionary]:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var out: Array[Dictionary] = []
	var gild := _wergild(j)
	var whose := ("for %s " % tc.client) if tc.client != "" else ""
	out.append({"id": "wergild", "label": "Wergild %s(%d oz)" % [whose, gild], "need": wr.win_ratio,
			"hint": "A fair verdict: men think the better of you for it."})
	if tc.kind == WorldTypes.CaseKind.KILLING or tc.kind == WorldTypes.CaseKind.RAID:
		out.append({"id": "lesser", "label": "Lesser outlawry for them", "need": wr.lesser_outlawry_ratio,
				"hint": "Three years out of Norway for the men who did it. Their kin will resent it."})
		out.append({"id": "full", "label": "Full outlawry", "need": wr.full_outlawry_ratio,
				"hint": "Any man may kill them. Their kin and friends will not forget it."})
	var fs := j.c.world.families
	if tc.client == "" and band.wife == "" and fs != null and fs.houses.has(tc.against) and not fs.abroad(tc.against):
		out.append({"id": "marry", "label": "A marriage to seal the peace", "need": wr.win_ratio,
				"hint": "A daughter of %s for your wife: the feud ends in a tie of kin." % tc.against})
	if tc.client == "" and (tc.kind == WorldTypes.CaseKind.LAND or tc.kind == WorldTypes.CaseKind.KILLING) and Landtake.house_land(j, tc.against) != "":
		out.append({"id": "land", "label": "Land of theirs (%d)" % wr.claim_units, "need": wr.lesser_outlawry_ratio if tc.kind != WorldTypes.CaseKind.LAND else wr.win_ratio,
				"hint": "A steading of theirs at %s for your own." % j.c.world.place(Landtake.house_land(j, tc.against)).display_name})
	return out


static func _wergild(j: Journey) -> int:
	var tc: ThingCase = j.life.case.tc
	var wr := j.c.world_rules
	return Feud.wergild(wr, tc.victim_rank) if tc.kind == WorldTypes.CaseKind.KILLING else tc.claim


static func _verdict_decision(j: Journey) -> Dictionary:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var w := weigh(j)
	var opts: Array[Dictionary] = []
	var text := ""
	var detail := "Weight of the case: %.0f for you, %.0f for them." % [float(w.us), float(w.them)]
	if bool(w.for_band) and (tc.plaintiff_is_band or tc.client != ""):
		text = "The law-men find for %s. What will you ask of %s?" % [tc.client if tc.client != "" else "you", tc.against]
		for a in asks(j):
			var carried := float(w.ratio) >= float(a.need)
			opts.append({"id": str(a.id), "label": str(a.label),
					"hint": str(a.hint) + ("" if carried else " The case will not carry so much: it would be refused, and resented.")})
		detail += " The weight carries wergild%s." % (", and outlawry" if float(w.ratio) >= wr.lesser_outlawry_ratio else "")
	elif bool(w.for_band):
		text = "The law-men find for you: %s's case against you fails." % tc.against
		opts.append({"id": "accept", "label": "Go home from the Thing", "hint": "They have nothing of you."})
	elif tc.plaintiff_is_band or tc.client != "":
		text = "The law-men find against %s: the case fails%s." % ["you" if tc.client == "" else tc.client, ", for a flaw in the pleading" if bool(s.slip) else ""]
		opts.append({"id": "accept", "label": "So be it", "hint": "The matter goes back to the sword." if tc.client == "" else "The houses' feud goes on."})
	else:
		var v := _against_band(j, float(w.ratio))
		s.verdict = v
		var gild := _wergild(j)
		match v:
			WorldTypes.Verdict.COMPENSATION:
				text = "The law-men find for %s: you are to pay %d oz." % [tc.against, gild]
				opts.append({"id": "pay", "label": "Pay %d oz" % gild, "hint": "The matter is ended." if band.silver >= gild else "You have %d; the rest is owed." % band.silver})
			_:
				text = "The law-men find for %s: you are %s." % [tc.against, "a full outlaw" if v == WorldTypes.Verdict.FULL_OUTLAWRY else "outlawed for three years"]
				opts.append({"id": "pay", "label": "Bow to the verdict",
						"hint": "Out of Norway by the winter, three years." if v == WorldTypes.Verdict.LESSER_OUTLAWRY else "Any man may kill you in Norway."})
		opts.append({"id": "defy", "label": "Defy the verdict", "hint": "Pay nothing, go nowhere: a full outlaw in Norway."})
		var king := _king(j)
		if king != null:
			opts.append({"id": "appeal", "label": "Appeal to %s (%d oz)" % [king.leader, wr.appeal_ounces], "enabled": band.silver >= wr.appeal_ounces,
					"hint": "As his man you may: outlawry becomes wergild, wergild is halved. It costs you some of his regard."})
	return {"kind": "thing", "step": "verdict", "title": "The Thing: the verdict", "text": text, "detail": detail, "options": opts}


## The verdict on the band as defendant, by the weight against it.
static func _against_band(j: Journey, ratio: float) -> WorldTypes.Verdict:
	var tc: ThingCase = j.life.case.tc
	return Thing._verdict_for(j.c.world_rules, tc.kind, ratio)


## The king the band may appeal to: the king who rules the Thing's land,
## when the band is his man (his regard at `appeal_relation` or more).
static func _king(j: Journey) -> Faction:
	var s: Dictionary = j.life.case
	var f := FactionAI.ruler_of(j.c.world, str(s.at))
	if f == null or not f.alive or f.kind != WorldTypes.FactionKind.KING:
		return null
	if FactionAI.relation(j.c.world, f.id, FactionAI.BAND) < j.c.world_rules.appeal_relation:
		return null
	return f


# --- Answering ------------------------------------------------------------------------

static func answer(j: Journey, d: Dictionary, id: String) -> void:
	if not j.life.has("case"):
		return
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var fs := j.c.world.families
	match str(d.step):
		"support":
			if id.begins_with("gift:") and fs != null:
				var h := id.trim_prefix("gift:")
				if fs.give_gift(wr, j.c.world, band, h, j.said) > 0:
					s.bought.append(h)
			elif id.begins_with("promise:"):
				var h2 := id.trim_prefix("promise:")
				var owed: Dictionary = band.law.get("owed", {})
				owed[h2] = j.c.cal.year
				band.law["owed"] = owed
				s.bought.append(h2)
				j._say("%s promises %s a favour, and they stand with him." % [band.leader.display_name, h2])
			elif id.begins_with("marry:") and fs != null:
				var h3 := id.trim_prefix("marry:")
				var bride: String = NorwayData.HOUSE_WOMEN[_case_rng(j, "bride").randi_range(0, NorwayData.HOUSE_WOMEN.size() - 1)]
				fs.marry_into(wr, j.c.rules, _case_rng(j, "marry"), band, h3, bride, j.said)
				s.bought.append(h3)
			elif id == "spend":
				var next := _next_spend(wr, int(s.spent))
				if next > 0 and band.silver >= next:
					s.spent = next
			elif id == "drop":
				_drop(j)
				return
			elif id == "go":
				var spent := mini(int(s.spent), band.silver)
				band.silver -= spent
				if spent > 0:
					j._say("%s lays out %d oz, and %s swear with him." % [band.leader.display_name, spent, "a man" if spent / wr.ounces_per_supporter == 1 else "%d men" % (spent / wr.ounces_per_supporter)])
				_preview(j)
				_push(j, _law_decision(j))
				return
			_push(j, _support_decision(j))
		"law":
			_plead(j, id)
			if standoff_due(j):
				_push(j, _standoff_decision(j))
			else:
				_push(j, _verdict_decision(j))
		"standoff":
			_standoff(j, id)
		"verdict":
			_verdict(j, id)


## The standoff answered.
static func _standoff(j: Journey, id: String) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var w := weigh(j)
	var r := _case_rng(j, "standoff")
	match id:
		"press":
			band.honor = clampi(band.honor - wr.press_honor, 0, 100)
			if r.randf() < yield_chance(wr, int(w.ours), int(w.theirs)):
				j._say("%s and his men stand close with their spears, and %s give way: the law-men find for him." % [band.leader.display_name, tc.against])
				s.their_slip = true
				s.slip = false
				_push(j, _verdict_decision(j))
			else:
				_brawl(j, true)
		"firm":
			if r.randf() < yield_chance(wr, int(w.theirs), int(w.ours)):
				_brawl(j, false)
			else:
				j._say("%s mutter over their spears, and take the verdict." % tc.against)
				_push(j, _verdict_decision(j))
		"arbiter":
			_arbitrate(j)
		"yield":
			j._say("%s lets the case go for the peace of the Thing." % band.leader.display_name)
			_close(j, "dropped")
		_:
			_push(j, _verdict_decision(j))


## Weapons drawn at the Thing: the brawl is fought (Journey's fight), and
## the case comes to nothing: the matter goes to the sword.
static func _brawl(j: Journey, band_struck: bool) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var text := "Weapons are drawn at the Thing and the band strikes first: a grave crime." if band_struck \
			else "Weapons are drawn at the Thing; %s strike first." % tc.against
	if band_struck:
		j.c.band.honor = clampi(j.c.band.honor - wr.thing_violence_honor, 0, 100)
	tc.violence = true
	tc.battle_required = {"kind": "thing_brawl", "attackers": tc.their_armed, "tier": wr.thing_brawl_tier, "text": text, "family": tc.against}
	j._say(text)
	var family := tc.against
	_close(j, "brawl")
	if tc.client == "" and Feud.find(j.c.band, family).is_empty():
		var seat := Thing.family_seat(j.c.world, family)
		Feud.start(wr, j.c.band, family, "blood shed at the Thing", seat.id if seat != null else "", j.said)
	j._offer_fight("thing brawl", wr.thing_brawl_tier, Sandbox._forced(j.c, tc.their_armed), false, wr.sea_fight_stat,
			false, true, {"kind": "thing", "family": family}, text, true)


## The house everybody owes makes a settlement: half the wergild from
## whoever the verdict leaned against, nobody outlawed.
static func _arbitrate(j: Journey) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	band.silver -= mini(wr.arbiter_fee, band.silver)
	var w := weigh(j)
	var gild := roundi(_wergild(j) * wr.arbitration_share)
	if tc.client != "":
		j._say("%s make a settlement between %s and %s, and nobody is outlawed." % [wr.arbiter_house, tc.client, tc.against])
	elif bool(w.for_band) and tc.plaintiff_is_band:
		band.silver += gild
		j._say("%s make a settlement: %s pay %d oz, and nobody is outlawed." % [wr.arbiter_house, tc.against, gild])
	elif not bool(w.for_band) and not tc.plaintiff_is_band:
		var paid := mini(gild, band.silver)
		band.silver -= paid
		j._say("%s make a settlement: %s pays %s %d oz, and nobody is outlawed." % [wr.arbiter_house, band.leader.display_name, tc.against, paid])
	else:
		j._say("%s make a settlement between the sides: nothing is paid, and nobody is outlawed." % wr.arbiter_house)
	j._shift(wr.arbiter_house, 5)
	band.honor = clampi(band.honor + 1, 0, 100)
	if tc.client != "" and j.c.world.families != null:
		j.c.world.families.settle_between(tc.client, tc.against)
	_settle_feud(j, "settled by arbitration")
	Way.add_deed(band, Way.Id.LAWMAN, wr.deed_settle)
	_close(j, "arbitrated")


## The verdict answered.
static func _verdict(j: Journey, id: String) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var fs := j.c.world.families
	var w := weigh(j)
	var who := band.leader.display_name
	if bool(w.for_band) and (tc.plaintiff_is_band or tc.client != "") and id != "accept":
		var pick := {}
		for a in asks(j):
			if str(a.id) == id:
				pick = a
		if pick.is_empty():
			pick = asks(j)[0]
		var chosen := str(pick.id)
		if float(w.ratio) < float(pick.need):
			j._say("The law-men will not give so much as %s asks; they award wergild, and %s take the asking ill." % [who, tc.against])
			j._shift(tc.against, wr.overreach_standing)
			chosen = "wergild"
		_grant(j, chosen)
		Way.add_deed(band, Way.Id.LAWMAN, wr.deed_case)
		_close(j, chosen)
		return
	if bool(w.for_band):
		j._say("The case of %s against %s fails at the Thing." % [tc.against, who])
		Way.add_deed(band, Way.Id.LAWMAN, wr.deed_case)
		if tc.client == "" and not tc.plaintiff_is_band:
			_settle_feud(j, "their case failed")
		_close(j, "won")
		return
	if tc.plaintiff_is_band or tc.client != "":
		if tc.client != "":
			j._say("The case of %s against %s fails, and the feud between them goes on." % [tc.client, tc.against])
			j._shift(tc.client, wr.standing_refused)
		else:
			j._say("The case fails: the matter goes to the sword.")
			var seat := Thing.family_seat(j.c.world, tc.against)
			if Feud.find(band, tc.against).is_empty():
				Feud.start(wr, band, tc.against, "a failed case at the Thing", seat.id if seat != null else "", j.said)
		_close(j, "failed")
		return
	# The verdict went against the band.
	var v: WorldTypes.Verdict = s.verdict
	var gild := _wergild(j)
	match id:
		"pay":
			if v == WorldTypes.Verdict.COMPENSATION:
				var paid := mini(gild, band.silver)
				band.silver -= paid
				j._say("%s pays %s %d oz, as the Thing found." % [who, tc.against, paid])
				_settle_feud(j, "wergild paid at the Thing")
			else:
				Outlawry.declare(wr, band, j.c.cal, v == WorldTypes.Verdict.FULL_OUTLAWRY, j.said)
				_settle_feud(j, "outlawry")
		"appeal":
			var king := _king(j)
			band.silver -= mini(wr.appeal_ounces, band.silver)
			if king != null:
				FactionAI.shift(j.c.world, king.id, FactionAI.BAND, -wr.appeal_relation_cost)
			var due := gild if v != WorldTypes.Verdict.COMPENSATION else gild / 2
			var paid2 := mini(due, band.silver)
			band.silver -= paid2
			j._say("%s turns the verdict for his man: %s pays %s %d oz, and is no outlaw." % [king.leader if king != null else "The king", who, tc.against, paid2])
			_settle_feud(j, "the king's judgement")
		_:
			j._say("%s will not bow to the Thing. He is a full outlaw in Norway now." % who)
			band.honor = clampi(band.honor - 5, 0, 100)
			Outlawry.declare(wr, band, j.c.cal, true, j.said)
	_close(j, "lost")


## What the band asked, given: wergild (fair), outlawry (harsh: the other
## house's kin resent it), a marriage, land.
static func _grant(j: Journey, chosen: String) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	var wr := j.c.world_rules
	var band := j.c.band
	var fs := j.c.world.families
	var who := band.leader.display_name
	var gild := _wergild(j)
	match chosen:
		"wergild":
			if tc.client != "":
				j._say("The Thing awards %s %d oz from %s, and the law-men make a settlement between them." % [tc.client, gild, tc.against])
			else:
				band.silver += gild
				j._say("The Thing awards %s %d oz from %s: a fair verdict, and men say so." % [who, gild, tc.against])
			band.honor = clampi(band.honor + wr.fair_verdict_honor, 0, 100)
			j._shift(tc.against, wr.standing_case_against / 2)
		"lesser", "full":
			var full := chosen == "full"
			j._say("The Thing declares the men of %s who did it %s." % [tc.against, "full outlaws: any man may kill them" if full else "outlawed for three years"])
			j._shift(tc.against, wr.standing_case_against + wr.harsh_verdict_standing * (2 if full else 1))
			if fs != null and fs.houses.has(tc.against):
				var h := fs.house(tc.against)
				h.strength = maxi(3, h.strength - (4 if full else 2))
			band.fame = clampi(band.fame + (3 if full else 2), 0, 100)
		"marry":
			if fs != null:
				var bride: String = NorwayData.HOUSE_WOMEN[_case_rng(j, "bride").randi_range(0, NorwayData.HOUSE_WOMEN.size() - 1)]
				fs.marry_into(wr, j.c.rules, _case_rng(j, "marry"), band, tc.against, bride, j.said)
			band.honor = clampi(band.honor + 2, 0, 100)
			j._say("%s takes a wife of %s to seal the peace between the houses." % [who, tc.against])
		"land":
			var at := Landtake.house_land(j, tc.against)
			if at != "":
				Landtake.grant(j, at, wr.claim_units, "won at the Thing from %s" % tc.against)
			j._shift(tc.against, wr.standing_case_against)
	if tc.client != "" and fs != null:
		fs.settle_between(tc.client, tc.against)
		j._shift(tc.client, wr.standing_case_for)
	else:
		_settle_feud(j, "settled at the Thing: %s" % chosen)


## The band's own feud with the other side is ended by the case.
static func _settle_feud(j: Journey, how: String) -> void:
	var tc: ThingCase = j.life.case.tc
	if tc.client != "":
		return
	var f := Feud.find(j.c.band, tc.against)
	if f.is_empty():
		return
	f["settled"] = true
	f["verdict"] = how
	j.c.band.log("the matter with %s was settled at the Thing: %s" % [tc.against, how])


## The case dropped before it was heard: a summons not answered is judged
## without the band (Outlawry follows in the winter: `judge_absent`).
static func _drop(j: Journey) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	j._say("%s lets the case against %s drop." % [j.c.band.leader.display_name, tc.against] if tc.plaintiff_is_band or tc.client != "" \
			else "%s will not stay to answer %s at the Thing." % [j.c.band.leader.display_name, tc.against])
	j.life.erase("case")


## The case is over: the days it took, the tally.
static func _close(j: Journey, how: String) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	j.life.erase("case")
	var summons: Dictionary = j.c.band.law.get("summons", {})
	summons.erase(tc.against)
	j.c.band.law["summons"] = summons
	var land_case: Dictionary = j.c.band.law.get("land_case", {})
	land_case.erase(tc.against)
	j.c.band.law["land_case"] = land_case
	j.c.tally.thing_cases = int(j.c.tally.get("thing_cases", 0)) + 1
	j.c.band.law["cases"] = int(j.c.band.law.get("cases", 0)) + 1
	tc.note("closed: %s" % how)
	j._pass(float(j.c.world_rules.thing_days))


# --- The spring: summons, favours called in -----------------------------------------------

## The houses the band has wronged may summon it to the Thing; a skald's
## verse may be taken for níð; a favour promised for a case is called in.
static func spring(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var fs := j.c.world.families
	var r := Landtake.fork(j, "summons")
	if Outlawry.is_outlawed(band, j.c.cal):
		return
	var summons: Dictionary = band.law.get("summons", {})
	for f in band.unsettled_feuds():
		var fam := str(f.get("family", f.get("against", "")))
		var cause := str(f.get("cause", ""))
		var wrongdoer := cause.begins_with("raid on") or cause.begins_with("strandhögg") or cause.begins_with("robbed") \
				or cause.contains("killing of their men") or cause.begins_with("holmgang")
		if not wrongdoer or summons.has(fam) or fam == band.vengeance or fs == null or not fs.houses.has(fam) or fs.abroad(fam):
			continue
		if r.randf() < wr.summons_chance:
			_summons(j, fam, "%s summon %s to the Thing for %s." % [fam, band.leader.display_name, cause])
			break
	if Way.rank(band, Way.Id.SKALD) >= 1 and fs != null:
		for pid in band.versed:
			var p := j.c.world.place(str(pid))
			if p == null or p.family == "" or not Families.is_foe(wr, band, p.family) or summons.has(p.family) or fs.abroad(p.family):
				continue
			if r.randf() < wr.nid_chance:
				band.law["nid"] = p.family
				_summons(j, p.family, "%s say the verse %s made in their hall at %s was níð, and summon him to the Thing for it." % [
						p.family, band.leader.display_name, p.display_name])
				break
	var owed: Dictionary = band.law.get("owed", {})
	for h in owed.keys():
		if int(owed[h]) < j.c.cal.year:
			j.decisions.append({"kind": "thing", "step": "favour", "house": h,
					"text": "%s send word: you promised them a favour for standing with you at the Thing. They ask %d oz of silver." % [h, wr.favour_ounces],
					"options": [{"id": "pay", "label": "Pay %d oz" % wr.favour_ounces, "enabled": band.silver >= wr.favour_ounces},
						{"id": "refuse", "label": "Put them off", "hint": "Standing %d." % wr.favour_refused_standing}]})
			owed.erase(h)
			break


static func _summons(j: Journey, family: String, text: String) -> void:
	var thing := Sandbox.nearest_thing(j.c)
	j.decisions.append({"kind": "thing", "step": "summons", "house": family,
			"text": text + " If he does not come, the Thing will judge him without him.",
			"options": [{"id": "answer", "label": "Answer the summons", "hint": "Come to a Thing this summer and plead your side%s." % (
					(" (the nearest is %s)" % j.c.world.place(thing).display_name) if thing != "" else "")},
				{"id": "ignore", "label": "Pay it no heed", "hint": "Judged without you: likely outlawry."}]})


## A spring decision of the law answered (a summons, a favour called in).
static func answer_spring(j: Journey, d: Dictionary, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	match str(d.step):
		"summons":
			var summons: Dictionary = band.law.get("summons", {})
			summons[str(d.house)] = {"year": j.c.cal.year, "answer": id == "answer"}
			band.law["summons"] = summons
			if id == "answer":
				j._say("%s will answer %s at the Thing this summer." % [band.leader.display_name, d.house])
			else:
				j._say("%s pays the summons of %s no heed." % [band.leader.display_name, d.house])
		"favour":
			if id == "pay" and band.silver >= wr.favour_ounces:
				band.silver -= wr.favour_ounces
				j._shift(str(d.house), 5)
				j._say("%s pays %s the favour he owed them." % [band.leader.display_name, d.house])
			else:
				j._shift(str(d.house), wr.favour_refused_standing)
				j._say("%s puts %s off; they say he does not pay what he owes." % [band.leader.display_name, d.house])


## Deeds at a Thing site: answer a summons, plead the bounds of the band's
## land. (Feud cases and speaking for a house are Journey's own.)
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null or not is_thing(j, p) or Outlawry.is_outlawed(j.c.band, j.c.cal) or j.life.has("case"):
		return out
	var band := j.c.band
	var summons: Dictionary = band.law.get("summons", {})
	for fam in summons:
		var sm: Dictionary = summons[fam]
		if int(sm.get("year", -1)) == j.c.cal.year:
			out.append({"id": "answer:" + str(fam), "label": "Answer %s's summons" % fam,
					"hint": "Plead your side: support, the law, the standoff, the verdict. %d days." % j.c.world_rules.thing_days})
	var land_case: Dictionary = band.law.get("land_case", {})
	for fam in land_case:
		out.append({"id": "case_land:" + str(fam), "label": "Plead the bounds of your land against %s" % fam,
				"hint": "They moved your boundary stones. Win, and they pay for it or give up land of theirs."})
	if p.id == "iceland" and band.settled_iceland and j.c.world.timeline_state.get("althing", false):
		pass  # the Althing hears the band's feud cases like any Thing (Journey.actions)
	return out


static func act(j: Journey, id: String) -> bool:
	if id.begins_with("answer:"):
		var fam := id.trim_prefix("answer:")
		var how := "nid" if str(j.c.band.law.get("nid", "")) == fam else "summons"
		if not begin(j, fam, how):
			j._say("There is no case to answer.")
		return true
	if id.begins_with("case_land:"):
		begin(j, id.trim_prefix("case_land:"), "land")
		return true
	return false


## Whether a place is a Thing the band can plead at: a Thing site, or
## Iceland once the Althing is set up there.
static func is_thing(j: Journey, p: Place) -> bool:
	if p == null:
		return false
	return p.kind == WorldTypes.PlaceKind.THING_SITE or (p.id == "iceland" and bool(j.c.world.timeline_state.get("althing", false)))


## A summons not answered by the winter: the Thing judges the band
## without it. It does not pay, so it is outlawed.
static func judge_absent(j: Journey) -> void:
	var band := j.c.band
	var summons: Dictionary = band.law.get("summons", {})
	for fam in summons.keys():
		var sm: Dictionary = summons[fam]
		if int(sm.get("year", -1)) != j.c.cal.year:
			continue
		summons.erase(fam)
		if Outlawry.is_outlawed(band, j.c.cal):
			continue
		j._say("%s did not come to answer %s at the Thing, and the Thing judged him without him: he is outlawed." % [band.leader.display_name, fam])
		Outlawry.declare(j.c.world_rules, band, j.c.cal, false, j.said)
		band.law["exile_by"] = j.c.cal.year + 1  # he hears of it at the winter; a summer to go
		break


# --- The stand-in player ----------------------------------------------------------------

## A man of his bent at the Thing: the law-wise, the skald and the king's
## man win the houses that waver and lay out silver; the fighting ways go
## to the law as they are. The law-wise pleads himself when his pleading
## holds well, a law-wise man of the band next, else the law-man is hired
## (and kept, by a law-wise man with silver); the others hire him when
## they can. At the standoff the fighting ways press and stand firm, the
## others take arbitration when it is there. Won, the law-wise man, the
## skald and the trader ask wergild, the king's man and the Viking lesser
## outlawry when the case carries it, the berserk full outlawry; a man
## with no wife takes the marriage. Lost, he pays when he can, appeals
## when he can, and defies the verdict only as a berserk.
static func bot(j: Journey, d: Dictionary, bent: int) -> String:
	var band := j.c.band
	var wr := j.c.world_rules
	var ids := {}
	for o in d.options:
		if o.get("enabled", true):
			ids[str(o.id)] = o
	var fighting := bent == Way.Id.VIKING or bent == Way.Id.BERSERK
	match str(d.step):
		"summons":
			return "ignore" if bent == Way.Id.BERSERK else "answer"
		"favour":
			return "pay" if ids.has("pay") and band.silver >= 40 else "refuse"
		"support":
			var spender := bent == Way.Id.LAWMAN or bent == Way.Id.SKALD or bent == Way.Id.KINGS_MAN
			if spender and band.silver >= 60:
				for id in ids:
					if str(id).begins_with("gift:") or str(id).begins_with("promise:"):
						return str(id)
			if ids.has("spend") and band.silver >= (80 if spender else 120) and int(j.life.case.spent) < (20 if spender else 10):
				return "spend"
			return "go"
		"law":
			var best := "self"
			var best_p := -1.0
			for o in pleaders(j):
				var id2 := str(o.id)
				if not ids.has(id2):
					continue
				if id2 == "keep" and not (bent == Way.Id.LAWMAN and band.silver >= int(o.fee) + 60):
					continue
				if id2 == "hire" and band.silver < int(o.fee) + 30:
					continue
				var p := float(o.odds) - (0.05 if int(o.fee) > 0 else 0.0)
				if p > best_p:
					best_p = p
					best = id2
			return best
		"standoff":
			if fighting:
				return "press" if ids.has("press") else "firm"
			if ids.has("arbiter"):
				return "arbiter"
			return "back" if ids.has("back") else "firm"
		"verdict":
			var w := weigh(j)
			for want in (["full", "lesser", "wergild"] if bent == Way.Id.BERSERK else (["lesser", "wergild"] if bent == Way.Id.VIKING or bent == Way.Id.KINGS_MAN else ["marry", "land", "wergild"])):
				for a in asks(j):
					if str(a.id) == want and ids.has(want) and float(w.ratio) >= float(a.need):
						return want
			if ids.has("pay") and (band.silver >= _wergild(j) or str(ids.pay.label).begins_with("Bow")):
				return "pay"
			if ids.has("appeal"):
				return "appeal"
			if ids.has("defy") and bent == Way.Id.BERSERK:
				return "defy"
			if ids.has("pay"):
				return "pay"
	return str(d.options[0].id)
