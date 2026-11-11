extends TestCase
## What a fight leaves behind (Aftermath, BattleBridge): wounds carried to
## the next fight, men too hurt left at the ship, breaking remembered,
## kills counted, loot taken, a man who asks to join. Shared by the
## campaign and the prototype's roster.


func _band(n := 6) -> Band:
	var rules := CampaignRules.new()
	var b := Band.new()
	var r := SimRng.new(5)
	var leader := Recruits.make(r.fork("l"), rules, CampaignTypes.Origin.YOUNGER_SON, 22, "Egil", b.next_id())
	leader.is_leader = true
	b.leader = leader
	for i in n - 1:
		b.add_man(Recruits.random(r.fork("m:%d" % i), rules, b.next_id()))
	return b


func test_wounds_carry_and_the_grievous_stay_behind() -> void:
	var rules := CampaignRules.new()
	var b := _band()
	var men := b.fighters()
	var warriors: Array[Warrior] = []
	for m in men:
		warriors.append(m.to_warrior(0, rules))
	warriors[1].wound = CombatTypes.Wound.WOUNDED
	warriors[2].wound = CombatTypes.Wound.GRIEVOUS
	warriors[3].wound = CombatTypes.Wound.BRUISED
	var result := BattleResult.new()
	result.winner = 0
	result.how = BattleResult.End.ROUT
	result.seed_value = 9
	var log := PackedStringArray()
	var told := BattleBridge.after_battle(rules, b, warriors, result, log)
	assert_eq(men[1].healing_turns, rules.wound_turns[CombatTypes.Wound.WOUNDED])
	assert_eq(men[1].current_wound(rules), CombatTypes.Wound.WOUNDED, "he fights the next one wounded")
	assert_eq(men[1].to_warrior(0, rules).wound, CombatTypes.Wound.WOUNDED)
	assert_true(men[2].too_hurt_to_fight(rules), "grievous: left at the ship")
	assert_true(not b.fighters(rules).has(men[2]), "and not among the fighters")
	assert_true(b.hurt(rules).has(men[2]))
	assert_eq(men[3].current_wound(rules), CombatTypes.Wound.BRUISED)
	assert_true(told.wounded.has(men[1].display_name) and told.grievous.has(men[2].display_name))
	b.mend(1)
	assert_eq(men[3].current_wound(rules), CombatTypes.Wound.UNHURT, "a bruise mends in a turn")
	assert_eq(men[1].current_wound(rules), CombatTypes.Wound.BRUISED, "a wound is a bruise after one")
	b.mend(3)
	assert_true(b.fighters(rules).has(men[2]), "four turns and the grievous man stands again")


func test_breaking_and_kills_are_remembered() -> void:
	var rules := CampaignRules.new()
	var b := _band()
	var men := b.fighters()
	var warriors: Array[Warrior] = []
	for m in men:
		warriors.append(m.to_warrior(0, rules))
	warriors[1].broken = true
	warriors[2].kills = rules.deed_kills
	var loyalty := men[1].loyalty
	var result := BattleResult.new()
	result.winner = 0
	result.seed_value = 9
	var told := BattleBridge.after_battle(rules, b, warriors, result, PackedStringArray())
	assert_eq(men[1].broke_count, 1)
	assert_eq(men[1].loyalty, loyalty - rules.loyalty_broke_penalty)
	assert_true(men[1].traits.has("broke and ran once"))
	assert_true(told.broke.has(men[1].display_name))
	assert_eq(men[2].kills, rules.deed_kills)
	assert_eq(men[2].deeds.size(), 1, "a deed is told of him")
	assert_true(told.deeds[0].begins_with(men[2].display_name))


func test_loot_and_a_man_who_asks_to_join() -> void:
	var rules := CampaignRules.new()
	rules.recruit_after_rout_chance = 1.0
	var b := _band()
	var warriors: Array[Warrior] = []
	for m in b.fighters():
		warriors.append(m.to_warrior(0, rules))
	warriors[1].looted = true
	var result := BattleResult.new()
	result.winner = 0
	result.how = BattleResult.End.ROUT
	result.seed_value = 9
	var silver := b.silver
	var men := b.fighters().size()
	var told := Aftermath.apply(rules, b, warriors, result, SimRng.new(1), true, PackedStringArray())
	assert_eq(b.silver, silver + rules.loot_per_man, "the greedy man's loot is the band's")
	assert_eq(b.fighters().size(), men + 1, "a man joined")
	assert_eq(told.joined.size(), 1)
	assert_true(told.lines[-1].ends_with("asks to join."), told.lines[-1])
	# At sea, or after a loss, nobody joins and nothing is stripped.
	var b2 := _band()
	var w2: Array[Warrior] = []
	for m in b2.fighters():
		w2.append(m.to_warrior(0, rules))
	w2[1].looted = true
	var lost := BattleResult.new()
	lost.winner = 1
	lost.seed_value = 9
	var told2 := Aftermath.apply(rules, b2, w2, lost, SimRng.new(1), true, PackedStringArray())
	assert_eq(told2.loot, 0)
	assert_true(told2.joined.is_empty())


func test_the_campaign_mends_between_fights_and_leaves_the_hurt_behind() -> void:
	var c := Campaign.new(11)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 9)
	var hurt := c.band.fighters()[2]
	hurt.healing_turns = c.rules.grievous_turns + c.rules.mend_between_fights
	var o := c.offer_fight("outlaws", CombatTypes.Tier.GREEN, 6, true)
	assert_true(not c.band.fighters(c.rules).has(hurt), "too hurt: not counted")
	c.resolve_offer(o, FightOffer.Choice.TAKE_THE_FIELD)
	assert_true(hurt.healing_turns <= c.rules.grievous_turns, "the days between mend a turn")
