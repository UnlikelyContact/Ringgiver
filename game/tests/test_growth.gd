extends TestCase


func _man(stats: Array[int], caps: Array[int], age := 28) -> Man:
	var m := Man.new()
	m.display_name = "Hrafn"
	m.stats = stats
	m.potential = caps
	m.age = age
	return m


func test_natures_and_age_scale_effort() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var m := _man([3, 3, 3, 3, 3], [8, 8, 8, 8, 8], 28)
	m.personality = [CombatTypes.Personality.RECKLESS]
	Growth.add_effort(r, m, CombatTypes.Stat.MIGHT, 20, log)
	Growth.add_effort(r, m, CombatTypes.Stat.WITS, 20, log)
	Growth.add_effort(r, m, CombatTypes.Stat.GRIT, 20, log)
	assert_eq(m.effort[CombatTypes.Stat.MIGHT], int(round(20 * r.nature_up)))
	assert_eq(m.effort[CombatTypes.Stat.WITS], int(round(20 * r.nature_down)))
	assert_eq(m.effort[CombatTypes.Stat.GRIT], 20)
	var young := _man([3, 3, 3, 3, 3], [8, 8, 8, 8, 8], 17)
	Growth.add_effort(r, young, CombatTypes.Stat.GRIT, 20, log)
	assert_eq(young.effort[CombatTypes.Stat.GRIT], int(round(20 * r.age_growth_under_20)))
	var old := _man([3, 3, 3, 3, 3], [8, 8, 8, 8, 8], 40)
	Growth.add_effort(r, old, CombatTypes.Stat.GRIT, 20, log)
	assert_eq(old.effort[CombatTypes.Stat.GRIT], int(round(20 * r.age_growth_36_plus)))
	var each := {
		CombatTypes.Personality.GRIM: [CombatTypes.Stat.NERVE, CombatTypes.Stat.SKILL],
		CombatTypes.Personality.BOASTFUL: [CombatTypes.Stat.SKILL, CombatTypes.Stat.GRIT],
		CombatTypes.Personality.STEADY: [CombatTypes.Stat.NERVE, CombatTypes.Stat.MIGHT],
		CombatTypes.Personality.GREEDY: [CombatTypes.Stat.WITS, CombatTypes.Stat.NERVE],
		CombatTypes.Personality.SUPERSTITIOUS: [CombatTypes.Stat.GRIT, CombatTypes.Stat.WITS],
	}
	for p in each:
		var n := _man([3, 3, 3, 3, 3], [8, 8, 8, 8, 8], 28)
		n.personality = [p]
		Growth.add_effort(r, n, each[p][0], 20, log)
		Growth.add_effort(r, n, each[p][1], 20, log)
		assert_eq(n.effort[each[p][0]], 25, "up for %d" % p)
		assert_eq(n.effort[each[p][1]], 15, "down for %d" % p)


func test_growth_threshold_one_point_per_call_and_cap() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var m := _man([3, 3, 3, 3, 3], [5, 3, 8, 8, 8])
	m.effort = [200, 200, 29, 30, 0]
	var rose := Growth.apply_growth(r, m, log)
	assert_eq(m.stats, [4, 3, 3, 4, 3] as Array[int])
	assert_true(rose.has(CombatTypes.Stat.MIGHT) and rose.has(CombatTypes.Stat.NERVE) and rose.size() == 2)
	assert_eq(m.effort[CombatTypes.Stat.MIGHT], 170, "pool consumed by the threshold")
	assert_eq(m.effort[CombatTypes.Stat.SKILL], 0, "a capped stat wastes its pool")
	Growth.apply_growth(r, m, log)
	assert_eq(m.stats[CombatTypes.Stat.MIGHT], 5)
	assert_eq(m.effort[CombatTypes.Stat.MIGHT], 0, "reached cap: pool cleared")
	Growth.apply_growth(r, m, log)
	assert_eq(m.stats[CombatTypes.Stat.MIGHT], 5, "never above the cap")


func test_soft_cap_doubles_threshold() -> void:
	var r := CampaignRules.new()
	var below := _man([7, 7, 7, 7, 3], [9, 9, 9, 9, 9])
	var at := _man([7, 7, 7, 7, 4], [9, 9, 9, 9, 9])
	assert_eq(Growth.threshold(r, below, CombatTypes.Stat.MIGHT), 70)
	assert_eq(Growth.threshold(r, at, CombatTypes.Stat.MIGHT), 140, "total 32 is at the soft cap")


func test_tiers_never_fall() -> void:
	var r := CampaignRules.new()
	var m := _man([5, 5, 5, 5, 5], [6, 6, 6, 6, 6])
	assert_eq(Growth.tier_for(r, m), CombatTypes.Tier.GREEN)
	m.battles_survived = r.tier_blooded_battles
	assert_eq(Growth.tier_for(r, m), CombatTypes.Tier.BLOODED)
	m.battles_survived = r.tier_veteran_battles
	assert_eq(Growth.tier_for(r, m), CombatTypes.Tier.VETERAN)
	m.battles_survived = r.tier_champion_battles
	assert_eq(Growth.tier_for(r, m), CombatTypes.Tier.VETERAN, "no stat at the champion minimum")
	m.stats[CombatTypes.Stat.SKILL] = r.tier_champion_min_stat
	assert_eq(Growth.tier_for(r, m), CombatTypes.Tier.CHAMPION)
	m.tier = CombatTypes.Tier.CHAMPION
	m.stats[CombatTypes.Stat.SKILL] = 3
	m.battles_survived = 0
	assert_eq(Growth.tier_for(r, m), CombatTypes.Tier.CHAMPION, "tier never falls")


func test_drill_adds_effort() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var m := _man([3, 3, 3, 3, 3], [8, 8, 8, 8, 8], 28)
	Growth.drill(r, m, CombatTypes.Stat.SKILL, log)
	assert_eq(m.effort[CombatTypes.Stat.SKILL], r.drill_effort)
	assert_true(log.size() >= 1)


func test_aging_declines_from_decline_age() -> void:
	var r := CampaignRules.new()
	var rng := SimRng.new(9)
	var log := PackedStringArray()
	var n := 2000
	var young_drops := 0
	var mid_drops := 0
	var old_drops := 0
	for i in n:
		var y := _man([6, 6, 6, 6, 6], [8, 8, 8, 8, 8], r.decline_age - 5)
		Growth.winter_age(rng, r, y, log)
		young_drops += 30 - y.total_stats()
		var mid := _man([6, 6, 6, 6, 6], [8, 8, 8, 8, 8], r.decline_age)
		mid.tier = CombatTypes.Tier.VETERAN
		Growth.winter_age(rng, r, mid, log)
		assert_eq(mid.age, r.decline_age + 1)
		var lost := 30 - mid.total_stats()
		mid_drops += lost
		if lost > 0:
			assert_true(mid.stats[CombatTypes.Stat.MIGHT] == 5 or mid.stats[CombatTypes.Stat.GRIT] == 5, "might or grit")
		assert_eq(mid.tier, CombatTypes.Tier.VETERAN, "an old veteran keeps his tier")
		var old := _man([6, 6, 6, 6, 6], [8, 8, 8, 8, 8], r.old_age)
		Growth.winter_age(rng, r, old, log)
		old_drops += 30 - old.total_stats()
	assert_eq(young_drops, 0, "no decline before decline_age")
	assert_between(float(mid_drops) / n, r.decline_chance - 0.03, r.decline_chance + 0.03)
	assert_between(float(old_drops) / n, 2 * r.decline_chance - 0.04, 2 * r.decline_chance + 0.04, "doubled from old_age")


## Twenty years of a fixed effort budget per stat, split over four
## seasons, each followed by apply_growth. Aging without decline.
func _simulate(rules: CampaignRules, men: Array[Man], years: int, per_season: int, totals_by_year: Array) -> void:
	var rng := SimRng.new(0)
	var log := PackedStringArray()
	for y in years:
		for season in 4:
			for m in men:
				for s in 5:
					Growth.add_effort(rules, m, s as CombatTypes.Stat, per_season, log)
				Growth.apply_growth(rules, m, log)
				for s in 5:
					if m.stats[s] > m.potential[s]:
						fail("%s exceeds cap in %s" % [m.display_name, CombatTypes.STAT_NAMES[s]])
		var totals: Array[int] = []
		for m in men:
			Growth.winter_age(rng, rules, m, log)
			totals.append(m.total_stats())
		totals_by_year.append(totals)


func _recruits(seed_in: int, rules: CampaignRules, n: int) -> Array[Man]:
	var rng := SimRng.new(seed_in)
	var out: Array[Man] = []
	for i in n:
		out.append(Recruits.random(rng, rules, i + 1))
	return out


func test_gate_growth_over_twenty_years() -> void:
	var trials := 5
	var per_season := 6  # a yearly budget of 24 per stat
	var years := 20
	for t in trials:
		var rules := CampaignRules.new()
		rules.decline_chance = 0.0
		var open := CampaignRules.new()
		open.decline_chance = 0.0
		open.total_soft_cap = 999
		var men := _recruits(1000 + t, rules, 200)
		var same := _recruits(1000 + t, open, 200)
		var coal: Array[bool] = []
		var cap_sum: Array[int] = []
		for m in men:
			coal.append(Potential.is_coal_biter(rules, m))
			var c := 0
			for v in m.potential:
				c += v
			cap_sum.append(c)
		var by_year: Array = []
		var by_year_open: Array = []
		_simulate(rules, men, years, per_season, by_year)
		_simulate(open, same, years, per_season, by_year_open)

		# Men reach their caps and stop.
		var below_soft := 0
		var capped_below_soft := 0
		var capped_early := 0
		var moved_after_cap := 0
		var pool_left_at_cap := 0
		for i in men.size():
			if cap_sum[i] < rules.total_soft_cap:
				below_soft += 1
				if men[i].total_stats() == cap_sum[i]:
					capped_below_soft += 1
			if by_year[9][i] == cap_sum[i]:
				capped_early += 1
				if men[i].total_stats() != cap_sum[i]:
					moved_after_cap += 1
			for s in 5:
				if men[i].stats[s] == men[i].potential[s] and men[i].effort[s] != 0:
					pool_left_at_cap += 1
		var frac_capped := float(capped_below_soft) / below_soft

		# Coal-biters end above average.
		var all_total := 0.0
		var coal_total := 0.0
		var coal_n := 0
		for i in men.size():
			all_total += men[i].total_stats()
			if coal[i]:
				coal_total += men[i].total_stats()
				coal_n += 1
		var mean_all := all_total / men.size()
		var mean_coal := coal_total / maxi(1, coal_n)

		# Total-cap men grow more slowly after it: same men, same effort,
		# with and without the soft cap, over the five years after crossing.
		var gain_capped := 0
		var gain_open := 0
		var crossers := 0
		for i in men.size():
			if cap_sum[i] <= rules.total_soft_cap:
				continue
			var cross := -1
			for y in years:
				if by_year[y][i] >= rules.total_soft_cap:
					cross = y
					break
			if cross < 0 or cross + 5 >= years:
				continue
			crossers += 1
			gain_capped += by_year[cross + 5][i] - by_year[cross][i]
			gain_open += by_year_open[cross + 5][i] - by_year_open[cross][i]
		print("    gate (trial %d): %.0f%% of men under the soft cap at all caps; coal-biters %d end %.1f vs mean %.1f; %d soft-cap crossers gain %d vs %d uncapped in 5 years" % [
			t, 100.0 * frac_capped, coal_n, mean_coal, mean_all, crossers, gain_capped, gain_open])
		assert_between(frac_capped, 0.9, 1.0, "men reach their caps")
		assert_true(capped_early >= 50, "many men capped by year ten (%d)" % capped_early)
		assert_eq(moved_after_cap, 0, "capped men stop")
		assert_eq(pool_left_at_cap, 0, "effort into a capped stat is not banked")
		assert_true(coal_n >= 5, "enough coal-biters to judge (%d)" % coal_n)
		assert_true(mean_coal > mean_all, "coal-biters end above average")
		assert_true(crossers >= 5, "enough men cross the total cap to judge (%d)" % crossers)
		assert_true(gain_capped < gain_open * 0.8, "slower past the total cap")
