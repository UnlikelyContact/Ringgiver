extends TestCase


func _man(name: String, loyalty := 50) -> Man:
	var m := Man.new()
	m.display_name = name
	m.loyalty = loyalty
	return m


func _band() -> Band:
	var b := Band.new()
	b.leader = _man("Egil")
	b.leader.is_leader = true
	b.leader.id = b.next_id()
	return b


func _son(name: String, born: int) -> Dictionary:
	var pot: Array[int] = [5, 5, 5, 5, 5]
	return {"name": name, "born": born, "potential": pot, "fostered_with": "", "alive": true, "daughter": false}


## Same men (seeded) under two different old leaders.
func _random_band(s: int, fame: int, honor: int, luck: int) -> Band:
	var rng := SimRng.new(s)
	var b := _band()
	b.fame = fame
	b.honor = honor
	b.luck = luck
	b.silver = 100
	var second := _man("Second", 80)
	b.add_man(second)
	b.sworn_second_id = second.id
	for i in 10:
		b.add_man(_man("Man%d" % i, rng.randi_range(35, 75)))
	for m in b.men:
		if m != second:
			b.set_bond(m, second, rng.randi_range(-15, 15))
	return b


func test_gate_famous_battle_death_keeps_more_men() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var kept_good := 0
	var kept_bad := 0
	var total := 0
	var n := 300
	for s in n:
		var good := _random_band(s, 90, 90, 8)
		var bad := _random_band(s, 10, 15, 2)
		var cal := Calendar.new(870)
		var gl := Succession.succeed(SimRng.new(s), r, good, cal, good.man_by_id(good.sworn_second_id), 10, "avenge my father", log, "battle")
		var bl := Succession.succeed(SimRng.new(s), r, bad, cal, bad.man_by_id(bad.sworn_second_id), 10, "avenge my father", log, "outlaw")
		assert_true(gl.size() <= bl.size(), "seed %d: a famous leader never loses more" % s)
		kept_good += good.men.size()
		kept_bad += bad.men.size()
		total += 10
		assert_eq(good.men.size() + gl.size(), 10)
	var fg := float(kept_good) / total
	var fb := float(kept_bad) / total
	print("    gate: famous battle death keeps %.2f, outlawed nobody keeps %.2f" % [fg, fb])
	assert_true(kept_good > kept_bad)
	assert_between(fg, 0.45, 0.85)
	assert_between(fb, 0.25, 0.7)
	assert_between(fg - fb, 0.05, 0.4)


func test_luck_and_fame_carry() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _random_band(1, 80, 50, 8)
	Succession.succeed(SimRng.new(1), r, b, Calendar.new(870), b.man_by_id(b.sworn_second_id), 0, "", log, "battle")
	assert_eq(b.luck, roundi(8 * r.luck_inherit_fraction) + r.luck_good_death)
	assert_eq(b.fame, roundi(80 * r.fame_inherit_fraction))
	b = _random_band(1, 80, 50, 8)
	Succession.succeed(SimRng.new(1), r, b, Calendar.new(870), b.man_by_id(b.sworn_second_id), 0, "", log, "outlaw")
	assert_eq(b.luck, roundi(8 * r.luck_inherit_fraction) - r.luck_shameful_death)
	b = _random_band(1, 80, 50, 8)
	Succession.succeed(SimRng.new(1), r, b, Calendar.new(870), b.man_by_id(b.sworn_second_id), 0, "", log, "old")
	assert_eq(b.luck, roundi(8 * r.luck_inherit_fraction))
	b = _random_band(1, 80, 50, 1)
	Succession.succeed(SimRng.new(1), r, b, Calendar.new(870), b.man_by_id(b.sworn_second_id), 0, "", log, "oathbreaker")
	assert_eq(b.luck, 0, "clamped")


func test_son_of_twelve_never_heir() -> void:
	var r := CampaignRules.new()
	var b := _band()
	var second := _man("Second")
	b.add_man(second)
	b.sworn_second_id = second.id
	b.sons.append(_son("Ketil", 858))
	for y in range(858, 858 + r.heir_min_age):
		var h := Succession.heir(r, b, Calendar.new(y))
		assert_eq(h.kind, "second", "a son of %d is not the heir" % (y - 858))
	b.sworn_second_id = -1
	assert_eq(Succession.heir(r, b, Calendar.new(870)).kind, "none", "a son of 12 and no second: no heir")
	b.sworn_second_id = second.id
	var h12 := Succession.heir(r, b, Calendar.new(870))
	assert_eq(h12.kind, "second")
	assert_eq(h12.man, second)
	var h15 := Succession.heir(r, b, Calendar.new(858 + r.heir_min_age))
	assert_eq(h15.kind, "son")
	assert_eq(h15.son.name, "Ketil")
	second.alive = false
	b.sons[0].alive = false
	assert_eq(Succession.heir(r, b, Calendar.new(880)).kind, "none")


func test_name_second() -> void:
	var b := _band()
	var m := _man("Thorir")
	b.add_man(m)
	var log := PackedStringArray()
	Succession.name_second(b, m, log)
	assert_eq(b.sworn_second_id, m.id)
	assert_eq(Succession.heir(CampaignRules.new(), b, Calendar.new(866)).man, m)


func test_feuds_carry_over_and_seat_changes() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	b.silver = 15
	var old := b.leader
	for i in 4:
		b.add_man(_man("Man%d" % i, 90))
	b.add_feud("Thorir", "Egil's brother slain")
	b.add_feud("Hakon", "a stolen ship")
	b.feuds[1].settled = true
	var before := b.feuds.duplicate(true)
	var heir := _man("Ketil")
	heir.id = b.next_id()
	var left := Succession.succeed(SimRng.new(3), r, b, Calendar.new(880), heir, 40, "burn Thorir's hall", log, "battle")
	assert_eq(b.feuds, before, "feuds carry over in full")
	assert_eq(b.leader, heir)
	assert_true(heir.is_leader)
	assert_true(not old.is_leader)
	assert_eq(b.silver, 0, "the grave-ale costs what the band holds, no more")
	assert_eq(left.size(), 0)
	assert_eq(b.men.size(), 4)
	assert_eq(b.vows.size(), 1)
	assert_eq(b.vows[0].text, "burn Thorir's hall")
	assert_eq(b.vows[0].year, 880)
	assert_eq(b.vows[0].kept, null)


func test_second_heir_leaves_men() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	var second := _man("Second", 90)
	b.add_man(second)
	b.sworn_second_id = second.id
	var loyal := _man("Loyal", 90)
	var weak := _man("Weak", 20)
	b.add_man(loyal)
	b.add_man(weak)
	var left := Succession.succeed(SimRng.new(1), r, b, Calendar.new(870), second, 0, "", log, "old")
	assert_eq(left, [weak] as Array[Man])
	assert_true(not b.men.has(second), "the heir leaves the benches for the high seat")
	assert_eq(b.sworn_second_id, -1)
	assert_true(b.men.has(loyal))
	assert_true(not b.men.has(weak))


func test_feast_brings_men_back() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var stays_no_feast := 0
	var stays_feast := 0
	for s in 100:
		for feast in [0, 30]:
			var b := _random_band(s, 30, 50, 5)
			b.silver = 100
			var left := Succession.succeed(SimRng.new(s), r, b, Calendar.new(870), b.man_by_id(b.sworn_second_id), feast, "", log, "old")
			if feast == 0:
				stays_no_feast += 10 - left.size()
			else:
				stays_feast += 10 - left.size()
	assert_true(stays_feast > stays_no_feast, "a lavish grave-ale keeps more men")


func test_passed_over_second_leaves_with_brothers_or_challenges() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	for challenge in [0.0, 1.0]:
		r.challenge_chance = challenge
		var b := _band()
		var second := _man("Second", 95)
		var brother := _man("Brother", 95)
		var other := _man("Other", 95)
		b.add_man(second)
		b.add_man(brother)
		b.add_man(other)
		b.sworn_second_id = second.id
		b.set_bond_kind(second, brother, CampaignTypes.BondKind.OATH_BROTHER)
		var son := _man("Ketil")
		son.id = b.next_id()
		b.set_bond(second, son, -10)
		var left := Succession.succeed(SimRng.new(5), r, b, Calendar.new(880), son, 0, "", log, "battle")
		if challenge == 0.0:
			assert_eq(left.size(), 2)
			assert_true(left.has(second) and left.has(brother))
			assert_true(b.men.has(other))
			assert_eq(b.sworn_second_id, -1)
		else:
			assert_eq(left.size(), 0, "a challenger stays to fight")
			assert_eq(b.get_meta(Succession.PENDING_CHALLENGE_META), second.id)
			assert_true(b.chronicle[b.chronicle.size() - 1].contains("holmgang") or "\n".join(b.chronicle).contains("holmgang"))
	# A second who likes the son stays and remains second.
	r.challenge_chance = 0.0
	var b2 := _band()
	var s2 := _man("Second", 95)
	b2.add_man(s2)
	b2.sworn_second_id = s2.id
	var son2 := _man("Ketil")
	son2.id = b2.next_id()
	b2.set_bond(s2, son2, 10)
	var left2 := Succession.succeed(SimRng.new(5), r, b2, Calendar.new(880), son2, 0, "", log, "battle")
	assert_eq(left2.size(), 0)
	assert_eq(b2.sworn_second_id, s2.id)
