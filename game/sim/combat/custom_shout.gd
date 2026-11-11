class_name CustomShout
extends RefCounted
## A shout of the band's own (concept.md, "Drill, custom formations and
## custom shouts"): a name, a formation template and an order. "Swine!"
## might be the boar's snout and push; "Hedgehog!" refused flanks and
## hold. Calling it (Battle.call_custom) forms the template this round and
## gives the order the next, through the same shout system: it carries by
## distance, can be misheard, and a man who has never drilled the shape
## hears a word he does not know (Warrior.drill) and does what the men
## beside him do.

var name := ""
var template: FormationTemplate = null
var order: CombatTypes.Shout = CombatTypes.Shout.HOLD


static func make(p_name: String, p_template: FormationTemplate, p_order: CombatTypes.Shout) -> CustomShout:
	var s := CustomShout.new()
	s.name = p_name
	s.template = p_template
	s.order = p_order
	return s


func describe() -> String:
	return "%s (%s, then %s)" % [name, template.name if template != null else "line", CombatTypes.SHOUT_NAMES[order]]
