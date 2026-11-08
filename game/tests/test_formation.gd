extends TestCase


func _man(p_name: String, side: int, pos: Vector2i, g: BattleGrid, id := 0) -> Warrior:
	var w := Warrior.make(p_name, side, [4, 4, 4, 4, 4])
	w.id = id
	w.reset_for_battle(CombatRules.new())
	g.place(w, pos)
	return w


func test_line_slots_alternate_right_left() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 5), g)
	leader.facing = Vector2i(0, -1)
	var slots := Formation.line_slots(g, leader, 6)
	var expected: Array[Vector2i] = [Vector2i(9, 5), Vector2i(7, 5), Vector2i(10, 5),
			Vector2i(6, 5), Vector2i(11, 5), Vector2i(5, 5)]
	assert_eq(slots, expected)


func test_line_slots_follow_facing() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 5), g)
	leader.facing = Vector2i(1, 0)  # east: right hand is south-west, left north-east
	var slots := Formation.line_slots(g, leader, 2)
	var expected: Array[Vector2i] = [Vector2i(7, 6), Vector2i(9, 4)]
	assert_eq(slots, expected)


func test_line_slots_skip_blocked_keep_friends() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 5), g)
	_man("foe", 1, Vector2i(9, 5), g)
	_man("friend", 0, Vector2i(7, 5), g)
	g.set_terrain(Vector2i(6, 5), CombatTypes.Terrain.WATER)
	var slots := Formation.line_slots(g, leader, 4)
	var expected: Array[Vector2i] = [Vector2i(7, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(5, 5)]
	assert_eq(slots, expected, "enemy and water skipped, friend's cell counts")


func test_line_slots_stop_at_edges() -> void:
	var g := BattleGrid.new(5, 5)
	var leader := _man("jarl", 0, Vector2i(1, 2), g)
	var slots := Formation.line_slots(g, leader, 10)
	assert_eq(slots.size(), 4, "only four cells on that row besides the leader")
	assert_true(not slots.has(leader.pos))


func test_wedge_slots_shape() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 2), g)
	leader.facing = Vector2i(0, -1)
	var slots := Formation.wedge_slots(g, leader, 9)
	# Facing north-west the tip's back cells are south-west (left) and
	# south-east (right); each rank runs east along the line between them.
	# Rank 1 right then left; rank 2 middle (directly behind the tip), right,
	# left; rank 3 the two middle cells right first, then the edges.
	var expected: Array[Vector2i] = [
		Vector2i(8, 3), Vector2i(7, 3),
		Vector2i(7, 4), Vector2i(8, 4), Vector2i(6, 4),
		Vector2i(7, 5), Vector2i(6, 5), Vector2i(8, 5), Vector2i(5, 5),
	]
	assert_eq(slots, expected)


func test_wedge_slots_diagonal_facing_is_packed() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 5), g)
	leader.facing = Vector2i(1, -1)  # north-east: the wedge turns with him
	var slots := Formation.wedge_slots(g, leader, 5)
	assert_eq(slots.size(), 5)
	# Rank 1: south-west (right) and west (left) of the tip. Rank 2: the
	# packed rank behind it, its middle cell directly behind the leader.
	var expected: Array[Vector2i] = [Vector2i(7, 6), Vector2i(7, 5),
			Vector2i(6, 6), Vector2i(6, 7), Vector2i(6, 5)]
	assert_eq(slots, expected)
	for c in slots:
		assert_eq(BattleGrid.arc_of(leader, c), CombatTypes.Arc.REAR, "behind the tip")


func test_assign_nearest_first_and_keeps_men_in_place() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 5), g)
	var on_slot := _man("on", 0, Vector2i(7, 5), g, 1)
	var a := _man("a", 0, Vector2i(9, 7), g, 2)
	var b := _man("b", 0, Vector2i(6, 8), g, 3)
	var slots := Formation.line_slots(g, leader, 3)  # (9,5) (7,5) (10,5)
	var men: Array[Warrior] = [b, a, on_slot]
	var plan := Formation.assign(slots, men)
	assert_eq(plan[on_slot], Vector2i(7, 5), "a man on a slot keeps it")
	assert_eq(plan[a], Vector2i(9, 5), "nearer man takes the nearer slot")
	assert_eq(plan[b], Vector2i(10, 5))
	assert_eq(plan.size(), 3)


func test_assign_more_men_than_slots() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 5), g)
	var near := _man("near", 0, Vector2i(9, 6), g, 1)
	var far := _man("far", 0, Vector2i(12, 10), g, 2)
	var slots := Formation.line_slots(g, leader, 1)
	var men: Array[Warrior] = [far, near]
	var plan := Formation.assign(slots, men)
	assert_eq(plan.size(), 1)
	assert_eq(plan.get(near), Vector2i(9, 5))
	assert_true(not plan.has(far))
