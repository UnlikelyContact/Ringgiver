class_name LeaderAI
extends RefCounted
## Picks a shout for an AI-led side each round. Deliberately simple: a
## doctrine plus a few situational overrides. Enemy leaders use the same
## shout system as the player (concept.md, Combat), so this is also what the
## player's men would hear if they could read the enemy.

enum Doctrine { STEADY, AGGRESSIVE, RECKLESS }

var doctrine: Doctrine = Doctrine.STEADY
var _formed_rounds := 0
var _last_wheel_round := -99


func _init(p_doctrine: Doctrine = Doctrine.STEADY) -> void:
	doctrine = p_doctrine


## Turns the wall toward the enemy's centre only when they are two or more
## steps (120 degrees or more) off its facing; a 60-degree offset is within
## the front arcs and not worth the shuffle of wheeling.
func _wheel_if_needed(battle: Battle, leader: Warrior, theirs: Array[Warrior]) -> void:
	if theirs.is_empty():
		return
	var sum := Vector2.ZERO
	for e in theirs:
		sum += BattleGrid.to_cart(Vector2(e.pos))
	var want := BattleGrid.state_toward(sum / theirs.size() - BattleGrid.to_cart(Vector2(leader.pos)))
	var n := BattleGrid.STATES.size()
	var diff := posmod(BattleGrid.state_of(want[0], want[1]) - BattleGrid.state_of(leader.wall_axis(), leader.wall_facing()), n)
	if battle.round - _last_wheel_round < battle.rules.ai_wheel_cooldown:
		return
	if diff >= battle.rules.ai_wheel_min_steps and diff <= n - battle.rules.ai_wheel_min_steps:
		_last_wheel_round = battle.round
		# One stance a round: the line follows the wheel over the rounds after.
		leader.wheel_wall(1 if diff <= n / 2 else -1)
		battle.log.append("%s wheels his line toward %s" % [leader.display_name, BattleGrid.AXIS_NAMES[leader.wall_axis()]])


func _within(leader: Warrior, theirs: Array[Warrior], range: int) -> bool:
	for e in theirs:
		if BattleGrid.distance(leader.pos, e.pos) <= range:
			return true
	return false


func _answer_rng(battle: Battle, side: int) -> SimRng:
	return battle.rng.fork("taunt-answer:%d:%d" % [side, battle.round])


func choose(battle: Battle, side: int) -> CombatTypes.Shout:
	var mine := battle.active(side)
	var theirs := battle.active(1 - side)
	var leader := battle.leader_of(side)
	if mine.is_empty() or leader == null:
		return CombatTypes.Shout.NONE
	_wheel_if_needed(battle, leader, theirs)
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
	if in_contact == 0:
		if doctrine == Doctrine.AGGRESSIVE or battle.round > battle.rules.ai_form_rounds + battle.rules.ai_patience_rounds:
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
	if doctrine == Doctrine.AGGRESSIVE or _formed_rounds > battle.rules.ai_hold_rounds_before_push:
		return CombatTypes.Shout.PUSH
	return CombatTypes.Shout.HOLD
