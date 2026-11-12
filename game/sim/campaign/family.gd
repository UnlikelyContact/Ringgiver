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
## The house the wife came from (the Families marriage tie), "" for none.
const WIFE_HOUSE_META := &"wife_house"
## The heir the leader has named among his sons (a child's name).
const HEIR_META := &"named_heir"
## The old leader's widow, who keeps the keys until the new man marries.
const MOTHER_META := &"mother"
## The old man of the hall: a leader who stepped down ({name, born, year}).
const OLD_MAN_META := &"old_man"


static func marry(rules: CampaignRules, band: Band, wife_name: String, wife_potential: Array[int],
		household_skill: int, alliance: String, log: PackedStringArray) -> void:
	band.wife = wife_name
	band.household_skill = clampi(household_skill, 0, rules.household_skill_max)
	band.set_meta(WIFE_POTENTIAL_META, wife_potential.duplicate())
	band.set_meta(WIFE_HOUSE_META, alliance)
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
		band.sons.append({"name": dname, "born": cal.year, "alive": true, "daughter": true, "father": who})
		var dtext := "%s bore %s a daughter, %s" % [band.wife, who, dname]
		log.append(dtext)
		band.log(dtext)
		return out
	var sname := _pick_name(rng, band, rules.son_names)
	var son := {
		"name": sname, "born": cal.year, "potential": wife_potential(band),
		"fostered_with": "", "alive": true, "daughter": false, "father": who,
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


# --- The household on the player's path (docs/design/notes/generations.md) ------

## The leader's own children: those whose father is the man in the high
## seat (a child with no father named is counted his, as before).
static func own_children(band: Band) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var who := band.leader.display_name if band.leader != null else ""
	for child in band.sons:
		if child.get("alive", true) and not child.get("seat", false) and str(child.get("father", who)) == who:
			out.append(child)
	return out


## The children of the house who are not the leader's own: his brothers and
## sisters, or an old leader's children raised in the hall.
static func kin_children(band: Band) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var who := band.leader.display_name if band.leader != null else ""
	for child in band.sons:
		if child.get("alive", true) and not child.get("seat", false) and str(child.get("father", who)) != who:
			out.append(child)
	return out


static func child_named(band: Band, child_name: String) -> Dictionary:
	for child in band.sons:
		if str(child.get("name", "")) == child_name and child.get("alive", true) and not child.get("seat", false):
			return child
	return {}


## Whether a son is at home (not away being fostered), at `year`.
static func at_home(rules: CampaignRules, child: Dictionary, year: int) -> bool:
	if str(child.get("fostered_with", "")) == "":
		return true
	return year - int(child.get("born", year)) >= rules.foster_returns_at_age


## The winter's household matters, as cards for the hall's talk
## (WinterHall): a son of fostering age (foster him with a friendly house,
## or keep him at home), a son come of age (into the band, into the band as
## heir, or to the farm), a daughter of an age to marry (to a house, or
## not yet). Each card is {kind: "household", what, child, text, options,
## default}. Needs the houses (c.world.families) for fostering and marriage.
static func hall_cards(c: Campaign) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var band := c.band
	var rules := c.rules
	var year := c.cal.year
	if band.leader == null or not band.leader.alive:
		return out
	var who := band.leader.display_name
	var houses := _friendly_houses(c, 2)
	for child in band.sons:
		if not child.get("alive", true) or child.get("seat", false):
			continue
		var name := str(child.get("name", ""))
		var age := year - int(child.get("born", year))
		var mine := str(child.get("father", who)) == who
		if is_son(child):
			if mine and age >= rules.foster_min_age and age <= rules.foster_max_age and str(child.get("fostered_with", "")) == "" \
					and not child.get("kept", false) and not houses.is_empty():
				var opts: Array[Dictionary] = []
				for h in houses:
					opts.append({"id": "foster:" + h, "label": "Foster him with %s" % h,
							"hint": "He goes to them now and comes home at %d with something of their craft; their house and yours are tied." % rules.foster_returns_at_age})
				opts.append({"id": "keep", "label": "Keep him at home", "hint": "He grows up in your own hall."})
				out.append({"kind": "household", "what": "foster", "child": name, "options": opts, "default": "keep",
						"text": "%s is %d winters old. A boy fostered in another man's hall comes home with friends and a craft; a boy kept at home is his father's." % [name, age]})
			elif age >= rules.son_join_age and int(child.get("man_id", -1)) < 0 and str(child.get("decided", "")) == "" \
					and at_home(rules, child, year):
				var away := str(child.get("fostered_with", ""))
				var text := "%s has come of age, %d winters old%s." % [name, age,
						(", home from %s with something of their craft" % away) if away != "" else ""]
				var heir_line := "He is the eldest son: if you fall he takes the high seat." if mine else "He is of your father's blood."
				out.append({"kind": "household", "what": "of_age", "child": name, "default": "band", "text": text + " " + heir_line,
						"options": [
							{"id": "band", "label": "Take him into the band", "hint": "A young man, green yet; what he may become is in his blood and his fostering."},
							{"id": "heir", "label": "Into the band, as your heir", "hint": "Named before the men: if you fall, the high seat is his."},
							{"id": "farm", "label": "Leave him to the farm", "hint": "He keeps the farm and the line safe at home, away from the spears."}]})
		elif mine and age >= rules.daughter_marry_age and str(child.get("married_to", "")) == "" and not houses.is_empty() \
				and int(child.get("asked", -1)) != year:
			var opts2: Array[Dictionary] = []
			for h in houses:
				opts2.append({"id": "marry:" + h, "label": "Marry her into %s" % h,
						"hint": "Their house and yours are one by marriage, and so are some of their quarrels."})
			opts2.append({"id": "wait", "label": "Not yet", "hint": "She stays in her father's hall another year."})
			out.append({"kind": "household", "what": "daughter", "child": name, "options": opts2, "default": "wait",
					"text": "%s is %d winters old, and men have asked after her." % [name, age]})
	return out


## Up to `n` houses the band stands well with, warmest first: those that
## may foster a son or take a daughter.
static func _friendly_houses(c: Campaign, n: int) -> Array[String]:
	var out: Array[String] = []
	if c.world == null or c.world.families == null or c.world_rules == null:
		return out
	var fs := c.world.families
	var names := fs.names()
	names.sort_custom(func(a: String, b: String) -> bool:
		var sa := Families.standing(c.band, a)
		var sb := Families.standing(c.band, b)
		return sa > sb or (sa == sb and a < b))
	for name in names:
		if out.size() >= n:
			break
		if Families.standing(c.band, name) < c.world_rules.standing_well_wisher or not Feud.find(c.band, name).is_empty():
			continue
		out.append(name)
	return out


## Does a household card's choice. Returns the lines told.
static func answer_card(c: Campaign, card: Dictionary, choice: String, log: PackedStringArray) -> PackedStringArray:
	var lines := PackedStringArray()
	var band := c.band
	var rules := c.rules
	var child := child_named(band, str(card.get("child", "")))
	if child.is_empty() or band.leader == null:
		return lines
	var who := band.leader.display_name
	var name := str(child.name)
	var fs: Families = c.world.families if c.world != null else null
	match str(card.get("what", "")):
		"foster":
			if choice.begins_with("foster:") and fs != null:
				var house := choice.trim_prefix("foster:")
				foster_out(rules, band, child, house, log)
				fs.foster_son_with(c.world_rules, band, house)
				var craft: int = rules.foster_crafts.get(fs.house(house).temper if fs.house(house) != null else "", CombatTypes.Stat.SKILL)
				child["craft"] = craft
				lines.append("%s sent %s to be fostered with %s; their house and his are tied." % [who, name, house])
			else:
				child["kept"] = true
				lines.append("%s kept %s at home, to grow up in his own hall." % [who, name])
		"of_age":
			match choice:
				"band", "heir":
					var m := son_man(c, child)
					band.add_man(m)
					c._arm_new_men()
					lines.append("%s took his son %s into the band, %d winters old." % [who, name, m.age])
					band.log("%s took his son %s into the band" % [who, name])
					if choice == "heir":
						band.set_meta(HEIR_META, name)
						lines.append("Before the men %s named %s his heir." % [who, name])
						band.log("%s named his son %s his heir" % [who, name])
				_:
					child["decided"] = "farm"
					lines.append("%s left %s to the farm, to keep the land and the line at home." % [who, name])
		"daughter":
			child["asked"] = c.cal.year
			if choice.begins_with("marry:") and fs != null:
				var house2 := choice.trim_prefix("marry:")
				child["married_to"] = house2
				fs.marry_daughter(c.world_rules, band, house2, name, log)
				lines.append("%s gave his daughter %s in marriage into %s." % [who, name, house2])
				band.log("%s gave his daughter %s in marriage into %s" % [who, name, house2])
			else:
				lines.append("%s kept %s at home another year." % [who, name])
	return lines


## A son as a man of the band: weak at first, with a potential from both
## parents (Recruits.son_of) and, if he was fostered, a point of his
## foster-father's craft. Marks the child with the man's id.
static func son_man(c: Campaign, child: Dictionary) -> Man:
	var rules := c.rules
	var band := c.band
	var father := band.leader
	var pot: Array[int] = []
	pot.assign(child.get("potential", wife_potential(band)))
	var m := Recruits.son_of(c.rng.fork("son:%s:%d" % [str(child.name), int(child.get("born", 0))]), rules, father, pot, str(child.name), band.next_id())
	m.born = int(child.get("born", c.cal.year - rules.son_join_age))
	m.age = c.cal.year - m.born
	m.loyalty = rules.son_join_loyalty
	m.origin = father.origin
	var away := str(child.get("fostered_with", ""))
	if away != "":
		var s := int(child.get("craft", CombatTypes.Stat.SKILL))
		m.potential[s] = mini(10, m.potential[s] + rules.foster_craft_bonus)
		m.stats[s] = mini(m.potential[s], m.stats[s] + rules.foster_craft_bonus)
		m.traits.append("fostered with %s" % away)
	child["man_id"] = m.id
	child["decided"] = "band"
	if band.leader != null:
		band.set_bond(band.leader, m, rules.son_join_bond)
	return m


## A line of counsel from the wife (or the old man of the hall) when a
## matter in the hall's talk touches the household or her kin; "" for none.
## `short` is how many rations the store is short by at the thaw (0: none).
static func counsel(c: Campaign, cards: Array, short: int) -> PackedStringArray:
	var out := PackedStringArray()
	var band := c.band
	var wife := short_name(band.wife)
	var house := str(band.get_meta(WIFE_HOUSE_META, "")) if band.has_meta(WIFE_HOUSE_META) else ""
	if wife != "":
		var said := ""
		for card in cards:
			if str(card.get("kind", "")) != "household":
				continue
			match str(card.get("what", "")):
				"foster":
					said = "A boy who grows up among other men's sons has friends when he needs them. Send %s out." % str(card.child)
				"of_age":
					said = "%s is my son as much as yours. Do not put him in the front of the wall his first summer." % str(card.child)
				"daughter":
					said = "Marry %s where it will hold. A house that is bound to us does not burn our hall." % str(card.child)
			if said != "":
				break
		if said == "" and house != "" and c.world != null and c.world.families != null and c.world.families.house(house) != null:
			if not Feud.find(band, house).is_empty():
				said = "There is blood between my father's house and yours. End it, before my sons have to."
			elif c.world_rules != null and Families.standing(band, house) < c.world_rules.standing_well_wisher:
				said = "My kin of %s think little of you this year. Send them a gift before the spring." % house
		if said == "" and short > 0:
			said = "The store will not last the winter: we are %d rations short. Send men to hunt, or buy now while there is grain to buy." % short
		if said != "":
			out.append("%s says: %s" % [wife, said])
	var old: Dictionary = band.get_meta(OLD_MAN_META, {}) if band.has_meta(OLD_MAN_META) else {}
	if not old.is_empty() and not old.get("dead", false):
		var line := "Hold to the men who held to me, and give rings with an open hand."
		if not band.unsettled_feuds().is_empty():
			var f: Dictionary = band.unsettled_feuds()[0]
			line = "The matter with %s is not ended. Do not let it lie until it comes to your door." % str(f.get("family", f.get("against", "")))
		out.append("Old %s says by the fire: %s" % [str(old.name), line])
	return out


## The first name of "Asgerd, daughter of Ketil": "Asgerd".
static func short_name(full: String) -> String:
	var at := full.find(",")
	return full if at < 0 else full.left(at)


## The household as plain values for the view (Journey.household): the
## wife, the mother, the old man of the hall, every living child of the
## house with what is to become of him, and the heir named.
static func household(c: Campaign) -> Dictionary:
	var band := c.band
	var rules := c.rules
	var year := c.cal.year
	var out := {"wife": {}, "mother": "", "old_man": {}, "children": [], "heir": str(band.get_meta(HEIR_META, "")) if band.has_meta(HEIR_META) else ""}
	if band.wife != "":
		out.wife = {"name": band.wife, "short": short_name(band.wife),
				"house": str(band.get_meta(WIFE_HOUSE_META, "")) if band.has_meta(WIFE_HOUSE_META) else "",
				"skill": band.household_skill}
	if band.has_meta(MOTHER_META):
		out.mother = str(band.get_meta(MOTHER_META))
	if band.has_meta(OLD_MAN_META):
		var old: Dictionary = band.get_meta(OLD_MAN_META)
		if not old.get("dead", false):
			out.old_man = {"name": str(old.name), "age": year - int(old.get("born", year))}
	var who := band.leader.display_name if band.leader != null else ""
	for child in band.sons:
		if not child.get("alive", true) or child.get("seat", false):
			continue
		var age := year - int(child.get("born", year))
		var son := is_son(child)
		var mine := str(child.get("father", who)) == who
		var state := ""
		var tag := ""
		var away := str(child.get("fostered_with", ""))
		if not son:
			var wed := str(child.get("married_to", ""))
			state = ("married into %s" % wed) if wed != "" else ("of an age to marry" if age >= rules.daughter_marry_age else "at home")
			tag = "married" if wed != "" else ""
		elif int(child.get("man_id", -1)) >= 0:
			var m := band.man_by_id(int(child.man_id))
			state = "in the band" if m != null and m.alive and band.men.has(m) else "gone from the band"
			tag = "in the band"
		elif away != "" and age < rules.foster_returns_at_age:
			state = "fostered with %s until he is %d" % [away, rules.foster_returns_at_age]
			tag = "fostered"
		elif str(child.get("decided", "")) == "farm":
			state = "keeps the farm"
			tag = "at the farm"
		elif age >= rules.son_join_age:
			state = "of age"
			tag = "of age"
		else:
			state = "at home" + (", of an age to foster" if age >= rules.foster_min_age and away == "" and not child.get("kept", false) else "")
		if str(out.heir) == str(child.name):
			tag = "heir"
		out.children.append({"name": str(child.name), "age": age, "son": son, "own": mine, "state": state, "tag": tag,
				"fostered_with": away, "father": str(child.get("father", who))})
	return out


## The old folk's year at the thaw: the old man of the hall may die in his
## bed; the chronicle keeps the line.
static func old_folk_year(rng: SimRng, rules: CampaignRules, band: Band, cal: Calendar, log: PackedStringArray) -> void:
	if not band.has_meta(OLD_MAN_META):
		return
	var old: Dictionary = band.get_meta(OLD_MAN_META)
	if old.get("dead", false):
		return
	if rng.randf() < rules.old_man_death_chance:
		old["dead"] = true
		old["died"] = cal.year
		var age := cal.year - int(old.get("born", cal.year))
		var text := "Old %s died in his bed, %d winters old, and was laid in a mound above the fjord" % [str(old.name), age]
		log.append(text)
		band.log(text)
		Chronicle.old_man_died(band, str(old.name), cal.year, age)
