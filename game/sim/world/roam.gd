class_name Roam
extends RefCounted
## Where the band is on the free-roam map, and who else is abroad on it
## (concept.md, "The map"). The band is a point that walks the land and,
## with a ship, sails the water (MapGrid.find_path); its ship is with it or
## lies where it was beached. Merchants ply between the markets, raiders
## prowl the coast, outlaws wait on the land; they move as the days pass
## and go for a band they like the look of. Journey drives it and turns a
## meeting into something to answer.


## Another party on the map.
class Party:
	extends RefCounted
	var kind := ""  # merchant | raiders | outlaws | levy | avengers
	var name := ""
	## The house the party's men belong to ("" for none), and how it stands
	## toward the band (Families.party_mood): 1 leaves it be, -1 hunts it
	## whatever the odds, 0 goes for it when it likes the odds.
	var family := ""
	var mood := 0
	var pos := Vector2.ZERO
	var men := 6
	var tier: CombatTypes.Tier = CombatTypes.Tier.GREEN
	var speed := 6.0
	var sails := true
	var route: Array[Vector2i] = []
	var at := 0
	var home := ""
	var rest_until := 0.0
	var offer := {}  # a merchant's goods: {good, units, price, home, family}
	var chasing := false
	## The world's own life (WorldLife): the party it hunts, the one it is
	## locked in a fight with and when that fight is decided, the place it
	## is making for to plunder (`strike`) and when that raid is over, what
	## it carries (silver, captives), a stolen ship, the faction whose
	## ships these are, when it is gone from the map (a wreck), and a
	## merchant who walks or sails with the band under its guard.
	var prey: Party = null
	var engaged: Party = null
	var fray_until := 0.0
	var strike := ""
	var raiding_until := -1.0
	var loot := 0
	var captives := 0
	var ship: Ship = null
	var faction := ""
	var expire := INF
	var escorted := false
	## In a fight it did not start: it was fallen upon.
	var hunted := false
	## A wreck's leavings: {silver, goods: {Good: n}, captives, survivor}.
	var leavings := {}
	var text := ""

	func busy() -> bool:
		return engaged != null or raiding_until >= 0.0


var grid: MapGrid
var pos := Vector2.ZERO
## The band is with its ship: at sea, or on the cell where she is beached.
var aboard := false
## Where she lies when the band has walked on (Vector2.INF: with the band,
## or there is none).
var ship_at := Vector2.INF
var route: Array[Vector2i] = []
var route_aboard: Array[bool] = []
var route_at := 0
## The last cell whose centre the band stood on: where it is coming from.
var last_cell := Vector2i(-1, -1)
var parties: Array[Party] = []
## Days since the summer began, with fractions.
var clock := 0.0
## The band guards a merchant: raiders and outlaws go for it whatever the
## odds, for the goods.
var lure := false
## Tidings of the world's own fights not yet heard by the band:
## [{at (clock), text, pos}] (WorldLife).
var news: Array[Dictionary] = []
## Place id -> the clock of the last raid on it this summer.
var struck := {}
## When the world's life was last reckoned (WorldLife.tick).
var life_clock := 0.0

static var _sea_routes := {}
static var _place_days := {}


func _init() -> void:
	grid = MapGrid.norway()


# --- The band ----------------------------------------------------------------------

func cell() -> Vector2i:
	return MapGrid.cell_of(pos)


func moving() -> bool:
	return route_at < route.size()


func stop() -> void:
	route = []
	route_aboard = []
	route_at = 0


## Whether the band is on the water.
func afloat() -> bool:
	return grid.is_sea(cell())


## Where the band's ship lies, as a cell ((-1, -1): with the band, or none).
func ship_cell() -> Vector2i:
	return MapGrid.cell_of(ship_at) if ship_at != Vector2.INF else Vector2i(-1, -1)


## Sets the band's course for a cell. Returns the days it will take, or
## -1 when there is no way (water and no ship; the deep in a small boat).
func plot(to: Vector2i, foot: float, sail: float, deep_ok: bool) -> float:
	var p := grid.find_path(cell(), to, foot, sail if has_reach(sail) else 0.0, aboard and sail > 0.0, ship_cell(), deep_ok)
	var cells: Array[Vector2i] = p.cells
	if cells.is_empty():
		return 0.0 if to == cell() else -1.0
	route = cells
	route_aboard = p.aboard
	route_at = 0
	last_cell = cell()
	return p.days


## Whether a ship is any use from here: the band is with her, or she lies
## somewhere it can walk to.
func has_reach(sail: float) -> bool:
	return sail > 0.0 and (aboard or ship_at != Vector2.INF)


## Moves the band along its course for up to `dt` days and returns the
## days used: it stops at each cell's centre so that the caller can look
## about. `foot` and `sail` are leagues a day.
func step_band(dt: float, foot: float, sail: float) -> float:
	if not moving():
		return dt
	var next := route[route_at]
	var target := MapGrid.centre(next)
	var here := last_cell if MapGrid.inside(last_cell) else cell()
	var by_ship: bool = route_aboard[route_at] and aboard and (grid.is_sea(next) or grid.is_sea(here))
	var speed := sail if by_ship else foot / float(MapGrid.COST[grid.terrain(next)])
	speed = maxf(speed, 0.05)
	var dist := pos.distance_to(target)
	if speed * dt < dist:
		pos = pos.move_toward(target, speed * dt)
		return dt
	var used := dist / speed
	var was := MapGrid.centre(here)
	pos = target
	var with_ship: bool = route_aboard[route_at]
	if aboard and not with_ship:
		ship_at = was  # she stays where she was beached
	elif with_ship:
		ship_at = Vector2.INF
	aboard = with_ship
	last_cell = next
	route_at += 1
	return used


# --- Routes and reckonings kept for all worlds --------------------------------------

## The way a ship takes between two places, by water all the way but for
## the landing: cells after the first. Kept once found.
func sea_route(a: String, b: String) -> Array[Vector2i]:
	var key := a + ">" + b
	if not _sea_routes.has(key):
		var p := grid.find_path(grid.place_cell[a], grid.place_cell[b], 0.0001, 7.0, true)
		_sea_routes[key] = p.cells
	return _sea_routes[key]


## Days between two places for a band that starts with its ship (`sail`
## leagues a day, 0 for none) and walks at `foot`. Kept once found.
func place_days(a: String, b: String, foot: float, sail: float, deep_ok: bool) -> float:
	if a == b:
		return 0.0
	var key := "%s>%s:%.1f:%.1f:%s" % [a, b, foot, sail, deep_ok]
	if not _place_days.has(key):
		var p := grid.find_path(grid.place_cell[a], grid.place_cell[b], foot, sail, sail > 0.0, Vector2i(-1, -1), deep_ok)
		_place_days[key] = p.days if not (p.cells as Array).is_empty() else -1.0
	return _place_days[key]


# --- The others --------------------------------------------------------------------

## Puts the summer's parties on the map, none within sight of the band.
func populate(rng: SimRng, rules: WorldRules, world: World, outlawed: bool) -> void:
	parties.clear()
	var markets: Array[String] = []
	var coast: Array[String] = []
	var farms: Array[String] = []
	var halls: Array[String] = []
	var ids: Array = world.places.keys()
	ids.sort()
	for id in ids:
		var p: Place = world.places[id]
		if not p.is_open(world.year) or p.pos.distance_to(pos) < rules.sight_leagues + 2.0:
			continue
		if p.has_market:
			markets.append(id)
		if p.kind == WorldTypes.PlaceKind.FARMSTEAD:
			farms.append(id)
		if p.kind == WorldTypes.PlaceKind.HALL:
			halls.append(id)
		if p.kind != WorldTypes.PlaceKind.THING_SITE and p.region != WorldTypes.Region.ICELAND:
			coast.append(id)
	for i in rules.roam_merchants:
		if markets.size() < 2:
			break
		var m := Party.new()
		m.kind = "merchant"
		m.home = markets[rng.randi_range(0, markets.size() - 1)]
		m.name = "a knarr out of %s" % world.place(m.home).display_name
		m.men = rules.merchant_crew
		m.tier = rules.merchant_tier
		m.speed = rules.merchant_speed
		m.pos = MapGrid.centre(grid.place_cell[m.home])
		var goods := WorldTypes.Good.values()
		var good: WorldTypes.Good = goods[rng.randi_range(0, goods.size() - 1)]
		var town := world.place(m.home)
		m.offer = {"good": good, "units": rules.merchant_cargo, "price": maxi(1, int(round(rules.base_price[good] * rules.merchant_discount))),
				"home": m.home, "family": town.family}
		_new_route(m, rng, markets)
		parties.append(m)
	for i in rules.roam_raiders:
		if coast.size() < 2:
			break
		var r := Party.new()
		r.kind = "raiders"
		r.name = "a rival ship"
		r.home = coast[rng.randi_range(0, coast.size() - 1)]
		var region: WorldTypes.Region = world.place(r.home).region
		r.men = maxi(4, rules.rival_crew + rng.randi_range(-2, 2))
		r.tier = Encounters.rival_tier(rules, world.region_alertness.get(region, 0))
		r.speed = rules.raider_speed
		r.pos = MapGrid.centre(grid.place_cell[r.home])
		r.family = world.place(r.home).family
		_new_route(r, rng, coast)
		parties.append(r)
	for i in rules.roam_outlaws:
		if farms.is_empty():
			break
		var o := Party.new()
		o.kind = "outlaws"
		o.name = "outlaws"
		o.sails = false
		o.home = farms[rng.randi_range(0, farms.size() - 1)]
		o.men = maxi(3, rules.outlaw_crew + rng.randi_range(-1, 1))
		o.tier = rules.outlaw_tier
		o.speed = rules.outlaw_speed
		o.pos = MapGrid.centre(grid.place_cell[o.home]) + Vector2(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		if not grid.is_land(MapGrid.cell_of(o.pos)):
			o.pos = MapGrid.centre(grid.place_cell[o.home])
		parties.append(o)
	if outlawed:
		for i in rules.roam_levy:
			if halls.is_empty():
				break
			var l := Party.new()
			l.kind = "levy"
			l.name = "the levy ships"
			l.home = halls[rng.randi_range(0, halls.size() - 1)]
			l.men = rules.levy_crew
			l.tier = rules.levy_tier
			l.speed = rules.raider_speed
			l.pos = MapGrid.centre(grid.place_cell[l.home])
			_new_route(l, rng, coast)
			parties.append(l)


## Men of a house sent after the band (a feud with it): they put out from
## the house's seat by sea when the band has a ship, else on foot, and
## hunt it whatever the odds. Returns the party, or null when the seat is
## not on the map or within sight of the band.
func add_avengers(rules: WorldRules, world: World, family: String, seat: String, men: int, sails: bool) -> Party:
	var p: Place = world.place(seat)
	if p == null or not grid.place_cell.has(seat) or p.pos.distance_to(pos) < rules.sight_leagues:
		return null
	var a := Party.new()
	a.kind = "avengers"
	a.family = family
	a.mood = -1
	a.name = "men of %s" % family
	a.home = seat
	a.men = men
	a.tier = rules.avenger_tier
	a.sails = sails
	a.speed = rules.raider_speed if sails else rules.outlaw_speed
	a.pos = MapGrid.centre(grid.place_cell[seat])
	parties.append(a)
	return a


## The king's ships: they hunt raiders and outlaws, and hail a band at sea
## for the king's due. `faction` is the king's (Harald's while he lives).
func add_kings_ships(rules: WorldRules, world: World, home: String, faction: String) -> Party:
	if not grid.place_cell.has(home):
		return null
	var k := Party.new()
	k.kind = "kings_ships"
	var f: Faction = world.factions.get(faction, null)
	k.name = "the ships of %s" % (f.leader if f != null else "the king")
	k.faction = faction
	k.home = home
	k.men = rules.kings_crew
	k.tier = rules.kings_tier
	k.speed = rules.kings_speed
	k.pos = MapGrid.centre(grid.place_cell[home])
	parties.append(k)
	return k


## Men of a house sent against a house it is at feud with: they make for
## the other's seat, and fall on its men where they meet them.
func add_house_party(rules: WorldRules, world: World, family: String, seat: String, against: String, to_seat: String, men: int) -> Party:
	if not grid.place_cell.has(seat) or not grid.place_cell.has(to_seat):
		return null
	var h := Party.new()
	h.kind = "house_men"
	h.family = family
	h.name = "men of %s" % family
	h.text = against
	h.home = seat
	h.men = men
	h.tier = rules.house_fight_tier
	h.speed = rules.raider_speed
	h.pos = MapGrid.centre(grid.place_cell[seat])
	h.strike = to_seat
	if not set_course(h, to_seat):
		return null
	parties.append(h)
	return h


## What is left where two parties fought: it lies there `wreck_days`.
func add_wreck(rules: WorldRules, at: Vector2, text: String, leavings: Dictionary) -> Party:
	var w := Party.new()
	w.kind = "wreck"
	w.name = text
	w.text = text
	w.sails = false
	w.speed = 0.0
	w.men = 0
	w.pos = at
	w.leavings = leavings
	w.expire = clock + rules.wreck_days
	parties.append(w)
	return w


## A merchant under the band's guard, with it wherever it goes.
func add_escorted(rules: WorldRules, world: World, from: String) -> Party:
	var m := Party.new()
	m.kind = "merchant"
	m.escorted = true
	m.name = "a merchant of %s" % world.place(from).display_name
	m.home = from
	m.family = world.place(from).family
	m.men = 2
	m.speed = rules.merchant_speed
	m.pos = pos
	m.mood = 1
	parties.append(m)
	return m


## A ship's next voyage: from where she lies to another of `places`.
func _new_route(p: Party, rng: SimRng, places: Array[String]) -> void:
	p.at = 0
	p.route = []
	if places.size() < 2:
		return
	var to := places[rng.randi_range(0, places.size() - 1)]
	var guard := 0
	while to == p.home and guard < 8:
		to = places[rng.randi_range(0, places.size() - 1)]
		guard += 1
	if to == p.home:
		return
	var here := MapGrid.cell_of(p.pos)
	if grid.place_cell.has(p.home) and here == grid.place_cell[p.home]:
		p.route = sea_route(p.home, to).duplicate()
	else:
		# Off her course (a chase): the way from where she is.
		p.route = grid.find_path(here, grid.place_cell[to], 0.0001, 7.0, true).cells
	p.home = to


## Moves every party for `dt` days. `band_men` is the band's strength and
## `band_place` the place it is at ("" in the wilds: a band at a place is
## left alone). Returns the first party to come within reach of the band,
## or null.
func step_parties(dt: float, rng: SimRng, rules: WorldRules, world: World, band_men: int, band_place: String) -> Party:
	var met: Party = null
	var band_cell := cell()
	var band_wet := grid.is_sea(band_cell)
	var band_shore := band_wet or grid.terrain(band_cell) == MapGrid.T.SHORE
	var places: Array[String] = []
	for p in parties:
		if p.escorted:
			p.pos = pos  # under the band's guard: where it goes, he goes
			continue
		var d := p.pos.distance_to(pos)
		var near := d <= rules.contact_leagues
		if p.kind == "wreck":
			if met == null and near and clock >= p.rest_until and band_wet == grid.is_sea(MapGrid.cell_of(p.pos)):
				met = p
			continue
		if p.busy():
			# Locked in a fight, or plundering a farm: it stands, and a band
			# that comes upon it may take a hand.
			if met == null and near and clock >= p.rest_until:
				met = p
			continue
		# A house's men leave a band they think well of alone.
		var free := clock >= p.rest_until and band_place == "" and p.mood <= 0
		# A house's men hunt a blood-enemy whatever the odds; and a laden
		# merchant under the band's guard draws any raider or outlaw.
		var odds_ok := p.mood < 0 or lure
		p.chasing = false
		match p.kind:
			"raiders":
				p.chasing = free and band_shore and d <= rules.raider_sight and (p.men >= band_men or odds_ok)
			"levy":
				p.chasing = free and band_shore and d <= rules.raider_sight * 1.5
			"outlaws":
				p.chasing = free and not band_wet and d <= rules.outlaw_sight and (p.men >= band_men or odds_ok)
			"avengers":
				p.chasing = free and (band_shore if p.sails else not band_wet) and d <= rules.raider_sight * 1.5
			"kings_ships":
				# They hail a band at sea once a summer for the king's due.
				p.chasing = free and band_wet and d <= rules.raider_sight and p.mood == 0
		if p.chasing:
			_chase(p, dt)
		elif p.prey != null and parties.has(p.prey) and p.prey.pos.distance_to(p.pos) <= rules.hunt_sight * 1.5:
			_chase_point(p, p.prey.pos, dt)
		elif p.kind == "ship_thieves":
			_follow(p, dt)  # home with her, and there they stay
		elif p.sails:
			if p.at >= p.route.size() and p.strike == "":
				if places.is_empty():
					places = _harbours(world, p.kind == "merchant")
				_new_route(p, rng, places)
			# (At the farm it made for, it waits: WorldLife starts the raid.)
			_follow(p, dt)
		else:
			_wander(p, dt, rng)
		if met == null and free and near \
				and (p.chasing or (p.kind == "merchant" and band_wet) or (p.kind == "ship_thieves")):
			met = p
	return met


func _harbours(world: World, markets_only: bool) -> Array[String]:
	var out: Array[String] = []
	var ids: Array = world.places.keys()
	ids.sort()
	for id in ids:
		var p: Place = world.places[id]
		if not p.is_open(world.year) or p.region == WorldTypes.Region.ICELAND:
			continue
		if p.has_market or (not markets_only and p.kind != WorldTypes.PlaceKind.THING_SITE):
			out.append(id)
	return out


func _follow(p: Party, dt: float) -> void:
	var left := dt
	while left > 0.0001 and p.at < p.route.size():
		var target := MapGrid.centre(p.route[p.at])
		var d := p.pos.distance_to(target)
		if p.speed * left < d:
			p.pos = p.pos.move_toward(target, p.speed * left)
			return
		p.pos = target
		left -= d / p.speed
		p.at += 1


## Straight for the band, a cell at a time, over the party's own element.
func _chase(p: Party, dt: float) -> void:
	_chase_point(p, pos, dt)


## Straight for a point (the band, or the party it hunts), a cell at a
## time, over the party's own element; it stands off where its element
## ends.
func _chase_point(p: Party, to: Vector2, dt: float) -> void:
	var left := dt
	var guard := 0
	var goal := MapGrid.cell_of(to)
	while left > 0.0001 and guard < 12:
		guard += 1
		var here := MapGrid.cell_of(p.pos)
		var target := to
		if here != goal:
			var best := here
			var best_d := MapGrid.centre(here).distance_to(to)
			for d in MapGrid._DIRS:
				var n: Vector2i = here + d
				if not MapGrid.inside(n):
					continue
				var ok := (grid.is_sea(n) if p.sails else grid.is_land(n)) or n == goal
				if not ok:
					continue
				var nd := MapGrid.centre(n).distance_to(to)
				if nd < best_d:
					best_d = nd
					best = n
			if best == here:
				break  # no nearer by her own element: she stands off
			target = MapGrid.centre(best)
		var speed := p.speed if p.sails else p.speed / float(MapGrid.COST[grid.terrain(MapGrid.cell_of(target))])
		var dist := p.pos.distance_to(target)
		if speed * left < dist:
			p.pos = p.pos.move_toward(target, speed * left)
			break
		p.pos = target
		left -= dist / maxf(speed, 0.05)
		if p.pos.distance_to(to) < 0.5:
			break
	p.route = []  # off her course now
	p.at = 0


## A course for a party from where it is to a place (by its own element;
## a ship to the place's landing). False when there is no way.
func set_course(p: Party, place_id: String) -> bool:
	if not grid.place_cell.has(place_id):
		return false
	var here := MapGrid.cell_of(p.pos)
	var to: Vector2i = grid.place_cell[place_id]
	var path := grid.find_path(here, to, 0.0001 if p.sails else p.speed, 7.0 if p.sails else 0.0, p.sails)
	var cells: Array[Vector2i] = path.cells
	if cells.is_empty():
		return false
	p.route = cells
	p.at = 0
	return true


## Outlaws keep to the land about the farm they prey on.
func _wander(p: Party, dt: float, rng: SimRng) -> void:
	if p.at >= p.route.size():
		var home: Vector2i = grid.place_cell[p.home]
		var to := home + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
		p.route = []
		p.at = 0
		if grid.is_land(to) and not grid.cell_place.has(MapGrid.index(to)):
			# A straight walk over land, as far as the land goes.
			var cur := MapGrid.cell_of(p.pos)
			var guard := 0
			while cur != to and guard < 12:
				guard += 1
				var step := Vector2i(signi(to.x - cur.x), signi(to.y - cur.y))
				if not grid.is_land(cur + step):
					break
				cur += step
				p.route.append(cur)
		if p.route.is_empty():
			return
	var left := dt
	while left > 0.0001 and p.at < p.route.size():
		var target := MapGrid.centre(p.route[p.at])
		var speed := p.speed / float(MapGrid.COST[grid.terrain(p.route[p.at])])
		var d := p.pos.distance_to(target)
		if speed * left < d:
			p.pos = p.pos.move_toward(target, speed * left)
			return
		p.pos = target
		left -= d / speed
		p.at += 1
