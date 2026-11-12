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
	if r.loser.luck != 0:
		_close_call(rules, r, log)

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
		_apply_wound(rng, rules, grid, r)
	log.append(r.describe())
	return r


## Resolves one shot. Only HIT and HEAVY do anything; a bow never shoves.
## A thrown spear (`thrown`) is Might's business, carries javelin_range, and
## caught on a shield it sticks there and spoils it.
static func resolve_shot(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		archer: Warrior, target: Warrior, log: PackedStringArray, thrown := false) -> ExchangeResult:
	var r := ExchangeResult.new()
	r.a = archer
	r.b = target
	r.is_shot = true
	r.is_thrown = thrown
	var dist := BattleGrid.chebyshev(archer.pos, target.pos)
	if dist < 1 or dist > (rules.javelin_range if thrown else rules.missile_range):
		log.append(r.describe())
		return r
	r.happened = true
	if thrown:
		archer.javelins = maxi(0, archer.javelins - 1)

	var sa: int
	if thrown:
		sa = archer.might + rules.javelin_bonus - archer.condition_penalty(rules)
	else:
		sa = archer.skill + rules.bow_shot_bonus - archer.condition_penalty(rules)
		if dist > rules.missile_free_range:
			sa -= (dist - rules.missile_free_range) / maxi(1, rules.missile_range_penalty_per)
	if rules.raining and not thrown:
		sa -= rules.rain_bow_penalty
	var sb := target.skill - target.condition_penalty(rules)
	var is_covered := covered(grid, target, archer.pos)
	if is_covered:
		sb += rules.shield_defense_bonus
		if not thrown and is_locked(grid, target):
			sb += rules.arrow_vs_locked_bonus  # a wall of shields: arrows rattle off it
	archer.spend_breath(rules.breath_cost_attack)

	var roll := OpposedRoll.resolve(rng, sa, sb)
	r.margin = roll.margin
	r.tier = roll.tier()
	if roll.attacker_won() and r.tier >= OpposedRoll.Tier.HIT:
		r.winner = archer
		r.loser = target
		archer.add_effort(CombatTypes.Stat.SKILL if not thrown else CombatTypes.Stat.MIGHT)
		_apply_wound(rng, rules, grid, r)
		log.append(r.describe())
	elif thrown and is_covered and roll.attacker_won():
		# Caught on the shield: the spear sticks there and the shield is the worse for it.
		r.tier = OpposedRoll.Tier.LOCKED
		r.winner = archer
		r.loser = target
		r.shield_damage = rules.javelin_shield_damage
		target.shield_hp = maxi(0, target.shield_hp - rules.javelin_shield_damage)
		r.shield_broke = target.shield_hp == 0
		log.append("%s's spear sticks in %s's shield%s" % [archer.display_name, target.display_name, ", and it is done for" if r.shield_broke else ""])
	else:
		# A miss, a graze or a shot caught on the shield: nothing happens.
		r.tier = OpposedRoll.Tier.LOCKED
		log.append("%s %s %s: misses" % [archer.display_name, "throws at" if thrown else "shoots at", target.display_name])
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
	if covered(grid, me, foe.pos):
		s += rules.shield_defense_bonus
		var locked := 0
		for n in grid.line_neighbors(me):
			if _shield_ok(n):
				locked += 1
		if locked >= 2:
			s += rules.locked_shields_bonus
		elif locked == 1:
			s += rules.locked_shields_bonus / 2
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
static func _shield_takes(grid: BattleGrid, r: ExchangeResult) -> bool:
	return covered(grid, r.loser, r.winner.pos)


## Whether a man's shield, or the shield of the man at his right shoulder,
## stands between him and a blow or shot from `from_pos`. His own covers his
## front and left; his open front-right is covered by the man to his right
## in a wall ("the man to your right covers your open side").
static func covered(grid: BattleGrid, me: Warrior, from_pos: Vector2i) -> bool:
	var arc := BattleGrid.arc_of(me, from_pos)
	if _shield_ok(me) and BattleGrid.shield_covers(arc):
		return true
	if arc == CombatTypes.Arc.FRONT_RIGHT:
		var right := grid.occupant(me.pos + BattleGrid.rotate(me.facing, 2))
		return right != null and right.side == me.side and right.is_active() and _shield_ok(right) \
				and BattleGrid.facing_steps(right.facing, me.facing) <= BattleGrid.DEFAULT_LINK_TURN
	return false


static func _damage_shield(rules: CombatRules, r: ExchangeResult) -> void:
	var dmg := rules.shield_damage_glancing
	if r.winner.weapon == CombatTypes.Weapon.BEARDED_AXE:
		dmg += rules.shield_damage_axe_extra
	dmg = mini(dmg, r.loser.shield_hp)
	r.loser.shield_hp -= dmg
	r.shield_damage += dmg
	r.shield_broke = r.loser.shield_hp <= 0


static func is_locked(grid: BattleGrid, w: Warrior) -> bool:
	if not _shield_ok(w):
		return false
	for n in grid.line_neighbors(w):
		if _shield_ok(n):
			return true
	return false


## A lucky leader's close calls go his way, an unlucky one's against him
## (Warrior.luck, CombatRules.luck_close_margin): a blow that lands on him
## with little to spare glances off his helm; one that would have glanced
## bites. Nobody else's luck is ever anything but 0.
static func _close_call(rules: CombatRules, r: ExchangeResult, log: PackedStringArray) -> void:
	var m := absi(r.margin)
	if r.loser.luck > 0 and r.tier == OpposedRoll.Tier.HIT and m <= rules.luck_close_margin:
		r.tier = OpposedRoll.Tier.GLANCING
		log.append(r.loser.said("the blow turns on %s's helm: the men say his luck holds" % r.loser.display_name))
	elif r.loser.luck < 0 and r.tier == OpposedRoll.Tier.GLANCING and m >= rules.luck_close_margin - 1:
		r.tier = OpposedRoll.Tier.HIT
		log.append(r.loser.said("a blow that should have glanced bites into %s: his luck is out" % r.loser.display_name))


static func _apply_glancing(rules: CombatRules, grid: BattleGrid, r: ExchangeResult) -> void:
	if _shield_takes(grid, r):
		_damage_shield(rules, r)
		return
	if rules.locked_braces_against_shove and is_locked(grid, r.loser):
		r.shove_blocked = true  # braced by the men beside him
		return
	var cell := r.loser.pos + BattleGrid.direction_to(r.winner.pos, r.loser.pos)
	if grid.is_free(cell):
		r.shove_to = cell
	else:
		r.shove_blocked = true


static func _apply_wound(rng: SimRng, rules: CombatRules, grid: BattleGrid, r: ExchangeResult) -> void:
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
		if _shield_takes(grid, r):
			_damage_shield(rules, r)
	r.loser.take_wound_steps(steps)
	r.wound_steps_dealt = steps
	r.went_down = r.loser.is_down()
	if steps > 0 and not r.went_down:
		r.loser.add_effort(CombatTypes.Stat.GRIT)
