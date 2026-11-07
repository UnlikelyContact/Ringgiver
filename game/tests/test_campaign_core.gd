extends TestCase


func test_calendar_turns() -> void:
	var c := Calendar.new(870)
	assert_true(not c.is_winter())
	c.advance_turn()
	assert_true(c.is_winter())
	assert_eq(c.winter_turn, CampaignTypes.WinterTurn.EARLY)
	c.advance_turn()
	c.advance_turn()
	c.advance_turn()
	assert_eq(c.winter_turn, CampaignTypes.WinterTurn.THAW)
	c.advance_turn()
	assert_eq(c.year, 871)
	assert_true(not c.is_winter())


func test_man_to_warrior_preserves_identity_and_gear() -> void:
	var m := Man.new()
	m.id = 7
	m.display_name = "Egil"
	m.stats = [6, 5, 4, 3, 2]
	m.tier = CombatTypes.Tier.VETERAN
	m.armor = CombatTypes.Armor.MAIL
	m.personality = [CombatTypes.Personality.GRIM]
	var w := m.to_warrior(0)
	assert_eq(w.id, 7)
	assert_eq(w.might, 6)
	assert_eq(w.wits, 2)
	assert_eq(w.tier, CombatTypes.Tier.VETERAN)
	assert_eq(w.armor, CombatTypes.Armor.MAIL)
	assert_true(w.has_shield)
	assert_true(w.personality.has(CombatTypes.Personality.GRIM))
	m.maims.append(CampaignTypes.Maim.LOST_HAND)
	assert_true(not m.to_warrior(0).has_shield, "a lost hand means no shield")


func test_band_ids_bonds_feuds() -> void:
	var b := Band.new()
	var a := Man.new()
	var c := Man.new()
	b.add_man(a)
	b.add_man(c)
	assert_eq(a.id, 1)
	assert_eq(c.id, 2)
	assert_eq(b.bond(a, c), 0)
	b.add_bond(c, a, 30)
	assert_eq(b.bond(a, c), 30, "bonds are symmetric")
	b.set_bond(a, c, 500)
	assert_eq(b.bond(a, c), 100, "clamped")
	assert_true(b.add_feud("Thorir", "Egil slain"))
	assert_true(not b.add_feud("Thorir", "again"), "no duplicate unsettled feud")
	assert_eq(b.unsettled_feuds().size(), 1)
	b.feuds[0].settled = true
	assert_true(b.add_feud("Thorir", "renewed"))
	b.log("a thing happened")
	assert_true(b.chronicle[0].begins_with("866: "))
	assert_eq(b.man_by_id(2), c)
