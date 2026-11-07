extends TestCase


func _man(p_name: String, tier: CombatTypes.Tier, pos: Vector2i, g: BattleGrid, wits := 3) -> Warrior:
	var w := Warrior.make(p_name, 0, [4, 4, 4, 4, wits], tier)
	w.reset_for_battle(CombatRules.new())
	g.place(w, pos)
	return w


func test_hear_chance_certain_inside_radius() -> void:
	var r := CombatRules.new()
	for d in r.hear_certain_radius + 1:
		assert_eq(Shouts.hear_chance(r, d, 1, false, true), 1.0, "distance %d in fog" % d)
	var edge := r.hear_certain_radius + r.hear_horn_radius_bonus
	assert_eq(Shouts.hear_chance(r, edge, 1, true, true), 1.0, "horn widens the radius")
	assert_true(Shouts.hear_chance(r, edge, 1, false, false) < 1.0, "no horn, same distance")


func test_hear_chance_monotonic() -> void:
	var r := CombatRules.new()
	for fog in [false, true]:
		for horn in [false, true]:
			for wits in range(1, 11):
				var prev := 2.0
				for d in range(0, 16):
					var c := Shouts.hear_chance(r, d, wits, horn, fog)
					assert_between(c, 0.0, 1.0)
					assert_true(c <= prev, "falls with distance (d %d wits %d)" % [d, wits])
					prev = c
	for d in range(3, 10):
		for wits in range(1, 10):
			assert_true(Shouts.hear_chance(r, d, wits + 1, false, false) >= Shouts.hear_chance(r, d, wits, false, false),
					"rises with wits")
		assert_true(Shouts.hear_chance(r, d, 4, false, true) <= Shouts.hear_chance(r, d, 4, false, false),
				"fog never helps")
		assert_true(Shouts.hear_chance(r, d, 4, true, false) >= Shouts.hear_chance(r, d, 4, false, false),
				"horn never hurts")
	assert_true(Shouts.hear_chance(r, 5, 3, false, true) < Shouts.hear_chance(r, 5, 3, false, false))
	assert_eq(Shouts.hear_chance(r, 40, 3, false, true), 0.0, "far away in fog: nothing")


func test_near_men_always_hear() -> void:
	var r := CombatRules.new()
	for s in 200:
		var g := BattleGrid.new(16, 12)
		var leader := _man("jarl", CombatTypes.Tier.VETERAN, Vector2i(5, 5), g)
		var m := _man("near", CombatTypes.Tier.GREEN, Vector2i(7, 5), g)
		var band: Array[Warrior] = [m]
		var log := PackedStringArray()
		Shouts.propagate(SimRng.new(s), r, g, leader, CombatTypes.Shout.HOLD, band, true, log)
		assert_eq(m.heard_order, CombatTypes.Shout.HOLD)
		assert_eq(log.size(), 0)


func test_none_propagates_nothing() -> void:
	var r := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", CombatTypes.Tier.VETERAN, Vector2i(5, 5), g)
	var m := _man("m", CombatTypes.Tier.GREEN, Vector2i(6, 5), g)
	m.heard_order = CombatTypes.Shout.PUSH
	var band: Array[Warrior] = [m]
	Shouts.propagate(SimRng.new(1), r, g, leader, CombatTypes.Shout.NONE, band, false, PackedStringArray())
	assert_eq(m.heard_order, CombatTypes.Shout.PUSH)
	assert_eq(m.order_lag, 0)


func _mishear_trials(tier: CombatTypes.Tier, shout: CombatTypes.Shout, trials: int) -> Dictionary:
	# Returns counts: heard, kept, misheard; fails on any same/NONE mishearing.
	var r := CombatRules.new()
	var out := {"heard": 0, "kept": 0, "misheard": 0}
	for s in trials:
		var g := BattleGrid.new(20, 12)
		var leader := _man("jarl", CombatTypes.Tier.VETERAN, Vector2i(1, 5), g)
		var m := _man("far", tier, Vector2i(9, 5), g)
		m.heard_order = CombatTypes.Shout.NONE
		var band: Array[Warrior] = [m]
		var log := PackedStringArray()
		Shouts.propagate(SimRng.new(s), r, g, leader, shout, band, true, log)
		if m.heard_order == shout:
			out["heard"] += 1
			assert_eq(log.size(), 0)
		elif m.heard_order == CombatTypes.Shout.NONE:
			out["kept"] += 1
			assert_eq(log.size(), 0)
		else:
			out["misheard"] += 1
			assert_eq(log.size(), 1, "each mishearing is logged")
	return out


func test_mishearing_never_same_or_none() -> void:
	# A wits-3 man 8 cells out in fog almost never hears, so most outcomes are
	# keep-or-mishear; a mishearing must always be some other real shout.
	for shout in [CombatTypes.Shout.SHIELD_WALL, CombatTypes.Shout.HOLD, CombatTypes.Shout.SVINFYLKING]:
		var c := _mishear_trials(CombatTypes.Tier.GREEN, shout, 2000)
		assert_true(c["misheard"] > 500, "green men mishear often (%s)" % str(c))


func test_mishear_rate_by_tier() -> void:
	var green := _mishear_trials(CombatTypes.Tier.GREEN, CombatTypes.Shout.HOLD, 3000)
	var blooded := _mishear_trials(CombatTypes.Tier.BLOODED, CombatTypes.Shout.HOLD, 3000)
	var veteran := _mishear_trials(CombatTypes.Tier.VETERAN, CombatTypes.Shout.HOLD, 3000)
	assert_true(green["misheard"] > blooded["misheard"] and blooded["misheard"] > veteran["misheard"],
			"%s %s %s" % [green, blooded, veteran])
	var r := CombatRules.new()
	var missed: int = green["kept"] + green["misheard"]
	assert_between(float(green["misheard"]) / missed, r.mishear_green - 0.05, r.mishear_green + 0.05)


func test_champion_never_mishears() -> void:
	var c := _mishear_trials(CombatTypes.Tier.CHAMPION, CombatTypes.Shout.SHIELD_WALL, 3000)
	assert_eq(c["misheard"], 0)
	assert_true(c["kept"] > 0, "he does still miss shouts")


func test_green_lag_only_on_new_order() -> void:
	var r := CombatRules.new()
	var lagged := 0
	var trials := 3000
	for s in trials:
		var g := BattleGrid.new(16, 12)
		var leader := _man("jarl", CombatTypes.Tier.VETERAN, Vector2i(5, 5), g)
		var green := _man("g", CombatTypes.Tier.GREEN, Vector2i(6, 5), g)
		var vet := _man("v", CombatTypes.Tier.VETERAN, Vector2i(4, 5), g)
		var band: Array[Warrior] = [green, vet]
		var rng := SimRng.new(s)
		Shouts.propagate(rng, r, g, leader, CombatTypes.Shout.HOLD, band, false, PackedStringArray())
		assert_eq(vet.order_lag, 0)
		lagged += green.order_lag
		green.order_lag = 0
		Shouts.propagate(rng, r, g, leader, CombatTypes.Shout.HOLD, band, false, PackedStringArray())
		assert_eq(green.order_lag, 0, "repeating the same order adds no lag")
	assert_between(float(lagged) / trials, r.green_lag_chance - 0.04, r.green_lag_chance + 0.04)


func test_banner_and_horn_extend_hearing() -> void:
	var r := CombatRules.new()
	var counts := [0, 0, 0]
	for variant in 3:
		for s in 1000:
			var g := BattleGrid.new(20, 12)
			var leader := _man("jarl", CombatTypes.Tier.VETERAN, Vector2i(1, 5), g)
			var m := _man("far", CombatTypes.Tier.CHAMPION, Vector2i(5, 5), g)
			var helper := _man("helper", CombatTypes.Tier.VETERAN, Vector2i(1, 6), g)
			helper.is_banner = variant == 1
			helper.is_horn = variant == 2
			var band: Array[Warrior] = [m, helper]
			Shouts.propagate(SimRng.new(s), r, g, leader, CombatTypes.Shout.HOLD, band, true, PackedStringArray())
			if m.heard_order == CombatTypes.Shout.HOLD:
				counts[variant] += 1
	assert_true(counts[0] < 1000, "unaided at distance 5 in fog: not certain")
	assert_eq(counts[1], 1000, "banner makes it certain")
	assert_eq(counts[2], 1000, "horn makes it certain")


func test_propagate_is_deterministic() -> void:
	var r := CombatRules.new()
	var a := PackedStringArray()
	var b := PackedStringArray()
	for log in [a, b]:
		var g := BattleGrid.new(20, 12)
		var leader := _man("jarl", CombatTypes.Tier.VETERAN, Vector2i(1, 5), g)
		var band: Array[Warrior] = []
		for i in 8:
			band.append(_man("m%d" % i, CombatTypes.Tier.GREEN, Vector2i(5 + i, 2 + i % 3), g))
		Shouts.propagate(SimRng.new(77), r, g, leader, CombatTypes.Shout.PUSH, band, true, log)
		for m in band:
			log.append(str(m.heard_order, m.order_lag))
	assert_eq(a, b)
