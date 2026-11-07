class_name Decision
extends RefCounted
## What one man does this round, from the order he believes he heard, his
## experience tier, his personality and his morale ("lead, don't command").
##
## Pure given the rng: reads the grid and the warriors and changes nothing
## except the man's own `order_lag` and the log.



static func choose(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		w: Warrior, leader: Warrior, all: Array[Warrior],
		log: PackedStringArray = PackedStringArray()) -> Action:
	if not w.is_active():
		return Action.idle()
	var enemies := _enemies(w, all)

	# 1. Broken men run.
	if w.broken:
		return _flee(grid, w, enemies)

	# 2. A green man slow to take up a new order keeps doing what he was: bracing.
	if w.order_lag > 0:
		w.order_lag -= 1
		return Action.brace()

	# 3. A frightened green man may ignore the order altogether.
	if w.tier == CombatTypes.Tier.GREEN and w.morale <= rules.morale_break_threshold \
			and rng.randf() < rules.green_panic_ignore_chance:
		log.append("%s freezes behind his shield" % w.display_name)
		return Action.brace()

	# 4. A reckless man charges anything close, whatever the order.
	if w.has_personality(CombatTypes.Personality.RECKLESS):
		var near := _nearest(w.pos, enemies)
		if near != null and BattleGrid.chebyshev(w.pos, near.pos) <= rules.reckless_charge_radius:
			return _break_them(grid, w, enemies, leader)

	# 5. A champion steps in to guard a beset leader.
	if w.tier == CombatTypes.Tier.CHAMPION and leader != null and leader != w and leader.is_active() \
			and leader.side == w.side and BattleGrid.chebyshev(w.pos, leader.pos) <= 2:
		var guard := _guard_leader(grid, w, leader, enemies)
		if guard != null:
			return guard

	# 7 (and 8). The heard order, with archers shooting rather than moving.
	var act := _by_order(rules, grid, w, leader, all, enemies, w.heard_order, log)

	# 6. A veteran with no move to make, and nobody to fight in front of him,
	# covers a gap beside him.
	if w.tier >= CombatTypes.Tier.VETERAN and act.kind != CombatTypes.ActionKind.MOVE \
			and act.kind != CombatTypes.ActionKind.FLEE and act.kind != CombatTypes.ActionKind.ATTACK:
		var gap := _gap_cell(grid, w, enemies)
		if gap != Vector2i(-1, -1):
			return Action.move_to(gap)
	return act


# --- Orders ----------------------------------------------------------------

static func _by_order(rules: CombatRules, grid: BattleGrid, w: Warrior,
		leader: Warrior, all: Array[Warrior], enemies: Array[Warrior],
		order: CombatTypes.Shout, log: PackedStringArray) -> Action:
	var act: Action
	var has_leader := leader != null and leader != w and leader.is_active()
	match order:
		CombatTypes.Shout.NONE:
			if w.tier == CombatTypes.Tier.GREEN:
				act = Action.brace()
			else:
				act = _hold(w, enemies, leader)
		CombatTypes.Shout.SHIELD_WALL:
			act = _form(grid, w, leader, all, enemies, false)
		CombatTypes.Shout.HOLD:
			act = _hold(w, enemies, leader)
		CombatTypes.Shout.PUSH:
			act = _push(grid, w, enemies, leader)
		CombatTypes.Shout.TO_ME:
			if has_leader and BattleGrid.chebyshev(w.pos, leader.pos) > 1:
				act = _step_toward(grid, w, leader.pos, Vector2i.ZERO)
			if act == null:
				act = _hold(w, enemies, leader)
		CombatTypes.Shout.BREAK_THEM:
			act = _break_them(grid, w, enemies, leader)
		CombatTypes.Shout.FALL_BACK:
			if w.tier <= CombatTypes.Tier.BLOODED and w.morale <= rules.fall_back_steady_morale:
				log.append("the line wavers: %s turns to run" % w.display_name)
				return _flee(grid, w, enemies)
			if has_leader and BattleGrid.chebyshev(w.pos, leader.pos) > rules.fall_back_regroup_distance:
				act = _step_toward(grid, w, leader.pos, Vector2i.ZERO)
			if act == null:
				var back := w.pos - w.facing
				if grid.is_free(back):
					act = Action.move_to(back)
				else:
					act = Action.brace()
		CombatTypes.Shout.SVINFYLKING:
			act = _form(grid, w, leader, all, enemies, true)
		_:
			act = _hold(w, enemies, leader)

	# 8. Bowmen with nobody at arm's length shoot instead of moving or waiting.
	if w.weapon == CombatTypes.Weapon.BOW and order != CombatTypes.Shout.BREAK_THEM \
			and (act.kind == CombatTypes.ActionKind.MOVE or act.kind == CombatTypes.ActionKind.BRACE or act.kind == CombatTypes.ActionKind.IDLE) \
			and _adjacent(w, enemies).is_empty():
		var mark := _nearest(w.pos, enemies)
		if mark != null and BattleGrid.chebyshev(w.pos, mark.pos) <= rules.missile_range:
			return Action.shoot(mark)
	return act


## HOLD: strike a man in front (a wounded one first), else brace toward the
## nearest enemy.
static func _hold(w: Warrior, enemies: Array[Warrior], leader: Warrior) -> Action:
	var front := _front(w, enemies)
	if not front.is_empty():
		return Action.attack(_pick_target(w, front, leader))
	var near := _nearest(w.pos, enemies)
	if near == null:
		return Action.brace()
	return Action.brace(BattleGrid.direction_to(w.pos, near.pos))


static func _push(grid: BattleGrid, w: Warrior, enemies: Array[Warrior], leader: Warrior) -> Action:
	var front := _front(w, enemies)
	if not front.is_empty():
		return Action.attack(_pick_target(w, front, leader))
	var adj := _adjacent(w, enemies)
	if not adj.is_empty():
		return Action.attack(_pick_target(w, adj, leader))
	# Drive forward means toward the enemy, not along whatever the leader
	# happened to face last; the line keeps its facing while the foe is ahead.
	var near := _nearest(w.pos, enemies)
	if near == null:
		return Action.brace()
	var toward := BattleGrid.direction_to(w.pos, near.pos)
	var line_dir := w.facing
	if leader != null and leader.is_active():
		line_dir = leader.facing
	var keep_line := BattleGrid.arc_of(w, near.pos) == CombatTypes.Arc.FRONT \
			or BattleGrid.arc_of(w, near.pos) == CombatTypes.Arc.FRONT_RIGHT
	var step := _step_toward(grid, w, near.pos, line_dir if keep_line else toward)
	if step == null:
		return Action.brace(toward)
	return step


static func _break_them(grid: BattleGrid, w: Warrior, enemies: Array[Warrior], leader: Warrior) -> Action:
	var adj := _adjacent(w, enemies)
	if not adj.is_empty():
		return Action.attack(_pick_target(w, adj, leader))
	var near := _nearest(w.pos, enemies)
	if near == null:
		return _hold(w, enemies, leader)
	var step := _step_toward(grid, w, near.pos, Vector2i.ZERO)
	if step == null:
		return Action.brace(BattleGrid.direction_to(w.pos, near.pos))
	step.new_facing = BattleGrid.direction_to(step.target_cell, near.pos)
	return step


## SHIELD_WALL (wedge false) or SVINFYLKING (wedge true): step toward this
## man's slot; once on it, hold (wall) or push (wedge).
static func _form(grid: BattleGrid, w: Warrior, leader: Warrior, all: Array[Warrior],
		enemies: Array[Warrior], wedge: bool) -> Action:
	if leader == null or leader == w or not leader.is_active() or leader.side != w.side:
		return _push(grid, w, enemies, leader) if wedge else _hold(w, enemies, leader)
	var band: Array[Warrior] = []
	for m in all:
		if m != leader and m.side == w.side and m.is_active() and not m.broken:
			band.append(m)
	var slots := Formation.wedge_slots(grid, leader, band.size()) if wedge \
			else Formation.line_slots(grid, leader, band.size())
	var plan := Formation.assign(slots, band)
	if plan.has(w) and plan[w] != w.pos:
		var step := _step_toward(grid, w, plan[w], leader.facing)
		if step != null:
			return step
		return Action.brace(leader.facing)
	if wedge:
		return _push(grid, w, enemies, leader)
	var act := _hold(w, enemies, leader)
	if act.kind == CombatTypes.ActionKind.BRACE and enemies.is_empty():
		act.new_facing = leader.facing
	return act


## CHAMPION: attack one of the enemies at the leader's side, stepping next to
## one first if he is not already. Null if the leader is not beset or there is
## no way in.
static func _guard_leader(grid: BattleGrid, w: Warrior, leader: Warrior,
		enemies: Array[Warrior]) -> Action:
	var threats := _adjacent(leader, enemies)
	if threats.size() < 2:
		return null
	var mine := _adjacent(w, threats)
	if not mine.is_empty():
		return Action.attack(_pick_target(w, mine, leader))
	var best := Vector2i(-1, -1)
	var best_score := 0
	for c in grid.neighbors(w.pos):
		if not grid.is_free(c):
			continue
		var touches := false
		for e in threats:
			if BattleGrid.chebyshev(c, e.pos) == 1:
				touches = true
				break
		if not touches:
			continue
		var score := BattleGrid.chebyshev(c, leader.pos) * 100 + (c - leader.pos).length_squared()
		if best.x < 0 or score < best_score:
			best = c
			best_score = score
	if best.x < 0:
		return null
	var foe := _nearest(best, threats)
	return Action.move_to(best, BattleGrid.direction_to(best, foe.pos))


## A free cell on w's line (left or right) that is a true gap: a friend
## stands on the far side of it and an active enemy is next to it. That is
## the space a fallen neighbour has left; the open end of a line is not a
## gap. (-1, -1) if none.
static func _gap_cell(grid: BattleGrid, w: Warrior, enemies: Array[Warrior]) -> Vector2i:
	for steps in [2, -2]:
		var side_dir := BattleGrid.rotate(w.facing, steps)
		var c := w.pos + side_dir
		if not grid.is_free(c):
			continue
		var beyond := grid.occupant(c + side_dir)
		if beyond == null or beyond.side != w.side or not beyond.is_active():
			continue
		for e in enemies:
			if BattleGrid.chebyshev(c, e.pos) == 1:
				return c
	return Vector2i(-1, -1)


## One cell directly away from the nearest enemy, or a free cell beside that
## line of flight; IDLE when hemmed in. With no enemy, away from his facing.
static func _flee(grid: BattleGrid, w: Warrior, enemies: Array[Warrior]) -> Action:
	var near := _nearest(w.pos, enemies)
	var away := -w.facing
	if near != null:
		away = BattleGrid.direction_to(near.pos, w.pos)
	for steps in [0, 1, -1]:
		var d := BattleGrid.rotate(away, steps)
		var c := w.pos + d
		if grid.is_free(c):
			var a := Action.flee(c)
			a.new_facing = d
			return a
	return Action.idle()


# --- Helpers ---------------------------------------------------------------

## A MOVE to the free neighbour that most shortens the way to `target`, or null
## if no free neighbour gets closer.
static func _step_toward(grid: BattleGrid, w: Warrior, target: Vector2i,
		facing: Vector2i) -> Action:
	var here := BattleGrid.chebyshev(w.pos, target)
	var best := Vector2i(-1, -1)
	var best_d := here
	var best_e := 0
	for d in BattleGrid.DIRS:
		var c := w.pos + d
		if not grid.is_free(c):
			continue
		var cd := BattleGrid.chebyshev(c, target)
		var ce := (target - c).length_squared()
		if cd < best_d or (cd == best_d and best.x >= 0 and ce < best_e):
			best = c
			best_d = cd
			best_e = ce
	if best.x < 0:
		return null
	return Action.move_to(best, facing)


static func _enemies(w: Warrior, all: Array[Warrior]) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for m in all:
		if m.side != w.side and m.is_active():
			out.append(m)
	return out


static func _nearest(from: Vector2i, men: Array[Warrior]) -> Warrior:
	var best: Warrior = null
	var best_d := 0
	for m in men:
		var d := BattleGrid.chebyshev(from, m.pos)
		if best == null or d < best_d or (d == best_d and m.id < best.id):
			best = m
			best_d = d
	return best


static func _adjacent(w: Warrior, men: Array[Warrior]) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for m in men:
		if BattleGrid.chebyshev(w.pos, m.pos) == 1:
			out.append(m)
	return out


## Adjacent enemies ahead of him: FRONT or FRONT_RIGHT (anything not on his
## flanks or behind).
static func _front(w: Warrior, enemies: Array[Warrior]) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for e in _adjacent(w, enemies):
		var arc := BattleGrid.arc_of(w, e.pos)
		if arc == CombatTypes.Arc.FRONT or arc == CombatTypes.Arc.FRONT_RIGHT:
			out.append(e)
	return out


## Which of several reachable enemies to strike: a Boastful man seeks the
## enemy leader or a champion; everyone prefers the worst-wounded; then the
## nearest, then the lowest id.
static func _pick_target(w: Warrior, candidates: Array[Warrior], _leader: Warrior) -> Warrior:
	var boastful := w.has_personality(CombatTypes.Personality.BOASTFUL)
	var best: Warrior = null
	var best_key := []
	for e in candidates:
		var glory := 1 if boastful and (e.is_leader or e.tier == CombatTypes.Tier.CHAMPION) else 0
		var key := [-glory, -int(e.wound), BattleGrid.chebyshev(w.pos, e.pos), e.id]
		if best == null or _less(key, best_key):
			best = e
			best_key = key
	return best


static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
