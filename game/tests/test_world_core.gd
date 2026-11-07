extends TestCase


func test_norway_builds_and_connects() -> void:
	var w := World.build_norway(WorldRules.new())
	assert_true(w.places.size() >= 25)
	assert_eq(w.days_between("kaupang", "borre"), 1)
	assert_eq(w.days_between("borre", "kaupang"), 1, "lanes are two-way")
	assert_eq(w.days_between("kaupang", "lade"), -1, "no direct lane")
	assert_true(w.lane_is_open_sea("kaupang", "hedeby"))
	assert_true(not w.lane_is_open_sea("kaupang", "borre"))
	assert_true(w.neighbours("lade").has("bjarkoy"))
	# Every place is reachable from Kaupang.
	var seen := {"kaupang": true}
	var queue: Array[String] = ["kaupang"]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for n in w.neighbours(id):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	for id in w.places:
		assert_true(seen.has(id), "%s unreachable" % id)


func test_iceland_opens_in_874() -> void:
	var w := World.build_norway(WorldRules.new(), 866)
	assert_true(not w.place("iceland").is_open(866))
	assert_true(w.open_places().size() == w.places.size() - 1)
	w.year = 874
	assert_true(w.place("iceland").is_open(w.year))


func test_markets_stock_and_farms_hold_grain() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	assert_eq(w.place("hedeby").stock[WorldTypes.Good.FURS], r.stock_baseline)
	assert_true(not w.place("jaeren").has_market)
	assert_eq(w.place("jaeren").stock[WorldTypes.Good.GRAIN], r.stock_baseline)
	assert_eq(w.places_in(WorldTypes.Region.HALOGALAND).size(), 3)


func test_ship_and_calendar_days() -> void:
	var r := WorldRules.new()
	var s := Ship.make(WorldTypes.ShipKind.SNEKKJA)
	assert_eq(s.crew_capacity(r), 24)
	assert_true(s.can_sail(r))
	s.damage = r.ship_unsailable_damage
	assert_true(not s.can_sail(r))
	var c := Calendar.new(870)
	c.advance_days(150)
	assert_eq(c.summer_left(r.summer_days), 49, "day 1 plus 150 days is day 151")
	c.start_winter()
	c.advance_turn(); c.advance_turn(); c.advance_turn(); c.advance_turn()
	assert_eq(c.day, 1, "a new year starts on day 1")


func test_band_world_fields() -> void:
	var b := Band.new()
	b.cargo[WorldTypes.Good.FURS] = 4
	b.cargo[WorldTypes.Good.AMBER] = 2
	assert_eq(b.cargo_units(), 6)
	assert_true(b.add_feud("Augvald's kin", "raid on Avaldsnes", "avaldsnes"))
	assert_eq(b.feuds[0].level, 1)
	assert_eq(b.feuds[0].place, "avaldsnes")
	assert_true(not b.knows("lade"))
