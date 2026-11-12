extends TestCase
## Ways of life (concept.md): the raider, the trader, the law-wise man, the
## berserk, the skald and the king's man each start their own way, have an
## edge in their own deed, and are named by what they do. And the player's
## summer (Journey) plays through for every one of them.


func test_each_way_starts_its_own_way() -> void:
	for way in Way.Id.values():
		var d := Way.def(way)
		var j := Journey.begin(7, way, "Egil")
		var band := j.c.band
		assert_eq(band.way, way)
		assert_eq(band.fighters().size(), int(d.followers) + 1, "%s: the leader and his followers" % d.name)
		assert_eq(band.ship.kind, d.ship, "%s: his ship" % d.name)
		assert_eq(band.silver, int(d.silver), "%s: his silver" % d.name)
		assert_eq(Way.epithet(band), "", "no name before the deeds")
		assert_eq(Way.title(band), "Egil")
	var trader := Journey.begin(7, Way.Id.TRADER, "Ottar")
	assert_true(trader.c.band.knows("hedeby") and trader.c.band.knows("bjarkoy"), "the trader knows the coast")
	var viking := Journey.begin(7, Way.Id.VIKING, "Egil")
	assert_true(not viking.c.band.knows("hedeby"), "the raider does not, yet")
	var berserk := Journey.begin(7, Way.Id.BERSERK, "Ljot")
	assert_true(berserk.c.band.leader.traits.has("berserk"), "the trait is on him")
	assert_true(berserk.c.band.leader.to_warrior(0).fury, "and goes to the fight with him")


func test_the_saga_names_a_man_by_his_deeds_not_his_start() -> void:
	var j := Journey.begin(7, Way.Id.LAWMAN, "Njal")
	var band := j.c.band
	Way.add_deed(band, Way.Id.VIKING, Way.EPITHET_DEEDS - 1)
	assert_eq(Way.epithet(band), "", "five deeds are not yet a name")
	Way.add_deed(band, Way.Id.VIKING, 1)
	assert_eq(Way.title(band), "Njal the Viking", "a law-wise man who raids is called a viking")
	Way.add_deed(band, Way.Id.LAWMAN, Way.EPITHET_DEEDS + 2)
	assert_eq(Way.title(band), "Njal the Law-Wise", "until his counsel outweighs it")


func test_the_fury_strikes_harder_feels_no_wound_and_is_weak_when_spent() -> void:
	var rules := CombatRules.new()
	var w := Warrior.make("Ljot", 0, [4, 4, 4, 4, 2])
	w.reset_for_battle(rules)
	var plain := w.condition_penalty(rules)
	w.fury = true
	assert_true(w.in_fury(rules))
	assert_eq(w.condition_penalty(rules), plain - rules.fury_bonus, "the fury is on him")
	w.wound = CombatTypes.Wound.WOUNDED
	assert_eq(w.condition_penalty(rules), -rules.fury_bonus, "he feels no wound in it")
	w.breath = 0
	assert_true(not w.in_fury(rules))
	assert_true(w.condition_penalty(rules) > rules.wound_penalty[CombatTypes.Wound.WOUNDED], "spent, he is weaker than a plain man")


func test_a_holmgang_ends_at_first_blood() -> void:
	var rules := CombatRules.new()
	var a := BandFactory.make_band(SimRng.new(1), 0, 1, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 0, 1, 4, rules)
	var b := BandFactory.make_band(SimRng.new(2), 1, 1, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 8, 101, 4, rules)
	var built := Scenario.build_duel(5, rules, a, b)
	var battle: Battle = built.battle
	assert_true(battle.duel)
	battle.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	var result := battle.run()
	assert_true(battle.is_over())
	if result.how == BattleResult.End.FIRST_BLOOD and result.winner >= 0:
		var loser: Warrior = (a if result.winner == 1 else b)[0]
		assert_true(int(loser.wound) >= int(rules.duel_first_blood), "the loser is blooded")
	var decided := 0
	for s in 20:
		var a2 := BandFactory.make_band(SimRng.new(10 + s), 0, 1, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 0, 1, 4, rules)
		var b2 := BandFactory.make_band(SimRng.new(50 + s), 1, 1, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 8, 101, 4, rules)
		var d2 := Scenario.build_duel(100 + s, rules, a2, b2)
		(d2.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		var r2: BattleResult = (d2.battle as Battle).run()
		if r2.how == BattleResult.End.FIRST_BLOOD:
			decided += 1
	print("    gate: holmgang, 20 duels: %d ended at first blood" % decided)
	assert_true(decided >= 14, "most duels end at first blood: %d of 20" % decided)


func test_counsel_and_verse_pay_the_men_who_are_good_at_them() -> void:
	var wr := WorldRules.new()
	# Counsel: over many tries the law-wise man's holds far more often.
	var held := [0, 0]
	var fees := [0, 0]
	for i in 2:
		for s in 40:
			var j := Journey.begin(100 + s, Way.Id.LAWMAN if i == 1 else Way.Id.VIKING, "Njal")
			var band := j.c.band
			var before := band.silver
			var thing := j.c.world.place("gulathing")  # a Thing always has cases
			assert_true(Callings.can_counsel(wr, j.c.world, band, thing))
			var r := Callings.counsel(SimRng.new(s), wr, j.c.world, band, thing, PackedStringArray())
			if r.ok:
				held[i] += 1
				fees[i] += band.silver - before
				assert_true(band.friends.has(thing.family), "the family are his friends")
			assert_true(not Callings.can_counsel(wr, j.c.world, band, thing), "once a year a place")
	print("    gate: counsel held, of 40: raider %d, law-wise %d; mean fee %d vs %d oz" % [held[0], held[1],
			fees[0] / maxi(1, held[0]), fees[1] / maxi(1, held[1])])
	assert_true(held[1] > held[0] * 2, "the law-wise man's counsel holds far more often")
	# A farm has a dispute only some years.
	var disputes := 0
	var w := Journey.begin(1, Way.Id.LAWMAN, "Njal").c.world
	for y in 40:
		w.year = 866 + y
		if Callings.has_dispute(wr, w, w.place("hardanger")):
			disputes += 1
	assert_between(float(disputes) / 40.0, 0.15, 0.6, "about one year in three: %d of 40" % disputes)
	assert_true(fees[1] / maxi(1, held[1]) > fees[0] / maxi(1, held[0]), "and pays him more")
	# A verse: only before a lord, and the skald is paid double.
	var j2 := Journey.begin(3, Way.Id.SKALD, "Egil")
	assert_true(not Callings.can_verse(j2.c.world, j2.c.band, j2.here()), "no lord at the farms")
	var fitjar := j2.c.world.place("fitjar")
	assert_true(Callings.can_verse(j2.c.world, j2.c.band, fitjar))
	var ok := 0
	for s in 30:
		var j3 := Journey.begin(200 + s, Way.Id.SKALD, "Egil")
		var r3 := Callings.verse(SimRng.new(s), wr, j3.c.world, j3.c.band, j3.c.world.place("fitjar"), PackedStringArray())
		if r3.ok:
			ok += 1
			assert_true(int(r3.ring) >= 2 * wr.verse_ring, "a skald's ring is double")
			assert_eq(Callings.verse_need(wr, j3.c.band, j3.c.world.place("fitjar")), wr.verse_difficulty + wr.verse_heard_harder,
					"and the lord who has heard him wants better next time")
			assert_eq(int(j3.c.band.deeds.get(Way.Id.SKALD, 0)), wr.deed_verse)
	assert_true(ok >= 15, "a skald's verse pleases more often than not: %d of 30" % ok)


func test_the_traders_edge_and_his_deeds() -> void:
	var j := Journey.begin(5, Way.Id.TRADER, "Ottar")
	var wr := j.c.world_rules
	var band := j.c.band
	var lade := j.c.world.place("lade")
	var good := WorldTypes.Good.FURS
	var stranger := Journey.begin(5, Way.Id.VIKING, "Egil").c.band
	var blades := WorldTypes.Good.FRANKISH_BLADES
	assert_eq(Market.buy_price(wr, lade, band, blades), Market.price(wr, lade, blades), "he buys at the price itself")
	assert_eq(Market.sell_price(wr, lade, band, blades), Market.price(wr, lade, blades), "and sells at it")
	assert_true(Market.buy_price(wr, lade, stranger, blades) > Market.price(wr, lade, blades), "a stranger pays the middlemen")
	assert_true(Market.sell_price(wr, lade, stranger, blades) < Market.price(wr, lade, blades), "both ways")
	# No round trip is free silver, for him or anyone: buy and sell back.
	for b in [band, stranger]:
		var before: int = b.silver
		b.silver += 500
		var n := Market.buy(wr, lade, b, good, 5, PackedStringArray())
		Market.sell(wr, lade, b, good, n, PackedStringArray())
		assert_true(b.silver - 500 <= before, "buying and selling back gains nothing")
		b.silver = before
	# Goods bought and sold at a margin count as a trader's deeds; loot does not.
	band.cargo[WorldTypes.Good.AMBER] = 4
	Market.sell(wr, lade, band, WorldTypes.Good.AMBER, 4, PackedStringArray())
	assert_eq(int(band.deeds.get(Way.Id.TRADER, 0)), 0, "loot sold is no trader's deed")
	band.bought[WorldTypes.Good.WINE] = [4, 4]
	band.cargo[WorldTypes.Good.WINE] = 4
	Market.sell(wr, lade, band, WorldTypes.Good.WINE, 4, PackedStringArray())
	assert_true(int(band.deeds.get(Way.Id.TRADER, 0)) > 0, "a margin on what he bought is")


func test_the_berserks_dread_makes_men_pay() -> void:
	var paid := 0
	for s in 60:
		var j := Journey.begin(300 + s, Way.Id.BERSERK, "Ljot")
		if Callings.holmgang_yields(SimRng.new(s), j.c.band):
			paid += 1
	assert_between(float(paid) / 60.0, 0.2, 0.5, "about one man in three pays")
	var plain := Journey.begin(1, Way.Id.VIKING, "Egil")
	assert_true(not Callings.holmgang_yields(SimRng.new(1), plain.c.band), "nobody pays a plain man")
	# A challenge without a feud costs honor; with one it does not, and a win ends it.
	var j2 := Journey.begin(9, Way.Id.BERSERK, "Ljot")
	var wr := j2.c.world_rules
	var farm := j2.c.world.place("sogn_farms")
	var terms := Callings.holmgang_terms(wr, j2.c.world, j2.c.band, farm)
	assert_true(not terms.feud and int(terms.honor_cost) == wr.holmgang_honor)
	j2.c.band.add_feud(farm.family, "a killing", farm.id)
	var lawful := Callings.holmgang_terms(wr, j2.c.world, j2.c.band, farm)
	assert_true(lawful.feud and int(lawful.honor_cost) == 0)
	Callings.after_holmgang(wr, j2.c.world, j2.c.band, farm, lawful, 1, false, PackedStringArray())
	assert_true(Feud.find(j2.c.band, farm.family).is_empty(), "the feud is ended on the island")


func test_a_summer_is_played_one_decision_at_a_time() -> void:
	var j := Journey.begin(11, Way.Id.VIKING, "Egil")
	j.quick = true
	# Spring: whatever must be answered first is answered.
	var guard := 0
	while not j.decisions.is_empty() and guard < 10:
		guard += 1
		j.answer(JourneyBot._answer(j, j.current()))
	assert_true(j.can_act(), "then the summer is his")
	var ids := []
	for a in j.actions():
		ids.append(a.id)
	assert_true(ids.has("listen") and ids.has("winter"), "at home: wait, or winter")
	assert_true(not ids.has("raid"), "nobody raids his own home")
	# Sail to the neighbours and raid them.
	assert_true(j.days_to("fitjar") > 0)
	j.sail("fitjar")
	guard = 0
	while not j.decisions.is_empty() and guard < 10:
		guard += 1
		j.answer(JourneyBot._answer(j, j.current()))
	if j.c.band.location == "fitjar" and j.can_act():
		ids = []
		for a in j.actions():
			ids.append(a.id)
		assert_true(ids.has("raid"), "a hall can be raided")
		j.act("raid")
		assert_eq(j.current().get("kind", ""), "fight", "the raid is offered as a fight first")
		var offer: FightOffer = j.current().offer
		assert_true(offer.attacking and offer.allows(FightOffer.Choice.FADE_AWAY))
		j.answer(str(FightOffer.Choice.FADE_AWAY))
		assert_true(j.can_act() or j.c.over, "he thought better of it")


func test_a_fight_can_be_handed_to_the_battle_view() -> void:
	var j := Journey.begin(11, Way.Id.VIKING, "Egil")
	j.quick = false
	var guard := 0
	while not j.decisions.is_empty() and guard < 10:
		guard += 1
		var d := j.current()
		j.answer("ignore" if d.kind == "spine" else str(d.options[0].id))
		if not j.fight.is_empty():
			break
	if j.fight.is_empty():
		j.sail("fitjar")
		if j.fight.is_empty() and j.decisions.is_empty() and j.c.band.location == "fitjar":
			j.act("raid")
			j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
	if not j.fight.is_empty():
		var battle: Battle = j.fight.built.battle
		assert_true(not j.can_act(), "nothing else until the fight is fought")
		# The view fights it; here the men are simply led off the field.
		assert_true(battle.withdraw(0))
		var lines := j.fight_done(battle.result)
		assert_true(j.fight.is_empty())
		assert_true(lines.size() >= 0)
		assert_true(j.can_act() or not j.decisions.is_empty() or j.c.over)


func test_every_way_plays_three_years_through() -> void:
	for way in Way.Id.values():
		var j := Journey.begin(21, way, "Egil")
		var years := 0
		for y in 3:
			if j.c.over:
				break
			var before := j.c.cal.year
			JourneyBot.play_year(j)
			if j.c.cal.year > before:
				years += 1
		var band := j.c.band
		print("    gate: %-12s %d years: %s, %d men, %d oz, fame %d honor %d, deeds %s%s" % [Way.name_of(way), years, Way.title(band),
				band.fighters().size(), band.silver, band.fame, band.honor, str(band.deeds), "  (ended: %s)" % j.c.over_reason if j.c.over else ""])
		assert_true(years >= 1 or j.c.over, "%s: the years turn" % Way.name_of(way))
		if not j.c.over and way != Way.Id.KINGS_MAN:
			assert_true(int(band.deeds.get(way, 0)) > 0, "%s: he has done the deeds of his way" % Way.name_of(way))
