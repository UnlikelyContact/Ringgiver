extends TestCase

const K := CombatTypes.ActionKind

var _next_id := 1


func _man(p_name: String, side: int, pos: Vector2i, g: BattleGrid,
		tier := CombatTypes.Tier.BLOODED, stats := [4, 4, 4, 5, 4]) -> Warrior:
	var w := Warrior.make(p_name, side, stats, tier)
	w.id = _next_id
	_next_id += 1
	w.reset_for_battle(CombatRules.new())
	w.facing = Vector2i(0, -1) if side == 0 else Vector2i(0, 1)
	g.place(w, pos)
	return w


func _choose(w: Warrior, leader: Warrior, g: BattleGrid, all: Array[Warrior], seed_in := 1) -> Action:
	return Decision.choose(SimRng.new(seed_in), CombatRules.new(), g, w, leader, all)


func test_broken_man_flees_away_from_nearest_enemy() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(2, 2), g)
	var w := _man("w", 0, Vector2i(8, 6), g)
	var near := _man("near", 1, Vector2i(8, 5), g)  # north of him
	var far := _man("far", 1, Vector2i(12, 6), g)
	w.broken = true
	w.heard_order = CombatTypes.Shout.BREAK_THEM
	var all: Array[Warrior] = [leader, w, near, far]
	var a := _choose(w, leader, g, all)
	assert_eq(a.kind, K.FLEE)
	assert_eq(a.target_cell, Vector2i(8, 7), "directly away from the nearest enemy")
	# Block straight back: he takes a free cell beside that line.
	var blocker := _man("blocker", 0, Vector2i(8, 7), g)
	all.append(blocker)
	a = _choose(w, leader, g, all)
	assert_eq(a.kind, K.FLEE)
	assert_eq(BattleGrid.chebyshev(a.target_cell, near.pos), 2, "still moving away")


func test_broken_man_hemmed_in_idles() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g)
	var e := _man("e", 1, Vector2i(8, 5), g)
	var all: Array[Warrior] = [w, e]
	for c in [Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7)]:
		all.append(_man("f", 0, c, g))
	w.broken = true
	assert_eq(_choose(w, null, g, all).kind, K.IDLE)


func test_reckless_charges_regardless_of_order() -> void:
	for order in CombatTypes.Shout.values():
		var g := BattleGrid.new(16, 12)
		var leader := _man("jarl", 0, Vector2i(8, 9), g)
		var w := _man("w", 0, Vector2i(8, 6), g)
		w.personality = [CombatTypes.Personality.RECKLESS]
		w.heard_order = order
		var e := _man("e", 1, Vector2i(8, 3), g)
		var all: Array[Warrior] = [leader, w, e]
		var a := _choose(w, leader, g, all)
		assert_eq(a.kind, K.MOVE, "order %s" % CombatTypes.SHOUT_NAMES[order])
		assert_eq(a.target_cell, Vector2i(8, 5), "straight at the enemy")
		# Adjacent: he attacks, even under Fall back!
		g.place(e, Vector2i(9, 7))
		a = _choose(w, leader, g, all)
		assert_eq(a.kind, K.ATTACK)
		assert_eq(a.target, e)


func test_steady_man_does_not_charge_under_hold() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g)
	w.personality = [CombatTypes.Personality.STEADY]
	w.heard_order = CombatTypes.Shout.HOLD
	var e := _man("e", 1, Vector2i(8, 3), g)
	var all: Array[Warrior] = [w, e]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.BRACE)
	assert_eq(a.new_facing, Vector2i(0, -1), "braces toward the enemy")


func test_order_lag_braces_and_counts_down() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 2), g)
	var w := _man("w", 0, Vector2i(8, 8), g, CombatTypes.Tier.GREEN, [4, 4, 4, 6, 4])
	w.heard_order = CombatTypes.Shout.TO_ME
	w.order_lag = 1
	var all: Array[Warrior] = [leader, w]
	var a := _choose(w, leader, g, all)
	assert_eq(a.kind, K.BRACE)
	assert_eq(w.order_lag, 0)
	a = _choose(w, leader, g, all)
	assert_eq(a.kind, K.MOVE)
	assert_eq(a.target_cell, Vector2i(8, 7))


func test_green_panic_ignores_order_sometimes() -> void:
	var r := CombatRules.new()
	var braced := 0
	var trials := 2000
	for s in trials:
		var g := BattleGrid.new(16, 12)
		var leader := _man("jarl", 0, Vector2i(8, 2), g)
		var w := _man("w", 0, Vector2i(8, 8), g, CombatTypes.Tier.GREEN, [4, 4, 4, 2, 4])
		w.morale = r.morale_break_threshold  # shaken: the panic rule applies
		w.heard_order = CombatTypes.Shout.TO_ME
		var all: Array[Warrior] = [leader, w]
		var log := PackedStringArray()
		var a := Decision.choose(SimRng.new(s), r, g, w, leader, all, log)
		if a.kind == K.BRACE:
			braced += 1
			assert_eq(log.size(), 1)
	assert_between(float(braced) / trials, r.green_panic_ignore_chance - 0.04, r.green_panic_ignore_chance + 0.04)


func test_hold_attacks_wounded_front_enemy() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g)
	w.heard_order = CombatTypes.Shout.HOLD
	var a1 := _man("a1", 1, Vector2i(8, 5), g)
	var a2 := _man("a2", 1, Vector2i(7, 5), g)
	var behind := _man("behind", 1, Vector2i(8, 7), g)
	a2.wound = CombatTypes.Wound.WOUNDED
	behind.wound = CombatTypes.Wound.GRIEVOUS
	var all: Array[Warrior] = [w, a1, a2, behind]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.ATTACK)
	assert_eq(a.target, a2, "the wounded man in front, not the worse one behind")


func test_boastful_seeks_champion() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g)
	w.personality = [CombatTypes.Personality.BOASTFUL]
	w.heard_order = CombatTypes.Shout.BREAK_THEM
	var wounded := _man("wounded", 1, Vector2i(8, 5), g)
	wounded.wound = CombatTypes.Wound.GRIEVOUS
	var champ := _man("champ", 1, Vector2i(9, 7), g, CombatTypes.Tier.CHAMPION)
	var all: Array[Warrior] = [w, wounded, champ]
	var a := _choose(w, null, g, all)
	assert_eq(a.target, champ)
	w.personality = []
	assert_eq(_choose(w, null, g, all).target, wounded)


func test_champion_guards_beset_leader() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 6), g)
	var champ := _man("champ", 0, Vector2i(6, 7), g, CombatTypes.Tier.CHAMPION)
	champ.heard_order = CombatTypes.Shout.HOLD
	var e1 := _man("e1", 1, Vector2i(7, 5), g)
	var e2 := _man("e2", 1, Vector2i(9, 5), g)
	var all: Array[Warrior] = [leader, champ, e1, e2]
	var a := _choose(champ, leader, g, all)
	assert_eq(a.kind, K.MOVE)
	assert_eq(BattleGrid.chebyshev(a.target_cell, e1.pos), 1, "steps up beside a threat")
	g.place(champ, a.target_cell)
	a = _choose(champ, leader, g, all)
	assert_eq(a.kind, K.ATTACK)
	# One enemy only: he keeps to his order.
	g.remove(e2)
	e2.wound = CombatTypes.Wound.DOWN
	g.place(champ, Vector2i(6, 7))
	assert_eq(_choose(champ, leader, g, all).kind, K.BRACE)


func test_veteran_covers_gap() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g, CombatTypes.Tier.VETERAN)
	var left := _man("left", 0, Vector2i(7, 6), g, CombatTypes.Tier.VETERAN)
	var right := _man("right", 0, Vector2i(10, 6), g, CombatTypes.Tier.VETERAN)  # the gap at (9, 6) is between friends
	w.heard_order = CombatTypes.Shout.HOLD
	var e := _man("e", 1, Vector2i(10, 5), g)  # next to the empty cell on his right
	var all: Array[Warrior] = [w, left, right, e]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.MOVE)
	assert_eq(a.target_cell, Vector2i(9, 6))
	g.place(w, Vector2i(2, 2))
	var lesser := _man("lesser", 0, Vector2i(8, 6), g, CombatTypes.Tier.BLOODED)
	lesser.heard_order = CombatTypes.Shout.HOLD
	all.append(lesser)
	assert_eq(_choose(lesser, null, g, all).kind, K.BRACE, "a blooded man holds his place")


func test_bowman_shoots_instead_of_moving() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 2), g)
	var bow := _man("bow", 0, Vector2i(8, 8), g)
	bow.weapon = CombatTypes.Weapon.BOW
	bow.has_shield = false
	bow.heard_order = CombatTypes.Shout.TO_ME
	var e := _man("e", 1, Vector2i(12, 6), g)
	var all: Array[Warrior] = [leader, bow, e]
	var a := _choose(bow, leader, g, all)
	assert_eq(a.kind, K.SHOOT)
	assert_eq(a.target, e)
	bow.heard_order = CombatTypes.Shout.BREAK_THEM
	assert_eq(_choose(bow, leader, g, all).kind, K.MOVE, "ordered to charge, he charges")
	g.place(e, Vector2i(15, 11))
	bow.heard_order = CombatTypes.Shout.TO_ME
	assert_eq(_choose(bow, leader, g, all).kind, K.MOVE, "out of range: obeys")


func test_fall_back_wavers_for_green_low_morale() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g, CombatTypes.Tier.GREEN, [4, 4, 4, 6, 4])
	var e := _man("e", 1, Vector2i(9, 4), g)
	var all: Array[Warrior] = [w, e]
	w.heard_order = CombatTypes.Shout.FALL_BACK
	w.morale = 4
	var log := PackedStringArray()
	var a := Decision.choose(SimRng.new(1), CombatRules.new(), g, w, null, all, log)
	assert_eq(a.kind, K.FLEE)
	assert_eq(log.size(), 1)
	assert_true(not w.broken, "only for this round")
	w.morale = 6
	a = _choose(w, null, g, all)
	assert_eq(a.kind, K.MOVE)
	assert_eq(a.target_cell, Vector2i(8, 7), "a steady step back")


func test_choose_deterministic_and_pure() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 4), g)
	var all: Array[Warrior] = [leader]
	for i in 6:
		var m := _man("m%d" % i, 0, Vector2i(5 + i, 8), g, CombatTypes.Tier.GREEN, [4, 4, 4, 3, 4])
		m.heard_order = CombatTypes.Shout.SHIELD_WALL
		all.append(m)
	all.append(_man("e", 1, Vector2i(8, 1), g))
	for m in all:
		if m.side != 0 or m == leader:
			continue
		var before := [m.pos, m.facing, m.morale, m.heard_order, g.describe()]
		var a := Decision.choose(SimRng.new(5), CombatRules.new(), g, m, leader, all)
		var b := Decision.choose(SimRng.new(5), CombatRules.new(), g, m, leader, all)
		assert_eq([a.kind, a.target_cell, a.new_facing], [b.kind, b.target_cell, b.new_facing])
		assert_eq([m.pos, m.facing, m.morale, m.heard_order, g.describe()], before)


# --- Gate: green men form a shield wall far slower than veterans ------------

## Rounds until all eight men stand on line slots (cap if never).
func _rounds_to_form(tier: CombatTypes.Tier, seed_in: int, cap: int) -> int:
	var rules := CombatRules.new()
	var stats := [3, 3, 3, 3, 3] if tier == CombatTypes.Tier.GREEN else [5, 5, 5, 5, 5]
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 2), g, CombatTypes.Tier.VETERAN, [5, 5, 5, 5, 5])
	leader.is_leader = true
	var band: Array[Warrior] = []
	var all: Array[Warrior] = [leader]
	for i in 8:
		var m := _man("m%d" % i, 0, Vector2i(6 + i % 4, 7 + i / 4), g, tier, stats)
		band.append(m)
		all.append(m)
	var rng := SimRng.new(seed_in)
	var log := PackedStringArray()
	for round_i in range(1, cap + 1):
		Shouts.propagate(rng, rules, g, leader, CombatTypes.Shout.SHIELD_WALL, band, true, log)
		var actions: Array[Action] = []
		for m in band:
			actions.append(Decision.choose(rng, rules, g, m, leader, all, log))
		for i in band.size():
			var a := actions[i]
			var m := band[i]
			if a.kind == K.MOVE or a.kind == K.FLEE:
				g.place(m, a.target_cell)  # fails harmlessly if taken this beat
			if a.new_facing != Vector2i.ZERO:
				m.facing = a.new_facing
		var slots := Formation.line_slots(g, leader, band.size())
		var formed := true
		for m in band:
			if not slots.has(m.pos):
				formed = false
				break
		if formed:
			return round_i
	return cap


func test_gate_green_forms_shield_wall_slower_than_veteran() -> void:
	# Capped runs count as `cap`. A few veteran runs cap because a man who
	# mishears "fall back" in fog keeps stepping away until he is out of
	# earshot; that is the hearing rule working, so a small share is allowed.
	var seeds := 300
	var cap := 40
	var green: Array[int] = []
	var vet: Array[int] = []
	for s in seeds:
		green.append(_rounds_to_form(CombatTypes.Tier.GREEN, 1000 + s, cap))
		vet.append(_rounds_to_form(CombatTypes.Tier.VETERAN, 1000 + s, cap))
	var gs := _summary(green, cap)
	var vs := _summary(vet, cap)
	print("    gate: shield wall in fog from 5 cells over %d seeds: green mean %.2f median %d capped %d;"
			% [seeds, gs[0], gs[1], gs[2]] + " veteran mean %.2f median %d capped %d" % [vs[0], vs[1], vs[2]])
	assert_true(vs[2] <= seeds / 10, "veterans nearly always form (%d capped)" % vs[2])
	assert_true(gs[0] >= vs[0] * 1.2 and gs[0] >= vs[0] + 2.0,
			"mean: green %.2f vs veteran %.2f" % [gs[0], vs[0]])
	assert_true(gs[1] >= vs[1] + 2, "median: green %d vs veteran %d" % [gs[1], vs[1]])


## [mean, median, capped count]
func _summary(runs: Array[int], cap: int) -> Array:
	var sorted := runs.duplicate()
	sorted.sort()
	var total := 0
	var capped := 0
	for r in runs:
		total += r
		capped += 1 if r >= cap else 0
	return [float(total) / runs.size(), sorted[sorted.size() / 2], capped]


func test_a_veteran_guards_a_beset_leader() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 6), g, CombatTypes.Tier.VETERAN)
	leader.is_leader = true
	var vet := _man("vet", 0, Vector2i(7, 7), g, CombatTypes.Tier.VETERAN)
	vet.heard_order = CombatTypes.Shout.HOLD
	var e1 := _man("e1", 1, Vector2i(8, 5), g)
	var e2 := _man("e2", 1, Vector2i(9, 5), g)
	var all: Array[Warrior] = [leader, vet, e1, e2]
	var a := _choose(vet, leader, g, all)
	assert_true(a.kind == K.MOVE or a.kind == K.ATTACK, "the veteran moves to or strikes a threat: %s" % a.describe())
	var green := _man("green", 0, Vector2i(9, 7), g, CombatTypes.Tier.GREEN)
	green.heard_order = CombatTypes.Shout.HOLD
	all.append(green)
	var b := _choose(green, leader, g, all)
	assert_true(b.kind == K.BRACE or b.kind == K.ATTACK, "a green man holds his place instead: %s" % b.describe())
