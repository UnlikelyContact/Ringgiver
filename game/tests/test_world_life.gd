extends TestCase
## The summer world alive (WorldLife, Roam's parties, Hiring, the ground a
## fight is fought on, the vengeance's long arc). See
## docs/design/notes/world-life.md.


func _free(j: Journey) -> void:
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		var d := j.current()
		var last: Dictionary = d.options[d.options.size() - 1]
		j.answer(str(last.id))


## A journey with the map cleared of everyone, the band at `at`.
func _quiet(seed_in: int, origin: String, at: String) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	_free(j)
	j.roam.parties.clear()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	j.c.band.location = at
	return j


func _party(j: Journey, kind: String, men: int, at: Vector2, family := "") -> Roam.Party:
	var p := Roam.Party.new()
	p.kind = kind
	p.name = kind
	p.men = men
	p.pos = at
	p.family = family
	p.speed = 6.0
	if kind == "merchant":
		p.offer = {"good": WorldTypes.Good.FURS, "units": 6, "price": 3, "home": "kaupang", "family": ""}
		p.name = "a knarr out of Kaupang"
	j.roam.parties.append(p)
	return p


## Lets the world's days pass with the band standing still and nothing to
## answer in the way.
func _days(j: Journey, days: float) -> void:
	var t := 0.0
	while t < days:
		j.roam.clock += 0.25
		j.roam.life_clock = minf(j.roam.life_clock, j.roam.clock - j.c.world_rules.life_tick_days)
		WorldLife.tick(j, 0.25)
		j.roam.step_parties(0.25, j._fork("t"), j.c.world_rules, j.c.world, j.c.band.fighters().size(), j.c.band.location)
		t += 0.25


func test_raiders_fall_on_a_merchant_and_leave_a_wreck_and_tidings() -> void:
	var j := _quiet(1, "younger_son", "hardanger")
	var far := MapGrid.centre(j.roam.grid.place_cell["lade"])
	var m := _party(j, "merchant", 4, far + Vector2(0.5, 0))
	var r := _party(j, "raiders", 9, far + Vector2(1.0, 0), "Augvald's kin")
	r.speed = 7.5
	_days(j, 4.0)
	var wrecks := 0
	for p in j.roam.parties:
		if p.kind == "wreck":
			wrecks += 1
	assert_true(wrecks >= 1, "where they fought, something is left")
	assert_true(not j.roam.parties.has(m) or m.offer.is_empty() or r.men < 9, "the merchant was taken or the raiders bloodied")
	assert_true(not j.roam.news.is_empty(), "the tidings wait to be told at a hall")
	# Told at the next hall.
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["fitjar"])
	j.c.band.location = "fitjar"
	var said := j.said.size()
	WorldLife.hear_news(j)
	assert_true(j.said.size() > said and j.said[j.said.size() - 1].begins_with("At Fitjar they tell that"), "heard at Fitjar")


func test_the_kings_ships_hunt_raiders() -> void:
	var j := _quiet(2, "younger_son", "hardanger")
	var far := MapGrid.centre(j.roam.grid.place_cell["giske"]) + Vector2(-2, 0)
	var k := _party(j, "kings_ships", 14, far)
	k.tier = CombatTypes.Tier.VETERAN
	var r := _party(j, "raiders", 4, far + Vector2(0.8, 0), "")
	_days(j, 5.0)
	assert_true(not j.roam.parties.has(r) or r.men < 4, "the raiders are caught")
	assert_true(j.c.tally.get("world_clashes", 0) >= 1)


func test_raiders_plunder_a_farm_and_it_is_poorer() -> void:
	var j := _quiet(3, "younger_son", "hardanger")
	var wr := j.c.world_rules
	var farm := j.c.world.place("jaeren")
	var before := farm.wealth
	var r := _party(j, "raiders", 10, MapGrid.centre(j.roam.grid.place_cell["jaeren"]), "Augvald's kin")
	r.strike = "jaeren"
	r.tier = CombatTypes.Tier.VETERAN
	_days(j, wr.place_raid_days + 1.0)
	assert_true(farm.wealth < before, "plundered: %d -> %d oz" % [before, farm.wealth])
	assert_true(r.loot > 0, "and the raiders carry it")
	assert_true(j.roam.struck.has("jaeren"), "not struck again for a while")


func test_a_band_at_a_farm_is_asked_to_stand_with_the_farmers() -> void:
	var j := _quiet(4, "younger_son", "hardanger")
	j.quick = true
	var band := j.c.band
	for i in 6:
		band.add_man(Recruits.random(j._fork("m%d" % i), j.c.rules, band.next_id()))
	j.c._arm_new_men()
	var r := _party(j, "raiders", 4, MapGrid.centre(j.roam.grid.place_cell["hardanger"]), "Augvald's kin")
	r.strike = "hardanger"
	j.roam.clock = 1.0
	WorldLife.tick(j, 1.0)
	assert_eq(str(j.current().get("what", "")), "defend", "the raid is the band's to answer")
	var standing := Families.standing(band, "Hardanger-Atli's kin")
	var silver := band.silver
	j.answer("defend")
	assert_eq(str(j.current().get("kind", "")), "fight", "standing with them is a fight")
	var offer: FightOffer = j.current().offer
	assert_eq(offer.ground, "farm", "fought at the steading")
	assert_true(offer.allows(FightOffer.Choice.WAIT_FOR_THEM) and offer.title(FightOffer.Choice.WAIT_FOR_THEM) == "Hold the hall", "the hall to hold")
	j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
	if j.c.tally.wins > 0:
		assert_true(Families.standing(band, "Hardanger-Atli's kin") > standing, "the house thinks the better of him")
		assert_true(band.silver > silver, "and the farmers pay")
		assert_true(not j.roam.parties.has(r), "the raiders are gone")


func test_coming_upon_a_fight_a_side_can_be_taken() -> void:
	var j := _quiet(5, "younger_son", "hardanger")
	j.quick = true
	var band := j.c.band
	for i in 7:
		band.add_man(Recruits.random(j._fork("m%d" % i), j.c.rules, band.next_id()))
	j.c._arm_new_men()
	var at := j.roam.pos
	var m := _party(j, "merchant", 4, at + Vector2(0.3, 0))
	var r := _party(j, "raiders", 6, at + Vector2(0.4, 0))
	m.engaged = r
	r.engaged = m
	m.fray_until = 99.0
	r.fray_until = 99.0
	band.location = ""
	var met := j.roam.step_parties(0.1, j._fork("x"), j.c.world_rules, j.c.world, band.fighters().size(), "")
	assert_true(met == m or met == r, "the band comes upon them")
	j._meet(met)
	var d := j.current()
	assert_eq(str(d.get("what", "")), "fray")
	assert_eq((d.options as Array).size(), 3, "help one, help the other, or keep out")
	var help := "a" if d.party == m else "b"
	j.answer(help)
	assert_eq(str(j.current().get("kind", "")), "fight", "taking a side is a fight with the other")
	var offer: FightOffer = j.current().offer
	assert_true(offer.enemy_size < r.men, "the merchant's men hold some of them")
	var silver := band.silver
	j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
	if j.c.tally.wins > 0:
		assert_true(band.silver > silver, "the merchant pays for his life")
		assert_true(m.engaged == null, "and goes on his way")


func test_the_kings_ships_ask_for_passage_money() -> void:
	var j := _quiet(6, "younger_son", "fitjar")
	var band := j.c.band
	band.silver = 50
	var k := _party(j, "kings_ships", 12, j.roam.pos)
	k.faction = "harald"
	assert_true(WorldLife.meet(j, k))
	var d := j.current()
	assert_eq(str(d.what), "toll")
	j.answer("pay")
	assert_eq(band.silver, 50 - int(d.toll), "the king's due is paid")
	assert_eq(k.mood, 1, "and they do not ask again this summer")


func test_a_ship_left_on_a_hostile_beach_is_taken_and_can_be_taken_back() -> void:
	var j := _quiet(7, "younger_son", "avaldsnes")
	j.quick = true
	var band := j.c.band
	for i in 6:
		band.add_man(Recruits.random(j._fork("m%d" % i), j.c.rules, band.next_id()))
	j.c._arm_new_men()
	band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	Families.set_standing(band, "Augvald's kin", -50)
	j.roam.ship_at = MapGrid.centre(j.roam.grid.place_cell["avaldsnes"])
	j.roam.aboard = false
	j.roam.pos = j.roam.ship_at + Vector2(4, 0)
	band.location = ""
	var guard := 0
	while band.ship != null and guard < 400:
		guard += 1
		j.roam.clock += 0.5
		WorldLife._theft(j, j._fork("theft"), 0.5)
	assert_true(band.ship == null, "unwatched on an ill-wisher's beach, she is taken")
	var stolen: Dictionary = j.life.get("stolen", {})
	assert_true(not stolen.is_empty(), "and the thieves have her")
	assert_true(not Feud.find(band, "Augvald's kin").is_empty(), "it is between him and them now")
	var t: Roam.Party = stolen.party
	j.roam.pos = t.pos
	assert_true(WorldLife.meet(j, t))
	assert_eq(str(j.current().what), "thieves")
	j.answer("fight")
	assert_eq(str(j.current().kind), "fight")
	j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
	if j.c.tally.wins > 0:
		assert_true(band.ship != null, "won back")


func test_a_watched_ship_is_safe() -> void:
	var j := _quiet(8, "younger_son", "avaldsnes")
	var band := j.c.band
	band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	band.silver = 20
	j.roam.aboard = true
	Families.set_standing(band, "Augvald's kin", -10)
	var ids := {}
	for a in j.actions():
		ids[a.id] = a
	assert_true(ids.has("watch"), "a watch can be paid for")
	j.act("watch")
	assert_eq(band.silver, 20 - j.c.world_rules.ship_watch_ounces)
	j.roam.ship_at = j.roam.pos
	j.roam.aboard = false
	j.roam.pos += Vector2(5, 0)
	for i in 200:
		WorldLife._theft(j, j._fork("theft"), 0.5)
	assert_true(band.ship != null, "nobody takes a watched ship")


func test_houses_at_feud_send_men_and_their_clash_is_a_killing() -> void:
	var j := _quiet(9, "younger_son", "hardanger")
	var fs := j.c.world.families
	var pr := fs.pair("Augvald's kin", "Rognvald's kin")
	assert_eq(str(pr.enmity), "feud", "the old feud of the web")
	var kills := int(pr.ledger.kills["Augvald's kin"]) + int(pr.ledger.kills["Rognvald's kin"])
	var at := MapGrid.centre(j.roam.grid.place_cell["giske"]) + Vector2(-3, 0)
	var a := _party(j, "house_men", 6, at, "Augvald's kin")
	a.tier = CombatTypes.Tier.BLOODED
	var b := _party(j, "house_men", 6, at + Vector2(1.5, 0), "Rognvald's kin")
	b.tier = CombatTypes.Tier.BLOODED
	_days(j, 4.0)
	var after := int(pr.ledger.kills["Augvald's kin"]) + int(pr.ledger.kills["Rognvald's kin"])
	assert_eq(after, kills + 1, "a killing on the ledger")
	# And in spring the houses at feud send their men out.
	var j2 := Journey.begin(10, "younger_son", "Egil")
	var houses := 0
	for p in j2.roam.parties:
		if p.kind == "house_men":
			houses += 1
	assert_true(houses <= j2.c.world_rules.house_parties_max)


func test_men_for_hire_and_their_wages() -> void:
	var j := _quiet(11, "younger_son", "fitjar")
	var band := j.c.band
	band.silver = 200
	var men := j.men_for_hire()
	assert_eq(men.size(), j.c.world_rules.hire_offers, "a hall has men looking for a lord")
	for o in men:
		assert_true(str(o.name) != "" and str(o.text) != "" and int(o.price) > 0)
	var before := band.living_men().size()
	j.act("hire:0")
	assert_eq(band.living_men().size(), before + 1, "taken into the band")
	var m: Man = band.living_men()[band.living_men().size() - 1]
	assert_true(m.wage > 0, "a hired man takes a wage")
	assert_eq(j.men_for_hire().size(), men.size() - 1, "and is not for hire twice")
	# A month unpaid, and another.
	band.silver = 0
	var loyalty := m.loyalty
	j.roam.clock += j.c.world_rules.wage_days + 0.1
	Hiring.reckon(j)
	assert_true(m.loyalty < loyalty, "pay short, heart shorter")
	m.loyalty = 0
	Hiring.reckon(j)
	assert_true(not band.living_men().has(m), "he takes his leave at a place")


func test_lent_men_go_home_at_the_summers_end() -> void:
	var j := _quiet(12, "burned_hall", "sogn_farms")
	var band := j.c.band
	var m := Recruits.random(j._fork("lent"), j.c.rules, band.next_id())
	m.lent_by = "Ulfar's kin"
	band.add_man(m)
	Hiring.end_of_summer(j)
	assert_true(not band.living_men().has(m), "home for the winter")


func test_captives_ransomed_or_freed() -> void:
	var j := _quiet(13, "younger_son", "fitjar")
	var band := j.c.band
	band.captives = 3
	var silver := band.silver
	j.act("ransom")
	assert_eq(band.silver, silver + 3 * j.c.world_rules.captive_ransom)
	band.captives = 2
	var honor := band.honor
	j.act("free")
	assert_eq(band.captives, 0)
	assert_true(band.honor > honor)


func test_the_ground_decides_the_choices_and_the_field() -> void:
	var c := Campaign.new(5)
	c.start_from("younger_son", "Egil")
	for i in 6:
		c.band.add_man(Recruits.random(c.rng.fork("m%d" % i), c.rules, c.band.next_id()))
	c._arm_new_men()
	var strand := c.offer_fight("x", CombatTypes.Tier.GREEN, 6, false, 3, false, false, "strand")
	assert_true(not strand.allows(FightOffer.Choice.WAIT_FOR_THEM), "open sand: no ground to choose")
	assert_true(not strand.allows(FightOffer.Choice.LAY_AMBUSH), "and nowhere to hide")
	var hills := c.offer_fight("x", CombatTypes.Tier.GREEN, 6, false, 3, false, false, "hills")
	assert_true(hills.allows(FightOffer.Choice.WAIT_FOR_THEM))
	assert_eq(hills.title(FightOffer.Choice.WAIT_FOR_THEM), "Hold the high ground")
	var built := c.build_fight(hills, FightOffer.Choice.WAIT_FOR_THEM)
	assert_eq(str(built.field_name), "hillside")
	assert_eq((built.field as Field).high_side, 0, "your line on the slope")
	var farm := c.offer_fight("x", CombatTypes.Tier.GREEN, 6, false, 3, false, false, "farm")
	var at_farm := c.build_fight(farm, FightOffer.Choice.WAIT_FOR_THEM)
	assert_eq((at_farm.objective as Objective).kind, Objective.Kind.THE_HALL, "the hall to hold")
	var sea := c.offer_fight("x", CombatTypes.Tier.GREEN, 6, false, 3, true, false, "sea")
	var on_deck := c.build_fight(sea, FightOffer.Choice.TAKE_THE_FIELD)
	# Both afloat: the hulls lashed together (saga-fights.md; it was the
	# strand by the ships before the deck was built).
	assert_eq((on_deck.objective as Objective).kind, Objective.Kind.DECK, "fought out on the decks")
	assert_eq(str(on_deck.field_name), "deck")
	assert_true(sea.brief().contains("aboard"))


func test_the_journey_reads_the_ground_under_the_band() -> void:
	var j := _quiet(14, "younger_son", "hardanger")
	assert_eq(j.ground_here(), "farm", "at a steading")
	j.c.band.location = ""
	var grid := j.roam.grid
	var found := {}
	for y in range(0, MapGrid.H, 3):
		for x in range(0, MapGrid.W, 3):
			var cell := MapGrid.ORIGIN + Vector2i(x, y)
			if not MapGrid.inside(cell) or grid.cell_place.has(MapGrid.index(cell)):
				continue
			j.roam.pos = MapGrid.centre(cell)
			found[j.ground_here()] = true
	for g in ["sea", "strand", "hills", "open"]:
		assert_true(found.has(g), "the map has %s ground" % g)


func test_the_burners_answer_only_to_a_band_with_backing() -> void:
	var j := _quiet(15, "burned_hall", "sogn_farms")
	var fs := j.c.world.families
	var wr := j.c.world_rules
	var band := j.c.band
	var name := band.vengeance
	assert_eq(name, "Hardanger-Atli's kin")
	var t := fs.reckoning_terms(wr, band, name)
	assert_true((t.allies as Array).size() >= 2, "Møre by marriage and Jæren by friendship stand with them")
	var vb := fs.vengeance_backing(wr, band, name, band.fighters().size())
	assert_true(not bool(vb.ready), "two men and ten ounces are no match for them: %d against %d" % [int(vb.ours), int(vb.theirs)])
	# No wergild is offered for the burning while they are the stronger.
	j.c.cal.year += 1
	for k in 10:
		for d in fs.asks(j._fork("asks"), wr, j.c.world, band, j.c.cal.year):
			assert_true(not (str(d.ask) == "compensation" and str(d.house) == name), "no wergild offered yet")
		(Feud.find(band, name) as Dictionary).erase("offered")
	# Friends among their enemies, and men: now they will answer.
	for e in fs.enemies_of(name):
		Families.set_standing(band, e, 70)
	for a in t.allies:
		for e in fs.enemies_of(str(a)):
			if e != name:
				Families.set_standing(band, e, 70)
	for i in 12:
		band.add_man(Recruits.random(j._fork("m%d" % i), j.c.rules, band.next_id()))
	vb = fs.vengeance_backing(wr, band, name, band.fighters().size())
	assert_true(bool(vb.ready), "with friends and men: %d against %d" % [int(vb.ours), int(vb.theirs)])
	var offered := false
	for k in 20:
		for d in fs.asks(j._fork("asks2"), wr, j.c.world, band, j.c.cal.year + k):
			if str(d.ask) == "compensation" and str(d.house) == name:
				offered = true
				assert_true(int(d.ounces) > roundi(Feud.wergild(wr, WorldTypes.Rank.HERSIR) * wr.compensation_share), "they pay dearly")
	assert_true(offered, "and the burners offer wergild")


func test_houses_abroad_neither_marry_nor_are_reckoned_with() -> void:
	var j := _quiet(16, "younger_son", "hardanger")
	var fs := j.c.world.families
	assert_true(fs.abroad("the monks of Iona"))
	assert_true(not fs.abroad("Horda-Kari's kin"))
	var band := j.c.band
	Families.set_standing(band, "the monks of Iona", 60)
	band.known_places["iona"] = true
	for k in 20:
		for d in fs.asks(j._fork("asks"), j.c.world_rules, j.c.world, band, 866 + k):
			assert_true(not (str(d.house) == "the monks of Iona" and (str(d.ask) == "marry" or str(d.ask) == "foster")), "the monks offer no daughter")
	for h in j.c.rules.marriage_houses:
		assert_true(fs.houses.has(str(h)) and not fs.abroad(str(h)), "%s is a house of the web" % h)


func test_the_world_is_the_same_from_the_same_seed() -> void:
	var told: Array[String] = []
	for k in 2:
		var j := Journey.begin(17, "younger_son", "Egil")
		JourneyBot.play_year(j, Way.Id.VIKING)
		told.append("\n".join(j.said))
	assert_eq(told[0], told[1], "a summer of the world's own life, twice")


## The party step runs every frame of travel on a phone: it must stay cheap.
func test_the_party_step_is_cheap() -> void:
	var j := Journey.begin(18, "younger_son", "Egil")
	_free(j)
	var n := 0
	var step_us := 0
	var life_us := 0
	var worst := 0
	for i in 400:
		j.roam.clock += 0.2
		var t0 := Time.get_ticks_usec()
		j.roam.step_parties(0.2, j._fork("perf"), j.c.world_rules, j.c.world, j.c.band.fighters().size(), "")
		var t1 := Time.get_ticks_usec()
		WorldLife.tick(j, 0.2)
		var t2 := Time.get_ticks_usec()
		step_us += t1 - t0
		life_us += t2 - t1
		worst = maxi(worst, t2 - t0)
		n += 1
		j.decisions.clear()
	var each := float(step_us + life_us) / n
	print("    gate: %d parties; Roam.step_parties %.0f us a step, WorldLife.tick %.0f us a step (reckoned every %.1f days), worst step %d us" % [
			j.roam.parties.size(), float(step_us) / n, float(life_us) / n, j.c.world_rules.life_tick_days, worst])
	assert_true(each < 5000.0, "%.0f us a step" % each)
