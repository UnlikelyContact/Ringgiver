class_name Voyage
extends RefCounted
## Sailing over the sea lanes: shortest routes by days (Dijkstra) and the
## voyage itself, lane by lane, with weather, encounters, wrecks and the
## closing of the season. See world-architecture.md, Module J.


## Shortest days from `from` to every reachable open place. With `known`
## non-empty, only known places (plus `from` and `to`) may be passed through
## or reached; `to`, if given, is an end and never a waypoint. Returns
## {id: days} and fills `prev` with each reached place's predecessor.
static func distances(world: World, from: String, known := {}, to := "", prev := {}) -> Dictionary:
	var dist := {from: 0}
	var done := {}
	while true:
		var best := ""
		var best_d := 0
		var ids := dist.keys()
		ids.sort()
		for id in ids:
			if done.has(id):
				continue
			if best == "" or dist[id] < best_d:
				best = id
				best_d = dist[id]
		if best == "":
			break
		done[best] = true
		if best == to and best != from:
			continue
		for n in world.neighbours(best):
			var p := world.place(n)
			if p == null or not p.is_open(world.year):
				continue
			if not known.is_empty() and not known.has(n) and n != to and n != from:
				continue
			var d: int = best_d + world.days_between(best, n)
			if not dist.has(n) or d < dist[n]:
				dist[n] = d
				prev[n] = best
	return dist


## Shortest route by days, from and to inclusive; [] if none. With `known`
## non-empty the route passes only through known places.
static func plan(world: World, from: String, to: String, known := {}) -> Array[String]:
	var out: Array[String] = []
	if world.place(from) == null or world.place(to) == null or not world.place(to).is_open(world.year):
		return out
	if from == to:
		out.append(from)
		return out
	var prev := {}
	var dist := distances(world, from, known, to, prev)
	if not dist.has(to):
		return out
	var cur := to
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	out.push_front(from)
	return out


static func route_days(world: World, route: Array[String]) -> int:
	var t := 0
	for i in range(route.size() - 1):
		t += world.days_between(route[i], route[i + 1])
	return t


## Sails the band toward `to` lane by lane. Stops early for a battle (the
## caller fights it, then sails again from `stopped_at`), a wreck, an
## unsailable ship, or the closing of the season.
static func sail(rng: SimRng, rules: WorldRules, world: World, band: Band, cal: Calendar, to: String, log: PackedStringArray) -> VoyageResult:
	var res := VoyageResult.new()
	_ensure_location(rules, world, band)
	res.stopped_at = band.location
	var here := world.place(band.location)
	var dest := world.place(to)
	if dest == null or not dest.is_open(world.year) or not band.knows(to):
		res.reason = "unknown"
		log.append("No one aboard knows the way to %s." % (dest.display_name if dest != null else to))
		return res
	if band.location == to:
		res.route.append(to)
		res.arrived = true
		return res
	if band.ship == null or not band.ship.can_sail(rules):
		res.reason = "no_ship"
		log.append("The band has no ship fit to sail from %s." % here.display_name)
		return res
	res.route = plan(world, band.location, to, band.known_places)
	if res.route.is_empty():
		res.reason = "no_route"
		log.append("No known way leads from %s to %s." % [here.display_name, dest.display_name])
		return res
	if cal.day + route_days(world, res.route) > rules.summer_days:
		res.reason = "season"
		log.append("Too late in the year to sail for %s; the band stays at %s." % [dest.display_name, here.display_name])
		return res
	log.append("The band sails from %s for %s." % [here.display_name, dest.display_name])
	for i in range(res.route.size() - 1):
		var a := res.route[i]
		var b := res.route[i + 1]
		if not band.ship.can_sail(rules):
			res.reason = "ship"
			log.append("The ship is too battered to go on from %s." % world.place(a).display_name)
			break
		var open_sea := world.lane_is_open_sea(a, b)
		# Weather and the encounter are rolled first, so the lane's cost is
		# known before the band commits to it.
		var storm := rng.randf() < rules.storm_chance
		var kind := ""
		if Encounters.happens(rng, rules, world, a, b):
			kind = Encounters.pick_kind(rng, rules)
		if kind == "storm":
			storm = true
		var cost := world.days_between(a, b) + (rules.storm_delay_days if storm else 0)
		if cal.day + cost > rules.summer_days:
			res.reason = "season"
			log.append("Weather and the closing season keep the band at %s." % world.place(a).display_name)
			break
		cal.advance_days(cost)
		res.days += cost
		if storm:
			res.encounters.append(Encounters.resolve(rng, rules, world, band, "storm", a, b, log))
		if open_sea and rng.randf() < rules.wreck_chance:
			_wreck(rng, rules, world, band, b, log)
			band.location = b
			res.wrecked = true
			res.reason = "wreck"
			break
		band.location = b
		if kind != "" and kind != "storm":
			var enc := Encounters.resolve(rng, rules, world, band, kind, a, b, log)
			res.encounters.append(enc)
			if enc.has("battle_required"):
				res.reason = "battle"
				break
	res.stopped_at = band.location
	res.arrived = band.location == to
	if res.stopped_at != res.route[0]:
		Knowledge.reveal(world, band, res.stopped_at, log)
	if res.arrived:
		log.append("The band makes land at %s after %d days." % [dest.display_name, res.days])
	return res


## Ship broken, cargo lost, men drowned (the leader always reaches shore).
static func _wreck(rng: SimRng, rules: WorldRules, world: World, band: Band, shore: String, log: PackedStringArray) -> void:
	band.ship.damage += rules.wreck_damage
	band.cargo.clear()
	log.append("The ship founders on the crossing; the cargo is lost and the band struggles ashore at %s." % world.place(shore).display_name)
	var drowned: Array[Man] = []
	var pool := _drownable(band)
	for k in range(rules.wreck_men_lost):
		if pool.is_empty():
			break
		var m: Man = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(m)
		drowned.append(m)
	for m in pool:
		if m.armor == CombatTypes.Armor.MAIL and rng.randf() < rules.wreck_mail_drown_chance:
			drowned.append(m)
	for m in drowned:
		m.alive = false
		band.remove_man(m)
		log.append("%s drowns%s." % [m.display_name, (" in %s mail" % m.his()) if m.armor == CombatTypes.Armor.MAIL else ""])


static func _drownable(band: Band) -> Array[Man]:
	var out: Array[Man] = []
	for m in band.living_men():
		if m != band.leader and not m.is_leader:
			out.append(m)
	return out


## Keeps band.location a real place: falls back to home, then the home region.
static func _ensure_location(rules: WorldRules, world: World, band: Band) -> void:
	if world.place(band.location) != null:
		return
	if world.place(band.home) != null:
		band.location = band.home
		return
	var ids: Array = []
	for p in world.places_in(rules.home_region):
		ids.append(p.id)
	if ids.is_empty():
		ids = world.places.keys()
	ids.sort()
	band.location = ids[0]
