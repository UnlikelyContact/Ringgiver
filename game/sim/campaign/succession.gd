class_name Succession
extends RefCounted
## Heirs and the grave-ale (concept.md, Succession, Loyalty must be won again,
## The grave-ale, What carries over). Every value comes from CampaignRules
## (section "Leader, family and succession").
##
## How the old leader died is passed to `succeed` as `death_cause` ("battle",
## "old", "outlaw", "sickness", "oathbreaker"; "" for unknown). It is also
## recorded on the band as metadata (DEATH_CAUSES_META: leader name -> cause)
## so Chronicle.generation_text can close a generation with the right line.
## A passed-over second who challenges the heir is recorded as metadata
## PENDING_CHALLENGE_META (his man id) for the loop to fight as a holmgang.

const DEATH_CAUSES_META := &"death_causes"
const PENDING_CHALLENGE_META := &"pending_challenge"
## Whether the high seat last passed by blood (`line_holds`).
const LINE_META := &"line_holds"


## Who takes the high seat: {kind: "son"|"second"|"none", son: Dictionary or
## null, man: Man or null}. A son of age comes before the sworn second.
static func heir(rules: CampaignRules, band: Band, cal: Calendar) -> Dictionary:
	var sons := Family.sons_of_age(rules, band, cal)
	if not sons.is_empty():
		return {"kind": "son", "son": sons[0], "man": null}
	var second := _second(band)
	if second != null:
		return {"kind": "second", "son": null, "man": second}
	return {"kind": "none", "son": null, "man": null}


static func name_second(band: Band, m: Man, log: PackedStringArray) -> void:
	band.sworn_second_id = m.id
	var who := band.leader.display_name if band.leader != null else "The leader"
	var text := "%s named %s his sworn second" % [who, m.display_name]
	log.append(text)
	band.log(text)


## The heir takes the high seat. `heir_man` is the sworn second, or a son the
## loop has built with Recruits.son_of. Feuds carry over untouched; luck and
## fame carry in part; the grave-ale costs `feast_ounces` (no more than the
## band holds) and every man decides again whether to stay. Returns the men
## who leave; they are already removed from band.men.
##
## `played` is the grave-ale the player holds (Journey): a strong second
## (stronger than the heir by `challenge_stat_margin`, or a better tier)
## whose bond with the heir is under `challenge_bond` disputes it as well
## as one who bears him ill will; the old automatic path is unchanged.
static func succeed(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, heir_man: Man,
		feast_ounces: int, vow: String, log: PackedStringArray, death_cause := "", played := false) -> Array[Man]:
	var old := band.leader
	var old_name := old.display_name if old != null else "the old leader"
	Chronicle.close_chapter(band, cal.year, death_cause)
	var passed_second: Man = null
	var second := _second(band)
	if second != null and second != heir_man:
		passed_second = second

	# The high seat.
	if old != null:
		old.is_leader = false
	if band.men.has(heir_man):
		band.remove_man(heir_man)
	heir_man.is_leader = true
	band.leader = heir_man
	if band.sworn_second_id == heir_man.id:
		band.sworn_second_id = -1
	_record_death(band, old_name, death_cause)
	var head := "%s is dead%s; %s takes the high seat" % [old_name, _cause_phrase(death_cause), heir_man.display_name]
	log.append(head)
	band.log(head)

	# What carries over. Feuds stay on the band in full.
	var luck := roundi(band.luck * rules.luck_inherit_fraction)
	if death_cause == "battle":
		luck += rules.luck_good_death
	elif rules.shameful_deaths.has(death_cause):
		luck -= rules.luck_shameful_death
	band.luck = clampi(luck, Leader.LUCK_MIN, Leader.LUCK_MAX)
	band.fame = clampi(roundi(band.fame * rules.fame_inherit_fraction), Leader.REP_MIN, Leader.REP_MAX)
	var open := band.unsettled_feuds().size()
	if open > 0:
		log.append("%s inherits %d feud%s" % [heir_man.display_name, open, "" if open == 1 else "s"])

	# The grave-ale.
	var spent := clampi(feast_ounces, 0, band.silver)
	band.silver -= spent
	var feast_bonus := spent * rules.feast_bonus_per_ounce
	var ale := "%s held the grave-ale for %s" % [heir_man.display_name, old_name]
	if spent > 0:
		ale += " and spent %d ounces on it" % spent
	log.append(ale)
	band.log(ale)

	var challenger: Man = null
	var leaving: Array[Man] = []
	var disputes := passed_second != null and band.bond(passed_second, heir_man) < 0
	var strong := passed_second != null and played and band.bond(passed_second, heir_man) < rules.challenge_bond \
			and (passed_second.total_stats() >= heir_man.total_stats() + rules.challenge_stat_margin or passed_second.tier > heir_man.tier)
	if disputes or strong:
		if strong or rng.randf() < rules.challenge_chance:
			challenger = passed_second
			band.set_meta(PENDING_CHALLENGE_META, passed_second.id)
			var ch := "%s would not drink to %s and challenged him to the holmgang" % [
				passed_second.display_name, heir_man.display_name]
			log.append(ch)
			band.log(ch)
		else:
			leaving.append(passed_second)
			for m in band.living_men():
				if m != passed_second and band.bond_kind(passed_second, m) == CampaignTypes.BondKind.OATH_BROTHER:
					leaving.append(m)
			var gone := "%s would not serve %s and left" % [passed_second.display_name, heir_man.display_name]
			log.append(gone)
			band.log(gone)

	var fame_pull := band.fame / 10.0
	for m in band.living_men():
		if m == challenger or leaving.has(m):
			continue
		var score := m.loyalty + band.bond(m, heir_man) + fame_pull + feast_bonus
		if score < rules.stay_threshold:
			leaving.append(m)
			log.append("%s would not drink the oath cup to %s, and left" % [m.display_name, heir_man.display_name])
		else:
			log.append("%s drank the oath cup to %s" % [m.display_name, heir_man.display_name])
	for m in leaving:
		band.remove_man(m)
		if band.sworn_second_id == m.id:
			band.sworn_second_id = -1
	if not leaving.is_empty():
		band.log("%d men left rather than serve %s" % [leaving.size(), heir_man.display_name])

	if vow != "":
		band.vows.append({"year": cal.year, "text": vow, "kept": null})
		var v := "%s vowed at the grave-ale: %s" % [heir_man.display_name, vow]
		log.append(v)
		band.log(v)
	Chronicle.open_chapter(band, heir_man.display_name, cal.year, str(heir_man.get_meta("came", "")) if heir_man.has_meta("came") else "")
	return leaving


static func death_cause_of(band: Band, leader_name: String) -> String:
	if not band.has_meta(DEATH_CAUSES_META):
		return ""
	var causes: Dictionary = band.get_meta(DEATH_CAUSES_META)
	return str(causes.get(leader_name, ""))


static func _record_death(band: Band, leader_name: String, cause: String) -> void:
	var causes: Dictionary = band.get_meta(DEATH_CAUSES_META) if band.has_meta(DEATH_CAUSES_META) else {}
	causes[leader_name] = cause
	band.set_meta(DEATH_CAUSES_META, causes)


static func _cause_phrase(cause: String) -> String:
	match cause:
		"battle":
			return ", fallen in battle"
		"old":
			return ", of old age"
		"outlaw":
			return ", an outlaw"
		"sickness":
			return ", of a fever"
		"oathbreaker":
			return ", an oath-breaker"
	return ""


static func _second(band: Band) -> Man:
	if band.sworn_second_id < 0:
		return null
	for m in band.men:
		if m.id == band.sworn_second_id and m.alive:
			return m
	return null


# --- The grave-ale, played (docs/design/notes/generations.md) ---------------------

## Who may take the high seat when the leader is dead (or steps down), in
## the order the hall would name them: the heir he named, his sons of age
## (in the band or at home, eldest first), the sworn second, his brothers
## and other kin of the blood come of age, and, when there is none of
## those, the best man of the band, who takes up his name. Each is {id,
## kind: son|kin|second|man, name, age, man (Man or null), child ({} for a
## man), line: what follows if he is chosen}.
static func candidates(c: Campaign) -> Array[Dictionary]:
	var band := c.band
	var rules := c.rules
	var year := c.cal.year
	var old := band.leader
	var old_name := old.display_name if old != null else "the old leader"
	var out: Array[Dictionary] = []
	var named := str(band.get_meta(Family.HEIR_META, "")) if band.has_meta(Family.HEIR_META) else ""
	var sons: Array[Dictionary] = []
	var kin: Array[Dictionary] = []
	for child in band.sons:
		if not Family.is_son(child) or not child.get("alive", true) or child.get("seat", false):
			continue
		var age := year - int(child.get("born", year))
		if age < rules.heir_min_age or not Family.at_home(rules, child, year):
			continue
		var m: Man = null
		if int(child.get("man_id", -1)) >= 0:
			m = band.man_by_id(int(child.man_id))
			if m == null or not m.alive or not band.men.has(m):
				continue
		var d := {"id": "son:" + str(child.name), "kind": "son", "name": str(child.name), "age": age, "man": m, "child": child}
		if str(child.get("father", old_name)) == old_name:
			sons.append(d)
		else:
			d.kind = "kin"
			d.id = "kin:" + str(child.name)
			kin.append(d)
	sons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (str(a.name) == named and str(b.name) != named) or (int(a.age) > int(b.age) and not (str(b.name) == named)))
	kin.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.age) > int(b.age))
	for d in sons:
		d.line = "His son. He keeps the name, the feuds and the family's luck; the men may doubt a young man."
		out.append(d)
	var second := _second(band)
	if second != null:
		out.append({"id": "second:%d" % second.id, "kind": "second", "name": second.display_name, "age": second.age, "man": second,
				"child": {}, "line": "The sworn second. He keeps the band and its feuds; the blood line of %s ends in the high seat." % old_name})
	for d in kin:
		d.line = "Of the same blood. He keeps the name and the feuds."
		out.append(d)
	if out.is_empty():
		var best: Man = null
		for m in band.living_men():
			if best == null or m.loyalty + m.total_stats() * 3 > best.loyalty + best.total_stats() * 3:
				best = m
		if best != null:
			out.append({"id": "man:%d" % best.id, "kind": "man", "name": best.display_name, "age": best.age, "man": best, "child": {},
					"line": "No son and no sworn second: %s, the best of his men, takes up his name and his quarrels." % best.display_name})
	return out


## The man a candidate is: the man of the band himself, or a son or
## kinsman at home made a man (Family.son_man) to sit the high seat.
static func heir_man_of(c: Campaign, cand: Dictionary) -> Man:
	var m: Man = cand.get("man", null)
	if m == null:
		m = Family.son_man(c, cand.child)
	match str(cand.kind):
		"son":
			m.set_meta("came", "son of %s" % c.band.leader.display_name)
		"kin":
			m.set_meta("came", "kinsman of %s" % c.band.leader.display_name)
		"second":
			m.set_meta("came", "sworn second of %s" % c.band.leader.display_name)
		_:
			m.set_meta("came", "one of the men of %s" % c.band.leader.display_name)
	return m


## The grave-ale the player held: `cand` takes the high seat (Succession.
## succeed, with the feast's silver and the vow), then what carries over
## for a son or a man of another blood (`carry_over`); a mean feast cools
## every man, an open-handed one is talked of. `vengeance` names the house
## a vow of vengeance is sworn against (a feud with it is opened if there is
## none). Returns the lines told; the heir is band.leader after.
static func grave_ale(c: Campaign, cand: Dictionary, feast: int, vow: String, vengeance: String, cause: String,
		log: PackedStringArray) -> PackedStringArray:
	var band := c.band
	var rules := c.rules
	var old := band.leader
	var lines := PackedStringArray()
	var heir := heir_man_of(c, cand)
	var mark := log.size()
	var plain := rules.grave_ale_ounces
	succeed(c.rng.fork("grave_ale:%d" % c.cal.year), rules, band, c.cal, heir, feast, vow, log, cause, true)
	c.tally.successions += 1
	if str(cand.kind) == "son" or str(cand.kind) == "kin":
		var child: Dictionary = cand.child
		child["seat"] = true
	carry_over(c, old, heir, str(cand.kind))
	if feast >= maxi(rules.grave_ale_open_min, rules.grave_ale_open_per_man * band.living_men().size()):
		band.fame = clampi(band.fame + rules.grave_ale_open_fame, Leader.REP_MIN, Leader.REP_MAX)
		log.append("The grave-ale for %s was talked of for a long time after." % old.display_name)
	elif feast < plain / 2:
		for m in band.living_men():
			Loyalty.adjust(m, -rules.grave_ale_mean_loyalty)
		band.honor = clampi(band.honor - rules.grave_ale_mean_honor, Leader.REP_MIN, Leader.REP_MAX)
		log.append("It was a thin grave-ale, and the men said %s was mean with his father's silver." % heir.display_name)
	if vengeance != "":
		if Feud.find(band, vengeance).is_empty():
			band.add_feud(vengeance, "the killing of %s" % old.display_name)
		if band.vengeance == "":
			band.vengeance = vengeance
	for i in range(mark, log.size()):
		lines.append(log[i])
	c._pending_vow = vow
	c._name_second_if_needed()
	return lines


## What carries from the old leader to the new one beyond Succession.
## succeed's luck and fame: a son keeps more of the family's luck, his
## mother keeps the keys and her house is his kin; any man starts on his own
## ways of life (the old leader's steps and deeds are his saga's, not the
## heir's); the houses keep part of their regard (`standing_inherit_*`);
## the blood line is marked ended or held.
static func carry_over(c: Campaign, old: Man, heir: Man, kind: String) -> void:
	var band := c.band
	var rules := c.rules
	var son := kind == "son" or kind == "kin"
	if son:
		band.luck = clampi(band.luck + rules.heir_son_luck, Leader.LUCK_MIN, Leader.LUCK_MAX)
	if band.wife != "":
		band.set_meta(Family.MOTHER_META, band.wife)
	band.wife = ""
	if band.has_meta(Family.WIFE_HOUSE_META):
		band.remove_meta(Family.WIFE_HOUSE_META)
	if band.has_meta(Family.HEIR_META):
		band.remove_meta(Family.HEIR_META)
	band.paths = {}
	band.deeds = {}
	Way.refresh(band)
	band.war_leader_id = -1 if band.war_leader_id == heir.id else band.war_leader_id
	band.leader_keeps_back = band.leader_keeps_back and band.war_leader_id >= 0
	if c.world != null and c.world.families != null:
		c.world.families.inherit(band, rules.standing_inherit_son if son else rules.standing_inherit_second, son)
	band.set_meta(LINE_META, son)
	heir.loyalty = 100


## The old leader steps down for `cand` at the spring: no grave-ale, he
## sits by the fire as the old man of the hall and gives counsel, and the
## saga goes on with the heir.
static func step_down(c: Campaign, cand: Dictionary, log: PackedStringArray) -> PackedStringArray:
	var band := c.band
	var old := band.leader
	var lines := PackedStringArray()
	var heir := heir_man_of(c, cand)
	Chronicle.close_chapter(band, c.cal.year, "stepped down")
	if band.men.has(heir):
		band.remove_man(heir)
	old.is_leader = false
	heir.is_leader = true
	band.leader = heir
	if band.sworn_second_id == heir.id:
		band.sworn_second_id = -1
	if str(cand.kind) == "son" or str(cand.kind) == "kin":
		(cand.child as Dictionary)["seat"] = true
	band.set_meta(Family.OLD_MAN_META, {"name": old.display_name, "born": c.cal.year - old.age, "year": c.cal.year})
	carry_over(c, old, heir, str(cand.kind))
	var text := "%s, grown old, gave the high seat to %s and sat down by the fire" % [old.display_name, heir.display_name]
	log.append(text)
	band.log(text)
	lines.append(Journey._cap(text) + ".")
	Chronicle.open_chapter(band, heir.display_name, c.cal.year, str(heir.get_meta("came", "")))
	c.tally.successions += 1
	c._name_second_if_needed()
	return lines


## The holmgang for the high seat is over: `won` is the heir's. Won, the
## challenger yields and drinks the oath cup (fame to the heir); lost, he
## takes the high seat and the heir goes down to the benches. Returns the
## lines told.
static func challenge_done(c: Campaign, challenger: Man, won: bool, log: PackedStringArray) -> PackedStringArray:
	var band := c.band
	var rules := c.rules
	var lines := PackedStringArray()
	if band.has_meta(PENDING_CHALLENGE_META):
		band.remove_meta(PENDING_CHALLENGE_META)
	if challenger == null or band.leader == null:
		return lines
	var heir := band.leader
	if won or not challenger.alive:
		challenger.loyalty = maxi(challenger.loyalty, rules.stay_threshold)
		band.add_bond(challenger, heir, rules.challenge_bond)
		band.fame = clampi(band.fame + rules.challenge_won_fame, Leader.REP_MIN, Leader.REP_MAX)
		var text := "%s yielded to %s on the island, and drank the oath cup to him after all" % [challenger.display_name, heir.display_name]
		log.append(text)
		band.log(text)
		lines.append(Journey._cap(text) + ".")
		return lines
	Chronicle.close_chapter(band, c.cal.year, "lost the high seat")
	band.remove_man(challenger)
	heir.is_leader = false
	challenger.is_leader = true
	band.leader = challenger
	band.add_man(heir)
	heir.loyalty = 40
	if band.sworn_second_id == challenger.id:
		band.sworn_second_id = -1
	band.set_meta(LINE_META, false)
	var text2 := "%s won the holmgang and took the high seat; %s went down to the benches" % [challenger.display_name, heir.display_name]
	log.append(text2)
	band.log(text2)
	lines.append(Journey._cap(text2) + ".")
	Chronicle.open_chapter(band, challenger.display_name, c.cal.year, "who won the high seat on the island")
	c._name_second_if_needed()
	return lines


## Whether the high seat last passed by blood (false once a sworn second,
## a man of the band or a challenger has taken it).
static func line_holds(band: Band) -> bool:
	return bool(band.get_meta(LINE_META, true)) if band.has_meta(LINE_META) else true
