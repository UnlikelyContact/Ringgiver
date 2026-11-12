class_name Thing
extends RefCounted
## The Thing: a case in four stages (concept.md, Ranks, politics and law >
## The Thing mini-game). Gather support, procedure, the standoff, the
## outcome. Battles are never fought here: a brawl at the Thing is left on
## the case as a `battle_required` for the sandbox loop.
## See world-architecture.md, Module M.


static func open_case(rules: WorldRules, band: Band, kind: WorldTypes.CaseKind, against: String,
		claim_ounces: int, plaintiff_is_band: bool) -> ThingCase:
	var c := ThingCase.new()
	c.kind = kind
	c.against = against
	c.claim = maxi(0, claim_ounces)
	c.plaintiff_is_band = plaintiff_is_band
	c.victim_rank = rules.default_victim_rank
	c.note("%d: %s" % [band.year, c.describe()])
	return c


## Stage 1. Returns the band's supporters; also sets the family's.
static func gather_support(rng: SimRng, rules: WorldRules, world: World, band: Band, c: ThingCase,
		silver_spent: int, log: PackedStringArray) -> int:
	var spent := clampi(silver_spent, 0, band.silver)
	band.silver -= spent
	var from_fame := maxi(0, band.fame) / rules.fame_per_supporter
	var from_silver := spent / rules.ounces_per_supporter
	var brothers := oath_brother_pairs(band)
	var from_factions := 0
	var family_place := family_seat(world, c.against)
	var their_faction := family_place.faction_id if family_place != null else ""
	if world != null:
		for fid in world.factions:
			if String(fid) == their_faction:
				continue
			from_factions += _faction_support(rules, world.factions[fid])
	# The houses: the band's friends, the other side's allies, and its enemies.
	var from_houses := 0
	var their_houses := 0
	if world != null and world.families != null:
		var backing := world.families.thing_backing(rules, band, c.against, c.client)
		from_houses = int(backing.ours)
		their_houses = int(backing.theirs)
		c.houses_with = backing.with
		c.houses_against = backing.against
	c.supporters = from_fame + from_silver + brothers + from_factions + from_houses
	var wealth := family_place.wealth if family_place != null else 0
	var spread := rng.randi_range(-rules.their_supporters_spread, rules.their_supporters_spread)
	c.their_supporters = maxi(0, rules.their_supporters_base + wealth / rules.family_standing + spread + their_houses)
	c.their_armed = rules.family_armed_men
	_say(c, log, "The band gathers %d supporters (%d for its fame, %d bought with %d oz, %d oath brothers, %d from friendly lords, %d from the houses that stand with it); %s bring %d, %d of them from their allies." % [
		c.supporters, from_fame, from_silver, spent, brothers, from_factions, from_houses, c.against, c.their_supporters, their_houses])
	if not c.houses_with.is_empty():
		_say(c, log, "With the band stand %s." % ", ".join(PackedStringArray(c.houses_with)))
	if not c.houses_against.is_empty():
		_say(c, log, "With %s stand %s." % [c.against, ", ".join(PackedStringArray(c.houses_against))])
	return c.supporters


## Stage 2. The band's best Wits + 2d6 against the case's difficulty. A
## slip sinks the case; a hired law-man buys one reroll.
static func procedure(rng: SimRng, rules: WorldRules, band: Band, c: ThingCase, log: PackedStringArray) -> bool:
	var wits := best_wits(rules, band) + int(band.gift("law", 0))
	var difficulty: int = rules.procedure_difficulty.get(c.kind, 10)
	var roll := wits + rng.roll_2d6()
	var ok := roll >= difficulty
	if not ok and c.lawman_hired and band.silver >= rules.lawman_fee:
		band.silver -= rules.lawman_fee
		_say(c, log, "A step of the pleading goes wrong (%d against %d); the hired law-man mends it for %d oz." % [
			roll, difficulty, rules.lawman_fee])
		roll = wits + rng.roll_2d6()
		ok = roll >= difficulty
	c.procedure_ok = ok
	if ok:
		_say(c, log, "The pleading holds (%d against %d)." % [roll, difficulty])
	else:
		_say(c, log, "A procedural slip (%d against %d): the law-men throw out the band's pleading." % [roll, difficulty])
	return ok


## Stage 3. Weighs both sides; evenly matched armed sides may come to blows.
static func standoff(rng: SimRng, rules: WorldRules, band: Band, c: ThingCase, log: PackedStringArray) -> Dictionary:
	var our_armed := band.fighters().size()
	c.weight_us = c.supporters + our_armed * rules.arms_weight
	c.weight_them = c.their_supporters + c.their_armed * rules.arms_weight
	var out := {"weight_us": c.weight_us, "weight_them": c.weight_them, "violence": false}
	_say(c, log, "At the standoff the band weighs %.1f against %.1f for %s." % [c.weight_us, c.weight_them, c.against])
	var close := absf(c.weight_us - c.weight_them) <= rules.standoff_margin
	if close and our_armed > 0 and c.their_armed > 0 and rng.randf() < rules.violence_chance:
		c.violence = true
		out.violence = true
		var band_struck := rng.randf() < 0.5
		out["band_struck"] = band_struck
		var text := ""
		if band_struck:
			band.honor -= rules.thing_violence_honor
			text = "Weapons are drawn at the Thing and the band strikes first: a grave crime."
		else:
			text = "Weapons are drawn at the Thing; %s strike first." % c.against
		c.battle_required = {"kind": "thing_brawl", "attackers": c.their_armed, "tier": rules.thing_brawl_tier,
				"text": text, "family": c.against}
		out["battle_required"] = c.battle_required
		_say(c, log, text)
	return out


## Stage 4. The weight ratio (plaintiff over defendant) decides; the
## verdict's consequences are applied to the band.
static func outcome(rng: SimRng, rules: WorldRules, world: World, band: Band, c: ThingCase,
		log: PackedStringArray) -> WorldTypes.Verdict:
	var p_weight := c.weight_us if c.plaintiff_is_band else c.weight_them
	var d_weight := c.weight_them if c.plaintiff_is_band else c.weight_us
	var ratio := p_weight / maxf(d_weight, 0.5)
	var v: WorldTypes.Verdict = WorldTypes.Verdict.PENDING
	if not c.procedure_ok:
		if c.plaintiff_is_band:
			v = WorldTypes.Verdict.FAILED
		else:
			ratio = maxf(ratio, rules.win_ratio)
	if v == WorldTypes.Verdict.PENDING:
		v = _verdict_for(rules, c.kind, ratio)
	c.verdict = v
	if c.client != "":
		return _client_outcome(rules, world, band, c, v, log)
	# The other side remembers who took them to the Thing and won.
	var band_won := (c.plaintiff_is_band and v != WorldTypes.Verdict.FAILED) or (not c.plaintiff_is_band and v == WorldTypes.Verdict.FAILED)
	if band_won and world != null and world.families != null:
		world.families.shift(rules, band, c.against, rules.standing_case_against)
	match v:
		WorldTypes.Verdict.COMPENSATION:
			c.wergild = Feud.wergild(rules, c.victim_rank) if c.kind == WorldTypes.CaseKind.KILLING else c.claim
			if c.plaintiff_is_band:
				band.silver += c.wergild
				_say(c, log, "The Thing awards the band %d oz from %s." % [c.wergild, c.against])
			else:
				var paid := mini(c.wergild, band.silver)
				band.silver -= paid
				_say(c, log, "The Thing orders the band to pay %s %d oz (%d paid)." % [c.against, c.wergild, paid])
		WorldTypes.Verdict.LESSER_OUTLAWRY, WorldTypes.Verdict.FULL_OUTLAWRY:
			var full := v == WorldTypes.Verdict.FULL_OUTLAWRY
			if c.plaintiff_is_band:
				_say(c, log, "The Thing declares %s %s." % [c.against, "full outlaws" if full else "outlawed for a time"])
			else:
				_say(c, log, "The Thing declares the band %s." % ("full outlaws" if full else "outlawed for a time"))
				var year := world.year if world != null else band.year
				Outlawry.declare(rules, band, Calendar.new(year), full, log)
		WorldTypes.Verdict.FAILED:
			_say(c, log, "The case fails: the matter goes to the sword.")
			var seat := family_seat(world, c.against)
			Feud.start(rules, band, c.against, "a failed %s case at the Thing" % String(WorldTypes.CaseKind.keys()[c.kind]).to_lower(),
					seat.id if seat != null else "", log)
	return v


## A case the band pleads for another house (`c.client`) against
## `c.against`: a verdict for the client settles the feud between them (to
## hold or break in the years to come) and wins the client's friendship;
## the other side resents the band for it. A failed case costs the band a
## little with its client and goes back to the houses' own feud.
static func _client_outcome(rules: WorldRules, world: World, band: Band, c: ThingCase, v: WorldTypes.Verdict,
		log: PackedStringArray) -> WorldTypes.Verdict:
	var fs: Families = world.families if world != null else null
	if v == WorldTypes.Verdict.FAILED:
		_say(c, log, "The case of %s against %s fails, and the feud between them goes on." % [c.client, c.against])
		if fs != null:
			fs.shift(rules, band, c.client, rules.standing_refused)
		return v
	match v:
		WorldTypes.Verdict.COMPENSATION:
			c.wergild = Feud.wergild(rules, c.victim_rank) if c.kind == WorldTypes.CaseKind.KILLING else c.claim
			_say(c, log, "The Thing awards %s %d oz from %s, and the law-men make a settlement between them." % [c.client, c.wergild, c.against])
		_:
			_say(c, log, "The Thing declares the men of %s who did the killings %s; a settlement is made between the houses." % [
					c.against, "full outlaws" if v == WorldTypes.Verdict.FULL_OUTLAWRY else "outlawed for a time"])
	if fs != null:
		fs.settle_between(c.client, c.against)
		fs.shift(rules, band, c.client, rules.standing_case_for)
		fs.shift(rules, band, c.against, rules.standing_case_against)
	return v


## The four stages in order.
static func run(rng: SimRng, rules: WorldRules, world: World, band: Band, c: ThingCase, silver_spent: int,
		log: PackedStringArray) -> WorldTypes.Verdict:
	gather_support(rng, rules, world, band, c, silver_spent, log)
	procedure(rng, rules, band, c, log)
	standoff(rng, rules, band, c, log)
	return outcome(rng, rules, world, band, c, log)


## The leader's Wits, or a law-wise man's if better.
static func best_wits(rules: WorldRules, band: Band) -> int:
	var best := 0
	if band.leader != null and band.leader.alive:
		best = band.leader.stat(CombatTypes.Stat.WITS)
	for m in band.living_men():
		if m.traits.has(rules.law_wise_trait):
			best = maxi(best, m.stat(CombatTypes.Stat.WITS))
	return best


## Pairs of oath brothers among the band's fighters.
static func oath_brother_pairs(band: Band) -> int:
	var f := band.fighters()
	var n := 0
	for i in f.size():
		for j in range(i + 1, f.size()):
			if band.bond_kind(f[i], f[j]) == CampaignTypes.BondKind.OATH_BROTHER:
				n += 1
	return n


## The first open place held by `family`, or null.
static func family_seat(world: World, family: String) -> Place:
	if world == null or family == "":
		return null
	for p in world.places.values():
		if p.family == family:
			return p
	return null


static func _verdict_for(rules: WorldRules, kind: WorldTypes.CaseKind, ratio: float) -> WorldTypes.Verdict:
	if ratio < rules.win_ratio:
		return WorldTypes.Verdict.FAILED
	match kind:
		WorldTypes.CaseKind.KILLING:
			if ratio >= rules.full_outlawry_ratio:
				return WorldTypes.Verdict.FULL_OUTLAWRY
			if ratio >= rules.lesser_outlawry_ratio:
				return WorldTypes.Verdict.LESSER_OUTLAWRY
		WorldTypes.CaseKind.RAID, WorldTypes.CaseKind.LAND:
			if ratio >= rules.full_outlawry_ratio:
				return WorldTypes.Verdict.LESSER_OUTLAWRY
	return WorldTypes.Verdict.COMPENSATION


## Supporters a faction lends the band: one per full `faction_support_relation`
## of its relation toward the band. Reads Module L's Faction defensively.
static func _faction_support(rules: WorldRules, f: Variant) -> int:
	if f == null:
		return 0
	var alive: Variant = true
	var rel: Variant = null
	if f is Dictionary:
		alive = f.get("alive", true)
		rel = f.get("relations", null)
	elif f is Object:
		var a: Variant = f.get("alive")
		if a != null:
			alive = a
		rel = f.get("relations")
	if not alive or not (rel is Dictionary):
		return 0
	var r := int(rel.get("band", 0))
	if r < rules.faction_support_relation:
		return 0
	return r / rules.faction_support_relation


static func _say(c: ThingCase, log: PackedStringArray, line: String) -> void:
	log.append(line)
	c.note(line)
