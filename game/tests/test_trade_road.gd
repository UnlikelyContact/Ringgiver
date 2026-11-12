extends TestCase
## The trader's road (TradeRoad, Market's local stalls, Knowledge's price
## book): pack-trading on foot between neighbouring farms, the félag, a
## poor man's livings, passage with loads, "what sells where", and no
## loop between two places that pays without end. See
## docs/design/notes/world-life.md.

const G := WorldTypes.Good


func _world() -> World:
	var wr := WorldRules.new()
	var w := World.build_norway(wr, 866)
	TradeRoad.open_stalls(wr, w)
	return w


## Answers whatever waits (the spring's asks) so the band is free to act.
func _free(j: Journey) -> void:
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		var d := j.current()
		var last: Dictionary = d.options[d.options.size() - 1]
		j.answer(str(last.id))


func _walker(silver := 100, men := 2) -> Band:
	var b := Band.new()
	b.silver = silver
	b.leader = Man.new()
	b.leader.id = 1
	b.leader.is_leader = true
	for i in men:
		var m := Man.new()
		m.id = i + 2
		b.add_man(m)
	return b


func test_farms_deal_in_what_they_make_and_lack() -> void:
	var r := WorldRules.new()
	var w := _world()
	var hardanger := w.place("hardanger")
	var sogn := w.place("sogn_farms")
	assert_true(Market.sells_here(hardanger, G.IRON), "Hardanger makes iron")
	assert_true(not Market.buys_here(hardanger, G.IRON), "and does not buy back its own")
	assert_true(Market.buys_here(sogn, G.IRON), "Sogn lacks iron")
	assert_true(not Market.sells_here(sogn, G.IRON))
	assert_true(Market.price(r, hardanger, G.IRON) < Market.price(r, sogn, G.IRON), "cheap where it is made, dear where it is wanted")
	assert_true(Market.sells_here(w.place("jaeren"), G.GRAIN), "a farm still sells rations")
	assert_true(not Market.buys_here(w.place("jaeren"), G.FURS), "a farm with no stall buys nothing")


func test_a_band_on_foot_carries_a_load_a_man() -> void:
	var r := WorldRules.new()
	var b := _walker(100, 2)
	assert_eq(Market.cargo_capacity(r, b), r.no_ship_cargo + 2 * r.load_per_man, "the leader's loads and one a man")
	b.ship = Ship.make(WorldTypes.ShipKind.FAERING)
	assert_eq(Market.cargo_capacity(r, b), r.no_ship_cargo + 2, "a færing's hold is no more than the men carry")
	b.ship = Ship.make(WorldTypes.ShipKind.KNARR)
	assert_eq(Market.cargo_capacity(r, b), int(r.ship_cargo[WorldTypes.ShipKind.KNARR]))
	b.felag.append({"partner": "x", "good": G.FURS, "units": 3, "to": "fitjar", "share": 0.4})
	assert_eq(Market.cargo_room(r, b), int(r.ship_cargo[WorldTypes.ShipKind.KNARR]) - 3, "a partner's goods take room too")


func test_a_load_of_iron_walked_to_sogn_pays_and_the_gap_closes() -> void:
	var r := WorldRules.new()
	var w := _world()
	var b := _walker(30, 2)
	var log := PackedStringArray()
	var hardanger := w.place("hardanger")
	var sogn := w.place("sogn_farms")
	var start := b.silver
	var gap_before := Market.price(r, sogn, G.IRON) - Market.price(r, hardanger, G.IRON)
	assert_eq(Market.buy(r, hardanger, b, G.IRON, 9, log), Market.cargo_capacity(r, b), "as many loads as the band can carry")
	Market.sell(r, sogn, b, G.IRON, 9, log)
	assert_true(b.silver > start, "an honest living: %d -> %d oz" % [start, b.silver])
	var gap_after := Market.price(r, sogn, G.IRON) - Market.price(r, hardanger, G.IRON)
	assert_true(gap_after < gap_before, "the gap closes as loads are carried across it (%d -> %d)" % [gap_before, gap_after])
	print("    gate: iron Hardanger to Sogn on foot, 4 loads: %d -> %d oz; the gap %d -> %d oz" % [start, b.silver, gap_before, gap_after])
	# It mends back, slowly: a difference lasts long enough to act on.
	Market.mend_local(r, w, 5.0)
	assert_true(Market.price(r, sogn, G.IRON) - Market.price(r, hardanger, G.IRON) < gap_before, "five days on, not yet mended")
	Market.mend_local(r, w, 60.0)
	assert_eq(Market.price(r, sogn, G.IRON) - Market.price(r, hardanger, G.IRON), gap_before, "two months on, it is as it was")


## The loop the old pump was made of, between every two places that deal
## in a good one makes and the other lacks, both ways, as fast as a band
## of four with a knarr could walk it, with the stalls mending as the days
## pass: the silver it makes in a day must not grow, and must stay small.
func test_no_two_place_loop_pays_without_end() -> void:
	var r := WorldRules.new()
	var pairs := [["hardanger", "sogn_farms"], ["sogn_farms", "fitjar"], ["more_farms", "giske"], ["kaupang", "hedeby"], ["lier", "kaupang"]]
	for pr in pairs:
		var w := _world()
		var a := w.place(str(pr[0]))
		var b2 := w.place(str(pr[1]))
		var band := _walker(500, 3)
		band.ship = Ship.make(WorldTypes.ShipKind.KNARR)
		var log := PackedStringArray()
		var days_leg := maxf(2.0, a.pos.distance_to(b2.pos) / 6.0)
		var per_day: Array[float] = []
		var day := 0.0
		for lap in 120:
			var before := band.silver
			for leg in [[a, b2], [b2, a]]:
				var from: Place = leg[0]
				var to: Place = leg[1]
				# Buy while it still pays to carry: the way a man works a gap.
				for g in G.values():
					if not (Market.sells_here(from, g) and Market.buys_here(to, g)) or g == G.GRAIN:
						continue
					while Market.cargo_room(r, band) > 0 and Market.buy_price(r, from, band, g) < Market.sell_price(r, to, band, g) \
							and int(from.stock.get(g, 0)) > 0:
						if Market.buy(r, from, band, g, 1, log) <= 0:
							break
				for g in band.cargo.keys():
					if Market.buys_here(to, g):
						Market.sell(r, to, band, g, int(band.cargo[g]), log)
				Market.mend_local(r, w, days_leg + r.market_days)
				day += days_leg + r.market_days
			per_day.append(float(band.silver - before) / (2.0 * (days_leg + r.market_days)))
		var early := 0.0
		var late := 0.0
		for i in 20:
			early += per_day[i]
			late += per_day[per_day.size() - 1 - i]
		early /= 20.0
		late /= 20.0
		assert_true(late <= early + 0.5, "%s and %s: the loop does not grow (%.1f then %.1f oz a day)" % [pr[0], pr[1], early, late])
		print("    gate: loop %s - %s: %.1f oz a day at first, %.1f once worked; %d oz in %d days" % [pr[0], pr[1], early, late, band.silver - 500, roundi(day)])
		assert_true(late <= 6.0, "%s and %s: %.1f oz a day once the stalls are worked, not a fortune" % [pr[0], pr[1], late])
		assert_true(band.silver < 500 + 6.0 * day, "%s and %s: %d oz after %d days" % [pr[0], pr[1], band.silver, roundi(day)])


func test_the_felag_carries_a_partners_goods_for_a_share() -> void:
	var j := Journey.begin(3, "freedman", "Egil")
	_free(j)
	var band := j.c.band
	assert_eq(band.location, "fitjar")
	var f := TradeRoad.felag_offer(j)
	assert_true(not f.is_empty(), "a man at Fitjar has goods to send")
	var ids := {}
	for a in j.actions():
		ids[a.id] = a
	assert_true(ids.has("felag"), "offered among the deeds")
	var silver := band.silver
	j.act("felag")
	assert_eq(band.felag.size(), 1, "the goods are aboard")
	assert_eq(band.silver, silver, "it costs nothing but the carrying")
	assert_true(TradeRoad.felag_offer(j).is_empty(), "one partnership a place a year")
	var to := str(f.to)
	j.sail(to)
	if j.c.band.location != to:
		j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[to])
		j.c.band.location = to
		j.decisions.clear()  # whatever stopped him on the way (a merchant hailing)
	var sell := ""
	for a in j.actions():
		if str(a.id).begins_with("felag_sell:"):
			sell = a.id
	assert_ne(sell, "", "at %s the goods can be sold" % to)
	var before := band.silver
	var standing := Families.standing(band, str(f.partner))
	j.act(sell)
	assert_true(band.silver > before, "his share: %d oz" % (band.silver - before))
	assert_true(band.felag.is_empty())
	assert_true(Families.standing(band, str(f.partner)) > standing, "the partner thinks the better of him")


func test_a_poor_mans_livings() -> void:
	var j := Journey.begin(2, "freedman", "Egil")
	_free(j)
	var band := j.c.band
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["hardanger"])
	band.location = "hardanger"
	var ids := {}
	for a in j.actions():
		ids[a.id] = a
	assert_true(ids.has("labour") and ids.has("herd"), "a farm has fields and herds for a man to work")
	var s0 := band.silver
	var food := band.food
	var day := j.c.cal.day
	j.act("labour")
	assert_eq(band.silver, s0 + TradeRoad.labour_pay(j.c.world_rules, band.living_men().size()))
	assert_eq(band.food, food + j.c.world_rules.labour_food)
	assert_true(j.c.cal.day >= day + j.c.world_rules.labour_days, "it takes its days")
	var again := false
	for a in j.actions():
		again = again or a.id == "labour"
	assert_true(not again, "once a farm a year")
	var known := band.known_places.size()
	j.act("herd")
	assert_true(band.known_places.size() >= known, "the high pastures teach the country")


func test_the_price_book_reads_what_sells_where() -> void:
	var j := Journey.begin(1, "younger_son", "Egil")
	var band := j.c.band
	var wr := j.c.world_rules
	Knowledge.see_prices(wr, j.c.world, band, "hardanger", 1)
	Knowledge.see_prices(wr, j.c.world, band, "sogn_farms", 3)
	var book := Knowledge.price_book(wr, j.c.world, band, 5)
	var places: Array = book.places
	assert_eq(places.size(), 2, "the two places seen")
	assert_eq(str(places[0].when), "4 days ago")
	var iron := false
	for run in book.runs:
		if int(run.good) == G.IRON:
			iron = str(run.from) == "hardanger" and str(run.to) == "sogn_farms" and int(run.margin) > 0
	assert_true(iron, "iron from Hardanger to Sogn is a run worth walking")
	var rows := j.market()
	assert_true(not rows.is_empty(), "the farm's stall is on the market panel")
	for row in rows:
		assert_true(row.has("can_buy") and row.has("can_sell"))


func test_passage_takes_the_loads_for_a_price() -> void:
	var j := Journey.begin(4, "younger_son", "Egil")
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["fitjar"])
	j.c.band.location = "fitjar"
	j.c.band.known_places["avaldsnes"] = true
	var bare: Array[Dictionary] = j.passages()
	assert_true(not bare.is_empty())
	j.c.band.cargo[G.SOAPSTONE] = 2
	var laden: Array[Dictionary] = j.passages()
	assert_eq(int(laden[0].cost), int(bare[0].cost) + 2 * j.c.world_rules.passage_per_load, "a price a load")


func test_a_merchant_guarded_to_his_market_pays() -> void:
	var j := Journey.begin(5, "younger_son", "Egil")
	_free(j)
	var band := j.c.band
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["lade"])
	band.location = "lade"
	band.known_places["lade"] = true
	band.known_places["bjarkoy"] = true
	var e := TradeRoad.escort_offer(j)
	assert_true(not e.is_empty(), "a merchant at Lade wants a guard")
	j.act("escort")
	assert_true(j.roam.lure, "a laden merchant draws raiders")
	var to := str(e.to)
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[to])
	band.location = to
	var before := band.silver
	TradeRoad.check_escort(j)
	assert_eq(band.silver, before + int(e.pay), "paid on arrival")
	assert_true(not j.roam.lure and j.life.get("escort", {}).is_empty())
