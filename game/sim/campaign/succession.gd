class_name Succession
extends RefCounted
## Heirs and the grave-ale (concept.md, Succession, Loyalty must be won again,
## The grave-ale, What carries over). Every value comes from CampaignRules
## (section "Leader, family and succession").
##
## How the old leader died is passed to `succeed` as `death_cause` ("battle",
## "old", "outlaw", "sickness", "oathbreaker"; "" for unknown). It is also
## recorded on the band as metadata (DEATH_CAUSES_META: leader name -> cause)
## so Chronicle.generation_text can close a generation with the right line.
## A passed-over second who challenges the heir is recorded as metadata
## PENDING_CHALLENGE_META (his man id) for the loop to fight as a holmgang.

const DEATH_CAUSES_META := &"death_causes"
const PENDING_CHALLENGE_META := &"pending_challenge"


## Who takes the high seat: {kind: "son"|"second"|"none", son: Dictionary or
## null, man: Man or null}. A son of age comes before the sworn second.
static func heir(rules: CampaignRules, band: Band, cal: Calendar) -> Dictionary:
	var sons := Family.sons_of_age(rules, band, cal)
	if not sons.is_empty():
		return {"kind": "son", "son": sons[0], "man": null}
	var second := _second(band)
	if second != null:
		return {"kind": "second", "son": null, "man": second}
	return {"kind": "none", "son": null, "man": null}


static func name_second(band: Band, m: Man, log: PackedStringArray) -> void:
	band.sworn_second_id = m.id
	var who := band.leader.display_name if band.leader != null else "The leader"
	var text := "%s named %s his sworn second" % [who, m.display_name]
	log.append(text)
	band.log(text)


## The heir takes the high seat. `heir_man` is the sworn second, or a son the
## loop has built with Recruits.son_of. Feuds carry over untouched; luck and
## fame carry in part; the grave-ale costs `feast_ounces` (no more than the
## band holds) and every man decides again whether to stay. Returns the men
## who leave; they are already removed from band.men.
static func succeed(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, heir_man: Man,
		feast_ounces: int, vow: String, log: PackedStringArray, death_cause := "") -> Array[Man]:
	var old := band.leader
	var old_name := old.display_name if old != null else "the old leader"
	var passed_second: Man = null
	var second := _second(band)
	if second != null and second != heir_man:
		passed_second = second

	# The high seat.
	if old != null:
		old.is_leader = false
	if band.men.has(heir_man):
		band.remove_man(heir_man)
	heir_man.is_leader = true
	band.leader = heir_man
	if band.sworn_second_id == heir_man.id:
		band.sworn_second_id = -1
	_record_death(band, old_name, death_cause)
	var head := "%s is dead%s; %s takes the high seat" % [old_name, _cause_phrase(death_cause), heir_man.display_name]
	log.append(head)
	band.log(head)

	# What carries over. Feuds stay on the band in full.
	var luck := roundi(band.luck * rules.luck_inherit_fraction)
	if death_cause == "battle":
		luck += rules.luck_good_death
	elif rules.shameful_deaths.has(death_cause):
		luck -= rules.luck_shameful_death
	band.luck = clampi(luck, Leader.LUCK_MIN, Leader.LUCK_MAX)
	band.fame = clampi(roundi(band.fame * rules.fame_inherit_fraction), Leader.REP_MIN, Leader.REP_MAX)
	var open := band.unsettled_feuds().size()
	if open > 0:
		log.append("%s inherits %d feud%s" % [heir_man.display_name, open, "" if open == 1 else "s"])

	# The grave-ale.
	var spent := clampi(feast_ounces, 0, band.silver)
	band.silver -= spent
	var feast_bonus := spent * rules.feast_bonus_per_ounce
	var ale := "%s held the grave-ale for %s" % [heir_man.display_name, old_name]
	if spent > 0:
		ale += " and spent %d ounces on it" % spent
	log.append(ale)
	band.log(ale)

	var challenger: Man = null
	var leaving: Array[Man] = []
	if passed_second != null and band.bond(passed_second, heir_man) < 0:
		if rng.randf() < rules.challenge_chance:
			challenger = passed_second
			band.set_meta(PENDING_CHALLENGE_META, passed_second.id)
			var ch := "%s would not drink to %s and challenged him to the holmgang" % [
				passed_second.display_name, heir_man.display_name]
			log.append(ch)
			band.log(ch)
		else:
			leaving.append(passed_second)
			for m in band.living_men():
				if m != passed_second and band.bond_kind(passed_second, m) == CampaignTypes.BondKind.OATH_BROTHER:
					leaving.append(m)
			var gone := "%s would not serve %s and left" % [passed_second.display_name, heir_man.display_name]
			log.append(gone)
			band.log(gone)

	var fame_pull := band.fame / 10.0
	for m in band.living_men():
		if m == challenger or leaving.has(m):
			continue
		var score := m.loyalty + band.bond(m, heir_man) + fame_pull + feast_bonus
		if score < rules.stay_threshold:
			leaving.append(m)
			log.append("%s would not drink the oath cup to %s, and left" % [m.display_name, heir_man.display_name])
		else:
			log.append("%s drank the oath cup to %s" % [m.display_name, heir_man.display_name])
	for m in leaving:
		band.remove_man(m)
		if band.sworn_second_id == m.id:
			band.sworn_second_id = -1
	if not leaving.is_empty():
		band.log("%d men left rather than serve %s" % [leaving.size(), heir_man.display_name])

	if vow != "":
		band.vows.append({"year": cal.year, "text": vow, "kept": null})
		var v := "%s vowed at the grave-ale: %s" % [heir_man.display_name, vow]
		log.append(v)
		band.log(v)
	return leaving


static func death_cause_of(band: Band, leader_name: String) -> String:
	if not band.has_meta(DEATH_CAUSES_META):
		return ""
	var causes: Dictionary = band.get_meta(DEATH_CAUSES_META)
	return str(causes.get(leader_name, ""))


static func _record_death(band: Band, leader_name: String, cause: String) -> void:
	var causes: Dictionary = band.get_meta(DEATH_CAUSES_META) if band.has_meta(DEATH_CAUSES_META) else {}
	causes[leader_name] = cause
	band.set_meta(DEATH_CAUSES_META, causes)


static func _cause_phrase(cause: String) -> String:
	match cause:
		"battle":
			return ", fallen in battle"
		"old":
			return ", of old age"
		"outlaw":
			return ", an outlaw"
		"sickness":
			return ", of a fever"
		"oathbreaker":
			return ", an oath-breaker"
	return ""


static func _second(band: Band) -> Man:
	if band.sworn_second_id < 0:
		return null
	for m in band.men:
		if m.id == band.sworn_second_id and m.alive:
			return m
	return null
