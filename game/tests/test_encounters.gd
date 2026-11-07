extends TestCase


class FakeFaction:
	extends RefCounted
	var name := "the Lade jarls"
	var relations := {}


static func _band(world: World, rules: WorldRules, men := 6) -> Band:
	var b := Band.new()
	b.leader = Man.new()
	b.leader.is_leader = true
	for i in range(men):
		b.add_man(Man.new())
	b.ship = Ship.make(WorldTypes.ShipKind.LONGSHIP)
	b.home = "fitjar"
	b.location = "fitjar"
	Knowledge.learn_home(rules, world, b)
	return b


static func _forced(kind: String) -> WorldRules:
	var r := WorldRules.new()
	r.encounter_chance = 1.0
	r.encounter_weights = {kind: 1}
	return r


func test_chance_and_open_sea_doubling() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r)
	var rng := SimRng.new(8)
	var coast := 0
	var sea := 0
	for i in range(4000):
		if Encounters.happens(rng, r, w, "fitjar", "gulathing"):
			coast += 1
		if Encounters.happens(rng, r, w, "kaupang", "hedeby"):
			sea += 1
	assert_between(coast / 4000.0, r.encounter_chance - 0.03, r.encounter_chance + 0.03)
	assert_between(sea / 4000.0, r.encounter_chance * 2 - 0.04, r.encounter_chance * 2 + 0.04)
	r.encounter_chance = 0.0
	assert_eq(Encounters.roll(rng, r, w, _band(w, r), "fitjar", "gulathing", PackedStringArray()), {})


func test_every_kind_fires_when_forced() -> void:
	var w := World.build_norway(WorldRules.new())
	for kind in ["rival_ship", "merchant", "outlaws", "levy", "storm", "whale"]:
		var r := _forced(kind)
		var e := Encounters.roll(SimRng.new(1), r, w, _band(w, r), "giske", "lade", PackedStringArray())
		assert_eq(e.get("kind", ""), kind)
		assert_true(String(e.get("text", "")) != "", kind + " has text")


func test_rival_ship_battle_tier_from_alertness() -> void:
	var r := _forced("rival_ship")
	var w := World.build_norway(r)
	var e := Encounters.roll(SimRng.new(1), r, w, _band(w, r), "giske", "lade", PackedStringArray())
	var req: Dictionary = e.battle_required
	assert_eq(req.kind, "rival_ship")
	assert_eq(req.attackers, r.rival_crew)
	assert_eq(req.tier, CombatTypes.Tier.GREEN)
	assert_true(req.has("text"))
	w.region_alertness[WorldTypes.Region.TRONDELAG] = 7
	e = Encounters.roll(SimRng.new(1), r, w, _band(w, r), "giske", "lade", PackedStringArray())
	assert_eq(e.battle_required.tier, CombatTypes.Tier.VETERAN)


func test_merchant_trade_and_robbery() -> void:
	var r := _forced("merchant")
	var w := World.build_norway(r)
	var b := _band(w, r)
	b.silver = 1000
	var e := Encounters.roll(SimRng.new(3), r, w, b, "giske", "lade", PackedStringArray())
	assert_true(not e.has("battle_required"), "a merchant offers trade, no fight")
	var offer: Dictionary = e.offer
	assert_eq(offer.price, maxi(1, int(round(r.base_price[offer.good] * r.merchant_discount))))
	assert_true(w.place(offer.home).has_market)
	var bought := Encounters.buy_from_merchant(r, b, e, 3, PackedStringArray())
	assert_eq(bought, 3)
	assert_eq(b.silver, 1000 - 3 * offer.price)
	assert_eq(b.cargo[offer.good], 3)
	# Rob the next one instead.
	var b2 := _band(w, r)
	var e2 := Encounters.roll(SimRng.new(3), r, w, b2, "giske", "lade", PackedStringArray())
	var req := Encounters.rob_merchant(r, e2)
	assert_eq(req.kind, "merchant")
	assert_eq(req.attackers, r.merchant_crew)
	var gained := Encounters.after_battle(r, b2, req, true, PackedStringArray())
	assert_eq(b2.cargo_units(), r.merchant_cargo)
	assert_eq(gained.feud, e2.offer.family)
	assert_eq(b2.unsettled_feuds().size(), 1)
	assert_eq(b2.feuds[0].place, e2.offer.home)
	assert_eq(Encounters.after_battle(r, _band(w, r), req, false, PackedStringArray()), {})


func test_outlaws_bounty_unless_outlawed() -> void:
	var r := _forced("outlaws")
	var w := World.build_norway(r)
	var b := _band(w, r)
	var e := Encounters.roll(SimRng.new(1), r, w, b, "giske", "lade", PackedStringArray())
	assert_eq(e.battle_required.attackers, r.outlaw_crew)
	assert_eq(e.battle_required.bounty, r.outlaw_bounty)
	var silver := b.silver
	Encounters.after_battle(r, b, e.battle_required, true, PackedStringArray())
	assert_eq(b.silver, silver + r.outlaw_bounty)
	b.outlawry = WorldTypes.Outlawry.LESSER
	e = Encounters.roll(SimRng.new(1), r, w, b, "giske", "lade", PackedStringArray())
	assert_eq(e.battle_required.bounty, 0)


func test_levy_fights_outlaws_and_enemies_else_rumor() -> void:
	var r := _forced("levy")
	var w := World.build_norway(r)
	var b := _band(w, r)
	var e := Encounters.roll(SimRng.new(1), r, w, b, "giske", "lade", PackedStringArray())
	assert_true(not e.has("battle_required"))
	assert_true(e.has("rumor"))
	assert_true(b.knows(e.rumor))
	b.outlawry = WorldTypes.Outlawry.FULL
	e = Encounters.roll(SimRng.new(1), r, w, b, "giske", "lade", PackedStringArray())
	assert_eq(e.battle_required.kind, "levy")
	assert_eq(e.battle_required.attackers, r.levy_crew)
	# At war with the ruling faction of the lane's end.
	var b2 := _band(w, r)
	var f := FakeFaction.new()
	f.relations = {"band": r.war_relation - 10}
	w.factions["lade"] = f
	e = Encounters.roll(SimRng.new(1), r, w, b2, "giske", "lade", PackedStringArray())
	assert_eq(e.battle_required.kind, "levy")
	f.relations = {"band": 20}
	e = Encounters.roll(SimRng.new(1), r, w, b2, "giske", "lade", PackedStringArray())
	assert_true(not e.has("battle_required"))


func test_storm_and_whale_effects() -> void:
	var r := _forced("storm")
	var w := World.build_norway(r)
	var b := _band(w, r)
	var e := Encounters.roll(SimRng.new(1), r, w, b, "giske", "lade", PackedStringArray())
	assert_eq(b.ship.damage, r.storm_ship_damage)
	assert_eq(e.ship_damage, r.storm_ship_damage)
	assert_eq(e.delay_days, r.storm_delay_days)
	r = _forced("whale")
	var food := b.food
	e = Encounters.roll(SimRng.new(1), r, w, b, "giske", "lade", PackedStringArray())
	assert_eq(b.food, food + r.whale_food)
	assert_eq(e.food, r.whale_food)


func test_weights_respected() -> void:
	var r := WorldRules.new()
	var rng := SimRng.new(9)
	var counts := {}
	for i in range(6000):
		var k := Encounters.pick_kind(rng, r)
		counts[k] = counts.get(k, 0) + 1
	var total := 0
	for k in r.encounter_weights:
		total += r.encounter_weights[k]
	for k in r.encounter_weights:
		var want: float = float(r.encounter_weights[k]) / total
		assert_between(counts.get(k, 0) / 6000.0, want - 0.03, want + 0.03, k)
