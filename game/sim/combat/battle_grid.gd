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


## Ground nobody can stand on: water too deep to wade, trees, rocks,
## fences and the walls of a building. Every movement choice goes through
## `is_free`, so these are simply never chosen; nobody stands in them, so
## nobody is struck or flanked from them either.
static func blocks(t: CombatTypes.Terrain) -> bool:
	return t == CombatTypes.Terrain.WATER or t == CombatTypes.Terrain.TREE or t == CombatTypes.Terrain.ROCK \
			or t == CombatTypes.Terrain.FENCE or t == CombatTypes.Terrain.BUILDING


## On the map and ground a man can stand on, whoever stands there now.
func is_passable(c: Vector2i) -> bool:
	return in_bounds(c) and not blocks(terrain_at(c))


func is_free(c: Vector2i) -> bool:
	return is_passable(c) and not _occupants.has(c)


## A man standing in the ford cannot set his feet: his shield locks with
## nobody's (`line_neighbors`). He is still in the wall (`chain`), so the
## line crosses together, but it crosses unlocked.
func in_ford(c: Vector2i) -> bool:
	return terrain_at(c) == CombatTypes.Terrain.FORD


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


# --- Lines: four ways a wall can run, eight ways it can stand -----------------
## A wall runs along one of four axes on the screen: LEVEL (a row of cells),
## PLUMB (up and down: a zigzag of neighbouring cells drawn straight),
## SLANT_R (the hex axis rising to the right, north-east/south-west) or
## SLANT_L (the hex axis rising to the left, north-west/south-east). Its men
## face one side of it or the other, so a wall stands one of eight ways;
## wheeling steps round them. The facing is a hex direction (what shields
## and arcs use); for a level or slanted line it is thirty degrees off the
## true perpendicular, which is as near as hexes come.
enum Axis { LEVEL, SLANT_R, PLUMB, SLANT_L }
const AXIS_NAMES := ["level", "slant right", "plumb", "slant left"]
## [axis, facing index, bearing of the front in degrees], right-hand turns
## going down the list.
const STATES := [
	[Axis.LEVEL, 0, 90], [Axis.SLANT_L, 1, 30], [Axis.PLUMB, 2, 0], [Axis.SLANT_R, 3, 330],
	[Axis.LEVEL, 3, 270], [Axis.SLANT_L, 4, 210], [Axis.PLUMB, 5, 180], [Axis.SLANT_R, 0, 150],
]


## The two raw hex axes nearest a man's line (kept for old callers).
static func line_dirs(facing: Vector2i) -> Array[Vector2i]:
	return [rotate(facing, 2), rotate(facing, 5)]


## The axis a lone man's line runs on, from his facing alone: level unless
## he faces east or west, then plumb.
static func default_axis(facing: Vector2i) -> int:
	var i := dir_index(facing)
	return Axis.PLUMB if i == 2 or i == 5 else Axis.LEVEL


## Whether a facing is on the first-listed side of an axis (up, up-right,
## east, up-left respectively) rather than the other.
static func side_a(axis: int, facing: Vector2i) -> bool:
	var i := dir_index(facing)
	match axis:
		Axis.LEVEL:
			return i == 0 or i == 1 or i == 2  # north-west, north-east (east breaks the tie upward)
		Axis.PLUMB:
			return i == 1 or i == 2 or i == 3  # east and its neighbours
		Axis.SLANT_R:
			return i == 0 or i == 5 or i == 1  # north-west, west (north-east along the axis counts as up-left)
		_:
			return i == 1 or i == 2 or i == 0  # north-east, east (north-west along the axis counts as up-right)


## The two hex steps that straddle "straight forward" for a man facing
## `facing` on `axis`, [the one taken from an even perpendicular coordinate,
## the one from odd]. Plumb has one step, given twice.
static func forward_pair(axis: int, facing: Vector2i) -> Array[Vector2i]:
	var a := side_a(axis, facing)
	var i: Array
	match axis:
		Axis.LEVEL:
			i = [1, 0] if a else [3, 4]
		Axis.PLUMB:
			i = [2, 2] if a else [5, 5]
		Axis.SLANT_R:
			i = [0, 5] if a else [3, 2]
		_:
			i = [1, 2] if a else [4, 5]
	var out: Array[Vector2i] = [DIRS[i[0]], DIRS[i[1]]]
	return out


## The coordinate that is constant along a line on `axis`: its parity keys
## the zigzag, so every man in the line steps the same way and each keeps
## his own place across the line.
static func across_key(pos: Vector2i, axis: int) -> int:
	match axis:
		Axis.LEVEL:
			return pos.y
		Axis.PLUMB:
			return 0
		Axis.SLANT_R:
			return pos.x + pos.y
		_:
			return pos.x


## The step a man at `pos` takes to advance straight forward from a line on
## `axis`, facing `facing`.
static func forward(pos: Vector2i, axis: int, facing: Vector2i) -> Vector2i:
	var pair := forward_pair(axis, facing)
	return pair[0] if posmod(across_key(pos, axis), 2) == 0 else pair[1]


## The next cell along a man's line to his right (or left).
static func along(pos: Vector2i, axis: int, facing: Vector2i, right: bool) -> Vector2i:
	var a := side_a(axis, facing)
	match axis:
		Axis.LEVEL:
			return pos + (DIRS[2] if a == right else DIRS[5])  # facing up, the right hand is east
		Axis.SLANT_R:
			return pos + (DIRS[1] if a == right else DIRS[4])  # facing up-left, the right hand is north-east
		Axis.SLANT_L:
			return pos + (DIRS[3] if a == right else DIRS[0])  # facing up-right, the right hand is south-east
		_:
			# Facing east, the right hand is south: down the zigzag, keeping the column.
			var down := a == right
			return pos + forward(pos, Axis.LEVEL, DIRS[3] if down else DIRS[0])


## The state (index into STATES) a wall stands in, from its axis and facing.
static func state_of(axis: int, facing: Vector2i) -> int:
	var best := 0
	var best_d := 9
	for i in STATES.size():
		if STATES[i][0] != axis:
			continue
		var d := facing_steps(DIRS[STATES[i][1]], facing)
		if d < best_d:
			best_d = d
			best = i
	return best


## The wall's stance `steps` right-hand turns round from (axis, facing):
## [axis, facing].
static func wheel_state(axis: int, facing: Vector2i, steps: int) -> Array:
	var s: Array = STATES[posmod(state_of(axis, facing) + steps, STATES.size())]
	return [s[0], DIRS[s[1]]]


## The stance whose front points nearest along a cartesian bearing: [axis, facing].
static func state_toward(bearing: Vector2) -> Array:
	var ang := rad_to_deg(atan2(-bearing.y, bearing.x))  # screen y runs down
	var best: Array = STATES[0]
	var best_d := 999.0
	for s in STATES:
		var d: float = absf(wrapf(ang - float(s[2]), -180.0, 180.0))
		if d < best_d:
			best_d = d
			best = s
	return [best[0], DIRS[best[1]]]


## How many wheel steps apart two stances are, the short way round (0..4).
static func state_steps(axis_a: int, facing_a: Vector2i, axis_b: int, facing_b: Vector2i) -> int:
	var d := posmod(state_of(axis_b, facing_b) - state_of(axis_a, facing_a), STATES.size())
	return mini(d, STATES.size() - d)


## Old names, for a lone man whose line axis follows his facing.
static func line_is_plumb(facing: Vector2i) -> bool:
	return default_axis(facing) == Axis.PLUMB


static func along_line(pos: Vector2i, facing: Vector2i, right: bool) -> Vector2i:
	return along(pos, default_axis(facing), facing, right)


static func advance_step(pos: Vector2i, facing: Vector2i) -> Vector2i:
	return forward(pos, default_axis(facing), facing)


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
## Nobody locks with a man standing in a ford, nor he with them (`in_ford`):
## the lock bonus, the brace against a shove, the push's line and the
## morale of a man alone all read this, so the stream breaks them all.
func line_neighbors(w: Warrior, max_turn := DEFAULT_LINK_TURN) -> Array[Warrior]:
	var out: Array[Warrior] = []
	if in_ford(w.pos):
		return out
	for c in neighbors(w.pos):
		var n := occupant(c)
		if n != null and n.is_active() and not in_ford(c) and linked(w, n, max_turn):
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
				var t := terrain_at(c)
				s += ". " if t == CombatTypes.Terrain.FLAT else ("# " if blocks(t) else "~ ")
			elif w.is_down():
				s += "x "
			else:
				s += ("A " if w.side == 0 else "B ")
		lines.append(s)
	return "\n".join(lines)
