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
