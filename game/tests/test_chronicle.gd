extends TestCase


func _band() -> Band:
	var b := Band.new()
	var l := Man.new()
	l.display_name = "Egil"
	l.is_leader = true
	b.leader = l
	return b


func test_line_and_year_lines() -> void:
	var b := _band()
	b.year = 866
	Chronicle.line(b, "Egil took ship")
	b.year = 867
	Chronicle.line(b, "the hall was built")
	Chronicle.line(b, "Thorir was slain")
	b.chronicle.append("8670: not a real year")
	assert_eq(b.chronicle[0], "866: Egil took ship")
	assert_eq(Chronicle.year_lines(b, 866).size(), 1)
	assert_eq(Chronicle.year_lines(b, 867), PackedStringArray(["867: the hall was built", "867: Thorir was slain"]))
	assert_eq(Chronicle.year_lines(b, 868).size(), 0)


func test_generation_text_names_leader_and_ends_with_death() -> void:
	var r := CampaignRules.new()
	var b := _band()
	b.year = 866
	Chronicle.line(b, "Egil took ship for the west")
	b.year = 868
	Chronicle.line(b, "Egil burned Thorir's hall")
	for cause in ["battle", "old", "outlaw", "sickness"]:
		var text := Chronicle.generation_text(b, "Egil", 866, 869, cause, r)
		assert_true(text.length() > 80, "a real paragraph")
		assert_true(text.contains("Egil"), "names the leader")
		assert_true(text.contains("burned Thorir's hall"))
		assert_true(text.contains("867"), "quiet years get a line")
		assert_true(text.ends_with(str(r.death_lines[cause])), "ends with the %s death line" % cause)
		assert_true(not text.contains("\n"))


func test_generation_text_uses_recorded_death() -> void:
	var r := CampaignRules.new()
	var log := PackedStringArray()
	var b := _band()
	b.year = 870
	Chronicle.line(b, "Egil fought at the ford")
	var heir := Man.new()
	heir.display_name = "Ketil"
	heir.id = b.next_id()
	Succession.succeed(SimRng.new(1), r, b, Calendar.new(870), heir, 0, "", log, "outlaw")
	var text := Chronicle.generation_text(b, "Egil", 868, 870)
	assert_true(text.begins_with("This is the saga of Egil"))
	assert_true(text.ends_with(str(r.death_lines["outlaw"])))
