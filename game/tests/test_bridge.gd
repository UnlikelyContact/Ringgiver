extends TestCase


func _band(n: int) -> Band:
	var b := Band.new()
	var rules := CampaignRules.new()
	var rng := SimRng.new(31)
	var lead := Recruits.make(rng, rules, CampaignTypes.Origin.YOUNGER_SON, 25, "Ulfar", 1)
	lead.is_leader = true
	lead.personality = []
	b.leader = lead
	b.add_man(lead)
	b.men.erase(lead)
	for i in n:
		var m := Recruits.make(rng, rules, CampaignTypes.Origin.FISHERMAN, 28, Recruits.NAMES[i], 2 + i)
		m.personality = []
		b.add_man(m)
	return b


func test_bridge_by_hand() -> void:
	var rules := CampaignRules.new()
	var band := _band(5)
	var log := PackedStringArray()
	var ws: Array[Warrior] = []
	for m in band.fighters():
		ws.append(m.to_warrior(0))
	# 1: leader unhurt with effort. 2: down, recovered. 3: dead. 4: maimed. 5: fled. 6: unhurt.
	var stranger := Warrior.make("Stranger", 0, [5, 5, 5, 5, 5])
	stranger.id = 999
	ws.append(stranger)
	ws[0].add_effort(CombatTypes.Stat.SKILL, 7)
	ws[1].wound = CombatTypes.Wound.DOWN
	ws[1].fate = CombatTypes.Fate.RECOVERED
	ws[2].wound = CombatTypes.Wound.DOWN
	ws[2].fate = CombatTypes.Fate.DEAD
	ws[3].wound = CombatTypes.Wound.DOWN
	ws[3].fate = CombatTypes.Fate.MAIMED
	ws[4].fled = true
	var maimed := band.man_by_id(4)
	var before_maimed: Array[int] = maimed.stats.duplicate()
	var fled_loyalty := band.man_by_id(5).loyalty
	var r := BattleResult.new()
	r.seed_value = 55
	BattleBridge.after_battle(rules, band, ws, r, log)

	assert_eq(band.leader.effort[CombatTypes.Stat.SKILL] + 0, int(round(7 * rules.age_growth_20_25)), "effort copied with multipliers")
	assert_eq(band.leader.battles_survived, 1)
	assert_eq(band.leader.tier, CombatTypes.Tier.BLOODED)
	assert_eq(band.man_by_id(2).battles_survived, 1, "recovered counts as survived")
	assert_true(not band.man_by_id(3).alive)
	assert_eq(band.man_by_id(3).battles_survived, 0)
	var dead_line := false
	for line in band.chronicle:
		if line.contains(band.man_by_id(3).display_name):
			dead_line = true
	assert_true(dead_line, "chronicle line for the dead")
	assert_eq(maimed.maims.size(), 1)
	assert_eq(maimed.battles_survived, 0, "a maimed man did not come through whole")
	var pen: Array = rules.maim_penalties[maimed.maims[0]]
	assert_eq(maimed.stats[pen[0]], maxi(1, before_maimed[pen[0]] - pen[1]), "maim penalty applied")
	assert_true(maimed.stats[pen[0]] <= maimed.potential[pen[0]])
	assert_eq(band.man_by_id(5).loyalty, fled_loyalty - rules.loyalty_fled_penalty)
	assert_eq(band.man_by_id(5).battles_survived, 1)
	# Bonds: those who stood and lived (1, 2, 4, 6), not the dead or the fled.
	var stood := [1, 2, 4, 6]
	for a in stood:
		for b in stood:
			if a < b:
				assert_eq(band.bond(band.man_by_id(a), band.man_by_id(b)), rules.bond_fought_together)
	assert_eq(band.bond(band.man_by_id(1), band.man_by_id(5)), 0, "the fled man earns no bond")
	assert_eq(band.bond(band.man_by_id(1), band.man_by_id(3)), 0, "the dead earn no bond")
	# Same seed, same maim.
	var band2 := _band(5)
	var ws2: Array[Warrior] = []
	for m in band2.fighters():
		ws2.append(m.to_warrior(0))
	ws2[3].wound = CombatTypes.Wound.DOWN
	ws2[3].fate = CombatTypes.Fate.MAIMED
	BattleBridge.after_battle(rules, band2, ws2, r, PackedStringArray())
	assert_eq(band2.man_by_id(4).maims, maimed.maims, "maims replay from the battle seed")


func test_bridge_growth_and_tier_over_battles() -> void:
	var rules := CampaignRules.new()
	var band := _band(1)
	var m := band.men[0]
	m.stats = [3, 3, 3, 3, 3]
	m.potential = [8, 8, 8, 8, 8]
	for i in rules.tier_veteran_battles:
		var w := m.to_warrior(0)
		w.add_effort(CombatTypes.Stat.MIGHT, 40)
		var r := BattleResult.new()
		BattleBridge.after_battle(rules, band, [w] as Array[Warrior], r, PackedStringArray())
	assert_eq(m.battles_survived, rules.tier_veteran_battles)
	assert_eq(m.tier, CombatTypes.Tier.VETERAN)
	assert_true(m.stats[CombatTypes.Stat.MIGHT] > 3, "effort grew might")


func test_bridge_after_real_battle() -> void:
	var crules := CombatRules.new()
	var rules := CampaignRules.new()
	var band := _band(7)
	var ws: Array[Warrior] = []
	for m in band.fighters():
		ws.append(m.to_warrior(0))
	var b := Battle.new(crules, 17)
	var foes := BandFactory.make_band(SimRng.new(17).fork("foe"), 1, 8, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 16, 101)
	BandFactory.deploy_column(b.grid, ws, 5, Vector2i(1, 0), crules)
	BandFactory.deploy_column(b.grid, foes, 10, Vector2i(-1, 0), crules)
	b.add_band(ws)
	b.add_band(foes)
	b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	b.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.STEADY))
	var result := b.run()
	var log := PackedStringArray()
	var any_effort := false
	for w in ws:
		if not w.effort.is_empty():
			any_effort = true
	BattleBridge.after_battle(rules, band, ws, result, log)
	assert_true(any_effort, "the battle produced effort")
	var dead := 0
	for w in ws:
		var m := band.man_by_id(w.id)
		if w.is_down() and w.fate == CombatTypes.Fate.DEAD:
			dead += 1
			assert_true(not m.alive)
		else:
			assert_true(m.alive)
		for s in 5:
			assert_true(m.stats[s] <= m.potential[s])
	assert_eq(dead, result.dead[0])
	assert_true(log.size() > 0)
