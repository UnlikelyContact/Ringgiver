extends TestCase

const FAMILY := "Hardanger-Atli's kin"


func _band(fighters: int, wits := 3) -> Band:
	var b := Band.new()
	b.year = 870
	var leader := Man.new()
	leader.display_name = "Ulf"
	leader.is_leader = true
	leader.set_stat(CombatTypes.Stat.WITS, wits)
	b.leader = leader
	b.add_man(leader)
	b.men.erase(leader)
	for i in fighters - 1:
		var m := Man.new()
		m.display_name = "man %d" % i
		b.add_man(m)
	return b


func _rate_won(fame: int, spent: int, trials: int) -> float:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var won := 0
	for s in trials:
		var b := _band(10)
		b.fame = fame
		b.silver = 100
		var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
		var log := PackedStringArray()
		var v := Thing.run(SimRng.new(s), r, w, b, c, spent, log)
		if v != WorldTypes.Verdict.FAILED and v != WorldTypes.Verdict.PENDING:
			won += 1
	return float(won) / trials


func test_gate_support_wins_raid_cases() -> void:
	var strong := _rate_won(60, 50, 500)
	var weak := _rate_won(10, 0, 500)
	print("    thing gate: fame 60 + 50 oz wins %.3f, fame 10 + 0 oz wins %.3f" % [strong, weak])
	assert_between(strong, 0.6, 0.85, "strong case wins unless the pleading slips")
	assert_between(weak, 0.0, 0.1, "a weak band rarely wins")
	assert_true(strong > weak + 0.5)


func test_gate_procedural_slip_rate_wits_3() -> void:
	var r := WorldRules.new()
	var slips := 0
	var n := 4000
	for s in n:
		var b := _band(1, 3)
		var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
		if not Thing.procedure(SimRng.new(s), r, b, c, PackedStringArray()):
			slips += 1
	var rate := float(slips) / n
	print("    thing gate: slip rate for Wits 3 on a raid case %.3f (target %.2f)" % [rate, r.procedure_slip_target])
	assert_between(rate, r.procedure_slip_target - 0.05, r.procedure_slip_target + 0.05)


func test_law_wise_man_and_lawman_reroll() -> void:
	var r := WorldRules.new()
	var b := _band(3, 2)
	assert_eq(Thing.best_wits(r, b), 2)
	b.men[0].set_stat(CombatTypes.Stat.WITS, 7)
	assert_eq(Thing.best_wits(r, b), 2, "Wits without the trait does not count")
	b.men[0].traits.append("law-wise")
	assert_eq(Thing.best_wits(r, b), 7)
	# A hired law-man cuts the slip rate and costs his fee only on a slip.
	var plain := 0
	var hired := 0
	var fees := 0
	for s in 2000:
		var b1 := _band(1, 3)
		var c1 := Thing.open_case(r, b1, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
		if not Thing.procedure(SimRng.new(s), r, b1, c1, PackedStringArray()):
			plain += 1
		var b2 := _band(1, 3)
		b2.silver = 100
		var c2 := Thing.open_case(r, b2, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
		c2.lawman_hired = true
		if not Thing.procedure(SimRng.new(s), r, b2, c2, PackedStringArray()):
			hired += 1
		if b2.silver < 100:
			fees += 1
			assert_eq(b2.silver, 100 - r.lawman_fee)
	assert_true(hired < plain / 2, "reroll halves slips at least: %d vs %d" % [hired, plain])
	assert_eq(fees, plain, "the fee is paid exactly when the first roll slips")


func test_support_counts_fame_silver_brothers_factions() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := _band(4)
	b.fame = 45
	b.silver = 25
	b.set_bond_kind(b.men[0], b.men[1], CampaignTypes.BondKind.OATH_BROTHER)
	b.set_bond_kind(b.leader, b.men[2], CampaignTypes.BondKind.OATH_BROTHER)
	w.factions["friend"] = {"id": "friend", "relations": {"band": 65}, "alive": true}
	w.factions["cold"] = {"id": "cold", "relations": {"band": 10}, "alive": true}
	w.factions["hordaland"] = {"id": "hordaland", "relations": {"band": 90}, "alive": true}
	var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
	var n := Thing.gather_support(SimRng.new(1), r, w, b, c, 40, PackedStringArray())
	# 45/15 = 3 fame, 25 oz (all the band has) / 10 = 2, 2 pairs, friend 65/30 = 2;
	# Hordaland rules the family's farms and lends nothing. The houses stand
	# where their ties put them (Families.thing_backing): the family's
	# enemies with the band, its allies with it.
	var houses := w.families.thing_backing(r, b, FAMILY)
	assert_true(int(houses.ours) > 0 and int(houses.theirs) > 0)
	assert_eq(n, 3 + 2 + 2 + 2 + int(houses.ours))
	assert_eq(b.silver, 0)
	var base: int = r.their_supporters_base + 30 / r.family_standing + int(houses.theirs)
	assert_between(c.their_supporters, base - r.their_supporters_spread, base + r.their_supporters_spread)


func test_tied_standoff_with_arms_turns_violent() -> void:
	var r := WorldRules.new()
	var n := 4000
	var violent := 0
	var band_struck := 0
	for s in n:
		var b := _band(10)
		var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
		c.supporters = 3
		c.their_supporters = 5
		c.their_armed = 6
		var honor := b.honor
		var res := Thing.standoff(SimRng.new(s), r, b, c, PackedStringArray())
		assert_eq(res.weight_us, res.weight_them)
		if res.violence:
			violent += 1
			assert_eq(c.battle_required.kind, "thing_brawl")
			assert_eq(c.battle_required.attackers, 6)
			if res.band_struck:
				band_struck += 1
				assert_eq(b.honor, honor - r.thing_violence_honor)
			else:
				assert_eq(b.honor, honor)
	var rate := float(violent) / n
	print("    thing: violence at a tied armed standoff %.3f (chance %.2f)" % [rate, r.violence_chance])
	assert_between(rate, r.violence_chance - 0.04, r.violence_chance + 0.04)
	assert_between(float(band_struck) / violent, 0.4, 0.6)
	# Unarmed or lopsided: never.
	for s in 500:
		var b := _band(10)
		var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
		c.supporters = 3
		c.their_supporters = 8
		c.their_armed = 0
		assert_true(not Thing.standoff(SimRng.new(s), r, b, c, PackedStringArray()).violence)
		c.supporters = 20
		c.their_armed = 6
		assert_true(not Thing.standoff(SimRng.new(s), r, b, c, PackedStringArray()).violence)


func _decided(r: WorldRules, w: World, kind: WorldTypes.CaseKind, band_plaintiff: bool, us: float, them: float) -> Array:
	var b := _band(5)
	b.silver = 500
	var c := Thing.open_case(r, b, kind, FAMILY, 30, band_plaintiff)
	c.victim_rank = WorldTypes.Rank.HERSIR
	c.weight_us = us
	c.weight_them = them
	var v := Thing.outcome(SimRng.new(1), r, w, b, c, PackedStringArray())
	return [v, b, c]


func test_outcome_verdicts_and_consequences() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var res := _decided(r, w, WorldTypes.CaseKind.KILLING, true, 12.0, 10.0)
	assert_eq(res[0], WorldTypes.Verdict.COMPENSATION)
	assert_eq(res[2].wergild, Feud.wergild(r, WorldTypes.Rank.HERSIR), "killings pay the dead man's wergild")
	assert_eq(res[1].silver, 500 + 100)
	res = _decided(r, w, WorldTypes.CaseKind.RAID, false, 10.0, 12.0)
	assert_eq(res[0], WorldTypes.Verdict.COMPENSATION)
	assert_eq(res[1].silver, 500 - 30, "the band pays the raid claim")
	res = _decided(r, w, WorldTypes.CaseKind.KILLING, false, 10.0, 16.0)
	assert_eq(res[0], WorldTypes.Verdict.LESSER_OUTLAWRY)
	assert_eq(res[1].outlawry, WorldTypes.Outlawry.LESSER)
	assert_eq(res[1].outlaw_until, 870 + r.lesser_outlawry_years)
	res = _decided(r, w, WorldTypes.CaseKind.KILLING, false, 5.0, 12.0)
	assert_eq(res[0], WorldTypes.Verdict.FULL_OUTLAWRY)
	assert_eq(res[1].outlawry, WorldTypes.Outlawry.FULL)
	res = _decided(r, w, WorldTypes.CaseKind.RAID, true, 8.0, 10.0)
	assert_eq(res[0], WorldTypes.Verdict.FAILED)
	assert_true(res[2].log[res[2].log.size() - 1].contains("goes to the sword"))
	var f := Feud.find(res[1], FAMILY)
	assert_eq(f.get("place", ""), "hardanger", "the failed case becomes a feud with the family")


func test_slip_sinks_band_case_and_loses_its_defense() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := _band(5)
	var c := Thing.open_case(r, b, WorldTypes.CaseKind.RAID, FAMILY, 30, true)
	c.weight_us = 30.0
	c.weight_them = 5.0
	c.procedure_ok = false
	assert_eq(Thing.outcome(SimRng.new(1), r, w, b, c, PackedStringArray()), WorldTypes.Verdict.FAILED)
	var b2 := _band(5)
	b2.silver = 100
	var c2 := Thing.open_case(r, b2, WorldTypes.CaseKind.RAID, FAMILY, 30, false)
	c2.weight_us = 30.0
	c2.weight_them = 5.0
	c2.procedure_ok = false
	assert_eq(Thing.outcome(SimRng.new(1), r, w, b2, c2, PackedStringArray()), WorldTypes.Verdict.COMPENSATION)
	assert_eq(b2.silver, 70)


func test_deterministic() -> void:
	var r := WorldRules.new()
	var logs: Array[PackedStringArray] = []
	for i in 2:
		var w := World.build_norway(r, 870)
		var b := _band(8)
		b.fame = 40
		var c := Thing.open_case(r, b, WorldTypes.CaseKind.KILLING, FAMILY, 0, false)
		var log := PackedStringArray()
		Thing.run(SimRng.new(77), r, w, b, c, 20, log)
		logs.append(log)
		assert_eq(log, c.log.slice(1), "the case keeps its own copy of the lines")
	assert_eq(logs[0], logs[1])
