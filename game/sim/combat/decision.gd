class_name Decision
extends RefCounted
## What one man does this round: a weighed choice among the things he could
## do, where what he sees depends on his experience tier and how he weighs
## it on his personality ("lead, don't command"). See sim-architecture.md,
## "Decision model".
##
## The rules come first and are not judgement: a broken man runs; a man
## carried by his wall goes with it (standing, he still picks whom to strike
## or whether to throw); a green man slow to take up an order braces; a
## frightened green man may freeze. Then the options: what the order says
## (ORDER: the plain default), and the alternatives his eyes and his nature
## offer him (charge, cover the leader, close a gap, drop back hurt, face a
## flanker, throw early, brace for a rush, loot, step out to be seen, go for
## a hurt man, make for the objective, run). Each is scored from
## considerations whose weights live in CombatRules (dm_*); the best wins,
## ties going to the earlier option in Opt order. A man who does something
## other than the plain default says why in `last_reason` and the log.
##
## Pure given the rng: reads the grid and the warriors and changes nothing
## except the man's own `order_lag`, `last_reason`, `last_option`, `looted`
## and the log.

## The options a man weighs, in tie order.
enum Opt { ORDER, THROW, BRACE_FOR_CHARGE, FILL_GAP, FACE_FLANK, DROP_BACK, COVER_LEADER,
	GIVE_GROUND, CHARGE, LOOT, STEP_OUT, GO_FOR_WOUNDED, OBJECTIVE, RUN }
const OPT_NAMES := ["order", "throw early", "brace for charge", "fill gap", "face flank", "drop back",
	"cover leader", "give ground", "charge", "loot", "step out", "go for wounded", "make for objective", "lose heart"]
## Names for what a man did when it was his order's plain default, by ActionKind.
const PLAIN_NAMES := ["hold", "step", "strike", "shoot", "run", "idle"]


## One thing a man could do, with how much he wants to.
class Option:
	var kind: int
	var score: float
	var action: Action
	var reason: String

	func _init(p_kind: int, p_score: float, p_action: Action, p_reason := "") -> void:
		kind = p_kind
		score = p_score
		action = p_action
		reason = p_reason


## What one man has in his head while he decides.
class Mind:
	var rules: CombatRules
	var grid: BattleGrid
	var w: Warrior
	var leader: Warrior
	var all: Array[Warrior]
	var enemies: Array[Warrior]
	var objective: Objective
	var blur: SimRng
	## Why a weighed pick of a mark differs from the plain one ("" if it does not).
	var note := ""
	## Log lines that stand only if he follows his order (the wavering line).
	var pending := PackedStringArray()

	## A green man's weights are blurred: a small deterministic jitter.
	func jitter() -> float:
		if w.tier != CombatTypes.Tier.GREEN:
			return 0.0
		return (blur.randf() - 0.5) * rules.dm_green_blur

	func sees_neighbours() -> bool:
		return w.tier >= CombatTypes.Tier.BLOODED

	func sees_flank() -> bool:
		return w.tier >= CombatTypes.Tier.VETERAN

	func reads_intent() -> bool:
		return w.tier >= CombatTypes.Tier.CHAMPION

	func has_leader() -> bool:
		return leader != null and leader != w and leader.is_active() and leader.side == w.side


static func choose(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		w: Warrior, leader: Warrior, all: Array[Warrior],
		log: PackedStringArray = PackedStringArray(), objective: Objective = null) -> Action:
	w.last_reason = ""
	w.last_option = ""
	if not w.is_active():
		w.last_option = "idle"
		return Action.idle()
	var m := Mind.new()
	m.rules = rules
	m.grid = grid
	m.w = w
	m.leader = leader
	m.all = all
	m.enemies = _enemies(w, all)
	m.objective = objective
	m.blur = rng.fork("blur")

	# 1. Broken men run.
	if w.broken:
		w.last_option = "broken"
		return _flee(grid, w, m.enemies)

	# 1b. A man standing in a wall that is moving as one goes with it; the
	# wall's single test has already been made. Standing, he still picks his
	# mark, or throws.
	if w.wall_move != Warrior.NO_WALL_MOVE:
		if w.wall_move == w.pos:
			var foe := _front_or_beside(m)
			if foe != null:
				return _finish(m, log, Option.new(Opt.ORDER, 0.0, Action.attack(foe), m.note))
			var volley := _throw(rules, grid, w, m.enemies)
			if volley != null:
				return _finish(m, log, Option.new(Opt.ORDER, 0.0, volley))
			return _finish(m, log, Option.new(Opt.ORDER, 0.0, Action.brace(w.facing)))  # the wall stands fast
		w.last_option = "with wall"
		return Action.move_to(w.wall_move, w.wall_face if w.wall_face != Vector2i.ZERO else w.facing)

	# 2. A green man slow to take up a new order keeps doing what he was: bracing.
	if w.order_lag > 0:
		w.order_lag -= 1
		w.last_option = "hold"
		return Action.brace()

	# 3. A frightened green man may ignore the order altogether.
	if w.tier == CombatTypes.Tier.GREEN and w.morale <= rules.morale_break_threshold \
			and rng.randf() < rules.green_panic_ignore_chance:
		var froze := "%s freezes behind his shield" % w.display_name
		log.append(froze)
		w.last_reason = froze
		w.last_option = "freeze"
		return Action.brace()

	# 4. The weighed choice.
	var order := w.heard_order
	var copied_from := _copied_order(m)
	if copied_from != null:
		order = copied_from.heard_order
	var opts: Array[Option] = []
	m.note = ""
	var plain := _by_order(m, order)
	var why := m.note
	if copied_from != null:
		why = "%s missed the shout and does as %s does" % [_nm(w), _nm(copied_from)]
	var order_score := rules.dm_order + _active_bonus(rules, plain)
	if plain.kind == CombatTypes.ActionKind.BRACE and (w.has_personality(CombatTypes.Personality.STEADY) \
			or w.has_personality(CombatTypes.Personality.GRIM)):
		order_score += rules.dm_steady_hold
	if plain.kind == CombatTypes.ActionKind.ATTACK and w.has_personality(CombatTypes.Personality.RECKLESS):
		order_score += rules.dm_reckless_strike
	if w.has_personality(CombatTypes.Personality.SUPERSTITIOUS) and _omen(m) < 0:
		order_score -= rules.dm_omen_order  # the heart has gone out of him
	opts.append(Option.new(Opt.ORDER, order_score + m.jitter(), plain, why))
	_alternatives(m, order, plain, opts)

	var best: Option = opts[0]
	for o in opts:
		if o.score > best.score or (o.score == best.score and o.kind < best.kind):
			best = o
	if best.kind == Opt.ORDER:
		for line in m.pending:
			log.append(line)
	return _finish(m, log, best)


## Records what he chose and why, and hands back the action.
static func _finish(m: Mind, log: PackedStringArray, o: Option) -> Action:
	var w := m.w
	if o.kind == Opt.ORDER:
		if o.action.kind == CombatTypes.ActionKind.SHOOT and o.action.thrown:
			w.last_option = "throw"
		else:
			w.last_option = PLAIN_NAMES[o.action.kind]
	else:
		w.last_option = OPT_NAMES[o.kind]
	if o.reason != "":
		w.last_reason = o.reason
		log.append(o.reason)
	return o.action


## The bonus doing his order earns when it means doing something now: a
## step, a blow, a run. Bracing and shooting earn none, so a close gap or a
## throw outbids them.
static func _active_bonus(rules: CombatRules, a: Action) -> float:
	return 0.0 if a.kind == CombatTypes.ActionKind.BRACE or a.kind == CombatTypes.ActionKind.SHOOT \
			or a.kind == CombatTypes.ActionKind.IDLE else rules.dm_order_active


## How the order he is acting on bears on an option: a holding order
## weighs against leaving his place, a driving one for going forward,
## falling back for dropping back.
static func _bearing(rules: CombatRules, order: CombatTypes.Shout, kind: int) -> float:
	var leaves := kind == Opt.CHARGE or kind == Opt.LOOT or kind == Opt.STEP_OUT \
			or kind == Opt.GO_FOR_WOUNDED or kind == Opt.DROP_BACK or kind == Opt.RUN or kind == Opt.OBJECTIVE
	var b := rules.dm_order_bearing
	match order:
		CombatTypes.Shout.HOLD, CombatTypes.Shout.SHIELD_WALL, CombatTypes.Shout.TO_ME:
			if kind == Opt.COVER_LEADER and order == CombatTypes.Shout.TO_ME:
				return b
			return -b if leaves else 0.0
		CombatTypes.Shout.PUSH, CombatTypes.Shout.BREAK_THEM, CombatTypes.Shout.SVINFYLKING:
			return b if kind == Opt.CHARGE or kind == Opt.STEP_OUT or kind == Opt.GO_FOR_WOUNDED or kind == Opt.OBJECTIVE else 0.0
		CombatTypes.Shout.FALL_BACK:
			return b if kind == Opt.DROP_BACK or kind == Opt.RUN else 0.0
	return 0.0


## Builds every alternative to the plain order that this man can see, scored.
static func _alternatives(m: Mind, order: CombatTypes.Shout, plain: Action, opts: Array[Option]) -> void:
	var rules := m.rules
	var w := m.w
	var adj := _adjacent(w, m.enemies)
	var reckless := w.has_personality(CombatTypes.Personality.RECKLESS)
	var steady := w.has_personality(CombatTypes.Personality.STEADY) or w.has_personality(CombatTypes.Personality.GRIM)
	var omen := _omen(m)
	var superstitious := w.has_personality(CombatTypes.Personality.SUPERSTITIOUS)

	# Charge: a reckless man goes at anything close whatever the order; a
	# superstitious one when the enemy's banner has fallen. Steady and grim
	# men will not.
	var near := _nearest(w.pos, m.enemies)
	if near != null and order != CombatTypes.Shout.BREAK_THEM \
			and BattleGrid.chebyshev(w.pos, near.pos) <= rules.reckless_charge_radius:
		var s := 0.0
		var why := ""
		if reckless:
			s += rules.dm_reckless_charge
			why = ("%s cannot hold himself: he runs at them" if w.tier == CombatTypes.Tier.GREEN
					else "%s will not wait: he goes at them") % _nm(w)
		if superstitious and omen > 0:
			s += rules.dm_omen_charge
			why = "%s sees their banner fall and goes at them" % _nm(w)
		if steady:
			s -= rules.dm_steady_charge
		if not w.shield_usable() and m.sees_neighbours():
			s -= rules.dm_drop_shieldless
		if s > 0.0:
			m.note = ""
			var a := _break_them(m)
			_add(m, opts, order, Opt.CHARGE, s, a, why)

	# Cover the leader: men of guard_min_tier or better see him beset.
	if w.tier >= rules.guard_min_tier and m.has_leader() \
			and BattleGrid.chebyshev(w.pos, m.leader.pos) <= 2:
		m.note = ""
		var guard := _guard_leader(m, rules.guard_threats)
		if guard != null:
			var s := rules.dm_cover_leader + (rules.dm_steady_hold if steady else 0.0)
			var lname := _nm(m.leader)
			var why := ("%s sees %s beset and goes to him" % [_nm(w), lname]) if guard.kind == CombatTypes.ActionKind.MOVE \
					else ("%s cuts at the men on %s" % [_nm(w), lname])
			_add(m, opts, order, Opt.COVER_LEADER, s, guard, why)

	# A bowman closed with gives ground toward his leader; cornered, he fights.
	if w.role == CombatTypes.Role.MISSILE and not adj.is_empty():
		var away := _step_away(m.grid, w, m.enemies, m.leader)
		if away != null:
			_add(m, opts, order, Opt.GIVE_GROUND, rules.dm_give_ground, away, "%s gives ground, bow in hand" % _nm(w))

	# Close a gap beside him: a blooded man where his neighbour has just
	# fallen, a veteran wherever the line has opened.
	if m.sees_neighbours():
		var gap := _gap_cell(m.grid, w, m.enemies, not m.sees_flank(), m.all)
		if gap != BattleGrid.NO_CELL:
			var fallen := _fallen_at(m.all, w.side, gap)
			var why := "%s sees the gap and steps into it" % _nm(w)
			if fallen != null:
				why = "%s closes up where %s fell" % [_nm(w), _nm(fallen)]
			_add(m, opts, order, Opt.FILL_GAP, rules.dm_fill_gap, Action.move_to(gap), why)

	# Drop back behind a friend when hurt and nobody is at arm's length.
	if adj.is_empty():
		var hurt := 0.0
		if w.wound == CombatTypes.Wound.GRIEVOUS:
			hurt = rules.dm_drop_grievous
		elif w.wound == CombatTypes.Wound.WOUNDED and m.sees_neighbours():
			hurt = rules.dm_drop_wounded
		if hurt > 0.0:
			if not w.shield_usable() and m.sees_neighbours() and w.role != CombatTypes.Role.MISSILE:
				hurt += rules.dm_drop_shieldless
			if reckless:
				hurt -= rules.dm_reckless_drop
			if w.has_personality(CombatTypes.Personality.GRIM):
				hurt -= rules.dm_grim_drop
			var res := _drop_back(m)
			if not res.is_empty():
				var friend: Warrior = res[1]
				var why := ("%s is hurt and falls back behind %s" if w.tier <= CombatTypes.Tier.BLOODED
						else "%s, badly cut, gives his place and drops behind %s") % [_nm(w), _nm(friend)]
				_add(m, opts, order, Opt.DROP_BACK, hurt, res[0], why)

	# An end man turns to meet a flanker coming round his open side.
	if m.sees_neighbours() and adj.is_empty():
		var ff := _face_flank(m)
		if not ff.is_empty():
			var flanker: Warrior = ff[1]
			var why := ("%s turns to meet %s on the flank" if not m.sees_flank()
					else "%s sees %s coming round and turns to meet him") % [_nm(w), _nm(flanker)]
			_add(m, opts, order, Opt.FACE_FLANK, rules.dm_face_flank, ff[0], why)

	# A champion reads intentions: he throws the round before the lines meet,
	# and braces the round before a rush lands.
	if m.reads_intent() and adj.is_empty() and plain.kind != CombatTypes.ActionKind.BRACE:
		var volley := _throw(rules, m.grid, w, m.enemies)
		if volley != null:
			_add(m, opts, order, Opt.THROW, rules.dm_read_throw, volley, "%s looses his spear before they close" % _nm(w))
		var rush := _rush_coming(m)
		if rush != null:
			_add(m, opts, order, Opt.BRACE_FOR_CHARGE, rules.dm_read_brace,
					Action.brace(BattleGrid.direction_to(w.pos, rush.pos)),
					"%s reads the rush and sets his shield" % _nm(w))

	# A greedy man goes for the gear of a fallen leader or banner man, once.
	if w.has_personality(CombatTypes.Personality.GREEDY) and not w.looted and adj.is_empty():
		var prize := _prize(m)
		if prize != null:
			if prize.pos == w.pos:
				w.looted = true  # he has it
			else:
				var step := _step_toward(m.grid, w, prize.pos, Vector2i.ZERO)
				if step != null:
					_add(m, opts, order, Opt.LOOT, rules.dm_greedy_loot, step,
							"%s leaves the line to strip %s" % [_nm(w), _nm(prize)])

	# A boastful man steps out where the enemy's leader will see him.
	if w.has_personality(CombatTypes.Personality.BOASTFUL) and adj.is_empty():
		var their := _enemy_leader(m)
		if their != null and BattleGrid.chebyshev(w.pos, their.pos) <= rules.reckless_charge_radius:
			var step := _step_toward(m.grid, w, their.pos, Vector2i.ZERO)
			if step != null:
				step.new_facing = BattleGrid.direction_to(step.target_cell, their.pos)
				_add(m, opts, order, Opt.STEP_OUT, rules.dm_boast_step, step,
						"%s steps out where %s can see him" % [_nm(w), _nm(their)])

	# A veteran on his own goes for a hurt man two cells off.
	if m.sees_flank() and adj.is_empty() and m.grid.line_neighbors(w).is_empty():
		var hurt_mark: Warrior = null
		for e in m.enemies:
			if BattleGrid.distance(w.pos, e.pos) == 2 and e.wound >= CombatTypes.Wound.WOUNDED \
					and (hurt_mark == null or e.wound > hurt_mark.wound or (e.wound == hurt_mark.wound and e.id < hurt_mark.id)):
				hurt_mark = e
		if hurt_mark != null:
			var cell := _cell_beside(m.grid, w, hurt_mark)
			if cell != BattleGrid.NO_CELL:
				_add(m, opts, order, Opt.GO_FOR_WOUNDED,
						rules.dm_wounded_step_base + rules.dm_wounded_step_per * int(hurt_mark.wound),
						Action.move_to(cell, BattleGrid.direction_to(cell, hurt_mark.pos)),
						"%s sees %s is hurt and goes for him" % [_nm(w), _nm(hurt_mark)])

	# A loose man of the attacking side makes for the objective.
	if m.objective != null and m.objective.attacker == w.side and plain.kind == CombatTypes.ActionKind.MOVE \
			and m.grid.line_neighbors(w).is_empty() and not m.objective.has_cell(w.pos):
		var close := false
		for e in m.enemies:
			close = close or BattleGrid.distance(w.pos, e.pos) <= 2
		var goal := _nearest_cell(w.pos, m.objective.cells)
		if not close and goal != BattleGrid.NO_CELL:
			var step := _step_toward(m.grid, w, goal, Vector2i.ZERO)
			if step != null:
				_add(m, opts, order, Opt.OBJECTIVE, rules.dm_objective_step, step,
						"%s makes for %s" % [_nm(w), m.objective.name])

	# A superstitious man whose banner has fallen wants no more of it.
	if superstitious and omen < 0:
		var s := rules.dm_omen_run + (rules.dm_omen_run_shaken if w.morale <= rules.morale_break_threshold + 2 else 0.0)
		_add(m, opts, order, Opt.RUN, s, _flee(m.grid, w, m.enemies),
				"%s sees the banner go down and wants no more of it" % _nm(w))


static func _add(m: Mind, opts: Array[Option], order: CombatTypes.Shout, kind: int, score: float,
		a: Action, why: String) -> void:
	if a == null:
		return
	# The men at his shoulders hold him in the wall: charging or stepping
	# out from it costs more than doing it alone.
	if (kind == Opt.CHARGE or kind == Opt.STEP_OUT) and not m.grid.line_neighbors(m.w).is_empty():
		score -= m.rules.dm_leave_wall
	opts.append(Option.new(kind, score + _bearing(m.rules, order, kind) + m.jitter(), a, why))


## Display name without the title, for reasons.
static func _nm(w: Warrior) -> String:
	return w.display_name.replace(" the leader", "") if w != null else "?"


# --- What he sees -------------------------------------------------------------

## A green man who missed the shout copies the order the men beside him are
## acting on: at least dm_green_copy_neighbours friends at his shoulders,
## and every one of them, act on one order that is not his. Returns one of
## them, or null.
static func _copied_order(m: Mind) -> Warrior:
	var w := m.w
	if w.tier != CombatTypes.Tier.GREEN:
		return null
	var model: Warrior = null
	var agree := 0
	for n in m.grid.line_neighbors(w):
		if n.broken or n.order_lag > 0 or n.heard_order == CombatTypes.Shout.NONE:
			continue
		if model != null and n.heard_order != model.heard_order:
			return null  # they disagree: he keeps his own
		agree += 1
		if model == null or n.id < model.id:
			model = n
	if model == null or agree < m.rules.dm_green_copy_neighbours or model.heard_order == w.heard_order:
		return null
	return model


## +1 when the enemy's banner has fallen and his own stands, -1 the other
## way round, 0 otherwise.
static func _omen(m: Mind) -> int:
	var ours := false
	var theirs := false
	for x in m.all:
		if x.is_banner and x.is_down():
			if x.side == m.w.side:
				ours = true
			else:
				theirs = true
	return (1 if theirs else 0) - (1 if ours else 0)


## A fallen enemy leader or banner man near enough to strip. Null if none.
static func _prize(m: Mind) -> Warrior:
	var best: Warrior = null
	for x in m.all:
		if x.side == m.w.side or not x.is_down() or not (x.is_leader or x.is_banner):
			continue
		if BattleGrid.distance(m.w.pos, x.pos) > m.rules.dm_loot_radius:
			continue
		if x.pos != m.w.pos and not m.grid.is_free(x.pos):
			continue
		if best == null or x.id < best.id:
			best = x
	return best


static func _enemy_leader(m: Mind) -> Warrior:
	for e in m.enemies:
		if e.is_leader:
			return e
	return null


## The friend down at a cell, or null.
static func _fallen_at(all: Array, side: int, c: Vector2i) -> Warrior:
	for x in all:
		if x.side == side and x.is_down() and x.pos == c:
			return x
	return null


## An enemy two cells off who is coming on (under Break them or Push) with
## nobody between: the rush will land next round. Null if none.
static func _rush_coming(m: Mind) -> Warrior:
	var best: Warrior = null
	for e in m.enemies:
		if e.broken or BattleGrid.distance(m.w.pos, e.pos) != 2:
			continue
		if e.heard_order != CombatTypes.Shout.BREAK_THEM and e.heard_order != CombatTypes.Shout.PUSH:
			continue
		if best == null or e.id < best.id:
			best = e
	return best


## [Action, friend] for a hurt man dropping back: he must be at the front
## (no friend beside him nearer the nearest enemy) with a friend behind him,
## and he steps to a free cell further from the enemy, as near the cell
## behind that friend as he can. [] if he cannot.
static func _drop_back(m: Mind) -> Array:
	var w := m.w
	var near := _nearest(w.pos, m.enemies)
	if near == null:
		return []
	var here := BattleGrid.distance(w.pos, near.pos)
	var friend: Warrior = null
	var friend_d := here
	for f in m.grid.adjacent_warriors(w.pos, w.side):
		if not f.is_active() or f.broken:
			continue
		var fd := BattleGrid.distance(f.pos, near.pos)
		if fd < here:
			return []  # someone already stands between him and them
		if fd > friend_d or (fd == friend_d and friend != null and f.id < friend.id):
			friend = f
			friend_d = fd
	if friend == null:
		return []
	var shelter := friend.pos + (friend.pos - w.pos)
	var best := BattleGrid.NO_CELL
	var best_d := 0
	for d in BattleGrid.DIRS:
		var c := w.pos + d
		if not m.grid.is_free(c) or BattleGrid.distance(c, near.pos) <= here:
			continue
		var sd := BattleGrid.distance(c, shelter)
		if best == BattleGrid.NO_CELL or sd < best_d:
			best = c
			best_d = sd
	if best == BattleGrid.NO_CELL:
		return []
	return [Action.move_to(best, w.facing), friend]


## [Action, flanker] for an end man of a wall turning one facing toward an
## enemy coming round his open side, within sight (two hexes for a blooded
## man, three for a veteran), keeping every man beside him linked. [] if not.
static func _face_flank(m: Mind) -> Array:
	var w := m.w
	var g := m.grid
	var neighbours := g.line_neighbors(w, m.rules.wall_link_turn)
	if neighbours.is_empty():
		return []
	var right_n := g.occupant(BattleGrid.along_line(w.pos, w.facing, true))
	var left_n := g.occupant(BattleGrid.along_line(w.pos, w.facing, false))
	var right_open := right_n == null or not neighbours.has(right_n)
	var left_open := left_n == null or not neighbours.has(left_n)
	if right_open == left_open:
		return []  # not an end man
	var sight := m.rules.dm_flank_sight_veteran if m.sees_flank() else m.rules.dm_flank_sight_blooded
	var best: Warrior = null
	var turn := 0
	for e in m.enemies:
		var d := BattleGrid.distance(w.pos, e.pos)
		if d > sight or d < 2:
			continue
		var rel := posmod(BattleGrid.dir_index(BattleGrid.direction_to(w.pos, e.pos)) - BattleGrid.dir_index(w.facing), 6)
		var t := 0
		if right_open and (rel == 2 or rel == 3):
			t = 1
		elif left_open and rel == 4:
			t = -1
		if t == 0:
			continue
		if best == null or d < BattleGrid.distance(w.pos, best.pos) or (d == BattleGrid.distance(w.pos, best.pos) and e.id < best.id):
			best = e
			turn = t
	if best == null:
		return []
	var face := BattleGrid.rotate(w.facing, turn)
	if m.has_leader() and BattleGrid.facing_steps(face, m.leader.wall_facing()) > m.rules.wall_max_bend:
		return []
	for n in neighbours:
		if not BattleGrid.linked_at(w.pos, face, n.pos, n.facing, m.rules.wall_link_turn):
			return []
	return [Action.brace(face), best]


## A free cell next to both w and `e`, or NO_CELL.
static func _cell_beside(grid: BattleGrid, w: Warrior, e: Warrior) -> Vector2i:
	for d in BattleGrid.DIRS:
		var c := w.pos + d
		if grid.is_free(c) and BattleGrid.distance(c, e.pos) == 1:
			return c
	return BattleGrid.NO_CELL


static func _nearest_cell(from: Vector2i, cells: Array[Vector2i]) -> Vector2i:
	var best := BattleGrid.NO_CELL
	var best_d := 0
	for c in cells:
		var d := BattleGrid.distance(from, c)
		if best == BattleGrid.NO_CELL or d < best_d:
			best = c
			best_d = d
	return best


# --- Orders ----------------------------------------------------------------

static func _by_order(m: Mind, order: CombatTypes.Shout) -> Action:
	var rules := m.rules
	var grid := m.grid
	var w := m.w
	var leader := m.leader
	var enemies := m.enemies
	var act: Action
	var has_leader := leader != null and leader != w and leader.is_active()
	match order:
		CombatTypes.Shout.NONE:
			if w.tier == CombatTypes.Tier.GREEN:
				# No orders: a green man stands where he is, but strikes at what
				# is in his face, or in his spear's reach.
				var at_him := _front_or_beside(m)
				act = Action.attack(at_him) if at_him != null else Action.brace()
			else:
				act = _hold(m)
		CombatTypes.Shout.SHIELD_WALL:
			act = _form(m, false)
		CombatTypes.Shout.HOLD:
			act = _hold(m)
		CombatTypes.Shout.PUSH:
			act = _push(m)
		CombatTypes.Shout.TO_ME:
			if has_leader and BattleGrid.chebyshev(w.pos, leader.pos) > 1:
				act = _step_toward(grid, w, leader.pos, Vector2i.ZERO)
			if act == null:
				act = _hold(m)
		CombatTypes.Shout.BREAK_THEM:
			act = _break_them(m)
		CombatTypes.Shout.FALL_BACK:
			if w.tier <= CombatTypes.Tier.BLOODED and w.morale <= rules.fall_back_steady_morale:
				m.pending.append("the line wavers: %s turns to run" % w.display_name)
				return _flee(grid, w, enemies)
			if has_leader and not _in_wall(grid, w) and _adjacent(w, enemies).is_empty():
				act = _form(m, false)  # rejoin the wall as it goes back
			elif has_leader and BattleGrid.chebyshev(w.pos, leader.pos) > rules.fall_back_regroup_distance:
				act = _step_toward(grid, w, leader.pos, Vector2i.ZERO)
			if act == null:
				var back := w.pos + BattleGrid.advance_step(w.pos, BattleGrid.rotate(w.facing, 3))
				if grid.is_free(back):
					act = Action.move_to(back)
				else:
					act = Action.brace()
		CombatTypes.Shout.SVINFYLKING:
			act = _form(m, true)
		_:  # TAUNT is never propagated as an order; anything else unknown: hold
			act = _hold(m)

	# Bowmen with nobody at arm's length shoot instead of moving or
	# waiting, unless the line has drawn too far ahead of them: then they
	# keep up first.
	var strayed := leader != null and leader.is_active() and leader != w \
			and BattleGrid.chebyshev(w.pos, leader.pos) > rules.missile_keep_distance
	if w.weapon == CombatTypes.Weapon.BOW and order != CombatTypes.Shout.BREAK_THEM and not strayed \
			and (act.kind == CombatTypes.ActionKind.MOVE or act.kind == CombatTypes.ActionKind.BRACE or act.kind == CombatTypes.ActionKind.IDLE) \
			and _adjacent(w, enemies).is_empty():
		var mark := _best_mark(grid, w, enemies, rules.missile_range)
		if mark != null:
			return Action.shoot(mark)
	# A man standing his ground with the enemy a throw away looses a spear.
	if act.kind == CombatTypes.ActionKind.BRACE and order != CombatTypes.Shout.BREAK_THEM:
		var volley := _throw(rules, grid, w, enemies)
		if volley != null:
			return volley
	return act


## The man an archer shoots at: within `range`, the most exposed first (no
## shield toward him, then a shield but no neighbour locking it, then a
## locked wall), the nearest among equals, then the lowest id. Null if
## nobody is in range.
static func _best_mark(grid: BattleGrid, w: Warrior, enemies: Array[Warrior], range: int) -> Warrior:
	var best: Warrior = null
	var best_key := []
	for e in enemies:
		var d := BattleGrid.chebyshev(w.pos, e.pos)
		if d > range or not e.is_active():
			continue
		var covered := MeleeExchange.covered(grid, e, w.pos)
		var exposure := 0 if not covered else (1 if grid.line_neighbors(e).is_empty() else 2)
		var key := [exposure, d, e.id]
		if best == null or _less(key, best_key):
			best = e
			best_key = key
	return best


## A throwing spear at the nearest enemy within javelin_range, if he has one
## and nobody is at arm's length. Null otherwise.
static func _throw(rules: CombatRules, _grid: BattleGrid, w: Warrior, enemies: Array[Warrior]) -> Action:
	if w.javelins <= 0 or not _adjacent(w, enemies).is_empty():
		return null
	var mark := _nearest(w.pos, enemies)
	if mark == null or BattleGrid.chebyshev(w.pos, mark.pos) > rules.javelin_range:
		return null
	return Action.throw_at(mark)


## A step that puts more ground between a man and the enemies at arm's
## length, toward his leader for choice. Null if there is none.
static func _step_away(grid: BattleGrid, w: Warrior, enemies: Array[Warrior], leader: Warrior) -> Action:
	var near := _nearest(w.pos, enemies)
	if near == null:
		return null
	var best := Vector2i(Warrior.NO_WALL_MOVE)
	var best_key := [0, 0]
	for d in BattleGrid.DIRS:
		var c := w.pos + d
		if not grid.is_free(c):
			continue
		var gap := 99
		for e in enemies:
			gap = mini(gap, BattleGrid.chebyshev(c, e.pos))
		if gap < 2:
			continue
		var to_leader := BattleGrid.chebyshev(c, leader.pos) if leader != null and leader.is_active() else 0
		var key := [-gap, to_leader]
		if best == Vector2i(Warrior.NO_WALL_MOVE) or _less(key, best_key):
			best = c
			best_key = key
	if best == Vector2i(Warrior.NO_WALL_MOVE):
		return null
	return Action.move_to(best, BattleGrid.direction_to(best, near.pos))


## HOLD: strike a man in front (a wounded one first), else brace toward the
## nearest enemy.
static func _hold(m: Mind) -> Action:
	var foe := _front_or_beside(m)
	if foe != null:
		return Action.attack(foe)
	var near := _nearest(m.w.pos, m.enemies)
	if near == null:
		return Action.brace()
	# In a wall, keep his facing; the battle dresses the line each round.
	if _in_wall(m.grid, m.w):
		return Action.brace(m.w.facing)
	return Action.brace(BattleGrid.direction_to(m.w.pos, near.pos))


## Whether w stands in the leader's own wall (BattleGrid.chain). A pair
## standing together off to one side is a fragment, not the wall.
static func _in_leaders_wall(grid: BattleGrid, w: Warrior, leader: Warrior) -> bool:
	if leader == null or not leader.is_active() or leader.side != w.side:
		return false
	return w == leader or grid.chain(leader).has(w)


## Whether any man of a wall has an enemy at arm's length.
static func _wall_engaged(_grid: BattleGrid, members: Array[Warrior], enemies: Array[Warrior]) -> bool:
	for m in members:
		if not _adjacent(m, enemies).is_empty():
			return true
	return false


## True when a friend stands at w's shoulder.
static func _in_wall(grid: BattleGrid, w: Warrior) -> bool:
	return not grid.line_neighbors(w).is_empty()


static func _push(m: Mind) -> Action:
	var grid := m.grid
	var w := m.w
	var leader := m.leader
	var enemies := m.enemies
	var foe := _front_or_beside(m)
	if foe != null:
		return Action.attack(foe)
	# Drive forward means the whole line steps toward the enemy together:
	# every man steps the same way, from his side's centre toward theirs,
	# so the wall advances as a wall. A man with nobody beside him closes
	# on the nearest enemy instead.
	var near := _nearest(w.pos, enemies)
	if near == null:
		return Action.brace()
	var toward := BattleGrid.direction_to(w.pos, near.pos)
	var anchor := leader if leader != null and leader.is_active() and leader.side == w.side else w
	if _in_leaders_wall(grid, w, anchor) and not grid.line_neighbors(w).is_empty():
		# One direction for the whole line, taken from the leader's position.
		# A wall advances the way it faces; without a set wall facing, toward the enemy.
		var wall := anchor.line_facing if anchor.line_facing != Vector2i.ZERO else _advance_direction(anchor, enemies)
		if _line_in_contact(grid, w, enemies):
			return Action.brace(wall)  # the line is engaged: hold it together
		var advance := BattleGrid.advance_step(w.pos, wall)
		var ahead := w.pos + advance
		if grid.is_free(ahead):
			return Action.move_to(ahead, wall)
		var occ := grid.occupant(ahead)
		if occ != null and occ.side == w.side:
			return Action.brace(advance)
	# Not in the wall: rejoin it rather than push ahead alone.
	if leader != null and leader.is_active() and leader.side == w.side and leader != w and not m.all.is_empty():
		return _form(m, false)
	var step := _step_toward(grid, w, near.pos, toward)
	if step == null:
		return Action.brace(toward)
	return step


static func _break_them(m: Mind) -> Action:
	var w := m.w
	var adj := _adjacent(w, m.enemies)
	if not adj.is_empty():
		return Action.attack(_pick_target(m, adj))
	var near := _nearest(w.pos, m.enemies)
	if near == null:
		return _hold(m)
	var step := _step_toward(m.grid, w, near.pos, Vector2i.ZERO)
	if step == null:
		return Action.brace(BattleGrid.direction_to(w.pos, near.pos))
	step.new_facing = BattleGrid.direction_to(step.target_cell, near.pos)
	return step


## SHIELD_WALL (wedge false) or SVINFYLKING (wedge true): step toward this
## man's slot; once on it, hold (wall) or push (wedge).
static func _form(m: Mind, wedge: bool) -> Action:
	var grid := m.grid
	var w := m.w
	var leader := m.leader
	var enemies := m.enemies
	if leader == null or leader == w or not leader.is_active() or leader.side != w.side:
		return _push(m) if wedge else _hold(m)
	var members: Array[Warrior] = []
	if not wedge:
		members = grid.chain(leader)
		if members.has(w) and _wall_engaged(grid, members, enemies):
			# In a wall that is fighting: hold it as it stands, bends and all.
			return _hold(m)
		members = []  # not engaged: everyone dresses to the row
	var band: Array[Warrior] = []
	for x in m.all:
		if x != leader and x.side == w.side and x.is_active() and not x.broken and not members.has(x):
			band.append(x)
	var template: FormationTemplate = FormationTemplate.wedge() if wedge else leader.formation
	var plan := Formation.template_slots(grid, leader, band, template)
	if not members.is_empty():
		# A slot held by a man of the engaged wall is not open: drop it.
		for x in plan.keys():
			var o := grid.occupant(plan[x])
			if o != null and not band.has(o):
				plan.erase(x)
	if plan.has(w) and plan[w] != w.pos:
		var step := _step_toward(grid, w, plan[w], leader.wall_facing())
		if step != null:
			return step
		return Action.brace(leader.wall_facing())
	if wedge:
		return _push(m)
	var act := _hold(m)
	if act.kind == CombatTypes.ActionKind.BRACE and enemies.is_empty():
		act.new_facing = leader.wall_facing()
	return act


## Covering the leader: attack one of the enemies at the leader's side,
## stepping next to one first if he is not already. Null if the leader is
## not beset or there is no way in.
static func _guard_leader(m: Mind, min_threats := 2) -> Action:
	var grid := m.grid
	var w := m.w
	var leader := m.leader
	var threats := _adjacent(leader, m.enemies)
	if threats.size() < min_threats:
		return null
	var mine := _adjacent(w, threats)
	if not mine.is_empty():
		return Action.attack(_pick_target(m, mine))
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
## gap. With `only_fallen`, only a cell where a friend of his (in `all`) lies down
## counts (what a blooded man sees: his neighbour has just fallen there).
## BattleGrid.NO_CELL if none.
static func _gap_cell(grid: BattleGrid, w: Warrior, enemies: Array[Warrior], only_fallen := false, all: Array = []) -> Vector2i:
	for right in [true, false]:
		var c := BattleGrid.along_line(w.pos, w.facing, right)
		if not grid.is_free(c):
			continue
		var beyond := grid.occupant(BattleGrid.along_line(c, w.facing, right))
		if beyond == null or beyond.side != w.side or not beyond.is_active():
			continue
		if only_fallen and _fallen_at(all, w.side, c) == null:
			continue
		for e in enemies:
			if BattleGrid.chebyshev(c, e.pos) == 1:
				return c
	return BattleGrid.NO_CELL


## True when any man connected to w through locked line neighbours has an
## enemy adjacent: the line is engaged and should not walk apart.
static func _line_in_contact(grid: BattleGrid, w: Warrior, enemies: Array[Warrior]) -> bool:
	var seen := {w: true}
	var queue: Array[Warrior] = [w]
	while not queue.is_empty():
		var m: Warrior = queue.pop_front()
		for e in enemies:
			if e.is_active() and BattleGrid.chebyshev(m.pos, e.pos) == 1:
				return true
		for n in grid.line_neighbors(m):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return false


## The direction a line advances: from this man toward the enemy's centre,
## snapped to a hex direction, so neighbours step the same way.
static func _advance_direction(w: Warrior, enemies: Array[Warrior]) -> Vector2i:
	var sum := Vector2.ZERO
	var n := 0
	for e in enemies:
		if e.is_active():
			sum += Vector2(e.pos)
			n += 1
	if n == 0:
		return w.facing
	var centre := sum / n
	var d := BattleGrid.to_cart(centre) - BattleGrid.to_cart(Vector2(w.pos))
	if d.length() < 0.5:
		return w.facing
	return BattleGrid.snap_direction(d)


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


## The man to strike while standing his ground: one in front of him first;
## failing that, one at his flank or back, since a man who is being cut at
## from behind turns to fight whatever it costs the line; failing that, one
## in his spear's reach. Null if nobody is in reach.
static func _front_or_beside(m: Mind) -> Warrior:
	var w := m.w
	var front := _front(w, m.enemies)
	if not front.is_empty():
		return _pick_target(m, front)
	var adj := _adjacent(w, m.enemies)
	if not adj.is_empty():
		return _pick_target(m, adj)
	var reach := _in_reach(m.grid, w, m.enemies)
	if not reach.is_empty():
		return _pick_target(m, reach)
	return null


## Enemies a spearman can strike over a friend's shoulder: two cells off,
## with an active friend in the cell between (MeleeExchange.can_reach).
static func _in_reach(grid: BattleGrid, w: Warrior, enemies: Array[Warrior]) -> Array[Warrior]:
	var out: Array[Warrior] = []
	if w.weapon != CombatTypes.Weapon.SPEAR:
		return out
	for e in enemies:
		if BattleGrid.chebyshev(w.pos, e.pos) != 2:
			continue
		var between := grid.occupant(w.pos + BattleGrid.direction_to(w.pos, e.pos))
		if between != null and between.side == w.side and between.is_active():
			out.append(e)
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


## Which of several reachable enemies to strike: weighed. Everyone sees the
## man in front before the man beside, and the hurt before the whole (the
## plain pick); a blooded man also sees a shield gone and, at a spear's
## reach, which enemy is pressing his friends; a boastful man seeks the
## enemy leader or a champion. A green man's weights are blurred. Then the
## nearest, then the lowest id. Sets m.note when the weighed pick is not the
## plain one.
static func _pick_target(m: Mind, candidates: Array[Warrior]) -> Warrior:
	var best: Warrior = null
	var best_key := []
	var best_s := 0.0
	var plain: Warrior = null
	var plain_key := []
	var plain_s := 0.0
	for e in candidates:
		var base := _mark_plain(m, e)
		var s := base + _mark_extra(m, e)
		var d := BattleGrid.chebyshev(m.w.pos, e.pos)
		var key := [-(s + m.jitter()), d, e.id]
		if best == null or _less(key, best_key):
			best = e
			best_key = key
			best_s = s
		var pkey := [-base, d, e.id]
		if plain == null or _less(pkey, plain_key):
			plain = e
			plain_key = pkey
			plain_s = base + _mark_extra(m, e)
	if best != plain and best_s > plain_s:
		m.note = _mark_reason(m, best)
	return best


## What every man sees in a mark: where he stands, and how hurt he is.
static func _mark_plain(m: Mind, e: Warrior) -> float:
	var s := m.rules.dm_mark_wound * int(e.wound)
	if BattleGrid.chebyshev(m.w.pos, e.pos) == 1:
		var arc := BattleGrid.arc_of(m.w, e.pos)
		s += m.rules.dm_mark_front if arc == CombatTypes.Arc.FRONT or arc == CombatTypes.Arc.FRONT_RIGHT \
				else m.rules.dm_mark_beside
	return s


## What only some men see in a mark.
static func _mark_extra(m: Mind, e: Warrior) -> float:
	var s := 0.0
	var w := m.w
	if m.sees_neighbours():
		if not e.shield_usable():
			s += m.rules.dm_mark_shieldless
		if BattleGrid.chebyshev(w.pos, e.pos) >= 2:
			s += m.rules.dm_mark_pressing * mini(_pressing(m, e).size(), m.rules.dm_mark_pressing_cap)
	if w.has_personality(CombatTypes.Personality.BOASTFUL) and (e.is_leader or e.tier == CombatTypes.Tier.CHAMPION):
		s += m.rules.dm_boast_mark
	return s


## His friends an enemy is at arm's length of.
static func _pressing(m: Mind, e: Warrior) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for f in m.grid.adjacent_warriors(e.pos, m.w.side):
		if f != m.w and f.is_active():
			out.append(f)
	return out


static func _mark_reason(m: Mind, e: Warrior) -> String:
	var w := m.w
	if w.has_personality(CombatTypes.Personality.BOASTFUL) and (e.is_leader or e.tier == CombatTypes.Tier.CHAMPION):
		return "%s seeks out %s, where all can see him" % [_nm(w), _nm(e)]
	if BattleGrid.chebyshev(w.pos, e.pos) >= 2:
		var pressed := _pressing(m, e)
		var friend: Warrior = null
		for f in pressed:
			if friend == null or f.id < friend.id:
				friend = f
		# Name the friend he is helping: the one beside the man between, for choice.
		var between := m.grid.occupant(w.pos + BattleGrid.direction_to(w.pos, e.pos))
		for f in pressed:
			if f != between:
				friend = f
				break
		if friend != null:
			return "%s's spear goes for the man on %s" % [_nm(w), _nm(friend)]
	if not e.shield_usable():
		return "%s picks %s, whose shield is gone" % [_nm(w), _nm(e)]
	return "%s picks his man: %s" % [_nm(w), _nm(e)]


static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
