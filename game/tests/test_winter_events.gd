extends TestCase


func _band(n: int) -> Band:
	var b := Band.new()
	b.leader = Man.new()
	b.leader.display_name = "Hrafn"
	b.leader.id = b.next_id()
	for i in n:
		var m := Man.new()
		m.display_name = "man%d" % i
		b.add_man(m)
	b.silver = 50
	b.food = 30
	b.captives = 1  # a thrall kept, so thrall unrest can be drawn
	return b


func _cal() -> Calendar:
	var c := Calendar.new(870)
	c.start_winter()
	return c


## Rules where only `kind` can be drawn, and feud kinds always fire.
func _only(kind: String) -> CampaignRules:
	var r := CampaignRules.new()
	var w := {}
	for k in r.winter_events:
		w[k] = 1 if k == kind else 0
	r.winter_events = w
	r.feud_attack_chance = 1.0
	r.hall_burning_chance = 1.0
	return r


func test_every_kind_can_fire() -> void:
	var base := CampaignRules.new()
	for k in base.winter_events:
		var kind: String = k
		var r := _only(kind)
		var b := _band(6)
		b.add_feud("Thorir", "Egil slain")
		var log := PackedStringArray()
		var evs := WinterEvents.roll(SimRng.new(5), r, b, _cal(), false, log)
		assert_eq(evs.size(), 1, kind)
		if evs.is_empty():
			continue
		var ev: Dictionary = evs[0]
		assert_eq(ev.kind, kind)
		assert_true(ev.text != "", kind + " has text")
		assert_eq(log.size(), 1, kind + " logged")


func test_event_effects() -> void:
	var cal := _cal()
	var b := _band(6)
	b.add_feud("Thorir", "Egil slain")
	var log := PackedStringArray()

	var ev: Dictionary = WinterEvents.roll(SimRng.new(1), _only("skald"), b, cal, false, log)[0]
	assert_eq(b.silver, 50 - CampaignRules.new().skald_fee)
	assert_true(ev.fame > 0)

	b.silver = 50
	ev = WinterEvents.roll(SimRng.new(1), _only("trader"), b, cal, false, log)[0]
	var r := CampaignRules.new()
	assert_eq(b.silver, 50 - r.trader_price)
	assert_eq(b.food, 30 + r.trader_food)

	ev = WinterEvents.roll(SimRng.new(1), _only("outlaw_shelter"), b, cal, false, log)[0]
	assert_true(ev.recruit_request)

	ev = WinterEvents.roll(SimRng.new(1), _only("marriage_offer"), b, cal, false, log)[0]
	assert_true(r.marriage_houses.has(ev.marriage_offer))

	ev = WinterEvents.roll(SimRng.new(1), _only("envoy"), b, cal, false, log)[0]
	assert_eq(b.rumors.size(), 1)

	ev = WinterEvents.roll(SimRng.new(1), _only("sickness"), b, cal, false, log)[0]
	assert_eq(ev.sick.size(), r.sickness_men)
	var sick := 0
	for m in b.men:
		if m.healing_turns == r.sickness_turns:
			sick += 1
	assert_eq(sick, r.sickness_men)

	ev = WinterEvents.roll(SimRng.new(1), _only("storm"), b, cal, false, log)[0]
	assert_eq(b.ship_damage, r.storm_ship_damage)

	var food := b.food
	ev = WinterEvents.roll(SimRng.new(1), _only("thrall_unrest"), b, cal, false, log)[0]
	assert_eq(b.food, food - r.thrall_unrest_food)

	ev = WinterEvents.roll(SimRng.new(1), _only("quarrel"), b, cal, false, log)[0]
	assert_eq(ev.quarrel.size(), 2)
	assert_ne(ev.quarrel[0], ev.quarrel[1])

	for kind in ["feud_attack", "hall_burning"]:
		ev = WinterEvents.roll(SimRng.new(1), _only(kind), b, cal, false, log)[0]
		var br: Dictionary = ev.battle_required
		assert_eq(br.kind, kind)
		assert_eq(br.against, "Thorir")
		assert_true(br.attackers > 0)
		assert_true(br.has("tier"))


func test_poor_band_events_do_not_go_negative() -> void:
	var b := _band(1)
	b.silver = 0
	b.food = 2
	var log := PackedStringArray()
	for kind in ["skald", "trader", "thrall_unrest", "sickness"]:
		WinterEvents.roll(SimRng.new(2), _only(kind), b, _cal(), false, log)
	assert_eq(b.silver, 0)
	assert_eq(b.food, 0)
	assert_eq(WinterEvents.roll(SimRng.new(2), _only("quarrel"), b, _cal(), false, log).size(), 0,
			"no quarrel with one man")


## Gate: no hall-burning or feud attack ever fires without an unsettled feud.
func test_gate_no_feud_no_attack() -> void:
	var r := CampaignRules.new()
	r.feud_attack_chance = 1.0
	r.hall_burning_chance = 1.0
	r.events_per_turn = 3
	var b := _band(8)
	b.add_feud("Thorir", "old wrong")
	b.feuds[0].settled = true
	var rng := SimRng.new(9)
	var cal := _cal()
	for i in 3000:
		for ev in WinterEvents.roll(rng, r, b, cal, i % 2 == 0, PackedStringArray()):
			assert_true(not ev.kind in WinterEvents.FEUD_KINDS, "fired %s without a feud" % ev.kind)
			assert_true(not ev.has("battle_required"))
		b.silver = 50
		b.food = 30
	# Forced: still nothing.
	assert_eq(WinterEvents.roll(rng, _only("feud_attack"), b, cal, false, PackedStringArray()).size(), 0)
	assert_eq(WinterEvents.roll(rng, _only("hall_burning"), b, cal, false, PackedStringArray()).size(), 0)


func test_guard_halves_attack_chance() -> void:
	var r := _only("feud_attack")
	r.feud_attack_chance = 0.4
	var b := _band(4)
	b.add_feud("Thorir", "Egil slain")
	var rng := SimRng.new(4)
	var open := 0
	var guarded := 0
	var n := 4000
	for i in n:
		open += WinterEvents.roll(rng, r, b, _cal(), false, PackedStringArray()).size()
		guarded += WinterEvents.roll(rng, r, b, _cal(), true, PackedStringArray()).size()
	assert_between(float(open) / n, 0.36, 0.44)
	assert_between(float(guarded) / n, 0.17, 0.23)


func test_winter_turn_reports_battle() -> void:
	var r := _only("hall_burning")
	var b := _band(4)
	b.add_feud("Thorir", "Egil slain")
	var rep := Winter.run_turn(SimRng.new(1), r, b, _cal(), WinterPlan.new(), PackedStringArray())
	assert_eq(rep.battle_required.kind, "hall_burning")
	assert_eq(rep.events.size(), 1)
