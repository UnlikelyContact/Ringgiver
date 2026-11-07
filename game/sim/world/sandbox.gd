class_name Sandbox
extends RefCounted
## The summer on the map, and letting the years pass. A SummerPlanner (an
## AI standing in for the player) chooses voyages, raids, trades, contracts
## and Thing cases; the campaign's `fight` resolves every battle request.
## See world-architecture.md, Module N.

const RAID_KINDS := [WorldTypes.PlaceKind.FARMSTEAD, WorldTypes.PlaceKind.HALL, WorldTypes.PlaceKind.TOWN]


## Builds the world, gives the band a ship and a home, and reveals the home
## region. Called once by the campaign.
static func setup(c: Campaign, wr: WorldRules, home_id: String) -> World:
	var world := World.build_norway(wr, c.cal.year)
	Faction.load_all(world)
	c.world = world
	c.world_rules = wr
	c.band.ship = Ship.make(WorldTypes.ShipKind.KARVE)
	c.band.home = home_id
	c.band.location = home_id
	var home := world.place(home_id)
	for p in world.places_in(home.region):
		c.band.known_places[p.id] = true
	for n in world.neighbours(home_id):
		c.band.known_places[n] = true
	c.band.land = wr.start_land
	return world


# --- The summer -------------------------------------------------------------

static func summer(c: Campaign, log: PackedStringArray) -> void:
	var wr := c.world_rules
	var world := c.world
	var band := c.band
	var cal := c.cal
	var rng := c.rng.fork("summer:%d" % cal.year)
	world.year = cal.year
	cal.day = 1
	var raids := 0
	var contracts_done := 0

	_spine(c, rng.fork("spine"), log)
	if c.over:
		return
	_feuds(c, rng.fork("feuds"), log)
	if c.over:
		return
	if _consider_emigration(c, rng.fork("emigrate"), log):
		return
	_sue_wrongs(c, rng.fork("sue"), log)
	if c.over:
		return
	if Outlawry.is_outlawed(band, cal):
		log.append("%d: %s sails as an outlaw" % [cal.year, band.leader.display_name])

	var idle_turns := 0
	while not c.over and cal.summer_left(wr.summer_days) > _days_home(c) + wr.home_margin_days:
		var acted := false
		# Contracts at halls and towns.
		var here := world.place(band.location)
		if here != null and not Outlawry.halls_closed(band, cal) \
				and (here.kind == WorldTypes.PlaceKind.HALL or here.kind == WorldTypes.PlaceKind.TOWN):
			var offers := Contracts.offers(rng.fork("offers:%d" % cal.day), wr, world, band, here.id)
			for o in offers:
				if o.kind == "escort" or o.kind == "hunt_outlaws" or o.kind == "debt":
					acted = _do_contract(c, rng.fork("contract:%d" % cal.day), o, log)
					if acted:
						contracts_done += 1
					break
		# A raid on the best soft target.
		if not acted and raids < wr.raids_per_summer_max:
			var target := _best_raid_target(c)
			if target != null:
				acted = _do_raid(c, rng.fork("raid:%d" % cal.day), target, log)
				if acted:
					raids += 1
		# Trade when a profitable route is known.
		if not acted and band.silver >= wr.trade_min_silver:
			var trade := Market.best_trade(world, band, band.location)
			if not trade.is_empty() and trade.get("profit_per_unit", 0) > 0:
				acted = _do_trade(c, rng.fork("trade:%d" % cal.day), trade, log)
		# Otherwise listen for rumors and wait.
		if not acted:
			idle_turns += 1
			var here2 := world.place(band.location)
			if here2 != null:
				Knowledge.hear_rumor(rng.fork("rumor:%d" % cal.day), wr, world, band, here2.id, log)
			cal.advance_days(wr.idle_days)
			if idle_turns >= wr.idle_turns_before_roving:
				idle_turns = 0
				_rove(c, rng.fork("rove:%d" % cal.day), log)
		if cal.summer_left(wr.summer_days) <= 0:
			break
	_go_home(c, rng.fork("home"), log)
	c.tally.raids = c.tally.get("raids", 0) + raids
	c.tally.contracts = c.tally.get("contracts", 0) + contracts_done


## Size of a fight the band did not pick: never more than its own strength plus a margin.
static func _forced(c: Campaign, n: int) -> int:
	var ours := mini(c.band.fighters().size(), Campaign.MAX_FIGHTERS)
	return clampi(n, 3, ours + c.world_rules.forced_fight_max_extra)


static func _days_home(c: Campaign) -> int:
	if c.band.location == c.band.home:
		return 0
	var route := Voyage.plan(c.world, c.band.location, c.band.home)
	var days := 0
	for i in range(1, route.size()):
		days += c.world.days_between(route[i - 1], route[i])
	return days if not route.is_empty() else 999


## Sails to `to`, fighting whatever the sea throws up. Returns true on arrival.
static func _sail(c: Campaign, rng: SimRng, to: String, log: PackedStringArray) -> bool:
	var guard := 0
	while guard < 6 and not c.over:
		guard += 1
		var vr := Voyage.sail(rng.fork("leg:%d" % guard), c.world_rules, c.world, c.band, c.cal, to, log)
		for ev in vr.encounters:
			if ev.has("battle_required"):
				var br: Dictionary = ev.battle_required
				var stat := c.world_rules.levy_stat if br.get("kind", "") == "levy" else c.world_rules.sea_fight_stat
				c.fight(br.get("kind", "sea fight"), br.tier, _forced(c, br.attackers), true, stat)
				if c.over:
					return false
		if vr.arrived:
			Knowledge.reveal(c.world, c.band, to, log)
			return true
		if vr.wrecked or not c.band.ship.can_sail(c.world_rules):
			return false
		if vr.encounters.is_empty():
			return false
	return c.band.location == to


static func _best_raid_target(c: Campaign) -> Place:
	var wr := c.world_rules
	var best: Place = null
	var best_score := 0.0
	var days_left := c.cal.summer_left(wr.summer_days) - wr.home_margin_days
	for p in Knowledge.known_targets(c.world, c.band):
		if not RAID_KINDS.has(p.kind) or p.wealth < wr.raid_min_wealth or p.id == c.band.home:
			continue
		if p.faction_id != "" and FactionAI.relation(c.world, p.faction_id, "band") >= wr.raid_avoid_relation \
				and p.region == c.world.place(c.band.home).region:
			continue  # not our own king's farms
		var route := Voyage.plan(c.world, c.band.location, p.id)
		if route.is_empty():
			continue
		var days := 0
		for i in range(1, route.size()):
			days += c.world.days_between(route[i - 1], route[i])
		if days * 2 > days_left:
			continue
		var a := Raiding.assess(wr, c.world, p, c.band)
		var fighters := c.band.fighters().size()
		if a.defenders > fighters * wr.raid_odds_max:
			continue
		var their_center: float = float(wr.defender_stat_by_kind[p.kind]) + p.defenses * wr.defender_stat_per_defense
		var softness: float = clampf(1.0 + (c._mean_stat(c.band.fighters()) - their_center) * wr.raid_softness_weight, 0.2, 2.0)
		var score: float = float(a.expected_plunder) / (float(a.defenders) + 1.0) / (1.0 + days * 0.1) * softness
		if score > best_score:
			best_score = score
			best = p
	return best


static func _do_raid(c: Campaign, rng: SimRng, target: Place, log: PackedStringArray) -> bool:
	if not _sail(c, rng.fork("sail"), target.id, log):
		return false
	var req := Raiding.raid(rng.fork("raid"), c.world_rules, c.world, c.band, target, log)
	var center := int(c.world_rules.defender_stat_by_kind[target.kind] + target.defenses * c.world_rules.defender_stat_per_defense)
	var result := c.fight("raid on %s" % target.display_name, req.tier, req.defenders, true, clampi(center, 1, 10))
	if c.over:
		return true
	var won := result.winner == 0
	var take := Raiding.after_raid(rng.fork("after"), c.world_rules, c.world, c.band, target, won, log)
	if won:
		c.band.silver += take.get("silver", 0)
		c.band.captives += take.get("captives", 0)
		for g in take.get("goods", {}):
			c.band.cargo[g] = c.band.cargo.get(g, 0) + take.goods[g]
		Loyalty.share_plunder(c.rules, c.band, take.get("silver", 0), c.rules.fair_leader_share, log)
		if target.faction_id != "":
			FactionAI.shift(c.world, target.faction_id, "band", -c.world_rules.raid_relation_hit)
	c.cal.advance_days(c.world_rules.raid_days)
	return true


static func _do_trade(c: Campaign, rng: SimRng, trade: Dictionary, log: PackedStringArray) -> bool:
	var here := c.world.place(c.band.location)
	var good: WorldTypes.Good = trade.good
	var price := Market.price(c.world_rules, here, good)
	var afford := int(float(c.band.silver) * c.world_rules.trade_spend_fraction / maxf(1.0, price))
	var bought := Market.buy(c.world_rules, here, c.band, good, afford, log)
	if bought <= 0:
		return false
	c.cal.advance_days(c.world_rules.market_days)
	if not _sail(c, rng.fork("sail"), trade.to, log):
		return true
	var dest := c.world.place(trade.to)
	Market.sell(c.world_rules, dest, c.band, good, c.band.cargo.get(good, 0), log)
	if c.band.captives > 0 and c.world_rules.slave_markets.has(dest.id):
		Market.sell_captives(c.world_rules, dest, c.band, c.band.captives, log)
		c.band.captives = 0
	c.cal.advance_days(c.world_rules.market_days)
	return true


static func _do_contract(c: Campaign, rng: SimRng, o: Dictionary, log: PackedStringArray) -> bool:
	var r := Contracts.accept(c.world_rules, c.world, c.band, o, log)
	var success := true
	if r.has("voyage_required"):
		success = _sail(c, rng.fork("sail"), r.voyage_required, log)
	if success and r.has("battle_required"):
		var br: Dictionary = r.battle_required
		var res := c.fight(br.get("kind", o.kind), br.tier, _forced(c, br.attackers), true,
				c.world_rules.levy_stat if o.kind == "levy" else c.world_rules.sea_fight_stat)
		success = not c.over and res.winner == 0
	if c.over:
		return true
	Contracts.complete(c.world_rules, c.world, c.band, o, success, log)
	_promote(c, log)
	c.cal.advance_days(int(o.get("days", 10)))
	return true


static func _rove(c: Campaign, rng: SimRng, log: PackedStringArray) -> void:
	# Nothing worth doing here: sail to a known hall or town to look for work.
	var options: Array[String] = []
	for id in c.band.known_places:
		var p := c.world.place(id)
		if p != null and id != c.band.location and p.is_open(c.world.year) \
				and (p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN):
			options.append(id)
	if options.is_empty():
		return
	options.sort()
	_sail(c, rng, options[rng.randi_range(0, options.size() - 1)], log)


static func _go_home(c: Campaign, rng: SimRng, log: PackedStringArray) -> void:
	if c.over or c.band.location == c.band.home:
		return
	if not _sail(c, rng, c.band.home, log):
		log.append("%d: the band winters away from home at %s" % [c.cal.year, c.world.place(c.band.location).display_name])


static func _promote(c: Campaign, log: PackedStringArray) -> void:
	var wr := c.world_rules
	for r in [WorldTypes.Rank.HERSIR, WorldTypes.Rank.JARL, WorldTypes.Rank.KING]:
		if c.band.rank < r and c.band.rank_progress >= wr.rank_thresholds[r]:
			c.band.rank = r
			c.band.log("%s is now reckoned a %s" % [c.band.leader.display_name, WorldTypes.RANK_NAMES[r]])
			log.append("%s is now a %s" % [c.band.leader.display_name, WorldTypes.RANK_NAMES[r]])


# --- Spine and feuds at the start of summer ---------------------------------

static func _spine(c: Campaign, rng: SimRng, log: PackedStringArray) -> void:
	for ev in Timeline.pending(c.world_rules, c.world, c.cal.year):
		var choice := _spine_choice(c, ev)
		var r := Timeline.fire(rng.fork(ev.id), c.world_rules, c.world, c.band, ev, choice, log)
		if r.has("place_opened"):
			c.band.known_places[r.place_opened] = true
		if r.has("battle_required"):
			var br: Dictionary = r.battle_required
			var res := c.fight(br.get("kind", ev.id), br.tier, _forced(c, br.attackers), br.get("side", "") != "against", c.world_rules.spine_stat)
			if c.over:
				return
			Timeline.resolve(c.world_rules, c.world, c.band, ev, choice, res.winner == 0, log)
		c.tally.spine = c.tally.get("spine", 0) + 1


## The stand-in player's politics: serve Harald when he is friendly, fight
## for him at Hafrsfjord, otherwise keep his head down.
static func _spine_choice(c: Campaign, ev: Dictionary) -> String:
	var options: Array = ev.get("options", ["ignore"])
	var rel := FactionAI.relation(c.world, "harald", "band")
	if ev.id == "hafrsfjord":
		return "fight_for_harald" if rel >= 0 else "ignore"
	if options.has("serve") and rel >= 0:
		return "serve"
	return "ignore"


static func _feuds(c: Campaign, rng: SimRng, log: PackedStringArray) -> void:
	for ev in Feud.summer_events(rng, c.world_rules, c.world, c.band, log):
		if c.over:
			return
		if ev.has("battle_required"):
			var br: Dictionary = ev.battle_required
			var f := Feud.find(c.band, ev.get("family", ""))
			var level: int = f.get("level", 1) if f != null and f is Dictionary else 1
			c.fight(br.get("kind", "ambush"), br.tier, _forced(c, br.attackers), true, c.world_rules.feud_stat_base + level - 1)
		elif ev.get("kind", "") == "demand":
			var family: String = ev.family
			var ask := Feud.offer_settlement(c.world_rules, c.band, family)
			if ask <= c.band.silver * c.world_rules.settle_if_fraction:
				Feud.settle(c.world_rules, c.band, family, ask, log)
			elif not go_to_thing(c, rng.fork("thing:" + family), family, WorldTypes.CaseKind.RAID, false, log):
				Feud.escalate(c.world_rules, c.band, family, log)


# --- The Thing and Iceland ------------------------------------------------

## The nearest known Thing site the band can reach, or "".
static func nearest_thing(c: Campaign) -> String:
	var best := ""
	var best_days := 999
	for id in c.band.known_places:
		var p := c.world.place(id)
		if p == null or p.kind != WorldTypes.PlaceKind.THING_SITE or not p.is_open(c.world.year):
			continue
		var route := Voyage.plan(c.world, c.band.location, id, c.band.known_places)
		if route.is_empty():
			continue
		var days := 0
		for i in range(1, route.size()):
			days += c.world.days_between(route[i - 1], route[i])
		if days < best_days:
			best_days = days
			best = id
	return best


## Sails to the nearest Thing and argues a case against `family`. Returns
## false if no Thing is reachable or the season is too far gone. A verdict
## of any kind other than FAILED settles the feud with that family.
static func go_to_thing(c: Campaign, rng: SimRng, family: String, kind: WorldTypes.CaseKind,
		plaintiff: bool, log: PackedStringArray) -> bool:
	var wr := c.world_rules
	if c.band.silver < wr.thing_min_silver or Outlawry.is_outlawed(c.band, c.cal):
		return false
	var site := nearest_thing(c)
	if site == "":
		return false
	if c.cal.summer_left(wr.summer_days) < wr.thing_days + wr.home_margin_days + 4:
		return false
	if not _sail(c, rng.fork("sail"), site, log):
		return false
	var claim := Feud.wergild(wr, c.band.rank)
	var tc := Thing.open_case(wr, c.band, kind, family, claim, plaintiff)
	var spend := mini(int(c.band.silver * wr.thing_spend_fraction), wr.thing_spend_max)
	var verdict := Thing.run(rng.fork("case"), wr, c.world, c.band, tc, spend, log)
	if not tc.battle_required.is_empty():
		var br: Dictionary = tc.battle_required
		c.fight(br.get("kind", "thing brawl"), br.tier, _forced(c, br.attackers), false, wr.sea_fight_stat)
		if c.over:
			return true
	c.cal.advance_days(wr.thing_days)
	c.tally.thing_cases = c.tally.get("thing_cases", 0) + 1
	var f := Feud.find(c.band, family)
	if verdict != WorldTypes.Verdict.FAILED and not f.is_empty():
		f.settled = true
		f.verdict = WorldTypes.VERDICT_NAMES[verdict]
		c.band.log("the matter with %s was settled at the Thing: %s" % [family, WorldTypes.VERDICT_NAMES[verdict]])
	return true


## Feuds where the band is the wronged party (a man of ours slain) go to the
## Thing as a killing case, once.
static func _sue_wrongs(c: Campaign, rng: SimRng, log: PackedStringArray) -> void:
	for f in c.band.unsettled_feuds():
		if f.get("sued", false) or str(f.get("cause", "")).begins_with("raid on"):
			continue
		f.sued = true
		if go_to_thing(c, rng.fork(str(f.get("family", ""))), str(f.get("family", "")), WorldTypes.CaseKind.KILLING, true, log):
			return


## A full outlaw, or a man whose home now answers to a hostile Harald, sails
## for Iceland if it is open and known, takes land there and starts again.
## Returns true when the band emigrated (the summer ends there).
static func _consider_emigration(c: Campaign, rng: SimRng, log: PackedStringArray) -> bool:
	var wr := c.world_rules
	var iceland := c.world.place("iceland")
	if iceland == null or not iceland.is_open(c.world.year) or not c.band.knows("iceland") or c.band.home == "iceland":
		return false
	var home := c.world.place(c.band.home)
	var hostile_harald := home != null and home.faction_id == "harald" \
			and FactionAI.relation(c.world, "harald", "band") < wr.emigrate_relation
	var full_outlaw := c.band.outlawry == WorldTypes.Outlawry.FULL
	if not (hostile_harald or full_outlaw):
		return false
	if not _sail(c, rng.fork("sail"), "iceland", log):
		return false
	c.band.home = "iceland"
	c.band.land += wr.iceland_land_claim
	c.band.known_places["iceland"] = true
	if c.band.outlawry != WorldTypes.Outlawry.NONE:
		Outlawry.lift(c.band, log)
		log.append("%d: Norwegian law does not reach Iceland" % c.cal.year)
	for f in c.band.unsettled_feuds():
		f.settled = true
	c.tally.emigrations = c.tally.get("emigrations", 0) + 1
	var why := "an outlaw" if full_outlaw else "with no wish to bow to Harald"
	c.band.log("%s sails for Iceland, %s, and carries fire around his land-take" % [c.band.leader.display_name, why])
	log.append("%d: the band takes land in Iceland" % c.cal.year)
	return true


# --- Letting the years pass ------------------------------------------------

## Auto-resolves years with no sailing until something demands attention.
## Returns the interrupts that stopped it (empty if all n years passed).
static func pass_years(c: Campaign, n: int, log: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for i in n:
		if c.over:
			break
		c.band.year = c.cal.year
		c.world.year = c.cal.year
		# Spine events that need the player stop the passing of years.
		var due := Timeline.pending(c.world_rules, c.world, c.cal.year)
		if not due.is_empty():
			out.append("spine:%s" % due[0].id)
			break
		if not c.band.unsettled_feuds().is_empty() and c.world_rules.pass_years_interrupts.has("feud_attack"):
			out.append("feud")
			break
		if not Family.sons_of_age(c.rules, c.band, c.cal).is_empty() and c.world_rules.pass_years_interrupts.has("son_of_age"):
			out.append("son_of_age")
			break
		log.append("%d: a quiet year" % c.cal.year)
		c.band.log("the year passed quietly")
		c.winter()
		if c.over:
			break
		c.cal.next_year()
		c.band.year = c.cal.year
	return out


## Year-end bookkeeping for the world: markets drift, factions move,
## alertness fades. Called by the campaign at the thaw.
static func year_end(c: Campaign, log: PackedStringArray) -> void:
	var rng := c.rng.fork("world_year_end:%d" % c.cal.year)
	Market.yearly_drift(rng.fork("market"), c.world_rules, c.world, log)
	for ev in FactionAI.yearly(rng.fork("factions"), c.world_rules, c.world, c.band, log):
		c.tally.faction_events = c.tally.get("faction_events", 0) + 1
	for p in c.world.places.values():
		p.alertness = maxi(0, p.alertness - c.world_rules.alertness_decay_per_year)
		p.captives_sold = 0
	for r in c.world.region_alertness:
		c.world.region_alertness[r] = maxi(0, c.world.region_alertness[r] - c.world_rules.alertness_decay_per_year)
	if Outlawry.is_outlawed(c.band, c.cal) and c.band.outlawry == WorldTypes.Outlawry.LESSER \
			and c.cal.year >= c.band.outlaw_until:
		Outlawry.lift(c.band, log)
