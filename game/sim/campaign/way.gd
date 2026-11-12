class_name Way
extends RefCounted
## The ways a man can live in the saga world (concept.md, "Ways of life"):
## the raider, the trader, the law-wise man, the berserk, the skald, the
## king's man. A way is where you start and what you are best at, never a
## wall: every deed is open to every man, your way gives you an edge in
## its own (`gifts`, read by the world modules through Band.gift), and the
## saga names you by what you have done (`deeds`, `epithet`), not by what
## you chose.

enum Id { VIKING, TRADER, LAWMAN, BERSERK, SKALD, KINGS_MAN }

const S := CombatTypes.Stat

## name: what the saga calls the way; model: the saga man it is cut from;
## blurb: what the player reads; origin, followers, silver, ship: the
## start; stats: what is added to the leader's own; gifts: the edges
## (Band.gift); epithet: what the saga calls a man with the deeds for it.
const DEFS := [
	{"key": "viking", "name": "Viking", "norse": "víkingr", "model": "the sea-kings",
		"blurb": "A ship, a crew, and other men's silver. Your raids take more, and men follow plunder.",
		"origin": CampaignTypes.Origin.YOUNGER_SON, "followers": 9, "silver": 20, "ship": WorldTypes.ShipKind.KARVE,
		"stats": {S.MIGHT: 1}, "gifts": {"raid_plunder": 1.5}, "epithet": "the Viking",
		"gift_text": "Raids yield half as much silver again."},
	{"key": "trader", "name": "Trader", "norse": "farmaðr", "model": "Ohthere of Hålogaland",
		"blurb": "A knarr with a deep hold and a head for prices. You deal at the true price where others pay the middlemen, and you know the market towns.",
		"origin": CampaignTypes.Origin.FISHERMAN, "followers": 5, "silver": 120, "ship": WorldTypes.ShipKind.KNARR,
		"stats": {S.WITS: 1}, "gifts": {"trade_edge": 0.1, "knows_markets": true}, "epithet": "the Far-Travelled",
		"gift_text": "No middleman's tenth on what you buy or sell; the coast from Hålogaland to Hedeby is known to you."},
	{"key": "lawman", "name": "Law-wise man", "norse": "lögmaðr", "model": "Njáll of Bergthorshvoll",
		"blurb": "Few men and no love of fighting, but no one pleads a case better, and you see trouble before it comes.",
		"origin": CampaignTypes.Origin.YOUNGER_SON, "followers": 4, "silver": 60, "ship": WorldTypes.ShipKind.KARVE,
		"stats": {S.WITS: 3, S.MIGHT: -1}, "gifts": {"law": 2, "foresight": true, "counsel_fee": 2.0}, "epithet": "the Law-Wise",
		"gift_text": "Two better at every pleading and counsel, paid double for it; never caught on the march, and your scouts count true."},
	{"key": "berserk", "name": "Berserk", "norse": "berserkr", "model": "Kveldulf's blood",
		"blurb": "The fury is on you in a fight and men fear to meet you on the island. Few follow you, and no lord trusts you.",
		"origin": CampaignTypes.Origin.OUTLAW, "followers": 2, "silver": 10, "ship": WorldTypes.ShipKind.KARVE,
		"stats": {S.MIGHT: 2, S.NERVE: 2, S.WITS: -1}, "gifts": {"fury": true, "dread": 0.35}, "epithet": "the Berserk",
		"gift_text": "The fury: stronger while your breath lasts, and those beside you lose heart. One man in three pays rather than fight you."},
	{"key": "skald", "name": "Skald", "norse": "skáld", "model": "Egil Skallagrimsson",
		"blurb": "Kings pay for praise that will outlive them. Your verses open halls, and your deeds are remembered.",
		"origin": CampaignTypes.Origin.YOUNGER_SON, "followers": 3, "silver": 30, "ship": WorldTypes.ShipKind.KARVE,
		"stats": {S.WITS: 2, S.SKILL: 1}, "gifts": {"verse": 3, "verse_gift": 2.0}, "epithet": "the Skald",
		"gift_text": "Three better at every verse, and lords give you double for it. A lord who has heard you wants something new."},
	{"key": "kings_man", "name": "King's man", "norse": "hirðmaðr", "model": "Thorolf Kveldulfsson",
		"blurb": "Sworn to your lord's hall. His work pays you better and raises you faster, while his favour lasts.",
		"origin": CampaignTypes.Origin.YOUNGER_SON, "followers": 6, "silver": 40, "ship": WorldTypes.ShipKind.KARVE,
		"stats": {S.SKILL: 1}, "gifts": {"contract_pay": 1.25, "rank_progress": 2, "lords_favour": 20}, "epithet": "the King's Man",
		"gift_text": "A lord's work pays a quarter more and counts double toward rank; your own lord favours you."},
]

## Deeds needed before the saga gives a man the name.
const EPITHET_DEEDS := 6


static func def(way: int) -> Dictionary:
	return DEFS[clampi(way, 0, DEFS.size() - 1)]


static func name_of(way: int) -> String:
	return def(way).name


## Marks the band with a way: its gifts, and the leader's own stats.
static func apply(band: Band, way: int) -> void:
	var d := def(way)
	band.way = way
	band.gifts = (d.gifts as Dictionary).duplicate()
	var leader := band.leader
	if leader != null:
		for s in d.stats:
			leader.set_stat(s, clampi(leader.stat(s) + int(d.stats[s]), 1, 10))
			leader.potential[s] = maxi(leader.potential[s], leader.stat(s))
		if band.gift("fury", false) and not leader.traits.has("berserk"):
			leader.traits.append("berserk")  # the trait is what the battle reads
	band.silver = int(d.silver)


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
