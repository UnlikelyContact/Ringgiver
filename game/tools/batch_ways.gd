## Plays each way of life for some years with its stand-in player
## (JourneyBot) and reports what became of the men who lived it. Usage:
##   godot --headless --path game -s tools/batch_ways.gd -- [sagas] [years] [seed] [way|all] [origin] [log]
## Each bent's line is followed by one "by year" line: the sagas still
## going at the end of each year, the mean silver in hand, how many own a
## ship, how many have had their vengeance (the burned hall), and the
## fights fought that year, a saga. A "law-land" line after it: land held
## at the end (units, a saga), sagas outlawed (and of those, ended, and
## still outlaws at the end), sagas settled in Iceland, Thing cases,
## captives sold, thralls held, the mean honor (docs/design/notes/law-land.md).
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var years := int(args[1]) if args.size() > 1 else 5
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var only := args[3] if args.size() > 3 else "all"
	var verbose := args.size() > 5
	var origin := args[4] if args.size() > 4 else "younger_son"
	print("== %d sagas x %d years a bent, from the %s, seed %d" % [n, years, origin, seed_in])
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
		var shipped := 0
		var steps := 0
		var per_year := 0.0
		var ll := {"land": 0, "outlawed": 0, "outlaw_ended": 0, "outlaw_still": 0, "iceland": 0, "cases": 0, "sold": 0, "thralls": 0, "holders": 0}
		var y_alive: Array[int] = []
		var y_silver: Array[int] = []
		var y_ship: Array[int] = []
		var y_avenged: Array[int] = []
		var y_fights: Array[int] = []
		for k in years:
			y_alive.append(0)
			y_silver.append(0)
			y_ship.append(0)
			y_avenged.append(0)
			y_fights.append(0)
		for i in n:
			var j := Journey.begin(seed_in + i, origin, "Egil")
			var start: int = j.c.band.silver
			var y := 0
			var had_ship := false
			var fights_before := 0
			while y < years and not j.c.over:
				var before := j.c.cal.year
				JourneyBot.play_year(j, way)
				if not j.c.over:
					y_alive[y] += 1
				y_silver[y] += j.c.band.silver
				had_ship = had_ship or j.c.band.ship != null
				if had_ship:
					y_ship[y] += 1
				if j.c.band.vengeance == "" and origin == "burned_hall":
					y_avenged[y] += 1
				y_fights[y] += int(j.c.tally.battles) - fights_before
				fights_before = int(j.c.tally.battles)
				if j.c.cal.year == before and not j.c.over:
					stalls += 1
					if verbose:
						print("   STALL seed %d year %d day %d at %s: decisions %d fight %s moving %s wintering %s" % [
								seed_in + i, before, j.c.cal.day, j.whereabouts(), j.decisions.size(), not j.fight.is_empty(), j.roam.moving(), j.wintering])
						for line in j.said.slice(maxi(0, j.said.size() - 6)):
							print("      " + line)
					break
				y += 1
			if j.c.over:
				ended += 1
			lived += y
			var lb := j.c.band
			ll.land += lb.land
			ll.holders += 1 if lb.land > 0 else 0
			if lb.law.has("outlawed"):
				ll.outlawed += 1
				ll.outlaw_ended += 1 if j.c.over else 0
				ll.outlaw_still += 1 if Outlawry.is_outlawed(lb, j.c.cal) else 0
			ll.iceland += 1 if lb.settled_iceland else 0
			ll.cases += int(lb.law.get("cases", 0))
			ll.sold += int(lb.law.get("sold", 0))
			ll.thralls += lb.thralls.size()
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
			if band.ship != null:
				shipped += 1
			steps += Way.rank(band, way)
			per_year += float(band.silver - start) / maxf(1.0, y)
			if verbose and i == 0:
				for line in j.said.slice(maxi(0, j.said.size() - 25)):
					print("      " + line)
		print("%-13s ended %2d/%d  years %.1f  silver %5d (%+.0f a year)  men %.1f  fame %2d  honor %2d  own deeds %3d  steps %.1f  named %2d/%d  ship %2d/%d  fights %.1f  deaths %.1f  stalls %d" % [
				d.name, ended, n, float(lived) / n, silver / n, per_year / n, float(men) / n, fame / n, honor / n, own / n, float(steps) / n, named, n,
				shipped, n, float(fights) / n, float(deaths) / n, stalls])
		var cols := PackedStringArray()
		for k in years:
			cols.append("y%d alive %d silver %d ship %d avenged %d fights %.1f" % [k + 1, y_alive[k], y_silver[k] / n, y_ship[k], y_avenged[k], float(y_fights[k]) / n])
		print("   by year: " + " | ".join(cols))
		print("   law-land: land %.1f (%d of %d hold land)  outlawed %d (ended %d, outlaws at the end %d)  Iceland %d  cases %.1f  captives sold %.1f  thralls %.1f" % [
				float(ll.land) / n, int(ll.holders), n, int(ll.outlawed), int(ll.outlaw_ended), int(ll.outlaw_still), int(ll.iceland),
				float(ll.cases) / n, float(ll.sold) / n, float(ll.thralls) / n])
	quit(0)
