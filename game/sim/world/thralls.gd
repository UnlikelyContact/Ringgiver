class_name Thralls
extends RefCounted
## The unfree (concept.md, "Thralls and tone"), told soberly in the
## sagas' own voice. Before this captives could only be sold, ransomed at
## a flat price or let go.
##
## After a won raid the band decides over the people it has taken (a
## decision, kind "unfree"): ransom them to their kin (more for a named
## person of a house, and the house is the warmer for it), keep them bound
## for a market that deals in people (Dublin above all; selling a house's
## people abroad costs standing with it, and a named freeborn person sold
## costs honor), take them home as thralls to work the band's land, or let
## them go (honor; one may ask to follow the band, a freedman who
## remembers it).
##
## Thralls at home are hands for the land (Landtake) and mouths at the
## thaw; their unrest (Band.unrest, 0..10) rises with their number past the
## watch kept on them, with the band long away and with a hard hand, and
## comes out in the winter (a card in the hall: flight, a killing) or, at
## its worst, in a rising while the band is away (Hjörleifr killed by his
## Irish thralls). Freeing a thrall is a ring-giver's act: honor, and in
## `freedman_house_years` the freedmen on the band's land are a house of
## their own, its friends.
##
## It can happen to the band too: after a fight lost abroad one of its men
## may be taken by slavers, to be ransomed or freed by force at the market
## where he is held, before he is sold on east.


## The captives of a won raid on `place`: what will be done with them.
static func after_raid(j: Journey, place: Place) -> void:
	var band := j.c.band
	if band.captives <= 0 or place == null:
		return
	var wr := j.c.world_rules
	var fs := j.c.world.families
	var named := ""
	var house := place.family
	if house != "" and fs != null and fs.houses.has(house) and (place.kind == WorldTypes.PlaceKind.HALL or place.kind == WorldTypes.PlaceKind.TOWN):
		var r := Landtake.fork(j, "named")
		named = "%s, daughter of %s" % [NorwayData.HOUSE_WOMEN[r.randi_range(0, NorwayData.HOUSE_WOMEN.size() - 1)], fs.house(house).head]
	var from: Dictionary = band.law.get("captives_from", {})
	from[house] = int(from.get(house, 0)) + band.captives
	band.law["captives_from"] = from
	if named != "":
		band.law["named"] = {"name": named, "house": house}
	j.decisions.push_front(_captives_decision(j, place, named))


static func _captives_decision(j: Journey, place: Place, named: String) -> Dictionary:
	var band := j.c.band
	var wr := j.c.world_rules
	var n := band.captives
	var house := place.family
	# Their kin ransom their own people, not the rest of the summer's.
	var ransom := ransom_for(j, _of_house(band, house), named != "")
	var opts: Array[Dictionary] = []
	if house != "":
		opts.append({"id": "ransom", "label": "Send to their kin for ransom (%d oz)" % ransom,
				"hint": "%s pay to have their people back, and think the better of you for it. Three days." % house})
	opts.append({"id": "bound", "label": "Keep them bound for the market",
			"hint": "Dublin pays %d a head, Hedeby and Birka %d, less for each the market has lately bought. Bound people must be watched and fed, slow the march and slip away; men think the less of a slaver. %s will not forgive their people sold abroad." % [wr.captive_price_dublin, wr.captive_price,
					house if house != "" else "Their kin"]})
	if not band.holdings.is_empty():
		opts.append({"id": "thralls", "label": "Take them home as thralls",
				"hint": "Hands for your land, mouths at the thaw, and a watch to keep on them."})
	opts.append({"id": "free", "label": "Let them go home",
			"hint": "No silver; men will speak of it (honor +%d)." % mini(n, wr.free_honor_max)})
	var who := "%d people of %s" % [n, place.display_name]
	var text := "%s are bound on the strand: %s." % [Journey._cap(who), ("among them %s" % named) if named != "" else "farm folk, men and women"]
	return {"kind": "unfree", "step": "captives", "title": "The captives", "place": place.id, "house": house, "named": named,
			"text": text, "detail": "What becomes of them is yours to say.", "options": opts}


## What the kin of `n` captives pay to have them back: a named person of
## the house for `named_ransom`.
static func ransom_for(j: Journey, n: int, named: bool) -> int:
	var wr := j.c.world_rules
	return n * wr.captive_ransom + (wr.named_ransom - wr.captive_ransom if named and n > 0 else 0)


static func answer(j: Journey, d: Dictionary, id: String) -> void:
	match str(d.step):
		"captives":
			_decide(j, d, id)
		"taken":
			if id == "lost":
				var band := j.c.band
				for t in band.taken.duplicate():
					if int(t.year) == j.c.cal.year and (t.man as Man).display_name == str(d.name):
						band.taken.erase(t)
						j._say("%s is given up for lost; his oath brothers do not forget who gave him up." % d.name)
			else:
				j._say("%s will go after %s." % [j.c.band.leader.display_name, d.name])


static func _decide(j: Journey, d: Dictionary, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var n := band.captives
	var house := str(d.house)
	var named := str(d.named)
	var who := band.leader.display_name
	match id:
		"ransom":
			n = _of_house(band, house)
			var silver := ransom_for(j, n, named != "")
			band.silver += silver
			band.captives -= n
			band.law.erase("named")
			_clear_from(band, house, n)
			j._shift(house, wr.ransom_standing + (wr.ransom_standing if named != "" else 0))
			band.honor = clampi(band.honor + 1, 0, 100)
			j._pass(3.0)
			j._say("%s send %d oz for their people, and have them back%s." % [house, silver, (", %s among them" % named) if named != "" else ""])
		"thralls":
			take_home(j, n, str(d.place))
		"free":
			let_go(j)
		_:
			j._say("%s keeps the captives bound, for the market." % who)


## How many of the captives held were taken from `house` (all of them when
## the band has no count by house).
static func _of_house(band: Band, house: String) -> int:
	var from: Dictionary = band.law.get("captives_from", {})
	if not from.has(house):
		return band.captives
	return clampi(int(from[house]), 0, band.captives)


static func _clear_from(band: Band, house: String, n: int) -> void:
	var from: Dictionary = band.law.get("captives_from", {})
	from[house] = maxi(0, int(from.get(house, 0)) - n)
	if int(from[house]) == 0:
		from.erase(house)
	band.law["captives_from"] = from


## The captives become thralls on the band's land: named people, each with
## where they were taken.
static func take_home(j: Journey, n: int, from_place: String) -> void:
	var band := j.c.band
	var r := Landtake.fork(j, "thrall_names")
	var p := j.c.world.place(from_place)
	var names := PackedStringArray()
	for i in mini(n, band.captives):
		var nm: String = Recruits.NAMES[r.randi_range(0, Recruits.NAMES.size() - 1)] if r.randf() < 0.5 \
				else NorwayData.HOUSE_WOMEN[r.randi_range(0, NorwayData.HOUSE_WOMEN.size() - 1)]
		band.thralls.append({"name": nm, "from": p.display_name if p != null else "over the sea", "year": j.c.cal.year})
		names.append(nm)
	band.captives = maxi(0, band.captives - names.size())
	band.law.erase("named")
	j._say("%s takes %d people home to work his land: %s." % [band.leader.display_name, names.size(), ", ".join(names)])


## The captives let go: honor a head (to `free_honor_max`), the named one's
## house the warmer, and one of them may ask to follow the band.
static func let_go(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var n := band.captives
	if n <= 0:
		return
	var named: Dictionary = band.law.get("named", {})
	band.captives = 0
	band.honor = clampi(band.honor + mini(n, wr.free_honor_max), 0, 100)
	if not named.is_empty():
		j._shift(str(named.house), wr.ransom_standing * 2)
	band.law.erase("named")
	band.law.erase("captives_from")
	j._say("%s lets %d captives go home; they will speak of it." % [band.leader.display_name, n])
	if band.living_men().size() < j.c.room():
		var r := Landtake.fork(j, "freed")
		var m := Recruits.make(r, j.c.rules, CampaignTypes.Origin.FREEDMAN, 22, Recruits.NAMES[r.randi_range(0, Recruits.NAMES.size() - 1)], band.next_id())
		m.loyalty = maxi(m.loyalty, 70)
		m.traits.append("freed by %s" % band.leader.display_name)
		band.add_man(m)
		j.c._arm_new_men()
		j._say("One of them, %s, will not go home: he asks to follow the man who freed him." % m.display_name)


## The days pass with captives held: the slave markets' glut mends a head
## every `captive_mend_days`, and bound people slip away, the more when
## there are too few men to watch them.
static func _captives_tick(j: Journey, days: float) -> void:
	var wr := j.c.world_rules
	var mend := float(j.life.get("captive_mend", 0.0)) + days
	while mend >= float(wr.captive_mend_days):
		mend -= float(wr.captive_mend_days)
		for id in wr.slave_markets:
			var p := j.c.world.place(str(id))
			if p != null and p.captives_sold > 0:
				p.captives_sold -= 1
	j.life["captive_mend"] = mend
	var band := j.c.band
	if band.captives <= 0:
		return
	var chance := wr.captive_flight_day * days
	if band.captives > band.fighters(j.c.rules).size() * wr.captives_per_guard:
		chance *= 2.0
	var r := Landtake.fork(j, "flight")
	var gone := 0
	for i in band.captives:
		if r.randf() < chance:
			gone += 1
	if gone <= 0:
		return
	var before := band.captives
	band.captives -= gone
	var from: Dictionary = band.law.get("captives_from", {})
	for h in from.keys():
		from[h] = int(floor(float(from[h]) * float(band.captives) / float(before)))
	if band.captives <= 0:
		band.law.erase("named")
		band.law.erase("captives_from")
	j._say("In the night %s of the captives slip their bonds and are gone." % (str(gone) if gone > 1 else "one"))


## The march's pace with captives in tow: more of them than men slow it by
## `captive_slow` a head over, to at least `captive_slow_floor`.
static func captive_pace(j: Journey) -> float:
	var wr := j.c.world_rules
	var over := j.c.band.captives - j.c.band.fighters().size()
	if over <= 0:
		return 1.0
	return maxf(wr.captive_slow_floor, 1.0 - wr.captive_slow * over)


## Sells the band's captives at a market that deals in people: the glut
## lowers the price a head; Dublin pays most. Their house will not forgive
## its people sold abroad, nor any man a named freeborn woman sold.
static func sell(j: Journey, place: Place) -> int:
	var band := j.c.band
	var wr := j.c.world_rules
	var base := wr.captive_price_dublin if place.id == "dublin" else wr.captive_price
	if Market.captive_price(wr, place) <= 0 or band.captives <= 0:
		return 0
	var earned := 0
	var sold := 0
	while sold < band.captives:
		var price := maxi(0, roundi(float(base) * (1.0 - wr.captive_glut * float(place.captives_sold))))
		if price <= 0:
			break
		earned += price
		sold += 1
		place.captives_sold += 1
	band.captives -= sold
	band.silver += earned
	band.law["sold"] = int(band.law.get("sold", 0)) + sold
	band.law["sold_oz"] = int(band.law.get("sold_oz", 0)) + earned
	if sold > 0:
		band.honor = clampi(band.honor - ceili(float(sold) / maxf(1.0, wr.sell_honor_heads)), 0, 100)
	var from: Dictionary = band.law.get("captives_from", {})
	var houses: Array = from.keys()
	houses.sort()
	for h in houses:
		j._shift(str(h), wr.sell_standing * int(from[h]))
	band.law.erase("captives_from")
	var named: Dictionary = band.law.get("named", {})
	if not named.is_empty():
		j._shift(str(named.house), wr.sell_named_standing)
		band.honor = clampi(band.honor - wr.sell_named_honor, 0, 100)
		j._say("%s is sold with the rest; %s will hear of it." % [named.name, named.house])
		band.law.erase("named")
	j._say("%s sells %d captives at %s for %d oz." % [band.leader.display_name, sold, place.display_name, earned])
	return earned


# --- Deeds ---------------------------------------------------------------------------------

## What may be done about the unfree here: ransom or free captives, set
## them to work the band's land, free a thrall, ransom or free a man of
## the band held for sale.
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null:
		return out
	var band := j.c.band
	var wr := j.c.world_rules
	if band.captives > 0 and Journey.SETTLED.has(p.kind):
		if (p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN) and not wr.slave_markets.has(p.id):
			var named: Dictionary = band.law.get("named", {})
			out.append({"id": "ransom", "label": "Let %d captives be ransomed" % band.captives,
					"hint": "Their kin send %d oz through the lord here%s." % [ransom_for(j, band.captives, not named.is_empty()),
							(", %d of it for %s" % [wr.named_ransom, named.name]) if not named.is_empty() else ""]})
		out.append({"id": "free", "label": "Set the captives free", "hint": "They go home and tell of it: honor, and no silver."})
		if not Landtake.holding_at(band, p.id).is_empty():
			out.append({"id": "thralls_home", "label": "Set the captives to work your land",
					"hint": "%d more hands for the land, and more to watch: unrest is %d of 10." % [band.captives, band.unrest]})
	if not band.thralls.is_empty() and not Landtake.holding_at(band, p.id).is_empty():
		var t: Dictionary = band.thralls[0]
		out.append({"id": "manumit", "label": "Free %s, a thrall" % t.name,
				"hint": "A ring-giver's act: honor +%d, and a freedman who stays on your land as a tenant." % wr.manumit_honor})
	for i in band.taken.size():
		var tk: Dictionary = band.taken[i]
		if str(tk.at) != p.id:
			continue
		var m: Man = tk.man
		out.append({"id": "ransom_taken:%d" % i, "label": "Buy %s back (%d oz)" % [m.display_name, int(tk.price)], "enabled": band.silver >= int(tk.price),
				"hint": "He is held here for sale. Bought back, he will not forget it."})
		out.append({"id": "rescue_taken:%d" % i, "label": "Take %s back by force" % m.display_name,
				"hint": "The slavers keep him under guard: a fight."})
	return out


static func act(j: Journey, id: String) -> bool:
	var band := j.c.band
	var wr := j.c.world_rules
	var p := j.here()
	if id == "ransom":
		var named: Dictionary = band.law.get("named", {})
		var n := band.captives
		var silver := ransom_for(j, n, not named.is_empty())
		band.captives = 0
		band.silver += silver
		var from: Dictionary = band.law.get("captives_from", {})
		for h in from:
			j._shift(str(h), wr.ransom_standing)
		band.law.erase("captives_from")
		band.law.erase("named")
		j._say("The kin of %d captives ransom them at %s for %d oz." % [n, p.display_name, silver])
		j._pass(2.0)
		return true
	if id == "free":
		let_go(j)
		return true
	if id == "thralls_home":
		take_home(j, band.captives, p.id)
		return true
	if id == "manumit":
		manumit(j)
		return true
	if id.begins_with("ransom_taken:") or id.begins_with("rescue_taken:"):
		var i := int(id.get_slice(":", 1))
		if i < 0 or i >= band.taken.size():
			return true
		var tk: Dictionary = band.taken[i]
		var m: Man = tk.man
		if id.begins_with("ransom_taken:"):
			if band.silver < int(tk.price):
				return true
			band.silver -= int(tk.price)
			_home_again(j, i, "%s buys %s back at %s for %d oz." % [band.leader.display_name, m.display_name, p.display_name, int(tk.price)])
		else:
			j._offer_fight("the slavers' guards", CombatTypes.Tier.BLOODED, Sandbox._forced(j.c, 6), true, wr.sea_fight_stat, false, false,
					{"kind": "unfree", "what": "rescue", "index": i}, "%s comes for %s with his men, and the slavers' guards stand to their spears." % [
							band.leader.display_name, m.display_name], true)
		return true
	return false


## A man of the band free again: back in its ranks, and the warmer for it.
static func _home_again(j: Journey, i: int, line: String) -> void:
	var band := j.c.band
	var tk: Dictionary = band.taken[i]
	var m: Man = tk.man
	band.taken.remove_at(i)
	band.add_man(m, m.joined_year)
	Loyalty.adjust(m, 20)
	j._say(line)
	band.log(line.trim_suffix("."))


## A thrall freed: honor, and a freedman tenant on the band's land.
static func manumit(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	if band.thralls.is_empty():
		return
	var t: Dictionary = band.thralls.pop_front()
	band.freedmen.append({"name": t.name, "year": j.c.cal.year})
	band.honor = clampi(band.honor + wr.manumit_honor, 0, 100)
	band.unrest = maxi(0, band.unrest - 2)
	j._say("%s frees %s before witnesses, and gives %s a cow and a plot to farm as a free tenant." % [band.leader.display_name, t.name, t.name])
	band.log("%s freed %s, who had been his thrall" % [band.leader.display_name, t.name])


# --- The year of the unfree ------------------------------------------------------------------

## A fight lost abroad: one of the band's men may be taken alive by the
## enemy and carried to a market that deals in people.
static func lost_fight(j: Journey, ctx: Dictionary, result: BattleResult) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	if result == null or result.winner == 0 or result.winner < 0 or Outlawry.in_realm(j):
		return
	var kind := str(ctx.get("kind", ""))
	if kind == "escape" or kind == "duel" or kind == "champion":
		return
	var men := band.living_men()
	if men.is_empty():
		return
	var r := Landtake.fork(j, "taken")
	if r.randf() >= wr.taken_chance:
		return
	var m: Man = men[r.randi_range(0, men.size() - 1)]
	for x in men:
		for tr in x.traits:
			if tr == "son of %s" % band.leader.display_name:
				m = x  # a son is the prize slavers look for
	var at := ""
	var best_d := INF
	for id in wr.slave_markets:
		var q := j.c.world.place(str(id))
		if q != null and q.pos.distance_to(j.roam.pos) < best_d:
			best_d = q.pos.distance_to(j.roam.pos)
			at = q.id
	if at == "":
		return
	band.remove_man(m)
	var price := wr.taken_price + wr.taken_per_tier * int(m.tier)
	band.taken.append({"man": m, "at": at, "year": j.c.cal.year, "price": price})
	band.known_places[at] = true
	var where := j.c.world.place(at).display_name
	band.log("%s was taken alive and carried off to be sold at %s" % [m.display_name, where])
	j.decisions.push_front({"kind": "unfree", "step": "taken", "name": m.display_name, "title": "Taken",
			"text": "%s was taken alive when the fight went against you, and carried off. Word is he will be sold at %s." % [m.display_name, where],
			"detail": "He can be bought back there for about %d oz, or taken back by force, before he is sold on east." % price,
			"options": [{"id": "after", "label": "Go after him"}, {"id": "lost", "label": "Give him up for lost"}]})


## A rescue fought: won, the man is free.
static func after_fight(j: Journey, ctx: Dictionary, result: BattleResult) -> void:
	if str(ctx.get("kind", "")) != "unfree":
		return
	var band := j.c.band
	var won := result != null and result.winner == 0
	var i := int(ctx.get("index", -1))
	if won and i >= 0 and i < band.taken.size():
		var m: Man = band.taken[i].man
		band.fame = clampi(band.fame + 3, 0, 100)
		_home_again(j, i, "%s takes %s back from the slavers by force." % [band.leader.display_name, m.display_name])


## The spring: men held too long are sold on east, beyond finding.
static func spring(j: Journey) -> void:
	var band := j.c.band
	for t in band.taken.duplicate():
		if j.c.cal.year - int(t.year) >= j.c.world_rules.taken_years:
			band.taken.erase(t)
			j._say("Word comes that %s has been sold on east, beyond finding." % (t.man as Man).display_name)
			band.log("%s was sold east, and never seen again" % (t.man as Man).display_name)


## While the band is away: a rising, when the unrest is at its worst and
## the watch too thin.
static func tick(j: Journey, days: float) -> void:
	_captives_tick(j, days)
	var band := j.c.band
	var wr := j.c.world_rules
	if band.thralls.is_empty() or band.unrest < wr.unrest_revolt or band.holdings.is_empty():
		return
	if not Landtake.holding_at(band, band.location).is_empty() or band.keepers.size() * 3 >= band.thralls.size():
		return
	if int(band.law.get("revolt", -1)) == j.c.cal.year:
		return
	var r := Landtake.fork(j, "revolt")
	if r.randf() >= 0.03 * days:
		return
	band.law["revolt"] = j.c.cal.year
	var h: Dictionary = band.holdings[0]
	var p := j.c.world.place(str(h.at))
	h.harried = j.c.cal.year
	var n := band.thralls.size()
	band.thralls.clear()
	band.unrest = 0
	var dead := ""
	if not band.keepers.is_empty():
		var m: Man = band.keepers.pop_back()
		m.alive = false
		dead = " They killed %s, who kept the farm," % m.display_name
	j._say("Word comes that the thralls at %s rose while you were away, as Hjorleif's Irishmen rose against him.%s burned the stores and fled with the boat: %d of them." % [
			p.display_name if p != null else "your farm", dead if dead != "" else " They", n])
	band.log("the thralls at %s rose and fled while %s was away" % [p.display_name if p != null else "his farm", band.leader.display_name])


## Into the winter: the unrest the summer left (the thralls past the
## watch, the band long away), and the freedmen grown into a house.
static func on_winter(j: Journey, p: Place) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	if not band.thralls.is_empty():
		var watch := band.keepers.size() * 3 + (2 if band.wife != "" else 0)
		var unwatched := maxi(0, band.thralls.size() - watch)
		var away := p == null or Landtake.holding_at(band, p.id).is_empty()
		band.unrest = clampi(band.unrest + unwatched * wr.unrest_per_unwatched / 2 + (wr.unrest_away if away else -1), 0, 10)
	if band.freedmen.size() >= 2 and not band.law.has("freedman_house") and not band.holdings.is_empty():
		var first: Dictionary = band.freedmen[0]
		if j.c.cal.year - int(first.year) >= wr.freedman_house_years and j.c.world.families != null:
			var name := "%s's kin" % str(first.name)
			var at := str(band.holdings[0].at)
			var region: WorldTypes.Region = j.c.world.place(at).region if j.c.world.place(at) != null else WorldTypes.Region.HORDALAND
			j.c.world.families.add_house(name, str(first.name), at, region, 3 + band.freedmen.size(), 10, "steadfast", 60)
			Families.set_standing(band, name, 70)
			band.law["freedman_house"] = name
			j._say("The freedmen on %s's land are a house of their own now, %s, and they hold by the man who freed them." % [band.leader.display_name, name])
			band.log("the freedmen on %s's land became a house, %s" % [band.leader.display_name, name])


## The thralls' winter card in the hall (WinterHall's talk), with what is
## at stake now: flight, a killing.
static func unrest_card(j: Journey) -> Dictionary:
	var band := j.c.band
	var wr := j.c.world_rules
	var t: Dictionary = band.thralls[0]
	var opts: Array[Dictionary] = [
		{"id": "press", "label": "Have it out of them", "hint": "The stores are found. A hard hand: the unrest rises, honor -1."},
		{"id": "watch", "label": "Set a man to watch them", "hint": "The unrest falls; the store is short what is gone."},
		{"id": "free", "label": "Free %s, who speaks for them" % t.name, "hint": "Honor +%d; the unrest falls." % wr.manumit_honor},
		{"id": "let", "label": "Let it lie"}]
	var mood := "sullen" if band.unrest < 4 else ("near to running" if band.unrest < wr.unrest_revolt else "near to rising")
	return {"kind": "thralls", "text": "Rations go missing from the stores, %d of them. The thralls are %s (unrest %d of 10), and %s will not meet your eye." % [
			wr.thrall_food * 2, mood, band.unrest, t.name], "options": opts}


## The thralls' card answered (WinterHall.resolve).
static func resolve_unrest(j: Journey, _card: Dictionary, choice: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	if band.thralls.is_empty():
		return
	var r := Landtake.fork(j, "unrest")
	var lost := mini(wr.thrall_food * 2, band.food)
	match choice:
		"press":
			band.unrest = clampi(band.unrest + wr.unrest_pressed, 0, 10)
			band.honor = clampi(band.honor - 1, 0, 100)
			lost = 0
		"watch":
			band.unrest = maxi(0, band.unrest - 2)
		"free":
			manumit(j)
			band.unrest = maxi(0, band.unrest - 1)
		_:
			band.unrest = clampi(band.unrest + 1, 0, 10)
	band.food -= lost
	if band.unrest >= wr.unrest_revolt + 2 and choice == "press" and not band.living_men().is_empty():
		var men := band.living_men()
		var m: Man = men[r.randi_range(0, men.size() - 1)]
		m.alive = false
		band.remove_man(m)
		var t: Dictionary = band.thralls.pop_front()
		j._say("In the dark of the winter %s killed %s with a wood-axe and was gone before morning." % [t.name, m.display_name])
		band.log("%s was killed by %s, a thrall, who fled" % [m.display_name, t.name])
		band.unrest = maxi(0, band.unrest - 3)
	elif band.unrest >= wr.unrest_revolt and choice != "watch" and choice != "free":
		var run := mini(band.thralls.size(), 1 + r.randi_range(0, 1))
		var names := PackedStringArray()
		for i in run:
			names.append(str(band.thralls.pop_back().name))
		j._say("%s ran from the farm in the night and were not found." % " and ".join(names))
		band.log("%s, thralls, ran away" % ", ".join(names))
		band.unrest = maxi(0, band.unrest - 2)
	elif lost > 0:
		j._say("Rations went missing from the stores; %d were not found again." % lost)


# --- The stand-in player -------------------------------------------------------------------

## A man of his bent over the unfree: the Viking keeps them bound for the
## market (the slaver's road, to be measured); a man with land takes them
## home; the law-wise and the skald let them go, unless their kin will pay;
## the others ransom where they can.
static func bot(j: Journey, d: Dictionary, bent: int) -> String:
	var ids := {}
	for o in d.options:
		if o.get("enabled", true):
			ids[str(o.id)] = true
	match str(d.step):
		"captives":
			if bent == Way.Id.VIKING and JourneyBot.slaver(j):
				return "bound"
			if ids.has("thralls") and j.c.band.thralls.size() < 6:
				return "thralls"
			if (bent == Way.Id.LAWMAN or bent == Way.Id.SKALD) and str(d.named) == "":
				return "free"
			return "ransom" if ids.has("ransom") else "free"
		"taken":
			return "after"
	return str(d.options[0].id)
