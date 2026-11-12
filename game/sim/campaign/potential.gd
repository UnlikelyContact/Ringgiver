class_name Potential
extends RefCounted
## Hidden caps (concept.md, The band > Inborn potential). The player never
## sees a number: only saga hints, sharper as the judge of men is better.
##
## judge_level 0: "no one can say". 1: whether the cap is above the current
## stat. 2: the cap's bucket phrase. 3: the bucket phrase, and the best stat
## is named as his greatest gift.


## Bucket of a cap: 0 low (1-3), 1 middling (4-6), 2 high (7-8), 3 great (9-10).
static func bucket(cap: int) -> int:
	if cap <= 3:
		return 0
	if cap <= 6:
		return 1
	if cap <= 8:
		return 2
	return 3


## The stat with the highest cap; ties go to the earlier stat.
static func best_stat(m: Man) -> CombatTypes.Stat:
	var best := 0
	for s in 5:
		if m.potential[s] > m.potential[best]:
			best = s
	return best as CombatTypes.Stat


static func hint(rules: CampaignRules, m: Man, stat: CombatTypes.Stat, judge_level: int) -> String:
	var level := clampi(judge_level, 0, 3)
	if level == 0:
		return rules.hint_unknown
	var cap: int = m.potential[stat]
	if level == 1:
		var room := 1 if cap > m.stats[stat] else 0
		return "%s %s %s" % [m.his(), CombatTypes.STAT_NAMES[stat], rules.hint_room_phrases[room]]
	var phrase: String = rules.hint_phrases[stat][bucket(cap)]
	if level == 3 and stat == best_stat(m):
		phrase += rules.hint_best_marker
	return phrase


## One hint per stat (in stat order), or a single "no one can say" at level 0.
static func hints(rules: CampaignRules, m: Man, judge_level: int) -> PackedStringArray:
	var out := PackedStringArray()
	if judge_level <= 0:
		out.append(rules.hint_unknown)
		return out
	for s in 5:
		out.append(hint(rules, m, s as CombatTypes.Stat, judge_level))
	return out


## The kolbitr: poor now, great later.
static func is_coal_biter(rules: CampaignRules, m: Man) -> bool:
	var avg := float(m.total_stats()) / 5.0
	if avg > rules.coal_biter_max_stat:
		return false
	var high := 0
	for c in m.potential:
		if c >= rules.coal_biter_min_cap:
			high += 1
	return high >= 2
