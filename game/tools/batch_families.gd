## Plays each bent with its stand-in player (JourneyBot) and reports how
## the band stands with the houses after it: friends and foes made, feuds
## begun and ended, the vengeance taken, the houses' own tidings. Usage:
##   godot --headless --path game -s tools/batch_families.gd -- [sagas] [years] [seed] [origin]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 6
	var years := int(args[1]) if args.size() > 1 else 4
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var origin := args[3] if args.size() > 3 else "burned_hall"
	print("== houses: %d sagas x %d years a bent, from the %s, seed %d" % [n, years, origin, seed_in])
	for way in Way.Id.values():
		var friends := 0
		var foes := 0
		var blood := 0
		var feuds_open := 0
		var feuds_ended := 0
		var avenged := 0
		var married := 0
		var tidings := 0
		var house_feuds := 0
		var steps := {}
		for i in n:
			var j := Journey.begin(seed_in + i, origin, "Egil")
			var y := 0
			while y < years and not j.c.over:
				JourneyBot.play_year(j, way)
				y += 1
			var wr := j.c.world_rules
			var band := j.c.band
			var fs := j.c.world.families
			for name in band.standing:
				var v := int(band.standing[name])
				if v >= wr.standing_friend:
					friends += 1
				if v <= wr.standing_ill_wisher:
					foes += 1
				if v <= wr.standing_blood_enemy:
					blood += 1
				var st := Families.step_of(wr, band, name)
				steps[st] = int(steps.get(st, 0)) + 1
			feuds_open += band.unsettled_feuds().size()
			feuds_ended += band.feuds.size() - band.unsettled_feuds().size()
			if origin == "burned_hall" and band.vengeance == "":
				avenged += 1
			if band.wife != "":
				married += 1
			for yr in fs.tidings:
				tidings += (fs.tidings[yr] as PackedStringArray).size()
			for k in fs.pairs:
				if fs.pairs[k].enmity == "feud":
					house_feuds += 1
		var keys: Array = steps.keys()
		keys.sort()
		var spread := PackedStringArray()
		for k in keys:
			spread.append("%s %.1f" % [k, float(steps[k]) / n])
		print("%-13s friends %.1f  ill-wishers %.1f (blood %.1f)  feuds open %.1f ended %.1f  avenged %d/%d  married %d/%d  house feuds %.1f  tidings %.1f a year  | %s" % [
				Way.def(way).name, float(friends) / n, float(foes) / n, float(blood) / n, float(feuds_open) / n, float(feuds_ended) / n,
				avenged, n, married, n, float(house_feuds) / n, float(tidings) / (n * years), ", ".join(spread)])
	quit(0)
