extends TestCase
## Omens and the seer (Omens): heeding and ignoring move luck and the men's
## nerve; the seer's word is true for the seed. And the stand-in player
## lives five years of each bent with the law, the land and the unfree all
## on, without stalling, the same each time. See
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


func _omen(j: Journey, list: Array, id: String, when: String) -> Dictionary:
	for o in list:
		if str(o.id) == id:
			return Omens._decision(j, o, str(o.text).replace("%s", "Egil"), when)
	return {}


func test_luck_in_words() -> void:
	assert_eq(Omens.luck_words(9), "the gods are with him")
	assert_eq(Omens.luck_words(5), "his luck holds")
	assert_eq(Omens.luck_words(0), "his luck has left him")


func test_a_good_omen_heeded_is_luck_and_heart() -> void:
	var j := _quiet(2, "younger_son", "fitjar")
	var band := j.c.band
	band.add_man(Recruits.random(SimRng.new(1), j.c.rules, band.next_id()))
	var m := band.living_men()[0]
	var luck := band.luck
	var loyalty := m.loyalty
	j.decisions.push_front(_omen(j, Omens.SPRING, "raven", "spring"))
	j.answer("heed")
	assert_eq(band.luck, luck + 1)
	assert_eq(m.loyalty, loyalty + j.c.world_rules.omen_nerve, "the men take heart")


func test_an_ill_omen_heeded_costs_days_or_silver() -> void:
	var j := _quiet(2, "younger_son", "fitjar")
	var band := j.c.band
	var day := j.c.cal.day
	j.decisions.push_front(_omen(j, Omens.SPRING, "stumble", "spring"))
	j.answer("heed")
	assert_true(j.c.cal.day >= day + j.c.world_rules.omen_wait_days - 1, "days lost")
	band.silver = 50
	j.decisions.push_front(_omen(j, Omens.SPRING, "dream", "spring"))
	j.answer("heed")
	assert_eq(band.silver, 50 - j.c.world_rules.sacrifice_ounces, "a sacrifice")


func test_an_ill_omen_ignored_may_come_true() -> void:
	var lost := 0
	var kept := 0
	for s in 40:
		var j := _quiet(2, "younger_son", "fitjar")
		j.c.band.luck = 5
		j.life["lln"] = s * 13  # a different draw each time
		j.decisions.push_front(_omen(j, Omens.SPRING, "stumble", "spring"))
		j.answer("ignore")
		if j.c.band.luck < 5:
			lost += 1
		else:
			kept += 1
	print("    omens: ignored 40 times, came true %d" % lost)
	assert_between(float(lost) / 40.0, 0.1, 0.55, "about omen_chance of the time")
	assert_true(kept > 0)


func test_a_raid_omen_heeded_turns_the_band_back() -> void:
	var j := _quiet(3, "younger_son", "jaeren")
	j.c.world_rules.raid_omen_chance = 1.0
	j.act("raid")
	var d := j.current()
	assert_eq(str(d.kind), "omen", "the omen comes before the fight's choice")
	assert_eq(str(j.decisions[1].kind), "fight")
	if str(d.omen) == "fetch":
		j.answer("heed")
		assert_true(j.decisions.is_empty() or str(j.current().kind) != "fight", "no raid this year")
	else:
		j.answer("heed")
		assert_eq(str(j.current().kind), "fight", "an eagle heeded: in at once")


func test_the_seer_tells_true() -> void:
	var j := _quiet(4, "younger_son", "fitjar")
	var band := j.c.band
	band.silver = 100
	var next := j.c.cal.year + 1
	var fate := Omens.fate(j, next)
	assert_eq(Omens.fate(j, next), fate, "the fate of a year is the seed's")
	Omens.resolve_volva(j, {}, "ask")
	assert_eq(int(band.foretold.year), next)
	assert_eq(bool(band.foretold.early), bool(fate.early))
	assert_eq(str(band.foretold.raid_at), str(fate.raid_at))
	assert_eq(band.silver, 100 - j.c.world_rules.volva_fee)
	# Her early winter comes, asked or not.
	var early := -1
	var plain := -1
	for y in range(870, 900):
		if bool(Omens.fate(j, y).early):
			early = y if early < 0 else early
		elif plain < 0:
			plain = y
	assert_true(early > 0 and plain > 0, "some years have an early winter, some not")
	j.c.cal.day = 1
	j.c.cal.year = plain
	var long := j.days_left()
	j.c.cal.year = early
	assert_eq(j.days_left(), long - j.c.world_rules.early_winter_days, "the summer is short")
	# And the first raider ship to turn for a farm turns for hers.
	var j2 := _quiet(4, "younger_son", "fitjar")
	j2.life["fated_raid"] = "lier"
	var r := Roam.Party.new()
	r.kind = "raiders"
	r.family = "Augvald's kin"
	r.strike = "jaeren"
	j2.roam.parties.append(r)
	Omens.tick(j2)
	assert_eq(r.strike, "lier", "the raid falls where she said")
	r.strike = "jaeren"
	Omens.tick(j2)
	assert_eq(r.strike, "jaeren", "only the first")


func test_the_seer_comes_to_the_hall() -> void:
	var j := _quiet(5, "younger_son", "fitjar")
	j.c.world_rules.volva_chance = 1.0
	j.stepped_winter = true
	j.act("winter")
	assert_true(j.in_winter())
	var seer := false
	for card in j.winter_hall.talk:
		if str(card.kind) == "volva":
			seer = true
	assert_true(seer, "a seer in the hall's talk")


func test_the_bot_lives_five_years_of_each_bent_without_stalling() -> void:
	for way in Way.Id.values():
		var j := Journey.begin(31 + way, "burned_hall", "Egil")
		var years := 0
		for y in 5:
			if j.c.over:
				break
			var before := j.c.cal.year
			JourneyBot.play_year(j, way)
			assert_true(j.c.cal.year > before or j.c.over, "%s: no stall in %d" % [Way.name_of(way), before])
			years += 1
		var b := j.c.band
		print("    law-land: %-12s %d years, land %d, thralls %d, outlaw %d, cases %d, sold %d, honor %d, luck %d%s" % [Way.name_of(way), years, b.land,
				b.thralls.size(), b.outlawry, int(b.law.get("cases", 0)), int(b.law.get("sold", 0)), b.honor, b.luck, " (ended)" if j.c.over else ""])


func test_deterministic() -> void:
	var a := Journey.begin(9, "younger_son", "Egil")
	var b := Journey.begin(9, "younger_son", "Egil")
	for y in 2:
		JourneyBot.play_year(a, Way.Id.LAWMAN)
		JourneyBot.play_year(b, Way.Id.LAWMAN)
	assert_eq(a.said, b.said, "the same saga twice")
	assert_eq(a.c.band.law.keys(), b.c.band.law.keys())
