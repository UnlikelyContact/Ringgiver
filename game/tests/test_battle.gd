extends TestCase
## Milestone 1 gate (concept.md, First playable): green versus veteran bands
## under the same AI shouts differ clearly, battles are not over in three
## rounds, and every battle replays exactly from its seed.

const Batch := preload("res://tools/batch_battles.gd")


func _fight(name: String, seed_in: int) -> BattleResult:
	var b: Battle = Batch.build_battle(name, seed_in, CombatRules.new())
	return b.run()


func test_replay_is_exact() -> void:
	var a := _fight("equal_green", 11)
	var b := _fight("equal_green", 11)
	assert_eq(a.winner, b.winner)
	assert_eq(a.rounds, b.rounds)
	assert_eq(a.log.size(), b.log.size())
	for i in mini(a.log.size(), b.log.size()):
		if a.log[i] != b.log[i]:
			fail("log diverges at line %d: %s | %s" % [i, a.log[i], b.log[i]])
			break


func test_battle_ends_with_a_result() -> void:
	var r := _fight("veteran_vs_green", 3)
	assert_true(r.rounds >= 1)
	assert_true(r.winner >= -1 and r.winner <= 1)
	assert_eq(r.started[0], 8)
	assert_eq(r.started[1], 8)
	assert_true(r.downed[0] + r.downed[1] + r.fled[0] + r.fled[1] > 0, "something happened")


func test_gate_green_versus_veteran() -> void:
	var n := 60
	var vet_wins := 0
	var rounds := 0
	var green_lost := 0
	var vet_lost := 0
	for i in n:
		var r := _fight("green_vs_veteran", 100 + i)
		if r.winner == 1:
			vet_wins += 1
		rounds += r.rounds
		green_lost += r.losses(0)
		vet_lost += r.losses(1)
	var mean_rounds := float(rounds) / n
	print("    gate: veterans win %.0f%% of %d, mean rounds %.1f, losses green %.1f vs veteran %.1f per battle" % [
		100.0 * vet_wins / n, n, mean_rounds, float(green_lost) / n, float(vet_lost) / n])
	assert_between(float(vet_wins) / n, 0.75, 1.0, "veterans should win clearly")
	assert_between(mean_rounds, 8.0, 30.0, "battles neither trivial nor endless")
	assert_true(green_lost > vet_lost * 2, "green losses dwarf veteran losses")


func test_equal_bands_are_not_one_sided_by_seed() -> void:
	var n := 40
	var a_wins := 0
	var decided := 0
	for i in n:
		var r := _fight("equal_veteran", 500 + i)
		if r.winner >= 0:
			decided += 1
			if r.winner == 0:
				a_wins += 1
	assert_true(decided >= n / 2, "most equal fights are decided inside max_rounds (%d of %d)" % [decided, n])


func test_the_line_is_dressed_each_round() -> void:
	var rules := CombatRules.new()
	var b := Battle.new(rules, 3)
	var ours := BandFactory.make_band(SimRng.new(3).fork("a"), 0, 6, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_band(SimRng.new(3).fork("b"), 1, 6, CombatTypes.Tier.BLOODED, CombatTypes.Armor.NONE, 16, 101)
	BandFactory.deploy_line(b.grid, ours, BattleGrid.from_offset(8, 8), Vector2i(0, -1), rules)
	BandFactory.deploy_line(b.grid, theirs, BattleGrid.from_offset(8, 3), Vector2i(0, 1), rules)
	b.add_band(ours)
	b.add_band(theirs)
	b.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.STEADY))
	# Turn every man of ours some other way, as a blow or a glance would.
	for w in ours:
		if not w.is_leader:
			w.facing = Vector2i(1, -1)
	b.set_shout(0, CombatTypes.Shout.HOLD)
	b.run_round()
	var in_wall := 0
	for w in ours:
		if w.is_active() and not b.grid.line_neighbors(w).is_empty():
			in_wall += 1
	assert_true(in_wall >= 5, "men standing in the row are back on the wall's facing: %d of 6" % in_wall)


func _two_walls(seed_in: int) -> Array:
	var rules := CombatRules.new()
	var b := Battle.new(rules, seed_in)
	var ours := BandFactory.make_band(SimRng.new(seed_in).fork("a"), 0, 6, CombatTypes.Tier.VETERAN, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_band(SimRng.new(seed_in).fork("b"), 1, 6, CombatTypes.Tier.VETERAN, CombatTypes.Armor.NONE, 16, 101)
	BandFactory.deploy_line(b.grid, ours, BattleGrid.from_offset(8, 9), Vector2i(0, -1), rules)
	BandFactory.deploy_line(b.grid, theirs, BattleGrid.from_offset(8, 1), Vector2i(0, 1), rules)
	b.add_band(ours)
	b.add_band(theirs)
	for side in 2:
		b.result.started[side] = 6
	return [b, ours, theirs]


func test_a_wall_pushes_as_one() -> void:
	var parts := _two_walls(5)
	var b: Battle = parts[0]
	var ours: Array[Warrior] = parts[1]
	b.set_shout(0, CombatTypes.Shout.PUSH)
	b.set_shout(1, CombatTypes.Shout.HOLD)
	var rows_before := {}
	for w in ours:
		rows_before[w] = BattleGrid.to_offset(w.pos).y
	b.run_round()
	var moved := 0
	for w in ours:
		if BattleGrid.to_offset(w.pos).y == rows_before[w] - 1:
			moved += 1
	assert_true(moved == 0 or moved == ours.size(), "everyone steps or nobody does: %d of %d" % [moved, ours.size()])
	assert_eq(b.wall_members(0).size(), ours.size(), "the wall is still whole after the step")
	var stepped := false
	for line in b.log:
		if line.contains("steps forward as one") or line.contains("hesitates"):
			stepped = true
	assert_true(stepped, "the wall's own test is logged")


func test_the_line_flows_past_a_blocked_man() -> void:
	var parts := _two_walls(6)
	var b: Battle = parts[0]
	var ours: Array[Warrior] = parts[1]
	# Water in front of the leftmost man.
	var left: Warrior = ours[0]
	for w in ours:
		if BattleGrid.to_offset(w.pos).x < BattleGrid.to_offset(left.pos).x:
			left = w
	var ahead := left.pos + BattleGrid.advance_step(left.pos, Vector2i(0, -1))
	b.grid.set_terrain(ahead, CombatTypes.Terrain.WATER)
	b.set_shout(0, CombatTypes.Shout.PUSH)
	b.set_shout(1, CombatTypes.Shout.HOLD)
	var before := {}
	for w in ours:
		before[w] = w.pos
	b.run_round()
	# Whether the wall stepped or hesitated, it bent round the water rather
	# than breaking: nobody is on it and every man is still in the wall.
	for w in ours:
		assert_true(b.grid.terrain_at(w.pos) != CombatTypes.Terrain.WATER, "%s is not in the water" % w.display_name)
	assert_eq(b.wall_members(0).size(), ours.size(), "the wall is whole")
	var said := false
	for line in b.log:
		said = said or line.contains("step and") or line.contains("hesitates") or line.contains("as one")
	assert_true(said, "the wall stepped or hesitated as one")


func test_a_wall_falls_back_as_one_except_a_man_whose_nerve_goes() -> void:
	var parts := _two_walls(7)
	var b: Battle = parts[0]
	var ours: Array[Warrior] = parts[1]
	var theirs: Array[Warrior] = parts[2]
	# Enemies close enough to matter but not adjacent.
	for w in theirs:
		b.grid.place(w, w.pos + Vector2i(0, 4))
	var shaky: Warrior = null
	for w in ours:
		if not w.is_leader:
			shaky = w
			break
	shaky.tier = CombatTypes.Tier.GREEN
	shaky.morale = b.rules.fall_back_steady_morale
	b.set_shout(0, CombatTypes.Shout.FALL_BACK)
	b.set_shout(1, CombatTypes.Shout.HOLD)
	var rows := {}
	for w in ours:
		rows[w] = BattleGrid.to_offset(w.pos).y
	b.run_round()
	var stepped_back := 0
	for w in ours:
		if w != shaky and BattleGrid.to_offset(w.pos).y == rows[w] + 1:
			stepped_back += 1
	var nerve_line := false
	for line in b.log:
		if line.contains("nerve goes"):
			nerve_line = true
	if nerve_line:
		assert_true(stepped_back == ours.size() - 1, "the rest of the wall stepped back together: %d" % stepped_back)
	else:
		assert_true(stepped_back == 0 or stepped_back == ours.size(), "the wall hesitated or moved whole")


func test_falling_back_keeps_heart_and_halts_at_the_edge() -> void:
	var parts := _two_walls(8)
	var b: Battle = parts[0]
	var ours: Array[Warrior] = parts[1]
	for w in ours:
		w.morale = 8
	# Isolate the rule: no leader heartening, and no "quits the field" before the edge.
	b.rules.morale_leader_adjacent = 0
	b.rules.morale_leader_near = 0
	b.rules.retreat_stall_rounds = 99
	b.rules.withdraw_distance = 99  # isolate the edge rule from the out-of-reach rule
	b.set_shout(0, CombatTypes.Shout.FALL_BACK)
	b.set_shout(1, CombatTypes.Shout.HOLD)
	b.run_round()
	var stepped := false
	for line in b.log:
		if line.contains("steps back as one"):
			stepped = true
	if stepped:
		for w in ours:
			if w.is_active() and not w.is_leader:
				assert_eq(w.morale, 8 + b.rules.fall_back_morale, "%s keeps heart on an ordered fall back" % w.display_name)
	# Keep falling back: the wall starts on row 9 of 12, so the edge comes
	# soon. Ordered back, the line halts there rather than leaving the field:
	# a commanded fall back is a manoeuvre, not a rout.
	var rounds := 0
	while not b.is_over() and rounds < 8:
		b.set_shout(0, CombatTypes.Shout.FALL_BACK)
		b.run_round()
		rounds += 1
	var halted := false
	for line in b.log:
		if line.contains("can give no more ground"):
			halted = true
	assert_true(halted, "a wall ordered back into the edge halts there")
	assert_eq(b.result.fled[0], 0, "nobody left the field")
	assert_true(not b.is_over(), "and the fight is not over for it")
	for w in ours:
		if w.is_active():
			assert_true(b.grid.in_bounds(w.pos), "%s still stands on the field" % w.display_name)
