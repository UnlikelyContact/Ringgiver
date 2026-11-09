class_name BattleResult
extends RefCounted
## What a battle produced. Filled by Battle.run; read by the batch runner,
## the campaign layer (effort, fates) and the replay tool.

var winner := -1  # side, or -1 for a draw / timeout
var rounds := 0
## True when the field's objective decided the fight (taken, or held until
## the time ran out) rather than a line breaking or both drawing off.
var by_objective := false
var seed_value := 0
## Per side (index 0/1): counts at the end of the battle.
var started: Array[int] = [0, 0]
var downed: Array[int] = [0, 0]
var broken: Array[int] = [0, 0]
var fled: Array[int] = [0, 0]
var dead: Array[int] = [0, 0]
var maimed: Array[int] = [0, 0]
var log := PackedStringArray()


func losses(side: int) -> int:
	return downed[side] + fled[side]


func summary() -> String:
	var who := "draw" if winner < 0 else "side %d wins" % winner
	return "%s after %d rounds | A: %d/%d down, %d broken, %d fled, %d dead | B: %d/%d down, %d broken, %d fled, %d dead" % [
		who, rounds,
		downed[0], started[0], broken[0], fled[0], dead[0],
		downed[1], started[1], broken[1], fled[1], dead[1],
	]
