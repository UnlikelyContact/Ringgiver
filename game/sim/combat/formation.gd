class_name Formation
extends RefCounted
## Where men should stand for the shield wall and the svinfylking, and who
## goes where. Slots never include the leader's own cell: he is the centre of
## the line and the tip of the wedge.


## Up to `count` cells on the line through the leader, perpendicular to his
## facing, alternating right and left of him outward. Cells that are blocked
## (enemy, body, water, off the map) are skipped; a cell held by an active
## friend counts as a slot already filled.
static func line_slots(grid: BattleGrid, leader: Warrior, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if leader == null or count <= 0:
		return out
	var dirs := BattleGrid.line_dirs(leader.facing)
	var reach := maxi(grid.width, grid.height)
	for k in range(1, reach + 1):
		for dir in dirs:
			var c: Vector2i = leader.pos + dir * k
			if _usable(grid, leader, c):
				out.append(c)
				if out.size() >= count:
					return out
	return out


## Up to `count` cells of a boar's-snout wedge behind the leader at its tip:
## rank 1 is behind-left and behind-right, rank 2 the three cells of the next
## rank out (two edges and the middle), and so on, each rank filled from its
## centre outward. The same skipping rules as `line_slots` apply.
static func wedge_slots(grid: BattleGrid, leader: Warrior, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if leader == null or count <= 0:
		return out
	# On hexes the two cells behind the tip are 120 and 180 degrees round
	# from the facing; the rank runs along the line direction between them.
	var back_left := BattleGrid.rotate(leader.facing, 4)
	var back_right := BattleGrid.rotate(leader.facing, 3)
	var across := back_right - back_left
	var reach := maxi(grid.width, grid.height)
	for k in range(1, reach + 1):
		var rank: Array[Vector2i] = []
		for i in k + 1:
			rank.append(leader.pos + back_left * k + across * i)
		# Centre outward, right before left at equal distance from the centre.
		var order: Array[int] = []
		for i in k + 1:
			order.append(i)
		var mid := k / 2.0
		order.sort_custom(func(a: int, b: int) -> bool:
			var da := absf(a - mid)
			var db := absf(b - mid)
			if da != db:
				return da < db
			return a > b)
		for i in order:
			var c: Vector2i = rank[i]
			if _usable(grid, leader, c):
				out.append(c)
				if out.size() >= count:
					return out
	return out


## Greedy nearest-first assignment: of all (man, slot) pairs, the closest is
## matched first, then the next closest among those left, and so on. A man
## already on a slot therefore keeps it, and a man walking toward his slot
## keeps it as he closes. Ties go to the man nearer the front of the line
## (slots[0], beside the leader), then lower id, then earlier slot. Returns
## Warrior -> Vector2i; men left over when slots run out are absent.
static func assign(slots: Array[Vector2i], men: Array[Warrior]) -> Dictionary:
	var result := {}
	if slots.is_empty():
		return result
	var anchor: Vector2i = slots[0]
	var pairs: Array = []
	for mi in men.size():
		var m: Warrior = men[mi]
		for si in slots.size():
			pairs.append([BattleGrid.chebyshev(m.pos, slots[si]),
					BattleGrid.chebyshev(m.pos, anchor), m.id, si, mi])
	pairs.sort_custom(func(a: Array, b: Array) -> bool:
		for i in 4:
			if a[i] != b[i]:
				return a[i] < b[i]
		return a[4] < b[4])
	var taken := {}
	for p in pairs:
		var m: Warrior = men[p[4]]
		var si: int = p[3]
		if result.has(m) or taken.has(si):
			continue
		result[m] = slots[si]
		taken[si] = true
	return result


static func _usable(grid: BattleGrid, leader: Warrior, c: Vector2i) -> bool:
	if grid.is_free(c):
		return true
	var o := grid.occupant(c)
	return o != null and o.side == leader.side and o.is_active()
