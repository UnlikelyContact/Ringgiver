class_name BattleGrid
extends RefCounted
## Square grid with eight-direction facing. Isometric presentation is a view
## concern; the sim only knows cells. Distance is Chebyshev (diagonals cost 1).

## Direction order is clockwise from north. Index math uses this order.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

var width: int
var height: int
var _terrain := PackedInt32Array()
var _occupants := {}


func _init(p_width := 16, p_height := 12) -> void:
	width = p_width
	height = p_height
	_terrain.resize(width * height)
	_terrain.fill(CombatTypes.Terrain.FLAT)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func terrain_at(c: Vector2i) -> CombatTypes.Terrain:
	return _terrain[c.y * width + c.x] as CombatTypes.Terrain


func set_terrain(c: Vector2i, t: CombatTypes.Terrain) -> void:
	_terrain[c.y * width + c.x] = t


func occupant(c: Vector2i) -> Warrior:
	return _occupants.get(c, null)


func is_free(c: Vector2i) -> bool:
	return in_bounds(c) and not _occupants.has(c) and terrain_at(c) != CombatTypes.Terrain.WATER


func place(w: Warrior, c: Vector2i) -> bool:
	if not is_free(c):
		return false
	_occupants.erase(w.pos) if _occupants.get(w.pos) == w else null
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


## Adjacent warriors (all eight neighbors), optionally filtered by side.
func adjacent_warriors(c: Vector2i, side := -1) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for n in neighbors(c):
		var w := occupant(n)
		if w != null and (side < 0 or w.side == side):
			out.append(w)
	return out


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func dir_index(d: Vector2i) -> int:
	return DIRS.find(d)


static func rotate(d: Vector2i, steps: int) -> Vector2i:
	return DIRS[posmod(dir_index(d) + steps, 8)]


## Direction from `a` toward `b`, snapped to eight directions.
static func direction_to(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(signi(b.x - a.x), signi(b.y - a.y))


## From which arc of the defender does an attack from `attacker_pos` arrive?
static func arc_of(defender: Warrior, attacker_pos: Vector2i) -> CombatTypes.Arc:
	var toward := direction_to(defender.pos, attacker_pos)
	var rel := posmod(dir_index(toward) - dir_index(defender.facing), 8)
	match rel:
		0, 7:
			return CombatTypes.Arc.FRONT
		1:
			return CombatTypes.Arc.FRONT_RIGHT
		6:
			return CombatTypes.Arc.LEFT
		2:
			return CombatTypes.Arc.RIGHT
	return CombatTypes.Arc.REAR


## True when the defender's shield covers an attack from that arc.
static func shield_covers(arc: CombatTypes.Arc) -> bool:
	return arc == CombatTypes.Arc.FRONT or arc == CombatTypes.Arc.LEFT


## The cell directly behind `w` (for second-rank support).
func behind(w: Warrior) -> Vector2i:
	return w.pos - w.facing


## Shield-bearing friends on w's left and right (perpendicular to facing).
func line_neighbors(w: Warrior) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for steps in [2, -2]:
		var side_dir := rotate(w.facing, steps)
		var n := occupant(w.pos + side_dir)
		if n != null and n.side == w.side and n.is_active():
			out.append(n)
	return out


func describe() -> String:
	var lines := PackedStringArray()
	for y in height:
		var row := ""
		for x in width:
			var w := occupant(Vector2i(x, y))
			if w == null:
				row += "." if terrain_at(Vector2i(x, y)) == CombatTypes.Terrain.FLAT else "~"
			elif w.is_down():
				row += "x"
			else:
				row += "A" if w.side == 0 else "B"
		lines.append(row)
	return "\n".join(lines)
