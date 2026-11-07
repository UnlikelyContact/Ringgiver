extends TestCase


func test_place_and_occupancy() -> void:
	var g := BattleGrid.new(8, 6)
	var w := Warrior.make("a", 0, [3, 3, 3, 3, 3])
	assert_true(g.place(w, Vector2i(2, 2)))
	assert_eq(g.occupant(Vector2i(2, 2)), w)
	assert_true(not g.is_free(Vector2i(2, 2)))
	assert_true(g.place(w, Vector2i(3, 2)))
	assert_eq(g.occupant(Vector2i(2, 2)), null)
	assert_eq(w.pos, Vector2i(3, 2))
	assert_true(not g.place(w, Vector2i(99, 0)))


func test_water_blocks() -> void:
	var g := BattleGrid.new(4, 4)
	g.set_terrain(Vector2i(1, 1), CombatTypes.Terrain.WATER)
	assert_true(not g.is_free(Vector2i(1, 1)))


func test_rotate_and_distance() -> void:
	assert_eq(BattleGrid.rotate(Vector2i(0, -1), 2), Vector2i(1, 0))
	assert_eq(BattleGrid.rotate(Vector2i(0, -1), -2), Vector2i(-1, 0))
	assert_eq(BattleGrid.rotate(Vector2i(0, -1), 4), Vector2i(0, 1))
	assert_eq(BattleGrid.chebyshev(Vector2i(0, 0), Vector2i(3, -2)), 3)


func test_arcs_match_shield_rules() -> void:
	var d := Warrior.make("d", 0, [3, 3, 3, 3, 3])
	d.pos = Vector2i(5, 5)
	d.facing = Vector2i(0, -1)  # north
	assert_eq(BattleGrid.arc_of(d, Vector2i(5, 4)), CombatTypes.Arc.FRONT, "straight ahead")
	assert_eq(BattleGrid.arc_of(d, Vector2i(4, 4)), CombatTypes.Arc.FRONT, "front-left")
	assert_eq(BattleGrid.arc_of(d, Vector2i(6, 4)), CombatTypes.Arc.FRONT_RIGHT)
	assert_eq(BattleGrid.arc_of(d, Vector2i(4, 5)), CombatTypes.Arc.LEFT)
	assert_eq(BattleGrid.arc_of(d, Vector2i(6, 5)), CombatTypes.Arc.RIGHT)
	assert_eq(BattleGrid.arc_of(d, Vector2i(5, 6)), CombatTypes.Arc.REAR)
	assert_eq(BattleGrid.arc_of(d, Vector2i(6, 6)), CombatTypes.Arc.REAR)
	assert_eq(BattleGrid.arc_of(d, Vector2i(4, 6)), CombatTypes.Arc.REAR)
	assert_true(BattleGrid.shield_covers(CombatTypes.Arc.FRONT))
	assert_true(BattleGrid.shield_covers(CombatTypes.Arc.LEFT))
	assert_true(not BattleGrid.shield_covers(CombatTypes.Arc.RIGHT))
	assert_true(not BattleGrid.shield_covers(CombatTypes.Arc.FRONT_RIGHT))


func test_line_neighbors_and_behind() -> void:
	var g := BattleGrid.new(8, 8)
	var w := Warrior.make("w", 0, [3, 3, 3, 3, 3])
	var l := Warrior.make("l", 0, [3, 3, 3, 3, 3])
	var r := Warrior.make("r", 1, [3, 3, 3, 3, 3])
	g.place(w, Vector2i(4, 4))
	w.facing = Vector2i(0, -1)
	g.place(l, Vector2i(3, 4))
	g.place(r, Vector2i(5, 4))
	var ln := g.line_neighbors(w)
	assert_eq(ln.size(), 1, "enemy on the right is not a line neighbor")
	assert_eq(ln[0], l)
	assert_eq(g.behind(w), Vector2i(4, 5))
	assert_eq(g.adjacent_warriors(w.pos).size(), 2)
	assert_eq(g.adjacent_warriors(w.pos, 1).size(), 1)
