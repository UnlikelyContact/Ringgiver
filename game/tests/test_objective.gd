extends TestCase
## Battle objectives: the ford, the ships and the hall decide a fight; time
## running out gives it to the defender; only varied fields carry one.

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)


## A small field by hand: four men a side, ours (side 0) on row 8 facing up,
## theirs on row 3 facing down. Nobody is AI-led; check() is called directly.
func _field(rules: CombatRules) -> Battle:
	var b := Battle.new(rules, 11)
	var ours := BandFactory.make_mixed_band(SimRng.new(1), 0, 4, 0, 0, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(SimRng.new(2), 1, 4, 0, 0, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101)
	BandFactory.deploy_formation(b.grid, ours, BattleGrid.from_offset(8, 8), NORTH, rules, FormationTemplate.line())
	BandFactory.deploy_formation(b.grid, theirs, BattleGrid.from_offset(8, 3), SOUTH, rules, FormationTemplate.line())
	b.add_band(ours)
	b.add_band(theirs)
	return b


## Moves the first `n` men of `side` onto the objective's cells.
func _occupy(b: Battle, obj: Objective, side: int, n: int) -> void:
	var men := b.active(side)
	var placed := 0
	for c in obj.cells:
		if placed >= n:
			break
		var occ := b.grid.occupant(c)
		if occ != null:
			continue
		b.grid.place(men[placed], c)
		placed += 1


func test_ford_goes_to_more_men_at_the_end_of_its_rounds() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.HOLD_GROUND, 0, 5, rules)
	obj.place(b.grid, 3, -1, 8)
	b.objective = obj
	assert_eq(obj.rounds, 16, "the ford is held for sixteen rounds by default")
	assert_true(obj.cells.size() >= 3 and obj.cells.size() <= 5, "three to five hexes")
	for c in obj.cells:
		assert_eq(BattleGrid.to_offset(c).y, 4, "the ford lies just before the defender's line")
	_occupy(b, obj, 0, 2)
	b.round = 10
	assert_eq(obj.check(b), -1, "nothing is decided before the end of round 16")
	b.round = 16
	assert_eq(obj.check(b), 0, "two attackers to none: the attacker has the ford")
	assert_true(obj.reason.begins_with("side 0"), obj.reason)


func test_ford_tie_goes_to_the_defender() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.HOLD_GROUND, 0, 5, rules)
	obj.place(b.grid, 3, -1, 8)
	_occupy(b, obj, 0, 1)
	_occupy(b, obj, 1, 1)
	b.round = 16
	assert_eq(obj.check(b), 1, "one each: the defender still holds it")


func test_ships_are_reached_with_enough_men() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.REACH_THE_SHIPS, 0, 5, rules)
	obj.place(b.grid, 3, -1, 8)
	for c in obj.cells:
		assert_eq(BattleGrid.to_offset(c).y, 0, "the ships lie along the defender's edge")
	b.round = 4
	_occupy(b, obj, 0, 3)
	assert_eq(obj.check(b), -1, "three men are not enough")
	b.round = 5
	_occupy(b, obj, 0, 4)
	assert_eq(obj.check(b), 0, "four men at the ships: the attacker wins at once")


func test_ships_safe_when_time_runs_out() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.REACH_THE_SHIPS, 1, 5, rules)
	obj.place(b.grid, 8, 1, 8)
	for c in obj.cells:
		assert_eq(BattleGrid.to_offset(c).y, 11, "our ships, along the bottom edge")
	b.round = 19
	assert_eq(obj.check(b), -1, "still time")
	b.round = 20
	assert_eq(obj.check(b), 0, "time is up: the defender (side 0) wins")
	assert_eq(obj.reason, "the ships are safe: side 0 holds them")


func test_hall_needs_half_its_cells_two_rounds_running() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.THE_HALL, 0, 5, rules)
	obj.place(b.grid, 3, -1, 8)
	assert_true(obj.cells.size() >= 4 and obj.cells.size() <= 6, "four to six hexes")
	var half := (obj.cells.size() + 1) / 2
	_occupy(b, obj, 0, half)
	b.round = 3
	assert_eq(obj.check(b), -1, "one round on it is not enough")
	assert_eq(obj.check(b), -1, "a second call in the same round counts nothing")
	b.round = 4
	assert_eq(obj.check(b), 0, "two rounds running on half the hall: taken")


func test_hall_streak_breaks_when_they_are_thrown_off() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.THE_HALL, 0, 5, rules)
	obj.place(b.grid, 3, -1, 8)
	var half := (obj.cells.size() + 1) / 2
	_occupy(b, obj, 0, half)
	b.round = 3
	assert_eq(obj.check(b), -1)
	# Thrown off: nobody of ours on the hall now.
	var men := b.active(0)
	for i in half:
		b.grid.place(men[i], BattleGrid.from_offset(2 + i, 7))
	b.round = 4
	assert_eq(obj.check(b), -1, "the streak is broken")
	b.round = 18
	assert_eq(obj.check(b), 1, "time runs out: the hall stands")
	assert_true(obj.reason.begins_with("the hall stands"), obj.reason)


func test_battle_finishes_on_the_objective() -> void:
	var rules := CombatRules.new()
	var b := _field(rules)
	var obj := Objective.new(Objective.Kind.REACH_THE_SHIPS, 1, 5, rules)
	obj.rounds = 2
	obj.place(b.grid, 8, 1, 8)
	b.objective = obj
	b.run_round()
	assert_true(not b.is_over(), "round one: still time")
	b.run_round()
	assert_true(b.is_over(), "round two: time is up")
	assert_eq(b.result.winner, 0, "the defender wins")
	assert_true(b.result.by_objective, "decided by the objective")


func test_symmetric_field_has_no_objective() -> void:
	var rules := CombatRules.new()
	for s in 20:
		var f := Scenario.build("equal_green", 100 + s, rules, false)
		assert_true(f.objective == null, "seed %d: no objective without vary" % (100 + s))
		assert_true((f.battle as Battle).objective == null)


func test_varied_fields_carry_objectives_about_seven_in_ten() -> void:
	var rules := CombatRules.new()
	var n_with := 0
	var we_attack := 0
	var kinds := [0, 0, 0]
	for s in 50:
		var f := Scenario.build("equal_green", 1 + s, rules, true)
		var obj: Objective = f.objective
		if obj == null:
			continue
		n_with += 1
		kinds[obj.kind] += 1
		if obj.attacker == 0:
			we_attack += 1
		# The objective sits at the defender's end of the field.
		var rows := 0
		for c in obj.cells:
			rows += BattleGrid.to_offset(c).y
		var mean_row := float(rows) / obj.cells.size()
		if obj.attacker == 0:
			assert_true(mean_row < 5.5, "seed %d: their end, at the top" % (1 + s))
		else:
			assert_true(mean_row > 5.5, "seed %d: our end, at the bottom" % (1 + s))
	assert_true(n_with >= 28 and n_with <= 42, "about 70%% have one (%d of 50)" % n_with)
	assert_true(we_attack >= n_with * 0.3 and we_attack <= n_with * 0.7, "we attack about half (%d of %d)" % [we_attack, n_with])
	for k in 3:
		assert_true(kinds[k] > 0, "every kind turns up")
