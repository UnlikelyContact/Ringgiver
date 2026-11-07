class_name Family
extends RefCounted
## Marriage, births and fostering (concept.md, Heirs). State lives on Band:
## `wife`, `household_skill`, `alliances` and `sons`, an Array[Dictionary] of
## children. A son is {name, born, potential, fostered_with, alive,
## daughter: false}; a daughter is {name, born, alive, daughter: true}. A son
## keeps his mother's potential array so the campaign loop can build him with
## Recruits.son_of when he comes of age; Family never builds a Man.
##
## The wife's potential is kept on the band as metadata (WIFE_POTENTIAL_META)
## because Band has no field for it.

const WIFE_POTENTIAL_META := &"wife_potential"


static func marry(rules: CampaignRules, band: Band, wife_name: String, wife_potential: Array[int],
		household_skill: int, alliance: String, log: PackedStringArray) -> void:
	band.wife = wife_name
	band.household_skill = clampi(household_skill, 0, rules.household_skill_max)
	band.set_meta(WIFE_POTENTIAL_META, wife_potential.duplicate())
	var who := band.leader.display_name if band.leader != null else "The leader"
	var text := "%s married %s" % [who, wife_name]
	if alliance != "":
		band.alliances.append(alliance)
		text += ", and so made an alliance with %s" % alliance
	log.append(text)
	band.log(text)


static func wife_potential(band: Band) -> Array[int]:
	var out: Array[int] = []
	if band.has_meta(WIFE_POTENTIAL_META):
		out.assign(band.get_meta(WIFE_POTENTIAL_META))
	return out


## Once per winter: if the leader is married, with birth_chance a child is
## born; daughter_chance of births are daughters. Returns the new sons only.
static func winter_births(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar,
		log: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if band.wife == "" or (band.leader != null and not band.leader.alive):
		return out
	if rng.randf() >= rules.birth_chance:
		return out
	var daughter := rng.randf() < rules.daughter_chance
	var who := band.leader.display_name if band.leader != null else "the leader"
	if daughter:
		var dname := _pick_name(rng, band, rules.daughter_names)
		band.sons.append({"name": dname, "born": cal.year, "alive": true, "daughter": true})
		var dtext := "%s bore %s a daughter, %s" % [band.wife, who, dname]
		log.append(dtext)
		band.log(dtext)
		return out
	var sname := _pick_name(rng, band, rules.son_names)
	var son := {
		"name": sname, "born": cal.year, "potential": wife_potential(band),
		"fostered_with": "", "alive": true, "daughter": false,
	}
	band.sons.append(son)
	out.append(son)
	var text := "%s bore %s a son, %s" % [band.wife, who, sname]
	log.append(text)
	band.log(text)
	return out


## Sends a son to be raised in another lord's hall: an alliance, but he is
## away until foster_returns_at_age.
static func foster_out(rules: CampaignRules, band: Band, son: Dictionary, lord: String,
		log: PackedStringArray) -> void:
	son["fostered_with"] = lord
	var alliance := "%s, who fosters %s" % [lord, son.get("name", "a son")]
	band.alliances.append(alliance)
	var text := "%s was sent to be fostered with %s" % [son.get("name", "a son"), lord]
	log.append(text)
	band.log(text)


static func age_of(son: Dictionary, cal: Calendar) -> int:
	return cal.year - int(son.get("born", cal.year))


static func is_son(child: Dictionary) -> bool:
	return not child.get("daughter", false)


## Living sons at home and old enough to lead, eldest first. A fostered son
## counts only once he is old enough to have come home.
static func sons_of_age(rules: CampaignRules, band: Band, cal: Calendar) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in band.sons:
		if not is_son(child) or not child.get("alive", true):
			continue
		var age := age_of(child, cal)
		if age < rules.heir_min_age:
			continue
		if str(child.get("fostered_with", "")) != "" and age < rules.foster_returns_at_age:
			continue
		out.append(child)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.born) < int(b.born))
	return out


static func _pick_name(rng: SimRng, band: Band, names: Array) -> String:
	var free: Array = []
	for n in names:
		var used := false
		for child in band.sons:
			if child.get("name", "") == n:
				used = true
				break
		if not used:
			free.append(n)
	var pool: Array = free if not free.is_empty() else names
	return str(pool[rng.randi_range(0, pool.size() - 1)])
