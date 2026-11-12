class_name Landtake
extends RefCounted
## Land of the band's own, and the land-taking in Iceland (concept.md,
## "Land", "Saga threads": Iceland's land-take). Before this `band.land`
## was set to 0 and never raised on the player's path.
##
## In Norway land is bought of a house that will sell (a well-wisher or
## better; a friend sells cheaper), granted by a lord to his hersir (with
## a duty: his summons each spring), won at the Thing, or claimed where a
## house the band has ended by the sword left a steading empty. Each piece
## is a holding on Band (`holdings`), at a place on the map. The first
## gives the band its hall site (`Band.hall_at`: the winter's "home"
## lodging, where it builds). Land yields at the thaw (`thaw_yield`), as
## much as it is worked: every unit wants `land_hands_per_unit` hands
## (thralls, freedmen, the wife's household, men left to keep it); an
## untended unit yields only the tenants' due. Held a generation, it is
## odal. Raiders who come to the band's farm while it is away meet the
## keepers, the household and the thralls (`tick`).
##
## Iceland, once the timeline opens it (874): with a knarr (or passage on a
## settler's), the band takes land the saga way (fire carried round in a
## day, the high-seat pillars thrown overboard, or a piece bought of
## Ingolf's kin), names it, and settles (`settle_iceland`): outlawry no
## longer reaches it, its men who want land and a home have them, and the
## saga may end there (the generations package's hook, `offer_ending`).
## Iceland grows by the settler houses the years bring (`year_end`).
##
## Men's ambitions for land, a home and vengeance move here (`ambition`,
## `watch`); a wife's in Families.marry_into.

const ICELAND_NAMES := ["Borg", "Hof", "Hvamm", "Holt", "Reykir", "Bakki", "Hlid", "Hjardarholt", "Lund", "Eyri", "Grund", "Vatnsdal"]
## Where the pillars come ashore: units of land, and what it is good for.
const PILLAR_SITES := [
	{"text": "a wide bay with a good harbour, where the grass is thin and neighbours are near", "units": 3, "food": 0, "silver": 2, "near": true},
	{"text": "a long strand with grazing for many beasts, no harbour worth the name, and no neighbour within a day's ride", "units": 5, "food": 3, "silver": 0, "near": false},
	{"text": "a fjord with fair grass and a fair harbour, under a steep fell", "units": 4, "food": 1, "silver": 1, "near": false},
]


## A fork of the campaign's seed for the law, the land and the unfree, kept
## apart from the summer's own forks so that adding these leaves the rest
## of the summer as it was drawn.
static func fork(j: Journey, label: String) -> SimRng:
	var n := int(j.life.get("lln", 0)) + 1
	j.life["lln"] = n
	return j.c.rng.fork("lawland:%d:%s:%d" % [j.c.cal.year, label, n])


# --- Holding land -----------------------------------------------------------------------

## Adds land to the band (no telling): a new holding at `at`, or more units
## on the one it has there. The first holding is its hall site.
static func add_holding(band: Band, at: String, units: int, how: String, year: int, name := "") -> Dictionary:
	for h in band.holdings:
		if str(h.at) == at:
			h.units = int(h.units) + units
			band.land += units
			return h
	var h2 := {"at": at, "units": units, "how": how, "year": year, "name": name, "harried": -1, "struck": -1.0}
	band.holdings.append(h2)
	band.land += units
	if band.holdings.size() == 1 or at == "iceland":
		band.hall_at = at
	return h2


## Land given to the band on the map: the holding, the telling, the men
## who wanted land the nearer it.
static func grant(j: Journey, at: String, units: int, how: String, name := "") -> Dictionary:
	var band := j.c.band
	var p := j.c.world.place(at)
	var h := add_holding(band, at, units, how, j.c.cal.year, name)
	var where := p.display_name if p != null else at
	j._say("%s has land of his own at %s now: %d %s, %s." % [band.leader.display_name, where, units, "unit" if units == 1 else "units", how])
	band.log("%s got land at %s, %s" % [band.leader.display_name, where, how])
	band.known_places[at] = true
	ambition(j, CampaignTypes.Ambition.LAND, j.c.world_rules.ambition_land, "land")
	return h


## The holding the band has at a place, or {}.
static func holding_at(band: Band, at: String) -> Dictionary:
	for h in band.holdings:
		if str(h.at) == at:
			return h
	return {}


## Every man who wants `kind` is the nearer it by `amount`.
static func ambition(j: Journey, kind: int, amount: int, _why: String) -> void:
	var band := j.c.band
	for m in band.living_men():
		if m.ambition == kind:
			Loyalty.ambition_progress(j.c.rules, band, m, amount, j.said)


## Hands to work the band's land: thralls, freedmen, men left to keep it,
## and the wife's household.
static func hands(rules: WorldRules, band: Band) -> int:
	var n := band.thralls.size() + band.freedmen.size() + band.keepers.size()
	if band.wife != "":
		n += rules.household_hands + band.household_skill / 2
	return n


## Land units worked and held: {worked, units}.
static func worked(rules: WorldRules, band: Band) -> Dictionary:
	var units := 0
	for h in band.holdings:
		units += int(h.units)
	return {"worked": mini(units, hands(rules, band) / maxi(1, rules.land_hands_per_unit)), "units": units}


## What the land yields at the thaw (Campaign._thaw). A band with no
## holdings (the old sandbox's AI, given `start_land`) yields as before.
## Returns {food, silver}.
static func thaw_yield(rules: WorldRules, band: Band, year: int, log: PackedStringArray) -> Dictionary:
	if band.holdings.is_empty():
		var f0 := band.land * rules.land_food_per_unit
		var s0 := band.land * rules.land_silver_per_unit
		band.food += f0
		band.silver += s0
		return {"food": f0, "silver": s0}
	var w := worked(rules, band)
	var units := maxi(1, int(w.units))
	var share := (float(w.worked) + float(units - int(w.worked)) * rules.land_untended_share) / float(units)
	var food := 0
	var silver := 0
	for h in band.holdings:
		var u := float(h.units) * share
		if year - int(h.year) >= rules.odal_years or bool(h.get("odal", false)):
			u *= 1.0 + rules.odal_bonus
		if int(h.get("harried", -1)) == year:
			u *= 1.0 - rules.farm_raid_loss
		food += roundi(u * float(rules.land_food_per_unit + int(h.get("food", 0))))
		silver += roundi(u * float(rules.land_silver_per_unit + int(h.get("silver", 0))))
	var eaten := mini(food, band.thralls.size() * rules.thrall_food)
	band.food += food - eaten
	band.silver += silver
	var line := "The land yielded %d rations and %d oz (%d of %d units worked)%s." % [food, silver, int(w.worked), int(w.units),
			(", and the thralls ate %d" % eaten) if eaten > 0 else ""]
	log.append(line)
	if int(w.worked) == 0:
		band.log("the fields went untended for want of hands")
	return {"food": food - eaten, "silver": silver}


## Whether a place may be raided by the band: not Iceland (empty, or the
## settlers' own), not land the band holds.
static func raidable(j: Journey, p: Place) -> bool:
	if p == null or p.region == WorldTypes.Region.ICELAND:
		return false
	return holding_at(j.c.band, p.id).is_empty()


## A steading of a house's that could be given up (for a land verdict): a
## farmstead it holds, its seat last; "" when it holds none.
static func house_land(j: Journey, house: String) -> String:
	var fs := j.c.world.families
	if fs == null or not fs.houses.has(house):
		return ""
	var h := fs.house(house)
	var best := ""
	for id in h.holdings:
		var p := j.c.world.place(id)
		if p == null or p.kind != WorldTypes.PlaceKind.FARMSTEAD or not Families.HOME_REGIONS.has(p.region):
			continue
		if best == "" or (best == h.seat and id != h.seat):
			best = id
	return best


# --- Deeds ----------------------------------------------------------------------------------

## What may be done about land where the band stands: buy land of a house
## that will sell, claim an empty steading, leave men to keep the band's
## own, take them back, take land in Iceland.
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null:
		return out
	var band := j.c.band
	var wr := j.c.world_rules
	var fs := j.c.world.families
	var mine := holding_at(band, p.id)
	if p.id == "iceland":
		if p.is_open(j.c.world.year) and not band.settled_iceland:
			var knarr := band.ship != null and band.ship.kind == WorldTypes.ShipKind.KNARR
			out.append({"id": "landtake", "label": "Take land in Iceland",
					"enabled": knarr or band.silver >= wr.iceland_passage,
					"hint": ("Your knarr carries your household and your beasts." if knarr else
							"A household and its beasts want a knarr: a settler's will bring them for %d oz." % wr.iceland_passage)
							+ " Out of reach of kings."})
	elif p.kind == WorldTypes.PlaceKind.FARMSTEAD and Families.HOME_REGIONS.has(p.region) and fs != null and fs.houses.has(p.family):
		var step := Families.support_step(wr, band, p.family)
		if step != "" and Feud.find(band, p.family).is_empty():
			var price := land_price(wr, band, p.family)
			out.append({"id": "buy_land", "label": "Ask %s for land (%d oz a unit)" % [fs.house(p.family).head, price],
					"enabled": band.silver >= price,
					"hint": "Land of your own: a hall site, and food and silver every winter when it is worked."})
		var claim: Dictionary = band.law.get("claimable", {})
		if claim.has(p.family) and j.c.cal.year - int(claim[p.family]) <= 2 and mine.is_empty():
			out.append({"id": "claim_land", "label": "Claim the empty steading",
					"hint": "%s have no man left to farm it since the reckoning. Their kin will not like it." % p.family})
	if not mine.is_empty():
		var men := band.living_men().size()
		if band.keepers.size() < wr.keepers_max and men > 1:
			out.append({"id": "keepers", "label": "Leave men to keep the farm",
					"hint": "They work the land and hold it while you are away; they do not fight with you."})
		if not band.keepers.is_empty():
			out.append({"id": "keepers_back", "label": "Take your keepers back (%d)" % band.keepers.size(),
					"hint": "They come with you again; the farm is the household's alone."})
	return out


## A unit of land's price from a house: a friend sells cheaper.
static func land_price(rules: WorldRules, band: Band, house: String) -> int:
	return rules.land_price_friend if Families.is_friend(rules, band, house) else rules.land_price


static func act(j: Journey, id: String) -> bool:
	var band := j.c.band
	var wr := j.c.world_rules
	var p := j.here()
	match id:
		"buy_land":
			j.decisions.push_front(_buy_decision(j))
		"claim_land":
			var claim: Dictionary = band.law.get("claimable", {})
			claim.erase(p.family)
			grant(j, p.id, wr.claim_units, "claimed where %s left it empty" % p.family)
			j._shift(p.family, wr.claim_standing)
		"keepers":
			j.decisions.push_front(_keepers_decision(j))
		"keepers_back":
			for m in band.keepers:
				band.add_man(m, m.joined_year)
			j._say("%s takes his keepers back into the band: %d men." % [band.leader.display_name, band.keepers.size()])
			band.keepers.clear()
		"landtake":
			j.decisions.push_front(_iceland_decision(j))
		_:
			return false
	return true


static func _buy_decision(j: Journey) -> Dictionary:
	var band := j.c.band
	var wr := j.c.world_rules
	var p := j.here()
	var h := j.c.world.families.house(p.family)
	var price := land_price(wr, band, p.family)
	var w := worked(wr, band)
	var opts: Array[Dictionary] = []
	for n in range(1, wr.land_buy_max + 1):
		opts.append({"id": "buy:%d" % n, "label": "Buy %d %s (%d oz)" % [n, "unit" if n == 1 else "units", n * price], "enabled": band.silver >= n * price})
	opts.append({"id": "no", "label": "Not now"})
	var detail := "A unit worked yields about %d rations and %d oz a winter, and wants %d hands. You have %d hands for %d units: thralls %d, freedmen %d, keepers %d%s. Untended, a unit yields a quarter." % [
			wr.land_food_per_unit, wr.land_silver_per_unit, wr.land_hands_per_unit, hands(wr, band), int(w.units),
			band.thralls.size(), band.freedmen.size(), band.keepers.size(), (", the household %d" % (wr.household_hands + band.household_skill / 2)) if band.wife != "" else ""]
	return {"kind": "land", "step": "buy", "title": "Land at %s" % p.display_name, "place": p.id,
			"text": "%s will sell you land at %s, %d oz a unit. Land of your own is a hall site, and in a generation it is odal." % [h.head, p.display_name, price],
			"detail": detail, "options": opts}


static func _keepers_decision(j: Journey) -> Dictionary:
	var band := j.c.band
	var wr := j.c.world_rules
	var opts: Array[Dictionary] = []
	var room := mini(wr.keepers_max - band.keepers.size(), band.living_men().size() - 1)
	for n in range(1, room + 1):
		opts.append({"id": "keep:%d" % n, "label": "Leave %d %s" % [n, "man" if n == 1 else "men"]})
	opts.append({"id": "no", "label": "Leave nobody"})
	return {"kind": "land", "step": "keepers", "title": "Keepers for the farm",
			"text": "Who will keep the farm while you are away? Each man left is a hand for the land and a spear against raiders, and one fewer in your wall.",
			"detail": "The thralls want watching too: unrest is %d of 10." % band.unrest, "options": opts}


static func answer(j: Journey, d: Dictionary, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	match str(d.step):
		"buy":
			if id.begins_with("buy:"):
				var n := int(id.trim_prefix("buy:"))
				var p := j.c.world.place(str(d.place))
				var price := land_price(wr, band, p.family) * n
				if band.silver >= price:
					band.silver -= price
					grant(j, p.id, n, "bought of %s for %d oz" % [p.family, price])
					j._shift(p.family, 3)
		"keepers":
			if id.begins_with("keep:"):
				var n2 := int(id.trim_prefix("keep:"))
				var pool := band.living_men()
				pool.sort_custom(func(a: Man, b: Man) -> bool: return a.tier < b.tier or (a.tier == b.tier and a.id > b.id))
				var left := PackedStringArray()
				for m in pool.slice(0, n2):
					if m.id == band.war_leader_id or m.id == band.sworn_second_id:
						continue
					band.remove_man(m)
					band.keepers.append(m)
					left.append(m.display_name)
				if not left.is_empty():
					j._say("%s leaves %s to keep the farm." % [band.leader.display_name, ", ".join(left)])
		"duty":
			_duty(j, id)
		"quarrel":
			_quarrel(j, d, id)
		"iceland":
			_iceland_how(j, id)
		"iceland_name":
			var s: Dictionary = j.life.get("landtake", {})
			settle_iceland(j, int(s.get("units", 2)), id.trim_prefix("name:"), s)


# --- The spring: the lord's summons, a land quarrel -----------------------------------------

static func spring(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var r := fork(j, "land_spring")
	watch(j)
	var liege := str(band.law.get("liege", ""))
	if liege != "" and not j.first_summer() and not Outlawry.is_outlawed(band, j.c.cal):
		var f: Faction = j.c.world.factions.get(liege, null)
		var granted := false
		for h in band.holdings:
			if str(h.how).begins_with("granted"):
				granted = true
		if f != null and f.alive and granted:
			j.decisions.append({"kind": "land", "step": "duty", "title": "The lord's summons",
					"text": "%s calls his hersir to his levy for the summer's first weeks, as the land he gave is held." % f.leader,
					"options": [{"id": "go", "label": "Go to the levy (%d days)" % wr.levy_duty_days},
						{"id": "pay", "label": "Send silver instead (%d oz)" % wr.levy_duty_ounces, "enabled": band.silver >= wr.levy_duty_ounces},
						{"id": "refuse", "label": "Refuse him", "hint": "He may take the land back."}]})
	var norse := []
	for h in band.holdings:
		var p := j.c.world.place(str(h.at))
		if p != null and Families.HOME_REGIONS.has(p.region) and p.family != "" and not j.first_summer():
			norse.append(h)
	if not norse.is_empty() and r.randf() < wr.land_quarrel_chance:
		var h2: Dictionary = norse[r.randi_range(0, norse.size() - 1)]
		var p2 := j.c.world.place(str(h2.at))
		var fam := p2.family
		if fam != "" and not Families.is_friend(wr, band, fam):
			j.decisions.append({"kind": "land", "step": "quarrel", "house": fam, "at": p2.id, "title": "Boundary stones",
					"text": "%s have moved the boundary stones of your land at %s in the night, and graze their beasts on your grass." % [fam, p2.display_name],
					"options": [{"id": "thing", "label": "Take it to the Thing", "hint": "Plead the bounds of your land this summer."},
						{"id": "drive", "label": "Drive them off", "hint": "Their men will stand: a fight."},
						{"id": "give", "label": "Let them have the strip", "hint": "Peace, and less land."}]})


static func _duty(j: Journey, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var liege := str(band.law.get("liege", ""))
	var f: Faction = j.c.world.factions.get(liege, null)
	var who := f.leader if f != null else "the lord"
	match id:
		"go":
			j._pass(float(wr.levy_duty_days))
			FactionAI.shift(j.c.world, liege, FactionAI.BAND, 5)
			band.rank_progress += 5
			j._say("%s goes to %s's levy, as a hersir must: %d days." % [band.leader.display_name, who, wr.levy_duty_days])
		"pay":
			band.silver -= mini(wr.levy_duty_ounces, band.silver)
			j._say("%s sends %s silver in place of his spears." % [band.leader.display_name, who])
		_:
			FactionAI.shift(j.c.world, liege, FactionAI.BAND, -20)
			band.law["refused_duty"] = int(band.law.get("refused_duty", 0)) + 1
			if int(band.law.refused_duty) >= 2:
				for h in band.holdings.duplicate():
					if str(h.how).begins_with("granted"):
						band.holdings.erase(h)
						band.land -= int(h.units)
						j._say("%s takes back the land he gave %s, who would not answer his summons." % [who, band.leader.display_name])
						band.log("%s lost the land %s gave him" % [band.leader.display_name, who])
			else:
				j._say("%s will not answer %s's summons; %s remembers it." % [band.leader.display_name, who, who])


static func _quarrel(j: Journey, d: Dictionary, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var fam := str(d.house)
	match id:
		"thing":
			var lc: Dictionary = band.law.get("land_case", {})
			lc[fam] = j.c.cal.year
			band.law["land_case"] = lc
			j._say("%s will plead the bounds of his land against %s at the Thing." % [band.leader.display_name, fam])
		"drive":
			var men := Sandbox._forced(j.c, 5)
			j._offer_fight("men of %s" % fam, wr.house_fight_tier, men, true, wr.house_fight_stat, false, false,
					{"kind": "land_fight", "family": fam, "at": str(d.at)}, "%s goes out to drive %s's beasts off his grass." % [band.leader.display_name, fam], true)
		_:
			var h := holding_at(band, str(d.at))
			if not h.is_empty() and int(h.units) > 1:
				h.units = int(h.units) - 1
				band.land -= 1
				j._say("%s lets %s have the strip; his land is the less by a unit." % [band.leader.display_name, fam])
			else:
				band.honor = clampi(band.honor - 2, 0, 100)
				j._say("%s lets %s have the strip, and men say he is easily moved." % [band.leader.display_name, fam])
			j._shift(fam, 5)


## A fight over land: driven off, the neighbours are colder for it; lost,
## the strip is theirs.
static func after_fight(j: Journey, ctx: Dictionary, result: BattleResult) -> void:
	var band := j.c.band
	var won := result != null and result.winner == 0
	match str(ctx.get("kind", "")):
		"land_fight":
			if won:
				j._say("%s's men are driven off the grass, and the stones go back where they stood." % ctx.family)
				j._shift(str(ctx.family), -10)
			else:
				var h := holding_at(band, str(ctx.get("at", "")))
				if not h.is_empty() and int(h.units) > 1:
					h.units = int(h.units) - 1
					band.land -= 1
				j._say("%s keep the strip they took." % ctx.family)
		"reckoning":
			if won:
				var claim: Dictionary = band.law.get("claimable", {})
				claim[str(ctx.family)] = j.c.cal.year
				band.law["claimable"] = claim


# --- The summer: the farm while the band is away ----------------------------------------------

## Raiders who came to one of the band's holdings while it was away (the
## world's own raids, Roam.struck): the keepers, the household and the
## thralls against them.
static func tick(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	watch(j)
	for h in band.holdings:
		var at := str(h.at)
		if not j.roam.struck.has(at) or float(j.roam.struck[at]) <= float(h.get("struck", -1.0)):
			continue
		h.struck = float(j.roam.struck[at])
		if band.location == at:
			continue  # the band is there: WorldLife asks it to stand with its people
		var r := fork(j, "farm_raid")
		var p := j.c.world.place(at)
		var guard := band.keepers.size() * 2 + (band.household_skill if band.wife != "" else 0) + band.thralls.size() / 3
		var raiders := wr.rival_crew
		if guard + r.randi_range(0, 4) >= raiders + r.randi_range(0, 4):
			j._say("Word comes that raiders came to your farm at %s, and your people there beat them off." % p.display_name)
			band.log("raiders were beaten off at %s's farm at %s" % [band.leader.display_name, p.display_name])
		else:
			h.harried = j.c.cal.year
			var lost := mini(band.thralls.size(), 1 + r.randi_range(0, 1))
			for i in lost:
				band.thralls.pop_back()
			var dead := ""
			if not band.keepers.is_empty() and r.randf() < 0.5:
				var m: Man = band.keepers.pop_back()
				m.alive = false
				dead = " %s fell holding the door." % m.display_name
			j._say("Word comes that raiders fell on your farm at %s while you were away: they drove off the beasts%s.%s" % [
					p.display_name, (" and %d of the thralls" % lost) if lost > 0 else "", dead])
			band.log("raiders harried %s's farm at %s" % [band.leader.display_name, p.display_name])


## Men's ambitions the band's doings have answered since last looked:
## a feud settled is vengeance had.
static func watch(j: Journey) -> void:
	var band := j.c.band
	var settled := 0
	for f in band.feuds:
		if f.settled:
			settled += 1
	var seen := int(band.law.get("settled_seen", 0))
	if settled > seen:
		band.law["settled_seen"] = settled
		ambition(j, CampaignTypes.Ambition.VENGEANCE, j.c.world_rules.ambition_vengeance * (settled - seen), "vengeance")


## The band goes into its winter quarters: wintering on its own land, the
## keepers sit at its benches again, and the men who wanted a home of
## their own have it the nearer.
static func on_winter(j: Journey, p: Place) -> void:
	var band := j.c.band
	if p == null or holding_at(band, p.id).is_empty():
		return
	for m in band.keepers:
		band.add_man(m, m.joined_year)
	band.keepers.clear()
	if int(band.law.get("home_year", -1)) != j.c.cal.year:
		band.law["home_year"] = j.c.cal.year
		ambition(j, CampaignTypes.Ambition.HOME, j.c.world_rules.ambition_home, "home")


# --- Rank: the hersir's land ------------------------------------------------------------------

## The lord who made the band's leader his hersir gives him land, with a
## duty (the summons each spring). From Sandbox._promote.
static func on_rank(c: Campaign, rank: int, log: PackedStringArray) -> void:
	if rank != WorldTypes.Rank.HERSIR or c.world == null or c.band.law.has("liege"):
		return
	var best: Faction = null
	for fid in c.world.factions:
		var f: Faction = c.world.factions[fid]
		if not f.alive or (f.kind != WorldTypes.FactionKind.KING and f.kind != WorldTypes.FactionKind.JARL):
			continue
		if best == null or FactionAI.relation(c.world, f.id, FactionAI.BAND) > FactionAI.relation(c.world, best.id, FactionAI.BAND):
			best = f
	if best == null or FactionAI.relation(c.world, best.id, FactionAI.BAND) < c.world_rules.contract_relation:
		return
	var at := ""
	var hold: Array = best.holdings.duplicate()
	hold.sort()
	for id in hold:
		var p := c.world.place(str(id))
		if p != null and p.kind == WorldTypes.PlaceKind.FARMSTEAD and Families.HOME_REGIONS.has(p.region):
			at = p.id
			break
	if at == "":
		return
	c.band.law["liege"] = best.id
	add_holding(c.band, at, c.world_rules.hersir_grant_units, "granted by %s for service" % best.leader, c.cal.year)
	var line := "%s gives %s land at %s as his hersir, and will call him to his levy." % [best.leader, c.band.leader.display_name, c.world.place(at).display_name]
	log.append(line)
	c.band.log(line)


# --- Iceland ---------------------------------------------------------------------------------

static func _iceland_decision(j: Journey) -> Dictionary:
	var band := j.c.band
	var wr := j.c.world_rules
	var l := band.leader
	var fire := _fire_units(wr, band, 0)
	var opts: Array[Dictionary] = [
		{"id": "fire", "label": "Carry fire round the land", "hint": "As much as you can walk round with a brand in a day: about %d units, the near shore, Ingolf's kin for neighbours." % fire},
		{"id": "pillars", "label": "Throw the high-seat pillars overboard", "hint": "Settle where the gods bring them ashore: more land or less, harbour or grass, as it falls. The men will think you lucky."},
		{"id": "buy", "label": "Buy land of Ingolf's kin (%d oz)" % wr.iceland_buy_price, "enabled": band.silver >= wr.iceland_buy_price,
			"hint": "A small piece by their own, and their goodwill."}]
	return {"kind": "land", "step": "iceland", "title": "The land-take",
			"text": "The ship lies in a bay under the fells, with %s's household and beasts aboard. How will you take your land?" % l.display_name,
			"detail": "Might %d, Nerve %d: the fire goes as far as you can carry it. Luck: %s." % [l.stat(CombatTypes.Stat.MIGHT), l.stat(CombatTypes.Stat.NERVE), Omens.luck_words(band.luck)],
			"options": opts}


static func _fire_units(rules: WorldRules, band: Band, roll: int) -> int:
	var l := band.leader
	return maxi(2, rules.iceland_fire_base + (l.stat(CombatTypes.Stat.MIGHT) + l.stat(CombatTypes.Stat.NERVE)) / 5 + roll)


static func _iceland_how(j: Journey, id: String) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var r := fork(j, "landtake")
	var knarr := band.ship != null and band.ship.kind == WorldTypes.ShipKind.KNARR
	if not knarr:
		band.silver -= mini(wr.iceland_passage, band.silver)
	var s := {"how": id, "units": 2, "food": 0, "silver": 0, "near": true, "text": ""}
	match id:
		"pillars":
			var site: Dictionary = PILLAR_SITES[r.randi_range(0, PILLAR_SITES.size() - 1)]
			s.units = int(site.units)
			s.food = int(site.food)
			s.silver = int(site.silver)
			s.near = bool(site.near)
			s.text = "The pillars come ashore at %s." % site.text
			band.luck = clampi(band.luck + 1, Leader.LUCK_MIN, Leader.LUCK_MAX)
		"buy":
			band.silver -= mini(wr.iceland_buy_price, band.silver)
			s.units = wr.iceland_buy_units
			s.food = 1
			s.text = "Ingolf's kin sell %s a piece of their land-take by the sea." % band.leader.display_name
			j._shift("Ingolf's kin", 15)
		_:
			s.units = _fire_units(wr, band, r.randi_range(-1, 1))
			s.text = "%s carries the fire round from sunrise to sunset: %d units of land." % [band.leader.display_name, int(s.units)]
			j._shift("Ingolf's kin", 5)
	j._say(str(s.text))
	j.life["landtake"] = s
	var names: Array = ICELAND_NAMES.duplicate()
	var opts: Array[Dictionary] = []
	for i in 3:
		var n: String = names.pop_at(r.randi_range(0, names.size() - 1))
		opts.append({"id": "name:" + n, "label": n})
	j.decisions.push_front({"kind": "land", "step": "iceland_name", "title": "The land-take",
			"text": "%s What will you call your land?" % str(s.text), "options": opts})


## The band takes its land in Iceland and settles: its home and hall
## there, Norway's outlawry out of reach, its men with the land and the
## home they wanted, the saga's possible end (`offer_ending`, the
## generations package: called when it is there). `Band.settled_iceland`
## is the flag the endings read.
static func settle_iceland(j: Journey, units: int, name: String, s := {}) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var who := band.leader.display_name
	var h := add_holding(band, "iceland", units, "taken in Iceland, %d" % j.c.cal.year, j.c.cal.year, name)
	h["food"] = int(s.get("food", 0))
	h["silver"] = int(s.get("silver", 0))
	band.settled_iceland = true
	band.home = "iceland"
	band.hall_at = "iceland"
	band.law["iceland_year"] = j.c.cal.year
	j.life.erase("landtake")
	var place := j.c.world.place("iceland")
	if place != null:
		place.wealth += wr.iceland_wealth_per_house
		place.base_wealth = place.wealth
	j._say("%s names his land %s, and brings his household and his beasts ashore. Here he will build his hall." % [who, name])
	band.log("%s took land in Iceland and called it %s" % [who, name])
	if Outlawry.is_outlawed(band, j.c.cal):
		j._say("Norway's law does not reach Iceland: %s is no man's outlaw here." % who)
		Outlawry.lift(band, j.said)
		Outlawry.tick(j)
	for m in band.living_men():
		if m.ambition == CampaignTypes.Ambition.LAND or m.ambition == CampaignTypes.Ambition.HOME:
			Loyalty.ambition_progress(j.c.rules, band, m, j.c.rules.ambition_fulfilled, j.said)
	if bool(s.get("near", true)) and j.c.world.families != null:
		for st in wr.iceland_settlers:
			if j.c.world.families.houses.has(str(st[1])):
				j._shift(str(st[1]), 10)
	j.c.tally.emigrations = int(j.c.tally.get("emigrations", 0)) + 1
	# The saga may end here: the generations package's hook, when it is in.
	if j.has_method("offer_ending"):
		j.call("offer_ending", "iceland")


## The settler houses the years bring to Iceland (WorldRules.iceland_settlers),
## new houses in the web, and the land-take the richer for each. From
## Sandbox.year_end.
static func year_end(c: Campaign) -> void:
	var world := c.world
	var fs := world.families if world != null else null
	var place := world.place("iceland") if world != null else null
	if fs == null or place == null or not place.is_open(c.cal.year):
		return
	for st in c.world_rules.iceland_settlers:
		if int(st[0]) > c.cal.year or fs.houses.has(str(st[1])):
			continue
		fs.add_house(str(st[1]), str(st[2]), "iceland", WorldTypes.Region.ICELAND, 6, 20, str(st[3]))
		if fs.houses.has("Ingolf's kin"):
			fs.add_tie(str(st[1]), "Ingolf's kin", "friend", c.cal.year)
		place.wealth += c.world_rules.iceland_wealth_per_house
		place.base_wealth += c.world_rules.iceland_wealth_per_house
		var line := "%s comes out to Iceland with his household and takes land there." % str(st[2])
		var told: PackedStringArray = fs.tidings.get(c.cal.year, PackedStringArray())
		told.append(line)
		fs.tidings[c.cal.year] = told
		if c.band.settled_iceland:
			Families.set_standing(c.band, str(st[1]), Families.standing(c.band, str(st[1])) + 10)


# --- The stand-in player -------------------------------------------------------------------

## A man of his bent about land: he buys a unit when the silver is well
## over what he needs, keeps a man at the farm when he has thralls to
## watch, and takes land in Iceland when he is there (by fire, unless he is
## a skald: the pillars); he goes to the levy as a king's man, pays
## otherwise; a land quarrel goes to the Thing for the law-wise, the
## fighting ways drive them off.
static func bot(j: Journey, d: Dictionary, bent: int) -> String:
	var band := j.c.band
	var ids := {}
	for o in d.options:
		if o.get("enabled", true):
			ids[str(o.id)] = true
	match str(d.step):
		"buy":
			if ids.has("buy:2") and band.silver >= 260:
				return "buy:2"
			return "buy:1" if ids.has("buy:1") else "no"
		"keepers":
			return "keep:1" if ids.has("keep:1") else "no"
		"duty":
			if bent == Way.Id.KINGS_MAN or not ids.has("pay"):
				return "go"
			return "pay"
		"quarrel":
			if bent == Way.Id.LAWMAN or bent == Way.Id.SKALD or bent == Way.Id.TRADER:
				return "thing"
			return "drive" if band.fighters(j.c.rules).size() >= 6 else "give"
		"iceland":
			if bent == Way.Id.SKALD:
				return "pillars"
			return "fire"
	return str(d.options[0].id)
