class_name Push
extends RefCounted
## The push (concept.md, Formation rules): at round end, lines in contact
## compare combined Might, weighted by morale and second-rank support; the
## weaker line is shoved back a cell.
##
## A man is "in contact" when he is active, not broken, and an active enemy
## stands adjacent in his FRONT arc. Contacted men of one side form groups:
## connected components over line-neighbor adjacency (BattleGrid.line_neighbors).
## Each pair of opposing groups that touch (some member of one adjacent to
## some member of the other) makes one opposed roll on their strengths.


## `may_advance`: Warrior -> true for men allowed to follow up a won push
## (the battle passes the members of each side's wall). Empty means anyone.
static func resolve(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		all: Array[Warrior], log: PackedStringArray, may_advance: Dictionary = {}) -> PushResult:
	var result := PushResult.new()
	var men: Array[Warrior] = all.duplicate()
	men.sort_custom(func(a: Warrior, b: Warrior) -> bool: return a.id < b.id)

	var contacted: Array[Warrior] = []
	for w in men:
		if in_contact(grid, w):
			contacted.append(w)
	if contacted.is_empty():
		return result

	var groups := _groups(grid, contacted)
	var strength_of: Array[float] = []
	for g in groups:
		var s := group_strength(rules, grid, g)
		strength_of.append(s)
		var side: int = g[0].side
		result.strengths[side] = result.strengths.get(side, 0.0) + s

	var wins := {}
	var losers: Array[Warrior] = []
	var winners: Array[Warrior] = []
	for i in groups.size():
		for j in range(i + 1, groups.size()):
			var a: Array[Warrior] = groups[i]
			var b: Array[Warrior] = groups[j]
			if a[0].side == b[0].side or not _touch(a, b):
				continue
			result.contests += 1
			var roll := OpposedRoll.resolve(rng, roundi(strength_of[i]), roundi(strength_of[j]))
			var label := "%s's group (%.1f) against %s's group (%.1f)" % [
				a[0].display_name, strength_of[i], b[0].display_name, strength_of[j]]
			if absi(roll.margin) < rules.push_min_margin:
				log.append("push: %s, neither gives ground" % label)
				continue
			var won: Array[Warrior] = a if roll.margin > 0 else b
			var lost: Array[Warrior] = b if roll.margin > 0 else a
			log.append("push: %s, side %d drives side %d back" % [label, won[0].side, lost[0].side])
			wins[won[0].side] = wins.get(won[0].side, 0) + 1
			for w in won:
				if not winners.has(w):
					winners.append(w)
			for w in lost:
				if not losers.has(w):
					losers.append(w)

	for w in winners:
		w.add_effort(CombatTypes.Stat.MIGHT)
	_shove(rules, grid, losers, result, log)
	if not result.shoved.is_empty() or not result.driven_off.is_empty():
		for w in winners:
			w.morale = clampi(w.morale + rules.push_won_morale, 0, 10)
	if rules.push_winners_advance:
		if may_advance.is_empty():
			_advance(grid, winners, losers, result, log)
		else:
			var allowed: Array[Warrior] = []
			for w in winners:
				if may_advance.has(w):
					allowed.append(w)
			if allowed.size() == winners.size():
				_advance(grid, winners, losers, result, log)
	result.winning_side = _top_side(wins)
	return result


## Winners step into the ground the losers gave up: each winner whose cell
## ahead is now free moves into it, so the lines stay in contact and a push
## actually drives the line forward (concept.md, "Push!").
static func _advance(grid: BattleGrid, winners: Array[Warrior], losers: Array[Warrior],
		result: PushResult, log: PackedStringArray) -> void:
	if losers.is_empty() or (result.shoved.is_empty() and not result.blocked.is_empty()):
		return
	# The winning line follows as a line: every man steps square to his
	# facing, and only if all of them can; otherwise the line holds its gain.
	var steps := {}
	for w in winners:
		if not w.is_active() or w.broken:
			continue
		var ahead := w.pos + BattleGrid.advance_step(w.pos, w.facing)
		var occ := grid.occupant(ahead)
		if not grid.in_bounds(ahead) or grid.terrain_at(ahead) == CombatTypes.Terrain.WATER \
				or (occ != null and not winners.has(occ)):
			return
		steps[w] = ahead
	for w in steps:
		grid.remove(w)
	for w in steps:
		if not grid.place(w, steps[w]):
			grid.place(w, w.pos)
		else:
			result.advanced.append(w)
	if not result.advanced.is_empty():
		log.append("side %d drives forward" % result.advanced[0].side)


## True when w is active, not broken, and faces an adjacent active enemy.
static func in_contact(grid: BattleGrid, w: Warrior) -> bool:
	if not w.is_active() or w.broken:
		return false
	for e in grid.adjacent_warriors(w.pos):
		var arc := BattleGrid.arc_of(w, e.pos)
		if e.side != w.side and e.is_active() and (arc == CombatTypes.Arc.FRONT or arc == CombatTypes.Arc.FRONT_RIGHT):
			return true
	return false


## Σ Might × (1 + push_morale_weight × morale / 10), plus
## push_second_rank_bonus per member with an active friend directly behind.
static func group_strength(rules: CombatRules, grid: BattleGrid, group: Array[Warrior]) -> float:
	var total := 0.0
	for w in group:
		total += w.might * (1.0 + rules.push_morale_weight * w.morale / 10.0)
		var back := grid.occupant(grid.behind(w))
		if back != null and back.side == w.side and back.is_active():
			total += rules.push_second_rank_bonus
	return total


## Connected components of contacted men over line-neighbor adjacency.
## Groups are ordered by their lowest id; members by id.
static func _groups(grid: BattleGrid, contacted: Array[Warrior]) -> Array:
	var group_of := {}
	var groups: Array = []
	for start in contacted:
		if group_of.has(start):
			continue
		var g: Array[Warrior] = []
		var queue: Array[Warrior] = [start]
		group_of[start] = true
		while not queue.is_empty():
			var w: Warrior = queue.pop_front()
			g.append(w)
			for other in contacted:
				if group_of.has(other) or other.side != w.side:
					continue
				if grid.line_neighbors(w).has(other) or grid.line_neighbors(other).has(w):
					group_of[other] = true
					queue.append(other)
		g.sort_custom(func(a: Warrior, b: Warrior) -> bool: return a.id < b.id)
		groups.append(g)
	return groups


static func _touch(a: Array[Warrior], b: Array[Warrior]) -> bool:
	for x in a:
		for y in b:
			if BattleGrid.chebyshev(x.pos, y.pos) == 1:
				return true
	return false


## Shoves each loser one cell straight back from his facing. Men whose
## cell behind is freed by a friend giving ground move too; the rest are
## blocked and lose breath.
static func _shove(rules: CombatRules, grid: BattleGrid, losers: Array[Warrior],
		result: PushResult, log: PackedStringArray) -> void:
	var pending: Array[Warrior] = losers.duplicate()
	pending.sort_custom(func(a: Warrior, b: Warrior) -> bool: return a.id < b.id)
	# A line gives ground together: if fewer than push_line_fraction of its
	# men have room behind them, the whole line is pressed and holds (and
	# tires); otherwise it goes back and the few who are blocked stay.
	if rules.push_as_a_line and not pending.is_empty():
		var can := 0
		var at_edge := 0
		for w: Warrior in pending:
			if grid.is_free(w.pos - w.facing):
				can += 1
			elif not grid.in_bounds(w.pos - w.facing):
				at_edge += 1
		# Pressed back onto the map's edge with nowhere to go: driven from the field.
		if at_edge > 0 and float(can) < float(pending.size()) * rules.push_line_fraction:
			for w: Warrior in pending:
				w.fled = true
				grid.remove(w)
				result.driven_off.append(w)
			log.append("the line is driven from the field, %d men" % pending.size())
			return
		if float(can) < float(pending.size()) * rules.push_line_fraction:
			for w: Warrior in pending:
				w.spend_breath(rules.push_blocked_breath)
				w.morale = clampi(w.morale + rules.push_pressed_morale, 0, 10)
				result.blocked.append(w)
			log.append("the line is pressed back but holds its ground")
			return
	var moved := true
	while moved:
		moved = false
		for w: Warrior in pending.duplicate():
			var dest: Vector2i = w.pos - w.facing
			if grid.is_free(dest) and grid.place(w, dest):
				pending.erase(w)
				result.shoved.append(w)
				w.morale = clampi(w.morale + rules.push_shoved_morale, 0, 10)
				log.append("%s is shoved back to %s" % [w.display_name, dest])
				moved = true
	for w in pending:
		w.spend_breath(rules.push_blocked_breath)
		result.blocked.append(w)
		log.append("%s is pressed back but has nowhere to go" % w.display_name)


static func _top_side(wins: Dictionary) -> int:
	var best := -1
	var best_count := 0
	var tied := false
	for side in wins:
		var c: int = wins[side]
		if c > best_count:
			best = side
			best_count = c
			tied = false
		elif c == best_count:
			tied = true
	return -1 if tied else best
