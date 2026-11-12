extends TestCase
## Land of the band's own and the land-taking (Landtake): bought, granted,
## won and claimed land; its yield worked and untended; the farm raided
## while the band is away; the Iceland land-take end to end; men's
## ambitions for land, a wife, a home and vengeance. See
## docs/design/notes/law-land.md.


func _free(j: Journey) -> void:
	var guard := 0
	while not j.decisions.is_empty() and guard < 30:
		guard += 1
		var d := j.current()
		var last: Dictionary = d.options[d.options.size() - 1]
		j.answer(str(last.id))


func _quiet(seed_in: int, origin: String, at: String) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	_free(j)
	j.roam.parties.clear()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	j.c.band.location = at
	return j


func _men(j: Journey, n: int) -> void:
	var band := j.c.band
	while band.living_men().size() < n:
		band.add_man(Recruits.random(SimRng.new(band.next_id() * 7), j.c.rules, band.next_id()))


func test_land_bought_of_a_house_that_will_sell() -> void:
	var j := _quiet(3, "younger_son", "jaeren")
	var band := j.c.band
	var wr := j.c.world_rules
	band.silver = 200
	var ids := {}
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(not ids.has("buy_land"), "a stranger's house will not sell")
	Families.set_standing(band, "Thorir Long-chin's kin", 30)
	ids.clear()
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(ids.has("buy_land"), "a well-wisher will")
	j.act("buy_land")
	var d := j.current()
	assert_eq(str(d.kind), "land")
	assert_true(str(d.detail).contains("hands"), "the yield and the hands in words")
	j.answer("buy:1")
	assert_eq(band.land, 1)
	assert_eq(band.silver, 200 - wr.land_price)
	assert_eq(band.hall_at, "jaeren", "land of his own is his hall site")
	assert_eq(band.holdings.size(), 1)


func test_worked_land_yields_and_untended_land_suffers() -> void:
	var wr := WorldRules.new()
	var b := Band.new()
	Landtake.add_holding(b, "jaeren", 2, "bought", 870)
	b.food = 0
	b.silver = 0
	var log := PackedStringArray()
	Landtake.thaw_yield(wr, b, 870, log)
	var untended_food := b.food
	var untended_silver := b.silver
	var w := Band.new()
	Landtake.add_holding(w, "jaeren", 2, "bought", 870)
	for i in 4:
		w.thralls.append({"name": "thrall %d" % i, "from": "Ireland", "year": 870})
	w.food = 0
	w.silver = 0
	Landtake.thaw_yield(wr, w, 870, log)
	print("    land: 2 units untended %d rations %d oz; worked by 4 thralls %d rations (after their keep) %d oz" % [untended_food, untended_silver, w.food, w.silver])
	assert_eq(w.silver, 2 * wr.land_silver_per_unit, "worked: the full yield")
	assert_eq(w.food, 2 * wr.land_food_per_unit - 4 * wr.thrall_food, "less what the thralls eat")
	assert_true(untended_silver < w.silver and untended_food <= 2 * wr.land_food_per_unit / 2, "an untended farm suffers")
	# Odal after a generation.
	var o := Band.new()
	Landtake.add_holding(o, "jaeren", 2, "bought", 840)
	for i in 4:
		o.freedmen.append({"name": "f%d" % i, "year": 840})
	o.silver = 0
	Landtake.thaw_yield(wr, o, 870, log)
	assert_eq(o.silver, roundi(2 * wr.land_silver_per_unit * (1.0 + wr.odal_bonus)), "odal land yields more")
	# The old sandbox's land, with no holdings, yields as before.
	var ai := Band.new()
	ai.land = 1
	ai.food = 0
	Landtake.thaw_yield(wr, ai, 870, log)
	assert_eq(ai.food, wr.land_food_per_unit)


func test_a_hersir_is_granted_land_with_a_duty() -> void:
	var j := _quiet(4, "younger_son", "lade")
	var band := j.c.band
	FactionAI.shift(j.c.world, "lade", FactionAI.BAND, 80)
	var log := PackedStringArray()
	band.rank_progress = 60
	Sandbox._promote(j.c, log)
	assert_eq(band.rank, WorldTypes.Rank.HERSIR)
	assert_true(band.land >= j.c.world_rules.hersir_grant_units, "a hersir has land")
	assert_eq(str(band.law.liege), "lade")
	j.c.cal.year += 1
	j.decisions.clear()
	Landtake.spring(j)
	var duty := {}
	for d in j.decisions:
		if str(d.get("step", "")) == "duty":
			duty = d
	assert_true(not duty.is_empty(), "the lord calls his hersir")
	var land := band.land
	Landtake.answer(j, duty, "refuse")
	Landtake.answer(j, duty, "refuse")
	assert_eq(band.land, land - j.c.world_rules.hersir_grant_units, "refused twice, the land is taken back")


func test_land_won_at_the_thing() -> void:
	var j := _quiet(3, "younger_son", "gulathing")
	var band := j.c.band
	band.silver = 200
	assert_true(ThingPlay.begin(j, "Thorir Long-chin's kin", "land"))
	j.answer("go")
	j.answer("self")
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	s.slip = false
	s.their_slip = false
	tc.their_supporters = 5
	tc.their_armed = 0
	tc.supporters = 20
	j.decisions.clear()
	j.decisions.push_front(ThingPlay._verdict_decision(j))
	var has := false
	for o in j.current().options:
		has = has or str(o.id) == "land"
	assert_true(has, "land may be asked")
	j.answer("land")
	assert_eq(band.land, j.c.world_rules.claim_units)
	assert_true(not Landtake.holding_at(band, "jaeren").is_empty())


func test_keepers_and_the_farm_raided_while_away() -> void:
	var j := _quiet(5, "younger_son", "jaeren")
	var band := j.c.band
	_men(j, 5)
	Landtake.add_holding(band, "jaeren", 2, "bought", j.c.cal.year)
	band.thralls.append({"name": "Kormlod", "from": "Ireland", "year": j.c.cal.year})
	j.act("keepers")
	assert_eq(str(j.current().step), "keepers")
	var n := band.living_men().size()
	j.answer("keep:1")
	assert_eq(band.keepers.size(), 1)
	assert_eq(band.living_men().size(), n - 1, "a keeper does not fight with the band")
	# Away, the raiders come; one keeper and a thrall will not hold them.
	band.keepers.clear()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["fitjar"])
	band.location = "fitjar"
	j.roam.clock = 10.0
	j.roam.struck["jaeren"] = 10.0
	Landtake.tick(j)
	var h := Landtake.holding_at(band, "jaeren")
	assert_eq(int(h.harried), j.c.cal.year, "harried while the band was away")
	band.food = 0
	band.silver = 0
	band.thralls.clear()
	Landtake.thaw_yield(j.c.world_rules, band, j.c.cal.year, PackedStringArray())
	assert_true(band.silver < 2 * j.c.world_rules.land_silver_per_unit, "the year's yield is the less")
	# Winter at home: the keepers come in.
	var m := Recruits.random(SimRng.new(3), j.c.rules, band.next_id())
	band.keepers.append(m)
	Landtake.on_winter(j, j.c.world.place("jaeren"))
	assert_true(band.keepers.is_empty() and band.living_men().has(m))


func test_iceland_is_no_raid_and_the_spine_offers_the_way() -> void:
	var j := _quiet(3, "younger_son", "fitjar")
	assert_true(not Landtake.raidable(j, j.c.world.place("iceland")))
	var wr := WorldRules.new()
	var w := World.build_norway(wr, 874)
	Faction.load_all(w)
	var due := Timeline.pending(wr, w, 874)
	var ice := {}
	for e in due:
		if str(e.id) == "iceland_opens":
			ice = e
	assert_true(Timeline.outcome_options(ice).has("sail_iceland"), "the Iceland event has real choices")
	assert_true(Timeline.outcome_options(ice).has("send_settlers"))


func test_the_iceland_land_take_end_to_end() -> void:
	var j := _quiet(7, "younger_son", "orkney")
	var band := j.c.band
	var wr := j.c.world_rules
	j.c.cal.year = 876
	j.c.world.year = 876
	band.year = 876
	_men(j, 5)
	for m in band.living_men():
		m.ambition = CampaignTypes.Ambition.LAND
	band.ship = Ship.make(WorldTypes.ShipKind.KNARR)
	j.roam.aboard = true
	band.known_places["iceland"] = true
	Outlawry.declare(wr, band, j.c.cal, true, j.said)
	j.c.world_rules.storm_chance_day = 0.0
	j.c.world_rules.wreck_chance_deep_day = 0.0
	assert_true(j.sail("iceland"), "a knarr crosses the open sea")
	var ids := {}
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(ids.has("landtake") and ids.landtake.enabled, "take land in Iceland")
	assert_true(not ids.has("raid"), "Iceland is not raided")
	j.act("landtake")
	var d := j.current()
	assert_eq(str(d.step), "iceland")
	assert_true(str(d.detail).contains("Might"), "the fire's reach in words")
	j.answer("fire")
	d = j.current()
	assert_eq(str(d.step), "iceland_name")
	var name := str(d.options[0].label)
	j.answer(str(d.options[0].id))
	assert_true(band.settled_iceland, "the flag the endings read")
	assert_eq(band.home, "iceland")
	assert_eq(band.hall_at, "iceland")
	assert_eq(str(Landtake.holding_at(band, "iceland").name), name, "the land has the name he gave it")
	assert_true(band.land >= 2)
	assert_eq(band.outlawry, WorldTypes.Outlawry.NONE, "Norway's outlawry does not reach Iceland")
	for m in band.living_men():
		assert_true(m.ambition_met, "%s has the land he wanted" % m.display_name)
	ids.clear()
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(not ids.has("landtake"), "once")


func test_iceland_grows_with_its_settlers() -> void:
	var c := Campaign.new(3)
	Sandbox.setup(c, WorldRules.new(), "fitjar")
	c.cal.year = 885
	c.world.year = 885
	var wealth := c.world.place("iceland").wealth
	Landtake.year_end(c)
	for name in ["Ketilbjorn's kin", "Skallagrim's kin", "Thorolf Mostur-beard's kin"]:
		assert_true(c.world.families.houses.has(name), name + " come out to Iceland")
	assert_true(not c.world.families.houses.has("Aud the Deep-minded's kin"), "not before her year")
	assert_true(c.world.place("iceland").wealth > wealth)
	assert_eq(c.world.families.house("Skallagrim's kin").seat, "iceland")


func test_ambitions_for_land_wife_home_and_vengeance_move() -> void:
	var j := _quiet(8, "younger_son", "jaeren")
	var band := j.c.band
	_men(j, 4)
	var kinds := [CampaignTypes.Ambition.LAND, CampaignTypes.Ambition.WIFE, CampaignTypes.Ambition.HOME, CampaignTypes.Ambition.VENGEANCE]
	var men := band.living_men()
	for i in 4:
		men[i].ambition = kinds[i]
		men[i].ambition_progress = 0
		men[i].ambition_met = false
	Landtake.grant(j, "jaeren", 1, "bought")
	assert_true(men[0].ambition_progress > 0, "land")
	band.wife = ""
	j.c.world.families.marry_into(j.c.world_rules, j.c.rules, SimRng.new(1), band, "Thorir Long-chin's kin", "Thora", j.said)
	assert_true(men[1].ambition_progress > 0, "a wife")
	Landtake.on_winter(j, j.c.world.place("jaeren"))
	assert_true(men[2].ambition_progress > 0, "a home")
	Feud.start(j.c.world_rules, band, "Augvald's kin", "a killing", "avaldsnes", j.said)
	Landtake.watch(j)
	Feud.find(band, "Augvald's kin")["settled"] = true
	Landtake.watch(j)
	assert_true(men[3].ambition_progress > 0, "vengeance")


func test_claiming_an_empty_steading_after_the_reckoning() -> void:
	var j := _quiet(9, "younger_son", "jaeren")
	var band := j.c.band
	var r := BattleResult.new()
	r.winner = 0
	Landtake.after_fight(j, {"kind": "reckoning", "family": "Thorir Long-chin's kin"}, r)
	var ids := {}
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(ids.has("claim_land"))
	var st := Families.standing(band, "Thorir Long-chin's kin")
	j.act("claim_land")
	assert_eq(band.land, j.c.world_rules.claim_units)
	assert_true(Families.standing(band, "Thorir Long-chin's kin") < st, "their kin do not like it")
