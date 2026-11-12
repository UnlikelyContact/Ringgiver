class_name Journey
extends RefCounted
## The player's summer on the free-roam map, one decision at a time
## (concept.md, "Ways of life", "The map" and "Picking your fights").
## Sandbox.summer is an AI standing in for the player; this is the player:
## he goes where he will, on foot or under sail (Roam, MapGrid), and at
## each place does what the place allows. The world modules do the work;
## this strings them together and stops wherever a person must answer.
##
## The shape: `go_to_place` / `go_to_point` set a course and `advance(dt)`
## moves the band along it as the days pass, with everyone else abroad
## moving too. `decisions` is a queue of things that must be answered
## before anything else (a fight offered, a merchant met, a king's demand);
## `answer(id)` answers the first. A fight the player will fight himself
## is left in `fight` for the battle view, which calls `fight_done(result)`.
## With `quick` set the leader AIs fight it out at once (tests, and "let
## the saga tell it"). Everything the player should read goes to `said`.

const RAID_KINDS := [WorldTypes.PlaceKind.FARMSTEAD, WorldTypes.PlaceKind.HALL, WorldTypes.PlaceKind.TOWN]
const SETTLED := [WorldTypes.PlaceKind.FARMSTEAD, WorldTypes.PlaceKind.HALL, WorldTypes.PlaceKind.TOWN]
const SPINE_LABELS := {"serve": "Serve him", "resist": "Resist him", "ignore": "Stand aside",
	"fight_for_harald": "Fight for Harald", "fight_against": "Fight against Harald", "join_rollo": "Sail west with Rollo",
	"back_eric": "Back Eric", "betray_eric": "Betray Eric", "acclaim": "Acclaim him",
	"sail_iceland": "Make for Iceland", "send_settlers": "Let the men who want land go", "hear": "So be it"}
## The hulls a man can buy, smallest first.
const HULLS := [WorldTypes.ShipKind.FAERING, WorldTypes.ShipKind.KARVE, WorldTypes.ShipKind.KNARR, WorldTypes.ShipKind.SNEKKJA]

var c: Campaign
var roam: Roam
var quick := false
var said := PackedStringArray()
var decisions: Array[Dictionary] = []
## A fight for the battle view: {offer, built, ctx}. Empty when there is none.
var fight := {}
## Work taken that waits at a place: done on arrival at its `to_place`.
var contract := {}
## The band is making for its winter quarters.
var wintering := false
## What the last winter did, for the screen that reads it out.
var winter_report := PackedStringArray()
## The winter the player plays (WinterHall) while the band winters; null in
## summer. With `stepped_winter` off (the default, for old callers) a
## winter is lived through at once with the sensible choices
## (`winter_auto`); the map screen and the stand-in players turn it on and
## step through it: `winter_state`, `winter_choose`, `winter_end`.
var stepped_winter := false
var winter_hall: WinterHall = null
var _rng: SimRng
var _n := 0
var _offers := {}  # place id -> the work on offer, rolled once a visit
var _traded_at := ""  # the place whose market the band has paid its days at
var _was_at := ""  # the place the band was last seen to be at
## The summer's own life beyond the band (WorldLife, TradeRoad, Hiring):
## the offers rolled at each place, what was done where this year, the
## merchant under guard, the stolen ship, the watch on the beach.
var life := {}


## A new saga: a man of the given origin (Origins key) and name, where his
## origin puts him, in the spring of the first year. No ship. With
## `escape`, an origin that has one (Origins.has_escape: the burned hall)
## begins with its fight waiting in `fight` (Campaign.build_escape): the
## night the hall burned, before he comes to his kin. The battle view
## fights it and calls `fight_done`; `skip_escape` lets the dice tell it.
## Without, the escape is only told, as before (the stand-in players).
static func begin(seed_in: int, origin_key: String, leader_name: String, escape := false) -> Journey:
	var j := Journey.new()
	j.c = Campaign.new(seed_in)
	j.c.start_from(origin_key, leader_name)
	var d := Origins.def(origin_key)
	var wr := WorldRules.new()
	Sandbox.setup(j.c, wr, str(d.at))
	j.c.world.salt = seed_in
	var band := j.c.band
	band.ship = null
	band.land = 0
	j.roam = Roam.new()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[str(d.at)])
	# He knows the country about where he stands.
	var at: Place = j.c.world.place(str(d.at))
	for p in j.c.world.places.values():
		if p.pos.distance_to(at.pos) <= wr.known_leagues_start and p.is_open(j.c.world.year):
			band.known_places[p.id] = true
	if str(d.feud_with) != "":
		var theirs: Place = j.c.world.place(str(d.feud_with))
		band.add_feud(theirs.family, "the burning of your father's hall", theirs.id)
		Feud.find(band, theirs.family)["rank"] = WorldTypes.Rank.HERSIR  # your father held a hall
		band.vengeance = theirs.family
		band.known_places[theirs.id] = true
		if theirs.faction_id != "":
			FactionAI.shift(j.c.world, theirs.faction_id, FactionAI.BAND, -20)
	# The houses he is born among: kin, the burners (Families).
	if j.c.world.families != null:
		j.c.world.families.start_origin(wr, j.c.world, band, origin_key)
		for id in wr.origin_standing.get(origin_key, {}):
			band.known_places[str(id)] = true
	if escape and Origins.has_escape(origin_key):
		# The ring is led by the head of the house that burned the hall.
		var burners: House = j.c.world.families.house_at(j.c.world, str(d.feud_with)) if j.c.world.families != null else null
		var built := j.c.build_escape(burners.name.trim_suffix("'s kin") if burners != null else "")
		(built.battle as Battle).clear_ai(0)
		j.fight = {"offer": null, "built": built, "ctx": {"kind": "escape"}}
		j._say("The night the hall at %s burned." % theirs_name(j))
	j.begin_summer()
	return j


## The place the band's vengeance lies, by name, for the telling.
static func theirs_name(j: Journey) -> String:
	var key := str(Origins.def(j.c.band.origin).get("feud_with", ""))
	var p: Place = j.c.world.place(key) if key != "" else null
	return p.display_name if p != null else "home"


## Whether the fight waiting is the burned hall's escape.
func escape_pending() -> bool:
	return not fight.is_empty() and str((fight.ctx as Dictionary).get("kind", "")) == "escape"


## Lets the dice tell the escape instead of the player: the leader gives
## the careful orders (Objective.escape_order) and slips away the moment
## he can, the rounds are fought out, and the result goes through
## `fight_done`. Returns its lines.
func skip_escape() -> PackedStringArray:
	if not escape_pending():
		return PackedStringArray()
	var battle: Battle = fight.built.battle
	while not battle.is_over() and battle.round < battle.rules.max_rounds:
		if battle.can_withdraw(0) and battle.withdraw(0):
			break
		battle.set_shout(0, Objective.escape_order(battle, 0))
		battle.run_round()
	if not battle.is_over():
		battle.run()
	return fight_done(battle.result)


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
	wintering = false
	roam.stop()
	roam.clock = 0.0
	roam.populate(_fork("parties"), c.world_rules, c.world, Outlawry.is_outlawed(c.band, cal))
	WorldLife.spring(self)
	c.band.location = roam.grid.place_at(roam.pos)
	_was_at = c.band.location
	_say("Spring of %d. The ice is off the fjord%s." % [cal.year, (" at %s" % here().display_name) if here() != null else ""])
	if Outlawry.is_outlawed(c.band, cal):
		_say("%s sails as an outlaw this year: the halls are shut to him." % c.band.leader.display_name)
	for ev in Timeline.pending(c.world_rules, c.world, cal.year):
		var opts: Array[Dictionary] = []
		for o in Timeline.outcome_options(ev):
			opts.append({"id": o, "label": SPINE_LABELS.get(o, str(o).capitalize())})
		decisions.append({"kind": "spine", "event": ev, "text": str(ev.text), "options": opts})
	# The saga's first summer is the player's to find his feet in: old
	# enemies do not come for him and no house asks anything of him yet.
	var feud_events: Array[Dictionary] = []
	if not first_summer():
		feud_events = Feud.summer_events(_fork("feuds"), c.world_rules, c.world, c.band, said)
	for ev in feud_events:
		if ev.has("battle_required"):
			var br: Dictionary = ev.battle_required
			var f := Feud.find(c.band, ev.get("family", ""))
			var level: int = f.get("level", 1) if not f.is_empty() else 1
			_offer_fight(br.get("kind", "feud_ambush"), br.tier, Sandbox._forced(c, br.attackers), false,
					c.world_rules.feud_stat_base + level - 1, false, false, {"kind": "feud", "family": str(ev.get("family", ""))}, str(br.text), false)
		elif ev.get("kind", "") == "demand":
			var family: String = ev.family
			var ask := Feud.offer_settlement(c.world_rules, c.band, family)
			decisions.append({"kind": "demand", "family": family, "ask": ask,
					"text": "%s send word: %d oz of silver, and the feud is ended." % [family, ask],
					"options": [
						{"id": "pay", "label": "Pay %d oz" % ask, "enabled": c.band.silver >= ask},
						{"id": "thing", "label": "Answer at the Thing"},
						{"id": "refuse", "label": "Refuse"}]})
	_houses_spring()
	_law_land_spring()
	_settle()


## The decision that must be answered now, or {}.
func current() -> Dictionary:
	return decisions[0] if not decisions.is_empty() else {}


## Whether the player is free to act: nothing to answer, no fight on.
func can_act() -> bool:
	return decisions.is_empty() and fight.is_empty() and not c.over and winter_hall == null


## The place the band is at, or null in the wilds and at sea.
func here() -> Place:
	return c.world.place(c.band.location) if c.band.location != "" else null


## Where the band is, in words.
func whereabouts() -> String:
	var p := here()
	if p != null:
		return p.display_name
	if roam.afloat():
		return "at sea"
	return "in the wilds"


func days_left() -> int:
	return c.cal.summer_left(c.world_rules.summer_days - Omens.short_summer(self))


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
			_law_land_spine(ev, id, r)
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
							{"kind": "rob", "req": req, "party": d.get("party", null)}, str(req.text), true)
				_:
					_say("The knarr goes on its way.")
		"house":
			_answer_house(d, id)
		"world":
			WorldLife.answer(self, d, id)
		"thing", "land", "unfree", "omen":
			_answer_law_land(d, id)
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
	roam.stop()  # a fight is where the day's march ends
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
	if str((f.ctx as Dictionary).get("kind", "")) == "escape":
		var out: PackedStringArray = told.lines
		out.append_array(_after_escape(f.built, result))
		_settle()
		return out
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
	var offer := c.offer_fight(kind, tier, size, attacking, stat, at_sea, cornered, ground_here())
	var opts: Array[Dictionary] = []
	if offer.they_know_first:
		opts.append({"id": str(FightOffer.Choice.TAKE_THE_FIELD), "label": "Fight"})
	for ch in offer.options():
		opts.append({"id": str(ch), "label": offer.title(ch)})
	var d := {"kind": "fight", "offer": offer, "ctx": ctx, "text": "%s %s You have %d men fit to fight." % [text, offer.brief(), offer.our_men],
			"options": opts}
	if front:
		decisions.push_front(d)
	else:
		decisions.append(d)


## The ground under the band, for a fight that finds it here
## (FightOffer.ground): aboard at sea, at a steading, on the strand, in the
## hills (a mountain cell, or low land under one), or the open low country.
func ground_here() -> String:
	if roam.afloat():
		return "sea"
	var p := here()
	if p != null and SETTLED.has(p.kind):
		return "farm"
	var cell := roam.cell()
	match roam.grid.terrain(cell):
		MapGrid.T.SHORE:
			return "strand"
		MapGrid.T.MOUNTAIN:
			return "hills"
	for d in MapGrid._DIRS:
		if roam.grid.terrain(cell + d) == MapGrid.T.MOUNTAIN:
			return "hills"
	return "open"


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
			_pass(float(wr.raid_days))
		"contract":
			var o: Dictionary = ctx.contract
			Contracts.complete(wr, c.world, c.band, o, won, said)
			_work_standing(o, won)
			if won:
				Way.add_deed(c.band, Way.Id.KINGS_MAN, wr.deed_contract)
				Sandbox._promote(c, said)
				c.tally.contracts = c.tally.get("contracts", 0) + 1
			_pass(float(int(o.get("days", 10))))
		"spine":
			Timeline.resolve(wr, c.world, c.band, ctx.event, ctx.choice, won, said)
		"duel":
			var outcome := -1 if result == null or result.winner < 0 else (1 if won else 0)
			Callings.after_holmgang(wr, c.world, c.band, ctx.place, ctx.terms, outcome, false, said, _fork("holm_feud"))
			_pass(float(wr.holmgang_days))
		"champion":
			var came := -1 if result == null or result.winner < 0 else (1 if won else 0)
			Callings.after_champion(wr, c.world, c.band, ctx.place, came, said)
			_pass(float(wr.holmgang_days))
		"house_fight", "blood", "reckoning":
			_after_house_fight(ctx, result)
		"world_fight":
			WorldLife.after_fight(self, ctx, result)
	_law_land_after_fight(ctx, result)
	_killed_their_men(ctx, result)
	# The party it was fought with: beaten, it is gone; otherwise it keeps
	# its distance for a while.
	var party: Roam.Party = ctx.get("party", null)
	if party != null:
		if won:
			# What they carried is the band's now: a raider's plunder.
			if party.loot > 0:
				c.band.silver += party.loot
				_say("Their plunder is %s's now: %d oz." % [c.band.leader.display_name, party.loot])
				party.loot = 0
			c.band.captives += party.captives
			party.captives = 0
			roam.parties.erase(party)
		else:
			party.rest_until = roam.clock + c.world_rules.party_rest_days
	_vengeance()
	if c.over:
		_say("The saga of %s ends here: %s." % [Way.title(c.band), c.over_reason])


## What the burned hall's escape leaves: how the band came to its kin, the
## chronicle's first line, and a man lent by the kin when both of his
## fell (the saga goes on with whoever lived). The leader never dies here
## (Battle.spared). Returns the lines told, also put in `said`.
func _after_escape(built: Dictionary, result: BattleResult) -> PackedStringArray:
	var band := c.band
	var who := band.leader.display_name
	var at := here().display_name if here() != null else "Sogn"
	var lines := PackedStringArray()
	var leader_w: Warrior = null
	for w in built.ours:
		if (w as Warrior).id == band.leader.id:
			leader_w = w
	var carried := leader_w != null and leader_w.is_down()
	var with_him := band.living_men().size()
	if carried:
		lines.append("%s remembers nothing after the blow. He wakes at %s with his wounds bound, and is told how he came there." % [who, at])
	else:
		lines.append("%s comes over the hills to %s by night, and his kin take him in." % [who, at])
	if with_him == 0:
		var m := Recruits.random(_fork("lent"), c.rules, band.next_id())
		band.add_man(m)
		c._arm_new_men()
		lines.append("Both his men lie dead at %s. His kin lend him %s, who will follow him." % [theirs_name(self), m.display_name])
		band.log("%s's kin lent him %s" % [who, m.display_name])
	band.log("%s got out of his father's burning hall at %s %s" % [who, theirs_name(self),
			"alone" if with_him == 0 else ("with one man" if with_him == 1 else "with %d men" % with_him)])
	for line in lines:
		_say(line)
	return lines


## The origin's unfinished matter: when the feud with the burners is ended,
## by the sword, the island or the Thing, it is told.
func _vengeance() -> void:
	var band := c.band
	if band.vengeance == "" or not Feud.find(band, band.vengeance).is_empty():
		return
	_say("The burning is answered: the matter between %s and %s is ended." % [band.leader.display_name, band.vengeance])
	band.log("%s had his vengeance for the burning of his father's hall" % band.leader.display_name)
	band.fame = clampi(band.fame + 10, 0, 100)
	band.vengeance = ""


# --- Going about ------------------------------------------------------------------

## Leagues a day on foot.
func foot_speed() -> float:
	return c.world_rules.foot_speed


## Leagues a day in the band's ship, or 0 when it has none it can use: no
## hull, too few hands for the oars, or more men than she will carry.
func sail_speed() -> float:
	var band := c.band
	if band.ship == null:
		return 0.0
	var wr := c.world_rules
	var men := band.fighters().size()
	if men < int(wr.ship_min_crew[band.ship.kind]):
		return 0.0
	if men > band.ship.crew_capacity(wr):
		# Overladen: she will not put out so, but at sea she limps home.
		return wr.ship_limp_speed if roam.afloat() and roam.aboard else 0.0
	if not band.ship.can_sail(wr):
		return wr.ship_limp_speed
	return float(wr.ship_speed[band.ship.kind])


## Why the ship is no use, in words, or "" when she is (or there is none).
func ship_trouble() -> String:
	var band := c.band
	if band.ship == null:
		return ""
	var wr := c.world_rules
	var men := band.fighters().size()
	if men < int(wr.ship_min_crew[band.ship.kind]):
		return "too few hands for her oars (%d needed)" % int(wr.ship_min_crew[band.ship.kind])
	if men > band.ship.crew_capacity(wr):
		return "she will not carry %d men (%d at most)" % [men, band.ship.crew_capacity(wr)]
	return ""


## A small boat keeps out of the deep.
func _deep_ok() -> bool:
	return c.band.ship != null and c.band.ship.kind != WorldTypes.ShipKind.FAERING


## Days to a place from here as the band would go, or -1 with no way.
func days_to(to: String) -> int:
	if to == c.band.location:
		return 0
	if not roam.grid.place_cell.has(to):
		return -1
	var sail := sail_speed()
	var days := -1.0
	if c.band.location != "" and (sail <= 0.0 or roam.aboard):
		days = roam.place_days(c.band.location, to, foot_speed(), sail, _deep_ok())
	else:
		var p := roam.grid.find_path(roam.cell(), roam.grid.place_cell[to], foot_speed(), sail if roam.has_reach(sail) else 0.0,
				roam.aboard and sail > 0.0, roam.ship_cell(), _deep_ok())
		days = p.days if not (p.cells as Array).is_empty() else -1.0
	return -1 if days < 0.0 else maxi(1, ceili(days - 0.01))


## Sets the band's course for a place it knows. False when there is no way.
func go_to_place(to: String) -> bool:
	if not can_act() or not roam.grid.place_cell.has(to):
		return false
	return _plot(roam.grid.place_cell[to], c.world.place(to).display_name)


## Sets the band's course for a point on the map (leagues).
func go_to_point(v: Vector2) -> bool:
	if not can_act():
		return false
	return _plot(MapGrid.cell_of(v), "there")


func _plot(cell: Vector2i, what: String) -> bool:
	var days := roam.plot(cell, foot_speed(), sail_speed(), _deep_ok())
	if days < 0.0:
		var why := "there is no way by land"
		if roam.grid.is_sea(cell) and c.band.ship == null:
			why = "you have no ship"
		elif c.band.ship != null and ship_trouble() != "":
			why = ship_trouble()
		elif c.band.ship != null and not _deep_ok():
			why = "a færing will not cross the deep"
		_say("No way to %s: %s." % [what, why])
		return false
	_traded_at = ""
	return true


## Whether the band is under way.
func moving() -> bool:
	return roam.moving() and can_act()


## Lets `dt` days pass with the band following its course (if it has one)
## and everyone else abroad going about theirs. Stops at once for anything
## that must be answered. Returns whether the band is still under way.
func advance(dt: float) -> bool:
	var left := dt
	var guard := 0
	while left > 0.0001 and can_act() and guard < 400:
		guard += 1
		var chunk := minf(left, 0.2)
		var used := chunk
		var was_moving := roam.moving()
		if was_moving:
			used = maxf(0.001, roam.step_band(chunk, foot_speed(), sail_speed()))
		_clock(used)
		_look_about()
		if roam.afloat() and roam.aboard and c.band.ship != null:
			_weather(used)
		_moods()
		var met := roam.step_parties(used, _fork("parties"), c.world_rules, c.world, c.band.fighters(c.rules).size(), c.band.location)
		if met != null:
			_meet(met)
		if can_act():
			WorldLife.tick(self, used)
			_law_land_tick(used)
		left -= used
		if was_moving and not roam.moving():
			_arrived()
			break
		if days_left() <= 0:
			break
	_settle()
	return moving()


## Goes on along the course until the band arrives or something stops it
## (for the stand-in player and tests). Returns whether it arrived.
func travel(max_days := 120.0) -> bool:
	var spent := 0.0
	while moving() and spent < max_days:
		advance(1.0)
		spent += 1.0
	return not roam.moving() and can_act()


## Sets a course for a place and goes there, as far as it can be gone
## without something to answer. Returns whether the band is there.
func sail(to: String) -> bool:
	if to == c.band.location:
		return true
	if not go_to_place(to):
		return false
	travel()
	return c.band.location == to


## The days go by: the clock, the calendar.
func _clock(days: float) -> void:
	roam.clock += days
	c.cal.day = 1 + int(roam.clock)


## Days pass with the band where it is (a deed done, a market, a wait):
## the others go on moving, and may find it.
func _pass(days: float) -> void:
	var left := days
	while left > 0.0001:
		var chunk := minf(left, 0.5)
		_clock(chunk)
		left -= chunk
		if not decisions.is_empty() or not fight.is_empty():
			continue  # the days still pass, but nothing more is met
		var met := roam.step_parties(chunk, _fork("parties"), c.world_rules, c.world, c.band.fighters(c.rules).size(), c.band.location)
		if met != null:
			_meet(met)
		if decisions.is_empty() and fight.is_empty():
			WorldLife.tick(self, chunk)
			_law_land_tick(chunk)


## The band's place, and what comes in sight of it.
func _look_about() -> void:
	var band := c.band
	band.location = roam.grid.place_at(roam.pos)
	var wr := c.world_rules
	for p in c.world.places.values():
		if band.known_places.has(p.id) or not p.is_open(c.world.year):
			continue
		if p.pos.distance_to(roam.pos) <= wr.sight_leagues:
			band.known_places[p.id] = true
			_say("%s comes in sight." % _cap(p.display_name))


func _arrived() -> void:
	var p := here()
	if p != null and p.id != _was_at:
		_say("%s comes to %s on day %d." % [c.band.leader.display_name, p.display_name, c.cal.day])
		Knowledge.reveal(c.world, c.band, p.id, said)
		Knowledge.see_prices(c.world_rules, c.world, c.band, p.id, c.cal.day)
		WorldLife.hear_news(self)
		TradeRoad.check_escort(self)
	_was_at = c.band.location


## A day's sailing has its weather: a storm that springs the strakes, and
## on the deep the chance of foundering.
func _weather(days: float) -> void:
	var wr := c.world_rules
	var band := c.band
	var r := _fork("weather")
	if r.randf() < wr.storm_chance_day * days:
		band.ship.damage += wr.storm_ship_damage
		_clock(float(wr.storm_delay_days))
		_say("A storm drives the ship off her course; %d days lost and the strakes sprung." % wr.storm_delay_days)
	if roam.grid.terrain(roam.cell()) == MapGrid.T.DEEP and r.randf() < wr.wreck_chance_deep_day * days:
		# She founders: the band struggles ashore at the nearest place.
		var best := ""
		var best_d := INF
		for p in c.world.places.values():
			if p.is_open(c.world.year) and p.pos.distance_to(roam.pos) < best_d:
				best_d = p.pos.distance_to(roam.pos)
				best = p.id
		Voyage._wreck(r, wr, c.world, band, best, said)
		band.ship = null
		roam.stop()
		roam.aboard = false
		roam.ship_at = Vector2.INF
		roam.pos = MapGrid.centre(roam.grid.place_cell[best])
		band.known_places[best] = true
		_look_about()
		_was_at = band.location


## Another party has come up with the band.
func _meet(p: Roam.Party) -> void:
	var wr := c.world_rules
	if WorldLife.meet(self, p) or Outlawry.meet(self, p):
		return
	p.rest_until = roam.clock + wr.party_rest_days
	var at_sea := roam.afloat()
	match p.kind:
		"merchant":
			var offer: Dictionary = p.offer
			var enc := {"kind": "merchant", "offer": offer, "text": "%s hails you, with %s at %d oz a unit." % [
					_cap(p.name), WorldTypes.GOOD_NAMES[offer.good], int(offer.price)]}
			var room := Market.cargo_room(wr, c.band)
			var n := mini(mini(int(offer.units), room), c.band.silver / maxi(1, int(offer.price)))
			decisions.append({"kind": "merchant", "enc": enc, "party": p, "text": str(enc.text), "options": [
				{"id": "buy", "label": "Buy %d for %d oz" % [n, n * int(offer.price)], "enabled": n > 0},
				{"id": "rob", "label": "Rob him"},
				{"id": "pass", "label": "Sail on"}]})
		"raiders":
			var text := "A rival ship bears down on you, %d men at her oars." % p.men
			_offer_fight("rival_ship", p.tier, Sandbox._forced(c, p.men), false, wr.sea_fight_stat, at_sea, false,
					{"kind": "sea", "req": {"kind": "rival_ship"}, "party": p}, text, true)
		"levy", "kings_ships":
			var text2 := "The levy ships have found the outlaw, and come on."
			_offer_fight("levy", p.tier, Sandbox._forced(c, p.men), false, wr.levy_stat, at_sea, false,
					{"kind": "sea", "req": {"kind": "levy"}, "party": p}, text2, true)
		"avengers":
			var text4 := "Men of %s come on, %d of them: they have been looking for you." % [p.family, p.men]
			_offer_fight("avengers", p.tier, Sandbox._forced(c, p.men), false, wr.feud_stat_base + 1, at_sea, false,
					{"kind": "sea", "req": {"kind": "avengers"}, "party": p, "family": p.family}, text4, true)
		"outlaws":
			var text3 := "Outlaws come out of the trees, %d of them, and want what you carry." % p.men
			var bounty := wr.outlaw_bounty if c.band.outlawry == WorldTypes.Outlawry.NONE else 0
			_offer_fight("outlaws", p.tier, Sandbox._forced(c, p.men), false, wr.sea_fight_stat, false, false,
					{"kind": "sea", "req": {"kind": "outlaws", "bounty": bounty}, "party": p}, text3, true)


# --- What can be done here ---------------------------------------------------------

## The deeds open where the band stands: [{id, label, hint, enabled}].
## Trading has its own calls (`market`, `buy`, `sell`); going somewhere is
## `go_to_place` / `go_to_point`.
func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_act():
		return out
	var wr := c.world_rules
	var p := here()
	var band := c.band
	if p == null:
		# In the wilds or on the water: little to do but wait.
		if band.ship != null and band.ship.damage > 0 and roam.aboard and not roam.afloat():
			out.append({"id": "mend", "label": "Mend the ship", "hint": "%d days on the beach for each of her %d hurts." % [wr.ship_mend_days, band.ship.damage]})
		out.append({"id": "camp", "label": "Wait a day", "hint": "Let a day go by where you are."})
		out.append_array(Outlawry.actions(self))
		return out
	var at_home := p.id == band.home
	var closed := Outlawry.door_shut(self, p, "work") != ""
	if RAID_KINDS.has(p.kind) and not at_home and p.wealth > 0 and Landtake.raidable(self, p):
		var a := Raiding.assess(wr, c.world, p, band)
		var fresh := int(band.raided.get(p.id, -1)) != c.cal.year
		out.append({"id": "raid", "label": "Raid %s" % p.display_name, "enabled": fresh,
				"hint": ("About %d %s defenders%s; near %d oz to take. %s will not forget it." % [a.defenders, CombatTypes.TIER_NAMES[a.tier],
						" (the beacons are lit)" if a.beacons else "", roundi(a.expected_plunder * float(band.gift("raid_plunder", 1.0))),
						_cap(p.family) if p.family != "" else "They"]) if fresh else "You have been here this year: what is left is hidden or fled."})
		if p.kind == WorldTypes.PlaceKind.FARMSTEAD:
			out.append({"id": "strandhogg", "label": "Strandhögg", "hint": "A quick raid for cattle and stores: %d rations and a little silver, no battle." % (
					wr.strandhogg_food * int(band.gift("strandhogg", 1)))})
	if not closed:
		var i := 0
		for o in _work_here():
			var label := "%s (%d oz)" % [_cap(str(o.text)), roundi(float(o.pay) * float(band.gift("contract_pay", 1.0)))]
			var reach: bool = not o.has("to_place") or days_to(str(o.to_place)) >= 0
			out.append({"id": "work:%d" % i, "label": label,
					"hint": ("A lord's work: about %d days." % int(o.get("days", 10))) if reach else "You have no way to get there: it needs a ship.",
					"enabled": contract.is_empty() and reach})
			i += 1
		if Callings.can_verse(c.world, band, p):
			out.append({"id": "verse", "label": "Speak a verse before the lord", "hint": "Wits and fame against %d: a ring if it pleases him." % Callings.verse_need(wr, band, p)})
	if Callings.can_counsel(wr, c.world, band, p):
		out.append({"id": "counsel", "label": "Give counsel in a dispute", "hint": "Wits against %d: a fee, honor and %s's friendship at the Thing." % [
				wr.counsel_difficulty + (wr.counsel_thing_harder if p.kind == WorldTypes.PlaceKind.THING_SITE else 0), p.family]})
	if Callings.can_champion(wr, c.world, band, p):
		out.append({"id": "champion", "label": "Stand in the farmer's place",
				"hint": "A berserk has called %s out for their land. Meet him on the island yourself: %d oz, honor and their friendship if you blood him." % [
						p.family, roundi(float(wr.champion_fee + p.wealth / wr.champion_wealth_per_oz) * float(band.gift("champion_fee", 1.0)))]})
	# The burners will not stake a burning on the island.
	if Callings.can_challenge(wr, c.world, band, p) and p.family != band.vengeance:
		var t := Callings.holmgang_terms(wr, c.world, band, p)
		out.append({"id": "holmgang", "label": "Call %s to the island" % p.family,
				"hint": ("To end the feud, and for %d oz." % t.stake) if t.feud else ("For %d oz of what they own. It costs honor: %d." % [t.stake, t.honor_cost])})
	if ThingPlay.is_thing(self, p) and not Outlawry.is_outlawed(band, c.cal) and not life.has("case"):
		for f in band.unsettled_feuds():
			var family := str(f.get("family", f.get("against", "")))
			if int((band.law.get("pleaded", {}) as Dictionary).get(family, -1)) == c.cal.year:
				continue  # one hearing a summer (ThingPlay)
			var hint := "Support, procedure, the standoff, the verdict. %d days." % wr.thing_days
			var ready := true
			if family == band.vengeance and c.world.families != null:
				var vb := c.world.families.vengeance_backing(wr, band, family, band.fighters(c.rules).size())
				ready = bool(vb.ready)
				if not ready:
					hint = "%s will not answer for the burning at the Thing while they and their friends are the stronger: you could bring %d men, they %d. Win friends among their enemies first." % [
							family, int(vb.ours), int(vb.theirs)]
			out.append({"id": "case:" + family, "label": "Plead against %s" % family, "hint": hint,
					"enabled": band.silver >= wr.thing_min_silver and ready})
	if band.captives > 0 and Market.captive_price(wr, p) > 0:
		out.append({"id": "captives", "label": "Sell %d captives" % band.captives, "hint": "%d oz for the next." % Market.captive_price(wr, p)})
	if not p.has_market and SETTLED.has(p.kind):
		out.append({"id": "rations", "label": "Buy rations", "hint": "Five rations at %d oz each." % wr.farm_food_price,
				"enabled": band.silver >= wr.farm_food_price})
	# A hull of his own, or passage on another man's.
	if Outlawry.door_shut(self, p, "market") == "" and (p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN):
		for kind in hulls_for_sale():
			var cost := hull_cost(kind)
			out.append({"id": "hull:%d" % kind, "label": "Buy a %s (%d oz)" % [WorldTypes.SHIP_NAMES[kind], cost],
					"hint": "Carries %d men and %d of cargo, %d leagues a day; needs %d at the oars.%s" % [int(wr.ship_crew[kind]), int(wr.ship_cargo[kind]),
							int(wr.ship_speed[kind]), int(wr.ship_min_crew[kind]), " She keeps out of the deep." if kind == WorldTypes.ShipKind.FAERING else ""],
					"enabled": band.silver >= cost})
	# Passage for a band without a ship it can use here, or with only a
	# small boat that will not cross the deep (she stays on the beach).
	if (sail_speed() <= 0.0 or not _deep_ok()) and SETTLED.has(p.kind):
		for to in passages():
			out.append({"id": "passage:" + str(to.id), "label": "Take passage to %s (%d oz)" % [c.world.place(to.id).display_name, int(to.cost)],
					"hint": "%d days on another man's ship%s." % [int(to.days), (", your loads with you" if band.cargo_units() + band.felag_units() > 0 else "")],
					"enabled": band.silver >= int(to.cost)})
	if band.ship != null and band.ship.damage > 0 and roam.aboard:
		out.append({"id": "mend", "label": "Mend the ship", "hint": "%d days on the beach for each of her %d hurts%s." % [
				wr.ship_mend_days, band.ship.damage, "" if band.ship.can_sail(wr) else ". She only limps as she is"]})
	if SETTLED.has(p.kind) and _healing() > 0:
		out.append({"id": "rest", "label": "Rest and mend", "hint": "%d days under a roof: every man's wounds mend a turn. %s" % [wr.rest_days,
				"Some of your men are too hurt to fight yet." if not band.hurt(c.rules).is_empty() else "Your men are hurt, but can stand in the line."]})
	out.append({"id": "listen", "label": "Wait and listen", "hint": "%d days. At a hall or a market there is talk of places you do not know." % wr.listen_days})
	out.append_array(TradeRoad.actions(self))
	out.append_array(Hiring.actions(self))
	out.append_array(WorldLife.actions(self))
	out.append_array(_house_actions(p))
	if SETTLED.has(p.kind):
		var guest := not at_home
		var cost := wr.guest_winter_per_man * band.fighters().size() if guest else 0
		var door := Families.shelter(wr, band, p) if guest else "paid"
		if door == "free":
			cost = 0
		var hint := ("End the summer as a guest here: %d oz for the lodging." % cost) if guest else "End the summer: the hall, the men, the long dark."
		if door == "free":
			hint = "End the summer as the guest of %s, your friends: they will take nothing for it." % p.family
		elif door == "shut":
			hint = "The door of %s is shut to you." % p.family
		out.append({"id": "winter", "label": "Winter here", "enabled": door != "shut" and (band.silver >= cost or not guest), "hint": hint})
	out.append_array(_law_land_actions())
	Outlawry.gate(self, out)
	return out


## Turns of healing the band still has to do, all its men together.
func _healing() -> int:
	var n := 0
	for m in c.band.fighters():
		n += m.healing_turns
	return n


## The hulls worth showing here: every one the band can pay for (bigger
## than the one it has), and the next it cannot yet.
func hulls_for_sale() -> Array[int]:
	var out: Array[int] = []
	var band := c.band
	var have := HULLS.find(band.ship.kind) if band.ship != null else -1
	var shown_dear := false
	for i in HULLS.size():
		if i <= have:
			continue
		if band.silver >= hull_cost(HULLS[i]):
			out.append(HULLS[i])
		elif not shown_dear:
			out.append(HULLS[i])
			shown_dear = true
	return out


## What a hull costs the band: her price, less part of the old one's.
func hull_cost(kind: int) -> int:
	var wr := c.world_rules
	var cost := int(wr.ship_price[kind])
	if c.band.ship != null:
		cost -= roundi(float(wr.ship_price.get(c.band.ship.kind, 0)) * wr.ship_trade_in)
	return maxi(1, cost)


## Passage to be had from here: up to four of the nearest halls, towns and
## markets the band knows, by sea: [{id, days, cost}].
func passages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wr := c.world_rules
	var band := c.band
	var from := band.location
	if from == "":
		return out
	var ids: Array = band.known_places.keys()
	ids.sort()
	for id in ids:
		var p := c.world.place(id)
		if p == null or id == from or not p.is_open(c.world.year):
			continue
		if not (p.has_market or p.kind == WorldTypes.PlaceKind.HALL or p.kind == WorldTypes.PlaceKind.TOWN):
			continue
		var days := roam.place_days(from, id, 0.0001, wr.merchant_speed, true)
		if days <= 0.0:
			continue
		var d := maxi(1, ceili(days - 0.01))
		out.append({"id": id, "days": d, "cost": wr.passage_base + ceili(d * (1.0 + band.fighters().size() * wr.passage_per_man_day))
				+ wr.passage_per_load * (band.cargo_units() + band.felag_units())})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.days) < int(b.days) or (int(a.days) == int(b.days) and str(a.id) < str(b.id)))
	return out.slice(0, 4)


## Does one of `actions()` by id.
func act(id: String) -> void:
	if not can_act():
		return
	var wr := c.world_rules
	var p := here()
	var band := c.band
	var shut := Outlawry.refuses(self, id)
	if shut != "":
		_say(shut)
		return
	roam.stop()
	if id == "camp":
		_pass(1.0)
	elif id == "mend":
		if band.ship != null and band.ship.damage > 0:
			band.ship.damage -= 1
			_pass(float(wr.ship_mend_days))
			_say("The crew haul the ship up and mend her (%d days)%s." % [wr.ship_mend_days, "" if band.ship.damage > 0 else "; she is sound again"])
	elif p == null:
		pass
	elif id == "raid":
		band.raided[p.id] = c.cal.year
		_shift(p.family, wr.standing_raid)
		var req := Raiding.raid(_fork("raid"), wr, c.world, band, p, said)
		if not req.is_empty():
			var center := int(wr.defender_stat_by_kind[p.kind] + p.defenses * wr.defender_stat_per_defense)
			_offer_fight("raid on %s" % p.display_name, req.tier, req.defenders, true, clampi(center, 1, 10), false, false,
					{"kind": "raid", "place": p}, "", true)
			Omens.before_raid(self)
	elif id == "strandhogg":
		Raiding.strandhogg(_fork("strand"), wr, c.world, band, p, said)
		_shift(p.family, wr.standing_strandhogg)
		Way.add_deed(band, Way.Id.VIKING, wr.deed_strandhogg)
		_pass(1.0)
	elif id.begins_with("work:"):
		var list := _work_here()
		var i := int(id.trim_prefix("work:"))
		if i < list.size() and contract.is_empty():
			var o: Dictionary = list[i]
			list.clear()  # a lord has one piece of work for a man in a year
			_take_work(o)
	elif id == "verse":
		Callings.verse(_fork("verse"), wr, c.world, band, p, said)
		_pass(float(wr.verse_days))
	elif id == "counsel":
		Callings.counsel(_fork("counsel"), wr, c.world, band, p, said)
		_pass(float(wr.counsel_days))
	elif id == "holmgang":
		_holmgang(p)
	elif id == "champion":
		var foe := Callings.bully(_fork("bully"), wr, p, c.combat_rules)
		_say("%s waits on the island; %s goes out to him in the farmer's place." % [foe.display_name, band.leader.display_name])
		_duel(foe, {"kind": "champion", "place": p})
	elif id.begins_with("case:"):
		ThingPlay.begin(self, id.trim_prefix("case:"))
	elif id == "captives":
		Thralls.sell(self, p)
	elif id == "rations":
		Market.buy(wr, p, band, WorldTypes.Good.GRAIN, 5, said)
	elif id.begins_with("hull:"):
		_buy_hull(int(id.trim_prefix("hull:")))
	elif id.begins_with("passage:"):
		_take_passage(id.trim_prefix("passage:"))
	elif id == "listen":
		var heard := Knowledge.hear_rumor(_fork("rumor"), wr, c.world, band, p.id, said)
		if heard == "":
			_say("%d days pass at %s, and nothing new is heard." % [wr.listen_days, p.display_name])
		_pass(float(wr.listen_days))
	elif id == "rest":
		band.mend(1)
		_pass(float(wr.rest_days))
		_say("The band rests %d days at %s, and the wounds mend%s." % [wr.rest_days, p.display_name,
				"" if _healing() > 0 else ": every man is whole again"])
	elif id == "winter":
		wintering = true
	elif TradeRoad.act(self, id) or Hiring.act(self, id) or WorldLife.act(self, id) or _act_law_land(id):
		pass
	elif _act_house(id, p):
		pass
	_vengeance()
	_settle()


func _buy_hull(kind: int) -> void:
	var band := c.band
	var cost := hull_cost(kind)
	if band.silver < cost or not HULLS.has(kind):
		return
	band.silver -= cost
	var old: String = WorldTypes.SHIP_NAMES[band.ship.kind] if band.ship != null else ""
	band.ship = Ship.make(kind as WorldTypes.ShipKind)
	roam.aboard = true
	roam.ship_at = Vector2.INF
	_say("%s buys a %s at %s for %d oz%s." % [band.leader.display_name, WorldTypes.SHIP_NAMES[kind], here().display_name, cost,
			(", the old %s in part payment" % old) if old != "" else ""])
	band.log("%s got himself a %s" % [band.leader.display_name, WorldTypes.SHIP_NAMES[kind]])


func _take_passage(to: String) -> void:
	var band := c.band
	for offer in passages():
		if str(offer.id) != to or band.silver < int(offer.cost):
			continue
		band.silver -= int(offer.cost)
		# A hull of his own stays on the beach where he left her.
		if band.ship != null and roam.aboard:
			roam.ship_at = roam.pos
		roam.aboard = false
		roam.pos = MapGrid.centre(roam.grid.place_cell[to])
		_pass(float(offer.days))
		_look_about()
		_say("%s takes passage to %s: %d days, %d oz." % [band.leader.display_name, c.world.place(to).display_name, int(offer.days), int(offer.cost)])
		_arrived()
		return


## Takes the next step down one of the ways of life (Way.invest), if the
## points are there. A man who takes up the fury is trusted the less by
## every lord.
func invest(way: int) -> bool:
	var had := Way.rank(c.band, way)
	if not Way.invest(c.band, way):
		return false
	var d := Way.def(way)
	_say("%s takes a step down the %s's way: %s." % [c.band.leader.display_name, str(d.name).to_lower(), d.ranks[had].name])
	if way == Way.Id.BERSERK and had == 0:
		for fid in c.world.factions:
			FactionAI.shift(c.world, fid, FactionAI.BAND, -10)
		_say("Word of it goes round the halls, and the lords like him the less.")
	return true


func _work_here() -> Array:
	var p := here()
	if Families.is_foe(c.world_rules, c.band, p.family):
		return []
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
		c.band.known_places[str(r.voyage_required)] = true
	else:
		_finish_work(o, true)


func _finish_work(o: Dictionary, success: bool) -> void:
	var wr := c.world_rules
	Contracts.complete(wr, c.world, c.band, o, success, said)
	_work_standing(o, success)
	if success:
		Way.add_deed(c.band, Way.Id.KINGS_MAN, wr.deed_contract)
		Sandbox._promote(c, said)
		c.tally.contracts = c.tally.get("contracts", 0) + 1
	_pass(float(int(o.get("days", 10))))


func _holmgang(p: Place) -> void:
	var wr := c.world_rules
	var terms := Callings.holmgang_terms(wr, c.world, c.band, p)
	Callings.challenge(wr, c.world, c.band, p, terms, said)
	if Callings.holmgang_yields(_fork("yield"), c.band):
		Callings.after_holmgang(wr, c.world, c.band, p, terms, 1, true, said, _fork("holm_feud"))
		_pass(float(wr.holmgang_days))
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
	_pass(float(wr.thing_days))
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
				false, true, {"kind": "thing", "family": family}, str(br.text), true)


# --- The houses ----------------------------------------------------------------------

## Moves the band's standing with a house (and its ties, Families.shift);
## nothing for a name that is no house.
func _shift(family: String, delta: int) -> void:
	if c.world.families != null and family != "":
		c.world.families.shift(c.world_rules, c.band, family, delta)


## The spring among the houses: men sent after the band by a house at feud
## with it, and what the houses ask of it this year.
## The year the saga began.
func first_summer() -> bool:
	return c.cal.year == c.rules.start_year


func _houses_spring() -> void:
	var fs := c.world.families
	if fs == null:
		return
	var wr := c.world_rules
	var band := c.band
	if first_summer():
		_moods()
		return
	var sent := 0
	var r := _fork("avengers")
	for f in band.unsettled_feuds():
		var fam := str(f.get("family", f.get("against", "")))
		var h := fs.house(fam)
		if h == null or sent >= wr.avengers_max or r.randf() >= wr.avenger_chance:
			continue
		var a := roam.add_avengers(wr, c.world, fam, h.seat, mini(wr.avenger_men, h.strength), band.ship != null)
		if a != null:
			sent += 1
			_say("Word comes that %s have sent men out to look for you." % fam)
	for d in fs.asks(_fork("asks"), wr, c.world, band, c.cal.year):
		# A house that has sent word asking silver of the band this spring
		# does not also offer it silver.
		var asking := false
		for e in decisions:
			if e.kind == "demand" and str(e.family) == str(d.house):
				asking = true
		if d.ask == "compensation" and asking:
			continue
		decisions.append(d)
	_moods()


## Every house's men abroad read the band as their house does: they leave a
## well-wisher alone and hunt a blood-enemy (Families.party_mood). Men sent
## after the band go home once the feud is ended.
func _moods() -> void:
	var wr := c.world_rules
	for p in roam.parties.duplicate():
		if p.family == "":
			continue
		if p.kind == "avengers" and Feud.find(c.band, p.family).is_empty():
			roam.parties.erase(p)
			continue
		p.mood = Families.party_mood(wr, c.band, p.family)
		if p.kind == "avengers":
			p.mood = mini(p.mood, 0)


func _answer_house(d: Dictionary, id: String) -> void:
	var fs := c.world.families
	var wr := c.world_rules
	var band := c.band
	var name := str(d.house)
	var h := fs.house(name)
	var who := band.leader.display_name
	match str(d.ask):
		"help":
			var against := str(d.against)
			var foe := fs.house(against)
			match id:
				"stand":
					var men := Sandbox._forced(c, mini(wr.house_fight_men, foe.strength))
					_offer_fight("men of %s" % against, wr.house_fight_tier, men, true, wr.house_fight_stat, false, false,
							{"kind": "house_fight", "client": name, "family": against},
							"%s goes with the men of %s against %s." % [who, name, against], true)
				"speak":
					band.pledges[name] = {"against": against, "year": c.cal.year}
					_say("%s gives his word to speak for %s against %s at the Thing this summer." % [who, name, against])
				"carry":
					var roll := band.leader.stat(CombatTypes.Stat.WITS) + _fork("peace").roll_2d6() + int(band.gift("law", 0))
					if roll >= wr.peace_difficulty:
						fs.settle_between(name, against)
						_shift(name, wr.standing_help_won / 2)
						_shift(against, wr.standing_help_won / 2)
						band.honor = clampi(band.honor + wr.peace_honor, 0, 100)
						Way.add_deed(band, Way.Id.LAWMAN, wr.deed_counsel)
						_say("%s carries an offer of settlement between %s and %s, and both take it (%d against %d)." % [
								who, name, against, roll, wr.peace_difficulty])
					else:
						_shift(name, wr.standing_refused)
						_say("%s carries an offer of settlement to %s, but they will not hear of it (%d against %d)." % [
								who, against, roll, wr.peace_difficulty])
					_pass(float(wr.counsel_days))
				_:
					_shift(name, wr.standing_refused)
					_say("%s keeps out of the quarrel between %s and %s; %s think the less of him for it." % [who, name, against, name])
		"marry":
			if id == "accept" and band.wife == "":
				fs.marry_into(wr, c.rules, _fork("marry"), band, name, str(d.bride), said)
				_say("%s's house and yours are one by marriage now." % h.head)
			else:
				_shift(name, wr.standing_refused)
				_say("%s declines the match with thanks; %s are not pleased." % [who, name])
		"foster":
			if id == "accept":
				fs.foster_for(wr, band, name, said)
			else:
				_shift(name, wr.standing_refused)
				_say("%s will not foster the boy; %s remember it." % [who, name])
		"compensation":
			var f := Feud.find(band, name)
			if f.is_empty():
				return
			if id == "take":
				band.silver += int(d.ounces)
				f["settled"] = true
				f["verdict"] = "wergild taken"
				band.fame = clampi(band.fame + wr.compensation_fame, 0, 100)
				band.log("%s took wergild from %s and the feud was ended" % [who, name])
				_say("%s takes %d oz of wergild from %s, and the feud is ended." % [who, int(d.ounces), name])
			else:
				var men2 := Sandbox._forced(c, mini(wr.avenger_men, h.strength))
				var stat2 := wr.feud_stat_base + 1
				if name == band.vengeance:
					men2 = mini(int(fs.reckoning_terms(wr, band, name).men), Campaign.MAX_FIGHTERS)
					stat2 = wr.vengeance_stat
				_offer_fight("men of %s" % name, wr.house_fight_tier, men2, true, stat2, false, false,
						{"kind": "blood", "family": name}, "%s will have blood, not silver, from %s." % [who, name], true)


## What a fight among the houses came to: standing with them for help
## given, the feud ended by blood, the reckoning.
func _after_house_fight(ctx: Dictionary, result: BattleResult) -> void:
	var wr := c.world_rules
	var fs := c.world.families
	var band := c.band
	var won := result != null and result.winner == 0
	var fam := str(ctx.get("family", ""))
	match str(ctx.kind):
		"house_fight":
			var client := str(ctx.client)
			if result == null:
				_shift(client, wr.standing_refused)
			elif won:
				_shift(client, wr.standing_help_won)
				_shift(fam, wr.standing_help_against)
				var pr := fs.pair(client, fam)
				if not pr.is_empty():
					pr.ledger.kills[client] = int(pr.ledger.kills.get(client, 0)) + 1
				_say("%s and the men of %s have the better of %s, and %s will not forget who stood with them." % [
						band.leader.display_name, client, fam, client])
			else:
				_shift(client, wr.standing_refused)
				_shift(fam, wr.standing_help_against / 2)
		"blood", "reckoning":
			var f := Feud.find(band, fam)
			if won and not f.is_empty():
				f["settled"] = true
				f["verdict"] = "blood"
				f["mended"] = true  # ended by the sword: no warmth comes of it
				var fame := wr.blood_fame if ctx.kind == "blood" else wr.reckoning_fame
				band.fame = clampi(band.fame + fame, 0, 100)
				band.log("%s ended the feud with %s by the sword" % [band.leader.display_name, fam])
				_say("The feud with %s is ended by the sword." % fam)
				if ctx.kind == "reckoning":
					var h := fs.house(fam)
					_say("%s falls in the fight; %s his son holds the house now, and wants no more of you." % [h.head, h.heir])
					fs._succeed(_fork("reckoned"), h)
					h.strength = maxi(3, roundi(h.strength * (1.0 - wr.burning_strength_loss)))
					for friend in ctx.get("friends", []):
						_shift(str(friend), wr.standing_reckoning_won)
			elif ctx.kind == "reckoning":
				for friend in ctx.get("friends", []):
					_shift(str(friend), wr.standing_reckoning_lost)
			elif result != null and not won and not f.is_empty():
				Feud.escalate(wr, band, fam, said)


## A house whose men the band has killed thinks the worse of it for each,
## and may take up a feud (the band's own fights with it aside).
func _killed_their_men(ctx: Dictionary, result: BattleResult) -> void:
	var fs := c.world.families
	if fs == null or result == null:
		return
	var fam := str(ctx.get("family", ""))
	if fam == "" and ctx.get("place", null) is Place:
		fam = (ctx.place as Place).family
	var party: Roam.Party = ctx.get("party", null)
	if fam == "" and party != null:
		fam = party.family
	if fam == "" or not fs.houses.has(fam) or result.dead.size() < 2:
		return
	var dead: int = result.dead[1]
	if dead <= 0:
		return
	var wr := c.world_rules
	_shift(fam, wr.standing_per_kill * dead)
	if Feud.find(c.band, fam).is_empty() and str(ctx.get("kind", "")) != "blood" and str(ctx.get("kind", "")) != "reckoning" \
			and _fork("kill_feud").randf() < wr.kill_feud_chance:
		Feud.start(wr, c.band, fam, "the killing of their men", fs.house(fam).seat, said)


## What a lord's work did to the houses: the house of the place it was
## given at is the warmer for it done; the house it was taken from (a debt
## collected, tribute gathered) the colder.
func _work_standing(o: Dictionary, success: bool) -> void:
	var wr := c.world_rules
	var giver: Place = c.world.place(str(o.get("at", "")))
	if giver != null:
		_shift(giver.family, wr.standing_contract if success else wr.standing_refused)
	if success and (o.kind == "debt" or o.kind == "tribute"):
		var from: Place = c.world.place(str(o.get("to_place", "")))
		if from != null:
			_shift(from.family, wr.standing_contract_against)


## The deeds among the houses at a place: a gift, rest for the hurt, men
## lent, wergild offered, the reckoning, and at a Thing speaking for a
## house the band has promised.
func _house_actions(p: Place) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fs := c.world.families
	if fs == null:
		return out
	var wr := c.world_rules
	var band := c.band
	var year := c.cal.year
	if p.kind == WorldTypes.PlaceKind.THING_SITE and not Outlawry.is_outlawed(band, c.cal):
		for client in band.pledges:
			var pl: Dictionary = band.pledges[client]
			out.append({"id": "speak:" + str(client), "label": "Speak for %s against %s" % [client, pl.against],
					"hint": "As you promised. A verdict for them settles their feud and makes them your friends; %s will resent it. %d days." % [
							pl.against, wr.thing_days]})
	var h := fs.house(p.family)
	if h == null or h.seat != p.id:
		return out
	var step := Families.step_of(wr, band, h.name)
	out.append({"id": "gift", "label": "Give %s a gift (%d oz)" % [h.head, wr.gift_ounces], "enabled": band.silver >= wr.gift_ounces,
			"hint": "%s think of you as %s. A gift would bring them nearer by about %d." % [Journey._cap(h.name),
					Families.step_phrase(step), Families.gift_worth(wr, band, h.name, year)]})
	var favour: Dictionary = band.favours.get(h.name, {})
	if Families.standing(band, h.name) >= wr.standing_well_wisher and not band.hurt(c.rules).is_empty() \
			and int(favour.get("heal", -1)) != year:
		out.append({"id": "heal", "label": "Rest your hurt men with %s" % h.name,
				"hint": "%d days in their hall: the hurt mend %d turns." % [wr.heal_days, wr.heal_turns]})
	var lend := int(wr.men_lent.get(Families.support_step(wr, band, h.name), 0))
	if lend > 0 and int(favour.get("men", -1)) != year and band.living_men().size() < c.rules.recruit_cap:
		out.append({"id": "men", "label": "Ask %s for men" % h.head, "hint": "Your friends will lend you %d of their men for the summer and after." % lend})
	var f := Feud.find(band, h.name)
	if not f.is_empty():
		var ask := Feud.offer_settlement(wr, band, h.name)
		out.append({"id": "wergild", "label": "Offer %s wergild (%d oz)" % [h.name, ask], "enabled": band.silver >= ask,
				"hint": "Silver for the feud over %s: it ends it, and they think the better of you for it." % str(f.get("cause", "an old wrong"))})
		var t := fs.reckoning_terms(wr, band, h.name)
		var friends: Array = t.friends
		var allies: Array = t.allies
		if not fs.abroad(h.name):
			out.append({"id": "reckoning", "label": "Bring your friends against %s" % h.name, "enabled": int(favour.get("reckoning", -1)) != year,
					"hint": "They have %d men%s. %s Against you: about %d." % [int(t.house_men),
							(", and %s send them %d more" % [", ".join(PackedStringArray(allies)), int(t.allied)]) if not allies.is_empty() else "",
							("%s send %d men with you." % [", ".join(PackedStringArray(friends)), int(t.sent)]) if not friends.is_empty() \
									else "None of their enemies is your friend yet, and you would go alone.", int(t.men)]})
	return out


## Does one of `_house_actions`. False when the id is not one.
func _act_house(id: String, p: Place) -> bool:
	var fs := c.world.families
	if fs == null:
		return false
	var wr := c.world_rules
	var band := c.band
	var year := c.cal.year
	if id.begins_with("speak:"):
		_speak(id.trim_prefix("speak:"))
		return true
	var h := fs.house(p.family)
	if h == null:
		return false
	var favour: Dictionary = band.favours.get(h.name, {})
	match id:
		"gift":
			fs.give_gift(wr, c.world, band, h.name, said)
			_pass(float(wr.gift_days))
		"heal":
			favour["heal"] = year
			band.favours[h.name] = favour
			band.mend(wr.heal_turns)
			_say("%s's men rest %d days in the hall of %s, and the hurt mend." % [band.leader.display_name, wr.heal_days, h.name])
			_pass(float(wr.heal_days))
		"men":
			favour["men"] = year
			band.favours[h.name] = favour
			var lend := int(wr.men_lent.get(Families.support_step(wr, band, h.name), 0))
			for i in lend:
				var m := Recruits.random(_fork("lent"), c.rules, band.next_id())
				m.lent_by = h.name
				band.add_man(m)
				_say("%s, one of %s's men, comes to %s's band." % [m.display_name, h.head, band.leader.display_name])
			c._arm_new_men()
			_pass(float(wr.gift_days))
		"wergild":
			var ask := Feud.offer_settlement(wr, band, h.name)
			if Feud.settle(wr, band, h.name, ask, said):
				Way.add_deed(band, Way.Id.LAWMAN, wr.deed_settle)
			_pass(float(wr.gift_days))
		"reckoning":
			# Once a summer: the friends' men do not come twice.
			if int(favour.get("reckoning", -1)) == year:
				return true
			favour["reckoning"] = year
			band.favours[h.name] = favour
			var t := fs.reckoning_terms(wr, band, h.name)
			var friends: Array = t.friends
			if not friends.is_empty():
				_say("%s send men: %d of them stand with you against %s." % [", ".join(PackedStringArray(friends)), int(t.sent), h.name])
			var center := int(wr.defender_stat_by_kind[p.kind] + p.defenses * wr.defender_stat_per_defense)
			if h.name == band.vengeance:
				center = wr.vengeance_stat  # the jarl's picked men, not farmers
			_offer_fight("the reckoning with %s" % h.name, wr.house_fight_tier, int(t.men), true, clampi(center, 1, 10), false, false,
					{"kind": "reckoning", "family": h.name, "friends": friends}, "%s comes to %s for the reckoning." % [band.leader.display_name, p.display_name], true)
		_:
			return false
	return true


## Speaks for a house the band has promised at the Thing it is at: a case
## of the client's against the other side (Thing, with `client` set).
func _speak(client: String) -> void:
	var wr := c.world_rules
	var band := c.band
	if not band.pledges.has(client):
		return
	var against := str(band.pledges[client].against)
	band.pledges.erase(client)
	_say("%s speaks for %s against %s at the Thing." % [band.leader.display_name, client, against])
	ThingPlay.begin(self, against, "speak", client)


# --- The market -----------------------------------------------------------------

## The goods here: [{good, name, buy, sell, stock, have}], prices as this
## band would pay and be paid. Empty where there is no market.
func market() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := here()
	if p == null or (not p.has_market and p.trade.is_empty()) or Outlawry.door_shut(self, p, "market") != "":
		return out
	for g in WorldTypes.Good.values():
		if not p.has_market and not p.trade.has(g):
			continue  # a farm's stall: what it makes and what it lacks
		var stock := int(p.stock.get(g, 0)) if Market.sells_here(p, g) else 0
		var have := int(c.band.cargo.get(g, 0))
		if stock <= 0 and have <= 0 and p.has_market:
			continue
		out.append({"good": g, "name": WorldTypes.GOOD_NAMES[g], "stock": stock, "have": have,
				"buy": Market.buy_price(c.world_rules, p, c.band, g) if Market.sells_here(p, g) else 0,
				"sell": Market.sell_price(c.world_rules, p, c.band, g) if Market.buys_here(p, g) else 0,
				"can_buy": Market.sells_here(p, g), "can_sell": Market.buys_here(p, g)})
	return out


## What sells where, as far as the band has seen (Knowledge.price_book):
## {places: [{id, name, when, rows: [{good, name, buy, sell}]}], runs:
## [{good, name, from_name, buy, to_name, sell, margin}]}.
func price_book() -> Dictionary:
	if here() != null:
		Knowledge.see_prices(c.world_rules, c.world, c.band, here().id, c.cal.day)
	return Knowledge.price_book(c.world_rules, c.world, c.band, c.cal.day)


## The men for hire where the band is (Hiring.men_for_hire): [{i, name,
## text, price, wage, tier, loyalty, stats}]. Hire one with act("hire:<i>").
func men_for_hire() -> Array[Dictionary]:
	return Hiring.men_for_hire(self)


func buy(good: int, units: int) -> int:
	if not can_act() or Outlawry.door_shut(self, here(), "market") != "":
		return 0
	_market_days()
	return Market.buy(c.world_rules, here(), c.band, good as WorldTypes.Good, units, said)


func sell(good: int, units: int) -> int:
	if not can_act() or Outlawry.door_shut(self, here(), "market") != "":
		return 0
	_market_days()
	return Market.sell(c.world_rules, here(), c.band, good as WorldTypes.Good, units, said)


## The days a market costs, once a visit.
func _market_days() -> void:
	if _traded_at != c.band.location:
		_traded_at = c.band.location
		_pass(float(c.world_rules.market_days))
		# Custom at a house's market makes a well-wisher of it, no more.
		var p := here()
		var wr := c.world_rules
		if p != null and Families.standing(c.band, p.family) < wr.standing_trade_cap:
			_shift(p.family, wr.standing_trade)


# --- Settling up ------------------------------------------------------------------

## After anything has happened: finish what waits on it, as far as the
## next thing a person must answer.
func _settle() -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		if c.over:
			decisions.clear()
			fight = {}
			roam.stop()
			return
		if c.world.families != null:
			c.world.families.sync(c.world_rules, c.band)
		if not decisions.is_empty() or not fight.is_empty() or winter_hall != null:
			return
		c.band.location = roam.grid.place_at(roam.pos)
		if not contract.is_empty() and c.band.location == str(contract.get("to_place", "")):
			var o := contract
			contract = {}
			_finish_work(o, true)
			continue
		if not wintering and days_left() <= 0:
			_say("The season is closing: there is no more travelling this year.")
			wintering = true
		if wintering:
			_end_of_summer()
			_winter()
			continue
		return


## What the summer leaves undone when the band turns for its winter
## quarters: a partner's goods unsold, a merchant unguarded, men lent by a
## house going home, a stolen ship not won back.
func _end_of_summer() -> void:
	TradeRoad.end_of_summer(self)
	Hiring.end_of_summer(self)
	WorldLife.end_of_summer(self)


func _winter() -> void:
	wintering = false
	roam.stop()
	var wr := c.world_rules
	var band := c.band
	var p := here()
	if p == null or not SETTLED.has(p.kind) or Outlawry.winter_shut(self, p) != "":
		# Caught out by the snow (or at a door that is shut): the band makes for the nearest roof it
		# knows; with none, it makes a camp where it stands.
		var best := ""
		var best_d := INF
		for id in band.known_places:
			var q := c.world.place(id)
			if q != null and q.is_open(c.world.year) and SETTLED.has(q.kind) and q.pos.distance_to(roam.pos) < best_d \
					and Outlawry.winter_shut(self, q) == "":
				best_d = q.pos.distance_to(roam.pos)
				best = id
		if best != "":
			if band.ship != null and roam.aboard:
				roam.ship_at = Vector2.INF  # she comes with them
			roam.pos = MapGrid.centre(roam.grid.place_cell[best])
			roam.aboard = band.ship != null and roam.ship_at == Vector2.INF
			band.location = best
			p = here()
			_say("The snow catches the band abroad: it makes for %s." % p.display_name)
		else:
			p = null
			_say("The snow catches the band in the wilds with no roof it knows of: it makes a camp.")
	# A promise to speak for a house at the Thing that was not kept.
	for client in band.pledges.keys():
		if int(band.pledges[client].get("year", -1)) <= c.cal.year:
			_say("%s did not come to the Thing for %s as he said he would, and they say so." % [band.leader.display_name, client])
			_shift(str(client), wr.standing_pledge_broken)
			band.pledges.erase(client)
	# A feud he said he would answer at the Thing and did not goes on.
	for f in band.unsettled_feuds():
		if int(f.get("at_thing", -1)) == c.cal.year:
			Feud.escalate(wr, band, str(f.get("family", f.get("against", ""))), said)
	if not contract.is_empty():
		Contracts.complete(wr, c.world, band, contract, false, said)
		contract = {}
	c._settle_vow()
	_law_land_winter(p)
	winter_begin(p)
	if not stepped_winter:
		winter_auto(false)


# --- The winter in the hall ------------------------------------------------------------

## The band goes into its winter quarters at `p` (null: a camp in the
## wilds): the lodging is settled and the hall opened (WinterHall.open).
func winter_begin(p: Place) -> void:
	var band := c.band
	winter_report = PackedStringArray()
	winter_hall = WinterHall.open(self, p)
	var h := winter_hall
	if p != null and h.lodging != "home":
		band.home = p.id
	match h.lodging:
		"guest":
			_say("%s winters at %s as a guest (%d oz for the lodging)." % [band.leader.display_name, p.display_name, h.fee])
		"friend":
			_say("%s winters at %s as the guest of %s, who will take nothing for it." % [band.leader.display_name, p.display_name, p.family])
		"lord":
			_say("%s winters in %s's hall at %s, as his man." % [band.leader.display_name, h.host, p.display_name])
		"home", "again":
			_say("%s winters at %s." % [band.leader.display_name, p.display_name])


## Whether the band is in its winter quarters, choosing.
func in_winter() -> bool:
	return winter_hall != null


## The winter's step as plain values for the screen (WinterHall.state), or
## {} in summer.
func winter_state() -> Dictionary:
	return winter_hall.state(self) if winter_hall != null else {}


## Makes one winter choice by its id (the buttons' ids in `winter_state`),
## or "next" / "back". "next" from the hall's talk lives through the
## winter; "next" from the spring begins the summer (`winter_end`).
func winter_choose(id: String) -> void:
	if winter_hall == null:
		return
	if id == "next" and winter_hall.step == WinterHall.SPRING:
		winter_end()
		return
	winter_hall.choose(self, id)
	if winter_hall.resolved and c.over:
		winter_end()


## Keeps the choices as they stand (the sensible defaults, or what was
## chosen) and goes on to the spring: what the stand-in players and the
## tools use.
func winter_auto(settle := true) -> void:
	if winter_hall == null:
		return
	winter_hall.resolve(self)
	winter_end(settle)


## The winter is over: lived through if it was not yet, the band goes where
## the summer begins, and the next spring begins (or the saga is ended).
func winter_end(settle := true) -> void:
	if winter_hall == null:
		return
	var h := winter_hall
	h.resolve(self)
	winter_hall = null
	_say("Winter of %d passes." % c.cal.year)
	if c.over:
		_say("The saga of %s ends here: %s." % [Way.title(c.band), c.over_reason])
		return
	h.go_in_spring(self)
	if stepped_winter:
		winter_report = PackedStringArray()  # read on the winter screen already
	c.cal.next_year()
	c.band.year = c.cal.year
	begin_summer()
	if settle:
		_settle()


# --- Law, land and the unfree (docs/design/notes/law-land.md) ---------------------------

## The spring of the law, the land, the unfree and the omens: the hunters
## for an outlaw, summons and favours called in, the lord's summons and a
## land quarrel, men sold on east, the year's omen and fate.
func _law_land_spring() -> void:
	Outlawry.spring(self)
	ThingPlay.spring(self)
	Landtake.spring(self)
	Thralls.spring(self)
	Omens.spring(self)


func _law_land_tick(days: float) -> void:
	Outlawry.tick(self)
	Landtake.tick(self)
	Thralls.tick(self, days)


func _law_land_actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(Outlawry.actions(self))
	out.append_array(ThingPlay.actions(self))
	out.append_array(Landtake.actions(self))
	out.append_array(Thralls.actions(self))
	return out


func _act_law_land(id: String) -> bool:
	return Outlawry.act(self, id) or ThingPlay.act(self, id) or Landtake.act(self, id) or Thralls.act(self, id)


func _answer_law_land(d: Dictionary, id: String) -> void:
	match str(d.kind):
		"thing":
			if str(d.step) == "summons" or str(d.step) == "favour":
				ThingPlay.answer_spring(self, d, id)
			else:
				ThingPlay.answer(self, d, id)
		"land":
			Landtake.answer(self, d, id)
		"unfree":
			Thralls.answer(self, d, id)
		"omen":
			Omens.answer(self, d, id)


func _law_land_after_fight(ctx: Dictionary, result: BattleResult) -> void:
	Outlawry.after_fight(self, ctx, result)
	Landtake.after_fight(self, ctx, result)
	Thralls.after_fight(self, ctx, result)
	Thralls.lost_fight(self, ctx, result)
	if str(ctx.get("kind", "")) == "raid" and result != null and result.winner == 0:
		Thralls.after_raid(self, ctx.place)


## A spine event's answer that takes the band somewhere: Rollo's exile, the
## way to Iceland, the men who want land let go west.
func _law_land_spine(ev: Dictionary, id: String, r: Dictionary) -> void:
	if r.get("exile", false):
		Outlawry.join_rollo(self)
	if str(ev.id) != "iceland_opens":
		return
	var band := c.band
	match id:
		"sail_iceland":
			band.known_places["iceland"] = true
			band.known_places["orkney"] = true
			_say("%s means to go out to Iceland: the way is by Orkney and seven days of open sea, and a household and its beasts want a knarr." % band.leader.display_name)
		"send_settlers":
			var went := PackedStringArray()
			for m in band.living_men():
				if m.ambition == CampaignTypes.Ambition.LAND:
					band.remove_man(m)
					went.append(m.display_name)
			if went.is_empty():
				_say("None of %s's men cares to go so far for land." % band.leader.display_name)
			else:
				band.honor = clampi(band.honor + mini(3, went.size()), 0, 100)
				_say("%s lets %s go west with his blessing and a gift, to take land in Iceland." % [band.leader.display_name, ", ".join(went)])
				band.log("%s let %s go west to Iceland" % [band.leader.display_name, ", ".join(went)])


## Into the winter: a summons not answered is judged; the lesser outlaw's
## exile is counted; the keepers come in; the thralls' unrest.
func _law_land_winter(p: Place) -> void:
	ThingPlay.judge_absent(self)
	Outlawry.on_winter(self, p)
	Landtake.on_winter(self, p)
	Thralls.on_winter(self, p)


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
		"title": Way.title(band), "way": Way.standing(band), "points": Way.points_free(band), "where": whereabouts(),
		"ship_with": roam.aboard, "ship_trouble": ship_trouble(), "year": c.cal.year, "day": c.cal.day,
		"days_left": maxi(0, days_left()), "silver": band.silver, "food": band.food,
		"men": band.fighters(c.rules).size(), "hurt": band.hurt(c.rules).size(),
		"ship": WorldTypes.SHIP_NAMES[band.ship.kind] if band.ship != null else "no ship",
		"ship_damage": band.ship.damage if band.ship != null else 0,
		"cargo": ", ".join(cargo), "cargo_room": Market.cargo_room(c.world_rules, band), "captives": band.captives,
		"luck": band.luck, "fame": band.fame, "honor": band.honor, "rank": WorldTypes.RANK_NAMES[band.rank],
		"feuds": band.unsettled_feuds().size(), "work": str(contract.get("text", "")),
		"outlaw": Outlawry.is_outlawed(band, c.cal),
		"outlaw_kind": ("" if not Outlawry.is_outlawed(band, c.cal) else ("full" if band.outlawry == WorldTypes.Outlawry.FULL else "lesser")),
		"luck_words": Omens.luck_words(band.luck), "land": band.land, "thralls": band.thralls.size(), "unrest": band.unrest,
		"settled_iceland": band.settled_iceland,
	}


## The line with its first letter raised, the rest as it is.
static func _cap(s: String) -> String:
	return s if s == "" else s[0].to_upper() + s.substr(1)


func _say(line: String) -> void:
	said.append(line)


func _fork(label: String) -> SimRng:
	_n += 1
	return _rng.fork("%s:%d" % [label, _n])
