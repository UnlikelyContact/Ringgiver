extends TestCase
## Generations (docs/design/notes/generations.md): the years let pass, the
## household, the death and the grave-ale played, the saga and its ends.


## A saga played to its first winter by the stand-in player, the winter
## lived through and standing at the spring step.
func _at_spring(seed_in: int, origin := "younger_son", bent := Way.Id.VIKING) -> Journey:
	var j := Journey.begin(seed_in, origin, "Egil")
	j.played_succession = true
	JourneyBot.play_year(j, bent, true)
	var guard := 0
	while j.in_winter() and guard < 12 and int(j.winter_state().step) < WinterHall.SPRING:
		guard += 1
		j.winter_choose("next")
	return j


## Clears the spine's choices so the years can run on.
func _no_spine(j: Journey) -> void:
	for ev in j.c.world_rules.spine:
		j.c.world.timeline_state[ev.id] = true


## Quiets the houses, so that no ask of theirs stops the years before the
## thing under test does: feuds settled, no house a friend, none bound to his.
func _no_houses(j: Journey) -> void:
	for f in j.c.band.feuds:
		f.settled = true
	for n in j.c.band.standing.keys():
		j.c.band.standing[n] = 0
	j.c.band.house_ties.clear()


func _let(j: Journey, n: int) -> Dictionary:
	j.winter_choose("years:%d" % n)
	j.winter_choose("next")
	return j.years_told


func test_years_pass_deterministically() -> void:
	var a := _at_spring(5)
	var b := _at_spring(5)
	_no_spine(a)
	_no_spine(b)
	a.c.band.silver = 400
	b.c.band.silver = 400
	var ta := _let(a, 3)
	var tb := _let(b, 3)
	assert_eq(int(ta.passed), int(tb.passed), "the same years pass")
	assert_eq(a.c.cal.year, b.c.cal.year)
	assert_eq(a.c.band.silver, b.c.band.silver)
	assert_eq(a.c.band.living_men().size(), b.c.band.living_men().size())
	assert_true(int(ta.passed) >= 1, "at least a year passes (%s: %s)" % [ta.stopped, ta.why])
	assert_eq(a.c.cal.year, 867 + int(ta.passed), "the calendar turns once a year passed")
	assert_true(not a.in_winter(), "the summer begins")
	assert_true((ta.lines as PackedStringArray).size() >= int(ta.passed), "each year writes the chronicle")
	assert_true(" ".join(ta.lines).contains("nothing is told of him"))
	var quiet: Array = a.c.band.get_meta(Chronicle.QUIET_META)
	assert_eq(quiet.size(), int(ta.passed))
	assert_true(a.c.band.leader.age >= 23 + int(ta.passed), "he grows older")


func test_years_stop_for_the_spine() -> void:
	var j := _at_spring(5)
	var told := _let(j, 10)
	# 867 is quiet; Harald takes the Trondelag in 868 and asks who stands where.
	assert_eq(str(told.stopped), "spine")
	assert_eq(j.c.cal.year, 868)
	assert_eq(int(told.passed), 1)
	var spine := false
	for d in j.decisions:
		if str(d.kind) == "spine":
			spine = true
	assert_true(spine, "the event waits for him in the summer")


func test_years_stop_for_each_interrupt() -> void:
	# A vow to keep.
	var j := _at_spring(6)
	_no_spine(j)
	j.c._pending_vow = "to win two fights"
	assert_true(Years.blocked(j) != "", "a vow due blocks the years")
	# A son of fostering age, a son come of age, a daughter to marry.
	for what in ["son12", "son16", "daughter"]:
		j = _at_spring(6)
		_no_spine(j)
		var y := j.c.cal.year + 1
		var child := {"name": "Thorstein", "born": y - (12 if what == "son12" else 16), "alive": true, "daughter": what == "daughter",
				"fostered_with": "", "father": "Egil", "potential": [5, 5, 5, 5, 5]}
		if what == "daughter":
			child.born = y - j.c.rules.daughter_marry_age
		j.c.band.sons.append(child)
		var told := _let(j, 5)
		assert_eq(str(told.stopped), "son" if what != "daughter" else "daughter", what)
		assert_eq(int(told.passed), 0, what)
	# An attack on the hall: the fight waits at his door.
	j = _at_spring(7, "burned_hall")
	_no_spine(j)
	j.c.rules.years_attack_chance = 1.0
	var t2 := _let(j, 5)
	assert_eq(str(t2.stopped), "attack")
	var fight := false
	for d in j.decisions:
		if str(d.kind) == "fight" and str((d.ctx as Dictionary).get("kind", "")) == "feud":
			fight = true
	assert_true(fight, "the house comes against the hall")
	# Stores run out.
	j = _at_spring(8)
	_no_spine(j)
	_no_houses(j)
	j.c.band.silver = 0
	j.c.band.food = 0
	j.c.rules.years_food_per_man = 0
	var t3 := _let(j, 5)
	assert_eq(str(t3.stopped), "stores")
	# Death in his bed.
	j = _at_spring(9)
	_no_spine(j)
	_no_houses(j)
	j.c.band.silver = 500
	j.c.band.leader.age = 70
	j.c.rules.old_leader_death_chance = 1.0
	var t4 := _let(j, 5)
	assert_eq(str(t4.stopped), "death")
	assert_true(not j.c.over)
	assert_eq(str(j.current().get("step", "")), "death", "the death card comes first")
	# A kinsman's ask: a house bound to his is at feud and asks for help.
	j = _at_spring(10, "burned_hall")
	_no_spine(j)
	j.c.band.silver = 500
	for f in j.c.band.feuds:
		f.settled = true
	var fs := j.c.world.families
	var friend := ""
	for n in fs.names():
		if not (j.c.band.house_ties.get(n, []) as Array).is_empty() and j.c.band.knows(fs.house(n).seat):
			friend = n
			break
	assert_true(friend != "", "the burned man has kin")
	j.c.band.standing[friend] = 60
	for n in fs.names():
		if n != friend and not Families.is_friend(j.c.world_rules, j.c.band, n) and fs.house(n).seat != "":
			fs.add_tie(friend, n, "feud", 866)
			break
	j.c.world_rules.ask_chance = 1.0
	var t5 := _let(j, 5)
	assert_eq(str(t5.stopped), "house")


## Sitting at home is not a way to grow rich: a year let pass brings in no
## more than the land yields, and the band that sits out its summers ends
## poorer than the one that plays them.
## What the band is worth: the chest, the land at what it sells for, and
## the hull (a saga that plays its summers turns silver into both).
func _worth(j: Journey) -> int:
	var wr := j.c.world_rules
	var band := j.c.band
	var w := band.silver + band.land * int(wr.land_price)
	if band.ship != null:
		w += int(wr.ship_price.get(band.ship.kind, 0))
	return w


func test_passing_years_is_not_richer() -> void:
	var gain_sit := 0
	var gain_play := 0
	for s in [11, 12, 13]:
		var j := _at_spring(s)
		_no_spine(j)
		var land := j.c.band.land * j.c.world_rules.land_silver_per_unit
		var before := j.c.band.silver
		var told := _let(j, 1)
		if int(told.passed) == 1:
			assert_true(j.c.band.silver <= before + land, "seed %d: a year at home %d -> %d" % [s, before, j.c.band.silver])
		# Two sagas from the same start: one plays four summers, one sits.
		var play := _at_spring(s)
		var sit := _at_spring(s)
		_no_spine(sit)
		var start := _worth(play)
		play.winter_choose("next")
		for y in 3:
			JourneyBot.play_year(play, Way.Id.VIKING)
		_let(sit, 3)
		while sit.c.cal.year < play.c.cal.year and not sit.c.over:
			JourneyBot.play_year(sit, Way.Id.VIKING)
		gain_play += _worth(play) - start
		gain_sit += _worth(sit) - start
	print("    years: playing gained %d oz of worth, sitting at home %d (three sagas, four years)" % [gain_play, gain_sit])
	# The sitter is often called out of his hall after a year and plays the
	# rest, so the two run close: sitting must not come out clearly ahead.
	assert_true(gain_sit <= gain_play * 1.1 + 30, "sitting at home is not richer")


func _married(j: Journey) -> String:
	var fs := j.c.world.families
	var house := ""
	for n in fs.names():
		if Families.is_friend(j.c.world_rules, j.c.band, n):
			house = n
			break
	fs.marry_into(j.c.world_rules, j.c.rules, SimRng.new(1), j.c.band, house, "Asgerd", PackedStringArray())
	return house


func _card(j: Journey, what: String) -> int:
	var talk: Array = j.winter_hall.talk
	for i in talk.size():
		if str(talk[i].kind) == "household" and str(talk[i].what) == what:
			return i
	return -1


func _to_talk(j: Journey) -> void:
	j.quick = true
	j.stepped_winter = true
	while not j.decisions.is_empty():
		j.answer(str(j.current().options[0].id))
	j.act("winter")
	while int(j.winter_state().step) < WinterHall.STEPS.find("talk"):
		j.winter_choose("next")


func test_son_born_fostered_returns_joins_and_is_heir() -> void:
	var j := Journey.begin(21, "burned_hall", "Egil")
	j.played_succession = true
	var c := j.c
	var house := _married(j)
	assert_eq(str(c.band.get_meta(Family.WIFE_HOUSE_META)), house, "the wife's house is known")
	c.rules.birth_chance = 1.0
	c.rules.daughter_chance = 0.0
	var born := Family.winter_births(SimRng.new(2), c.rules, c.band, c.cal, PackedStringArray())
	assert_eq(born.size(), 1, "a son is born")
	c.rules.birth_chance = 0.0
	var son: Dictionary = born[0]
	assert_eq(str(son.father), "Egil")
	# Twelve winters on, he is of fostering age.
	son.born = c.cal.year - 12
	_to_talk(j)
	var i := _card(j, "foster")
	assert_true(i >= 0, "the hall asks whether he is to be fostered")
	var opt := ""
	for o in j.winter_hall.talk[i].options:
		if str(o.id).begins_with("foster:"):
			opt = str(o.id)
			break
	var foster_house := opt.trim_prefix("foster:")
	j.winter_choose("talk:%d:%s" % [i, opt])
	j.winter_choose("next")  # the winter is lived
	assert_eq(str(son.fostered_with), foster_house)
	assert_true((c.band.house_ties.get(foster_house, []) as Array).has("foster"), "the house and the band are tied by it")
	assert_true(not Family.at_home(c.rules, son, c.cal.year), "he is away")
	assert_true(j.household().children.size() == 1 and str(j.household().children[0].tag) == "fostered")
	j.winter_auto()
	# He comes home at sixteen: into the band, as the heir.
	son.born = c.cal.year - 16
	_to_talk(j)
	var k := _card(j, "of_age")
	assert_true(k >= 0, "he has come of age")
	assert_true(str(j.winter_hall.talk[k].text).contains("home from"), "home from his fostering")
	j.winter_choose("talk:%d:heir" % k)
	j.winter_choose("next")
	var m := c.band.man_by_id(int(son.man_id))
	assert_true(m != null and c.band.men.has(m), "he is a man of the band")
	assert_true(m.traits.has("fostered with %s" % foster_house), "with something of his foster-father's craft")
	assert_eq(str(c.band.get_meta(Family.HEIR_META)), str(son.name), "named heir")
	j.winter_auto()
	# The father falls: the son is the first the hall names.
	var cands := Succession.candidates(c)
	assert_eq(str(cands[0].kind), "son")
	assert_eq(str(cands[0].name), str(son.name))


func _kill(j: Journey, cause := "battle") -> void:
	j.c.band.leader.alive = false
	j.c.succession(cause)
	j._settle()


## Answers every grave-ale card with `pick` (step -> option id), or the
## stand-in player's answer.
func _hold(j: Journey, pick := {}, stop_at := "") -> void:
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		var d := j.current()
		if str(d.kind) != "saga" or str(d.step) == stop_at:
			break
		var id := str(pick.get(str(d.step), JourneyBot._answer_saga(j, d, Way.Id.VIKING)))
		j.answer(id)


func test_succession_by_son_and_by_second_carry_over() -> void:
	for kind in ["son", "second"]:
		var j := Journey.begin(31, "burned_hall", "Egil")
		j.played_succession = true
		j.quick = true
		var c := j.c
		var band := c.band
		var house := _married(j)
		band.sons.append({"name": "Thorstein", "born": c.cal.year - 17, "alive": true, "daughter": false, "fostered_with": "",
				"father": "Egil", "potential": [6, 6, 6, 6, 6]})
		Way.add_deed(band, Way.Id.VIKING, 30)
		Way.invest(band, Way.Id.VIKING)
		band.luck = 6
		band.fame = 40
		var st := Families.standing(band, house)
		var feuds := band.unsettled_feuds().size()
		var old_hall := band.hall
		_kill(j)
		assert_eq(str(j.current().step), "death")
		var second := band.man_by_id(band.sworn_second_id)
		var pick := {"heir": "son:Thorstein" if kind == "son" else "second:%d" % second.id, "feast": "20", "vow": "peace", "challenge": "pay"}
		_hold(j, pick)
		assert_true(band.leader.alive and band.leader.display_name != "Egil", kind)
		assert_eq(band.unsettled_feuds().size(), feuds, "%s: the feuds carry over in full" % kind)
		assert_eq(band.hall, old_hall, "the hall is his")
		assert_true(band.paths.is_empty(), "%s: his ways are his own" % kind)
		if kind == "son":
			assert_eq(band.leader.display_name, "Thorstein")
			assert_true(Succession.line_holds(band))
			assert_eq(band.luck, roundi(6 * c.rules.luck_inherit_fraction) + c.rules.luck_good_death + c.rules.heir_son_luck)
			assert_eq(str(band.get_meta(Family.MOTHER_META)), "Asgerd, daughter of %s" % c.world.families.house(house).head)
			assert_eq(band.wife, "")
			assert_true((band.house_ties.get(house, []) as Array).has("kin"), "his mother's house is his kin")
			assert_eq(Families.standing(band, house), roundi(st * c.rules.standing_inherit_son))
		else:
			assert_eq(band.leader, second)
			assert_true(not Succession.line_holds(band))
			assert_eq(band.luck, roundi(6 * c.rules.luck_inherit_fraction) + c.rules.luck_good_death)
			assert_true(not (band.house_ties.get(house, []) as Array).has("marriage"), "the marriage was the old man's")
			assert_eq(Families.standing(band, house), roundi(st * c.rules.standing_inherit_second))
		assert_eq(band.fame, roundi(40 * c.rules.fame_inherit_fraction))
		var told := j.saga()
		assert_eq(told.chapters.size(), 2, "%s: two chapters" % kind)


func test_challenge_is_a_holmgang_and_both_outcomes_work() -> void:
	var lost := 0
	var won := 0
	for s in range(40, 52):
		var j := Journey.begin(s, "burned_hall", "Egil")
		j.played_succession = true
		var c := j.c
		var band := c.band
		band.sons.append({"name": "Thorstein", "born": c.cal.year - 15, "alive": true, "daughter": false, "fostered_with": "",
				"father": "Egil", "potential": [3, 3, 3, 3, 3]})
		var second := band.man_by_id(band.sworn_second_id)
		for st in 5:
			second.stats[st] = 8
		_kill(j)
		_hold(j, {"heir": "son:Thorstein", "feast": "0", "vow": "peace"}, "challenge")
		var d := j.current()
		assert_eq(str(d.get("step", "")), "challenge", "seed %d: the strong second disputes the seat" % s)
		j.answer("fight")
		assert_true(not j.fight.is_empty() and j.fight.built.get("duel", false), "fought on the battle screen as a holmgang")
		assert_eq(str(j.fight.ctx.kind), "challenge")
		var battle: Battle = j.fight.built.battle
		var result := battle.run()
		j.fight_done(result)
		if band.leader.alive and band.leader.display_name == "Thorstein":
			won += 1
			assert_true(band.men.has(second) or not second.alive)
		elif band.leader == second:
			lost += 1
			assert_true(band.men.any(func(m: Man) -> bool: return m.display_name == "Thorstein"), "the heir goes down to the benches")
		assert_true(not band.has_meta(Succession.PENDING_CHALLENGE_META))
		var step := str(j.current().get("step", ""))
		assert_true(step == "told" or step == "death", "seed %d: the saga goes on (%s)" % [s, step])
	# Both outcomes, forced.
	var j2 := Journey.begin(60, "burned_hall", "Egil")
	var ch := j2.c.band.man_by_id(j2.c.band.sworn_second_id)
	var heir := j2.c.band.leader
	Succession.challenge_done(j2.c, ch, false, PackedStringArray())
	assert_eq(j2.c.band.leader, ch, "lost: the challenger holds the seat")
	assert_true(j2.c.band.men.has(heir))
	var j3 := Journey.begin(61, "burned_hall", "Egil")
	var ch3 := j3.c.band.man_by_id(j3.c.band.sworn_second_id)
	var fame := j3.c.band.fame
	Succession.challenge_done(j3.c, ch3, true, PackedStringArray())
	assert_eq(j3.c.band.fame, fame + j3.c.rules.challenge_won_fame, "won: it is talked of")
	print("    challenges: the heir won %d, the second %d of 12" % [won, lost])


func test_first_summer_death_ends_in_succession_or_an_ending() -> void:
	for s in range(70, 76):
		var j := Journey.begin(s, "burned_hall", "Egil")
		j.played_succession = true
		j.quick = true
		_kill(j)
		assert_eq(str(j.current().step), "death", "seed %d: the death card" % s)
		_hold(j)
		assert_true(j.c.over or (j.c.band.leader.alive and j.c.pending_death.is_empty()), "seed %d: never a stall" % s)
		if not j.c.over:
			assert_true(j.c.band.vengeance != "", "the name's vengeance is taken up")
			JourneyBot.play_year(j, Way.Id.VIKING)
			assert_true(j.c.cal.year > 866 or j.c.over, "seed %d: the year goes on" % s)
	# His men all dead: the band scatters, and the saga ends properly.
	var j2 := Journey.begin(80, "burned_hall", "Egil")
	j2.played_succession = true
	for m in j2.c.band.men.duplicate():
		j2.c.band.remove_man(m)
	j2.c.band.sworn_second_id = -1
	_kill(j2)
	var d := j2.current()
	assert_eq(str(d.options[0].id), "scatter")
	j2.answer("scatter")
	assert_true(j2.c.over)
	assert_eq(str(j2.c.band.get_meta(Chronicle.ENDING_META).kind), "no_heir")
	assert_true(j2.c.over_reason.contains("line died out"))


func test_saga_text_tells_each_generation() -> void:
	var j := _at_spring(90, "burned_hall")
	_no_spine(j)
	j.c.band.silver = 300
	j.c.rules.years_attack_chance = 0.0
	_let(j, 2)
	JourneyBot.play_year(j, Way.Id.VIKING)
	_kill(j)
	_hold(j)
	var heir := j.c.band.leader.display_name
	JourneyBot.play_year(j, Way.Id.VIKING)
	var s := j.saga()
	var text := str(s.text)
	assert_true(str(s.title).begins_with("The saga of Egil Hardanger-son"), str(s.title))
	assert_eq(s.chapters.size(), 2)
	assert_true(text.contains("There was a man named Egil"))
	assert_true(text.contains("%s took the high seat" % heir), "the second generation")
	assert_true(text.contains("Then nothing is told of Egil for"), "the years let pass")
	assert_true(text.contains("vowed at the grave-ale"), "the grave-ale")
	assert_true(text.contains("burning of the hall at Hardanger"), "the feud")
	assert_true(text.contains("A skald made this about him"), "the verse")
	assert_true(text.contains("He died in"), "his death")


func test_endings_trigger_on_their_conditions() -> void:
	# Vengeance taken: the arc is offered; ending it closes the saga.
	var j := Journey.begin(100, "burned_hall", "Egil")
	j.played_succession = true
	for f in j.c.band.feuds:
		f.settled = true
	j._vengeance()
	assert_eq(str(j.current().step), "arc")
	j.answer("go_on")
	assert_true(not j.c.over, "but the saga does not end there")
	j._vengeance()
	assert_true(j.decisions.is_empty() or str(j.current().get("step", "")) != "arc", "offered once")
	j.offer_ending("iceland")
	j.answer("end")
	assert_true(j.c.over)
	var r := Chronicle.reckoning(j.c.band, j.c.rules)
	assert_true(str(r.ending).contains("Iceland"))
	assert_true(str(r.verdict) != "")
	assert_true(" ".join(r.lines).contains("was answered"), "the vengeance is reckoned")
	assert_true(str(j.saga().text).contains("Here the saga ends"))
	# A jarl: offered when he reaches the rank.
	var k := Journey.begin(101, "younger_son", "Egil")
	k.c.band.rank = WorldTypes.Rank.JARL
	k._settle()
	assert_eq(str(k.current().get("arc", "")), "jarl")
	# Old age: the death card may end it.
	var o := Journey.begin(102, "younger_son", "Egil")
	o.played_succession = true
	o.c.band.leader.age = 66
	_kill(o, "old")
	var ids := []
	for opt in o.current().options:
		ids.append(str(opt.id))
	assert_true(ids.has("end"), "an old man's death may end the saga")
	o.answer("end")
	assert_true(o.c.over)
	assert_eq(str(o.c.band.get_meta(Chronicle.ENDING_META).kind), "old_age")


func test_step_down_and_the_old_man() -> void:
	var j := _at_spring(110)
	var band := j.c.band
	band.leader.age = j.c.rules.step_down_age + 2
	var father := band.leader.display_name
	band.sons.append({"name": "Hrafn", "born": j.c.cal.year - 18, "alive": true, "daughter": false, "fostered_with": "",
			"father": father, "potential": [5, 5, 5, 5, 5]})
	var s := j.winter_state()
	var found := false
	for r in s.rows:
		if str(r.title).begins_with("Step down"):
			found = true
	assert_true(found, "the spring offers to step down")
	j.winter_choose("stepdown:son:Hrafn")
	j.winter_choose("next")
	assert_eq(band.leader.display_name, "Hrafn")
	var old: Dictionary = band.get_meta(Family.OLD_MAN_META)
	assert_eq(str(old.name), father)
	assert_true(not j.household().old_man.is_empty(), "the old man sits by the fire")
	j.c.rules.old_man_death_chance = 1.0
	Family.old_folk_year(SimRng.new(1), j.c.rules, band, j.c.cal, PackedStringArray())
	assert_true(old.get("dead", false))
	assert_true(str(j.saga().text).contains("He died in his bed in"), "the chronicle keeps the line")


func test_bot_plays_twelve_years_with_deaths_and_never_stalls() -> void:
	var j := Journey.begin(120, "burned_hall", "Egil")
	JourneyBot.let_years = 3  # some summers sat out: fewer to play, and the years tested with the deaths
	var deaths := 0
	var y := 0
	while j.c.cal.year < 878 and y < 12:
		y += 1
		if j.c.over:
			break
		if y == 2 or y == 4 or y == 6:
			j.played_succession = true
			if j.c.band.leader.alive and j.c.pending_death.is_empty():
				_kill(j)
				deaths += 1
		var before := j.c.cal.year
		JourneyBot.play_year(j, Way.Id.VIKING)
		assert_true(j.c.cal.year > before or j.c.over, "year %d: no stall (day %d, decisions %d)" % [before, j.c.cal.day, j.decisions.size()])
	JourneyBot.let_years = 0
	assert_true(deaths >= 2, "deaths forced: %d" % deaths)
	assert_true(j.c.over or j.c.cal.year >= 878, "twelve years or an ending")
	assert_true(Chronicle.chapters(j.c.band).size() >= 2 or j.c.over)


func test_old_succession_callers_unchanged() -> void:
	var c := Campaign.new(42)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 4)
	var second := c.band.man_by_id(c.band.sworn_second_id)
	c.band.leader.alive = false
	c.succession("battle")
	assert_true(c.pending_death.is_empty(), "no grave-ale waits for the AI")
	assert_eq(c.band.leader, second, "the second takes the seat at once")
	var j := Journey.begin(43, "younger_son", "Egil")
	assert_true(not j.played_succession, "off unless asked for")
