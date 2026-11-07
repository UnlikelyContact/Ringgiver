extends SceneTree
## Runs seeded sandbox campaigns on the map of Norway and reports what the
## bands did and what became of the kingdoms.
##
##   timeout 900 godot --headless --path ring-giver/game -s tools/batch_sandbox.gd -- [campaigns] [years] [seed]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 10
	var years := int(args[1]) if args.size() > 1 else 10
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var totals := {}
	var overs := 0
	var men_end := 0
	var silver_end := 0
	var harald_holdings := 0
	var ranks := [0, 0, 0, 0, 0, 0]
	var sample := ""
	for i in n:
		var c := Campaign.new(seed_in + i)
		c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 4)
		Sandbox.setup(c, WorldRules.new(), "hardanger")
		c.run_years(years)
		for k in c.tally:
			totals[k] = totals.get(k, 0) + c.tally[k]
		if c.over:
			overs += 1
		men_end += c.band.living_men().size()
		silver_end += c.band.silver
		ranks[c.band.rank] += 1
		if c.world.factions.has("harald"):
			harald_holdings += c.world.factions["harald"].holdings.size()
		if i == 0:
			sample = c.summary() + "\n" + "\n".join(c.log.slice(0, 14)) + "\n   world:\n" + "\n".join(c.world.chronicle.slice(0, 8))
	print("== %d sandbox campaigns x %d years, seed %d" % [n, years, seed_in])
	print("   ended early: %d   mean men %.1f   mean silver %.0f oz   Harald holds %.1f places" % [overs, float(men_end) / n, float(silver_end) / n, float(harald_holdings) / n])
	var line := "   per campaign:"
	for k in totals:
		line += " %s %.1f" % [k, float(totals[k]) / n]
	print(line)
	print("   ranks: thrall %d freedman %d karl %d hersir %d jarl %d king %d" % ranks)
	print("   sample:\n" + sample)
	quit(0)
