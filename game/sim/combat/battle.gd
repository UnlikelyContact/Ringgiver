class_name Battle
extends RefCounted
## The battle loop: one round = shouts, simultaneous decisions, fixed beats
## (movement, missiles, melee, push, morale), end check. See
## docs/design/sim-architecture.md, "Round structure".

var rules: CombatRules
var rng: SimRng
var grid: BattleGrid
var warriors: Array[Warrior] = []
var result := BattleResult.new()
var log := PackedStringArray()
var round := 0
var fog := false
var _leaders := {}  # side -> Warrior (the sworn leader, may be down)
var _ai := {}  # side -> LeaderAI (absent = external input via set_shout)
var _pending_shout := {}  # side -> Shout set from outside for this round
var _last_shout := {}  # side -> Shout actually given
var _standing := {}  # side -> the last order given that was not NONE
var _contact_logged := {}  # side -> bool, so "in contact" is logged once per spell
var _wall_step := {}  # side -> true when the leader asks his wall to step forward this round
var _volleyed := {}  # side -> true once the wall has paused to throw its spears
var _taunted_round := {}  # side -> the last round that side was taunted
var _blows_ever := false
var _rounds_without_blow := 0
var _player_action := {}  # side -> Action for that side's leader this round (presentation hook)
## Actions chosen in the last round, Warrior -> Action (read by the view).
var last_actions := {}
## Positions after the movement beat and after the melee beat of the last
## round, Warrior -> Vector2i, so a view can animate the beats in order.
var after_movement := {}
var after_melee := {}
var _over := false


func _init(p_rules: CombatRules, seed_in: int, p_grid: BattleGrid = null) -> void:
	rules = p_rules
	rng = SimRng.new(seed_in)
	grid = p_grid if p_grid != null else BattleGrid.new()
	result.seed_value = seed_in


func add_band(band: Array[Warrior]) -> void:
	for w in band:
		warriors.append(w)
		if w.is_leader:
			_leaders[w.side] = w
	warriors.sort_custom(func(a: Warrior, b: Warrior) -> bool: return a.id < b.id)


func set_ai(side: int, ai: LeaderAI) -> void:
	_ai[side] = ai


## External (player) shout for the coming round.
func set_shout(side: int, shout: CombatTypes.Shout) -> void:
	_pending_shout[side] = shout


## The player's own man acts on this instead of Decision next round.
func set_player_action(side: int, action: Action) -> void:
	_player_action[side] = action


## The leader takes his wall one step forward this round, whatever the
## standing order: one test, everyone steps or nobody (the Advance control).
func request_wall_step(side: int) -> void:
	_wall_step[side] = true


func last_shout(side: int) -> CombatTypes.Shout:
	return _last_shout.get(side, CombatTypes.Shout.NONE)


func side_warriors(side: int) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for w in warriors:
		if w.side == side:
			out.append(w)
	return out


func active(side: int) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for w in warriors:
		if w.side == side and w.is_active():
			out.append(w)
	return out


## The order a side's men are standing under (the last shout that was given).
func standing_order(side: int) -> CombatTypes.Shout:
	return _standing.get(side, CombatTypes.Shout.NONE)


## The wall: every active, unbroken man standing with the leader, the
## leader first (BattleGrid.chain): a line that may bend a facing between
## men and two off the leader, and has broken where it bends further.
func wall_members(side: int) -> Array[Warrior]:
	return grid.chain(leader_of(side), rules.wall_link_turn, rules.wall_max_bend)


## Under Push or Fall back the wall moves as a wall: one roll against the
## wall's average chance to hear, and then it steps or nobody does. Pushing,
## a man with an enemy at arm's length holds and fights; with nobody in
## contact the line marches straight, square to each man's facing; once part
## of it is engaged the rest close on the nearest enemy, each man keeping a
## hand on a man beside him, so the line bends round the fight. Falling back
## every man steps straight back. A man whose cell is taken holds and the
## line flows past him. Men outside the wall are not touched here.
func _plan_wall(wr: SimRng, side: int, leader: Warrior) -> void:
	for w in warriors:
		if w.side == side:
			w.wall_move = Warrior.NO_WALL_MOVE
			w.wall_face = Vector2i.ZERO
	if leader == null:
		return
	var order := standing_order(side)
	if _wall_step.get(side, false):
		_wall_step.erase(side)
		if order != CombatTypes.Shout.FALL_BACK:
			order = CombatTypes.Shout.PUSH
	if order != CombatTypes.Shout.PUSH and order != CombatTypes.Shout.FALL_BACK:
		return
	var members := wall_members(side)
	if members.size() < 2:
		return
	var back := order == CombatTypes.Shout.FALL_BACK
	if not back and _wheel_toward_enemy(side, leader, members):
		_hold_wall(members)
		return
	var theirs := active(1 - side)
	var engaged := {}
	for w in members:
		if not grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			engaged[w] = true
	if not back and engaged.size() == members.size():
		if not _contact_logged.get(side, false):
			log.append("side %d's wall is in contact and holds" % side)
			_contact_logged[side] = true
		_hold_wall(members)
		return
	# A wall closing with spears to throw pauses one round at a throw's
	# distance to loose them, then comes on.
	if not back and not _volleyed.get(side, false) and engaged.is_empty():
		var spears := 0
		var in_range := false
		for w in members:
			spears += w.javelins
			for e in theirs:
				if BattleGrid.distance(w.pos, e.pos) <= rules.javelin_range:
					in_range = true
		if spears > 0 and in_range:
			_volleyed[side] = true
			log.append("%s's line halts and looses its spears" % leader.display_name)
			_hold_wall(members)
			return
	var horn := false
	for w in active(side):
		horn = horn or w.is_horn
	var targets := {}  # Warrior -> cell
	var faces := {}  # Warrior -> facing taken with the step
	var claimed := {}  # cell -> true
	var carried := {}  # a friend behind a falling-back man, stepping back with him
	# Pass one: every man's straight step, square to his own facing, by the
	# zigzag that keeps his column. All at once, so a line that marches
	# together stays together. No hex step is square to a row, so when the
	# enemy lies a little to one side the whole line takes the slant toward
	# them instead of the zigzag, and slides across as it comes on rather
	# than marching past.
	# One step for the whole wall, the leader's: straight forward (or back)
	# from the line's axis by the zigzag that keeps every man's place across
	# the line, so the shape of the line, bends and all, moves as a piece.
	# Coming on with the enemy a little to one side, the whole line takes
	# the straddling step toward them instead, and slides across as it comes.
	var lf := leader.wall_facing()
	var ax := leader.wall_axis()
	var step := BattleGrid.forward(leader.pos, ax, BattleGrid.rotate(lf, 3) if back else lf)
	if not back and not theirs.is_empty():
		var near_l := _nearest_enemy(leader.pos, theirs)
		var pair := BattleGrid.forward_pair(ax, lf)
		var other: Vector2i = pair[1] if step == pair[0] else pair[0]
		if other != step and BattleGrid.distance(leader.pos + other, near_l.pos) < BattleGrid.distance(leader.pos + step, near_l.pos):
			step = other
	for w in members:
		if engaged.has(w) and not back:
			continue
		var target: Vector2i = w.pos + step
		if back and not grid.in_bounds(target):
			# Falling back with the edge of the field at their backs: the wall retreats off it.
			for m in members:
				m.fled = true
				grid.remove(m)
				result.fled[side] += 1
			log.append("%s's wall falls back off the field, %d men" % [leader.display_name, members.size()])
			return
		var occ := grid.occupant(target)
		if back and occ != null and not members.has(occ) and occ.side == side and occ.is_active() and not occ.broken:
			var his: Vector2i = occ.pos + step
			if grid.is_free(his) and not claimed.has(his):
				carried[occ] = his
				claimed[his] = true
				occ = null
		if claimed.has(target) or not grid.in_bounds(target) or grid.terrain_at(target) == CombatTypes.Terrain.WATER \
				or (occ != null and not members.has(occ)):
			continue  # he holds, for now
		targets[w] = target
		claimed[target] = true
	if not back:
		# Nobody lets go of a man beside him: a stepper who would lose a
		# linked neighbour holds instead, until the line is consistent.
		var changed := true
		while changed:
			changed = false
			for w in targets.keys():
				if not _keeps_a_hand_on(targets[w], w.facing, w, members, targets, faces):
					claimed.erase(targets[w])
					targets.erase(w)
					changed = true
		# Pass two: men still standing, from the ends of the line inward, try
		# any step that brings them nearer the closest enemy without letting
		# go of anyone, so a wing swings forward round a held or blocked man
		# like a door on its hinge, and the line bends round the fight. A man
		# who steps this way turns toward the enemy, a facing at most.
		if not theirs.is_empty():
			var outer := members.duplicate()
			outer.reverse()
			changed = true
			while changed:
				changed = false
				for w in outer:
					if targets.has(w) or engaged.has(w):
						continue
					var near := _nearest_enemy(w.pos, theirs)
					var now_d := BattleGrid.distance(w.pos, near.pos)
					var best := Vector2i(Warrior.NO_WALL_MOVE)
					var best_face := Vector2i.ZERO
					var best_d := now_d
					for c in grid.neighbors(w.pos):
						if claimed.has(c) or not grid.is_free(c):
							continue
						var d := BattleGrid.distance(c, near.pos)
						if d >= best_d:
							continue
						# The facing he takes there: toward the enemy for choice,
						# else a facing either way, but always one that keeps the
						# men beside him at his shoulder. No such facing: no step.
						var face := _facing_that_keeps_links(c, w, BattleGrid.direction_to(c, near.pos), members, targets, faces)
						if face == Vector2i.ZERO:
							continue
						best_d = d
						best = c
						best_face = face
					if best == Vector2i(Warrior.NO_WALL_MOVE):
						continue
					targets[w] = best
					claimed[best] = true
					faces[w] = best_face
					changed = true
	if targets.is_empty():
		if not _contact_logged.get(side, false):
			log.append("%s's wall cannot step: every man is held or blocked" % leader.display_name)
			_contact_logged[side] = true
		_hold_wall(members)
		return
	var chance_sum := 0.0
	var tier_sum := 0
	for w in members:
		chance_sum += 1.0 if w == leader else Shouts.hear_chance(rules, BattleGrid.distance(w.pos, leader.pos), w.wits, horn, fog)
		tier_sum += int(w.tier)
	var tier_avg := int(round(float(tier_sum) / members.size()))
	var chance: float = chance_sum / members.size() * rules.wall_test_tier_factor[clampi(tier_avg, 0, 3)]
	if wr.randf() > chance:
		log.append("%s's line hesitates (%d%% to move as one)" % [leader.display_name, int(round(chance * 100))])
		_hold_wall(members)
		return
	_contact_logged[side] = false
	_hold_wall(members)
	for w in carried:
		w.wall_move = carried[w]
	# The second rank goes with the line: a friend standing straight behind
	# a stepping man, not in the wall himself, takes the same step if the
	# cell is his for the taking.
	if not back:
		var back_facing := BattleGrid.rotate(leader.wall_facing(), 3)
		var ax2 := leader.wall_axis()
		for w in targets:
			var m := grid.occupant(w.pos + BattleGrid.forward(w.pos, ax2, back_facing))
			if m == null or m.side != side or members.has(m) or not m.is_active() or m.broken or m.role == CombatTypes.Role.MISSILE:
				continue
			var his: Vector2i = m.pos + (targets[w] - w.pos)
			if his == w.pos or (grid.is_free(his) and not claimed.has(his)):
				m.wall_move = his
				claimed[his] = true
	var stepped := 0
	for w in targets:
		# The exceptions to moving as one: a man who falls, and a man whose
		# nerve breaks. Falling back, a green or blooded man with little
		# heart left wavers and runs instead of stepping back with the wall.
		if back and w != leader and w.tier <= CombatTypes.Tier.BLOODED and w.morale <= rules.fall_back_steady_morale:
			log.append("%s's nerve goes as the wall falls back" % w.display_name)
			w.wall_move = Warrior.NO_WALL_MOVE
			continue
		w.wall_move = targets[w]
		w.wall_face = faces.get(w, Vector2i.ZERO)
		stepped += 1
		if back:
			w.morale = clampi(w.morale + rules.fall_back_morale, 0, 10)
	var held := members.size() - stepped
	if held == 0:
		log.append("%s's wall steps %s as one, %d men" % [leader.display_name, "back" if back else "forward", stepped])
	else:
		log.append("%s's wall %s, %d men step and %d hold" % [leader.display_name, "gives ground" if back else "closes", stepped, held])


## The nearest active enemy to a cell (never null when `theirs` is not empty).
func _nearest_enemy(from: Vector2i, theirs: Array[Warrior]) -> Warrior:
	var best: Warrior = null
	var best_d := 999
	for e in theirs:
		var d := BattleGrid.distance(from, e.pos)
		if d < best_d or (d == best_d and e.id < best.id):
			best = e
			best_d = d
	return best


## Would a man stepping to `c` and facing `face` still be linked to every
## man now linked to him: each such member where he stays, or where he is
## stepping to, with the facing he takes there.
func _keeps_a_hand_on(c: Vector2i, face: Vector2i, w: Warrior, members: Array[Warrior],
		targets: Dictionary, faces: Dictionary) -> bool:
	# The wall is rooted on the leader's wall facing, whichever way he turns.
	var leader := leader_of(w.side)
	if w == leader:
		face = w.wall_facing()
	for m in members:
		if m == w or BattleGrid.distance(w.pos, m.pos) != 1:
			continue
		var at: Vector2i = targets[m] if targets.has(m) else m.pos
		# A wall-mate at arm's length stays at arm's length, so nobody is
		# left behind (not even a man turned to strike); a linked one stays linked.
		if BattleGrid.distance(c, at) != 1:
			return false
		var was_linked := BattleGrid.linked_at(w.pos, w.wall_facing() if w == leader else w.facing, m.pos,
				m.wall_facing() if m == leader else m.facing, rules.wall_link_turn)
		var m_face: Vector2i = m.wall_facing() if m == leader else faces.get(m, m.facing)
		if was_linked and not BattleGrid.linked_at(c, face, at, m_face, rules.wall_link_turn):
			return false
	return true


## The facing a man takes stepping to `c`: `want` if it is within a facing
## of his own and keeps his links; else the facing a step either way of his
## own that does, nearer `want` first; else his own; ZERO if nothing keeps
## them.
func _facing_that_keeps_links(c: Vector2i, w: Warrior, want: Vector2i, members: Array[Warrior],
		targets: Dictionary, faces: Dictionary) -> Vector2i:
	var turn := posmod(BattleGrid.dir_index(want) - BattleGrid.dir_index(w.facing), 6)
	var toward := 1 if turn <= 3 else -1
	var tries: Array[Vector2i] = []
	if w == leader_of(w.side):
		# The leader sets the wall's facing and does not turn off it to bend.
		return w.wall_facing() if _keeps_a_hand_on(c, w.wall_facing(), w, members, targets, faces) else Vector2i.ZERO
	if BattleGrid.facing_steps(want, w.facing) <= rules.wall_link_turn:
		tries.append(want)
	for f in [w.facing, BattleGrid.rotate(w.facing, toward), BattleGrid.rotate(w.facing, -toward)]:
		if not tries.has(f):
			tries.append(f)
	for f in tries:
		if _keeps_a_hand_on(c, f, w, members, targets, faces):
			return f
	return Vector2i.ZERO


## A wall pushing with the enemy two or more facings off its front (beside or
## behind it) wheels one facing toward them instead of marching away. Not
## while in contact: wheeling in a melee is chaos. True if it wheeled.
func _wheel_toward_enemy(side: int, leader: Warrior, members: Array[Warrior]) -> bool:
	var theirs := active(1 - side)
	if theirs.is_empty():
		return false
	for w in members:
		if not grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			return false
	var sum := Vector2.ZERO
	for e in theirs:
		sum += BattleGrid.to_cart(Vector2(e.pos))
	var want := BattleGrid.state_toward(sum / theirs.size() - BattleGrid.to_cart(Vector2(leader.pos)))
	var have_i := BattleGrid.state_of(leader.wall_axis(), leader.wall_facing())
	var want_i := BattleGrid.state_of(want[0], want[1])
	var diff := posmod(want_i - have_i, BattleGrid.STATES.size())
	var n := BattleGrid.STATES.size()
	if diff < rules.wall_wheel_min_steps or diff > n - rules.wall_wheel_min_steps:
		return false
	var step := 1 if diff <= n / 2 else -1
	leader.wheel_wall(step)
	log.append("%s's line wheels %s to face the enemy" % [leader.display_name, "right" if step == 1 else "left"])
	return true


## Marks a wall's men to stand fast this round (wall_move = own cell).
func _hold_wall(members: Array[Warrior]) -> void:
	for w in members:
		w.wall_move = w.pos


## The man giving orders for a side: the sworn leader while he stands, else
## the senior active man (highest tier, then id). Null if nobody stands.
func leader_of(side: int) -> Warrior:
	var sworn: Warrior = _leaders.get(side, null)
	if sworn != null and sworn.is_active() and not sworn.broken:
		return sworn
	var best: Warrior = null
	for w in active(side):
		if w.broken:
			continue
		if best == null or w.tier > best.tier:
			best = w
	return best


func is_over() -> bool:
	return _over


func run(max_rounds := -1) -> BattleResult:
	var limit := rules.max_rounds if max_rounds < 0 else max_rounds
	if round == 0:
		for side in 2:
			result.started[side] = active(side).size()
	while not _over and round < limit:
		run_round()
	if not _over:
		_finish(-1, "the light fails; both sides draw off")
	return result


func run_round() -> void:
	if _over:
		return
	round += 1
	log.append("--- round %d ---" % round)
	var round_log_start := log.size()
	var rr := rng.fork("round:%d" % round)

	# 1. Shouts. A leader who turned to strike last round faces his wall again.
	var leaders := {}
	for side in 2:
		var leader := leader_of(side)
		leaders[side] = leader
		if leader != null and leader.line_facing != Vector2i.ZERO:
			leader.facing = leader.line_facing
		_dress_line(side, leader)
		_relieve_shieldless(side, leader)
		var shout: CombatTypes.Shout = CombatTypes.Shout.NONE
		if _pending_shout.has(side):
			shout = _pending_shout[side]
			_pending_shout.erase(side)
		elif _ai.has(side) and leader != null:
			shout = (_ai[side] as LeaderAI).choose(self, side)
		_last_shout[side] = shout
		if shout == CombatTypes.Shout.TAUNT:
			# A jeer across the field, not an order: the standing order holds.
			if leader != null:
				_taunt(side, leader)
			continue
		if shout != CombatTypes.Shout.NONE:
			_standing[side] = shout
		if leader != null and shout != CombatTypes.Shout.NONE:
			log.append("%s shouts: %s!" % [leader.display_name, CombatTypes.SHOUT_NAMES[shout]])
			Shouts.propagate(rr.fork("shout:%d" % side), rules, grid, leader, shout, active(side), fog, log)
			if shout == CombatTypes.Shout.TO_ME:
				Morale.rally(rules, grid, leader, warriors, log)

	# 1b. The walls decide as units: one test per wall, everyone steps or nobody.
	for side in 2:
		_plan_wall(rr.fork("wall:%d" % side), side, leaders[side])

	# 2. Simultaneous decisions. If the player's man is stepping somewhere,
	# his men form on where he is going: the line follows its leader.
	var actions := {}
	var any_attacks := false
	var intent_leader: Warrior = null
	var intent_from := Vector2i.ZERO
	for side in _player_action:
		var pa: Action = _player_action[side]
		var l: Warrior = _leaders.get(side, null)
		if pa != null and pa.kind == CombatTypes.ActionKind.MOVE and l != null and l.is_active() \
				and grid.is_free(pa.target_cell) and BattleGrid.chebyshev(l.pos, pa.target_cell) == 1:
			intent_leader = l
			intent_from = l.pos
			grid.place(l, pa.target_cell)
			if pa.new_facing != Vector2i.ZERO:
				l.facing = pa.new_facing
	for w in warriors:
		if not w.is_active():
			continue
		var leader: Warrior = leaders[w.side]
		if leader == null:
			leader = _leaders.get(w.side, w)
		var a: Action
		if w.is_leader and _player_action.has(w.side) and _player_action[w.side] != null:
			a = _player_action[w.side]
			_player_action.erase(w.side)
			if a.kind == CombatTypes.ActionKind.ATTACK and (a.target == null or not a.target.is_active()
					or BattleGrid.chebyshev(w.pos, a.target.pos) > 1):
				a = Decision.choose(rr.fork("decide:%d" % w.id), rules, grid, w, leader, warriors)
		else:
			a = Decision.choose(rr.fork("decide:%d" % w.id), rules, grid, w, leader, warriors)
		actions[w] = a
		if a.kind == CombatTypes.ActionKind.ATTACK or a.kind == CombatTypes.ActionKind.SHOOT:
			any_attacks = true
	_log_action_counts(actions)
	last_actions = actions
	if intent_leader != null:
		grid.place(intent_leader, intent_from)

	# 3a. Movement.
	_resolve_movement(rr.fork("move"), actions)
	after_movement = _positions()
	# 3b. Missiles.
	_resolve_missiles(rr.fork("missiles"), actions)
	# 3c. Melee.
	_resolve_melee(rr.fork("melee"), actions)
	after_melee = _positions()
	# 3d. The push: a heave happens only when a leader has called for it.
	if _push_called():
		var may_advance := {}
		var wall_facing := {}
		var wall_axis := {}
		var driving := {0: false, 1: false}
		for side in 2:
			# Only a line driving forward throws the enemy back and follows
			# up; a line told to hold stops the push where it stands.
			var order := standing_order(side)
			if order != CombatTypes.Shout.PUSH and order != CombatTypes.Shout.BREAK_THEM and order != CombatTypes.Shout.SVINFYLKING:
				continue
			driving[side] = true
			for w in wall_members(side):
				may_advance[w] = true
			var l := leader_of(side)
			if l != null:
				wall_facing[side] = l.wall_facing()
				wall_axis[side] = l.wall_axis()
		var push := Push.resolve(rr.fork("push"), rules, grid, warriors, log, may_advance, wall_facing, driving, wall_axis)
		for w in push.driven_off:
			result.fled[w.side] += 1
		if push.winning_side >= 0:
			log.append("the push goes to side %d" % push.winning_side)
	# 3e. Morale.
	var broke := Morale.round_update(rr.fork("morale"), rules, grid, warriors, leaders, any_attacks, log)
	for w in broke:
		result.broken[w.side] += 1

	# Blows landed this round?
	var any_blow := false
	for i in range(round_log_start, log.size()):
		var line := log[i]
		if line.contains(" beats ") and not line.contains("glancing") and line.begins_with(line.split(" beats ")[0]):
			any_blow = true
			break
		if (line.contains(" shoots ") or line.contains(" spears ")) and not line.contains("misses"):
			any_blow = true  # an arrow or a thrown spear that bit is a blow too
			break
	_rounds_without_blow = 0 if any_blow else _rounds_without_blow + 1
	_blows_ever = _blows_ever or any_blow

	# 4. End check.
	for side in 2:
		var standing := 0
		for w in active(side):
			if not w.broken:
				standing += 1
		if standing == 0:
			_finish(1 - side, "side %d has no one left standing" % side)
			return
	for side in 2:
		if last_shout(side) == CombatTypes.Shout.FALL_BACK and _withdrawn(side):
			_finish(1 - side, "side %d draws off and leaves the field" % side)
			return
	if _rounds_without_blow >= rules.retreat_stall_rounds:
		var retreating := []
		for side in 2:
			if standing_order(side) == CombatTypes.Shout.FALL_BACK:
				retreating.append(side)
		if retreating.size() == 1:
			_finish(1 - retreating[0], "side %d keeps giving ground and quits the field" % retreating[0])
			return
		if retreating.size() == 2:
			_finish(-1, "both sides draw off")
			return
	# Nobody has struck a blow for a while after the lines met: the fight is
	# over. The side with clearly fewer men standing has had enough and quits;
	# otherwise both draw off.
	if _blows_ever and _rounds_without_blow >= rules.stall_rounds:
		var standing := [0, 0]
		for side in 2:
			for w in active(side):
				if not w.broken:
					standing[side] += 1
		for side in 2:
			if float(standing[side]) < float(standing[1 - side]) * rules.stall_quit_fraction:
				_finish(1 - side, "side %d has had enough and quits the field" % side)
				return
		_finish(-1, "neither side will close again; both draw off")
		return


func _push_called() -> bool:
	for side in 2:
		var s := last_shout(side)
		if s == CombatTypes.Shout.PUSH or s == CombatTypes.Shout.SVINFYLKING:
			return true
	return false


## True when no active man of `side` is within withdraw_distance of an enemy.
func _withdrawn(side: int) -> bool:
	var foes := active(1 - side)
	if foes.is_empty():
		return false
	for w in active(side):
		for e in foes:
			if BattleGrid.chebyshev(w.pos, e.pos) < rules.withdraw_distance:
				return false
	return true


## Every man with a friend beside him along the wall's axis faces the wall's
## facing, so a man who turned to strike or to watch an enemy is back in
## the line next round. A lone man keeps whatever way he was facing.
## The round a side was last taunted, or -99.
func taunted_round(side: int) -> int:
	return _taunted_round.get(side, -99)


## A leader jeers at the enemy. Every enemy in earshot who is standing
## about (his side not driving forward, and none of ours at arm's length)
## loses heart, never below the break threshold plus one; Steady and Grim
## men do not hear it. Men who are coming on answer with their feet and
## are not shamed. Our own men in earshot take heart from the jeering.
func _taunt(side: int, leader: Warrior) -> void:
	var foe := 1 - side
	var their_order := standing_order(foe)
	var coming_on := their_order == CombatTypes.Shout.PUSH or their_order == CombatTypes.Shout.BREAK_THEM \
			or their_order == CombatTypes.Shout.SVINFYLKING
	_taunted_round[foe] = round
	log.append("%s taunts the enemy across the field" % leader.display_name)
	var shamed := 0
	for e in active(foe):
		if e.broken or BattleGrid.distance(e.pos, leader.pos) > rules.taunt_range:
			continue
		if coming_on or not grid.adjacent_warriors(e.pos, side).is_empty():
			continue
		if e.has_personality(CombatTypes.Personality.STEADY) or e.has_personality(CombatTypes.Personality.GRIM):
			continue
		var floor_m := rules.morale_break_threshold + 1
		if e.morale > floor_m:
			e.morale = maxi(floor_m, e.morale + rules.taunt_morale)
			shamed += 1
	for m in active(side):
		if not m.broken and BattleGrid.distance(m.pos, leader.pos) <= rules.taunt_range:
			m.morale = clampi(m.morale + rules.taunt_cheer, 0, 10)
	if coming_on:
		log.append("they answer with their feet")
	elif shamed > 0:
		log.append("%d of them stand and take it, and like it less" % shamed)
	else:
		log.append("nobody within earshot stands for it")


## Relief: a man in the line whose shield is gone changes places with a
## shielded man standing straight behind him. The fresh shield steps up
## into the line and the shieldless man drops back, where his spear still
## reaches over the shoulder. The wall closes itself. Once per pair a round.
func _relieve_shieldless(side: int, leader: Warrior) -> void:
	if leader == null:
		return
	var back_facing := BattleGrid.rotate(leader.wall_facing(), 3)
	var ax := leader.wall_axis()
	var swapped := {}
	for w in wall_members(side):
		if swapped.has(w) or w.shield_usable() or w.role == CombatTypes.Role.MISSILE or w == leader:
			continue
		var relief := grid.occupant(w.pos + BattleGrid.forward(w.pos, ax, back_facing))
		if relief == null or swapped.has(relief) or relief.side != side or not relief.is_active() or relief.broken \
				or not relief.shield_usable() or relief.role == CombatTypes.Role.MISSILE:
			continue
		var front_cell := w.pos
		var back_cell := relief.pos
		grid.remove(w)
		grid.remove(relief)
		grid.place(relief, front_cell)
		grid.place(w, back_cell)
		relief.facing = w.facing
		relief.spend_breath(rules.breath_cost_move)
		w.spend_breath(rules.breath_cost_move)
		swapped[w] = true
		swapped[relief] = true
		log.append("%s's shield is gone: %s steps up into the line and he drops back behind" % [w.display_name, relief.display_name])


## Each man in the wall minds his own front. With an enemy before him he
## keeps his facing; with one at his flank and none before him he turns a
## facing toward him, hinging the line; with nobody at arm's length he
## dresses a facing a round back toward the wall's facing, so a wheel runs
## along the line over rounds and a bend straightens only once the fight
## there is over.
func _dress_line(side: int, leader: Warrior) -> void:
	if leader == null:
		return
	var wf := leader.wall_facing()
	# A man who turned off the front to strike turns back to his wall's
	# facing the moment nobody is at arm's length, and so rejoins it.
	for w in active(side):
		if w.turned_to_strike and w != leader and not w.broken and grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			w.facing = wf
			w.turned_to_strike = false
	for w in wall_members(side):
		if w == leader:
			continue
		var front := false
		var right := false
		var left := false
		for e in grid.adjacent_warriors(w.pos, 1 - side):
			if not e.is_active():
				continue
			match BattleGrid.arc_of(w, e.pos):
				CombatTypes.Arc.FRONT, CombatTypes.Arc.FRONT_RIGHT:
					front = true
				CombatTypes.Arc.RIGHT:
					right = true
				CombatTypes.Arc.LEFT:
					left = true
		if front or (right and left):
			continue
		if right:
			w.facing = BattleGrid.rotate(w.facing, 1)
		elif left:
			w.facing = BattleGrid.rotate(w.facing, -1)
		elif w.facing != wf and grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			var d := posmod(BattleGrid.dir_index(wf) - BattleGrid.dir_index(w.facing), 6)
			var dressed := BattleGrid.rotate(w.facing, 1 if d <= 3 else -1)
			# Only if that keeps the men beside him at his shoulder: a hinge
			# stays hinged while the line still needs it.
			var keeps := true
			for n in grid.line_neighbors(w, rules.wall_link_turn):
				if not BattleGrid.linked_at(w.pos, dressed, n.pos, n.facing, rules.wall_link_turn):
					keeps = false
			if keeps:
				w.facing = dressed


func _log_action_counts(actions: Dictionary) -> void:
	var counts := [0, 0, 0, 0, 0, 0]
	for w in actions:
		counts[(actions[w] as Action).kind] += 1
	log.append("actions: brace %d move %d attack %d shoot %d flee %d idle %d" % counts)


func _positions() -> Dictionary:
	var out := {}
	for w in warriors:
		out[w] = w.pos
	return out


func _resolve_movement(mr: SimRng, actions: Dictionary) -> void:
	# Facing chosen with any action (a brace toward the nearest enemy, say)
	# applies now; attackers turn toward their target in the melee beat.
	for w in actions:
		var a: Action = actions[w]
		if a.new_facing != Vector2i.ZERO and a.kind != CombatTypes.ActionKind.MOVE and a.kind != CombatTypes.ActionKind.FLEE:
			w.facing = a.new_facing
	var movers: Array[Warrior] = []
	for w in warriors:
		if not actions.has(w):
			continue
		var a: Action = actions[w]
		if a.kind == CombatTypes.ActionKind.MOVE or a.kind == CombatTypes.ActionKind.FLEE:
			movers.append(w)
	# Contested cells: highest Might + 2d6 takes it.
	var claims := {}  # cell -> Array[Warrior]
	for w in movers:
		var cell: Vector2i = (actions[w] as Action).target_cell
		if not claims.has(cell):
			claims[cell] = []
		claims[cell].append(w)
	var winners := {}
	for cell in claims:
		var list: Array = claims[cell]
		if list.size() == 1:
			winners[list[0]] = true
			continue
		var best: Warrior = null
		var best_roll := -1
		for w in list:
			var roll: int = w.might + mr.roll_2d6()
			if roll > best_roll or (roll == best_roll and w.id < best.id):
				best = w
				best_roll = roll
		winners[best] = true
		log.append("%s wins the scramble for %s" % [best.display_name, cell])
	# A wall steps as one: lift every carried man first so they never block
	# each other, then set them down on their targets.
	var carried: Array[Warrior] = []
	for w in movers:
		if w.wall_move != Warrior.NO_WALL_MOVE and (actions[w] as Action).target_cell == w.wall_move:
			carried.append(w)
	for w in carried:
		grid.remove(w)
	for w in carried:
		if not grid.place(w, w.wall_move):
			grid.place(w, w.pos)
		w.spend_breath(rules.breath_cost_move)
		var ca: Action = actions[w]
		if ca.new_facing != Vector2i.ZERO:
			w.facing = ca.new_facing
		winners.erase(w)
	for w in movers:
		var a: Action = actions[w]
		if not winners.has(w):
			continue
		if a.kind == CombatTypes.ActionKind.FLEE:
			if not grid.in_bounds(a.target_cell) or _on_edge(w.pos):
				grid.remove(w)
				w.fled = true
				result.fled[w.side] += 1
				log.append("%s flees the field" % w.display_name)
				continue
		if grid.is_free(a.target_cell) and BattleGrid.chebyshev(w.pos, a.target_cell) == 1:
			grid.place(w, a.target_cell)
			w.spend_breath(rules.breath_cost_move)
			if grid.terrain_at(a.target_cell) == CombatTypes.Terrain.MUD:
				w.spend_breath(rules.breath_cost_move)
		if a.new_facing != Vector2i.ZERO:
			w.facing = a.new_facing


func _on_edge(c: Vector2i) -> bool:
	return grid.is_edge(c)


func _resolve_missiles(mr: SimRng, actions: Dictionary) -> void:
	for w in warriors:
		if not actions.has(w) or not w.is_active():
			continue
		var a: Action = actions[w]
		if a.kind != CombatTypes.ActionKind.SHOOT or a.target == null or not a.target.is_active():
			continue
		var r := MeleeExchange.resolve_shot(mr.fork("shot:%d" % w.id), rules, grid, w, a.target, log, a.thrown)
		_after_exchange(r)


func _resolve_melee(mr: SimRng, actions: Dictionary) -> void:
	# Collect pairs with at least one ATTACK between them, deterministic order.
	var pairs := {}  # "lo:hi" -> [a, b]
	var keys: Array[String] = []
	for w in warriors:
		if not actions.has(w) or not w.is_active():
			continue
		var a: Action = actions[w]
		if a.kind != CombatTypes.ActionKind.ATTACK or a.target == null:
			continue
		var t := a.target
		if not t.is_active():
			continue
		var lo := w if w.id < t.id else t
		var hi := t if w.id < t.id else w
		var key := "%d:%d" % [lo.id, hi.id]
		if not pairs.has(key):
			pairs[key] = [lo, hi]
			keys.append(key)
	keys.sort()
	for key in keys:
		var a: Warrior = pairs[key][0]
		var b: Warrior = pairs[key][1]
		if not a.is_active() or not b.is_active():
			continue
		var aa: Action = actions.get(a, Action.idle())
		var ba: Action = actions.get(b, Action.idle())
		var a_attacks := aa.kind == CombatTypes.ActionKind.ATTACK and aa.target == b
		var b_attacks := ba.kind == CombatTypes.ActionKind.ATTACK and ba.target == a
		var a_braced := aa.kind == CombatTypes.ActionKind.BRACE
		var b_braced := ba.kind == CombatTypes.ActionKind.BRACE
		# A man turns to strike only if his target is not already ahead of him;
		# turning inside a wall would unlock it for the push that follows.
		if a_attacks and not _ahead_of(a, b.pos):
			a.facing = BattleGrid.direction_to(a.pos, b.pos)
			a.turned_to_strike = true
		if b_attacks and not _ahead_of(b, a.pos):
			b.facing = BattleGrid.direction_to(b.pos, a.pos)
			b.turned_to_strike = true
		var r := MeleeExchange.resolve(mr.fork(key), rules, grid, a, b, a_attacks, b_attacks, a_braced, b_braced, log)
		_after_exchange(r)


static func _ahead_of(w: Warrior, target: Vector2i) -> bool:
	var arc := BattleGrid.arc_of(w, target)
	return arc == CombatTypes.Arc.FRONT or arc == CombatTypes.Arc.FRONT_RIGHT


func _after_exchange(r: ExchangeResult) -> void:
	if r == null:
		return
	if r.shove_to != Vector2i(-1, -1) and r.loser != null and grid.is_free(r.shove_to):
		grid.place(r.loser, r.shove_to)
	if r.went_down and r.loser != null:
		grid.remove(r.loser)
		result.downed[r.loser.side] += 1
		Morale.on_down(rules, grid, r.loser, warriors, log)


func _finish(winner: int, why: String) -> void:
	_over = true
	result.winner = winner
	result.rounds = round
	log.append("=== %s ===" % why)
	var fr := rng.fork("fate")
	for w in warriors:
		if w.is_down():
			var f := Fate.roll(fr.fork("fate:%d" % w.id), rules, w)
			match f:
				CombatTypes.Fate.DEAD:
					result.dead[w.side] += 1
					log.append("%s dies of his wounds" % w.display_name)
				CombatTypes.Fate.MAIMED:
					result.maimed[w.side] += 1
					log.append("%s lives, maimed" % w.display_name)
				_:
					log.append("%s will recover" % w.display_name)
	result.log = log
