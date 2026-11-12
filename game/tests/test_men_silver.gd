extends TestCase
## Men and silver (docs/design/notes/men-silver.md): the leader's nature
## and what each trait does, a son's share of it; the smith and his stock,
## arms for a man or the chest, the sword with a name; gifts in summer;
## the works (benches, the hall's adornment, feasts, stones, a skald, the
## ship fitted, the boathouse); the shieldmaidens and the saga's words for
## them; the stand-in player's spending; and the save.


func _free(j: Journey) -> void:
	var guard := 0
	while not j.decisions.is_empty() and guard < 30:
		guard += 1
		var d := j.current()
		var last: Dictionary = d.options[d.options.size() - 1]
		j.answer(str(last.id))


func _at(seed_in: int, origin: String, at: String) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	_free(j)
	j.roam.parties.clear()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	j.c.band.location = at
	j.c.band.known_places[at] = true
	return j


func _men(j: Journey, n: int) -> void:
	var band := j.c.band
	while band.living_men().size() < n:
		band.add_man(Recruits.random(SimRng.new(band.next_id() * 7), j.c.rules, band.next_id()))


func _home(j: Journey) -> void:
	var band := j.c.band
	band.hall_at = band.location
	band.home = band.location
	Hall.ensure(band, j.c.rules)


# --- The leader's nature -------------------------------------------------------------------

func test_a_nature_is_two_traits_of_different_pairs_once() -> void:
	var j := Journey.begin(1, "younger_son", "Egil")
	assert_eq(j.nature_choices().size(), 8, "eight traits in four pairs")
	assert_true(not j.choose_nature(PackedStringArray(["reckless", "steady"])), "not two of one pair")
	assert_true(not j.choose_nature(PackedStringArray(["reckless"])), "not one alone")
	assert_true(j.choose_nature(PackedStringArray(["reckless", "grim"])), "two of different pairs")
	assert_eq(j.c.band.leader.natures, PackedStringArray(["reckless", "grim"]))
	assert_true(not j.choose_nature(PackedStringArray(["steady", "open_handed"])), "chosen once")
	assert_true(j.nature_choices().is_empty(), "nothing more to choose")
	for k in Natures.keys():
		assert_true(Natures.line(j.c.rules, k).length() > 20, "every trait says what it does: " + k)


func test_a_nature_moves_growth_and_lays_edges() -> void:
	var j := Journey.begin(2, "younger_son", "Egil")
	var rules := j.c.rules
	var lead := j.c.band.leader
	var before := Growth.nature_multiplier(rules, lead, CombatTypes.Stat.WITS)
	j.choose_nature(PackedStringArray(["silver_tongued", "quick_to_anger"]))
	assert_true(Growth.nature_multiplier(rules, lead, CombatTypes.Stat.WITS) > before, "wits grows quicker in a silver tongue")
	var nerve := Natures.multiplier(rules, lead, CombatTypes.Stat.NERVE)
	assert_true(nerve < 1.0, "quick to anger: nerve grows slower (%.2f)" % nerve)
	assert_eq(int(j.c.band.gift("law", 0)), 1, "one better at counsel and the Thing")
	assert_eq(int(j.c.band.gift("verse", 0)), 1, "one better at verse")
	# The edges survive a step down a way (Way.refresh rebuilds them).
	Way.add_deed(j.c.band, Way.Id.LAWMAN, 6)
	j.invest(Way.Id.LAWMAN)
	assert_eq(int(j.c.band.gift("law", 0)), 2, "the way's and the nature's together")
	var p := j.c.world.place("fitjar")
	var plain := roundi(j.c.world_rules.holmgang_honor * 0.5)
	assert_eq(int(Callings.holmgang_terms(j.c.world_rules, j.c.world, j.c.band, p).honor_cost), plain, "half the honor for a challenge")


func test_open_hand_and_closed_fist_are_true() -> void:
	var a := Journey.begin(3, "younger_son", "Egil")
	var b := Journey.begin(3, "younger_son", "Egil")
	a.choose_nature(PackedStringArray(["open_handed", "grim"]))
	b.choose_nature(PackedStringArray(["close_fisted", "grim"]))
	_men(a, 3)
	_men(b, 3)
	var ma := a.c.band.living_men()[0]
	var mb := b.c.band.living_men()[0]
	ma.loyalty = 40
	mb.loyalty = 40
	var log := PackedStringArray()
	Loyalty.gift(a.c.rules, a.c.band, ma, 3, log)
	Loyalty.gift(b.c.rules, b.c.band, mb, 3, log)
	assert_true(ma.loyalty - 40 > mb.loyalty - 40, "the open hand binds more: %d against %d" % [ma.loyalty - 40, mb.loyalty - 40])
	# The closed fist keeps more of the plunder and nobody grumbles.
	var plain := Journey.begin(3, "younger_son", "Egil")
	_men(plain, 3)
	plain.c.band.silver = 0
	b.c.band.silver = 0
	var lb := mb.loyalty
	Loyalty.share_plunder(plain.c.rules, plain.c.band, 100, plain.c.rules.fair_leader_share, log)
	Loyalty.share_plunder(b.c.rules, b.c.band, 100, b.c.rules.fair_leader_share, log)
	assert_true(b.c.band.silver > plain.c.band.silver, "he keeps more: %d against %d" % [b.c.band.silver, plain.c.band.silver])
	assert_true(mb.loyalty > lb, "and the men think it fair")


func test_steady_draws_off_without_shame_and_deep_minded_keeps_luck() -> void:
	var j := Journey.begin(4, "younger_son", "Egil")
	j.choose_nature(PackedStringArray(["steady", "deep_minded"]))
	var band := j.c.band
	var honor := band.honor
	Leader.on_battle(j.c.rules, band, false, true, 1.0, PackedStringArray(), BattleResult.Outcome.WITHDREW)
	assert_eq(band.honor, honor, "drawing off costs a steady man no honor")
	band.luck = j.c.rules.luck_drift_high + 1
	Leader.winter_drift(j.c.rules, band, PackedStringArray())
	assert_eq(band.luck, j.c.rules.luck_drift_high + 1, "a deep mind's luck does not fade from there")
	var k := Journey.begin(4, "younger_son", "Egil")
	k.c.band.luck = k.c.rules.luck_drift_high + 1
	Leader.winter_drift(k.c.rules, k.c.band, PackedStringArray())
	assert_eq(k.c.band.luck, k.c.rules.luck_drift_high, "another's does")


func test_reckless_wins_more_fame_against_the_odds() -> void:
	var a := Journey.begin(5, "younger_son", "Egil")
	var b := Journey.begin(5, "younger_son", "Egil")
	a.choose_nature(PackedStringArray(["reckless", "grim"]))
	var fa := a.c.band.fame
	var fb := b.c.band.fame
	Leader.on_battle(a.c.rules, a.c.band, true, true, 0.5, PackedStringArray(), BattleResult.Outcome.ROUTED_THEM)
	Leader.on_battle(b.c.rules, b.c.band, true, true, 0.5, PackedStringArray(), BattleResult.Outcome.ROUTED_THEM)
	assert_eq(a.c.band.fame - fa, b.c.band.fame - fb + 2, "two more fame")


func test_a_son_inherits_a_mix() -> void:
	var rules := CampaignRules.new()
	var father := Man.new()
	father.display_name = "Egil"
	father.natures = PackedStringArray(["reckless", "open_handed"])
	var kept := 0
	for i in 40:
		var son := Recruits.son_of(SimRng.new(100 + i), rules, father, [5, 5, 5, 5, 5], "Thorstein", 10 + i)
		assert_true(Natures.valid(son.natures), "a whole nature: %s" % ", ".join(son.natures))
		for k in son.natures:
			if father.natures.has(k):
				kept += 1
	assert_between(kept, 20, 70, "about half his father's traits")
	var none := Man.new()
	assert_true(Recruits.son_of(SimRng.new(1), rules, none, [5, 5, 5, 5, 5], "Ulf", 99).natures.is_empty(), "no nature from a father without one")


# --- The smith -----------------------------------------------------------------------------

func test_smiths_where_they_should_be() -> void:
	var j := _at(6, "younger_son", "kaupang")
	assert_eq(Estate.smith_kind(j, j.c.world.place("kaupang")), "great")
	assert_eq(Estate.smith_kind(j, j.c.world.place("hedeby")), "great")
	assert_eq(Estate.smith_kind(j, j.c.world.place("ribe")), "plain", "a market town")
	assert_eq(Estate.smith_kind(j, j.c.world.place("hardanger")), "", "a farm has none")
	var acts := {}
	for a in j.actions():
		acts[a.id] = a
	assert_true(acts.has("smith"), "the smith is on the place's list")


func test_the_smith_sells_what_he_has_for_a_man_or_the_chest() -> void:
	var j := _at(7, "younger_son", "ribe")
	_men(j, 3)
	var band := j.c.band
	band.silver = 1000
	var s := j.smith()
	assert_eq(str(s.kind), "plain")
	var bows := 0
	for r in s.rows:
		if str(r.item) == "bow":
			bows = int(r.left)
	assert_true(bows >= 1, "a plain smith has a bow or two")
	var m := band.living_men()[0]
	m.weapon = CombatTypes.Weapon.SPEAR
	var lo := m.loyalty
	var silver := band.silver
	assert_true(j.buy_arms("bow", m.id), "a bow for a man")
	assert_eq(m.weapon, CombatTypes.Weapon.BOW)
	assert_true(m.loyalty > lo, "a gift of arms binds him")
	assert_eq(band.silver, silver - j.c.rules.smith_price.bow)
	assert_true(not j.buy_arms("bow", m.id), "not what he has already")
	# The stock runs out for the year.
	var n := 0
	while j.buy_arms("bow", -1):
		n += 1
	assert_eq(n, bows - 1, "the rest for the chest, then none")
	assert_eq(int(band.estate.chest.get("bow", 0)), bows - 1)
	# A great smith is dearer.
	assert_true(Estate.arms_price(j.c.rules, "great", "mail") > Estate.arms_price(j.c.rules, "plain", "mail"))


func test_a_sword_with_a_name() -> void:
	var j := _at(8, "younger_son", "hedeby")
	_men(j, 2)
	var band := j.c.band
	band.silver = 1000
	Estate._smith(j, j.here(), "great").named = "Legbiter"
	var m := band.living_men()[0]
	m.role = CombatTypes.Role.SHIELD  # a sword is for the front rank
	var fame := band.fame
	assert_true(j.buy_arms("named", m.id))
	assert_eq(m.sword_name, "Legbiter")
	assert_eq(m.weapon, CombatTypes.Weapon.SWORD)
	assert_eq(band.fame, fame + j.c.rules.smith_named_fame, "it is talked of")
	assert_true(band.estate.named_sold.has("Legbiter"), "never offered again")
	var told := false
	for l in band.chronicle:
		told = told or "Legbiter" in l
	assert_true(told, "the saga remembers it")
	assert_true("Legbiter" in Estate.gear_words(m))


func test_a_gift_in_summer_once_a_man() -> void:
	var j := _at(9, "younger_son", "hardanger")
	_men(j, 2)
	var band := j.c.band
	band.silver = 50
	var m := band.living_men()[0]
	band.estate.chest["helmet"] = 1
	m.helmet = false
	var ids := []
	for o in j.gift_options(m.id):
		ids.append(str(o.id))
	assert_true(ids.has("chest:helmet"), "the chest's helmet may be given")
	assert_true(j.give(m.id, "chest:helmet"))
	assert_true(m.helmet)
	assert_true(band.estate.chest.is_empty(), "out of the chest")
	assert_true(not j.give(m.id, "silver"), "once a summer")
	assert_true(j.gift_options(band.leader.id).is_empty(), "nothing to give himself")


# --- The works -----------------------------------------------------------------------------

func test_benches_in_summer_raise_the_ceiling() -> void:
	var j := _at(10, "younger_son", "hardanger")
	_home(j)
	var band := j.c.band
	band.silver = 500
	var room := j.c.room()
	assert_true(j.do_work("build:%d" % CampaignTypes.Building.BENCHES), "benches built in summer")
	assert_true(j.c.room() > room, "the band may grow: %d -> %d" % [room, j.c.room()])
	assert_eq(band.estate.sunk, int(j.c.rules.building_costs[CampaignTypes.Building.BENCHES]))


func test_the_hall_adorned_brings_honor_and_warmth() -> void:
	var j := _at(11, "younger_son", "hardanger")
	_home(j)
	_men(j, 2)
	var band := j.c.band
	band.silver = 1000
	var honor := band.honor
	assert_true(j.do_work("adorn"))
	assert_eq(band.honor, honor + int(j.c.rules.hall_adorn[0].honor))
	var m := band.living_men()[0]
	m.loyalty = 50
	Loyalty.winter_drift(j.c.rules, band, m, true, true, PackedStringArray())
	assert_eq(m.loyalty, 50 + j.c.rules.loyalty_winter_rest + j.c.rules.adorn_rest, "a seated man warms the more")
	for i in 2:
		j.do_work("adorn")
	assert_eq(band.estate.adorn, 3)
	for w in j.works():
		assert_true(str(w.id) != "adorn", "nothing more to adorn")


func test_feasts_win_standing() -> void:
	var j := _at(12, "younger_son", "fitjar")
	var band := j.c.band
	band.silver = 500
	var fam := j.here().family
	var before := Families.standing(band, fam)
	assert_true(j.do_work("feast_house"), "a feast for the house")
	assert_true(Families.standing(band, fam) > before, "they think the better of him")
	assert_true(not j.do_work("feast_house"), "once a year")
	var k := _at(12, "younger_son", "hardanger")
	_home(k)
	k.c.band.silver = 500
	var d := Estate.district(k)
	assert_true(not d.is_empty(), "a district round his hall")
	var s0 := Families.standing(k.c.band, d[0])
	assert_true(k.do_work("feast_district"))
	assert_true(Families.standing(k.c.band, d[0]) > s0)


func test_stones_for_the_dead_and_a_skald() -> void:
	var j := _at(13, "younger_son", "hardanger")
	_home(j)
	var band := j.c.band
	band.silver = 500
	var dead := Man.new()
	dead.display_name = "Hervor"
	dead.woman = true
	Chronicle.fell(band, dead, 866)
	var fame := band.fame
	assert_true(j.do_work("stone:0"))
	assert_eq(band.fame, fame + j.c.rules.stone_fame)
	var said := false
	for l in band.chronicle:
		said = said or ("Hervor" in l and "keep her" in l)
	assert_true(said, "the stone's words say her")
	assert_true(not j.do_work("mound:0"), "one memorial for each")
	assert_true(j.do_work("skald"))
	assert_true(band.estate.skald != "")
	# The winter pays him and he makes the verse.
	j.act("winter")
	var paid := false
	for l in j.winter_report:
		paid = paid or ("The skald %s is given %d oz" % [band.estate.skald, j.c.rules.kept_skald_keep]) in l
	assert_true(paid, "he is paid at the winter: " + "\n".join(j.winter_report))


func test_the_ship_fitted_and_the_boathouse() -> void:
	var j := _at(14, "younger_son", "kaupang")
	_men(j, 5)
	var band := j.c.band
	band.ship = Ship.make(WorldTypes.ShipKind.KNARR)
	j.roam.aboard = true
	band.silver = 500
	var speed := j.sail_speed()
	assert_true(j.do_work("fit:sail"))
	assert_true(j.sail_speed() > speed, "the striped sail: %.1f -> %.1f" % [speed, j.sail_speed()])
	var ids := []
	for w in j.works():
		ids.append(str(w.id))
	assert_true(not ids.has("fit:prow"), "no dragon for a knarr")
	band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	assert_eq(j.sail_speed(), float(j.c.world_rules.ship_speed[WorldTypes.ShipKind.KARVE]), "a new hull starts bare")
	var k := _at(14, "younger_son", "hardanger")
	_home(k)
	k.c.band.silver = 500
	k.c.band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	k.roam.aboard = true
	assert_true(k.do_work("build:%d" % CampaignTypes.Building.BOATHOUSE))
	k.c.band.ship.damage = 2
	k.act("winter")
	k.winter_auto()
	assert_eq(k.c.band.ship.damage, 0, "she comes out of the boathouse sound")


# --- Shieldmaidens ---------------------------------------------------------------------------

func _maiden(j: Journey) -> Man:
	Shieldmaidens._offer(j, SimRng.new(5), j.here())
	assert_eq(str(j.current().get("kind", "")), "men_silver")
	j.answer("take")
	for m in j.c.band.living_men():
		if m.woman:
			return m
	return null


func test_a_shieldmaiden_comes_and_the_saga_says_her() -> void:
	var j := _at(15, "younger_son", "fitjar")
	_men(j, 3)
	var m := _maiden(j)
	assert_true(m != null, "she swears")
	assert_true(m.woman)
	assert_true(m.tier >= CombatTypes.Tier.BLOODED, "she has stood in a fight before")
	assert_eq(m.he(), "she")
	assert_eq(m.his(), "her")
	assert_eq(j.c.band.estate.maidens, 1)
	# The saga's lines that can name her say "her".
	var log := PackedStringArray()
	var brother := j.c.band.living_men()[0]
	j.c.band.set_bond_kind(m, brother, CampaignTypes.BondKind.OATH_BROTHER)
	Bonds.on_death(j.c.rules, j.c.band, brother, "Ulf", log)
	assert_true(" her oath brother" in "\n".join(log), "bonds: " + "\n".join(log))
	assert_true(not (" his oath brother" in "\n".join(log)))
	for h in Potential.hints(j.c.rules, m, 1):
		assert_true(not h.begins_with("his"), "the hints say her: " + h)
	# Nothing in the fight differs: the warrior is built as any man's.
	var w := m.to_warrior(0, j.c.rules)
	assert_eq([w.might, w.skill, w.grit, w.nerve, w.wits], [m.stats[0], m.stats[1], m.stats[2], m.stats[3], m.stats[4]])


func test_the_maidens_are_rare() -> void:
	var come := 0
	for s in 30:
		var j := Journey.begin(200 + s, "younger_son", "Egil")
		j.c.band.fame = 40
		for y in 10:
			j.c.cal.year += 1
			j.decisions.clear()
			Shieldmaidens.spring(j)
			if not j.decisions.is_empty() and str(j.current().get("step", "")) == "maiden":
				come += 1
	assert_between(come, 3, 40, "a few in three hundred summers: %d" % come)


func test_a_house_asks_for_her_hand() -> void:
	var j := _at(16, "younger_son", "fitjar")
	_men(j, 2)
	var m := _maiden(j)
	m.joined_year -= 1
	m.ambition_met = true
	Shieldmaidens._suit(j, SimRng.new(1), m)
	var d := j.current()
	assert_eq(str(d.get("step", "")), "suit")
	var house := str(d.house)
	var st := Families.standing(j.c.band, house)
	j.answer("give")
	assert_true(not j.c.band.living_men().has(m), "she goes to be married")
	assert_true(Families.standing(j.c.band, house) > st, "they are kin now")


# --- The stand-in, and the save ---------------------------------------------------------------

func test_the_stand_in_spends_on_the_works() -> void:
	var sunk := 0
	for s in 3:
		var j := Journey.begin(300 + s, "younger_son", "Egil")
		for y in 4:
			JourneyBot.play_year(j, Way.Id.TRADER)
			if j.c.over:
				break
		sunk += j.c.band.estate.sunk
		assert_true(not j.c.band.leader.natures.is_empty(), "the stand-in has a nature")
	assert_true(sunk > 0, "silver laid out on works and arms in four years: %d" % sunk)


func test_the_estate_is_saved() -> void:
	var j := _at(17, "younger_son", "hardanger")
	_home(j)
	_men(j, 2)
	j.choose_nature(PackedStringArray(["grim", "open_handed"]))
	j.c.band.silver = 500
	j.do_work("adorn")
	j.do_work("skald")
	j.c.band.estate.chest["mail"] = 2
	var m := _maiden(j)
	m.sword_name = "Whitling"
	var text := JSON.stringify(SaveCodec.encode(j), "", false)
	var back: Journey = SaveCodec.decode(JSON.parse_string(text))
	var e := back.c.band.estate
	assert_eq(e.adorn, 1)
	assert_eq(e.skald, j.c.band.estate.skald)
	assert_eq(int(e.chest.get("mail", 0)), 2)
	assert_eq(back.c.band.leader.natures, PackedStringArray(["grim", "open_handed"]))
	var found := false
	for x in back.c.band.living_men():
		if x.woman and x.sword_name == "Whitling":
			found = true
	assert_true(found, "she and her sword come back")
	assert_eq(float(back.c.band.gift("dread", 0.0)), float(j.c.band.gift("dread", 0.0)), "the edges come back")


## The fight's own lines turn for a woman of the band, and are untouched
## for a man (the battle log is byte for byte what it was).
func test_the_fight_says_she_of_a_woman() -> void:
	var w := Warrior.new()
	w.display_name = "Hervor"
	var line := "Hervor cannot hold himself: he runs at them, his shield before him."
	assert_eq(w.said(line), line)
	w.woman = true
	assert_eq(w.said(line), "Hervor cannot hold herself: she runs at them, her shield before her.")
	assert_eq(w.said("Hervor looks for his place in the shield wall"), "Hervor looks for her place in the shield wall")
