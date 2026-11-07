class_name LeaderAI
extends RefCounted
## Picks a shout for an AI-led side each round. Deliberately simple: a
## doctrine plus a few situational overrides. Enemy leaders use the same
## shout system as the player (concept.md, Combat), so this is also what the
## player's men would hear if they could read the enemy.

enum Doctrine { STEADY, AGGRESSIVE, RECKLESS }

var doctrine: Doctrine = Doctrine.STEADY
var _formed_rounds := 0


func _init(p_doctrine: Doctrine = Doctrine.STEADY) -> void:
	doctrine = p_doctrine


func choose(battle: Battle, side: int) -> CombatTypes.Shout:
	var mine := battle.active(side)
	var theirs := battle.active(1 - side)
	var leader := battle.leader_of(side)
	if mine.is_empty() or leader == null:
		return CombatTypes.Shout.NONE
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
		return CombatTypes.Shout.PUSH if doctrine == Doctrine.AGGRESSIVE else CombatTypes.Shout.HOLD
	_formed_rounds += 1
	if doctrine == Doctrine.AGGRESSIVE or _formed_rounds > battle.rules.ai_hold_rounds_before_push:
		return CombatTypes.Shout.PUSH
	return CombatTypes.Shout.HOLD
