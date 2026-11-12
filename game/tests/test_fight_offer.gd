extends TestCase
## The choice before the fight (concept.md, "Picking your fights"): the
## scout's report, the offer's options, and what each answer does.


func _campaign(seed_in := 11) -> Campaign:
	var c := Campaign.new(seed_in)
	c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 9)
	return c


func test_the_scout_counts_truer_with_wits_and_seasoning() -> void:
	var r := CampaignRules.new()
	assert_eq(Scouting.error(r, 1, CombatTypes.Tier.GREEN), r.scout_error, "a dull green scout is out by the most")
	assert_eq(Scouting.error(r, 5, CombatTypes.Tier.GREEN), r.scout_error - 4 * r.scout_error_per_wits)
	assert_true(Scouting.error(r, 2, CombatTypes.Tier.VETERAN) < Scouting.error(r, 2, CombatTypes.Tier.GREEN), "a seasoned one truer still")
	var o := FightOffer.new()
	o.enemy_size = 10
	o.enemy_shields = 7
	o.enemy_spears = 2
	o.enemy_bows = 1
	o.enemy_leader = "Asgrim the leader"
	o.doctrine = LeaderAI.Doctrine.CUNNING
	var rep := Scouting.report(SimRng.new(3), r, 1, CombatTypes.Tier.GREEN, o)
	assert_true(rep.men_low <= 10 and rep.men_high >= 10, "the truth lies in the range: %d-%d" % [rep.men_low, rep.men_high])
	assert_true(rep.men_high - rep.men_low == 2 * r.scout_error, "as wide as twice the error")
	assert_eq(rep.leader, "", "a dull scout does not name the leader")
	var sharp := Scouting.report(SimRng.new(3), r, 5, CombatTypes.Tier.VETERAN, o)
	assert_true(sharp.leader.begins_with("Asgrim"), "a sharp one does")
	assert_true(sharp.leader.contains("cunning"), "and a seasoned one knows his manner")
	assert_true(sharp.text.contains("spears behind and a few bows"), sharp.text)


func test_the_offer_knows_its_options() -> void:
	var o := FightOffer.new()
	var C := FightOffer.Choice
	o.attacking = true
	assert_eq(o.options(), [C.TAKE_THE_FIELD, C.FADE_AWAY] as Array[int], "your own attack: take it or leave it")
	o.attacking = false
	assert_eq(o.options(), [C.TAKE_THE_FIELD, C.WAIT_FOR_THEM, C.FADE_AWAY] as Array[int], "they come to you: you may choose the ground")
	o.we_know_first = true
	assert_true(o.allows(C.LAY_AMBUSH), "the scout saw them first: an ambush")
	o.at_sea = true
	assert_true(not o.allows(C.LAY_AMBUSH) and not o.allows(C.WAIT_FOR_THEM), "no ground at sea")
	o.at_sea = false
	o.cornered = true
	assert_true(not o.allows(C.FADE_AWAY), "cornered: no fading away")
	o.cornered = false
	o.they_know_first = true
	assert_true(o.options().is_empty(), "caught on the march: no choice")
	assert_eq(o.scenario_for(C.TAKE_THE_FIELD), "ambushed")
	o.they_know_first = false
	assert_eq(o.scenario_for(C.LAY_AMBUSH), "ambush")
	assert_eq(o.scenario_for(C.WAIT_FOR_THEM), "hold")
	assert_eq(o.scenario_for(C.TAKE_THE_FIELD), "equal_green")


func test_fading_away_costs_honor_not_luck_and_no_blood() -> void:
	var c := _campaign()
	var men := c.band.fighters().size()
	var honor := c.band.honor
	var luck := c.band.luck
	var o := c.offer_fight("outlaws", CombatTypes.Tier.GREEN, men, false)
	assert_true(o.report.has("text") and o.report.text.begins_with("Your scout counts"), o.report.get("text", ""))
	var res := c.resolve_offer(o, FightOffer.Choice.FADE_AWAY)
	assert_true(res == null, "no fight")
	assert_eq(c.band.fighters().size(), men, "nobody hurt")
	assert_eq(c.band.luck, luck, "no luck lost")
	assert_eq(c.band.honor, honor - c.rules.honor_withdrew, "honor lost")
	assert_eq(c.tally.faded, 1)
	# From a fight at long odds there is no shame in it.
	var o2 := c.offer_fight("levy", CombatTypes.Tier.GREEN, men * 2, false)
	c.resolve_offer(o2, FightOffer.Choice.FADE_AWAY)
	assert_eq(c.band.honor, honor - c.rules.honor_withdrew, "twice their number: no honor lost for leaving")


func test_each_answer_builds_its_fight() -> void:
	var c := _campaign()
	var o := c.offer_fight("feud_ambush", CombatTypes.Tier.GREEN, 10, false)
	o.we_know_first = true
	o.they_know_first = false
	c.debug_battles = true
	var res := c.resolve_offer(o, FightOffer.Choice.LAY_AMBUSH)
	assert_true(res != null)
	var surprised := false
	for line in c.battle_logs[0]:
		if line.contains("taken by surprise"):
			surprised = true
	assert_true(surprised, "an ambush laid: their men are taken by surprise")
	var c2 := _campaign(12)
	var o2 := c2.offer_fight("feud_ambush", CombatTypes.Tier.GREEN, 10, false)
	o2.we_know_first = false
	o2.they_know_first = true
	c2.debug_battles = true
	c2.resolve_offer(o2, FightOffer.Choice.FADE_AWAY)  # no choice: it is their ambush
	var caught := false
	for line in c2.battle_logs[0]:
		if line.contains("taken by surprise"):
			caught = true
	assert_true(caught, "caught on the march: your men are taken by surprise")
	var c3 := _campaign(13)
	var o3 := c3.offer_fight("outlaws", CombatTypes.Tier.GREEN, 10, false)
	o3.we_know_first = false
	o3.they_know_first = false
	c3.debug_battles = true
	c3.resolve_offer(o3, FightOffer.Choice.WAIT_FOR_THEM)
	var ford := false
	for line in c3.battle_logs[0]:
		if line.contains("the ford"):
			ford = true
	assert_true(ford, "waiting for them: the fight is at the ford")


func test_the_sandbox_picks_like_a_careful_leader() -> void:
	var c := _campaign(21)
	var wr := WorldRules.new()
	Sandbox.setup(c, wr, "hardanger")
	var o := c.offer_fight("outlaws", CombatTypes.Tier.GREEN, 10, false)
	o.we_know_first = true
	o.they_know_first = false
	assert_eq(c.fight_policy.call(o), FightOffer.Choice.LAY_AMBUSH, "an ambush when he can")
	o.we_know_first = false
	assert_eq(c.fight_policy.call(o), FightOffer.Choice.WAIT_FOR_THEM, "his own ground when they come to him")
	o.attacking = true
	o.report.men_low = o.our_men * 3
	o.report.men_high = o.our_men * 3
	assert_eq(c.fight_policy.call(o), FightOffer.Choice.FADE_AWAY, "fades from a fight he cannot win")
	o.report.men_low = o.our_men
	o.report.men_high = o.our_men
	assert_eq(c.fight_policy.call(o), FightOffer.Choice.TAKE_THE_FIELD, "and takes the field when he can")
