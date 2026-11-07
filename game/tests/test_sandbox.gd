extends TestCase
## Milestone 3 gate: a sandbox campaign on the map of Norway runs for years
## without error and replays exactly; the band sails, raids, trades or takes
## contracts; Harald's conquest unfolds; letting the years pass stops on
## what matters.


func _campaign(seed_in: int, years := 0) -> Campaign:
	var c := Campaign.new(seed_in)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 4)
	Sandbox.setup(c, WorldRules.new(), "hardanger")
	if years > 0:
		c.run_years(years)
	return c


func test_sandbox_years_run_and_replay_exactly() -> void:
	var a := _campaign(21, 4)
	var b := _campaign(21, 4)
	assert_eq(a.summary(), b.summary())
	assert_eq(a.log.size(), b.log.size())
	for i in mini(a.log.size(), b.log.size()):
		if a.log[i] != b.log[i]:
			fail("log diverges at %d: %s | %s" % [i, a.log[i], b.log[i]])
			break
	assert_eq(a.world.chronicle.size(), b.world.chronicle.size())
	assert_true(a.world.place(a.band.location) != null, "the band is always somewhere real")


func test_band_acts_on_the_map() -> void:
	var c := _campaign(22, 3)
	var sailed := 0
	for line in c.log:
		if line.contains("sails from"):
			sailed += 1
	assert_true(sailed >= 3, "the band sailed %d times" % sailed)
	assert_true(c.tally.get("raids", 0) + c.tally.get("contracts", 0) >= 1, "it raided or took a contract")
	assert_true(c.band.known_places.size() > 6, "it learned the map: %d places" % c.band.known_places.size())


func test_harald_expands_without_the_player() -> void:
	var c := _campaign(23, 10)
	var harald: Faction = c.world.factions["harald"]
	assert_true(harald.holdings.size() >= 6, "Harald holds %d places by %d" % [harald.holdings.size(), c.cal.year])
	assert_true(c.tally.get("spine", 0) >= 3, "spine events fired: %d" % c.tally.get("spine", 0))


func test_pass_years_stops_for_the_spine() -> void:
	var c := _campaign(24)
	var log := PackedStringArray()
	var stops := Sandbox.pass_years(c, 5, log)
	assert_true(stops.size() == 1 and stops[0].begins_with("spine:"), "stopped for %s" % str(stops))
	assert_eq(c.cal.year, 866, "the first spine year is never skipped")
	c.world.timeline_state["harald_vow"] = true
	c.run_year()
	var stops2 := Sandbox.pass_years(c, 1, log)
	assert_true(stops2.is_empty() or stops2[0].begins_with("spine:") or stops2[0] == "feud" or stops2[0] == "son_of_age",
			"a year passes or stops for a listed reason: %s" % str(stops2))


func test_feud_demand_can_be_answered_at_the_thing() -> void:
	var c := _campaign(31)
	c.band.silver = 120
	c.band.location = "fitjar"
	c.band.known_places["gulathing"] = true
	c.band.add_feud("Augvald's kin", "raid on Avaldsnes", "avaldsnes")
	var log := PackedStringArray()
	var went := Sandbox.go_to_thing(c, c.rng.fork("t"), "Augvald's kin", WorldTypes.CaseKind.RAID, false, log)
	assert_true(went, "the band went to the Gulathing")
	assert_eq(c.band.location, "gulathing")
	assert_eq(c.tally.get("thing_cases", 0), 1)
	var f := Feud.find(c.band, "Augvald's kin")
	assert_true(f.is_empty() or f.settled or c.band.feuds[0].get("verdict", "") == "" , "a verdict settles the feud or the matter went to the sword")


func test_outlaw_emigrates_to_iceland_when_it_is_open() -> void:
	var c := _campaign(32)
	c.cal.year = 876
	c.world.year = 876
	c.band.year = 876
	c.band.location = "avaldsnes"
	c.band.known_places["orkney"] = true
	c.band.known_places["iceland"] = true
	c.band.outlawry = WorldTypes.Outlawry.FULL
	c.band.add_feud("Augvald's kin", "raid on Avaldsnes", "avaldsnes")
	var log := PackedStringArray()
	var wr := c.world_rules
	wr.wreck_chance = 0.0
	wr.encounter_chance = 0.0
	wr.storm_chance = 0.0
	var went := Sandbox._consider_emigration(c, c.rng.fork("e"), log)
	assert_true(went, "an outlaw with Iceland known sails for it")
	assert_eq(c.band.home, "iceland")
	assert_eq(c.band.outlawry, WorldTypes.Outlawry.NONE, "Norwegian law does not reach Iceland")
	assert_true(c.band.unsettled_feuds().is_empty())
	assert_true(c.band.land >= wr.iceland_land_claim)
