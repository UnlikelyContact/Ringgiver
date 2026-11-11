class_name Scouting
extends RefCounted
## What a scout brings back before a fight (concept.md, "Picking your
## fights"): a count that is truer the sharper and the more seasoned he is,
## the arms, the leader's name and manner, the ground. And whether he saw
## them first, which is what makes an ambush possible. Every value comes
## from CampaignRules (section "Scouting").


## The band's scout: the sharpest man, a seasoned one before a green one of
## the same wits. Null for an empty band.
static func pick_scout(men: Array[Man]) -> Man:
	var best: Man = null
	for m in men:
		if not m.alive:
			continue
		if best == null or m.stat(CombatTypes.Stat.WITS) > best.stat(CombatTypes.Stat.WITS) \
				or (m.stat(CombatTypes.Stat.WITS) == best.stat(CombatTypes.Stat.WITS) and m.tier > best.tier):
			best = m
	return best


## How far the count may be out either way: `scout_error` less one a point
## of wits, less `scout_veteran_bonus` for a seasoned man, never below zero.
static func error(rules: CampaignRules, wits: int, tier: CombatTypes.Tier) -> int:
	var e := rules.scout_error - (wits - 1) * rules.scout_error_per_wits
	if tier >= CombatTypes.Tier.VETERAN:
		e -= rules.scout_veteran_bonus
	return maxi(0, e)


## Whether the scout sees them before they see him: `scout_first_chance`
## plus `scout_first_per_wits` a point of wits above one, and
## `scout_first_veteran` for a seasoned man.
static func spots_first(rng: SimRng, rules: CampaignRules, wits: int, tier: CombatTypes.Tier) -> bool:
	var chance := rules.scout_first_chance + (wits - 1) * rules.scout_first_per_wits
	if tier >= CombatTypes.Tier.VETERAN:
		chance += rules.scout_first_veteran
	return rng.randf() < chance


## The report: {men_low, men_high, arms, leader, ground, text}. The count
## is a range about the truth, as wide as `error`, shifted by the roll so
## the truth is not always in the middle; the arms are told in kind
## ("shields, with spears behind and a few bows"); the leader's name is
## known when the scout is sharp enough (`scout_leader_wits`), his manner
## only to a seasoned scout.
static func report(rng: SimRng, rules: CampaignRules, wits: int, tier: CombatTypes.Tier, offer: FightOffer) -> Dictionary:
	var e := error(rules, wits, tier)
	var shift := rng.randi_range(-e, e) if e > 0 else 0
	var low := maxi(1, offer.enemy_size + shift - e)
	var high := offer.enemy_size + shift + e
	var arms := "shields"
	if offer.enemy_spears > 0 and offer.enemy_bows > 0:
		arms = "shields, with spears behind and a few bows"
	elif offer.enemy_spears > 0:
		arms = "shields with spears behind"
	elif offer.enemy_bows > 0:
		arms = "shields and a few bows"
	var leader := ""
	if wits >= rules.scout_leader_wits and offer.enemy_leader != "":
		leader = offer.enemy_leader
		if tier >= CombatTypes.Tier.VETERAN:
			leader += ", " + LeaderAI.DOCTRINE_MANNER[offer.doctrine]
	# The ground is the choice's to make, so the report names it only at
	# sea, where there is none.
	var ground := "at sea" if offer.at_sea else ""
	var count := ("%d men" % low) if low == high else ("%d or %d men" % [low, high]) if high - low == 1 else ("%d to %d men" % [low, high])
	var text := "Your scout counts %s, %s%s%s." % [count, arms, (", led by " + leader) if leader != "" else "", (", " + ground) if ground != "" else ""]
	if offer.enemy_tier >= CombatTypes.Tier.VETERAN and tier >= CombatTypes.Tier.VETERAN:
		text += " Seasoned men, he says."
	return {"men_low": low, "men_high": high, "arms": arms, "leader": leader, "ground": ground, "text": text}
