class_name MeleeExchange
extends RefCounted
## Melee exchanges and missile shots (sim-architecture.md, Module A).
##
## One opposed roll per pair per round. The margin's tier (OpposedRoll) says
## how hard the blow lands; shields and armor then take their share; what is
## left advances the loser's wound state. Shoves are reported, not applied.


## Resolves one exchange between `a` and `b`. Either may be attacking, bracing
## or both idle-but-adjacent; at least one is expected to attack. Mutates
## breath, wounds, shield_hp and effort; never moves anyone.
static func resolve(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		a: Warrior, b: Warrior, a_attacks: bool, b_attacks: bool,
		a_braced: bool, b_braced: bool, log: PackedStringArray) -> ExchangeResult:
	var r := ExchangeResult.new()
	r.a = a
	r.b = b
	var a_reaches := can_reach(rules, grid, a, b)
	var b_reaches := can_reach(rules, grid, b, a)
	var a_att := a_attacks and a_reaches
	var b_att := b_attacks and b_reaches
	if not a_att and not b_att:
		log.append(r.describe())
		return r
	r.happened = true

	var sa := score(rules, grid, a, b, a_att, a_braced)
	var sb := score(rules, grid, b, a, b_att, b_braced)
	if a_att:
		a.spend_breath(rules.breath_cost_attack)
	if b_att:
		b.spend_breath(rules.breath_cost_attack)

	var roll := OpposedRoll.resolve(rng, sa, sb)
	r.margin = roll.margin
	r.tier = roll.tier()
	if r.tier == OpposedRoll.Tier.LOCKED:
		a.spend_breath(rules.breath_cost_locked)
		b.spend_breath(rules.breath_cost_locked)
		log.append(r.describe())
		return r

	var a_won := roll.attacker_won()
	r.winner = a if a_won else b
	r.loser = b if a_won else a
	var winner_attacked := a_att if a_won else b_att
	var winner_reaches := a_reaches if a_won else b_reaches
	r.winner.add_effort(CombatTypes.Stat.SKILL)

	# Reach: a defender who wins against a spear striking from the second
	# rank cannot touch him.
	if not winner_reaches:
		log.append(r.describe())
		return r
	# A man who only braced turns the blow aside but does not strike home.
	if not winner_attacked and r.tier > OpposedRoll.Tier.GLANCING:
		r.tier = OpposedRoll.Tier.GLANCING

	if r.tier == OpposedRoll.Tier.GLANCING:
		_apply_glancing(rules, grid, r)
	else:
		_apply_wound(rng, rules, r)
	log.append(r.describe())
	return r


## Resolves one shot. Only HIT and HEAVY do anything; a bow never shoves.
static func resolve_shot(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		archer: Warrior, target: Warrior, log: PackedStringArray) -> ExchangeResult:
	var r := ExchangeResult.new()
	r.a = archer
	r.b = target
	r.is_shot = true
	var dist := BattleGrid.chebyshev(archer.pos, target.pos)
	if dist < 1 or dist > rules.missile_range:
		log.append(r.describe())
		return r
	r.happened = true

	var sa := archer.skill + rules.bow_shot_bonus - archer.condition_penalty(rules)
	if dist > rules.missile_free_range:
		sa -= (dist - rules.missile_free_range) / maxi(1, rules.missile_range_penalty_per)
	if rules.raining:
		sa -= rules.rain_bow_penalty
	var sb := target.skill - target.condition_penalty(rules)
	if _shield_ok(target) and BattleGrid.shield_covers(BattleGrid.arc_of(target, archer.pos)):
		sb += rules.shield_defense_bonus
	archer.spend_breath(rules.breath_cost_attack)

	var roll := OpposedRoll.resolve(rng, sa, sb)
	r.margin = roll.margin
	r.tier = roll.tier()
	if roll.attacker_won() and r.tier >= OpposedRoll.Tier.HIT:
		r.winner = archer
		r.loser = target
		archer.add_effort(CombatTypes.Stat.SKILL)
		_apply_wound(rng, rules, r)
		log.append(r.describe())
	else:
		# A miss, a graze or a shot caught on the shield: nothing happens.
		r.tier = OpposedRoll.Tier.LOCKED
		log.append("%s shoots at %s: misses" % [archer.display_name, target.display_name])
	return r


## A man's total modifier for one exchange against `foe` (before 2d6).
static func score(rules: CombatRules, grid: BattleGrid, me: Warrior,
		foe: Warrior, attacking: bool, braced: bool) -> int:
	var s := me.skill + int(rules.weapon_attack_bonus.get(me.weapon, 0)) - me.condition_penalty(rules)
	if attacking:
		match BattleGrid.arc_of(foe, me.pos):
			CombatTypes.Arc.RIGHT:
				s += rules.flank_attack_bonus
			CombatTypes.Arc.REAR:
				s += rules.rear_attack_bonus
	var behind := grid.occupant(grid.behind(me))
	if behind != null and behind != foe and behind.side == me.side and behind.is_active() \
			and behind.weapon == CombatTypes.Weapon.SPEAR:
		s += rules.second_rank_support_bonus
	if _shield_ok(me) and BattleGrid.shield_covers(BattleGrid.arc_of(me, foe.pos)):
		s += rules.shield_defense_bonus
		for n in grid.line_neighbors(me):
			if _shield_ok(n):
				s += rules.locked_shields_bonus
				break
	if braced:
		s += rules.brace_defense_bonus
	return s


## Can `me` strike `foe` from where he stands: adjacent, or a spear at reach
## through an active friend in the cell between.
static func can_reach(rules: CombatRules, grid: BattleGrid, me: Warrior, foe: Warrior) -> bool:
	var dist := BattleGrid.chebyshev(me.pos, foe.pos)
	if dist == 1:
		return true
	if dist < 1 or dist > rules.spear_reach or me.weapon != CombatTypes.Weapon.SPEAR:
		return false
	var between := grid.occupant(me.pos + BattleGrid.direction_to(me.pos, foe.pos))
	return between != null and between != foe and between.side == me.side and between.is_active()


## Long axes and bows are two-handed: no shield bonus ever, whatever the
## gear flags say.
static func _shield_ok(w: Warrior) -> bool:
	return w.shield_usable() and w.weapon != CombatTypes.Weapon.LONG_AXE \
			and w.weapon != CombatTypes.Weapon.BOW


## Does the loser's shield face the winner's blow?
static func _shield_takes(r: ExchangeResult) -> bool:
	return _shield_ok(r.loser) and BattleGrid.shield_covers(BattleGrid.arc_of(r.loser, r.winner.pos))


static func _damage_shield(rules: CombatRules, r: ExchangeResult) -> void:
	var dmg := rules.shield_damage_glancing
	if r.winner.weapon == CombatTypes.Weapon.BEARDED_AXE:
		dmg += rules.shield_damage_axe_extra
	dmg = mini(dmg, r.loser.shield_hp)
	r.loser.shield_hp -= dmg
	r.shield_damage += dmg
	r.shield_broke = r.loser.shield_hp <= 0


static func _apply_glancing(rules: CombatRules, grid: BattleGrid, r: ExchangeResult) -> void:
	if _shield_takes(r):
		_damage_shield(rules, r)
		return
	var cell := r.loser.pos + BattleGrid.direction_to(r.winner.pos, r.loser.pos)
	if grid.is_free(cell):
		r.shove_to = cell
	else:
		r.shove_blocked = true


static func _apply_wound(rng: SimRng, rules: CombatRules, r: ExchangeResult) -> void:
	var steps := rules.steps_heavy if r.tier == OpposedRoll.Tier.HEAVY else rules.steps_hit
	var chance := 0.0
	match r.loser.armor:
		CombatTypes.Armor.LEATHER:
			chance = rules.absorb_leather
		CombatTypes.Armor.MAIL:
			chance = rules.absorb_mail
	if r.loser.helmet:
		chance += rules.absorb_helmet_bonus
	if steps > 0 and chance > 0.0 and rng.randf() < chance:
		steps -= 1
		r.absorbed = true
		if _shield_takes(r):
			_damage_shield(rules, r)
	r.loser.take_wound_steps(steps)
	r.wound_steps_dealt = steps
	r.went_down = r.loser.is_down()
	if steps > 0 and not r.went_down:
		r.loser.add_effort(CombatTypes.Stat.GRIT)
