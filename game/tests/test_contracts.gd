extends TestCase


func _world(r: WorldRules) -> World:
	var w := World.build_norway(r)
	Faction.load_all(w)
	return w


func test_offers_at_halls_and_towns_by_ruler() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	var kinds := {}
	for s in 200:
		var offers := Contracts.offers(SimRng.new(s), r, w, b, "kaupang")
		assert_between(offers.size(), 1, r.contract_offers_max)
		for c in offers:
			assert_eq(c.from_faction, "harald")
			assert_true(c.pay >= 0 and c.days > 0 and c.text != "")
			kinds[c.kind] = true
	assert_true(kinds.has("escort") and kinds.has("hunt_outlaws") and kinds.has("levy") and kinds.has("debt"))
	assert_true(not kinds.has("tribute"), "tribute only for higher ranks")
	assert_eq(Contracts.offers(SimRng.new(1), r, w, b, "lier").size(), 0, "none at a farm")
	assert_eq(Contracts.offers(SimRng.new(1), r, w, b, "iceland").size(), 0, "none without a ruler")
	FactionAI.shift(w, "harald", "band", r.contract_relation - 1)
	assert_eq(Contracts.offers(SimRng.new(1), r, w, b, "kaupang").size(), 0, "none to the disliked")


func test_tribute_offered_to_a_hersir() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	b.rank = WorldTypes.Rank.HERSIR
	var seen := false
	for s in 100:
		for c in Contracts.offers(SimRng.new(s), r, w, b, "kaupang"):
			if c.kind == "tribute":
				seen = true
				assert_eq(w.place(c.to_place).faction_id, "harald")
	assert_true(seen)


func test_accept_asks_for_battle_or_voyage() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	var by_kind := {}
	for s in 200:
		for c in Contracts.offers(SimRng.new(s), r, w, b, "kaupang"):
			by_kind[c.kind] = c
	var hunt := Contracts.accept(r, w, b, by_kind["hunt_outlaws"], PackedStringArray())
	assert_eq(hunt.battle_required.kind, "hunt_outlaws")
	assert_eq(hunt.battle_required.attackers, r.contract_outlaws)
	assert_eq(hunt.battle_required.tier, r.contract_outlaw_tier)
	var levy := Contracts.accept(r, w, b, by_kind["levy"], PackedStringArray())
	assert_eq(levy.battle_required.attackers, r.contract_levy_men)
	var escort := Contracts.accept(r, w, b, by_kind["escort"], PackedStringArray())
	assert_true(w.place(escort.voyage_required).has_market)
	var debt := Contracts.accept(r, w, b, by_kind["debt"], PackedStringArray())
	assert_eq(w.place(debt.voyage_required).kind, WorldTypes.PlaceKind.FARMSTEAD)


func test_complete_pays_and_raises_relation_and_rank() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	var c: Dictionary = {}
	for s in 50:
		for o in Contracts.offers(SimRng.new(s), r, w, b, "lade"):
			if o.kind == "escort":
				c = o
	assert_true(not c.is_empty())
	assert_eq(c.from_faction, "lade")
	var silver := b.silver
	var fame := b.fame
	var rel := FactionAI.relation(w, "lade", "band")
	Contracts.accept(r, w, b, c, PackedStringArray())
	var log := PackedStringArray()
	Contracts.complete(r, w, b, c, true, log)
	assert_eq(b.silver, silver + c.pay)
	assert_true(c.pay > 0)
	assert_eq(b.fame, fame + r.contract_fame["escort"])
	assert_eq(FactionAI.relation(w, "lade", "band"), rel + r.contract_relation_gain)
	assert_eq(b.rank_progress, r.rank_progress_per_contract)
	assert_eq(log.size(), 1)
	Contracts.complete(r, w, b, c, false, log)
	assert_eq(b.silver, silver + c.pay, "no pay for failure")
	assert_eq(FactionAI.relation(w, "lade", "band"), rel + r.contract_relation_gain - r.contract_fail_relation_hit)


func test_pay_within_spread_and_rank_earned() -> void:
	var r := WorldRules.new()
	var w := _world(r)
	var b := Band.new()
	for s in 200:
		for c in Contracts.offers(SimRng.new(s), r, w, b, "hedeby"):
			var base: float = r.contract_pay[c.kind]
			assert_between(c.pay, floor(base * (1.0 - r.contract_pay_spread)), ceil(base * (1.0 + r.contract_pay_spread)))
	assert_eq(Contracts.rank_earned(r, b), WorldTypes.Rank.KARL)
	b.rank_progress = r.rank_thresholds[WorldTypes.Rank.JARL]
	assert_eq(Contracts.rank_earned(r, b), WorldTypes.Rank.JARL)
