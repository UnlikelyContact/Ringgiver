class_name Journey
extends RefCounted
## The player's summer on the map, one decision at a time (concept.md,
## "Ways of life" and "Picking your fights"). Sandbox.summer is an AI
## standing in for the player; this is the player: he sails where he will,
## and at each place does what the place and his way of life allow. The
## world modules do the work; this strings them together and stops
## wherever a person must answer.
##
## The shape: `decisions` is a queue of things that must be answered
## before anything else (a fight offered, a merchant met, a king's demand);
## `answer(id)` answers the first. A fight the player will fight himself
## is left in `fight` for the battle view, which calls `fight_done(result)`.
## With `quick` set the leader AIs fight it out at once (tests, and "let
## the saga tell it"). Everything the player should read goes to `said`.

const RAID_KINDS := [WorldTypes.PlaceKind.FARMSTEAD, WorldTypes.PlaceKind.HALL, WorldTypes.PlaceKind.TOWN]
const SPINE_LABELS := {"serve": "Serve him", "resist": "Resist him", "ignore": "Stand aside",
	"fight_for_harald": "Fight for Harald", "fight_against": "Fight against Harald", "join_rollo": "Sail west with Rollo",
	"back_eric": "Back Eric", "betray_eric": "Betray Eric", "acclaim": "Acclaim him"}

var c: Campaign
var quick := false
var said := PackedStringArray()
var decisions: Array[Dictionary] = []
## A fight for the battle view: {offer, built, ctx}. Empty when there is none.
var fight := {}
## Where the ship is bound, when a voyage was interrupted.
var destination := ""
## Work taken that needs a voyage: done on arrival at its `to_place`.
var contract := {}
## The band is making for its winter quarters.
var wintering := false
## What the last winter did, for the screen that reads it out.
var winter_report := PackedStringArray()
var _rng: SimRng
var _n := 0
var _offers := {}  # place id -> {day, list}: the work on offer, rolled once a visit
var _traded_at := ""  # the place whose market the band has paid its days at
var _legs := 0


## A new saga: a man of the given way (Way.Id) and name, at home in
## western Norway, in the spring of the first year.
static func begin(seed_in: int, way: int, leader_name: String, home := "hardanger") -> Journey:
	var j := Journey.new()
	j.c = Campaign.new(seed_in)
	j.c.start_as(way, leader_name)
	var wr := WorldRules.new()
	Sandbox.setup(j.c, wr, home)
	j.c.world.salt = seed_in
	var d := Way.def(way)
	var band := j.c.band
	band.ship = Ship.make(d.ship)
	if band.gift("knows_markets", false):
		# The trader knows the coast from Hålogaland to Hedeby.
		for p in j.c.world.places.values():
			if p.region <= WorldTypes.Region.HALOGALAND or p.region == WorldTypes.Region.DENMARK:
				band.known_places[p.id] = true
	var home_place := j.c.world.place(home)
	if home_place != null and home_place.faction_id != "" and int(band.gift("lords_favour", 0)) != 0:
		FactionAI.shift(j.c.world, home_place.faction_id, FactionAI.BAND, int(band.gift("lords_favour", 0)))
	if band.gift("fury", false):
		# No lord trusts a berserk until he has shown himself worth it.
		for fid in j.c.world.factions:
			FactionAI.shift(j.c.world, fid, FactionAI.BAND, -15)
	j.begin_summer()
	return j


# --- The year ------------------------------------------------------------------

func begin_summer() -> void:
	var cal := c.cal
	c.band.year = cal.year
	c.world.year = cal.year
	cal.day = 1
	c._summer_wins = 0
	_rng = c.rng.fork("journey:%d" % cal.year)
	_n = 0
	_offers.clear()
	_traded_at = ""
	destination = ""
	wintering = false
	_say("Spring of %d. The ice is off the fjord at %s." % [cal.year, here().display_name])
	if Outlawry.is_outlawed(c.band, cal):
		_say("%s sails as an outlaw this year: the halls are shut to him." % c.band.leader.display_name)
	for ev in Timeline.pending(c.world_rules, c.world, cal.year):
		var opts: Array[Dictionary] = []
		for o in Timeline.outcome_options(ev):
			opts.append({"id": o, "label": SPINE_LABELS.get(o, str(o).capitalize())})
		decisions.append({"kind": "spine", "event": ev, "text": str(ev.text), "options": opts})
	for ev in Feud.summer_events(_fork("feuds"), c.world_rules, c.world, c.band, said):
		if ev.has("battle_required"):
			var br: Dictionary = ev.battle_required
			var f := Feud.find(c.band, ev.get("family", ""))
			var level: int = f.get("level", 1) if not f.is_empty() else 1
			_offer_fight(br.get("kind", "feud_ambush"), br.tier, Sandbox._forced(c, br.attackers), false,
					c.world_rules.feud_stat_base + level - 1, false, false, {"kind": "feud"}, str(br.text), false)
		elif ev.get("kind", "") == "demand":
			var family: String = ev.family
			var ask := Feud.offer_settlement(c.world_rules, c.band, family)
			decisions.append({"kind": "demand", "family": family, "ask": ask,
					"text": "%s send word: %d oz of silver, and the feud is ended." % [family, ask],
					"options": [
						{"id": "pay", "label": "Pay %d oz" % ask, "enabled": c.band.silver >= ask},
						{"id": "thing", "label": "Answer at the Thing"},
						{"id": "refuse", "label": "Refuse"}]})
	_settle()


## The decision that must be answered now, or {}.
func current() -> Dictionary:
	return decisions[0] if not decisions.is_empty() else {}


## Whether the player is free to act: nothing to answer, no fight on.
func can_act() -> bool:
	return decisions.is_empty() and fight.is_empty() and not c.over


func here() -> Place:
	return c.world.place(c.band.location)


func days_left() -> int:
	return c.cal.summer_left(c.world_rules.summer_days)


# --- Answering ----------------------------------------------------------------

## Answers the current decision with one of its options' ids.
func answer(id: String) -> void:
	if decisions.is_empty():
		return
	var d: Dictionary = decisions.pop_front()
	var wr := c.world_rules
	match d.kind:
		"spine":
			var ev: Dictionary = d.event
			var r := Timeline.fire(_fork("spine:" + str(ev.id)), wr, c.world, c.band, ev, id, said)
			if r.has("place_opened"):
				c.band.known_places[r.place_opened] = true
			c.tally.spine = c.tally.get("spine", 0) + 1
			if r.has("battle_required"):
				var br: Dictionary = r.battle_required
				_offer_fight(br.get("kind", ev.id), br.tier, Sandbox._forced(c, br.attackers), br.get("side", "") != "against",
						wr.spine_stat, false, false, {"kind": "spine", "event": ev, "choice": id}, str(br.text), true)
		"demand":
			match id:
				"pay":
					if Feud.settle(wr, c.band, d.family, d.ask, said):
						Way.add_deed(c.band, Way.Id.LAWMAN, wr.deed_settle)
				"thing":
					var f := Feud.find(c.band, d.family)
					if not f.is_empty():
						f["at_thing"] = c.cal.year
					_say("%s will answer %s at the Thing this summer." % [c.band.leader.display_name, d.family])
				_:
					Feud.escalate(wr, c.band, d.family, said)
		"merchant":
			var enc: Dictionary = d.enc
			match id:
				"buy":
					Encounters.buy_from_merchant(wr, c.band, enc, int(enc.offer.units), said)
				"rob":
					var req := Encounters.rob_merchant(wr, enc)
					_offer_fight("merchant", req.tier, req.attackers, true, wr.sea_fight_stat, true, false,
							{"kind": "rob", "req": req}, str(req.text), true)
				_:
					_say("The knarr goes on its way.")
		"fight":
			_answer_fight(d, int(id))
			return  # _answer_fight settles when the fight is over
	_settle()


func _answer_fight(d: Dictionary, choice: int) -> void:
	var offer: FightOffer = d.offer
	choice = c.settle_choice(offer, choice)
	if choice == FightOffer.Choice.FADE_AWAY:
		c.fade(offer)
		_say("%s does not care to fight today, and leads his men away." % c.band.leader.display_name)
		_after_fight(d.ctx, null)
		_settle()
		return
	var built := c.build_fight(offer, choice)
	if quick:
		var result: BattleResult = (built.battle as Battle).run()
		var told := c.conclude_fight(offer, built, result)
		_tell_fight(result, told)
		_after_fight(d.ctx, result)
		_settle()
		return
	(built.battle as Battle).clear_ai(0)
	fight = {"offer": offer, "built": built, "ctx": d.ctx}


## The battle view has fought `fight` out. Returns the lines of what it
## left behind (Aftermath), for the result panel.
func fight_done(result: BattleResult) -> PackedStringArray:
	if fight.is_empty():
		return PackedStringArray()
	var f := fight
	fight = {}
	var told := c.conclude_fight(f.offer, f.built, result)
	_tell_fight(result, told)
	var mark := said.size()
	_after_fight(f.ctx, result)
	var lines: PackedStringArray = told.lines
	for i in range(mark, said.size()):
		lines.append(said[i])
	_settle()
	return lines


func _tell_fight(result: BattleResult, told: Dictionary) -> void:
	_say("The fight is over: %s." % result.outcome_text(0))
	for line in told.lines:
		_say(line)


# --- Fights and what follows them ------------------------------------------------

func _offer_fight(kind: String, tier: CombatTypes.Tier, size: int, attacking: bool, stat: int, at_sea: bool,
		cornered: bool, ctx: Dictionary, text: String, front: bool) -> void:
	var offer := c.offer_fight(kind, tier, size, attacking, stat, at_sea, cornered)
	var opts: Array[Dictionary] = []
	if offer.they_know_first:
		opts.append({"id": str(FightOffer.Choice.TAKE_THE_FIELD), "label": "Fight"})
	for ch in offer.options():
		opts.append({"id": str(ch), "label": FightOffer.CHOICE_TITLES[ch]})
	var d := {"kind": "fight", "offer": offer, "ctx": ctx, "text": "%s %s You have %d men fit to fight." % [text, offer.brief(), offer.our_men],
			"options": opts}
	if front:
		decisions.push_front(d)
	else:
		decisions.append(d)


## What the fight was for, once it is over (`result` null: the band faded).
func _after_fight(ctx: Dictionary, result: BattleResult) -> void:
	var wr := c.world_rules
	var won := result != null and result.winner == 0
	match ctx.get("kind", ""):
		"sea":
			if result != null:
				Encounters.after_battle(wr, c.band, ctx.req, won, said)
		"rob":
			if result != null:
				Encounters.after_battle(wr, c.band, ctx.req, won, said)
				if won:
					Way.add_deed(c.band, Way.Id.VIKING, wr.deed_rob)
		"raid":
			var target: Place = ctx.place
			if result != null:
				var take := Raiding.after_raid(_fork("after_raid"), wr, c.world, c.band, target, won, said)
				if won:
					Loyalty.share_plunder(c.rules, c.band, take.get("silver", 0), c.rules.fair_leader_share, said)
					if target.faction_id != "":
						FactionAI.shift(c.world, target.faction_id, FactionAI.BAND, -wr.raid_relation_hit)
					Way.add_deed(c.band, Way.Id.VIKING, wr.deed_raid)
				c.tally.raids = c.tally.get("raids", 0) + 1
			c.cal.advance_days(wr.raid_days)
		"contract":
			var o: Dictionary = ctx.contract
			Contracts.complete(wr, c.world, c.band, o, won, said)
			if won:
				Way.add_deed(c.band, Way.Id.KINGS_MAN, wr.deed_contract)
				Sandbox._promote(c, said)
				c.tally.contracts = c.tally.get("contracts", 0) + 1
			c.cal.advance_days(int(o.get("days", 10)))
		"spine":
			Timeline.resolve(wr, c.world, c.band, ctx.event, ctx.choice, won, said)
		"duel":
			var outcome := -1 if result == null or result.winner < 0 else (1 if won else 0)
			Callings.after_holmgang(wr, c.world, c.band, ctx.place, ctx.terms, outcome, false, said, _fork("holm_feud"))
			c.cal.advance_days(wr.holmgang_days)
		"champion":
			var came := -1 if result == null or result.winner < 0 else (1 if won else 0)
			Callings.after_champion(wr, c.world, c.band, ctx.place, came, said)
			c.cal.advance_days(wr.holmgang_days)
	if c.over:
		_say("The saga of %s ends here: %s." % [Way.title(c.band), c.over_reason])


# --- Sailing --------------------------------------------------------------------

## Whether the band knows a way to `to` and how long it takes: days, or -1.
func days_to(to: String) -> int:
	if to == c.band.location:
		return 0
	var route := Voyage.plan(c.world, c.band.location, to, c.band.known_places)
	return -1 if route.is_empty() else Voyage.route_days(c.world, route)


## Sets sail for `to`. The voyage stops for whatever is met and goes on
## when it has been answered.
func sail(to: String) -> void:
	if not can_act() or to == c.band.location:
		return
	destination = to
	_legs = 0
	_traded_at = ""
	_voyage()
	_settle()


func _voyage() -> void:
	_legs += 1
	var to := destination
	var vr := Voyage.sail(_fork("leg"), c.world_rules, c.world, c.band, c.cal, to, said)
	for enc in vr.encounters:
		if enc.has("battle_required"):
			var br: Dictionary = enc.battle_required
			var stat := c.world_rules.levy_stat if br.get("kind", "") == "levy" else c.world_rules.sea_fight_stat
			_offer_fight(br.get("kind", "sea fight"), br.tier, Sandbox._forced(c, br.attackers), false, stat, true, false,
					{"kind": "sea", "req": br}, "", false)
		elif enc.has("offer"):
			var offer: Dictionary = enc.offer
			var room := Market.cargo_room(c.world_rules, c.band)
			var n := mini(mini(int(offer.units), room), c.band.silver / maxi(1, int(offer.price)))
			decisions.append({"kind": "merchant", "enc": enc, "text": str(enc.text), "options": [
				{"id": "buy", "label": "Buy %d for %d oz" % [n, n * int(offer.price)], "enabled": n > 0},
				{"id": "rob", "label": "Rob him"},
				{"id": "pass", "label": "Sail on"}]})
	if vr.arrived:
		destination = ""
		Knowledge.reveal(c.world, c.band, to, said)
	elif vr.wrecked or vr.reason != "battle" and vr.reason != "" or _legs >= 8:
		destination = ""  # wrecked, too late in the year, no way known: the voyage ends where it is
	elif vr.encounters.is_empty():
		destination = ""


# --- What can be done here ---------------------------------------------------------

## The deeds open at this place: [{id, label, hint, enabled}]. Trading has
## its own calls (`market`, `buy`, `sell`).
func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_act():
		return out
	var wr := c.world_rules
	var p := here()
	var band := c.band
	var at_home := p.id == band.home
	var closed := Outlawry.halls_closed(band, c.cal)
	if RAID_KINDS.has(p.kind) and not at_home and p.wealth > 0:
		var a := Raiding.assess(wr, c.world, p, band)
		var fresh := int(band.raided.get(p.id, -1)) != c.cal.year
		out.append({"id": "raid", "label": "Raid %s" % p.display_name, "enabled": fresh,
				"hint": ("About %d %s defenders%s; near %d oz to take. %s will not forget it." % [a.defenders, CombatTypes.TIER_NAMES[a.tier],
						" (the beacons are lit)" if a.beacons else "", roundi(a.expected_plunder * float(band.gift("raid_plunder", 1.0))),
						p.family.capitalize() if p.family != "" else "They"]) if fresh else "You have been here this year: what is left is hidden or fled."})
		if p.kind == WorldTypes.PlaceKind.FARMSTEAD:
			out.append({"id": "strandhogg", "label": "Strandhögg", "hint": "A quick shore raid for cattle and stores: %d rations and a little silver, no battle." % wr.strandhogg_food})
	if not closed:
		var i := 0
		for o in _work_here():
			var label := "%s (%d oz)" % [str(o.text).capitalize(), roundi(float(o.pay) * float(band.gift("contract_pay", 1.0)))]
			out.append({"id": "work:%d" % i, "label": label, "hint": "A lord's work: about %d days." % int(o.get("days", 10)),
					"enabled": contract.is_empty()})
			i += 1
		if Callings.can_verse(c.world, band, p):
			out.append({"id": "verse", "label": "Speak a verse before the lord", "hint": "Wits and fame against %d: a ring if it pleases him." % Callings.verse_need(wr, band, p)})
	if Callings.can_counsel(wr, c.world, band, p):
		out.append({"id": "counsel", "label": "Give counsel in a dispute", "hint": "Wits against %d: a fee, honor and %s's friendship at the Thing." % [
				wr.counsel_difficulty + (wr.counsel_thing_harder if p.kind == WorldTypes.PlaceKind.THING_SITE else 0), p.family]})
	if Callings.can_champion(wr, c.world, band, p):
		out.append({"id": "champion", "label": "Stand in the farmer's place",
				"hint": "A berserk has called %s out for their land. Meet him on the island yourself: %d oz, honor and their friendship if you blood him." % [
						p.family, wr.champion_fee + p.wealth / wr.champion_wealth_per_oz]})
	if Callings.can_challenge(wr, c.world, band, p):
		var t := Callings.holmgang_terms(wr, c.world, band, p)
		out.append({"id": "holmgang", "label": "Call %s to the island" % p.family,
				"hint": ("To end the feud, and for %d oz." % t.stake) if t.feud else ("For %d oz of what they own. It costs honor: %d." % [t.stake, t.honor_cost])})
	if p.kind == WorldTypes.PlaceKind.THING_SITE and not Outlawry.is_outlawed(band, c.cal):
		for f in band.unsettled_feuds():
			var family := str(f.get("family", f.get("against", "")))
			out.append({"id": "case:" + family, "label": "Plead against %s" % family,
					"hint": "Support, procedure, the standoff, the verdict. %d days." % wr.thing_days,
					"enabled": band.silver >= wr.thing_min_silver})
	if band.captives > 0 and Market.captive_price(wr, p) > 0:
		out.append({"id": "captives", "label": "Sell %d captives" % band.captives, "hint": "%d oz for the next." % Market.captive_price(wr, p)})
	if not p.has_market and p.kind != WorldTypes.PlaceKind.BAY and p.kind != WorldTypes.PlaceKind.THING_SITE:
		out.append({"id": "rations", "label": "Buy rations", "hint": "Five rations at %d oz each." % wr.farm_food_price,
				"enabled": band.silver >= wr.farm_food_price})
	if band.ship != null and band.ship.damage > 0:
		out.append({"id": "mend", "label": "Mend the ship", "hint": "%d days on the beach for each of her %d hurts%s." % [
				wr.ship_mend_days, band.ship.damage, "" if band.ship.can_sail(wr) else ". She cannot sail as she is"]})
	out.append({"id": "listen", "label": "Wait and listen", "hint": "%d days. At a hall or a market there is talk of places you do not know." % wr.listen_days})
	if at_home:
		out.append({"id": "winter", "label": "Winter here", "hint": "End the summer: the hall, the men, the long dark."})
	else:
		var d := days_to(band.home)
		out.append({"id": "home", "label": "Sail home for the winter", "hint": ("%d days' sail." % d) if d >= 0 else "No way home is known.", "enabled": d >= 0})
	return out


## Does one of `actions()` by id.
func act(id: String) -> void:
	if not can_act():
		return
	var wr := c.world_rules
	var p := here()
	var band := c.band
	if id == "raid":
		band.raided[p.id] = c.cal.year
		var req := Raiding.raid(_fork("raid"), wr, c.world, band, p, said)
		if not req.is_empty():
			var center := int(wr.defender_stat_by_kind[p.kind] + p.defenses * wr.defender_stat_per_defense)
			_offer_fight("raid on %s" % p.display_name, req.tier, req.defenders, true, clampi(center, 1, 10), false, false,
					{"kind": "raid", "place": p}, "", true)
	elif id == "strandhogg":
		Raiding.strandhogg(_fork("strand"), wr, c.world, band, p, said)
		Way.add_deed(band, Way.Id.VIKING, wr.deed_strandhogg)
		c.cal.advance_days(1)
	elif id.begins_with("work:"):
		var list := _work_here()
		var i := int(id.trim_prefix("work:"))
		if i < list.size() and contract.is_empty():
			var o: Dictionary = list[i]
			list.clear()  # a lord has one piece of work for a man in a year
			_take_work(o)
	elif id == "verse":
		Callings.verse(_fork("verse"), wr, c.world, band, p, said)
		c.cal.advance_days(wr.verse_days)
	elif id == "counsel":
		Callings.counsel(_fork("counsel"), wr, c.world, band, p, said)
		c.cal.advance_days(wr.counsel_days)
	elif id == "holmgang":
		_holmgang(p)
	elif id == "champion":
		var foe := Callings.bully(_fork("bully"), wr, p, c.combat_rules)
		_say("%s waits on the island; %s goes out to him in the farmer's place." % [foe.display_name, band.leader.display_name])
		_duel(foe, {"kind": "champion", "place": p})
	elif id.begins_with("case:"):
		_plead(id.trim_prefix("case:"))
	elif id == "captives":
		Market.sell_captives(wr, p, band, band.captives, said)
	elif id == "rations":
		Market.buy(wr, p, band, WorldTypes.Good.GRAIN, 5, said)
	elif id == "mend":
		if band.ship != null and band.ship.damage > 0:
			band.ship.damage -= 1
			c.cal.advance_days(wr.ship_mend_days)
			_say("The crew haul the ship up at %s and mend her (%d days)%s." % [p.display_name, wr.ship_mend_days,
					"" if band.ship.damage > 0 else "; she is sound again"])
	elif id == "listen":
		var heard := Knowledge.hear_rumor(_fork("rumor"), wr, c.world, band, p.id, said)
		if heard == "":
			_say("%d days pass at %s, and nothing new is heard." % [wr.listen_days, p.display_name])
		c.cal.advance_days(wr.listen_days)
	elif id == "winter":
		wintering = true
	elif id == "home":
		wintering = true
		destination = band.home
		_legs = 0
		_voyage()
	_settle()


func _work_here() -> Array:
	var p := here()
	if not _offers.has(p.id):
		_offers[p.id] = Contracts.offers(_fork("work"), c.world_rules, c.world, c.band, p.id)
	return _offers[p.id]


func _take_work(o: Dictionary) -> void:
	var wr := c.world_rules
	var r := Contracts.accept(wr, c.world, c.band, o, said)
	if r.has("battle_required"):
		var br: Dictionary = r.battle_required
		_offer_fight(br.get("kind", o.kind), br.tier, Sandbox._forced(c, br.attackers), true,
				wr.levy_stat if o.kind == "levy" else wr.sea_fight_stat, false, false, {"kind": "contract", "contract": o}, "", true)
	elif r.has("voyage_required"):
		contract = o
		_say("The work waits at %s; the lord's steward tells the way." % c.world.place(r.voyage_required).display_name)
		for id in Voyage.plan(c.world, c.band.location, str(r.voyage_required)):
			c.band.known_places[id] = true
	else:
		_finish_work(o, true)


func _finish_work(o: Dictionary, success: bool) -> void:
	var wr := c.world_rules
	Contracts.complete(wr, c.world, c.band, o, success, said)
	if success:
		Way.add_deed(c.band, Way.Id.KINGS_MAN, wr.deed_contract)
		Sandbox._promote(c, said)
		c.tally.contracts = c.tally.get("contracts", 0) + 1
	c.cal.advance_days(int(o.get("days", 10)))


func _holmgang(p: Place) -> void:
	var wr := c.world_rules
	var terms := Callings.holmgang_terms(wr, c.world, c.band, p)
	Callings.challenge(wr, c.world, c.band, p, terms, said)
	if Callings.holmgang_yields(_fork("yield"), c.band):
		Callings.after_holmgang(wr, c.world, c.band, p, terms, 1, true, said, _fork("holm_feud"))
		c.cal.advance_days(wr.holmgang_days)
		return
	var opponent := Callings.holmgang_opponent(_fork("opponent"), wr, p, terms, c.combat_rules)
	_say("%s takes up his shield and comes to the island." % opponent.display_name)
	_duel(opponent, {"kind": "duel", "place": p, "terms": terms})


## The leader alone against `opponent`, to first blood.
func _duel(opponent: Warrior, ctx: Dictionary) -> void:
	var built := c.build_duel(opponent, _fork("duel").seed_value)
	if quick:
		var result: BattleResult = (built.battle as Battle).run()
		var told := c.conclude_fight(null, built, result)
		_tell_fight(result, told)
		_after_fight(ctx, result)
		return
	(built.battle as Battle).clear_ai(0)
	fight = {"offer": null, "built": built, "ctx": ctx}


## Pleads the feud with `family` at the Thing the band is at.
func _plead(family: String) -> void:
	var wr := c.world_rules
	var f := Feud.find(c.band, family)
	if f.is_empty():
		return
	var cause := str(f.get("cause", ""))
	var wronged := not (cause.begins_with("raid on") or cause.begins_with("strandhögg") or cause.begins_with("robbed"))
	var kind := WorldTypes.CaseKind.KILLING if wronged else WorldTypes.CaseKind.RAID
	var tc := Thing.open_case(wr, c.band, kind, family, Feud.wergild(wr, c.band.rank), wronged)
	var spend := mini(int(c.band.silver * wr.thing_spend_fraction), wr.thing_spend_max)
	var verdict := Thing.run(_fork("case"), wr, c.world, c.band, tc, spend, said)
	c.cal.advance_days(wr.thing_days)
	c.tally.thing_cases = c.tally.get("thing_cases", 0) + 1
	if verdict != WorldTypes.Verdict.FAILED:
		f["settled"] = true
		f["verdict"] = WorldTypes.VERDICT_NAMES[verdict]
		c.band.log("the matter with %s was settled at the Thing: %s" % [family, WorldTypes.VERDICT_NAMES[verdict]])
		var good := (wronged and verdict != WorldTypes.Verdict.FAILED) or (not wronged and verdict == WorldTypes.Verdict.COMPENSATION)
		if good:
			Way.add_deed(c.band, Way.Id.LAWMAN, wr.deed_case)
	if not tc.battle_required.is_empty():
		var br: Dictionary = tc.battle_required
		_offer_fight(br.get("kind", "thing brawl"), br.tier, Sandbox._forced(c, br.attackers), false, wr.sea_fight_stat,
				false, true, {"kind": "thing"}, str(br.text), true)


# --- The market -----------------------------------------------------------------

## The goods here: [{good, name, buy, sell, stock, have}], prices as this
## band would pay and be paid. Empty where there is no market.
func market() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := here()
	if p == null or not p.has_market:
		return out
	for g in WorldTypes.Good.values():
		var stock := int(p.stock.get(g, 0))
		var have := int(c.band.cargo.get(g, 0))
		if stock <= 0 and have <= 0:
			continue
		out.append({"good": g, "name": WorldTypes.GOOD_NAMES[g], "stock": stock, "have": have,
				"buy": Market.buy_price(c.world_rules, p, c.band, g), "sell": Market.sell_price(c.world_rules, p, c.band, g)})
	return out


func buy(good: int, units: int) -> int:
	if not can_act():
		return 0
	_market_days()
	return Market.buy(c.world_rules, here(), c.band, good as WorldTypes.Good, units, said)


func sell(good: int, units: int) -> int:
	if not can_act():
		return 0
	_market_days()
	return Market.sell(c.world_rules, here(), c.band, good as WorldTypes.Good, units, said)


## The days a market costs, once a visit.
func _market_days() -> void:
	if _traded_at != c.band.location:
		_traded_at = c.band.location
		c.cal.advance_days(c.world_rules.market_days)


# --- Settling up ------------------------------------------------------------------

## After anything has happened: go on with what was interrupted, as far as
## the next thing a person must answer.
func _settle() -> void:
	var guard := 0
	while guard < 12:
		guard += 1
		if c.over:
			decisions.clear()
			fight = {}
			return
		if not decisions.is_empty() or not fight.is_empty():
			return
		if destination != "" and c.band.location != destination:
			_voyage()
			continue
		destination = ""
		if not contract.is_empty() and c.band.location == str(contract.get("to_place", "")):
			var o := contract
			contract = {}
			_finish_work(o, true)
			continue
		if not wintering and days_left() <= 0:
			_say("The season is closing: there is no more sailing this year.")
			wintering = true
			if c.band.location != c.band.home:
				destination = c.band.home
				_legs = 0
				_voyage()
				continue
		if wintering:
			_winter()
			continue
		return


func _winter() -> void:
	wintering = false
	destination = ""
	var wr := c.world_rules
	if c.band.location != c.band.home:
		_say("%s winters away from home, at %s." % [c.band.leader.display_name, here().display_name])
	# A feud he said he would answer at the Thing and did not goes on.
	for f in c.band.unsettled_feuds():
		if int(f.get("at_thing", -1)) == c.cal.year:
			Feud.escalate(wr, c.band, str(f.get("family", f.get("against", ""))), said)
	if not contract.is_empty():
		Contracts.complete(wr, c.world, c.band, contract, false, said)
		contract = {}
	c._settle_vow()
	var mark := c.log.size()
	var chron := c.band.chronicle.size()
	c.winter()
	winter_report = PackedStringArray()
	for i in range(chron, c.band.chronicle.size()):
		winter_report.append(c.band.chronicle[i])
	for i in range(mark, c.log.size()):
		winter_report.append(c.log[i])
	_say("Winter of %d passes." % c.cal.year)
	if c.over:
		_say("The saga of %s ends here: %s." % [Way.title(c.band), c.over_reason])
		return
	c.cal.next_year()
	c.band.year = c.cal.year
	begin_summer()


# --- Small things -----------------------------------------------------------------

## What the screen shows of the band: a dictionary of plain values.
func status() -> Dictionary:
	var band := c.band
	var cargo := PackedStringArray()
	var goods: Array = band.cargo.keys()
	goods.sort()
	for g in goods:
		cargo.append("%d %s" % [int(band.cargo[g]), WorldTypes.GOOD_NAMES[g]])
	return {
		"title": Way.title(band), "way": Way.name_of(band.way) if band.way >= 0 else "", "year": c.cal.year, "day": c.cal.day,
		"days_left": maxi(0, days_left()), "silver": band.silver, "food": band.food,
		"men": band.fighters(c.rules).size(), "hurt": band.hurt(c.rules).size(),
		"ship": WorldTypes.SHIP_NAMES[band.ship.kind] if band.ship != null else "no ship",
		"ship_damage": band.ship.damage if band.ship != null else 0,
		"cargo": ", ".join(cargo), "cargo_room": Market.cargo_room(c.world_rules, band), "captives": band.captives,
		"luck": band.luck, "fame": band.fame, "honor": band.honor, "rank": WorldTypes.RANK_NAMES[band.rank],
		"feuds": band.unsettled_feuds().size(), "work": str(contract.get("text", "")),
		"outlaw": Outlawry.is_outlawed(band, c.cal),
	}


func _say(line: String) -> void:
	said.append(line)


func _fork(label: String) -> SimRng:
	_n += 1
	return _rng.fork("%s:%d" % [label, _n])
