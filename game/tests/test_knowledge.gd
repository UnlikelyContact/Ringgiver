extends TestCase


static func _band(world: World, rules: WorldRules) -> Band:
	var b := Band.new()
	b.leader = Man.new()
	b.leader.is_leader = true
	b.ship = Ship.make(WorldTypes.ShipKind.SNEKKJA)
	b.home = "fitjar"
	b.location = "fitjar"
	Knowledge.learn_home(rules, world, b)
	return b


func test_starts_with_home_region() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band(w, r)
	assert_eq(b.known_places.size(), 3)
	for id in ["fitjar", "gulathing", "hardanger"]:
		assert_true(b.knows(id), id)
	assert_true(not b.knows("lade"))
	assert_eq(Knowledge.known_targets(w, b).size(), 3)


func test_reveal_adds_lane_neighbours() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band(w, r)
	var log := PackedStringArray()
	Knowledge.reveal(w, b, "giske", log)
	for id in ["giske", "sogn_hall", "more_farms", "lade", "orkney"]:
		assert_true(b.knows(id), id)
	assert_true(not b.knows("frostathing"), "two lanes away stays unknown")
	assert_eq(log.size(), 1)
	# Closed places are not revealed.
	Knowledge.reveal(w, b, "orkney", log)
	assert_true(not b.knows("iceland"), "Iceland is not open in 866")
	assert_true(b.knows("dublin"))


func test_arrival_reveals_through_sail() -> void:
	var r := WorldRules.new()
	r.encounter_chance = 0.0
	r.storm_chance = 0.0
	var w := World.build_norway(r)
	var b := _band(w, r)
	b.known_places["sogn_hall"] = true
	var res := Voyage.sail(SimRng.new(1), r, w, b, Calendar.new(), "sogn_hall", PackedStringArray())
	assert_true(res.arrived)
	assert_true(b.knows("giske"))
	assert_true(b.knows("sogn_farms"))


func test_rumor_reveals_only_unknown_within_radius() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var rng := SimRng.new(4)
	var within := Voyage.distances(w, "fitjar")
	for i in range(200):
		var b := _band(w, r)
		var before := b.known_places.duplicate()
		var id := Knowledge.hear_rumor(rng, r, w, b, "fitjar", PackedStringArray())
		assert_ne(id, "")
		assert_true(not before.has(id), "rumor of a known place")
		assert_true(within[id] <= r.rumor_radius_days, "%s too far" % id)
		assert_eq(b.known_places.size(), before.size() + 1)
		assert_eq(b.rumors.size(), 1)
	# Once everything near is known, rumors dry up.
	var b2 := _band(w, r)
	for id in within:
		if within[id] <= r.rumor_radius_days:
			b2.known_places[id] = true
	assert_eq(Knowledge.hear_rumor(rng, r, w, b2, "fitjar", PackedStringArray()), "")
	# No rumors at a farm or a bay.
	var b3 := _band(w, r)
	assert_eq(Knowledge.hear_rumor(rng, r, w, b3, "hardanger", PackedStringArray()), "")
	assert_eq(b3.rumors.size(), 0)


func test_known_targets_skip_closed_places() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band(w, r)
	b.known_places["iceland"] = true
	b.known_places["lade"] = true
	var ids := []
	for p in Knowledge.known_targets(w, b):
		ids.append(p.id)
	assert_true(ids.has("lade"))
	assert_true(not ids.has("iceland"))
