extends TestCase
## The unfree (Thralls): the captives' four fates and what each costs or
## earns in honor and standing; thralls' unrest and what comes of it; a
## man of the band taken by slavers and bought back. See
## docs/design/notes/law-land.md.

const RAIDED := "Augvald's kin"


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


## A band just home from a won raid on Avaldsnes (a hall: a named person
## among the people taken), the captives' decision waiting.
func _after_raid(seed_in := 3) -> Journey:
	var j := _quiet(seed_in, "younger_son", "fitjar")
	j.c.band.captives = 3
	Thralls.after_raid(j, j.c.world.place("avaldsnes"))
	return j


func test_the_captives_decision_and_ransom() -> void:
	var j := _after_raid()
	var band := j.c.band
	var wr := j.c.world_rules
	var d := j.current()
	assert_eq(str(d.kind), "unfree")
	assert_true(str(d.named) != "", "a named person of the house among them")
	assert_true(str(d.text).contains(str(d.named)))
	var ids := {}
	for o in d.options:
		ids[str(o.id)] = o
	assert_true(ids.has("ransom") and ids.has("bound") and ids.has("free"))
	assert_true(not ids.has("thralls"), "no thralls without land to work")
	var silver := band.silver
	var st := Families.standing(band, RAIDED)
	var honor := band.honor
	j.answer("ransom")
	assert_eq(band.silver, silver + 2 * wr.captive_ransom + wr.named_ransom, "more for a named person")
	assert_true(Families.standing(band, RAIDED) > st, "their kin are glad of it")
	assert_eq(band.honor, honor + 1)
	assert_eq(band.captives, 0)


func test_sold_abroad_costs_standing_and_a_named_woman_honor() -> void:
	var j := _after_raid()
	var band := j.c.band
	var wr := j.c.world_rules
	j.answer("bound")
	assert_eq(band.captives, 3, "kept bound for the market")
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["dublin"])
	band.location = "dublin"
	var st := Families.standing(band, RAIDED)
	var honor := band.honor
	var silver := band.silver
	j.act("captives")
	assert_eq(band.captives, 0)
	var dublin := band.silver - silver
	assert_true(dublin > 3 * wr.captive_price, "Dublin pays most: %d oz" % dublin)
	assert_true(Families.standing(band, RAIDED) <= st + 3 * wr.sell_standing + wr.sell_named_standing, "their people sold abroad")
	assert_eq(band.honor, honor - wr.sell_named_honor, "a named freeborn woman sold")


func test_kept_as_thralls_and_freed() -> void:
	var j := _quiet(4, "younger_son", "jaeren")
	var band := j.c.band
	Landtake.add_holding(band, "jaeren", 2, "bought", j.c.cal.year)
	band.captives = 2
	Thralls.after_raid(j, j.c.world.place("avaldsnes"))
	var ids := {}
	for o in j.current().options:
		ids[str(o.id)] = o
	assert_true(ids.has("thralls"), "with land, they can be taken home")
	j.answer("thralls")
	assert_eq(band.thralls.size(), 2, "thralls with names")
	assert_true(str(band.thralls[0].name) != "" and str(band.thralls[0].from) != "")
	assert_eq(Landtake.hands(j.c.world_rules, band), 2, "hands for the land")
	var honor := band.honor
	j.act("manumit")
	assert_eq(band.thralls.size(), 1)
	assert_eq(band.freedmen.size(), 1, "a freedman stays as a tenant")
	assert_eq(band.honor, honor + j.c.world_rules.manumit_honor, "a ring-giver's act")
	# Let go after a raid: honor, and one asks to follow.
	var j2 := _after_raid(5)
	var b2 := j2.c.band
	var n := b2.living_men().size()
	var h2 := b2.honor
	j2.answer("free")
	assert_eq(b2.honor, h2 + mini(3, j2.c.world_rules.free_honor_max))
	assert_eq(b2.living_men().size(), n + 1, "a freedman who remembers it")
	var freed := b2.living_men()[b2.living_men().size() - 1]
	assert_eq(freed.origin, CampaignTypes.Origin.FREEDMAN)
	assert_true(freed.loyalty >= 70)


func test_freedmen_grow_into_a_house() -> void:
	var j := _quiet(4, "younger_son", "jaeren")
	var band := j.c.band
	Landtake.add_holding(band, "jaeren", 2, "bought", j.c.cal.year)
	band.freedmen = [{"name": "Kol", "year": j.c.cal.year - 6}, {"name": "Ketil", "year": j.c.cal.year - 5}]
	Thralls.on_winter(j, j.c.world.place("jaeren"))
	assert_true(j.c.world.families.houses.has("Kol's kin"), "the freedmen are a house")
	assert_true(Families.is_friend(j.c.world_rules, band, "Kol's kin"), "the band's friends")


func test_thrall_unrest_flight_a_killing_and_a_rising() -> void:
	var wr := WorldRules.new()
	# Flight: unrest past the rising mark, let lie.
	var j := _quiet(6, "younger_son", "jaeren")
	var band := j.c.band
	Landtake.add_holding(band, "jaeren", 2, "bought", j.c.cal.year)
	for i in 4:
		band.thralls.append({"name": "t%d" % i, "from": "Ireland", "year": 866})
	band.unrest = wr.unrest_revolt
	var card := Thralls.unrest_card(j)
	assert_eq(str(card.kind), "thralls")
	assert_true(str(card.text).contains("near to rising"))
	Thralls.resolve_unrest(j, card, "let")
	assert_true(band.thralls.size() < 4, "some run")
	# A killing: a hard hand on thralls at the edge.
	var j2 := _quiet(6, "younger_son", "jaeren")
	var b2 := j2.c.band
	b2.add_man(Recruits.random(SimRng.new(1), j2.c.rules, b2.next_id()))
	for i in 3:
		b2.thralls.append({"name": "t%d" % i, "from": "Ireland", "year": 866})
	b2.unrest = wr.unrest_revolt + 1
	var men := b2.living_men().size()
	Thralls.resolve_unrest(j2, Thralls.unrest_card(j2), "press")
	assert_eq(b2.living_men().size(), men - 1, "a man of the band killed in the night")
	assert_eq(b2.thralls.size(), 2, "and the killer gone")
	# Watched, the unrest falls.
	var j3 := _quiet(6, "younger_son", "jaeren")
	j3.c.band.thralls.append({"name": "t", "from": "Ireland", "year": 866})
	j3.c.band.unrest = 5
	Thralls.resolve_unrest(j3, Thralls.unrest_card(j3), "watch")
	assert_eq(j3.c.band.unrest, 3)
	# A rising while the band is away, and the watch too thin.
	var j4 := _quiet(6, "younger_son", "fitjar")
	var b4 := j4.c.band
	Landtake.add_holding(b4, "jaeren", 2, "bought", j4.c.cal.year)
	for i in 5:
		b4.thralls.append({"name": "t%d" % i, "from": "Ireland", "year": 866})
	b4.unrest = 9
	for i in 200:
		Thralls.tick(j4, 1.0)
		if b4.thralls.is_empty():
			break
	assert_true(b4.thralls.is_empty(), "they rise and flee")
	assert_eq(int(Landtake.holding_at(b4, "jaeren").harried), j4.c.cal.year, "the stores burned")
	# The winter's unrest rises with the band away and the thralls unwatched.
	var j5 := _quiet(6, "younger_son", "fitjar")
	var b5 := j5.c.band
	Landtake.add_holding(b5, "jaeren", 2, "bought", j5.c.cal.year)
	for i in 6:
		b5.thralls.append({"name": "t%d" % i, "from": "Ireland", "year": 866})
	Thralls.on_winter(j5, j5.c.world.place("fitjar"))
	var away := b5.unrest
	assert_true(away >= wr.unrest_away, "away and unwatched: %d" % away)
	# No thralls, no unrest drawn in the winter.
	var b6 := Band.new()
	var cr := CampaignRules.new()
	cr.winter_events = {"thrall_unrest": 5}
	assert_eq(WinterEvents.pick_kind(SimRng.new(1), cr, b6), "")
	b6.thralls.append({"name": "t", "from": "x", "year": 866})
	assert_eq(WinterEvents.pick_kind(SimRng.new(1), cr, b6), "thrall_unrest")


func test_a_son_taken_by_slavers_is_bought_back() -> void:
	var j := _quiet(7, "younger_son", "iona")
	var band := j.c.band
	j.c.world_rules.taken_chance = 1.0
	var son := Recruits.random(SimRng.new(2), j.c.rules, band.next_id())
	son.traits.append("son of %s" % band.leader.display_name)
	band.add_man(son)
	var lost := BattleResult.new()
	lost.winner = 1
	Thralls.lost_fight(j, {"kind": "sea"}, lost)
	assert_true(not band.living_men().has(son), "the son is taken")
	assert_eq(band.taken.size(), 1)
	var at := str(band.taken[0].at)
	assert_true(j.c.world_rules.slave_markets.has(at))
	assert_eq(str(j.current().step), "taken")
	j.answer("after")
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	band.location = at
	band.silver = 200
	var ids := {}
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(ids.has("ransom_taken:0") and ids.has("rescue_taken:0"))
	j.act("ransom_taken:0")
	assert_true(band.living_men().has(son), "home again")
	assert_true(band.taken.is_empty())
	# Not in Norway: a fight lost at home takes nobody.
	var j2 := _quiet(7, "younger_son", "fitjar")
	j2.c.world_rules.taken_chance = 1.0
	Thralls.lost_fight(j2, {"kind": "sea"}, lost)
	assert_true(j2.c.band.taken.is_empty())


func test_a_slaver_pays_in_honor_and_standing() -> void:
	# Ten raids' captives sold against ten let go: the silver is the
	# slaver's, the honor and the houses' goodwill the other man's.
	var sold := _quiet(8, "younger_son", "fitjar")
	var freed := _quiet(8, "younger_son", "fitjar")
	for i in 10:
		for j in [sold, freed]:
			j.c.band.captives = 3
			j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["fitjar"])
			j.c.band.location = "fitjar"
			Thralls.after_raid(j, j.c.world.place("avaldsnes"))
			j.answer("bound" if j == sold else "free")
			j.decisions.clear()
		sold.roam.pos = MapGrid.centre(sold.roam.grid.place_cell["dublin"])
		sold.c.band.location = "dublin"
		sold.c.world.place("dublin").captives_sold = 0
		sold.act("captives")
	var bs := sold.c.band
	var bf := freed.c.band
	print("    unfree: slaver silver %d honor %d standing %d; freer silver %d honor %d standing %d" % [
			bs.silver, bs.honor, Families.standing(bs, RAIDED), bf.silver, bf.honor, Families.standing(bf, RAIDED)])
	assert_true(bs.silver > bf.silver)
	assert_true(bs.honor < bf.honor, "the slaver's honor")
	assert_true(Families.standing(bs, RAIDED) < Families.standing(bf, RAIDED) - 50, "the raided house remembers")
