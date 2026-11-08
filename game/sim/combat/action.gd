class_name Action
extends RefCounted
## What one man intends to do this round. Produced by Decision, consumed by
## Battle. Actions are decided simultaneously and resolved in fixed beats.

var kind: CombatTypes.ActionKind = CombatTypes.ActionKind.IDLE
## For MOVE: destination cell (must be adjacent). For ATTACK/SHOOT: target.
var target_cell := Vector2i.ZERO
var target: Warrior = null
## New facing after the action, or Vector2i.ZERO to keep the current one.
var new_facing := Vector2i.ZERO
## For SHOOT: a thrown spear rather than an arrow.
var thrown := false


static func brace(facing := Vector2i.ZERO) -> Action:
	var a := Action.new()
	a.kind = CombatTypes.ActionKind.BRACE
	a.new_facing = facing
	return a


static func move_to(cell: Vector2i, facing := Vector2i.ZERO) -> Action:
	var a := Action.new()
	a.kind = CombatTypes.ActionKind.MOVE
	a.target_cell = cell
	a.new_facing = facing
	return a


static func attack(enemy: Warrior) -> Action:
	var a := Action.new()
	a.kind = CombatTypes.ActionKind.ATTACK
	a.target = enemy
	a.target_cell = enemy.pos
	return a


static func shoot(enemy: Warrior) -> Action:
	var a := Action.new()
	a.kind = CombatTypes.ActionKind.SHOOT
	a.target = enemy
	a.target_cell = enemy.pos
	return a


static func throw_at(enemy: Warrior) -> Action:
	var a := shoot(enemy)
	a.thrown = true
	return a


static func flee(cell: Vector2i) -> Action:
	var a := Action.new()
	a.kind = CombatTypes.ActionKind.FLEE
	a.target_cell = cell
	return a


static func idle() -> Action:
	return Action.new()


func describe() -> String:
	match kind:
		CombatTypes.ActionKind.BRACE:
			return "brace"
		CombatTypes.ActionKind.MOVE:
			return "move to %s" % target_cell
		CombatTypes.ActionKind.ATTACK:
			return "attack %s" % (target.display_name if target else "?")
		CombatTypes.ActionKind.SHOOT:
			return "%s %s" % ["throw at" if thrown else "shoot", target.display_name if target else "?"]
		CombatTypes.ActionKind.FLEE:
			return "flee to %s" % target_cell
	return "idle"
