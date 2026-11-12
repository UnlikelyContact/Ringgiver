extends TestCase
## The burned hall: every saga's first fight, the escape, and the tutorial
## that teaches it (Scenario.build_escape, Objective.Kind.ESCAPE,
## Journey.begin with escape, view/tutorial.gd, view/hints.gd). See
## docs/design/notes/tutorial.md.


## Plays the escape the way the tutorial asks, step by step: Go on, the
## shout it names, Next round, Withdraw, a tap on the hex or man it marks.
## Returns the director (free it).
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
		elif want == "tap" and t.point != BattleGrid.NO_CELL:
			var occ := b.grid.occupant(t.point)
			b.set_player_action(0, Action.attack(occ) if occ != null else Action.move_to(t.point))
			t.on_tap(t.point)
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
	assert_true(t.goal, "the dark is shown from the first")
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
	assert_eq(t.said, Tutorial.SAID_WALL, "and a line says what the wall did")
	var push := "shout:%d" % CombatTypes.Shout.PUSH
	assert_eq(t.control(), push)
	var only_push: Array[String] = [push]
	assert_eq(t.allowed(), only_push, "the first push is taught alone too")
	assert_true(t.point != BattleGrid.NO_CELL and b.grid.occupant(t.point) != null and b.grid.occupant(t.point).side == 1,
			"the man between you and the dark is marked")
	t.pending = CombatTypes.Shout.PUSH
	t.evaluate()
	assert_true(t.text().contains("3 more"), "how many shoves the thin place will take: " + t.text())
	b.set_shout(0, CombatTypes.Shout.PUSH)
	b.run_round()
	t.after_round()
	assert_true(t.allowed().is_empty(), "past the first push every control answers")
	t.free()


## The director's choice is a pure function of the field (Tutorial.advise):
## each of the field's states on a built escape, by hand.
static func _advise(b: Battle, m := {}) -> Dictionary:
	var memo := {"acked": true, "pending": CombatTypes.Shout.NONE, "tapped": BattleGrid.NO_CELL, "last_text": "",
			"last_progress": true, "to_me_tried": false}
	memo.merge(m, true)
	return Tutorial.advise(b, memo)


## The band (you first) at offset row `row` from column `col`, the burners
## within `clear` hexes of the dark taken off the field.
static func _band_at(f: Dictionary, row: int, col: int, clear: int) -> void:
	var b: Battle = f.battle
	for w in f.ours:
		b.grid.remove(w)
	for w in f.ours:
		b.grid.place(w, BattleGrid.from_offset(col, row))
		col += 1
	for w in f.theirs:
		if (w as Warrior).is_active() and b.objective.dark_distance((w as Warrior).pos) <= clear:
			b.grid.remove(w)
			(w as Warrior).fled = true


func test_the_director_says_the_one_useful_thing_the_field_shows() -> void:
	var rules := CombatRules.new()
	# One of them between you and the dark: push, and he is marked.
	var f := Scenario.build_escape(5, rules)
	var b: Battle = f.battle
	b.round = 1
	var a := _advise(b)
	assert_eq(a.step, Tutorial.Step.PUSH, "the ring stands between")
	assert_eq(a.control, "shout:%d" % CombatTypes.Shout.PUSH)
	var marked: Warrior = b.grid.occupant(a.point)
	assert_true(marked != null and marked.side == 1 and b.objective.dark_distance(marked.pos) < b.objective.leader_distance(b),
			"the man marked stands nearer the dark than you")
	# A man alone: To Me, and he is marked.
	var man: Warrior = f.ours[1]
	b.grid.remove(man)
	b.grid.place(man, BattleGrid.from_offset(4, 3))
	a = _advise(b)
	assert_eq(a.step, Tutorial.Step.TO_ME, "a man apart: call him in")
	assert_eq(a.control, "shout:%d" % CombatTypes.Shout.TO_ME)
	assert_eq(a.point, man.pos)
	assert_true(a.text.contains(man.display_name), a.text)
	a = _advise(b, {"pending": CombatTypes.Shout.TO_ME})
	assert_eq(a.control, "next", "To Me waiting: the round")
	a = _advise(b, {"to_me_tried": true})
	assert_eq(a.step, Tutorial.Step.PUSH, "called once and still apart: the field's next need comes first")
	# Through, out of reach: Withdraw.
	f = Scenario.build_escape(5, rules)
	b = f.battle
	b.round = 3
	_band_at(f, 3, 5, 3)
	assert_true(b.can_withdraw(0))
	a = _advise(b)
	assert_eq(a.step, Tutorial.Step.WITHDRAW)
	assert_eq(a.control, "withdraw")
	assert_true(a.goal, "the dark pulses")
	# Through, with one at your heels: fall back toward the dark.
	var chaser: Warrior = null
	for w in f.theirs:
		if (w as Warrior).is_active():
			chaser = w
	b.grid.remove(chaser)
	b.grid.place(chaser, BattleGrid.from_offset(5, 4))
	assert_true(b.objective.way_open(b) and not b.can_withdraw(0), "the way open, but one at arm's length")
	a = _advise(b)
	assert_eq(a.step, Tutorial.Step.FALL_BACK)
	assert_eq(a.control, "shout:%d" % CombatTypes.Shout.FALL_BACK)
	assert_true(a.goal)
	# The same words after a round that came to nothing are not said again.
	a = _advise(b, {"pending": CombatTypes.Shout.FALL_BACK})
	var fb_on: String = a.text
	assert_eq(a.control, "next")
	a = _advise(b, {"pending": CombatTypes.Shout.FALL_BACK, "last_text": fb_on, "last_progress": false})
	assert_eq(a.step, Tutorial.Step.STEP_OUT, "the wall was held up: step out yourself")
	assert_eq(a.control, "tap")
	assert_true(a.text != fb_on)
	assert_true(b.grid.is_free(a.point) and b.objective.dark_distance(a.point) < b.objective.leader_distance(b),
			"the hex marked is free and nearer the dark")
	# Down: what is happening, and nothing to press.
	(f.ours[0] as Warrior).wound = CombatTypes.Wound.DOWN
	a = _advise(b)
	assert_eq(a.step, Tutorial.Step.CARRIED)
	assert_eq(a.control, "")
	assert_eq(a.text, Tutorial.TEXT_CARRIED)
	for k in [Tutorial.TEXT_WHO, Tutorial.TEXT_WALL, Tutorial.TEXT_PUSH, Tutorial.TEXT_TO_ME, Tutorial.TEXT_FALL_BACK,
			Tutorial.TEXT_STEP_OUT, Tutorial.TEXT_WITHDRAW, Tutorial.TEXT_CARRIED, Tutorial.TEXT_PUSH_RING]:
		assert_true(not str(k).contains("!"), "plain words: " + str(k))


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


## The harder ring (12 Nov 2026, world-life): the jarl's picked men hold
## except at the thin place, more come up from the flanks as the rounds
## pass, and their leader is the head of the house that burned the hall.
func test_the_ring_holds_but_at_the_thin_place() -> void:
	var broke := 0
	var routed := 0
	for s in range(1, 11):
		var j := Journey.begin(s, "burned_hall", "Egil", true)
		var b: Battle = j.fight.built.battle
		var thin: Array = []
		for c in (j.fight.built.gap as Array).slice(1):
			thin.append(b.grid.occupant(c))
		var t := follow_tutorial(b)
		t.free()
		for w in j.fight.built.theirs:
			# Men who give way to the push run off the field (first-fight.md):
			# by design, and not the ring breaking.
			if (w as Warrior).broken and not (w as Warrior).fled and not thin.has(w):
				broke += 1
		if b.result.how == BattleResult.End.ROUT and b.result.winner == 0:
			routed += 1
	assert_eq(routed, 0, "three men do not rout the jarl's men")
	assert_true(broke <= 10, "the ring holds: %d of its men broke in 10 escapes, the thin place aside" % broke)


func test_more_come_from_the_flanks_and_lingering_is_punished() -> void:
	var rules := CombatRules.new()
	var f := Scenario.build_escape(3, rules)
	assert_eq((f.theirs as Array).size(), rules.escape_enemy_shields + rules.escape_flankers + rules.escape_enemy_spears,
			"the ring and the men at the yard's edges")
	var out := 0
	for s in range(1, 11):
		var j := Journey.begin(s, "burned_hall", "Egil", true)
		var b: Battle = j.fight.built.battle
		var lw := _leader_warrior(j)
		while not b.is_over() and b.round < 40:
			b.run_round()
		if b.result.escaped(0) and not lw.is_down():
			out += 1
	assert_true(out <= 3, "a band that stands in the yard is caught: out on his feet %d of 10" % out)


func test_the_ring_is_led_by_the_head_of_the_burning_house() -> void:
	var j := Journey.begin(2, "burned_hall", "Egil", true)
	var h := j.c.world.families.house(j.c.band.vengeance)
	var leader: Warrior = j.fight.built.theirs[0]
	assert_true(leader.is_leader)
	assert_eq(leader.display_name, h.name.trim_suffix("'s kin"), "not the prototype's name")


# --- The first fight made robust (docs/design/notes/first-fight.md) -----------

const PLAYERS := preload("res://tests/escape_players.gd")


## Stand-in first-timers of every kind, pressing the HUD's controls as the
## HUD lets them: each gets out on his feet often enough, none is kept past
## the round cap, and the banner never asks for what cannot be pressed, nor
## repeats itself after a round, played as it asked, that came to nothing.
func test_sloppy_first_timers_get_out() -> void:
	var cap := CombatRules.new().escape_round_cap
	for model in ["exact", "late", "early", "observed", "next_only", "back_after_push", "taps", "withdraw"]:
		var m: Dictionary = PLAYERS.measure(model, 12)
		var need := 11 if model == "exact" else 10
		assert_true(m.out >= need, "%s: out on his feet %d of 12" % [model, m.out])
		assert_true(m.worst <= cap, "%s: never past round %d (worst %d)" % [model, cap, m.worst])
		assert_eq(m.impossible, 0, "%s: the banner never asks for a control that will not answer" % model)
		assert_eq(m.stuck, 0, "%s: never stuck at a lock" % model)
		assert_eq(m.died, 0, "%s: the leader never dies" % model)
		if model != "taps":
			assert_eq(m.bad, 0, "%s: never the same words after a round that came to nothing" % model)


func test_doing_nothing_is_still_carried_off() -> void:
	var m: Dictionary = PLAYERS.measure("nothing", 10)
	assert_true(m.carried >= 9, "no order at all: carried off %d of 10" % m.carried)
	assert_true(m.worst <= CombatRules.new().escape_round_cap)
	assert_eq(m.died, 0)


## The thin place gives to anyone who pushes: after `escape_give_rounds`
## rounds of pushing, none of them stands nearer the dark within reach of
## the leader, and the way is open soon after.
func test_the_thin_place_gives_to_a_push() -> void:
	var rules := CombatRules.new()
	var opened := 0
	for s in range(1, 11):
		var j := Journey.begin(s, "burned_hall", "Egil", true)
		var b: Battle = j.fight.built.battle
		b.set_shout(0, CombatTypes.Shout.SHIELD_WALL)
		b.run_round()
		b.set_shout(0, CombatTypes.Shout.PUSH)
		while not b.is_over() and b.first_fight_pushed() < rules.escape_give_rounds:
			b.run_round()
		var l := b.sworn_leader(0)
		if b.is_over() or not l.is_active():
			continue
		var mine := b.objective.dark_distance(l.pos)
		for w in b.active(1):
			if not w.broken and b.objective.dark_distance(w.pos) < mine:
				assert_true(BattleGrid.distance(w.pos, l.pos) > rules.escape_give_radius, "seed %d: %s gave way" % [s, w.display_name])
		for k in 4:
			if b.is_over() or b.objective.way_open(b):
				break
			b.run_round()
		if b.is_over() or b.objective.way_open(b):
			opened += 1
	assert_true(opened >= 9, "the way open within four more rounds of pushing, %d of 10" % opened)


## The saga's own rescue: a leader cut off from his men is dragged out by the
## nearest of them, both hurt, and the escape is made.
func test_a_leader_cut_off_is_dragged_out() -> void:
	var rescued := 0
	for s in range(1, 11):
		var rules := CombatRules.new()
		rules.escape_rescue_rounds = 1
		var f := Scenario.build_escape(s, rules)
		var b: Battle = f.battle
		var l: Warrior = f.ours[0]
		var men: Array = f.ours.slice(1)
		b.set_shout(0, CombatTypes.Shout.SHIELD_WALL)  # he has given an order
		# Him alone by the hall's left end, two of them on him; his men away right.
		for w in f.ours:
			b.grid.remove(w)
		b.grid.place(l, BattleGrid.from_offset(1, 6))
		b.grid.place(men[0], BattleGrid.from_offset(11, 3))
		b.grid.place(men[1], BattleGrid.from_offset(12, 3))
		var near := 0
		for w in f.theirs:
			if near < 1 and (w as Warrior).is_active():
				for c in b.grid.neighbors(l.pos):
					if b.grid.is_free(c):
						b.grid.remove(w)
						b.grid.place(w, c)
						near += 1
						break
		b.run_round()
		if not l.is_active():
			continue  # felled outright: his men carry him off instead
		assert_true(b.is_over(), "seed %d: the rescue ends it" % s)
		assert_eq(b.objective.how_out, "rescued")
		assert_true(b.result.escaped(0), "the escape is made")
		var hurt := 0
		for m in men:
			if (m as Warrior).wound >= rules.escape_rescue_wound:
				hurt += 1
		assert_eq(hurt, 1, "the man who dragged him out is hurt")
		assert_true(l.wound >= rules.escape_rescued_wound, "and so is he")
		assert_true(b.result.log[b.result.log.size() - 1].contains("will") or " ".join(b.result.log).contains("drags"), "it is told")
		rescued += 1
	assert_true(rescued >= 6, "rescued %d of 10" % rescued)


## The night has an end: a band that gave orders is told out at the round
## cap; one that never did has its leader carried off.
func test_the_round_cap_tells_the_escape() -> void:
	var rules := CombatRules.new()
	for s in range(1, 6):
		var f := Scenario.build_escape(s, rules)
		var b: Battle = f.battle
		while not b.is_over() and b.round < 40:
			b.set_shout(0, CombatTypes.Shout.HOLD)  # an order, but never the push
			b.run_round()
		assert_true(b.round <= rules.escape_round_cap, "seed %d: over by round %d (%d)" % [s, rules.escape_round_cap, b.round])
		assert_true(b.result.escaped(0))
		var told := b.objective.how_out
		if b.round == rules.escape_round_cap and told == "told":
			assert_true((f.ours[0] as Warrior).is_active(), "told out on his feet")
	var g := Scenario.build_escape(3, rules)
	var nb: Battle = g.battle
	while not nb.is_over() and nb.round < 40:
		nb.run_round()
	assert_true(nb.round <= rules.escape_round_cap)
	assert_true((g.ours[0] as Warrior).is_down(), "no order at all: carried off at the end")
	assert_true(nb.result.escaped(0), "but the saga goes on")


## The first fight only: the saga's later break-out from a burning hall and
## the burning of another's keep the ordinary rules.
func test_only_the_first_fight_bends() -> void:
	var rules := CombatRules.new()
	var f := Scenario.build_escape(4, rules)
	assert_true((f.objective as Objective).first_fight)
	var j := Journey.begin(4, "burned_hall", "Egil", true)
	assert_true((j.fight.built.objective as Objective).first_fight, "the saga's own first fight")
	var bo := Scenario.build_breakout(4, rules, {"ours": f.ours.duplicate(), "theirs": f.theirs.duplicate()})
	assert_true(not (bo.objective as Objective).first_fight, "a later break-out is not")
	var hb := Scenario.build_hall_burning(4, rules, {"ours": f.ours.duplicate(), "theirs": f.theirs.duplicate()})
	assert_true(not (hb.objective as Objective).first_fight, "nor a burning")


# --- The rest of the battle, taught in later fights ----------------------------

func test_battle_hints_come_once_on_their_conditions() -> void:
	var rules := CombatRules.new()
	var j := Journey.begin(3, "younger_son", "Egil")
	var h := Hints.new(j)
	var b: Battle = Scenario.build("equal_green", 7, rules, true, 8).battle
	b.objective = null  # an open fight: no clock
	assert_eq(h.next_battle_hint(b), "b_form", "before the first round: the shape")
	h.seen["b_form"] = true
	assert_eq(h.next_battle_hint(b), "", "nothing else bears yet")
	b.round = 1
	assert_eq(h.next_battle_hint(b), "b_tap", "a round in: tapping the board")
	h.seen["b_tap"] = true
	assert_true(Hints.battle_due("b_advance", b), "apart, the wall formed: Advance")
	# A man of yours off on his own: To Me.
	var lone: Warrior = null
	for w in b.side_warriors(0):
		if not w.is_leader and w.role == CombatTypes.Role.SHIELD:
			lone = w
	assert_true(not Hints.battle_due("b_tome", b))
	b.grid.remove(lone)
	for row in b.grid.height:
		var c := BattleGrid.from_offset(0, row)
		if b.grid.is_free(c) and b.grid.adjacent_warriors(c, 1).is_empty() and BattleGrid.chebyshev(c, b.leader_of(0).pos) >= 3:
			b.grid.place(lone, c)
			break
	assert_eq(h.next_battle_hint(b), "b_tome", "a man alone: To Me")
	h.seen["b_tome"] = true
	# Their hearts thin: Break Them, once they are met.
	for w in b.active(1):
		w.morale = rules.morale_break_threshold
	assert_true(not Hints.battle_due("b_break", b), "not before the lines meet")
	var foe: Warrior = b.active(1)[0]
	var mine: Warrior = b.leader_of(0)
	for c in b.grid.neighbors(mine.pos):
		if b.grid.is_free(c):
			b.grid.remove(foe)
			b.grid.place(foe, c)
			break
	assert_true(Hints.battle_due("b_break", b), "their heart going, the lines met")
	b.round = Hints.PULSE_ROUND
	assert_true(Hints.battle_due("b_pulse", b))
	# An objective's clock; and never in the burned hall.
	var o: Battle = Scenario.build("hold", 7, rules, true, 8).battle
	if o.objective != null:
		assert_true(Hints.battle_due("b_clock", o), "a fight over something: its clock")
	var e: Battle = Scenario.build_escape(7, rules).battle
	for id in Hints.BATTLE_ORDER:
		e.round = 5
		assert_true(not Hints.battle_due(id, e), "%s: the burned hall teaches itself" % id)
		assert_true(Hints.battle_text(id) != "" and not Hints.battle_text(id).contains("!"), "%s: one plain line" % id)
		assert_true(Hints.battle_control(id) == "" or Hints.battle_control(id) in ["form", "advance", "wheel_l", "withdraw", "pulse"]
				or Hints.battle_control(id).begins_with("shout:"), "%s names a control the HUD has" % id)
	# Seen, never again; and listed with what has been learned.
	for id in Hints.BATTLE_ORDER:
		h.seen[id] = true
	assert_eq(h.next_battle_hint(b), "")
	assert_eq(h.learned_in_battle().size(), Hints.BATTLE_ORDER.size())
	assert_true(Hints.battle_text("offer").contains("fade away"))
