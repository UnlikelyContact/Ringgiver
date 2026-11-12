class_name Bonds
extends RefCounted
## Module F: ties between men. Fighting side by side builds bonds that can
## end in oath-brotherhood; clashing natures and drunken quarrels make
## rivals; a slain oath brother starts a feud. The values live in Band's bond
## table (Band.bond / set_bond / add_bond / bond_kind / set_bond_kind).
## See campaign-architecture.md > Module F.


## After a fight: every pair of survivors grows closer. Each survivor who
## lost an oath brother grieves (loyalty_grief loyalty per fallen brother).
## Then bonds that crossed a threshold become oath-brotherhood or rivalry.
## Call before the fallen are removed from the band.
static func after_battle(rules: CampaignRules, band: Band, survivors: Array[Man], fallen: Array[Man], log: PackedStringArray) -> void:
	for i in survivors.size():
		for j in range(i + 1, survivors.size()):
			band.add_bond(survivors[i], survivors[j], rules.bond_fought_together)
	for s in survivors:
		for f in fallen:
			if band.bond_kind(s, f) == CampaignTypes.BondKind.OATH_BROTHER:
				Loyalty.adjust(s, -rules.loyalty_grief)
				log.append("%s grieves for his oath brother %s: loyalty -%d (%d)" % [
					s.display_name, f.display_name, rules.loyalty_grief, s.loyalty])
	for i in survivors.size():
		for j in range(i + 1, survivors.size()):
			update_kind(rules, band, survivors[i], survivors[j], log)


## Once a winter, over every pair of the leader and his living men: clashing
## natures drift apart, men of the same origin drift together, and a reckless
## man and a steady one may quarrel in drink.
static func winter_drift(rng: SimRng, rules: CampaignRules, band: Band, log: PackedStringArray) -> void:
	var people := band.fighters()
	for i in people.size():
		for j in range(i + 1, people.size()):
			var a := people[i]
			var b := people[j]
			if clashes(rules, a, b):
				band.add_bond(a, b, -rules.bond_clash_drift)
			if a.origin == b.origin:
				band.add_bond(a, b, rules.bond_kin_drift)
			if _reckless_and_steady(a, b) and rng.randf() < rules.quarrel_chance:
				band.add_bond(a, b, -rules.bond_quarrel)
				log.append("%s and %s quarrel over the ale: bond -%d (%d)" % [
					a.display_name, b.display_name, rules.bond_quarrel, band.bond(a, b)])
			update_kind(rules, band, a, b, log)


## True when one man has a personality that personality_conflicts sets
## against one of the other's.
static func clashes(rules: CampaignRules, a: Man, b: Man) -> bool:
	for pair in rules.personality_conflicts:
		if (a.has_personality(pair[0]) and b.has_personality(pair[1])) \
				or (a.has_personality(pair[1]) and b.has_personality(pair[0])):
			return true
	return false


## Promotes a pair whose bond crossed a threshold. Oath-brotherhood is sworn
## once and never undone; rivalry replaces NONE or KIN, and a rival pair whose
## bond later climbs to the oath threshold may still swear brotherhood.
static func update_kind(rules: CampaignRules, band: Band, a: Man, b: Man, log: PackedStringArray) -> void:
	var kind := band.bond_kind(a, b)
	if kind == CampaignTypes.BondKind.OATH_BROTHER:
		return
	var v := band.bond(a, b)
	if v >= rules.bond_oath_threshold:
		band.set_bond_kind(a, b, CampaignTypes.BondKind.OATH_BROTHER)
		log.append("%s and %s swear oath-brotherhood (bond %d)" % [a.display_name, b.display_name, v])
		band.log("%s and %s mixed their blood under the turf and swore to avenge each other." % [
			a.display_name, b.display_name])
	elif v <= rules.bond_rival_threshold and kind != CampaignTypes.BondKind.RIVAL:
		band.set_bond_kind(a, b, CampaignTypes.BondKind.RIVAL)
		log.append("%s and %s are rivals now (bond %d)" % [a.display_name, b.display_name, v])
		band.log("There was bad blood between %s and %s." % [a.display_name, b.display_name])


## The living men (and the leader) sworn as oath brothers to m.
static func oath_brothers(band: Band, m: Man) -> Array[Man]:
	return _of_kind(band, m, CampaignTypes.BondKind.OATH_BROTHER)


## The living men (and the leader) who are m's rivals.
static func rivals(band: Band, m: Man) -> Array[Man]:
	return _of_kind(band, m, CampaignTypes.BondKind.RIVAL)


## A man has died at killer's hands: each of his oath brothers swears
## vengeance. One feud against the killer is opened (unless an unsettled one
## already stands), and every brother whose ambition is not already
## VENGEANCE or FAME now wants vengeance. Call before removing the dead man.
## The house of the killers, for `on_death`, when the caller does not know
## it: the old ways, a feud named for the killer himself.
const OLD_WAYS := "-"


## `house` is the house the killers belong to: the vengeance is a feud with
## it. "" (raiders, outlaws, men of no house): no feud, a private grudge
## sworn at the grave. OLD_WAYS: a feud named for the killer, as it was.
static func on_death(rules: CampaignRules, band: Band, dead: Man, killer: String, log: PackedStringArray,
		house := OLD_WAYS) -> void:
	var brothers := oath_brothers(band, dead)
	if brothers.is_empty():
		return
	var cause := "%s slain" % dead.display_name
	var against := killer if house == OLD_WAYS else house
	if against == "":
		log.append("no house answers for %s's death: a grudge against %s" % [dead.display_name, killer])
	elif band.add_feud(against, cause):
		log.append("feud opened against %s: %s" % [against, cause])
	for b in brothers:
		if b.ambition != CampaignTypes.Ambition.VENGEANCE and b.ambition != CampaignTypes.Ambition.FAME:
			b.ambition = CampaignTypes.Ambition.VENGEANCE
			b.ambition_progress = 0
			b.ambition_met = false
		log.append("%s vows vengeance on %s for his oath brother %s" % [b.display_name, killer, dead.display_name])
		if against == "":
			band.log("%s swore over %s's grave that %s would pay, though no house answers for him." % [b.display_name, dead.display_name, killer])
		else:
			band.log("%s swore over %s's grave that %s would pay." % [b.display_name, dead.display_name, against if house != OLD_WAYS else killer])


static func _of_kind(band: Band, m: Man, kind: CampaignTypes.BondKind) -> Array[Man]:
	var out: Array[Man] = []
	for other in band.fighters():
		if other != m and band.bond_kind(m, other) == kind:
			out.append(other)
	return out


static func _reckless_and_steady(a: Man, b: Man) -> bool:
	var r := CombatTypes.Personality.RECKLESS
	var s := CombatTypes.Personality.STEADY
	return (a.has_personality(r) and b.has_personality(s)) or (a.has_personality(s) and b.has_personality(r))
