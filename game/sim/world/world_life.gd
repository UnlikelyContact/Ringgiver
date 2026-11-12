class_name WorldLife
extends RefCounted
## The summer world alive (notes/world-life.md): the others abroad on the
## map (Roam.Party) live their own summer, cheaply and from the seed.
## Raiders hunt merchants and fall on farms; the king's ships hunt raiders
## and outlaws and ask a band at sea for the king's due; houses at feud
## (Families) send their men against each other's men and seats. A clash is
## a strength roll after `clash_days`, never a battle; it leaves a wreck to
## come upon, tidings ("Word comes that ...") heard at once nearby or told
## later at a hall, and, between houses, a killing on their feud's ledger.
## The band takes part where it stands: it may come upon a fight and take
## a side, stand with farmers who are being plundered, guard a merchant,
## pay or refuse the king's ships, lose a ship left on a hostile beach and
## take her back. Every fight the band takes up goes through
## Journey._offer_fight like any other.
##
## `tick(j, dt)` runs from Journey's clock (advance, _pass) after the
## parties have moved; it reckons the world every `life_tick_days`.


# --- Spring -------------------------------------------------------------------------

## The summer's own parties beyond the merchants, raiders and outlaws
## (Roam.populate): the king's ships, and the men of houses at feud.
static func spring(j: Journey) -> void:
	var wr := j.c.world_rules
	var world := j.c.world
	var roam := j.roam
	roam.news.clear()
	roam.struck.clear()
	roam.life_clock = 0.0
	roam.lure = false
	for k in j.life.keys():
		if str(k).contains("_offer:"):
			j.life.erase(k)
	var r := j._fork("life_spring")
	var halls: Array[String] = []
	var ids: Array = world.places.keys()
	ids.sort()
	for id in ids:
		var p: Place = world.places[id]
		if p.is_open(world.year) and p.region != WorldTypes.Region.ICELAND and HOME_KINDS.has(p.kind) \
				and p.pos.distance_to(roam.pos) >= wr.sight_leagues + 2.0 and roam.grid.place_cell.has(id) \
				and Families.HOME_REGIONS.has(p.region):
			halls.append(id)
	for i in wr.roam_kings_ships:
		if halls.is_empty():
			break
		var home := halls[r.randi_range(0, halls.size() - 1)]
		var fid := world.place(home).faction_id
		if world.factions.has("harald") and (world.factions["harald"] as Faction).alive:
			fid = "harald"
		var k := roam.add_kings_ships(wr, world, home, fid)
		if k != null:
			k.mood = 0
	# Houses at feud send their men against each other.
	var fs := world.families
	if fs == null:
		return
	var sent := 0
	var keys: Array = fs.pairs.keys()
	keys.sort()
	for key in keys:
		if sent >= wr.house_parties_max:
			break
		var pr: Dictionary = fs.pairs[key]
		if str(pr.enmity) != "feud" or r.randf() >= wr.house_party_chance:
			continue
		var a := fs.house(str(pr.a))
		var b := fs.house(str(pr.b))
		if a == null or b == null or not Families.HOME_REGIONS.has(a.region) or not Families.HOME_REGIONS.has(b.region):
			continue
		# The side that has lost more men goes after the other.
		var kills: Dictionary = pr.ledger.kills
		var go := a if int(kills.get(b.name, 0)) >= int(kills.get(a.name, 0)) else b
		var other := b if go == a else a
		var men := mini(wr.house_party_men, maxi(3, go.strength / 2))
		var hp := roam.add_house_party(wr, world, go.name, go.seat, other.name, other.seat, men)
		if hp != null:
			hp.mood = Families.party_mood(wr, j.c.band, go.name)
			sent += 1


const HOME_KINDS := [WorldTypes.PlaceKind.HALL, WorldTypes.PlaceKind.TOWN]


# --- The world's day ------------------------------------------------------------------------

static func tick(j: Journey, dt: float) -> void:
	var roam := j.roam
	var wr := j.c.world_rules
	if roam.clock - roam.life_clock < wr.life_tick_days:
		return
	var days := roam.clock - roam.life_clock
	roam.life_clock = roam.clock
	Market.mend_local(wr, j.c.world, days)
	var r := j._fork("life")
	_expire(j)
	_hunt(j)
	_clash(j, r)
	_strike(j, r, days)
	_raids(j, r)
	_theft(j, r, days)
	Hiring.reckon(j)
	TradeRoad.check_escort(j)


static func _expire(j: Journey) -> void:
	var roam := j.roam
	for p: Roam.Party in roam.parties.duplicate():
		if p.kind == "wreck" and roam.clock >= p.expire:
			roam.parties.erase(p)


## Whom each hunter goes after: raiders a merchant, the king's ships
## raiders and outlaws, a house's men the men of the house it is at feud
## with. The nearest within `hunt_sight` that is not already in a fight.
static func _hunt(j: Journey) -> void:
	var roam := j.roam
	var wr := j.c.world_rules
	for p in roam.parties:
		if p.busy() or p.kind == "wreck" or p.escorted or roam.clock < p.rest_until:
			continue
		if p.prey != null and (not roam.parties.has(p.prey) or p.prey.busy()):
			p.prey = null
		var best: Roam.Party = null
		var best_d := wr.hunt_sight
		for q in roam.parties:
			if q == p or q.busy() or q.escorted or roam.clock < q.rest_until or not preys_on(j, p, q):
				continue
			var d := p.pos.distance_to(q.pos)
			if d < best_d:
				best_d = d
				best = q
		p.prey = best


## Whether `p` goes for `q` on sight.
static func preys_on(j: Journey, p: Roam.Party, q: Roam.Party) -> bool:
	match p.kind:
		"raiders":
			return q.kind == "merchant" and p.men >= q.men
		"kings_ships":
			return q.kind == "raiders" or q.kind == "outlaws"
		"house_men":
			var fs := j.c.world.families
			return q.family != "" and q.family != p.family and fs != null and fs.at_feud(p.family, q.family) \
					and q.kind != "wreck"
	return false


## Hunters that have come up with their prey fall to fighting; a fight
## that has lasted `clash_days` is decided by a strength roll.
static func _clash(j: Journey, r: SimRng) -> void:
	var roam := j.roam
	var wr := j.c.world_rules
	for p: Roam.Party in roam.parties.duplicate():
		if not roam.parties.has(p):
			continue
		if p.engaged != null:
			if roam.clock >= p.fray_until and roam.parties.has(p.engaged):
				decide(j, p, p.engaged, r, "")
			elif not roam.parties.has(p.engaged):
				p.engaged = null
			continue
		if p.prey != null and roam.parties.has(p.prey) and not p.prey.busy() and p.pos.distance_to(p.prey.pos) <= wr.clash_leagues:
			var q: Roam.Party = p.prey
			p.engaged = q
			q.engaged = p
			p.hunted = false
			q.hunted = true
			p.fray_until = roam.clock + wr.clash_days
			q.fray_until = p.fray_until
			p.prey = null
			q.prey = null
			p.chasing = false
			q.chasing = false


## A party's strength for a clash: its men by their tier, by the roll.
static func strength(rules: WorldRules, men: int, tier: int, r: SimRng) -> float:
	var w: float = float(rules.clash_tier_weight[clampi(tier, 0, rules.clash_tier_weight.size() - 1)])
	return float(men) * w * (1.0 + (r.randf() * 2.0 - 1.0) * rules.clash_luck)


## Decides the fight between `a` and `b` by a strength roll: the loser is
## destroyed or gets away hurt, the winner loses men, a wreck lies where
## it was fought, the houses' ledger takes the killing, and the tidings go
## out. `forced` names the winner's kind when the band has decided it
## ("" for the dice). Returns the winner.
static func decide(j: Journey, a: Roam.Party, b: Roam.Party, r: SimRng, _forced: String) -> Roam.Party:
	var wr := j.c.world_rules
	var roam := j.roam
	var sa := strength(wr, a.men, a.tier, r)
	var sb := strength(wr, b.men, b.tier, r)
	var win := a if sa >= sb else b
	var lose := b if win == a else a
	var ws := maxf(sa, sb)
	var ls := minf(sa, sb)
	_settle_fight(j, win, lose, ls >= ws * wr.clash_flee_ratio, ls)
	return win


## The fight between `win` and `lose` is over: losses, what is left of it,
## the ledger, the tidings. `fled`: the loser got away hurt.
static func _settle_fight(j: Journey, win: Roam.Party, lose: Roam.Party, fled: bool, lose_strength: float) -> void:
	var wr := j.c.world_rules
	var roam := j.roam
	win.engaged = null
	lose.engaged = null
	var w_weight: float = float(wr.clash_tier_weight[clampi(win.tier, 0, 3)])
	win.men = maxi(1, win.men - roundi(lose_strength * wr.clash_winner_loss / w_weight))
	win.rest_until = roam.clock + 2.0
	var where := _where(j, lose.pos)
	# What the loser carried: a merchant's cargo, a raider's plunder.
	var worth := lose.loot
	if lose.kind == "merchant" and not lose.offer.is_empty():
		worth += int(lose.offer.units) * int(wr.base_price[lose.offer.good])
	var leavings := {"silver": 0, "goods": {}, "captives": 0, "survivor": lose.kind == "merchant"}
	if lose.kind == "merchant" and not lose.offer.is_empty():
		leavings.goods = {lose.offer.good: maxi(1, int(lose.offer.units) / 3)}
	if win.kind == "raiders" or win.kind == "outlaws":
		win.loot += worth
		win.captives += 1 if lose.kind == "merchant" else 0
	else:
		leavings.silver = worth / 2
		leavings.captives = lose.captives
	if fled:
		lose.men = maxi(1, roundi(lose.men * (1.0 - wr.clash_loser_loss)))
		lose.rest_until = roam.clock + wr.party_rest_days
		lose.prey = null
		lose.loot = 0
		if lose.kind == "merchant":
			lose.offer = {}
	else:
		roam.parties.erase(lose)
	roam.add_wreck(wr, lose.pos, "the leavings of a fight %s" % where, leavings)
	# The houses' ledger: a fight between their men is a killing.
	var fs := j.c.world.families
	if fs != null and win.family != "" and lose.family != "" and win.family != lose.family \
			and fs.houses.has(win.family) and fs.houses.has(lose.family):
		fs.record_killing(wr, j.c.band, win.family, lose.family, j.c.world.year, win.kind == "house_men" and lose.kind == "house_men")
	var text := ""
	if lose.hunted:
		var end := "but they got away with their lives, and little else" if fled else ("and took her and all she carried" if lose.kind == "merchant" else "and cut them down")
		text = "%s fell on %s %s, %s" % [_who(j, win), _who(j, lose), where, end]
		if win.kind == "kings_ships":
			text = "%s caught %s %s and %s them" % [_who(j, win), _who(j, lose), where, "put to flight" if fled else "made an end of"]
	else:
		text = "%s fell on %s %s and were %s" % [_who(j, lose), _who(j, win), where, "beaten off" if fled else "cut down to the last man"]
	win.hunted = false
	lose.hunted = false
	tell(j, text, lose.pos)
	return


## The farms the raiders fall on: a raider ship with nothing in its sights
## turns for a farm or a small hall near its course, now and then.
static func _strike(j: Journey, r: SimRng, days: float) -> void:
	var roam := j.roam
	var wr := j.c.world_rules
	var world := j.c.world
	for p in roam.parties:
		if p.kind != "raiders" or p.busy() or p.strike != "" or p.prey != null or p.chasing or roam.clock < p.rest_until:
			continue
		if r.randf() >= wr.strike_chance_day * days:
			continue
		var best := ""
		var best_d := wr.strike_leagues
		var ids: Array = world.places.keys()
		ids.sort()
		for id in ids:
			var q: Place = world.places[id]
			if not q.is_open(world.year) or q.family == p.family or q.wealth < wr.raid_min_wealth:
				continue
			if not (q.kind == WorldTypes.PlaceKind.FARMSTEAD or (q.kind == WorldTypes.PlaceKind.HALL and q.defenses <= 3)):
				continue
			if roam.struck.has(id) and roam.clock - float(roam.struck[id]) < wr.raided_rest_days:
				continue
			var d := q.pos.distance_to(p.pos)
			if d < best_d:
				best_d = d
				best = id
		if best != "":
			# It makes for the farm once it comes to the harbour it is bound
			# for (Roam.step_parties), by the sea route.
			p.strike = best


## Raiders that have come to the farm they made for: the raid lasts
## `place_raid_days`, and is then decided against the farmers. A band at
## the place is asked whether it will stand with them.
static func _raids(j: Journey, r: SimRng) -> void:
	var roam := j.roam
	var wr := j.c.world_rules
	var world := j.c.world
	for p: Roam.Party in roam.parties.duplicate():
		if not roam.parties.has(p) or p.strike == "" or p.kind == "kings_ships":
			continue
		var target := world.place(p.strike)
		if target == null:
			p.strike = ""
			continue
		var at_it: bool = MapGrid.cell_of(p.pos) == roam.grid.place_cell.get(p.strike, Vector2i(-9, -9)) or p.pos.distance_to(MapGrid.centre(roam.grid.place_cell[p.strike])) < 0.6
		if p.raiding_until < 0.0:
			if not at_it:
				if p.at >= p.route.size() and not p.busy() and p.home == p.strike:
					p.strike = ""  # it could not come there: it goes elsewhere
				continue
			p.raiding_until = roam.clock + wr.place_raid_days
			roam.struck[p.strike] = roam.clock
			if j.c.band.location == p.strike and j.can_act():
				ask_defend(j, p)
			elif roam.pos.distance_to(target.pos) <= wr.hear_leagues:
				j._say("Smoke goes up over %s: %s have come ashore there." % [target.display_name, _who(j, p)])
			continue
		if roam.clock < p.raiding_until:
			continue
		_raid_done(j, p, target, r)


## The farmers alone against the raiders: a strength roll.
static func _raid_done(j: Journey, p: Roam.Party, target: Place, r: SimRng) -> void:
	var wr := j.c.world_rules
	var world := j.c.world
	p.raiding_until = -1.0
	p.strike = ""
	p.route = []
	p.at = 0
	p.rest_until = j.roam.clock + 3.0
	var a := Raiding.assess(wr, world, target, j.c.band)
	var theirs := strength(wr, int(a.defenders), int(wr.place_defender_tier), r)
	var ours := strength(wr, p.men, p.tier, r)
	if ours >= theirs:
		var take := roundi(float(target.wealth) * wr.raided_wealth_share)
		target.wealth -= take
		target.alertness = clampi(target.alertness + 1, 0, 10)
		p.loot += take
		p.captives += 1
		p.men = maxi(1, p.men - roundi(theirs * wr.clash_winner_loss))
		var fs := world.families
		if fs != null and p.family != "" and fs.houses.has(p.family) and fs.houses.has(target.family) and p.family != target.family:
			fs.record_killing(wr, j.c.band, p.family, target.family, world.year)
		tell(j, "%s plundered %s and carried off %d oz and some of the people" % [_who(j, p), target.display_name, take], target.pos)
		j.c.tally.world_raids = int(j.c.tally.get("world_raids", 0)) + 1
	else:
		p.men = maxi(1, roundi(p.men * (1.0 - wr.clash_loser_loss)))
		var fs2 := world.families
		if fs2 != null and p.family != "" and fs2.houses.has(p.family) and fs2.houses.has(target.family) and p.family != target.family:
			fs2.record_killing(wr, j.c.band, target.family, p.family, world.year)
		tell(j, "the men of %s beat off %s" % [target.display_name, _who(j, p)], target.pos)


## Asks the band whether it will stand with the farmers being plundered.
static func ask_defend(j: Journey, p: Roam.Party) -> void:
	var target := j.c.world.place(p.strike)
	j.decisions.push_front({"kind": "world", "what": "defend", "party": p, "place": target.id,
			"text": "%s have come ashore at %s, %d of them, and are driving off the cattle and the people. Will you stand with the farmers?" % [
					Journey._cap(_who(j, p)), target.display_name, p.men],
			"options": [{"id": "defend", "label": "Stand with the farmers"}, {"id": "away", "label": "Keep out of it"}]})


# --- Meeting them ----------------------------------------------------------------------------

## The band has come within reach of a party busy with its own fight or
## raid, a wreck, the king's ships or the thieves with its ship. Returns
## true when this module has answered the meeting (a decision queued).
static func meet(j: Journey, p: Roam.Party) -> bool:
	var wr := j.c.world_rules
	match p.kind:
		"merchant":
			if p.offer.is_empty():
				return true  # robbed already: nothing left to sell
		"wreck":
			p.rest_until = j.roam.clock + wr.wreck_days  # seen once
			var lv: Dictionary = p.leavings
			var what := PackedStringArray()
			if int(lv.get("silver", 0)) > 0:
				what.append("%d oz of silver among the dead" % int(lv.silver))
			for g in (lv.get("goods", {}) as Dictionary):
				what.append("%d %s" % [int(lv.goods[g]), WorldTypes.GOOD_NAMES[g]])
			if int(lv.get("captives", 0)) > 0:
				what.append("%d captives left bound" % int(lv.captives))
			if bool(lv.get("survivor", false)):
				what.append("a man who lived through it")
			if what.is_empty():
				return true  # nothing worth stopping for
			j.decisions.append({"kind": "world", "what": "wreck", "party": p,
					"text": "You come upon %s: %s." % [p.text, ", ".join(what)],
					"options": [{"id": "take", "label": "Take what is there"}, {"id": "leave", "label": "Leave it"}]})
			return true
		"kings_ships":
			if Outlawry.is_outlawed(j.c.band, j.c.cal):
				return false  # they fight an outlaw: the levy's way
			p.mood = 1  # once a summer
			p.rest_until = j.roam.clock + wr.party_rest_days
			var toll := toll_for(j)
			j.decisions.append({"kind": "world", "what": "toll", "party": p, "toll": toll,
					"text": "%s hail you: the king's waters are not crossed for nothing, they say, and want %d oz for your passage." % [Journey._cap(p.name), toll],
					"options": [{"id": "pay", "label": "Pay %d oz" % toll, "enabled": j.c.band.silver >= toll}, {"id": "refuse", "label": "Refuse"}]})
			return true
		"ship_thieves":
			p.rest_until = j.roam.clock + 3.0
			j.decisions.append({"kind": "world", "what": "thieves", "party": p,
					"text": "Here is your ship, and %d men of %s with her, who took her off the beach." % [p.men, p.family if p.family != "" else "the thieves"],
					"options": [{"id": "fight", "label": "Take her back"}, {"id": "away", "label": "Let her go"}]})
			return true
	if p.engaged != null:
		var a := p
		var b := p.engaged
		p.rest_until = j.roam.clock + 2.0
		b.rest_until = p.rest_until
		j.decisions.append({"kind": "world", "what": "fray", "party": a, "other": b,
				"text": "Ahead of you %s (%d men) and %s (%d men) are at it with axes and spears." % [_who(j, a), a.men, _who(j, b), b.men],
				"options": [{"id": "a", "label": "Help %s" % _who(j, a)}, {"id": "b", "label": "Help %s" % _who(j, b)},
						{"id": "away", "label": "Keep out of it"}]})
		return true
	if p.raiding_until >= 0.0 and p.strike != "":
		p.rest_until = j.roam.clock + 1.0
		ask_defend(j, p)
		return true
	return false


## The king's due for a band of this size.
static func toll_for(j: Journey) -> int:
	var wr := j.c.world_rules
	return maxi(wr.toll_min, wr.toll_per_man * j.c.band.fighters().size())


## Answers a "world" decision. Returns false when it is not one of ours.
static func answer(j: Journey, d: Dictionary, id: String) -> bool:
	if str(d.get("kind", "")) != "world":
		return false
	var wr := j.c.world_rules
	var band := j.c.band
	var who := band.leader.display_name
	var roam := j.roam
	var p: Roam.Party = d.get("party", null)
	match str(d.what):
		"wreck":
			if id == "take" and p != null and roam.parties.has(p):
				var lv: Dictionary = p.leavings
				band.silver += int(lv.get("silver", 0))
				band.captives += int(lv.get("captives", 0))
				var goods: Dictionary = lv.get("goods", {})
				for g in goods:
					var n := mini(int(goods[g]), Market.cargo_room(wr, band))
					if n > 0:
						band.cargo[g] = int(band.cargo.get(g, 0)) + n
				var lines := "%s takes what the fight left" % who
				var room := band.ship == null or not roam.afloat() or band.fighters().size() < band.ship.crew_capacity(wr)
				if bool(lv.get("survivor", false)) and band.living_men().size() < j.c.rules.recruit_cap and room:
					var m := Recruits.random(j._fork("survivor"), j.c.rules, band.next_id())
					band.add_man(m)
					j.c._arm_new_men()
					lines += "; %s, who lived through it, asks to go with him" % m.display_name
				j._say(lines + ".")
				roam.parties.erase(p)
			j._pass(0.5)
		"toll":
			var f: Faction = j.c.world.factions.get(p.faction, null) if p != null else null
			if id == "pay" and band.silver >= int(d.toll):
				band.silver -= int(d.toll)
				if f != null:
					FactionAI.shift(j.c.world, f.id, FactionAI.BAND, 2)
				j._say("%s pays the king's due, %d oz, and the ships let him go his way." % [who, int(d.toll)])
			else:
				if f != null:
					FactionAI.shift(j.c.world, f.id, FactionAI.BAND, -wr.toll_refused_relation)
				if p != null and j._fork("toll").randf() < wr.toll_refused_fight:
					j._offer_fight("the king's ships", p.tier, Sandbox._forced(j.c, p.men), false, wr.levy_stat, roam.afloat(), false,
							{"kind": "world_fight", "what": "toll", "party": p}, "%s will not pay, and the king's men come on." % who, true)
				else:
					j._say("%s will not pay; the king's men let him go, and will remember it." % who)
		"defend":
			if id == "defend" and p != null and roam.parties.has(p):
				var place := j.c.world.place(str(d.place))
				j._offer_fight("raiders at %s" % place.display_name, p.tier, Sandbox._forced(j.c, p.men), false, j.c.world_rules.sea_fight_stat,
						false, false, {"kind": "world_fight", "what": "defend", "party": p, "place": place, "family": p.family},
						"%s stands with the farmers of %s." % [who, place.display_name], true)
			else:
				j._say("%s keeps out of it." % who)
		"fray":
			var other: Roam.Party = d.get("other", null)
			if id == "away" or p == null or other == null or not roam.parties.has(p) or not roam.parties.has(other):
				j._say("%s keeps out of it, and goes his way." % who)
			else:
				var ally := p if id == "a" else other
				var foe := other if id == "a" else p
				var size := maxi(2, foe.men - ally.men / 2)
				j._offer_fight("%s" % _who(j, foe), foe.tier, Sandbox._forced(j.c, size), true, wr.sea_fight_stat, roam.afloat(), false,
						{"kind": "world_fight", "what": "fray", "party": foe, "ally": ally, "family": foe.family},
						"%s takes the side of %s against %s." % [who, _who(j, ally), _who(j, foe)], true)
		"thieves":
			if id == "fight" and p != null and roam.parties.has(p):
				j._offer_fight("the ship-thieves", CombatTypes.Tier.GREEN, Sandbox._forced(j.c, p.men), true, wr.sea_fight_stat, false, false,
						{"kind": "world_fight", "what": "thieves", "party": p, "family": p.family},
						"%s goes to take his ship back." % who, true)
			else:
				j._say("%s lets her go, for now." % who)
	return true


## A fight the band took up in the world's life is over (`result` null: it
## faded). The party itself is dealt with by Journey._after_fight.
static func after_fight(j: Journey, ctx: Dictionary, result: BattleResult) -> void:
	var wr := j.c.world_rules
	var band := j.c.band
	var won := result != null and result.winner == 0
	var p: Roam.Party = ctx.get("party", null)
	var who := band.leader.display_name
	match str(ctx.get("what", "")):
		"defend":
			var place: Place = ctx.place
			if won:
				j._shift(place.family, wr.standing_defended)
				band.silver += wr.defend_fee
				band.honor = clampi(band.honor + 2, 0, 100)
				Way.add_deed(band, Way.Id.KINGS_MAN, 1)
				j._say("The farmers of %s give %s %d oz and their thanks; %s will hear of it." % [place.display_name, who, wr.defend_fee, place.family])
				tell(j, "%s drove raiders off %s" % [who, place.display_name], place.pos, true)
			elif result != null and p != null and j.roam.parties.has(p):
				_raid_done(j, p, place, j._fork("raid_after"))
		"fray":
			var ally: Roam.Party = ctx.get("ally", null)
			if ally == null:
				return
			ally.engaged = null
			ally.rest_until = j.roam.clock + wr.party_rest_days
			if won:
				match ally.kind:
					"merchant":
						var worth := 0
						if not ally.offer.is_empty():
							worth = int(ally.offer.units) * int(wr.base_price[ally.offer.good])
						var pay := maxi(3, roundi(float(worth) * wr.rescue_share))
						band.silver += pay
						j._shift(ally.family, wr.standing_rescued)
						Way.add_deed(band, Way.Id.TRADER, 1)
						j._say("The merchant gives %s %d oz for his life and his goods." % [who, pay])
					"kings_ships":
						if ally.faction != "":
							FactionAI.shift(j.c.world, ally.faction, FactionAI.BAND, wr.contract_relation_gain)
						band.fame = clampi(band.fame + 1, 0, 100)
						Way.add_deed(band, Way.Id.KINGS_MAN, 1)
						j._say("The king's men will speak well of %s in the king's hall." % who)
					"raiders", "outlaws":
						# He joined the robbers: a share of what they took.
						var share := (p.loot if p != null else 0) / 2
						if p != null and p.kind == "merchant" and not p.offer.is_empty():
							var n := mini(int(p.offer.units) / 2, Market.cargo_room(wr, band))
							if n > 0:
								band.cargo[p.offer.good] = int(band.cargo.get(p.offer.good, 0)) + n
							j._shift(p.family, wr.standing_raid / 2)
						band.silver += share
						Way.add_deed(band, Way.Id.VIKING, 1)
						j._say("%s's share of the taking is his." % who)
					"house_men":
						j._shift(ally.family, wr.standing_help_won)
						if p != null and p.family != "":
							j._shift(p.family, wr.standing_help_against)
						var fs := j.c.world.families
						if fs != null and p != null and fs.houses.has(ally.family) and fs.houses.has(p.family):
							fs.record_killing(wr, band, ally.family, p.family, j.c.world.year, true)
						j._say("%s will not forget who stood with them." % ally.family)
				if p != null:
					tell(j, "%s took the side of %s against %s" % [who, _who(j, ally), _who(j, p)], ally.pos, true)
			elif result != null:
				j.roam.parties.erase(ally)
		"toll":
			pass
		"thieves":
			if won and p != null and p.ship != null:
				band.ship = p.ship
				j.roam.ship_at = p.pos
				if j.roam.pos.distance_to(p.pos) < 1.0:
					j.roam.ship_at = Vector2.INF
					j.roam.aboard = j.roam.afloat() or j.roam.grid.terrain(j.roam.cell()) == MapGrid.T.SHORE
					if not j.roam.aboard:
						j.roam.ship_at = j.roam.pos
				j.life.erase("stolen")
				j._say("%s has his ship again." % who)


# --- The ship on the beach ---------------------------------------------------------------------

## The band's ship, beached where it walked away from her: in hostile
## country, unwatched, she may be taken (`ship_theft_day`, more with
## raiders or outlaws about), and her thieves sail her home.
static func _theft(j: Journey, r: SimRng, days: float) -> void:
	var roam := j.roam
	var band := j.c.band
	var wr := j.c.world_rules
	if band.ship == null or roam.ship_at == Vector2.INF or roam.aboard:
		return
	if ship_guarded(j) or roam.pos.distance_to(roam.ship_at) <= 2.0:
		return  # watched, on a friend's beach, or within call of the band
	var near: Roam.Party = null
	for p in roam.parties:
		if (p.kind == "raiders" or p.kind == "outlaws") and p.pos.distance_to(roam.ship_at) <= wr.ship_thief_sight:
			near = p
			break
	# Hostile country: an ill-wisher's land; or the wilds, far from any
	# farm, with raiders or outlaws about. A stranger's farm keeps an eye
	# on a ship on its beach.
	var host := _host(j, roam.ship_at)
	var hostile := host != null and Families.is_foe(wr, band, host.family)
	var chance := 0.0
	if hostile:
		chance = wr.ship_theft_day_near if near != null else wr.ship_theft_day
	elif host == null and near != null:
		chance = wr.ship_theft_day_near
	if chance <= 0.0 or r.randf() >= chance * days:
		return
	var t := Roam.Party.new()
	t.kind = "ship_thieves"
	t.ship = band.ship
	t.family = near.family if near != null else (host.family if host != null else "")
	t.name = "the thieves with your %s" % WorldTypes.SHIP_NAMES[band.ship.kind]
	t.men = wr.ship_thieves_men
	t.tier = CombatTypes.Tier.GREEN
	t.speed = wr.raider_speed
	t.pos = roam.ship_at
	t.mood = -1
	var home := ""
	if t.family != "" and j.c.world.families != null and j.c.world.families.houses.has(t.family):
		home = j.c.world.families.house(t.family).seat
	if home == "" and near != null:
		home = near.home
	if home == "" and host != null:
		home = host.id
	t.home = home
	roam.parties.append(t)
	if home != "":
		roam.set_course(t, home)
	var lost: String = WorldTypes.SHIP_NAMES[band.ship.kind]
	band.ship = null
	roam.ship_at = Vector2.INF
	roam.stop()  # the way he had planned went by her
	j.life["stolen"] = {"party": t, "year": j.c.cal.year}
	var whose := t.family if t.family != "" else "men nobody knows"
	j._say("Word comes that your %s has been taken off the beach by %s%s." % [lost, whose,
			(", who make for %s with her" % j.c.world.place(home).display_name) if j.c.world.place(home) != null else ""])
	band.log("%s's %s was stolen off the beach by %s" % [band.leader.display_name, lost, whose])
	if t.family != "" and j.c.world.families != null and j.c.world.families.houses.has(t.family) and Feud.find(band, t.family).is_empty():
		Feud.start(wr, band, t.family, "the theft of your ship", home, j.said)


## Whether the ship lies safe: watched for silver, or on a friendly beach.
static func ship_guarded(j: Journey) -> bool:
	var roam := j.roam
	var watch: Dictionary = j.life.get("watch", {})
	if not watch.is_empty() and int(watch.get("year", -1)) == j.c.cal.year \
			and MapGrid.cell_of(roam.ship_at) == (watch.cell as Vector2i):
		return true
	var host := _host(j, roam.ship_at)
	return host != null and Families.standing(j.c.band, host.family) >= j.c.world_rules.standing_well_wisher


## The settled place nearest a point on the map, within a few leagues.
static func _host(j: Journey, at: Vector2) -> Place:
	var best: Place = null
	var best_d := 6.0
	for p in j.c.world.places.values():
		if Journey.SETTLED.has(p.kind) and p.pos.distance_to(at) < best_d:
			best_d = p.pos.distance_to(at)
			best = p
	return best


## Paying a farm or a hall to watch the ship, where she is.
static func actions(j: Journey) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := j.here()
	var band := j.c.band
	var wr := j.c.world_rules
	if p == null or band.ship == null or not j.roam.aboard or not Journey.SETTLED.has(p.kind):
		return out
	var watch: Dictionary = j.life.get("watch", {})
	if Families.standing(band, p.family) >= wr.standing_well_wisher:
		return out  # friends watch her for nothing
	if not watch.is_empty() and int(watch.get("year", -1)) == j.c.cal.year and (watch.cell as Vector2i) == j.roam.cell():
		return out
	out.append({"id": "watch", "label": "Pay for a watch on your ship (%d oz)" % wr.ship_watch_ounces, "enabled": band.silver >= wr.ship_watch_ounces,
			"hint": "The men of %s will keep her while you go up-country. A ship left on a strange beach is soon some other man's." % p.display_name})
	return out


static func act(j: Journey, id: String) -> bool:
	if id != "watch":
		return false
	var wr := j.c.world_rules
	if j.c.band.silver < wr.ship_watch_ounces:
		return true
	j.c.band.silver -= wr.ship_watch_ounces
	j.life["watch"] = {"cell": j.roam.cell(), "year": j.c.cal.year}
	j._say("%s pays %d oz for a watch on his ship at %s." % [j.c.band.leader.display_name, wr.ship_watch_ounces, j.here().display_name])
	return true


## The summer's end: a ship not taken back is theirs.
static func end_of_summer(j: Journey) -> void:
	var stolen: Dictionary = j.life.get("stolen", {})
	if stolen.is_empty():
		return
	var t: Roam.Party = stolen.party
	j._say("The ship taken off the beach was not won back this summer; she is theirs now%s." % (
			", and it is between you and %s" % t.family if t.family != "" else ""))
	j.life.erase("stolen")


# --- Tidings ----------------------------------------------------------------------------------

## A tiding of the world's own life: heard at once when the band is within
## `hear_leagues` of it (or `own`, the band's own deed), else kept and told
## at the next hall, town or market. Also counted for the batches.
static func tell(j: Journey, text: String, at: Vector2, own := false) -> void:
	j.c.tally.world_clashes = int(j.c.tally.get("world_clashes", 0)) + (0 if own else 1)
	j.c.world.log(text)
	if own:
		j.roam.news.append({"at": j.roam.clock, "text": text, "pos": at, "own": true})
		return
	if j.roam.pos.distance_to(at) <= j.c.world_rules.hear_leagues:
		j._say("Word comes that %s." % text)
	else:
		j.roam.news.append({"at": j.roam.clock, "text": text, "pos": at})


## At a hall, a town or a market the band hears what has happened about
## the country since: the latest `news_per_place`, none older than
## `news_days`. The band's own deeds are told back to it as others tell them.
static func hear_news(j: Journey) -> void:
	var p := j.here()
	if p == null or not (p.has_market or p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN):
		return
	var wr := j.c.world_rules
	var told := 0
	var keep: Array[Dictionary] = []
	for n in j.roam.news:
		if j.roam.clock - float(n.at) > wr.news_days:
			continue
		if told < wr.news_per_place:
			j._say("At %s they tell that %s." % [p.display_name, n.text])
			told += 1
		else:
			keep.append(n)
	j.roam.news = keep


static func _who(j: Journey, p: Roam.Party) -> String:
	match p.kind:
		"raiders":
			return "raiders out of %s" % _home_name(j, p) if p.family != "" else "raiders"
		"merchant":
			return p.name
		"kings_ships":
			return p.name
		"outlaws":
			return "outlaws"
		"house_men", "avengers":
			return "men of %s" % p.family
		"ship_thieves":
			return "the ship-thieves"
	return p.name


static func _home_name(j: Journey, p: Roam.Party) -> String:
	var fs := j.c.world.families
	if fs != null and fs.houses.has(p.family):
		var seat := j.c.world.place(fs.house(p.family).seat)
		if seat != null:
			return seat.display_name
	return p.family


## Where a point is, in words: "off Fitjar", "near the Sogn farms".
static func _where(j: Journey, at: Vector2) -> String:
	var best: Place = null
	var best_d := INF
	for p in j.c.world.places.values():
		if p.is_open(j.c.world.year) and p.pos.distance_to(at) < best_d:
			best_d = p.pos.distance_to(at)
			best = p
	if best == null:
		return "at sea"
	var wet := j.roam.grid.is_sea(MapGrid.cell_of(at))
	return ("off %s" if wet else "near %s") % best.display_name
