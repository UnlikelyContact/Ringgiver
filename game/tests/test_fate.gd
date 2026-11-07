extends TestCase


func _downed(grit: int) -> Warrior:
	var w := Warrior.make("w", 0, [4, 4, grit, 4, 4])
	w.wound = CombatTypes.Wound.DOWN
	return w


func _shares(grit: int, seed: int, n: int) -> Array:
	var r := CombatRules.new()
	var rng := SimRng.new(seed)
	var counts := [0, 0, 0]
	for i in n:
		var w := _downed(grit)
		var f := Fate.roll(rng, r, w)
		assert_eq(w.fate, f, "roll sets w.fate")
		counts[f] += 1
	return [float(counts[0]) / n, float(counts[1]) / n, float(counts[2]) / n]


## 2d6 + Grit 4 with defaults: dead below 7 (2d6 <= 2: 1/36), maimed below 10
## (2d6 3-5: 9/36), else recovered (26/36).
func test_distribution_matches_thresholds() -> void:
	var s := _shares(4, 7, 20000)
	assert_between(s[CombatTypes.Fate.DEAD], 0.018, 0.038, "dead")
	assert_between(s[CombatTypes.Fate.MAIMED], 0.23, 0.27, "maimed")
	assert_between(s[CombatTypes.Fate.RECOVERED], 0.70, 0.745, "recovered")


func test_grit_improves_survival() -> void:
	var weak := _shares(1, 8, 10000)
	var tough := _shares(8, 9, 10000)
	assert_true(weak[CombatTypes.Fate.DEAD] > tough[CombatTypes.Fate.DEAD] + 0.1)
	assert_true(tough[CombatTypes.Fate.RECOVERED] > weak[CombatTypes.Fate.RECOVERED] + 0.3)
	assert_eq(tough[CombatTypes.Fate.DEAD], 0.0, "grit 8 can never roll below 7")


func test_boundaries_by_threshold() -> void:
	var r := CombatRules.new()
	# Grit high enough that even snake eyes reaches fate_maimed_below.
	var w := _downed(r.fate_maimed_below - 2)
	assert_eq(Fate.roll(SimRng.new(1), r, w), CombatTypes.Fate.RECOVERED)
	# Thresholds above any possible roll: always dead.
	r.fate_dead_below = 100
	r.fate_maimed_below = 100
	assert_eq(Fate.roll(SimRng.new(1), r, _downed(4)), CombatTypes.Fate.DEAD)


func test_unhurt_man_recovers() -> void:
	var r := CombatRules.new()
	r.fate_dead_below = 100
	var w := Warrior.make("w", 0, [4, 4, 4, 4, 4])
	w.wound = CombatTypes.Wound.GRIEVOUS
	assert_eq(Fate.roll(SimRng.new(1), r, w), CombatTypes.Fate.RECOVERED)
	assert_eq(w.fate, CombatTypes.Fate.RECOVERED)


func test_replayable() -> void:
	var a := _shares(4, 42, 200)
	var b := _shares(4, 42, 200)
	assert_eq(a, b)
