class_name WinterHall
extends RefCounted
## The winter the player plays (concept.md, "Winter hall phase"): seven
## steps in the hall, each a few small choices whose cost is shown before
## anything is spent. The store, the ring-giving, the yard, the men, the
## hall's talk; then the winter is lived through (Campaign.winter with a
## plan made from the choices, turn by turn as before) and the year is
## told; then the spring. Journey holds one while the band winters
## (`Journey.winter_begin` .. `winter_end`) and is the face the view and
## the stand-in players use; `state` is plain dictionaries for the screen.
##
## Nothing is spent while the player chooses: the choices are a draft, and
## `resolve` does them all in a fixed order when the winter is lived
## through, so Back is always safe until then. The defaults filled in at
## the start are what `Journey.winter_auto` keeps: a sensible winter.

const STEPS := ["store", "gifts", "yard", "men", "talk", "told", "spring"]
const STEP_TITLES := ["The store", "The ring-giving", "The yard", "The men", "The hall's talk", "The year told", "Spring"]
const TOLD := 5
const SPRING := 6
## The band's own shouts, one for each learned shape: the word and the
## order it gives after the shape is formed.
const SHOUTS := {"boar's snout": ["Swine", CombatTypes.Shout.PUSH], "refused flanks": ["Hedgehog", CombatTypes.Shout.HOLD]}
const ROLE_PLACES := ["Front rank", "Second rank", "Bows"]
## The deeds a vow at the Yule cup can name; any is kept by winning
## `vow_wins_needed` fights in the summer.
const VOWS := ["to win two fights before the next Yule", "to take silver from the sea-roads this summer"]

var year := 0
var place_id := ""
var place_name := ""
## home: where the band wintered before, its own benches; friend: free at a
## friend's seat; guest: paid for; lord: a lord's hall takes the band in as
## his men, lodging and board; camp: in the wilds, no roof.
var lodging := "home"
var host := ""
var fee := 0
var step := 0
var resolved := false

# The store.
var lots := 0
var hunters := 0
var feast := false
var eat_grain := false
var sent_home := {}  # man id -> true
var build := {}  # CampaignTypes.Building -> count
# The ring-giving: man id -> index into `ladder(m)`.
var gifts := {}
# The yard.
var shape := ""
var shout := ""
var roles := {}  # man id -> CombatTypes.Role
var banner := -1
# The men.
var candidates: Array[Dictionary] = []  # {man, ask, line, taken}
var let_go := {}  # man id -> true
var war_leader := -1
var keeps_back := false
var second := -1
var seat_ups: Array[int] = []  # man ids moved a bench up, in order
# The hall's talk: cards (WinterEvents.card, a house's ask, the Yule cup),
# each with its "choice".
var talk: Array[Dictionary] = []
# What the winter came to.
var told := PackedStringArray()
var verse := PackedStringArray()
var spring_to := ""
var given := {}  # man id -> what he was given, in words
# Spring (Years): the years to let pass after this winter (0: play the
# summer), or the candidate an old leader steps down for.
var years := 0
var step_down := ""
var _facts := {}


# --- The start -------------------------------------------------------------------

## Where the band winters and what comes to the hall, drawn once from the
## campaign's seed; the defaults set to a sensible winter.
static func open(j: Journey, p: Place) -> WinterHall:
	var h := WinterHall.new()
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	h.year = c.cal.year
	h._lodge(j, p)
	var r := c.rng.fork("hall:%d" % h.year)
	# Who comes to the hall: the men fame draws, as the thaw drew them.
	var room := c.rules.recruit_cap - band.living_men().size()
	for i in mini(Leader.recruits_drawn(c.rules, band), maxi(0, room)):
		var m := Recruits.random(r.fork("cand:%d" % i), c.rules, band.next_id())
		var ask := int(c.rules.recruit_ask.get(m.origin, 0))
		h.candidates.append({"man": m, "ask": ask, "line": _about(c.rules, m, ask), "taken": true})
	# The hall's talk: visitors and troubles, a house's ask, the Yule cup.
	var n := r.fork("talk_n").randi_range(c.rules.hall_talk_min, c.rules.hall_talk_max)
	var houses := _house_cards(j, r.fork("houses"))
	if not houses.is_empty():
		h.talk.append(houses[0])
		n -= 1
	var guarded := false
	for kind in WinterEvents.draw(r.fork("draw"), c.rules, band, maxi(0, n), band.ship != null, guarded):
		if kind == "marriage_offer" and c.world.families != null:
			continue  # the houses offer their daughters by name (`_house_cards`)
		var card := WinterEvents.card(r.fork("card:" + kind), c.rules, band, kind)
		if not card.is_empty():
			h.talk.append(card)
	h.talk.append_array(Family.hall_cards(c))
	h.talk.append(_vow_card(c))
	h._facts = h._year_facts(c)
	h._defaults(j)
	return h


func _lodge(j: Journey, p: Place) -> void:
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	if p == null:
		lodging = "camp"
		place_name = "a camp in the wilds"
		return
	place_id = p.id
	place_name = p.display_name
	host = p.family
	if band.hall_at == "" and band.origin != "":
		band.hall_at = str(Origins.def(band.origin).get("at", ""))
	if p.id == band.hall_at or (band.hall_at == "" and p.id == band.home):
		lodging = "home"
	elif p.id == band.home:
		lodging = "again"
	elif p.kind == WorldTypes.PlaceKind.HALL and p.faction_id != "" \
			and FactionAI.relation(c.world, p.faction_id, FactionAI.BAND) >= wr.lords_hall_relation:
		lodging = "lord"
		var f := FactionAI.ruler_of(c.world, p.id)
		host = f.leader if f != null else p.family
	elif Families.shelter(wr, band, p) == "free":
		lodging = "friend"
	else:
		lodging = "guest"
		fee = mini(band.silver, wr.guest_winter_per_man * band.fighters().size())


## The lodging in words, for the screen and the telling.
func lodging_text() -> String:
	match lodging:
		"home":
			return "At home at %s: your own benches, and what you build stays yours." % place_name
		"friend":
			return "The guests of %s at %s, your friends: they take nothing for the lodging." % [host, place_name]
		"lord":
			return "In %s's hall at %s, as his men: his benches and his board." % [host, place_name]
		"again":
			return "At %s again, where you wintered before: they take you in for nothing, and the benches are theirs." % place_name
		"camp":
			return "No roof: a camp in the wilds. Cold, no benches, nothing to buy; the hunting is better."
	return "Guests at %s, %d oz paid for the lodging. The benches are theirs." % [place_name, fee]


static func _about(rules: CampaignRules, m: Man, ask: int) -> String:
	var best := Potential.best_stat(m)
	var origin: String = CampaignTypes.ORIGIN_NAMES[m.origin]
	var line := "%s %s of %d, %s. He wants %s." % ["An" if "aeiou".contains(origin[0]) else "A", origin, m.age, Potential.hint(rules, m, best, 2),
			CampaignTypes.AMBITION_NAMES[m.ambition]]
	line += " He asks a ring of %d oz to swear." % ask if ask > 0 else " He asks a seat and his keep."
	return line


## A house's ask that belongs to the winter: a daughter to marry, a son to
## foster (Families.asks). A marriage is not offered in the winter of a
## year a house offered one in the spring.
static func _house_cards(j: Journey, r: SimRng) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := j.c
	var fs := c.world.families
	if fs == null:
		return out
	for d in fs.asks(r, c.world_rules, c.world, c.band, c.cal.year):
		var ask := str(d.get("ask", ""))
		if ask == "foster" or (ask == "marry" and int(c.band.get_meta("marriage_asked", -1)) != c.cal.year):
			var card := {"kind": "house", "ask": d, "text": str(d.text), "options": []}
			var opts: Array[Dictionary] = []
			for o in d.options:
				opts.append({"id": str(o.id), "label": str(o.label)})
			card.options = opts
			out.append(card)
	return out


static func _vow_card(c: Campaign) -> Dictionary:
	var r := c.rules
	var opts: Array[Dictionary] = [{"id": "none", "label": "Drink, and vow nothing"}]
	for i in VOWS.size():
		opts.append({"id": "vow:%d" % i, "label": "Vow %s" % VOWS[i],
				"hint": "Win %d fights and it is kept: luck, fame and honor. Break it and men remember." % r.vow_wins_needed})
	return {"kind": "vow", "text": "At Yule the cup goes round the benches, and a man may vow a deed for the summer to come.", "options": opts}


## What this year was, for the verse: fights won, men put down and by whom.
func _year_facts(c: Campaign) -> Dictionary:
	var best: Man = null
	var kills := 0
	for m in c.band.fighters():
		kills += m.this_year("kills")
		if best == null or m.this_year("kills") > best.this_year("kills"):
			best = m
	return {"wins": c._summer_wins, "kills": kills, "best": best.display_name if best != null and best.this_year("kills") > 0 else "",
			"best_kills": best.this_year("kills") if best != null else 0}


## The sensible winter, as the old plan made it: hunters when the store
## will not last, a feast when it will, rings for deeds and silver for the
## coldest, the band's shape in the yard, every man who comes taken on.
func _defaults(j: Journey) -> void:
	var c := j.c
	var band := c.band
	shape = band.drilling
	war_leader = band.war_leader_id
	keeps_back = band.leader_keeps_back
	second = band.sworn_second_id
	for m in band.living_men():
		gifts[m.id] = 0
	if lodging != "lord":
		# A feast if it can be had, hunters while the store will not last,
		# then rations bought while the chest allows (a turn's eating to
		# spare); without enough even so, no feast.
		feast = lodging != "camp"
		var spare := staying(j).size() + 1
		var free := _free_men(j).size()
		while food_end(j) < spare and hunters < mini(2, free):
			hunters += 1
		while can_buy() and food_end(j) < spare and lots < 12 and silver_after(j) >= lot_price(j) + 10 \
				and food_start(j) + rules_lot(j) <= _capacity(j):
			lots += 1
		if food_end(j) < 0:
			feast = false
	else:
		feast = false  # the lord holds Yule; the band is feasted at his board
	# Rings: an arm-ring for every great deed, a few ounces to the three
	# coldest, while a third of the chest allows.
	var budget := band.silver / 3
	var by_loyalty := band.living_men()
	by_loyalty.sort_custom(func(a: Man, b: Man) -> bool: return a.loyalty < b.loyalty or (a.loyalty == b.loyalty and a.id < b.id))
	for m in by_loyalty:
		if great_deed(c.rules, m) and budget >= c.rules.hall_gift_ounces[1]:
			gifts[m.id] = 2
			budget -= c.rules.hall_gift_ounces[1]
	var n := 0
	for m in by_loyalty:
		if n >= 3:
			break
		if int(gifts[m.id]) == 0 and budget >= c.rules.hall_gift_ounces[0]:
			gifts[m.id] = 1
			budget -= c.rules.hall_gift_ounces[0]
			n += 1
	# The talk: the first thing that can be paid for, a quarrel made up.
	for card in talk:
		card.choice = default_choice(j, card)
	spring_to = place_id


func default_choice(j: Journey, card: Dictionary) -> String:
	var opts: Array = card.options
	match str(card.kind):
		"vow":
			return "none"
		"house":
			return "accept"
		"quarrel":
			return "settle" if j.c.band.silver >= 2 * j.c.rules.settle_quarrel_ounces + 20 else "for_a"
		"thrall_unrest":
			return "let"
		"household":
			return str(card.get("default", opts[opts.size() - 1].id))
	for o in opts:
		if j.c.band.silver + int(o.get("silver", 0)) >= 0:
			return str(o.id)
	return str(opts[opts.size() - 1].id)


# --- The reckoning of the draft ----------------------------------------------------

## The men who stay in the hall this winter: the living, less any sent home
## or let go, with the new men taken on.
func staying(j: Journey) -> Array[Man]:
	var out: Array[Man] = []
	for m in j.c.band.living_men():
		if not sent_home.has(m.id) and not let_go.has(m.id):
			out.append(m)
	for cd in candidates:
		if cd.taken:
			out.append(cd.man)
	if _talk_choice("outlaw_shelter") == "take":
		out.append(null)  # a mouth not yet named
	return out


## Men free for the hunt or the yard: staying, sworn already, not hurt.
func _free_men(j: Journey) -> Array[Man]:
	var out: Array[Man] = []
	for m in staying(j):
		if m != null and m.healing_turns <= 0 and not candidates.any(func(cd: Dictionary) -> bool: return cd.man == m):
			out.append(m)
	return out


func _talk_choice(kind: String) -> String:
	for card in talk:
		if str(card.kind) == kind:
			return str(card.get("choice", ""))
	return ""


func lot_price(j: Journey) -> int:
	var p := j.c.world.place(place_id) if place_id != "" else null
	if p == null:
		return 0
	var each := j.c.world_rules.farm_food_price
	if p.has_market:
		each = Market.buy_price(j.c.world_rules, p, j.c.band, WorldTypes.Good.GRAIN)
	return each * j.c.rules.hall_buy_lot


func can_buy() -> bool:
	return lodging != "camp" and lodging != "lord"


func can_build() -> bool:
	return lodging == "home"


## The rations the winter will eat, all four turns and the feast.
func food_need(j: Journey) -> int:
	if lodging == "lord":
		return 0
	var c := j.c
	var eaters := staying(j).size() + 1
	var per := maxi(0, eaters - maxi(0, j.c.band.household_skill))
	if _has(j, CampaignTypes.Building.BYRE):
		per = maxi(0, per - c.rules.byre_rations)
	return per * 4 + (c.rules.feast_rations_per_man * eaters if feast else 0)


func _has(j: Journey, b: int) -> bool:
	var hall: Hall = j.c.band.hall as Hall
	return int(build.get(b, 0)) > 0 or (hall != null and hall.has(b as CampaignTypes.Building))


## What the store holds at the start, after spoilage, what is bought and
## the grain in the hold, and what the talk brings or loses.
func food_start(j: Journey) -> int:
	var c := j.c
	var f := c.band.food + lots * c.rules.hall_buy_lot
	if eat_grain:
		f += grain(j) * c.rules.grain_rations
	for card in talk:
		f += int(_option(card).get("food", 0))
	return mini(f, _capacity(j))  # the rest spoils at the start of winter


## What the stores keep past the first turn, with a storehouse to be built.
func _capacity(j: Journey) -> int:
	var c := j.c
	var hall := Hall.ensure(c.band, c.rules)
	return hall.food_capacity(c.rules) + c.rules.storehouse_capacity * int(build.get(CampaignTypes.Building.STOREHOUSE, 0))


func rules_lot(j: Journey) -> int:
	return j.c.rules.hall_buy_lot


func food_gained(j: Journey) -> int:
	var c := j.c
	var each := c.rules.hunt_rations + (c.rules.camp_hunt_bonus if lodging == "camp" else 0)
	return hunters * each * 4


## Rations left at the thaw; below zero, that many go unfed.
func food_end(j: Journey) -> int:
	return food_start(j) + food_gained(j) - food_need(j)


func grain(j: Journey) -> int:
	return int(j.c.band.cargo.get(WorldTypes.Good.GRAIN, 0))


func _option(card: Dictionary) -> Dictionary:
	for o in card.options:
		if str(o.id) == str(card.get("choice", "")):
			return o
	return {}


## What each man would be given, best last: nothing, silver, an arm-ring,
## then the arms he lacks.
func ladder(rules: CampaignRules, m: Man) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"key": "none", "label": "Nothing", "ounces": 0}]
	var oz: Array = rules.hall_gift_ounces
	out.append({"key": "silver", "label": "%d oz" % int(oz[0]), "ounces": int(oz[0])})
	out.append({"key": "ring", "label": "Arm-ring, %d oz" % int(oz[1]), "ounces": int(oz[1])})
	if not m.helmet:
		out.append({"key": "helmet", "label": "Helmet, %d oz" % int(rules.arms_price.helmet), "ounces": int(rules.arms_price.helmet)})
	if m.weapon != CombatTypes.Weapon.SWORD:
		out.append({"key": "sword", "label": "Sword, %d oz" % int(rules.arms_price.sword), "ounces": int(rules.arms_price.sword)})
	if m.armor != CombatTypes.Armor.MAIL:
		out.append({"key": "mail", "label": "Mail shirt, %d oz" % int(rules.arms_price.mail), "ounces": int(rules.arms_price.mail)})
	return out


func gift_of(rules: CampaignRules, m: Man) -> Dictionary:
	var l := ladder(rules, m)
	return l[clampi(int(gifts.get(m.id, 0)), 0, l.size() - 1)]


func gifts_total(j: Journey) -> int:
	var t := 0
	for m in j.c.band.living_men():
		if not let_go.has(m.id):
			t += int(gift_of(j.c.rules, m).ounces)
	return t


## The silver all the choices would spend.
func spend(j: Journey) -> int:
	var c := j.c
	var s := lots * lot_price(j) + gifts_total(j)
	for cd in candidates:
		if cd.taken:
			s += int(cd.ask)
	for card in talk:
		s -= int(_option(card).get("silver", 0))
	for b in build:
		s += int(c.rules.building_costs.get(b, 0)) * int(build[b])
	return s


func silver_after(j: Journey) -> int:
	return j.c.band.silver - spend(j)


static func great_deed(rules: CampaignRules, m: Man) -> bool:
	return m.this_year("deeds") > 0 or m.this_year("kills") >= rules.great_deed_kills


static func loyalty_words(v: int) -> String:
	if v >= 80:
		return "would die for you"
	if v >= 60:
		return "true to you"
	if v >= 40:
		return "content"
	if v >= 25:
		return "grumbling"
	return "thinking of leaving"


## His summer in a few words: fights, men put down, wounds, a break.
static func deeds_words(m: Man) -> String:
	var bits := PackedStringArray()
	if m.this_year("fights") > 0:
		bits.append("%d fight%s" % [m.this_year("fights"), "" if m.this_year("fights") == 1 else "s"])
	if m.this_year("kills") > 0:
		bits.append("%d put down" % m.this_year("kills"))
	if m.this_year("wounds") > 0:
		bits.append("wounded %s" % ("once" if m.this_year("wounds") == 1 else "%d times" % m.this_year("wounds")))
	if m.this_year("broke") > 0:
		bits.append("broke and ran")
	if bits.is_empty():
		return "no fights this summer"
	return ", ".join(bits)


# --- Choosing --------------------------------------------------------------------------

## Does one choice by id (see `state` for the ids each step offers).
func choose(j: Journey, id: String) -> void:
	var c := j.c
	var band := c.band
	if id == "back":
		if not resolved and step > 0:
			step -= 1
		return
	if id == "next":
		if step == STEPS.find("talk") and not resolved:
			resolve(j)
			step = TOLD
		elif step < SPRING:
			step += 1
		return
	if id.begins_with("goto:"):
		var to := int(id.trim_prefix("goto:"))
		if not resolved and to >= 0 and to < TOLD:
			step = to
		return
	var parts := id.split(":")
	var key := parts[0]
	var arg := ":".join(parts.slice(1)) if parts.size() > 1 else ""
	if resolved:
		match key:
			"invest":
				j.invest(int(arg))
			"spring":
				if arg == "" or _spring_places(j).any(func(d: Dictionary) -> bool: return str(d.id) == arg):
					spring_to = arg if arg != "" else place_id
			"years", "stepdown":
				Years.choose(j, self, key, arg)
		return
	match key:
		"buy+":
			if can_buy() and silver_after(j) >= lot_price(j) and food_start(j) + rules_lot(j) <= _capacity(j):
				lots += 1
		"buy-":
			lots = maxi(0, lots - 1)
		"hunt+":
			hunters = mini(hunters + 1, _free_men(j).size())
		"hunt-":
			hunters = maxi(0, hunters - 1)
		"feast":
			feast = not feast and lodging != "lord" and lodging != "camp"
		"grain":
			eat_grain = not eat_grain and grain(j) > 0
		"home":
			_toggle(sent_home, int(arg))
			hunters = mini(hunters, _free_men(j).size())
		"build":
			var b := int(arg)
			if can_build():
				if int(build.get(b, 0)) > 0:
					build.erase(b)
				elif silver_after(j) >= int(c.rules.building_costs.get(b, 0)) and (b == CampaignTypes.Building.BENCHES or not _has(j, b)):
					build[b] = 1
		"gift+", "gift-":
			var m := band.man_by_id(int(arg))
			if m != null:
				var i := int(gifts.get(m.id, 0))
				var l := ladder(c.rules, m)
				if key == "gift-":
					gifts[m.id] = maxi(0, i - 1)
				elif i + 1 < l.size() and silver_after(j) >= int(l[i + 1].ounces) - int(l[i].ounces):
					gifts[m.id] = i + 1
		"shape":
			shape = arg
		"shout":
			shout = "" if shout == arg else arg
		"role":
			var m2 := band.man_by_id(int(arg))
			if m2 != null:
				var now: int = roles.get(m2.id, m2.role)
				roles[m2.id] = (now + 1) % 3
		"banner":
			banner = int(arg)
		"take":
			var i2 := int(arg)
			if i2 >= 0 and i2 < candidates.size():
				var cd: Dictionary = candidates[i2]
				cd.taken = not cd.taken and (silver_after(j) >= int(cd.ask))
		"let":
			_toggle(let_go, int(arg))
			hunters = mini(hunters, _free_men(j).size())
		"war":
			war_leader = -1 if war_leader == int(arg) else int(arg)
			if war_leader < 0:
				keeps_back = false
		"keep":
			keeps_back = not keeps_back and war_leader >= 0
		"second":
			second = int(arg)
		"seat":
			seat_ups.append(int(arg))
		"talk":
			var i3 := int(arg)
			if i3 >= 0 and i3 < talk.size() and parts.size() > 2:
				var card: Dictionary = talk[i3]
				var want := ":".join(parts.slice(2))
				for o in card.options:
					if str(o.id) == want and (int(o.get("silver", 0)) >= 0 or silver_after(j) + int(_option(card).get("silver", 0)) + int(o.get("silver", 0)) >= 0):
						card.choice = want


func _toggle(d: Dictionary, k: int) -> void:
	if d.has(k):
		d.erase(k)
	else:
		d[k] = true


## The seating as it would be with the moves chosen: man ids, high seat first.
func seating(j: Journey) -> Array[int]:
	var hall := Hall.ensure(j.c.band, j.c.rules)
	var order: Array[int] = hall.seating.duplicate()
	for id in seat_ups:
		var i := order.find(id)
		if i > 0:
			order.remove_at(i)
			order.insert(i - 1, id)
	return order


# --- The winter lived through ------------------------------------------------------------

## Does every choice, in a fixed order, then lets the four turns and the
## thaw pass (Campaign.winter) with a plan made from them, and tells it.
func resolve(j: Journey) -> void:
	if resolved:
		return
	resolved = true
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	var rules := c.rules
	var log := c.log
	var mark := log.size()
	var chron := band.chronicle.size()
	var r := c.rng.fork("hall_resolve:%d" % year)
	var said_mark := j.said.size()
	c.cal.start_winter()  # what happens in the hall now happens in the winter
	var who := band.leader.display_name
	var lines := PackedStringArray()
	if fee > 0:
		band.silver -= mini(fee, band.silver)
	# The men: let go, sent home, taken on; the war-leader and the second.
	for id in let_go:
		var m := band.man_by_id(int(id))
		if m == null or not m.alive or m == band.leader:
			continue
		band.remove_man(m)
		for brother in Bonds.oath_brothers(band, m):
			Loyalty.adjust(brother, -rules.bond_brother_left)
		lines.append("%s let %s go, with thanks for his service." % [who, m.display_name])
		band.log("%s let %s go" % [who, m.display_name])
	var away: Array[Man] = []
	for id in sent_home:
		var m := band.man_by_id(int(id))
		if m == null or not m.alive or m == band.leader:
			continue
		band.remove_man(m)
		Loyalty.adjust(m, -rules.loyalty_sent_home)
		away.append(m)
		lines.append("%s went home to his kin for the winter." % m.display_name)
	for cd in candidates:
		if not cd.taken or band.living_men().size() >= rules.recruit_cap:
			continue
		var m: Man = cd.man
		var ask := mini(int(cd.ask), band.silver)
		band.silver -= ask
		band.add_man(m)
		c.tally.recruits += 1
		if Potential.is_coal_biter(rules, m):
			c.tally.coal_biters += 1
		lines.append("%s came to the hall and swore to %s%s." % [m.display_name, who, (" for a ring of %d oz" % ask) if ask > 0 else ""])
		band.log("%s, a %s, swears to %s" % [m.display_name, CampaignTypes.ORIGIN_NAMES[m.origin], who])
	c._arm_new_men()
	var wl := band.man_by_id(war_leader)
	if wl != null and band.men.has(wl) and war_leader != band.war_leader_id:
		lines.append("%s named %s his war-leader, to lead the wall when he does not." % [who, wl.display_name])
		band.log("%s named %s his war-leader" % [who, wl.display_name])
	band.war_leader_id = war_leader if wl != null and band.men.has(wl) else -1
	band.leader_keeps_back = keeps_back and band.war_leader_id >= 0
	var sec := band.man_by_id(second)
	if sec != null and band.men.has(sec) and second != band.sworn_second_id:
		Succession.name_second(band, sec, log)
	# The hall: seats, buildings, the yard.
	var hall := Hall.ensure(band, rules)
	for id in seat_ups:
		var i := hall.seating.find(id)
		if i > 0:
			var passed := band.man_by_id(hall.seating[i - 1])
			var up := band.man_by_id(id)
			hall.move(id, i - 1)
			if passed != null and up != null:
				Loyalty.seating_offense(rules, band, up, passed, log)
	if can_build():
		for b in build:
			for n in int(build[b]):
				hall.build(rules, b as CampaignTypes.Building, band, log)
	for id in roles:
		var m := band.man_by_id(int(id))
		if m != null:
			m.role = roles[id] as CombatTypes.Role
	if banner >= 0 and band.man_by_id(banner) != null:
		for m in band.living_men():
			m.is_banner = m.id == banner
	band.drilling = shape
	if shout != "" and SHOUTS.has(shout):
		var sh: Array = SHOUTS[shout]
		var cs := CustomShout.make(str(sh[0]), FormationTemplate.named(shout), sh[1])
		band.custom_shouts.assign([cs])
		lines.append("The band swore a shout of its own: %s." % cs.describe())
	# The store.
	if lots > 0 and can_buy():
		var cost := mini(lots * lot_price(j), band.silver)
		band.silver -= cost
		band.food += lots * rules.hall_buy_lot
		lines.append("%d rations were bought from the house for %d oz." % [lots * rules.hall_buy_lot, cost])
	if eat_grain and grain(j) > 0:
		band.food += grain(j) * rules.grain_rations
		lines.append("The grain in the hold went to the store: %d rations." % (grain(j) * rules.grain_rations))
		band.cargo.erase(WorldTypes.Good.GRAIN)
	# The hall's talk.
	var vow := ""
	for card in talk:
		var choice := str(card.get("choice", ""))
		match str(card.kind):
			"vow":
				if choice.begins_with("vow:"):
					vow = VOWS[clampi(int(choice.trim_prefix("vow:")), 0, VOWS.size() - 1)]
			"house":
				j._answer_house(card.ask, choice)
			"household":
				lines.append_array(Family.answer_card(c, card, choice, log))
			_:
				var ev := WinterEvents.resolve(r.fork("talk:" + str(card.kind)), rules, band, c.cal, card, choice, band.ship, log)
				_after_talk(j, ev)
				if c.over:
					break
	for i in range(said_mark, j.said.size()):
		lines.append(j.said[i])
	if c.over:
		_tell(j, mark, chron, lines)
		return
	# The ring-giving, at Yule.
	_give(j, lines)
	# The turns and the thaw.
	var host_rations := staying(j).size() + 1 if lodging == "lord" else 0
	var me := self
	var planner := func(cr: CampaignRules, b: Band, cal: Calendar) -> WinterPlan:
		return me.plan_for(cr, b, cal, host_rations, vow)
	c.winter(planner, {"recruits": false, "returning": away})
	_tell(j, mark, chron, lines)


## What a resolved card leaves for the loop: fame and honor, an outlaw
## taken in, a marriage, a fight at the door.
func _after_talk(j: Journey, ev: Dictionary) -> void:
	var c := j.c
	var band := c.band
	if ev.is_empty():
		return
	band.fame = clampi(band.fame + int(ev.get("fame", 0)), 0, 100)
	band.honor = clampi(band.honor + int(ev.get("honor", 0)), 0, 100)
	if ev.get("lawful", false):
		Way.add_deed(band, Way.Id.LAWMAN, c.world_rules.deed_settle)
	if ev.get("recruit_request", false) and band.living_men().size() < c.rules.recruit_cap:
		var rr := c.rng.fork("outlaw:%d" % year)
		var m := Recruits.make(rr, c.rules, CampaignTypes.Origin.OUTLAW, 24,
				Recruits.NAMES[rr.fork("name").randi_range(0, Recruits.NAMES.size() - 1)], band.next_id())
		band.add_man(m)
		c._arm_new_men()
		c.tally.recruits += 1
	if ev.has("marriage_offer") and band.wife == "":
		var mr := c.rng.fork("marriage:%d" % year)
		var pot: Array[int] = []
		for s in 5:
			pot.append(clampi(c.rules.cap_mean + mr.randi_range(-c.rules.cap_spread, c.rules.cap_spread), 1, 10))
		Family.marry(c.rules, band, "a daughter of %s" % ev.marriage_offer, pot, mr.randi_range(1, c.rules.household_skill_max), str(ev.marriage_offer), c.log)
	if ev.has("battle_required"):
		# Hall fights are told by the saga for now. A later hook: hand this
		# to the battle screen (Journey.fight) and resume `resolve` after.
		var br: Dictionary = ev.battle_required
		c.tally.hall_fights += 1
		c.fight(str(br.kind), br.tier, int(br.attackers), false, -1, false, true)


## The ring-giving: each gift taken from the chest and given; a deed
## honoured binds tighter, a deed passed over rankles; the hall's name for
## open hands or a close fist.
func _give(j: Journey, lines: PackedStringArray) -> void:
	var c := j.c
	var band := c.band
	var rules := c.rules
	var log := c.log
	var who := band.leader.display_name
	var total := 0
	var men := band.living_men()
	var chest := band.silver
	for m in men:
		if not gifts.has(m.id):
			continue
		var g := gift_of(rules, m)
		var oz := int(g.ounces)
		if oz <= 0 or band.silver < oz:
			continue
		band.silver -= oz
		total += oz
		match str(g.key):
			"silver", "ring":
				Loyalty.gift(rules, band, m, oz, log)
			_:
				Loyalty.gift_gear(rules, band, m, str(g.key), log)
				Loyalty.adjust(m, rules.loyalty_arms_bonus)
		given[m.id] = str(g.label)
		if great_deed(rules, m):
			Loyalty.adjust(m, rules.loyalty_deed_honoured)
	for m in men:
		if great_deed(rules, m) and not given.has(m.id):
			Loyalty.adjust(m, -rules.loyalty_passed_over)
			lines.append("%s did great things this summer and was given nothing for it; he takes it ill." % m.display_name)
	var n := maxi(1, men.size())
	if not men.is_empty() and total >= rules.open_hand_ounces * n:
		band.fame = clampi(band.fame + rules.fame_open_hand, 0, 100)
		band.honor = clampi(band.honor + rules.honor_open_hand, 0, 100)
		lines.append("At Yule %s gave %d oz in rings and arms down the benches, and is called open-handed for it." % [who, total])
		band.log("%s gave rings down the benches at Yule" % who)
		_facts["hand"] = "open"
	elif not men.is_empty() and total < rules.miser_ounces * n and chest >= rules.miser_chest:
		for m in men:
			Loyalty.adjust(m, -rules.loyalty_miser)
		band.honor = clampi(band.honor - rules.honor_miser, 0, 100)
		lines.append("At Yule %s kept his chest shut, and the benches say so." % who)
		band.log("men said %s kept his silver close" % who)
		_facts["hand"] = "close"
	elif total > 0:
		lines.append("At Yule %s gave %d oz in gifts." % [who, total])
	_facts["given"] = total


## One turn's plan from the choices: the wounded heal, the chosen number
## hunt (the men lowest on the benches, as the old plan sent them), the
## rest drill the chosen shape; the feast and the vow at Yule.
func plan_for(rules: CampaignRules, band: Band, cal: Calendar, host_rations: int, vow: String) -> WinterPlan:
	var plan := WinterPlan.new()
	plan.events = false
	plan.cold = lodging == "camp"
	plan.host_rations = host_rations
	plan.drill_shape = shape
	var hall := Hall.ensure(band, rules)
	var free: Array[Man] = []
	for id in hall.seating:
		var m := band.man_by_id(id)
		if m == null or not m.alive:
			continue
		if m.healing_turns > 0:
			plan.tasks[m.id] = CampaignTypes.Task.HEAL
		else:
			free.append(m)
	var gather := CampaignTypes.Task.FISH if hall.has(CampaignTypes.Building.BOATHOUSE) else CampaignTypes.Task.HUNT
	for n in mini(hunters, free.size()):
		var m: Man = free.pop_back()
		plan.tasks[m.id] = gather
	for m in free:
		plan.tasks[m.id] = CampaignTypes.Task.DRILL
		plan.drill_stat[m.id] = Winter.lowest_stat(m)
	# A guest's benches are his host's to add to: he is not shamed for them.
	if lodging != "home" and lodging != "camp":
		hall.seats = maxi(hall.seats, hall.seating.size())
	if cal.winter_turn == CampaignTypes.WinterTurn.YULE:
		plan.feast = feast
		plan.vow = vow
	return plan


## The year told: the skald's verse, what the winter did, the men, the
## household, the houses' tidings and the saga's standing.
func _tell(j: Journey, mark: int, chron: int, lines: PackedStringArray) -> void:
	var c := j.c
	var band := c.band
	told = PackedStringArray()
	verse = _verse(j)
	Chronicle.keep_verse(band, year, verse)
	told.append("The skald's verse")
	for v in verse:
		told.append("  " + v)
	told.append("")
	told.append("The year, as the skald tells it")
	for line in band.chronicle.slice(0, chron):
		if line.begins_with("%d:" % year):
			told.append("  " + line.trim_prefix("%d: " % year))
	told.append("")
	told.append("The winter")
	for line in lines:
		told.append("  " + line)
	for i in range(mark, c.log.size()):
		var line := c.log[i]
		if line.contains(" effort in ") or line.contains(" drills ") or line.contains(": loyalty ") or line.contains("loyalty +") \
				or line.contains("loyalty -") or line.contains(" hunted and brought in ") or line.contains(" fished and brought in "):
			continue
		var at := line.find(": ")
		if line.begins_with("%d, " % year) and at > 0:
			line = line.substr(at + 2)  # the turn is not the telling's business
		if not (line.ends_with(".") or line.ends_with(")") or line.ends_with("!")):
			line += "."
		told.append("  " + Journey._cap(line))
	if (band.wife != "" or not band.sons.is_empty()) and not j.stepped_winter:
		# The stepped winter shows the household as rows (`_household_rows`).
		told.append("")
		told.append("The household")
		if band.wife != "":
			told.append("  %s keeps the keys of the stores%s." % [band.wife, (" and stretches them by %d a turn" % band.household_skill) if band.household_skill > 0 else ""])
		for child in band.sons:
			if not child.get("alive", true):
				continue
			var age := c.cal.year - int(child.get("born", c.cal.year))
			var away := str(child.get("fostered_with", ""))
			told.append("  %s, %s, %d winters old%s." % [str(child.get("name", "")), "a daughter" if child.get("daughter", false) else "a son",
					age, (", fostered with %s" % away) if away != "" else ""])
	if c.world.families != null:
		var tidings := c.world.families.tidings_of(year)
		if not tidings.is_empty():
			told.append("")
			told.append("Tidings of the houses")
			for line in tidings:
				told.append("  " + line)
	told.append("")
	told.append("The saga")
	told.append("  %s: fame %d, honor %d, luck %d. %d men sworn, %d oz in the chest, %d rations in the store." % [
			Way.title(band), band.fame, band.honor, band.luck, band.living_men().size(), band.silver, band.food])
	if Way.standing(band) != "":
		told.append("  He is reckoned %s." % Way.standing(band))
	j.winter_report = told.duplicate()


## Four lines in the skald's manner, from what the year was.
func _verse(j: Journey) -> PackedStringArray:
	var band := j.c.band
	var who := band.leader.display_name
	var out := PackedStringArray()
	var hand := str(_facts.get("hand", ""))
	if hand == "close":
		out.append("%s sat close by his chest at %s;" % [who, place_name])
	else:
		out.append("%s the ring-giver sat the high seat at %s;" % [who, place_name])
	var wins := int(_facts.get("wins", 0))
	if wins > 0:
		out.append("the raven had his fill of it, %s this summer;" % ("once" if wins == 1 else "%d times" % wins))
	else:
		out.append("no raven followed his ship this summer;")
	if str(_facts.get("best", "")) != "":
		out.append("%s fed the wolf, and %d men lay down before him;" % [_facts.best, int(_facts.best_kills)])
	else:
		out.append("the swords hung on the wall and grew no rust;")
	if hand == "open":
		out.append("red gold went down the benches, and the men will stand.")
	elif hand == "close":
		out.append("the benches looked at their empty hands.")
	else:
		out.append("the fire was long and the ale was good.")
	return out


# --- Spring --------------------------------------------------------------------------------

## Where the summer may begin: here, or a known settled place within
## `spring_days` on foot.
func _spring_places(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := j.c
	if place_id == "":
		return out
	var ids: Array = c.band.known_places.keys()
	ids.sort()
	for id in ids:
		var p := c.world.place(id)
		if p == null or id == place_id or not p.is_open(c.world.year) or not Journey.SETTLED.has(p.kind):
			continue
		var days := j.roam.place_days(place_id, id, j.foot_speed(), 0.0, false)
		if days <= 0.0 or days > float(c.world_rules.spring_days):
			continue
		out.append({"id": id, "name": p.display_name, "days": ceili(days)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.days) < int(b.days) or (int(a.days) == int(b.days) and str(a.id) < str(b.id)))
	return out.slice(0, 5)


## The band goes where the summer begins; a ship with it stays on the beach.
func go_in_spring(j: Journey) -> void:
	if spring_to == "" or spring_to == place_id or not j.roam.grid.place_cell.has(spring_to):
		return
	var band := j.c.band
	if band.ship != null and j.roam.aboard:
		j.roam.ship_at = j.roam.pos
		j.roam.aboard = false
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[spring_to])
	band.location = spring_to
	j._say("At the thaw %s goes over the hills to %s to begin the summer." % [band.leader.display_name, j.c.world.place(spring_to).display_name])


# --- For the screen ----------------------------------------------------------------------

## The step as plain values: {step, step_id, steps, title, where, lodging,
## text, rows: [{title, detail, tag, buttons: [{id, label, enabled, on}]}],
## notes, tally: {silver, silver_after, food, food_end, need, men, seats},
## can_back, can_next, next_label, resolved, told}.
func state(j: Journey) -> Dictionary:
	var c := j.c
	var s := {"step": step, "step_id": STEPS[step], "steps": STEP_TITLES, "title": STEP_TITLES[step],
			"where": place_name, "lodging": lodging_text(), "year": year, "rows": [], "notes": PackedStringArray(),
			"can_back": step > 0 and not resolved, "can_next": true, "next_label": "Go on", "resolved": resolved,
			"told": told, "text": ""}
	var hall := Hall.ensure(c.band, c.rules)
	s.tally = {"silver": c.band.silver, "silver_after": silver_after(j) if not resolved else c.band.silver,
			"food": c.band.food, "food_end": food_end(j) if not resolved else c.band.food,
			"need": food_need(j), "men": staying(j).size() if not resolved else c.band.living_men().size(),
			"seats": hall.seats + c.rules.benches_seats * int(build.get(CampaignTypes.Building.BENCHES, 0))}
	match STEPS[step]:
		"store":
			_state_store(j, s)
		"gifts":
			_state_gifts(j, s)
		"yard":
			_state_yard(j, s)
		"men":
			_state_men(j, s)
		"talk":
			_state_talk(j, s)
			s.next_label = "Live through the winter"
		"told":
			_state_told(j, s)
		"spring":
			s.next_label = "Begin the summer"
			_state_spring(j, s)
	return s


func _btn(id: String, label: String, enabled := true, on := false) -> Dictionary:
	return {"id": id, "label": label, "enabled": enabled, "on": on}


func _row(title: String, detail: String, tag: String, buttons: Array) -> Dictionary:
	return {"title": title, "detail": detail, "tag": tag, "buttons": buttons}


func _state_store(j: Journey, s: Dictionary) -> void:
	var c := j.c
	var rules := c.rules
	var band := c.band
	var rows: Array = s.rows
	var eaters := staying(j).size() + 1
	if lodging == "lord":
		s.text = "%s The lord's board feeds you and your men all winter; your own store is untouched." % lodging_text()
	else:
		s.text = "%s %d mouths to feed through four turns: %d rations%s. The store holds %d; %d keep past the first turn." % [
				lodging_text(), eaters, food_need(j), ", the feast included" if feast else "", band.food, _capacity(j)]
	var end := food_end(j)
	if end < 0:
		var per := ceili(float(-end) / maxf(1.0, float(eaters)))
		s.notes.append("Short by %d rations: men go hungry at the end of winter, %d loyalty lost for each turn a man goes without." % [-end, rules.loyalty_unfed_per_turn])
		var risk := PackedStringArray()
		for m in staying(j):
			if m != null and m.loyalty - per * rules.loyalty_unfed_per_turn < rules.loyalty_leave_below:
				risk.append(m.display_name)
		if not risk.is_empty():
			s.notes.append("Hungry, %s would leave at the thaw." % ", ".join(risk))
	else:
		s.notes.append("Enough for the winter, with %d rations over." % end)
	if can_buy():
		rows.append(_row("Buy rations", "%d rations for %d oz from the house." % [rules.hall_buy_lot, lot_price(j)], "%d bought" % (lots * rules.hall_buy_lot),
				[_btn("buy-", "Less", lots > 0), _btn("buy+", "More", silver_after(j) >= lot_price(j) and food_start(j) + rules.hall_buy_lot <= _capacity(j))]))
	if lodging != "lord":
		var each := rules.hunt_rations + (rules.camp_hunt_bonus if lodging == "camp" else 0)
		rows.append(_row("Men to hunt", "About %d rations a man each turn; they do not drill." % each, "%d hunting" % hunters,
				[_btn("hunt-", "Fewer", hunters > 0), _btn("hunt+", "More", hunters < _free_men(j).size())]))
	if lodging != "lord" and lodging != "camp":
		rows.append(_row("A Yule feast", "%d rations to the boards; it is talked of (fame %+d)." % [rules.feast_rations_per_man * eaters, rules.fame_feast],
				"held" if feast else "none", [_btn("feast", "Hold it" if not feast else "No feast", true, feast)]))
	if grain(j) > 0:
		rows.append(_row("The grain in the hold", "%d units: %d rations." % [grain(j), grain(j) * rules.grain_rations], "eaten" if eat_grain else "kept",
				[_btn("grain", "Eat it" if not eat_grain else "Keep it", true, eat_grain)]))
	if can_build():
		for b in CampaignTypes.Building.values():
			var cost := int(rules.building_costs.get(b, 0))
			var have := _has(j, b) and int(build.get(b, 0)) == 0
			if have and b != CampaignTypes.Building.BENCHES:
				continue
			var what: String = ["benches for %d more men" % rules.benches_seats, "a storehouse: %d more rations keep" % rules.storehouse_capacity,
					"a smithy: the ship is mended twice as fast", "a boathouse: men fish instead of hunting", "a byre: %d rations a turn" % rules.byre_rations][b]
			var on := int(build.get(b, 0)) > 0
			rows.append(_row("Build %s" % CampaignTypes.BUILDING_NAMES[b], "%s. %d oz." % [Journey._cap(what), cost], "to build" if on else "",
					[_btn("build:%d" % b, "Undo" if on else "Build", on or silver_after(j) >= cost, on)]))
	elif lodging != "camp":
		s.notes.append("The hall is not yours to build on; the benches are your host's, and no man is shamed for want of one.")
	if lodging == "home" and staying(j).size() > int(s.tally.seats):
		s.notes.append("%d men and %d seats: a man without a bench loses %d loyalty a turn." % [staying(j).size(), int(s.tally.seats), rules.loyalty_unseated])
	for m in c.band.living_men():
		if let_go.has(m.id):
			continue
		var home := sent_home.has(m.id)
		rows.append(_row(m.display_name, "Send him home to his kin: one mouth fewer. He comes back at the thaw if he is content.",
				"at home" if home else "in the hall", [_btn("home:%d" % m.id, "Keep him" if home else "Send home", true, home)]))


func _state_gifts(j: Journey, s: Dictionary) -> void:
	var c := j.c
	var rules := c.rules
	s.text = "The ring-giving at Yule. Give to the men of your choosing: silver, an arm-ring, arms. A man who did great things and is passed over takes it ill; a hall where nothing is given empties. %d oz in the chest." % c.band.silver
	var men := c.band.living_men()
	men.sort_custom(func(a: Man, b: Man) -> bool:
		var da := a.this_year("kills") * 3 + a.this_year("fights") + a.this_year("wounds") * 2
		var db := b.this_year("kills") * 3 + b.this_year("fights") + b.this_year("wounds") * 2
		return da > db or (da == db and a.id < b.id))
	for m in men:
		if let_go.has(m.id):
			continue
		var g := gift_of(rules, m)
		var l := ladder(rules, m)
		var i := int(gifts.get(m.id, 0))
		var detail := "%s %s. %s. %s; wants %s." % [CombatTypes.TIER_NAMES[m.tier].capitalize(), ROLE_PLACES[int(m.role)].to_lower(), Journey._cap(deeds_words(m)),
				Journey._cap(loyalty_words(m.loyalty)), CampaignTypes.AMBITION_NAMES[m.ambition]]
		if great_deed(rules, m):
			detail += " His deeds want honouring."
		var more := i + 1 < l.size() and silver_after(j) >= int(l[i + 1].ounces) - int(l[i].ounces)
		s.rows.append(_row(m.display_name, detail, str(g.label), [_btn("gift-:%d" % m.id, "Less", i > 0), _btn("gift+:%d" % m.id, "More", more)]))
	var n := maxi(1, men.size())
	var total := gifts_total(j)
	if total >= rules.open_hand_ounces * n:
		s.notes.append("%d oz given: the hall will call you open-handed (fame %+d)." % [total, rules.fame_open_hand])
	elif total < rules.miser_ounces * n and c.band.silver >= rules.miser_chest:
		s.notes.append("Next to nothing given from a full chest: every man cools by %d, and men will say so." % rules.loyalty_miser)
	else:
		s.notes.append("%d oz given; %d a man would have them call you open-handed." % [total, rules.open_hand_ounces])


func _state_yard(j: Journey, s: Dictionary) -> void:
	var c := j.c
	var rules := c.rules
	var drillers := maxi(0, _free_men(j).size() - hunters)
	s.text = "The yard. %s each turn, a point a turn in the shape you choose, to %d. A man who does not drill a shape loses a point of it at the thaw." % [
			"one man drills" if drillers == 1 else "%d men drill" % drillers, rules.drill_points_full]
	var none_on := shape == ""
	s.rows.append(_row("Each man his own weakness", "No shape: every man drills what he is worst at.", "chosen" if none_on else "",
			[_btn("shape:", "Choose", true, none_on)]))
	for t in FormationTemplate.presets():
		if not t.learned:
			continue
		var fam := c.band.familiarity(t.name, rules)
		var on := shape == t.name
		s.rows.append(_row(Journey._cap(t.name), "The band knows it %s now. A winter on the yard, and the men who drill it know it by heart." % _fam_words(fam), "chosen" if on else "",
				[_btn("shape:" + t.name, "Drill it", true, on)]))
	for key in SHOUTS:
		var sh: Array = SHOUTS[key]
		var on2: bool = shout == str(key)
		var sworn: bool = c.band.custom_shouts.size() > 0 and (c.band.custom_shouts[0] as CustomShout).name == str(sh[0])
		s.rows.append(_row("Swear \"%s!\"" % sh[0], "A shout of the band's own: the %s, then %s." % [key, CombatTypes.SHOUT_NAMES[sh[1]]],
				"sworn" if sworn else ("to swear" if on2 else ""), [_btn("shout:" + key, "Swear it" if not on2 else "Undo", not sworn, on2)]))
	for m in c.band.living_men():
		if let_go.has(m.id) or sent_home.has(m.id):
			continue
		var role: int = roles.get(m.id, m.role)
		var is_banner := banner == m.id or (banner < 0 and m.is_banner)
		s.rows.append(_row(m.display_name, "Stands in the %s.%s" % [ROLE_PLACES[role].to_lower(), " Carries the banner at your shoulder." if is_banner else ""],
				ROLE_PLACES[role], [_btn("role:%d" % m.id, "Move him"), _btn("banner:%d" % m.id, "Banner", not is_banner, is_banner)]))


static func _fam_words(f: float) -> String:
	if f >= 0.99:
		return "by heart"
	if f >= 0.6:
		return "well"
	if f > 0.0:
		return "a little"
	return "not at all"


func _state_men(j: Journey, s: Dictionary) -> void:
	var c := j.c
	var band := c.band
	s.text = "The men. Take on those who come to the hall, let a man go, seat a man higher, and name who leads the wall when you do not, and who follows you if you fall."
	for i in candidates.size():
		var cd: Dictionary = candidates[i]
		var m: Man = cd.man
		s.rows.append(_row("%s comes to the hall" % m.display_name, str(cd.line), "taken on" if cd.taken else "",
				[_btn("take:%d" % i, "Turn away" if cd.taken else "Take him", cd.taken or silver_after(j) >= int(cd.ask), cd.taken)]))
	var wl := band.man_by_id(war_leader)
	s.rows.append(_row("Lead the wall yourself", ("%s, your war-leader, leads it in your place: his eyes and voice, half the fame of it yours, and you safe at the ship." % wl.display_name) \
			if wl != null and keeps_back else "You stand in the wall in every fight.", "in your place" if keeps_back else "yourself",
			[_btn("keep", "He leads" if not keeps_back else "I lead", war_leader >= 0, keeps_back)]))
	var order := seating(j)
	for idx in order.size():
		var m := band.man_by_id(order[idx])
		if m == null:
			continue
		var bits := PackedStringArray()
		bits.append("Bench %d" % (idx + 1))
		if war_leader == m.id:
			bits.append("war-leader")
		if second == m.id:
			bits.append("sworn second")
		var detail := "%s, %d, %s %s; M%d S%d G%d N%d W%d. %s." % [", ".join(bits), m.age, CombatTypes.TIER_NAMES[m.tier], ROLE_PLACES[int(m.role)].to_lower(),
				m.stats[0], m.stats[1], m.stats[2], m.stats[3], m.stats[4], Journey._cap(loyalty_words(m.loyalty))]
		var going := let_go.has(m.id)
		s.rows.append(_row(m.display_name, detail, "to go" if going else "", [
				_btn("seat:%d" % m.id, "Seat higher", idx > 0 and not going),
				_btn("war:%d" % m.id, "War-leader", not going, war_leader == m.id),
				_btn("second:%d" % m.id, "Second", not going and second != m.id, second == m.id),
				_btn("let:%d" % m.id, "Keep" if going else "Let go", true, going)]))


func _state_talk(j: Journey, s: Dictionary) -> void:
	s.text = "The hall's talk: who came through the snow this winter, and what was asked of you."
	s.notes.append_array(Family.counsel(j.c, talk, maxi(0, -food_end(j))))
	for i in talk.size():
		var card: Dictionary = talk[i]
		var btns: Array = []
		var hints := PackedStringArray()
		for o in card.options:
			var cost := ""
			if int(o.get("silver", 0)) != 0:
				cost = " (%d oz)" % -int(o.silver)
			btns.append(_btn("talk:%d:%s" % [i, o.id], str(o.label) + cost,
					int(o.get("silver", 0)) >= 0 or silver_after(j) + int(_option(card).get("silver", 0)) + int(o.get("silver", 0)) >= 0, str(o.id) == str(card.get("choice", ""))))
			if str(card.get("choice", "")) == str(o.id) and str(o.get("hint", "")) != "":
				hints.append(str(o.hint))
		var title: String = {"vow": "The Yule cup", "house": "A house sends word", "quarrel": "A quarrel", "skald": "A skald",
				"trader": "A trader", "sickness": "Sickness", "storm": "A storm", "envoy": "An envoy", "outlaw_shelter": "An outlaw at the door",
				"thrall_unrest": "The stores", "feud_attack": "Spears in the snow", "hall_burning": "Fire in the night", "marriage_offer": "A marriage",
				"household": "The household"}.get(str(card.kind), "In the hall")
		s.rows.append(_row(str(title), str(card.text) + ((" " + " ".join(hints)) if not hints.is_empty() else ""), "", btns))


func _state_told(j: Journey, s: Dictionary) -> void:
	var band := j.c.band
	s.text = "The year told. %s." % Way.title(band)
	_household_rows(j, s)
	var free := Way.points_free(band)
	if free > 0:
		s.notes.append("%d point%s to spend down the ways of life." % [free, "" if free == 1 else "s"])
	for way in Way.Id.values():
		var cost := Way.next_cost(band, way)
		if cost <= 0:
			continue
		var d := Way.def(way)
		var r := Way.rank(band, way)
		if free <= 0 and r == 0:
			continue
		s.rows.append(_row("%s (%d of %d)" % [d.name, r, Way.MAX_RANK], str(d.ranks[r].text), "",
				[_btn("invest:%d" % way, "%s (%d)" % [d.ranks[r].name, cost], Way.can_invest(band, way))]))


func _state_spring(j: Journey, s: Dictionary) -> void:
	s.text = "The ice goes out of the fjords. Where does the summer begin?"
	if not j.c.pending_death.is_empty():
		s.text = "%s is dead. When the ice goes out, the grave-ale must be held." % str(j.c.pending_death.name)
		s.next_label = "The grave-ale"
	Years.spring_rows(j, self, s)
	s.rows.append(_row("Here, at %s" % place_name, "Where you wintered.", "chosen" if spring_to == place_id else "",
			[_btn("spring:", "Begin here", true, spring_to == place_id)]))
	for d in _spring_places(j):
		var on := spring_to == str(d.id)
		s.rows.append(_row(Journey._cap(str(d.name)), "%d days over the hills at the thaw%s." % [int(d.days),
				"; your ship stays where she lies" if j.c.band.ship != null and j.roam.aboard else ""], "chosen" if on else "",
				[_btn("spring:" + str(d.id), "Begin there", true, on)]))


## The household as rows of the year told: the wife and her keys, the old
## man by the fire, each child of the house and what is to become of him
## (Journey.household).
func _household_rows(j: Journey, s: Dictionary) -> void:
	var hh := j.household()
	var wife: Dictionary = hh.wife
	if not wife.is_empty():
		var from := str(wife.house)
		s.rows.append(_row(str(wife.short), "Your wife%s. She keeps the keys of the stores%s." % [(", of %s" % from) if from != "" else "",
				(" and stretches them by %d a turn" % int(wife.skill)) if int(wife.skill) > 0 else ""], "the keys", []))
	elif str(hh.mother) != "":
		s.rows.append(_row(Family.short_name(str(hh.mother)), "Your mother, the old leader's widow. She keeps the keys until you marry.", "the keys", []))
	var old: Dictionary = hh.old_man
	if not old.is_empty():
		s.rows.append(_row("Old %s" % str(old.name), "%d winters old. He sits by the fire and gives counsel." % int(old.age), "by the fire", []))
	for ch in hh.children:
		var who := "son" if ch.son else "daughter"
		var whose := "Your %s" % who if ch.own else "Of your father's blood: a %s" % who
		s.rows.append(_row(str(ch.name), "%s, %d winters old: %s." % [whose, int(ch.age), str(ch.state)], str(ch.tag), []))
