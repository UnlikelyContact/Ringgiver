class_name FormationTemplate
extends RefCounted
## A shape a band forms on its leader's shout: which rank each role stands
## in. Rank 1 is the line itself, shoulder to shoulder through the leader;
## rank 2 stands directly behind rank 1, spears over the shoulders of the
## men in front; rank 3 stands two behind, loose, for bows. A role with
## rank 1 everywhere is the plain line everyone knows. The wedge is its own
## shape. Custom templates (the main game's drill yard) are the same thing
## with the player's own name and ranks.

## LINE: the row through the leader. WEDGE: the boar's snout, the leader
## at its tip. REFUSED: the row with its two end men a hex back, so a wall
## coming round an end meets a refused flank (the hedgehog).
enum Shape { LINE, WEDGE, REFUSED }

var name := "line"
var shape: Shape = Shape.LINE
## CombatTypes.Role -> rank (1, 2 or 3).
var rank_of := {CombatTypes.Role.SHIELD: 1, CombatTypes.Role.SPEAR: 1, CombatTypes.Role.MISSILE: 1}
## A learned shape is one the band must drill (concept.md, "Drill, custom
## formations and custom shouts"): its familiarity (Warrior.familiar, from
## Man.drill) is what the wall's one test rolls against, and a man who has
## never drilled it fumbles for his place. The plain shapes every leader
## knows are not learned.
var learned := false


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
	t.learned = true
	return t


## Shields in the line with its ends drawn back, spears behind, bows two
## behind: the hedgehog, a learned shape.
static func refused() -> FormationTemplate:
	var t := ranks()
	t.name = "refused flanks"
	t.shape = Shape.REFUSED
	t.learned = true
	return t


## A shape of the band's own: a name, a shape and the rank each role
## stands in. Always learned.
static func custom(p_name: String, p_shape: Shape, p_rank_of: Dictionary) -> FormationTemplate:
	var t := FormationTemplate.new()
	t.name = p_name
	t.shape = p_shape
	t.rank_of = p_rank_of.duplicate()
	t.learned = true
	return t


## The shapes a leader can call, in the order the HUD cycles them: the
## three every leader knows, then the learned ones.
static func presets() -> Array[FormationTemplate]:
	return [ranks(), line(), bows_behind(), wedge(), refused()]


## The preset of this name, or null.
static func named(p_name: String) -> FormationTemplate:
	for t in presets():
		if t.name == p_name:
			return t
	return null


func rank(role: CombatTypes.Role) -> int:
	return int(rank_of.get(role, 1))
