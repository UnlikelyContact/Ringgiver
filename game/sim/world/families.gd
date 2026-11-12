class_name Families
extends RefCounted
## The web of houses (concept.md, "Feud and wergild", "Politics"): every
## ruling family as a `House`, the ties between them, the band's standing
## with each, and the year the houses live without the band. Njal's saga
## is the model: friendships that outlast their kin's killings, feuds that
## climb step by step from an insult to a burning, settlements at the Thing
## that hold or break.
##
## A house is known by its name (what `Place.family`, `Band.feuds` and
## `Band.standing` are keyed by). Ties between two houses live in `pairs`,
## keyed by the two names in order, so they are symmetric by construction:
## {a, b, bonds: [kin|marriage|foster|friend|debt], enmity: ""|grudge|feud,
## debtor, ledger: {kills: {name: n}, step, breaks, since}}. A pair is never
## at feud and in sworn friendship at once: a feud breaks the friendship,
## and a friendship is not sworn across a feud.
##
## The band's standing is one number a house (`Band.standing`, -100..100),
## read in steps (`step_name`). It moves with what the band does
## (`shift`), and a change spreads one step out along the web: a house's
## kin and friends move part of the way with it, its enemies the other way
## (WorldRules.tie_spread). What the steps do (the Thing, prices, shelter,
## men, the war-parties on the map) is read here and used by Journey,
## Thing, Market and Roam.

const BONDS: Array[String] = ["kin", "marriage", "foster", "friend", "debt"]
## Regions whose houses live the yearly round of grudges and marriages; the
## houses abroad keep their authored ties but are not drawn into new ones.
const HOME_REGIONS := [WorldTypes.Region.VIKEN, WorldTypes.Region.AGDER, WorldTypes.Region.ROGALAND,
	WorldTypes.Region.HORDALAND, WorldTypes.Region.SOGN, WorldTypes.Region.MORE, WorldTypes.Region.TRONDELAG,
	WorldTypes.Region.HALOGALAND]
## Houses that can come to blows and marry live within this many leagues
## of each other.
const NEIGHBOUR_LEAGUES := 22.0

var houses := {}  # name -> House
var pairs := {}  # "a|b" -> Dictionary (see above)
## Year -> the tidings of the houses that year, in the saga's voice.
var tidings := {}
## House name -> the last thing told of it.
var last_told := {}


# --- Building the web -----------------------------------------------------------

## Every family that rules a place becomes a house: the authored western
## houses as written (NorwayData.HOUSES), the rest with a head and a temper
## drawn from the seed; then the authored ties (NorwayData.HOUSE_TIES).
static func build(rules: WorldRules, world: World, seed_in: int) -> Families:
	var fs := Families.new()
	var rng := SimRng.new(seed_in).fork("families")
	var authored := {}
	for d in NorwayData.HOUSES:
		authored[str(d.name)] = d
	var ids: Array = world.places.keys()
	ids.sort()
	for id in ids:
		var p: Place = world.places[id]
		if p.family == "":
			continue
		var h: House = fs.houses.get(p.family, null)
		if h == null:
			h = House.new()
			h.name = p.family
			h.seat = p.id
			h.region = p.region
			fs.houses[h.name] = h
			if authored.has(h.name):
				var d: Dictionary = authored[h.name]
				h.western = true
				h.seat = str(d.seat)
				h.head = str(d.head)
				h.heir = str(d.heir)
				h.head_age = int(d.age)
				h.strength = int(d.strength)
				h.wealth = int(d.wealth)
				h.temper = str(d.temper)
				h.honor = int(d.honor)
				h.creditor = bool(d.get("creditor", false))
			else:
				var r := rng.fork(h.name)
				h.head = NorwayData.HOUSE_MEN[r.randi_range(0, NorwayData.HOUSE_MEN.size() - 1)]
				h.heir = fs._new_name(r, h.head)
				h.head_age = 35 + r.randi_range(0, 25)
				h.temper = House.TEMPERS[r.randi_range(0, House.TEMPERS.size() - 1)]
				h.honor = 40 + r.randi_range(0, 30)
				h.wealth = p.wealth
				h.strength = maxi(4, int(rules.defenders_base.get(p.kind, 4)) + p.defenses * 2)
		h.holdings.append(p.id)
		if p.id == h.seat:
			h.region = p.region
	# A seat the data names is the house's chief place; otherwise its first.
	for h: House in fs.houses.values():
		if not h.holdings.has(h.seat) and not h.holdings.is_empty():
			h.seat = h.holdings[0]
	for t in NorwayData.HOUSE_TIES:
		var a := str(t[0])
		var b := str(t[1])
		if not fs.houses.has(a) or not fs.houses.has(b):
			continue
		var kind := str(t[2])
		var extra: Dictionary = t[3]
		fs.add_tie(a, b, kind, int(extra.get("since", world.year)))
		if kind == "feud":
			var led: Dictionary = fs.pair(a, b).ledger
			led.kills[a] = int(extra.get("kills_a", 0))
			led.kills[b] = int(extra.get("kills_b", 0))
			led.step = int(extra.get("step", 1))
		elif kind == "debt":
			fs.pair(a, b).debtor = a
	return fs


func _new_name(rng: SimRng, not_this: String) -> String:
	var n := not_this
	var guard := 0
	while n == not_this and guard < 8:
		n = NorwayData.HOUSE_MEN[rng.randi_range(0, NorwayData.HOUSE_MEN.size() - 1)]
		guard += 1
	return n


# --- Reading the web -----------------------------------------------------------------

func house(name: String) -> House:
	return houses.get(name, null)


## The house that rules a place, or null.
func house_at(world: World, place_id: String) -> House:
	var p: Place = world.place(place_id) if world != null else null
	return houses.get(p.family, null) if p != null else null


func names() -> Array[String]:
	var out: Array[String] = []
	for n in houses.keys():
		out.append(str(n))
	out.sort()
	return out


static func key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## The pair record of two houses, or {} when nothing ties them.
func pair(a: String, b: String) -> Dictionary:
	return pairs.get(key(a, b), {})


func _pair_or_new(a: String, b: String) -> Dictionary:
	var k := key(a, b)
	if not pairs.has(k):
		var lo := a if a < b else b
		var hi := b if a < b else a
		pairs[k] = {"a": lo, "b": hi, "bonds": [], "enmity": "", "debtor": "",
				"ledger": {"kills": {lo: 0, hi: 0}, "step": 0, "breaks": 0, "since": 0}}
	return pairs[k]


func has_tie(a: String, b: String, kind: String) -> bool:
	var p := pair(a, b)
	if p.is_empty():
		return false
	return (p.bonds as Array).has(kind) or str(p.enmity) == kind


func at_feud(a: String, b: String) -> bool:
	return str(pair(a, b).get("enmity", "")) == "feud"


## Ties a pair of houses. A bond is added beside the others; a grudge or a
## feud is the pair's enmity (a feud breaks a sworn friendship). A sworn
## friendship or a marriage is not made across a feud: returns false.
func add_tie(a: String, b: String, kind: String, year := 0) -> bool:
	if a == b or not houses.has(a) or not houses.has(b):
		return false
	var p := _pair_or_new(a, b)
	match kind:
		"feud":
			p.enmity = "feud"
			(p.bonds as Array).erase("friend")
			var led: Dictionary = p.ledger
			if int(led.since) == 0:
				led.since = year
			led.step = maxi(1, int(led.step))
		"grudge":
			if str(p.enmity) == "":
				p.enmity = "grudge"
				p.ledger.since = year
		_:
			if (kind == "friend" or kind == "marriage") and str(p.enmity) == "feud":
				return false
			if not (p.bonds as Array).has(kind):
				(p.bonds as Array).append(kind)
	return true


## Ends the enmity between two houses (a settlement that held, a feud that
## cooled out of men's minds).
func end_enmity(a: String, b: String) -> void:
	var p := pair(a, b)
	if p.is_empty():
		return
	p.enmity = ""
	p.ledger.step = 0
	p.ledger.breaks = 0


## The houses tied to `name`: [{other, bonds, enmity, debtor, ledger}].
func ties_of(name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ks: Array = pairs.keys()
	ks.sort()
	for k in ks:
		var p: Dictionary = pairs[k]
		if p.a != name and p.b != name:
			continue
		if (p.bonds as Array).is_empty() and str(p.enmity) == "":
			continue
		out.append({"other": p.b if p.a == name else p.a, "bonds": p.bonds, "enmity": p.enmity,
				"debtor": p.debtor, "ledger": p.ledger})
	return out


## Houses with a bond of friendship, blood, marriage or fostering to `name`.
func allies_of(name: String) -> Array[String]:
	var out: Array[String] = []
	for t in ties_of(name):
		var bonds: Array = t.bonds
		if str(t.enmity) == "feud":
			continue
		for k in ["kin", "marriage", "friend", "foster"]:
			if bonds.has(k):
				out.append(str(t.other))
				break
	return out


## Houses with a grudge or a feud against `name`.
func enemies_of(name: String) -> Array[String]:
	var out: Array[String] = []
	for t in ties_of(name):
		if str(t.enmity) != "":
			out.append(str(t.other))
	return out


## The share of a change in standing with `from` that reaches `to` along
## their ties (WorldRules.tie_spread); 0 when nothing ties them.
func spread_share(rules: WorldRules, from: String, to: String) -> float:
	var p := pair(from, to)
	if p.is_empty():
		return 0.0
	var share := 0.0
	for k in p.bonds:
		share += float(rules.tie_spread.get(k, 0.0))
	if str(p.enmity) != "":
		share += float(rules.tie_spread.get(str(p.enmity), 0.0))
	return share


## A pair's ties as a short string from `name`'s side: "kin, marriage",
## "owes them", "feud (2 killings to 1, a case at the Thing)".
func tie_text(rules: WorldRules, name: String, t: Dictionary) -> String:
	var bits := PackedStringArray()
	for k in t.bonds:
		match str(k):
			"kin":
				bits.append("kin")
			"marriage":
				bits.append("tied by marriage")
			"foster":
				bits.append("fostering")
			"friend":
				bits.append("sworn friends")
			"debt":
				bits.append("owes them" if str(t.debtor) == name else "they owe")
	match str(t.enmity):
		"grudge":
			bits.append("a grudge")
		"feud":
			var led: Dictionary = t.ledger
			var step := clampi(int(led.step), 0, rules.house_feud_steps.size() - 1)
			var ours := int(led.kills.get(name, 0))
			bits.append("feud: %d killing%s to %d, now %s" % [ours, "" if ours == 1 else "s", int(led.kills.get(str(t.other), 0)),
					rules.house_feud_steps[step]])
	return "%s: %s" % [t.other, ", ".join(bits)]


# --- The band's standing ---------------------------------------------------------------

static func standing(band: Band, name: String) -> int:
	return int(band.standing.get(name, 0))


## The step a standing is read as.
static func step_name(rules: WorldRules, value: int, kin := false) -> String:
	if value <= rules.standing_blood_enemy:
		return "blood-enemy"
	if value <= rules.standing_ill_wisher:
		return "ill-wisher"
	if value < rules.standing_well_wisher:
		return "stranger"
	if value < rules.standing_friend:
		return "well-wisher"
	if value < rules.standing_sworn:
		return "kin" if kin else "friend"
	return "kin" if kin else "sworn friend"


## The band's step with a house, as the player reads it.
static func step_of(rules: WorldRules, band: Band, name: String) -> String:
	var ties: Array = band.house_ties.get(name, [])
	return step_name(rules, standing(band, name), ties.has("kin") or ties.has("marriage"))


## A step as it is said: "a friend", "an ill-wisher", "kin".
static func step_phrase(step: String) -> String:
	if step == "kin":
		return step
	return ("an " if step.begins_with("i") else "a ") + step


## The band's step with a house as a key for the rules' tables: "sworn"
## (sworn friend or kin at the top), "friend", "well-wisher", or "".
static func support_step(rules: WorldRules, band: Band, name: String) -> String:
	var v := standing(band, name)
	if v >= rules.standing_sworn:
		return "sworn"
	if v >= rules.standing_friend:
		return "friend"
	if v >= rules.standing_well_wisher:
		return "well-wisher"
	return ""


static func is_friend(rules: WorldRules, band: Band, name: String) -> bool:
	return standing(band, name) >= rules.standing_friend


static func is_foe(rules: WorldRules, band: Band, name: String) -> bool:
	return standing(band, name) <= rules.standing_ill_wisher


static func set_standing(band: Band, name: String, value: int) -> void:
	band.standing[name] = clampi(value, -100, 100)


## Moves the band's standing with `name` by `delta`, and with every house
## tied to it by its share (WorldRules.tie_spread), one step out. Returns
## {house: change} for every house that moved. Names that are no house
## (a single killer, a stranger) are left alone.
func shift(rules: WorldRules, band: Band, name: String, delta: int) -> Dictionary:
	var moved := {}
	if band == null or delta == 0 or not houses.has(name):
		return moved
	set_standing(band, name, standing(band, name) + delta)
	moved[name] = delta
	for t in ties_of(name):
		var other := str(t.other)
		var d := roundi(float(delta) * spread_share(rules, name, other))
		if d == 0:
			continue
		set_standing(band, other, standing(band, other) + d)
		moved[other] = d
	return moved


## Keeps the band's feuds and its standing of a piece: an open feud holds
## the house at `standing_feud_cap` or under, and a feud newly settled (by
## silver, the island or the Thing) lifts it by `standing_settled`. Called
## after anything has happened.
func sync(rules: WorldRules, band: Band) -> void:
	for f in band.feuds:
		var name := str(f.get("family", f.get("against", "")))
		if not houses.has(name):
			continue
		if not f.settled:
			if standing(band, name) > rules.standing_feud_cap:
				set_standing(band, name, rules.standing_feud_cap)
		elif not f.get("mended", false):
			f["mended"] = true
			shift(rules, band, name, rules.standing_settled)


## Gift of silver at a house's seat: the standing it buys, halved for every
## gift that house has had from the band this year.
static func gift_worth(rules: WorldRules, band: Band, name: String, year: int) -> int:
	var given: Dictionary = band.gifts_given.get(name, {})
	var n := int(given.get("n", 0)) if int(given.get("year", -1)) == year else 0
	return maxi(1, rules.standing_gift >> n)


func give_gift(rules: WorldRules, world: World, band: Band, name: String, log: PackedStringArray) -> int:
	if band.silver < rules.gift_ounces or not houses.has(name):
		return 0
	var worth := gift_worth(rules, band, name, world.year)
	band.silver -= rules.gift_ounces
	var given: Dictionary = band.gifts_given.get(name, {})
	var n := int(given.get("n", 0)) if int(given.get("year", -1)) == world.year else 0
	band.gifts_given[name] = {"year": world.year, "n": n + 1}
	shift(rules, band, name, worth)
	var h := house(name)
	var who := band.leader.display_name if band.leader != null else "The leader"
	var line := "%s gives %s a gift of %d oz in silver. %s" % [who, h.head, rules.gift_ounces,
			"It is well taken." if n == 0 else "It is taken, but the last is not long forgotten."]
	log.append(line)
	return worth


# --- What standing does ---------------------------------------------------------------

## Who stands with whom at the Thing in a case against `against`: the
## band's own well-wishers and friends (not the other side's allies, and
## never a debtor of the other side), the other side's allies (unless they
## are the band's friends), and the other side's enemies who are not the
## band's ill-wishers, for the band. `client` is a house the band speaks
## for: its strength and allies are with the band. Returns {ours, theirs,
## with: [names], against: [names]}.
func thing_backing(rules: WorldRules, band: Band, against: String, client := "") -> Dictionary:
	var out := {"ours": 0, "theirs": 0, "with": [], "against": []}
	var counted := {}
	for name in names():
		if name == against:
			continue
		var p := pair(name, against)
		var owes_them: bool = not p.is_empty() and str(p.debtor) == name
		var allied: bool = allies_of(against).has(name)
		var their_enemy: bool = not p.is_empty() and str(p.enmity) != ""
		var step := support_step(rules, band, name)
		if name == client:
			out.ours += rules.ally_support * 2
			(out.with as Array).append(name)
			counted[name] = true
			continue
		if allied and not is_friend(rules, band, name):
			out.theirs += rules.ally_support
			(out.against as Array).append(name)
			continue
		if owes_them:
			continue
		if step != "":
			out.ours += int(rules.house_support.get(step, 0))
			(out.with as Array).append(name)
			counted[name] = true
		elif their_enemy and not is_foe(rules, band, name):
			out.ours += rules.enemy_of_enemy_support
			(out.with as Array).append(name)
			counted[name] = true
	if client != "":
		for ally in allies_of(client):
			if not counted.has(ally) and ally != against and not allies_of(against).has(ally):
				out.ours += rules.ally_support
				(out.with as Array).append(ally)
				counted[ally] = true
	return out


## The middlemen's spread a house lets the band off at its market: all of
## it for a friend (he deals at the true price, as a trader does), none
## for anyone else. Never more than the spread, so no round trip pays.
static func spread_off(rules: WorldRules, band: Band, place: Place) -> float:
	if band == null or place == null or place.family == "":
		return 0.0
	return rules.friend_spread_off if is_friend(rules, band, place.family) else 0.0


## What an ill-wisher's market asks over the price (and takes off what it
## pays): `foe_price`, else 1.
static func foe_factor(rules: WorldRules, band: Band, place: Place) -> float:
	if band == null or place == null or place.family == "":
		return 1.0
	return rules.foe_price if is_foe(rules, band, place.family) else 1.0


## Whether a house will lodge the band for the winter: "free" at a
## friend's seat, "shut" at an ill-wisher's, else "paid".
static func shelter(rules: WorldRules, band: Band, place: Place) -> String:
	if place == null or place.family == "":
		return "paid"
	if is_friend(rules, band, place.family):
		return "free"
	if is_foe(rules, band, place.family):
		return "shut"
	return "paid"


## A party of `family` on the map toward the band: 1 leaves it alone (a
## well-wisher or better), -1 hunts it whatever the odds (a blood-enemy, or
## at feud with it), 0 as it would any band.
static func party_mood(rules: WorldRules, band: Band, family: String) -> int:
	if family == "":
		return 0
	var v := standing(band, family)
	if v >= rules.standing_well_wisher:
		return 1
	if v <= rules.standing_blood_enemy or not Feud.find(band, family).is_empty():
		return -1
	return 0


## The reckoning with `name`: its men in the field, with its allies' (each
## house tied to it by kin, marriage, fostering or sworn friendship sends
## `ally_men_sent`, unless it is the band's friend, or a friend of the
## band's is its own enemy and keeps it at home), the friends of the band
## among its enemies and the men they send. {house_men, allies: [names],
## allied, friends: [names], sent, men}.
func reckoning_terms(rules: WorldRules, band: Band, name: String) -> Dictionary:
	var h := house(name)
	var friends: Array[String] = []
	for e in enemies_of(name):
		if standing(band, e) >= rules.standing_friend:
			friends.append(e)
	var allies: Array[String] = []
	for a in allies_of(name):
		if standing(band, a) >= rules.standing_friend:
			continue
		var held := false
		for e in enemies_of(a):
			if e != name and standing(band, e) >= rules.standing_friend:
				held = true
				break
		if not held:
			allies.append(a)
	var house_men := h.strength if h != null else rules.house_fight_men
	var allied := allies.size() * rules.ally_men_sent
	var sent := friends.size() * rules.friend_men_sent
	return {"house_men": house_men, "allies": allies, "allied": allied, "friends": friends, "sent": sent,
			"men": maxi(3, house_men + allied - sent)}


## The burned hall's long arc: what the band could bring against the house
## it has its vengeance on (its own fighting men, `band_men`, and the men
## its friends among their enemies would send) against what that house
## would bring with its allies. They answer for the burning (wergild
## offered, a case at the Thing) only once the band's side is
## `vengeance_backing_ratio` of theirs: {ours, theirs, ready}.
func vengeance_backing(rules: WorldRules, band: Band, name: String, band_men: int) -> Dictionary:
	var t := reckoning_terms(rules, band, name)
	var theirs := int(t.house_men) + int(t.allied)
	var ours := band_men + int(t.sent)
	return {"ours": ours, "theirs": theirs, "ready": float(ours) >= float(theirs) * rules.vengeance_backing_ratio}


## Whether a house lives abroad (outside Norway's own regions: the monks
## of Iona, the Danish king's men): it offers no marriage or fostering and
## is not brought to a reckoning as a Norse house is.
func abroad(name: String) -> bool:
	var h := house(name)
	return h != null and not HOME_REGIONS.has(h.region)


## A killing between two houses' men out in the world (WorldLife): a pair
## with nothing between them takes a grudge; a feud takes the killing on
## its ledger. A grudge comes to a feud with it only when the houses' own
## men met (`open_war`); a raid by one house's ship on another's farm
## leaves a grudge, and the houses' own year decides whether it comes to
## blood.
func record_killing(rules: WorldRules, band: Band, killer: String, dead: String, year: int, open_war := false) -> void:
	if killer == dead or not houses.has(killer) or not houses.has(dead):
		return
	var p := pair(killer, dead)
	if p.is_empty() or str(p.enmity) == "":
		add_tie(killer, dead, "grudge", year)
		return
	if str(p.enmity) == "grudge":
		if not open_war:
			return
		add_tie(killer, dead, "feud", year)
		p = pair(killer, dead)
	_kill(rules, band, p, killer, dead)


# --- The houses' own year ---------------------------------------------------------------

## A year of the houses without the band: heads die and sons follow them,
## feuds climb or cool by seeded chance shaped by the tempers, grudges
## break into killings or fade, neighbours fall out and marry. At most
## `tidings_max` tidings, kept in `tidings[year]`. A killing against a
## house the band is kin to by blood or marriage costs the killers some of
## the band's standing: the feud is partly the band's.
func year_end(rng: SimRng, rules: WorldRules, world: World, band: Band) -> PackedStringArray:
	var out := PackedStringArray()
	var year := world.year
	# Heads grow old and die; their sons follow them.
	var deaths := 0
	for name in names():
		var h := house(name)
		h.head_age += 1
		if out.size() >= rules.tidings_max or deaths >= rules.deaths_max:
			continue
		var chance := rules.head_old_death_chance if h.head_age >= rules.head_old_age else rules.head_death_chance
		if rng.fork("death:" + name).randf() < chance:
			_tell(out, name, "%s died in his bed, and %s his son holds the house now." % [h.head_title(world), h.heir])
			deaths += 1
			_succeed(rng.fork("heir:" + name), h)
	# Feuds climb or cool; settlements hold or break.
	var ks: Array = pairs.keys()
	ks.sort()
	for k in ks:
		if out.size() >= rules.tidings_max:
			break
		var p: Dictionary = pairs[k]
		var r := rng.fork("pair:" + str(k))
		match str(p.enmity):
			"feud":
				_feud_year(r, rules, world, band, p, out)
			"grudge":
				var a := house(str(p.a))
				var b := house(str(p.b))
				var hot := rules.grudge_to_feud + float(rules.temper_climb.get(a.temper, 0.0)) + float(rules.temper_climb.get(b.temper, 0.0))
				var roll := r.randf()
				if roll < hot:
					add_tie(a.name, b.name, "feud", year)
					var killer := a if r.randf() < 0.5 else b
					var dead := b if killer == a else a
					_kill(rules, band, p, killer.name, dead.name)
					_tell(out, killer.name, "The grudge between %s and %s came to blood: a man of %s was killed by %s's men." % [
							a.name, b.name, dead.name, killer.head])
				elif roll < hot + rules.grudge_fade_chance:
					p.enmity = ""
					_tell(out, a.name, "The grudge between %s and %s is let lie." % [a.name, b.name])
	# Neighbours fall out.
	if out.size() < rules.tidings_max and rng.fork("grudge").randf() < rules.new_grudge_chance:
		var two := _two_neighbours(rng.fork("grudge_pick"), world, func(p: Dictionary) -> bool: return p.is_empty() or (str(p.enmity) == "" and (p.bonds as Array).is_empty()))
		if not two.is_empty():
			add_tie(two[0], two[1], "grudge", year)
			var cause: String = ["grazing", "a stranded whale", "a horse-fight", "a loan not repaid", "words at a feast"][rng.fork("cause").randi_range(0, 4)]
			_tell(out, two[0], "Words passed between %s and %s over %s; there is a grudge between them now." % [two[0], two[1], cause])
	# Neighbours marry.
	if out.size() < rules.tidings_max and rng.fork("marry").randf() < rules.house_marriage_chance:
		var two2 := _two_neighbours(rng.fork("marry_pick"), world, func(p: Dictionary) -> bool:
			return p.is_empty() or (str(p.enmity) != "feud" and not (p.bonds as Array).has("marriage")))
		if not two2.is_empty():
			add_tie(two2[0], two2[1], "marriage", year)
			var bride: String = NorwayData.HOUSE_WOMEN[rng.fork("bride").randi_range(0, NorwayData.HOUSE_WOMEN.size() - 1)]
			_tell(out, two2[0], "%s of %s was married to %s, a son of %s; the two houses are tied now." % [
					bride, two2[1], house(two2[0]).heir, two2[0]])
	tidings[year] = out
	return out


func _feud_year(r: SimRng, rules: WorldRules, world: World, band: Band, p: Dictionary, out: PackedStringArray) -> void:
	var a := house(str(p.a))
	var b := house(str(p.b))
	var led: Dictionary = p.ledger
	var step := int(led.step)
	var heat := float(rules.temper_climb.get(a.temper, 0.0)) + float(rules.temper_climb.get(b.temper, 0.0))
	var steps := rules.house_feud_steps
	if step == 4:
		# A settlement: it holds, or it breaks.
		if r.randf() < rules.settlement_hold_chance - heat:
			end_enmity(a.name, b.name)
			a.honor = mini(100, a.honor + rules.feud_honor_loss)
			b.honor = mini(100, b.honor + rules.feud_honor_loss)
			_tell(out, a.name, "The settlement between %s and %s held, and the feud is over." % [a.name, b.name])
		else:
			var breaker := a if r.randf() < 0.5 else b
			var other := b if breaker == a else a
			breaker.honor = maxi(0, breaker.honor - rules.feud_honor_loss)
			led.breaks = int(led.breaks) + 1
			led.step = 2
			_kill(rules, band, p, breaker.name, other.name)
			_tell(out, breaker.name, "%s broke the settlement with %s: a man was killed on the road, and the feud is open again." % [
					breaker.name, other.name])
		return
	var roll := r.randf()
	var climb := rules.feud_climb_chance + heat
	if roll < climb:
		if step >= 2 and int(led.breaks) >= 1:
			_burning(r, rules, world, band, p, out)
			return
		step = mini(step + 1, 4)
		led.step = step
		match step:
			1, 2:
				# The side that has lost more men kills next.
				var killer := a if int(led.kills.get(b.name, 0)) >= int(led.kills.get(a.name, 0)) else b
				if step == 2:
					killer = b if int(led.kills.get(a.name, 0)) > int(led.kills.get(b.name, 0)) else a
				var dead := b if killer == a else a
				_kill(rules, band, p, killer.name, dead.name)
				_tell(out, killer.name, "%s's men killed a man of %s; it is %s between them now." % [killer.head, dead.name, steps[step]])
			3:
				_tell(out, a.name, "%s and %s brought their killings to the Thing." % [a.name, b.name])
			4:
				var payer := a if int(led.kills.get(a.name, 0)) > int(led.kills.get(b.name, 0)) else b
				_tell(out, payer.name, "At the Thing the law-men made a settlement between %s and %s; %s paid wergild for the odd killing." % [
						a.name, b.name, payer.name])
	elif roll < climb + rules.feud_cool_chance and step < 3:
		p.enmity = "grudge"
		led.step = 0
		_tell(out, a.name, "The feud between %s and %s cools; men say little of it this year." % [a.name, b.name])


## A settlement broken and broken again ends in fire: the weaker house is
## burned in its hall. Its head dies there, its son holds what is left, and
## the burners are thought the less of. The feud goes on: there is a
## burning to avenge.
func _burning(r: SimRng, rules: WorldRules, world: World, band: Band, p: Dictionary, out: PackedStringArray) -> void:
	var a := house(str(p.a))
	var b := house(str(p.b))
	var burned := a if a.strength < b.strength or (a.strength == b.strength and r.randf() < 0.5) else b
	var burner := b if burned == a else a
	var led: Dictionary = p.ledger
	led.step = 5
	var seat: Place = world.place(burned.seat)
	_tell(out, burner.name, "%s's men burned %s in their hall at %s. %s died in the fire; %s got out, and holds what is left." % [
			burner.head, burned.name, seat.display_name if seat != null else burned.seat, burned.head, burned.heir])
	_kill(rules, band, p, burner.name, burned.name)
	burned.strength = maxi(3, roundi(burned.strength * (1.0 - rules.burning_strength_loss)))
	burner.honor = maxi(0, burner.honor - rules.burning_honor)
	_succeed(r.fork("burned_heir"), burned)
	led.step = 1
	led.breaks = 0


func _kill(rules: WorldRules, band: Band, p: Dictionary, killer: String, dead: String) -> void:
	var kills: Dictionary = p.ledger.kills
	kills[killer] = int(kills.get(killer, 0)) + 1
	# The band's kin's feuds are partly the band's.
	if band != null:
		var ties: Array = band.house_ties.get(dead, [])
		if ties.has("kin") or ties.has("marriage"):
			shift(rules, band, killer, -5)


func _succeed(rng: SimRng, h: House) -> void:
	h.head = h.heir if h.heir != "" else _new_name(rng, h.head)
	h.heir = _new_name(rng, h.head)
	h.head_age = 28 + rng.randi_range(0, 12)


## Two houses at home within `NEIGHBOUR_LEAGUES` of each other whose pair
## `ok` accepts, drawn from the seed; [] if none.
func _two_neighbours(rng: SimRng, world: World, ok: Callable) -> Array[String]:
	var cands: Array = []
	var ns := names()
	for i in ns.size():
		var a := house(ns[i])
		var pa: Place = world.place(a.seat)
		if pa == null or not HOME_REGIONS.has(a.region):
			continue
		for j in range(i + 1, ns.size()):
			var b := house(ns[j])
			var pb: Place = world.place(b.seat)
			if pb == null or not HOME_REGIONS.has(b.region) or pa.pos.distance_to(pb.pos) > NEIGHBOUR_LEAGUES:
				continue
			if ok.call(pair(a.name, b.name)):
				cands.append([a.name, b.name])
	if cands.is_empty():
		return []
	var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
	var out: Array[String] = [str(pick[0]), str(pick[1])]
	return out


func _tell(out: PackedStringArray, name: String, line: String) -> void:
	out.append(line)
	last_told[name] = line


## Whether any pair is at once at feud and in sworn friendship.
func contradictions() -> PackedStringArray:
	var out := PackedStringArray()
	for k in pairs:
		var p: Dictionary = pairs[k]
		if str(p.enmity) == "feud" and (p.bonds as Array).has("friend"):
			out.append(str(k))
		if str(p.enmity) != "" and str(p.enmity) != "feud" and str(p.enmity) != "grudge":
			out.append(str(k))
	return out


## Settles a feud between two houses through the band (a settlement carried
## or pleaded for one of them): the feud goes to the settlement step, to
## hold or break in the coming years.
func settle_between(a: String, b: String) -> void:
	var p := pair(a, b)
	if p.is_empty() or str(p.enmity) == "":
		return
	if str(p.enmity) == "grudge":
		end_enmity(a, b)
		return
	p.ledger.step = 4


# --- Asked of the band -----------------------------------------------------------------

## What the houses ask of the band this spring: at most `asks_per_summer`,
## each in `ask_chance`, from houses whose seat the band knows and that are
## no ill-wishers of it. Each is {kind: "house", ask, house, against?,
## ounces?, text, options}. Asks: "help" (stand with them in their feud,
## speak for them at the Thing, carry an offer of settlement, or refuse),
## "marry" (a daughter of the house for an unmarried leader), "foster"
## (their son raised in the band's hall), "compensation" (a house at feud
## with the band offers wergild for the band's dead, or blood is taken).
func asks(rng: SimRng, rules: WorldRules, world: World, band: Band, cal_year: int) -> Array[Dictionary]:
	var cands: Array[Dictionary] = []
	var who := band.leader.display_name if band.leader != null else "you"
	for name in names():
		var h := house(name)
		if not band.knows(h.seat) or is_foe(rules, band, name):
			continue
		var seat: Place = world.place(h.seat)
		var at := seat.display_name if seat != null else h.seat
		for e in enemies_of(name):
			if not at_feud(name, e) or is_friend(rules, band, e):
				continue
			var help_opts: Array[Dictionary] = [
				{"id": "stand", "label": "Stand with them"},
				{"id": "speak", "label": "Speak for them at the Thing"},
				{"id": "carry", "label": "Carry an offer of settlement"},
				{"id": "refuse", "label": "Keep out of it"}]
			cands.append({"kind": "house", "ask": "help", "house": name, "against": e, "options": help_opts,
					"text": "%s sends from %s: there is a feud between his house and %s (%s). Will %s stand with them? Whatever you do, the other side will hear of it." % [
							h.head, at, e, tie_text(rules, name, _tie(name, e)).trim_prefix(e + ": "), who]})
			break
		if band.wife == "" and band.leader != null and band.leader.alive and standing(band, name) >= rules.standing_well_wisher \
				and not (band.house_ties.get(name, []) as Array).has("marriage") and not abroad(name):
			var bride: String = NorwayData.HOUSE_WOMEN[rng.fork("bride:" + name).randi_range(0, NorwayData.HOUSE_WOMEN.size() - 1)]
			var enemies := enemies_of(name)
			cands.append({"kind": "house", "ask": "marry", "house": name, "bride": bride, "options": [
					{"id": "accept", "label": "Take her to wife"}, {"id": "decline", "label": "Decline with thanks"}],
					"text": "%s offers %s, his daughter, to %s in marriage. His house would be yours by marriage%s." % [
							h.head, bride, who, (", and so would its quarrels with %s" % ", ".join(enemies)) if not enemies.is_empty() else ""]})
		if standing(band, name) >= rules.standing_well_wisher and not (band.house_ties.get(name, []) as Array).has("foster") and not abroad(name):
			cands.append({"kind": "house", "ask": "foster", "house": name, "options": [
					{"id": "accept", "label": "Foster the boy"}, {"id": "decline", "label": "Decline"}],
					"text": "%s asks %s to foster his youngest son. To foster a man's son is to have his house in your debt." % [h.head, who]})
	for f in band.unsettled_feuds():
		var fam := str(f.get("family", f.get("against", "")))
		var cause := str(f.get("cause", ""))
		var wronged := not (cause.begins_with("raid on") or cause.begins_with("strandhögg") or cause.begins_with("robbed"))
		if not houses.has(fam) or not wronged or int(f.get("offered", -1)) == cal_year:
			continue
		var ask := roundi(Feud.wergild(rules, f.get("rank", rules.default_victim_rank)) * rules.compensation_share)
		if fam == band.vengeance:
			# The burners pay for a burning only when they must, and dearly.
			if not bool(vengeance_backing(rules, band, fam, band.fighters().size()).ready):
				continue
			ask = roundi(Feud.wergild(rules, f.get("rank", rules.default_victim_rank)) * rules.vengeance_wergild_mult)
		cands.append({"kind": "house", "ask": "compensation", "house": fam, "ounces": ask, "feud": f, "options": [
				{"id": "take", "label": "Take %d oz" % ask}, {"id": "blood", "label": "Take blood instead"}],
				"text": "%s offer %d oz of wergild to end the feud over %s. Silver, or blood?" % [Journey._cap(fam), ask, cause]})
	# Drawn in a seeded order, a few a spring.
	var out: Array[Dictionary] = []
	var order := cands.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Dictionary = order[i]
		order[i] = order[j]
		order[j] = t
	var asked := {}
	for d: Dictionary in order:
		if out.size() >= rules.asks_per_summer:
			break
		if asked.has(d.house) or rng.randf() >= rules.ask_chance:
			continue
		asked[d.house] = true
		if d.ask == "compensation":
			(d.feud as Dictionary)["offered"] = cal_year
		out.append(d)
	return out


func _tie(a: String, b: String) -> Dictionary:
	for t in ties_of(a):
		if t.other == b:
			return t
	return {"other": b, "bonds": [], "enmity": "", "debtor": "", "ledger": {}}


## The band takes a house's daughter to wife: the standing of a marriage
## (spreading to the house's kin and against its enemies), the tie, and
## its quarrels become partly the band's.
func marry_into(rules: WorldRules, crules: CampaignRules, rng: SimRng, band: Band, name: String, bride: String, log: PackedStringArray) -> void:
	var pot: Array[int] = []
	for s in 5:
		pot.append(clampi(crules.cap_mean + rng.randi_range(-crules.cap_spread, crules.cap_spread), 1, 10))
	Family.marry(crules, band, "%s, daughter of %s" % [bride, house(name).head], pot, rng.randi_range(1, crules.household_skill_max), name, log)
	_band_tie(band, name, "marriage")
	shift(rules, band, name, rules.standing_marriage)


func foster_for(rules: WorldRules, band: Band, name: String, log: PackedStringArray) -> void:
	_band_tie(band, name, "foster")
	shift(rules, band, name, rules.standing_foster)
	var h := house(name)
	log.append("A son of %s comes to be fostered with %s; his house owes you for it." % [h.head, band.leader.display_name if band.leader != null else "you"])
	band.alliances.append("%s, whose son is fostered with you" % name)


static func _band_tie(band: Band, name: String, kind: String) -> void:
	var ties: Array = band.house_ties.get(name, [])
	if not ties.has(kind):
		ties.append(kind)
	band.house_ties[name] = ties


## The origin's houses: the standing and the blood ties it starts with
## (WorldRules.origin_standing, origin_kin), and the vengeance pointed
## into the web.
func start_origin(rules: WorldRules, world: World, band: Band, origin_key: String) -> void:
	var st: Dictionary = rules.origin_standing.get(origin_key, {})
	for place_id in st:
		var h := house_at(world, str(place_id))
		if h != null:
			set_standing(band, h.name, int(st[place_id]))
	for place_id in rules.origin_kin.get(origin_key, []):
		var h := house_at(world, str(place_id))
		if h != null:
			_band_tie(band, h.name, "kin")


# --- For the screen ----------------------------------------------------------------------

## Every house as plain values for the view, the band's friends and foes
## first: [{name, head, heir, seat, seat_name, temper, strength, honor,
## standing, step, ties: [str], your_ties: [str], feud: str, told}].
func report(rules: WorldRules, world: World, band: Band) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for name in names():
		var h := house(name)
		var seat: Place = world.place(h.seat)
		var ties := PackedStringArray()
		for t in ties_of(name):
			ties.append(tie_text(rules, name, t))
		var feud := ""
		var f := Feud.find(band, name)
		if not f.is_empty():
			feud = "at feud with you over %s" % str(f.get("cause", "an old wrong"))
		var yours := PackedStringArray()
		for k in band.house_ties.get(name, []):
			yours.append(str(k))
		out.append({"name": name, "head": h.head, "heir": h.heir, "seat": h.seat,
				"seat_name": seat.display_name if seat != null else h.seat, "region": WorldTypes.REGION_NAMES[h.region],
				"temper": h.temper, "strength": h.strength, "honor": h.honor, "western": h.western,
				"standing": standing(band, name), "step": step_of(rules, band, name), "ties": ties,
				"your_ties": yours, "feud": feud, "told": str(last_told.get(name, "")),
				"known": band.knows(h.seat)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ax := absi(int(x.standing)) + (200 if str(x.feud) != "" else 0) + (100 if x.western else 0)
		var ay := absi(int(y.standing)) + (200 if str(y.feud) != "" else 0) + (100 if y.western else 0)
		return ax > ay or (ax == ay and str(x.name) < str(y.name)))
	return out


## The tidings of a year (the last told, when `year` is 0).
func tidings_of(year := 0) -> PackedStringArray:
	if year == 0:
		var ys: Array = tidings.keys()
		if ys.is_empty():
			return PackedStringArray()
		ys.sort()
		year = int(ys[-1])
	return tidings.get(year, PackedStringArray())
