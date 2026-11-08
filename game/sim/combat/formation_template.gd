class_name FormationTemplate
extends RefCounted
## A shape a band forms on its leader's shout: which rank each role stands
## in. Rank 1 is the line itself, shoulder to shoulder through the leader;
## rank 2 stands directly behind rank 1, spears over the shoulders of the
## men in front; rank 3 stands two behind, loose, for bows. A role with
## rank 1 everywhere is the plain line everyone knows. The wedge is its own
## shape. Custom templates (the main game's drill yard) are the same thing
## with the player's own name and ranks.

enum Shape { LINE, WEDGE }

var name := "line"
var shape: Shape = Shape.LINE
## CombatTypes.Role -> rank (1, 2 or 3).
var rank_of := {CombatTypes.Role.SHIELD: 1, CombatTypes.Role.SPEAR: 1, CombatTypes.Role.MISSILE: 1}


static func line() -> FormationTemplate:
	return FormationTemplate.new()


## Shield-bearers in the line, spears behind them, bows two behind.
static func ranks() -> FormationTemplate:
	var t := FormationTemplate.new()
	t.name = "ranks"
	t.rank_of = {CombatTypes.Role.SHIELD: 1, CombatTypes.Role.SPEAR: 2, CombatTypes.Role.MISSILE: 3}
	return t


## Everyone in the line but the bows, who stand off behind.
static func bows_behind() -> FormationTemplate:
	var t := FormationTemplate.new()
	t.name = "bows behind"
	t.rank_of = {CombatTypes.Role.SHIELD: 1, CombatTypes.Role.SPEAR: 1, CombatTypes.Role.MISSILE: 3}
	return t


static func wedge() -> FormationTemplate:
	var t := FormationTemplate.new()
	t.name = "boar's snout"
	t.shape = Shape.WEDGE
	return t


## The shapes a leader can call without drill, in the order the HUD cycles them.
static func presets() -> Array[FormationTemplate]:
	return [ranks(), line(), bows_behind(), wedge()]


func rank(role: CombatTypes.Role) -> int:
	return int(rank_of.get(role, 1))
