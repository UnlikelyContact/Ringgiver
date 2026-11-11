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
	var wf := leader.wall_facing()
	var ax := leader.wall_axis()
	var right := leader.pos
	var left := leader.pos
	var reach := maxi(grid.width, grid.height)
	for k in range(1, reach + 1):
		right = BattleGrid.along(right, ax, wf, true)
		left = BattleGrid.along(left, ax, wf, false)
		for c in [right, left]:
			if _usable(grid, leader, c):
				out.append(c)
				if out.size() >= count:
					return out
	return out


## Line slots not already held by a friend: where a man outside the wall
## should go to join it.
static func open_line_slots(grid: BattleGrid, leader: Warrior, count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if leader == null or count <= 0:
		return out
	var wf := leader.wall_facing()
	var ax := leader.wall_axis()
	var right := leader.pos
	var left := leader.pos
	var reach := maxi(grid.width, grid.height)
	for k in range(1, reach + 1):
		right = BattleGrid.along(right, ax, wf, true)
		left = BattleGrid.along(left, ax, wf, false)
		for c in [right, left]:
			if grid.is_free(c):
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
	var back_left := BattleGrid.rotate(leader.wall_facing(), 4)
	var back_right := BattleGrid.rotate(leader.wall_facing(), 3)
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


## Where every man of `band` (the leader excluded) should stand for
## `template`, as Warrior -> cell. Rank 1 fills the line through the leader
## as `line_slots`; rank 2 the cells straight behind rank 1 and the leader,
## centre outward; rank 3 the cells two behind, spread one in two. A rank
## with more men than cells spills its surplus into the line. Each rank is
## assigned greedily within itself. Null template is the plain line.
static func template_slots(grid: BattleGrid, leader: Warrior, band: Array[Warrior],
		template: FormationTemplate) -> Dictionary:
	var out := {}
	if leader == null or band.is_empty():
		return out
	if template != null and template.shape == FormationTemplate.Shape.WEDGE:
		return assign(wedge_slots(grid, leader, band.size()), band)
	var by_rank := {1: [] as Array[Warrior], 2: [] as Array[Warrior], 3: [] as Array[Warrior]}
	for m in band:
		var r := 1 if template == null else clampi(template.rank(m.role), 1, 3)
		(by_rank[r] as Array[Warrior]).append(m)
	var wf := leader.wall_facing()
	var ax := leader.wall_axis()
	var back_facing := BattleGrid.rotate(wf, 3)
	var front: Array[Warrior] = by_rank[1]
	var second: Array[Warrior] = by_rank[2]
	var third: Array[Warrior] = by_rank[3]
	# Rank 2 stands behind the line, so the line must be at least as wide as
	# the second rank needs, the leader's own back included.
	var line_width := maxi(front.size(), second.size() - 1)
	var line := line_slots(grid, leader, line_width)
	var behind: Array[Vector2i] = []
	for c in [leader.pos] + line:
		var b: Vector2i = c + BattleGrid.forward(c, ax, back_facing)  # straight behind
		if _usable(grid, leader, b):
			behind.append(b)
	var far: Array[Vector2i] = []
	var i := 0
	for c in [leader.pos] + line:
		if i % 2 == 0:
			var b1: Vector2i = c + BattleGrid.forward(c, ax, back_facing)
			var b: Vector2i = b1 + BattleGrid.forward(b1, ax, back_facing)
			if _usable(grid, leader, b):
				far.append(b)
		i += 1
	# Surplus of the rear ranks goes into the line.
	var spill: Array[Warrior] = []
	if second.size() > behind.size():
		spill.append_array(second.slice(behind.size()))
		second = second.slice(0, behind.size())
	if third.size() > far.size():
		spill.append_array(third.slice(far.size()))
		third = third.slice(0, far.size())
	front = front + spill
	if front.size() > line.size():
		line = line_slots(grid, leader, front.size())
	var front_slots: Array[Vector2i] = line.slice(0, front.size()) if line.size() >= front.size() else line
	if template != null and template.shape == FormationTemplate.Shape.REFUSED and front_slots.size() >= 4:
		# The two end men stand a hex back: the refused flanks.
		for k in [front_slots.size() - 1, front_slots.size() - 2]:
			var c: Vector2i = front_slots[k]
			var b: Vector2i = c + BattleGrid.forward(c, ax, back_facing)
			if _usable(grid, leader, b) and not behind.slice(0, second.size()).has(b):
				front_slots[k] = b  # unless a second-rank man has that cell
	out.merge(assign(front_slots, front))
	out.merge(assign(behind.slice(0, second.size()), second))
	out.merge(assign(far.slice(0, third.size()), third))
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
