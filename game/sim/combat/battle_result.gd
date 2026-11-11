class_name BattleResult
extends RefCounted
## What a battle produced. Filled by Battle.run; read by the batch runner,
## the campaign layer (effort, fates) and the replay tool.

var winner := -1  # side, or -1 for a draw / timeout
var rounds := 0
## How the fight ended (set with `winner` by Battle._finish): a line routed
## (nobody standing, or broken), a side drew off the field in order, both
## drew off (a stall), the objective decided it, the light failed, or a
## side withdrew by its leader's choice before the lines met again.
enum End { ROUT, DRAW_OFF, STALL, OBJECTIVE, TIMEOUT, WITHDRAWAL }
var how: End = End.STALL
## What the fight was for a side, best to worst: the ladder the campaign
## reads (concept.md, "Picking your fights"). A rout is worth more than a
## drive-off; a withdrawal costs standing, not the battle; both drawing off
## is nobody's day.
enum Outcome { ROUTED_THEM, DROVE_THEM_OFF, WON_THE_FIELD, BOTH_DREW_OFF, WITHDREW, DRIVEN_OFF, ROUTED, LOST_THE_FIELD }
const OUTCOME_NAMES := ["routed them", "drove them off", "won the field", "both drew off",
	"withdrew", "driven off", "routed", "lost the field"]
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


## The outcome for `side`, from `winner` and `how`.
func outcome(side: int) -> Outcome:
	if winner < 0:
		return Outcome.BOTH_DREW_OFF
	if winner == side:
		match how:
			End.ROUT:
				return Outcome.ROUTED_THEM
			End.DRAW_OFF, End.WITHDRAWAL:
				return Outcome.DROVE_THEM_OFF
			_:
				return Outcome.WON_THE_FIELD
	match how:
		End.ROUT:
			return Outcome.ROUTED
		End.DRAW_OFF:
			return Outcome.DRIVEN_OFF
		End.WITHDRAWAL:
			return Outcome.WITHDREW
		_:
			return Outcome.LOST_THE_FIELD


func won(side: int) -> bool:
	return winner == side


## A withdrawal is a choice, not a defeat: the side left in order before
## the lines met again.
func withdrew(side: int) -> bool:
	return outcome(side) == Outcome.WITHDREW


func outcome_text(side: int) -> String:
	return OUTCOME_NAMES[outcome(side)]


func summary() -> String:
	var who := "draw" if winner < 0 else "side %d wins" % winner
	return "%s after %d rounds | A: %d/%d down, %d broken, %d fled, %d dead | B: %d/%d down, %d broken, %d fled, %d dead" % [
		who, rounds,
		downed[0], started[0], broken[0], fled[0], dead[0],
		downed[1], started[1], broken[1], fled[1], dead[1],
	]
