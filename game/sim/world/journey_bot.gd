class_name JourneyBot
extends RefCounted
## A stand-in player with a bent: he plays a Journey the plain way a man
## leaning toward one way of life would (Way.Id), spending his points down
## that path, getting himself a hull when he can pay for one, and making
## his living by whatever is to hand until his own way pays. For tests and
## balance batches; fights are told quickly (Journey.quick).


## Years he lets pass at each spring (Years), 0 to play every summer: the
## batches set it to measure a saga that sits at home against one that
## plays. `ends` lets him end the saga when one is offered (old age, an
## arc completed); off, he always goes on.
static var let_years := 0
static var ends := false
## The raider keeps his captives bound for the slave markets; off, he
## ransoms them to their kin like anyone else (for measuring one living
## against the other, docs/design/notes/balance.md).
static var slaver := true


## Plays until the year turns (or the saga ends). Returns the steps taken.
## With `stop_at_winter` he stops when the band goes into its winter
## quarters, the winter's choices still to make (tools).
static func play_year(j: Journey, bent: int, stop_at_winter := false) -> int:
	j.quick = true
	j.stepped_winter = true
	j.played_succession = true
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
	# Never a miser's Yule when the chest can spare the little expected:
	# a ring for the man with the greatest deeds, then the least loyal.
	if not men.is_empty():
		var line := WinterHall.miser_line(c.rules, men.size(), band.silver)
		var by_need := men.duplicate()
		by_need.sort_custom(func(a: Man, b: Man) -> bool:
			var da := WinterHall.great_deed(c.rules, a)
			var db := WinterHall.great_deed(c.rules, b)
			return (da and not db) or (da == db and (a.loyalty < b.loyalty or (a.loyalty == b.loyalty and a.id < b.id))))
		for m in by_need:
			if h.gifts_total(j) >= line or band.silver < c.rules.miser_chest or h.silver_after(j) < c.rules.hall_gift_ounces[0]:
				break
			if int(h.gifts.get(m.id, 0)) == 0:
				j.winter_choose("gift+:%d" % m.id)
	# At his own hall a man with silver builds: benches before the men
	# outgrow them, then a storehouse and a byre.
	if h.can_build():
		var B := CampaignTypes.Building
		var costs: Dictionary = c.rules.building_costs
		if men.size() + 2 >= (band.hall as Hall).seats and men.size() < _band_wanted(bent) and h.silver_after(j) >= int(costs.get(B.BENCHES, 0)) + 40:
			j.winter_choose("build:%d" % B.BENCHES)
		for b in [B.STOREHOUSE, B.BYRE]:
			if h.silver_after(j) >= int(costs.get(b, 0)) + 150:
				j.winter_choose("build:%d" % b)
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
	if bent == Way.Id.VIKING and let_years <= 0:
		for i in h.talk.size():
			if str(h.talk[i].kind) == "vow":
				j.winter_choose("talk:%d:vow:0" % i)
	# The seer is asked by a man with silver to spare; the thralls are
	# watched by the careful, freed by the law-wise and the skald.
	for i in h.talk.size():
		var kind := str(h.talk[i].kind)
		if kind == "volva" and band.silver >= 60:
			j.winter_choose("talk:%d:ask" % i)
		elif kind == "thralls":
			j.winter_choose("talk:%d:%s" % [i, "free" if bent == Way.Id.LAWMAN or bent == Way.Id.SKALD else ("press" if bent == Way.Id.BERSERK else "watch")])
	# No more men than a man of his bent wants about him (a trader does not
	# feed forty), and no more than his hull will carry unless he can pay
	# for a bigger one: a band too big for its boat is stranded.
	var wanted := _band_wanted(bent)
	var keep := band.fighters().size()
	for i in h.candidates.size():
		if bool(h.candidates[i].taken):
			if keep >= wanted:
				j.winter_choose("take:%d" % i)
			else:
				keep += 1
	if band.ship != null:
		var carry := band.ship.crew_capacity(c.world_rules)
		var next_hull := 0
		for kind in Journey.HULLS:
			if int(c.world_rules.ship_crew[kind]) > carry and (next_hull == 0 or int(c.world_rules.ship_price[kind]) < next_hull):
				next_hull = int(c.world_rules.ship_price[kind])
		if band.silver < next_hull:
			var count := band.fighters().size()  # the leader takes a thwart too
			for i in h.candidates.size():
				if bool(h.candidates[i].taken):
					if count >= carry:
						j.winter_choose("take:%d" % i)
					else:
						count += 1
	# More men than benches and thwarts, or than a man of his bent wants
	# about him (the quiet years' recruits fill every bench): the least
	# loyal go, never his second, his war-leader or a son of the house.
	var over := maxi(men.size() - c.room(), men.size() + 1 - _band_wanted(bent))
	if over > 0:
		var sons := {}
		for ch in band.sons:
			sons[int(ch.get("man_id", -1))] = true
		var spare: Array[Man] = []
		for m in men:
			if m.id != band.sworn_second_id and m.id != band.war_leader_id and not sons.has(m.id) \
					and m.lent_by == "" and int(h.gifts.get(m.id, 0)) == 0:
				spare.append(m)
		spare.sort_custom(func(a: Man, b: Man) -> bool: return a.loyalty < b.loyalty or (a.loyalty == b.loyalty and a.id < b.id))
		for m in spare.slice(0, over):
			j.winter_choose("let:%d" % m.id)
	var guard := 0
	while j.in_winter() and not h.resolved and guard < 10:
		guard += 1
		j.winter_choose("next")
	if j.in_winter():
		_spend(j, bent)
		# An old man steps down for his son; otherwise the years he lets pass.
		var old := c.band.leader != null and c.band.leader.alive and c.band.leader.age >= c.rules.step_down_age + 4 and c.pending_death.is_empty()
		if old:
			for cand in Succession.candidates(c):
				if str(cand.kind) == "son":
					j.winter_choose("stepdown:" + str(cand.id))
					break
		if let_years > 0 and h.step_down == "" and Years.blocked(j) == "":
			j.winter_choose("years:%d" % let_years)
			j.winter_choose("offers:accept")
	j.winter_end()


## How many men a man of his bent wants about him, at most.
static func _band_wanted(bent: int) -> int:
	match bent:
		Way.Id.VIKING:
			return 40
		Way.Id.KINGS_MAN:
			return 30
		Way.Id.BERSERK:
			return 20
		Way.Id.SKALD:
			return 18
		Way.Id.LAWMAN:
			return 16
	return 14


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
				if o.id == "sail_iceland" and (band.outlawry == WorldTypes.Outlawry.FULL or bent == Way.Id.TRADER):
					return "sail_iceland"
				if o.id == "hear":
					return "hear"
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
		"saga":
			return _answer_saga(j, d, bent)
		"thing":
			return ThingPlay.bot(j, d, bent)
		"land":
			return Landtake.bot(j, d, bent)
		"unfree":
			return Thralls.bot(j, d, bent)
		"omen":
			return Omens.bot(j, d, bent)
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


## The death card and the grave-ale: the first heir the hall would name, a
## plain feast (an open-handed one from a full chest), vengeance when it is
## owed (a peaceful vow otherwise), the island for a challenger; the saga
## goes on unless he is told he may end it.
static func _answer_saga(j: Journey, d: Dictionary, _bent: int) -> String:
	var ids := []
	for o in d.options:
		if o.get("enabled", true):
			ids.append(str(o.id))
	match str(d.step):
		"death":
			if ends and ids.has("end"):
				return "end"
			return "ale" if ids.has("ale") else str(ids[0])
		"feast":
			if j.c.band.silver >= 150 and not ids.is_empty():
				return str(ids[0])
			return str(ids[1]) if ids.size() > 2 else str(ids[-1])
		"vow":
			for id in ids:
				if str(id).begins_with("vengeance:"):
					return str(id)
			return "peace"
		"challenge":
			# The men first, then silver he can spare, then a champion who is
			# the better man, else the island himself.
			if ids.has("back"):
				return "back"
			var ch := j.c.band.man_by_id(int(d.man))
			if ids.has("pay") and ch != null and j.c.band.silver >= 2 * Succession.buyoff_price(j.c, ch):
				return "pay"
			var champ := Succession.champion_for(j.c, ch)
			if ids.has("champion") and ch != null and champ != null and j.c.band.leader != null \
					and champ.total_stats() + 2 * int(champ.tier) > j.c.band.leader.total_stats() + 2 * int(j.c.band.leader.tier) \
					and champ.total_stats() + 2 * int(champ.tier) >= ch.total_stats() + 2 * int(ch.tier):
				return "champion"
			return "fight"
		"arc":
			return "end" if ends else "go_on"
	return str(ids[0]) if not ids.is_empty() else str(d.options[0].id)


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
	# The law, the land and the unfree first: an outlaw's way out, the
	# land he can buy, the men he left at home, a man held for sale.
	if _law_land(j, bent, ids):
		return
	# A watch on the ship where she lies, once he has learned what a strange
	# beach costs (she was taken from him before), or when it is nothing to him.
	if ids.has("watch") and band.ship != null and (band.silver >= 120 or (j.life.has("stolen") and band.silver >= 20)) \
			and int(j.life.get("bot_watched:" + here.id, -1)) != c.cal.year:
		j.life["bot_watched:" + here.id] = c.cal.year  # once a place a summer
		j.act("watch")
		return
	# A ship too battered to trust is mended first.
	if ids.has("mend") and band.ship.damage >= wr.ship_unsailable_damage - 1:
		j.act("mend")
		return
	# A hull, when he has none he can use and can pay for one that will
	# carry his men; a knarr for a trader who can afford the hold. Men lent
	# for the summer are not counted: they go home in the autumn.
	var men := 0
	for m in band.fighters():
		if m.lent_by == "":
			men += 1
	for kind in Journey.HULLS:
		var id := "hull:%d" % kind
		if not ids.has(id):
			continue
		var carries: bool = int(wr.ship_crew[kind]) >= men and int(wr.ship_min_crew[kind]) <= men
		var want := carries and j.sail_speed() <= 0.0 and band.silver >= j.hull_cost(kind) + 8
		if bent == Way.Id.TRADER and kind == WorldTypes.ShipKind.KNARR and carries and band.silver >= j.hull_cost(kind) + 40:
			want = true
		# A lord with a great band and the silver for it gets his longship.
		if kind == WorldTypes.ShipKind.LONGSHIP and carries and band.silver >= j.hull_cost(kind) + 100 \
				and (bent == Way.Id.VIKING or bent == Way.Id.KINGS_MAN):
			want = true
		if want:
			j.act(id)
			return
	# A farmer to stand up for, for a man who can fight: whole, blooded,
	# strong, and not beaten on the island already this summer.
	var fighter: bool = band.leader.stat(CombatTypes.Stat.MIGHT) + band.leader.stat(CombatTypes.Stat.SKILL) >= 9
	var champion: bool = band.leader.stat(CombatTypes.Stat.MIGHT) + band.leader.stat(CombatTypes.Stat.SKILL) >= 10 \
			and band.leader.tier >= CombatTypes.Tier.BLOODED and band.leader.healing_turns == 0 \
			and int(j.life.get("island_lost", -1)) != c.cal.year
	if ids.has("champion") and champion:
		j.act("champion")
		return
	# A feud to plead when at a Thing, or a house he promised to speak for;
	# work in hand to finish.
	for id in ids:
		if str(id).begins_with("case:") or str(id).begins_with("speak:") or str(id).begins_with("answer:") or str(id).begins_with("case_land:"):
			j.act(id)
			return
	if _houses(j, bent, ids):
		return
	if not j.contract.is_empty() and j.days_to(str(j.contract.to_place)) > 0:
		if j.sail(str(j.contract.to_place)) or not j.decisions.is_empty():
			return
	if _hire(j, bent, ids):
		return
	if ids.has("thralls_home") and band.thralls.size() < 6:
		j.act("thralls_home")
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
			# A farmer's champion is the honest half of his living.
			if ids.has("champion") and band.leader.healing_turns == 0 and int(j.life.get("island_lost", -1)) != c.cal.year:
				j.act("champion")
				return
			# While men still speak well enough of him, and not every week:
			# a few overbearing challenges a summer, not a country's worth.
			var called := int(j.life.get("bot_called:%d" % c.cal.year, 0))
			if band.honor > wr.holmgang_outlaw_honor + 3 * wr.holmgang_honor and called < 3:
				if ids.has("holmgang"):
					j.life["bot_called:%d" % c.cal.year] = called + 1
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
			if ids.has("work:0") and _work_fits(j):
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
		if ids.has(id) and (id != "work:0" or _work_fits(j)):
			j.act(id)
			return
	var living := _nearest(j, func(q: Place) -> bool:
		return Callings.can_counsel(wr, c.world, band, q) or (champion and Callings.can_champion(wr, c.world, band, q)) \
				or ((q.kind == WorldTypes.PlaceKind.HALL or q.kind == WorldTypes.PlaceKind.TOWN) and not j._offers.has(q.id)))
	if living != "" and _go(j, living):
		return
	# Nothing to hand here: work his way somewhere else (a place at another
	# man's oars, a day's labour), or pay for passage to the nearest hall.
	for id in ["crew", "labour", "fish"]:
		if ids.has(id):
			j.act(id)
			return
	# A man with little in his chest does not sit listening for weeks: he
	# goes where there are fields to work.
	if band.silver < 80:
		var fields := _nearest(j, func(q: Place) -> bool: return Journey.SETTLED.has(q.kind) and not TradeRoad._done(j, "labour", q.id) \
				and not Families.is_foe(wr, band, q.family))
		if fields != "" and _go(j, fields):
			return
	var cheapest := ""
	var cost := 1 << 20
	for o in j.passages():
		if j.sail_speed() <= 0.0 and ids.has("passage:" + str(o.id)) and int(o.cost) < cost and int(o.cost) * 3 <= band.silver:
			cost = int(o.cost)
			cheapest = "passage:" + str(o.id)
	# Not back and forth: a passage, then a fortnight's living where it lands.
	var today := c.cal.year * 400 + c.cal.day
	if cheapest != "" and today - int(j.life.get("bot_passage", -100)) >= 15:
		j.life["bot_passage"] = today
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
	if ids.has("heal"):
		j.act("heal")
		return true
	# Men from friends, while his hull will still carry them all.
	if ids.has("men"):
		var crew := band.ship.crew_capacity(wr) if band.ship != null else 1 << 20
		var lend := int(wr.men_lent.get(Families.support_step(wr, band, j.here().family), 0))
		if band.fighters(c.rules).size() + lend <= crew and (bent != Way.Id.TRADER or band.fighters(c.rules).size() < 4):
			j.act("men")
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
	# The king's man takes his quarrel to the king.
	if ids.has("king_justice"):
		j.act("king_justice")
		return true
	if bent == Way.Id.KINGS_MAN and band.vengeance != "" and band.rank >= wr.king_justice_rank and int(band.law.get("king_justice", -1)) != c.cal.year:
		var court := _nearest(j, func(q: Place) -> bool:
			var k := Outlawry._king_of(j, q)
			return k != null and FactionAI.relation(c.world, k.id, FactionAI.BAND) >= wr.king_justice_relation)
		if court != "" and _go(j, court):
			return true
	if not band.pledges.is_empty() or _thing_due(j):
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
	# Already there: going would pass no time, and he would ask again.
	if to == j.c.band.location or not j.go_to_place(to):
		return false
	j.travel()
	return true


## Whether the lord's first work here is one his band can do: a fight only
## with men enough for it.
static func _work_fits(j: Journey) -> bool:
	var list := j._work_here()
	if list.is_empty():
		return false
	var o: Dictionary = list[0]
	if not o.has("battle"):
		return true
	return int(o.battle.attackers) <= j.c.band.fighters(j.c.rules).size() * j.c.world_rules.raid_odds_max


## A place worth raiding with the men in hand.
static func _raidable(j: Journey, p: Place) -> bool:
	var c := j.c
	if not Journey.RAID_KINDS.has(p.kind) or p.id == c.band.home or p.wealth < c.world_rules.raid_min_wealth or not Landtake.raidable(j, p):
		return false
	if int(c.band.raided.get(p.id, -1)) == c.cal.year:
		return false
	# He does not raid his own friends and kin.
	if Families.is_friend(c.world_rules, c.band, p.family):
		return false
	# Green farmers at the odds he will take; seasoned men only when he has
	# the better numbers, as a man who read his scout's report would.
	var a := Raiding.assess(c.world_rules, c.world, p, c.band)
	var odds := c.world_rules.raid_odds_max if int(a.tier) <= CombatTypes.Tier.GREEN else (0.8 if int(a.tier) == CombatTypes.Tier.BLOODED else 0.6)
	return a.defenders <= c.band.fighters(c.rules).size() * odds


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
	if j.c.band.captives <= 0 or (bent == Way.Id.VIKING and slaver):
		return false
	if (bent == Way.Id.LAWMAN or bent == Way.Id.SKALD) and ids.has("free"):
		j.act("free")
		return true
	if ids.has("ransom"):
		j.act("ransom")
		return true
	return false


# --- Law, land and the unfree (docs/design/notes/law-land.md) -------------------------

## A summons he will answer, or a land quarrel he will plead, this summer.
static func _thing_due(j: Journey) -> bool:
	var band := j.c.band
	if Outlawry.is_outlawed(band, j.c.cal):
		return false
	var summons: Dictionary = band.law.get("summons", {})
	for fam in summons:
		var sm: Dictionary = summons[fam]
		if int(sm.get("year", -1)) == j.c.cal.year and bool(sm.get("answer", false)):
			return true
	return not (band.law.get("land_case", {}) as Dictionary).is_empty()


## The law, the land and the unfree, as a man of his bent would have them:
## an outlaw makes his peace or goes west (with his own ship when he has
## one); a man held for sale is bought back or taken; land is bought when
## the silver is well over what is needed and the band has no more than a
## couple of units; a man is left at the farm when there are thralls to
## watch; the law-wise and the skald free a thrall now and then; land is
## taken in Iceland when the band is there. True when he did something.
static func _law_land(j: Journey, bent: int, ids: Dictionary) -> bool:
	var c := j.c
	var band := c.band
	var od := Outlawry.bot_deed(j, bent, ids)
	if od == "*":
		return true  # on his way to a king's hall for his peace
	if od != "":
		j.act(od)
		return true
	if Outlawry.is_outlawed(band, c.cal) and Outlawry.in_realm(j) and j.sail_speed() > 0.0 and j.roam.aboard \
			and (band.outlawry == WorldTypes.Outlawry.FULL or j.days_left() < 60):
		var haven := Outlawry._west_haven(j)
		if haven != "" and haven != band.location and _go(j, haven):
			return true
	for id in ids:
		if str(id).begins_with("ransom_taken:") and band.silver >= 60:
			j.act(id)
			return true
		if str(id).begins_with("rescue_taken:") and band.fighters(c.rules).size() >= 8:
			j.act(id)
			return true
	if not band.taken.is_empty() and band.location != str(band.taken[0].at) and band.silver >= 60:
		var to := str(band.taken[0].at)
		if j.days_to(to) >= 0 and j.days_to(to) + 10 <= j.days_left() and _go(j, to):
			return true
	if ids.has("landtake"):
		j.act("landtake")
		return true
	if ids.has("buy_land") and band.land < 6 and band.silver >= 200 + 60 * band.land:
		j.act("buy_land")
		return true
	if ids.has("keepers") and band.thralls.size() >= 3 and band.keepers.is_empty():
		j.act("keepers")
		return true
	if ids.has("manumit") and (bent == Way.Id.LAWMAN or bent == Way.Id.SKALD) and band.thralls.size() >= 2:
		j.act("manumit")
		return true
	# Iceland, once it is open and known: an outlaw's road, and the trader's.
	var iceland := c.world.place("iceland")
	if not band.settled_iceland and iceland != null and iceland.is_open(c.world.year) and band.knows("iceland") \
			and (band.outlawry == WorldTypes.Outlawry.FULL or (bent == Way.Id.TRADER and band.ship != null and band.ship.kind == WorldTypes.ShipKind.KNARR)) \
			and band.location != "iceland" and j.days_to("iceland") >= 0 and j.days_to("iceland") + 10 <= j.days_left():
		if _go(j, "iceland"):
			return true
	return false
