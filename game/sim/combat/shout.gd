class_name Shouts
extends RefCounted
## Carries a leader's shout to his men (concept.md, Combat > Shouts).
##
## Near men hear for certain; beyond that the chance falls off with distance,
## rises with Wits and drops in fog. A horn or banner on the side widens the
## certain radius. A man who misses the shout may mishear it as some other
## order (green men often, champions never) or simply keep his old one.


## Sets `heard_order` (and for green men sometimes `order_lag`) on each active
## man of `band`. A NONE shout, or a leader who is down or fled, carries nothing.
static func propagate(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		leader: Warrior, shout: CombatTypes.Shout, band: Array[Warrior],
		fog: bool, log: PackedStringArray) -> void:
	if shout == CombatTypes.Shout.NONE or leader == null or not leader.is_active():
		return
	var has_horn := leader.is_horn
	var has_banner := leader.is_banner
	for m in band:
		if m.is_active() and m.side == leader.side:
			has_horn = has_horn or m.is_horn
			has_banner = has_banner or m.is_banner
	var banner_bonus := rules.hear_banner_radius_bonus if has_banner else 0
	for m in band:
		if not m.is_active() or m.broken:
			continue  # a running man hears nothing
		if m == leader:
			m.heard_order = shout
			continue
		var distance := BattleGrid.chebyshev(m.pos, leader.pos)
		var chance := hear_chance(rules, distance - banner_bonus, m.wits, has_horn, fog)
		if chance >= 1.0 or rng.randf() < chance:
			if m.heard_order != shout and m.tier == CombatTypes.Tier.GREEN \
					and rng.randf() < rules.green_lag_chance:
				m.order_lag = 1
			m.heard_order = shout
			continue
		if rng.randf() < mishear_chance(rules, m.tier):
			var others: Array[CombatTypes.Shout] = []
			for s in CombatTypes.Shout.values():
				if s != CombatTypes.Shout.NONE and s != shout and s != CombatTypes.Shout.TAUNT:
					others.append(s)
			var wrong: CombatTypes.Shout = others[rng.randi_range(0, others.size() - 1)]
			m.heard_order = wrong
			log.append("%s mishears \"%s\" as \"%s\"" % [m.display_name,
					CombatTypes.SHOUT_NAMES[shout], CombatTypes.SHOUT_NAMES[wrong]])


## Chance (0-1) that a man `distance` cells from the leader hears the shout.
## Within the certain radius (widened by a horn) it is 1, in fog or not.
static func hear_chance(rules: CombatRules, distance: int, wits: int,
		has_horn: bool, fog: bool) -> float:
	var radius := rules.hear_certain_radius
	if has_horn:
		radius += rules.hear_horn_radius_bonus
	if distance <= radius:
		return 1.0
	var chance := 1.0 - rules.hear_falloff_per_tile * (distance - radius)
	chance += rules.hear_wits_bonus * wits
	if fog:
		chance -= rules.hear_fog_penalty
	return clampf(chance, 0.0, 1.0)


## Chance that a man who missed the shout believes he heard a different one.
static func mishear_chance(rules: CombatRules, tier: CombatTypes.Tier) -> float:
	match tier:
		CombatTypes.Tier.GREEN:
			return rules.mishear_green
		CombatTypes.Tier.BLOODED:
			return rules.mishear_blooded
		CombatTypes.Tier.VETERAN:
			return rules.mishear_veteran
	return 0.0
