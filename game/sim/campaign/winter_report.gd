class_name WinterReport
extends RefCounted
## What one winter turn did. Loyalty, growth, fame and bonds are applied by
## the campaign loop from these fields, not by the winter module.

var turn: CampaignTypes.WinterTurn = CampaignTypes.WinterTurn.EARLY
var fed := {}  # man id -> bool (leader included)
var seated := {}  # man id -> bool (sworn men only)
var food_eaten := 0
var food_gained := 0
var food_spoiled := 0
var drilled := {}  # man id -> CombatTypes.Stat
var drilled_shape := ""  # the shape they practised, if any
var healed: Array[int] = []  # men whose healing_turns reached 0 this turn
var repaired := 0  # units of ship damage restored
var shields_mended := false  # true when anyone REPAIRed: the loop resets shields
var feasted := false
var vow := ""
var gifts := {}  # man id -> ounces actually given (for Module F to score)
var events: Array[Dictionary] = []
var battle_required := {}  # {} or {kind, attackers, tier, against}
var men_without_seat: Array[int] = []  # at THAW: everyone unseated at any turn this winter


func unfed_ids() -> Array[int]:
	var out: Array[int] = []
	for id in fed:
		if not fed[id]:
			out.append(id)
	return out
