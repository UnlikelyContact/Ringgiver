## The save, checked the long way (docs/design/notes/save.md): plays sagas
## with the stand-in player to each save point, saves, loads into a new
## graph, plays the original and the copy on, and prints where they went
## apart, by path; then the sizes and the times of saving. Usage:
##   godot --headless --path game -s tools/save_check.gd -- [seeds] [origins|all] [bents|all] [points|all] [years] [sizes]
## e.g. `-- 5 all all all 1` (the whole matrix), `-- 2 younger_son viking
## winter:2,battle 2`, `-- 0 - - - 0 sizes` (the sizes alone). Lists are
## comma-separated; points are SavePlay.POINTS. A line per check:
##   OK   younger_son viking seed 3 sea              (digest)
##   DIFF burned_hall lawman seed 1 winter:2         then the paths
##   --   freedman trader seed 2 battle             never came to it
## A DIFF names the first paths that differ ("root.c.band.men[2].loyalty:
## 51 / 52"): the field is state the codec does not carry, or carries
## inexactly. "at save" means the copy differs before anything was played
## (the codec itself); "after" that it went apart in the playing (state
## not saved at all, like a static or a cache that changes what happens);
## "told" that the saga's words went apart while the encodings did not.
extends SceneTree

const ORIGINS := ["younger_son", "burned_hall", "freedman"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 2
	var origins := _list(args[1] if args.size() > 1 else "all", ORIGINS)
	var bent_keys := []
	for w in Way.Id.values():
		bent_keys.append(str(Way.def(w).key))
	var bents := _list(args[2] if args.size() > 2 else "all", bent_keys)
	var points := _list(args[3] if args.size() > 3 else "all", SavePlay.POINTS)
	var years := int(args[4]) if args.size() > 4 else 1
	var sizes := args.size() > 5 and args[5] == "sizes"
	var ok := 0
	var bad := 0
	var never := 0
	var t0 := Time.get_ticks_msec()
	if seeds > 0:
		for origin in origins:
			for bk in bents:
				var bent := bent_keys.find(bk)
				for s in range(1, seeds + 1):
					for point in points:
						var j := SavePlay.reach(s, origin, bent, point)
						if j == null:
							never += 1
							print("--   %s %s seed %d %s" % [origin, bk, s, point])
							SavePlay.reset_bot()
							continue
						var r := SavePlay.continue_check(j, bent, years)
						SavePlay.reset_bot()
						if r.ok:
							ok += 1
							print("OK   %s %s seed %d %-12s %s" % [origin, bk, s, point, str(r.digest).left(12)])
						else:
							bad += 1
							print("DIFF %s %s seed %d %s" % [origin, bk, s, point])
							for what in ["at_save", "after", "told"]:
								for line in r[what]:
									print("       %s  %s" % [what, line])
						var rep: Dictionary = r.report
						if int(rep.get("mismatched", 0)) + int(rep.get("unknown_classes", 0)) + int(rep.get("unknown_props", 0)) > 0:
							print("       decode report %s" % str(rep))
		print("== %d OK, %d DIFF, %d never came to the point, in %.0f s" % [ok, bad, never, (Time.get_ticks_msec() - t0) / 1000.0])
	if sizes or seeds == 0:
		_sizes()
	quit(1 if bad > 0 else 0)


func _list(arg: String, all: Array) -> Array:
	if arg == "all" or arg == "-":
		return all
	return Array(arg.split(","))


## The bytes and the times of a save of a saga after 1, 10 and 30 years.
func _sizes() -> void:
	SaveStore.dir = "user://save_check/"
	var j := Journey.begin(4, "younger_son", "Egil")
	var played := 0
	for target in [1, 10, 30]:
		while played < target and not j.c.over:
			SavePlay.play_years(j, Way.Id.VIKING, 1)
			played += 1
		var text := JSON.stringify(SaveCodec.encode(j), "", false)
		var best_enc := 1 << 30
		var best_write := 1 << 30
		for i in 3:
			var err := SaveStore.write(SaveStore.AUTO, j, {})
			assert(err == "")
			best_enc = mini(best_enc, int(SaveStore.last_usec.encode))
			best_write = mini(best_write, int(SaveStore.last_usec.write))
		var t := Time.get_ticks_usec()
		var back := SaveStore.read(SaveStore.AUTO)
		var load_ms := (Time.get_ticks_usec() - t) / 1000.0
		var file := FileAccess.get_file_as_bytes(SaveStore.path_of(SaveStore.AUTO)).size()
		var said := 0
		for line in j.said:
			said += line.length() + 1
		print("year %2d (%d, over %s): %d objects, json %d bytes (said %d lines, %d bytes), file %d bytes; encode+pack %.1f ms, write %.1f ms, read+decode %.1f ms, same %s" % [
				played, j.c.cal.year, j.c.over, SaveCodec.encode(j).objects.size(), text.length(), j.said.size(), said, file,
				best_enc / 1000.0, best_write / 1000.0, load_ms, SaveCodec.digest(back.journey) == SaveCodec.digest(j)])
		if j.c.over:
			break
	SaveStore.remove(SaveStore.AUTO)
	SaveStore.remove(SaveStore.BACKUP)
