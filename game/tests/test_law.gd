extends TestCase
## The Thing played (ThingPlay) and outlawry that bites (Outlawry): a
## case's steps and each branch, the cost of overreach, the one predicate
## that shuts an outlaw's doors, the bounty hunters, Rollo's exile. See
## docs/design/notes/law-land.md.

const FOE := "Augvald's kin"


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


## A band at the Gulathing with a feud over a killing of its own.
func _at_thing(seed_in := 3, cause := "the killing of a man of yours") -> Journey:
	var j := _quiet(seed_in, "younger_son", "gulathing")
	j.c.band.silver = 300
	Feud.start(j.c.world_rules, j.c.band, FOE, cause, "avaldsnes", j.said)
	return j


func _won() -> BattleResult:
	var r := BattleResult.new()
	r.winner = 0
	return r


## Opens the case and pleads it with the band's own leader; the decision
## after the pleading is waiting.
func _pleaded(j: Journey) -> void:
	j.act("case:" + FOE)
	j.answer("go")
	j.answer("self")


## Sets the weights of the case in hand so the plaintiff's ratio is `ratio`.
func _weights(j: Journey, ratio: float, their_armed := 0) -> void:
	var s: Dictionary = j.life.case
	var tc: ThingCase = s.tc
	s.slip = false
	s.their_slip = false
	var ours := j.c.band.fighters(j.c.rules).size()
	tc.their_armed = their_armed
	tc.their_supporters = 10
	var them := 10.0 + their_armed * j.c.world_rules.arms_weight
	if tc.plaintiff_is_band:
		tc.supporters = roundi(them * ratio - ours * j.c.world_rules.arms_weight)
	else:
		tc.supporters = roundi(them / ratio - ours * j.c.world_rules.arms_weight)


func test_a_case_is_four_steps_through_the_queue() -> void:
	var j := _at_thing()
	var band := j.c.band
	var ids := {}
	for a in j.actions():
		ids[a.id] = a
	assert_true(ids.has("case:" + FOE), "a feud can be pleaded at a Thing")
	j.act("case:" + FOE)
	var d := j.current()
	assert_eq(str(d.kind), "thing")
	assert_eq(str(d.step), "support")
	assert_true(str(d.detail).contains("With you") and str(d.detail).contains("under arms"), "the counts in words: " + str(d.detail))
	j.answer("spend")
	assert_eq(int(j.life.case.spent), 10, "silver laid out for oath-helpers")
	assert_eq(str(j.current().step), "support", "the support step comes back after each choice")
	var silver := band.silver
	j.answer("go")
	assert_eq(band.silver, silver - 10, "the oath-helpers are paid when the case goes to the law")
	d = j.current()
	assert_eq(str(d.step), "law")
	var opts := {}
	for o in d.options:
		opts[str(o.id)] = o
	assert_true(opts.has("self") and opts.has("hire") and opts.has("keep"), "plead, hire or keep the Gulathing's law-man")
	assert_true(str(opts.hire.label).contains("Thorleif the Wise"), "the law-man by name")
	silver = band.silver
	j.answer("hire")
	assert_eq(band.silver, silver - j.c.world_rules.lawman_hire_fee)
	assert_true((j.life.case.tc as ThingCase).lawman_hired, "ThingCase.lawman_hired is set at last")
	d = j.current()
	assert_true(str(d.step) == "standoff" or str(d.step) == "verdict")
	var guard := 0
	while j.life.has("case") and guard < 6:
		guard += 1
		j.answer(str(j.current().options[0].id))
	assert_true(not j.life.has("case"), "the case closes")
	assert_eq(int(j.c.tally.thing_cases), 1)
	var again := false
	for a in j.actions():
		if str(a.id) == "case:" + FOE:
			again = true
	assert_true(not again, "one hearing a summer")


func test_waverers_won_with_a_gift_or_a_promise() -> void:
	var j := _at_thing(5)
	j.act("case:" + FOE)
	var before := (j.life.case.tc as ThingCase).supporters
	var waver := ThingPlay.waverers(j)
	assert_true(not waver.is_empty(), "some house stands with neither side")
	var w: Dictionary = waver[0]
	var id := ("gift:" if str(w.wants) == "gift" else ("promise:" if str(w.wants) == "promise" else "marry:")) + str(w.house)
	j.answer(id)
	assert_true((j.life.case.bought as Array).has(str(w.house)), "the house stands with the band now")
	ThingPlay._preview(j)
	assert_true((j.life.case.tc as ThingCase).supporters > before, "one supporter more at least")
	if str(w.wants) == "promise":
		assert_true((j.c.band.law.owed as Dictionary).has(str(w.house)), "a favour owed")


func test_a_law_wise_man_of_ones_own() -> void:
	var j := _at_thing()
	_men(j, 3)
	var wr := j.c.world_rules
	var best: Man = null
	for m in j.c.band.living_men():
		if best == null or m.stat(CombatTypes.Stat.WITS) > best.stat(CombatTypes.Stat.WITS) \
				or (m.stat(CombatTypes.Stat.WITS) == best.stat(CombatTypes.Stat.WITS) and m.id < best.id):
			best = m
	for i in wr.law_sat_cases:
		ThingPlay._sat_through(j, "self")
	assert_true(best.traits.has(wr.law_wise_trait), "a man who sits through cases learns the law")
	# Or the law-man kept.
	var j2 := _at_thing(4)
	j2.act("case:" + FOE)
	j2.answer("go")
	var n := j2.c.band.living_men().size()
	j2.answer("keep")
	assert_eq(j2.c.band.living_men().size(), n + 1)
	var kept := false
	for m in j2.c.band.living_men():
		if m.display_name == "Thorleif the Wise" and m.traits.has(wr.law_wise_trait):
			kept = true
	assert_true(kept, "the law-man stays, law-wise")
	assert_true(ThingPlay.lawman_name(j2) == "" or not j2.life.has("case"), "he is not for hire any more")


func test_the_chance_in_words() -> void:
	assert_eq(ThingPlay.chance(3, 10), 21.0 / 36.0)
	assert_eq(ThingPlay.odds_words(0.6), "about 6 times in 10")
	assert_eq(ThingPlay.odds_words(1.0), "all but surely")


func test_the_standoff_press_yields_or_comes_to_blows() -> void:
	var yields := 0
	var brawls := 0
	for s in 12:
		var j := _at_thing(10 + s)
		_men(j, 9)
		_pleaded(j)
		_weights(j, 0.8, 2)
		assert_true(ThingPlay.standoff_due(j), "the verdict leans against the side with more spears")
		var honor := j.c.band.honor
		j.decisions.clear()
		j.decisions.push_front(ThingPlay._standoff_decision(j))
		j.answer("press")
		if j.life.has("case"):
			yields += 1
			assert_eq(str(j.current().step), "verdict")
			assert_eq(j.c.band.honor, honor - j.c.world_rules.press_honor, "overbearing at the Thing")
		else:
			brawls += 1
			assert_eq(str(j.current().kind), "fight", "the brawl is handed to the fight")
			assert_eq(str((j.current().ctx as Dictionary).kind), "thing")
			assert_eq(j.c.band.honor, honor - j.c.world_rules.press_honor - j.c.world_rules.thing_violence_honor)
	print("    law: pressed with 9 spears to 2, they gave way %d of 12, blows %d" % [yields, brawls])
	assert_true(yields > brawls and brawls >= 0)


func test_arbitration_by_the_house_everyone_owes() -> void:
	var j := _at_thing()
	_men(j, 9)
	_pleaded(j)
	_weights(j, 0.8, 2)
	var silver := j.c.band.silver
	var arb := Families.standing(j.c.band, j.c.world_rules.arbiter_house)
	j.decisions.clear()
	j.decisions.push_front(ThingPlay._standoff_decision(j))
	j.answer("arbiter")
	assert_true(not j.life.has("case"))
	assert_eq(j.c.band.silver, silver - j.c.world_rules.arbiter_fee, "a plaintiff who would have lost is given nothing")
	assert_true(Feud.find(j.c.band, FOE).is_empty(), "the feud is settled")
	assert_true(Families.standing(j.c.band, j.c.world_rules.arbiter_house) > arb, "the arbiters are honoured")


func test_a_fair_verdict_against_a_harsh_one_and_overreach() -> void:
	var wr := WorldRules.new()
	var results := {}
	for ask in ["wergild", "lesser", "full"]:
		var j := _at_thing()
		_pleaded(j)
		_weights(j, 1.7)
		var band := j.c.band
		var honor := band.honor
		var silver := band.silver
		var kin := Families.standing(band, "Eirik of Hordaland's kin")  # Augvald's kin's kin
		var foe := Families.standing(band, FOE)
		j.decisions.clear()
		j.decisions.push_front(ThingPlay._verdict_decision(j))
		j.answer(ask)
		results[ask] = {"honor": band.honor - honor, "silver": band.silver - silver, "kin": Families.standing(band, "Eirik of Hordaland's kin") - kin,
				"foe_settled": Feud.find(band, FOE).is_empty(), "foe": foe}
	assert_eq(int(results.wergild.honor), wr.fair_verdict_honor, "a fair verdict is honor")
	assert_true(int(results.wergild.silver) > 0, "and silver")
	assert_true(int(results.lesser.kin) < int(results.wergild.kin), "their kin resent outlawry more than wergild")
	assert_eq(int(results.full.silver), int(results.wergild.silver), "full outlawry asked beyond the case's weight: wergild given")
	assert_true(int(results.full.kin) < int(results.wergild.kin), "and the asking resented")
	for k in results:
		assert_true(bool(results[k].foe_settled), "%s settles the feud" % k)


func test_losing_pay_defy_or_appeal() -> void:
	for how in ["pay", "defy", "appeal"]:
		var j := _at_thing(6, "raid on the Jæren farms")
		var band := j.c.band
		if how == "appeal":
			FactionAI.shift(j.c.world, "hordaland", FactionAI.BAND, 60)
		_pleaded(j)
		assert_true(not (j.life.case.tc as ThingCase).plaintiff_is_band, "a raid case: the band answers it")
		_weights(j, 1.3)
		j.decisions.clear()
		j.decisions.push_front(ThingPlay._verdict_decision(j))
		var opts := {}
		for o in j.current().options:
			opts[str(o.id)] = o
		assert_true(opts.has("pay") and opts.has("defy"))
		assert_eq(opts.has("appeal"), how == "appeal", "an appeal only for the king's man")
		var silver := band.silver
		j.answer(how)
		match how:
			"pay":
				assert_true(band.silver < silver, "wergild paid")
				assert_eq(band.outlawry, WorldTypes.Outlawry.NONE)
				assert_true(Feud.find(band, FOE).is_empty())
			"defy":
				assert_eq(band.outlawry, WorldTypes.Outlawry.FULL, "defying the Thing is full outlawry")
			"appeal":
				assert_eq(band.outlawry, WorldTypes.Outlawry.NONE)
				assert_true(band.silver < silver)


func test_speaking_for_a_house_is_played_too() -> void:
	var j := _quiet(3, "younger_son", "gulathing")
	j.c.band.silver = 200
	j.c.band.pledges["Eirik of Hordaland's kin"] = {"against": "Thorir Long-chin's kin", "year": j.c.cal.year}
	j.act("speak:Eirik of Hordaland's kin")
	assert_eq(str(j.current().kind), "thing")
	assert_eq((j.life.case.tc as ThingCase).client, "Eirik of Hordaland's kin")
	var guard := 0
	while j.life.has("case") and guard < 8:
		guard += 1
		var d := j.current()
		j.answer("go" if str(d.step) == "support" else str(d.options[0].id))
	assert_true(not j.life.has("case"))
	assert_true(not j.c.band.pledges.has("Eirik of Hordaland's kin"), "the promise is kept")


func test_a_summons_ignored_is_outlawry() -> void:
	var j := _at_thing(3, "raid on the Jæren farms")
	ThingPlay.answer_spring(j, {"step": "summons", "house": FOE}, "ignore")
	ThingPlay.judge_absent(j)
	assert_eq(j.c.band.outlawry, WorldTypes.Outlawry.LESSER, "judged without him")
	# Answered, it can be pleaded at the Thing.
	var j2 := _at_thing(3, "raid on the Jæren farms")
	ThingPlay.answer_spring(j2, {"step": "summons", "house": FOE}, "answer")
	var found := false
	for a in j2.actions():
		if str(a.id) == "answer:" + FOE:
			found = true
	assert_true(found, "answer the summons at the Thing")
	j2.act("answer:" + FOE)
	assert_eq(str(j2.current().step), "support")


func test_old_automatic_thing_still_runs() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := Band.new()
	var l := Man.new()
	l.is_leader = true
	b.leader = l
	b.silver = 100
	var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FOE, 30, true)
	var v := Thing.run(SimRng.new(1), r, w, b, c, 20, PackedStringArray())
	assert_true(v != WorldTypes.Verdict.PENDING, "Thing.run stays the AI's path")


# --- Outlawry -------------------------------------------------------------------------

func test_one_predicate_shuts_every_door_to_a_full_outlaw() -> void:
	var j := _quiet(2, "younger_son", "fitjar")
	var band := j.c.band
	band.silver = 300
	band.ship = null
	band.fighters()[0].healing_turns = 0
	var m := Recruits.random(SimRng.new(9), j.c.rules, band.next_id())
	m.healing_turns = 3
	band.add_man(m)
	var open := {}
	for a in j.actions():
		open[str(a.id)] = a.get("enabled", true)
	Outlawry.declare(j.c.world_rules, band, j.c.cal, true, j.said)
	var p := j.here()
	for door in ["winter", "rest", "passage", "hire", "market", "work", "shelter", "thing"]:
		assert_true(Outlawry.door_shut(j, p, door) != "", "%s is shut to a full outlaw in Norway" % door)
	var shut := {}
	for a in j.actions():
		shut[str(a.id)] = a
	for id in shut:
		var door := Outlawry.door_of(str(id))
		if door != "":
			assert_true(not shut[id].get("enabled", true), "%s greyed" % id)
	assert_true(shut.has("winter") and not shut.winter.enabled, "no winter at Fitjar")
	assert_true(j.market().is_empty(), "no market")
	assert_eq(j.buy(WorldTypes.Good.GRAIN, 1), 0)
	var said := j.said.size()
	j.act("rest")
	assert_true(j.said[said].contains("full outlaw"), "the deed itself asks the same predicate")
	# Abroad, the law does not reach.
	var dub := j.c.world.place("dublin")
	for door in ["winter", "rest", "passage", "hire", "market", "work"]:
		assert_eq(Outlawry.door_shut(j, dub, door), "", "%s is open at Dublin" % door)
	# A sworn friend will hide him for the winter.
	Families.set_standing(band, "Horda-Kari's kin", 90)
	assert_eq(Outlawry.door_shut(j, p, "winter"), "")
	assert_true(Outlawry.door_shut(j, p, "market") != "")


func test_a_lesser_outlaw_may_provision_and_go() -> void:
	var j := _quiet(2, "younger_son", "fitjar")
	var band := j.c.band
	Outlawry.declare(j.c.world_rules, band, j.c.cal, false, j.said)
	var p := j.here()
	for door in ["passage", "market", "rest"]:
		assert_eq(Outlawry.door_shut(j, p, door), "", door)
	for door in ["winter", "work", "hire"]:
		assert_true(Outlawry.door_shut(j, p, door) != "", door)
	Outlawry.on_winter(j, p)
	assert_eq(band.outlawry, WorldTypes.Outlawry.FULL, "he did not leave Norway by the winter")
	var j2 := _quiet(2, "younger_son", "fitjar")
	Outlawry.declare(j2.c.world_rules, j2.c.band, j2.c.cal, false, j2.said)
	Outlawry.on_winter(j2, j2.c.world.place("orkney"))
	assert_eq(j2.c.band.outlawry, WorldTypes.Outlawry.LESSER)
	assert_eq(int(j2.c.band.law.exile_winters), 1, "a winter of his time served")


func test_bounty_hunters_hunt_and_go_home_on_pardon() -> void:
	var j := _quiet(4, "younger_son", "sogn_farms")
	var band := j.c.band
	band.fame = 60
	j.c.world_rules.hunters_chance = 1.0
	Outlawry.declare(j.c.world_rules, band, j.c.cal, true, j.said)
	Outlawry.spring(j)
	var hunters: Array = j.roam.parties.filter(func(p: Roam.Party) -> bool: return p.kind == "hunters")
	assert_true(hunters.size() >= 1, "hunters out after him")
	var h: Roam.Party = hunters[0]
	assert_eq(h.men, j.c.world_rules.hunters_base + 60 / j.c.world_rules.hunters_per_fame, "more of them for his fame")
	assert_eq(h.mood, -1)
	# They come for him wherever he is in the realm.
	j.c.band.location = ""
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["sogn_farms"]) + Vector2(2, 0)
	var met: Roam.Party = null
	for i in 400:
		met = j.roam.step_parties(0.25, SimRng.new(i), j.c.world_rules, j.c.world, 3, "")
		if met == h:
			break
	assert_true(met == h, "they track him down")
	j._meet(h)
	assert_eq(str(j.current().kind), "fight")
	assert_eq(str((j.current().ctx as Dictionary).what), "hunters")
	j.decisions.clear()
	Outlawry.pardon(j, "Egil pays for his peace")
	assert_eq(band.outlawry, WorldTypes.Outlawry.NONE)
	assert_eq(j.roam.parties.filter(func(p: Roam.Party) -> bool: return p.kind == "hunters").size(), 0, "they go home")


func test_the_grettir_clause_and_the_kings_pardon() -> void:
	var j := _quiet(4, "younger_son", "kaupang")
	var band := j.c.band
	Outlawry.declare(j.c.world_rules, band, j.c.cal, true, j.said)
	for i in j.c.world_rules.grettir_kills:
		Outlawry.after_fight(j, {"kind": "sea", "req": {"kind": "outlaws"}}, _won())
	assert_eq(band.outlawry, WorldTypes.Outlawry.NONE, "three outlaws killed, his peace earned")
	Outlawry.declare(j.c.world_rules, band, j.c.cal, true, j.said)
	band.silver = 500
	var ids := {}
	for a in j.actions():
		ids[str(a.id)] = a
	assert_true(ids.has("pardon_silver") and ids.has("pardon_service"), "at the king's hall at Kaupang")
	j.act("pardon_silver")
	assert_eq(band.outlawry, WorldTypes.Outlawry.NONE)
	assert_eq(band.silver, 500 - Outlawry.pardon_price(j.c.world_rules, band))


func test_rollos_exile_takes_the_band_west() -> void:
	var j := _quiet(5, "younger_son", "fitjar")
	var wr := j.c.world_rules
	j.c.cal.year = 900
	j.c.world.year = 900
	var ev: Dictionary = {}
	for e in wr.spine:
		if str(e.id) == "rollo_outlawed":
			ev = (e as Dictionary).duplicate(true)
	j.decisions.push_front({"kind": "spine", "event": ev, "text": str(ev.text), "options": [{"id": "join_rollo", "label": "Sail west with Rollo"}]})
	j.answer("join_rollo")
	var band := j.c.band
	assert_eq(band.location, "seine", "the band is on the Seine")
	assert_eq(band.home, "seine")
	assert_eq(j.roam.grid.place_at(j.roam.pos), "seine")
	assert_eq(band.outlawry, WorldTypes.Outlawry.FULL, "outlawed in Harald's Norway")
	assert_true(not Outlawry.in_realm(j), "where Harald's law does not reach")
	assert_eq(Outlawry.door_shut(j, j.here(), "work"), "")
	var work := false
	for a in j.actions():
		if str(a.id).begins_with("work:"):
			work = true
	assert_true(work, "Rollo has work for his men")
	assert_eq(j.c.world.factions["seine"].leader, "Rollo")


func test_the_snow_does_not_put_the_band_in_an_ill_wishers_hall() -> void:
	var j := _quiet(6, "younger_son", "fitjar")
	var band := j.c.band
	band.known_places = {"avaldsnes": true, "fitjar": true}
	Families.set_standing(band, "Augvald's kin", -50)
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell["avaldsnes"]) + Vector2(1, 1)
	band.location = ""
	j.wintering = true
	j._settle()
	assert_eq(band.location, "fitjar", "not at the ill-wisher's door, but the next roof")
