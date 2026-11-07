extends TestCase


func test_gate_full_outlaw_draws_bounty_hunters() -> void:
	var r := WorldRules.new()
	var b := Band.new()
	var cal := Calendar.new(870)
	assert_true(not Outlawry.halls_closed(b, cal))
	Outlawry.declare(r, b, cal, true, PackedStringArray())
	assert_eq(b.outlawry, WorldTypes.Outlawry.FULL)
	assert_true(Outlawry.is_outlawed(b, Calendar.new(900)), "full outlawry is open-ended")
	assert_true(Outlawry.halls_closed(b, cal))
	var n := 4000
	var hits := 0
	for s in n:
		var br := Outlawry.bounty_hunters(SimRng.new(s), r, b, cal, PackedStringArray())
		if not br.is_empty():
			hits += 1
			assert_eq(br.kind, "bounty_hunters")
			assert_eq(br.attackers, r.bounty_crew)
			assert_eq(br.tier, r.bounty_tier)
	var rate := float(hits) / n
	print("    outlawry gate: bounty hunters per voyage roll %.3f (chance %.2f)" % [rate, r.bounty_chance])
	assert_between(rate, r.bounty_chance - 0.03, r.bounty_chance + 0.03)


func test_gate_lesser_outlawry_expires() -> void:
	var r := WorldRules.new()
	var b := Band.new()
	var cal := Calendar.new(870)
	Outlawry.declare(r, b, cal, false, PackedStringArray())
	assert_eq(b.outlawry, WorldTypes.Outlawry.LESSER)
	assert_eq(b.outlaw_until, 870 + r.lesser_outlawry_years)
	for y in range(870, 870 + r.lesser_outlawry_years):
		assert_true(Outlawry.is_outlawed(b, Calendar.new(y)), "outlawed in %d" % y)
		assert_true(Outlawry.halls_closed(b, Calendar.new(y)))
	var after := Calendar.new(870 + r.lesser_outlawry_years)
	assert_true(not Outlawry.is_outlawed(b, after))
	assert_true(not Outlawry.halls_closed(b, after))
	for s in 500:
		assert_true(Outlawry.bounty_hunters(SimRng.new(s), r, b, cal, PackedStringArray()).is_empty(),
				"lesser outlaws are not hunted")


func test_lesser_does_not_soften_full_and_lift_clears() -> void:
	var r := WorldRules.new()
	var b := Band.new()
	var cal := Calendar.new(870)
	Outlawry.declare(r, b, cal, true, PackedStringArray())
	Outlawry.declare(r, b, cal, false, PackedStringArray())
	assert_eq(b.outlawry, WorldTypes.Outlawry.FULL)
	var log := PackedStringArray()
	Outlawry.lift(b, log)
	assert_eq(b.outlawry, WorldTypes.Outlawry.NONE)
	assert_eq(b.outlaw_until, 0)
	assert_true(not Outlawry.is_outlawed(b, cal))
	assert_eq(log.size(), 1)
	for s in 200:
		assert_true(Outlawry.bounty_hunters(SimRng.new(s), r, b, cal, PackedStringArray()).is_empty())


func test_deterministic() -> void:
	var r := WorldRules.new()
	var b := Band.new()
	var cal := Calendar.new(870)
	Outlawry.declare(r, b, cal, true, PackedStringArray())
	for s in 100:
		assert_eq(Outlawry.bounty_hunters(SimRng.new(s), r, b, cal, PackedStringArray()),
				Outlawry.bounty_hunters(SimRng.new(s), r, b, cal, PackedStringArray()))
