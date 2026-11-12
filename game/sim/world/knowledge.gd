class_name Knowledge
extends RefCounted
## What the band knows of the map: its home region at first, then every
## place it reaches and its lane neighbours, and places heard of by rumor
## at markets and halls. See world-architecture.md, Module J.


## Sets the band's starting knowledge: its home region (and its home).
static func learn_home(rules: WorldRules, world: World, band: Band) -> void:
	for p in world.places_in(rules.home_region):
		band.known_places[p.id] = true
	if world.place(band.home) != null:
		band.known_places[band.home] = true


## Marks a place known together with its open lane neighbours.
static func reveal(world: World, band: Band, place_id: String, log: PackedStringArray) -> void:
	var ids: Array[String] = [place_id]
	ids.append_array(world.neighbours(place_id))
	var learned := PackedStringArray()
	for id in ids:
		var p := world.place(id)
		if p == null or not p.is_open(world.year) or band.knows(id):
			continue
		band.known_places[id] = true
		learned.append(p.display_name)
	if not learned.is_empty():
		log.append("The band learns the way to %s." % ", ".join(learned))


## At a market or hall, someone tells of a place the band does not know
## within `rumor_radius_days`. Returns its id, or "".
static func hear_rumor(rng: SimRng, rules: WorldRules, world: World, band: Band, at: String, log: PackedStringArray) -> String:
	var p := world.place(at)
	if p == null or not (p.has_market or p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN):
		return ""
	return spread_rumor(rng, rules, world, band, at, log)


## The rumor itself, wherever it is heard (encounters at sea use it too).
static func spread_rumor(rng: SimRng, rules: WorldRules, world: World, band: Band, at: String, log: PackedStringArray) -> String:
	if world.place(at) == null:
		return ""
	var dist := Voyage.distances(world, at)
	var pool: Array[String] = []
	for id in dist:
		if dist[id] <= rules.rumor_radius_days and not band.knows(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	pool.sort()
	var id := pool[rng.randi_range(0, pool.size() - 1)]
	band.known_places[id] = true
	var text := "At %s the band hears of %s, %d days' sail away." % [
		world.place(at).display_name, world.place(id).display_name, dist[id]]
	band.rumors.append(text)
	log.append(text)
	return id


## Every known, open place, sorted by id.
static func known_targets(world: World, band: Band) -> Array[Place]:
	var ids: Array = band.known_places.keys()
	ids.sort()
	var out: Array[Place] = []
	for id in ids:
		var p := world.place(id)
		if p != null and p.is_open(world.year):
			out.append(p)
	return out


# --- What sells where -----------------------------------------------------------------

## Remembers the prices the band sees at a place (a market, or a farm's or
## a hall's own stall): {day, year, goods: {Good: [buy, sell]}}, a price 0
## where the place does not sell (or buy) that good.
static func see_prices(rules: WorldRules, world: World, band: Band, place_id: String, day: int) -> void:
	var p := world.place(place_id)
	if p == null or (not p.has_market and p.trade.is_empty()):
		return
	var goods := {}
	for g in WorldTypes.Good.values():
		if not p.has_market and not p.trade.has(g):
			continue
		if p.has_market and int(p.stock.get(g, 0)) <= 0 and int(band.cargo.get(g, 0)) <= 0 and g == WorldTypes.Good.GRAIN:
			continue
		var buy := Market.buy_price(rules, p, band, g) if Market.sells_here(p, g) and int(p.stock.get(g, 0)) > 0 else 0
		var sell := Market.sell_price(rules, p, band, g) if Market.buys_here(p, g) else 0
		goods[g] = [buy, sell]
	band.prices_seen[place_id] = {"day": day, "year": world.year, "goods": goods}


## "What sells where", for the screen: plain values. `places`: every place
## whose prices the band has seen (or, with the merchant's `price_talk`,
## every market it knows, as they stand today), [{id, name, when, rows:
## [{good, name, buy, sell}]}]; `runs`: the best known carries, [{good,
## name, from, from_name, buy, to, to_name, sell, margin}], the dearest
## margin first. Prices seen are as they were then; they move.
static func price_book(rules: WorldRules, world: World, band: Band, day: int) -> Dictionary:
	if band.gift("price_talk", false):
		for id in band.known_places:
			var p := world.place(str(id))
			if p != null and p.has_market and p.is_open(world.year):
				see_prices(rules, world, band, p.id, day)
	var places: Array[Dictionary] = []
	var ids: Array = band.prices_seen.keys()
	ids.sort()
	var cheapest := {}
	var dearest := {}
	for id in ids:
		var seen: Dictionary = band.prices_seen[id]
		var p := world.place(str(id))
		if p == null:
			continue
		var rows: Array[Dictionary] = []
		var goods: Dictionary = seen.goods
		var gs: Array = goods.keys()
		gs.sort()
		for g in gs:
			var bs: Array = goods[g]
			rows.append({"good": g, "name": WorldTypes.GOOD_NAMES[g], "buy": int(bs[0]), "sell": int(bs[1])})
			if int(bs[0]) > 0 and (not cheapest.has(g) or int(bs[0]) < int(cheapest[g][1])):
				cheapest[g] = [p.id, int(bs[0])]
			if int(bs[1]) > 0 and (not dearest.has(g) or int(bs[1]) > int(dearest[g][1])):
				dearest[g] = [p.id, int(bs[1])]
		var ago := day - int(seen.day) if int(seen.year) == world.year else -1
		places.append({"id": p.id, "name": p.display_name, "when": ("today" if ago == 0 else ("%d days ago" % ago if ago > 0 else "last year")),
				"rows": rows})
	var runs: Array[Dictionary] = []
	for g in cheapest:
		if not dearest.has(g) or str(dearest[g][0]) == str(cheapest[g][0]):
			continue
		var margin := int(dearest[g][1]) - int(cheapest[g][1])
		if margin <= 0:
			continue
		runs.append({"good": g, "name": WorldTypes.GOOD_NAMES[g], "from": cheapest[g][0], "from_name": world.place(str(cheapest[g][0])).display_name,
				"buy": int(cheapest[g][1]), "to": dearest[g][0], "to_name": world.place(str(dearest[g][0])).display_name,
				"sell": int(dearest[g][1]), "margin": margin})
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.margin) > int(b.margin) or (int(a.margin) == int(b.margin) and int(a.good) < int(b.good)))
	return {"places": places, "runs": runs}
