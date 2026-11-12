extends TestCase
## Battles 2 (docs/design/notes/battles-2.md): named lieutenants and their
## words, the strandhogg fought for its cattle, letting none out of a
## burning, the great battle's sector, barring the door against fire.


func _quiet(seed_in: int, origin := "younger_son") -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	j.quick = true
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		var d := j.current()
		j.answer(str(d.options[d.options.size() - 1].id))
	return j


func _campaign(seed_in: int, men: int) -> Campaign:
	var c := Campaign.new(seed_in)
	c.start_from("younger_son", "Egil")
	for i in men:
		c.band.add_man(Recruits.random(c.rng.fork("m%d" % i), c.rules, c.band.next_id()))
	c._arm_new_men()
	c._name_second_if_needed()
	return c


func _even(s: int) -> Dictionary:
	var rules := CombatRules.new()
	var r := SimRng.new(s).fork("t")
	var ours := BandFactory.make_mixed_band(r.fork("a"), 0, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(r.fork("b"), 1, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101)
	var sc := Scenario.build("equal_green", s, rules, true, 12, "meadow", {"ours": ours, "theirs": theirs}, {"objective": -1})
	(sc.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	return sc


func _shield_men(b: Battle, side: int, n: int) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for w in b.side_warriors(side):
		if not w.is_leader and w.role == CombatTypes.Role.SHIELD and out.size() < n:
			out.append(w)
	return out


# --- Named lieutenants -----------------------------------------------------------

func test_wings_are_given_where_the_men_stand_and_nobody_is_moved() -> void:
	var sc := _even(3)
	var b: Battle = sc.battle
	var before := {}
	for w in b.warriors:
		before[w] = w.pos
	var lts := _shield_men(b, 0, 2)
	var wings := Wing.form(b, 0, lts, [Wing.Word.PRESS, Wing.Word.HOLD_LINE], [Wing.Temper.PLAIN, Wing.Temper.STEADY])
	assert_eq(wings.size(), 2)
	for w in b.warriors:
		assert_eq(w.pos, before[w], "%s stands where he was formed" % w.display_name)
	assert_true(wings[0].hand != wings[1].hand, "a left and a right")
	for wing in wings:
		assert_true(wing.men.has(wing.lieutenant), "he is of his own wing")
		assert_between(float(wing.men.size()), 3.0, 5.0, "about a third of the line")
		assert_true(not wing.men.has(b.sworn_leader(0)), "the leader is nobody's wing")


func test_a_wing_with_no_word_changes_nothing() -> void:
	var a := _even(5)
	var b := _even(5)
	Wing.form(b.battle, 0, _shield_men(b.battle, 0, 2), [Wing.Word.NONE, Wing.Word.NONE], [0, 0])
	var ra := (a.battle as Battle).run()
	var rb := (b.battle as Battle).run()
	assert_eq(ra.winner, rb.winner)
	assert_eq(ra.rounds, rb.rounds)
	assert_eq(hash("\n".join((a.battle as Battle).log)), hash("\n".join((b.battle as Battle).log)), "the same fight, blow for blow")


func test_ordinary_fights_have_none_of_it() -> void:
	var sc := Scenario.build("equal_green", 4, CombatRules.new(), true, 12)
	var b: Battle = sc.battle
	assert_true(b.wings.is_empty())
	assert_true(b.arrivals.is_empty())
	assert_true(b.sector == null)
	assert_true(not b.barred)


func test_a_lieutenant_presses_when_they_waver_and_says_so() -> void:
	var sc := _even(7)
	var b: Battle = sc.battle
	var lt: Warrior = _shield_men(b, 0, 1)[0]
	var wings := Wing.form(b, 0, [lt], [Wing.Word.PRESS], [Wing.Temper.PLAIN])
	var wing: Wing = wings[0]
	b.run_round()
	assert_true(not wing.acting, "nothing to press yet")
	var guard := 0
	while wing._foes_near(b).is_empty() and guard < 12 and not b.is_over():
		guard += 1
		b.run_round()
	assert_true(not wing._foes_near(b).is_empty(), "the lines close")
	for e in b.active(1):
		e.morale = 4
	b.run_round()
	assert_true(wing.acting or wing.acted_round > 0, "he sees them waver")
	assert_true("\n".join(b.log).contains("%s sees them waver and takes the %s in" % [lt.display_name, wing.hand_name()]))


func test_tempers_judge_differently() -> void:
	assert_eq(Wing.temper_of([], PackedStringArray(["reckless in the fight"]), 3), Wing.Temper.RASH)
	assert_eq(Wing.temper_of([], PackedStringArray(["a steady hand"]), 3), Wing.Temper.STEADY)
	assert_eq(Wing.temper_of([CombatTypes.Personality.RECKLESS], PackedStringArray(), 3), Wing.Temper.RASH)
	assert_eq(Wing.temper_of([], PackedStringArray(), 7), Wing.Temper.CUNNING)
	# A rash man sees them waver at a heart a steady man thinks firm.
	var r := CombatRules.new()
	assert_true(float(r.wing_waver[Wing.Temper.RASH]) > float(r.wing_waver[Wing.Temper.STEADY]))


func test_a_fallen_lieutenant_leaves_his_wing_leaderless() -> void:
	var sc := _even(8)
	var b: Battle = sc.battle
	var lt: Warrior = _shield_men(b, 0, 1)[0]
	var wing: Wing = Wing.form(b, 0, [lt], [Wing.Word.HOLD_LINE], [0])[0]
	b.run_round()
	var hearts := {}
	for w in wing.men:
		hearts[w] = w.morale
	lt.wound = CombatTypes.Wound.DOWN
	b.grid.remove(lt)
	Wing.think(b)
	assert_true(wing.leaderless)
	assert_true("\n".join(b.log).contains("%s is down, and the %s wing has no one to lead it" % [lt.display_name, wing.hand_name()]))
	for w in wing.men:
		if w != lt:
			assert_true(w.morale < hearts[w] or w.morale == 0, "%s's heart sinks" % w.display_name)


func test_the_campaign_gives_its_second_a_wing_when_the_line_is_long_enough() -> void:
	var c := _campaign(11, 9)
	assert_true(c.band.sworn_second_id >= 0, "the band has a second")
	var o := c.offer_fight("raid", CombatTypes.Tier.GREEN, 8, true, 3, false, false, "open", {"cause": "rob"})
	o.they_know_first = false
	var built := c.build_fight(o, FightOffer.Choice.TAKE_THE_FIELD)
	var b: Battle = built.battle
	var ours := 0
	for wing in b.wings:
		if wing.side == 0:
			ours += 1
			assert_eq(wing.lieutenant.id, c.band.sworn_second_id, "the sworn second leads it")
			assert_true(wing.word != Wing.Word.NONE, "with a sensible word")
	assert_eq(ours, 1, "one wing under sixteen men")
	assert_true(bool(built.get("wings", false)), "the battle screen shows the sheet")
	var small := _campaign(12, 4)
	var o2 := small.offer_fight("raid", CombatTypes.Tier.GREEN, 4, true, 3, false, false, "open", {"cause": "rob"})
	o2.they_know_first = false
	assert_true((small.build_fight(o2, FightOffer.Choice.TAKE_THE_FIELD).battle as Battle).wings.is_empty(), "a few men need no wings")


# --- Men coming onto the field ---------------------------------------------------

func test_arrivals_come_onto_the_field_on_their_round() -> void:
	var rules := CombatRules.new()
	var sc := Scenario.build("equal_green", 6, rules, false, 6)
	var b: Battle = sc.battle
	var men := Scenario.hands(SimRng.new(1), 1, 3, CombatTypes.Tier.GREEN, rules, 901)
	var cells: Array[Vector2i] = [BattleGrid.from_offset(0, 0), BattleGrid.from_offset(1, 0), BattleGrid.from_offset(2, 0)]
	b.add_arrival(2, 1, men, cells, Vector2i(0, 1), "{n} more come")
	var before := b.warriors.size()
	b.run_round()
	assert_eq(b.warriors.size(), before, "not yet")
	b.run_round()
	assert_eq(b.warriors.size(), before + 3)
	assert_true(b.log.has("3 more come"))
	for w in men:
		assert_true(not w.is_leader)
		assert_eq(b.grid.occupant(w.pos), w)


# --- The strandhogg ----------------------------------------------------------------

func test_the_strandhogg_is_a_fight_for_cattle() -> void:
	var rules := CombatRules.new()
	var sc := Scenario.build_strandhogg(3, rules, {}, 6)
	var b: Battle = sc.battle
	var obj: Objective = b.objective
	assert_eq(obj.kind, Objective.Kind.CATTLE)
	assert_true(not obj.boats.is_empty())
	assert_true(not b.arrivals.is_empty(), "the district gathers on the clock")
	assert_true(not b.can_withdraw(0), "nobody gets aboard from the pasture")
	b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	var r := b.run()
	if r.winner == 0:
		assert_true(r.cattle > 0, "away with cattle")
		assert_true(obj.at_boats(b) or r.how == BattleResult.End.ROUT, "from the boats")
	assert_true(b.log.size() > 0 and "\n".join(b.log).contains("rounds up"))


func test_greed_waits_for_more_of_the_herd() -> void:
	var rules := CombatRules.new()
	var more := 0
	var less := 0
	for s in range(1, 9):
		var greedy := Scenario.build_strandhogg(s, rules, {}, 8, 1.0)
		var wary := Scenario.build_strandhogg(s, rules, {}, 8, 0.2)
		for sc in [greedy, wary]:
			(sc.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		more += (greedy.battle as Battle).run().cattle
		less += (wary.battle as Battle).run().cattle
	assert_true(more > less, "greed takes more of the herd (%d against %d)" % [more, less])


func test_the_journey_fights_the_strandhogg_and_tells_it() -> void:
	var j := _quiet(21)
	var p: Place = null
	for q in j.c.world.places.values():
		if (q as Place).kind == WorldTypes.PlaceKind.FARMSTEAD and (q as Place).is_open(j.c.world.year) and (q as Place).id != j.c.band.home:
			p = q
			break
	assert_true(p != null)
	for i in 5:
		j.c.band.add_man(Recruits.random(j.c.rng.fork("s%d" % i), j.c.rules, j.c.band.next_id()))
	j.c._arm_new_men()
	j._strandhogg(p)
	var d := j.current()
	assert_eq(str(d.kind), "fight")
	var offer: FightOffer = d.offer
	assert_eq(offer.cause, "strandhogg")
	assert_eq(offer.title(FightOffer.Choice.TAKE_THE_FIELD), "Go in for the cattle")
	var food := j.c.band.food
	j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))  # quick: the saga tells it
	assert_true(j.fight.is_empty(), "told by the dice")
	var told := "\n".join(j.said)
	assert_true(told.contains("head of cattle") or told.contains("without the cattle") or told.contains("nothing to show"), told.right(400))
	if told.contains("head of cattle"):
		assert_true(j.c.band.food > food, "the cattle feed the band")


# --- Let none out ---------------------------------------------------------------------

func test_before_the_fire_the_choice_is_asked() -> void:
	var j := _quiet(36, "burned_hall")
	var name := j.c.band.vengeance
	var about := j._about_fight({"kind": "reckoning", "family": name})
	var o := j.c.offer_fight("x", CombatTypes.Tier.GREEN, 8, true, 3, false, false, "farm", about)
	o.they_know_first = false
	j.decisions.clear()
	j._answer_fight({"kind": "fight", "offer": o, "ctx": {"kind": "reckoning", "family": name}}, FightOffer.Choice.BURN)
	var d := j.current()
	assert_eq(str(d.kind), "mercy")
	var ids := []
	for opt in d.options:
		ids.append(str(opt.id))
	assert_eq(ids, ["let_out", "none_out"])


func test_letting_none_out_is_a_nithing_s_deed() -> void:
	var j := _quiet(34, "burned_hall")
	var band := j.c.band
	var fs := j.c.world.families
	var wr := j.c.world_rules
	var name := band.vengeance
	var others := {}
	for n in fs.names():
		others[n] = Families.standing(band, n)
	var honor := band.honor
	var sc := Scenario.build_hall_burning(9, j.c.combat_rules)
	var b: Battle = sc.battle
	b.sworn_leader(1).wound = CombatTypes.Wound.DOWN
	b.result.winner = 0
	var ctx := {"kind": "reckoning", "family": name, "built": sc, "choice": FightOffer.Choice.BURN, "friends": [], "none_out": true}
	j._after_fight(ctx, b.result)
	var told := "\n".join(j.said)
	assert_true(not told.contains("were let out before the roof fell"), "nobody was let out")
	assert_true(told.contains("None were let out"))
	assert_true(told.contains("nithing"))
	assert_true(band.honor <= honor - wr.none_out_honor, "the honor goes")
	for n in fs.names():
		if n != name:
			assert_true(Families.standing(band, n) < int(others[n]), "%s think the worse of him" % n)
	var kin_feud := {}
	for f in band.feuds:
		if bool(f.get("no_silver", false)):
			kin_feud = f
	assert_true(not kin_feud.is_empty(), "their kin take up a feud")
	var fam := str(kin_feud.get("family", kin_feud.get("against", "")))
	band.silver = 10000
	assert_true(not Feud.settle(wr, band, fam, 10000, j.said), "no silver ends it")
	assert_true(band.chronicle.size() > 0 and "\n".join(band.chronicle).contains("let none out"), "the saga remembers")
	assert_eq(int(j.c.tally.get("nithing", 0)), 1)


func test_burners_may_let_none_of_the_household_out() -> void:
	var j := _quiet(40)
	var band := j.c.band
	band.wife = "Gudrun"
	band.sons.append({"name": "Ari", "born": j.c.cal.year - 4, "alive": true, "daughter": false, "father": band.leader.display_name, "fostered_with": ""})
	band.add_feud("Augvald's kin", "an insult", "")
	Feud.find(band, "Augvald's kin")["level"] = 3
	j.c.world_rules.enemy_none_out_chance = 1.0
	assert_true(j.burners_let_none_out("Augvald's kin"))
	assert_eq(band.wife, "")
	assert_true(not band.sons[-1].alive, "the child burned")
	assert_true(bool(Feud.find(band, "Augvald's kin").get("no_silver", false)))
	j.c.world_rules.enemy_none_out_chance = 0.0
	assert_true(not j.burners_let_none_out("Augvald's kin"), "the custom, as a rule")


# --- The great battle ------------------------------------------------------------------

func test_the_sector_holds_a_line_beyond_the_band() -> void:
	var rules := CombatRules.new()
	var r := SimRng.new(3).fork("t")
	var ours := BandFactory.make_mixed_band(r.fork("a"), 0, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(r.fork("b"), 1, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101)
	for ground in ["deck", "shore"]:
		var sc := Scenario.build_sector(3, rules, {"ours": ours.duplicate(), "theirs": theirs.duplicate()},
				{"ground": ground, "edge": 0.5, "battle_name": "Hafrsfjord", "banner": 1})
		var b: Battle = sc.battle
		var s: Sector = b.sector
		assert_eq(s.neighbours.size(), 2)
		var right := s.neighbour(1)
		right.state = -1
		var n := b.warriors.size()
		s.drift = 1.0
		s.edge = 0.0
		s.weight = 0.0
		s.round_end(b)
		assert_eq(int(right.state), -2, "the right breaks")
		assert_true(b.log.has("Harald's banner goes back with them") or b.log.has("the king's banner goes back with them"), "the banner stood there")
		b.run_round()
		assert_true(b.warriors.size() > n, "and the enemy come over onto the flank")
		var day := s.verdict(b)
		assert_true(s.final)
		assert_true(day == 1 or s.score <= 0.0, "a broken line loses the day")


func test_hafrsfjord_is_fought_on_the_ships_as_a_sector() -> void:
	var j := _quiet(7)
	var ev := {}
	for e in j.c.world_rules.spine:
		if str(e.id) == "hafrsfjord":
			ev = e
	var p := j._great_battle({"kind": "spine", "event": ev, "choice": "fight_for_harald"})
	assert_eq(str(p.ground), "deck")
	assert_eq(int(p.attacker), 0, "Harald's fleet comes on")
	assert_between(float(p.edge), 0.05, 0.95)
	var q := j._great_battle({"kind": "spine", "event": ev, "choice": "fight_against"})
	assert_true(absf(float(p.edge) + float(q.edge) - 1.0) < 0.001, "one side's lean is the other's lack")
	var about := j._about_fight({"kind": "spine", "event": ev, "choice": "fight_for_harald"})
	var o := j.c.offer_fight("spine", CombatTypes.Tier.VETERAN, 8, true, 3, false, false, "open", about)
	o.they_know_first = false
	var built := j.c.build_fight(o, FightOffer.Choice.TAKE_THE_FIELD)
	assert_eq(str(built.field_name), "sector")
	assert_true((built.battle as Battle).sector != null)


# --- Barring the door ----------------------------------------------------------------------

func test_the_barred_hall_is_held_at_its_doors() -> void:
	var rules := CombatRules.new()
	var sc := Scenario.build_hall_defence(4, rules, {}, true, "bar")
	var b: Battle = sc.battle
	assert_true(b.barred)
	var inside := 0
	var doors := 0
	for w in b.side_warriors(0):
		var t := b.grid.terrain_at(w.pos)
		if t == CombatTypes.Terrain.DOOR:
			doors += 1
		if BattleGrid.to_offset(w.pos).y >= b.grid.height - 2 - rules.bar_floor_rows:
			inside += 1
	assert_true(doors >= 1, "a man in the doorway")
	assert_eq(inside, b.side_warriors(0).size(), "the band is inside")
	assert_eq(b.objective.smoke_rounds, rules.bar_smoke_rounds, "the fire is a clock")
	# Help comes only once the door has held after the lines met.
	var help := {"men": Scenario.hands(SimRng.new(2), 0, 4, CombatTypes.Tier.BLOODED, rules, 4001), "line": "friends, {n}"}
	var sc2 := Scenario.build_hall_defence(4, rules, {"help": help}, true, "bar")
	var b2: Battle = sc2.battle
	b2.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
	var came := -1
	while not b2.is_over() and b2.round < 30:
		b2.run_round()
		if came < 0 and b2.log.has("friends, 4"):
			came = b2.round
	if came > 0:
		assert_true(b2.objective.clock_start >= 0 and came >= b2.objective.clock_start + rules.bar_help_round, "after the door held")


func test_the_campaign_sends_a_friendly_house_to_a_barred_hall() -> void:
	var j := _quiet(34, "burned_hall")
	var band := j.c.band
	var fs := j.c.world.families
	var friend := ""
	for n in fs.names():
		if n != band.vengeance:
			friend = n
			break
	Families.set_standing(band, friend, 80)
	var o := j.c.offer_fight("the fire at the hall", CombatTypes.Tier.BLOODED, 8, false, 3, false, true, "hall",
			{"cause": "hall", "house": band.vengeance, "burning": true})
	var help := j.c._hall_help(o, "bar", 5)
	assert_true(not help.is_empty())
	assert_true((help.men as Array).size() >= j.c.rules.hall_help_men)
	assert_true(j.c._hall_help(o, "meet", 5).is_empty(), "only for a barred door")
