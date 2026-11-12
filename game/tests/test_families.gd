extends TestCase
## The houses (Families, House): the web of kinship, marriage, fostering,
## friendship and feud between the families, the band's standing with
## each, what that standing does, the houses' own year, and the asks that
## make the band take sides.


func _world(seed_in := 1) -> World:
	var wr := WorldRules.new()
	var w := World.build_norway(wr, 866)
	Faction.load_all(w)
	w.families = Families.build(wr, w, seed_in)
	return w


func _band() -> Band:
	var b := Band.new()
	b.year = 866
	b.silver = 200
	return b


func _fingerprint(fs: Families) -> String:
	var bits := PackedStringArray()
	for n in fs.names():
		var h := fs.house(n)
		bits.append("%s/%s/%s/%s/%d/%d" % [n, h.head, h.heir, h.temper, h.strength, h.honor])
	var ks: Array = fs.pairs.keys()
	ks.sort()
	for k in ks:
		bits.append("%s=%s" % [k, str(fs.pairs[k])])
	return "|".join(bits)


func test_every_ruling_family_is_a_house_and_the_west_is_authored() -> void:
	var w := _world()
	var fs := w.families
	for p in w.places.values():
		if p.family != "":
			assert_true(fs.houses.has(p.family), "%s has a house" % p.family)
	var west := 0
	for n in fs.names():
		var h := fs.house(n)
		assert_true(h.head != "" and h.heir != "", "%s has a head and an heir" % n)
		assert_true(w.place(h.seat) != null, "%s has a seat" % n)
		assert_true(House.TEMPERS.has(h.temper), "%s has a temper" % n)
		if h.western:
			west += 1
	assert_between(west, 8, 12, "the western fjords have eight to twelve named houses")
	# At least two old feuds, a few marriages, one house everybody owes, one alone.
	var feuds := 0
	var marriages := 0
	for k in fs.pairs:
		var pr: Dictionary = fs.pairs[k]
		if pr.enmity == "feud":
			feuds += 1
		if (pr.bonds as Array).has("marriage"):
			marriages += 1
	assert_true(feuds >= 2, "two old feuds")
	assert_true(marriages >= 3, "a few marriage alliances")
	var owed := 0
	for t in fs.ties_of("Horda-Kari's kin"):
		if str(t.debtor) == str(t.other):
			owed += 1
	assert_true(owed >= 3 and fs.house("Horda-Kari's kin").creditor, "a house everybody owes")
	assert_true(fs.ties_of("Hrafn's kin").is_empty(), "a house that stands alone")


func test_the_web_is_deterministic_per_seed() -> void:
	assert_eq(_fingerprint(_world(5).families), _fingerprint(_world(5).families), "same seed, same web")
	assert_true(_fingerprint(_world(5).families) != _fingerprint(_world(6).families), "another seed, other heads and tempers")
	# And the years after it, too.
	var a := _world(5)
	var b := _world(5)
	var r := WorldRules.new()
	for y in 6:
		a.year = 866 + y
		b.year = 866 + y
		assert_eq(a.families.year_end(SimRng.new(40 + y), r, a, null), b.families.year_end(SimRng.new(40 + y), r, b, null))
	assert_eq(_fingerprint(a.families), _fingerprint(b.families))


func test_the_burned_hall_points_into_the_web() -> void:
	var j := Journey.begin(7, "burned_hall", "Egil")
	var fs := j.c.world.families
	var wr := j.c.world_rules
	var band := j.c.band
	var burners := j.c.world.place("hardanger").family
	assert_true(fs.houses.has(burners), "the burners are a house")
	assert_eq(band.vengeance, burners)
	assert_eq(Families.step_of(wr, band, burners), "blood-enemy")
	var kin := j.c.world.place("sogn_farms").family
	assert_true(fs.houses.has(kin) and kin != burners, "the kin in Sogn are a house of their own")
	assert_eq(Families.step_of(wr, band, kin), "kin")
	assert_true(fs.enemies_of(burners).has(kin), "and they have a grudge against the burners")
	assert_true(not fs.allies_of(burners).is_empty(), "the burners have allies")
	# The younger son is kin to the house at Hardanger.
	var y := Journey.begin(7, "younger_son", "Egil")
	assert_eq(Families.step_of(wr, y.c.band, burners), "kin")


func test_standing_spreads_along_ties_with_the_right_signs() -> void:
	var w := _world()
	var fs := w.families
	var wr := WorldRules.new()
	var b := _band()
	var moved := fs.shift(wr, b, "Augvald's kin", 40)
	assert_eq(Families.standing(b, "Augvald's kin"), 40)
	assert_eq(Families.standing(b, "Eirik of Hordaland's kin"), roundi(40 * wr.tie_spread.kin), "kin move with them")
	assert_eq(Families.standing(b, "the Sygna kings"), roundi(40 * wr.tie_spread.marriage), "and in-laws")
	assert_eq(Families.standing(b, "Rognvald's kin"), roundi(40 * wr.tie_spread.feud), "their enemies move the other way")
	assert_eq(Families.standing(b, "Hrafn's kin"), 0, "a house nothing ties to them is untouched")
	assert_true(moved.has("Rognvald's kin") and not moved.has("Hrafn's kin"))
	# One step out only: Rognvald's own friends are not moved by Augvald.
	assert_eq(Families.standing(b, "the Lade jarls"), 0)
	# A name that is no house is left alone.
	assert_true(fs.shift(wr, b, "Thorir Hound", -30).is_empty())


func test_helping_one_side_of_a_feud_costs_with_the_other() -> void:
	var j := Journey.begin(11, "younger_son", "Egil")
	j.quick = true
	var band := j.c.band
	var wr := j.c.world_rules
	j.decisions.clear()
	var d := {"kind": "house", "ask": "help", "house": "Rognvald's kin", "against": "Augvald's kin", "text": "", "options": []}
	var before_a := Families.standing(band, "Augvald's kin")
	var before_r := Families.standing(band, "Rognvald's kin")
	j.decisions.append(d)
	j.answer("stand")
	assert_true(not j.decisions.is_empty() and j.decisions[0].kind == "fight", "standing with them is a fight, through the usual offer")
	assert_eq(str(j.decisions[0].ctx.kind), "house_fight")
	# Win it, as the fight would be won.
	var res := BattleResult.new()
	res.winner = 0
	j.decisions.clear()
	j._after_house_fight({"kind": "house_fight", "client": "Rognvald's kin", "family": "Augvald's kin"}, res)
	assert_true(Families.standing(band, "Rognvald's kin") > before_r, "the house helped thinks the better of him")
	assert_true(Families.standing(band, "Augvald's kin") < before_a, "the other side the worse")
	assert_true(Families.standing(band, "Eirik of Hordaland's kin") < 0, "and so do the other side's kin")
	# Carrying an offer of settlement: a feud between them goes to the settlement.
	var fs := j.c.world.families
	assert_true(fs.at_feud("Augvald's kin", "Rognvald's kin"))
	fs.settle_between("Augvald's kin", "Rognvald's kin")
	assert_eq(int(fs.pair("Augvald's kin", "Rognvald's kin").ledger.step), 4)
	assert_eq(wr.house_feud_steps[4], "a settlement")


func test_the_thing_counts_allies_on_both_sides() -> void:
	var w := _world()
	var fs := w.families
	var wr := WorldRules.new()
	var b := _band()
	b.leader = Man.new()
	var against := "Hardanger-Atli's kin"
	var plain := fs.thing_backing(wr, b, against)
	assert_true((plain.against as Array).has("Rognvald's kin"), "their in-laws stand with them")
	assert_true((plain.against as Array).has("Thorir Long-chin's kin"), "and their sworn friends")
	assert_true((plain.with as Array).has("Horda-Kari's kin"), "their creditor, who has a grudge against them, stands with the band")
	# Their enemies stand with a band that is no ill-wisher of theirs.
	assert_true((plain.with as Array).has("Ulfar's kin"), "the burners' enemies stand with the band")
	# Friends count more, and a friend of the band among their allies stays home.
	Families.set_standing(b, "Augvald's kin", wr.standing_friend)
	Families.set_standing(b, "Rognvald's kin", wr.standing_friend)
	var friendly := fs.thing_backing(wr, b, against)
	assert_true(int(friendly.ours) > int(plain.ours), "friends bring supporters")
	assert_true(int(friendly.theirs) < int(plain.theirs), "an ally of theirs who is the band's friend stays home")
	assert_true(not (friendly.against as Array).has("Rognvald's kin"))
	# A debtor never stands against the house it owes, friend of the band or not.
	Families.set_standing(b, "Thorir Long-chin's kin", wr.standing_sworn)
	var owed := fs.thing_backing(wr, b, "Horda-Kari's kin")
	assert_true(not (owed.with as Array).has("Thorir Long-chin's kin"), "a debtor stays home")
	# And it is what the Thing weighs.
	var c := Thing.open_case(wr, b, WorldTypes.CaseKind.KILLING, against, 40, true)
	Thing.gather_support(SimRng.new(1), wr, w, b, c, 0, PackedStringArray())
	assert_true(c.houses_with.has("Ulfar's kin"), "the case names who stood with the band")
	var c2 := Thing.open_case(wr, _band(), WorldTypes.CaseKind.KILLING, against, 40, true)
	Thing.gather_support(SimRng.new(1), wr, w, _band(), c2, 0, PackedStringArray())
	assert_true(c2.houses_against.has("Rognvald's kin"), "and with the other side")
	assert_true(c2.their_supporters > c.their_supporters, "who count for them")


func test_the_yearly_step_never_contradicts_itself() -> void:
	var r := WorldRules.new()
	for s in 12:
		var w := _world(s)
		var b := _band()
		for y in 20:
			w.year = 866 + y
			var told := w.families.year_end(SimRng.new(s * 100 + y), r, w, b)
			assert_true(told.size() <= r.tidings_max, "a handful of tidings a year")
			assert_eq(w.families.contradictions(), PackedStringArray(), "never at feud and sworn friends at once")
			for k in w.families.pairs:
				var pr: Dictionary = w.families.pairs[k]
				assert_true(pr.a < pr.b, "pairs are kept in order, so ties are symmetric")
				if pr.enmity == "feud":
					assert_between(int(pr.ledger.step), 1, 4, "an open feud stands at a step")
	# A sworn friendship is not made across a feud.
	var w2 := _world()
	assert_true(not w2.families.add_tie("Augvald's kin", "Rognvald's kin", "friend"))
	assert_true(w2.families.add_tie("Hardanger-Atli's kin", "Thorir Long-chin's kin", "feud"))
	assert_true(not w2.families.has_tie("Hardanger-Atli's kin", "Thorir Long-chin's kin", "friend"), "a feud breaks the friendship")


func test_the_houses_live_their_own_years() -> void:
	var r := WorldRules.new()
	var lines := 0
	var deaths := 0
	var burnings := 0
	var settled := 0
	for s in 8:
		var w := _world(s)
		for y in 10:
			w.year = 866 + y
			for line in w.families.year_end(SimRng.new(s * 31 + y), r, w, null):
				lines += 1
				if line.contains("died in his bed"):
					deaths += 1
				if line.contains("burned"):
					burnings += 1
				if line.contains("held, and the feud is over"):
					settled += 1
	print("    houses: %.1f tidings a year; in 80 years %d deaths, %d burnings, %d settlements held" % [lines / 80.0, deaths, burnings, settled])
	assert_between(lines / 80.0, 1.5, float(r.tidings_max), "a handful of tidings a year")
	assert_true(deaths > 0 and settled > 0, "heads die and settlements hold")


func test_marriage_ties_the_band_to_a_house_and_its_quarrels() -> void:
	var j := Journey.begin(3, "younger_son", "Egil")
	var band := j.c.band
	j.decisions.clear()
	band.wife = ""
	var d := {"kind": "house", "ask": "marry", "house": "Augvald's kin", "bride": "Thora", "text": "", "options": []}
	j.decisions.append(d)
	j.answer("accept")
	assert_true(band.wife.begins_with("Thora"), "she is his wife")
	assert_true((band.house_ties["Augvald's kin"] as Array).has("marriage"))
	assert_eq(Families.step_of(j.c.world_rules, band, "Augvald's kin"), "well-wisher", "a marriage is a strong gain")
	assert_true(Families.standing(band, "Eirik of Hordaland's kin") > 0, "with their kin too")
	assert_true(Families.standing(band, "Rognvald's kin") < 0, "and their feud is partly his")
	# A killing done to his in-laws costs the killers his standing.
	var fs := j.c.world.families
	var before := Families.standing(band, "Rognvald's kin")
	fs._kill(j.c.world_rules, band, fs.pair("Augvald's kin", "Rognvald's kin"), "Rognvald's kin", "Augvald's kin")
	assert_true(Families.standing(band, "Rognvald's kin") < before)


func test_wergild_settles_a_feud_and_mends_the_standing() -> void:
	var j := Journey.begin(4, "younger_son", "Egil")
	var band := j.c.band
	var wr := j.c.world_rules
	j.decisions.clear()
	var fam := "Thorir Long-chin's kin"
	Feud.start(wr, band, fam, "a slain karl", "jaeren", PackedStringArray())
	j._settle()
	assert_true(Families.standing(band, fam) <= wr.standing_feud_cap, "a feud holds the standing down")
	var low := Families.standing(band, fam)
	# They offer wergild for his dead man, and he takes it.
	j.decisions.append({"kind": "house", "ask": "compensation", "house": fam, "ounces": 30, "text": "", "options": []})
	var silver := band.silver
	j.answer("take")
	assert_true(Feud.find(band, fam).is_empty(), "the feud is ended")
	assert_eq(band.silver, silver + 30)
	assert_eq(Families.standing(band, fam), low + wr.standing_settled, "and the standing mends a little")
	# Paying it at their seat ends a feud he owes for.
	Feud.start(wr, band, "Eirik of Hordaland's kin", "raid on Hafrsfjord", "hafrsfjord", PackedStringArray())
	band.silver = 500
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["hafrsfjord"])
	j.c.band.location = "hafrsfjord"
	var ids := {}
	for a in j.actions():
		ids[a.id] = a
	assert_true(ids.has("wergild") and ids.has("reckoning"), "wergild or the reckoning, at their seat")
	j.act("wergild")
	assert_true(Feud.find(band, "Eirik of Hordaland's kin").is_empty())


func test_standing_opens_and_shuts_doors() -> void:
	var j := Journey.begin(4, "younger_son", "Egil")
	var band := j.c.band
	var wr := j.c.world_rules
	var p := j.c.world.place("fitjar")
	var fam := p.family
	Families.set_standing(band, fam, wr.standing_friend)
	assert_eq(Families.shelter(wr, band, p), "free")
	assert_eq(Families.party_mood(wr, band, fam), 1, "their ships leave a friend alone")
	assert_eq(Families.spread_off(wr, band, p), wr.friend_spread_off, "and their market deals at the true price")
	Families.set_standing(band, fam, wr.standing_blood_enemy)
	assert_eq(Families.shelter(wr, band, p), "shut")
	assert_eq(Families.party_mood(wr, band, fam), -1, "and hunt a blood-enemy")
	assert_eq(Families.foe_factor(wr, band, p), wr.foe_price)
	# A gift is worth less the second time in a year.
	Families.set_standing(band, fam, 0)
	band.silver = 100
	var first := j.c.world.families.give_gift(wr, j.c.world, band, fam, PackedStringArray())
	var second := j.c.world.families.give_gift(wr, j.c.world, band, fam, PackedStringArray())
	assert_eq(first, wr.standing_gift)
	assert_true(second < first, "diminishing returns")
	assert_eq(band.silver, 100 - 2 * wr.gift_ounces)


func test_killing_a_houses_men_may_bring_a_feud() -> void:
	var feuds := 0
	for s in 20:
		var j := Journey.begin(30 + s, "younger_son", "Egil")
		var band := j.c.band
		var res := BattleResult.new()
		res.winner = 0
		res.dead = [0, 2]
		var fam := "Augvald's kin"
		var before := Families.standing(band, fam)
		j._killed_their_men({"kind": "sea", "family": fam}, res)
		assert_eq(Families.standing(band, fam), before + 2 * j.c.world_rules.standing_per_kill, "each man killed costs standing")
		if not Feud.find(band, fam).is_empty():
			feuds += 1
	assert_between(feuds, 4, 16, "about half the time their kin take it up")


func test_the_report_is_plain_values() -> void:
	var j := Journey.begin(7, "burned_hall", "Egil")
	var rows := j.c.world.families.report(j.c.world_rules, j.c.world, j.c.band)
	assert_eq(rows.size(), j.c.world.families.houses.size())
	assert_eq(str(rows[0].name), j.c.band.vengeance, "the house he is at feud with comes first")
	for r in rows:
		for k in ["name", "head", "heir", "seat", "seat_name", "temper", "strength", "honor", "standing", "step", "ties", "your_ties", "feud", "told", "known"]:
			assert_true(r.has(k), "a row has %s" % k)
		assert_true(r.ties is PackedStringArray)
	assert_true(str(rows[0].feud) != "")


func test_the_bot_plays_three_years_of_each_bent_with_the_houses() -> void:
	var moved := 0
	for way in Way.Id.values():
		var j := Journey.begin(21 + way, "burned_hall", "Egil")
		for y in 3:
			if j.c.over:
				break
			var before := j.c.cal.year
			JourneyBot.play_year(j, way)
			assert_true(j.c.over or j.c.cal.year > before, "%s: the year turns (no stall)" % Way.name_of(way))
		assert_eq(j.c.world.families.contradictions(), PackedStringArray())
		var n := 0
		for k in j.c.band.standing:
			if int(j.c.band.standing[k]) != 0:
				n += 1
		moved += n
		assert_true(not j.c.world.families.tidings.is_empty() or j.c.over, "the houses had their years")
	assert_true(moved > 6 * 3, "standings moved")
