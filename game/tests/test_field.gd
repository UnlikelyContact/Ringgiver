extends TestCase
## Fields and terrain: the templates, the ground they draw, what that ground
## does to men standing on it, the band size, and the way round.

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)


func _man(name: String, side: int, id: int, rules: CombatRules) -> Warrior:
	var w := Warrior.make(name, side, [4, 4, 4, 4, 4])
	w.id = id
	w.reset_for_battle(rules)
	return w


func test_templates_stay_inside_the_field_and_off_the_deployment_rows() -> void:
	var rules := CombatRules.new()
	for key in Field.KEYS:
		for band in [4, 8, 12]:
			for s in 12:
				var f := Scenario.build("equal_green", 40 + s, rules, true, band, key)
				var field: Field = f.field
				var grid: BattleGrid = (f.battle as Battle).grid
				assert_eq(field.name, key, "the template asked for")
				assert_eq(f.field_name, key)
				var rows := Field.deployment_rows(field.their_row, field.our_row)
				for c in field.features:
					assert_true(grid.in_bounds(c), "%s seed %d: %s inside the field" % [key, 40 + s, c])
					var t := grid.terrain_at(c)
					if t != CombatTypes.Terrain.SLOPE:
						assert_true(not rows.has(c.y), "%s band %d seed %d: %s (%s) is off the deployment rows" % [
							key, band, 40 + s, BattleGrid.to_offset(c), CombatTypes.TERRAIN_NAMES[t]])
				# Everyone deployed on ground he can stand on.
				for w in (f.battle as Battle).warriors:
					assert_true(grid.is_passable(w.pos), "%s seed %d: %s stands on open ground" % [key, 40 + s, w.display_name])


func test_every_varied_field_keeps_a_way_between_the_lines() -> void:
	var rules := CombatRules.new()
	var seen := {}
	for band in [4, 12]:
		for s in 120:
			var f := Scenario.build("equal_green", s, rules, true, band)
			var field: Field = f.field
			var b: Battle = f.battle
			seen[field.name] = true
			assert_true(Field.open_ways(b.grid, field.their_row, field.our_row), "seed %d band %d (%s): open" % [s, band, field.name])
			var path := LeaderAI.route(b.grid, b.leader_of(0).pos, b.active(1))
			assert_true(not path.is_empty(), "seed %d band %d (%s): a walk from our leader to them" % [s, band, field.name])
	for key in Field.KEYS:
		assert_true(seen.has(key), "%s turns up" % key)


func test_open_ways_needs_two_wide_ways() -> void:
	var g := BattleGrid.new(12, 10)
	assert_true(Field.open_ways(g, 2, 7), "an empty field is open")
	for col in 12:
		g.set_terrain(BattleGrid.from_offset(col, 5), CombatTypes.Terrain.WATER)
	assert_true(not Field.open_ways(g, 2, 7), "a stream with no crossing closes it")
	g.set_terrain(BattleGrid.from_offset(3, 5), CombatTypes.Terrain.FORD)
	assert_true(not Field.open_ways(g, 2, 7), "a ford one hex wide is not enough")
	g.set_terrain(BattleGrid.from_offset(4, 5), CombatTypes.Terrain.FORD)
	assert_true(not Field.open_ways(g, 2, 7), "one way two wide is not enough")
	g.set_terrain(BattleGrid.from_offset(8, 5), CombatTypes.Terrain.BRIDGE)
	g.set_terrain(BattleGrid.from_offset(9, 5), CombatTypes.Terrain.FORD)
	assert_true(Field.open_ways(g, 2, 7), "two ways two wide")


func test_impassable_ground_blocks_and_crossings_do_not() -> void:
	var g := BattleGrid.new(8, 6)
	var c := Vector2i(3, 2)
	for t in [CombatTypes.Terrain.WATER, CombatTypes.Terrain.TREE, CombatTypes.Terrain.ROCK,
			CombatTypes.Terrain.FENCE, CombatTypes.Terrain.BUILDING]:
		g.set_terrain(c, t)
		assert_true(not g.is_free(c) and not g.is_passable(c), "%s blocks" % CombatTypes.TERRAIN_NAMES[t])
		var w := Warrior.make("a", 0, [3, 3, 3, 3, 3])
		assert_true(not g.place(w, c), "nobody stands in %s" % CombatTypes.TERRAIN_NAMES[t])
	for t in [CombatTypes.Terrain.FLAT, CombatTypes.Terrain.MUD, CombatTypes.Terrain.SLOPE,
			CombatTypes.Terrain.FORD, CombatTypes.Terrain.BRIDGE, CombatTypes.Terrain.DOOR]:
		g.set_terrain(c, t)
		assert_true(g.is_free(c) and g.is_passable(c), "%s can be walked" % CombatTypes.TERRAIN_NAMES[t])


func test_a_building_turns_the_wall_aside_and_a_door_lets_it_through() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(12, 10)
	var leader := _man("l", 0, 1, rules)
	leader.is_leader = true
	g.place(leader, BattleGrid.from_offset(5, 5))
	leader.facing = NORTH
	leader.line_facing = NORTH
	var right := BattleGrid.along(leader.pos, leader.wall_axis(), NORTH, true)
	g.set_terrain(right, CombatTypes.Terrain.BUILDING)
	var slots := Formation.line_slots(g, leader, 4)
	assert_true(not slots.has(right), "no slot in a wall of the hall")
	g.set_terrain(right, CombatTypes.Terrain.DOOR)
	slots = Formation.line_slots(g, leader, 4)
	assert_true(slots.has(right), "a door is a place to stand")
	# A man walks into the door, not into the wall.
	var b := Battle.new(rules, 3, g)
	var m := _man("m", 0, 2, rules)
	g.place(m, BattleGrid.from_offset(5, 7))
	b.add_band([leader, m] as Array[Warrior])
	var wall := m.pos + NORTH
	g.set_terrain(wall, CombatTypes.Terrain.BUILDING)
	b._resolve_movement(SimRng.new(1), {m: Action.move_to(wall, NORTH)})
	assert_eq(m.pos, BattleGrid.from_offset(5, 7), "the wall stops him")
	g.set_terrain(wall, CombatTypes.Terrain.DOOR)
	b._resolve_movement(SimRng.new(1), {m: Action.move_to(wall, NORTH)})
	assert_eq(m.pos, wall, "the door lets him in")


func test_the_ford_costs_breath_and_breaks_the_lock_and_the_bridge_does_not() -> void:
	var rules := CombatRules.new()
	for t in [CombatTypes.Terrain.FORD, CombatTypes.Terrain.BRIDGE, CombatTypes.Terrain.FLAT]:
		var g := BattleGrid.new(12, 10)
		var b := Battle.new(rules, 3, g)
		var a := _man("a", 0, 1, rules)
		var n := _man("n", 0, 2, rules)
		g.place(a, BattleGrid.from_offset(5, 6))
		g.place(n, BattleGrid.from_offset(6, 6))
		a.facing = NORTH
		n.facing = NORTH
		b.add_band([a, n] as Array[Warrior])
		assert_true(MeleeExchange.is_locked(g, a), "side by side on flat ground: locked")
		# n steps forward into the ground under test; a steps beside him.
		var to := BattleGrid.from_offset(6, 5)
		var to_a := BattleGrid.from_offset(5, 5)
		g.set_terrain(to, t)
		var before := n.breath
		var before_a := a.breath
		b._resolve_movement(SimRng.new(1), {n: Action.move_to(to, NORTH), a: Action.move_to(to_a, NORTH)})
		assert_eq(n.pos, to)
		var spent := before - n.breath
		var spent_flat := before_a - a.breath
		var name: String = CombatTypes.TERRAIN_NAMES[t]
		if t == CombatTypes.Terrain.FORD:
			assert_eq(spent, spent_flat + rules.breath_cost_move * rules.terrain_breath_extra, "the ford costs breath like mud")
			assert_true(not MeleeExchange.is_locked(g, a), "a man beside the ford locks with nobody in it")
			assert_true(not MeleeExchange.is_locked(g, n), "a man in the ford locks with nobody")
			assert_true(g.line_neighbors(n).is_empty() and g.line_neighbors(a).is_empty())
			assert_eq(g.chain(a).size(), 2, "but he is still in the wall: it crosses together")
		else:
			assert_eq(spent, spent_flat, "%s costs no more than flat ground" % name)
			assert_true(MeleeExchange.is_locked(g, a) and MeleeExchange.is_locked(g, n), "on %s the shields lock" % name)


func test_the_slope_adds_to_the_push() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(12, 10)
	var group: Array[Warrior] = []
	for i in 4:
		var w := _man("w%d" % i, 0, i + 1, rules)
		g.place(w, BattleGrid.from_offset(3 + i, 4))
		w.facing = SOUTH
		group.append(w)
	var flat := Push.group_strength(rules, g, group)
	for w in group:
		g.set_terrain(w.pos, CombatTypes.Terrain.SLOPE)
	var high := Push.group_strength(rules, g, group)
	assert_true(absf(high - flat - rules.slope_push_bonus) < 0.001, "the whole group on the slope: the full bonus (%.2f vs %.2f)" % [high, flat])
	g.set_terrain(group[0].pos, CombatTypes.Terrain.FLAT)
	g.set_terrain(group[1].pos, CombatTypes.Terrain.FLAT)
	var half := Push.group_strength(rules, g, group)
	assert_true(absf(half - flat - rules.slope_push_bonus / 2.0) < 0.001, "half on it: half the bonus")


func test_the_hall_is_its_doors_and_floor_inside_its_walls() -> void:
	var rules := CombatRules.new()
	for s in 30:
		var g := BattleGrid.new(22, 16)
		var obj := Objective.new(Objective.Kind.THE_HALL, 1, s, rules)
		obj.place(g, 10, 1, 11)
		var walls := 0
		var doors := 0
		for c in obj.features:
			match g.terrain_at(c):
				CombatTypes.Terrain.BUILDING:
					walls += 1
					assert_true(not obj.has_cell(c), "a wall is not the objective")
				CombatTypes.Terrain.DOOR:
					doors += 1
					assert_true(obj.has_cell(c), "a door is the objective")
		assert_true(walls >= 4 and walls <= 6, "seed %d: four to six walls (%d)" % [s, walls])
		assert_true(doors >= 1 and doors <= 2, "seed %d: one or two doors (%d)" % [s, doors])
		for c in obj.cells:
			var t := g.terrain_at(c)
			assert_true(t == CombatTypes.Terrain.DOOR or t == CombatTypes.Terrain.FLAT, "seed %d: the hall's cells are doors and floor" % s)
			if t == CombatTypes.Terrain.FLAT:
				# The floor is shut in: walls, doors and floor all round.
				for n in g.neighbors(c):
					assert_true(obj.features.has(n), "seed %d: the floor at %s is inside the hall" % [s, c])
				assert_true(BattleGrid.to_offset(c).y >= 13, "seed %d: behind the defender's ranks" % s)
			else:
				assert_eq(BattleGrid.to_offset(c).y, 13, "seed %d: the doors face the fight" % s)


func test_the_ford_is_the_crossing_of_a_stream() -> void:
	var rules := CombatRules.new()
	for s in 30:
		var g := BattleGrid.new(22, 16)
		var obj := Objective.new(Objective.Kind.HOLD_GROUND, 0, s, rules)
		obj.place(g, 5, -1, 11)
		assert_true(obj.cells.size() >= 4 and obj.cells.size() <= 5, "seed %d: four or five crossing hexes" % s)
		for col in 22:
			var c := BattleGrid.from_offset(col, 6)  # directly before the defender's line on row 5
			var t := g.terrain_at(c)
			if obj.has_cell(c):
				assert_true(t == CombatTypes.Terrain.FORD or t == CombatTypes.Terrain.BRIDGE, "seed %d: a crossing" % s)
			else:
				assert_eq(t, CombatTypes.Terrain.WATER, "seed %d col %d: the rest of the row is stream" % [s, col])
		assert_true(Field.open_ways(g, 5, 10), "seed %d: the crossings keep the field open" % s)


func test_band_size_arms_and_sizes_the_field() -> void:
	var rules := CombatRules.new()
	assert_eq(Scenario.band_split(4, rules), [3, 1, 0] as Array[int])
	assert_eq(Scenario.band_split(6, rules), [4, 1, 1] as Array[int])
	assert_eq(Scenario.band_split(8, rules), [5, 2, 1] as Array[int])
	assert_eq(Scenario.band_split(12, rules), [8, 2, 2] as Array[int])
	assert_eq(Scenario.field_size(4, rules), Vector2i(14, 12))
	assert_eq(Scenario.field_size(6, rules), Vector2i(14, 12))
	assert_eq(Scenario.field_size(12, rules), Vector2i(rules.field_width, rules.field_height))
	for band in [4, 6, 8, 12]:
		var f := Scenario.build("equal_green", 9, rules, true, band)
		var b: Battle = f.battle
		assert_eq((f.ours as Array).size(), band, "band %d: so many men" % band)
		assert_eq(Vector2i(b.grid.width, b.grid.height), f.size)
		assert_eq(f.band, band)
		var theirs: Array = f.theirs
		assert_true(theirs.size() >= band * 0.6 and theirs.size() <= band * 1.6, "band %d: the enemy is about as strong (%d)" % [band, theirs.size()])
	var obj := Objective.new(Objective.Kind.REACH_THE_SHIPS, 0, 1, rules)
	obj.size_for_band(12, rules)
	assert_eq(obj.ships_men, 4, "a third of twelve")
	obj.size_for_band(8, rules)
	assert_eq(obj.ships_men, 3, "a third of eight, rounded up")
	obj.size_for_band(4, rules)
	assert_eq(obj.ships_men, 2, "never fewer than two")


func test_the_symmetric_field_is_flat_and_featureless() -> void:
	var rules := CombatRules.new()
	for s in 20:
		var f := Scenario.build("equal_green", 200 + s, rules, false)
		assert_true(f.field == null, "no template")
		assert_eq(f.field_name, "flat")
		var g: BattleGrid = (f.battle as Battle).grid
		assert_eq(Vector2i(g.width, g.height), Vector2i(22, 16))
		for row in g.height:
			for col in g.width:
				var t := g.terrain_at(BattleGrid.from_offset(col, row))
				assert_true(t == CombatTypes.Terrain.FLAT or t == CombatTypes.Terrain.MUD, "seed %d: only flat ground and a little mud" % (200 + s))
		assert_eq((f.ours as Array).size(), 8, "eight shields")
		assert_eq((f.theirs as Array).size(), 8, "against eight")


func test_the_enemy_leader_aims_for_the_crossing() -> void:
	var rules := CombatRules.new()
	var g := BattleGrid.new(16, 12)
	var b := Battle.new(rules, 5, g)
	var theirs: Array[Warrior] = []
	var ours: Array[Warrior] = []
	for i in 3:
		var w := _man("t%d" % i, 1, 101 + i, rules)
		theirs.append(w)
		var o := _man("o%d" % i, 0, 1 + i, rules)
		ours.append(o)
	theirs[0].is_leader = true
	ours[0].is_leader = true
	BandFactory.deploy_line(g, theirs, BattleGrid.from_offset(6, 2), SOUTH, rules)
	BandFactory.deploy_line(g, ours, BattleGrid.from_offset(6, 9), NORTH, rules)
	b.add_band(ours)
	b.add_band(theirs)
	var ai := LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE)
	assert_eq(ai.route_target(b, 1, theirs[0]), Vector2.INF, "open ground: no way round needed")
	# A stream across row 4, crossed only far out on the right.
	for col in 16:
		g.set_terrain(BattleGrid.from_offset(col, 4), CombatTypes.Terrain.WATER)
	var ford := BattleGrid.from_offset(13, 4)
	g.set_terrain(ford, CombatTypes.Terrain.FORD)
	g.set_terrain(BattleGrid.from_offset(14, 4), CombatTypes.Terrain.FORD)
	var aim := ai.route_target(b, 1, theirs[0])
	assert_true(aim != Vector2.INF, "the stream is in the way")
	var on_ford := false
	for c in [ford, BattleGrid.from_offset(14, 4)]:
		on_ford = on_ford or BattleGrid.to_cart(Vector2(c)).distance_to(aim) < 0.01
	assert_true(on_ford, "he aims at a ford hex (%s)" % aim)
	# And he wheels toward it rather than marching into the water.
	var before := absi(LeaderAI.steps_toward(theirs[0], aim))
	assert_true(before >= 1, "the ford is off his front")
	ai._wheel_if_needed(b, 1, theirs[0], false)
	assert_true(absi(LeaderAI.steps_toward(theirs[0], aim)) < before, "he wheels toward the crossing")
