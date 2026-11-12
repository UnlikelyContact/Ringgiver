extends TestCase
## The whole-game pass (docs/design/notes/balance.md): the slave market a
## stock and captives a burden, luck that wanders, the band's ceiling of
## benches and thwarts, the years that pass on a standing word, the heir's
## answers to a challenge, the benches judging by the chest, the outlaw's
## land, the vengeance's outlook and the stand-in player's housekeeping.


func _free(j: Journey) -> void:
	var guard := 0
	while not j.decisions.is_empty() and guard < 30:
		guard += 1
		var d := j.current()
		var last: Dictionary = d.options[d.options.size() - 1]
		j.answer(str(last.id))


func _quiet(seed_in: int, origin: String, at: String) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	_free(j)
	j.roam.parties.clear()
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	j.c.band.location = at
	return j


func _men(j: Journey, n: int) -> void:
	var band := j.c.band
	while band.living_men().size() < n:
		band.add_man(Recruits.random(SimRng.new(band.next_id() * 7), j.c.rules, band.next_id()))


# --- Captives ---------------------------------------------------------------------------

func test_a_slave_market_fills_and_mends_by_the_day() -> void:
	var j := _quiet(3, "younger_son", "dublin")
	var wr := j.c.world_rules
	var dublin := j.c.world.place("dublin")
	j.c.band.captives = 10
	var got := Thralls.sell(j, dublin)
	assert_true(dublin.captives_sold < 10, "the market stops buying before ten: %d sold" % dublin.captives_sold)
	assert_true(got < 10 * wr.captive_price_dublin / 2, "ten heads fetch under half the full price: %d oz" % got)
	assert_true(j.c.band.captives > 0, "the rest are left on his hands")
	var full := dublin.captives_sold
	Thralls._captives_tick(j, float(wr.captive_mend_days) * 2.0)
	assert_eq(dublin.captives_sold, full - 2, "two heads of the glut mend in twice the days")


func test_captives_are_a_burden_and_selling_costs_honor() -> void:
	var j := _quiet(4, "younger_son", "dublin")
	var wr := j.c.world_rules
	var band := j.c.band
	var room := Market.cargo_room(wr, band)
	var pace := j.foot_speed()
	band.captives = 8
	assert_eq(Market.cargo_room(wr, band), maxi(0, room - 8 / wr.captive_load), "bound people take room")
	assert_true(j.foot_speed() < pace, "more captives than men slow the march")
	# Over a month on the road some of them slip away.
	Thralls._captives_tick(j, 30.0)
	assert_true(band.captives < 8, "captives slip away: %d of 8 left" % band.captives)
	band.captives = 8
	var honor := band.honor
	var dublin := j.c.world.place("dublin")
	dublin.captives_sold = 0
	Thralls.sell(j, dublin)
	assert_true(band.honor < honor, "men think the less of a slaver (%d -> %d)" % [honor, band.honor])


func test_their_kin_ransom_only_their_own_people() -> void:
	var j := _quiet(3, "younger_son", "fitjar")
	var band := j.c.band
	var wr := j.c.world_rules
	band.captives = 4
	band.law["captives_from"] = {"Hrafn's kin": 4}
	Thralls.after_raid(j, j.c.world.place("avaldsnes"))
	var d := j.current()
	var house := str(d.house)
	assert_true(band.captives >= 4)
	var from: Dictionary = band.law.captives_from
	var theirs := int(from[house])
	var silver := band.silver
	var before := band.captives
	j.answer("ransom")
	assert_eq(band.captives, before - theirs, "the other house's people are still bound")
	assert_true(band.silver - silver <= Thralls.ransom_for(j, theirs, true), "and are not paid for")
	assert_true(band.silver > silver)


# --- Luck -------------------------------------------------------------------------------

func test_luck_crests_and_drifts_back() -> void:
	var c := Campaign.new(1)
	var band := Band.new()
	var rules := c.rules
	var log := PackedStringArray()
	band.luck = rules.luck_crest
	Leader.on_battle(rules, band, true, true, 1.0, log, BattleResult.Outcome.WON_THE_FIELD)
	assert_eq(band.luck, rules.luck_crest, "a plain win adds nothing at the crest")
	Leader.on_battle(rules, band, true, true, 0.5, log, BattleResult.Outcome.WON_THE_FIELD)
	assert_eq(band.luck, rules.luck_crest + rules.luck_long_odds - 1, "a win against the odds still lifts it, less")
	band.luck = rules.luck_crest - 1
	Leader.on_battle(rules, band, true, true, 1.0, log, BattleResult.Outcome.WON_THE_FIELD)
	assert_eq(band.luck, rules.luck_crest, "below the crest a win lifts it")
	# On the map a win at the crest lifts it now and then, rarer higher up.
	var lifted := [0, 0]
	for i in 400:
		for k in 2:
			band.luck = rules.luck_crest + k
			Leader.on_battle(rules, band, true, true, 1.0, log, BattleResult.Outcome.WON_THE_FIELD, SimRng.new(i))
			lifted[k] += 1 if band.luck > rules.luck_crest + k else 0
	assert_between(lifted[0], 70, 130, "a quarter of wins at the crest")
	assert_between(lifted[1], 10, 45, "a sixteenth a point above")
	band.luck = 9
	Leader.winter_drift(rules, band, log)
	assert_eq(band.luck, 8, "high luck is talked of less over a winter")
	band.luck = 1
	Leader.winter_drift(rules, band, log)
	assert_eq(band.luck, 2, "ill luck is forgotten too")
	band.luck = 5
	Leader.winter_drift(rules, band, log)
	assert_eq(band.luck, 5, "the middle stays")


# --- The band's ceiling -----------------------------------------------------------------

func test_benches_and_thwarts_are_the_ceiling() -> void:
	var j := _quiet(3, "younger_son", "fitjar")
	var c := j.c
	var band := c.band
	assert_eq(c.room(), c.rules.room_min, "no hull, a host's benches")
	band.ship = Ship.new()
	band.ship.kind = WorldTypes.ShipKind.KARVE
	assert_eq(c.room(), int(c.world_rules.ship_crew[WorldTypes.ShipKind.KARVE]), "a karve's thwarts")
	band.ship.kind = WorldTypes.ShipKind.LONGSHIP
	assert_eq(c.room(), c.rules.room_max_karl, "below a hersir, a snekkja's crew at most")
	band.rank = WorldTypes.Rank.HERSIR
	assert_eq(c.room(), mini(c.rules.room_max, int(c.world_rules.ship_crew[WorldTypes.ShipKind.LONGSHIP])), "a lord's longship")
	band.rank = WorldTypes.Rank.KARL
	band.ship = null
	var hall := Hall.ensure(band, c.rules)
	hall.seats = 20
	assert_eq(c.room(), 20, "a great hall's benches")
	hall.seats = c.rules.hall_base_seats
	assert_eq(Campaign.new(1).room(), c.rules.recruit_cap, "without a map the old cap")
	# Full: no man for hire, no lent men, nobody asks to join after a fight.
	_men(j, c.room())
	for a in j.actions():
		if str(a.id).begins_with("hire:"):
			assert_true(not a.get("enabled", true), "hiring is shut when the benches are full")
			assert_true(str(a.hint).contains("no bench"), "and says why")
		assert_true(str(a.id) != "men", "friends lend no men past the benches")


func test_the_stand_in_lets_go_the_men_he_cannot_seat() -> void:
	var j := Journey.begin(7, "younger_son", "Egil")
	JourneyBot.play_year(j, Way.Id.TRADER, true)
	assert_true(j.in_winter())
	j.c.band.ship = null
	_men(j, j.c.room() + 4)
	JourneyBot.winter(j, Way.Id.TRADER)
	assert_true(j.c.band.living_men().size() <= j.c.room() + 1, "the men beyond the benches are let go: %d for %d" % [
			j.c.band.living_men().size(), j.c.room()])


# --- The years and the hall's word -----------------------------------------------------

func test_offers_are_answered_by_the_hall_s_word() -> void:
	var j := _quiet(5, "younger_son", "fitjar")
	var band := j.c.band
	var house := "Hrafn's kin"
	band.add_feud(house, "a killing")
	var silver := band.silver
	Years._standing_answer(j, {"ask": "compensation", "house": house, "ounces": 20}, "accept")
	assert_true(Feud.find(band, house).is_empty(), "fair wergild taken: the feud ended")
	assert_eq(band.silver, silver + 20)
	band.add_feud(house, "another killing")
	Years._standing_answer(j, {"ask": "compensation", "house": house, "ounces": 20}, "refuse")
	assert_true(not Feud.find(band, house).is_empty(), "let lie: the feud stays open")
	assert_eq(int((j.c.tally.years_answered as Dictionary).compensation), 2)
	# The word is chosen at the spring step, beside the years.
	var h := WinterHall.new()
	Years.choose(j, h, "offers", "accept")
	assert_eq(h.years_offers, "accept")
	Years.choose(j, h, "offers", "nonsense")
	assert_eq(h.years_offers, "")


# --- The grave-ale's challenge ----------------------------------------------------------

func test_the_heir_has_honest_answers_to_a_challenge() -> void:
	var j := Journey.begin(40, "burned_hall", "Egil")
	var c := j.c
	var band := c.band
	_men(j, 8)
	var ch := band.man_by_id(band.sworn_second_id)
	for m in band.living_men():
		if m != band.leader and m != ch:
			m.loyalty = 80
	var back := Succession.backing(c, ch)
	assert_true(bool(back.enough), "loyal men behind the blood: %d of %d" % [int(back.ours), int(back.all)])
	for m in band.living_men():
		if m != band.leader and m != ch:
			m.loyalty = 30
	assert_true(not bool(Succession.backing(c, ch).enough), "not when they waver")
	assert_true(Succession.champion_for(c, ch) == null, "no man stands for a leader his men waver over")
	for m in band.living_men():
		m.loyalty = 80
	var champ := Succession.champion_for(c, ch)
	assert_true(champ != null and champ != ch and champ != band.leader, "a loyal champion can be found")
	ch.ambition = CampaignTypes.Ambition.SILVER
	var cheap := Succession.buyoff_price(c, ch)
	ch.ambition = CampaignTypes.Ambition.FAME
	var dear := Succession.buyoff_price(c, ch)
	assert_true(dear > cheap, "a man who wants fame wants the seat itself: %d against %d" % [dear, cheap])
	var ids := PackedStringArray()
	for o in j._challenge_options(ch):
		ids.append(str(o.id))
	assert_true(ids.has("fight") and ids.has("champion") and ids.has("back") and ids.has("pay") and ids.has("go"), str(ids))
	# The champion's holmgang is fought by the champion.
	var built := c.build_duel(ch.to_warrior(1, c.rules, 0), 5, champ)
	assert_eq((built.fighters as Array)[0], champ)


# --- The winter's ring-giving ------------------------------------------------------------

func test_the_benches_judge_by_the_chest() -> void:
	var rules := CampaignRules.new()
	assert_eq(WinterHall.miser_line(rules, 6, 20), 2, "a thin chest is forgiven a thin Yule")
	assert_eq(WinterHall.miser_line(rules, 6, 400), 6, "a full one owes a ring a man")


# --- The outlaw's land -------------------------------------------------------------------

func test_an_outlaw_s_land_is_forfeit_or_held_by_kin() -> void:
	for wed in [false, true]:
		var j := _quiet(3, "younger_son", "jaeren")
		var band := j.c.band
		Landtake.add_holding(band, "jaeren", 2, "bought", j.c.cal.year)
		if wed:
			band.wife = "Hallgerd"
		Outlawry.declare(j.c.world_rules, band, j.c.cal, true, j.said)
		Landtake.outlaw_land(j)
		assert_eq(band.land, 0, "an outlaw holds no land in Norway")
		if not wed:
			assert_true(band.holdings.is_empty(), "the king takes it")
			continue
		assert_eq(band.holdings.size(), 1, "his wife's kin hold it")
		var yielded := Landtake.thaw_yield(j.c.world_rules, band, j.c.cal.year, PackedStringArray())
		assert_eq(int(yielded.silver), 0, "and it yields him nothing")
		Outlawry.pardon(j, "Egil pays for his peace")
		assert_eq(band.land, 2, "his peace made, it is his again")


func test_the_stand_in_outlaw_seeks_his_peace() -> void:
	var j := _quiet(3, "younger_son", "fitjar")
	var band := j.c.band
	Outlawry.declare(j.c.world_rules, band, j.c.cal, true, j.said)
	band.silver = Outlawry.pardon_price(j.c.world_rules, band) + 100
	var to := Outlawry.pardon_road(j, Way.Id.VIKING)
	assert_true(to != "", "he knows a king's hall to go to")
	assert_true(Outlawry._king_of(j, j.c.world.place(to)) != null)


# --- The vengeance ----------------------------------------------------------------------

func test_the_vengeance_outlook_says_what_is_lacking() -> void:
	var j := Journey.begin(3, "burned_hall", "Egil")
	var v := j.vengeance_outlook()
	assert_true(bool(v.owed))
	assert_eq(str(v.house), j.c.band.vengeance)
	assert_eq(bool(v.ready), int(v.short) == 0, "ready when nothing is short")
	assert_true((v.lines as PackedStringArray).size() >= 2)
	assert_true(not (v.could_win as Array).is_empty() or not bool(v.ready), "who could be won when not ready")
	assert_true(not bool(Journey.begin(3, "younger_son", "Egil").vengeance_outlook().owed), "none owed by a younger son")


func test_the_king_judges_for_his_great_man() -> void:
	var j := Journey.begin(3, "burned_hall", "Egil")
	_free(j)
	j.roam.parties.clear()
	var at := ""
	var ids: Array = j.c.world.places.keys()
	ids.sort()
	for id in ids:
		if Outlawry._king_of(j, j.c.world.place(str(id))) != null:
			at = str(id)
			break
	assert_true(at != "", "a king has a hall")
	j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[at])
	j.c.band.location = at
	var king := Outlawry._king_of(j, j.here())
	var act := j._king_justice()
	assert_true(not act.is_empty() and not act.get("enabled", true), "greyed for a man who is not his jarl")
	j.c.band.rank = j.c.world_rules.king_justice_rank
	FactionAI.shift(j.c.world, king.id, FactionAI.BAND, 100)
	act = j._king_justice()
	assert_true(act.get("enabled", true), str(act.get("hint", "")))
	assert_true(bool(j.vengeance_outlook().king_ready))
	var house := j.c.band.vengeance
	j.act("king_justice")
	assert_eq(j.c.band.vengeance, "", "the burning is answered by the king's word")
	assert_true(Feud.find(j.c.band, house).is_empty())


## The challenge at the grave-ale as the stand-in heir meets it, over twelve
## seeds where the second is much the stronger (in
## test_generations::test_challenge_is_a_holmgang the heir always fights
## and loses all twelve): the men, silver, a champion or the island.
func test_the_challenge_is_no_foregone_loss() -> void:
	var kept := 0
	var ways := {}
	for s in range(40, 52):
		var j := Journey.begin(s, "burned_hall", "Egil")
		j.played_succession = true
		j.quick = true
		var c := j.c
		var band := c.band
		_men(j, 6)
		band.sons.append({"name": "Thorstein", "born": c.cal.year - 15, "alive": true, "daughter": false, "fostered_with": "",
				"father": "Egil", "potential": [3, 3, 3, 3, 3]})
		var second := band.man_by_id(band.sworn_second_id)
		for st in 5:
			second.stats[st] = 8
		band.leader.alive = false
		c.succession("battle")
		j._settle()
		var guard := 0
		while not j.decisions.is_empty() and guard < 20:
			guard += 1
			var d := j.current()
			if str(d.kind) != "saga":
				break
			var pick := JourneyBot._answer_saga(j, d, Way.Id.VIKING)
			if str(d.step) == "heir":
				pick = "son:Thorstein"
			if str(d.step) == "challenge":
				ways[pick] = int(ways.get(pick, 0)) + 1
			j.answer(pick)
		if band.leader != null and band.leader.display_name == "Thorstein":
			kept += 1
	print("    the heir kept the seat %d of 12: %s" % [kept, str(ways)])
	assert_true(kept >= 3, "the heir has honest ways to keep his seat: %d of 12" % kept)


func test_the_hall_warns_when_the_band_outgrows_its_boat() -> void:
	var j := Journey.begin(7, "younger_son", "Egil")
	JourneyBot.play_year(j, Way.Id.SKALD, true)
	assert_true(j.in_winter())
	j.c.band.ship = Ship.make(WorldTypes.ShipKind.FAERING)
	_men(j, 6)
	j.winter_choose("goto:%d" % WinterHall.STEPS.find("men"))
	var notes := " ".join(j.winter_state().notes)
	assert_true(notes.contains("will not put to sea"), notes)


func test_the_saga_tells_oaths_by_the_count_and_no_line_twice() -> void:
	var j := Journey.begin(3, "younger_son", "Egil")
	var band := j.c.band
	var y := j.c.cal.year
	for pair in [["Ketil", "Orm"], ["Hrafn", "Bard"], ["Ulf", "Grim"]]:
		band.log("%s and %s mixed their blood under the turf and swore to avenge each other." % pair)
	band.log("Egil and Ketil mixed their blood under the turf and swore to avenge each other.")
	band.log("Egil heeded an omen.")
	band.log("Egil heeded an omen.")
	band.log("An outlaw came through the snow asking shelter, and was taken in.")
	var text := str(Chronicle.saga(band).text)
	assert_true(text.contains("Three pairs of his men mixed their blood"), text)
	assert_true(text.contains("Egil and Ketil mixed their blood"), "his own oath is told")
	assert_eq(text.count("heeded an omen"), 1, "a line is told once a year")
	assert_true(not text.contains("Hrafn and Bard"))
	assert_true(not text.contains("asking shelter"), "a man taken in is one who came to his benches")
	assert_true(y > 0)


## The stall found in the batches: ashore by shipwreck at the very place a
## guarded merchant was bound, the stand-in "went" there for ever. Going
## where he already is is no going, and the guard is paid off there.
func test_no_going_where_he_already_is() -> void:
	var j := _quiet(3, "younger_son", "orkney")
	assert_true(not JourneyBot._go(j, "orkney"), "already there")
	j.life["escort"] = {"to": "orkney", "pay": 20, "by": 999.0, "family": "", "party": null}
	var silver := j.c.band.silver
	TradeRoad.check_escort(j)
	assert_true(j.life.get("escort", {}).is_empty(), "the guard is done")
	assert_eq(j.c.band.silver, silver + 20)
