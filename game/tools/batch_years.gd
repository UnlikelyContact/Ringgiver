extends SceneTree
## Runs many seeded campaigns for a number of years and reports what became
## of the bands.
##
##   godot --headless --path ring-giver/game -s tools/batch_years.gd -- [campaigns] [years] [seed]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var years := int(args[1]) if args.size() > 1 else 10
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var totals := {}
	var overs := 0
	var men_end := 0
	var growth := 0
	var growth_n := 0
	var tiers := [0, 0, 0, 0]
	var sample := ""
	for i in n:
		var c := Campaign.new(seed_in + i)
		c.start(CampaignTypes.Origin.YOUNGER_SON, "Egil", 4)
		var start_stats := {}
		for m in c.band.men:
			start_stats[m.id] = m.total_stats()
		c.run_years(years)
		for k in c.tally:
			totals[k] = totals.get(k, 0) + c.tally[k]
		if c.over:
			overs += 1
		men_end += c.band.living_men().size()
		for m in c.band.living_men():
			tiers[m.tier] += 1
			if start_stats.has(m.id):
				growth += m.total_stats() - start_stats[m.id]
				growth_n += 1
		if i == 0:
			sample = c.summary() + "\n" + "\n".join(c.band.chronicle.slice(0, 12)) + "\n   battle log:\n" + "\n".join(c.log.slice(0, 8))
	print("== %d campaigns x %d years, seed %d" % [n, years, seed_in])
	print("   ended early (no heir): %d   mean men at end %.1f" % [overs, float(men_end) / n])
	var line := "   per campaign:"
	for k in totals:
		line += " %s %.1f" % [k, float(totals[k]) / n]
	print(line)
	print("   original men still serving: %d, mean stat growth %.1f points" % [growth_n, (float(growth) / growth_n) if growth_n > 0 else 0.0])
	print("   tiers at end: green %d blooded %d veteran %d champion %d" % tiers)
	print("   sample campaign:\n" + sample)
	quit(0)
