extends TestCase


func _world() -> World:
	var w := World.build_norway(WorldRules.new())
	Faction.load_all(w)
	return w


func test_load_all_reads_every_faction() -> void:
	var w := _world()
	assert_eq(w.factions.size(), NorwayData.FACTIONS.size())
	var h: Faction = w.factions["harald"]
	assert_eq(h.leader, "Harald Fairhair")
	assert_eq(h.kind, WorldTypes.FactionKind.KING)
	assert_eq(h.ambition, "expand")
	assert_eq(h.strength, 150)
	assert_eq(h.holdings.size(), 4)
	assert_true(h.alive)
	assert_eq(h.relations["more"], 60)


func test_holdings_match_places() -> void:
	var w := _world()
	var held := {}
	for f in w.factions.values():
		for id in (f as Faction).holdings:
			assert_true(not held.has(id), "%s held twice" % id)
			held[id] = true
			assert_eq(w.place(id).faction_id, f.id, id)
	assert_eq(FactionAI.ruler_of(w, "lade").id, "lade")
	assert_eq(FactionAI.ruler_of(w, "iceland"), null, "Iceland has no ruler")


func test_relations_are_mutable_copies() -> void:
	var w := _world()
	FactionAI.shift(w, "harald", "more", 10)
	assert_eq(FactionAI.relation(w, "harald", "more"), 70)
	var w2 := _world()
	assert_eq(FactionAI.relation(w2, "harald", "more"), 60, "a fresh load is untouched")
	FactionAI.shift(w, "harald", "band", -500)
	assert_eq(FactionAI.relation(w, "harald", "band"), -100, "clamped")
	assert_eq(FactionAI.relation(w, "nobody", "band"), 0)
