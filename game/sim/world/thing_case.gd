class_name ThingCase
extends RefCounted
## One case before the Thing, filled in stage by stage by `Thing`.
## The verdict is judged against the defendant: COMPENSATION means the
## defendant pays `wergild`, the outlawries fall on the defendant, FAILED
## means the plaintiff's case fails and the dispute goes to the sword.

var kind: WorldTypes.CaseKind = WorldTypes.CaseKind.RAID
## The family on the other side.
var against := ""
## The house the band speaks for, when the case is another house's ("" when
## it is the band's own). The verdict's silver is the client's, and a
## failed case is the client's to carry, not a feud of the band's.
var client := ""
## The houses that stood with the band and with the other side (Families).
var houses_with: Array = []
var houses_against: Array = []
## Ounces claimed (raid, land, insult). Killings use `wergild(victim_rank)`.
var claim := 0
var plaintiff_is_band := true
## Rank of the dead man in a killing case.
var victim_rank: WorldTypes.Rank = WorldTypes.Rank.KARL
## Spend `lawman_fee` for one reroll of a procedural slip.
var lawman_hired := false
var supporters := 0
var their_supporters := 0
## Armed men the family brings (the band's armed men are its fighters).
var their_armed := 0
var procedure_ok := true
var weight_us := 0.0
var weight_them := 0.0
var violence := false
## {} or the thing_brawl battle request from the standoff.
var battle_required := {}
var verdict: WorldTypes.Verdict = WorldTypes.Verdict.PENDING
## Ounces the defendant pays under a COMPENSATION verdict.
var wergild := 0
var log: PackedStringArray = []


func note(line: String) -> void:
	log.append(line)


func describe() -> String:
	return "%s case, %s %s: %s" % [
		String(WorldTypes.CaseKind.keys()[kind]).to_lower(),
		"the band against" if plaintiff_is_band else "brought by", against,
		WorldTypes.VERDICT_NAMES[verdict]]
