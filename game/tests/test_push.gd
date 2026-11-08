extends TestCase

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)


func _man(name: String, side: int, id: int, rules: CombatRules, stats := [4, 4, 4, 4, 4]) -> Warrior:
	var w := Warrior.make(name, side, stats)
	w.id = id
	w.reset_for_battle(rules)
	return w


func _put(grid: BattleGrid, w: Warrior, c: Vector2i, facing: Vector2i) -> void:
	grid.place(w, c)
	w.facing = facing


## Two facing lines: side 0 on row 6 facing north over xs0, side 1 on row 5
## facing south over xs1.
func _lines(grid: BattleGrid, rules: CombatRules, xs0: Array, xs1: Array,
		stats0 := [4, 4, 4, 4, 4], stats1 := [4, 4, 4, 4, 4]) -> Array[Warrior]:
	var all: Array[Warrior] = []
	var id := 1
	for x in xs0:
		var w := _man("a%d" % x, 0, id, rules, stats0)
		_put(grid, w, Vector2i(x, 6), NORTH)
		all.append(w)
		id += 1
	for x in xs1:
		var w := _man("b%d" % x, 1, id, rules, stats1)
		_put(grid, w, Vector2i(x, 5), SOUTH)
		all.append(w)
		id += 1
	return all


func test_no_contact_no_push() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var log := PackedStringArray()
	var a := _man("a", 0, 1, rules)
	var b := _man("b", 1, 2, rules)
	_put(grid, a, Vector2i(3, 6), NORTH)
	_put(grid, b, Vector2i(3, 3), SOUTH)
	var all: Array[Warrior] = [a, b]
	var r := Push.resolve(SimRng.new(1), rules, grid, all, log)
	assert_eq(r.winning_side, -1)
	assert_eq(r.contests, 0)
	assert_true(r.shoved.is_empty())
	# Adjacent but facing away: not in contact either.
	grid.place(b, Vector2i(3, 7))
	b.facing = SOUTH
	a.facing = NORTH
	var r2 := Push.resolve(SimRng.new(1), rules, grid, all, log)
	assert_eq(r2.contests, 0, "enemy behind is not contact")
	assert_eq(r2.winning_side, -1)
	assert_true(r2.describe().length() > 0)


func test_group_strength_formula() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var front := _man("front", 0, 1, rules, [6, 4, 4, 4, 4])  # morale 4
	var back := _man("back", 0, 2, rules)
	_put(grid, front, Vector2i(4, 6), NORTH)
	_put(grid, back, Vector2i(4, 7), NORTH)
	var g: Array[Warrior] = [front]
	var expected := 6.0 * (1.0 + rules.push_morale_weight * 0.4) + rules.push_second_rank_bonus
	assert_between(Push.group_strength(rules, grid, g), expected - 0.001, expected + 0.001)
	back.take_wound_steps(4)
	expected -= rules.push_second_rank_bonus
	assert_between(Push.group_strength(rules, grid, g), expected - 0.001, expected + 0.001,
		"a downed man behind gives no support")


func test_stronger_line_wins_and_losers_give_ground() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var wins := [0, 0]
	var trials := 2000
	for s in trials:
		var grid := BattleGrid.new(16, 12)
		var log := PackedStringArray()
		var all := _lines(grid, rules, [4, 5, 6], [4, 5, 6], [6, 4, 4, 6, 4], [3, 4, 4, 3, 4])
		var r := Push.resolve(SimRng.new(s), rules, grid, all, log)
		assert_eq(r.contests, 1)
		if r.winning_side < 0:
			continue
		wins[r.winning_side] += 1
		assert_eq(r.shoved.size(), 3, "the whole losing line gives ground")
		for w in r.shoved:
			assert_ne(w.side, r.winning_side)
			assert_eq(w.pos.y, 7 if w.side == 0 else 4, "shoved one cell straight back")
		for w in all:
			if w.side == r.winning_side:
				assert_eq(w.effort.get(CombatTypes.Stat.MIGHT, 0), 1, "winners gain Might effort")
	# Strength 3 * 6 * 1.3 = 23.4 vs 3 * 3 * 1.15 = 10.35: the bigger men win
	# nearly always; equal lines would be near even.
	assert_between(float(wins[0]) / trials, 0.97, 1.0, "strong side wins")


func test_equal_lines_are_even() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	rules.push_min_margin = 1  # this test calibrates the contest, not the threshold
	var wins := [0, 0]
	var trials := 4000
	for s in trials:
		var grid := BattleGrid.new(16, 12)
		var all := _lines(grid, rules, [4, 5, 6], [4, 5, 6])
		var r := Push.resolve(SimRng.new(s), rules, grid, all, PackedStringArray())
		if r.winning_side >= 0:
			wins[r.winning_side] += 1
	assert_between(float(wins[0]) / trials, 0.40, 0.50)
	assert_between(float(wins[1]) / trials, 0.40, 0.50)


func test_morale_and_second_rank_tip_the_push() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	rules.push_min_margin = 1  # this test calibrates the contest, not the threshold
	var wins0 := 0
	var trials := 4000
	for s in trials:
		var grid := BattleGrid.new(16, 12)
		var all := _lines(grid, rules, [4, 5, 6], [4, 5, 6])
		var id := 50
		for x in [4, 5, 6]:
			var back := _man("r%d" % x, 0, id, rules)
			_put(grid, back, Vector2i(x, 7), NORTH)
			all.append(back)
			id += 1
		for w in all:
			if w.side == 0:
				w.morale = 9
		var r := Push.resolve(SimRng.new(s), rules, grid, all, PackedStringArray())
		if r.winning_side == 0:
			wins0 += 1
	assert_between(float(wins0) / trials, 0.85, 1.0, "heartened, supported line wins")


func test_blocked_shove_costs_breath() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var log := PackedStringArray()
	# A huge, high-morale man (15 strength) against a weak, shaken one (1):
	# margin is always positive. The loser has a friend at his back.
	var strong := _man("strong", 0, 1, rules, [10, 4, 4, 4, 4])
	strong.morale = 10
	var weak := _man("weak", 1, 2, rules, [1, 4, 4, 4, 4])
	weak.morale = 0
	var wall := _man("wall", 1, 3, rules)
	_put(grid, strong, Vector2i(5, 6), NORTH)
	_put(grid, weak, Vector2i(5, 5), SOUTH)
	_put(grid, wall, Vector2i(5, 4), SOUTH)
	var all: Array[Warrior] = [strong, weak, wall]
	var before := weak.breath
	var r := Push.resolve(SimRng.new(9), rules, grid, all, log)
	assert_eq(r.winning_side, 0)
	assert_true(r.shoved.is_empty())
	assert_eq(r.blocked, [weak] as Array[Warrior])
	assert_eq(weak.pos, Vector2i(5, 5), "blocked man stays put")
	assert_eq(weak.breath, before - rules.push_blocked_breath)
	assert_eq(wall.breath, before, "the man behind was not in contact")
	# The map edge is different: a man pressed back onto it is driven from the field.
	var grid2 := BattleGrid.new(16, 12)
	var s2 := _man("s2", 0, 1, rules, [10, 4, 4, 4, 4])
	s2.morale = 10
	var w2 := _man("w2", 1, 2, rules, [1, 4, 4, 4, 4])
	w2.morale = 0
	_put(grid2, s2, Vector2i(5, 1), NORTH)
	_put(grid2, w2, Vector2i(5, 0), SOUTH)
	var all2: Array[Warrior] = [s2, w2]
	var r2 := Push.resolve(SimRng.new(9), rules, grid2, all2, log)
	assert_eq(r2.blocked.size(), 0)
	assert_eq(r2.driven_off, [w2] as Array[Warrior])
	assert_true(w2.fled, "driven off the field")
	assert_eq(grid2.occupant(Vector2i(5, 0)), null, "and gone from the grid")


func test_groups_are_line_connected_components() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	# Full lines facing each other: one group per side, one contest.
	var grid := BattleGrid.new(16, 12)
	var all := _lines(grid, rules, [2, 3, 4, 5, 6, 7], [2, 3, 4, 5, 6, 7])
	var r := Push.resolve(SimRng.new(1), rules, grid, all, PackedStringArray())
	assert_eq(r.contests, 1)
	# A gap in side 0's line splits it into two groups, each pushing alone.
	# Side 1's man at x=4 then has nobody in his front arc, so side 1 also
	# splits into {2,3} and {5,6,7}: two touching pairs, two contests.
	var grid2 := BattleGrid.new(16, 12)
	var all2 := _lines(grid2, rules, [2, 3, 6, 7], [2, 3, 4, 5, 6, 7])
	var r2 := Push.resolve(SimRng.new(1), rules, grid2, all2, PackedStringArray())
	assert_eq(r2.contests, 2)
	# Two separate skirmishes far apart: two contests.
	var grid3 := BattleGrid.new(16, 12)
	var all3 := _lines(grid3, rules, [1, 2, 10, 11], [1, 2, 10, 11])
	var r3 := Push.resolve(SimRng.new(1), rules, grid3, all3, PackedStringArray())
	assert_eq(r3.contests, 2)
	var s0: float = r3.strengths[0]
	var expected := 4 * 4.0 * (1.0 + rules.push_morale_weight * 0.4)
	assert_between(s0, expected - 0.001, expected + 0.001, "strengths sum over the side's groups")


func test_broken_men_do_not_push() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var all := _lines(grid, rules, [4], [4])
	all[0].broken = true
	all[1].broken = true
	var r := Push.resolve(SimRng.new(1), rules, grid, all, PackedStringArray())
	assert_eq(r.contests, 0)


func test_push_is_deterministic() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var out := []
	for k in 2:
		var grid := BattleGrid.new(16, 12)
		var all := _lines(grid, rules, [3, 4, 5, 6], [3, 4, 5, 6])
		var log := PackedStringArray()
		var r := Push.resolve(SimRng.new(1234), rules, grid, all, log)
		out.append([r.winning_side, r.shoved.size(), "\n".join(log)])
	assert_eq(out[0], out[1])
