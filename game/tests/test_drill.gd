extends TestCase
## Drill, custom formations and custom shouts (concept.md): learned shapes
## the band must drill, a shout of its own that is a shape and an order,
## familiarity that the wall's test and a man's forming roll against,
## winter drill that raises it, the thaw that lets it fade, and standing
## in a shape that teaches it.


func _field(seed_in := 3) -> Dictionary:
	return Scenario.build("equal_green", seed_in, CombatRules.new(), false)


func test_refused_flanks_draw_the_end_men_back() -> void:
	var f := _field()
	var b: Battle = f.battle
	var ours: Array = f.ours
	var leader: Warrior = ours[0]
	var band: Array[Warrior] = []
	for w in ours:
		if w != leader:
			band.append(w)
	var plain := Formation.template_slots(b.grid, leader, band, FormationTemplate.line())
	var refused := Formation.template_slots(b.grid, leader, band, FormationTemplate.refused())
	var back_facing := BattleGrid.rotate(leader.wall_facing(), 3)
	var drawn_back := 0
	for w in band:
		if plain.has(w) and refused.has(w) and plain[w] != refused[w]:
			var behind: Vector2i = plain[w] + BattleGrid.forward(plain[w], leader.wall_axis(), back_facing)
			assert_eq(refused[w], behind, "an end man stands straight behind his plain slot")
			drawn_back += 1
	assert_eq(drawn_back, 2, "the two end men are drawn back")
	assert_true(FormationTemplate.refused().learned and FormationTemplate.wedge().learned)
	assert_true(not FormationTemplate.ranks().learned and not FormationTemplate.line().learned)


func test_familiarity_is_drill_over_full_and_plain_shapes_are_known() -> void:
	var rules := CombatRules.new()
	var w := Warrior.make("Grim", 0, [3, 3, 3, 3, 3])
	assert_eq(w.familiar(FormationTemplate.ranks(), rules.drill_points_full), 1.0, "every leader knows ranks")
	assert_eq(w.familiar(FormationTemplate.wedge(), rules.drill_points_full), 0.0, "a wedge must be drilled")
	w.drill["boar's snout"] = 2
	assert_between(w.familiar(FormationTemplate.wedge(), 3), 0.66, 0.67)
	w.drill["boar's snout"] = 9
	assert_eq(w.familiar(FormationTemplate.wedge(), 3), 1.0, "never above one")


func test_an_undrilled_wall_hesitates_more_forming_a_learned_shape() -> void:
	# The same bands, the same seeds, the wedge called: drilled men step
	# as one more often than men who never drilled it.
	var rules := CombatRules.new()
	var hesitated := [0, 0]
	for drilled in 2:
		for s in 30:
			var f := Scenario.build("equal_green", 100 + s, rules, false)
			var b: Battle = f.battle
			for w in f.ours:
				(w as Warrior).drill["boar's snout"] = rules.drill_points_full if drilled == 1 else 0
			(f.ours[0] as Warrior).formation = FormationTemplate.wedge()
			b.set_shout(0, CombatTypes.Shout.SHIELD_WALL)
			b.run_round()
			for r in 4:
				b.set_shout(0, CombatTypes.Shout.PUSH)
				b.run_round()
			for line in b.log:
				if line.contains("You's line hesitates"):
					hesitated[drilled] += 1
	print("    gate: forming the boar's snout, hesitations over 30 fights x 4 pushes: undrilled %d, drilled %d" % [hesitated[0], hesitated[1]])
	assert_true(hesitated[0] > hesitated[1], "undrilled men hesitate more: %d vs %d" % [hesitated[0], hesitated[1]])


func test_a_custom_shout_forms_its_shape_then_gives_its_order() -> void:
	var rules := CombatRules.new()
	var f := _field(5)
	var b: Battle = f.battle
	for w in f.ours:
		(w as Warrior).drill["refused flanks"] = rules.drill_points_full
	var hedgehog := CustomShout.make("Hedgehog", FormationTemplate.refused(), CombatTypes.Shout.HOLD)
	assert_eq(hedgehog.describe(), "Hedgehog (refused flanks, then hold)")
	b.call_custom(0, hedgehog)
	b.run_round()
	assert_eq(b.last_shout(0), CombatTypes.Shout.SHIELD_WALL, "the shape is called first")
	assert_eq((f.ours[0] as Warrior).formation.name, "refused flanks")
	var told := false
	for line in b.log:
		if line.contains("shouts: Hedgehog! (refused flanks)"):
			told = true
	assert_true(told, "under the band's own name")
	b.run_round()
	assert_eq(b.last_shout(0), CombatTypes.Shout.HOLD, "then its order, the next round")
	assert_eq(b.standing_order(0), CombatTypes.Shout.HOLD)
	# Men who never drilled the shape hear a word they do not know.
	var g := _field(6)
	var b2: Battle = g.battle
	b2.call_custom(0, CustomShout.make("Swine", FormationTemplate.wedge(), CombatTypes.Shout.PUSH))
	b2.run_round()
	var blank := false
	for line in b2.log:
		if line.contains("do not know the word"):
			blank = true
	assert_true(blank, "nobody has drilled the boar's snout")
	var none := 0
	for w in b2.active(0):
		if w != b2.leader_of(0) and w.heard_order == CombatTypes.Shout.NONE:
			none += 1
	assert_true(none > 0)
	# And another shout given in between drops the order.
	var h := _field(7)
	var b3: Battle = h.battle
	b3.call_custom(0, hedgehog)
	b3.run_round()
	b3.set_shout(0, CombatTypes.Shout.PUSH)
	b3.run_round()
	assert_eq(b3.last_shout(0), CombatTypes.Shout.PUSH, "the leader's next word stands")


func test_winter_drill_teaches_a_shape_and_the_thaw_lets_it_fade() -> void:
	var c := Campaign.new(11)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 6)
	c.band.drilling = "boar's snout"
	var before := c.band.familiarity("boar's snout", c.rules)
	assert_eq(before, 0.0)
	c.run_years(1)
	var after := c.band.familiarity("boar's snout", c.rules)
	assert_true(after > 0.0, "a winter of drill: the band knows the snout somewhat (%.2f)" % after)
	var man := c.band.fighters()[1]
	# A man who sits the next winter out loses a point at the thaw.
	c.band.drilling = ""
	var had: int = man.drill.get("boar's snout", 0)
	c.run_years(1)
	if man.alive and c.band.fighters().has(man):
		assert_true(int(man.drill.get("boar's snout", 0)) <= maxi(0, had - c.rules.drill_decay) + 1,
				"it fades: %d from %d" % [int(man.drill.get("boar's snout", 0)), had])


func test_standing_in_a_learned_shape_teaches_it() -> void:
	var rules := CampaignRules.new()
	var b := Band.new()
	var r := SimRng.new(5)
	var leader := Recruits.make(r.fork("l"), rules, CampaignTypes.Origin.YOUNGER_SON, 22, "Egil", b.next_id())
	leader.is_leader = true
	b.leader = leader
	for i in 4:
		b.add_man(Recruits.random(r.fork("m:%d" % i), rules, b.next_id()))
	var warriors: Array[Warrior] = []
	for m in b.fighters():
		warriors.append(m.to_warrior(0, rules))
	warriors[0].formation = FormationTemplate.wedge()
	var result := BattleResult.new()
	result.winner = 0
	result.seed_value = 1
	BattleBridge.after_battle(rules, b, warriors, result, PackedStringArray())
	for m in b.fighters():
		assert_eq(int(m.drill.get("boar's snout", 0)), 1, "%s learned the snout by standing in it" % m.display_name)
