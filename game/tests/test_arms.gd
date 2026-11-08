extends TestCase
## Mixed arms: formation templates with ranks, spears fighting at reach from
## the second rank, bows standing off, and the volley of throwing spears.

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)


func _band(rules: CombatRules, side: int, shields: int, spears: int, bows: int, first_id := 1) -> Array[Warrior]:
	return BandFactory.make_mixed_band(SimRng.new(3 + side), side, shields, spears, bows, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, first_id)


func test_ranks_template_puts_spears_behind_and_bows_two_behind() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var band := _band(rules, 0, 5, 2, 2)
	BandFactory.deploy_formation(g, band, BattleGrid.from_offset(8, 8), NORTH, rules, FormationTemplate.ranks())
	var leader := band[0]
	var back := BattleGrid.rotate(NORTH, 3)
	for w in band:
		if w == leader:
			continue
		match w.role:
			CombatTypes.Role.SHIELD:
				assert_eq(BattleGrid.to_offset(w.pos).y, 8, "%s stands in the line" % w.display_name)
			CombatTypes.Role.SPEAR:
				var ahead := g.occupant(w.pos - back)
				assert_true(ahead != null and ahead.side == 0 and ahead.role == CombatTypes.Role.SHIELD, "%s stands straight behind a shield-bearer" % w.display_name)
			CombatTypes.Role.MISSILE:
				assert_eq(BattleGrid.to_offset(w.pos).y, 10, "%s stands two behind" % w.display_name)
	# The wall is the shields and the spears; the bows stand off.
	var wall := g.chain(leader)
	assert_eq(wall.size(), 7, "five shields and two spears in the wall")
	for w in wall:
		assert_true(w.role != CombatTypes.Role.MISSILE, "no bow in the wall")


func test_line_template_puts_everyone_in_the_line() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var band := _band(rules, 0, 4, 2, 1)
	BandFactory.deploy_formation(g, band, BattleGrid.from_offset(8, 8), NORTH, rules, FormationTemplate.line())
	for w in band:
		assert_eq(BattleGrid.to_offset(w.pos).y, 8, "%s in the one line" % w.display_name)


func test_second_rank_spear_strikes_over_a_shoulder() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var front := Warrior.make("front", 0, [4, 4, 4, 4, 4])
	var spear := Warrior.make("spear", 0, [4, 4, 4, 4, 4])
	spear.role = CombatTypes.Role.SPEAR
	var foe := Warrior.make("foe", 1, [4, 4, 4, 4, 4])
	for w in [front, spear, foe]:
		w.reset_for_battle(rules)
	front.id = 1
	spear.id = 2
	foe.id = 101
	g.place(front, Vector2i(8, 6))
	front.facing = NORTH
	g.place(spear, Vector2i(8, 7))  # straight behind him (south-east on this grid is "back" for a north-west face)
	spear.facing = NORTH
	g.place(foe, Vector2i(8, 5))
	foe.facing = SOUTH
	var enemies: Array[Warrior] = [foe]
	var a := Decision.choose(SimRng.new(1), rules, g, spear, front, [front, spear, foe] as Array[Warrior])
	assert_eq(a.kind, CombatTypes.ActionKind.ATTACK, "the spearman strikes at reach")
	assert_true(a.target == foe)
	assert_true(MeleeExchange.can_reach(rules, g, spear, foe), "two cells off through a friend")
	assert_true(not MeleeExchange.can_reach(rules, g, foe, spear), "the foe cannot reach back")


func test_a_wall_halts_to_throw_its_spears_then_comes_on() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var b := Battle.new(rules, 5)
	var ours := _band(rules, 0, 6, 0, 0, 1)
	var theirs := _band(rules, 1, 6, 0, 0, 101)
	for w in theirs:
		w.javelins = 0  # only our side throws, so the count is clean
	BandFactory.deploy_formation(b.grid, ours, BattleGrid.from_offset(8, 7), NORTH, rules, FormationTemplate.line())
	BandFactory.deploy_formation(b.grid, theirs, BattleGrid.from_offset(8, 4), SOUTH, rules, FormationTemplate.line())
	b.add_band(ours)
	b.add_band(theirs)
	for w in theirs:
		w.javelins = 0
	b.set_shout(1, CombatTypes.Shout.HOLD)
	b.set_shout(0, CombatTypes.Shout.SHIELD_WALL)
	b.run_round()
	b.set_shout(0, CombatTypes.Shout.PUSH)
	b.run_round()  # the line steps to two cells off
	var before := 0
	for w in ours:
		before += w.javelins
	assert_eq(before, 6, "six spears in hand")
	b.run_round()  # halts and throws
	var halted := false
	var thrown := 0
	for line in b.log:
		halted = halted or line.contains("looses its spears")
		if line.contains(" throws at ") or line.contains(" spears ") or line.contains("spear sticks"):
			thrown += 1
	assert_true(halted, "the line halts to throw")
	var after := 0
	for w in ours:
		after += w.javelins
	assert_true(after <= 1, "every spear within a throw of the enemy is thrown (%d left)" % after)
	assert_true(thrown >= 5, "the throws are logged (%d)" % thrown)
	var row_before := BattleGrid.to_offset(ours[0].pos).y
	b.run_round()  # and comes on
	assert_true(BattleGrid.to_offset(ours[0].pos).y < row_before or not b.grid.adjacent_warriors(ours[0].pos, 1).is_empty(), "the line steps on after the volley")


func test_thrown_spear_caught_on_a_shield_spoils_it() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var thrower := Warrior.make("thrower", 0, [10, 1, 4, 4, 4])  # a huge arm, no skill: the throw lands but will not pierce
	var mark := Warrior.make("mark", 1, [4, 10, 4, 4, 4])
	for w in [thrower, mark]:
		w.reset_for_battle(rules)
	thrower.javelins = 1
	g.place(thrower, Vector2i(8, 7))
	thrower.facing = NORTH
	g.place(mark, Vector2i(8, 5))
	mark.facing = SOUTH
	var sticks := 0
	var hits := 0
	for i in 200:
		mark.shield_hp = rules.shield_hp
		mark.wound = CombatTypes.Wound.UNHURT
		thrower.javelins = 1
		var log := PackedStringArray()
		var r := MeleeExchange.resolve_shot(SimRng.new(i), rules, g, thrower, mark, log, true)
		assert_true(r.is_thrown)
		assert_eq(thrower.javelins, 0, "the spear is gone whatever happens")
		if r.shield_damage > 0:
			sticks += 1
		if r.wound_steps_dealt > 0:
			hits += 1
	assert_true(sticks > 0, "some spears stick in the shield (%d)" % sticks)
	assert_true(hits > 0, "some spears bite (%d)" % hits)


func test_a_bowman_gives_ground_when_closed_with() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var leader := Warrior.make("jarl", 0, [4, 4, 4, 4, 4])
	leader.is_leader = true
	var bow := Warrior.make("bow", 0, [4, 4, 4, 4, 4])
	bow.role = CombatTypes.Role.MISSILE
	bow.weapon = CombatTypes.Weapon.BOW
	bow.has_shield = false
	var foe := Warrior.make("foe", 1, [4, 4, 4, 4, 4])
	for w in [leader, bow, foe]:
		w.reset_for_battle(rules)
	g.place(leader, Vector2i(8, 9))
	g.place(bow, Vector2i(8, 6))
	bow.facing = NORTH
	g.place(foe, Vector2i(8, 5))
	foe.facing = SOUTH
	var a := Decision.choose(SimRng.new(1), rules, g, bow, leader, [leader, bow, foe] as Array[Warrior])
	assert_eq(a.kind, CombatTypes.ActionKind.MOVE, "he steps away rather than fight")
	assert_true(BattleGrid.distance(a.target_cell, foe.pos) >= 2, "out of arm's reach")
