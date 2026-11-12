extends TestCase
## The saga's fights fought over something (docs/design/notes/saga-fights.md):
## the objective from the fight's cause and ground, the raid's clock and
## its plunder, luck in battle and the front rank, what a feud's fight
## settles, the burning of a hall and what it leaves along the houses' ties.


func _campaign(seed_in := 5) -> Campaign:
	var c := Campaign.new(seed_in)
	c.start_from("younger_son", "Egil")
	for i in 6:
		c.band.add_man(Recruits.random(c.rng.fork("m%d" % i), c.rules, c.band.next_id()))
	c._arm_new_men()
	return c


func _quiet(seed_in: int, origin := "younger_son") -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	j.quick = true
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		var d := j.current()
		j.answer(str(d.options[d.options.size() - 1].id))
	return j


func test_the_objective_follows_what_the_fight_is_for() -> void:
	var c := _campaign()
	var T := FightOffer.Choice.TAKE_THE_FIELD
	var cases := [
		# [ground, cause, attacking, ships_here, kind, attacker]
		["farm", "raid", true, false, Objective.Kind.PLUNDER, 0],
		["farm", "defend", false, false, Objective.Kind.THE_HALL, 1],
		["strand", "thieves", true, false, Objective.Kind.REACH_THE_SHIPS, 0],
		["open", "rob", true, false, Objective.Kind.CARGO, 0],
		["strand", "sea", false, true, Objective.Kind.REACH_THE_SHIPS, 1],
		["strand", "sea", false, false, -1, 0],
		["open", "feud", false, false, -1, 0],
		["sea", "rob", true, false, Objective.Kind.DECK, 0],
	]
	for k in cases:
		var o := c.offer_fight("x", CombatTypes.Tier.GREEN, 6, k[2], 3, k[0] == "sea", false, k[0],
				{"cause": k[1], "ships_here": k[3]})
		o.they_know_first = false
		var st := c.stake(o, T)
		assert_eq(int(st.kind), int(k[4]), "%s, %s" % [k[0], k[1]])
		var built := c.build_fight(o, T)
		var obj: Objective = built.objective
		assert_eq(obj.kind if obj != null else -1, int(k[4]), "%s, %s: the field has it" % [k[0], k[1]])
		if obj != null:
			assert_eq(obj.attacker, int(k[5]), "%s, %s: who must come on" % [k[0], k[1]])
	var raid := c.offer_fight("raid", CombatTypes.Tier.GREEN, 6, true, 3, false, false, "farm", {"cause": "raid"})
	assert_true(raid.brief().contains("Take the hall before their neighbours come: about %d rounds from contact" % c.combat_rules.objective_plunder_rounds),
			"the offer says what it is over: %s" % raid.brief())


func test_the_thing_and_your_own_hall_offer_what_makes_sense_there() -> void:
	var c := _campaign()
	var thing := c.offer_fight("thing_brawl", CombatTypes.Tier.GREEN, 6, false, 3, false, true, "thing", {"cause": "thing"})
	assert_eq(thing.options(), [FightOffer.Choice.TAKE_THE_FIELD] as Array[int], "a brawl among the booths: stand and fight")
	assert_eq(thing.title(FightOffer.Choice.TAKE_THE_FIELD), "Stand and fight")
	var built := c.build_fight(thing, FightOffer.Choice.WAIT_FOR_THEM)
	assert_true(built.objective == null, "no ford at the Thing")
	var hall := c.offer_fight("hall_burning", CombatTypes.Tier.VETERAN, 8, false, -1, false, true, "hall", {"cause": "hall", "burning": true})
	assert_true(not hall.allows(FightOffer.Choice.FADE_AWAY))
	assert_eq(hall.title(FightOffer.Choice.WAIT_FOR_THEM), "Bar the door and hold the walls")
	assert_eq(hall.title(FightOffer.Choice.TAKE_THE_FIELD), "Out, and meet them in the yard")
	var hb := c.build_fight(hall, FightOffer.Choice.WAIT_FOR_THEM)
	assert_eq((hb.objective as Objective).kind, Objective.Kind.FIRE)
	assert_true((hb.battle as Battle).night)


func test_the_raid_clock_and_its_plunder() -> void:
	var rules := CombatRules.new()
	var sc := Scenario.build("equal_green", 3, rules, true, 12, "", {}, {"objective": Objective.Kind.PLUNDER, "attacker": 0})
	var b: Battle = sc.battle
	var obj: Objective = sc.objective
	assert_eq(obj.rounds, rules.objective_plunder_rounds)
	assert_eq(sc.field_name, "farmstead", "a raid on a steading is fought at its hall")
	# The neighbours come with the raiders the stronger: they have the
	# field, not the hall.
	obj.clock_start = 0
	b.round = obj.rounds
	assert_eq(obj.check(b), 0, "the stronger raiders have the field")
	assert_true(not obj.taken, "but not the hall")
	var sc2 := Scenario.build("equal_green", 3, rules, true, 12, "", {}, {"objective": Objective.Kind.PLUNDER, "attacker": 0})
	var b2: Battle = sc2.battle
	for w in b2.side_warriors(0):
		if not w.is_leader:
			w.wound = CombatTypes.Wound.DOWN
			b2.grid.remove(w)
	(sc2.objective as Objective).clock_start = 0
	b2.round = (sc2.objective as Objective).rounds
	assert_eq((sc2.objective as Objective).check(b2), 1, "the weaker go home with nothing")
	# The campaign's share of the plunder.
	var c := _campaign()
	var r := BattleResult.new()
	r.winner = 0
	r.how = BattleResult.End.OBJECTIVE
	r.objective_kind = Objective.Kind.PLUNDER
	r.taken = true
	assert_eq(c.plunder_share(r), 1.0, "broke into the hall: all of it")
	r.taken = false
	assert_eq(c.plunder_share(r), c.rules.raid_late_share, "the field without the hall: less")
	r.how = BattleResult.End.ROUT
	assert_eq(c.plunder_share(r), 1.0, "routed them: nothing stops the plundering")


func test_luck_warms_the_men_within_its_bound_and_turns_close_calls() -> void:
	var rules := CombatRules.new()
	for luck in [-1, 0, 1]:
		var base := Scenario.build("equal_green", 4, rules, true, 12)
		var lucky := Scenario.build("equal_green", 4, rules, true, 12)
		(lucky.battle as Battle).set_luck(0, luck)
		for i in (base.ours as Array).size():
			var a: Warrior = base.ours[i]
			var b: Warrior = lucky.ours[i]
			assert_eq(b.morale, clampi(a.morale + luck * rules.luck_morale, 0, 10), "luck %d: one step of heart at most" % luck)
		for w: Warrior in lucky.theirs:
			assert_eq(w.luck, 0, "the other side's luck is not ours")
	var r := ExchangeResult.new()
	r.loser = Warrior.make("l", 0, [3, 3, 3, 3, 3])
	r.loser.luck = 1
	r.margin = rules.luck_close_margin
	r.tier = OpposedRoll.Tier.HIT
	MeleeExchange._close_call(rules, r, PackedStringArray())
	assert_eq(r.tier, OpposedRoll.Tier.GLANCING, "a lucky man's close call glances off")
	r.margin = 6
	r.tier = OpposedRoll.Tier.HEAVY
	MeleeExchange._close_call(rules, r, PackedStringArray())
	assert_eq(r.tier, OpposedRoll.Tier.HEAVY, "luck does not turn a heavy blow")
	r.loser.luck = -1
	r.margin = 2
	r.tier = OpposedRoll.Tier.GLANCING
	MeleeExchange._close_call(rules, r, PackedStringArray())
	assert_eq(r.tier, OpposedRoll.Tier.HIT, "an unlucky man's glancing blow bites")
	# The fate roll leans on it.
	var dead := {-1: 0, 0: 0, 1: 0}
	for luck in dead:
		for i in 600:
			var w := Warrior.make("w", 0, [3, 3, 3, 3, 3])
			w.wound = CombatTypes.Wound.DOWN
			w.luck = luck
			if Fate.roll(SimRng.new(i), rules, w) == CombatTypes.Fate.DEAD:
				dead[luck] += 1
	assert_true(dead[1] < dead[0] and dead[0] < dead[-1], "luck keeps a downed man alive: %s" % str(dead))


func test_hanging_back_is_seen() -> void:
	var c := _campaign()
	var o := c.offer_fight("x", CombatTypes.Tier.GREEN, 6, false, 3, false, false, "open", {"cause": "feud"})
	var built := c.build_fight(o, FightOffer.Choice.TAKE_THE_FIELD)
	var b: Battle = built.battle
	var me: Warrior = null
	var other: Warrior = null
	for w: Warrior in built.ours:
		if w.id == c.band.leader.id:
			me = w
		elif other == null:
			other = w
	assert_true(c.led_from_front(built, b.result), "nobody closed: nobody hung back")
	other.contact_rounds = 3
	assert_true(not c.led_from_front(built, b.result), "his men fought and he did not")
	me.contact_rounds = c.rules.front_contact_rounds
	assert_true(c.led_from_front(built, b.result), "he stood in the front rank")
	me.contact_rounds = 0
	me.strikes = 1
	assert_true(c.led_from_front(built, b.result), "he struck a blow")
	me.strikes = 0
	built.war_leader = other.id
	assert_true(c.led_from_front(built, b.result), "the war-leader led: the leader was honestly not there")
	var luck := c.band.luck
	var lines := c.luck_lines(false, luck)
	assert_true(lines.size() >= 1 and lines[0].contains("keep back"), "the men speak of it")
	# The real fight: the leader keeps out of it, and it costs him.
	c.band.luck = 5
	var honor := c.band.honor
	built.war_leader = -1
	other.contact_rounds = 3
	me.contact_rounds = 0
	b.run()
	me.contact_rounds = 0
	me.strikes = 0
	me.wound = CombatTypes.Wound.UNHURT
	var front := c.led_from_front(built, b.result)
	Leader.on_battle(c.rules, c.band, false, front, 1.0, PackedStringArray(), BattleResult.Outcome.LOST_THE_FIELD)
	assert_true(c.band.honor < honor, "hanging back costs honor")


func test_a_feud_ambush_beaten_off_cools_the_feud_and_a_lost_one_warms_it() -> void:
	var j := _quiet(31)
	var fam := "Augvald's kin"
	j.c.band.add_feud(fam, "an insult", "")
	var f := Feud.find(j.c.band, fam)
	f["level"] = 2
	var won := BattleResult.new()
	won.winner = 0
	won.dead = [0, 3]
	j._after_fight({"kind": "feud", "family": fam}, won)
	assert_eq(int(f.level), 1, "beaten off: the feud cools")
	assert_eq(int(f.kills_ours), 3, "their dead on the ledger")
	var lost := BattleResult.new()
	lost.winner = 1
	lost.dead = [2, 0]
	j._after_fight({"kind": "feud", "family": fam}, lost)
	assert_eq(int(f.level), 2, "beaten: it warms again")
	assert_eq(int(f.kills_theirs), 2)


func test_a_brawl_at_the_thing_changes_the_footing() -> void:
	var j := _quiet(32)
	var fam := "Augvald's kin"
	j.c.band.add_feud(fam, "a failed case", "")
	var f := Feud.find(j.c.band, fam)
	f["level"] = 2
	var before := Families.standing(j.c.band, fam)
	var won := BattleResult.new()
	won.winner = 0
	j._after_fight({"kind": "thing", "family": fam}, won)
	assert_eq(int(f.level), 1, "the Thing saw who held the field")
	assert_true(Families.standing(j.c.band, fam) >= before or Families.standing(j.c.band, fam) == j.c.world_rules.standing_feud_cap,
			"they think the better of the band (or are held at the feud's cap)")


func test_a_vengeance_is_against_a_house_and_raiders_leave_a_grudge() -> void:
	var rules := CampaignRules.new()
	for house in ["Augvald's kin", "", Bonds.OLD_WAYS]:
		var b := Band.new()
		var a := Man.new()
		a.id = 1
		a.display_name = "Bjorn"
		var d := Man.new()
		d.id = 2
		d.display_name = "Grim"
		b.add_man(a)
		b.add_man(d)
		b.set_bond(a, d, 100)
		Bonds.update_kind(rules, b, a, d, PackedStringArray())
		assert_true(not Bonds.oath_brothers(b, d).is_empty(), "sworn brothers")
		Bonds.on_death(rules, b, d, "Kveldulf", PackedStringArray(), house)
		match house:
			"Augvald's kin":
				assert_true(not Feud.find(b, "Augvald's kin").is_empty(), "the feud is with the killers' house")
				assert_true(Feud.find(b, "Kveldulf").is_empty(), "not with a man's name")
			"":
				assert_true(b.unsettled_feuds().is_empty(), "men of no house: a grudge, no feud")
			_:
				assert_true(not Feud.find(b, "Kveldulf").is_empty(), "the old ways: named for the killer")
	var j := _quiet(33)
	var p := Roam.Party.new()
	p.kind = "avengers"
	p.family = "Hrafn's kin"
	assert_eq(str(j._about_fight({"kind": "sea", "party": p}).house), "Hrafn's kin", "the party's house")
	var raiders := Roam.Party.new()
	raiders.kind = "raiders"
	assert_eq(str(j._about_fight({"kind": "sea", "party": raiders}).house), "", "raiders are no house")
	assert_eq(str(j._about_fight({"kind": "feud", "family": "Augvald's kin"}).house), "Augvald's kin")


func test_the_burning_of_a_hall_and_what_it_leaves() -> void:
	var j := _quiet(34, "burned_hall")
	var band := j.c.band
	var fs := j.c.world.families
	var wr := j.c.world_rules
	var name := band.vengeance
	assert_eq(name, "Hardanger-Atli's kin")
	var allies := fs.allies_of(name)
	assert_true(not allies.is_empty(), "the burners have friends")
	var before := {}
	for a in allies:
		before[a] = Families.standing(band, a)
	var head := fs.house(name).head
	var strength := fs.house(name).strength
	var honor := band.honor
	var sc := Scenario.build_hall_burning(9, j.c.combat_rules)
	var b: Battle = sc.battle
	b.sworn_leader(1).wound = CombatTypes.Wound.DOWN
	b.result.winner = 0
	var ctx := {"kind": "reckoning", "family": name, "built": sc, "choice": FightOffer.Choice.BURN, "friends": []}
	j._after_fight(ctx, b.result)
	assert_true(fs.house(name).head != head, "the head of the house died in the fire")
	assert_true(fs.house(name).strength < strength, "the house is halved")
	for a in allies:
		assert_true(Families.standing(band, a) < int(before[a]), "%s turns against the band" % a)
	assert_true(band.honor >= honor - wr.burning_avenged_honor, "a burning for a burning costs little honor")
	assert_eq(band.vengeance, "", "the burning is answered")
	assert_true(not Feud.find(band, name).is_empty(), "and the heir does not forget")
	assert_true(j.said.has("The women, the children and the thralls of %s were let out before the roof fell." % name), "the household was let out, and it is told")
	# A house that never burned the band: the honor goes heavily.
	var k := _quiet(35)
	var other := "Augvald's kin"
	k.c.band.add_feud(other, "an insult", "")
	var h2 := k.c.band.honor
	var sc2 := Scenario.build_hall_burning(10, k.c.combat_rules)
	(sc2.battle as Battle).result.winner = 0
	k._after_fight({"kind": "reckoning", "family": other, "built": sc2, "choice": FightOffer.Choice.BURN, "friends": []}, (sc2.battle as Battle).result)
	assert_true(k.c.band.honor <= maxi(0, h2 - wr.burning_band_honor), "a burning is a heavy thing to answer for")


func test_the_burning_is_offered_only_at_the_seat_of_a_house_at_feud() -> void:
	var j := _quiet(36, "burned_hall")
	var name := j.c.band.vengeance
	var about := j._about_fight({"kind": "reckoning", "family": name})
	assert_true(bool(about.get("can_burn", false)), "the reckoning at their seat")
	assert_eq(str(about.head), j.c.world.families.house(name).head, "their head leads them out")
	var o := j.c.offer_fight("x", CombatTypes.Tier.GREEN, 8, true, 3, false, false, "farm", about)
	assert_true(o.allows(FightOffer.Choice.BURN))
	assert_eq(o.title(FightOffer.Choice.BURN), "Burn them in by night")
	var built := j.c.build_fight(o, FightOffer.Choice.BURN)
	assert_eq(str(built.field_name), "burning")
	var not_feud := j._about_fight({"kind": "house_fight", "family": "Augvald's kin"})
	assert_true(not bool(not_feud.get("can_burn", false)), "no burning without a feud at their seat")


func test_each_new_fight_is_the_same_on_the_same_seed() -> void:
	var rules := CombatRules.new()
	for name in ["plunder", "deck", "hall", "fire", "burning"]:
		var hashes: Array[int] = []
		for k in 2:
			var sc: Dictionary
			match name:
				"plunder":
					sc = Scenario.build("equal_green", 12, rules, true, 12, "", {}, {"objective": Objective.Kind.PLUNDER, "attacker": 0})
				"deck":
					sc = Scenario.build_deck(12, rules)
				"hall":
					sc = Scenario.build_hall_defence(12, rules)
				"fire":
					sc = Scenario.build_hall_defence(12, rules, {}, true, "meet")
				_:
					sc = Scenario.build_hall_burning(12, rules)
			var b: Battle = sc.battle
			b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
			b.run()
			hashes.append(("\n".join(b.log) + b.result.summary()).hash())
		assert_eq(hashes[0], hashes[1], "%s: one seed, one fight" % name)
