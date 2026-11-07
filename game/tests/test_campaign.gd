extends TestCase
## Milestone 2 gate: a ten-year campaign runs without error and replays
## exactly; men grow and reach tiers; an unfed band scatters; a dead leader
## is succeeded; marriage and a sworn second keep the saga alive.


func _campaign(seed_in: int, rules: CampaignRules = null) -> Campaign:
	var c := Campaign.new(seed_in, rules)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 4)
	return c


func test_ten_years_run_and_replay_exactly() -> void:
	var a := _campaign(11)
	var b := _campaign(11)
	a.run_years(10)
	b.run_years(10)
	assert_eq(a.summary(), b.summary())
	assert_eq(a.band.chronicle.size(), b.band.chronicle.size())
	assert_eq(a.log.size(), b.log.size())
	for i in mini(a.log.size(), b.log.size()):
		if a.log[i] != b.log[i]:
			fail("log diverges at %d: %s | %s" % [i, a.log[i], b.log[i]])
			break
	assert_true(a.tally.battles >= 3, "battles were fought")


func test_men_grow_and_reach_tiers() -> void:
	var grew := 0
	var tiered := 0
	var n := 8
	for i in n:
		var c := _campaign(200 + i)
		var start := {}
		for m in c.band.men:
			start[m.id] = m.total_stats()
		c.run_years(10)
		for m in c.band.living_men():
			if start.has(m.id) and m.total_stats() > start[m.id]:
				grew += 1
			if m.tier >= CombatTypes.Tier.BLOODED:
				tiered += 1
	assert_true(grew >= 4, "original men who grew: %d" % grew)
	assert_true(tiered >= 8, "men at blooded or better: %d" % tiered)


func test_unfed_band_scatters() -> void:
	var rules := CampaignRules.new()
	rules.hunt_rations = 0
	rules.fish_rations = 0
	rules.byre_rations = 0
	rules.plunder_per_win = 0
	rules.fame_per_recruit = 100000
	rules.recruits_min = 0
	var left := 0
	var n := 6
	for i in n:
		var c := _campaign(300 + i, rules)
		c.band.food = 0
		c.band.silver = 0
		c.run_years(3)
		left += c.tally.departures
	assert_true(left >= n * 2, "unfed, unpaid men leave: %d departures over %d campaigns" % [left, n])


func test_leader_death_passes_to_sworn_second() -> void:
	var c := _campaign(42)
	var second := c.band.man_by_id(c.band.sworn_second_id)
	assert_true(second != null, "a second is named at the start")
	var old := c.band.leader
	old.alive = false
	c.succession("battle")
	assert_true(not c.over, "the saga continues")
	assert_eq(c.band.leader, second)
	assert_true(second.is_leader)
	assert_true(not c.band.men.has(second), "the heir is no longer among the men")
	assert_eq(c.tally.successions, 1)


func test_no_heir_ends_the_saga() -> void:
	var c := _campaign(43)
	c.band.sworn_second_id = -1
	c.band.leader.alive = false
	c.succession("battle")
	assert_true(c.over)
	assert_true(c.over_reason.contains("no heir"))
