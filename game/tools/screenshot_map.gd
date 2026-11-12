## The map's own screenshot tool: tools/screenshot_game.gd with a few
## more commands for looking at the overworld's art (MapCanvas, MapArt).
## Usage:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_map.gd -- <out.png> [origin key] [seed] [commands...]
## Besides those of screenshot_game.gd: mincrew (any ship sails with the
## band's few men), goto:<x>:<y> (set the course for a point in leagues),
## foe:<kind>:<dx>:<dy>[:chase] (a party of that kind that far from the band),
## tag (show the last party's tag), knowall (the band knows every place),
## day:<n> (the summer's day, for the season's tint), cam:<x>:<y> (look
## there, not at the band; give it last), nofollow, perf (print the frame
## and the canvas's own drawing time over 60 frames).
## Commands, run in order on the journey before the shot: sail:<place> (go
## there), go:<place> (set the course only), days:<n>, act:<id>,
## answer:<id>, select:<place>, invest:<way>, silver:<oz>, zoom:<px>,
## quick (tell fights quickly), men, ways, year:<way> (the stand-in player
## plays a year with that bent), rounds:<n> and leave (on the battle screen).
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "res://game.png"
	var what := args[1] if args.size() > 1 else "title"
	var seed_in := int(args[2]) if args.size() > 2 else 7
	var game: Node = load("res://view/game.tscn").instantiate()
	game.fixed_seed = true
	game.seed_in = seed_in
	get_root().add_child(game)
	await process_frame
	if what == "origins":
		game.show_origins()
	elif what != "title":
		game.begin_saga(what, "Egil")
		var j: Journey = game.journey
		var map: MapScreen = game.map
		map.paused = true  # the tool moves the band itself
		for i in range(3, args.size()):
			var cmd := args[i]
			if cmd == "mincrew":
				for kk in j.c.world_rules.ship_min_crew:
					j.c.world_rules.ship_min_crew[kk] = 1
				continue
			elif cmd.begins_with("foe:"):
				var f := cmd.split(":")
				var p := Roam.Party.new()
				p.kind = f[1]
				p.name = f[1]
				p.men = 9
				p.sails = f[1] != "outlaws"
				p.pos = j.roam.pos + Vector2(float(f[2]), float(f[3]))
				p.chasing = f.size() > 4
				j.roam.parties.append(p)
				map.canvas.queue_redraw()
				continue
			elif cmd == "tag":
				map.canvas._tagged = j.roam.parties[j.roam.parties.size() - 1]
				continue
			elif cmd.begins_with("cam:"):
				var f := cmd.split(":")
				map.canvas.follow = false
				map.canvas.centre_on(Vector2(float(f[1]), float(f[2])))
				continue
			elif cmd.begins_with("goto:"):
				var f := cmd.split(":")
				print("goto ", j.go_to_point(Vector2(float(f[1]), float(f[2]))))
			elif cmd == "knowall":
				for id in j.c.world.places:
					j.c.band.known_places[id] = true
				continue
			elif cmd.begins_with("day:"):
				j.c.cal.day = int(cmd.trim_prefix("day:"))
				continue
			elif cmd == "nofollow":
				map.canvas.follow = false
				continue
			elif cmd == "perf":
				for n in 30:
					await process_frame
				var t0 := Time.get_ticks_usec()
				var acc := 0
				var acc_static := 0
				for n in 60:
					map.canvas.queue_redraw()
					map.canvas._places.queue_redraw()
					await process_frame
					acc += map.canvas.draw_usec
					acc_static += map.canvas.static_usec
				print("PERF frame %.2f ms, canvas _draw %.3f ms, places layer %.3f ms, art build %.1f ms" % [(Time.get_ticks_usec() - t0) / 60000.0, acc / 60000.0, acc_static / 60000.0, MapArt.for_grid(j.roam.grid).build_usec / 1000.0])
				continue
			elif cmd == "quick":
				j.quick = true
				map._quick = true
			elif cmd == "men":
				map._show_men()
				continue
			elif cmd == "ways":
				map._show_ways()
				continue
			elif cmd.begins_with("year:"):
				JourneyBot.play_year(j, int(cmd.trim_prefix("year:")))
				j.quick = false
			elif cmd.begins_with("invest:"):
				j.invest(int(cmd.trim_prefix("invest:")))
			elif cmd.begins_with("silver:"):
				j.c.band.silver = int(cmd.trim_prefix("silver:"))
			elif cmd.begins_with("sail:"):
				j.sail(cmd.trim_prefix("sail:"))
			elif cmd.begins_with("go:"):
				j.go_to_place(cmd.trim_prefix("go:"))
			elif cmd.begins_with("days:"):
				j.advance(float(cmd.trim_prefix("days:")))
			elif cmd.begins_with("zoom:"):
				map.canvas.zoom = float(cmd.trim_prefix("zoom:"))
			elif cmd.begins_with("act:"):
				j.act(cmd.trim_prefix("act:"))
			elif cmd.begins_with("answer:"):
				j.answer(cmd.trim_prefix("answer:"))
			elif cmd.begins_with("select:"):
				map.selected = cmd.trim_prefix("select:")
				map.refresh()
				continue
			elif cmd.begins_with("rounds:") and game.battle_node != null:
				# Fight the battle on screen: shield wall, then push.
				await process_frame
				var view: BattleView = game.battle_node.view
				view.anim_scale = 0.0
				view.pulse_seconds = 0.0
				view.auto_pause = false
				view.pending_shout = CombatTypes.Shout.SHIELD_WALL
				for r in int(cmd.trim_prefix("rounds:")):
					view.step()
					if r == 1:
						view.pending_shout = CombatTypes.Shout.PUSH
				continue
			elif cmd == "leave" and game.battle_node != null:
				game.leave_battle()
				continue
			if game.battle_node == null:
				map.selected = j.c.band.location
				map.canvas.centre_on(j.roam.pos)
				map.refresh()
	for i in 4:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("saved %s %dx%d" % [out, img.get_width(), img.get_height()])
	quit(0)
