extends TestCase
## The ambush: the fight you chose. The enemy is strung out on the march,
## their leader struck dumb for two rounds and their men shaken; your band
## stands formed two rows off, in range to throw. See concept.md, "Picking
## your fights".


func test_the_ambushed_band_is_a_column_on_the_track() -> void:
	var rules := CombatRules.new()
	var f := Scenario.build("ambush", 5, rules, true, 12)
	var b: Battle = f.battle
	assert_eq(f.field_name, "ambush")
	assert_eq(f.title, "Ambush")
	assert_true(f.objective == null, "no objective: the fight is the point")
	var theirs: Array = f.theirs
	var rows := {}
	var cols := []
	for w in theirs:
		rows[BattleGrid.to_offset(w.pos).y] = true
		cols.append(BattleGrid.to_offset(w.pos).x)
		assert_eq(w.facing, Vector2i(1, 0), "%s faces along the track" % w.display_name)
	assert_eq(rows.size(), 1, "the column lies along one row")
	cols.sort()
	assert_true(cols[-1] - cols[0] + 1 > theirs.size(), "strung out: the column is longer than the men in it")
	var ours: Array = f.ours
	var track: int = BattleGrid.to_offset(theirs[0].pos).y
	var front := 99
	for w in ours:
		front = mini(front, BattleGrid.to_offset(w.pos).y)
	assert_eq(front - track, rules.ambush_distance, "your front rank stands two rows below the track")
	for w in theirs:
		assert_true(w.morale >= rules.morale_break_threshold, "shaken, not broken: %s at %d" % [w.display_name, w.morale])
	assert_eq(b.ambushed_side, 1)


func test_the_surprised_leader_gives_no_order_then_wakes() -> void:
	var rules := CombatRules.new()
	var f := Scenario.build("ambush", 5, rules, true, 12)
	var b: Battle = f.battle
	b.set_shout(0, CombatTypes.Shout.HOLD)
	b.run_round()
	assert_true(b.is_surprised(1), "round one: surprised")
	assert_eq(b.last_shout(1), CombatTypes.Shout.NONE, "no order comes from him")
	var told := false
	for line in b.log:
		if line.contains("taken by surprise"):
			told = true
	assert_true(told, "the log says so")
	b.set_shout(0, CombatTypes.Shout.HOLD)
	b.run_round()
	assert_eq(b.last_shout(1), CombatTypes.Shout.NONE, "round two: still none")
	b.set_shout(0, CombatTypes.Shout.HOLD)
	b.run_round()
	assert_true(not b.is_surprised(1), "round three: he has his wits again")
	assert_ne(b.last_shout(1), CombatTypes.Shout.NONE, "and shouts")


func test_an_ambush_is_a_fight_worth_choosing() -> void:
	# Pushing at once from the trees wins most of them: this is the one
	# fight where the attacker holds the advantage.
	var rules := CombatRules.new()
	var wins := 0
	var n := 24
	for s in n:
		var f := Scenario.build("ambush", 100 + s, rules, true, 12)
		var b: Battle = f.battle
		while not b.is_over() and b.round < rules.max_rounds:
			b.set_shout(0, CombatTypes.Shout.SHIELD_WALL if b.round == 0 else CombatTypes.Shout.PUSH)
			b.run_round()
		if b.result.winner == 0:
			wins += 1
	print("    gate: ambush, push from the trees, wins %d of %d" % [wins, n])
	assert_true(wins * 100 >= n * 60, "an ambush pushed home wins at least six in ten: %d of %d" % [wins, n])
