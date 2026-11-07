extends TestCase


func test_tier_boundaries() -> void:
	assert_eq(OpposedRoll.tier_for(0), OpposedRoll.Tier.LOCKED)
	assert_eq(OpposedRoll.tier_for(1), OpposedRoll.Tier.GLANCING)
	assert_eq(OpposedRoll.tier_for(2), OpposedRoll.Tier.GLANCING)
	assert_eq(OpposedRoll.tier_for(3), OpposedRoll.Tier.HIT)
	assert_eq(OpposedRoll.tier_for(5), OpposedRoll.Tier.HIT)
	assert_eq(OpposedRoll.tier_for(6), OpposedRoll.Tier.HEAVY)
	assert_eq(OpposedRoll.tier_for(10), OpposedRoll.Tier.HEAVY)


func test_resolve_is_replayable() -> void:
	var a := OpposedRoll.resolve(SimRng.new(5), 3, 3)
	var b := OpposedRoll.resolve(SimRng.new(5), 3, 3)
	assert_eq(a.margin, b.margin)
	assert_eq(a.attacker_total, b.attacker_total)


func test_margin_matches_totals() -> void:
	var r := OpposedRoll.resolve(SimRng.new(11), 4, 2)
	assert_eq(r.margin, r.attacker_total - r.defender_total)
	assert_true(r.attacker_total >= 6 and r.attacker_total <= 16)
	assert_true(r.defender_total >= 4 and r.defender_total <= 14)


## Checks the lethality numbers in concept-review-v1.md: between equal men,
## a 6+ margin happens about 10.8% of the time and a tie about 11.3%.
func test_equal_fighters_distribution() -> void:
	var rng := SimRng.new(2024)
	var n := 40000
	var heavy := 0
	var locked := 0
	for i in n:
		var r := OpposedRoll.resolve(rng, 0, 0)
		match r.tier():
			OpposedRoll.Tier.HEAVY:
				heavy += 1
			OpposedRoll.Tier.LOCKED:
				locked += 1
	assert_between(float(heavy) / n, 0.095, 0.122, "heavy share")
	assert_between(float(locked) / n, 0.100, 0.127, "locked share")


func test_stat_edge_shifts_outcome() -> void:
	var rng := SimRng.new(3)
	var wins := 0
	var n := 20000
	for i in n:
		if OpposedRoll.resolve(rng, 3, 0).attacker_won():
			wins += 1
	# +3 should win clearly more than half but far from always.
	assert_between(float(wins) / n, 0.68, 0.80, "+3 attacker win rate")
