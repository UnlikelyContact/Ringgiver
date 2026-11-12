class_name Hiring
extends RefCounted
## Men in summer (concept.md, "Loyalty must be won again"; notes/
## world-life.md): men for hire at halls, towns and markets, each by name
## and price with a line about him (WorldRules.hire_kinds); the wage they
## are owed every `wage_days`, and what a man does when it is not paid or
## his loyalty runs out (he takes his leave at the next place); men lent
## by a house, who go home at the summer's end or the day the house turns
## against the band; and captives ransomed, freed or kept. The winter's
## recruiting (Campaign._thaw) is the other way men come.


## The men for hire here this visit: [{i, name, text, kind, price, wage,
## tier, loyalty, stats: [might, skill, grit, nerve, wits]}], plain values
## for the screen. Rolled once a place a year.
static func men_for_hire(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list := _offers(j)
	for i in list.size():
		var o: Dictionary = list[i]
		var m: Man = o.man
		out.append({"i": i, "name": m.display_name, "text": str(o.text), "kind": str(o.kind), "price": int(o.price), "wage": int(o.wage),
				"tier": CombatTypes.TIER_NAMES[m.tier], "loyalty": m.loyalty, "stats": m.stats.duplicate()})
	return out


static func _offers(j: Journey) -> Array:
	var p := j.here()
	if p == null or not Journey.SETTLED.has(p.kind):
		return []
	var wr := j.c.world_rules
	var band := j.c.band
	if Families.is_foe(wr, band, p.family):
		return []
	var key := "hire_offer:%s" % p.id
	var cached: Dictionary = j.life.get(key, {})
	if int(cached.get("year", -1)) == j.c.cal.year:
		return cached.list
	var n := wr.hire_offers if (p.kind != WorldTypes.PlaceKind.FARMSTEAD or p.has_market) else wr.hire_offers_farm
	var r := j._fork("hire:" + p.id)
	var list: Array = []
	var kinds: Array = wr.hire_kinds.keys()
	kinds.sort()
	var total := 0
	for k in kinds:
		total += int(wr.hire_kinds[k].weight)
	for i in n:
		var roll := r.randi_range(1, total)
		var kind := str(kinds[0])
		for k in kinds:
			roll -= int(wr.hire_kinds[k].weight)
			if roll <= 0:
				kind = str(k)
				break
		var d: Dictionary = wr.hire_kinds[kind]
		var m := Recruits.random(r.fork("man:%d" % i), j.c.rules, 0)
		m.tier = d.tier as CombatTypes.Tier
		var bias: Array = d.bias
		for s in 5:
			m.set_stat(s as CombatTypes.Stat, m.stat(s as CombatTypes.Stat) + int(bias[s]))
			m.potential[s] = maxi(m.potential[s], m.stats[s])
		m.loyalty = int(d.loyalty)
		m.wage = int(d.wage)
		m.hire_kind = kind
		if kind == "berserk" and not m.has_personality(CombatTypes.Personality.RECKLESS):
			m.personality = [CombatTypes.Personality.RECKLESS]
		if kind == "outlaw":
			m.origin = CampaignTypes.Origin.OUTLAW
		list.append({"kind": kind, "man": m, "text": "%s, %s" % [m.display_name, d.text], "price": int(d.price), "wage": int(d.wage),
				"honor": int(d.honor)})
	j.life[key] = {"year": j.c.cal.year, "list": list}
	return list


## What can be done about men and captives here: [{id, label, hint, enabled}].
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null:
		return out
	var wr := j.c.world_rules
	var band := j.c.band
	var full := band.living_men().size() >= j.c.rules.recruit_cap
	var list := _offers(j)
	for i in list.size():
		var o: Dictionary = list[i]
		out.append({"id": "hire:%d" % i, "label": "Take %s into your band (%d oz)" % [(o.man as Man).display_name, int(o.price)],
				"enabled": band.silver >= int(o.price) and not full,
				"hint": "%s. %s; he wants %d oz each month of the summer.%s" % [Journey._cap(str(o.text)), CombatTypes.TIER_NAMES[(o.man as Man).tier].capitalize(),
						int(o.wage), (" Men will think the less of you for taking him on (honor -%d)." % int(o.honor)) if int(o.honor) > 0 else ""]})
	if band.captives > 0 and Journey.SETTLED.has(p.kind):
		if (p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN) and not wr.slave_markets.has(p.id):
			out.append({"id": "ransom", "label": "Let %d captives be ransomed" % band.captives,
					"hint": "Their kin send %d oz a head through the lord here." % wr.captive_ransom})
		out.append({"id": "free", "label": "Set the captives free", "hint": "They go home and tell of it: honor, and no silver."})
	return out


static func act(j: Journey, id: String) -> bool:
	var p := j.here()
	if p == null:
		return false
	var wr := j.c.world_rules
	var band := j.c.band
	var who := band.leader.display_name
	if id.begins_with("hire:"):
		var list := _offers(j)
		var i := int(id.trim_prefix("hire:"))
		if i < 0 or i >= list.size():
			return true
		var o: Dictionary = list[i]
		if band.silver < int(o.price) or band.living_men().size() >= j.c.rules.recruit_cap:
			return true
		var m: Man = o.man
		band.silver -= int(o.price)
		m.id = 0
		band.add_man(m)
		m.paid_until = j.roam.clock
		j.c._arm_new_men()
		band.honor = clampi(band.honor - int(o.honor), 0, 100)
		list.remove_at(i)
		j.c.tally.hired = int(j.c.tally.get("hired", 0)) + 1
		j._say("%s takes %s into his band for %d oz: %s." % [who, m.display_name, int(o.price), str(wr.hire_kinds[str(o.kind)].text)])
		band.log("%s took %s into his band" % [who, m.display_name])
		return true
	match id:
		"ransom":
			var n := band.captives
			band.captives = 0
			band.silver += n * wr.captive_ransom
			j._say("The kin of %d captives ransom them at %s for %d oz." % [n, p.display_name, n * wr.captive_ransom])
			j._pass(2.0)
		"free":
			var n2 := band.captives
			band.captives = 0
			band.honor = clampi(band.honor + mini(n2, wr.free_honor_max), 0, 100)
			j._say("%s lets %d captives go home; they will speak of it." % [who, n2])
		_:
			return false
	return true


## Every `wage_days` of the summer the hired men are paid, as far as the
## silver goes; a man not paid thinks the less of it. A man whose loyalty
## is spent takes his leave when the band is next at a place; a man lent
## by a house that has turned against the band goes home at once.
static func reckon(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var cr := j.c.rules
	var clock := j.roam.clock
	for m in band.living_men():
		if m.wage <= 0:
			continue
		if clock - m.paid_until < wr.wage_days:
			continue
		m.paid_until += wr.wage_days
		if band.silver >= m.wage:
			band.silver -= m.wage
		else:
			Loyalty.adjust(m, -wr.unpaid_loyalty)
			j._say("%s's pay is short this month; %s says nothing, and thinks the more." % [m.display_name, m.display_name])
	for m in band.living_men():
		if m.lent_by != "" and Families.is_foe(wr, band, m.lent_by):
			band.remove_man(m)
			j._say("%s goes home to %s: they want no man of theirs in your band now." % [m.display_name, m.lent_by])
	var p := j.here()
	if p == null or not Journey.SETTLED.has(p.kind):
		return
	for m in band.living_men():
		if m.loyalty < cr.loyalty_leave_below and not m.is_leader:
			band.remove_man(m)
			j.c.tally.departures = int(j.c.tally.get("departures", 0)) + 1
			var why := "the pay is short" if m.wage > 0 else "he has had enough of following %s" % band.leader.display_name
			j._say("%s takes his leave at %s: %s." % [m.display_name, p.display_name, why])
			band.log("%s left the band at %s" % [m.display_name, p.display_name])
			return  # one at a time


## The summer's end: men lent by a house go home for the winter, and a
## hired man who has come to think well enough of the band (loyalty at
## `hire_swear_loyalty` or more) swears himself to it: no more wage, a
## share of the plunder like the rest.
static func end_of_summer(j: Journey) -> void:
	var band := j.c.band
	for m in band.living_men():
		if m.lent_by != "":
			band.remove_man(m)
			j._say("%s goes home to %s for the winter, with thanks." % [m.display_name, m.lent_by])
		elif m.wage > 0 and m.loyalty >= j.c.world_rules.hire_swear_loyalty:
			m.wage = 0
			j._say("%s will take no more wage: he swears himself to %s for the winter and after." % [m.display_name, band.leader.display_name])
