class_name Growth
extends RefCounted
## Effort pools, growth to the hidden caps, aging and tiers (concept.md,
## The band > Effort, Personality as Natures, Experience tiers, Wounds and age).


## Multiplier on effort into `stat` from the man's personality traits.
static func nature_multiplier(rules: CampaignRules, m: Man, stat: CombatTypes.Stat) -> float:
	var mult := 1.0
	for p in m.personality:
		if not rules.nature_effects.has(p):
			continue
		var pair: Array = rules.nature_effects[p]
		if pair[0] == stat:
			mult *= rules.nature_up
		elif pair[1] == stat:
			mult *= rules.nature_down
	return mult * Natures.multiplier(rules, m, stat)


static func age_multiplier(rules: CampaignRules, m: Man) -> float:
	if m.age < 20:
		return rules.age_growth_under_20
	if m.age <= 25:
		return rules.age_growth_20_25
	if m.age <= 35:
		return rules.age_growth_26_35
	return rules.age_growth_36_plus


## Effort a point of `stat` costs now: growth_pool_per_point x stat, doubled
## once the man's stat total is at or above the loose total cap.
static func threshold(rules: CampaignRules, m: Man, stat: CombatTypes.Stat) -> int:
	var t: int = rules.growth_pool_per_point * m.stats[stat]
	if m.total_stats() >= rules.total_soft_cap:
		t *= 2
	return t


## Adds effort to a pool after nature and age multipliers (rounded).
static func add_effort(rules: CampaignRules, m: Man, stat: CombatTypes.Stat, amount: int, log: PackedStringArray) -> void:
	if amount <= 0:
		return
	var scaled := int(round(amount * nature_multiplier(rules, m, stat) * age_multiplier(rules, m)))
	m.effort[stat] += scaled
	if scaled != amount:
		log.append("%s: %d effort in %s (%d before nature and age)" % [
			m.display_name, scaled, CombatTypes.STAT_NAMES[stat], amount])


## Raises each stat whose pool has reached its threshold by one point, never
## above its cap. A stat at its cap wastes its pool. Returns the stats that rose.
static func apply_growth(rules: CampaignRules, m: Man, log: PackedStringArray) -> Array[CombatTypes.Stat]:
	var rose: Array[CombatTypes.Stat] = []
	for s in 5:
		var stat := s as CombatTypes.Stat
		if m.stats[s] >= m.potential[s]:
			m.effort[s] = 0
			continue
		var t := threshold(rules, m, stat)
		if m.effort[s] >= t:
			m.effort[s] -= t
			m.stats[s] += 1
			rose.append(stat)
			log.append("%s grows in %s (%d)" % [m.display_name, CombatTypes.STAT_NAMES[s], m.stats[s]])
			if m.stats[s] >= m.potential[s]:
				m.effort[s] = 0
	return rose


## One winter: +1 year; from decline_age Might or Grit may drop a point
## (chance doubled from old_age). Tier never falls.
static func winter_age(rng: SimRng, rules: CampaignRules, m: Man, log: PackedStringArray) -> void:
	m.age += 1
	if m.age < rules.decline_age:
		return
	var chance := rules.decline_chance * (2.0 if m.age >= rules.old_age else 1.0)
	if rng.randf() >= chance:
		return
	var first := CombatTypes.Stat.MIGHT if rng.randi_range(0, 1) == 0 else CombatTypes.Stat.GRIT
	var other := CombatTypes.Stat.GRIT if first == CombatTypes.Stat.MIGHT else CombatTypes.Stat.MIGHT
	var s := first
	if m.stats[s] <= 1:
		s = other
	if m.stats[s] <= 1:
		return
	m.stats[s] -= 1
	if rules.decline_lowers_cap:
		m.potential[s] = maxi(m.stats[s], m.potential[s] - 1)
	log.append("%s, %d winters old, loses %s (%d)" % [m.display_name, m.age, CombatTypes.STAT_NAMES[s], m.stats[s]])


## Winter drill: deliberate effort into one stat.
static func drill(rules: CampaignRules, m: Man, stat: CombatTypes.Stat, log: PackedStringArray) -> void:
	log.append("%s drills %s" % [m.display_name, CombatTypes.STAT_NAMES[stat]])
	add_effort(rules, m, stat, rules.drill_effort, log)


## The tier his battles have earned, never below the tier he holds.
static func tier_for(rules: CampaignRules, m: Man) -> CombatTypes.Tier:
	var earned := CombatTypes.Tier.GREEN
	if m.battles_survived >= rules.tier_blooded_battles:
		earned = CombatTypes.Tier.BLOODED
	if m.battles_survived >= rules.tier_veteran_battles:
		earned = CombatTypes.Tier.VETERAN
	if m.battles_survived >= rules.tier_champion_battles:
		var best := 0
		for v in m.stats:
			best = maxi(best, v)
		if best >= rules.tier_champion_min_stat:
			earned = CombatTypes.Tier.CHAMPION
	return maxi(earned, m.tier) as CombatTypes.Tier
