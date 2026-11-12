## One stand-in saga told in full, for reading what a bent does with its
## summers. Usage:
##   godot --headless --path game -s tools/diag_saga.gd -- [seed] [way key] [origin] [years] [grep]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_in := int(args[0]) if args.size() > 0 else 1
	var key := args[1] if args.size() > 1 else "viking"
	var origin := args[2] if args.size() > 2 else "burned_hall"
	var years := int(args[3]) if args.size() > 3 else 2
	var only := args[4] if args.size() > 4 else ""
	var way := 0
	for w in Way.Id.values():
		if str(Way.def(w).key) == key:
			way = w
	var j := Journey.begin(seed_in, origin, "Egil")
	var shown := 0
	for y in years:
		if j.c.over:
			break
		var t0 := Time.get_ticks_msec()
		j.quick = true
		var year := j.c.cal.year
		var steps := 0
		while not j.c.over and j.c.cal.year == year and steps < 900:
			steps += 1
			var before := "%d %s %s" % [j.c.cal.day, j.c.band.location, j.roam.pos]
			if not j.decisions.is_empty():
				j.answer(JourneyBot._answer(j, j.current(), way))
			elif not j.can_act():
				break
			elif j.roam.moving():
				j.travel()
			else:
				JourneyBot._spend(j, way)
				JourneyBot._act(j, way)
			for i in range(shown, j.said.size()):
				if only == "" or j.said[i].contains(only):
					print("  [%d %s %d oz] %s" % [j.c.cal.day, j.c.band.location, j.c.band.silver, j.said[i]])
			if shown == j.said.size() and only == "":
				print("  [%d %s %d oz] (%s)" % [j.c.cal.day, j.c.band.location, j.c.band.silver, before])
			shown = j.said.size()
		print("== end of year %d: silver %d, men %d, ship %s, fame %d, honor %d, vengeance '%s' (%d ms)" % [y + 1, j.c.band.silver,
				j.c.band.fighters().size(), WorldTypes.SHIP_NAMES[j.c.band.ship.kind] if j.c.band.ship != null else "none",
				j.c.band.fame, j.c.band.honor, j.c.band.vengeance, Time.get_ticks_msec() - t0])
	quit(0)
