extends TestCase


func _band() -> Band:
	var b := Band.new()
	var l := Man.new()
	l.display_name = "Egil"
	l.is_leader = true
	b.leader = l
	return b


func _pot(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out


func test_marry_sets_wife_household_alliance() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	Family.marry(r, b, "Asgerd", _pot([4, 6, 5, 7, 8]), 3, "Ketil of Vik", log)
	assert_eq(b.wife, "Asgerd")
	assert_eq(b.household_skill, 3)
	assert_true(b.alliances.has("Ketil of Vik"))
	assert_eq(Family.wife_potential(b), _pot([4, 6, 5, 7, 8]))
	assert_eq(b.chronicle.size(), 1)
	var b2 := _band()
	Family.marry(r, b2, "Gudrun", _pot([5, 5, 5, 5, 5]), 99, "", log)
	assert_eq(b2.household_skill, r.household_skill_max, "household skill clamps")
	assert_eq(b2.alliances.size(), 0)


func test_no_births_unmarried() -> void:
	var r := CampaignRules.new()
	var b := _band()
	var log := PackedStringArray()
	var cal := Calendar.new(866)
	var rng := SimRng.new(1)
	for i in 200:
		Family.winter_births(rng, r, b, cal, log)
	assert_eq(b.sons.size(), 0)


func test_births_over_many_winters() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	Family.marry(r, b, "Asgerd", _pot([4, 6, 5, 7, 8]), 2, "", log)
	var cal := Calendar.new(866)
	var rng := SimRng.new(42)
	var n := 3000
	var sons_returned := 0
	for i in n:
		var born := Family.winter_births(rng, r, b, cal, log)
		sons_returned += born.size()
		assert_true(born.size() <= 1, "at most one child a winter")
		cal.next_year()
	var children := b.sons.size()
	assert_between(float(children) / n, r.birth_chance - 0.03, r.birth_chance + 0.03, "births at birth_chance")
	var daughters := 0
	for c in b.sons:
		if c.daughter:
			daughters += 1
			assert_true(not c.has("potential"))
		else:
			assert_eq(c.potential, _pot([4, 6, 5, 7, 8]), "a son keeps his mother's potential")
			assert_eq(c.fostered_with, "")
			assert_true(c.alive)
	assert_eq(sons_returned, children - daughters, "only sons are returned")
	assert_between(float(daughters) / children, r.daughter_chance - 0.05, r.daughter_chance + 0.05)


func test_fostering_and_sons_of_age() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	b.sons.append({"name": "Ketil", "born": 850, "potential": _pot([5, 5, 5, 5, 5]), "fostered_with": "", "alive": true, "daughter": false})
	b.sons.append({"name": "Sigurd", "born": 853, "potential": _pot([5, 5, 5, 5, 5]), "fostered_with": "", "alive": true, "daughter": false})
	b.sons.append({"name": "Helga", "born": 848, "alive": true, "daughter": true})
	var cal := Calendar.new(866)  # Ketil 16, Sigurd 13
	var of_age := Family.sons_of_age(r, b, cal)
	assert_eq(of_age.size(), 1)
	assert_eq(of_age[0].name, "Ketil")
	Family.foster_out(r, b, b.sons[0], "Jarl Hakon", log)
	assert_eq(b.sons[0].fostered_with, "Jarl Hakon")
	assert_eq(b.alliances.size(), 1, "fostering makes an alliance")
	assert_true(b.alliances[0].contains("Jarl Hakon"))
	r.foster_returns_at_age = 18
	assert_eq(Family.sons_of_age(r, b, cal).size(), 0, "a fostered son of 16 is away")
	cal = Calendar.new(868)  # Ketil 18, Sigurd 15
	of_age = Family.sons_of_age(r, b, cal)
	assert_eq(of_age.size(), 2)
	assert_eq(of_age[0].name, "Ketil", "eldest first")
	b.sons[0].alive = false
	of_age = Family.sons_of_age(r, b, cal)
	assert_eq(of_age.size(), 1)
	assert_eq(of_age[0].name, "Sigurd")
