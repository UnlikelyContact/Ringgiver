extends TestCase
## The ship fight (Scenario.build_deck, Objective.Kind.DECK): two hulls
## lashed together, men overboard, the deck cleared, the lashings cut, the
## prize. See docs/design/notes/saga-fights.md.


func _deck(seed_in: int, attacker := 0) -> Dictionary:
	return Scenario.build_deck(seed_in, CombatRules.new(), {}, attacker)


func _log_hash(b: Battle) -> int:
	return "\n".join(b.log).hash()


func test_the_deck_is_laid_out_and_the_same_from_the_same_seed() -> void:
	var a := _deck(3)
	var b := _deck(3)
	var ba: Battle = a.battle
	var bb: Battle = b.battle
	ba.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	bb.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	ba.run()
	bb.run()
	assert_eq(ba.result.summary(), bb.result.summary(), "one seed, one fight")
	assert_eq(_log_hash(ba), _log_hash(bb))
	var g: BattleGrid = _deck(4).battle.grid
	assert_true(g.has_sea, "the deck field has sea on it")
	var built := _deck(4)
	var hulls: Dictionary = built.hulls
	var grid: BattleGrid = built.battle.grid
	for side in 2:
		var own: Array = hulls[side]
		assert_true(own.size() >= 24, "a deck big enough for a crew")
		for c: Vector2i in own:
			assert_true(grid.is_passable(c), "the deck is planking")
			assert_true(not (hulls[1 - side] as Array).has(c), "the hulls are apart")
		for w: Warrior in (built.ours if side == 0 else built.theirs):
			assert_true(own.has(w.pos), "%s starts on his own deck" % w.display_name)
	for c: Vector2i in built.gangways:
		assert_eq(grid.terrain_at(c), CombatTypes.Terrain.BRIDGE, "the gangways are planks over the water")
	for col in grid.width:
		assert_eq(grid.terrain_at(BattleGrid.from_offset(col, 0)), CombatTypes.Terrain.SEA, "open sea round the hulls")
	# Nothing but the deck ever holds sea.
	for s in 10:
		var sc := Scenario.build("equal_green", s, CombatRules.new(), true, 12)
		assert_true(not (sc.battle as Battle).grid.has_sea, "an ordinary field has no sea")


func test_a_man_thrown_back_with_the_sea_behind_him_goes_over_the_side() -> void:
	var rules := CombatRules.new()
	var overboard := 0
	for s in 40:
		var g := BattleGrid.new(6, 5)
		for col in 6:
			g.set_terrain(BattleGrid.from_offset(col, 0), CombatTypes.Terrain.SEA)
		var d := Warrior.make("d", 1, [1, 3, 3, 3, 3])
		var a := Warrior.make("a", 0, [10, 3, 3, 3, 3])
		d.id = 2
		a.id = 1
		d.reset_for_battle(rules)
		a.reset_for_battle(rules)
		g.place(d, BattleGrid.from_offset(2, 1))
		g.place(a, BattleGrid.from_offset(2, 2))
		d.facing = BattleGrid.direction_to(d.pos, a.pos)
		a.facing = BattleGrid.direction_to(a.pos, d.pos)
		var all: Array[Warrior] = [a, d]
		var r := Push.resolve(SimRng.new(s), rules, g, all, PackedStringArray())
		if r.overboard.has(d):
			overboard += 1
			assert_true(g.occupant(d.pos) != d, "he is off the deck")
	assert_true(overboard > 20, "a strong man throws a weak one over the side most times (%d of 40)" % overboard)


func test_men_go_overboard_in_deck_fights_and_the_sea_decides_their_fate() -> void:
	var over := 0
	for s in 20:
		var built := _deck(100 + s)
		var b: Battle = built.battle
		b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		b.run()
		over += b.result.overboard[0] + b.result.overboard[1]
		for w in b.warriors:
			if w.overboard:
				assert_true(w.fled and not w.is_active(), "overboard is off the field")
				assert_true(w.fate == CombatTypes.Fate.DEAD or w.fate == CombatTypes.Fate.RECOVERED, "drowned or hauled out")
				if w.fate == CombatTypes.Fate.DEAD:
					assert_true(w.is_down(), "a drowned man is counted dead")
	assert_true(over > 0, "men go over the side in twenty ship fights (%d)" % over)


func test_mail_drowns_more_than_a_bare_back() -> void:
	var rules := CombatRules.new()
	var drowned := {CombatTypes.Armor.NONE: 0, CombatTypes.Armor.MAIL: 0}
	var b := Battle.new(rules, 1, BattleGrid.new(4, 4))
	for armor in drowned:
		for i in 400:
			var w := Warrior.make("m", 0, [3, 3, 3, 3, 3])
			w.id = i
			w.armor = armor
			w.overboard = true
			b._sea_takes(SimRng.new(i * 7 + int(armor)), w)
			if w.fate == CombatTypes.Fate.DEAD:
				drowned[armor] += 1
	assert_between(drowned[CombatTypes.Armor.NONE] / 400.0, rules.overboard_drown - 0.07, rules.overboard_drown + 0.07, "a bare man drowns at the base rate")
	assert_true(drowned[CombatTypes.Armor.MAIL] > drowned[CombatTypes.Armor.NONE] * 2, "mail drowns far more (%d against %d)" % [drowned[CombatTypes.Armor.MAIL], drowned[CombatTypes.Armor.NONE]])


func test_clearing_her_deck_takes_the_ship() -> void:
	var built := _deck(9, 0)
	var b: Battle = built.battle
	var g := b.grid
	var theirs: Array = built.hulls[1]
	# Her crew are all down; one of ours stands on her deck.
	for w in b.side_warriors(1):
		w.wound = CombatTypes.Wound.DOWN
		g.remove(w)
	var boarder: Warrior = b.side_warriors(0)[1]
	for c: Vector2i in theirs:
		if g.is_free(c):
			g.remove(boarder)
			g.place(boarder, c)
			break
	b.round = 1
	var obj: Objective = b.objective
	assert_eq(obj.check(b), 0, "her deck is cleared: she is ours")
	assert_eq(obj.ship_taken, 1)
	assert_true(obj.taken, "the boarders did it")


func test_a_ship_with_no_enemy_aboard_cuts_her_lashings() -> void:
	var built := _deck(11, 0)
	var b: Battle = built.battle
	assert_true(b.can_withdraw(1), "nobody of ours on her deck: she may cut loose")
	var g := b.grid
	var boarder: Warrior = b.side_warriors(0)[1]
	for c: Vector2i in built.hulls[1]:
		if g.is_free(c):
			g.remove(boarder)
			g.place(boarder, c)
			break
	assert_true(not b.can_withdraw(1), "with a man of ours aboard her she cannot")
	g.remove(boarder)
	g.place(boarder, BattleGrid.from_offset(3, 6))
	assert_true(b.withdraw(1), "she cuts loose")
	assert_eq(b.result.how, BattleResult.End.WITHDRAWAL)
	assert_eq(b.result.outcome(0), BattleResult.Outcome.DROVE_THEM_OFF, "they rowed away: we have the field")


func test_a_sea_fight_from_the_map_is_on_the_decks_and_a_taken_ship_is_a_prize() -> void:
	var j := Journey.begin(7, "younger_son", "Egil")
	var c := j.c
	for i in 6:
		c.band.add_man(Recruits.random(SimRng.new(50 + i), c.rules, c.band.next_id()))
	c._arm_new_men()
	var o := c.offer_fight("rival_ship", CombatTypes.Tier.GREEN, 8, false, 3, true, false, "sea", {"cause": "sea"})
	assert_true(o.brief().contains("board"), "the offer says what the fight is over: %s" % o.brief())
	var built := c.build_fight(o, FightOffer.Choice.TAKE_THE_FIELD)
	assert_eq(str(built.field_name), "deck")
	assert_eq((built.objective as Objective).attacker, 1, "they come on: they board")
	# The prize: no ship, so she is kept; a smaller one is sold off.
	c.band.ship = null
	j._take_prize("rival_ship")
	assert_true(c.band.ship != null and c.band.ship.kind == WorldTypes.ShipKind.KARVE, "the band takes her for its own")
	var silver := c.band.silver
	c.band.ship = Ship.make(WorldTypes.ShipKind.SNEKKJA)
	j._take_prize("rival_ship")
	assert_eq(c.band.ship.kind, WorldTypes.ShipKind.SNEKKJA, "a worse hull is not kept")
	assert_eq(c.band.silver, silver + roundi(int(c.world_rules.ship_price[WorldTypes.ShipKind.KARVE]) * c.world_rules.prize_sale_share), "she is sold off")
