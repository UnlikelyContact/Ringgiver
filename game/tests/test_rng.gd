extends TestCase


func test_same_seed_same_sequence() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	for i in 50:
		assert_eq(a.roll_2d6(), b.roll_2d6(), "roll %d" % i)


func test_different_seed_different_sequence() -> void:
	var a := SimRng.new(1)
	var b := SimRng.new(2)
	var same := true
	for i in 20:
		if a.d6() != b.d6():
			same = false
	assert_true(not same, "two seeds should not produce identical 20-roll runs")


func test_d6_in_range() -> void:
	var rng := SimRng.new(7)
	for i in 1000:
		var v := rng.d6()
		assert_true(v >= 1 and v <= 6, "d6 gave %d" % v)


func test_fork_is_deterministic_and_distinct() -> void:
	var root := SimRng.new(99)
	var f1 := root.fork("melee")
	var f2 := SimRng.new(99).fork("melee")
	var other := root.fork("missiles")
	assert_eq(f1.seed_value, f2.seed_value)
	assert_ne(f1.seed_value, other.seed_value)
