extends TestCase

const GATE_TRIALS := 2000


func _man(name: String, side: int, id: int, rules: CombatRules, stats := [4, 4, 4, 4, 4]) -> Warrior:
	var w := Warrior.make(name, side, stats)
	w.id = id
	w.reset_for_battle(rules)
	return w


func _put(grid: BattleGrid, w: Warrior, c: Vector2i, facing := Vector2i(0, -1)) -> void:
	grid.place(w, c)
	w.facing = facing


## One gate run: a line of six all-4s men facing north, optionally with
## their leader directly behind the middle (adjacent to three of them). Each
## round one more friend goes down just in front of the line (the spot walks
## along it), then the morale beat runs. Returns how many of the six are
## broken after 10 rounds.
func _gate_run(seed: int, with_leader: bool) -> int:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var rng := SimRng.new(seed)
	var log := PackedStringArray()
	var all: Array[Warrior] = []
	var line: Array[Warrior] = []
	for i in 6:
		var w := _man("line%d" % i, 0, i + 1, rules)
		_put(grid, w, Vector2i(5 + i, 6))
		line.append(w)
		all.append(w)
	var leaders := {0: null}
	if with_leader:
		var lead := _man("leader", 0, 10, rules)
		lead.is_leader = true
		_put(grid, lead, Vector2i(7, 7))
		all.append(lead)
		leaders[0] = lead
	var last_down: Warrior = null
	for r in 10:
		if last_down != null:
			grid.remove(last_down)
		var f := _man("friend%d" % r, 0, 100 + r, rules)
		_put(grid, f, Vector2i(5 + r % 6, 5))
		all.append(f)
		f.take_wound_steps(4)
		Morale.on_down(rules, grid, f, all, log)
		Morale.round_update(rng, rules, grid, all, leaders, true, log)
		last_down = f
	var broken := 0
	for w in line:
		if w.broken:
			broken += 1
	return broken


## Gate: the line "holds" when a majority (at most two of six) is still
## unbroken after ten rounds of one friend falling per round.
func test_gate_leader_holds_the_line() -> void:
	var held_with := 0
	var held_without := 0
	var broken_with := 0
	var broken_without := 0
	for s in GATE_TRIALS:
		var bw := _gate_run(s, true)
		var bn := _gate_run(s, false)
		broken_with += bw
		broken_without += bn
		if bw <= 2:
			held_with += 1
		if bn <= 2:
			held_without += 1
	var rate_with := float(held_with) / GATE_TRIALS
	var rate_without := float(held_without) / GATE_TRIALS
	print("    gate: line holds %.3f with leader, %.3f without; mean broken %.2f vs %.2f of 6" % [
		rate_with, rate_without, float(broken_with) / GATE_TRIALS, float(broken_without) / GATE_TRIALS])
	assert_between(rate_with, 0.35, 0.8, "line with leader holds")
	assert_between(rate_without, 0.0, 0.08, "line without leader holds")
	assert_true(rate_with - rate_without >= 0.3, "leader should matter a great deal")
	assert_true(broken_without - broken_with >= GATE_TRIALS, "at least one fewer broken man on average")


func test_on_down_moves_morale_by_distance_and_side() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var log := PackedStringArray()
	var downed := _man("downed", 0, 1, rules)
	var adj := _man("adj", 0, 2, rules)
	var near := _man("near", 0, 3, rules)
	var far := _man("far", 0, 4, rules)
	var foe := _man("foe", 1, 5, rules)
	var far_foe := _man("far_foe", 1, 6, rules)
	_put(grid, downed, Vector2i(5, 5))
	_put(grid, adj, Vector2i(6, 5))
	_put(grid, near, Vector2i(5, 5 + rules.morale_visible_radius))
	_put(grid, far, Vector2i(5 + rules.morale_visible_radius + 1, 5))
	_put(grid, foe, Vector2i(5, 4))
	_put(grid, far_foe, Vector2i(5 - rules.morale_visible_radius - 1, 5))
	var all: Array[Warrior] = [downed, adj, near, far, foe, far_foe]
	downed.take_wound_steps(4)
	Morale.on_down(rules, grid, downed, all, log)
	assert_eq(adj.morale, 4 + rules.morale_ally_down_adjacent, "adjacent friend")
	assert_eq(near.morale, 4 + rules.morale_ally_down_visible, "visible friend")
	assert_eq(far.morale, 4, "friend out of sight")
	assert_eq(foe.morale, 4 + rules.morale_enemy_down_visible, "enemy who saw it")
	assert_eq(far_foe.morale, 4, "enemy out of sight")


func test_leader_and_banner_down_hit_whole_side() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(30, 12)
	var log := PackedStringArray()
	var lead := _man("lead", 0, 1, rules)
	lead.is_leader = true
	lead.is_banner = true
	var far := _man("far", 0, 2, rules, [4, 4, 4, 8, 4])
	var foe := _man("foe", 1, 3, rules, [4, 4, 4, 8, 4])
	_put(grid, lead, Vector2i(1, 1))
	_put(grid, far, Vector2i(25, 1))
	_put(grid, foe, Vector2i(25, 3))
	var all: Array[Warrior] = [lead, far, foe]
	lead.take_wound_steps(4)
	Morale.on_down(rules, grid, lead, all, log)
	assert_eq(far.morale, 8 + rules.morale_leader_down + rules.morale_banner_lost)
	assert_eq(foe.morale, 8, "far enemies unaffected")
	assert_true(log.size() >= 2, "leader and banner losses are logged")


func test_morale_clamps_to_scale() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(8, 8)
	var log := PackedStringArray()
	var downed := _man("downed", 0, 1, rules)
	downed.is_leader = true
	var friend := _man("friend", 0, 2, rules, [4, 4, 4, 1, 4])
	_put(grid, downed, Vector2i(3, 3))
	_put(grid, friend, Vector2i(4, 3))
	var all: Array[Warrior] = [downed, friend]
	downed.take_wound_steps(4)
	Morale.on_down(rules, grid, downed, all, log)
	assert_eq(friend.morale, 0)
	var lead := _man("lead", 1, 3, rules)
	var man := _man("man", 1, 4, rules)
	man.morale = 10
	_put(grid, lead, Vector2i(1, 6))
	_put(grid, man, Vector2i(2, 6))
	var all2: Array[Warrior] = [lead, man]
	Morale.round_update(SimRng.new(1), rules, grid, all2, {1: lead}, true, log)
	assert_eq(man.morale, 10)


func test_leader_adjacent_and_flanked_modifiers() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(10, 10)
	var log := PackedStringArray()
	var lead := _man("lead", 0, 1, rules, [4, 4, 4, 8, 4])
	var by_lead := _man("by_lead", 0, 2, rules, [4, 4, 4, 6, 4])
	var flanked := _man("flanked", 0, 3, rules, [4, 4, 4, 6, 4])
	var foe := _man("foe", 1, 4, rules, [4, 4, 4, 8, 4])
	_put(grid, lead, Vector2i(2, 2))
	_put(grid, by_lead, Vector2i(3, 2))
	_put(grid, flanked, Vector2i(7, 7))  # facing north
	_put(grid, foe, Vector2i(8, 7), Vector2i(-1, 0))  # on flanked's right
	var all: Array[Warrior] = [lead, by_lead, flanked, foe]
	Morale.round_update(SimRng.new(3), rules, grid, all, {0: lead, 1: null}, true, log)
	assert_eq(by_lead.morale, 6 + rules.morale_leader_adjacent)
	assert_eq(lead.morale, 8, "the leader does not hearten himself")
	assert_eq(flanked.morale, 6 + rules.morale_flanked)
	assert_eq(foe.morale, 8, "foe is facing flanked, not flanked himself")


func test_is_flanked_by_arc() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(10, 10)
	var w := _man("w", 0, 1, rules)
	_put(grid, w, Vector2i(5, 5))  # facing north
	var e := _man("e", 1, 2, rules)
	_put(grid, e, Vector2i(5, 4))
	assert_true(not Morale.is_flanked(grid, w), "enemy in front")
	grid.place(e, Vector2i(4, 5))
	assert_true(not Morale.is_flanked(grid, w), "enemy on the shield side")
	grid.place(e, Vector2i(6, 5))
	assert_true(Morale.is_flanked(grid, w), "enemy on the right")
	grid.place(e, Vector2i(5, 6))
	assert_true(Morale.is_flanked(grid, w), "enemy behind")
	e.take_wound_steps(4)
	assert_true(not Morale.is_flanked(grid, w), "a downed enemy flanks nobody")
	grid.place(e, Vector2i(5, 8))
	e.wound = CombatTypes.Wound.UNHURT
	assert_true(not Morale.is_flanked(grid, w), "not adjacent")


func test_break_rate_and_steady_bonus() -> void:
	# Nerve 4 at morale 0 with target 9 breaks on 2d6 < 5 (6/36); a steady man
	# with +2 breaks only on 2d6 < 3 (1/36).
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var log := PackedStringArray()
	var rng := SimRng.new(77)
	var plain_breaks := 0
	var steady_breaks := 0
	var trials := 6000
	for i in trials:
		var grid := BattleGrid.new(8, 8)
		var plain := _man("plain", 0, 1, rules)
		var steady := _man("steady", 0, 2, rules)
		steady.personality = [CombatTypes.Personality.STEADY]
		plain.morale = 0
		steady.morale = 0
		_put(grid, plain, Vector2i(1, 1))
		_put(grid, steady, Vector2i(5, 5))
		var all: Array[Warrior] = [plain, steady]
		Morale.round_update(rng, rules, grid, all, {}, true, log)
		plain_breaks += 1 if plain.broken else 0
		steady_breaks += 1 if steady.broken else 0
	assert_between(float(plain_breaks) / trials, 0.13, 0.20, "plain break rate")
	assert_between(float(steady_breaks) / trials, 0.01, 0.05, "steady break rate")


func test_men_above_threshold_do_not_check() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	rules.morale_check_target = 100  # anyone who checks breaks
	var grid := BattleGrid.new(8, 8)
	var log := PackedStringArray()
	var w := _man("w", 0, 1, rules)
	_put(grid, w, Vector2i(3, 3))
	var all: Array[Warrior] = [w]
	var broke := Morale.round_update(SimRng.new(1), rules, grid, all, {}, true, log)
	assert_true(broke.is_empty())
	assert_true(not w.broken)


func test_panic_spreads_one_hop_only() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	rules.morale_check_target = 100  # anyone who checks breaks
	var grid := BattleGrid.new(10, 10)
	var log := PackedStringArray()
	var a := _man("a", 0, 1, rules)
	var b := _man("b", 0, 2, rules)
	var c := _man("c", 0, 3, rules)
	var d := _man("d", 0, 4, rules)
	a.morale = 0  # will break
	b.morale = 4  # panic drops him to 2: checks, breaks
	c.morale = 4  # next to b only: must be untouched
	d.morale = 10  # next to a, steady enough to stay above the threshold
	_put(grid, a, Vector2i(2, 5))
	_put(grid, b, Vector2i(3, 5))
	_put(grid, c, Vector2i(4, 5))
	_put(grid, d, Vector2i(1, 5))
	var all: Array[Warrior] = [a, b, c, d]
	var broke := Morale.round_update(SimRng.new(5), rules, grid, all, {}, true, log)
	assert_eq(broke.size(), 2)
	assert_true(a.broken and b.broken, "a breaks, b catches his panic")
	assert_eq(b.morale, 4 + rules.morale_panic_spread)
	assert_true(not c.broken, "panic does not chain past one hop")
	assert_eq(c.morale, 4, "c takes no panic from b")
	assert_true(not d.broken)
	assert_eq(d.morale, 10 + rules.morale_panic_spread)


func test_reckless_never_breaks_with_enemy_adjacent() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var log := PackedStringArray()
	var rng := SimRng.new(11)
	var broke_engaged := 0
	var broke_alone := 0
	for i in 2000:
		var grid := BattleGrid.new(10, 10)
		var r := _man("reckless", 0, 1, rules, [4, 4, 4, 1, 4])
		r.personality = [CombatTypes.Personality.RECKLESS]
		r.morale = 0
		var foe := _man("foe", 1, 2, rules, [4, 4, 4, 10, 4])
		_put(grid, r, Vector2i(4, 4))
		_put(grid, foe, Vector2i(4, 3), Vector2i(0, 1))
		var lone := _man("lone", 0, 3, rules, [4, 4, 4, 1, 4])
		lone.personality = [CombatTypes.Personality.RECKLESS]
		lone.morale = 0
		_put(grid, lone, Vector2i(8, 8))
		var all: Array[Warrior] = [r, foe, lone]
		Morale.round_update(rng, rules, grid, all, {}, true, log)
		broke_engaged += 1 if r.broken else 0
		broke_alone += 1 if lone.broken else 0
	assert_eq(broke_engaged, 0, "reckless with an enemy adjacent")
	assert_true(broke_alone > 500, "reckless with no enemy near still breaks (%d)" % broke_alone)


func test_lull_restores_breath() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(8, 8)
	var log := PackedStringArray()
	var w := _man("w", 0, 1, rules)
	var e := _man("e", 1, 2, rules)
	var down := _man("down", 0, 3, rules)
	_put(grid, w, Vector2i(2, 2))
	_put(grid, e, Vector2i(5, 5))
	_put(grid, down, Vector2i(7, 7))
	var full := w.max_breath(rules)
	w.breath = 1
	e.breath = full - 1
	down.breath = 0
	down.take_wound_steps(4)
	var all: Array[Warrior] = [w, e, down]
	Morale.round_update(SimRng.new(2), rules, grid, all, {}, true, log)
	assert_eq(w.breath, 1, "no recovery while men are attacking")
	Morale.round_update(SimRng.new(2), rules, grid, all, {}, false, log)
	assert_eq(w.breath, 1 + rules.breath_recover_lull)
	assert_eq(e.breath, full, "recovery caps at max breath")
	assert_eq(down.breath, 0, "downed men do not recover")


func test_round_update_rallies_near_leader() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(12, 12)
	var log := PackedStringArray()
	var lead := _man("lead", 0, 1, rules, [4, 4, 4, 8, 4])
	var near := _man("near", 0, 2, rules)
	var far := _man("far", 0, 3, rules)
	_put(grid, lead, Vector2i(2, 2))
	_put(grid, near, Vector2i(2 + rules.rally_radius, 2))
	_put(grid, far, Vector2i(2 + rules.rally_radius + 1, 6))
	near.broken = true
	far.broken = true
	near.morale = rules.morale_break_threshold + 1
	far.morale = rules.morale_break_threshold + 1
	var all: Array[Warrior] = [lead, near, far]
	Morale.round_update(SimRng.new(4), rules, grid, all, {0: lead}, true, log)
	assert_true(not near.broken, "within rally radius and above threshold")
	assert_true(far.broken, "too far from the leader")


func test_to_me_rally() -> void:
	var rules := CombatRules.new()
	rules.morale_start_bonus = 0  # these scenarios calibrate morale against raw Nerve
	var grid := BattleGrid.new(16, 12)
	var log := PackedStringArray()
	var lead := _man("lead", 0, 1, rules)
	var close := _man("close", 0, 2, rules)
	var earshot := _man("earshot", 0, 3, rules)
	var deaf := _man("deaf", 0, 4, rules)
	var foe := _man("foe", 1, 5, rules)
	_put(grid, lead, Vector2i(2, 2))
	_put(grid, close, Vector2i(3, 2))
	_put(grid, earshot, Vector2i(2 + rules.hear_certain_radius, 4))
	_put(grid, deaf, Vector2i(2 + rules.hear_certain_radius + 1, 2))
	_put(grid, foe, Vector2i(2, 3))
	close.broken = true
	close.morale = 2
	earshot.morale = 2
	var all: Array[Warrior] = [lead, close, earshot, deaf, foe]
	Morale.rally(rules, grid, lead, all, log)
	assert_eq(close.morale, 2 + rules.morale_rally_to_me)
	assert_true(not close.broken, "close man rallies")
	assert_eq(earshot.morale, 2 + rules.morale_rally_to_me)
	assert_eq(deaf.morale, 4, "out of earshot")
	assert_eq(foe.morale, 4, "the enemy is not heartened")
	# A horn on the side carries the shout further.
	var horn := _man("horn", 0, 6, rules)
	horn.is_horn = true
	_put(grid, horn, Vector2i(10, 10))
	all.append(horn)
	Morale.rally(rules, grid, lead, all, log)
	assert_eq(deaf.morale, 4 + rules.morale_rally_to_me, "heard with the horn")


func test_round_update_is_deterministic() -> void:
	assert_eq(_gate_run(42, true), _gate_run(42, true))
	assert_eq(_gate_run(42, false), _gate_run(42, false))
