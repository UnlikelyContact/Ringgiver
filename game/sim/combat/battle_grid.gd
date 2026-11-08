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


const DEFAULT_LINK_TURN := 1  # a line may turn one facing between two men
const DEFAULT_MAX_BEND := 2  # and no man may face more than two off its leader


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


## Lines run level or plumb on the screen, never slantwise, whatever the
## hexes do. A man facing up or down (the four diagonal hex facings) stands
## in a level row of cells; a man facing east or west stands in a plumb
## line, which on pointy-top hexes is a zigzag of neighbouring cells drawn
## straight. The two directions along his line are "right" and "left" of
## his facing. (`line_dirs` is kept for callers that only need the two raw
## hex axes nearest the line.)
static func line_dirs(facing: Vector2i) -> Array[Vector2i]:
	return [rotate(facing, 2), rotate(facing, 5)]


## Does a man with this facing stand in a plumb (up-and-down) line?
static func line_is_plumb(facing: Vector2i) -> bool:
	var i := dir_index(facing)
	return i == 2 or i == 5


## The next cell along a man's line to his right (or left): along the row
## for a level line, down or up the zigzag for a plumb one.
static func along_line(pos: Vector2i, facing: Vector2i, right: bool) -> Vector2i:
	var i := dir_index(facing)
	if line_is_plumb(facing):
		# Facing east, his right hand is south; facing west, north.
		var down := (i == 2) == right
		return pos + advance_step(pos, DIRS[3] if down else DIRS[0])
	# Facing up (north-west or north-east), his right hand is east.
	var up := i == 0 or i == 1
	return pos + (DIRS[2] if up == right else DIRS[5])


## The step a wall takes to advance square to its line. Facing east or
## west it is the plain hex step. Facing up or down no hex step is square,
## so "straight" alternates the two that straddle it, keyed on the row, so
## every man in a level row steps the same way and keeps his column.
static func advance_step(pos: Vector2i, facing: Vector2i) -> Vector2i:
	var i := dir_index(facing)
	if i == 2 or i == 5:
		return facing
	# With odd rows shoved right, the cell straight above an even row is to
	# the north-east and above an odd row to the north-west; straight below,
	# south-east and south-west. Each step keeps the man's own column.
	if i == 0 or i == 1:  # up
		return DIRS[1] if posmod(pos.y, 2) == 0 else DIRS[0]
	return DIRS[3] if posmod(pos.y, 2) == 0 else DIRS[4]  # down


## The cell straight behind `w` (for second-rank support).
func behind(w: Warrior) -> Vector2i:
	return w.pos + advance_step(w.pos, rotate(w.facing, 3))


## How many hex facings (60 degrees each) apart two directions are: 0..3.
static func facing_steps(a: Vector2i, b: Vector2i) -> int:
	var d := posmod(dir_index(a) - dir_index(b), 6)
	return mini(d, 6 - d)


## Friends at w's shoulders: active men linked to him in his line (`linked`),
## whose shields lock with his. The same rule builds the wall, groups the
## push and draws the bars, so what is counted is what is drawn and fought.
func line_neighbors(w: Warrior, max_turn := DEFAULT_LINK_TURN) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for c in neighbors(w.pos):
		var n := occupant(c)
		if n != null and n.is_active() and linked(w, n, max_turn):
			out.append(n)
	return out


## The wall built on a leader: every active, unbroken friend reachable from
## him through men standing next to each other (`linked`), each link
## turning at most `max_turn`, and no man
## facing more than `max_bend` facings off the leader's wall facing. Bend
## further than that and the wall has broken there. Breadth-first from the
## leader, so nearer men come first. Empty without a leader.
func chain(leader: Warrior, max_turn := DEFAULT_LINK_TURN, max_bend := DEFAULT_MAX_BEND) -> Array[Warrior]:
	var out: Array[Warrior] = []
	if leader == null or not leader.is_active() or leader.broken:
		return out
	var wf := leader.wall_facing()
	var seen := {leader: true}
	var queue: Array[Warrior] = [leader]
	while not queue.is_empty():
		var w: Warrior = queue.pop_front()
		out.append(w)
		for c in neighbors(w.pos):
			var n := occupant(c)
			if n == null or seen.has(n) or n.side != leader.side or not n.is_active() or n.broken \
					or n.role == CombatTypes.Role.MISSILE:  # bows stand off; they are never the wall
				continue
			var w_facing: Vector2i = wf if w == leader else w.facing
			if facing_steps(wf, n.facing) > max_bend or not linked_at(w.pos, w_facing, n.pos, n.facing, max_turn):
				continue
			seen[n] = true
			queue.append(n)
	return out


## Two men are linked in a wall when at least one of them has the other at
## his shoulder (not straight ahead or behind him) and they face within
## `max_turn` of each other: a hinge where a wing has swung forward of the
## man beside it still holds, a second rank straight behind does not.
static func linked(a: Warrior, b: Warrior, max_turn := DEFAULT_LINK_TURN) -> bool:
	if a == b or a.side != b.side:
		return false
	return linked_at(a.pos, a.facing, b.pos, b.facing, max_turn)


static func linked_at(a_pos: Vector2i, a_facing: Vector2i, b_pos: Vector2i, b_facing: Vector2i, max_turn := DEFAULT_LINK_TURN) -> bool:
	if distance(a_pos, b_pos) != 1:
		return false
	if facing_steps(a_facing, b_facing) > max_turn:
		return false
	var ab := posmod(dir_index(direction_to(a_pos, b_pos)) - dir_index(a_facing), 6)
	var ba := posmod(dir_index(direction_to(b_pos, a_pos)) - dir_index(b_facing), 6)
	return (ab != 0 and ab != 3) or (ba != 0 and ba != 3)


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
