class_name MapGrid
extends RefCounted
## The ground and the water of the free-roam map: a raster of one-league
## cells cut from NorwayData.SHORES, with every place standing on the
## coast (a fjord is carved in to any that would not) and the land rising
## from shore to upland to mountain with its distance from the sea. A band
## walks the land and, with a ship, sails the water; `find_path` knows the
## difference, and that a ship stays where she was beached.
##
## Coordinates: leagues, x east and y south, as Place.pos. Cell (cx, cy)
## covers [ORIGIN + (cx, cy), +1). One grid serves every world: `norway()`.
##
## The wider world (docs/design/notes/wider-world.md) reaches east to the
## Rus' lands and south to Miklagard: lakes and the Black Sea are cut out
## of the land (NorwayData.WATERS), rivers a cell wide are cut along lines
## (RIVERS: water, but a ship makes only RIVER_PACE of her pace on them),
## the portages are land a ship may be hauled over (PORTAGES: `find_path`'s
## `haul`), and the Rus' forests and the steppe never rise to mountain
## (FLATS).

enum T { DEEP, SEA, SHORE, LAND, MOUNTAIN }

const ORIGIN := Vector2i(-58, -14)
const W := 258
const H := 176
## Days' worth of going per league, by terrain, as a multiple of the plain
## pace: the hills are slow and the mountains slower.
const COST := [1.0, 1.0, 1.0, 1.6, 4.0]
## Land this near the sea is shore; this near, low land; beyond, mountain.
const SHORE_WITHIN := 2
const LAND_WITHIN := 5
## Sea this far from any land is the deep.
const DEEP_BEYOND := 4
## The share of a ship's pace she makes on a river (against the current,
## picking through the shoals; the same both ways, for simplicity).
const RIVER_PACE := 0.6
## Leagues a day a ship is hauled over a portage when the caller does not
## say (`find_path`'s haul < 0): this share of her pace. The band's own
## ship is hauled at its hull's pace (WorldRules.portage_haul).
const HAUL_SHARE := 0.15

var cells := PackedByteArray()
## Place id -> its cell; cell index -> place id.
var place_cell := {}
var cell_place := {}
## Per cell: 1 on a river; the portage's number (1, 2, ...) on a portage.
var river := PackedByteArray()
var portage := PackedByteArray()
## Land that never rises to mountain (FLATS): 1 wooded, 2 open.
var flat := PackedByteArray()
## Going on foot over the flats, as a multiple of the terrain's COST, by
## `flat`: trackless forest and bog, and the open steppe, where a band
## without a ship gets on no faster than in the fells. (Without it the
## steppe would be a road to Miklagard for a band that left its ship.)
const FLAT_COST := [1.0, 3.0, 2.2]

static var _norway: MapGrid = null


static func norway() -> MapGrid:
	if _norway == null:
		_norway = MapGrid.new()
		_norway._build()
	return _norway


# --- Cells ---------------------------------------------------------------------

static func cell_of(v: Vector2) -> Vector2i:
	return Vector2i(floori(v.x), floori(v.y)) - ORIGIN


static func centre(c: Vector2i) -> Vector2:
	return Vector2(c + ORIGIN) + Vector2(0.5, 0.5)


static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


static func index(c: Vector2i) -> int:
	return c.y * W + c.x


func terrain(c: Vector2i) -> int:
	return cells[index(c)] if inside(c) else T.DEEP


func terrain_at(v: Vector2) -> int:
	return terrain(cell_of(v))


func is_sea(c: Vector2i) -> bool:
	return terrain(c) <= T.SEA


func is_land(c: Vector2i) -> bool:
	return inside(c) and cells[index(c)] >= T.SHORE


## Days' worth of going per league on foot over this cell, as a multiple
## of the plain pace (COST, and FLAT_COST over the flats).
func walk_cost(c: Vector2i) -> float:
	if not inside(c):
		return COST[T.DEEP]
	var i := index(c)
	return float(COST[cells[i]]) * float(FLAT_COST[flat[i]])


func is_river(c: Vector2i) -> bool:
	return inside(c) and river[index(c)] == 1


## The portage (its index in NorwayData.PORTAGES) this cell is on, or -1.
func portage_at(c: Vector2i) -> int:
	return int(portage[index(c)]) - 1 if inside(c) else -1


## The place standing on this cell, or "".
func place_at(v: Vector2) -> String:
	return cell_place.get(index(cell_of(v)), "")


# --- Building --------------------------------------------------------------------

func _build() -> void:
	cells.resize(W * H)
	var land := PackedByteArray()
	land.resize(W * H)
	var shores: Array[PackedVector2Array] = []
	for s in NorwayData.SHORES:
		shores.append(PackedVector2Array(s))
	var waters: Array[PackedVector2Array] = []
	for s in NorwayData.WATERS:
		waters.append(PackedVector2Array(s))
	river.resize(W * H)
	portage.resize(W * H)
	flat.resize(W * H)
	for y in H:
		for x in W:
			var p := centre(Vector2i(x, y))
			for poly in shores:
				if Geometry2D.is_point_in_polygon(p, poly):
					land[y * W + x] = 1
					break
			for poly in waters:
				if Geometry2D.is_point_in_polygon(p, poly):
					land[y * W + x] = 0
					break
			for f in NorwayData.FLATS:
				if Geometry2D.is_point_in_polygon(p, PackedVector2Array(f[0])):
					flat[y * W + x] = 1 if bool(f[1]) else 2
					break
	# Every place stands on land, with water at its door.
	for d in NorwayData.PLACES:
		var c := cell_of(d.pos)
		place_cell[d.id] = c
		cell_place[index(c)] = d.id
		land[index(c)] = 1
	_rivers(land)
	for d in NorwayData.PLACES:
		_harbour(land, place_cell[d.id])
	# Terrain by distance: land from the sea, sea from the land.
	var from_sea := _distances(land, false)
	var from_land := _distances(land, true)
	for i in W * H:
		if land[i] == 1:
			var d: int = from_sea[i]
			cells[i] = T.SHORE if d <= SHORE_WITHIN else (T.LAND if d <= LAND_WITHIN or flat[i] != 0 else T.MOUNTAIN)
		else:
			cells[i] = T.DEEP if from_land[i] > DEEP_BEYOND else T.SEA


## Cuts the rivers (water a cell wide, by steps that never turn a corner,
## so a ship can follow them) and marks the portages (land, hauled over).
## A place's own cell is never cut.
func _rivers(land: PackedByteArray) -> void:
	for line in NorwayData.RIVERS:
		var pts: Array = line
		for k in range(pts.size() - 1):
			for c in steps(cell_of(pts[k]), cell_of(pts[k + 1])):
				if inside(c) and not cell_place.has(index(c)):
					land[index(c)] = 0
					river[index(c)] = 1
	for n in NorwayData.PORTAGES.size():
		for v in NorwayData.PORTAGES[n][1]:
			var c := cell_of(v)
			if inside(c):
				land[index(c)] = 1
				portage[index(c)] = n + 1


## The cells from `a` to `b` inclusive, four-way: each step along the axis
## that is furthest behind the straight line.
static func steps(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [a]
	var c := a
	var tx := absi(b.x - a.x)
	var ty := absi(b.y - a.y)
	var guard := 0
	while c != b and guard < 4096:
		guard += 1
		var done_x := absi(c.x - a.x)
		var done_y := absi(c.y - a.y)
		# Step x when x is behind its share of the way (or y is done).
		if c.x != b.x and (c.y == b.y or done_x * ty <= done_y * tx):
			c.x += signi(b.x - a.x)
		else:
			c.y += signi(b.y - a.y)
		out.append(c)
	return out


## Makes sure the place's cell has sea at one of its four sides: if not, a
## fjord a cell wide is cut to it from the nearest water, by steps that
## never turn a corner (so a ship can follow it).
func _harbour(land: PackedByteArray, c: Vector2i) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if inside(n) and land[index(n)] == 0:
			return
	# Breadth-first over the land (round other places, never through them)
	# to the nearest water, then the fjord is cut back along that way, as
	# far as the place's own door.
	var came := {c: c}
	var queue: Array[Vector2i] = [c]
	var found := Vector2i(-1, -1)
	while not queue.is_empty() and found.x < 0:
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if not inside(n) or came.has(n) or cell_place.has(index(n)):
				continue
			came[n] = cur
			if land[index(n)] == 0:
				found = n
				break
			queue.append(n)
	if found.x < 0:
		return
	var back: Vector2i = came[found]
	while back != c:
		land[index(back)] = 0
		back = came[back]


## Steps (four-way) from every cell to the nearest cell of the other kind:
## `from_land` true gives each sea cell its distance from land.
func _distances(land: PackedByteArray, from_land: bool) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(9999)
	var queue := PackedInt32Array()
	var source := 1 if from_land else 0
	for i in W * H:
		if land[i] == source:
			dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % W
		var y := i / W
		var d := dist[i] + 1
		if x > 0 and dist[i - 1] > d:
			dist[i - 1] = d
			queue.append(i - 1)
		if x < W - 1 and dist[i + 1] > d:
			dist[i + 1] = d
			queue.append(i + 1)
		if y > 0 and dist[i - W] > d:
			dist[i - W] = d
			queue.append(i - W)
		if y < H - 1 and dist[i + W] > d:
			dist[i + W] = d
			queue.append(i + W)
	return dist


# --- Finding the way ---------------------------------------------------------------

const _DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## The quickest way from `from` to `to` for a band on foot that may have a
## ship: {cells: Array[Vector2i], aboard: Array[bool], days: float}, the
## cells in order after the first, each with whether the band is with its
## ship there; empty `cells` when there is no way. `foot` and `sail` are
## leagues a day (`sail` 0: no ship). `aboard`: the band starts with its
## ship (at sea, or on the cell where she is beached); else she lies at
## `ship_cell` ((-1, -1): nowhere). `deep_ok` false keeps a small boat out
## of the deep. A ship goes only by water and lands on any shore; a band
## that walks on leaves her where she landed. On a river she makes
## RIVER_PACE of `sail`; over a portage she is hauled at `haul` leagues a
## day (below 0: HAUL_SHARE of `sail`; 0: she cannot be hauled).
func find_path(from: Vector2i, to: Vector2i, foot: float, sail: float, aboard: bool,
		ship_cell := Vector2i(-1, -1), deep_ok := true, haul := -1.0) -> Dictionary:
	var out := {"cells": [] as Array[Vector2i], "aboard": [] as Array[bool], "days": 0.0}
	if not inside(from) or not inside(to) or from == to:
		return out
	if is_sea(to) and sail <= 0.0:
		return out
	var n := W * H * 2
	var g := PackedFloat64Array()
	g.resize(n)
	g.fill(INF)
	var closed := PackedByteArray()
	closed.resize(n)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var best_speed := maxf(foot, sail)
	if haul < 0.0:
		haul = sail * HAUL_SHARE
	var start := index(from) * 2 + (1 if aboard and sail > 0.0 else 0)
	g[start] = 0.0
	# A binary heap of [f, node] kept in two parallel arrays.
	var heap_f := PackedFloat64Array([0.0])
	var heap_n := PackedInt32Array([start])
	var goal := -1
	var ship_i := index(ship_cell) if inside(ship_cell) and sail > 0.0 else -1
	while not heap_n.is_empty():
		# Pop the least.
		var node := heap_n[0]
		var f0 := heap_f[0]
		var last := heap_n.size() - 1
		heap_n[0] = heap_n[last]
		heap_f[0] = heap_f[last]
		heap_n.resize(last)
		heap_f.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and heap_f[l] < heap_f[m]:
				m = l
			if r < last and heap_f[r] < heap_f[m]:
				m = r
			if m == i:
				break
			var tf := heap_f[i]
			heap_f[i] = heap_f[m]
			heap_f[m] = tf
			var tn := heap_n[i]
			heap_n[i] = heap_n[m]
			heap_n[m] = tn
			i = m
		var ci := node >> 1
		var with_ship := (node & 1) == 1
		var c := Vector2i(ci % W, ci / W)
		if c == to:
			goal = node
			break
		if closed[node] == 1:
			continue  # a stale entry: he has been here by a better way
		closed[node] = 1
		var gc := g[node]
		var c_sea := cells[ci] <= T.SEA
		for d in _DIRS:
			var nc: Vector2i = c + d
			if not inside(nc):
				continue
			var ni := index(nc)
			var n_sea := cells[ni] <= T.SEA
			var n_with := false
			var cost := 0.0
			var len := 1.4142 if d.x != 0 and d.y != 0 else 1.0
			if n_sea:
				if not with_ship or (not deep_ok and cells[ni] == T.DEEP):
					continue
				# Out of a harbour or along the water: never across a corner of land.
				if d.x != 0 and d.y != 0 and (cells[index(c + Vector2i(d.x, 0))] > T.SEA or cells[index(c + Vector2i(0, d.y))] > T.SEA):
					continue
				n_with = true
				cost = len / (sail * RIVER_PACE if river[ni] == 1 else sail)
			elif c_sea:
				if d.x != 0 and d.y != 0:
					continue  # a ship lands square on
				n_with = true  # beached where she lands
				cost = len / sail
			elif with_ship and portage[ni] != 0 and haul > 0.0:
				# Hauled on rollers to the next water.
				n_with = true
				cost = len / haul
			else:
				n_with = ni == ship_i
				cost = len * COST[cells[ni]] * FLAT_COST[flat[ni]] / foot
			var nn := ni * 2 + (1 if n_with else 0)
			if closed[nn] == 1:
				continue
			var ng := gc + cost
			if ng < g[nn]:
				g[nn] = ng
				came[nn] = node
				# Push.
				var f := ng + _h(nc, to, best_speed)
				heap_n.append(nn)
				heap_f.append(f)
				var k := heap_n.size() - 1
				while k > 0:
					var parent := (k - 1) / 2
					if heap_f[parent] <= heap_f[k]:
						break
					var pf := heap_f[parent]
					heap_f[parent] = heap_f[k]
					heap_f[k] = pf
					var pn := heap_n[parent]
					heap_n[parent] = heap_n[k]
					heap_n[k] = pn
					k = parent
	if goal < 0:
		return out
	out.days = g[goal]
	var cells_out: Array[Vector2i] = []
	var aboard_out: Array[bool] = []
	var cur := goal
	while cur != start and cur >= 0:
		var ci2 := cur >> 1
		cells_out.push_front(Vector2i(ci2 % W, ci2 / W))
		aboard_out.push_front((cur & 1) == 1)
		cur = came[cur]
	out.cells = cells_out
	out.aboard = aboard_out
	return out


static func _h(a: Vector2i, b: Vector2i, speed: float) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return (maxi(dx, dy) + 0.4142 * mini(dx, dy)) / speed
