class_name Field
extends RefCounted
## The ground of a varied field: a named template whose features (trees,
## rocks, fences, a stream, a hall, a hillside) are drawn from the seed
## inside the field (concept.md, "Terrain and conditions"; sim-architecture
## .md, "Fields and terrain"). Scenario.build makes one when `vary` is set,
## after the objective has drawn its own ground (the ford's stream, the
## hall's walls) and before anyone deploys.
##
##   meadow     a few trees and rocks, sometimes a fence line
##   river      a stream across the middle, crossed by fords and maybe a bridge
##   farmstead  a hall with a fenced yard and a tree or two
##   wood_edge  a band of trees along one flank
##   hillside   SLOPE (high ground) under one side's lines
##
## The objective picks the template when there is one: the hall is fought on
## a farmstead, the ford on a river, the ships on a meadow or a wood edge;
## an open fight draws from CombatRules.field_weights. Features never stand
## on the deployment rows (the three rank rows of each side; SLOPE, being
## ground and not a thing in the way, is the one exception) nor on the
## objective's ground, and never close the field: every row between the
## lines keeps two ways two hexes wide (or one four wide) and a walk through
## such hexes joins the lines (`open_ways`). A draw that fails is undone and
## made again from the next fork of the seed.

enum Kind { MEADOW, RIVER, FARMSTEAD, WOOD_EDGE, HILLSIDE }

const KEYS := ["meadow", "river", "farmstead", "wood_edge", "hillside"]
const TITLES := ["Meadow", "River", "Farmstead", "Wood edge", "Hillside"]

var kind: Kind = Kind.MEADOW
var name := "meadow"
var their_row := 0
var our_row := 0
## Hillside: the side whose lines stand on the slope (-1 elsewhere).
var high_side := -1
## Every cell the template drew, and what was there before (to undo a draw).
var features: Array[Vector2i] = []
var _was := {}
var _reserved := {}
var _rows := {}  # deployment rows -> true


## The template named `key` ("meadow", "river", ...), or -1.
static func kind_named(key: String) -> int:
	return KEYS.find(key)


## The template for a field: the objective's, or a weighted draw.
static func choose(rng: SimRng, rules: CombatRules, objective: Objective) -> Kind:
	if objective != null:
		match objective.kind:
			Objective.Kind.THE_HALL, Objective.Kind.PLUNDER:
				return Kind.FARMSTEAD
			Objective.Kind.HOLD_GROUND:
				return Kind.RIVER
			_:
				return Kind.WOOD_EDGE if rng.randf() < rules.field_ships_wood else Kind.MEADOW
	var total := 0
	for wt in rules.field_weights:
		total += int(wt)
	var roll := rng.randi_range(0, maxi(0, total - 1))
	for i in rules.field_weights.size():
		roll -= int(rules.field_weights[i])
		if roll < 0:
			return i as Kind
	return Kind.MEADOW


## The six rows the lines deploy on: each side's front and its two ranks
## behind (theirs above, rear toward row 0; ours below).
static func deployment_rows(p_their_row: int, p_our_row: int) -> Array[int]:
	return [p_their_row - 2, p_their_row - 1, p_their_row, p_our_row, p_our_row + 1, p_our_row + 2]


## Draws a template on `grid`. `forced` (a Kind, or -1) overrides the
## choice; tools use it to show a template.
static func make(grid: BattleGrid, rules: CombatRules, seed_in: int, p_their_row: int, p_our_row: int,
		objective: Objective, forced := -1) -> Field:
	var rng := SimRng.new(seed_in).fork("field-template")
	var f := Field.new()
	f.kind = (forced if forced >= 0 else choose(rng.fork("choose"), rules, objective)) as Kind
	f.name = KEYS[f.kind]
	f.their_row = p_their_row
	f.our_row = p_our_row
	for row in deployment_rows(p_their_row, p_our_row):
		f._rows[row] = true
	if objective != null:
		for c in objective.features:
			f._reserved[c] = true
	for t in rules.field_tries:
		f._draw(grid, rng.fork("try:%d" % t), objective)
		if open_ways(grid, p_their_row, p_our_row):
			return f
		f._undo(grid)
	f.high_side = -1
	return f


func title() -> String:
	return TITLES[kind]


# --- Is the field open? ------------------------------------------------------

## True when every row between the lines has two runs of two or more
## passable hexes (or one of four or more), and a walk through "wide" hexes
## (passable, with a passable hex beside it in its row) joins our front row
## to theirs. Men, mud and slopes do not matter; only what nobody can stand on.
static func open_ways(grid: BattleGrid, p_their_row: int, p_our_row: int) -> bool:
	for row in range(p_their_row + 1, p_our_row):
		var runs := _runs(grid, row)
		var wide := 0
		var long := false
		for n in runs:
			if n >= 2:
				wide += 1
			if n >= 4:
				long = true
		if wide < 2 and not long:
			return false
	var seen := {}
	var queue: Array[Vector2i] = []
	for col in grid.width:
		var c := BattleGrid.from_offset(col, p_our_row)
		if _wide(grid, c):
			seen[c] = true
			queue.append(c)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c.y == p_their_row:
			return true
		for n in grid.neighbors(c):
			if not seen.has(n) and _wide(grid, n):
				seen[n] = true
				queue.append(n)
	return false


static func _runs(grid: BattleGrid, row: int) -> Array[int]:
	var out: Array[int] = []
	var n := 0
	for col in grid.width:
		if grid.is_passable(BattleGrid.from_offset(col, row)):
			n += 1
		else:
			if n > 0:
				out.append(n)
			n = 0
	if n > 0:
		out.append(n)
	return out


static func _wide(grid: BattleGrid, c: Vector2i) -> bool:
	if not grid.is_passable(c):
		return false
	var o := BattleGrid.to_offset(c)
	return grid.is_passable(BattleGrid.from_offset(o.x - 1, o.y)) or grid.is_passable(BattleGrid.from_offset(o.x + 1, o.y))


# --- Drawing -----------------------------------------------------------------

func _draw(grid: BattleGrid, r: SimRng, objective: Objective) -> void:
	match kind:
		Kind.MEADOW:
			_scatter(grid, r, r.randi_range(3, 6), 0.65)
			if r.randf() < 0.5:
				_fence_line(grid, r)
			_round_the_ships(grid, r, objective)
		Kind.RIVER:
			if objective == null or objective.kind != Objective.Kind.HOLD_GROUND:
				var row := their_row + r.randi_range(2, 3)
				var crossing := Objective.stream_crossings(r, grid.width, grid.width / 2)
				for col in grid.width:
					_put(grid, BattleGrid.from_offset(col, row), crossing.get(col, CombatTypes.Terrain.WATER))
			_banks(grid, r)
		Kind.FARMSTEAD:
			var hall: Array[Vector2i] = []
			if objective != null and (objective.kind == Objective.Kind.THE_HALL or objective.kind == Objective.Kind.PLUNDER):
				hall = objective.features
			else:
				# A steading out on a flank between the lines.
				var left := r.randf() < 0.5
				var col := r.randi_range(2, 3) if left else grid.width - 1 - r.randi_range(2, 3)
				var row := their_row + r.randi_range(2, 3)
				var shape := Objective.hall_shape(grid, r, row, 1 if row > (their_row + our_row) / 2 else -1, col)
				for c in shape.walls:
					_put(grid, c, CombatTypes.Terrain.BUILDING)
				for c in shape.doors:
					_put(grid, c, CombatTypes.Terrain.DOOR)
				for c in shape.floor:
					_put(grid, c, CombatTypes.Terrain.FLAT)
				hall.append_array(shape.walls)
				hall.append_array(shape.doors)
				hall.append_array(shape.floor)
			_yard(grid, r, hall)
			_scatter(grid, r, r.randi_range(1, 2), 1.0)
		Kind.WOOD_EDGE:
			var left := r.randf() < 0.5
			var depth := 2 if grid.width < 18 else 3
			for row in grid.height:
				for k in depth:
					var col := k if left else grid.width - 1 - k
					var chance := 0.85 if k == 0 else (0.6 if k == 1 else 0.3)
					if r.randf() < chance:
						_put(grid, BattleGrid.from_offset(col, row), CombatTypes.Terrain.TREE)
			_scatter(grid, r, r.randi_range(0, 2), 0.8)
			_round_the_ships(grid, r, objective)
		Kind.HILLSIDE:
			high_side = (objective.defender() if objective != null else (0 if r.randf() < 0.5 else 1))
			var half := grid.width / 3 + r.randi_range(0, 2)
			var centre := grid.width / 2 + r.randi_range(-1, 1)
			var rows: Array[int] = []
			if high_side == 1:
				for row in range(0, their_row + 2):
					rows.append(row)
			else:
				for row in range(our_row - 1, grid.height):
					rows.append(row)
			for row in rows:
				for col in range(centre - half, centre + half + 1):
					_put(grid, BattleGrid.from_offset(col, row), CombatTypes.Terrain.SLOPE, true)
			_scatter(grid, r, r.randi_range(1, 3), 0.3)


## Sets one feature, unless the cell is off the field, the objective's, a
## deployment row's (except for `ground`: SLOPE), or drawn already.
func _put(grid: BattleGrid, c: Vector2i, t: CombatTypes.Terrain, ground := false) -> bool:
	if not grid.in_bounds(c) or _reserved.has(c) or _was.has(c):
		return false
	if not ground and _rows.has(c.y):
		return false
	_was[c] = grid.terrain_at(c)
	features.append(c)
	grid.set_terrain(c, t)
	return true


func _undo(grid: BattleGrid) -> void:
	for c in features:
		grid.set_terrain(c, _was[c])
	features.clear()
	_was.clear()


## `n` trees (else rocks, by `tree_share`) on free rows, kept off the middle
## third of the field between the lines so they texture the flanks more than
## they wall the fight.
func _scatter(grid: BattleGrid, r: SimRng, n: int, tree_share: float) -> void:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 12:
		tries += 1
		var col := r.randi_range(0, grid.width - 1)
		var row := r.randi_range(0, grid.height - 1)
		var between := row > their_row and row < our_row
		if between and absi(col - grid.width / 2) < grid.width / 6:
			continue
		var t := CombatTypes.Terrain.TREE if r.randf() < tree_share else CombatTypes.Terrain.ROCK
		if _put(grid, BattleGrid.from_offset(col, row), t):
			placed += 1


## A fence of three to five hexes along a free row, out toward a flank.
func _fence_line(grid: BattleGrid, r: SimRng) -> void:
	var rows: Array[int] = []
	for row in grid.height:
		if not _rows.has(row):
			rows.append(row)
	if rows.is_empty():
		return
	var row: int = rows[r.randi_range(0, rows.size() - 1)]
	var n := r.randi_range(3, 5)
	var left := r.randf() < 0.5
	var start := r.randi_range(0, 2) if left else grid.width - n - r.randi_range(0, 2)
	for i in n:
		_put(grid, BattleGrid.from_offset(start + i, row), CombatTypes.Terrain.FENCE)


## Trees along the stream's banks, out on the flanks.
func _banks(grid: BattleGrid, r: SimRng) -> void:
	var n := r.randi_range(2, 4)
	var placed := 0
	var tries := 0
	while placed < n and tries < 40:
		tries += 1
		var row := r.randi_range(their_row + 1, our_row - 1)
		var col := r.randi_range(0, 3) if r.randf() < 0.5 else grid.width - 1 - r.randi_range(0, 3)
		var c := BattleGrid.from_offset(col, row)
		if grid.terrain_at(c) == CombatTypes.Terrain.WATER:
			continue
		if _put(grid, c, CombatTypes.Terrain.TREE if r.randf() < 0.8 else CombatTypes.Terrain.ROCK):
			placed += 1


## A yard fence running out from the hall's ends along its rows, and a gap
## left at the doors' side so the hall is never fenced in.
func _yard(grid: BattleGrid, r: SimRng, hall: Array[Vector2i]) -> void:
	if hall.is_empty():
		return
	var lo := 9999
	var hi := -9999
	var row := 0
	for c in hall:
		var o := BattleGrid.to_offset(c)
		if o.x < lo:
			lo = o.x
			row = o.y
		hi = maxi(hi, o.x)
	var n := r.randi_range(2, 4)
	var go_left := r.randf() < 0.5
	for i in n:
		var col := lo - 1 - i if go_left else hi + 1 + i
		_put(grid, BattleGrid.from_offset(col, row), CombatTypes.Terrain.FENCE)


## Round the ships' strand, three fields in five: a tree or a fence post at
## either end, and sometimes a broken fence beyond it, away from the fight;
## never in front of it.
func _round_the_ships(grid: BattleGrid, r: SimRng, objective: Objective) -> void:
	if objective == null or (objective.kind != Objective.Kind.REACH_THE_SHIPS and objective.kind != Objective.Kind.CARGO) \
			or objective.cells.is_empty() or r.randf() < 0.4:
		return
	var lo := 9999
	var hi := -9999
	var row := BattleGrid.to_offset(objective.cells[0]).y
	for c in objective.cells:
		var o := BattleGrid.to_offset(c)
		lo = mini(lo, o.x)
		hi = maxi(hi, o.x)
	var t := CombatTypes.Terrain.TREE if r.randf() < 0.5 else CombatTypes.Terrain.FENCE
	_put(grid, BattleGrid.from_offset(lo - 1, row), t)
	_put(grid, BattleGrid.from_offset(hi + 1, row), t)
	# Beyond the strand, away from the fight.
	var away := 1 if row > (their_row + our_row) / 2 else -1
	if r.randf() < 0.5:
		for col in range(lo, hi + 1, 2):
			_put(grid, BattleGrid.from_offset(col, row + away), CombatTypes.Terrain.FENCE)
