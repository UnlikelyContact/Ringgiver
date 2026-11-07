extends TestCase


static func _band(world: World, rules: WorldRules, at := "fitjar", men := 10) -> Band:
	var b := Band.new()
	var lead := Man.new()
	lead.display_name = "Egil"
	lead.is_leader = true
	b.leader = lead
	for i in range(men):
		var m := Man.new()
		m.display_name = "Man%d" % i
		b.add_man(m)
	b.ship = Ship.make(WorldTypes.ShipKind.LONGSHIP)
	b.home = "fitjar"
	b.location = at
	Knowledge.learn_home(rules, world, b)
	return b


static func _know_all(world: World, band: Band) -> void:
	for id in world.places:
		band.known_places[id] = true


static func _calm(rules: WorldRules) -> void:
	rules.encounter_chance = 0.0
	rules.storm_chance = 0.0


func test_gate_hordaland_to_trondelag() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var route := Voyage.plan(w, "fitjar", "lade")
	assert_true(not route.is_empty(), "a route exists")
	assert_eq(route[0], "fitjar")
	assert_eq(route[route.size() - 1], "lade")
	var days := Voyage.route_days(w, route)
	print("    gate: fitjar -> lade %s, %d days" % [" > ".join(PackedStringArray(route)), days])
	assert_between(days, r.route_min_days, r.route_max_days)
	# Sailing it with calm weather costs exactly that.
	_calm(r)
	var b := _band(w, r)
	_know_all(w, b)
	var cal := Calendar.new()
	var res := Voyage.sail(SimRng.new(1), r, w, b, cal, "lade", PackedStringArray())
	assert_true(res.arrived)
	assert_eq(res.days, days)
	assert_eq(cal.day, 1 + days)
	assert_eq(b.location, "lade")


func test_dijkstra_picks_cheaper_route() -> void:
	var w := World.new()
	for id in ["a", "b", "c", "d"]:
		var p := Place.new()
		p.id = id
		p.display_name = id
		w.places[id] = p
	w.add_lane("a", "d", 10)
	w.add_lane("a", "c", 1)
	w.add_lane("c", "d", 5)
	w.add_lane("a", "b", 2)
	w.add_lane("b", "d", 2)
	var route := Voyage.plan(w, "a", "d")
	assert_eq(route, ["a", "b", "d"] as Array[String])
	assert_eq(Voyage.route_days(w, route), 4)
	# Only known places may be passed through: without b, c is the way.
	route = Voyage.plan(w, "a", "d", {"a": true, "c": true, "d": true})
	assert_eq(route, ["a", "c", "d"] as Array[String])
	assert_eq(Voyage.plan(w, "a", "zzz"), [] as Array[String])


func test_gate_coastal_lanes_never_wreck() -> void:
	var r := WorldRules.new()
	r.storm_chance = 0.0
	var w := World.build_norway(r)
	var rng := SimRng.new(7)
	var wrecks := 0
	for i in range(1000):
		var b := _band(w, r, "fitjar", 4)
		_know_all(w, b)
		var res := Voyage.sail(rng, r, w, b, Calendar.new(), "gulathing", PackedStringArray())
		if res.wrecked:
			wrecks += 1
		assert_eq(b.men.size(), 4)
	print("    gate: 1000 coastal lanes, %d wrecks" % wrecks)
	assert_eq(wrecks, 0)


func test_gate_open_sea_wreck_rate() -> void:
	var r := WorldRules.new()
	_calm(r)
	var w := World.build_norway(r)
	var rng := SimRng.new(11)
	var wrecks := 0
	for i in range(1000):
		var b := _band(w, r, "kaupang", 6)
		_know_all(w, b)
		b.cargo[WorldTypes.Good.FURS] = 3
		var res := Voyage.sail(rng, r, w, b, Calendar.new(), "hedeby", PackedStringArray())
		if res.wrecked:
			wrecks += 1
			assert_eq(b.cargo_units(), 0, "cargo lost")
			assert_eq(b.ship.damage, r.wreck_damage)
			assert_true(not b.ship.can_sail(r))
			assert_eq(b.men.size(), 6 - r.wreck_men_lost)
			assert_true(b.leader.alive, "the leader never drowns")
			assert_true(w.place(b.location) != null)
	var rate := wrecks / 1000.0
	print("    gate: 1000 open-sea lanes, wreck rate %.3f (wreck_chance %.3f)" % [rate, r.wreck_chance])
	assert_between(rate, r.wreck_chance - 0.015, r.wreck_chance + 0.015)


func test_wreck_drowns_more_in_mail_and_never_the_leader() -> void:
	var r := WorldRules.new()
	_calm(r)
	r.wreck_chance = 1.0
	var w := World.build_norway(r)
	var rng := SimRng.new(3)
	var lost_plain := 0
	var lost_mail := 0
	for i in range(200):
		var b := _band(w, r, "kaupang", 8)
		_know_all(w, b)
		Voyage.sail(rng, r, w, b, Calendar.new(), "hedeby", PackedStringArray())
		lost_plain += 8 - b.men.size()
		var c := _band(w, r, "kaupang", 8)
		_know_all(w, c)
		for m in c.men:
			m.armor = CombatTypes.Armor.MAIL
		var drowned_flags := c.men.duplicate()
		Voyage.sail(rng, r, w, c, Calendar.new(), "hedeby", PackedStringArray())
		lost_mail += 8 - c.men.size()
		for m in drowned_flags:
			if not c.men.has(m):
				assert_true(not m.alive, "drowned men are dead")
	assert_eq(lost_plain, 200 * r.wreck_men_lost)
	assert_true(lost_mail > lost_plain, "mail drowns more men")
	# A band of the leader alone: nobody drowns.
	var lone := _band(w, r, "kaupang", 0)
	_know_all(w, lone)
	var res := Voyage.sail(rng, r, w, lone, Calendar.new(), "hedeby", PackedStringArray())
	assert_true(res.wrecked)
	assert_true(lone.leader.alive)


func test_gate_never_arrives_after_summer() -> void:
	var r := WorldRules.new()
	r.storm_chance = 0.5
	var w := World.build_norway(r)
	var rng := SimRng.new(5)
	var arrivals := 0
	var dests := ["lade", "hedeby", "orkney", "bjarkoy", "gulathing", "dublin"]
	for i in range(500):
		var b := _band(w, r, "fitjar", 6)
		_know_all(w, b)
		var cal := Calendar.new()
		cal.day = rng.randi_range(r.summer_days - 25, r.summer_days + 2)
		var res := Voyage.sail(rng, r, w, b, cal, dests[i % dests.size()], PackedStringArray())
		assert_true(w.place(b.location) != null, "location valid")
		assert_eq(res.stopped_at, b.location)
		if res.arrived:
			arrivals += 1
		if res.days > 0:
			assert_true(cal.day <= r.summer_days, "day %d past summer" % cal.day)
	print("    gate: 500 late voyages, %d arrived, none after day %d" % [arrivals, r.summer_days])
	assert_true(arrivals > 0)
	# Too late from the start: refused and the band stays.
	var b2 := _band(w, r)
	_know_all(w, b2)
	var cal2 := Calendar.new()
	cal2.day = r.summer_days - 2
	var res2 := Voyage.sail(SimRng.new(1), r, w, b2, cal2, "lade", PackedStringArray())
	assert_true(not res2.arrived)
	assert_eq(res2.days, 0)
	assert_eq(b2.location, "fitjar")
	assert_eq(cal2.day, r.summer_days - 2)


func test_unknown_destination_refused() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band(w, r)
	var cal := Calendar.new()
	var res := Voyage.sail(SimRng.new(1), r, w, b, cal, "lade", PackedStringArray())
	assert_true(not res.arrived)
	assert_eq(res.days, 0)
	assert_eq(b.location, "fitjar")
	assert_eq(cal.day, 1)
	# Iceland is closed before 874 even if known.
	b.known_places["iceland"] = true
	res = Voyage.sail(SimRng.new(1), r, w, b, cal, "iceland", PackedStringArray())
	assert_true(not res.arrived)
	assert_eq(res.days, 0)


func test_unsailable_ship_and_invalid_location() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band(w, r)
	_know_all(w, b)
	b.ship.damage = r.ship_unsailable_damage
	var res := Voyage.sail(SimRng.new(1), r, w, b, Calendar.new(), "lade", PackedStringArray())
	assert_true(not res.arrived)
	assert_eq(res.days, 0)
	b.location = "nowhere"
	Voyage.sail(SimRng.new(1), r, w, b, Calendar.new(), "lade", PackedStringArray())
	assert_eq(b.location, "fitjar", "falls back to home")


func test_battle_stops_voyage_and_resumes() -> void:
	var r := WorldRules.new()
	r.storm_chance = 0.0
	r.encounter_chance = 1.0
	r.encounter_weights = {"rival_ship": 1}
	var w := World.build_norway(r)
	var b := _band(w, r)
	_know_all(w, b)
	var cal := Calendar.new()
	var res := Voyage.sail(SimRng.new(2), r, w, b, cal, "lade", PackedStringArray())
	assert_true(not res.arrived)
	assert_eq(res.stopped_at, "gulathing", "stops after the first lane")
	assert_eq(res.battle().kind, "rival_ship")
	assert_eq(res.days, 1)
	r.encounter_chance = 0.0
	res = Voyage.sail(SimRng.new(2), r, w, b, cal, "lade", PackedStringArray())
	assert_true(res.arrived)
	assert_eq(cal.day, 1 + 9)


func test_storm_delays_and_damages() -> void:
	var r := WorldRules.new()
	r.storm_chance = 1.0
	r.encounter_chance = 0.0
	var w := World.build_norway(r)
	var b := _band(w, r)
	var res := Voyage.sail(SimRng.new(2), r, w, b, Calendar.new(), "gulathing", PackedStringArray())
	assert_true(res.arrived)
	assert_eq(res.days, 1 + r.storm_delay_days)
	assert_eq(b.ship.damage, r.storm_ship_damage)


func test_sail_is_deterministic() -> void:
	var r := WorldRules.new()
	r.encounter_chance = 0.6
	var w1 := World.build_norway(r)
	var w2 := World.build_norway(r)
	var b1 := _band(w1, r, "kaupang")
	var b2 := _band(w2, r, "kaupang")
	_know_all(w1, b1)
	_know_all(w2, b2)
	var c1 := Calendar.new()
	var c2 := Calendar.new()
	var l1 := PackedStringArray()
	var l2 := PackedStringArray()
	var r1 := Voyage.sail(SimRng.new(99), r, w1, b1, c1, "dublin", l1)
	var r2 := Voyage.sail(SimRng.new(99), r, w2, b2, c2, "dublin", l2)
	assert_eq(r1.describe(), r2.describe())
	assert_eq(r1.encounters.size(), r2.encounters.size())
	assert_eq(l1, l2)
	assert_eq(c1.day, c2.day)
	assert_eq(b1.men.size(), b2.men.size())
	assert_eq(b1.silver, b2.silver)
	assert_eq(b1.food, b2.food)
	assert_eq(b1.ship.damage, b2.ship.damage)
