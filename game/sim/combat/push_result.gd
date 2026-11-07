class_name PushResult
extends RefCounted
## Outcome of one push beat (Push.resolve).

## The side that won the most contests this beat; -1 if no lines were in
## contact or the contests came out even.
var winning_side := -1
## Men shoved one cell back.
var shoved: Array[Warrior] = []
## Men who lost the push but could not give ground (and lost breath).
var blocked: Array[Warrior] = []
## side -> summed push strength of that side's men in contact (float).
var strengths := {}
## Number of opposed contests rolled (one per touching pair of groups).
var contests := 0


func describe() -> String:
	if contests == 0:
		return "no push: the lines are not in contact"
	var parts := PackedStringArray()
	var sides := strengths.keys()
	sides.sort()
	for s in sides:
		parts.append("side %d %.1f" % [s, strengths[s]])
	var head := "push (%s): " % ", ".join(parts)
	if winning_side < 0:
		head += "the lines grind, neither gives"
	else:
		head += "side %d drives the other back" % winning_side
	return "%s; %d shoved, %d blocked" % [head, shoved.size(), blocked.size()]
