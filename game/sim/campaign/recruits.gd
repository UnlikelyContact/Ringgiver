class_name Recruits
extends RefCounted
## New men: origin sets starting stats, a trait, age, loyalty and what he
## wants; caps are rolled per stat, and a few recruits are coal-biters.

const NAMES := [
	"Agnar", "Alf", "Ari", "Arnbjorn", "Asbjorn", "Atli", "Bersi", "Bodvar",
	"Bolli", "Brand", "Dag", "Einar", "Eirik", "Eyolf", "Finnbogi", "Frodi",
	"Gest", "Glum", "Grettir", "Gudmund", "Hakon", "Hall", "Hallbjorn", "Harek",
	"Hauk", "Hedin", "Helgi", "Hogni", "Hrafn", "Illugi", "Ingjald", "Isleif",
	"Jokul", "Kalf", "Kolbein", "Kol", "Leif", "Ljot", "Magnus", "Odd",
	"Ospak", "Ottar", "Ref", "Runolf", "Saemund", "Skeggi", "Snorri", "Solvi",
	"Starkad", "Steinthor", "Sturla", "Svein", "Thorbjorn", "Thord", "Thorgeir", "Thorstein",
	"Thrand", "Tosti", "Ulfar", "Vagn", "Vermund", "Vestein", "Ymir", "Ozur",
]


static func _weighted(rng: SimRng, weights: Dictionary) -> int:
	var keys := weights.keys()
	keys.sort()
	var total := 0
	for k in keys:
		total += int(weights[k])
	var r := rng.randi_range(1, maxi(1, total))
	for k in keys:
		r -= int(weights[k])
		if r <= 0:
			return k
	return keys[0]


static func _conflicts(rules: CampaignRules, a: CombatTypes.Personality, b: CombatTypes.Personality) -> bool:
	for pair in rules.personality_conflicts:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


## One or two personality traits, never contradictory, never repeated.
static func roll_personality(rng: SimRng, rules: CampaignRules) -> Array[CombatTypes.Personality]:
	var out: Array[CombatTypes.Personality] = []
	var n := CombatTypes.Personality.size()
	out.append(rng.randi_range(0, n - 1) as CombatTypes.Personality)
	if rng.randf() < rules.second_personality_chance:
		var options: Array[CombatTypes.Personality] = []
		for i in n:
			var p := i as CombatTypes.Personality
			if p != out[0] and not _conflicts(rules, out[0], p):
				options.append(p)
		out.append(options[rng.randi_range(0, options.size() - 1)])
	return out


static func roll_ambition(rng: SimRng, rules: CampaignRules, origin: CampaignTypes.Origin) -> CampaignTypes.Ambition:
	var w: Dictionary = rules.ambition_weights.get(origin, {})
	if w.is_empty():
		return CampaignTypes.Ambition.SILVER
	return _weighted(rng, w) as CampaignTypes.Ambition


static func _roll_cap(rng: SimRng, rules: CampaignRules) -> int:
	return clampi(rules.cap_mean + rng.randi_range(-rules.cap_spread, rules.cap_spread), 1, 10)


static func make(rng: SimRng, rules: CampaignRules, origin: CampaignTypes.Origin, age: int, name: String, id: int) -> Man:
	var m := Man.new()
	m.id = id
	m.display_name = name
	m.origin = origin
	m.age = age
	m.born = rules.start_year - age
	var bias: Array = rules.origin_stat_bias.get(origin, [0, 0, 0, 0, 0])
	var stats: Array[int] = []
	var caps: Array[int] = []
	var coal := rng.randf() < rules.coal_biter_chance
	for s in 5:
		var v := rules.recruit_stat_base + rng.randi_range(-rules.recruit_stat_spread, rules.recruit_stat_spread) + int(bias[s])
		stats.append(clampi(v, 1, 10))
		caps.append(_roll_cap(rng, rules))
	if coal:
		# Low now, great later: two (distinct) stats get high caps.
		for s in 5:
			stats[s] = rng.randi_range(1, clampi(rules.coal_biter_max_stat, 1, 10))
		var a := rng.randi_range(0, 4)
		var b := (a + rng.randi_range(1, 4)) % 5
		caps[a] = rng.randi_range(clampi(rules.coal_biter_min_cap, 1, 10), 10)
		caps[b] = rng.randi_range(clampi(rules.coal_biter_min_cap, 1, 10), 10)
	for s in 5:
		caps[s] = maxi(caps[s], stats[s])
	m.stats = stats
	m.potential = caps
	m.effort = [0, 0, 0, 0, 0]
	m.personality = roll_personality(rng, rules)
	m.ambition = roll_ambition(rng, rules, origin)
	m.loyalty = int(rules.origin_loyalty.get(origin, rules.loyalty_start))
	var t: String = rules.origin_traits.get(origin, "")
	if t != "":
		m.traits.append(t)
	return m


## A man of random origin, age (from that origin's range) and name.
static func random(rng: SimRng, rules: CampaignRules, id: int) -> Man:
	var origin := _weighted(rng, rules.origin_weights) as CampaignTypes.Origin
	var span: Array = rules.origin_age_ranges.get(origin, [rules.join_age_min, rules.join_age_max])
	var lo := clampi(int(span[0]), rules.join_age_min, rules.join_age_max)
	var hi := clampi(int(span[1]), lo, rules.join_age_max)
	var age := rng.randi_range(lo, hi)
	var name: String = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	return make(rng, rules, origin, age, name, id)


## A son: caps are the mean of his father's and mother's, ± inherit_spread.
## He comes of age at join_age_min with his father's origin; the campaign
## loop may set his age and birth year afterwards.
static func son_of(rng: SimRng, rules: CampaignRules, father: Man, mother_potential: Array[int], name: String, id: int) -> Man:
	var m := make(rng, rules, father.origin, rules.join_age_min, name, id)
	var caps: Array[int] = []
	for s in 5:
		var mother: int = mother_potential[s] if s < mother_potential.size() else father.potential[s]
		var mean := int(round((father.potential[s] + mother) / 2.0))
		caps.append(clampi(mean + rng.randi_range(-rules.inherit_spread, rules.inherit_spread), 1, 10))
	for s in 5:
		m.stats[s] = mini(m.stats[s], caps[s])
	m.potential = caps
	m.traits.append("son of %s" % father.display_name)
	m.natures = Natures.inherit(rng.fork("nature"), rules, father)
	return m
