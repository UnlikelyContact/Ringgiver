extends TestCase


func _conflicting(r: CampaignRules, m: Man) -> bool:
	for pair in r.personality_conflicts:
		if m.has_personality(pair[0]) and m.has_personality(pair[1]):
			return true
	return false


func test_recruits_are_valid() -> void:
	var r := CampaignRules.new()
	var rng := SimRng.new(21)
	var origins := {}
	for i in 1000:
		var m := Recruits.random(rng, r, i + 1)
		assert_eq(m.id, i + 1)
		assert_true(m.display_name in Recruits.NAMES)
		assert_true(m.age >= r.join_age_min and m.age <= r.join_age_max, "age %d" % m.age)
		var span: Array = r.origin_age_ranges[m.origin]
		assert_true(m.age >= span[0] and m.age <= span[1], "age in origin range")
		for s in 5:
			assert_true(m.stats[s] >= 1 and m.stats[s] <= 10)
			assert_true(m.potential[s] >= m.stats[s] and m.potential[s] <= 10, "cap at or above stat")
		assert_true(m.personality.size() >= 1 and m.personality.size() <= 2)
		if m.personality.size() == 2:
			assert_ne(m.personality[0], m.personality[1])
		assert_true(not _conflicting(r, m), "contradictory personality")
		assert_true(r.ambition_weights[m.origin].has(m.ambition), "ambition from origin weights")
		assert_true(m.traits.has(r.origin_traits[m.origin]), "origin trait")
		origins[m.origin] = origins.get(m.origin, 0) + 1
	assert_eq(origins.size(), CampaignTypes.Origin.size(), "every origin appears")


func test_replays_from_seed() -> void:
	var r := CampaignRules.new()
	var a := Recruits.random(SimRng.new(4), r, 1)
	var b := Recruits.random(SimRng.new(4), r, 1)
	assert_eq(a.describe(), b.describe())
	assert_eq(a.potential, b.potential)


func _mean_stat(origin: CampaignTypes.Origin, s: int, n: int) -> float:
	var r := CampaignRules.new()
	r.coal_biter_chance = 0.0
	var rng := SimRng.new(77 + origin)
	var total := 0.0
	for i in n:
		total += Recruits.make(rng, r, origin, 22, "Odd", i + 1).stats[s]
	return total / n


func test_origins_shape_recruits() -> void:
	var r := CampaignRules.new()
	var n := 500
	var O := CampaignTypes.Origin
	var S := CombatTypes.Stat
	assert_true(_mean_stat(O.FISHERMAN, S.GRIT, n) > _mean_stat(O.YOUNGER_SON, S.GRIT, n) + 0.5, "fishermen are hardy")
	assert_true(_mean_stat(O.OUTLAW, S.MIGHT, n) > _mean_stat(O.YOUNGER_SON, S.MIGHT, n) + 0.5, "outlaws are strong")
	assert_true(_mean_stat(O.OUTLAW, S.NERVE, n) > _mean_stat(O.YOUNGER_SON, S.NERVE, n) + 0.5, "outlaws are bold")
	assert_true(_mean_stat(O.FREEDMAN, S.SKILL, n) < _mean_stat(O.YOUNGER_SON, S.SKILL, n) - 0.5, "freedmen start low")
	assert_true(_mean_stat(O.EXILED_JARLS_SON, S.SKILL, n) > _mean_stat(O.YOUNGER_SON, S.SKILL, n) + 0.5, "jarl's sons are trained")
	assert_true(_mean_stat(O.EXILED_JARLS_SON, S.WITS, n) > _mean_stat(O.YOUNGER_SON, S.WITS, n) + 0.5)
	var rng := SimRng.new(3)
	var outlaw := Recruits.make(rng, r, O.OUTLAW, 25, "Ospak", 1)
	var freed := Recruits.make(rng, r, O.FREEDMAN, 25, "Kol", 2)
	var son := Recruits.make(rng, r, O.YOUNGER_SON, 25, "Bolli", 3)
	assert_true(outlaw.loyalty < son.loyalty, "outlaw loyalty starts low")
	assert_true(freed.loyalty > son.loyalty, "freedman loyalty starts high")
	for i in 50:
		var j := Recruits.make(rng, r, O.EXILED_JARLS_SON, 18, "Hakon", 10 + i)
		assert_eq(j.ambition, CampaignTypes.Ambition.FAME, "exiled jarl's son wants fame")
	assert_true(Recruits.make(rng, r, O.FISHERMAN, 20, "Ari", 99).traits.has("good at sea"))


func test_coal_biter_chance() -> void:
	var r := CampaignRules.new()
	var rng := SimRng.new(8)
	var n := 4000
	var coal := 0
	for i in n:
		if Potential.is_coal_biter(r, Recruits.random(rng, r, i + 1)):
			coal += 1
	# Rolled coal-biters plus the occasional natural one.
	assert_between(float(coal) / n, r.coal_biter_chance * 0.8, r.coal_biter_chance * 2.0)
	r.coal_biter_chance = 1.0
	for i in 100:
		assert_true(Potential.is_coal_biter(r, Recruits.random(rng, r, i + 1)), "forced coal-biter")


func test_son_of_inherits_caps() -> void:
	var r := CampaignRules.new()
	var rng := SimRng.new(12)
	var father := Man.new()
	father.display_name = "Thorstein"
	father.potential = [10, 10, 2, 6, 6]
	var mother: Array[int] = [8, 2, 2, 6, 6]
	var means := [9.0, 6.0, 2.0, 6.0, 6.0]
	var sums := [0.0, 0.0, 0.0, 0.0, 0.0]
	var n := 2000
	for i in n:
		var s := Recruits.son_of(rng, r, father, mother, "Egil", i + 1)
		assert_true(s.traits.has("son of Thorstein"))
		for k in 5:
			assert_true(absi(s.potential[k] - int(means[k])) <= r.inherit_spread, "within the spread")
			assert_true(s.stats[k] <= s.potential[k])
			sums[k] += s.potential[k]
	for k in 5:
		# Clamping at 1 and 10 pulls the mean in a little.
		assert_between(sums[k] / n, means[k] - 0.8, means[k] + 0.8, "stat %d" % k)
