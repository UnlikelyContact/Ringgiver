extends TestCase

const N := Vector2i(0, -1)
const S := Vector2i(0, 1)
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)


func _rules() -> CombatRules:
	return CombatRules.new()


func _man(r: CombatRules, g: BattleGrid, name: String, side: int, cell: Vector2i, facing: Vector2i,
		stats := [4, 4, 4, 4, 4]) -> Warrior:
	var w := Warrior.make(name, side, stats)
	w.reset_for_battle(r)
	w.facing = facing
	g.place(w, cell)
	return w


## Two men face each other (or `b` is attacked from behind) and trade blows
## until one goes Down. Shoves are not applied, so they stay in contact.
## Returns the average number of exchanges over `trials` seeded duels.
func _mean_exchanges_to_down(trials: int, seed_base: int, armor: CombatTypes.Armor, from_rear: bool) -> float:
	var total := 0
	for t in trials:
		var r := _rules()
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
		if from_rear:
			b.facing = N
		a.armor = armor
		b.armor = armor
		var rng := SimRng.new(seed_base + t)
		var log := PackedStringArray()
		var n := 0
		while n < 200 and a.is_active() and b.is_active():
			MeleeExchange.resolve(rng, r, g, a, b, true, true, false, false, log)
			n += 1
		total += n
	return float(total) / trials


func test_gate_equal_men_four_to_seven_exchanges() -> void:
	var mean := _mean_exchanges_to_down(4000, 1000, CombatTypes.Armor.NONE, false)
	print("    gate: equal men, no armor: %.2f exchanges to Down" % mean)
	assert_between(mean, 4.0, 7.0, "equal unarmored men")


func test_gate_mail_roughly_doubles() -> void:
	var base := _mean_exchanges_to_down(4000, 2000, CombatTypes.Armor.NONE, false)
	var mail := _mean_exchanges_to_down(4000, 3000, CombatTypes.Armor.MAIL, false)
	print("    gate: mail %.2f vs none %.2f (x%.2f)" % [mail, base, mail / base])
	assert_between(mail / base, 1.6, 2.5, "mail ratio")


func test_gate_rear_roughly_halves() -> void:
	var base := _mean_exchanges_to_down(4000, 4000, CombatTypes.Armor.NONE, false)
	var rear := _mean_exchanges_to_down(4000, 5000, CombatTypes.Armor.NONE, true)
	print("    gate: rear %.2f vs front %.2f (x%.2f)" % [rear, base, rear / base])
	assert_between(rear / base, 0.35, 0.65, "rear ratio")


func test_score_components() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
	var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
	# Skill 4 + spear 0 + shield covering the front.
	assert_eq(MeleeExchange.score(r, g, a, b, true, false), 4 + r.shield_defense_bonus)
	assert_eq(MeleeExchange.score(r, g, a, b, true, true), 4 + r.shield_defense_bonus + r.brace_defense_bonus)
	# A shield-bearing line neighbor locks shields.
	_man(r, g, "f", 0, Vector2i(4, 6), N)
	assert_eq(MeleeExchange.score(r, g, a, b, true, false), 4 + r.shield_defense_bonus + r.locked_shields_bonus / 2)  # one neighbour: half
	# A spear directly behind supports.
	_man(r, g, "s", 0, Vector2i(5, 7), N)
	assert_eq(MeleeExchange.score(r, g, a, b, true, false),
			4 + r.shield_defense_bonus + r.locked_shields_bonus / 2 + r.second_rank_support_bonus)


func test_score_flank_and_rear_bonus() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var b := _man(r, g, "b", 1, Vector2i(5, 5), S)  # faces south-east
	# Facing south-east, b's rear arc is north-west and north-east of him.
	# The rear man stands north-east, so he is not on the right man's line
	# (which would lock their shields and muddy the score).
	var rear := _man(r, g, "rear", 0, Vector2i(6, 4), Vector2i(-1, 1))  # behind b, faces b
	var right := _man(r, g, "right", 0, Vector2i(4, 5), E)  # b's right (facing south-east, right is west)
	assert_eq(BattleGrid.arc_of(b, rear.pos), CombatTypes.Arc.REAR)
	assert_eq(BattleGrid.arc_of(b, right.pos), CombatTypes.Arc.RIGHT)
	var base := 4 + r.shield_defense_bonus
	assert_eq(MeleeExchange.score(r, g, rear, b, true, false), base + r.rear_attack_bonus)
	assert_eq(MeleeExchange.score(r, g, right, b, true, false), base + r.flank_attack_bonus)
	# No arc bonus when not attacking.
	assert_eq(MeleeExchange.score(r, g, rear, b, false, false), base)
	# b's shield does not cover the rear.
	assert_eq(MeleeExchange.score(r, g, b, rear, true, false), 4)


func test_two_handers_never_get_shield() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
	var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
	_man(r, g, "f", 0, Vector2i(4, 6), N)
	a.weapon = CombatTypes.Weapon.LONG_AXE
	a.has_shield = true  # wrongly flagged: score must still ignore it
	a.shield_hp = 3
	assert_eq(MeleeExchange.score(r, g, a, b, true, false), 4 + r.weapon_attack_bonus[CombatTypes.Weapon.LONG_AXE])
	a.weapon = CombatTypes.Weapon.BOW
	assert_eq(MeleeExchange.score(r, g, a, b, true, false), 4 + r.weapon_attack_bonus[CombatTypes.Weapon.BOW])


func test_broken_shield_gives_no_bonus() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
	var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
	a.shield_hp = 0
	assert_eq(MeleeExchange.score(r, g, a, b, true, false), 4)


func test_attackers_pay_breath_and_locks_tire() -> void:
	var r := _rules()
	var locks := 0
	for seed in 400:
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
		var full := a.breath
		var res := MeleeExchange.resolve(SimRng.new(seed), r, g, a, b, true, false, false, true, PackedStringArray())
		var expect_a := full - r.breath_cost_attack
		var expect_b := full
		if res.is_locked():
			locks += 1
			expect_a -= r.breath_cost_locked
			expect_b -= r.breath_cost_locked
			assert_eq(res.winner, null)
			assert_eq(a.wound, CombatTypes.Wound.UNHURT)
			assert_eq(b.wound, CombatTypes.Wound.UNHURT)
		assert_eq(a.breath, expect_a, "attacker breath")
		assert_eq(b.breath, expect_b, "bracer breath")
	assert_true(locks > 10, "some exchanges lock")


func test_bracer_who_wins_only_glances() -> void:
	var r := _rules()
	var b_wins := 0
	for seed in 3000:
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S, [4, 9, 4, 4, 4])
		var res := MeleeExchange.resolve(SimRng.new(seed), r, g, a, b, true, false, false, true, PackedStringArray())
		if res.winner == b:
			b_wins += 1
			assert_true(res.tier <= OpposedRoll.Tier.GLANCING, "bracer dealt " + OpposedRoll.tier_name(res.tier))
			assert_eq(a.wound, CombatTypes.Wound.UNHURT)
	assert_true(b_wins > 1000, "skilled bracer wins often")


func test_glancing_hits_shield_or_shoves() -> void:
	var r := _rules()
	var shield_seen := false
	var shove_seen := false
	var blocked_seen := false
	for seed in 2000:
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
		a.weapon = CombatTypes.Weapon.BEARDED_AXE
		# seed % 3: 0 shielded, 1 no shield and free behind, 2 no shield and blocked.
		if seed % 3 != 0:
			b.has_shield = false
			b.shield_hp = 0
		if seed % 3 == 2:
			_man(r, g, "wall", 1, Vector2i(5, 4), S)
		var res := MeleeExchange.resolve(SimRng.new(seed), r, g, a, b, true, false, false, false, PackedStringArray())
		if res.winner != a or res.tier != OpposedRoll.Tier.GLANCING:
			continue
		assert_eq(b.wound, CombatTypes.Wound.UNHURT, "glancing never wounds")
		if b.has_shield:
			shield_seen = true
			assert_eq(res.shield_damage, r.shield_damage_glancing + r.shield_damage_axe_extra)
			assert_eq(b.shield_hp, r.shield_hp - res.shield_damage)
			assert_eq(res.shove_to, ExchangeResult.NO_CELL)
		elif g.occupant(Vector2i(5, 4)) != null:
			blocked_seen = true
			assert_eq(res.shove_to, ExchangeResult.NO_CELL)
			assert_true(res.shove_blocked)
		else:
			shove_seen = true
			assert_eq(res.shove_to, Vector2i(5, 4), "shoved directly away")
		assert_eq(b.pos, Vector2i(5, 5), "exchange never moves anyone")
	assert_true(shield_seen and shove_seen and blocked_seen, "all glancing outcomes seen")


func test_hits_and_heavies_deal_steps_without_armor() -> void:
	var r := _rules()
	var hits := 0
	var heavies := 0
	for seed in 3000:
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N)
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
		var res := MeleeExchange.resolve(SimRng.new(seed), r, g, a, b, true, true, false, false, PackedStringArray())
		if res.winner == null or res.tier < OpposedRoll.Tier.HIT:
			continue
		var expect := r.steps_heavy if res.tier == OpposedRoll.Tier.HEAVY else r.steps_hit
		if res.tier == OpposedRoll.Tier.HEAVY:
			heavies += 1
		else:
			hits += 1
		assert_true(not res.absorbed)
		assert_eq(res.wound_steps_dealt, expect)
		assert_eq(int(res.loser.wound), expect)
		assert_eq(res.loser.effort.get(CombatTypes.Stat.GRIT, 0), 1, "wounded and up gains grit effort")
		assert_eq(res.winner.effort.get(CombatTypes.Stat.SKILL, 0), 1, "winner gains skill effort")
		assert_eq(res.shield_damage, 0, "unabsorbed hit leaves shield alone")
	assert_true(hits > 500 and heavies > 100)


func test_mail_absorbs_at_its_rate_and_damages_shield() -> void:
	var r := _rules()
	var wounding := 0
	var absorbed := 0
	for seed in 6000:
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N, [4, 7, 4, 4, 4])
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
		b.armor = CombatTypes.Armor.MAIL
		var res := MeleeExchange.resolve(SimRng.new(seed), r, g, a, b, true, false, false, false, PackedStringArray())
		if res.winner != a or res.tier < OpposedRoll.Tier.HIT:
			continue
		wounding += 1
		var raw := r.steps_heavy if res.tier == OpposedRoll.Tier.HEAVY else r.steps_hit
		if res.absorbed:
			absorbed += 1
			assert_eq(res.wound_steps_dealt, raw - 1)
			assert_eq(res.shield_damage, r.shield_damage_glancing, "absorbed step marks the shield")
		else:
			assert_eq(res.wound_steps_dealt, raw)
			assert_eq(res.shield_damage, 0)
	var rate := float(absorbed) / wounding
	assert_between(rate, r.absorb_mail - 0.05, r.absorb_mail + 0.05, "mail absorb rate")


func test_helmet_adds_to_absorption() -> void:
	var r := _rules()
	var rng := SimRng.new(77)
	var wounding := 0
	var absorbed := 0
	for i in 8000:
		var g := BattleGrid.new()
		var a := _man(r, g, "a", 0, Vector2i(5, 6), N, [4, 8, 4, 4, 4])
		var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
		b.armor = CombatTypes.Armor.LEATHER
		b.helmet = true
		var res := MeleeExchange.resolve(rng, r, g, a, b, true, false, false, false, PackedStringArray())
		if res.winner == a and res.tier >= OpposedRoll.Tier.HIT:
			wounding += 1
			if res.absorbed:
				absorbed += 1
	var expect := r.absorb_leather + r.absorb_helmet_bonus
	assert_between(float(absorbed) / wounding, expect - 0.05, expect + 0.05, "leather + helmet")


func test_spear_reach_through_friend() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var spear := _man(r, g, "spear", 0, Vector2i(5, 7), N)
	var front := _man(r, g, "front", 0, Vector2i(5, 6), N)
	var foe := _man(r, g, "foe", 1, Vector2i(5, 5), S)
	assert_true(MeleeExchange.can_reach(r, g, spear, foe))
	assert_true(not MeleeExchange.can_reach(r, g, foe, spear), "foe cannot strike back at reach")
	# An axe in the second rank cannot reach.
	spear.weapon = CombatTypes.Weapon.BEARDED_AXE
	assert_true(not MeleeExchange.can_reach(r, g, spear, foe))
	spear.weapon = CombatTypes.Weapon.SPEAR
	# Through an empty cell: no reach.
	g.remove(front)
	assert_true(not MeleeExchange.can_reach(r, g, spear, foe))


func test_defender_beating_reach_attack_does_nothing() -> void:
	var r := _rules()
	var foe_wins := 0
	var spear_wins := 0
	for seed in 3000:
		var g := BattleGrid.new()
		var spear := _man(r, g, "spear", 0, Vector2i(5, 7), N)
		_man(r, g, "front", 0, Vector2i(5, 6), N)
		var foe := _man(r, g, "foe", 1, Vector2i(5, 5), S)
		var res := MeleeExchange.resolve(SimRng.new(seed), r, g, spear, foe, true, true, false, false, PackedStringArray())
		assert_true(res.happened)
		if res.winner == foe:
			foe_wins += 1
			assert_eq(spear.wound, CombatTypes.Wound.UNHURT)
			assert_eq(spear.shield_hp, r.shield_hp)
			assert_eq(res.shove_to, ExchangeResult.NO_CELL)
			assert_eq(res.wound_steps_dealt, 0)
			assert_eq(foe.breath, foe.max_breath(r), "foe could not attack, so paid nothing")
		elif res.winner == spear:
			spear_wins += 1
	assert_true(foe_wins > 500 and spear_wins > 500)


func test_out_of_reach_does_not_happen() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var a := _man(r, g, "a", 0, Vector2i(5, 8), N)
	var b := _man(r, g, "b", 1, Vector2i(5, 5), S)
	var log := PackedStringArray()
	var res := MeleeExchange.resolve(SimRng.new(1), r, g, a, b, true, true, false, false, log)
	assert_true(not res.happened)
	assert_eq(a.breath, a.max_breath(r))
	assert_eq(log.size(), 1)


func test_resolve_is_replayable_and_logs() -> void:
	var outs := []
	for k in 2:
		var r := _rules()
		var g := BattleGrid.new()
		var a := _man(r, g, "Egil", 0, Vector2i(5, 6), N)
		var b := _man(r, g, "Grim", 1, Vector2i(5, 5), S)
		var rng := SimRng.new(99)
		var log := PackedStringArray()
		for i in 10:
			MeleeExchange.resolve(rng, r, g, a, b, true, true, false, false, log)
		assert_eq(log.size(), 10)
		outs.append([a.wound, b.wound, a.breath, b.breath, a.shield_hp, b.shield_hp, "\n".join(log)])
	assert_eq(outs[0], outs[1])


func test_shot_range_and_effects() -> void:
	var r := _rules()
	var g := BattleGrid.new()
	var archer := _man(r, g, "archer", 0, Vector2i(5, 11), N)
	archer.weapon = CombatTypes.Weapon.BOW
	archer.has_shield = false
	var far := _man(r, g, "far", 1, Vector2i(5, 11 - r.missile_range - 1), S)
	var res := MeleeExchange.resolve_shot(SimRng.new(1), r, g, archer, far, PackedStringArray())
	assert_true(not res.happened, "beyond missile_range")
	var target := _man(r, g, "t", 1, Vector2i(5, 8), S)
	var rng := SimRng.new(5)
	for i in 3000:
		target.wound = CombatTypes.Wound.UNHURT
		target.shield_hp = r.shield_hp
		archer.breath = archer.max_breath(r)
		var s := MeleeExchange.resolve_shot(rng, r, g, archer, target, PackedStringArray())
		assert_eq(s.shove_to, ExchangeResult.NO_CELL, "a bow never shoves")
		if s.winner == null:
			assert_eq(target.wound, CombatTypes.Wound.UNHURT, "miss or graze does nothing")
			assert_eq(target.shield_hp, r.shield_hp)
		else:
			assert_true(s.tier >= OpposedRoll.Tier.HIT)


func _shot_hit_rate(r: CombatRules, dist: int, seed: int) -> float:
	var g := BattleGrid.new()
	var archer := _man(r, g, "archer", 0, Vector2i(5, 11), N)
	archer.weapon = CombatTypes.Weapon.BOW
	archer.has_shield = false
	var target := _man(r, g, "t", 1, Vector2i(5, 11 - dist), S)
	target.has_shield = false
	target.shield_hp = 0
	var rng := SimRng.new(seed)
	var hits := 0
	var n := 6000
	for i in n:
		target.wound = CombatTypes.Wound.UNHURT
		archer.breath = archer.max_breath(r)
		if MeleeExchange.resolve_shot(rng, r, g, archer, target, PackedStringArray()).winner != null:
			hits += 1
	return float(hits) / n


func test_range_rain_and_shield_lower_hit_rate() -> void:
	var r := _rules()
	var near := _shot_hit_rate(r, 3, 10)
	var far := _shot_hit_rate(r, 6, 11)
	assert_true(near > far + 0.1, "range penalty: %.2f vs %.2f" % [near, far])
	r.raining = true
	var wet := _shot_hit_rate(r, 3, 12)
	assert_true(near > wet + 0.08, "rain penalty: %.2f vs %.2f" % [near, wet])


func test_shield_stops_shots_from_front_not_rear() -> void:
	var r := _rules()
	var rates := []
	for facing in [S, N]:
		var g := BattleGrid.new()
		var archer := _man(r, g, "archer", 0, Vector2i(5, 11), N)
		archer.weapon = CombatTypes.Weapon.BOW
		archer.has_shield = false
		var target := _man(r, g, "t", 1, Vector2i(5, 8), facing)
		var rng := SimRng.new(31)
		var hits := 0
		for i in 6000:
			target.wound = CombatTypes.Wound.UNHURT
			target.shield_hp = r.shield_hp
			archer.breath = archer.max_breath(r)
			if MeleeExchange.resolve_shot(rng, r, g, archer, target, PackedStringArray()).winner != null:
				hits += 1
		rates.append(float(hits) / 6000)
	assert_true(rates[1] > rates[0] + 0.1, "back turned is easier: %s" % str(rates))


func test_locked_shields_full_with_both_sides_half_with_one() -> void:
	var r := CombatRules.new()
	var g := BattleGrid.new(8, 8)
	var me := Warrior.make("me", 0, [4, 4, 4, 4, 4])
	var foe := Warrior.make("foe", 1, [4, 4, 4, 4, 4])
	var left := Warrior.make("l", 0, [4, 4, 4, 4, 4])
	var right := Warrior.make("r", 0, [4, 4, 4, 4, 4])
	for w in [me, foe, left, right]:
		w.reset_for_battle(r)
	me.facing = Vector2i(0, -1)
	g.place(me, Vector2i(4, 4))
	g.place(foe, Vector2i(4, 3))
	var alone := MeleeExchange.score(r, g, me, foe, false, false)
	g.place(left, Vector2i(3, 4))
	var one := MeleeExchange.score(r, g, me, foe, false, false)
	g.place(right, Vector2i(5, 4))
	var both := MeleeExchange.score(r, g, me, foe, false, false)
	assert_eq(one - alone, r.locked_shields_bonus / 2, "one neighbour: half")
	assert_eq(both - alone, r.locked_shields_bonus, "both sides: full")


func test_locked_man_is_not_shoved_by_a_glancing_blow() -> void:
	var r := CombatRules.new()
	var g := BattleGrid.new(8, 8)
	var me := Warrior.make("me", 0, [4, 4, 4, 4, 4])
	var foe := Warrior.make("foe", 1, [4, 9, 4, 4, 4])
	var left := Warrior.make("l", 0, [4, 4, 4, 4, 4])
	for w in [me, foe, left]:
		w.reset_for_battle(r)
	me.facing = Vector2i(0, 1)  # facing away: no shield cover, so a glancing blow would shove
	g.place(me, Vector2i(4, 4))
	g.place(foe, Vector2i(4, 3))
	g.place(left, Vector2i(3, 4))
	left.facing = Vector2i(0, 1)
	var shoved := 0
	var blocked := 0
	var log := PackedStringArray()
	for i in 300:
		me.wound = CombatTypes.Wound.UNHURT
		me.shield_hp = r.shield_hp
		var res := MeleeExchange.resolve(SimRng.new(i), r, g, foe, me, true, false, false, false, log)
		if res.loser == me and res.tier == OpposedRoll.Tier.GLANCING:
			if res.shove_to != Vector2i(-1, -1):
				shoved += 1
			elif res.shove_blocked:
				blocked += 1
	assert_eq(shoved, 0, "a locked man is braced by his neighbour")
	assert_true(blocked > 0, "glancing blows happened and were braced: %d" % blocked)
