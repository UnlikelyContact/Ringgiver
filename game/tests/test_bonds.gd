extends TestCase


func _man(id: int, name: String, traits: Array[CombatTypes.Personality] = []) -> Man:
	var m := Man.new()
	m.id = id
	m.display_name = name
	m.personality = traits
	m.ambition = CampaignTypes.Ambition.SILVER
	return m


func _band(men: Array[Man]) -> Band:
	var b := Band.new()
	for m in men:
		b.add_man(m)
	return b


func test_after_battle_bonds_and_oath() -> void:
	var r := CampaignRules.new()
	var a := _man(1, "Egil")
	var c := _man(2, "Ulf")
	var d := _man(3, "Bjorn")
	var b := _band([a, c, d])
	var log := PackedStringArray()
	var survivors: Array[Man] = [a, c]
	var fallen: Array[Man] = [d]
	Bonds.after_battle(r, b, survivors, fallen, log)
	assert_eq(b.bond(a, c), r.bond_fought_together)
	assert_eq(b.bond(a, d), 0, "the fallen gain nothing")
	b.set_bond(a, c, r.bond_oath_threshold - 1)
	Bonds.after_battle(r, b, survivors, [] as Array[Man], log)
	assert_eq(b.bond_kind(a, c), CampaignTypes.BondKind.OATH_BROTHER)
	var lines := b.chronicle.size()
	Bonds.after_battle(r, b, survivors, [] as Array[Man], log)
	assert_eq(b.chronicle.size(), lines, "oath-brotherhood is sworn once")
	assert_eq(Bonds.oath_brothers(b, a), [c] as Array[Man])
	# Grief: Ulf falls; Egil, his oath brother, loses loyalty, Bjorn does not.
	var survivors2: Array[Man] = [a, d]
	var fallen2: Array[Man] = [c]
	Bonds.after_battle(r, b, survivors2, fallen2, log)
	assert_eq(a.loyalty, 50 - r.loyalty_grief)
	assert_eq(d.loyalty, 50)


func test_rival_threshold() -> void:
	var r := CampaignRules.new()
	var a := _man(1, "Egil")
	var c := _man(2, "Ulf")
	var b := _band([a, c])
	b.set_bond(a, c, r.bond_rival_threshold - 5)
	Bonds.update_kind(r, b, a, c, PackedStringArray())
	assert_eq(b.bond_kind(a, c), CampaignTypes.BondKind.RIVAL)
	assert_eq(Bonds.rivals(b, c), [a] as Array[Man])
	assert_eq(Bonds.oath_brothers(b, c).size(), 0)


func test_winter_drift_clash_kin_quarrel() -> void:
	var r := CampaignRules.new()
	var reck := _man(1, "Hrafn", [CombatTypes.Personality.RECKLESS] as Array[CombatTypes.Personality])
	var stead := _man(2, "Kol", [CombatTypes.Personality.STEADY] as Array[CombatTypes.Personality])
	reck.origin = CampaignTypes.Origin.FISHERMAN
	stead.origin = CampaignTypes.Origin.OUTLAW
	var kin1 := _man(3, "Ari")
	var kin2 := _man(4, "Oddr")
	kin1.origin = CampaignTypes.Origin.FREEDMAN
	kin2.origin = CampaignTypes.Origin.FREEDMAN
	var quarrels := 0
	var trials := 3000
	for t in trials:
		var b := _band([reck, stead, kin1, kin2])
		Bonds.winter_drift(SimRng.new(t), r, b, PackedStringArray())
		var v := b.bond(reck, stead)
		if v == -r.bond_clash_drift - r.bond_quarrel:
			quarrels += 1
		else:
			assert_eq(v, -r.bond_clash_drift)
		assert_eq(b.bond(kin1, kin2), r.bond_kin_drift)
		assert_eq(b.bond(reck, kin1), 0)
	assert_between(float(quarrels) / trials, r.quarrel_chance - 0.03, r.quarrel_chance + 0.03)
	var boast := _man(5, "Thorkel", [CombatTypes.Personality.BOASTFUL] as Array[CombatTypes.Personality])
	var grim := _man(6, "Grim", [CombatTypes.Personality.GRIM] as Array[CombatTypes.Personality])
	boast.origin = CampaignTypes.Origin.OUTLAW
	grim.origin = CampaignTypes.Origin.FISHERMAN
	var b2 := _band([boast, grim])
	Bonds.winter_drift(SimRng.new(1), r, b2, PackedStringArray())
	assert_eq(b2.bond(boast, grim), -r.bond_clash_drift, "boastful and grim clash, no quarrel")


func test_on_death_feud_and_vengeance() -> void:
	var r := CampaignRules.new()
	var dead := _man(1, "Egil")
	var b1 := _man(2, "Ulf")
	var b2 := _man(3, "Bjorn")
	var other := _man(4, "Ari")
	b2.ambition = CampaignTypes.Ambition.FAME
	var b := _band([dead, b1, b2, other])
	b.year = 870
	b.set_bond_kind(dead, b1, CampaignTypes.BondKind.OATH_BROTHER)
	b.set_bond_kind(dead, b2, CampaignTypes.BondKind.OATH_BROTHER)
	b1.ambition_progress = 40
	var log := PackedStringArray()
	Bonds.on_death(r, b, dead, "Thorir Hound", log)
	assert_eq(b.feuds.size(), 1, "one feud for both brothers")
	assert_eq(b.feuds[0].against, "Thorir Hound")
	assert_eq(b.feuds[0].cause, "Egil slain")
	assert_eq(b.feuds[0].year, 870)
	assert_eq(b.feuds[0].settled, false)
	assert_eq(b1.ambition, CampaignTypes.Ambition.VENGEANCE)
	assert_eq(b1.ambition_progress, 0)
	assert_eq(b2.ambition, CampaignTypes.Ambition.FAME, "fame is kept")
	assert_eq(other.ambition, CampaignTypes.Ambition.SILVER)
	# A second death at the same hand opens no second feud.
	b.set_bond_kind(other, b1, CampaignTypes.BondKind.OATH_BROTHER)
	Bonds.on_death(r, b, other, "Thorir Hound", log)
	assert_eq(b.feuds.size(), 1)
	# No oath brothers, no feud.
	var lonely := _man(9, "Lonely")
	b.add_man(lonely)
	Bonds.on_death(r, b, lonely, "Someone Else", log)
	assert_eq(b.feuds.size(), 1)


# --- Gate ---------------------------------------------------------------------

## Two men in a band of their own over ten years: a summer fight together,
## then the winter drift. Returns true when they end as rivals.
func _pair_ends_rivals(seed_value: int, first: CombatTypes.Personality, second: CombatTypes.Personality) -> bool:
	var r := CampaignRules.new()
	var rng := SimRng.new(seed_value)
	var a := _man(1, "A", [first] as Array[CombatTypes.Personality])
	var c := _man(2, "B", [second] as Array[CombatTypes.Personality])
	a.origin = CampaignTypes.Origin.FISHERMAN
	c.origin = CampaignTypes.Origin.YOUNGER_SON
	var b := _band([a, c])
	var log := PackedStringArray()
	var both: Array[Man] = [a, c]
	for year in 10:
		Bonds.after_battle(r, b, both, [] as Array[Man], log)
		Bonds.winter_drift(rng, r, b, log)
	return b.bond_kind(a, c) == CampaignTypes.BondKind.RIVAL


func test_gate_reckless_and_steady_become_rivals() -> void:
	var seeds := 1000
	var mixed := 0
	var steady := 0
	for s in seeds:
		if _pair_ends_rivals(s, CombatTypes.Personality.RECKLESS, CombatTypes.Personality.STEADY):
			mixed += 1
		if _pair_ends_rivals(s, CombatTypes.Personality.STEADY, CombatTypes.Personality.STEADY):
			steady += 1
	var mixed_rate := float(mixed) / seeds
	var steady_rate := float(steady) / seeds
	assert_between(mixed_rate, 0.3, 1.0, "reckless and steady men often end as rivals")
	assert_between(steady_rate, 0.0, 0.05, "two steady men rarely do")
	assert_true(mixed_rate > steady_rate + 0.25, "mixed %.2f vs steady %.2f" % [mixed_rate, steady_rate])
	print("    gate: reckless/steady rivals %.2f, steady/steady rivals %.2f" % [mixed_rate, steady_rate])
