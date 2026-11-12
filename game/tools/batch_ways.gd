## Plays each way of life for some years with its stand-in player
## (JourneyBot) and reports what became of the men who lived it. Usage:
##   godot --headless --path game -s tools/batch_ways.gd -- [sagas] [years] [seed] [way|all] [log]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var years := int(args[1]) if args.size() > 1 else 5
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var only := args[3] if args.size() > 3 else "all"
	var verbose := args.size() > 4
	print("== %d sagas x %d years a way, seed %d" % [n, years, seed_in])
	for way in Way.Id.values():
		var d := Way.def(way)
		if only != "all" and only != str(d.key):
			continue
		var ended := 0
		var lived := 0
		var silver := 0
		var men := 0
		var fame := 0
		var honor := 0
		var own := 0
		var named := 0
		var stalls := 0
		var fights := 0
		var deaths := 0
		var per_year := 0.0
		for i in n:
			var j := Journey.begin(seed_in + i, way, "Egil")
			var start: int = j.c.band.silver
			var y := 0
			while y < years and not j.c.over:
				var before := j.c.cal.year
				JourneyBot.play_year(j)
				if j.c.cal.year == before and not j.c.over:
					stalls += 1
					if verbose:
						print("   STALL seed %d year %d day %d at %s: decisions %d fight %s dest '%s' wintering %s" % [
								seed_in + i, before, j.c.cal.day, j.c.band.location, j.decisions.size(), not j.fight.is_empty(), j.destination, j.wintering])
						for line in j.said.slice(maxi(0, j.said.size() - 6)):
							print("      " + line)
					break
				y += 1
			if j.c.over:
				ended += 1
			lived += y
			var band := j.c.band
			silver += band.silver
			men += band.fighters().size()
			fame += band.fame
			honor += band.honor
			own += int(band.deeds.get(way, 0))
			fights += int(j.c.tally.battles)
			deaths += int(j.c.tally.deaths)
			if Way.renowned_for(band) == way:
				named += 1
			per_year += float(band.silver - start) / maxf(1.0, y)
			if verbose and i == 0:
				for line in j.said.slice(maxi(0, j.said.size() - 25)):
					print("      " + line)
		print("%-13s ended %2d/%d  years %.1f  silver %5d (%+.0f a year)  men %.1f  fame %2d  honor %2d  own deeds %3d  named for it %2d/%d  fights %.1f  deaths %.1f  stalls %d" % [
				d.name, ended, n, float(lived) / n, silver / n, per_year / n, float(men) / n, fame / n, honor / n, own / n, named, n,
				float(fights) / n, float(deaths) / n, stalls])
	quit(0)
