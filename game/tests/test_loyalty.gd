extends TestCase


func _man(id: int, name: String, loyalty := 50) -> Man:
	var m := Man.new()
	m.id = id
	m.display_name = name
	m.loyalty = loyalty
	m.ambition = CampaignTypes.Ambition.FAME
	return m


func _band(n: int, loyalty := 50) -> Band:
	var b := Band.new()
	var lead := _man(100, "Harek", 100)
	lead.is_leader = true
	b.leader = lead
	for i in n:
		b.add_man(_man(i + 1, "Man%d" % (i + 1), loyalty))
	return b


func test_gift_scales_caps_and_rings() -> void:
	var r := CampaignRules.new()
	var b := _band(1)
	var m := b.men[0]
	var log := PackedStringArray()
	Loyalty.gift(r, b, m, 3, log)
	assert_eq(m.loyalty, 50 + 3 * r.loyalty_per_ounce)
	assert_eq(b.chronicle.size(), 0, "a small gift is no arm-ring")
	m.loyalty = 10
	Loyalty.gift(r, b, m, 50, log)
	assert_eq(m.loyalty, 10 + r.gift_cap + r.loyalty_ring_bonus, "capped, plus the ring bonus")
	assert_eq(b.chronicle.size(), 1, "an arm-ring is remembered")
	var greedy := _man(9, "Silverhand", 10)
	greedy.ambition = CampaignTypes.Ambition.SILVER
	Loyalty.gift(r, b, greedy, 1, log)
	assert_eq(greedy.loyalty, 10 + r.loyalty_per_ounce + r.ambition_gift_bonus)
	m.loyalty = 95
	Loyalty.gift(r, b, m, 20, log)
	assert_eq(m.loyalty, 100, "clamped to 100")


func test_gift_gear_sets_gear() -> void:
	var r := CampaignRules.new()
	var b := _band(1)
	var m := b.men[0]
	var log := PackedStringArray()
	m.has_shield = false
	Loyalty.gift_gear(r, b, m, "sword", log)
	assert_eq(m.weapon, CombatTypes.Weapon.SWORD)
	assert_eq(m.loyalty, 50 + r.loyalty_gear_gift)
	Loyalty.gift_gear(r, b, m, "mail", log)
	assert_eq(m.armor, CombatTypes.Armor.MAIL)
	Loyalty.gift_gear(r, b, m, "helmet", log)
	assert_true(m.helmet)
	Loyalty.gift_gear(r, b, m, "shield", log)
	assert_true(m.has_shield)
	Loyalty.gift_gear(r, b, m, "axe", log)
	assert_eq(m.weapon, CombatTypes.Weapon.BEARDED_AXE)
	Loyalty.gift_gear(r, b, m, "spear", log)
	assert_eq(m.weapon, CombatTypes.Weapon.SPEAR)
	var before := m.loyalty
	Loyalty.gift_gear(r, b, m, "cabbage", log)
	assert_eq(m.loyalty, before, "unknown gear does nothing")


func test_share_plunder_fair_and_unfair() -> void:
	var r := CampaignRules.new()
	var b := _band(4)
	b.men[0].personality = [CombatTypes.Personality.GREEDY]
	b.silver = 0
	var log := PackedStringArray()
	Loyalty.share_plunder(r, b, 100, 0.2, log)
	assert_eq(b.silver, 20, "leader keeps his fifth")
	assert_eq(b.men[1].loyalty, 50 + r.loyalty_fair_share)
	assert_eq(b.men[0].loyalty, 50 + 2 * r.loyalty_fair_share, "greedy doubles")
	Loyalty.share_plunder(r, b, 100, 0.6, log)
	assert_eq(b.silver, 80)
	assert_eq(b.men[1].loyalty, 50 + r.loyalty_fair_share - r.loyalty_unfair_share)
	assert_eq(b.men[0].loyalty, 50 + 2 * r.loyalty_fair_share - 2 * r.loyalty_unfair_share)
	b.silver = 0
	Loyalty.share_plunder(r, b, 10, 0.0, log)
	assert_eq(b.silver, 2, "odd ounces stay with the leader")


func test_ambition_fulfilled_once() -> void:
	var r := CampaignRules.new()
	var b := _band(1)
	var m := b.men[0]
	var log := PackedStringArray()
	Loyalty.ambition_progress(r, b, m, r.ambition_fulfilled - 1, log)
	assert_true(not m.ambition_met)
	assert_eq(m.loyalty, 50)
	Loyalty.ambition_progress(r, b, m, 5, log)
	assert_true(m.ambition_met)
	assert_eq(m.loyalty, 50 + r.loyalty_ambition_met)
	Loyalty.ambition_progress(r, b, m, 500, log)
	assert_eq(m.loyalty, 50 + r.loyalty_ambition_met, "the jump comes once")


func test_winter_drift() -> void:
	var r := CampaignRules.new()
	var b := _band(1)
	var m := b.men[0]
	var log := PackedStringArray()
	b.luck = 5
	Loyalty.winter_drift(r, b, m, true, true, log)
	assert_eq(m.loyalty, 50 + r.loyalty_winter_rest)
	m.loyalty = 50
	Loyalty.winter_drift(r, b, m, false, true, log)
	assert_eq(m.loyalty, 50 - r.loyalty_unfed_per_turn)
	m.loyalty = 50
	Loyalty.winter_drift(r, b, m, true, false, log)
	assert_eq(m.loyalty, 50 - r.loyalty_unseated)
	m.loyalty = 50
	Loyalty.winter_drift(r, b, m, false, false, log)
	assert_eq(m.loyalty, 50 - r.loyalty_unfed_per_turn - r.loyalty_unseated)
	m.loyalty = 50
	b.luck = r.luck_loyalty_above + 1
	Loyalty.winter_drift(r, b, m, true, true, log)
	assert_eq(m.loyalty, 50 + r.loyalty_winter_rest + r.loyalty_luck_bonus)
	m.loyalty = 50
	b.luck = r.luck_loyalty_below - 1
	Loyalty.winter_drift(r, b, m, true, true, log)
	assert_eq(m.loyalty, 50 + r.loyalty_winter_rest - r.loyalty_luck_bonus)


func test_departures_leave_turn_and_grieve() -> void:
	var r := CampaignRules.new()
	var stole := 0
	var trials := 2000
	for t in trials:
		var b := _band(4)
		b.silver = 100
		var leaver := b.men[0]
		leaver.loyalty = r.loyalty_turn_below - 1
		leaver.origin = CampaignTypes.Origin.OUTLAW
		var homesick := b.men[1]
		homesick.loyalty = r.loyalty_leave_below - 1
		homesick.ambition = CampaignTypes.Ambition.HOME
		var brother := b.men[2]
		b.set_bond(leaver, brother, 80)
		b.set_bond_kind(leaver, brother, CampaignTypes.BondKind.OATH_BROTHER)
		var stayer := b.men[3]
		stayer.loyalty = r.loyalty_leave_below
		var log := PackedStringArray()
		var gone := Loyalty.departures(SimRng.new(t), r, b, log)
		if t == 0:
			assert_eq(gone.size(), 2)
			assert_true(gone.has(leaver) and gone.has(homesick))
			assert_true(not gone.has(stayer), "at the threshold he stays")
			assert_eq(brother.loyalty, 50 - r.bond_brother_left)
			assert_eq(b.men.size(), 4, "the caller removes leavers")
		if b.silver < 100:
			assert_eq(b.silver, 100 - r.turn_theft_ounces)
			stole += 1
	assert_between(float(stole) / trials, r.turn_chance - 0.05, r.turn_chance + 0.05, "turn chance")
	# A loyal-enough outlaw who is not below the turn line never steals.
	var b2 := _band(1)
	b2.men[0].loyalty = r.loyalty_turn_below
	b2.men[0].origin = CampaignTypes.Origin.OUTLAW
	b2.silver = 100
	for t in 200:
		Loyalty.departures(SimRng.new(t), r, b2, PackedStringArray())
	assert_eq(b2.silver, 100)


func test_seating_offense() -> void:
	var r := CampaignRules.new()
	var b := _band(3)
	var log := PackedStringArray()
	Loyalty.seating_offense(r, b, b.men[0], b.men[1], log)
	assert_eq(b.men[0].loyalty, 50 + r.loyalty_seating_honor)
	assert_eq(b.men[1].loyalty, 50 - r.loyalty_seating_passed)
	b.men[2].personality = [CombatTypes.Personality.BOASTFUL]
	Loyalty.seating_offense(r, b, b.men[0], b.men[2], log)
	assert_eq(b.men[2].loyalty, 50 - 2 * r.loyalty_seating_passed, "boastful men take it twice as hard")


# --- Gate ---------------------------------------------------------------------

## A band of ten varied men: random origins, one non-clashing personality or
## two, random ambitions, loyalty 20-70 (outlaws start low).
func _gate_band(rng: SimRng) -> Band:
	var b := Band.new()
	var lead := _man(100, "Harek", 100)
	lead.is_leader = true
	b.leader = lead
	b.luck = 5
	for i in 10:
		var m := _man(i + 1, "Man%d" % (i + 1))
		m.origin = rng.randi_range(0, CampaignTypes.Origin.size() - 1) as CampaignTypes.Origin
		m.ambition = rng.randi_range(0, CampaignTypes.Ambition.size() - 1) as CampaignTypes.Ambition
		m.loyalty = rng.randi_range(20, 70)
		if m.origin == CampaignTypes.Origin.OUTLAW:
			m.loyalty = rng.randi_range(20, 35)
		var p := rng.randi_range(0, CombatTypes.Personality.size() - 1) as CombatTypes.Personality
		m.personality = [p]
		b.add_man(m)
	return b


## Ten years: a summer's plunder shared at leader_share, four winter turns,
## the winter's bond drift, then departures at the thaw. Returns men lost.
func _run_years(seed_value: int, leader_share: float, fed: bool, seated: bool) -> int:
	var r := CampaignRules.new()
	var rng := SimRng.new(seed_value)
	var b := _gate_band(rng.fork("band"))
	var log := PackedStringArray()
	var lost := 0
	for year in 10:
		Loyalty.share_plunder(r, b, 90, leader_share, log)
		for turn in 4:
			for m in b.living_men():
				Loyalty.winter_drift(r, b, m, fed, seated, log)
		Bonds.winter_drift(rng, r, b, log)
		for m in Loyalty.departures(rng, r, b, log):
			b.remove_man(m)
			lost += 1
		b.year += 1
	return lost


func test_gate_fair_band_holds_unfed_band_scatters() -> void:
	var seeds := 300
	var fair_worst := 0
	var fair_total := 0
	var hard_total := 0
	var hard_fewest := 10
	for s in seeds:
		var fair := _run_years(s, 0.25, true, true)
		var hard := _run_years(s, 1.0, false, true)
		fair_worst = maxi(fair_worst, fair)
		fair_total += fair
		hard_total += hard
		hard_fewest = mini(hard_fewest, hard)
	assert_between(fair_worst, 0, 1, "fair shares and feasts lose at most one man")
	assert_between(float(hard_total) / seeds, 8.0, 10.0, "an unfed, unshared band loses most of its men")
	assert_between(hard_fewest, 6, 10, "every unfed band loses most of its men")
	print("    gate: fair band lost %.2f men on average (worst %d); unfed band lost %.2f (fewest %d)" % [
		float(fair_total) / seeds, fair_worst, float(hard_total) / seeds, hard_fewest])
