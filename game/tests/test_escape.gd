extends TestCase
## The burned hall: every saga's first fight, the escape, and the tutorial
## that teaches it (Scenario.build_escape, Objective.Kind.ESCAPE,
## Journey.begin with escape, view/tutorial.gd, view/hints.gd). See
## docs/design/notes/tutorial.md.


## Plays the escape the way the tutorial asks, step by step: Go on, the
## shout it names, Next round, Withdraw. Returns the director (free it).
static func follow_tutorial(b: Battle) -> Tutorial:
	var t := Tutorial.new()
	t.start(b)
	var acts := 0
	while not b.is_over() and acts < 200:
		acts += 1
		var want := t.control()
		if want == "ack":
			t.acknowledge()
		elif want.begins_with("shout:"):
			t.pending = int(want.trim_prefix("shout:")) as CombatTypes.Shout
			t.evaluate()
		elif want == "next":
			if t.pending != CombatTypes.Shout.NONE:
				b.set_shout(0, t.pending)
			b.run_round()
			t.after_round()
		elif want == "withdraw":
			b.withdraw(0)
			t.evaluate()
		else:
			break
	return t


static func _leader_warrior(j: Journey) -> Warrior:
	for w in j.fight.built.ours:
		if (w as Warrior).id == j.c.band.leader.id:
			return w
	return null


func test_the_escape_is_built_the_same_from_the_same_seed() -> void:
	var rules := CombatRules.new()
	var logs: Array[String] = []
	for k in 2:
		var f := Scenario.build_escape(11, rules)
		var b: Battle = f.battle
		assert_eq(f.field_name, "burned_hall")
		assert_true(b.objective != null and b.objective.kind == Objective.Kind.ESCAPE, "the escape's objective")
		assert_eq((f.ours as Array).size(), 3, "you and two men")
		assert_true((f.theirs as Array).size() > 3, "more of them than you can beat")
		assert_eq(b.spared.size(), 1, "the leader is spared")
		var at := PackedStringArray()
		for w in b.warriors:
			at.append("%s@%s" % [w.display_name, w.pos])
		for r in 8:
			b.set_shout(0, CombatTypes.Shout.SHIELD_WALL if r == 0 else CombatTypes.Shout.PUSH)
			b.run_round()
		logs.append(",".join(at) + "|" + "\n".join(b.log))
	assert_eq(logs[0], logs[1], "same seed, same men, same ground, same fight")
	var other := Scenario.build_escape(12, rules)
	assert_ne(str(other.ours[1].display_name) + str(other.theirs[2].display_name),
			"", "another seed draws its own men")


func test_the_thin_place_is_straight_ahead_of_the_door() -> void:
	var f := Scenario.build_escape(3, CombatRules.new())
	var b: Battle = f.battle
	var gap: Array = f.gap
	assert_true(b.grid.occupant(gap[0]) == null, "an empty hex in the ring")
	assert_true(b.grid.occupant(gap[1]) != null and b.grid.occupant(gap[1]).side == 1, "a man either side of it")
	assert_true(b.grid.occupant(gap[2]) != null and b.grid.occupant(gap[2]).side == 1, "a man either side of it")
	var leader: Warrior = f.ours[0]
	assert_eq(BattleGrid.to_offset(gap[0]).x, BattleGrid.to_offset(leader.pos).x, "straight ahead of you")
	assert_eq(b.grid.terrain_at(f.door), CombatTypes.Terrain.DOOR, "the hall's door behind you")


func test_the_fight_ends_when_the_leader_reaches_the_dark() -> void:
	var f := Scenario.build_escape(4, CombatRules.new())
	var b: Battle = f.battle
	var leader: Warrior = f.ours[0]
	assert_eq(b.objective.check(b), -1, "still in the ring")
	var out: Vector2i = b.objective.cells[b.objective.cells.size() / 2]
	b.grid.remove(leader)
	b.grid.place(leader, out)
	b.run_round()
	assert_true(b.is_over(), "out in the dark: the fight is over")
	assert_eq(b.result.how, BattleResult.End.ESCAPE)
	assert_eq(b.result.outcome(0), BattleResult.Outcome.ESCAPED)
	assert_true(b.result.escaped(0), "you got away")
	assert_true(not b.result.won(0), "getting out is not winning: no loot, no fame")
	assert_eq(b.result.outcome(1), BattleResult.Outcome.WON_THE_FIELD, "the burners keep the yard")


func test_the_band_may_slip_away_only_once_through_the_ring() -> void:
	var f := Scenario.build_escape(5, CombatRules.new())
	var b: Battle = f.battle
	assert_true(not b.can_withdraw(0), "the ring stands between you and the dark")
	# Carry the band up past the ring, out of reach of any of them.
	var row := 2
	var col := 5
	for w in f.ours:
		b.grid.remove(w)
		b.grid.place(w, BattleGrid.from_offset(col, row))
		col += 1
	assert_true(b.objective.way_open(b), "nobody of theirs nearer the dark")
	assert_true(b.can_withdraw(0), "through, and out of contact")
	assert_true(b.withdraw(0))
	assert_eq(b.result.how, BattleResult.End.ESCAPE, "slipping away is the escape")
	assert_true(b.result.escaped(0))


func test_the_old_ladder_keeps_its_numbers() -> void:
	assert_eq(BattleResult.End.FIRST_BLOOD, 6)
	assert_eq(BattleResult.End.ESCAPE, 7)
	assert_eq(BattleResult.Outcome.LOST_THE_FIELD, 7)
	assert_eq(BattleResult.Outcome.ESCAPED, 8)
	assert_eq(Objective.DRAWN_KINDS, 3, "a varied field never draws the escape")


func test_a_player_who_follows_the_tutorial_gets_out() -> void:
	var clean := 0
	for s in range(1, 11):
		var j := Journey.begin(s, "burned_hall", "Egil", true)
		var b: Battle = j.fight.built.battle
		var lw := _leader_warrior(j)
		var t := follow_tutorial(b)
		assert_true(b.is_over(), "seed %d: the escape ends" % s)
		assert_eq(t.step, Tutorial.Step.OUT, "seed %d: the tutorial is done" % s)
		assert_true(t.done.has(Tutorial.Step.WALL) and t.done.has(Tutorial.Step.PUSH), "seed %d: the wall and the push are taught" % s)
		t.free()
		if b.result.escaped(0) and not lw.is_down():
			clean += 1
		j.fight_done(b.result)
		assert_true(j.c.band.leader.alive, "seed %d: the leader lives" % s)
	assert_true(clean >= 9, "out on his feet on %d of 10 seeds" % clean)


func test_the_leader_never_dies_whatever_the_player_does() -> void:
	for mode in ["nothing", "charge"]:
		for s in range(1, 31):
			var j := Journey.begin(s, "burned_hall", "Egil", true)
			var b: Battle = j.fight.built.battle
			while not b.is_over() and b.round < 40:
				if mode == "charge":
					b.set_shout(0, CombatTypes.Shout.BREAK_THEM)
				b.run_round()
			if not b.is_over():
				b.run()
			assert_true(b.is_over(), "%s seed %d: it ends" % [mode, s])
			var lines := j.fight_done(b.result)
			var band := j.c.band
			assert_true(band.leader.alive, "%s seed %d: the leader lives" % [mode, s])
			assert_true(not j.c.over, "%s seed %d: the saga goes on" % [mode, s])
			assert_true(band.living_men().size() >= 1, "%s seed %d: someone follows him" % [mode, s])
			assert_true(not lines.is_empty(), "%s seed %d: the night is told" % [mode, s])


func test_the_aftermath_leaves_a_band_that_can_go_on() -> void:
	var j := Journey.begin(6, "burned_hall", "Egil", true)
	assert_true(j.escape_pending(), "the night waits to be fought")
	assert_true(not j.can_act(), "nothing else until it is")
	var b: Battle = j.fight.built.battle
	var t := follow_tutorial(b)
	t.free()
	var lines := j.fight_done(b.result)
	var band := j.c.band
	assert_true(j.fight.is_empty(), "the fight is done")
	assert_eq(band.location, "sogn_farms", "at the kin's farm in Sogn")
	assert_eq(band.silver, 10, "ten ounces: nothing won, nothing lost")
	assert_true(band.ship == null, "no ship")
	assert_true(band.vengeance != "", "the vengeance is the saga")
	assert_true(not Feud.find(band, band.vengeance).is_empty(), "at feud with the burners")
	assert_true(band.chronicle[band.chronicle.size() - 1].contains("burning hall"), "the chronicle begins with the burning")
	var told := " ".join(lines)
	assert_true(told.contains("Sogn"), "how he came to Sogn: " + told)
	assert_eq(j.c.tally.battles, 1, "the first fight of the saga")
	assert_true(not j.c.over)


func test_the_kin_lend_a_man_when_both_fall() -> void:
	var j := Journey.begin(8, "burned_hall", "Egil", true)
	var b: Battle = j.fight.built.battle
	b.rules.fate_dead_below = 99  # whoever goes down here dies
	var lw := _leader_warrior(j)
	for w in j.fight.built.ours:
		if w != lw:
			(w as Warrior).wound = CombatTypes.Wound.DOWN
			b.grid.remove(w)
	b.grid.remove(lw)
	b.grid.place(lw, b.objective.cells[0])
	b.run_round()
	assert_true(b.is_over())
	var lines := j.fight_done(b.result)
	var band := j.c.band
	assert_true(band.leader.alive, "never the leader")
	assert_eq(band.living_men().size(), 1, "one man lent by the kin")
	assert_true(" ".join(lines).contains("lend him"), "it is told")


func test_skipping_lets_the_dice_tell_it() -> void:
	var told: Array[String] = []
	for k in 2:
		var j := Journey.begin(9, "burned_hall", "Egil", true)
		var lines := j.skip_escape()
		assert_true(j.fight.is_empty(), "nothing left to fight")
		assert_true(j.c.band.leader.alive)
		assert_true(not lines.is_empty())
		told.append(" ".join(lines))
	assert_eq(told[0], told[1], "the same night from the same seed")


func test_the_other_beginnings_start_on_the_map() -> void:
	for key in ["younger_son", "freedman"]:
		var j := Journey.begin(4, key, "Egil", true)
		assert_true(not Origins.has_escape(key))
		assert_true(j.fight.is_empty(), "%s: no escape" % key)
		assert_eq(j.c.band.location, str(Origins.def(key).at), "%s: where the origin puts him" % key)
		assert_eq(j.c.band.silver, int(Origins.def(key).silver))
		assert_eq(j.c.band.living_men().size(), int(Origins.def(key).followers))
	var told := Journey.begin(4, "burned_hall", "Egil")
	assert_true(told.fight.is_empty(), "without the escape the burned hall is told, as the stand-in players have it")
	assert_eq(told.c.band.location, "sogn_farms")
	assert_eq((Origins.def("burned_hall").night as Array).size(), 3, "three cards set the night")


func test_the_director_teaches_one_control_at_a_time() -> void:
	var f := Scenario.build_escape(5, CombatRules.new())
	var b: Battle = f.battle
	var t := Tutorial.new()
	t.start(b)
	assert_eq(t.step, Tutorial.Step.WHO)
	assert_eq(t.control(), "ack", "first, read who is who")
	var none: Array[String] = ["none"]
	assert_eq(t.allowed(), none, "nothing on the field to press yet")
	t.acknowledge()
	assert_eq(t.step, Tutorial.Step.WALL)
	var wall := "shout:%d" % CombatTypes.Shout.SHIELD_WALL
	assert_eq(t.control(), wall)
	var only_wall: Array[String] = [wall]
	assert_eq(t.allowed(), only_wall, "only the wall")
	t.pending = CombatTypes.Shout.SHIELD_WALL
	t.evaluate()
	assert_eq(t.control(), "next", "then the round")
	assert_true(t.allowed().has("next") and t.allowed().has(wall))
	b.set_shout(0, CombatTypes.Shout.SHIELD_WALL)
	b.run_round()
	t.after_round()
	assert_eq(t.step, Tutorial.Step.PUSH, "the wall is done: now the push")
	assert_true(t.said != "", "and a line says what the wall did")
	assert_eq(t.control(), "shout:%d" % CombatTypes.Shout.PUSH)
	# A man of yours hurt between rounds: the wound is read, then on.
	t.pending = CombatTypes.Shout.PUSH
	b.set_shout(0, CombatTypes.Shout.PUSH)
	(f.ours[1] as Warrior).wound = CombatTypes.Wound.BRUISED
	b.run_round()
	t.after_round()
	assert_eq(t.step, Tutorial.Step.HURT)
	assert_true(t.text().contains((f.ours[1] as Warrior).display_name), "names the man: " + t.text())
	t.acknowledge()
	assert_eq(t.step, Tutorial.Step.PUSH, "back to the push")
	assert_eq(t.control(), "next", "the push stands: keep going")
	var only_next: Array[String] = ["next"]
	assert_eq(t.allowed(), only_next, "still only the round")
	t.free()


func test_the_director_waits_for_the_way_to_open_before_falling_back() -> void:
	var f := Scenario.build_escape(2, CombatRules.new())
	var b: Battle = f.battle
	var t := Tutorial.new()
	t.start(b)
	t.acknowledge()
	b.set_shout(0, CombatTypes.Shout.SHIELD_WALL)
	b.run_round()
	t.after_round()
	b.set_shout(0, CombatTypes.Shout.PUSH)
	b.run_round()
	t.after_round()
	if t.step == Tutorial.Step.HURT:
		t.acknowledge()
	assert_eq(t.step == Tutorial.Step.FALL_BACK, b.objective.way_open(b), "fall back comes when they are behind you")
	# Through the ring by hand: the next round's end brings the lesson.
	var col := 4
	for w in f.ours:
		b.grid.remove(w)
		b.grid.place(w, BattleGrid.from_offset(col, 2))
		col += 1
	t.evaluate()
	assert_eq(t.step, Tutorial.Step.FALL_BACK)
	assert_eq(t.control(), "shout:%d" % CombatTypes.Shout.FALL_BACK)
	assert_true(t.allowed().is_empty(), "past the first steps every control answers")
	t.free()


func test_the_first_days_hints_come_in_order_and_once() -> void:
	var j := Journey.begin(3, "burned_hall", "Egil")
	var h := Hints.new(j)
	assert_eq(h.next_hint(), "where", "first, where you are")
	assert_true(h.text("where").contains("Sogn"), h.text("where"))
	h.showing = h.next_hint()
	h.dismiss()
	assert_eq(h.next_hint(), "walk")
	h.showing = "walk"
	h.dismiss()
	# A choice waits at the start (Harald's vow), so nothing to do here yet.
	assert_true(not j.can_act())
	assert_eq(h.next_hint(), "ways", "the point to spend is due while the place waits")
	while not j.decisions.is_empty():
		j.answer(str(j.current().options[j.current().options.size() - 1].id))
	assert_true(j.can_act())
	assert_eq(h.next_hint(), "actions", "at a place, free to act: what it offers")
	for id in Hints.ORDER:
		h.seen[id] = true
	assert_eq(h.next_hint(), "", "each shown once")
	assert_eq(h.learned().size(), Hints.ORDER.size(), "and all of it can be read again")
	for id in Hints.ORDER:
		var line := h.text(id)
		assert_true(line != "" and not line.contains("!"), "%s: one plain line" % id)


func test_rest_and_mend_heals_the_hurt() -> void:
	var j := Journey.begin(5, "burned_hall", "Egil")
	while not j.decisions.is_empty():
		j.answer(str(j.current().options[j.current().options.size() - 1].id))
	var ids := []
	for a in j.actions():
		ids.append(a.id)
	assert_true(not ids.has("rest"), "nobody hurt: no rest offered")
	var m: Man = j.c.band.living_men()[0]
	m.healing_turns = 2
	ids.clear()
	for a in j.actions():
		ids.append(a.id)
	assert_true(ids.has("rest"), "a hurt man: rest is offered")
	var day := j.c.cal.day
	j.act("rest")
	assert_eq(m.healing_turns, 1, "a turn mended")
	assert_true(j.c.cal.day > day, "days pass")
