class_name TradeRoad
extends RefCounted
## The early trader's road and a poor man's first livings (concept.md,
## "Making a living"; notes/world-life.md). A man with no ship and little
## silver still has ways to live: the farms and halls deal in what they
## make and what they lack (Place.trade, Market's local stalls), and his
## men carry a load each between neighbouring places; a man at a market
## gives him goods to carry for a share (the félag, which is how the
## sagas' traders begin); he can guard a merchant's goods for pay, work a
## farmer's fields, take the herds up to the summer pasture, go out with
## the fishermen, or row in another man's ship for a share of the voyage.
## Journey asks `actions(j)` and hands `act(j, id)` what it does not know.
## State lives in `Journey.life` (keys below), so the year's offers are
## rolled once and the days a thing was done are remembered.


## Puts every farm's and hall's stall on the world (WorldRules.local_trade):
## what it makes and what it lacks, `local_stock` units of each.
static func open_stalls(rules: WorldRules, world: World) -> void:
	for table: Dictionary in [rules.local_trade, rules.wider_local_trade]:
		for id in table:
			var p := world.place(str(id))
			if p == null or p.has_market:
				continue
			p.trade = (table[id] as Dictionary).duplicate()
			for g in p.trade:
				p.stock[g] = rules.local_stock


## What a man does at this place to make his living by this road:
## [{id, label, hint, enabled}].
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null:
		return out
	var wr := j.c.world_rules
	var band := j.c.band
	var year := j.c.cal.year
	var foe := Families.is_foe(wr, band, p.family)
	var men := band.living_men().size()
	# Goods carried for a partner, to be sold here.
	for i in band.felag.size():
		var f: Dictionary = band.felag[i]
		if str(f.to) == p.id and Market.buys_here(p, f.good):
			out.append({"id": "felag_sell:%d" % i, "label": "Sell %s's %s here" % [f.partner, WorldTypes.GOOD_NAMES[f.good]],
					"hint": "%d loads, about %d oz; %d in a hundred of it is yours, as agreed." % [int(f.units),
							int(f.units) * Market.sell_price(wr, p, band, f.good), roundi(float(f.share) * 100.0)]})
	if Journey.SETTLED.has(p.kind) and not foe:
		var f2 := felag_offer(j)
		if not f2.is_empty():
			var to: Place = j.c.world.place(str(f2.to))
			var room := Market.cargo_room(wr, band)
			out.append({"id": "felag", "label": "Carry %s's %s to %s for a share" % [f2.partner, WorldTypes.GOOD_NAMES[f2.good], to.display_name],
					"enabled": room > 0,
					"hint": ("%d loads of his, %d days away; a share of %d in a hundred of what they fetch (about %d oz), and his house's goodwill." % [
							mini(int(f2.units), room), maxi(0, j.days_to(to.id)), roundi(wr.felag_share * 100.0), int(f2.worth)]) if room > 0 \
							else "You have no room to carry his goods."})
		var e := escort_offer(j)
		if not e.is_empty() and j.life.get("escort", {}).is_empty():
			out.append({"id": "escort", "label": "Guard a merchant to %s (%d oz)" % [j.c.world.place(str(e.to)).display_name, int(e.pay)],
					"hint": "His goods go with you. Paid there, if you bring him within %d days; raiders like a laden merchant better than they like you." % int(e.days)})
	if Journey.SETTLED.has(p.kind) and not foe and p.kind != WorldTypes.PlaceKind.TOWN:
		if not _done(j, "labour", p.id):
			out.append({"id": "labour", "label": "Work the farmer's fields", "hint": "%d days: %d oz and %d rations for you and your men." % [
					wr.labour_days, labour_pay(wr, men), wr.labour_food]})
		if p.kind == WorldTypes.PlaceKind.FARMSTEAD and not _done(j, "herd", p.id):
			out.append({"id": "herd", "label": "Take the herds to the summer pasture", "hint": "%d days in the uplands: %d oz, %d rations, and you learn the country about." % [
					wr.herd_days, wr.herd_pay, wr.herd_food]})
		if p.kind == WorldTypes.PlaceKind.FARMSTEAD and on_shore(j, p) and int(_count(j, "fish", p.id)) < wr.fish_max:
			out.append({"id": "fish", "label": "Go out with the fishermen", "hint": "%d days at the lines: %d rations and %d oz for the catch." % [
					wr.fish_days, wr.fish_food, wr.fish_pay]})
	if (p.has_market or p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN) and j.sail_speed() <= 0.0 \
			and band.fighters().size() <= wr.crew_max_men:
		var cr := crew_offer(j)
		if not cr.is_empty():
			out.append({"id": "crew", "label": "Row in a ship bound for %s" % j.c.world.place(str(cr.to)).display_name,
					"hint": "%d days at another man's oars, and a share for it: %d oz." % [int(cr.days), int(cr.pay)]})
	return out


## Does one of `actions`; false when the id is not this road's.
static func act(j: Journey, id: String) -> bool:
	var p := j.here()
	if p == null:
		return false
	var wr := j.c.world_rules
	var band := j.c.band
	var who := band.leader.display_name
	if id.begins_with("felag_sell:"):
		_sell_felag(j, int(id.trim_prefix("felag_sell:")))
		return true
	match id:
		"felag":
			var f := felag_offer(j)
			var room := Market.cargo_room(wr, band)
			if f.is_empty() or room <= 0:
				return true
			var units := mini(int(f.units), room)
			band.felag.append({"partner": f.partner, "good": f.good, "units": units, "to": f.to, "share": wr.felag_share,
					"year": j.c.cal.year, "from": p.id})
			_mark(j, "felag", p.id)
			j._say("%s takes %d loads of %s from %s, to sell at %s for a share." % [who, units, WorldTypes.GOOD_NAMES[f.good],
					f.partner, j.c.world.place(str(f.to)).display_name])
			j._pass(1.0)
		"escort":
			var e := escort_offer(j)
			if e.is_empty():
				return true
			_mark(j, "escort", p.id)
			var party := j.roam.add_escorted(wr, j.c.world, p.id)
			j.life["escort"] = {"to": e.to, "pay": e.pay, "by": j.roam.clock + float(e.days), "family": p.family, "party": party}
			j.roam.lure = true
			j._say("%s takes a merchant of %s under his guard, bound for %s." % [who, p.display_name, j.c.world.place(str(e.to)).display_name])
		"labour":
			_mark(j, "labour", p.id)
			var pay := labour_pay(wr, band.living_men().size())
			band.silver += pay
			band.food += wr.labour_food
			j._shift(p.family, wr.standing_labour)
			j._say("%s and his men work the fields at %s for %d days: %d oz and %d rations." % [who, p.display_name, wr.labour_days, pay, wr.labour_food])
			j._pass(float(wr.labour_days))
		"herd":
			_mark(j, "herd", p.id)
			band.silver += wr.herd_pay
			band.food += wr.herd_food
			j._shift(p.family, wr.standing_labour)
			j._say("%s takes the herds of %s up to the summer pasture for %d days: %d oz and %d rations." % [who, p.display_name, wr.herd_days, wr.herd_pay, wr.herd_food])
			var learned := PackedStringArray()
			for q in j.c.world.places.values():
				if not band.knows(q.id) and q.is_open(j.c.world.year) and q.pos.distance_to(p.pos) <= wr.herd_reveal_leagues:
					band.known_places[q.id] = true
					learned.append(q.display_name)
			if not learned.is_empty():
				j._say("From the high pastures he comes to know %s." % ", ".join(learned))
			j._pass(float(wr.herd_days))
		"fish":
			_mark(j, "fish", p.id)
			band.food += wr.fish_food
			band.silver += wr.fish_pay
			j._say("%s goes out with the fishermen of %s for %d days: %d rations, and %d oz for the catch." % [who, p.display_name, wr.fish_days, wr.fish_food, wr.fish_pay])
			j._pass(float(wr.fish_days))
		"crew":
			var cr := crew_offer(j)
			if cr.is_empty():
				return true
			_mark(j, "crew", p.id)
			var to := str(cr.to)
			if band.ship != null and j.roam.aboard:
				j.roam.ship_at = j.roam.pos  # his own boat stays on the beach
			j.roam.aboard = false
			j.roam.stop()
			j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[to])
			band.known_places[to] = true
			j._pass(float(cr.days))
			band.silver += int(cr.pay)
			j._look_about()
			j._say("%s rows in a ship of %s to %s: %d days, and %d oz for his share." % [who, p.display_name, j.c.world.place(to).display_name, int(cr.days), int(cr.pay)])
			j._arrived()
		_:
			return false
	return true


## The day's work for a band of `men`: the farmer pays the leader and a
## little for each man.
static func labour_pay(rules: WorldRules, men: int) -> int:
	return rules.labour_pay + rules.labour_pay_man * mini(men, 4)


## Whether a place lies by the water (a cell beside it is sea).
static func on_shore(j: Journey, p: Place) -> bool:
	var grid := j.roam.grid
	if not grid.place_cell.has(p.id):
		return false
	var c: Vector2i = grid.place_cell[p.id]
	for d in MapGrid._DIRS:
		if grid.is_sea(c + d):
			return true
	return grid.terrain(c) == MapGrid.T.SHORE


# --- The félag ------------------------------------------------------------------------

## The partnership a man here offers this year, or {}: {partner, good,
## units, to, worth}. The good is one the place has plenty of (a farm's
## or hall's makings, or a market's stock), and the place he names the
## nearest the band knows and can reach where it fetches more.
static func felag_offer(j: Journey) -> Dictionary:
	var p := j.here()
	if p == null or p.family == "" or _done(j, "felag", p.id):
		return {}
	var key := "felag_offer:%s" % p.id
	if j.life.has(key):
		return j.life[key]
	var wr := j.c.world_rules
	var band := j.c.band
	var best := {}
	var best_gain := 0.0
	var goods: Array = p.trade.keys() if not p.has_market else WorldTypes.Good.values()
	for g in goods:
		if not Market.sells_here(p, g) or g == WorldTypes.Good.GRAIN or int(p.stock.get(g, 0)) <= 2:
			continue
		var here_price := Market.price(wr, p, g)
		for id in band.known_places:
			var q := j.c.world.place(str(id))
			if q == null or q.id == p.id or not q.is_open(j.c.world.year) or not Market.buys_here(q, g) or Roam.far_east(q) != Roam.far_east(p):
				continue
			var days := j.days_to(q.id)
			if days < 0 or days > wr.crew_max_days * 2:
				continue
			var gain := float(Market.price(wr, q, g) - here_price) / float(days + 2)
			if gain > best_gain:
				best_gain = gain
				best = {"partner": p.family, "good": g, "to": q.id, "units": wr.felag_units,
						"worth": roundi(float(wr.felag_units * Market.price(wr, q, g)) * wr.felag_share)}
	j.life[key] = best
	return best


static func _sell_felag(j: Journey, i: int) -> void:
	var band := j.c.band
	var wr := j.c.world_rules
	var p := j.here()
	if i < 0 or i >= band.felag.size() or p == null:
		return
	var f: Dictionary = band.felag[i]
	j._market_days()
	var earned := 0
	for k in int(f.units):
		p.stock[f.good] = int(p.stock.get(f.good, wr.local_stock if p.trade.has(f.good) else 0)) + 1
		earned += Market.sell_price(wr, p, band, f.good)
	var mine := roundi(float(earned) * float(f.share))
	band.silver += mine
	band.felag.remove_at(i)
	j._shift(str(f.partner), wr.standing_felag_kept)
	Way.add_deed(band, Way.Id.TRADER, maxi(1, mine / wr.deed_trade_margin))
	j._say("%s sells %d loads of %s for %s at %s: %d oz, of which %d are his share." % [band.leader.display_name, int(f.units),
			WorldTypes.GOOD_NAMES[f.good], f.partner, p.display_name, earned, mine])


## Goods of a partner lost with the band's cargo (a fight lost, a ship
## taken): the partner's house thinks the worse of it.
static func lose_felag(j: Journey, why: String) -> void:
	var band := j.c.band
	for f in band.felag:
		j._shift(str(f.partner), j.c.world_rules.standing_felag_broken)
		j._say("%s's %s are lost %s." % [f.partner, WorldTypes.GOOD_NAMES[f.good], why])
	band.felag.clear()


# --- Guarding a merchant -----------------------------------------------------------------

## The merchant here who wants a guard this year, or {}: {to, pay, days}.
## Only at a market or a town.
static func escort_offer(j: Journey) -> Dictionary:
	var p := j.here()
	if p == null or not (p.has_market or p.kind == WorldTypes.PlaceKind.TOWN) or _done(j, "escort", p.id):
		return {}
	var key := "escort_offer:%s" % p.id
	if j.life.has(key):
		return j.life[key]
	var wr := j.c.world_rules
	var cands: Array[String] = []
	var ids: Array = j.c.band.known_places.keys()
	ids.sort()
	for id in ids:
		var q := j.c.world.place(str(id))
		if q == null or q.id == p.id or not q.is_open(j.c.world.year) or not (q.has_market or q.kind == WorldTypes.PlaceKind.TOWN or q.kind == WorldTypes.PlaceKind.HALL):
			continue
		if Roam.far_east(q) != Roam.far_east(p):
			continue  # (a merchant's guard does not go up the river road)
		var d := j.days_to(q.id)
		if d > 0 and d <= wr.crew_max_days * 2:
			cands.append(q.id)
	var out := {}
	if not cands.is_empty():
		var to := cands[j._fork("escort_to").randi_range(0, cands.size() - 1)]
		var d := j.days_to(to)
		# A guard nobody cares to cross is worth more (the berserk's dread).
		var pay := roundi(float(wr.escort_pay_base + roundi(wr.escort_pay_day * d)) * float(j.c.band.gift("escort_pay", 1.0)))
		out = {"to": to, "pay": pay, "days": ceili(d * wr.escort_slack) + 3}
	j.life[key] = out
	return out


## The escorted merchant: paid on arrival, gone when the days run out.
static func check_escort(j: Journey) -> void:
	var e: Dictionary = j.life.get("escort", {})
	if e.is_empty():
		return
	var band := j.c.band
	var wr := j.c.world_rules
	if band.location == str(e.to):
		band.silver += int(e.pay)
		j._shift(str(e.family), wr.standing_rescued / 2)
		# A guard nobody cared to cross is told as the berserk's deed.
		Way.add_deed(band, Way.Id.BERSERK if float(band.gift("escort_pay", 1.0)) > 1.0 else Way.Id.TRADER, 1)
		j._say("The merchant comes safe to %s and pays %s %d oz for the guard." % [j.c.world.place(str(e.to)).display_name, band.leader.display_name, int(e.pay)])
		end_escort(j)
	elif j.roam.clock > float(e.by) or j.days_left() <= 0:
		j._say("The merchant will wait no longer and goes on alone; there is no pay for the guard.")
		end_escort(j)


static func end_escort(j: Journey) -> void:
	var e: Dictionary = j.life.get("escort", {})
	if e.has("party"):
		j.roam.parties.erase(e.party)
	j.life.erase("escort")
	j.roam.lure = false


# --- A place at another man's oars ----------------------------------------------------------

## The voyage a ship here would take a few hands on for, or {}: {to, days,
## pay}. A market, hall or town within `crew_max_days` by sea, drawn once
## a visit; it need not be a place the band knows.
static func crew_offer(j: Journey) -> Dictionary:
	var p := j.here()
	if p == null or _done(j, "crew", p.id):
		return {}
	var key := "crew_offer:%s" % p.id
	if j.life.has(key):
		return j.life[key]
	var wr := j.c.world_rules
	var cands: Array[String] = []
	var ids: Array = j.c.world.places.keys()
	ids.sort()
	for id in ids:
		var q: Place = j.c.world.places[id]
		if q.id == p.id or not q.is_open(j.c.world.year) or q.region == WorldTypes.Region.ICELAND \
				or not (q.has_market or q.kind == WorldTypes.PlaceKind.HALL or q.kind == WorldTypes.PlaceKind.TOWN):
			continue
		if not j.roam.grid.place_cell.has(q.id) or Roam.far_east(q) != Roam.far_east(p):
			continue  # (not over the river road: that is a venture, not a passage)
		var days := j.roam.place_days(p.id, q.id, 0.0001, wr.merchant_speed, true)
		if days > 0.0 and days <= wr.crew_max_days:
			cands.append(q.id)
	var out := {}
	if not cands.is_empty():
		var to := cands[j._fork("crew_to").randi_range(0, cands.size() - 1)]
		var d := maxi(1, ceili(j.roam.place_days(p.id, to, 0.0001, wr.merchant_speed, true) - 0.01))
		out = {"to": to, "days": d, "pay": maxi(1, roundi(wr.crew_pay_day * d * j.c.band.fighters().size()))}
	j.life[key] = out
	return out


# --- The summer's end -----------------------------------------------------------------------

## Goods carried for a partner and not sold by the winter: his house
## thinks the worse of the band.
static func end_of_summer(j: Journey) -> void:
	var band := j.c.band
	for f in band.felag:
		j._shift(str(f.partner), j.c.world_rules.standing_felag_broken)
		j._say("%s's %s were never sold as was agreed; he will want them back, and thinks the less of %s." % [
				f.partner, WorldTypes.GOOD_NAMES[f.good], band.leader.display_name])
	band.felag.clear()
	if not j.life.get("escort", {}).is_empty():
		end_escort(j)


# --- Small things ---------------------------------------------------------------------------

static func _done(j: Journey, what: String, place_id: String) -> bool:
	return int(j.life.get("%s:%s" % [what, place_id], -1)) == j.c.cal.year


static func _count(j: Journey, what: String, place_id: String) -> int:
	var v: Array = j.life.get("%s#:%s" % [what, place_id], [0, 0])
	return int(v[1]) if int(v[0]) == j.c.cal.year else 0


static func _mark(j: Journey, what: String, place_id: String) -> void:
	j.life["%s:%s" % [what, place_id]] = j.c.cal.year
	j.life["%s#:%s" % [what, place_id]] = [j.c.cal.year, _count(j, what, place_id) + 1]
