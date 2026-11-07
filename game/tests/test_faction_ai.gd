extends TestCase


func _world(r: WorldRules) -> World:
	var w := World.build_norway(r)
	Faction.load_all(w)
	return w


## In 866 Harald's only lawful target is the Agder farms (weaker, hostile,
## one lane from Kaupang): he takes them at conquest_chance x his share of men.
func test_conquest_rate_matches_chance_and_strength() -> void:
	var r := WorldRules.new()
	var n := 2000
	var taken := 0
	for s in n:
		var w := _world(r)
		var log := PackedStringArray()
		var events := FactionAI.yearly(SimRng.new(s), r, w, Band.new(), log)
		var conquests := events.filter(func(e): return e.kind == "conquest")
		var wars := events.filter(func(e): return e.kind == "war")
		assert_eq(conquests.size() + wars.size(), 1, "one campaign a year")
		if not conquests.is_empty():
			taken += 1
			assert_eq(conquests[0].place, "agder_farms")
			assert_eq(w.place("agder_farms").faction_id, "harald")
			assert_true(w.factions["harald"].holds("agder_farms"))
			assert_true(not w.factions["agder"].holds("agder_farms"))
		assert_eq(FactionAI.relation(w, "harald", "agder"), -20 - r.expand_hostility - r.war_relation_hit)
		if failures.size() > 5:
			return
	var expected := r.conquest_chance * 150.0 / 190.0
	assert_between(float(taken) / n, expected - 0.04, expected + 0.04)
	print("    gate: Harald takes the Agder farms in 866 in %.3f of %d seeds (expected %.3f)" % [float(taken) / n, n, expected])


func test_hold_factions_do_not_attack() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	w.factions["harald"].ambition = "hold"
	for s in 50:
		var events := FactionAI.yearly(SimRng.new(s), r, w, Band.new(), PackedStringArray())
		for e in events:
			assert_true(e.kind != "conquest" and e.kind != "war", e.text)


func test_weak_faction_absorbed_by_strongest_neighbour() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	w.factions["harald"].ambition = "hold"
	var sogn: Faction = w.factions["sogn"]
	sogn.strength = r.absorb_strength - 1
	var events := FactionAI.yearly(SimRng.new(1), r, w, Band.new(), PackedStringArray())
	assert_true(not sogn.alive)
	# Sogn borders Hordaland (60) and Møre (50): Hordaland is stronger.
	assert_eq(sogn.absorbed_by, "hordaland")
	assert_eq(w.place("sogn_hall").faction_id, "hordaland")
	assert_true(w.factions["hordaland"].holds("sogn_farms"))
	assert_true(sogn.holdings.is_empty())
	assert_true(events.any(func(e): return e.kind == "absorbed" and e.b == "sogn"))


func test_losing_every_holding_ends_a_faction() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var log := PackedStringArray()
	FactionAI.conquer(r, w, "agder_farms", "harald", log)
	assert_true(w.factions["agder"].alive)
	assert_eq(w.factions["agder"].strength, 20, "lost half its men with half its land")
	assert_eq(w.factions["harald"].strength, 160)
	FactionAI.conquer(r, w, "lindesnes", "harald", log)
	assert_true(not w.factions["agder"].alive)
	assert_eq(w.factions["agder"].absorbed_by, "harald")
	assert_true(log.size() >= 3)


func test_alliances_logged_once_and_marriages_raise_relation() -> void:
	var r := WorldRules.new()
	r.marriage_chance = 1.0
	r.betrayal_chance = 0.0
	var w := _world(r)
	w.factions["harald"].ambition = "hold"
	var e1 := FactionAI.yearly(SimRng.new(3), r, w, Band.new(), PackedStringArray())
	var allied := e1.filter(func(e): return e.kind == "alliance" and e.a == "harald" and e.b == "more")
	assert_eq(allied.size(), 1)
	assert_true(w.factions["more"].allies.has("harald"))
	var e2 := FactionAI.yearly(SimRng.new(4), r, w, Band.new(), PackedStringArray())
	assert_true(not e2.any(func(e): return e.kind == "alliance" and e.a == "harald" and e.b == "more"), "logged once")
	assert_true(e2.any(func(e): return e.kind == "marriage" and e.a == "harald" and e.b == "more"))
	assert_eq(FactionAI.relation(w, "harald", "more"), 60 + r.marriage_relation_gain)


func test_betrayal_breaks_alliance() -> void:
	var r := WorldRules.new()
	r.betrayal_chance = 1.0
	var w := _world(r)
	w.factions["harald"].ambition = "hold"
	FactionAI.yearly(SimRng.new(3), r, w, Band.new(), PackedStringArray())
	var e2 := FactionAI.yearly(SimRng.new(4), r, w, Band.new(), PackedStringArray())
	assert_true(e2.any(func(e): return e.kind == "betrayal"))
	assert_true(not w.factions["harald"].allies.has("more"))
	assert_eq(FactionAI.relation(w, "harald", "more"), 60 - r.betrayal_relation_hit)


func test_raid_lowers_ruler_relation_to_band() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	FactionAI.on_raid(r, w, "avaldsnes", PackedStringArray())
	assert_eq(FactionAI.relation(w, "rogaland", "band"), -r.raid_relation_hit)
	FactionAI.on_raid(r, w, "iceland", PackedStringArray())
