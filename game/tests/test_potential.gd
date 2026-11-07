extends TestCase


func _man(stats: Array[int], caps: Array[int]) -> Man:
	var m := Man.new()
	m.display_name = "Kol"
	m.stats = stats
	m.potential = caps
	return m


func test_bucket_edges() -> void:
	assert_eq(Potential.bucket(1), 0)
	assert_eq(Potential.bucket(3), 0)
	assert_eq(Potential.bucket(4), 1)
	assert_eq(Potential.bucket(6), 1)
	assert_eq(Potential.bucket(7), 2)
	assert_eq(Potential.bucket(8), 2)
	assert_eq(Potential.bucket(9), 3)
	assert_eq(Potential.bucket(10), 3)


func test_judge_levels() -> void:
	var r := CampaignRules.new()
	var m := _man([3, 5, 3, 3, 3], [9, 5, 2, 7, 4])
	var might := CombatTypes.Stat.MIGHT
	var skill := CombatTypes.Stat.SKILL
	assert_eq(Potential.hint(r, m, might, 0), r.hint_unknown)
	assert_eq(Potential.hints(r, m, 0), PackedStringArray([r.hint_unknown]))
	assert_true(Potential.hint(r, m, might, 1).ends_with(r.hint_room_phrases[1]), "room above current")
	assert_true(Potential.hint(r, m, skill, 1).ends_with(r.hint_room_phrases[0]), "at cap")
	assert_eq(Potential.hint(r, m, might, 2), r.hint_phrases[might][3])
	assert_eq(Potential.hint(r, m, CombatTypes.Stat.GRIT, 2), r.hint_phrases[CombatTypes.Stat.GRIT][0])
	assert_eq(Potential.hint(r, m, CombatTypes.Stat.NERVE, 2), r.hint_phrases[CombatTypes.Stat.NERVE][2])
	assert_eq(Potential.hint(r, m, might, 3), r.hint_phrases[might][3] + r.hint_best_marker)
	assert_eq(Potential.hint(r, m, skill, 3), r.hint_phrases[skill][1], "only the best stat is named")
	var h3 := Potential.hints(r, m, 3)
	assert_eq(h3.size(), 5)
	var named := 0
	for line in h3:
		if line.ends_with(r.hint_best_marker):
			named += 1
	assert_eq(named, 1, "exactly one best stat")


func test_hints_never_show_numbers() -> void:
	var r := CampaignRules.new()
	var rng := SimRng.new(5)
	var digits := RegEx.new()
	digits.compile("[0-9]")
	for i in 200:
		var m := Recruits.random(rng, r, i + 1)
		for level in 4:
			for line in Potential.hints(r, m, level):
				if digits.search(line) != null:
					fail("hint shows a number: %s" % line)
					return


func test_coal_biter() -> void:
	var r := CampaignRules.new()
	assert_true(Potential.is_coal_biter(r, _man([2, 3, 2, 3, 2], [9, 8, 4, 4, 4])))
	assert_true(not Potential.is_coal_biter(r, _man([2, 3, 2, 3, 2], [9, 7, 4, 4, 4])), "one high cap is not enough")
	assert_true(not Potential.is_coal_biter(r, _man([5, 5, 4, 4, 4], [9, 9, 9, 4, 4])), "already good")
