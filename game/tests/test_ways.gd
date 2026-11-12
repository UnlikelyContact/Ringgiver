extends TestCase
## Ways of life and the free-roam summer (concept.md): a man starts from
## an origin with no ship and no way of life; deeds earn points that he
## spends down any paths he likes; the saga names him by what he does. He
## walks the land and, once he has a hull, sails the water, and others
## abroad on the map may come for him.


func _lawful(j: Journey, way: int, rank: int) -> void:
	j.c.band.paths[way] = rank
	Way.refresh(j.c.band)


func test_the_origins_start_small_and_without_a_ship() -> void:
	for key in Origins.keys():
		var d := Origins.def(key)
		var j := Journey.begin(7, key, "Egil")
		var band := j.c.band
		assert_eq(band.origin, key)
		assert_eq(band.fighters().size(), int(d.followers) + 1, "%s: him and his followers" % d.name)
		assert_true(band.ship == null, "%s: no ship" % d.name)
		assert_eq(band.silver, int(d.silver))
		assert_eq(band.location, str(d.at), "%s: where his origin puts him" % d.name)
		assert_true(band.paths.is_empty() and band.gifts.is_empty(), "no way of life yet")
		assert_eq(Way.points_free(band), Way.START_POINTS, "one point to begin with")
		assert_eq(Way.title(band), "Egil")
		assert_eq(j.sail_speed(), 0.0)
	var burned := Journey.begin(7, "burned_hall", "Egil")
	var burners: String = burned.c.world.place("hardanger").family
	assert_true(not Feud.find(burned.c.band, burners).is_empty(), "the burned hall begins at feud with the burners")
	assert_eq(burned.c.band.vengeance, burners)
	# Ending that feud, by whatever road, is told as his vengeance.
	Feud.find(burned.c.band, burners)["settled"] = true
	var fame := burned.c.band.fame
	burned._vengeance()
	assert_eq(burned.c.band.vengeance, "")
	assert_true(burned.c.band.fame > fame, "and men speak of it")


func test_deeds_earn_points_and_points_buy_steps_down_any_paths() -> void:
	var j := Journey.begin(7, "younger_son", "Egil")
	var band := j.c.band
	assert_true(Way.can_invest(band, Way.Id.LAWMAN), "the first step costs the one point he has")
	assert_true(j.invest(Way.Id.LAWMAN))
	assert_eq(Way.rank(band, Way.Id.LAWMAN), 1)
	assert_eq(int(band.gift("law", 0)), 1, "and gives its edge")
	assert_eq(Way.points_free(band), 0)
	assert_true(not j.invest(Way.Id.VIKING), "nothing left to spend")
	# Deeds of any kind earn points: raiding pays for learning the law.
	Way.add_deed(band, Way.Id.VIKING, Way.POINT_DEEDS * 3)
	assert_eq(Way.points_free(band), 3)
	assert_eq(Way.next_cost(band, Way.Id.LAWMAN), 2, "the second step is dearer")
	assert_true(j.invest(Way.Id.LAWMAN))
	assert_eq(int(band.gift("law", 0)), 2)
	assert_true(j.invest(Way.Id.SKALD), "and a step down another path beside it")
	assert_eq(int(band.gift("verse", 0)), 1)
	assert_eq(int(band.gift("law", 0)), 2, "both hold")
	assert_eq(Way.points_free(band), 0)
	assert_eq(Way.standing(band), "law-man and verse-maker")
	Way.add_deed(band, Way.Id.VIKING, Way.POINT_DEEDS * 3)
	assert_true(j.invest(Way.Id.LAWMAN))
	assert_true(band.gift("foresight", false), "the third step of the law gives foresight")
	assert_eq(Way.next_cost(band, Way.Id.LAWMAN), 0, "the path is walked to its end")
	assert_true(not Way.can_invest(band, Way.Id.LAWMAN))
	# The saga still names him by what he did, which was raiding.
	assert_eq(Way.title(band), "Egil the Viking")


func test_the_fury_is_a_step_down_the_berserks_way_and_lords_like_it_less() -> void:
	var j := Journey.begin(7, "younger_son", "Ljot")
	var band := j.c.band
	var lord: Faction = FactionAI.ruler_of(j.c.world, "fitjar")
	var before := FactionAI.relation(j.c.world, lord.id, FactionAI.BAND)
	assert_true(not band.leader.to_warrior(0).fury)
	assert_true(j.invest(Way.Id.BERSERK))
	assert_true(band.leader.traits.has("berserk"))
	var w := band.leader.to_warrior(0)
	assert_true(w.fury and w.fury_level == 1, "the fury goes to the fight with him")
	assert_true(FactionAI.relation(j.c.world, lord.id, FactionAI.BAND) < before, "and the lords trust him the less")
	_lawful(j, Way.Id.BERSERK, 3)
	assert_eq(band.leader.to_warrior(0).fury_level, 2, "deeper at the third step")
	var rules := CombatRules.new()
	var deep := band.leader.to_warrior(0)
	deep.reset_for_battle(rules)
	assert_eq(deep.condition_penalty(rules), -(rules.fury_bonus + 1))
	deep.wound = CombatTypes.Wound.WOUNDED
	assert_eq(deep.condition_penalty(rules), -(rules.fury_bonus + 1), "he feels no wound in it")
	deep.breath = 0
	assert_true(deep.condition_penalty(rules) > rules.wound_penalty[CombatTypes.Wound.WOUNDED], "spent, he is weaker than a plain man")


func test_a_holmgang_ends_at_first_blood() -> void:
	var rules := CombatRules.new()
	var decided := 0
	for s in 20:
		var a := BandFactory.make_band(SimRng.new(10 + s), 0, 1, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 0, 1, 4, rules)
		var b := BandFactory.make_band(SimRng.new(50 + s), 1, 1, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 8, 101, 4, rules)
		var built := Scenario.build_duel(100 + s, rules, a, b)
		var battle: Battle = built.battle
		assert_true(battle.duel)
		battle.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		var r := battle.run()
		if r.how == BattleResult.End.FIRST_BLOOD:
			decided += 1
			if r.winner >= 0:
				var loser: Warrior = (a if r.winner == 1 else b)[0]
				assert_true(int(loser.wound) >= int(rules.duel_first_blood), "the loser is blooded")
	print("    gate: holmgang, 20 duels: %d ended at first blood" % decided)
	assert_true(decided >= 14, "most duels end at first blood: %d of 20" % decided)


func test_counsel_and_verse_pay_the_men_who_have_learned_them() -> void:
	var wr := WorldRules.new()
	var held := [0, 0]
	var fees := [0, 0]
	for i in 2:
		for s in 40:
			var j := Journey.begin(100 + s, "younger_son", "Njal")
			if i == 1:
				_lawful(j, Way.Id.LAWMAN, 3)
			var band := j.c.band
			var before := band.silver
			var thing := j.c.world.place("gulathing")  # a Thing always has cases
			assert_true(Callings.can_counsel(wr, j.c.world, band, thing))
			var was := band.standing.duplicate()
			var r := Callings.counsel(SimRng.new(s), wr, j.c.world, band, thing, PackedStringArray())
			if r.ok:
				held[i] += 1
				fees[i] += band.silver - before
				# He judged between two houses: the one he found for thinks the
				# better of him (Families), the other a little the worse.
				var won := str(r.winner)
				var lost := str(r.loser)
				assert_true(Families.standing(band, won) > int(was.get(won, 0)), "the house he found for is the warmer to him")
				assert_true(Families.standing(band, lost) < int(was.get(lost, 0)), "the other the colder")
			assert_true(not Callings.can_counsel(wr, j.c.world, band, thing), "once a year a place")
	print("    gate: counsel held, of 40: unlearned %d, law-wise %d; mean fee %d vs %d oz" % [held[0], held[1],
			fees[0] / maxi(1, held[0]), fees[1] / maxi(1, held[1])])
	assert_true(held[1] > held[0], "the law-wise man's counsel holds more often")
	assert_true(fees[1] / maxi(1, held[1]) > fees[0] / maxi(1, held[0]), "and pays him more")
	var disputes := 0
	var w := Journey.begin(1, "younger_son", "Njal").c.world
	for y in 40:
		w.year = 866 + y
		if Callings.has_dispute(wr, w, w.place("hardanger")):
			disputes += 1
	assert_between(float(disputes) / 40.0, 0.15, 0.6, "a farm has a dispute about one year in three: %d of 40" % disputes)
	# A verse: only before a lord; a skald's ring is double, and the lord wants better next time.
	var j2 := Journey.begin(3, "younger_son", "Egil")
	assert_true(not Callings.can_verse(j2.c.world, j2.c.band, j2.here()), "no lord at the farms")
	var ok := 0
	for s in 30:
		var j3 := Journey.begin(200 + s, "younger_son", "Egil")
		_lawful(j3, Way.Id.SKALD, 3)
		var fitjar := j3.c.world.place("fitjar")
		var r3 := Callings.verse(SimRng.new(s), wr, j3.c.world, j3.c.band, fitjar, PackedStringArray())
		if r3.ok:
			ok += 1
			assert_true(int(r3.ring) >= 2 * wr.verse_ring, "a king's skald's ring is double")
			assert_eq(Callings.verse_need(wr, j3.c.band, fitjar), wr.verse_difficulty + wr.verse_heard_harder)
	assert_true(ok >= 12, "a skald's verse pleases often: %d of 30" % ok)


func test_the_traders_edge_and_his_deeds() -> void:
	var j := Journey.begin(5, "younger_son", "Ottar")
	var wr := j.c.world_rules
	var band := j.c.band
	var lade := j.c.world.place("lade")
	var blades := WorldTypes.Good.FRANKISH_BLADES
	assert_true(Market.buy_price(wr, lade, band, blades) > Market.price(wr, lade, blades), "a stranger pays the middlemen")
	assert_true(Market.sell_price(wr, lade, band, blades) < Market.price(wr, lade, blades), "both ways")
	_lawful(j, Way.Id.TRADER, 1)
	var pedlar := Market.buy_price(wr, lade, band, blades)
	_lawful(j, Way.Id.TRADER, 3)
	assert_eq(Market.buy_price(wr, lade, band, blades), Market.price(wr, lade, blades), "the far-trader buys at the price itself")
	assert_eq(Market.sell_price(wr, lade, band, blades), Market.price(wr, lade, blades), "and sells at it")
	assert_true(pedlar >= Market.price(wr, lade, blades), "a pedlar somewhere between")
	# No round trip is free silver: buy and sell back.
	var before := band.silver
	band.silver += 500
	var n := Market.buy(wr, lade, band, WorldTypes.Good.FURS, 2, PackedStringArray())
	Market.sell(wr, lade, band, WorldTypes.Good.FURS, n, PackedStringArray())
	assert_true(band.silver - 500 <= before, "buying and selling back gains nothing")
	band.silver = before
	# Goods bought and sold at a margin count as a trader's deeds; loot does not.
	band.deeds.clear()
	band.cargo[WorldTypes.Good.AMBER] = 2
	Market.sell(wr, lade, band, WorldTypes.Good.AMBER, 2, PackedStringArray())
	assert_eq(int(band.deeds.get(Way.Id.TRADER, 0)), 0, "loot sold is no trader's deed")
	band.bought[WorldTypes.Good.WINE] = [2, 2]
	band.cargo[WorldTypes.Good.WINE] = 2
	Market.sell(wr, lade, band, WorldTypes.Good.WINE, 2, PackedStringArray())
	assert_true(band.trade_margin > 0 or int(band.deeds.get(Way.Id.TRADER, 0)) > 0, "a margin on what he bought is")


func test_dread_makes_men_pay_and_an_overbearing_man_is_outlawed() -> void:
	var paid := 0
	for s in 60:
		var j := Journey.begin(300 + s, "younger_son", "Ljot")
		_lawful(j, Way.Id.BERSERK, 3)
		if Callings.holmgang_yields(SimRng.new(s), j.c.band):
			paid += 1
	assert_between(float(paid) / 60.0, 0.2, 0.5, "about one man in three pays a berserk")
	var plain := Journey.begin(1, "younger_son", "Egil")
	assert_true(not Callings.holmgang_yields(SimRng.new(1), plain.c.band), "nobody pays a plain man")
	var j2 := Journey.begin(9, "younger_son", "Ljot")
	var wr := j2.c.world_rules
	var farm := j2.c.world.place("sogn_farms")
	var terms := Callings.holmgang_terms(wr, j2.c.world, j2.c.band, farm)
	assert_true(not terms.feud and int(terms.honor_cost) == wr.holmgang_honor)
	j2.c.band.honor = wr.holmgang_outlaw_honor + 1
	Callings.challenge(wr, j2.c.world, j2.c.band, farm, terms, PackedStringArray())
	assert_eq(j2.c.band.outlawry, WorldTypes.Outlawry.LESSER, "the district will bear it no longer")
	j2.c.band.add_feud(farm.family, "a killing", farm.id)
	var lawful := Callings.holmgang_terms(wr, j2.c.world, j2.c.band, farm)
	assert_true(lawful.feud and int(lawful.honor_cost) == 0)
	Callings.after_holmgang(wr, j2.c.world, j2.c.band, farm, lawful, 1, false, PackedStringArray())
	assert_true(Feud.find(j2.c.band, farm.family).is_empty(), "the feud is ended on the island")


func test_a_man_walks_until_he_has_a_hull() -> void:
	var j := Journey.begin(11, "younger_son", "Egil")
	j.quick = true
	while not j.decisions.is_empty():
		j.answer(JourneyBot._answer(j, j.current(), Way.Id.LAWMAN))
	var wr := j.c.world_rules
	var band := j.c.band
	# On foot: the neighbours can be walked to, the sea cannot be crossed.
	var on_foot := j.days_to("fitjar")
	assert_true(on_foot >= 2, "a walk of days to Fitjar: %d" % on_foot)
	assert_eq(j.days_to("orkney"), -1, "no way to Orkney without a ship")
	band.known_places["orkney"] = true
	assert_true(not j.go_to_place("orkney"))
	assert_true(j.said[j.said.size() - 1].contains("no ship") or j.said[j.said.size() - 1].contains("no way"), j.said[j.said.size() - 1])
	assert_true(not j.go_to_point(Vector2(10, 54)), "nor out onto the water")
	# He walks to the hall, as the days pass.
	var day := j.c.cal.day
	assert_true(j.go_to_place("fitjar"))
	assert_true(j.moving())
	var guard := 0
	while band.location != "fitjar" and guard < 60:
		guard += 1
		if not j.decisions.is_empty():
			j.answer(JourneyBot._answer(j, j.current(), Way.Id.LAWMAN))
			if not j.moving() and band.location != "fitjar":
				j.go_to_place("fitjar")
		j.advance(1.0)
	assert_eq(band.location, "fitjar")
	assert_true(j.c.cal.day - day >= 2, "it took days: %d" % (j.c.cal.day - day))
	# A hull is to be had at a hall; with it the same road is a day.
	band.silver = 40
	var hulls := j.hulls_for_sale()
	assert_true(hulls.has(WorldTypes.ShipKind.FAERING), "a færing he can pay for")
	assert_true(hulls.has(WorldTypes.ShipKind.KARVE), "and the karve shown, though he cannot yet")
	j.act("hull:%d" % WorldTypes.ShipKind.FAERING)
	assert_true(band.ship != null and band.ship.kind == WorldTypes.ShipKind.FAERING)
	assert_eq(band.silver, 40 - int(wr.ship_price[WorldTypes.ShipKind.FAERING]))
	assert_true(j.roam.aboard, "she lies on the beach where he stands")
	assert_true(j.sail_speed() > j.foot_speed())
	var by_boat := j.days_to("hardanger")
	assert_true(by_boat < on_foot, "by boat %d days, on foot %d" % [by_boat, on_foot])
	assert_eq(j.days_to("orkney"), -1, "but a færing keeps out of the deep")
	# More men than she carries, and she is no use.
	for i in 5:
		band.add_man(Recruits.random(SimRng.new(i), j.c.rules, band.next_id()))
	assert_eq(j.sail_speed(), 0.0, "a færing will not carry seven")
	assert_true(j.ship_trouble().contains("will not carry"), j.ship_trouble())


func test_a_ship_stays_where_she_is_beached() -> void:
	var j := Journey.begin(11, "younger_son", "Egil")
	j.quick = true
	while not j.decisions.is_empty():
		j.answer("ignore")
	var band := j.c.band
	band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	for i in 4:
		band.add_man(Recruits.random(SimRng.new(i), j.c.rules, band.next_id()))
	j.roam.aboard = true
	j.roam.parties.clear()
	# Out onto the fjord and back to land a little way off.
	var start := j.roam.pos
	var water := Vector2.INF
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		if j.roam.grid.is_sea(MapGrid.cell_of(start + d)):
			water = start + d
	assert_true(water != Vector2.INF)
	assert_true(j.go_to_point(water))
	j.travel()
	assert_true(j.roam.afloat() and j.roam.aboard, "afloat")
	assert_eq(band.location, "", "and at no place")
	assert_eq(j.whereabouts(), "at sea")
	assert_true(j.go_to_place("hardanger"))
	j.travel()
	assert_true(j.roam.aboard and not j.roam.afloat(), "beached at the farm")
	# Inland on foot: she stays.
	var inland := Vector2.INF
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := MapGrid.cell_of(start) + Vector2i(dx, dy)
			if j.roam.grid.is_land(c) and (dx != 0 or dy != 0) and not j.roam.grid.cell_place.has(MapGrid.index(c)) and inland == Vector2.INF:
				inland = MapGrid.centre(c)
	assert_true(j.go_to_point(inland))
	j.travel()
	assert_true(not j.roam.aboard, "he has walked on")
	var lies := MapGrid.cell_of(j.roam.ship_at)
	assert_true(j.roam.ship_at != Vector2.INF and lies != j.roam.cell(), "and she lies where he left her, not where he is")
	assert_true(j.roam.grid.is_land(lies), "on a beach")
	# To sail again he must go back to her.
	j.c.band.known_places["orkney"] = true
	assert_true(j.go_to_place("orkney"), "the way to Orkney is by way of the ship")
	assert_true(j.roam.route.has(lies), "back to where she lies first")
	assert_eq(j.whereabouts(), "in the wilds")


func test_others_abroad_come_for_a_band_they_like_the_look_of() -> void:
	var j := Journey.begin(11, "younger_son", "Egil")
	j.quick = false
	while not j.decisions.is_empty():
		j.answer("ignore")
	var wr := j.c.world_rules
	j.roam.parties.clear()
	# Outlaws near a band on the road go for it; at a place it is left alone.
	var o := Roam.Party.new()
	o.kind = "outlaws"
	o.name = "outlaws"
	o.sails = false
	o.home = "hardanger"
	o.men = 5
	o.speed = wr.outlaw_speed
	var road := Vector2.INF
	for dx in range(-4, 5):
		var c := MapGrid.cell_of(j.roam.pos) + Vector2i(dx, -2)
		if j.roam.grid.is_land(c) and road == Vector2.INF:
			road = MapGrid.centre(c)
	o.pos = road
	j.roam.parties.append(o)
	j.advance(2.0)
	assert_true(j.decisions.is_empty(), "at the farm nobody troubles him")
	assert_true(j.go_to_point(road + Vector2(0, -1)) or j.go_to_point(road))
	var guard := 0
	while j.decisions.is_empty() and guard < 20:
		guard += 1
		j.advance(0.5)
	assert_eq(j.current().get("kind", ""), "fight", "on the road they come out of the trees")
	var offer: FightOffer = j.current().offer
	assert_true(not offer.at_sea and offer.allows(FightOffer.Choice.FADE_AWAY))
	j.answer(str(FightOffer.Choice.FADE_AWAY))
	assert_true(o.rest_until > j.roam.clock, "outrun, they leave him be for a while")
	assert_true(j.roam.parties.has(o))


func test_a_summer_is_played_one_decision_at_a_time() -> void:
	var j := Journey.begin(11, "younger_son", "Egil")
	j.quick = true
	var guard := 0
	while not j.decisions.is_empty() and guard < 10:
		guard += 1
		j.answer(JourneyBot._answer(j, j.current(), Way.Id.VIKING))
	assert_true(j.can_act(), "then the summer is his")
	var ids := []
	for a in j.actions():
		ids.append(a.id)
	assert_true(ids.has("listen") and ids.has("winter"), "at home: wait, or winter")
	assert_true(not ids.has("raid"), "nobody raids the roof he sleeps under")
	j.roam.parties.clear()
	assert_true(j.sail("fitjar"), "he walks to the hall")
	ids = []
	for a in j.actions():
		ids.append(a.id)
	assert_true(ids.has("raid"), "a hall can be raided")
	assert_true(ids.has("hull:%d" % WorldTypes.ShipKind.FAERING), "and has hulls to sell")
	var has_passage := false
	for id in ids:
		has_passage = has_passage or str(id).begins_with("passage:")
	assert_true(has_passage, "and ships that will carry a man without one")
	j.act("raid")
	assert_eq(j.current().get("kind", ""), "fight", "the raid is offered as a fight first")
	var offer: FightOffer = j.current().offer
	assert_true(offer.attacking and offer.allows(FightOffer.Choice.FADE_AWAY))
	j.answer(str(FightOffer.Choice.FADE_AWAY))
	assert_true(j.can_act() or j.c.over, "he thought better of it")
	# Passage carries him where he could not walk.
	j.c.band.silver = 60
	var before := j.c.cal.day
	var to := ""
	for p in j.passages():
		to = str(p.id)
	assert_true(to != "")
	j.act("passage:" + to)
	if j.decisions.is_empty():
		assert_eq(j.c.band.location, to, "carried there")
		assert_true(j.c.cal.day > before, "as the days pass")


func test_a_fight_can_be_handed_to_the_battle_view() -> void:
	var j := Journey.begin(11, "younger_son", "Egil")
	j.quick = false
	while not j.decisions.is_empty():
		j.answer("ignore")
	j.roam.parties.clear()
	j.sail("fitjar")
	j.act("raid")
	assert_eq(j.current().get("kind", ""), "fight")
	j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
	assert_true(not j.fight.is_empty(), "the fight waits for the battle screen")
	assert_true(not j.can_act(), "nothing else until it is fought")
	var battle: Battle = j.fight.built.battle
	assert_true(battle.withdraw(0))
	var lines := j.fight_done(battle.result)
	assert_true(j.fight.is_empty())
	assert_true(lines.size() >= 0)
	assert_true(j.can_act() or not j.decisions.is_empty() or j.c.over)


func test_every_bent_plays_three_years_through() -> void:
	for way in Way.Id.values():
		var j := Journey.begin(21, "younger_son", "Egil")
		var years := 0
		for y in 3:
			if j.c.over:
				break
			var before := j.c.cal.year
			JourneyBot.play_year(j, way)
			if j.c.cal.year > before:
				years += 1
		var band := j.c.band
		print("    gate: %-12s %d years: %s (%s), %d men, %s, %d oz, fame %d honor %d%s" % [Way.name_of(way), years, Way.title(band),
				Way.standing(band), band.fighters().size(), WorldTypes.SHIP_NAMES[band.ship.kind] if band.ship != null else "no ship",
				band.silver, band.fame, band.honor, "  (ended: %s)" % j.c.over_reason if j.c.over else ""])
		assert_true(years >= 3 or j.c.over, "%s: the years turn" % Way.name_of(way))
		if not j.c.over:
			assert_true(Way.rank(band, way) >= 1, "%s: he has taken a step down his way" % Way.name_of(way))
