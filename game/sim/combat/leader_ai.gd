class_name LeaderAI
extends RefCounted
## Picks a shout for an AI-led side each round. A doctrine plus a few
## situational overrides. Enemy leaders use the same shout system as the
## player (concept.md, Combat), so this is also what the player's men would
## hear if they could read the enemy.
##
## Every doctrine but RECKLESS minds his wall: he wheels toward the nearest
## part of the enemy, not the middle of their band, and the men at an end
## that an enemy line is getting round hinge back to refuse the flank.
## STEADY and CUNNING will not walk into ranks with ranks unless they have
## the numbers, the enemy is wavering, or the lines are already engaged.
## CUNNING also reads a wall marching across his front and wheels to meet it
## where it is going. See docs/design/sim-architecture.md, "Enemy doctrine".

enum Doctrine { STEADY, AGGRESSIVE, RECKLESS, CUNNING }

const NO_POS := Vector2i(-9999, -9999)

var doctrine: Doctrine = Doctrine.STEADY
var _formed_rounds := 0
var _refusing := {}  # true (right end) / false (left end) -> refusing this spell, so it is logged once
var _hinged := {}  # Warrior -> true: men this leader hinged back last round
var _enemy_leader_was := NO_POS


func _init(p_doctrine: Doctrine = Doctrine.STEADY) -> void:
	doctrine = p_doctrine


# --- Reading the field ---------------------------------------------------------

## The cartesian unit vector a stance's front points along (screen y down).
static func front_vector(axis: int, facing: Vector2i) -> Vector2:
	var r := deg_to_rad(float(BattleGrid.STATES[BattleGrid.state_of(axis, facing)][2]))
	return Vector2(cos(r), -sin(r))


## The cartesian unit vector of a stance's right hand.
static func right_vector(axis: int, facing: Vector2i) -> Vector2:
	var f := front_vector(axis, facing)
	return Vector2(-f.y, f.x)


static func standing(men: Array[Warrior]) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for w in men:
		if w.is_active() and not w.broken:
			out.append(w)
	return out


## A side's fighting weight: its standing men, shields 1.0, spears 0.9,
## bows 0.6 (CombatRules.ai_strength_*).
static func strength(rules: CombatRules, men: Array[Warrior]) -> float:
	var s := 0.0
	for w in standing(men):
		match w.role:
			CombatTypes.Role.SPEAR:
				s += rules.ai_strength_spear
			CombatTypes.Role.MISSILE:
				s += rules.ai_strength_bow
			_:
				s += rules.ai_strength_shield
	return s


## Mean morale of the standing men, or 10 if nobody stands.
static func mean_morale(men: Array[Warrior]) -> float:
	var st := standing(men)
	if st.is_empty():
		return 10.0
	var sum := 0
	for w in st:
		sum += w.morale
	return float(sum) / st.size()


## Whether a leader's band forms in ranks (a line template with some role
## standing behind the first rank).
static func ranked(leader: Warrior) -> bool:
	if leader == null or leader.formation == null or leader.formation.shape != FormationTemplate.Shape.LINE:
		return false
	for r in leader.formation.rank_of.values():
		if int(r) > 1:
			return true
	return false


static func _distance_to(men: Array[Warrior], pos: Vector2i) -> int:
	var best := 999
	for m in men:
		best = mini(best, BattleGrid.distance(m.pos, pos))
	return best


static func _engaged(battle: Battle, men: Array[Warrior], side: int) -> bool:
	for w in men:
		if not battle.grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			return true
	return false


## The enemy men that make the threat, nearest first: the nearest
## `ai_threat_fraction` of their wall if they have one (two men or more), else of their
## standing men, measured from our wall (then from our leader, then by id).
static func threat_men(battle: Battle, side: int) -> Array[Warrior]:
	var leader := battle.leader_of(side)
	var out: Array[Warrior] = []
	if leader == null:
		return out
	var mine := battle.wall_members(side)
	if mine.is_empty():
		mine = [leader]
	var pool := battle.wall_members(1 - side)
	if pool.size() < 2:  # a leader on his own is no wall
		pool = standing(battle.active(1 - side))
	if pool.is_empty():
		return out
	var keyed := []
	for e in pool:
		keyed.append([_distance_to(mine, e.pos), BattleGrid.distance(leader.pos, e.pos), e.id, e])
	keyed.sort()
	var k := maxi(1, roundi(pool.size() * battle.rules.ai_threat_fraction))
	for i in mini(k, keyed.size()):
		out.append(keyed[i][3])
	return out


## Where the threat stands (cartesian): the centre of `threat_men`, each
## weighted by 1 / (1 + his distance from our wall), so the nearest part of
## their line counts most. Vector2.INF when there is no enemy.
static func threat_point(battle: Battle, side: int) -> Vector2:
	var men := threat_men(battle, side)
	if men.is_empty():
		return Vector2.INF
	var mine := battle.wall_members(side)
	if mine.is_empty():
		mine = [battle.leader_of(side)]
	var sum := Vector2.ZERO
	var wsum := 0.0
	for e in men:
		var wt := 1.0 / (1.0 + _distance_to(mine, e.pos))
		sum += BattleGrid.to_cart(Vector2(e.pos)) * wt
		wsum += wt
	return sum / wsum


## True when the enemy's nearest man stands behind the plane of our line
## through the leader: their line's end is already past ours.
static func outflanked(battle: Battle, side: int) -> bool:
	var leader := battle.leader_of(side)
	var men := threat_men(battle, side)
	if leader == null or men.is_empty():
		return false
	var rel := BattleGrid.to_cart(Vector2(men[0].pos)) - BattleGrid.to_cart(Vector2(leader.pos))
	return rel.dot(front_vector(leader.wall_axis(), leader.wall_facing())) < -0.5


# --- Wheeling ------------------------------------------------------------------

## Signed stances (-4..4, right-hand positive) from the leader's stance to
## the one fronting `target` (cartesian).
static func steps_toward(leader: Warrior, target: Vector2) -> int:
	var want := BattleGrid.state_toward(target - BattleGrid.to_cart(Vector2(leader.pos)))
	var n := BattleGrid.STATES.size()
	var diff := posmod(BattleGrid.state_of(want[0], want[1]) - BattleGrid.state_of(leader.wall_axis(), leader.wall_facing()), n)
	return diff if diff <= n / 2 else diff - n


## A cunning leader's read of a wall marching across his front: when their
## nearest man is more than one stance (45 degrees) off his front and their
## leader is moving, the point they are making for, `ai_cunning_lead` hexes
## along their own wall facing from the threat. Vector2.INF otherwise.
func _cunning_target(battle: Battle, side: int, leader: Warrior, moving: bool) -> Vector2:
	if doctrine != Doctrine.CUNNING or not moving:
		return Vector2.INF
	var men := threat_men(battle, side)
	var el := battle.leader_of(1 - side)
	if men.is_empty() or el == null:
		return Vector2.INF
	var rel := BattleGrid.to_cart(Vector2(men[0].pos)) - BattleGrid.to_cart(Vector2(leader.pos))
	var front := front_vector(leader.wall_axis(), leader.wall_facing())
	if rel.length() < 0.01 or absf(rad_to_deg(front.angle_to(rel))) <= 45.0:
		return Vector2.INF
	var tp := threat_point(battle, side)
	var lead := front_vector(el.wall_axis(), el.wall_facing()) * battle.rules.ai_cunning_lead * sqrt(3.0)
	return tp + lead


## Turns the wall toward the threat (`threat_point`) when it is
## `ai_threat_wheel_min_steps` stances or more off his front: one stance a
## round, two when he is already outflanked. A cunning leader whose front is
## being marched across wheels toward where they are going as soon as that
## is a stance off. Never while any of his wall is engaged: wheeling in a
## melee is chaos. True if he wheeled.
func _wheel_if_needed(battle: Battle, side: int, leader: Warrior, moving: bool) -> bool:
	if _engaged(battle, battle.wall_members(side), side) or _engaged(battle, [leader] as Array[Warrior], side):
		return false
	var target := _cunning_target(battle, side, leader, moving)
	var min_steps := 1
	if target == Vector2.INF:
		target = threat_point(battle, side)
		min_steps = battle.rules.ai_threat_wheel_min_steps
	if target == Vector2.INF:
		return false
	var steps := steps_toward(leader, target)
	if absi(steps) < min_steps:
		return false
	var turn := 1 if steps > 0 else -1
	if absi(steps) >= 2 and outflanked(battle, side):
		turn *= 2
	leader.wheel_wall(turn)
	battle.log.append("%s wheels his line %s toward %s" % [leader.display_name, "right" if turn > 0 else "left",
			BattleGrid.AXIS_NAMES[leader.wall_axis()]])
	return true


# --- Refusing the flank --------------------------------------------------------

## When an enemy wall member stands within `ai_refuse_range` of an end of
## our wall, beyond it or behind the line there, the outermost men at that
## end hinge back one facing toward him: the end man at once, the next only
## once the man outside him has already hinged (a round later), and so on
## up to `ai_refuse_men`. One facing from the wall's facing, and never more
## than one from the man inside him, so the wall stays linked. Logged once
## a spell. Called every round from `choose`, after the battle has dressed
## the line (which turns them back when the threat is gone).
func refuse_flanks(battle: Battle, side: int, leader: Warrior) -> void:
	var hinged_now := {}
	var wall := battle.wall_members(side)
	var theirs := battle.wall_members(1 - side)
	if wall.size() < 3 or theirs.size() < 2:
		_hinged = hinged_now
		_refusing.clear()
		return
	var wf := leader.wall_facing()
	var fv := front_vector(leader.wall_axis(), wf)
	var rv := right_vector(leader.wall_axis(), wf)
	var lp := BattleGrid.to_cart(Vector2(leader.pos))
	for right in [true, false]:
		var sgn := 1.0 if right else -1.0
		# Outermost first: furthest along that hand, front rank before rear.
		var keyed := []
		for m in wall:
			var rel := BattleGrid.to_cart(Vector2(m.pos)) - lp
			keyed.append([-rel.dot(rv) * sgn, -rel.dot(fv), m.id, m])
		keyed.sort()
		var end: Warrior = keyed[0][3]
		var end_c := BattleGrid.to_cart(Vector2(end.pos))
		var threat := false
		for e in theirs:
			if BattleGrid.distance(e.pos, end.pos) > battle.rules.ai_refuse_range:
				continue
			var rel := BattleGrid.to_cart(Vector2(e.pos)) - end_c
			var along := rel.dot(rv) * sgn
			var fwd := rel.dot(fv)
			# Beyond the end and level with it, or behind the line there; a
			# man beyond the end but in front of it is in the front arcs.
			if (along > 0.8 and fwd < 0.8) or (fwd < -0.5 and along > -1.0):
				threat = true
				break
		if not threat:
			_refusing[right] = false
			continue
		if not _refusing.get(right, false):
			battle.log.append("%s's %s hand refuses the flank" % [leader.display_name, "right" if right else "left"])
			_refusing[right] = true
		var hinge := BattleGrid.rotate(wf, 1 if right else -1)
		var outer_was_hinged := true
		for i in mini(battle.rules.ai_refuse_men, keyed.size() - 1):
			var m: Warrior = keyed[i][3]
			if m == leader or not outer_was_hinged:
				break
			if m.facing != wf and m.facing != hinge:
				break  # still dressing, or turned to fight: leave him be
			# He must stay linked to the man inside him, and to the man
			# outside him who has already hinged: on some stances two men
			# turned the same way would stand one behind the other.
			var inner: Warrior = keyed[i + 1][3]
			var inner_face: Vector2i = inner.wall_facing() if inner == leader else inner.facing
			if BattleGrid.distance(m.pos, inner.pos) == 1 \
					and not BattleGrid.linked_at(m.pos, hinge, inner.pos, inner_face, battle.rules.wall_link_turn):
				break
			if i > 0:
				var outer: Warrior = keyed[i - 1][3]
				if BattleGrid.distance(m.pos, outer.pos) == 1 \
						and not BattleGrid.linked_at(m.pos, hinge, outer.pos, outer.facing, battle.rules.wall_link_turn):
					break
			outer_was_hinged = _hinged.has(m)
			m.facing = hinge
			hinged_now[m] = true
	_hinged = hinged_now


# --- Shouts --------------------------------------------------------------------

func _within(leader: Warrior, theirs: Array[Warrior], range: int) -> bool:
	for e in theirs:
		if BattleGrid.distance(leader.pos, e.pos) <= range:
			return true
	return false


func _answer_rng(battle: Battle, side: int) -> SimRng:
	return battle.rng.fork("taunt-answer:%d:%d" % [side, battle.round])


## Ranks against ranks, nobody engaged: whether a steady or cunning leader
## has reason to come on (the numbers, or an enemy that is wavering).
func _ranks_should_push(battle: Battle, side: int) -> bool:
	var rules := battle.rules
	var ours := strength(rules, battle.active(side))
	var theirs := strength(rules, battle.active(1 - side))
	if ours >= theirs * rules.ai_push_advantage:
		return true
	return mean_morale(battle.active(1 - side)) < rules.ai_push_when_wavering


func choose(battle: Battle, side: int) -> CombatTypes.Shout:
	var mine := battle.active(side)
	var theirs := battle.active(1 - side)
	var leader := battle.leader_of(side)
	if mine.is_empty() or leader == null:
		return CombatTypes.Shout.NONE
	var el := battle.leader_of(1 - side)
	var moving := false
	if el != null:
		moving = (_enemy_leader_was != NO_POS and el.pos != _enemy_leader_was) \
				or battle.standing_order(1 - side) == CombatTypes.Shout.PUSH
		_enemy_leader_was = el.pos
	if doctrine != Doctrine.RECKLESS:
		_wheel_if_needed(battle, side, leader, moving)
		refuse_flanks(battle, side, leader)
	var started := battle.result.started[side]
	var unbroken := 0
	for w in mine:
		if not w.broken:
			unbroken += 1
	# Too few left: get out.
	if unbroken * 100 < started * battle.rules.ai_fall_back_percent:
		return CombatTypes.Shout.FALL_BACK
	# Enemy is crumbling: finish it.
	var enemy_broken := 0
	for e in theirs:
		if e.broken:
			enemy_broken += 1
	if theirs.is_empty() or enemy_broken * 100 >= theirs.size() * battle.rules.ai_break_them_percent:
		return CombatTypes.Shout.BREAK_THEM
	if doctrine == Doctrine.RECKLESS:
		return CombatTypes.Shout.BREAK_THEM
	# Scattered: gather.
	var spread := 0
	for w in mine:
		spread += BattleGrid.chebyshev(w.pos, leader.pos)
	if mine.size() > 1 and spread > mine.size() * battle.rules.ai_scatter_mean_distance:
		return CombatTypes.Shout.TO_ME
	# Form first, then hold until contact, then push.
	if battle.round <= battle.rules.ai_form_rounds:
		return CombatTypes.Shout.SHIELD_WALL
	var in_contact := 0
	for w in mine:
		if not battle.grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			in_contact += 1
	var aggressive := doctrine == Doctrine.AGGRESSIVE
	# Ranks against ranks: a steady or cunning leader will not walk into the
	# spears behind their shields unless he has reason to.
	var ranks_hold := not aggressive and ranked(leader) and ranked(el)
	if in_contact == 0:
		if ranks_hold:
			if _ranks_should_push(battle, side):
				return CombatTypes.Shout.PUSH
		else:
			if aggressive or battle.round > battle.rules.ai_form_rounds + battle.rules.ai_patience_rounds:
				return CombatTypes.Shout.PUSH
			# Taunted while standing: a proud man comes on.
			if battle.taunted_round(side) >= battle.round - 1 and _answer_rng(battle, side).randf() < battle.rules.taunt_answer_chance:
				battle.log.append("%s will not stand and be called a coward" % leader.display_name)
				return CombatTypes.Shout.PUSH
		# A holding enemy who will not come to us gets jeered at.
		var their_order := battle.standing_order(1 - side)
		var they_hold := their_order != CombatTypes.Shout.PUSH and their_order != CombatTypes.Shout.BREAK_THEM
		if they_hold and battle.round % battle.rules.taunt_ai_every == 0 and _within(leader, theirs, battle.rules.taunt_range):
			return CombatTypes.Shout.TAUNT
		return CombatTypes.Shout.HOLD
	_formed_rounds += 1
	if aggressive or _formed_rounds > battle.rules.ai_hold_rounds_before_push:
		return CombatTypes.Shout.PUSH
	return CombatTypes.Shout.HOLD
