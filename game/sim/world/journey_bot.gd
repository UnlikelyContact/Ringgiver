class_name JourneyBot
extends RefCounted
## A stand-in player for each way of life: plays a Journey the plain way a
## man of that way would (the raider raids, the trader trades, the law-wise
## man gives counsel, the berserk calls men to the island, the skald
## speaks his verses, the king's man does his lord's work). For tests and
## balance batches; fights are told quickly (Journey.quick).


## Plays until the year turns (or the saga ends). Returns the steps taken.
static func play_year(j: Journey) -> int:
	j.quick = true
	var year := j.c.cal.year
	var steps := 0
	while not j.c.over and j.c.cal.year == year and steps < 600:
		steps += 1
		if not j.decisions.is_empty():
			j.answer(_answer(j, j.current()))
			continue
		if not j.can_act():
			break
		_act(j)
	return steps


static func _answer(j: Journey, d: Dictionary) -> String:
	var band := j.c.band
	match d.kind:
		"fight":
			var offer: FightOffer = d.offer
			if offer.they_know_first:
				return str(FightOffer.Choice.TAKE_THE_FIELD)
			return str(Sandbox.choose_fight(offer))
		"spine":
			for o in d.options:
				if o.id == "serve" and band.way == Way.Id.KINGS_MAN:
					return "serve"
			return "ignore"
		"demand":
			return "pay" if band.silver >= int(d.ask) * 2 else "thing"
		"merchant":
			if band.way == Way.Id.TRADER and d.options[0].get("enabled", true):
				return "buy"
			return "rob" if band.way == Way.Id.VIKING and band.fighters(j.c.rules).size() >= 8 else "pass"
	return str(d.options[0].id)


static func _act(j: Journey) -> void:
	var c := j.c
	var band := c.band
	var wr := c.world_rules
	var home_days := j.days_to(band.home)
	# Time to go home.
	if j.days_left() <= maxi(0, home_days) + wr.home_margin_days + 6:
		j.act("winter" if band.location == band.home else "home")
		return
	var ids := {}
	for a in j.actions():
		if a.get("enabled", true):
			ids[a.id] = a
	# A ship too battered to trust is mended first.
	if ids.has("mend") and band.ship.damage >= wr.ship_unsailable_damage - 1:
		j.act("mend")
		return
	# A farmer to stand up for, for a man who can fight.
	if ids.has("champion") and band.leader.stat(CombatTypes.Stat.MIGHT) + band.leader.stat(CombatTypes.Stat.SKILL) >= 9:
		j.act("champion")
		return
	# A feud to plead when at a Thing; work in hand to finish.
	for id in ids:
		if str(id).begins_with("case:"):
			j.act(id)
			return
	if not j.contract.is_empty() and j.days_to(str(j.contract.to_place)) > 0:
		j.sail(str(j.contract.to_place))
		return
	match band.way:
		Way.Id.VIKING:
			# Captives and loot are silver only at a market.
			if ids.has("captives"):
				j.act("captives")
				return
			if j.here().has_market:
				for row in j.market():
					if int(row.have) > 0:
						j.sell(int(row.good), int(row.have))
			if band.captives >= 4:
				var slavers := _nearest(j, func(q: Place) -> bool: return wr.slave_markets.has(q.id))
				if slavers != "":
					j.sail(slavers)
					return
			if ids.has("raid") and _raidable(j, j.here()):
				j.act("raid")
				return
			var target := _nearest(j, func(p: Place) -> bool: return _raidable(j, p))
			if target != "":
				j.sail(target)
				return
		Way.Id.TRADER:
			var p := j.here()
			if p.has_market:
				for row in j.market():
					if int(row.have) > 0:
						j.sell(int(row.good), int(row.have))
				# Buy what pays best elsewhere, a unit at a time, while the price
				# here stays well under what it fetches there.
				var trade := Market.best_trade(c.world, band, p.id, wr)
				if not trade.is_empty() and int(trade.profit_per_unit) > 0:
					var dest := c.world.place(str(trade.to))
					var got := 0
					while Market.cargo_room(wr, band) > 0 and band.silver > 20 \
							and Market.buy_price(wr, p, band, trade.good) * 4 < Market.sell_price(wr, dest, band, trade.good) * 3:
						if j.buy(int(trade.good), 1) <= 0:
							break
						got += 1
					if got > 0:
						j.sail(str(trade.to))
						return
			var market := _nearest(j, func(q: Place) -> bool: return q.has_market)
			if market != "":
				j.sail(market)
				return
		Way.Id.LAWMAN:
			if ids.has("counsel"):
				j.act("counsel")
				return
			var where := _nearest(j, func(q: Place) -> bool: return Callings.can_counsel(wr, c.world, band, q))
			if where != "":
				j.sail(where)
				return
		Way.Id.BERSERK:
			# While men still speak well enough of him; after that he raids.
			if band.honor > wr.holmgang_outlaw_honor + 2 * wr.holmgang_honor:
				if ids.has("holmgang"):
					j.act("holmgang")
					return
				var who := _nearest(j, func(q: Place) -> bool: return Callings.can_challenge(wr, c.world, band, q))
				if who != "":
					j.sail(who)
					return
			else:
				if ids.has("raid") and _raidable(j, j.here()):
					j.act("raid")
					return
				var prey := _nearest(j, func(q: Place) -> bool: return _raidable(j, q))
				if prey != "":
					j.sail(prey)
					return
		Way.Id.SKALD:
			if ids.has("verse"):
				j.act("verse")
				return
			var hall := _nearest(j, func(q: Place) -> bool: return Callings.can_verse(c.world, band, q))
			if hall != "":
				j.sail(hall)
				return
		Way.Id.KINGS_MAN:
			if ids.has("work:0"):
				j.act("work:0")
				return
			var lord := _nearest(j, func(q: Place) -> bool:
				return (q.kind == WorldTypes.PlaceKind.HALL or q.kind == WorldTypes.PlaceKind.TOWN) and not j._offers.has(q.id))
			if lord != "":
				j.sail(lord)
				return
	j.act("listen")


## A place worth raiding with the men in hand.
static func _raidable(j: Journey, p: Place) -> bool:
	var c := j.c
	if not Journey.RAID_KINDS.has(p.kind) or p.id == c.band.home or p.wealth < c.world_rules.raid_min_wealth:
		return false
	if int(c.band.raided.get(p.id, -1)) == c.cal.year:
		return false
	var a := Raiding.assess(c.world_rules, c.world, p, c.band)
	return a.defenders <= c.band.fighters(c.rules).size() * c.world_rules.raid_odds_max


## The nearest known, open place other than this one that `want` accepts,
## near enough to reach and come home from; "" if none.
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
		if d < 0 or d >= best_days:
			continue
		var back := Voyage.plan(c.world, id, c.band.home, c.band.known_places)
		if back.is_empty() and id != c.band.home:
			continue
		if d + Voyage.route_days(c.world, back) + c.world_rules.home_margin_days > j.days_left():
			continue
		best_days = d
		best = id
	return best
