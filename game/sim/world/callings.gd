class_name Callings
extends RefCounted
## The deeds that are not raiding, trading or a lord's work (concept.md,
## "Ways of life"): counsel given in a dispute, a verse before a lord, and
## the holmgang. Open to every man; the law-wise man, the skald and the
## berserk are better at their own (Band.gift). Every value comes from
## WorldRules (section "Ways of life").

const COUNSEL_KINDS := [WorldTypes.PlaceKind.FARMSTEAD, WorldTypes.PlaceKind.HALL, WorldTypes.PlaceKind.TOWN, WorldTypes.PlaceKind.THING_SITE]


# --- Counsel ------------------------------------------------------------------

## Whether a dispute lies at this place this year: always at a Thing site,
## elsewhere in `counsel_dispute_chance` of years, drawn from the place,
## the year and the world's own number.
static func has_dispute(rules: WorldRules, world: World, place: Place) -> bool:
	if place == null or not COUNSEL_KINDS.has(place.kind) or place.family == "":
		return false
	if place.kind == WorldTypes.PlaceKind.THING_SITE:
		return true
	return SimRng.new(world.salt).fork("dispute:%s:%d" % [place.id, world.year]).randf() < rules.counsel_dispute_chance


## Whether there is a dispute here the leader has not yet given counsel in
## this year.
static func can_counsel(rules: WorldRules, world: World, band: Band, place: Place) -> bool:
	return has_dispute(rules, world, place) and int(band.counselled.get(place.id, -1)) != world.year


## The leader gives counsel in a dispute of the place's family: his Wits +
## 2d6 + his `law` gift against `counsel_difficulty` (a Thing site is
## harder and pays double). Returns {ok, roll, need, fee, text}.
static func counsel(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, log: PackedStringArray) -> Dictionary:
	var out := {"ok": false, "roll": 0, "need": 0, "fee": 0, "text": ""}
	if not can_counsel(rules, world, band, place) or band.leader == null:
		return out
	band.counselled[place.id] = world.year
	var at_thing := place.kind == WorldTypes.PlaceKind.THING_SITE
	var need := rules.counsel_difficulty + (rules.counsel_thing_harder if at_thing else 0)
	var roll := band.leader.stat(CombatTypes.Stat.WITS) + rng.roll_2d6() + int(band.gift("law", 0))
	out.roll = roll
	out.need = need
	var who := band.leader.display_name
	if roll >= need:
		var fee := roundi(float(rules.counsel_fee + place.wealth / rules.counsel_wealth_per_oz) \
				* float(band.gift("counsel_fee", 1.0)) * (2.0 if at_thing else 1.0))
		band.silver += fee
		band.honor = clampi(band.honor + rules.counsel_honor, 0, 100)
		band.friends[place.family] = world.year
		if place.faction_id != "":
			FactionAI.shift(world, place.faction_id, FactionAI.BAND, rules.counsel_relation)
		Way.add_deed(band, Way.Id.LAWMAN, rules.deed_counsel)
		out.ok = true
		out.fee = fee
		out.text = "%s's counsel settles a dispute of %s at %s (%d against %d): they give %d oz and their friendship." % [
				who, place.family, place.display_name, roll, need, fee]
		band.log("%s gave counsel to %s, and it held" % [who, place.family])
	elif need - roll >= rules.counsel_bad_miss:
		band.honor = clampi(band.honor - rules.counsel_bad_honor, 0, 100)
		out.text = "%s's counsel to %s turns out ill (%d against %d), and men remember who gave it." % [who, place.family, roll, need]
	else:
		out.text = "%s gives counsel to %s, but the matter is not mended (%d against %d)." % [who, place.family, roll, need]
	log.append(out.text)
	return out


# --- A verse before a lord ----------------------------------------------------

## A hall or town with a living lord who has not heard the leader this year.
static func can_verse(world: World, band: Band, place: Place) -> bool:
	if place == null or not (place.kind == WorldTypes.PlaceKind.HALL or place.kind == WorldTypes.PlaceKind.TOWN):
		return false
	var f := FactionAI.ruler_of(world, place.id)
	return f != null and f.alive and int(band.versed.get(place.id, -1)) != world.year


## The leader recites a praise-poem before the place's lord: Wits + 2d6 +
## fame over `verse_fame_per_point` + his `verse` gift against
## `verse_difficulty`. Returns {ok, roll, need, ring, text}.
static func verse(rng: SimRng, rules: WorldRules, world: World, band: Band, place: Place, log: PackedStringArray) -> Dictionary:
	var need := verse_need(rules, band, place)
	var out := {"ok": false, "roll": 0, "need": need, "ring": 0, "text": ""}
	if not can_verse(world, band, place) or band.leader == null:
		return out
	band.versed[place.id] = world.year
	var f := FactionAI.ruler_of(world, place.id)
	var roll := band.leader.stat(CombatTypes.Stat.WITS) + rng.roll_2d6() + band.fame / rules.verse_fame_per_point \
			+ int(band.gift("verse", 0))
	out.roll = roll
	var who := band.leader.display_name
	if roll >= need:
		band.verses_heard[place.id] = int(band.verses_heard.get(place.id, 0)) + 1
		var ring := roundi(float(rules.verse_ring + place.wealth / rules.verse_wealth_per_oz) * float(band.gift("verse_gift", 1.0)))
		band.silver += ring
		band.fame = clampi(band.fame + rules.verse_fame, 0, 100)
		FactionAI.shift(world, f.id, FactionAI.BAND, rules.verse_relation)
		Way.add_deed(band, Way.Id.SKALD, rules.deed_verse)
		out.ok = true
		out.ring = ring
		out.text = "%s speaks a verse in praise of %s at %s (%d against %d); the lord gives a ring worth %d oz." % [
				who, f.leader, place.display_name, roll, need, ring]
		band.log("%s made a verse on %s and was paid a ring for it" % [who, f.leader])
	elif need - roll >= rules.verse_bad_miss:
		band.fame = clampi(band.fame - 1, 0, 100)
		out.text = "%s's verse limps before %s (%d against %d), and the hall laughs." % [who, f.leader, roll, need]
	else:
		out.text = "%s's verse is heard out in silence at %s (%d against %d); no ring is given." % [who, place.display_name, roll, need]
	log.append(out.text)
	return out


## What a verse must reach here: harder for each one this lord has heard.
static func verse_need(rules: WorldRules, band: Band, place: Place) -> int:
	return rules.verse_difficulty + rules.verse_heard_harder * int(band.verses_heard.get(place.id, 0))


# --- Holmgang -----------------------------------------------------------------

## Whether a man here can be called to the island: a farm or a hall with a
## family, once a year.
static func can_challenge(rules: WorldRules, world: World, band: Band, place: Place) -> bool:
	return place != null and rules.holmgang_stake.has(place.kind) and place.family != "" \
			and place.id != band.home and int(band.challenged.get(place.id, -1)) != world.year


## What the challenge is for: {stake, feud, family, honor_cost, tier,
## stat}. With a feud behind it the challenge is lawful and costs no honor.
static func holmgang_terms(rules: WorldRules, world: World, band: Band, place: Place) -> Dictionary:
	var feud := not Feud.find(band, place.family).is_empty()
	var stake := mini(place.wealth, roundi(float(place.wealth) * float(rules.holmgang_stake.get(place.kind, 0.0))))
	var stat := int(rules.defender_stat_by_kind[place.kind] + place.defenses * rules.defender_stat_per_defense) + 1
	return {"stake": stake, "feud": feud, "family": place.family, "honor_cost": 0 if feud else rules.holmgang_honor,
			"tier": maxi(CombatTypes.Tier.BLOODED, Raiding.defender_tier(rules, place)), "stat": clampi(stat, 1, 10)}


## The man who answers for the place: its family's best, a spear and shield.
static func holmgang_opponent(rng: SimRng, rules: WorldRules, place: Place, terms: Dictionary, combat_rules: CombatRules) -> Warrior:
	var w: Warrior = BandFactory.make_band(rng, 1, 1, terms.tier, CombatTypes.Armor.NONE, rng.randi_range(0, 40), 2001, terms.stat, combat_rules)[0]
	w.display_name = "%s of %s" % [w.display_name.trim_suffix(" the leader"), place.display_name.trim_prefix("the ")]
	return w


## Whether the man pays rather than fight: only a challenger with `dread`.
static func holmgang_yields(rng: SimRng, band: Band) -> bool:
	return rng.randf() < float(band.gift("dread", 0.0))


## Whether a berserk has called this farm's man out this year, and nobody
## has yet stood in his place: a farm or hall with a family, in
## `bully_chance` of years.
static func can_champion(rules: WorldRules, world: World, band: Band, place: Place) -> bool:
	if place == null or not rules.holmgang_stake.has(place.kind) or place.family == "" or place.id == band.home:
		return false
	if int(band.championed.get(place.id, -1)) == world.year:
		return false
	return SimRng.new(world.salt).fork("bully:%s:%d" % [place.id, world.year]).randf() < rules.bully_chance


## The berserk who has called the farmer out: seasoned, and the fury on him.
static func bully(rng: SimRng, _rules: WorldRules, place: Place, combat_rules: CombatRules) -> Warrior:
	var w: Warrior = BandFactory.make_band(rng, 1, 1, CombatTypes.Tier.VETERAN, CombatTypes.Armor.NONE, rng.randi_range(0, 40), 2001, 5, combat_rules)[0]
	w.display_name = "%s the berserk" % w.display_name.trim_suffix(" the leader")
	w.fury = true
	return w


## What standing in the farmer's place came to. `outcome` 1: the leader won
## (the fee, honor, fame, the family's friendship); 0: he lost (the
## ransom); -1: nobody's. Returns {silver, text}.
static func after_champion(rules: WorldRules, world: World, band: Band, place: Place, outcome: int, log: PackedStringArray) -> Dictionary:
	var out := {"silver": 0, "text": ""}
	band.championed[place.id] = world.year
	var who: String = band.leader.display_name if band.leader != null else "the leader"
	if outcome == 1:
		var fee := rules.champion_fee + place.wealth / rules.champion_wealth_per_oz
		band.silver += fee
		band.honor = clampi(band.honor + rules.champion_honor, 0, 100)
		band.fame = clampi(band.fame + rules.champion_fame, 0, 100)
		band.friends[place.family] = world.year
		Way.add_deed(band, Way.Id.BERSERK, rules.deed_champion)
		out.silver = fee
		out.text = "%s blooded the berserk on the island. %s give %d oz, and will not forget it." % [who, place.family.capitalize(), fee]
		band.log("%s stood in a farmer's place against a berserk at %s, and won" % [who, place.display_name])
	elif outcome == 0:
		var ransom := mini(band.silver, rules.holmgang_ransom)
		band.silver -= ransom
		out.silver = -ransom
		out.text = "The berserk blooded %s, who pays %d oz to leave the island. The farm is the berserk's." % [who, ransom]
	else:
		out.text = "Neither man has the better of it; the berserk goes off to trouble someone else."
	log.append(out.text)
	return out


## The challenge is made: the honor it costs, the place marked for the year.
static func challenge(rules: WorldRules, world: World, band: Band, place: Place, terms: Dictionary, log: PackedStringArray) -> void:
	band.challenged[place.id] = world.year
	if int(terms.honor_cost) > 0:
		band.honor = clampi(band.honor - int(terms.honor_cost), 0, 100)
		if place.faction_id != "":
			FactionAI.shift(world, place.faction_id, FactionAI.BAND, -rules.holmgang_relation_hit)
		log.append("%s calls %s to the island for what they own: an overbearing thing, and men say so." % [
				band.leader.display_name, place.family])
		if band.honor <= rules.holmgang_outlaw_honor and band.outlawry == WorldTypes.Outlawry.NONE:
			log.append("The district will bear it no longer: the farmers go to the Thing together.")
			Outlawry.declare(rules, band, Calendar.new(world.year), false, log)
	else:
		log.append("%s calls %s to the island to end the feud between them." % [band.leader.display_name, place.family])


## What the island decided. `outcome` is 1 (the leader won), 0 (he lost) or
## -1 (nobody's), `yielded` when the man paid rather than fight. A win
## takes the stake (half when he yielded) and fame, and settles a feud; a
## loss costs the ransom. A man beaten or cowed for his goods without
## cause may take up a feud (`rng`, `holmgang_feud_chance`). Returns
## {silver, feud, text}.
static func after_holmgang(rules: WorldRules, _world: World, band: Band, place: Place, terms: Dictionary,
		outcome: int, yielded: bool, log: PackedStringArray, rng: SimRng = null) -> Dictionary:
	var out := {"silver": 0, "feud": false, "text": ""}
	var who: String = band.leader.display_name if band.leader != null else "the leader"
	if yielded or outcome == 1:
		var take := mini(place.wealth, int(terms.stake) / 2 if yielded else int(terms.stake))
		place.wealth -= take
		band.silver += take
		out.silver = take
		Way.add_deed(band, Way.Id.BERSERK, rules.deed_duel_yielded if yielded else rules.deed_duel)
		if not yielded:
			band.fame = clampi(band.fame + rules.holmgang_win_fame, 0, 100)
		if terms.feud:
			var f := Feud.find(band, terms.family)
			if not f.is_empty():
				f["settled"] = true
				band.log("%s ended the feud with %s on the island" % [who, terms.family])
		out.text = ("%s will not meet %s on the island and pay %d oz to be left alone." % [terms.family, who, take]) if yielded \
				else ("%s wins the holmgang and takes %d oz%s." % [who, take, ", and the feud is ended" if terms.feud else ""])
		if not terms.feud and rng != null and rng.randf() < rules.holmgang_feud_chance \
				and band.add_feud(terms.family, "holmgang at %s" % place.display_name, place.id):
			out.feud = true
			out.text += " %s swear to be avenged for it." % terms.family
	elif outcome == 0:
		var ransom := mini(band.silver, rules.holmgang_ransom)
		band.silver -= ransom
		out.silver = -ransom
		out.text = "%s is blooded on the island and pays %d oz to leave it." % [who, ransom]
	else:
		out.text = "Neither man has the better of it on the island; the matter stands."
	log.append(out.text)
	return out
