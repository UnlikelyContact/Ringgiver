extends TestCase

const FAMILY := "Kjotve's kin"


func _band() -> Band:
	var b := Band.new()
	b.year = 870
	b.silver = 200
	return b


func test_wergild_by_rank() -> void:
	var r := WorldRules.new()
	assert_eq(Feud.wergild(r, WorldTypes.Rank.THRALL), 5)
	assert_eq(Feud.wergild(r, WorldTypes.Rank.KARL), 40)
	assert_eq(Feud.wergild(r, WorldTypes.Rank.KING), 600)
	var last := 0
	for rank in WorldTypes.Rank.values():
		var w := Feud.wergild(r, rank)
		assert_true(w > last, "wergild rises with rank")
		last = w


func test_start_records_family_place_level() -> void:
	var r := WorldRules.new()
	var b := _band()
	var log := PackedStringArray()
	Feud.start(r, b, FAMILY, "a burned farm", "agder_farms", log)
	Feud.start(r, b, FAMILY, "another insult", "agder_farms", log)
	assert_eq(b.feuds.size(), 1, "one open feud per family")
	var f := Feud.find(b, FAMILY)
	assert_eq(f.family, FAMILY)
	assert_eq(f.place, "agder_farms")
	assert_eq(f.level, 1)
	assert_eq(f.settled, false)
	assert_eq(Feud.offer_settlement(r, b, FAMILY), 40)


func test_gate_escalates_to_three_and_hires_blades() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := _band()
	var log := PackedStringArray()
	Feud.start(r, b, FAMILY, "a burned farm", "agder_farms", log)
	var honor := b.honor
	Feud.escalate(r, b, FAMILY, log)
	assert_eq(Feud.find(b, FAMILY).level, 2)
	assert_eq(b.honor, honor, "one refusal costs no honor")
	assert_eq(Feud.offer_settlement(r, b, FAMILY), 60)
	Feud.escalate(r, b, FAMILY, log)
	assert_eq(Feud.find(b, FAMILY).level, 3, "two refusals reach level 3")
	assert_eq(b.honor, honor - r.feud_refusal_honor, "refusing twice costs honor")
	assert_eq(Feud.offer_settlement(r, b, FAMILY), 80)
	Feud.escalate(r, b, FAMILY, log)
	assert_eq(Feud.find(b, FAMILY).level, 3, "capped at 3")
	var n := 4000
	var ambushes := 0
	var demands := 0
	for s in n:
		for ev in Feud.summer_events(SimRng.new(s), r, w, b, PackedStringArray()):
			if ev.kind == "ambush":
				ambushes += 1
				var br: Dictionary = ev.battle_required
				assert_eq(br.attackers, r.feud_ambush_men + r.hired_blades)
				assert_eq(br.hired_blades, r.hired_blades)
				assert_eq(br.family, FAMILY)
				assert_eq(br.tier, r.feud_tier)
			elif ev.kind == "demand":
				demands += 1
				assert_eq(ev.ounces, 80)
	var rate := float(ambushes) / n
	print("    feud gate: level-3 ambush rate %.3f (expected %.2f), each with %d hired blades" % [
		rate, r.ambush_chance * 3, r.hired_blades])
	assert_between(rate, r.ambush_chance * 3 - 0.04, r.ambush_chance * 3 + 0.04)
	assert_between(float(demands) / n, r.demand_chance - 0.04, r.demand_chance + 0.04)


func test_level_one_ambushes_without_hired_blades() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := _band()
	Feud.start(r, b, FAMILY, "a burned farm", "agder_farms", PackedStringArray())
	var ambushes := 0
	for s in 4000:
		for ev in Feud.summer_events(SimRng.new(s), r, w, b, PackedStringArray()):
			if ev.kind == "ambush":
				ambushes += 1
				assert_eq(ev.battle_required.attackers, r.feud_ambush_men)
	assert_between(float(ambushes) / 4000, r.ambush_chance - 0.03, r.ambush_chance + 0.03)


func test_settle_ends_the_feud() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := _band()
	var log := PackedStringArray()
	Feud.start(r, b, FAMILY, "a burned farm", "agder_farms", log)
	assert_true(not Feud.settle(r, b, FAMILY, 20, log), "too little")
	b.silver = 30
	assert_true(not Feud.settle(r, b, FAMILY, 40, log), "cannot pay what he lacks")
	b.silver = 100
	assert_true(Feud.settle(r, b, FAMILY, 40, log))
	assert_eq(b.silver, 60)
	assert_eq(b.feuds[0].settled, true)
	assert_eq(b.unsettled_feuds().size(), 0)
	for s in 200:
		assert_eq(Feud.summer_events(SimRng.new(s), r, w, b, PackedStringArray()).size(), 0)


func test_deterministic() -> void:
	var r := WorldRules.new()
	var w := World.build_norway(r, 870)
	var b := _band()
	Feud.start(r, b, FAMILY, "a burned farm", "agder_farms", PackedStringArray())
	Feud.start(r, b, "the Lade jarls", "a slain karl", "lade", PackedStringArray())
	for s in 50:
		var a := PackedStringArray()
		var c := PackedStringArray()
		Feud.summer_events(SimRng.new(s), r, w, b, a)
		Feud.summer_events(SimRng.new(s), r, w, b, c)
		assert_eq(a, c)
