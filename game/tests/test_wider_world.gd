extends TestCase
## The wider world (docs/design/notes/wider-world.md): Shetland and the
## Hebrides in the west, the river road east to Miklagard with its
## portages; reachable through Journey, priced through Market, and saved
## like everything else.

const WEST := ["shetland", "hebrides", "skye"]
const EAST := ["aldeigjuborg", "holmgard", "koenugard", "miklagard"]


## A band of `men` (leader and all) with a hull of `kind`, at `at`, knowing
## every place, its fights told quickly.
func _journey(at: String, kind: int, men := 7, seed_in := 7) -> Journey:
	var j := Journey.begin(seed_in, "younger_son", "Egil")
	j.quick = true
	var band := j.c.band
	band.silver = 600
	band.ship = Ship.make(kind as WorldTypes.ShipKind)
	var i := 0
	while band.fighters().size() < men:
		band.add_man(Recruits.random(SimRng.new(100 + i), j.c.rules, band.next_id()))
		i += 1
	j.decisions.clear()
	j.roam.stop()
	j.roam.aboard = true
	j.roam.ship_at = Vector2.INF
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	band.location = at
	j._was_at = at
	for id in j.c.world.places:
		band.known_places[id] = true
	return j


## Goes on to `to`, answering whatever is met with its first choice.
func _go(j: Journey, to: String, max_days := 200) -> void:
	var guard := 0
	while j.c.band.location != to and guard < max_days * 2 and not j.c.over:
		guard += 1
		if not j.decisions.is_empty():
			j.answer(str(j.current().options[0].id))
			continue
		if not j.moving() and not j.go_to_place(to):
			return
		j.advance(1.0)


func test_the_new_places_exist_with_their_kind_house_and_lore() -> void:
	var w := World.build_norway(WorldRules.new())
	var kinds := {"shetland": WorldTypes.PlaceKind.FARMSTEAD, "hebrides": WorldTypes.PlaceKind.HALL, "skye": WorldTypes.PlaceKind.FARMSTEAD,
			"aldeigjuborg": WorldTypes.PlaceKind.TOWN, "holmgard": WorldTypes.PlaceKind.TOWN, "koenugard": WorldTypes.PlaceKind.TOWN,
			"miklagard": WorldTypes.PlaceKind.TOWN}
	for id in kinds:
		var p := w.place(id)
		assert_true(p != null, "%s is on the map" % id)
		assert_eq(p.kind, kinds[id], "%s's kind" % id)
		assert_true(p.family != "" and w.families.houses.has(p.family), "%s has a house" % id)
		assert_true(EastRoad.about(id).length() > 40, "%s is told of" % id)
	for id in EAST:
		assert_true(w.place(id).has_market and w.place(id).region == WorldTypes.Region.EAST, "%s is a market of the east" % id)
	# The Hebrides are tied into the web: Ketil's daughter is married into
	# Ivar's kin at Dublin; the eastern houses stand apart from the sagas' own.
	var fs := w.families
	assert_true(fs.has_tie("Ketil Flatnose's kin", "Ivar's kin", "marriage"), "Ketil's kin is married into Ivar's")
	assert_true(fs.has_tie("Ketil Flatnose's kin", "the Norse-Gaels of Skye", "grudge"), "and has a grudge against the Gaels of Skye")
	assert_true(fs.house("Ketil Flatnose's kin").western, "Ketil's kin is one of the sagas' houses")
	assert_true(not fs.house("Rurik's kin").western, "Rurik's kin is met only in the east")
	assert_eq(fs.house("Ketil Flatnose's kin").head, "Ketil Flatnose")


func test_every_new_place_can_be_sailed_to_from_norway() -> void:
	var j := _journey("fitjar", WorldTypes.ShipKind.KARVE)
	for id in WEST + EAST:
		assert_true(j.days_to(id) > 0, "a way to %s (%d days)" % [id, j.days_to(id)])
	print("    gate: from Fitjar by karve: Shetland %d, the Hebrides %d, Holmgard %d, Koenugard %d, Miklagard %d days" % [
			j.days_to("shetland"), j.days_to("hebrides"), j.days_to("holmgard"), j.days_to("koenugard"), j.days_to("miklagard")])
	# And the band gets there through Journey itself.
	j.c.world_rules.portage_ambush_day = 0.0
	_go(j, "shetland")
	assert_eq(j.c.band.location, "shetland", "sailed to Shetland")
	var k := _journey("birka", WorldTypes.ShipKind.KARVE)
	k.c.world_rules.portage_ambush_day = 0.0
	_go(k, "koenugard")
	assert_eq(k.c.band.location, "koenugard", "sailed and hauled to Koenugard")


func test_the_portage_costs_what_the_rules_say() -> void:
	var wr := WorldRules.new()
	var g := MapGrid.norway()
	var from: Vector2i = g.place_cell["holmgard"]
	var to: Vector2i = g.place_cell["koenugard"]
	var cells: int = (NorwayData.PORTAGES[0][1] as Array).size()
	var by := {}
	for kind in [WorldTypes.ShipKind.FAERING, WorldTypes.ShipKind.KARVE, WorldTypes.ShipKind.KNARR]:
		var p := g.find_path(from, to, 2.0, float(wr.ship_speed[kind]), true, Vector2i(-1, -1), true, float(wr.portage_haul[kind]))
		assert_true(not (p.cells as Array).is_empty(), "a way for a %s" % WorldTypes.SHIP_NAMES[kind])
		var hauled := 0
		for i in (p.cells as Array).size():
			if g.portage_at(p.cells[i]) >= 0:
				hauled += 1
				assert_true(p.aboard[i], "the ship goes with the band over the haul")
		assert_eq(hauled, cells, "the whole haul, cell by cell")
		by[kind] = p.days
	# The haul alone is cells / pace: a knarr is hauled slower than a karve,
	# a karve slower than a færing, by exactly that.
	var knarr_extra: float = float(cells) / float(wr.portage_haul[WorldTypes.ShipKind.KNARR]) - float(cells) / float(wr.portage_haul[WorldTypes.ShipKind.KARVE])
	assert_true(by[WorldTypes.ShipKind.KNARR] > by[WorldTypes.ShipKind.KARVE] + knarr_extra * 0.8, "knarr %.1f, karve %.1f days" % [by[WorldTypes.ShipKind.KNARR], by[WorldTypes.ShipKind.KARVE]])
	# Without a ship to haul there is no way by water past it.
	var none := g.find_path(from, to, 0.0001, 7.0, true, Vector2i(-1, -1), true, 0.0)
	assert_true((none.cells as Array).is_empty() or none.days > 1000.0, "no way past the haul for a ship that cannot be hauled")
	# In the game: the days at the ropes, the men worn by it.
	var j := _journey("holmgard", WorldTypes.ShipKind.KNARR, 8)
	j.c.world_rules.portage_ambush_day = 0.0
	j.c.world_rules.portage_strain = 0.0
	var loyal := {}
	for m in j.c.band.living_men():
		loyal[m] = m.loyalty
	_go(j, "koenugard")
	assert_eq(j.c.band.location, "koenugard")
	var told := "\n".join(j.said)
	assert_true(told.contains("onto the rollers") and told.contains("in the water again"), "the haul is told")
	var re := RegEx.create_from_string("after the haul to the Dnieper, (\\d+) days at the ropes")
	var m := re.search(told)
	assert_true(m != null, "the days at the ropes are told")
	var days := int(m.get_string(1))
	var want := float(cells) / float(wr.portage_haul[WorldTypes.ShipKind.KNARR])
	assert_between(days, floori(want) - 2, ceili(want) + 1, "a knarr's haul takes cells / pace days")
	for man in j.c.band.living_men():
		if not man.is_leader and loyal.has(man):
			assert_eq(man.loyalty, clampi(int(loyal[man]) - wr.portage_loyalty, 0, 100), "%s curses the road" % man.display_name)


func test_an_ambush_on_the_haul_is_offered_and_a_lost_one_costs_cargo() -> void:
	var j := _journey("holmgard", WorldTypes.ShipKind.KARVE)
	j.roam.parties.clear()
	j.c.world_rules.portage_ambush_day = 1000.0
	j.go_to_place("koenugard")
	var guard := 0
	while j.decisions.is_empty() and guard < 100:
		guard += 1
		j.advance(1.0)
	assert_true(not j.decisions.is_empty(), "the men of the forest come on")
	var d := j.current()
	assert_eq(str(d.kind), "fight")
	assert_true(str(d.text).contains("rollers"), d.text)
	assert_eq(str(d.ctx.kind), "portage")
	assert_true(EastRoad.hauling(j) >= 0, "while hauling")
	# Beaten: half of what she carries is gone.
	j.c.band.cargo = {WorldTypes.Good.FURS: 6, WorldTypes.Good.AMBER: 3}
	EastRoad.after_fight(j, {"kind": "portage"}, null)
	assert_eq(int(j.c.band.cargo[WorldTypes.Good.FURS]), 3)
	assert_eq(int(j.c.band.cargo[WorldTypes.Good.AMBER]), 2)


func test_the_round_trip_is_most_of_a_summer() -> void:
	var wr := WorldRules.new()
	var j := _journey("kaupang", WorldTypes.ShipKind.KNARR)
	var r := j.roam
	var out := {}
	for kind in [WorldTypes.ShipKind.KARVE, WorldTypes.ShipKind.KNARR]:
		var sail := float(wr.ship_speed[kind])
		var haul := float(wr.portage_haul[kind])
		var there := r.place_days("kaupang", "miklagard", 2.0, sail, true, haul)
		var back := r.place_days("miklagard", "kaupang", 2.0, sail, true, haul)
		out[kind] = there + back
		# There and back fits in the summer, with a fortnight to trade, but
		# takes more than half of it: it is the summer's whole venture.
		assert_between(there + back, wr.summer_days * 0.5, wr.summer_days - 14.0,
				"%s, Kaupang to Miklagard and back: %.0f days" % [WorldTypes.SHIP_NAMES[kind], there + back])
	# From Hordaland in a knarr, setting out after midsummer, it does not:
	# he winters abroad.
	var from_west := r.place_days("fitjar", "miklagard", 2.0, 6.0, true, float(wr.portage_haul[WorldTypes.ShipKind.KNARR])) * 2.0
	assert_true(from_west > wr.summer_days - 60, "from Fitjar and back in a knarr: %.0f days" % from_west)
	print("    gate: Kaupang-Miklagard and back: karve %.0f, knarr %.0f days; from Fitjar in a knarr %.0f" % [
			out[WorldTypes.ShipKind.KARVE], out[WorldTypes.ShipKind.KNARR], from_west])


func test_silk_is_dear_at_home_cheap_at_miklagard_and_fair_for_the_road() -> void:
	var wr := WorldRules.new()
	var w := World.build_norway(wr)
	var band := Band.new()
	var mik := w.place("miklagard")
	var kaupang := w.place("kaupang")
	var silk := WorldTypes.Good.SILK
	assert_true(Market.buy_price(wr, mik, band, silk) * 2 <= Market.sell_price(wr, kaupang, band, silk),
			"silk: %d at Miklagard, %d paid at Kaupang" % [Market.buy_price(wr, mik, band, silk), Market.sell_price(wr, kaupang, band, silk)])
	for g in [WorldTypes.Good.FURS, WorldTypes.Good.AMBER, WorldTypes.Good.WALRUS_IVORY]:
		assert_true(Market.sell_price(wr, mik, band, g) > Market.sell_price(wr, kaupang, band, g), "%s fetches more at Miklagard" % WorldTypes.GOOD_NAMES[g])
		assert_true(Market.sell_price(wr, mik, band, g) >= Market.sell_price(wr, w.place("holmgard"), band, g), "and more there than at Holmgard")
	# A hold of silk carried home, against a hold of furs carried from
	# Bjarkøy to Hedeby, each by the ounce a day of the round trip: the far
	# road pays more a voyage but not more a day than twice the near one.
	var j := _journey("kaupang", WorldTypes.ShipKind.KNARR)
	var r := j.roam
	var far_days := r.place_days("kaupang", "miklagard", 2.0, 6.0, true, 0.6) * 2.0
	var near_days := r.place_days("bjarkoy", "hedeby", 2.0, 6.0, true, 0.6) * 2.0
	var far := _carry(wr, w.place("miklagard"), w.place("kaupang"), silk, 10)
	var near := _carry(wr, w.place("bjarkoy"), w.place("hedeby"), WorldTypes.Good.FURS, 10)
	print("    gate: silk home %d oz in %.0f days (%.1f a day); furs to Hedeby %d oz in %.0f days (%.1f a day)" % [
			far, far_days, far / far_days, near, near_days, near / near_days])
	assert_true(far > near, "the far road pays more a voyage")
	assert_true(far / far_days <= 2.0 * near / near_days, "but not more than twice as much a day")
	# Captives fetch most at the far end of the road.
	assert_true(Market.captive_price(wr, mik) > Market.captive_price(wr, w.place("hedeby")))


## Ounces made buying `n` units of `good` at `a` and selling them at `b`,
## on fresh markets, as a stranger.
func _carry(wr: WorldRules, a: Place, b: Place, good: WorldTypes.Good, n: int) -> int:
	var band := Band.new()
	band.silver = 100000
	band.ship = Ship.make(WorldTypes.ShipKind.KNARR)
	var log := PackedStringArray()
	var before := band.silver
	Market.buy(wr, a, band, good, n, log)
	Market.sell(wr, b, band, good, n, log)
	return band.silver - before


func test_a_season_in_the_emperors_guard() -> void:
	var j := _journey("miklagard", WorldTypes.ShipKind.KARVE, 6)
	j.stepped_winter = true
	var band := j.c.band
	var ids := {}
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(ids.has("guard") and bool(ids.guard.get("enabled", true)), "the emperor takes men on")
	var silver := band.silver
	var fame := band.fame
	var pay := EastRoad.guard_pay(j)
	j.act("guard")
	assert_true(j.in_winter(), "the summer is the emperor's, and the winter")
	assert_between(band.silver, silver + pay - j.winter_hall.fee, silver + pay, "paid, less the lodging: %d -> %d" % [silver, band.silver])
	assert_eq(band.fame, fame + j.c.world_rules.guard_fame)
	assert_eq(band.home, "miklagard", "he winters in Miklagard")
	assert_true("\n".join(band.chronicle).contains("emperor's guard"), "the saga tells it")
	# Not where there is no emperor.
	var k := _journey("holmgard", WorldTypes.ShipKind.KARVE, 6)
	for a in k.actions():
		assert_true(str(a.id) != "guard")


func test_the_east_has_its_own_parties_and_tidings() -> void:
	var j := _journey("kaupang", WorldTypes.ShipKind.KARVE)
	j.roam.populate(SimRng.new(5), j.c.world_rules, j.c.world, false)
	var east := 0
	var west := 0
	for p in j.roam.parties:
		if p.road == "east":
			east += 1
			assert_true(not p.route.is_empty(), "%s has somewhere to go" % p.name)
		if p.kind == "raiders" and j.c.world_rules.wider_raider_lairs.has(p.home):
			west += 1
	assert_eq(east, j.c.world_rules.roam_east_merchants, "the Rus merchants are out")
	# No home-waters party is put out at an eastern town.
	for p in j.roam.parties:
		if p.road == "":
			assert_true(not Roam.far_east(j.c.world.place(p.home)) or p.kind == "raiders", "%s keeps to the home waters" % p.name)
	# A tiding of the river road is told on it, not at Kaupang.
	j.roam.news = [{"at": j.roam.clock, "text": "Rus traders fought Pechenegs at the rapids", "pos": Vector2(176, 108)}]
	WorldLife.hear_news(j)
	assert_true(not "\n".join(j.said).contains("Pechenegs at the rapids"), "not told at Kaupang")
	assert_eq(j.roam.news.size(), 1, "kept for the east")


func test_the_road_east_is_heard_of_at_the_great_markets() -> void:
	var j := Journey.begin(3, "younger_son", "Egil")
	assert_true(not j.c.band.knows("birka"))
	EastRoad.arrived(j, j.c.world.place("lade"))
	assert_true(j.c.band.knows("birka"), "Lade's merchants tell of Birka")
	# And from Birka each stop of the road shows the next.
	Knowledge.reveal(j.c.world, j.c.band, "birka", j.said)
	assert_true(j.c.band.knows("aldeigjuborg"))


func test_a_saga_saved_on_the_rollers_goes_on_the_same() -> void:
	var j := _journey("holmgard", WorldTypes.ShipKind.KNARR)
	j.c.world_rules.portage_ambush_day = 0.0
	j.go_to_place("koenugard")
	var guard := 0
	while EastRoad.hauling(j) < 0 and guard < 60:
		guard += 1
		if not j.decisions.is_empty():
			j.answer(str(j.current().options[0].id))
			continue
		j.advance(0.5)
	assert_true(EastRoad.hauling(j) >= 0, "on the rollers")
	j.advance(1.0)
	var errs := PackedStringArray()
	var data := SaveCodec.encode(j, true, errs)
	assert_true(errs.is_empty(), "nothing unsaveable: %s" % ", ".join(errs))
	var k: Journey = SaveCodec.decode(JSON.parse_string(JSON.stringify(data, "", false)))
	assert_eq(SaveCodec.digest(k), SaveCodec.digest(j), "the same at the save")
	assert_true(k.life.has("haul"), "the haul is remembered")
	for x in [j, k]:
		var g2 := 0
		while x.c.band.location != "koenugard" and g2 < 80:
			g2 += 1
			if not x.decisions.is_empty():
				x.answer(str(x.current().options[0].id))
				continue
			x.advance(1.0)
	assert_eq(k.c.band.location, "koenugard")
	assert_eq(SaveCodec.digest(k), SaveCodec.digest(j), "and the same when both are at Koenugard")
