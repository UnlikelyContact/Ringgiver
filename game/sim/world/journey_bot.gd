class_name JourneyBot
extends RefCounted
## A stand-in player with a bent: he plays a Journey the plain way a man
## leaning toward one way of life would (Way.Id), spending his points down
## that path, getting himself a hull when he can pay for one, and making
## his living by whatever is to hand until his own way pays. For tests and
## balance batches; fights are told quickly (Journey.quick).


## Plays until the year turns (or the saga ends). Returns the steps taken.
## With `stop_at_winter` he stops when the band goes into its winter
## quarters, the winter's choices still to make (tools).
static func play_year(j: Journey, bent: int, stop_at_winter := false) -> int:
	j.quick = true
	j.stepped_winter = true
	var year := j.c.cal.year
	var steps := 0
	while not j.c.over and j.c.cal.year == year and steps < 900:
		steps += 1
		if j.in_winter():
			if stop_at_winter:
				break
			winter(j, bent)
			continue
		if not j.decisions.is_empty():
			j.answer(_answer(j, j.current(), bent))
			continue
		if not j.can_act():
			break
		if j.roam.moving():
			j.travel()
			continue
		_spend(j, bent)
		_act(j, bent)
	return steps


## The winter in the hall, as a man of his bent keeps it (WinterHall):
## the store as the sensible defaults have it; rings for every great deed
## and silver for the cold-hearted from a raider, a berserk, a skald or a
## king's man, a few ounces to every man from the law-wise, the defaults
## from the trader; the fighting ways drill the boar's snout and swear
## "Swine!", the king's man and the law-wise the hedgehog; the law-wise
## names a war-leader and keeps out of the wall himself; a raider vows at
## Yule. Then the points are spent and the spring begins. Always ends the
## winter: it never waits on anything.
static func winter(j: Journey, bent: int) -> void:
	var h := j.winter_hall
	var c := j.c
	var band := c.band
	var men := band.living_men()
	match bent:
		Way.Id.VIKING, Way.Id.BERSERK, Way.Id.SKALD, Way.Id.KINGS_MAN:
			for m in men:
				if WinterHall.great_deed(c.rules, m):
					while int(h.gifts.get(m.id, 0)) < 2 and h.silver_after(j) >= 30:
						j.winter_choose("gift+:%d" % m.id)
			for m in men:
				if m.loyalty < 40 and int(h.gifts.get(m.id, 0)) == 0 and h.silver_after(j) >= 30:
					j.winter_choose("gift+:%d" % m.id)
		Way.Id.LAWMAN:
			for m in men:
				if int(h.gifts.get(m.id, 0)) == 0 and h.silver_after(j) >= 30:
					j.winter_choose("gift+:%d" % m.id)
	if bent == Way.Id.VIKING or bent == Way.Id.BERSERK:
		j.winter_choose("shape:boar's snout")
		if band.custom_shouts.is_empty():
			j.winter_choose("shout:boar's snout")
	elif bent == Way.Id.KINGS_MAN or bent == Way.Id.LAWMAN:
		j.winter_choose("shape:refused flanks")
		if band.custom_shouts.is_empty():
			j.winter_choose("shout:refused flanks")
	if bent == Way.Id.LAWMAN and not men.is_empty():
		var best: Man = null
		for m in men:
			if best == null or m.tier > best.tier or (m.tier == best.tier and m.stat(CombatTypes.Stat.SKILL) + m.stat(CombatTypes.Stat.NERVE) > best.stat(CombatTypes.Stat.SKILL) + best.stat(CombatTypes.Stat.NERVE)):
				best = m
		if h.war_leader != best.id:
			j.winter_choose("war:%d" % best.id)
		if not h.keeps_back:
			j.winter_choose("keep")
	if bent == Way.Id.VIKING:
		for i in h.talk.size():
			if str(h.talk[i].kind) == "vow":
				j.winter_choose("talk:%d:vow:0" % i)
	var guard := 0
	while j.in_winter() and not h.resolved and guard < 10:
		guard += 1
		j.winter_choose("next")
	if j.in_winter():
		_spend(j, bent)
	j.winter_end()


## Points go down his own path first, then wherever they will.
static func _spend(j: Journey, bent: int) -> void:
	var band := j.c.band
	while Way.can_invest(band, bent):
		j.invest(bent)
	if Way.rank(band, bent) >= Way.MAX_RANK:
		for way in Way.Id.values():
			while way != Way.Id.BERSERK and Way.can_invest(band, way):
				j.invest(way)


static func _answer(j: Journey, d: Dictionary, bent: int) -> String:
	var band := j.c.band
	match d.kind:
		"fight":
			var offer: FightOffer = d.offer
			if offer.they_know_first:
				return str(FightOffer.Choice.TAKE_THE_FIELD)
			# The berserk takes the darkest road to his vengeance: the burning.
			if bent == Way.Id.BERSERK and offer.allows(FightOffer.Choice.BURN) and offer.house == band.vengeance:
				return str(FightOffer.Choice.BURN)
			return str(Sandbox.choose_fight(offer))
		"spine":
			for o in d.options:
				if o.id == "serve" and bent == Way.Id.KINGS_MAN:
					return "serve"
			return "ignore"
		"demand":
			return "pay" if band.silver >= int(d.ask) * 2 else "thing"
		"merchant":
			if bent == Way.Id.TRADER and d.options[0].get("enabled", true):
				return "buy"
			return "rob" if bent == Way.Id.VIKING and band.fighters(j.c.rules).size() >= 8 else "pass"
		"house":
			return _answer_house(j, d, bent)
		"world":
			return _answer_world(j, d, bent)
	return str(d.options[0].id)


## The world's own life met on the way (WorldLife): a wreck is stripped; the
## king's due is paid while silver allows; farmers are stood with, and a
## fight come upon is joined, when the band is a match for the other side
## (the raider joins the raiders against a merchant; everyone else helps
## the merchant or the king's men); a stolen ship is taken back.
static func _answer_world(j: Journey, d: Dictionary, bent: int) -> String:
	var men := j.c.band.fighters(j.c.rules).size()
	var p: Roam.Party = d.get("party", null)
	var odds := j.c.world_rules.raid_odds_max
	match str(d.what):
		"wreck":
			return "take"
		"toll":
			return "pay" if j.c.band.silver >= int(d.toll) * 3 or bent == Way.Id.TRADER and j.c.band.silver >= int(d.toll) else "refuse"
		"defend":
			return "defend" if p != null and p.men <= men * odds and men >= 3 else "away"
		"thieves":
			return "fight" if p != null and p.men <= men * odds else "away"
		"fray":
			var other: Roam.Party = d.get("other", null)
			if p == null or other == null:
				return "away"
			if men < 3:
				return "away"
			var pick := ""
			for side in [["a", p, other], ["b", other, p]]:
				var ally: Roam.Party = side[1]
				var foe: Roam.Party = side[2]
				var robber := ally.kind == "raiders" or ally.kind == "outlaws"
				if robber != (bent == Way.Id.VIKING):
					continue
				if maxi(2, foe.men - ally.men / 2) <= men * odds:
					pick = str(side[0])
			return pick if pick != "" else "away"
	return str(d.options[0].id)


## The houses' asks, as a man of his bent would answer them: the fighting
## ways stand with a house when they have the men, the law-wise man speaks
## for it at the Thing, the skald and the trader carry an offer of peace; a
## marriage or a fosterling is taken; wergild is taken, unless a fighting
## man with a band behind him would rather have blood.
static func _answer_house(j: Journey, d: Dictionary, bent: int) -> String:
	var men := j.c.band.fighters(j.c.rules).size()
	var fighting := bent == Way.Id.VIKING or bent == Way.Id.BERSERK or bent == Way.Id.KINGS_MAN
	match str(d.ask):
		"help":
			if fighting and men >= 5:
				return "stand"
			if bent == Way.Id.LAWMAN:
				return "speak"
			if bent == Way.Id.SKALD or bent == Way.Id.TRADER:
				return "carry"
			return "refuse"
		"marry", "foster":
			return "accept"
		"compensation":
			return "blood" if fighting and men >= 6 else "take"
	return str(d.options[0].id)


static func _act(j: Journey, bent: int) -> void:
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	var here := j.here()
	var ids := {}
	for a in j.actions():
		if a.get("enabled", true):
			ids[a.id] = a
	# Time to find a roof for the winter.
	if j.days_left() <= 14:
		if ids.has("winter"):
			j.act("winter")
			return
		var roof := _nearest(j, func(q: Place) -> bool: return Journey.SETTLED.has(q.kind))
		if roof != "" and j.sail(roof):
			return
		j.act("camp" if ids.has("camp") else "listen")
		return
	if here == null:
		# In the wilds with nowhere in mind: back to the nearest place.
		var back := _nearest(j, func(_q: Place) -> bool: return true)
		if back == "" or not j.go_to_place(back):
			j.act("camp")
		return
	# A ship too battered to trust is mended first.
	if ids.has("mend") and band.ship.damage >= wr.ship_unsailable_damage - 1:
		j.act("mend")
		return
	# A hull, when he has none he can use and can pay for one that will
	# carry his men; a knarr for a trader who can afford the hold.
	var men := band.fighters().size()
	for kind in Journey.HULLS:
		var id := "hull:%d" % kind
		if not ids.has(id):
			continue
		var carries: bool = int(wr.ship_crew[kind]) >= men and int(wr.ship_min_crew[kind]) <= men
		var want := carries and j.sail_speed() <= 0.0 and band.silver >= j.hull_cost(kind) + 8
		if bent == Way.Id.TRADER and kind == WorldTypes.ShipKind.KNARR and carries and band.silver >= j.hull_cost(kind) + 40:
			want = true
		if want:
			j.act(id)
			return
	# A farmer to stand up for, for a man who can fight.
	var fighter: bool = band.leader.stat(CombatTypes.Stat.MIGHT) + band.leader.stat(CombatTypes.Stat.SKILL) >= 9
	if ids.has("champion") and fighter:
		j.act("champion")
		return
	# A feud to plead when at a Thing, or a house he promised to speak for;
	# work in hand to finish.
	for id in ids:
		if str(id).begins_with("case:") or str(id).begins_with("speak:"):
			j.act(id)
			return
	if _houses(j, bent, ids):
		return
	if not j.contract.is_empty() and j.days_to(str(j.contract.to_place)) > 0:
		if j.sail(str(j.contract.to_place)) or not j.decisions.is_empty():
			return
	if _hire(j, bent, ids):
		return
	if _captives(j, bent, ids):
		return
	if bent == Way.Id.TRADER and _trade(j, ids):
		return
	if _livelihood(j, bent, ids):
		return
	match bent:
		Way.Id.VIKING:
			# Captives and loot are silver only at a market.
			if ids.has("captives"):
				j.act("captives")
				return
			if here.has_market:
				for row in j.market():
					if int(row.have) > 0:
						j.sell(int(row.good), int(row.have))
			if band.captives >= 4:
				var slavers := _nearest(j, func(q: Place) -> bool: return wr.slave_markets.has(q.id))
				if slavers != "" and _go(j, slavers):
					return
			if ids.has("raid") and _raidable(j, here):
				j.act("raid")
				return
			var target := _nearest(j, func(q: Place) -> bool: return _raidable(j, q))
			if target != "" and _go(j, target):
				return
		Way.Id.TRADER:
			# Nothing to carry from here: on to the nearest place that deals.
			var stall := _nearest(j, func(q: Place) -> bool: return (q.has_market or not q.trade.is_empty()) \
					and int(j.life.get("bot_traded:" + q.id, -1)) != c.cal.year)
			if stall != "" and _go(j, stall):
				return
		Way.Id.LAWMAN:
			if ids.has("counsel"):
				j.act("counsel")
				return
			var where := _nearest(j, func(q: Place) -> bool: return Callings.can_counsel(wr, c.world, band, q))
			if where != "" and _go(j, where):
				return
		Way.Id.BERSERK:
			# A merchant pays well for a guard nobody cares to cross.
			var esc2: Dictionary = j.life.get("escort", {})
			if not esc2.is_empty() and _go(j, str(esc2.to)):
				return
			if ids.has("escort") and band.fighters(c.rules).size() >= 2:
				j.act("escort")
				return
			# While men still speak well enough of him.
			if band.honor > wr.holmgang_outlaw_honor + 2 * wr.holmgang_honor:
				if ids.has("holmgang"):
					j.act("holmgang")
					return
				var who := _nearest(j, func(q: Place) -> bool: return Callings.can_challenge(wr, c.world, band, q))
				if who != "" and _go(j, who):
					return
		Way.Id.SKALD:
			if ids.has("verse"):
				j.act("verse")
				return
			var hall := _nearest(j, func(q: Place) -> bool: return Callings.can_verse(c.world, band, q))
			if hall != "" and _go(j, hall):
				return
		Way.Id.KINGS_MAN:
			if ids.has("work:0"):
				j.act("work:0")
				return
			# A merchant's guard is service too, and pays.
			var esc: Dictionary = j.life.get("escort", {})
			if not esc.is_empty() and _go(j, str(esc.to)):
				return
			if ids.has("escort") and band.fighters(c.rules).size() >= 4:
				j.act("escort")
				return
			var lord := _nearest(j, func(q: Place) -> bool:
				return (q.kind == WorldTypes.PlaceKind.HALL or q.kind == WorldTypes.PlaceKind.TOWN) and not j._offers.has(q.id))
			if lord != "" and _go(j, lord):
				return
	# Whatever is to hand: counsel, a lord's work, a verse.
	for id in ["counsel", "work:0", "verse"]:
		if ids.has(id):
			j.act(id)
			return
	var living := _nearest(j, func(q: Place) -> bool:
		return Callings.can_counsel(wr, c.world, band, q) or (fighter and Callings.can_champion(wr, c.world, band, q)) \
				or ((q.kind == WorldTypes.PlaceKind.HALL or q.kind == WorldTypes.PlaceKind.TOWN) and not j._offers.has(q.id)))
	if living != "" and _go(j, living):
		return
	# Nothing to hand here: work his way somewhere else (a place at another
	# man's oars, a day's labour), or pay for passage to the nearest hall.
	for id in ["crew", "labour", "fish"]:
		if ids.has(id):
			j.act(id)
			return
	var cheapest := ""
	var cost := 1 << 20
	for o in j.passages():
		if band.ship == null and ids.has("passage:" + str(o.id)) and int(o.cost) < cost and int(o.cost) * 3 <= band.silver:
			cost = int(o.cost)
			cheapest = "passage:" + str(o.id)
	if cheapest != "" and int(j.life.get("bot_passage", -1)) != c.cal.day:
		j.life["bot_passage"] = c.cal.day
		j.act(cheapest)
		return
	j.act("listen")


## What he does among the houses: rest the hurt and take men his friends
## lend, give a gift where it is worth it, pay wergild he can well afford,
## go to the Thing he promised, and seek the reckoning with the house he
## is at feud with once his friends make the odds good. True when he did
## something (the turn is spent).
static func _houses(j: Journey, bent: int, ids: Dictionary) -> bool:
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	var fs := c.world.families
	if fs == null:
		return false
	for id in ["heal", "men"]:
		if ids.has(id):
			j.act(id)
			return true
	var here := j.here()
	if ids.has("reckoning"):
		var t := fs.reckoning_terms(wr, band, here.family)
		if int(t.men) <= band.fighters(c.rules).size() * wr.raid_odds_max:
			j.act("reckoning")
			return true
	if ids.has("wergild") and here.family != band.vengeance \
			and band.silver >= 2 * Feud.offer_settlement(wr, band, here.family):
		j.act("wergild")
		return true
	var giver := bent == Way.Id.LAWMAN or bent == Way.Id.KINGS_MAN or bent == Way.Id.SKALD or bent == Way.Id.TRADER
	if giver and ids.has("gift") and band.silver >= 60 and Families.standing(band, here.family) < wr.standing_friend \
			and Families.gift_worth(wr, band, here.family, c.cal.year) >= wr.standing_gift:
		j.act("gift")
		return true
	# The long arc of the vengeance: friends among the burners' enemies (and
	# their allies' enemies), won with gifts, until the band's side is a
	# match for theirs.
	if band.vengeance != "" and fs.house(band.vengeance) != null and band.silver >= wr.gift_ounces + 20:
		var vb := fs.vengeance_backing(wr, band, band.vengeance, band.fighters(c.rules).size())
		if not bool(vb.ready):
			var foes_of := fs.enemies_of(band.vengeance)
			for a in fs.allies_of(band.vengeance):
				foes_of.append_array(fs.enemies_of(a))
			var want := ""
			for e in foes_of:
				if e == band.vengeance or Families.is_friend(wr, band, e) or Families.is_foe(wr, band, e) or fs.abroad(e):
					continue
				if Families.gift_worth(wr, band, e, c.cal.year) < wr.standing_gift:
					continue
				var seat := fs.house(e).seat
				if not band.knows(seat) or j.days_to(seat) < 0 or j.days_to(seat) + 10 > j.days_left():
					continue
				want = e
				break
			if want != "":
				if here.family == want and ids.has("gift"):
					j.act("gift")
					return true
				if _go(j, fs.house(want).seat):
					return true
	if not band.pledges.is_empty():
		var thing := _nearest(j, func(q: Place) -> bool: return q.kind == WorldTypes.PlaceKind.THING_SITE)
		if thing != "" and _go(j, thing):
			return true
	var tried: Dictionary = band.favours.get(band.vengeance, {})
	if band.vengeance != "" and fs.house(band.vengeance) != null and int(tried.get("reckoning", -1)) != c.cal.year:
		var t2 := fs.reckoning_terms(wr, band, band.vengeance)
		var seat := fs.house(band.vengeance).seat
		if int(t2.men) <= band.fighters(c.rules).size() * wr.raid_odds_max and seat != band.location \
				and j.days_to(seat) >= 0 and j.days_to(seat) + 10 <= j.days_left() and _go(j, seat):
			return true
	return false


## Sets off for a place. True when he is on his way (or there, or stopped
## by something to answer): the turn is spent.
static func _go(j: Journey, to: String) -> bool:
	if not j.go_to_place(to):
		return false
	j.travel()
	return true


## A place worth raiding with the men in hand.
static func _raidable(j: Journey, p: Place) -> bool:
	var c := j.c
	if not Journey.RAID_KINDS.has(p.kind) or p.id == c.band.home or p.wealth < c.world_rules.raid_min_wealth:
		return false
	if int(c.band.raided.get(p.id, -1)) == c.cal.year:
		return false
	# He does not raid his own friends and kin.
	if Families.is_friend(c.world_rules, c.band, p.family):
		return false
	var a := Raiding.assess(c.world_rules, c.world, p, c.band)
	return a.defenders <= c.band.fighters(c.rules).size() * c.world_rules.raid_odds_max


## The nearest known, open place other than this one that `want` accepts
## and that can be reached with days to spare; "" if none.
static func _nearest(j: Journey, want: Callable) -> String:
	var c := j.c
	var best := ""
	var best_days := 999
	var ids: Array = c.band.known_places.keys()
	ids.sort()
	for id in ids:
		var p := c.world.place(id)
		if p == null or id == c.band.location or not p.is_open(c.world.year) or not want.call(p):
			continue
		var d := j.days_to(id)
		if d < 0 or d >= best_days or d + 10 > j.days_left():
			continue
		best_days = d
		best = id
	return best



# --- The summer's new ways (TradeRoad, Hiring, WorldLife) ----------------------------

## The trader's road: sell what fetches more here than it cost, carry a
## partner's goods for a share, guard a merchant, and buy what the best
## known place pays well for, as much as he can carry, then go there.
static func _trade(j: Journey, ids: Dictionary) -> bool:
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	var here := j.here()
	for id in ids:
		if str(id).begins_with("felag_sell:"):
			j.act(id)
			return true
	if here.has_market or not here.trade.is_empty():
		j.life["bot_traded:" + here.id] = c.cal.year
		for row in j.market():
			if int(row.have) > 0 and bool(row.get("can_sell", true)) and int(row.sell) > 0:
				var basis: Array = band.bought.get(int(row.good), [0, 0])
				var cost := float(basis[1]) / maxf(1.0, float(basis[0]))
				if float(row.sell) >= cost or int(basis[0]) <= 0:
					j.sell(int(row.good), int(row.have))
	if ids.has("felag"):
		j.act("felag")
		return true
	if ids.has("escort") and band.fighters(c.rules).size() >= 3:
		j.act("escort")
		return true
	var esc: Dictionary = j.life.get("escort", {})
	if not esc.is_empty() and _go(j, str(esc.to)):
		return true
	if not band.felag.is_empty():
		var f: Dictionary = band.felag[0]
		if j.days_to(str(f.to)) > 0 and _go(j, str(f.to)):
			return true
	# The best carry from here: margin a day on the loads he can carry.
	var room := Market.cargo_room(wr, band)
	if room > 0 and (here.has_market or not here.trade.is_empty()):
		var best := {}
		var best_score := 0.0
		for g in WorldTypes.Good.values():
			if not Market.sells_here(here, g) or int(here.stock.get(g, 0)) <= 0 or (g == WorldTypes.Good.GRAIN and not here.has_market):
				continue
			var cost := Market.buy_price(wr, here, band, g)
			var n := mini(room, band.silver / maxi(1, cost))
			if n <= 0:
				continue
			for id in band.known_places:
				var q := c.world.place(str(id))
				if q == null or q.id == here.id or not q.is_open(c.world.year) or not Market.buys_here(q, g):
					continue
				var days := j.days_to(q.id)
				if days < 0 or days + 10 > j.days_left():
					continue
				var margin := Market.sell_price(wr, q, band, g) - cost
				if margin * 4 < cost:
					continue
				var score := float(margin * n) / float(days + 3)
				if score > best_score:
					best_score = score
					best = {"good": g, "to": q.id, "n": n}
		if not best.is_empty() and best_score >= 0.3:
			if j.buy(int(best.good), int(best.n)) > 0 and _go(j, str(best.to)):
				return true
	return false


## A poor man's living, for a band with little silver and no ship it can
## use: a partner's goods, the fields, the fishing, the herds, a place at
## another man's oars. Any bent does it while he must.
static func _livelihood(j: Journey, bent: int, ids: Dictionary) -> bool:
	var band := j.c.band
	var poor := band.silver < 30 and j.sail_speed() <= 0.0
	if not poor:
		return false
	# A partner's goods are delivered before anything else.
	for id in ids:
		if str(id).begins_with("felag_sell:"):
			j.act(id)
			return true
	if not band.felag.is_empty():
		var f: Dictionary = band.felag[0]
		if j.days_to(str(f.to)) > 0 and _go(j, str(f.to)):
			return true
	for id in ["felag", "fish", "labour", "herd"]:
		if ids.has(id):
			j.act(id)
			return true
	if ids.has("crew") and bent != Way.Id.LAWMAN:
		j.act("crew")
		return true
	return false


## Men for hire: the fighting ways take on men while they can pay and their
## hull will carry them, the trader a man or two for the loads, the others
## enough to stand a fight. Cheap men first; never past the hull.
static func _hire(j: Journey, bent: int, ids: Dictionary) -> bool:
	var band := j.c.band
	var wr := j.c.world_rules
	var men := band.fighters().size()
	var want := 4
	match bent:
		Way.Id.VIKING:
			want = 12
		Way.Id.KINGS_MAN:
			want = 8
		Way.Id.BERSERK:
			want = 5
		Way.Id.TRADER:
			want = 4
	if band.ship != null:
		want = mini(want, band.ship.crew_capacity(wr))
	if men >= want:
		return false
	var offers := j.men_for_hire()
	for o in offers:
		var id := "hire:%d" % int(o.i)
		if not ids.has(id):
			continue
		# Enough in hand for the price and half a year of his wage.
		var reserve := 30 + int(o.wage) * 12
		if band.silver < int(o.price) + reserve:
			continue
		if str(o.kind) == "berserk" and bent != Way.Id.BERSERK and bent != Way.Id.VIKING:
			continue
		if str(o.kind) == "outlaw" and (bent == Way.Id.LAWMAN or bent == Way.Id.SKALD):
			continue
		j.act(id)
		return true
	return false


## Captives: a raider sells them at a slave market (his own block), anyone
## else lets them be ransomed where he can, the law-wise man and the
## skald set them free.
static func _captives(j: Journey, bent: int, ids: Dictionary) -> bool:
	if j.c.band.captives <= 0 or bent == Way.Id.VIKING:
		return false
	if (bent == Way.Id.LAWMAN or bent == Way.Id.SKALD) and ids.has("free"):
		j.act("free")
		return true
	if ids.has("ransom"):
		j.act("ransom")
		return true
	return false
