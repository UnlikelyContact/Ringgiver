class_name BattleGrid
extends RefCounted
## A hex grid (pointy-top, axial coordinates in Vector2i as (q, r)) with
## six-direction facing. Six equal neighbours: no diagonals, no corners, so
## a wall can face any of six ways and still lock, and a wedge is a natural
## shape. The map's bounds are a rectangle in odd-r offset coordinates.

## Clockwise from north-west. Opposite directions are three apart.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
]
const NO_CELL := Vector2i(-9999, -9999)

var width: int
var height: int
var _terrain := {}  # axial -> Terrain (missing = FLAT)
var _occupants := {}


func _init(p_width := 16, p_height := 12) -> void:
	width = p_width
	height = p_height


# --- Coordinates --------------------------------------------------------------

## Axial (q, r) from odd-r offset (col, row).
static func from_offset(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row - (row & 1)) / 2, row)


## Odd-r offset (col, row) from axial.
static func to_offset(c: Vector2i) -> Vector2i:
	return Vector2i(c.x + (c.y - (c.y & 1)) / 2, c.y)


## Cartesian position in hex units (pointy-top, size 1).
static func to_cart(c: Vector2) -> Vector2:
	return Vector2(sqrt(3.0) * (c.x + c.y / 2.0), 1.5 * c.y)


func in_bounds(c: Vector2i) -> bool:
	var o := to_offset(c)
	return o.x >= 0 and o.y >= 0 and o.x < width and o.y < height


func is_edge(c: Vector2i) -> bool:
	var o := to_offset(c)
	return o.x == 0 or o.y == 0 or o.x == width - 1 or o.y == height - 1


func terrain_at(c: Vector2i) -> CombatTypes.Terrain:
	return _terrain.get(c, CombatTypes.Terrain.FLAT)


func set_terrain(c: Vector2i, t: CombatTypes.Terrain) -> void:
	_terrain[c] = t


# --- Occupancy ----------------------------------------------------------------

func occupant(c: Vector2i) -> Warrior:
	return _occupants.get(c, null)


func is_free(c: Vector2i) -> bool:
	return in_bounds(c) and not _occupants.has(c) and terrain_at(c) != CombatTypes.Terrain.WATER


func place(w: Warrior, c: Vector2i) -> bool:
	if not is_free(c):
		return false
	if _occupants.get(w.pos) == w:
		_occupants.erase(w.pos)
	w.pos = c
	_occupants[c] = w
	return true


func remove(w: Warrior) -> void:
	if _occupants.get(w.pos) == w:
		_occupants.erase(w.pos)


func warriors() -> Array[Warrior]:
	var out: Array[Warrior] = []
	for w in _occupants.values():
		out.append(w)
	return out


func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n := c + d
		if in_bounds(n):
			out.append(n)
	return out


## Adjacent warriors (all six neighbours), optionally filtered by side.
func adjacent_warriors(c: Vector2i, side := -1) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for n in neighbors(c):
		var w := occupant(n)
		if w != null and (side < 0 or w.side == side):
			out.append(w)
	return out


# --- Distance and direction ---------------------------------------------------

static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## Kept under its old name for callers written against the square grid.
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return distance(a, b)


static func dir_index(d: Vector2i) -> int:
	return DIRS.find(d)


static func rotate(d: Vector2i, steps: int) -> Vector2i:
	return DIRS[posmod(dir_index(d) + steps, 6)]


## The hex direction that best points from `a` toward `b`.
static func direction_to(a: Vector2i, b: Vector2i) -> Vector2i:
	var delta := b - a
	if DIRS.has(delta):
		return delta
	return snap_direction(to_cart(Vector2(b)) - to_cart(Vector2(a)))


## The hex direction closest to a cartesian vector.
static func snap_direction(v: Vector2) -> Vector2i:
	if v.length_squared() < 0.0001:
		return DIRS[0]
	var best := DIRS[0]
	var best_dot := -INF
	for d in DIRS:
		var dot := to_cart(Vector2(d)).normalized().dot(v.normalized())
		if dot > best_dot:
			best_dot = dot
			best = d
	return best


# --- Facing and arcs ----------------------------------------------------------

## From which arc of the defender does an attack from `attacker_pos` arrive?
## Relative to facing, clockwise: 0 front (covered), 1 front-right (open,
## no flank bonus), 2 right (the exposed flank), 3 and 4 rear, 5 left
## (covered). The man to your right covers your open side: that is the wall.
static func arc_of(defender: Warrior, attacker_pos: Vector2i) -> CombatTypes.Arc:
	var toward := direction_to(defender.pos, attacker_pos)
	var rel := posmod(dir_index(toward) - dir_index(defender.facing), 6)
	match rel:
		0:
			return CombatTypes.Arc.FRONT
		1:
			return CombatTypes.Arc.FRONT_RIGHT
		2:
			return CombatTypes.Arc.RIGHT
		5:
			return CombatTypes.Arc.LEFT
	return CombatTypes.Arc.REAR


## True when the defender's shield covers an attack from that arc.
static func shield_covers(arc: CombatTypes.Arc) -> bool:
	return arc == CombatTypes.Arc.FRONT or arc == CombatTypes.Arc.LEFT


## The two directions along a line facing `facing`: right-hand first.
static func line_dirs(facing: Vector2i) -> Array[Vector2i]:
	return [rotate(facing, 2), rotate(facing, 5)]


## The step a wall takes to advance square to its row. No hex direction is
## perpendicular to a hex row, so "straight" alternates the two directions
## that straddle the facing; the alternation is keyed on the coordinate that
## stays constant along the row, so every man in the row steps the same way
## and each keeps his own column over two steps.
static func advance_step(pos: Vector2i, facing: Vector2i) -> Vector2i:
	var row := rotate(facing, 2)
	var key: int
	if row.y == 0:
		key = pos.y  # row runs east-west: r is constant along it
	elif row.x == 0:
		key = pos.x  # row runs north-west/south-east: q is constant
	else:
		key = pos.x + pos.y  # row runs north-east/south-west: q + r is constant
	return facing if posmod(key, 2) == 0 else rotate(facing, 1)


## The cell directly behind `w` (for second-rank support).
func behind(w: Warrior) -> Vector2i:
	return w.pos - w.facing


## Shield-bearing friends on w's right and left along his line.
func line_neighbors(w: Warrior) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for side_dir in line_dirs(w.facing):
		var n := occupant(w.pos + side_dir)
		if n != null and n.side == w.side and n.is_active():
			out.append(n)
	return out


func describe() -> String:
	var lines := PackedStringArray()
	for row in height:
		var s := " " if row & 1 else ""
		for col in width:
			var c := from_offset(col, row)
			var w := occupant(c)
			if w == null:
				s += ". " if terrain_at(c) == CombatTypes.Terrain.FLAT else "~ "
			elif w.is_down():
				s += "x "
			else:
				s += ("A " if w.side == 0 else "B ")
		lines.append(s)
	return "\n".join(lines)
