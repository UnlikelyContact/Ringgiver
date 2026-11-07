extends TestCase


func _band(n := 10) -> Band:
	var b := Band.new()
	b.ship = Ship.make(WorldTypes.ShipKind.LONGSHIP)
	b.leader = Man.new()
	b.leader.display_name = "Ulf"
	b.silver = 0
	for i in n:
		var m := Man.new()
		m.display_name = "man %d" % i
		b.add_man(m)
	return b


func test_assess_and_raid_request() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var jaeren := w.place("jaeren")
	var b := _band()
	var a := Raiding.assess(r, w, jaeren, b)
	assert_eq(a.defenders, r.defenders_base[WorldTypes.PlaceKind.FARMSTEAD] + jaeren.defenses)
	assert_eq(a.tier, CombatTypes.Tier.GREEN)
	assert_eq(a.expected_plunder, int(jaeren.wealth * r.plunder_fraction))
	assert_eq(Raiding.assess(r, w, w.place("avaldsnes"), b).tier, CombatTypes.Tier.VETERAN)
	var log: PackedStringArray = []
	var req := Raiding.raid(SimRng.new(1), r, w, b, jaeren, log)
	assert_eq(req.kind, "raid")
	assert_eq(req.place, "jaeren")
	assert_eq(req.defenders, a.defenders)
	assert_eq(req.tier, a.tier)
	assert_eq(req.attackers.size(), 11)
	assert_true(req.text != "")
	assert_eq(jaeren.wealth, 35, "raid itself changes nothing")
	jaeren.alertness = 4
	assert_eq(Raiding.assess(r, w, jaeren, b).defenders, a.defenders + 4 * r.defenders_per_alert)
	assert_eq(Raiding.raid(SimRng.new(1), r, w, b, w.place("iceland"), log), {}, "Iceland not yet open")


func test_five_raids_on_jaeren_leave_it_poor_and_wary() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var jaeren := w.place("jaeren")
	var start := jaeren.wealth
	var b := _band()
	var rng := SimRng.new(42)
	var log: PackedStringArray = []
	var takes: Array[int] = []
	for i in 5:
		Raiding.raid(rng, r, w, b, jaeren, log)
		var res := Raiding.after_raid(rng, r, w, b, jaeren, true, log)
		takes.append(res.silver)
	assert_true(jaeren.wealth * 3 < start, "wealth %d of %d" % [jaeren.wealth, start])
	assert_true(jaeren.alertness >= 5, "alertness %d" % jaeren.alertness)
	assert_true(takes[4] < takes[0], "smaller returns: %s" % str(takes))
	print("    gate: five raids on Jæren take %s oz, wealth %d -> %d, alertness %d" % [str(takes), start, jaeren.wealth, jaeren.alertness])
	assert_eq(b.silver, start - jaeren.wealth, "silver taken is wealth lost")
	assert_true(b.captives > 0)
	assert_true(b.cargo.get(WorldTypes.Good.GRAIN, 0) > 0, "grain looted from the farm")
	assert_eq(w.region_alertness[WorldTypes.Region.ROGALAND], 5 * r.region_alert_per_raid)


func test_five_raids_hold_across_seeds() -> void:
	var r := WorldRules.new()
	for seed in 200:
		var w := World.build_norway(r)
		var jaeren := w.place("jaeren")
		var b := _band()
		var rng := SimRng.new(seed)
		var log: PackedStringArray = []
		for i in 5:
			Raiding.after_raid(rng, r, w, b, jaeren, true, log)
		if jaeren.wealth * 3 >= 35:
			fail("seed %d left wealth %d" % [seed, jaeren.wealth])
			return


func test_beacons_double_defenders() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var b := _band()
	for id in ["jaeren", "avaldsnes"]:
		var p := w.place(id)
		w.region_alertness[p.region] = r.beacon_threshold - 1
		var unlit: int = Raiding.assess(r, w, p, b).defenders
		w.region_alertness[p.region] = r.beacon_threshold
		var lit := Raiding.assess(r, w, p, b)
		assert_eq(lit.defenders, unlit * 2, id)
		print("    gate: %s defenders %d, beacons lit %d" % [id, unlit, lit.defenders])
		assert_true(lit.beacons)
	assert_true(not Raiding.assess(r, w, w.place("fitjar"), b).beacons, "other regions are untouched")


func test_lost_raid_still_raises_alertness() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var p := w.place("jaeren")
	var b := _band()
	var log: PackedStringArray = []
	var res := Raiding.after_raid(SimRng.new(3), r, w, b, p, false, log)
	assert_eq(res.silver, 0)
	assert_eq(res.captives, 0)
	assert_true(not res.feud)
	assert_eq(p.wealth, 35)
	assert_eq(p.alertness, r.alert_per_raid)
	assert_eq(w.region_alertness[p.region], r.region_alert_per_raid)


func test_guarded_halls_give_no_captives() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var avaldsnes := w.place("avaldsnes")
	assert_true(avaldsnes.defenses >= r.no_captives_defense)
	var b := _band()
	var log: PackedStringArray = []
	for i in 20:
		assert_eq(Raiding.after_raid(SimRng.new(i), r, w, b, avaldsnes, true, log).captives, 0)


func test_raid_feud_chance_and_recording() -> void:
	var r := WorldRules.new()
	var fired := 0
	var trials := 2000
	for i in trials:
		var w := World.build_norway(r)
		var b := _band(0)
		var log: PackedStringArray = []
		var res := Raiding.after_raid(SimRng.new(i), r, w, b, w.place("jaeren"), true, log)
		if res.feud:
			fired += 1
			assert_eq(b.feuds.size(), 1)
			assert_eq(b.feuds[0].against, "Thorir Long-chin's kin")
			assert_eq(b.feuds[0].place, "jaeren")
		else:
			assert_eq(b.feuds.size(), 0)
	assert_between(float(fired) / trials, r.raid_feud_chance - 0.05, r.raid_feud_chance + 0.05)


func test_strandhogg_food_alertness_feud() -> void:
	var r := WorldRules.new()
	var fired := 0
	var trials := 2000
	for i in trials:
		var w := World.build_norway(r)
		var p := w.place("hardanger")
		var b := _band(0)
		var food := b.food
		var log: PackedStringArray = []
		var res := Raiding.strandhogg(SimRng.new(i), r, w, b, p, log)
		assert_eq(b.food, food + r.strandhogg_food)
		assert_eq(res.food, r.strandhogg_food)
		assert_eq(b.silver, r.strandhogg_silver)
		assert_eq(p.alertness, 1)
		assert_eq(p.wealth, 30 - r.strandhogg_silver)
		if res.feud:
			fired += 1
			assert_eq(b.feuds.size(), 1)
	assert_between(float(fired) / trials, r.strandhogg_feud_chance - 0.04, r.strandhogg_feud_chance + 0.04)


func test_raids_replay_from_rng() -> void:
	var r := WorldRules.new()
	var outs: Array[String] = []
	for k in 2:
		var w := World.build_norway(r)
		var b := _band()
		var rng := SimRng.new(1234)
		var log: PackedStringArray = []
		var results: Array = []
		for id in ["jaeren", "hardanger", "kaupang", "jaeren"]:
			Raiding.raid(rng, r, w, b, w.place(id), log)
			results.append(Raiding.after_raid(rng, r, w, b, w.place(id), true, log))
			results.append(Raiding.strandhogg(rng, r, w, b, w.place("sogn_farms"), log))
		outs.append(str([results, b.silver, b.captives, b.cargo, b.feuds.size(), log]))
	assert_eq(outs[0], outs[1])
