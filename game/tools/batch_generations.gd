## Plays long sagas with the stand-in player (JourneyBot), the years let
## pass at each spring, and reports how far the sagas get: the year
## reached, the generations, the deaths, how they ended. With a second
## run at let_years 0 on the same seeds it measures whether sitting at home
## out-earns playing (silver per calendar year). Usage:
##   godot --headless --path game -s tools/batch_generations.gd -- [sagas] [calendar years] [seed] [let_years] [way] [origin] [verbose]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 3
	var span := int(args[1]) if args.size() > 1 else 25
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var let := int(args[3]) if args.size() > 3 else 3
	var way_key := args[4] if args.size() > 4 else "viking"
	var origin := args[5] if args.size() > 5 else "burned_hall"
	var verbose := args.size() > 6
	var way := Way.Id.VIKING
	for w in Way.Id.values():
		if str(Way.def(w).key) == way_key:
			way = w
	print("== %d sagas x %d years, seed %d, %s from the %s" % [n, span, seed_in, way_key, origin])
	for years in ([let, 0] if let > 0 else [0]):
		JourneyBot.let_years = years
		var reached := 0
		var gens := 0
		var stalls := 0
		var silver_rate := 0.0
		var passed := 0
		for i in n:
			var j := Journey.begin(seed_in + i, origin, "Egil")
			var start := j.c.cal.year
			var silver0 := j.c.band.silver
			var guard := 0
			var samples := PackedStringArray()
			while not j.c.over and j.c.cal.year < start + span and guard < span + 5:
				guard += 1
				var before := j.c.cal.year
				JourneyBot.play_year(j, way)
				if (j.c.cal.year - start) % 5 == 0:
					samples.append("%d: %d men, %d oz, luck %d, land %d%s%s" % [j.c.cal.year, j.c.band.living_men().size(), j.c.band.silver, j.c.band.luck,
							j.c.band.land, ", Iceland" if j.c.band.settled_iceland else "", ", outlaw" if Outlawry.is_outlawed(j.c.band, j.c.cal) else ""])
				if j.c.cal.year == before and not j.c.over:
					stalls += 1
					print("   STALL seed %d year %d day %d: decisions %d (%s) fight %s winter %s" % [seed_in + i, before, j.c.cal.day,
							j.decisions.size(), str(j.current().get("kind", "")) + ":" + str(j.current().get("step", "")), not j.fight.is_empty(), j.in_winter()])
					break
			var chs := Chronicle.chapters(j.c.band)
			var ending: Dictionary = j.c.band.get_meta(Chronicle.ENDING_META, {}) if j.c.band.has_meta(Chronicle.ENDING_META) else {}
			var lived := maxi(1, j.c.cal.year - start)
			silver_rate += float(j.c.band.silver - silver0) / lived
			passed += int(j.c.tally.get("years_passed", 0))
			reached += j.c.cal.year
			gens += chs.size()
			var names := PackedStringArray()
			for ch in chs:
				names.append("%s %d-%d (%s)" % [str(ch.name), int(ch.from), int(ch.to), str(ch.cause) if str(ch.cause) != "" else "living"])
			print("  seed %d let %d: reached %d, %d generations, %d years let pass, silver %d (%+.0f a year), men %d, %s%s" % [
					seed_in + i, years, j.c.cal.year, chs.size(), int(j.c.tally.get("years_passed", 0)), j.c.band.silver,
					float(j.c.band.silver - silver0) / lived, j.c.band.living_men().size(),
					("ENDED " + str(ending.get("kind", j.c.over_reason))) if j.c.over else "going on", ""])
			print("      " + "; ".join(names) + "   stops " + str(j.c.tally.get("years_stops", {})))
			print("      by five years: " + " | ".join(samples))
			if verbose:
				print(j.saga().text)
		print("let %d: mean year reached %.1f, generations %.1f, years let pass %.1f, silver %+.0f a year, stalls %d" % [
				years, float(reached) / n, float(gens) / n, float(passed) / n, silver_rate / n, stalls])
	quit(0)
