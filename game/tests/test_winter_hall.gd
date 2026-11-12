extends TestCase
## The winter the player plays (WinterHall, Journey's winter calls): the
## steps, their costs and consequences, the war-leader, the stand-in
## players, and the bugs found in the old winter.


## A journey at its first place, the spring's decisions answered, ready to
## winter where it stands (stepped: the choices are left to the test).
func _ready(seed_in: int, origin := "younger_son", stepped := true) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	j.quick = true
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		j.answer(str(j.current().options[0].id))
	j.stepped_winter = stepped
	return j


## Two more men, so the hall has someone to give to.
func _with_men(j: Journey, n: int) -> void:
	for i in n:
		var m := Recruits.random(SimRng.new(100 + i), j.c.rules, j.c.band.next_id())
		m.loyalty = 50
		j.c.band.add_man(m)
	j.c._arm_new_men()


func _winter_now(j: Journey) -> void:
	j.act("winter")


func _man(j: Journey, i := 0) -> Man:
	return j.c.band.living_men()[i]


func test_auto_winter_ends_like_the_old_winter() -> void:
	var j := _ready(11, "younger_son", false)
	_with_men(j, 3)
	var hurt := _man(j, 0)
	hurt.healing_turns = 2
	j.c.band.food = 60
	var year := j.c.cal.year
	_winter_now(j)
	assert_true(not j.in_winter(), "the auto winter does not wait")
	assert_eq(j.c.cal.year, year + 1, "the year turns")
	assert_true(not j.c.cal.is_winter(), "the spring has begun")
	assert_true(j.can_act() or not j.decisions.is_empty(), "the summer can be played")
	assert_eq(hurt.healing_turns, 0, "wounds mend over the winter")
	assert_true(not "\n".join(j.c.log).contains("went hungry"), "a full store feeds everyone")
	assert_true(not j.winter_report.is_empty(), "the winter is told")
	# The old winter, from the same kind of band, ends the same way.
	var c := Campaign.new(11)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 3)
	c.band.food = 60
	c.band.living_men()[0].healing_turns = 2
	c.winter()
	c.cal.next_year()
	assert_eq(c.cal.year, year + 1, "the old winter turns the year too")
	assert_eq(c.band.living_men()[0].healing_turns, 0, "and mends")


func test_the_steps_run_in_order_and_back_is_safe() -> void:
	var j := _ready(12)
	_with_men(j, 2)
	_winter_now(j)
	assert_true(j.in_winter(), "the stepped winter waits for the player")
	assert_true(not j.can_act(), "no summer deeds in winter")
	var silver := j.c.band.silver
	var seen := PackedStringArray()
	for i in 5:
		seen.append(str(j.winter_state().step_id))
		j.winter_choose("next")
	assert_eq(",".join(seen), "store,gifts,yard,men,talk", "the steps before the winter is lived")
	assert_eq(str(j.winter_state().step_id), "told", "Go on from the talk lives through the winter")
	assert_true(not j.winter_state().can_back, "no going back once it is lived")
	j.winter_choose("next")
	assert_eq(str(j.winter_state().step_id), "spring")
	j.winter_choose("next")
	assert_true(not j.in_winter() and (j.can_act() or not j.decisions.is_empty()), "the spring begins")
	# Back before the winter is lived spends nothing.
	var k := _ready(12)
	_with_men(k, 2)
	_winter_now(k)
	var before := k.c.band.silver
	k.winter_choose("next")
	k.winter_choose("gift+:%d" % _man(k).id)
	k.winter_choose("back")
	k.winter_choose("back")
	assert_eq(k.c.band.silver, before, "choices are a draft until the winter is lived")
	assert_true(silver >= 0)


func test_gifts_raise_loyalty_and_cost_silver() -> void:
	var a := _ready(13)
	var b := _ready(13)
	for j in [a, b]:
		_with_men(j, 3)
		j.c.band.silver = 100
		j.c.band.food = 60
		_winter_now(j)
		for m in j.c.band.living_men():
			j.winter_hall.gifts[m.id] = 0  # nobody given anything by default
	var target := _man(a, 1)
	a.winter_choose("gift+:%d" % target.id)
	a.winter_choose("gift+:%d" % target.id)  # an arm-ring
	assert_eq(a.winter_hall.spend(a) - b.winter_hall.spend(b), a.c.rules.hall_gift_ounces[1], "the ring's cost is shown before it is given")
	a.winter_auto()
	b.winter_auto()
	var ta := a.c.band.man_by_id(target.id)
	var tb := b.c.band.man_by_id(target.id)
	assert_true(ta != null and tb != null)
	assert_true(ta.loyalty > tb.loyalty, "a ring warms a man (%d against %d)" % [ta.loyalty, tb.loyalty])
	assert_eq(b.c.band.silver - a.c.band.silver, a.c.rules.hall_gift_ounces[1], "the ring came out of the chest")


func test_a_great_deed_passed_over_rankles() -> void:
	var a := _ready(14)
	var b := _ready(14)
	for j in [a, b]:
		_with_men(j, 3)
		j.c.band.silver = 100
		j.c.band.food = 60
		var hero := _man(j, 0)
		hero.year_tally = {"fights": 3, "kills": 5, "deeds": 1}
		_winter_now(j)
		for m in j.c.band.living_men():
			j.winter_hall.gifts[m.id] = 0
		j.winter_hall.gifts[_man(j, 1).id] = 1  # the hall saw gifts, not for him
	var hero_id := _man(a, 0).id
	b.winter_hall.gifts[hero_id] = 2
	for i in 5:
		a.winter_choose("next")
	assert_true("\n".join(a.winter_state().told).contains("takes it ill"), "the telling says so")
	a.winter_auto()
	b.winter_auto()
	var pa := a.c.band.man_by_id(hero_id)
	var pb := b.c.band.man_by_id(hero_id)
	assert_true(pb.loyalty - pa.loyalty >= a.c.rules.loyalty_passed_over, "passed over: %d against %d" % [pa.loyalty, pb.loyalty])
	assert_true(pa.year_tally.is_empty(), "the year's deeds are cleared at the thaw")


func test_a_miser_hall_cools_every_man() -> void:
	var a := _ready(15)
	var b := _ready(15)
	for j in [a, b]:
		_with_men(j, 4)
		j.c.band.silver = 200
		j.c.band.food = 60
		_winter_now(j)
		for m in j.c.band.living_men():
			j.winter_hall.gifts[m.id] = 0
	for m in b.c.band.living_men():
		b.winter_hall.gifts[m.id] = 2
	a.winter_auto()
	b.winter_auto()
	assert_true(b.c.band.fame >= a.c.band.fame + a.c.rules.fame_open_hand - 1, "open hands are spoken of")
	var cold := 0
	for m in a.c.band.living_men():
		var other := b.c.band.man_by_id(m.id)
		if other != null and other.loyalty > m.loyalty:
			cold += 1
	assert_true(cold >= 3, "the miser's men are colder")


func test_short_stores_lose_men() -> void:
	var j := _ready(16)
	_with_men(j, 8)
	for m in j.c.band.living_men():
		m.loyalty = 34
	j.c.band.silver = 0
	j.c.band.food = 0
	var men := j.c.band.living_men().size()
	_winter_now(j)
	var h := j.winter_hall
	h.hunters = 0
	h.lots = 0
	h.feast = false
	for c in h.candidates:
		c.taken = false
	assert_true(h.food_end(j) < 0, "the store shows the shortfall before it happens")
	var s := j.winter_state()
	assert_true(" ".join(s.notes).contains("go hungry"), "the screen says men will go hungry")
	j.winter_auto()
	assert_true("\n".join(j.c.log).contains("went hungry"), "they did")
	assert_true(j.c.band.living_men().size() < men, "hungry men leave at the thaw (%d of %d stay)" % [j.c.band.living_men().size(), men])


func test_the_war_leader_commands_in_the_leaders_place() -> void:
	var c := Campaign.new(21)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Njal", 5)
	var sk := c.band.living_men()[2]
	sk.stats = [6, 7, 5, 6, 4]
	c.band.war_leader_id = sk.id
	var offer := c.offer_fight("raid", CombatTypes.Tier.GREEN, 5, true)
	var built := c.build_fight(offer, FightOffer.Choice.TAKE_THE_FIELD)
	var battle: Battle = built.battle
	assert_eq(battle.leader_of(0).id, c.band.leader.id, "named but not leading: the leader leads")
	c.band.leader_keeps_back = true
	var offer2 := c.offer_fight("raid", CombatTypes.Tier.GREEN, 5, true)
	assert_eq(offer2.our_men, 5, "the leader's place in the count is the war-leader's")
	var built2 := c.build_fight(offer2, FightOffer.Choice.TAKE_THE_FIELD)
	var lead: Warrior = (built2.battle as Battle).leader_of(0)
	assert_eq(lead.id, sk.id, "the war-leader leads the wall")
	assert_eq([lead.might, lead.skill, lead.grit, lead.nerve, lead.wits], [6, 7, 5, 6, 4], "and the fight uses his skill")
	assert_true(not (built2.fighters as Array).has(c.band.leader), "the leader keeps back")
	assert_eq((built2.ours as Array)[0].id, sk.id, "he is the man the battle screen gives the player")
	var fame := c.band.fame
	var result := (built2.battle as Battle).run()
	c.conclude_fight(offer2, built2, result)
	assert_true(c.band.leader.alive, "a leader who keeps back does not fall")
	if result.winner == 0:
		assert_true(c.band.fame - fame <= c.rules.fame_win + c.rules.fame_rout, "half the fame of it is the war-leader's")
	# A war-leader too hurt to stand: the leader goes himself.
	sk.healing_turns = c.rules.grievous_turns
	assert_true(c.line_men().has(c.band.leader), "with the war-leader abed, the leader stands")


func test_the_war_leader_is_named_in_the_hall() -> void:
	var j := _ready(22)
	_with_men(j, 3)
	_winter_now(j)
	var m := _man(j, 1)
	j.winter_choose("war:%d" % m.id)
	j.winter_choose("keep")
	j.winter_choose("second:%d" % _man(j, 2).id)
	j.winter_auto()
	assert_eq(j.c.band.war_leader_id, m.id, "the war-leader is named")
	assert_true(j.c.band.leader_keeps_back, "and leads the wall")
	assert_eq(j.c.band.sworn_second_id, _man(j, 2).id, "the sworn second is a role of its own")


func test_the_yard_reaches_the_band() -> void:
	var j := _ready(23)
	_with_men(j, 4)
	j.c.band.food = 60
	_winter_now(j)
	j.winter_choose("shape:boar's snout")
	j.winter_choose("shout:boar's snout")
	var m := _man(j, 0)
	j.winter_choose("role:%d" % m.id)
	var want: int = (int(m.role) + 1) % 3
	j.winter_choose("banner:%d" % m.id)
	j.winter_auto()
	var band := j.c.band
	assert_eq(band.drilling, "boar's snout", "the band drills the shape chosen")
	assert_eq(band.custom_shouts.size(), 1)
	assert_eq((band.custom_shouts[0] as CustomShout).name, "Swine", "the shout is sworn")
	assert_true(band.familiarity("boar's snout", j.c.rules) > 0.0, "the men know it the better")
	assert_eq(int(m.role), want, "he stands where he was put")
	assert_true(m.is_banner, "and carries the banner")


func test_the_halls_talk_resolves() -> void:
	var r := CampaignRules.new()
	var cal := Calendar.new(870)
	cal.start_winter()
	for kind in ["skald", "trader", "outlaw_shelter", "marriage_offer", "envoy", "sickness", "storm", "thrall_unrest", "quarrel", "feud_attack", "hall_burning"]:
		var band := Band.new()
		band.leader = Man.new()
		band.leader.id = band.next_id()
		band.leader.display_name = "Egil"
		for i in 4:
			var m := Man.new()
			m.display_name = "man%d" % i
			band.add_man(m)
		band.silver = 50
		band.food = 30
		band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
		band.add_feud("Atli's kin", "a killing")
		var card := WinterEvents.card(SimRng.new(3), r, band, kind)
		assert_true(not card.is_empty(), "%s makes a card" % kind)
		for o in card.options:
			var ev := WinterEvents.resolve(SimRng.new(4), r, band, cal, card, str(o.id), band.ship, PackedStringArray())
			assert_true(not ev.is_empty() and str(ev.text) != "", "%s / %s resolves" % [kind, o.id])
	# What the choices do.
	var b := Band.new()
	b.leader = Man.new()
	b.leader.id = b.next_id()
	for i in 2:
		b.add_man(Man.new())
	b.silver = 20
	b.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	var skald := WinterEvents.card(SimRng.new(1), r, b, "skald")
	var ev2 := WinterEvents.resolve(SimRng.new(1), r, b, cal, skald, "pay", b.ship, PackedStringArray())
	assert_eq(b.silver, 20 - r.skald_fee, "the skald is paid")
	assert_eq(int(ev2.fame), r.skald_fame, "for fame")
	var storm := WinterEvents.card(SimRng.new(1), r, b, "storm")
	WinterEvents.resolve(SimRng.new(1), r, b, cal, storm, "leave", b.ship, PackedStringArray())
	assert_eq(b.ship.damage, r.storm_ship_damage, "the storm hurts the ship the band sails")
	var q := WinterEvents.card(SimRng.new(1), r, b, "quarrel")
	var x := b.man_by_id(int(q.quarrel[0]))
	var y := b.man_by_id(int(q.quarrel[1]))
	var lx := x.loyalty
	var ly := y.loyalty
	WinterEvents.resolve(SimRng.new(1), r, b, cal, q, "for_a", b.ship, PackedStringArray())
	assert_true(x.loyalty > lx and y.loyalty < ly, "a quarrel judged warms one and cools the other")


func test_old_winter_bugs_are_mended() -> void:
	var r := CampaignRules.new()
	# The skald's fame reaches the band (Campaign._apply_report).
	var c := Campaign.new(5)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 2)
	var fame := c.band.fame
	var rep := WinterReport.new()
	rep.events = [{"kind": "skald", "fame": 3}]
	c._apply_report(WinterPlan.new(), rep)
	assert_eq(c.band.fame, fame + 3, "the praise-poem is fame")
	# A REPAIR turn mends the ship the band sails.
	var band := c.band
	band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	band.ship.damage = 2
	var plan := WinterPlan.new()
	plan.events = false
	plan.tasks[band.living_men()[0].id] = CampaignTypes.Task.REPAIR
	var cal := Calendar.new(870)
	cal.start_winter()
	Winter.run_turn(SimRng.new(1), r, band, cal, plan, PackedStringArray())
	assert_eq(band.ship.damage, 1, "repair mends the ship on the map")
	# No thralls, no thrall unrest.
	var r2 := CampaignRules.new()
	r2.winter_events = {"thrall_unrest": 5}
	assert_eq(WinterEvents.pick_kind(SimRng.new(1), r2, band), "", "a band with no thralls has no unrest among them")
	band.captives = 3
	assert_eq(WinterEvents.pick_kind(SimRng.new(1), r2, band), "thrall_unrest", "captives kept are thralls")


func test_a_marriage_in_winter_is_asked_by_a_house() -> void:
	# On the map the winter marries no one by itself.
	for seed_in in [31, 32, 33, 34, 35]:
		var j := _ready(seed_in, "burned_hall")
		_winter_now(j)
		for card in j.winter_hall.talk:
			assert_true(str(card.kind) != "marriage_offer", "no daughter of nobody")
		var before := j.c.band.wife
		for card in j.winter_hall.talk:
			if str(card.kind) == "house":
				card.choice = "decline"
		j.winter_auto()
		assert_eq(j.c.band.wife, before, "declined, nobody is married")


func test_a_home_hall_builds_and_a_guest_is_not_shamed() -> void:
	var j := _ready(41)
	_with_men(j, 10)
	j.c.band.silver = 200
	j.c.band.food = 60
	_winter_now(j)
	var h := j.winter_hall
	assert_eq(h.lodging, "home")
	var seats := (j.c.band.hall as Hall).seats
	j.winter_choose("build:%d" % CampaignTypes.Building.BENCHES)
	assert_eq(h.spend(j) >= j.c.rules.building_costs[CampaignTypes.Building.BENCHES], true, "the benches' cost is shown")
	j.winter_auto()
	assert_eq((j.c.band.hall as Hall).seats, seats + j.c.rules.benches_seats, "the benches are built")
	# A guest's benches are his host's: nobody goes benchless.
	var g := WinterHall.new()
	g.lodging = "guest"
	var band := Band.new()
	band.leader = Man.new()
	band.leader.id = band.next_id()
	for i in 12:
		band.add_man(Man.new())
	var rules := CampaignRules.new()
	var cal := Calendar.new(870)
	cal.start_winter()
	var plan := g.plan_for(rules, band, cal, 0, "")
	var rep := Winter.run_turn(SimRng.new(1), rules, band, cal, plan, PackedStringArray())
	for id in rep.seated:
		assert_true(rep.seated[id], "a guest is not shamed for his host's benches")


func test_ways_can_be_invested_in_winter() -> void:
	var j := _ready(42)
	j.c.band.deeds[Way.Id.SKALD] = 12
	_winter_now(j)
	for i in 5:
		j.winter_choose("next")
	assert_true(Way.points_free(j.c.band) > 0)
	var before := Way.rank(j.c.band, Way.Id.SKALD)
	j.winter_choose("invest:%d" % Way.Id.SKALD)
	assert_eq(Way.rank(j.c.band, Way.Id.SKALD), before + 1, "a step down a way, taken in the hall")


func test_the_stand_in_players_winter_three_years_without_stalling() -> void:
	for way in Way.Id.values():
		var j := Journey.begin(7, "burned_hall", "Egil")
		for y in 3:
			var before := j.c.cal.year
			JourneyBot.play_year(j, way)
			assert_true(j.c.over or j.c.cal.year == before + 1, "%s: the year turns" % Way.name_of(way))
			assert_true(not j.in_winter(), "%s: the winter is ended" % Way.name_of(way))
			if j.c.over:
				break
		if way == Way.Id.LAWMAN and not j.c.over and not j.c.band.living_men().is_empty():
			assert_true(j.c.band.war_leader() != null and j.c.band.leader_keeps_back, "the law-wise man has a war-leader in the wall")


func test_the_stepped_winter_is_the_same_on_the_same_seed() -> void:
	var out := PackedStringArray()
	for k in 2:
		var j := Journey.begin(9, "younger_son", "Egil")
		JourneyBot.play_year(j, Way.Id.VIKING)
		JourneyBot.play_year(j, Way.Id.VIKING)
		var b := j.c.band
		out.append("%d %d %d %d %d %s" % [b.silver, b.food, b.fame, b.honor, b.living_men().size(), "|".join(b.chronicle)])
	assert_eq(out[0], out[1], "same seed, same winters")
