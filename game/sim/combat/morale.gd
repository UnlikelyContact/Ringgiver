class_name Morale
extends RefCounted
## Morale in battle (concept.md, Wounds, shields and morale): men falling
## nearby, flanks and the leader's presence move a man's morale; a man at or
## below the break threshold must check or break, and panic spreads one hop.
##
## Morale is a whole number clamped to 0-10. Every value comes from
## CombatRules (section "Morale and the push").

const MORALE_MIN := 0
const MORALE_MAX := 10


## A man has just gone Down. Friends nearby lose heart, enemies nearby gain
## it; a fallen leader or banner hits his whole side. Adjacent friends take
## the adjacent penalty only (not the visible one as well).
static func on_down(rules: CombatRules, grid: BattleGrid, downed: Warrior,
		all: Array[Warrior], log: PackedStringArray) -> void:
	for w in _sorted(all):
		if w == downed or not w.is_active():
			continue
		var dist := BattleGrid.chebyshev(w.pos, downed.pos)
		var delta := 0
		if w.side == downed.side:
			if dist <= 1:
				delta += rules.morale_ally_down_adjacent
			elif dist <= rules.morale_visible_radius:
				delta += rules.morale_ally_down_visible
			if downed.is_leader:
				delta += rules.morale_leader_down
			if downed.is_banner:
				delta += rules.morale_banner_lost
		elif dist <= rules.morale_visible_radius:
			delta += rules.morale_enemy_down_visible
		_shift(w, delta)
	if downed.is_leader:
		log.append("%s, the leader, falls: his side's heart sinks" % downed.display_name)
	if downed.is_banner:
		log.append("%s falls and the banner is lost" % downed.display_name)


## End-of-round morale beat. `leaders` maps side -> Warrior (or null).
## `any_attacks` is false when nobody attacked this round (a lull).
## Returns the men who broke this round, in the order they broke.
static func round_update(rng: SimRng, rules: CombatRules, grid: BattleGrid,
		all: Array[Warrior], leaders: Dictionary, any_attacks: bool,
		log: PackedStringArray) -> Array[Warrior]:
	var men := _sorted(all)
	var broke: Array[Warrior] = []

	# Lull: nobody attacked, everybody gets his breath back.
	if not any_attacks:
		for w in men:
			if w.is_active():
				w.recover_breath(rules.breath_recover_lull, rules)
		log.append("a lull: both sides catch their breath")

	# Standing modifiers: the leader at a man's side, an enemy on his flank.
	for w in men:
		if not w.is_active():
			continue
		var leader := _leader_of(leaders, w.side)
		var delta := 0
		if leader != null and leader != w:
			var d := BattleGrid.distance(w.pos, leader.pos)
			if d == 1:
				delta += rules.morale_leader_adjacent
			elif d <= rules.morale_leader_near_radius:
				delta += rules.morale_leader_near
		if is_flanked(grid, w):
			delta += rules.morale_flanked
		# Heart comes from the man at your shoulder: no shield-friend beside
		# him in his line, and a man feels alone whoever is milling about.
		if grid.line_neighbors(w).is_empty():
			delta += rules.morale_alone
		_shift(w, delta)

	# Rallying: broken men whose heart has come back near their leader.
	for w in men:
		_try_rally(rules, w, _leader_of(leaders, w.side), log)

	# First wave: every shaken man checks.
	var checked := {}
	var first_wave: Array[Warrior] = []
	for w in men:
		if w.is_active() and not w.broken and w.morale <= rules.morale_break_threshold \
				and not (rules.leaders_never_break and w.is_leader):
			checked[w] = true
			if _check_breaks(rng, rules, grid, w):
				_break(w, log, "")
				first_wave.append(w)
				broke.append(w)

	# Panic spreads from first-wave breakers to adjacent friends; a friend
	# left shaken by it checks once more this round if he has not yet. Men
	# who break from panic spread nothing further (one hop only).
	var panicked: Array[Warrior] = []
	for b in first_wave:
		for f in grid.adjacent_warriors(b.pos, b.side):
			if f == b or not f.is_active() or f.broken or not men.has(f):
				continue
			_shift(f, rules.morale_panic_spread)
			if not panicked.has(f):
				panicked.append(f)
	panicked.sort_custom(func(x: Warrior, y: Warrior) -> bool: return x.id < y.id)
	for f in panicked:
		if checked.has(f) or f.broken or f.morale > rules.morale_break_threshold or (rules.leaders_never_break and f.is_leader):
			continue
		checked[f] = true
		if _check_breaks(rng, rules, grid, f):
			_break(f, log, " as panic spreads")
			broke.append(f)
	return broke


## "To me!" heard: friends within earshot of the leader take heart, and any
## broken man among them who is back above the threshold and within
## `rally_radius` of the leader rallies.
static func rally(rules: CombatRules, grid: BattleGrid, leader: Warrior,
		all: Array[Warrior], log: PackedStringArray) -> void:
	if leader == null or not leader.is_active():
		return
	var radius := rules.hear_certain_radius
	for w in all:
		if w.side == leader.side and w.is_active() and w.is_horn:
			radius += rules.hear_horn_radius_bonus
			break
	log.append("%s shouts \"To me!\"" % leader.display_name)
	for w in _sorted(all):
		if w == leader or w.side != leader.side or not w.is_active():
			continue
		if BattleGrid.chebyshev(w.pos, leader.pos) > radius:
			continue
		_shift(w, rules.morale_rally_to_me)
		_try_rally(rules, w, leader, log)


## True when an active enemy stands adjacent in w's RIGHT or REAR arc.
static func is_flanked(grid: BattleGrid, w: Warrior) -> bool:
	for e in grid.adjacent_warriors(w.pos):
		if e.side == w.side or not e.is_active():
			continue
		var arc := BattleGrid.arc_of(w, e.pos)
		if arc == CombatTypes.Arc.RIGHT or arc == CombatTypes.Arc.REAR:
			return true
	return false


## Personality modifier to the break check.
static func check_modifier(rules: CombatRules, w: Warrior) -> int:
	if w.has_personality(CombatTypes.Personality.STEADY) or w.has_personality(CombatTypes.Personality.GRIM):
		return rules.morale_steady_bonus
	return 0


## One break check. True if the man breaks.
static func _check_breaks(rng: SimRng, rules: CombatRules, grid: BattleGrid, w: Warrior) -> bool:
	if w.has_personality(CombatTypes.Personality.RECKLESS) and _enemy_adjacent(grid, w):
		return false
	var total := rng.roll_2d6() + w.nerve + check_modifier(rules, w)
	return total < rules.morale_check_target


static func _enemy_adjacent(grid: BattleGrid, w: Warrior) -> bool:
	for e in grid.adjacent_warriors(w.pos):
		if e.side != w.side and e.is_active():
			return true
	return false


static func _try_rally(rules: CombatRules, w: Warrior, leader: Warrior, log: PackedStringArray) -> void:
	if not w.broken or not w.is_active() or leader == null or leader == w:
		return
	if w.morale <= rules.morale_break_threshold:
		return
	if BattleGrid.chebyshev(w.pos, leader.pos) > rules.rally_radius:
		return
	w.broken = false
	log.append("%s rallies to %s" % [w.display_name, leader.display_name])


static func _break(w: Warrior, log: PackedStringArray, why: String) -> void:
	w.broken = true
	log.append("%s breaks%s" % [w.display_name, why])


static func _leader_of(leaders: Dictionary, side: int) -> Warrior:
	var l: Warrior = leaders.get(side, null)
	if l == null or not l.is_active():
		return null
	return l


static func _shift(w: Warrior, delta: int) -> void:
	w.morale = clampi(w.morale + delta, MORALE_MIN, MORALE_MAX)


static func _sorted(all: Array[Warrior]) -> Array[Warrior]:
	var out: Array[Warrior] = all.duplicate()
	out.sort_custom(func(a: Warrior, b: Warrior) -> bool: return a.id < b.id)
	return out
