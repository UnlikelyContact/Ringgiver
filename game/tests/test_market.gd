extends TestCase

const G := WorldTypes.Good


func _band(silver := 1000, kind := WorldTypes.ShipKind.KNARR) -> Band:
	var b := Band.new()
	b.silver = silver
	b.ship = Ship.make(kind)
	return b


func test_buying_twenty_furs_at_kaupang_raises_price() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var kaupang := w.place("kaupang")
	var b := _band()
	var log: PackedStringArray = []
	var before := Market.price(r, kaupang, G.FURS)
	assert_eq(before, r.base_price[G.FURS], "at baseline stock the price is the base price")
	assert_eq(Market.buy(r, kaupang, b, G.FURS, 20, log), 20)
	var after := Market.price(r, kaupang, G.FURS)
	assert_true(after - before >= r.price_rise_min, "price %d -> %d" % [before, after])
	print("    gate: 20 furs at Kaupang move the price %d -> %d oz (paid %d)" % [before, after, 1000 - b.silver])
	assert_eq(b.cargo[G.FURS], 20)
	assert_eq(kaupang.stock[G.FURS], 0)
	assert_true(b.silver < 1000)
	assert_true(not log.is_empty())


func test_selling_adds_stock_and_lowers_price() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var hedeby := w.place("hedeby")
	var b := _band(0)
	b.cargo[G.FURS] = 10
	var before := Market.price(r, hedeby, G.FURS)
	var log: PackedStringArray = []
	var earned := Market.sell(r, hedeby, b, G.FURS, 15, log)
	assert_true(earned > 0)
	assert_eq(b.silver, earned)
	assert_true(not b.cargo.has(G.FURS), "sold only what was carried")
	assert_eq(hedeby.stock[G.FURS], r.stock_baseline + 10)
	assert_true(Market.price(r, hedeby, G.FURS) < before)


func test_cargo_capacity_and_silver_limit_buying() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var kaupang := w.place("kaupang")
	var log: PackedStringArray = []
	var b := _band(1000, WorldTypes.ShipKind.KARVE)
	b.cargo[G.IRON] = 2
	assert_eq(Market.buy(r, kaupang, b, G.FURS, 20, log), r.ship_cargo[WorldTypes.ShipKind.KARVE] - 2)
	var walker := Band.new()
	walker.silver = 1000
	assert_eq(Market.buy(r, kaupang, walker, G.FURS, 20, log), r.no_ship_cargo, "no ship: what men can carry")
	var poor := _band(9)
	assert_eq(Market.buy(r, World.build_norway(r).place("kaupang"), poor, G.FURS, 20, log), 2, "4 + 4 oz, then too poor")
	assert_eq(poor.silver, 1)


func test_farms_sell_only_food_and_buy_nothing() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var jaeren := w.place("jaeren")
	var b := _band(10)
	b.cargo[G.FURS] = 3
	var log: PackedStringArray = []
	assert_eq(Market.price(r, jaeren, G.GRAIN), r.farm_food_price)
	assert_eq(Market.price(r, jaeren, G.FURS), 0)
	assert_eq(Market.buy(r, jaeren, b, G.FURS, 1, log), 0)
	assert_eq(Market.sell(r, jaeren, b, G.FURS, 3, log), 0)
	assert_eq(b.cargo[G.FURS], 3)
	var food := b.food
	assert_eq(Market.buy(r, jaeren, b, G.GRAIN, 5, log), 5)
	assert_eq(b.food, food + 5, "farm grain becomes rations")
	assert_eq(b.silver, 10 - 5 * r.farm_food_price)
	assert_true(not b.cargo.has(G.GRAIN))


func test_furs_from_halogaland_sell_at_hedeby_for_profit() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band(200)
	for id in w.places:
		b.known_places[id] = true
	var best := Market.best_trade(w, b, "bjarkoy", r)
	assert_eq(best.get("to", ""), "hedeby", "best trade from Bjarkøy: %s" % str(best))
	assert_true(best.get("profit_per_unit", 0) > 0)
	var log: PackedStringArray = []
	var start := b.silver
	var n := Market.buy(r, w.place("bjarkoy"), b, G.FURS, 10, log)
	assert_eq(n, 10)
	Market.sell(r, w.place("hedeby"), b, G.FURS, n, log)
	assert_true(b.silver > start, "%d -> %d" % [start, b.silver])
	print("    gate: best trade from Bjarkøy %s; 10 furs Bjarkøy -> Hedeby: %d -> %d oz" % [str(best), start, b.silver])


func test_best_trade_only_known_markets() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band()
	b.known_places["bjarkoy"] = true
	assert_eq(Market.best_trade(w, b, "bjarkoy", r), {}, "no other market known")
	assert_eq(Market.best_trade(w, b, "jaeren", r), {}, "no market here")
	b.known_places["lade"] = true
	assert_eq(Market.best_trade(w, b, "bjarkoy", r).get("to", ""), "lade")
	assert_eq(Market.best_trade(w, b, "bjarkoy").get("to", ""), "lade", "default rules")


func test_yearly_drift_toward_baseline_and_source_supply() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var log: PackedStringArray = []
	var kaupang := w.place("kaupang")
	var hedeby := w.place("hedeby")
	kaupang.stock[G.FURS] = 0
	hedeby.stock[G.FURS] = 60
	w.place("jaeren").stock[G.GRAIN] = 0
	Market.yearly_drift(SimRng.new(5), r, w, log)
	assert_eq(kaupang.stock[G.FURS], 10, "half way back up")
	assert_eq(hedeby.stock[G.FURS], 40, "half way back down")
	assert_eq(w.place("jaeren").stock[G.GRAIN], 10, "farms refill grain")
	var bj: int = w.place("bjarkoy").stock[G.FURS]
	assert_between(bj, r.stock_baseline + r.source_supply - r.source_supply_spread,
			r.stock_baseline + r.source_supply + r.source_supply_spread, "furs pile up at the source")
	assert_eq(hedeby.stock[G.AMBER], r.stock_baseline, "Denmark is not an amber source")
	assert_true(w.place("gotland").stock[G.AMBER] > r.stock_baseline, "the Baltic is")
	# Over many years sources stay cheap.
	for i in 10:
		Market.yearly_drift(SimRng.new(i), r, w, log)
	assert_true(Market.price(r, w.place("bjarkoy"), G.FURS) < Market.price(r, w.place("hedeby"), G.FURS))


func test_captive_glut_and_slave_markets() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var log: PackedStringArray = []
	var b := _band(0)
	b.captives = 10
	assert_eq(Market.sell_captives(r, w.place("kaupang"), b, 5, log), 0, "Kaupang is no slave market")
	assert_eq(b.captives, 10)
	var hedeby := w.place("hedeby")
	var first := Market.sell_captives(r, hedeby, b, 2, log)
	assert_eq(first, r.captive_price + roundi(r.captive_price * (1.0 - r.captive_glut)))
	var second := Market.sell_captives(r, hedeby, b, 2, log)
	assert_true(second < first, "glut: %d then %d" % [first, second])
	assert_eq(b.captives, 6)
	assert_eq(b.silver, first + second)
	assert_eq(Market.sell_captives(r, w.place("birka"), b, 1, log), r.captive_price, "Birka has no glut yet")
	Market.yearly_drift(SimRng.new(1), r, w, log)
	assert_eq(Market.captive_price(r, hedeby), r.captive_price, "the glut clears with the year")


func test_drift_replays_from_rng() -> void:
	var r := WorldRules.new()
	var runs: Array = []
	for k in 2:
		var w := World.build_norway(r)
		var log: PackedStringArray = []
		var rng := SimRng.new(77)
		for y in 5:
			Market.yearly_drift(rng, r, w, log)
		var snap := {}
		for id in w.places:
			snap[id] = w.places[id].stock.duplicate()
		runs.append(snap)
	assert_eq(str(runs[0]), str(runs[1]))
	var other := World.build_norway(r)
	var log2: PackedStringArray = []
	var rng2 := SimRng.new(78)
	for y in 5:
		Market.yearly_drift(rng2, r, other, log2)
	var snap2 := {}
	for id in other.places:
		snap2[id] = other.places[id].stock.duplicate()
	assert_ne(str(snap2), str(runs[0]), "another seed differs")
