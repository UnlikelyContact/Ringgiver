extends TestCase
## "Your men" as the saga tells them (view/men_panel.gd): strengths in
## four steps of words, never a number unless asked; loyalty and ambition
## in words; the one line a man is known for; the judge of men's sight.


func _man(stats: Array[int]) -> Man:
	var m := Man.new()
	m.display_name = "Atli"
	m.stats = stats
	return m


func test_strength_comes_in_four_steps_of_words() -> void:
	assert_eq(MenPanel.step_of(1), 0)
	assert_eq(MenPanel.step_of(3), 0)
	assert_eq(MenPanel.step_of(4), 1)
	assert_eq(MenPanel.step_of(6), 2)
	assert_eq(MenPanel.step_of(8), 3)
	assert_eq(MenPanel.step_of(10), 3)
	for s in 5:
		var seen := {}
		for v in range(1, 11):
			var w := MenPanel.stat_words(s, v)
			assert_true(w != "" and not w.is_valid_int(), "words, not a number")
			seen[w] = true
		assert_eq(seen.size(), 4, "four steps for %s" % CombatTypes.STAT_NAMES[s])


func test_loyalty_and_ambition_in_words() -> void:
	var rules := CampaignRules.new()
	var m := _man([5, 5, 5, 5, 5])
	m.loyalty = rules.loyalty_leave_below - 1
	assert_true(MenPanel.loyalty_words(rules, m).contains("thaw"), "a man about to leave says so")
	m.loyalty = 95
	assert_true(MenPanel.loyalty_words(rules, m).contains("die"), "a sworn man would die for you")
	m.ambition = CampaignTypes.Ambition.SILVER
	m.ambition_met = true
	assert_true(MenPanel.ambition_words(rules, m).contains("has had it"))
	m.ambition = CampaignTypes.Ambition.HOME
	m.ambition_met = false
	assert_true(MenPanel.ambition_words(rules, m).begins_with("He wants to go home"))


func test_what_a_man_is_known_for() -> void:
	var rules := CampaignRules.new()
	var m := _man([3, 7, 4, 4, 4])
	m.origin = CampaignTypes.Origin.YOUNGER_SON
	m.traits.append(str(rules.origin_traits.get(m.origin, "landless")))
	var line := MenPanel.known_for(rules, m)
	assert_true(line.to_lower().contains("skilled"), "his best gift, in words (%s)" % line)
	assert_true(not line.to_lower().contains(str(rules.origin_traits.get(m.origin, "@"))), "not what his birth gave him")
	m.kills = 3
	assert_true(MenPanel.known_for(rules, m).contains("3 men"))
	m.deeds.append("put down 3 men in one fight")
	assert_true(MenPanel.known_for(rules, m).contains("one fight"), "a deed first")


func test_the_judge_of_men_sees_by_his_wits() -> void:
	var b := Band.new()
	b.leader = _man([5, 5, 5, 5, 2])
	assert_eq(MenPanel.judge_level(b), 1)
	b.leader.stats[CombatTypes.Stat.WITS] = 5
	assert_eq(MenPanel.judge_level(b), 2)
	b.leader.stats[CombatTypes.Stat.WITS] = 8
	assert_eq(MenPanel.judge_level(b), 3)


func test_the_band_in_its_order() -> void:
	var b := Band.new()
	b.leader = _man([5, 5, 5, 5, 5])
	var a := _man([4, 4, 4, 4, 4])
	var d := _man([4, 4, 4, 4, 4])
	d.alive = false
	b.add_man(a)
	b.add_man(d)
	var people := MenPanel.people(b)
	assert_eq(people.size(), 2, "the dead are not listed")
	assert_true(people[0] == b.leader, "the leader first")
