class_name Feud
extends RefCounted
## Blood feuds between the band and a family (concept.md, Feud and
## wergild). Entries live in `band.feuds` with `family`, `place`, `level`
## (1-3), `settled`, plus `refusals` and `rank` (the dead man's) kept here.
## Ambushes are returned as battle requests for the sandbox loop.
## See world-architecture.md, Module M.
##
## The families are houses now (Families, House): a feud here is the band's
## own with a house, and the band's standing with that house follows it
## (Families.sync holds a house at feud with the band at
## `standing_feud_cap` or under, and lifts it by `standing_settled` once the
## feud is settled). Feuds between two houses, with their ledger of
## killings and their steps from an insult to a burning, live in
## Families.pairs.


static func start(rules: WorldRules, band: Band, family: String, cause: String, place_id: String,
		log: PackedStringArray) -> void:
	if band.add_feud(family, cause, place_id):
		var f := find(band, family)
		f["refusals"] = 0
		f["rank"] = rules.default_victim_rank
		log.append("A feud begins with %s over %s." % [family, cause])
		band.log("A feud began with %s over %s." % [family, cause])
	else:
		log.append("The feud with %s smoulders on (%s)." % [family, cause])


## Each unsettled feud may bring an ambush and a demand for wergild.
## Events: {kind: "ambush", family, battle_required, text} and
## {kind: "demand", family, ounces, text} (settle or escalate).
static func summer_events(rng: SimRng, rules: WorldRules, world: World, band: Band,
		log: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in band.unsettled_feuds():
		var family: String = f.get("family", f.get("against", ""))
		var level: int = f.get("level", 1)
		if rng.randf() < rules.ambush_chance * level:
			var hired := rules.hired_blades if level >= 3 else 0
			var where := ""
			var seat: Place = world.place(f.get("place", "")) if world != null else null
			if seat != null:
				where = " from %s" % seat.display_name
			var text := "%s come%s for blood, %d men%s." % [family, where, rules.feud_ambush_men + hired,
					(" with %d hired blades" % hired) if hired > 0 else ""]
			out.append({"kind": "ambush", "family": family, "text": text, "battle_required": {
				"kind": "feud_ambush", "attackers": rules.feud_ambush_men + hired, "tier": rules.feud_tier,
				"text": text, "family": family, "hired_blades": hired}})
			log.append(text)
		# The house that wronged him (the burned hall) owes, it does not
		# ask: no demand for silver comes from the men he has vengeance on.
		if family != band.vengeance and rng.randf() < rules.demand_chance:
			var ask := offer_settlement(rules, band, family)
			var text := "%s demand %d oz of wergild to end the feud." % [family, ask]
			out.append({"kind": "demand", "family": family, "ounces": ask, "text": text})
			log.append(text)
	return out


## Wergild asked to settle: the dead man's wergild scaled by the feud's level.
static func offer_settlement(rules: WorldRules, band: Band, family: String) -> int:
	var f := find(band, family)
	if f.is_empty():
		return 0
	var level: int = clampi(f.get("level", 1), 1, 3)
	var mult: float = rules.feud_level_wergild_mult[mini(level, rules.feud_level_wergild_mult.size() - 1)]
	return roundi(wergild(rules, f.get("rank", rules.default_victim_rank)) * mult)


## Pays `ounces` to end the feud if they meet the asking price and the band
## has them.
static func settle(rules: WorldRules, band: Band, family: String, ounces: int, log: PackedStringArray) -> bool:
	var f := find(band, family)
	if f.is_empty():
		return false
	var ask := offer_settlement(rules, band, family)
	if ounces < ask or band.silver < ounces:
		log.append("The band cannot settle with %s: %d oz offered of %d asked, %d in hand." % [
			family, ounces, ask, band.silver])
		return false
	band.silver -= ounces
	f["settled"] = true
	log.append("The feud with %s is settled for %d oz." % [family, ounces])
	band.log("Settled the feud with %s for %d oz." % [family, ounces])
	return true


## A refused settlement: the feud rises a level (to 3). Refusing a fair
## offer a second time, and every time after, costs honor.
static func escalate(rules: WorldRules, band: Band, family: String, log: PackedStringArray) -> void:
	var f := find(band, family)
	if f.is_empty():
		return
	f["level"] = mini(3, int(f.get("level", 1)) + 1)
	f["refusals"] = int(f.get("refusals", 0)) + 1
	var line := "The band refuses %s; the feud rises to level %d." % [family, f.level]
	if f.refusals >= 2:
		band.honor -= rules.feud_refusal_honor
		line += " Men say the band will not take fair terms (honor -%d)." % rules.feud_refusal_honor
	if f.level >= 3:
		line += " %s hire blades." % family
	log.append(line)


static func wergild(rules: WorldRules, rank: int) -> int:
	return int(rules.wergild_by_rank.get(rank, 0))


## The unsettled feud entry with `family`, or {}.
static func find(band: Band, family: String) -> Dictionary:
	for f in band.feuds:
		if not f.settled and f.get("family", f.get("against", "")) == family:
			return f
	return {}
