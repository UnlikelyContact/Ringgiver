## What the saga's fights came to over the stand-in players' years
## (docs/design/notes/saga-fights.md): fights by the field they were fought
## on, prizes taken, burnings, hall fights, and how often the leader hung
## back. Usage:
##   godot --headless --path game -s tools/diag_saga_tally.gd -- [sagas] [years] [seed] [way] [origin]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 4
	var years := int(args[1]) if args.size() > 1 else 4
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var way_name := args[3] if args.size() > 3 else "viking"
	var origin := args[4] if args.size() > 4 else "burned_hall"
	var ways := {"viking": Way.Id.VIKING, "trader": Way.Id.TRADER, "lawman": Way.Id.LAWMAN, "berserk": Way.Id.BERSERK,
			"skald": Way.Id.SKALD, "kings_man": Way.Id.KINGS_MAN}
	var way: int = ways.get(way_name, Way.Id.VIKING)
	var tally := {}
	var hung := 0
	var lucky := 0
	for i in n:
		var j := Journey.begin(seed_in + i, origin, "Egil")
		var y := 0
		while y < years and not j.c.over:
			JourneyBot.play_year(j, way)
			y += 1
		for k in ["prizes", "burnings", "hall_fights", "battles", "wins"]:
			tally[k] = int(tally.get(k, 0)) + int(j.c.tally.get(k, 0))
		for line in j.c.log:
			if line.contains("hung back from the shield-wall"):
				hung += 1
		lucky += j.c.band.luck
	print("%s from %s, %d sagas x %d years: %s, leader hung back %d times, mean luck at the end %.1f" % [
			way_name, origin, n, years, str(tally), hung, float(lucky) / n])
	quit()
