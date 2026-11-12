class_name Outlawry
extends RefCounted
## Outlawry (concept.md, Outlawry). Lesser outlawry is three years abroad:
## the man must be out of Norway by the winter, or he is a full outlaw,
## and it lapses if he stays away (`outlaw_until`). Full outlawry
## (skóggangr) is open-ended until lifted: any man may kill him, and the
## halls and markets of the realm that outlawed him are shut to him.
## Norway's law does not reach the west, Frankia, Denmark or Iceland.
##
## The one predicate is `door_shut`: winter, rest, passage, hire, market,
## work, the Thing and the houses' favours all ask it, and so does
## `gate`, which greys the deeds the map offers. The outlaw's roads are
## here too: the wilds (camping, robbing the road), the west, a king's
## pardon bought with silver or service, and the Grettir clause (three
## outlaws killed, and a man has earned his peace). Bounty hunters
## (`Roam.Party` kind "hunters") come for a full outlaw in Norway every
## spring and hunt him whatever the odds; they go home when he leaves the
## realm or is pardoned. Rollo's exile takes the band west to the Seine.
## See world-architecture.md, Module M, and docs/design/notes/law-land.md.

## Deeds by what they ask of a house or a market: the id, or its prefix
## before ":", to the door it knocks at.
const DOORS := {"winter": "winter", "rest": "rest", "passage": "passage", "hire": "hire", "work": "work",
	"heal": "shelter", "men": "shelter", "hull": "market", "rations": "market", "captives": "market",
	"ransom": "market", "verse": "work", "counsel": "work", "champion": "work", "labour": "work", "crew": "work",
	"felag": "work", "escort": "work", "case": "thing", "speak": "thing", "answer": "thing", "buy_land": "market",
	"thralls_sell": "market", "volva": "shelter"}


static func declare(rules: WorldRules, band: Band, cal: Calendar, full: bool, log: PackedStringArray) -> void:
	if full:
		band.outlawry = WorldTypes.Outlawry.FULL
		band.outlaw_until = 0
		band.law["outlawed"] = cal.year
		log.append("The band is declared full outlaws: any man may kill them without penalty.")
		band.log("Declared full outlaws.")
		return
	if band.outlawry == WorldTypes.Outlawry.FULL:
		log.append("The band is already full outlaws; the lesser sentence changes nothing.")
		return
	band.outlawry = WorldTypes.Outlawry.LESSER
	band.outlaw_until = maxi(band.outlaw_until, cal.year + rules.lesser_outlawry_years)
	band.law["exile_by"] = cal.year
	band.law["outlawed"] = cal.year
	log.append("The band is outlawed until %d." % band.outlaw_until)
	band.log("Outlawed until %d." % band.outlaw_until)


static func is_outlawed(band: Band, cal: Calendar) -> bool:
	match band.outlawry:
		WorldTypes.Outlawry.FULL:
			return true
		WorldTypes.Outlawry.LESSER:
			return cal.year < band.outlaw_until
	return false


## No contracts, no winter hospitality, no market will trade (anywhere:
## the old sandbox's rule; the played summer asks `door_shut`).
static func halls_closed(band: Band, cal: Calendar) -> bool:
	return is_outlawed(band, cal)


## Rolled once per voyage: a full outlaw draws hunters with `bounty_chance`.
## Returns {} or a battle request. (The old sandbox; on the map the
## hunters are a party that comes after him, `spring`.)
static func bounty_hunters(rng: SimRng, rules: WorldRules, band: Band, cal: Calendar, log: PackedStringArray) -> Dictionary:
	if band.outlawry != WorldTypes.Outlawry.FULL or not is_outlawed(band, cal):
		return {}
	if rng.randf() >= rules.bounty_chance:
		return {}
	var text := "Bounty hunters, %d men, come after the outlaw band." % rules.bounty_crew
	log.append(text)
	return {"kind": "bounty_hunters", "attackers": rules.bounty_crew, "tier": rules.bounty_tier, "text": text}


static func lift(band: Band, log: PackedStringArray) -> void:
	if band.outlawry == WorldTypes.Outlawry.NONE:
		return
	band.outlawry = WorldTypes.Outlawry.NONE
	band.outlaw_until = 0
	band.law.erase("exile_by")
	band.law.erase("grettir")
	log.append("The band's outlawry is lifted.")
	band.log("Outlawry lifted.")


# --- Where the law reaches ----------------------------------------------------------

## Whether Norway's law reaches a place: Norway's own regions.
static func reaches(place: Place) -> bool:
	return place != null and Families.HOME_REGIONS.has(place.region)


## The region the band is in: its place's, or the nearest place's in the
## wilds and at sea.
static func region_here(j: Journey) -> int:
	var p := j.here()
	if p != null:
		return p.region
	var best: Place = null
	var best_d := INF
	for q: Place in j.c.world.places.values():
		var d := q.pos.distance_to(j.roam.pos)
		if d < best_d:
			best_d = d
			best = q
	return best.region if best != null else WorldTypes.Region.HORDALAND


## Whether the band is where Norway's outlawry reaches it.
static func in_realm(j: Journey) -> bool:
	return Families.HOME_REGIONS.has(region_here(j))


## The one predicate: why `what` (a door in DOORS: "winter", "rest",
## "passage", "hire", "market", "work", "shelter", "thing") is shut to the
## band at `p`, or "" when it is open. A lesser outlaw has the law's leave
## to provision himself and take ship out of Norway, no more; a full
## outlaw has nothing in the realm, save what a sworn friend will risk for
## him in secret (shelter and a winter roof).
static func door_shut(j: Journey, p: Place, what: String) -> String:
	var band := j.c.band
	if p == null or not is_outlawed(band, j.c.cal) or not reaches(p):
		return ""
	var who := band.leader.display_name
	if band.outlawry == WorldTypes.Outlawry.LESSER:
		if what == "passage" or what == "market" or what == "rest":
			return ""
		return "%s is outlawed for a time: the law lets him buy what he needs and take ship out of Norway, no more." % who
	if (what == "winter" or what == "shelter") and p.family != "" \
			and Families.standing(band, p.family) >= j.c.world_rules.standing_sworn:
		return ""  # a sworn friend will hide him, at a risk to themselves
	if what == "passage":
		return "No shipmaster in Norway will carry a full outlaw openly."
	return "%s is a full outlaw: %s is shut to him." % [who, ("the door of %s" % p.family) if p.family != "" else "every door here"]


## The door an action knocks at, or "".
static func door_of(id: String) -> String:
	var key := id.get_slice(":", 0)
	return str(DOORS.get(key, ""))


## Greys the deeds the band may not do here as an outlaw (Journey.actions).
static func gate(j: Journey, acts: Array[Dictionary]) -> void:
	var p := j.here()
	if p == null or not is_outlawed(j.c.band, j.c.cal):
		return
	for a in acts:
		var door := door_of(str(a.id))
		if door == "":
			continue
		var why := door_shut(j, p, door)
		if why != "":
			a["enabled"] = false
			a["hint"] = why


## Why one of Journey.actions may not be done here, or "" (Journey.act
## asks this before it does anything).
static func refuses(j: Journey, id: String) -> String:
	var door := door_of(id)
	return door_shut(j, j.here(), door) if door != "" else ""


## The roof the band may winter under: its own place if the door is open
## (neither an outlaw's door nor an ill-wisher's shut), else "".
static func winter_shut(j: Journey, p: Place) -> String:
	if p == null:
		return "no roof"
	var why := door_shut(j, p, "winter")
	if why != "":
		return why
	if p.id != j.c.band.hall_at and p.id != j.c.band.home and Families.shelter(j.c.world_rules, j.c.band, p) == "shut":
		return "The door of %s is shut to you." % p.family
	return ""


# --- The year of an outlaw -------------------------------------------------------------

## The spring: the bounty hunters come for a full outlaw who is in the
## realm; the lesser outlaw is told where he stands; Rollo's men are given
## their land when the Franks give it to him.
static func spring(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	if band.outlawry == WorldTypes.Outlawry.LESSER and is_outlawed(band, j.c.cal) and in_realm(j):
		j._say("%s is outlawed for a time: he must be out of Norway before the winter, or he is a full outlaw." % band.leader.display_name)
	if band.outlawry == WorldTypes.Outlawry.FULL and in_realm(j):
		var r := Landtake.fork(j, "hunters")
		if r.randf() < wr.hunters_chance:
			var n := mini(wr.hunters_parties, 1 + band.fame / 50)
			for i in n:
				_add_hunters(j, r.fork("h%d" % i))
			j._say("Word comes that men are out after %s: there is a price of %d oz on his head." % [band.leader.display_name, bounty(wr, band)])
	if int(band.law.get("rollo", 0)) > 0 and j.c.cal.year >= 911 and not band.law.has("normandy"):
		band.law["normandy"] = j.c.cal.year
		Landtake.grant(j, "seine", wr.hersir_grant_units, "given by Rollo when the Frankish king gave him the land about the Seine")


## The price on a full outlaw's head: it grows with his fame.
static func bounty(rules: WorldRules, band: Band) -> int:
	return rules.bounty_base + band.fame / 2


## A party of bounty hunters, from the realm's hall nearest the band.
static func _add_hunters(j: Journey, r: SimRng) -> Roam.Party:
	var wr := j.c.world_rules
	var band := j.c.band
	var roam := j.roam
	var best := ""
	var best_d := INF
	var ids: Array = j.c.world.places.keys()
	ids.sort()
	for id in ids:
		var p: Place = j.c.world.places[id]
		if not p.is_open(j.c.world.year) or not reaches(p) or not roam.grid.place_cell.has(id):
			continue
		if p.kind != WorldTypes.PlaceKind.HALL and p.kind != WorldTypes.PlaceKind.TOWN:
			continue
		var d := p.pos.distance_to(roam.pos)
		if d < wr.sight_leagues + 2.0:
			continue
		d += r.randf() * 6.0
		if d < best_d:
			best_d = d
			best = id
	if best == "":
		return null
	var h := Roam.Party.new()
	h.kind = "hunters"
	h.name = "bounty hunters"
	h.mood = -1
	h.home = best
	h.men = wr.hunters_base + band.fame / wr.hunters_per_fame
	h.tier = wr.hunters_tier
	h.sails = band.ship != null
	h.speed = wr.raider_speed if h.sails else wr.outlaw_speed
	h.pos = MapGrid.centre(roam.grid.place_cell[best])
	roam.parties.append(h)
	return h


## Every step of the summer: hunters go home when the band is out of the
## realm or no longer an outlaw.
static func tick(j: Journey) -> void:
	var hunted := j.c.band.outlawry == WorldTypes.Outlawry.FULL and in_realm(j)
	if hunted:
		return
	for p in j.roam.parties.duplicate():
		if p.kind == "hunters":
			j.roam.parties.erase(p)


## The hunters have come up with the band. True when it was theirs.
static func meet(j: Journey, p: Roam.Party) -> bool:
	if p.kind != "hunters":
		return false
	var wr := j.c.world_rules
	p.rest_until = j.roam.clock + wr.party_rest_days
	var text := "Bounty hunters come on, %d of them, for the %d oz on %s's head." % [p.men, bounty(wr, j.c.band), j.c.band.leader.display_name]
	j._offer_fight("bounty hunters", p.tier, Sandbox._forced(j.c, p.men), false, wr.hunters_stat, j.roam.afloat(), false,
			{"kind": "law", "what": "hunters", "party": p}, text, true)
	return true


## What the outlaw may do where he stands: ask the king's pardon at one of
## the king's halls, take ship west with a shipmaster who asks no
## questions, rob the road in the wilds.
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var band := j.c.band
	var wr := j.c.world_rules
	if not is_outlawed(band, j.c.cal):
		return out
	var p := j.here()
	var full := band.outlawry == WorldTypes.Outlawry.FULL
	if p == null:
		if full and not j.roam.afloat() and in_realm(j):
			out.append({"id": "rob_road", "label": "Rob travellers on the road",
					"hint": "A few ounces from whoever comes by, %d days. It is a thief's living: honor -%d." % [wr.rob_road_days, wr.rob_road_honor]})
		return out
	if not reaches(p):
		return out
	var king := _king_of(j, p)
	if king != null and int(band.law.get("pardon_asked", -1)) != j.c.cal.year:
		var price := pardon_price(wr, band)
		out.append({"id": "pardon_silver", "label": "Buy the king's pardon (%d oz)" % price, "enabled": band.silver >= price,
				"hint": "%s will take silver for your peace in his land. The price rises with your fame." % king.leader})
		out.append({"id": "pardon_service", "label": "Offer your sword for your peace",
				"hint": "Fight %s's enemies for him, about %d men. Win, and you are a free man in his land." % [king.leader, wr.pardon_service_men]})
	if Journey.SETTLED.has(p.kind):
		var west := _west_haven(j)
		if west != "":
			var cost := _west_cost(j, west)
			out.append({"id": "west_passage", "label": "Pay a shipmaster to carry you to %s (%d oz)" % [j.c.world.place(west).display_name, cost],
					"enabled": band.silver >= cost, "hint": "A man who asks no questions, for twice the fare. Norway's law does not reach the west."})
	return out


## The pardon's price in silver.
static func pardon_price(rules: WorldRules, band: Band) -> int:
	return rules.pardon_base + band.fame


static func act(j: Journey, id: String) -> bool:
	var band := j.c.band
	var wr := j.c.world_rules
	var who := band.leader.display_name
	match id:
		"rob_road":
			var r := Landtake.fork(j, "rob")
			var got := wr.rob_road_silver + r.randi_range(0, wr.rob_road_silver)
			band.silver += got
			band.honor = clampi(band.honor - wr.rob_road_honor, 0, 100)
			j._pass(float(wr.rob_road_days))
			j._say("%s and his men lie by the road %d days and take %d oz from those who come by." % [who, wr.rob_road_days, got])
			band.log("%s lived by robbing the road" % who)
		"pardon_silver":
			var price := pardon_price(wr, band)
			if band.silver < price:
				return true
			band.silver -= price
			band.law["pardon_asked"] = j.c.cal.year
			var king := _king_of(j, j.here())
			pardon(j, "%s pays %s %d oz for his peace" % [who, king.leader if king != null else "the king", price])
			if king != null:
				FactionAI.shift(j.c.world, king.id, FactionAI.BAND, 5)
		"pardon_service":
			band.law["pardon_asked"] = j.c.cal.year
			var king2 := _king_of(j, j.here())
			var text := "%s offers his sword to %s for his peace, and is sent against the king's enemies." % [who, king2.leader if king2 != null else "the king"]
			j._offer_fight("the king's enemies", CombatTypes.Tier.BLOODED, Sandbox._forced(j.c, wr.pardon_service_men), true, wr.levy_stat,
					false, false, {"kind": "law", "what": "pardon", "king": king2.id if king2 != null else ""}, text, true)
		"west_passage":
			var to := _west_haven(j)
			var cost := _west_cost(j, to)
			if to == "" or band.silver < cost:
				return true
			band.silver -= cost
			if band.ship != null and j.roam.aboard:
				j.roam.ship_at = j.roam.pos
			j.roam.aboard = false
			var days := maxi(2, ceili(j.roam.place_days(band.location, to, 0.0001, wr.merchant_speed, true)))
			j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[to])
			j._pass(float(days))
			j._look_about()
			j._say("%s is carried to %s by a shipmaster who asks no questions: %d days, %d oz." % [who, j.c.world.place(to).display_name, days, cost])
			j._arrived()
		_:
			return false
	return true


## The outlaw's peace: his outlawry lifted, the hunters gone home.
static func pardon(j: Journey, line: String) -> void:
	var band := j.c.band
	j._say(line + ": he is a free man in Norway again.")
	band.log(line)
	lift(band, j.said)
	tick(j)
	Landtake.outlaw_land(j)


## What a fight did for an outlaw: hunters beaten (the price goes up with
## his name), the king's service done (his pardon), an outlaw band killed
## (the Grettir clause).
static func after_fight(j: Journey, ctx: Dictionary, result: BattleResult) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var won := result != null and result.winner == 0
	var what := str(ctx.get("what", ""))
	if str(ctx.get("kind", "")) == "law":
		if what == "hunters" and won:
			band.fame = clampi(band.fame + 2, 0, 100)
			j._say("The hunters are beaten off, and the tale makes the price on %s's head the higher." % band.leader.display_name)
		elif what == "pardon":
			if won:
				pardon(j, "%s fought the king's enemies for his peace" % band.leader.display_name)
				band.rank_progress += 10
			else:
				j._say("The king's enemies have the better of it; there is no peace for %s this year." % band.leader.display_name)
	var req: Dictionary = ctx.get("req", {})
	if won and str(req.get("kind", "")) == "outlaws" and band.outlawry == WorldTypes.Outlawry.FULL:
		band.law["grettir"] = int(band.law.get("grettir", 0)) + 1
		var n := int(band.law.grettir)
		if n >= wr.grettir_kills:
			pardon(j, "%s has killed outlaws three times over, and by the old law has earned his own peace" % band.leader.display_name)
		else:
			j._say("Outlaws killed by an outlaw: %d of the %d the law asks before a man has earned his peace." % [n, wr.grettir_kills])


## Where the band winters, as the law has it: a lesser outlaw who winters
## in Norway is a full outlaw now; one who winters abroad has served a
## winter of his time; a sworn friend who hides a full outlaw may be found
## out.
static func on_winter(j: Journey, p: Place) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	if not is_outlawed(band, j.c.cal):
		return
	var abroad := (p != null and not reaches(p)) or (p == null and not in_realm(j))
	if band.outlawry == WorldTypes.Outlawry.LESSER:
		if abroad:
			band.law["exile_winters"] = int(band.law.get("exile_winters", 0)) + 1
			j._say("%s winters out of Norway, as the law bade him: a winter of his outlawry served." % band.leader.display_name)
		elif int(band.law.get("exile_by", 9999)) <= j.c.cal.year:
			j._say("%s did not leave Norway as the law bade him; now he is a full outlaw." % band.leader.display_name)
			declare(wr, band, j.c.cal, true, j.said)
		return
	if p != null and reaches(p) and p.family != "" and Families.standing(band, p.family) >= wr.standing_sworn:
		if Landtake.fork(j, "hidden").randf() < wr.secret_shelter_risk:
			j._say("Word gets out that %s hid %s over the winter; their lord thinks the less of them, and they will not do it again lightly." % [p.family, band.leader.display_name])
			j._shift(p.family, -20)
			var h := j.c.world.families.house(p.family) if j.c.world.families != null else null
			if h != null:
				h.honor = maxi(0, h.honor - 5)
			var f := FactionAI.ruler_of(j.c.world, p.id)
			if f != null:
				FactionAI.shift(j.c.world, f.id, FactionAI.BAND, wr.shelter_found_relation)
		else:
			j._say("%s take %s in for the winter in secret, as sworn friends will." % [p.family, band.leader.display_name])


## Rollo's exile: the band sails west with him, outlawed in Harald's
## Norway, to the host on the Seine, which is its home now: work for
## Rollo, raiding in Frankia, the Isles over the sea.
static func join_rollo(j: Journey) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var world := j.c.world
	declare(wr, band, j.c.cal, true, j.said)
	band.law["rollo"] = j.c.cal.year
	var host: Faction = world.factions.get("seine", null)
	if host != null:
		host.leader = "Rollo"
		FactionAI.shift(world, "seine", FactionAI.BAND, 60)
	j.roam.stop()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["seine"])
	j.roam.aboard = band.ship != null
	j.roam.ship_at = Vector2.INF
	band.location = "seine"
	band.home = "seine"
	for id in ["seine", "rouen", "northumbria", "dublin", "orkney", "ribe"]:
		band.known_places[id] = true
	j._was_at = "seine"
	j._say("%s sails west with Rollo and his men, out of Harald's Norway, and comes with them to the Seine. The host's camp is his home now." % band.leader.display_name)
	band.log("%s went into exile with Rollo, west over the sea to the Seine" % band.leader.display_name)
	tick(j)


## A full outlaw's way out: the nearest known haven the law does not reach.
static func _west_haven(j: Journey) -> String:
	var best := ""
	var best_d := INF
	var ids: Array = j.c.band.known_places.keys()
	ids.sort()
	for id in ids:
		var q := j.c.world.place(str(id))
		if q == null or reaches(q) or not q.is_open(j.c.world.year) or not Journey.SETTLED.has(q.kind):
			continue
		var d := q.pos.distance_to(j.roam.pos)
		if d < best_d:
			best_d = d
			best = q.id
	if best == "":
		best = "orkney"
	return best


static func _west_cost(j: Journey, to: String) -> int:
	var wr := j.c.world_rules
	var days := maxf(2.0, j.roam.place_days(j.c.band.location, to, 0.0001, wr.merchant_speed, true))
	return 2 * (wr.passage_base + ceili(days * (1.0 + j.c.band.fighters().size() * wr.passage_per_man_day)))


## The king whose hall this is (a king's faction holds it), or null.
static func _king_of(j: Journey, p: Place) -> Faction:
	if p == null or (p.kind != WorldTypes.PlaceKind.HALL and p.kind != WorldTypes.PlaceKind.TOWN):
		return null
	var f := FactionAI.ruler_of(j.c.world, p.id)
	if f == null or not f.alive or f.kind != WorldTypes.FactionKind.KING:
		return null
	return f


## Where a stand-in outlaw goes to make his peace: the nearest king's hall he
## knows in Norway while he has the silver for the pardon (and some over)
## or the men to offer his sword; "" when he has neither or none is near.
static func pardon_road(j: Journey, bent: int) -> String:
	var band := j.c.band
	if int(band.law.get("pardon_asked", -1)) == j.c.cal.year:
		return ""
	var can_pay := band.silver >= pardon_price(j.c.world_rules, band) + 30
	var can_serve := band.fighters(j.c.rules).size() >= 6 and bent != Way.Id.TRADER
	if not can_pay and not can_serve:
		return ""
	return JourneyBot._nearest(j, func(q: Place) -> bool: return reaches(q) and _king_of(j, q) != null)


## A stand-in player's answer to the law's questions (none of its own: the
## outlaw's choices are deeds, JourneyBot.law_deed).
static func bot_deed(j: Journey, bent: int, ids: Dictionary) -> String:
	var band := j.c.band
	if not is_outlawed(band, j.c.cal):
		return ""
	var go := pardon_road(j, bent)
	if go != "" and go != band.location and JourneyBot._go(j, go):
		return "*"
	if ids.has("pardon_silver") and band.silver >= pardon_price(j.c.world_rules, band) + 30:
		return "pardon_silver"
	if ids.has("pardon_service") and band.fighters(j.c.rules).size() >= 6 and bent != Way.Id.TRADER:
		return "pardon_service"
	if band.outlawry == WorldTypes.Outlawry.FULL or (int(band.law.get("exile_by", 9999)) <= j.c.cal.year and j.days_left() < 60):
		if in_realm(j) and ids.has("west_passage") and j.sail_speed() <= 0.0:
			return "west_passage"
	if ids.has("rob_road") and band.silver < 20:
		return "rob_road"
	return ""
