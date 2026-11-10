extends TestCase
## The decision model (decision.gd, sim-architecture.md "Decision model"):
## a weighed choice among options, what a man sees gated by his tier, how
## he weighs it by his personality, and why he did it in `last_reason`.

const K := CombatTypes.ActionKind
const T := CombatTypes.Tier
const P := CombatTypes.Personality
const NORTH := Vector2i(0, -1)

var _next_id := 1


func _man(p_name: String, side: int, pos: Vector2i, g: BattleGrid,
		tier := T.BLOODED, stats := [4, 4, 4, 5, 4]) -> Warrior:
	var w := Warrior.make(p_name, side, stats, tier)
	w.id = _next_id
	_next_id += 1
	w.reset_for_battle(CombatRules.new())
	w.facing = NORTH if side == 0 else Vector2i(0, 1)
	g.place(w, pos)
	return w


func _choose(w: Warrior, leader: Warrior, g: BattleGrid, all: Array[Warrior],
		log: PackedStringArray = PackedStringArray()) -> Action:
	return Decision.choose(SimRng.new(1), CombatRules.new(), g, w, leader, all, log)


func test_a_grievous_green_man_drops_back_behind_a_friend() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Olvir", 0, Vector2i(8, 6), g, T.GREEN)
	var friend := _man("Thorolf", 0, g.behind(w), g, T.GREEN)
	var e := _man("e", 1, Vector2i(8, 3), g)
	w.heard_order = CombatTypes.Shout.HOLD
	w.wound = CombatTypes.Wound.GRIEVOUS
	var all: Array[Warrior] = [w, friend, e]
	var log := PackedStringArray()
	var a := _choose(w, null, g, all, log)
	assert_eq(a.kind, K.MOVE, "he steps back of his own accord: %s" % a.describe())
	assert_true(BattleGrid.distance(a.target_cell, e.pos) > BattleGrid.distance(w.pos, e.pos), "away from them")
	assert_eq(BattleGrid.distance(a.target_cell, friend.pos), 1, "beside the friend behind him")
	assert_eq(w.last_reason, "Olvir is hurt and falls back behind Thorolf")
	assert_true(log.has(w.last_reason), "the reason is logged")
	assert_eq(w.last_option, "drop back")
	# Nobody behind him: he stays where he is.
	g.remove(friend)
	friend.wound = CombatTypes.Wound.DOWN
	assert_eq(_choose(w, null, g, all).kind, K.BRACE, "with no friend behind, he holds")
	# An enemy at arm's length: he fights.
	g.place(friend, friend.pos)
	friend.wound = CombatTypes.Wound.UNHURT
	g.place(e, Vector2i(8, 5))
	assert_eq(_choose(w, null, g, all).kind, K.ATTACK, "with a man in his face he fights")


func test_a_blooded_man_closes_the_gap_where_his_neighbour_fell() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Grim", 0, Vector2i(8, 6), g)
	var left := _man("left", 0, Vector2i(7, 6), g)
	var fallen := _man("Skalla", 0, Vector2i(9, 6), g)
	var right := _man("right", 0, Vector2i(10, 6), g)
	var e := _man("e", 1, Vector2i(10, 5), g)  # at the gap, two from him
	g.remove(fallen)
	fallen.wound = CombatTypes.Wound.DOWN
	for m in [w, left, right]:
		m.heard_order = CombatTypes.Shout.HOLD
	var all: Array[Warrior] = [w, left, fallen, right, e]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.MOVE)
	assert_eq(a.target_cell, Vector2i(9, 6), "into the gap")
	assert_eq(w.last_reason, "Grim closes up where Skalla fell")
	# A green man in the same spot holds his place.
	w.tier = T.GREEN
	assert_ne(_choose(w, null, g, all).kind, K.MOVE, "a green man does not see it")


func test_a_spearman_at_reach_picks_the_enemy_pressing_his_neighbour() -> void:
	var g := BattleGrid.new(16, 12)
	var front := _man("Thorolf", 0, Vector2i(8, 6), g)
	var neighbour := _man("Skalla", 0, Vector2i(9, 6), g)
	var spear := _man("Hallvard", 0, g.behind(front), g)
	spear.role = CombatTypes.Role.SPEAR
	spear.heard_order = CombatTypes.Shout.HOLD
	var near := _man("near", 1, Vector2i(8, 5), g)  # on Thorolf only, lowest id: the plain pick
	var presser := _man("presser", 1, Vector2i(9, 5), g)  # on Thorolf and on Skalla
	var all: Array[Warrior] = [front, neighbour, spear, near, presser]
	assert_true(MeleeExchange.can_reach(CombatRules.new(), g, spear, near))
	assert_true(MeleeExchange.can_reach(CombatRules.new(), g, spear, presser))
	var a := _choose(spear, null, g, all)
	assert_eq(a.kind, K.ATTACK)
	assert_true(a.target == presser, "the man pressing his neighbour, not the nearest")
	assert_eq(spear.last_reason, "Hallvard's spear goes for the man on Skalla")
	# A green spearman does not see who is pressing whom: either mark is
	# the same to him (his blur settles it), and he gives no reason.
	spear.tier = T.GREEN
	a = _choose(spear, null, g, all)
	assert_eq(a.kind, K.ATTACK)
	assert_eq(spear.last_reason, "")


func test_a_green_man_who_missed_the_shout_does_as_his_neighbours_do() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(8, 10), g, T.VETERAN)
	leader.is_leader = true
	var a1 := _man("Egil", 0, Vector2i(7, 6), g, T.GREEN)
	var w := _man("Olvir", 0, Vector2i(8, 6), g, T.GREEN)
	var b1 := _man("Bard", 0, Vector2i(9, 6), g, T.GREEN)
	a1.heard_order = CombatTypes.Shout.TO_ME
	b1.heard_order = CombatTypes.Shout.TO_ME
	w.heard_order = CombatTypes.Shout.NONE  # he missed it
	var all: Array[Warrior] = [leader, a1, w, b1]
	var a := _choose(w, leader, g, all)
	assert_eq(a.kind, K.MOVE, "he goes to the leader with them: %s" % a.describe())
	assert_true(BattleGrid.distance(a.target_cell, leader.pos) < BattleGrid.distance(w.pos, leader.pos))
	assert_eq(w.last_reason, "Olvir missed the shout and does as Egil does")
	assert_eq(w.heard_order, CombatTypes.Shout.NONE, "what he heard is unchanged")
	# A veteran trusts his own ears.
	w.tier = T.VETERAN
	assert_eq(_choose(w, leader, g, all).kind, K.BRACE)
	# Only one neighbour acting on it is not enough.
	w.tier = T.GREEN
	b1.heard_order = CombatTypes.Shout.NONE
	assert_eq(_choose(w, leader, g, all).kind, K.BRACE)


func test_a_blooded_end_man_turns_to_face_a_flanker() -> void:
	var g := BattleGrid.new(16, 12)
	var leader := _man("jarl", 0, Vector2i(6, 6), g)
	leader.is_leader = true
	leader.line_facing = NORTH
	var mid := _man("mid", 0, Vector2i(7, 6), g)
	var w := _man("Grim", 0, Vector2i(8, 6), g)  # the right end
	var flanker := _man("Ketil", 1, Vector2i(10, 6), g)  # level with the line, past its open end
	for m in [leader, mid, w]:
		m.heard_order = CombatTypes.Shout.HOLD
	var all: Array[Warrior] = [leader, mid, w, flanker]
	var a := _choose(w, leader, g, all)
	assert_eq(a.kind, K.BRACE)
	assert_eq(a.new_facing, BattleGrid.rotate(NORTH, 1), "one facing round toward him")
	assert_true(BattleGrid.linked_at(w.pos, a.new_facing, mid.pos, mid.facing), "and still locked with his neighbour")
	assert_eq(w.last_reason, "Grim turns to meet Ketil on the flank")
	w.tier = T.VETERAN
	_choose(w, leader, g, all)
	assert_eq(w.last_reason, "Grim sees Ketil coming round and turns to meet him", "a veteran's voice")
	w.tier = T.GREEN
	a = _choose(w, leader, g, all)
	assert_eq(a.new_facing, NORTH, "a green man keeps facing the front")
	# The middle man is no end man and does not turn.
	assert_eq(_choose(mid, leader, g, all).new_facing, NORTH)


func test_a_champion_braces_the_round_before_a_charge_lands() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Kveldulf", 0, Vector2i(8, 6), g, T.CHAMPION)
	w.heard_order = CombatTypes.Shout.PUSH
	var e := _man("e", 1, Vector2i(8, 4), g)
	e.heard_order = CombatTypes.Shout.BREAK_THEM
	var all: Array[Warrior] = [w, e]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.BRACE, "he reads the rush: %s" % a.describe())
	assert_eq(a.new_facing, BattleGrid.direction_to(w.pos, e.pos))
	assert_eq(w.last_reason, "Kveldulf reads the rush and sets his shield")
	# A veteran in the same spot walks into it.
	w.tier = T.VETERAN
	assert_eq(_choose(w, null, g, all).kind, K.MOVE)
	# Nobody coming on: the champion goes on too.
	w.tier = T.CHAMPION
	e.heard_order = CombatTypes.Shout.HOLD
	assert_eq(_choose(w, null, g, all).kind, K.MOVE)


func test_a_champion_throws_the_round_before_the_lines_meet() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Kveldulf", 0, Vector2i(8, 6), g, T.CHAMPION)
	w.heard_order = CombatTypes.Shout.BREAK_THEM
	w.javelins = 1
	var e := _man("e", 1, Vector2i(8, 4), g)
	var all: Array[Warrior] = [w, e]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.SHOOT)
	assert_true(a.thrown and a.target == e)
	w.tier = T.VETERAN
	assert_eq(_choose(w, null, g, all).kind, K.MOVE, "a veteran charging keeps his spear")


func test_a_reckless_man_charges_where_a_steady_one_holds() -> void:
	for p in [P.RECKLESS, P.STEADY]:
		var g := BattleGrid.new(16, 12)
		var w := _man("Bard", 0, Vector2i(8, 6), g)
		var e := _man("e", 1, Vector2i(8, 3), g)
		w.heard_order = CombatTypes.Shout.HOLD
		w.personality = [p]
		var all: Array[Warrior] = [w, e]
		var a := _choose(w, null, g, all)
		if p == P.RECKLESS:
			assert_eq(a.kind, K.MOVE, "the reckless man goes")
			assert_eq(a.target_cell, Vector2i(8, 5))
			assert_eq(w.last_reason, "Bard will not wait: he goes at them")
			assert_eq(w.last_option, "charge")
		else:
			assert_eq(a.kind, K.BRACE, "the steady man holds his place")
			assert_eq(w.last_reason, "", "holding is his plain order: no reason given")
		# With friends at his shoulders both stay in the wall under Hold.
		var left := _man("left", 0, Vector2i(7, 6), g)
		var right := _man("right", 0, Vector2i(9, 6), g)
		all.append(left)
		all.append(right)
		assert_eq(_choose(w, null, g, all).kind, K.BRACE, "held in the wall")


func test_a_boastful_man_picks_the_enemy_leader() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Egil", 0, Vector2i(8, 6), g)
	w.heard_order = CombatTypes.Shout.HOLD
	var hurt := _man("hurt", 1, Vector2i(8, 5), g)
	hurt.wound = CombatTypes.Wound.GRIEVOUS
	var jarl := _man("Atli the leader", 1, Vector2i(9, 5), g)  # front-right
	jarl.is_leader = true
	var all: Array[Warrior] = [w, hurt, jarl]
	assert_true(_choose(w, null, g, all).target == hurt, "a plain man finishes the hurt one")
	assert_eq(w.last_reason, "")
	w.personality = [P.BOASTFUL]
	var a := _choose(w, null, g, all)
	assert_true(a.target == jarl, "the boastful man wants the leader")
	assert_eq(w.last_reason, "Egil seeks out Atli, where all can see him")


func test_a_greedy_man_goes_for_a_fallen_leader_once() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Mord", 0, Vector2i(8, 6), g)
	w.heard_order = CombatTypes.Shout.HOLD
	w.personality = [P.GREEDY]
	var jarl := _man("Atli the leader", 1, Vector2i(8, 4), g)
	jarl.is_leader = true
	g.remove(jarl)
	jarl.wound = CombatTypes.Wound.DOWN
	var e := _man("e", 1, Vector2i(12, 2), g)
	var all: Array[Warrior] = [w, jarl, e]
	var a := _choose(w, null, g, all)
	assert_eq(a.kind, K.MOVE)
	assert_eq(a.target_cell, Vector2i(8, 5))
	assert_eq(w.last_reason, "Mord leaves the line to strip Atli")
	g.place(w, Vector2i(8, 5))
	_choose(w, null, g, all)
	g.place(w, jarl.pos)
	a = _choose(w, null, g, all)
	assert_true(w.looted, "on the body he has it")
	g.place(w, Vector2i(8, 6))
	a = _choose(w, null, g, all)
	assert_ne(w.last_option, "loot", "and does not go back for more")


func test_a_superstitious_man_swings_with_the_banner() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("Gizur", 0, Vector2i(8, 6), g)
	w.heard_order = CombatTypes.Shout.HOLD
	w.personality = [P.SUPERSTITIOUS]
	var ours := _man("ours", 0, Vector2i(5, 8), g)
	ours.is_banner = true
	var theirs := _man("theirs", 1, Vector2i(12, 2), g)
	theirs.is_banner = true
	var e := _man("e", 1, Vector2i(8, 3), g)
	var all: Array[Warrior] = [w, ours, theirs, e]
	assert_eq(_choose(w, null, g, all).kind, K.BRACE, "both banners stand: he holds")
	g.remove(theirs)
	theirs.wound = CombatTypes.Wound.DOWN
	assert_eq(_choose(w, null, g, all).kind, K.MOVE, "their banner is down: he goes at them")
	assert_eq(w.last_option, "charge")
	g.place(theirs, theirs.pos)
	theirs.wound = CombatTypes.Wound.UNHURT
	g.remove(ours)
	ours.wound = CombatTypes.Wound.DOWN
	assert_eq(_choose(w, null, g, all).kind, K.BRACE, "his own is down: steady enough, he holds")
	w.morale = CombatRules.new().morale_break_threshold + 1
	assert_eq(_choose(w, null, g, all).kind, K.FLEE, "shaken, he wants no more of it")
	assert_eq(w.last_reason, "Gizur sees the banner go down and wants no more of it")
	assert_true(not w.broken, "a step away, not a rout")


func test_plain_orders_give_no_reason() -> void:
	var g := BattleGrid.new(16, 12)
	var w := _man("w", 0, Vector2i(8, 6), g, T.VETERAN)
	var e := _man("e", 1, Vector2i(8, 5), g)
	w.heard_order = CombatTypes.Shout.HOLD
	var all: Array[Warrior] = [w, e]
	var log := PackedStringArray()
	var a := _choose(w, null, g, all, log)
	assert_eq(a.kind, K.ATTACK)
	assert_eq(w.last_reason, "")
	assert_eq(w.last_option, "strike")
	assert_eq(log.size(), 0)


func test_band_personalities_follow_the_odds() -> void:
	var rules := CombatRules.new()
	var counts := [0, 0, 0]
	var by_trait := {}
	var men := 0
	for s in 400:
		var band := BandFactory.make_band(SimRng.new(s), 0, 10, T.GREEN)
		for w in band:
			if w.is_leader:
				continue
			men += 1
			counts[w.personality.size()] += 1
			for p in w.personality:
				by_trait[p] = by_trait.get(p, 0) + 1
			for pair in BandFactory.CONFLICTS:
				assert_true(not (w.personality.has(pair[0]) and w.personality.has(pair[1])), "no conflicting pair")
	assert_between(float(counts[0]) / men, 0.27, 0.33, "about 30% have none")
	assert_between(float(counts[1]) / men, 0.56, 0.64, "about 60% have one")
	assert_between(float(counts[2]) / men, 0.08, 0.12, "about 10% have two")
	assert_true(by_trait[P.STEADY] > by_trait[P.GRIM] and by_trait[P.RECKLESS] > by_trait[P.BOASTFUL], "steady and reckless commonest")
	assert_true(by_trait[P.GRIM] > by_trait[P.GREEDY] and by_trait[P.BOASTFUL] > by_trait[P.SUPERSTITIOUS], "greedy and superstitious rare")
	# Personalities come from their own stream: the stats drawn are the same.
	var a := BandFactory.make_band(SimRng.new(7), 0, 8, T.GREEN)
	rules.personality_none_chance = 1.0
	rules.personality_leader_none_chance = 1.0
	var b := BandFactory.make_band(SimRng.new(7), 0, 8, T.GREEN, CombatTypes.Armor.NONE, 0, 1, -1, rules)
	for i in a.size():
		assert_eq([a[i].might, a[i].skill, a[i].grit, a[i].nerve, a[i].wits], [b[i].might, b[i].skill, b[i].grit, b[i].nerve, b[i].wits])
		assert_eq(b[i].personality.size(), 0)
