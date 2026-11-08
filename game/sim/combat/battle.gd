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
	var rr := rng.fork("round:%d" % round)

	# 1. Shouts.
	var leaders := {}
	for side in 2:
		var leader := leader_of(side)
		leaders[side] = leader
		var shout: CombatTypes.Shout = CombatTypes.Shout.NONE
		if _pending_shout.has(side):
			shout = _pending_shout[side]
			_pending_shout.erase(side)
		elif _ai.has(side) and leader != null:
			shout = (_ai[side] as LeaderAI).choose(self, side)
		_last_shout[side] = shout
		if leader != null and shout != CombatTypes.Shout.NONE:
			log.append("%s shouts: %s!" % [leader.display_name, CombatTypes.SHOUT_NAMES[shout]])
			Shouts.propagate(rr.fork("shout:%d" % side), rules, grid, leader, shout, active(side), fog, log)
			if shout == CombatTypes.Shout.TO_ME:
				Morale.rally(rules, grid, leader, warriors, log)

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
		var push := Push.resolve(rr.fork("push"), rules, grid, warriors, log)
		if push.winning_side >= 0:
			log.append("the push goes to side %d" % push.winning_side)
	# 3e. Morale.
	var broke := Morale.round_update(rr.fork("morale"), rules, grid, warriors, leaders, any_attacks, log)
	for w in broke:
		result.broken[w.side] += 1

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
	return c.x == 0 or c.y == 0 or c.x == grid.width - 1 or c.y == grid.height - 1


func _resolve_missiles(mr: SimRng, actions: Dictionary) -> void:
	for w in warriors:
		if not actions.has(w) or not w.is_active():
			continue
		var a: Action = actions[w]
		if a.kind != CombatTypes.ActionKind.SHOOT or a.target == null or not a.target.is_active():
			continue
		var r := MeleeExchange.resolve_shot(mr.fork("shot:%d" % w.id), rules, grid, w, a.target, log)
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
		if a_attacks and BattleGrid.chebyshev(a.pos, b.pos) >= 1:
			a.facing = BattleGrid.direction_to(a.pos, b.pos)
		if b_attacks and BattleGrid.chebyshev(a.pos, b.pos) >= 1:
			b.facing = BattleGrid.direction_to(b.pos, a.pos)
		var r := MeleeExchange.resolve(mr.fork(key), rules, grid, a, b, a_attacks, b_attacks, a_braced, b_braced, log)
		_after_exchange(r)


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
