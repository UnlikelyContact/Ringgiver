class_name Estate
extends RefCounted
## Men and silver (docs/design/notes/men-silver.md): what a band of some
## standing spends its silver on, and the summer's arms. The state hangs
## off the band (`Band.estate`); the static functions are the rules, read
## and called through Journey (`smith_state`, `buy_arms`, `works`,
## `do_work`, `gift_options`, `give`).
##
## - The smith: at market towns and kings' halls (and the band's own
##   smithy), helmets, swords, mail, long axes and bows for a named man or
##   for the chest, a stock rolled once a place a year; better and dearer
##   at the three great markets, where now and then a sword with a name is
##   to be had.
## - Gifts in summer: silver or arms from the chest, once a summer a man.
## - The works: the hall's buildings and its adornment, feasts for a house
##   and for the district, rune-stones and mounds for the dead, a skald
##   kept at the hall, the ship fitted.

# --- State ---------------------------------------------------------------------------

## Steps of the hall's adornment built (CampaignRules.hall_adorn).
var adorn := 0
## The skald kept at the hall ("" for none) and the year he came.
var skald := ""
var skald_since := 0
## The ship the fittings are on, and which ("sail", "shields", "prow").
## A new hull starts bare.
var fit_ship: Ship = null
var fittings := {}
## The dead honoured: "name:year" -> "stone" or "mound".
var memorials := {}
## House name -> the year the band last feasted it; the year of the
## district's feast.
var feasts := {}
var district_feast := -1
## Place id -> {year, stock: {item: n}, named: "" or a sword's name}.
var smiths := {}
## Swords with names already sold, never offered again.
var named_sold := PackedStringArray()
## Arms bought for the chest, not yet given: item -> count.
var chest := {}
## Man id -> the year he was last given a gift in summer.
var given := {}
## Ounces spent on all of it (tools), and by kind.
var sunk := 0
var spent := {}
## Shieldmaidens come to the band; woman's id -> the year a house asked for her.
var maidens := 0
var suits := {}


static func of(band: Band) -> Estate:
	if band.estate == null:
		band.estate = Estate.new()
	return band.estate


## The loyalty every fed, seated man gains a winter turn for the hall's
## adornment (Loyalty.winter_drift).
static func adorn_rest(rules: CampaignRules, band: Band) -> int:
	return (band.estate.adorn if band.estate != null else 0) * rules.adorn_rest


static func _pay(j: Journey, oz: int, kind: String) -> void:
	var e := of(j.c.band)
	j.c.band.silver -= oz
	e.sunk += oz
	e.spent[kind] = int(e.spent.get(kind, 0)) + oz


# --- The smith ------------------------------------------------------------------------

## What kind of smith works here: "great" (Kaupang, Hedeby, Dublin),
## "plain" (a market town or a king's hall), "own" (the band's smithy at
## its own hall), or "" for none (or a door shut to the band).
static func smith_kind(j: Journey, p: Place) -> String:
	if p == null:
		return ""
	var c := j.c
	if p.id == c.band.hall_at and c.band.hall != null and (c.band.hall as Hall).has(CampaignTypes.Building.SMITHY):
		return "own"
	if Outlawry.door_shut(j, p, "market") != "":
		return ""
	if c.rules.smith_great.has(p.id) and p.has_market:
		return "great"
	if (p.kind == WorldTypes.PlaceKind.TOWN and p.has_market) or Outlawry._king_of(j, p) != null:
		return "plain"
	return ""


## The smith's stock here this year, rolled once: {year, stock, named}.
static func _smith(j: Journey, p: Place, kind: String) -> Dictionary:
	var e := of(j.c.band)
	var year := j.c.cal.year
	var s: Dictionary = e.smiths.get(p.id, {})
	if int(s.get("year", -1)) == year:
		return s
	var rules := j.c.rules
	var r := j.c.rng.fork("smith:%s:%d" % [p.id, year])
	var table: Dictionary = rules.smith_stock_great if kind == "great" else (rules.smith_own_stock if kind == "own" else rules.smith_stock_plain)
	var stock := {}
	for item in rules.smith_items:
		var span: Array = table.get(item, [0, 0])
		stock[item] = r.randi_range(int(span[0]), int(span[1]))
	var named := ""
	if kind == "great" and r.randf() < rules.smith_named_chance:
		var free: Array = []
		for n in rules.sword_names:
			if not e.named_sold.has(n):
				free.append(n)
		if not free.is_empty():
			named = str(free[r.randi_range(0, free.size() - 1)])
	s = {"year": year, "stock": stock, "named": named}
	e.smiths[p.id] = s
	return s


static func arms_price(rules: CampaignRules, kind: String, item: String) -> int:
	var base := int(rules.smith_price.get(item, 0))
	if kind == "great":
		return roundi(base * rules.smith_great_price)
	if kind == "own":
		return roundi(base * rules.smith_own_price)
	return base


## Whether `m` would be the better for `item`: what he lacks. A sword or
## a long axe is for a man of the front rank (the second rank fights with
## the spear, the bowmen with the bow: Man.to_warrior); a bow is for a man
## not yet among the bowmen, and takes him there.
static func lacks(m: Man, item: String) -> bool:
	var front := m.role == CombatTypes.Role.SHIELD
	match item:
		"helmet":
			return not m.helmet
		"sword", "named":
			return front and (m.weapon != CombatTypes.Weapon.SWORD or (item == "named" and m.sword_name == ""))
		"mail":
			return m.armor != CombatTypes.Armor.MAIL
		"long axe":
			return front and m.weapon != CombatTypes.Weapon.LONG_AXE
		"bow":
			return m.role != CombatTypes.Role.MISSILE and not m.is_leader
	return false


## The dead not yet honoured offered at once, the latest first.
const MEMORIALS_SHOWN := 4
## CombatTypes.Weapon in words.
const WEAPON_WORDS := ["a spear", "a bearded axe", "a sword", "a long axe", "a bow"]


## His gear, in words: "a sword, a shield, a mail shirt and a helmet".
static func gear_words(m: Man) -> String:
	var bits := PackedStringArray()
	var weapon: String = WEAPON_WORDS[m.weapon] if m.weapon < WEAPON_WORDS.size() else "a spear"
	if m.sword_name != "" and m.weapon == CombatTypes.Weapon.SWORD:
		weapon = "the sword %s" % m.sword_name
	bits.append(weapon)
	if m.has_shield and m.weapon != CombatTypes.Weapon.LONG_AXE and m.weapon != CombatTypes.Weapon.BOW and not m.has_maim(CampaignTypes.Maim.LOST_HAND):
		bits.append("a shield")
	match m.armor:
		CombatTypes.Armor.MAIL:
			bits.append("a mail shirt")
		CombatTypes.Armor.LEATHER:
			bits.append("a leather coat")
	if m.helmet:
		bits.append("a helmet")
	if bits.size() == 1:
		return bits[0]
	return "%s and %s" % [", ".join(bits.slice(0, bits.size() - 1)), bits[bits.size() - 1]]


## The smith here for the screen: {} with none, else {kind, name, words,
## rows: [{item, label, price, left}], named: {name, price} or {},
## people: [{id, name, lacks: [items]}], chest: {item: n}, silver}.
static func smith_state(j: Journey) -> Dictionary:
	var p := j.here()
	var kind := smith_kind(j, p)
	if kind == "" or not j.can_act():
		return {}
	var c := j.c
	var s := _smith(j, p, kind)
	var rows: Array[Dictionary] = []
	for item in c.rules.smith_items:
		var left := int((s.stock as Dictionary).get(item, 0))
		if kind == "own" and left <= 0:
			continue
		rows.append({"item": item, "label": _item_label(item), "price": arms_price(c.rules, kind, item), "left": left})
	var people: Array[Dictionary] = []
	var everyone: Array[Man] = [c.band.leader]
	everyone.append_array(c.band.living_men())
	for m in everyone:
		var l := PackedStringArray()
		for item in c.rules.smith_items + ["named"]:
			if lacks(m, item):
				l.append(item)
		people.append({"id": m.id, "name": m.display_name, "lacks": l, "gear": gear_words(m), "leader": m == c.band.leader})
	var words := {
		"great": "The smiths of %s work for kings: the dearest arms in the north, and the best. Fine work binds a man the more when it is given." % p.display_name,
		"plain": "A smith at %s has a little made for sale, and what he has is honest work." % p.display_name,
		"own": "Your own smith at the hall: a little made over the winter, cheaper than the market's.",
	}
	var named := {}
	if str(s.named) != "":
		named = {"name": str(s.named), "price": c.rules.smith_named_price}
	return {"kind": kind, "name": p.display_name, "words": words[kind], "rows": rows, "named": named,
			"people": people, "chest": of(c.band).chest.duplicate(), "silver": c.band.silver}


static func _item_label(item: String) -> String:
	match item:
		"mail":
			return "A mail shirt"
		"long axe":
			return "A long axe"
		"helmet":
			return "A helmet"
		"sword":
			return "A sword"
		"bow":
			return "A bow and arrows"
	return item.capitalize()


## Buys `item` here for the man `man_id` (the leader too), or for the chest
## (-1). `item` "named" is the sword with a name, for a man only. Returns
## whether it was done.
static func buy_arms(j: Journey, item: String, man_id: int) -> bool:
	var p := j.here()
	var kind := smith_kind(j, p)
	if kind == "" or not j.can_act():
		return false
	var c := j.c
	var band := c.band
	var s := _smith(j, p, kind)
	var m: Man = band.man_by_id(man_id) if man_id >= 0 else null
	if man_id >= 0 and (m == null or not m.alive):
		return false
	if item == "named":
		var sword := str(s.named)
		if sword == "" or m == null or band.silver < c.rules.smith_named_price or not lacks(m, "named"):
			return false
		_pay(j, c.rules.smith_named_price, "smith")
		s.named = ""
		of(band).named_sold.append(sword)
		m.weapon = CombatTypes.Weapon.SWORD
		m.sword_name = sword
		if m != band.leader:
			Loyalty.adjust(m, roundi(c.rules.smith_named_loyalty * float(band.gift("gift_bind", 1.0))))
		band.fame = clampi(band.fame + c.rules.smith_named_fame, 0, 100)
		var to := "for himself" if m == band.leader else "and gives it to %s" % m.display_name
		j._say("%s buys the sword called %s at %s %s. Men will remember that sword." % [band.leader.display_name, sword, p.display_name, to])
		band.log("%s bought the sword %s at %s, %s" % [band.leader.display_name, sword, p.display_name,
				"and bore it himself" if m == band.leader else "and gave it to %s" % m.display_name])
		return true
	if not c.rules.smith_items.has(item):
		return false
	var left := int((s.stock as Dictionary).get(item, 0))
	var price := arms_price(c.rules, kind, item)
	if left <= 0 or band.silver < price:
		return false
	if m != null and not lacks(m, item):
		return false
	_pay(j, price, "smith")
	s.stock[item] = left - 1
	if m == null:
		of(band).chest[item] = int(of(band).chest.get(item, 0)) + 1
		j._say("%s buys %s at %s for the chest: %d oz." % [band.leader.display_name, _item_label(item).to_lower(), p.display_name, price])
		return true
	_arm(j, m, item, kind == "great")
	j._say("%s buys %s at %s for %s: %d oz." % [band.leader.display_name, _item_label(item).to_lower(), p.display_name,
			"himself" if m == band.leader else m.display_name, price])
	return true


## Puts `item` on `m`: a gift to a sworn man (Loyalty.gift_gear, and a
## great smith's fine work binds him the more); on the leader, his own.
static func _arm(j: Journey, m: Man, item: String, fine: bool) -> void:
	var c := j.c
	var said := PackedStringArray()
	if item == "bow":
		m.role = CombatTypes.Role.MISSILE  # he takes his place among the bowmen
		m.armed = true
	if m == c.band.leader:
		var before := m.loyalty
		Loyalty.gift_gear(c.rules, c.band, m, item, said)
		m.loyalty = before
		return
	Loyalty.gift_gear(c.rules, c.band, m, item, said)
	if fine:
		Loyalty.adjust(m, c.rules.smith_fine_loyalty)


# --- Gifts in summer --------------------------------------------------------------

## What may be given `m` now: [{id, label, hint, enabled}]. Silver as at
## Yule, and what the chest holds that he lacks; once a summer a man.
static func gift_options(j: Journey, m: Man) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := j.c
	var band := c.band
	if m == null or m == band.leader or not m.alive or j.in_winter():
		return out
	var done := int(of(band).given.get(m.id, -1)) == c.cal.year
	var why := "%s has had a gift from you this summer." % m.he(true) if done else ""
	var oz: Array = c.rules.hall_gift_ounces
	out.append({"id": "silver", "label": "%d oz of silver" % int(oz[0]), "enabled": not done and band.silver >= int(oz[0]),
			"hint": why if done else "A small gift: it warms %s." % m.him()})
	out.append({"id": "ring", "label": "An arm-ring, %d oz" % int(oz[1]), "enabled": not done and band.silver >= int(oz[1]),
			"hint": why if done else "A ring is talked of: it binds %s more." % m.him()})
	var chest: Dictionary = of(band).chest
	var items: Array = chest.keys()
	items.sort()
	for item in items:
		if int(chest[item]) > 0 and lacks(m, str(item)):
			out.append({"id": "chest:" + str(item), "label": "%s from the chest" % _item_label(str(item)),
					"enabled": not done, "hint": why if done else "Arms are a lord's gift: %s will not forget it." % m.he()})
	return out


static func give(j: Journey, man_id: int, what: String) -> bool:
	var c := j.c
	var band := c.band
	var m := band.man_by_id(man_id)
	var ok := false
	for o in gift_options(j, m):
		if str(o.id) == what and bool(o.enabled):
			ok = true
	if not ok:
		return false
	var said := PackedStringArray()
	var oz: Array = c.rules.hall_gift_ounces
	if what == "silver" or what == "ring":
		var n := int(oz[0]) if what == "silver" else int(oz[1])
		band.silver -= n
		Loyalty.gift(c.rules, band, m, n, said)
		j._say("%s gives %s %s." % [band.leader.display_name, m.display_name, ("%d oz of silver" % n) if what == "silver" else "an arm-ring"])
	else:
		var item := what.trim_prefix("chest:")
		of(band).chest[item] = int(of(band).chest.get(item, 0)) - 1
		if int(of(band).chest[item]) <= 0:
			of(band).chest.erase(item)
		_arm(j, m, item, false)
		j._say("%s gives %s %s from the chest." % [band.leader.display_name, m.display_name, _item_label(item).to_lower()])
	of(band).given[m.id] = c.cal.year
	return true


# --- The works -------------------------------------------------------------------------

static func _fallen(band: Band) -> Array:
	return band.get_meta(Chronicle.FALLEN_META, []) if band.has_meta(Chronicle.FALLEN_META) else []


static func _cost_feast_house(j: Journey) -> int:
	return j.c.rules.feast_house_base + j.c.rules.feast_house_per_man * j.c.band.fighters().size()


static func _cost_feast_district(j: Journey) -> int:
	return j.c.rules.feast_district_base + j.c.rules.feast_district_per_man * j.c.band.fighters().size()


## The houses of the band's district: those whose seat is within
## `feast_district_leagues` of its own hall, the band's enemies left out.
static func district(j: Journey) -> Array[String]:
	var out: Array[String] = []
	var c := j.c
	var fs := c.world.families
	var hall: Place = c.world.place(c.band.hall_at) if c.band.hall_at != "" else null
	if fs == null or hall == null:
		return out
	var names: Array = fs.houses.keys()
	names.sort()
	for n in names:
		var h: House = fs.houses[n]
		var seat: Place = c.world.place(h.seat)
		if seat == null or seat.pos.distance_to(hall.pos) > c.rules.feast_district_leagues:
			continue
		if str(n) == c.band.vengeance or Families.is_foe(c.world_rules, c.band, str(n)):
			continue
		out.append(str(n))
	return out


## What may be built, given or raised here: [{id, label, hint, cost,
## enabled, group}]. Groups: "hall" (the band's own hall), "feast",
## "dead", "ship". Empty when the band cannot act.
static func works(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	if p == null or not j.can_act():
		return out
	var c := j.c
	var band := c.band
	var rules := c.rules
	var e := of(band)
	var home := band.hall_at != "" and p.id == band.hall_at
	if home:
		var hall := Hall.ensure(band, rules)
		var B := CampaignTypes.Building
		var what := {
			B.BENCHES: "Six more men can sit at your benches (%d now): the band may grow to it." % hall.seats,
			B.STOREHOUSE: "The stores keep %d rations more over the winter." % rules.storehouse_capacity,
			B.SMITHY: "Your own smith: arms made at the hall, cheaper than the market's, and the ship mended twice as fast in winter.",
			B.BOATHOUSE: "The ship winters under a roof and comes out sound; men may fish in the winter.",
			B.BYRE: "Cattle in the byre: %d rations a winter turn." % rules.byre_rations,
		}
		for b in [B.BENCHES, B.STOREHOUSE, B.SMITHY, B.BOATHOUSE, B.BYRE]:
			var cost := int(rules.building_costs.get(b, 0))
			if b != B.BENCHES and hall.has(b):
				continue
			out.append({"id": "build:%d" % b, "label": "Build %s (%d oz)" % [CampaignTypes.BUILDING_NAMES[b], cost], "cost": cost,
					"hint": what[b], "enabled": band.silver >= cost, "group": "hall"})
		if e.adorn < rules.hall_adorn.size():
			var step: Dictionary = rules.hall_adorn[e.adorn]
			out.append({"id": "adorn", "label": "Have %s made (%d oz)" % [step.name, int(step.cost)], "cost": int(step.cost),
					"hint": "Honor +%d and fame +%d; every man seated at your benches warms to you the more each winter turn." % [int(step.honor), int(step.fame)],
					"enabled": band.silver >= int(step.cost), "group": "hall"})
		if e.skald == "":
			out.append({"id": "skald", "label": "Keep a skald at the hall (%d oz)" % rules.kept_skald_take, "cost": rules.kept_skald_take,
					"hint": "Fame +%d every winter and a verse in your saga; %d oz a winter to keep him." % [rules.kept_skald_fame, rules.kept_skald_keep],
					"enabled": band.silver >= rules.kept_skald_take, "group": "hall"})
		var d := district(j)
		var dc := _cost_feast_district(j)
		out.append({"id": "feast_district", "label": "Feast the district (%d oz)" % dc, "cost": dc,
				"hint": ("Standing +%d with %d houses near your hall (%s), and fame +%d. Once a year." % [rules.feast_district_standing, d.size(),
						", ".join(d.slice(0, 3)) + (" and more" if d.size() > 3 else ""), rules.feast_district_fame]) if e.district_feast != c.cal.year
						else "You have feasted the district this year.",
				"enabled": e.district_feast != c.cal.year and band.silver >= dc and not d.is_empty(), "group": "feast"})
		var fallen := _fallen(band)
		var shown := 0
		for i in range(fallen.size() - 1, -1, -1):  # the latest dead first, a few at a time
			if shown >= MEMORIALS_SHOWN:
				break
			var f: Dictionary = fallen[i]
			var key := "%s:%d" % [str(f.name), int(f.year)]
			if e.memorials.has(key):
				continue
			shown += 1
			var who := str(f.name)
			var them := "her" if bool(f.get("woman", false)) else "him"
			out.append({"id": "stone:%d" % i, "label": "Raise a stone for %s (%d oz)" % [who, rules.stone_cost], "cost": rules.stone_cost,
					"hint": "Runes cut for %s, who fell in %d: fame +%d, honor +%d, and the saga tells it." % [who, int(f.year), rules.stone_fame, rules.stone_honor],
					"enabled": band.silver >= rules.stone_cost, "group": "dead"})
			out.append({"id": "mound:%d" % i, "label": "Raise a mound over %s (%d oz)" % [who, rules.mound_cost], "cost": rules.mound_cost,
					"hint": "A howe by the shore that men will point to: fame +%d, honor +%d. It honours %s more than a stone." % [rules.mound_fame, rules.mound_honor, them],
					"enabled": band.silver >= rules.mound_cost, "group": "dead"})
	elif p.family != "" and c.world.families != null and c.world.families.houses.has(p.family) and p.family != band.vengeance \
			and not Families.is_foe(c.world_rules, band, p.family) and Outlawry.door_shut(j, p, "work") == "":
		var fc := _cost_feast_house(j)
		var fed := int(e.feasts.get(p.family, -1)) == c.cal.year
		out.append({"id": "feast_house", "label": "Give a feast for %s (%d oz)" % [p.family, fc], "cost": fc,
				"hint": ("Two days of ale and meat at their seat: standing +%d with them, and fame +%d." % [rules.feast_house_standing, rules.feast_fame]) if not fed
						else "You have feasted them this year.",
				"enabled": not fed and band.silver >= fc, "group": "feast"})
	# The ship, where there are shipwrights: the band's own hall, a market, a king's hall.
	if band.ship != null and j.roam.aboard and (home or p.has_market or Outlawry._king_of(j, p) != null):
		if e.fit_ship != band.ship:
			e.fit_ship = band.ship
			e.fittings = {}
		var ship_name: String = WorldTypes.SHIP_NAMES[band.ship.kind]
		if not e.fittings.has("sail"):
			out.append({"id": "fit:sail", "label": "A striped sail for the %s (%d oz)" % [ship_name, rules.fit_sail], "cost": rules.fit_sail,
					"hint": "She sails a tenth faster. Fittings stay with her: a new hull starts bare.", "enabled": band.silver >= rules.fit_sail, "group": "ship"})
		if not e.fittings.has("shields"):
			out.append({"id": "fit:shields", "label": "Painted shields on her rail (%d oz)" % rules.fit_shields, "cost": rules.fit_shields,
					"hint": "Fame +%d: she is known when she comes in." % rules.fit_shields_fame, "enabled": band.silver >= rules.fit_shields, "group": "ship"})
		var big := band.ship.kind == WorldTypes.ShipKind.SNEKKJA or band.ship.kind == WorldTypes.ShipKind.LONGSHIP
		if big and not e.fittings.has("prow"):
			out.append({"id": "fit:prow", "label": "A dragon's head for her prow (%d oz)" % rules.fit_prow, "cost": rules.fit_prow,
					"hint": "Fame +%d: a warship that is talked of." % rules.fit_prow_fame, "enabled": band.silver >= rules.fit_prow, "group": "ship"})
	return out


## Does one of `works` by id. Returns whether it was done.
static func do_work(j: Journey, id: String) -> bool:
	var found := {}
	for w in works(j):
		if str(w.id) == id:
			found = w
	if found.is_empty() or not bool(found.enabled):
		return false
	var c := j.c
	var band := c.band
	var rules := c.rules
	var e := of(band)
	var who := band.leader.display_name
	var p := j.here()
	var cost := int(found.cost)
	if id.begins_with("build:"):
		var hall := Hall.ensure(band, rules)
		var said := PackedStringArray()
		if not hall.build(rules, int(id.trim_prefix("build:")) as CampaignTypes.Building, band, said):
			return false
		e.sunk += cost
		e.spent["hall"] = int(e.spent.get("hall", 0)) + cost
		j._say("%s has %s built at %s: %d oz." % [who, CampaignTypes.BUILDING_NAMES[int(id.trim_prefix("build:"))], p.display_name, cost])
		return true
	match id:
		"adorn":
			var step: Dictionary = rules.hall_adorn[e.adorn]
			_pay(j, cost, "hall")
			e.adorn += 1
			band.honor = clampi(band.honor + int(step.honor), 0, 100)
			band.fame = clampi(band.fame + int(step.fame), 0, 100)
			j._say("%s has %s made at %s, and men come to see it." % [who, step.name, p.display_name])
			band.log("%s had %s made in his hall" % [who, step.name])
		"skald":
			_pay(j, cost, "skald")
			var r := c.rng.fork("skald:%d" % c.cal.year)
			e.skald = str(rules.kept_skald_names[r.randi_range(0, rules.kept_skald_names.size() - 1)])
			e.skald_since = c.cal.year
			j._say("%s takes the skald %s into his hall: he will make the verses of the band's deeds." % [who, e.skald])
			band.log("%s kept the skald %s in his hall" % [who, e.skald])
		"feast_district":
			_pay(j, cost, "feast")
			e.district_feast = c.cal.year
			var d := district(j)
			for n in d:
				c.world.families.shift(c.world_rules, band, n, rules.feast_district_standing)
			band.fame = clampi(band.fame + rules.feast_district_fame, 0, 100)
			j._pass(2.0)
			j._say("%s feasts the district at %s for two days: %s come, and go home speaking well of him." % [who, p.display_name, _and(d)])
			band.log("%s feasted all the district at his hall" % who)
		"feast_house":
			_pay(j, cost, "feast")
			e.feasts[p.family] = c.cal.year
			c.world.families.shift(c.world_rules, band, p.family, rules.feast_house_standing)
			band.fame = clampi(band.fame + rules.feast_fame, 0, 100)
			j._pass(2.0)
			j._say("%s gives a feast for %s at %s: two days of ale and meat, and they think the better of him." % [who, p.family, p.display_name])
			band.log("%s gave a feast for %s" % [who, p.family])
		"fit:sail", "fit:shields", "fit:prow":
			var what := id.trim_prefix("fit:")
			_pay(j, cost, "ship")
			e.fit_ship = band.ship
			e.fittings[what] = true
			var ship_name: String = WorldTypes.SHIP_NAMES[band.ship.kind]
			match what:
				"sail":
					j._say("A striped sail is sewn for the %s at %s." % [ship_name, p.display_name])
				"shields":
					band.fame = clampi(band.fame + rules.fit_shields_fame, 0, 100)
					j._say("Painted shields are hung along the %s's rail." % ship_name)
					band.log("%s hung painted shields on his ship's rail" % who)
				"prow":
					band.fame = clampi(band.fame + rules.fit_prow_fame, 0, 100)
					j._say("A dragon's head is carved for the %s's prow, and she is talked of." % ship_name)
					band.log("%s set a dragon's head on his ship" % who)
		_:
			if id.begins_with("stone:") or id.begins_with("mound:"):
				var mound := id.begins_with("mound:")
				var f: Dictionary = _fallen(band)[int(id.get_slice(":", 1))]
				var key := "%s:%d" % [str(f.name), int(f.year)]
				_pay(j, cost, "dead")
				e.memorials[key] = "mound" if mound else "stone"
				band.fame = clampi(band.fame + (rules.mound_fame if mound else rules.stone_fame), 0, 100)
				band.honor = clampi(band.honor + (rules.mound_honor if mound else rules.stone_honor), 0, 100)
				var them := "her" if bool(f.get("woman", false)) else "him"
				if mound:
					j._say("%s raises a mound over %s by the shore at %s." % [who, str(f.name), p.display_name])
					band.log("%s raised a mound over %s, and it stands there yet" % [who, str(f.name)])
				else:
					j._say("%s has a stone raised for %s, and the runes cut on it." % [who, str(f.name)])
					band.log("%s raised this stone after %s, who fell in %d. May the gods keep %s" % [who, str(f.name), int(f.year), them])
			else:
				return false
	return true


static func _and(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## Her speed under sail, times this (the striped sail).
static func sail_mult(j: Journey) -> float:
	var e: Estate = j.c.band.estate
	if e == null or e.fit_ship == null or e.fit_ship != j.c.band.ship or not e.fittings.has("sail"):
		return 1.0
	return j.c.rules.fit_sail_speed


## The winter (WinterHall.resolve): the skald is paid and makes his verse
## or goes; a ship wintered in the band's own boathouse comes out sound.
static func on_winter(j: Journey, h: WinterHall, lines: PackedStringArray) -> void:
	var c := j.c
	var band := c.band
	var e := of(band)
	var rules := c.rules
	if e.skald != "":
		if h.lodging == "home" and band.silver >= rules.kept_skald_keep:
			_pay(j, rules.kept_skald_keep, "skald")
			band.fame = clampi(band.fame + rules.kept_skald_fame, 0, 100)
			lines.append("The skald %s is given %d oz and makes a verse of the year's deeds." % [e.skald, rules.kept_skald_keep])
			band.log("%s made a verse in %s's hall of the deeds of that year" % [e.skald, band.leader.display_name])
		elif h.lodging == "home":
			lines.append("There is no silver to keep the skald %s, and he goes to another hall." % e.skald)
			band.log("The skald %s left %s's hall, for there was nothing to give him" % [e.skald, band.leader.display_name])
			e.skald = ""
	var hall := band.hall as Hall
	if h.lodging == "home" and hall != null and hall.has(CampaignTypes.Building.BOATHOUSE) and band.ship != null and band.ship.damage > 0:
		band.ship.damage = 0
		lines.append("The ship winters in the boathouse and comes out sound.")
