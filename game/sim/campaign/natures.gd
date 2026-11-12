class_name Natures
extends RefCounted
## The leader's own nature (concept.md, "Personality as Natures" and
## "Character creation"; docs/design/notes/men-silver.md). At the saga's
## start the player picks two traits, each from a different one of four
## saga pairs (reckless or steady, open-handed or close-fisted,
## silver-tongued or grim, deep-minded or quick to anger). Each pushes his
## growth up in one stat and down in another (Growth.nature_multiplier,
## the same machinery a man's personality uses) and gives an edge that is
## true in the sim, read through Band.gift like a way's (Way.refresh adds
## them). A son inherits a mix of his father's (`inherit`).
##
## The leader's nature does not touch the fight: he is the player's to
## command, and his token acts on the player's word, not on his temper.

## The four pairs; a man has at most one trait of each.
const PAIRS := [
	["reckless", "steady"],
	["open_handed", "close_fisted"],
	["silver_tongued", "grim"],
	["deep_minded", "quick_to_anger"],
]
## How many traits the player picks.
const PICK := 2
## The names as the saga says them.
const NAMES := {
	"reckless": "Reckless", "steady": "Steady",
	"open_handed": "Open-handed", "close_fisted": "Close-fisted",
	"silver_tongued": "Silver-tongued", "grim": "Grim",
	"deep_minded": "Deep-minded", "quick_to_anger": "Quick to anger",
}


static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for pair in PAIRS:
		for k in pair:
			out.append(str(k))
	return out


static func pair_of(key: String) -> int:
	for i in PAIRS.size():
		if (PAIRS[i] as Array).has(key):
			return i
	return -1


static func name_of(key: String) -> String:
	return str(NAMES.get(key, key))


## The stat whose growth goes up and the one that goes down, or [] (the
## open hand and the closed fist move no stat: they are about silver).
static func growth(rules: CampaignRules, key: String) -> Array:
	return rules.nature_growth.get(key, [])


## What the trait does, in one plain line, from the rules' own numbers.
static func line(rules: CampaignRules, key: String) -> String:
	var g := growth(rules, key)
	var grow := ""
	if g.size() == 2:
		grow = "%s grows quicker in him, %s slower. " % [str(CombatTypes.STAT_NAMES[g[0]]).capitalize(), str(CombatTypes.STAT_NAMES[g[1]])]
	var e: Dictionary = rules.nature_edges.get(key, {})
	match key:
		"reckless":
			return grow + "A win against the odds brings him %d more fame." % int(e.get("odds_fame", 0))
		"steady":
			return grow + "He may draw off from a fight and no man calls it fear: it costs him no honor."
		"open_handed":
			return "His gifts of silver and arms bind a man half again as much."
		"close_fisted":
			return "He keeps %d in a hundred more of the plunder and the men let it pass; his gifts bind them a quarter less." % roundi(float(e.get("keep_share", 0.0)) * 100.0)
		"silver_tongued":
			return grow + "One better at every counsel, pleading at the Thing and verse."
		"grim":
			return grow + "One man in %d pays rather than meet him on the island." % roundi(1.0 / maxf(0.01, float(e.get("dread", 0.1))))
		"deep_minded":
			return grow + "His luck is slow to be forgotten: it fades over the winter only from %d, not %d." % [rules.luck_drift_high + int(e.get("luck_keep", 0)) + 1, rules.luck_drift_high + 1]
		"quick_to_anger":
			return grow + "Calling a house to the island costs him half the honor it costs another."
	return grow.strip_edges()


## Whether `picked` is a whole nature: PICK known traits, no two of a pair.
static func valid(picked: PackedStringArray) -> bool:
	if picked.size() != PICK:
		return false
	var pairs := {}
	for k in picked:
		var p := pair_of(k)
		if p < 0 or pairs.has(p):
			return false
		pairs[p] = true
	return true


## Gives the leader his nature, rebuilds the band's edges, and tells it.
static func choose(band: Band, picked: PackedStringArray) -> bool:
	if band.leader == null or not valid(picked):
		return false
	band.leader.natures = picked.duplicate()
	Way.refresh(band)
	band.log("Men said of %s that he was %s" % [band.leader.display_name, words(band.leader)])
	return true


## "reckless and open-handed", or "".
static func words(m: Man) -> String:
	var out := PackedStringArray()
	for k in m.natures:
		out.append(name_of(k).to_lower())
	return " and ".join(out)


## The edges of the leader's nature, laid on top of his ways' (`gifts`):
## numbers that add (law, verse, dread) are added; the rest are set.
static func add_edges(rules: CampaignRules, m: Man, gifts: Dictionary) -> void:
	if m == null or m.natures.is_empty():
		return
	if rules == null:
		rules = CampaignRules.new()  # Way.refresh has no rules of its own: the defaults
	for k in m.natures:
		var e: Dictionary = rules.nature_edges.get(k, {})
		for edge in e:
			if edge in ["law", "verse", "dread"]:
				gifts[edge] = gifts.get(edge, 0) + e[edge]
			else:
				gifts[edge] = e[edge]


## Multiplier on effort into `stat` from his chosen nature.
static func multiplier(rules: CampaignRules, m: Man, stat: CombatTypes.Stat) -> float:
	var mult := 1.0
	for k in m.natures:
		var g := growth(rules, k)
		if g.size() != 2:
			continue
		if g[0] == stat:
			mult *= rules.nature_up
		elif g[1] == stat:
			mult *= rules.nature_down
	return mult


## A son's nature: each of his father's traits he has with
## `nature_inherit_chance`, the rest drawn from the pairs his father's left
## open. Empty when the father had none.
static func inherit(rng: SimRng, rules: CampaignRules, father: Man) -> PackedStringArray:
	var out := PackedStringArray()
	if father == null or father.natures.is_empty():
		return out
	for k in father.natures:
		if rng.randf() < rules.nature_inherit_chance:
			out.append(k)
	var guard := 0
	while out.size() < PICK and guard < 20:
		guard += 1
		var all := keys()
		var k := all[rng.randi_range(0, all.size() - 1)]
		var clash := false
		for have in out:
			if pair_of(have) == pair_of(k):
				clash = true
		if not clash:
			out.append(k)
	return out
