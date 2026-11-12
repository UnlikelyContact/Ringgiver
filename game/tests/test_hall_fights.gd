extends TestCase
## Fights at a hall by night: your own hall defended in the winter (the
## spears in the snow, the fire in the night) through the battle screen and
## back into the stepped winter, the break-out or the hold-and-burn, and the
## hall's fate. See docs/design/notes/saga-fights.md.


func _ready(seed_in: int, played := true) -> Journey:
	var j := Journey.begin(seed_in, "burned_hall", "Egil")
	j.quick = true
	var guard := 0
	while not j.decisions.is_empty() and guard < 20:
		guard += 1
		j.answer(str(j.current().options[0].id))
	j.stepped_winter = true
	for i in 6:
		var m := Recruits.random(SimRng.new(300 + i), j.c.rules, j.c.band.next_id())
		m.loyalty = 50
		j.c.band.add_man(m)
	j.c._arm_new_men()
	j.act("winter")
	j.quick = not played
	return j


## Puts a feud's card at the head of the hall's talk and lives the winter
## through to it.
func _feud_card(j: Journey, kind: String, how: String) -> void:
	var h := j.winter_hall
	var card := WinterEvents.card(SimRng.new(5), j.c.rules, j.c.band, kind)
	WinterHall._hall_fight_card(j.c, SimRng.new(6), card)
	card.choice = how
	h.talk.insert(0, card)
	h.step = WinterHall.STEPS.find("talk")
	j.winter_choose("next")


func test_the_hall_at_night_is_laid_out_and_the_same_from_the_same_seed() -> void:
	var rules := CombatRules.new()
	for burning in [false, true]:
		var a := Scenario.build_hall_defence(4, rules, {}, burning, "bar")
		var b := Scenario.build_hall_defence(4, rules, {}, burning, "bar")
		var ba: Battle = a.battle
		assert_true(ba.night, "it is night")
		assert_eq((a.objective as Objective).attacker, 1, "they come for the hall")
		assert_eq((a.objective as Objective).kind, Objective.Kind.FIRE if burning else Objective.Kind.THE_HALL)
		assert_eq(ba.grid.terrain_at(a.door), CombatTypes.Terrain.DOOR)
		ba.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
		(b.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
		ba.run()
		(b.battle as Battle).run()
		assert_eq(ba.result.summary(), (b.battle as Battle).result.summary())
		assert_eq("\n".join(ba.log).hash(), "\n".join((b.battle as Battle).log).hash())
	var burn := Scenario.build_hall_burning(4, rules)
	var bb: Battle = burn.battle
	assert_true(bb.night and bb.hall_alight and bb.ai_breaks_out)
	assert_eq((burn.objective as Objective).attacker, 1, "their men break out; ours are the ring")


func test_held_at_the_walls_the_roof_takes() -> void:
	var rules := CombatRules.new()
	var sc := Scenario.build_hall_defence(8, rules, {}, true, "meet")
	var b: Battle = sc.battle
	var obj: Objective = sc.objective
	var g := b.grid
	# Two of theirs at the walls, nobody of ours near: round after round of fire.
	var torch: Array[Warrior] = []
	for w in b.side_warriors(1):
		if torch.size() < rules.fire_men:
			torch.append(w)
	var k := 0
	for c in obj.cells:
		if k < torch.size() and g.is_free(c):
			g.remove(torch[k])
			g.place(torch[k], c)
			k += 1
	var decided := -1
	for r in range(1, rules.fire_rounds + 1):
		b.round = r
		decided = obj.check(b)
	assert_eq(decided, 1, "%d rounds at the walls and the roof takes" % rules.fire_rounds)
	assert_true(b.hall_alight and obj.taken)


func test_a_played_hall_fight_stops_the_winter_and_it_goes_on_after() -> void:
	var j := _ready(21)
	var h := j.winter_hall
	_feud_card(j, "feud_attack", "bar")
	assert_true(not j.fight.is_empty(), "the fight waits for the battle screen")
	assert_eq(str(j.fight.ctx.kind), "hall")
	assert_true(h.paused(j), "the winter waits on it")
	var step := h.step
	j.winter_choose("next")
	assert_eq(h.step, step, "nothing goes on while the fight waits")
	var b: Battle = j.fight.built.battle
	assert_true(b.night, "at night")
	var built_offer: FightOffer = j.fight.offer
	assert_eq(built_offer.ground, "hall")
	assert_true(not built_offer.allows(FightOffer.Choice.FADE_AWAY), "no fading from your own hall")
	assert_eq(built_offer.title(FightOffer.Choice.WAIT_FOR_THEM), "Bar the door and hold the yard", "no ford at your own hall")
	# They are beaten off: every one of them down.
	for w in b.side_warriors(1):
		w.wound = CombatTypes.Wound.DOWN
		b.grid.remove(w)
	b.run_round()
	assert_true(b.is_over() and b.result.winner == 0)
	var lines := j.fight_done(b.result)
	assert_true(not lines.is_empty(), "the fight is told")
	assert_true(not h.paused(j), "the winter goes on")
	assert_true(h.resolved and not h.told.is_empty(), "and is lived through and told")
	assert_true(j.c.band.leader.alive)


func test_a_hall_taken_loses_its_store() -> void:
	var j := _ready(22)
	j.c.band.food = 40
	_feud_card(j, "feud_attack", "meet")
	var b: Battle = j.fight.built.battle
	for w in b.side_warriors(0):
		if not w.is_leader:
			w.wound = CombatTypes.Wound.DOWN
			b.grid.remove(w)
	for w in b.side_warriors(0):
		w.broken = true
		w.morale = 0
	b.run_round()
	assert_true(b.is_over() and b.result.winner == 1, "the band is broken")
	var food_before := j.c.band.food
	j.fight_done(b.result)
	assert_true(j.c.band.food < food_before, "they carry off the store (%d of %d left)" % [j.c.band.food, food_before])


func _lose_the_walls(j: Journey) -> void:
	var b: Battle = j.fight.built.battle
	for w in b.side_warriors(0):
		w.broken = true
		w.morale = 0
	b.run_round()
	j.fight_done(b.result)


func test_the_roof_burns_and_the_leader_holds_and_burns() -> void:
	var j := _ready(23)
	var band := j.c.band
	var hall := Hall.ensure(band, j.c.rules)
	hall.buildings.append(CampaignTypes.Building.STOREHOUSE)
	band.food = 30
	var wife := band.wife
	_feud_card(j, "hall_burning", "bar")
	assert_true(not j.fight.is_empty())
	_lose_the_walls(j)
	var h := j.winter_hall
	assert_true(hall.buildings.is_empty(), "the hall's buildings burn")
	assert_eq(band.food, 0, "and the store")
	assert_eq(band.wife, wife, "the household is let out and lives")
	assert_true(not h.fire.is_empty(), "the choice waits")
	var s := j.winter_state()
	assert_eq(str(s.title), "Fire in the night")
	assert_true(not bool(s.can_next), "no going on without choosing")
	var leader := band.leader
	j.winter_choose("fire:hold")
	assert_true(not leader.alive, "he lies down in the fire")
	assert_true(not h.paused(j), "the winter goes on")
	assert_true(h.resolved)
	assert_true(j.c.over or band.leader != leader, "an heir or the end of the saga")


func test_the_leader_breaks_out_through_the_door() -> void:
	var j := _ready(24)
	_feud_card(j, "hall_burning", "bar")
	_lose_the_walls(j)
	var h := j.winter_hall
	j.winter_choose("fire:out")
	assert_true(not j.fight.is_empty(), "the break-out is a fight of its own")
	assert_eq(str(j.fight.ctx.kind), "breakout")
	var b: Battle = j.fight.built.battle
	assert_true(b.spared.is_empty(), "he is not spared: he may die in the yard")
	b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
	var guard := 0
	while not b.is_over() and guard < 60:
		guard += 1
		if b.can_withdraw(0) and b.withdraw(0):
			break
		b.set_shout(0, Objective.escape_order(b, 0))
		b.run_round()
	if not b.is_over():
		b.run()
	j.fight_done(b.result)
	assert_true(not h.paused(j) and h.resolved, "the winter goes on after the break-out")


func test_unplayed_the_hall_fight_is_fought_at_once() -> void:
	var j := _ready(25, false)
	_feud_card(j, "hall_burning", "meet")
	assert_true(j.fight.is_empty(), "the leader AIs fight it")
	assert_true(j.winter_hall.resolved and not j.winter_hall.paused(j), "and the winter is lived through")


func test_a_warned_hall_may_wait_at_the_gate() -> void:
	var c := Campaign.new(3)
	c.start_from("younger_son", "Egil")
	var warned := c.offer_fight("feud_attack", CombatTypes.Tier.BLOODED, 6, false, -1, false, true, "hall", {"cause": "hall", "warned": true})
	assert_true(warned.allows(FightOffer.Choice.LAY_AMBUSH))
	assert_eq(warned.title(FightOffer.Choice.LAY_AMBUSH), "Lie in wait at the gate")
	var not_warned := c.offer_fight("feud_attack", CombatTypes.Tier.BLOODED, 6, false, -1, false, true, "hall", {"cause": "hall"})
	assert_true(not not_warned.allows(FightOffer.Choice.LAY_AMBUSH))
	assert_true(not not_warned.they_know_first, "nobody is caught on the march at his own hall")
