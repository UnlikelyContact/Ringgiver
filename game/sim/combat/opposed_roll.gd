class_name OpposedRoll
extends RefCounted
## One opposed exchange: stat + modifiers + 2d6 on each side.
##
## The margin maps to a result tier (concept.md, Combat > Rolls). This class
## does not apply shield or armor absorption; that belongs to the wound step,
## so the raw table here can be tuned by simulation (see tools/margin_table.gd).

enum Tier { LOCKED, GLANCING, HIT, HEAVY }

const GLANCING_MAX := 2
const HIT_MAX := 5

var attacker_total: int
var defender_total: int
## Positive means the attacker won the exchange, negative the defender.
var margin: int


static func resolve(rng: SimRng, attacker_score: int, defender_score: int) -> OpposedRoll:
	var r := OpposedRoll.new()
	r.attacker_total = attacker_score + rng.roll_2d6()
	r.defender_total = defender_score + rng.roll_2d6()
	r.margin = r.attacker_total - r.defender_total
	return r


static func tier_for(margin_abs: int) -> Tier:
	if margin_abs <= 0:
		return Tier.LOCKED
	if margin_abs <= GLANCING_MAX:
		return Tier.GLANCING
	if margin_abs <= HIT_MAX:
		return Tier.HIT
	return Tier.HEAVY


func tier() -> Tier:
	return tier_for(absi(margin))


func attacker_won() -> bool:
	return margin > 0


func defender_won() -> bool:
	return margin < 0


static func tier_name(t: Tier) -> String:
	return ["locked", "glancing", "hit", "heavy"][t]
