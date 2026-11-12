class_name Way
extends RefCounted
## The ways a man can live in the saga world (concept.md, "Ways of life"):
## the raider, the trader, the law-wise man, the berserk, the skald, the
## king's man. Nobody starts as one. Deeds of any kind earn points
## (`points_earned`), and a man spends them on steps down whichever paths
## he likes, in any mixture (`invest`): three steps a path, each dearer
## than the last, each giving its edges (`gifts`, read by the world
## modules through Band.gift). And the saga names him by what he has done
## (`deeds`, `epithet`), not by what he has learned.

enum Id { VIKING, TRADER, LAWMAN, BERSERK, SKALD, KINGS_MAN }

## Steps on one path, and what a step costs: the first one point, the
## second two, the third three.
const MAX_RANK := 3
## A point for every so many deeds of any kind; and one to begin with.
const POINT_DEEDS := 6
const START_POINTS := 1
## Deeds in one way before the saga gives a man its name.
const EPITHET_DEEDS := 6

## key, name, norse, model (the saga man it is cut from), blurb, epithet,
## and `ranks`: for each step its name, what the player reads, and the
## whole of the edges a man has at that step (not what the step adds).
const DEFS := [
	{"key": "viking", "name": "Viking", "norse": "víkingr", "model": "the sea-kings", "epithet": "the Viking",
		"blurb": "A ship, a crew, and other men's silver.",
		"ranks": [
			{"name": "Raider", "text": "Raids take a fifth more silver.", "gifts": {"raid_plunder": 1.2}},
			{"name": "Sea-wolf", "text": "A third more silver; a strandhögg brings twice the stores.", "gifts": {"raid_plunder": 1.35, "strandhogg": 2}},
			{"name": "Sea-king", "text": "Half as much again, and two more captives from every raid.", "gifts": {"raid_plunder": 1.5, "strandhogg": 2, "raid_captives": 2}},
		]},
	{"key": "trader", "name": "Trader", "norse": "farmaðr", "model": "Ohthere of Hålogaland", "epithet": "the Far-Travelled",
		"blurb": "A deep hold and a head for prices.",
		"ranks": [
			{"name": "Pedlar", "text": "The middlemen take six in a hundred from you, not ten.", "gifts": {"trade_edge": 0.04}},
			{"name": "Merchant", "text": "Three in a hundred, and you hear the prices of every market you know.", "gifts": {"trade_edge": 0.07, "price_talk": true}},
			{"name": "Far-trader", "text": "You deal at the true price itself.", "gifts": {"trade_edge": 0.1, "price_talk": true}},
		]},
	{"key": "lawman", "name": "Law-wise man", "norse": "lögmaðr", "model": "Njáll of Bergthorshvoll", "epithet": "the Law-Wise",
		"blurb": "Counsel, the Thing, and friends who stand by you there.",
		"ranks": [
			{"name": "Law-learned", "text": "One better at every pleading and counsel; a third more for your counsel.", "gifts": {"law": 1, "counsel_fee": 1.3}},
			{"name": "Law-man", "text": "Two better; paid half as much again.", "gifts": {"law": 2, "counsel_fee": 1.6}},
			{"name": "Law-wise", "text": "Three better, paid double. You see trouble before it comes: your scouts count true, and you are never caught on the march.", "gifts": {"law": 3, "counsel_fee": 2.0, "foresight": true}},
		]},
	{"key": "berserk", "name": "Berserk", "norse": "berserkr", "model": "Kveldulf's blood", "epithet": "the Berserk",
		"blurb": "The fury in a fight, and the fear of it before one. Lords trust you the less for it.",
		"ranks": [
			{"name": "Hard man", "text": "The fury: stronger while your breath lasts, no wound felt, and those beside you lose heart. One man in seven pays rather than meet you on the island.", "gifts": {"fury": 1, "dread": 0.15}},
			{"name": "Wolf-coat", "text": "One man in four pays rather than fight; half as much again for standing in a farmer's place.", "gifts": {"fury": 1, "dread": 0.25, "champion_fee": 1.5}},
			{"name": "Berserk", "text": "The fury runs deeper; one man in three pays; double for standing in a farmer's place.", "gifts": {"fury": 2, "dread": 0.35, "champion_fee": 2.0}},
		]},
	{"key": "skald", "name": "Skald", "norse": "skáld", "model": "Egil Skallagrimsson", "epithet": "the Skald",
		"blurb": "Kings pay for praise that will outlive them.",
		"ranks": [
			{"name": "Verse-maker", "text": "One better at a verse; a third more in the ring.", "gifts": {"verse": 1, "verse_gift": 1.3}},
			{"name": "Skald", "text": "Two better; half as much again.", "gifts": {"verse": 2, "verse_gift": 1.6}},
			{"name": "King's skald", "text": "Three better, double the ring, and twice the fame of it.", "gifts": {"verse": 3, "verse_gift": 2.0, "verse_fame": 2}},
		]},
	{"key": "kings_man", "name": "King's man", "norse": "hirðmaðr", "model": "Thorolf Kveldulfsson", "epithet": "the King's Man",
		"blurb": "A lord's work, a lord's pay, and a place on his bench.",
		"ranks": [
			{"name": "Sworn man", "text": "A lord's work pays a tenth more.", "gifts": {"contract_pay": 1.1}},
			{"name": "Hirdman", "text": "A fifth more, and it counts double toward your rank.", "gifts": {"contract_pay": 1.2, "rank_progress": 2}},
			{"name": "Lendman", "text": "Three tenths more, and it counts threefold.", "gifts": {"contract_pay": 1.3, "rank_progress": 3}},
		]},
]


static func def(way: int) -> Dictionary:
	return DEFS[clampi(way, 0, DEFS.size() - 1)]


static func name_of(way: int) -> String:
	return def(way).name


# --- Points and paths -------------------------------------------------------------

static func total_deeds(band: Band) -> int:
	var n := 0
	for way in band.deeds:
		n += int(band.deeds[way])
	return n


## Points a man has had to spend so far: one to begin with, and one for
## every `POINT_DEEDS` deeds of any kind.
static func points_earned(band: Band) -> int:
	return START_POINTS + total_deeds(band) / POINT_DEEDS


## What the steps he has taken cost: 1, 1+2, 1+2+3 for a path.
static func points_spent(band: Band) -> int:
	var n := 0
	for way in band.paths:
		var r := int(band.paths[way])
		n += r * (r + 1) / 2
	return n


static func points_free(band: Band) -> int:
	return points_earned(band) - points_spent(band)


static func rank(band: Band, way: int) -> int:
	return int(band.paths.get(way, 0))


## What the next step on a path costs, or 0 when it is walked to its end.
static func next_cost(band: Band, way: int) -> int:
	var r := rank(band, way)
	return 0 if r >= MAX_RANK else r + 1


static func can_invest(band: Band, way: int) -> bool:
	var cost := next_cost(band, way)
	return cost > 0 and points_free(band) >= cost


## Takes the next step on a path, if he has the points for it.
static func invest(band: Band, way: int) -> bool:
	if not can_invest(band, way):
		return false
	band.paths[way] = rank(band, way) + 1
	refresh(band)
	band.log("%s is now reckoned a %s" % [band.leader.display_name if band.leader != null else "he",
			str(def(way).ranks[rank(band, way) - 1].name).to_lower()])
	return true


## Rebuilds the band's edges from the steps taken, and the berserk trait
## (which is what the battle reads) from the fury.
static func refresh(band: Band) -> void:
	var gifts := {}
	for way in band.paths:
		var r := int(band.paths[way])
		if r <= 0:
			continue
		var g: Dictionary = def(way).ranks[mini(r, MAX_RANK) - 1].gifts
		for k in g:
			gifts[k] = g[k]
	band.gifts = gifts
	var leader := band.leader
	if leader != null:
		var has := leader.traits.has("berserk")
		if int(gifts.get("fury", 0)) > 0 and not has:
			leader.traits.append("berserk")
		leader.fury = int(gifts.get("fury", 0))


## The path he has gone furthest down (ties to the earlier in the list),
## or -1 with none: what he is, as against what the saga calls him.
static func foremost(band: Band) -> int:
	var best := -1
	var best_rank := 0
	for way in Id.values():
		if rank(band, way) > best_rank:
			best_rank = rank(band, way)
			best = way
	return best


## What he is by the steps he has taken: "sea-wolf and law-learned", or "".
static func standing(band: Band) -> String:
	var parts := PackedStringArray()
	for way in Id.values():
		var r := rank(band, way)
		if r > 0:
			parts.append(str(def(way).ranks[r - 1].name).to_lower())
	return " and ".join(parts) if parts.size() <= 2 else ", ".join(parts)


# --- Deeds and the name ------------------------------------------------------------

## Counts a deed toward a way (a raid won for the Viking, a case won for
## the Law-wise): `points` onto Band.deeds.
static func add_deed(band: Band, way: int, points: int) -> void:
	if points <= 0:
		return
	band.deeds[way] = int(band.deeds.get(way, 0)) + points


## The way the band's deeds speak loudest for, or -1 with too few.
static func renowned_for(band: Band) -> int:
	var best := -1
	var best_points := EPITHET_DEEDS - 1
	for way in Id.values():
		var p := int(band.deeds.get(way, 0))
		if p > best_points:
			best_points = p
			best = way
	return best


## What the saga calls the leader: "the Law-Wise", or "" before he has
## earned a name.
static func epithet(band: Band) -> String:
	var way := renowned_for(band)
	return "" if way < 0 else str(def(way).epithet)


## "Egil the Skald", or plain "Egil".
static func title(band: Band) -> String:
	var who: String = band.leader.display_name if band.leader != null else "nobody"
	var e := epithet(band)
	return who if e == "" else "%s %s" % [who, e]
