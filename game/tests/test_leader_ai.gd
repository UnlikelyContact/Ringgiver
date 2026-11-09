extends TestCase
## The enemy leader: wheeling toward the threat, refusing a flank, holding
## ranks against ranks, and the cunning leader's pre-emptive wheel.

const DOWN := Vector2i(0, 1)  # the AI side faces down the screen (south-east)
const UP := Vector2i(0, -1)
const WEST := Vector2i(-1, 0)
const D := LeaderAI.Doctrine


func _cell(col: int, row: int) -> Vector2i:
	return BattleGrid.from_offset(col, row)


## A loose man of `side` at offset (col, row), facing `facing`.
func _man(rules: CombatRules, name: String, side: int, id: int, col: int, row: int, facing: Vector2i, leader := false) -> Warrior:
	var w := Warrior.make(name, side, [4, 4, 4, 4, 4])
	w.id = id
	w.reset_for_battle(rules)
	w.facing = facing
	w.is_leader = leader
	return w


## The AI's (side 1) wall: `n` shields in a plain line through (8, 6)
## facing down. Returns the band, leader first.
func _ai_line(b: Battle, rules: CombatRules, n := 5, template: FormationTemplate = null) -> Array[Warrior]:
	var band := BandFactory.make_band(SimRng.new(11), 1, n, CombatTypes.Tier.GREEN, CombatTypes.Armor.NONE, 16, 101)
	BandFactory.deploy_formation(b.grid, band, _cell(8, 6), DOWN, rules, template)
	b.add_band(band)
	return band


## Loose men of side 0 at the given offsets, the first of `far` their leader.
func _loose(b: Battle, rules: CombatRules, near: Array, far: Array) -> Array[Warrior]:
	var out: Array[Warrior] = []
	var id := 1
	for c in far + near:
		var w := _man(rules, "m%d" % id, 0, id, c.x, c.y, UP, id == 1)
		b.grid.place(w, _cell(c.x, c.y))
		out.append(w)
		id += 1
	b.add_band(out)
	return out


func _started(b: Battle) -> void:
	for side in 2:
		b.result.started[side] = b.active(side).size()


func _state(w: Warrior) -> int:
	return BattleGrid.state_of(w.wall_axis(), w.wall_facing())


func test_wheels_toward_the_nearest_third_not_the_whole_band() -> void:
	var rules := CombatRules.new()
	var b := Battle.new(rules, 7)
	var ai := _ai_line(b, rules)
	# Six far off in front of the line, three close beside its left (east) end.
	_loose(b, rules, [Vector2i(13, 6), Vector2i(13, 7), Vector2i(13, 8)],
			[Vector2i(1, 11), Vector2i(3, 11), Vector2i(5, 11), Vector2i(7, 11), Vector2i(9, 11), Vector2i(11, 11)])
	_started(b)
	var leader := ai[0]
	var before := _state(leader)
	# The whole band's centre is about straight ahead: the old measure would not wheel.
	var sum := Vector2.ZERO
	for e in b.active(0):
		sum += BattleGrid.to_cart(Vector2(e.pos))
	assert_eq(absi(LeaderAI.steps_toward(leader, sum / b.active(0).size())), 0, "the band's centre is dead ahead")
	assert_true(not LeaderAI.outflanked(b, 1), "nobody is behind the line yet")
	var threat := LeaderAI.threat_men(b, 1)
	assert_eq(threat.size(), 3, "the nearest third of nine")
	for e in threat:
		assert_eq(BattleGrid.to_offset(e.pos).x, 13, "%s is one of the three at the end" % e.display_name)
	LeaderAI.new(D.STEADY).choose(b, 1)
	assert_eq(_state(leader), posmod(before - 1, 8), "one stance left, toward the men at his left end")


func test_wheels_two_stances_when_their_end_is_past_his() -> void:
	var rules := CombatRules.new()
	var b := Battle.new(rules, 7)
	var ai := _ai_line(b, rules)
	# The three near men stand behind the plane of his line, off its left end.
	_loose(b, rules, [Vector2i(13, 4), Vector2i(13, 5), Vector2i(14, 4)],
			[Vector2i(1, 11), Vector2i(3, 11), Vector2i(5, 11), Vector2i(7, 11), Vector2i(9, 11), Vector2i(11, 11)])
	_started(b)
	var leader := ai[0]
	var before := _state(leader)
	assert_true(LeaderAI.outflanked(b, 1), "their nearest man is behind his line")
	LeaderAI.new(D.STEADY).choose(b, 1)
	assert_eq(_state(leader), posmod(before - 2, 8), "two stances in one round")
	# Engaged, he does not wheel at all.
	var b2 := Battle.new(rules, 7)
	var ai2 := _ai_line(b2, rules)
	_loose(b2, rules, [Vector2i(13, 4), Vector2i(13, 5), Vector2i(14, 4), Vector2i(8, 7)],
			[Vector2i(1, 11), Vector2i(3, 11), Vector2i(5, 11), Vector2i(7, 11), Vector2i(9, 11)])
	_started(b2)
	var before2 := _state(ai2[0])
	LeaderAI.new(D.STEADY).choose(b2, 1)
	assert_eq(_state(ai2[0]), before2, "a man of his wall is engaged: no wheel")


## A field with the AI's line through (8, 6) facing down, and a three-man
## enemy wall standing up and down through (col, 6) facing `facing`.
func _flank_field(rules: CombatRules, col: int, facing: Vector2i) -> Battle:
	var b := Battle.new(rules, 7)
	_ai_line(b, rules)
	var theirs := BandFactory.make_band(SimRng.new(5), 0, 3, CombatTypes.Tier.GREEN)
	BandFactory.deploy_formation(b.grid, theirs, _cell(col, 6), facing, rules, null)
	b.add_band(theirs)
	_started(b)
	return b


func _at(b: Battle, col: int, row := 6) -> Warrior:
	return b.grid.occupant(_cell(col, row))


func _logged(b: Battle, text: String) -> int:
	var n := 0
	for line in b.log:
		if line.contains(text):
			n += 1
	return n


func test_refusing_the_flank_hinges_the_end_man_then_the_next() -> void:
	var rules := CombatRules.new()
	# Their wall level with his right (west) end, two hexes off it.
	var b := _flank_field(rules, 4, Vector2i(1, 0))
	var leader := b.leader_of(1)
	var wf := leader.wall_facing()
	var size := b.wall_members(1).size()
	assert_eq(b.wall_members(0).size(), 3, "their three stand as a wall")
	var end := _at(b, 6)
	var next := _at(b, 7)
	var third := _at(b, 8)
	assert_true(end != null and next != null and third != null and third == leader)
	var lai := LeaderAI.new(D.STEADY)
	lai.refuse_flanks(b, 1, leader)
	var hinge := BattleGrid.rotate(wf, 1)
	assert_eq(end.facing, hinge, "the end man hinges back one facing toward them")
	assert_eq(next.facing, wf, "the next man waits for him")
	assert_eq(b.wall_members(1).size(), size, "the wall is still one wall")
	lai.refuse_flanks(b, 1, leader)
	assert_eq(end.facing, hinge, "still one facing, never two")
	assert_eq(next.facing, hinge, "now the man inside him hinges too")
	assert_eq(b.wall_members(1).size(), size, "and the wall still holds together")
	lai.refuse_flanks(b, 1, leader)
	assert_eq(leader.wall_facing(), wf, "the leader never turns off his wall's facing")
	assert_eq(_logged(b, "right hand refuses the flank"), 1, "logged once a spell")
	for col in [9, 10]:
		assert_eq(_at(b, col).facing, wf, "the other end keeps its facing")
	# Gone: the spell ends, and a new one is logged again.
	for w in b.active(0):
		b.grid.remove(w)
		w.wound = CombatTypes.Wound.DOWN
	lai.refuse_flanks(b, 1, leader)
	assert_eq(_logged(b, "refuses the flank"), 1, "nothing new while nobody is there")


func test_refusing_never_breaks_the_wall() -> void:
	var rules := CombatRules.new()
	# On his left (east) end a level line facing down hinges toward east,
	# along the row: two men turned that way would stand one behind the
	# other, so only the end man hinges.
	var b := _flank_field(rules, 12, Vector2i(-1, 0))
	var leader := b.leader_of(1)
	var wf := leader.wall_facing()
	var size := b.wall_members(1).size()
	var lai := LeaderAI.new(D.STEADY)
	for i in 3:
		lai.refuse_flanks(b, 1, leader)
		assert_eq(b.wall_members(1).size(), size, "round %d: the wall holds together" % i)
	assert_eq(_at(b, 10).facing, BattleGrid.rotate(wf, -1), "the end man hinges")
	assert_eq(_at(b, 9).facing, wf, "the next man would break the wall, so he does not")
	assert_eq(_logged(b, "left hand refuses the flank"), 1)
	# An enemy beyond the end but in front of it is in the front arcs: no hinge.
	var b2 := Battle.new(rules, 7)
	_ai_line(b2, rules)
	var theirs := BandFactory.make_band(SimRng.new(5), 0, 3, CombatTypes.Tier.GREEN)
	BandFactory.deploy_formation(b2.grid, theirs, _cell(11, 8), UP, rules, null)
	b2.add_band(theirs)
	_started(b2)
	LeaderAI.new(D.STEADY).refuse_flanks(b2, 1, b2.leader_of(1))
	assert_eq(_logged(b2, "refuses the flank"), 0, "they are in front of him")


## Both bands in ranks, five rows apart: six shields, a spear and a bow each.
func _ranks_field(rules: CombatRules, ours_template: FormationTemplate) -> Dictionary:
	var b := Battle.new(rules, 9)
	var ours := BandFactory.make_mixed_band(SimRng.new(1), 0, 6, 1, 1, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(SimRng.new(2), 1, 6, 1, 1, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101)
	BandFactory.deploy_formation(b.grid, ours, _cell(8, 8), UP, rules, ours_template)
	BandFactory.deploy_formation(b.grid, theirs, _cell(8, 3), DOWN, rules, FormationTemplate.ranks())
	b.add_band(ours)
	b.add_band(theirs)
	_started(b)
	# Past forming and past a steady leader's patience, on a round he would not jeer.
	b.round = rules.ai_form_rounds + rules.ai_patience_rounds + 2
	while b.round % rules.taunt_ai_every == 0:
		b.round += 1
	return {"battle": b, "ours": ours, "theirs": theirs}


func test_holds_ranks_against_ranks_until_the_odds_or_their_nerve_change() -> void:
	var rules := CombatRules.new()
	var f := _ranks_field(rules, FormationTemplate.ranks())
	var b: Battle = f.battle
	var ours: Array[Warrior] = f.ours
	var steady := LeaderAI.new(D.STEADY)
	assert_eq(steady.choose(b, 1), CombatTypes.Shout.HOLD, "ranks against ranks, even odds: he holds past his patience")
	b.round += 1
	while b.round % rules.taunt_ai_every != 0:
		b.round += 1
	assert_eq(steady.choose(b, 1), CombatTypes.Shout.TAUNT, "and jeers at them")
	b.round += 1
	assert_eq(LeaderAI.new(D.CUNNING).choose(b, 1), CombatTypes.Shout.HOLD, "a cunning leader holds too")
	assert_eq(LeaderAI.new(D.AGGRESSIVE).choose(b, 1), CombatTypes.Shout.PUSH, "an aggressive one comes on anyway")
	# A taunt does not bring him on.
	b._taunted_round[1] = b.round - 1
	for i in 5:
		assert_eq(LeaderAI.new(D.STEADY).choose(b, 1), CombatTypes.Shout.HOLD, "he will not be jeered into their spears")
	b._taunted_round.erase(1)
	# Their nerve goes: he comes on.
	for w in ours:
		w.morale = 4
	assert_true(LeaderAI.mean_morale(ours) < rules.ai_push_when_wavering)
	assert_eq(LeaderAI.new(D.STEADY).choose(b, 1), CombatTypes.Shout.PUSH, "they are wavering: push")
	for w in ours:
		w.morale = 8
	assert_eq(LeaderAI.new(D.STEADY).choose(b, 1), CombatTypes.Shout.HOLD, "steady again: hold")
	# Two of their shields down: the odds are his, he comes on.
	var downed := 0
	for w in ours:
		if downed < 2 and not w.is_leader and w.role == CombatTypes.Role.SHIELD:
			w.wound = CombatTypes.Wound.DOWN
			b.grid.remove(w)
			downed += 1
	var ratio := LeaderAI.strength(rules, b.active(1)) / LeaderAI.strength(rules, b.active(0))
	assert_true(ratio >= rules.ai_push_advantage, "ratio %.2f" % ratio)
	assert_eq(LeaderAI.new(D.STEADY).choose(b, 1), CombatTypes.Shout.PUSH, "he has the numbers: push")
	# Against a plain line the old patience still runs out.
	var g := _ranks_field(rules, FormationTemplate.line())
	assert_eq(LeaderAI.new(D.STEADY).choose(g.battle, 1), CombatTypes.Shout.PUSH, "no ranks to fear: patience runs out")


func test_cunning_wheels_toward_where_a_marching_wall_is_going() -> void:
	var rules := CombatRules.new()
	var built := {}
	for doc in [D.STEADY, D.CUNNING]:
		var b := Battle.new(rules, 7)
		var ai := _ai_line(b, rules)
		# Their wall stands up and down off his right front, facing west: it
		# is marching across his front.
		var theirs := BandFactory.make_band(SimRng.new(5), 0, 3, CombatTypes.Tier.GREEN)
		BandFactory.deploy_formation(b.grid, theirs, _cell(5, 10), WEST, rules, null)
		b.add_band(theirs)
		_started(b)
		b.round = rules.ai_form_rounds + 1
		var lai := LeaderAI.new(doc)
		var before := _state(ai[0])
		lai.choose(b, 1)
		assert_eq(_state(ai[0]), before, "%s: not moving yet, the threat is a stance off: no wheel" % D.keys()[doc])
		# They step west.
		var order := theirs.duplicate()
		order.sort_custom(func(x: Warrior, y: Warrior) -> bool: return x.pos.x < y.pos.x)
		for w in order:
			b.grid.place(w, w.pos + WEST)
		lai.choose(b, 1)
		built[doc] = posmod(_state(ai[0]) - before, 8)
	assert_eq(built[D.STEADY], 0, "a steady leader waits for them to come round")
	assert_eq(built[D.CUNNING], 1, "a cunning one wheels right to meet them where they are going")
