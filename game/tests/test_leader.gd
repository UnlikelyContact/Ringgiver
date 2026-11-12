extends TestCase


func _band() -> Band:
	var b := Band.new()
	var l := Man.new()
	l.display_name = "Egil"
	l.is_leader = true
	b.leader = l
	b.luck = 5
	b.fame = 10
	b.honor = 50
	return b


func test_battle_luck_and_fame() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	Leader.on_battle(r, b, true, true, 1.0, log)
	assert_eq(b.luck, 5 + r.luck_win)
	assert_eq(b.fame, 10 + r.fame_win)
	b = _band()
	Leader.on_battle(r, b, true, true, r.long_odds - 0.1, log)
	assert_eq(b.luck, 5 + r.luck_long_odds, "a win against long odds")
	assert_eq(b.fame, 10 + r.fame_long_odds)
	b = _band()
	Leader.on_battle(r, b, false, true, 0.3, log)
	assert_eq(b.luck, 5 - r.luck_loss, "a loss, odds do not matter")
	b = _band()
	Leader.on_battle(r, b, true, false, 1.0, log)
	assert_eq(b.luck, 5 + r.luck_win - r.luck_hung_back)
	assert_eq(b.honor, 50 - r.honor_hung_back, "hanging back costs honor")
	# The ladder: a rout is talked of more, a withdrawal costs honor and no
	# luck, both drawing off costs nothing.
	b = _band()
	Leader.on_battle(r, b, true, true, 1.0, log, BattleResult.Outcome.ROUTED_THEM)
	assert_eq(b.fame, 10 + r.fame_win + r.fame_rout, "a rout brings more fame")
	b = _band()
	Leader.on_battle(r, b, false, true, 1.0, log, BattleResult.Outcome.WITHDREW)
	assert_eq(b.luck, 5, "a withdrawal is a choice: no luck lost")
	assert_eq(b.honor, 50 - r.honor_withdrew, "but it costs honor")
	b = _band()
	Leader.on_battle(r, b, false, true, r.long_odds - 0.1, log, BattleResult.Outcome.WITHDREW)
	assert_eq(b.honor, 50, "no shame in leaving a fight at long odds")
	b = _band()
	Leader.on_battle(r, b, false, true, 1.0, log, BattleResult.Outcome.BOTH_DREW_OFF)
	assert_eq(b.luck, 5, "both drawing off is nobody's day")
	assert_eq(b.honor, 50)
	assert_true(log.size() >= 5)


func test_vows_oaths_feasts() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	b.vows.append({"year": 866, "text": "burn Thorir's hall", "kept": null})
	Leader.on_vow_kept(r, b, "burn Thorir's hall", log)
	assert_eq(b.vows.size(), 1)
	assert_eq(b.vows[0].kept, true)
	assert_eq(b.luck, 5 + r.luck_vow_kept)
	assert_eq(b.honor, 50 + r.honor_vow_kept)
	assert_eq(b.fame, 10 + r.fame_vow_kept)
	b = _band()
	Leader.on_vow_broken(r, b, "sail to Dublin", log)
	assert_eq(b.vows[0].kept, false, "an unrecorded vow is recorded as broken")
	assert_eq(b.luck, 5 - r.luck_vow_broken)
	assert_eq(b.honor, 50 - r.honor_vow_broken)
	b = _band()
	Leader.on_oath_broken(r, b, log)
	assert_eq(b.luck, 5 - r.luck_oath_broken)
	assert_eq(b.honor, 50 - r.honor_oath_broken)
	b = _band()
	Leader.on_feast(r, b, false, log)
	assert_eq(b.fame, 10, "a plain feast wins no fame")
	Leader.on_feast(r, b, true, log)
	assert_eq(b.fame, 10 + r.fame_feast)


func test_luck_and_reputation_clamp() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	for i in 20:
		Leader.on_battle(r, b, true, true, 0.1, log)
		Leader.on_vow_kept(r, b, "v%d" % i, log)
	assert_eq(b.luck, 10)
	assert_eq(b.fame, 100)
	assert_eq(b.honor, 100)
	for i in 20:
		Leader.on_oath_broken(r, b, log)
	assert_eq(b.luck, 0)
	assert_eq(b.honor, 0)


func test_omen_ignored_at_chance() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var hits := 0
	var n := 4000
	for s in n:
		var b := _band()
		Leader.on_omen_ignored(SimRng.new(s), r, b, log)
		if b.luck < 5:
			hits += 1
			assert_eq(b.luck, 5 - r.luck_omen)
	assert_between(float(hits) / n, r.omen_chance - 0.04, r.omen_chance + 0.04)


func test_luck_modifier_boundaries() -> void:
	var r := CampaignRules.new()
	var b := _band()
	b.luck = r.luck_high
	assert_eq(Leader.luck_modifier(r, b), 1)
	b.luck = r.luck_high - 1
	assert_eq(Leader.luck_modifier(r, b), 0)
	b.luck = r.luck_low + 1
	assert_eq(Leader.luck_modifier(r, b), 0)
	b.luck = r.luck_low
	assert_eq(Leader.luck_modifier(r, b), -1)
	b.luck = 0
	assert_eq(Leader.luck_modifier(r, b), -1)
	b.luck = 10
	assert_eq(Leader.luck_modifier(r, b), 1)


func test_recruits_drawn_from_fame() -> void:
	var r := CampaignRules.new()
	var b := _band()
	b.fame = 0
	assert_eq(Leader.recruits_drawn(r, b), r.recruits_min)
	b.fame = r.fame_per_recruit - 1
	assert_eq(Leader.recruits_drawn(r, b), maxi(r.recruits_min, 0))
	b.fame = r.fame_per_recruit * 3
	assert_eq(Leader.recruits_drawn(r, b), 3)
	b.fame = 100
	assert_eq(Leader.recruits_drawn(r, b), 100 / r.fame_per_recruit)
