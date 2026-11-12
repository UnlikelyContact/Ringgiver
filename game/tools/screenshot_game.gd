## Renders the game (title, ways, map) under a display and saves a
## screenshot. Usage:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_game.gd -- <out.png> [origin key|title|origins] [seed] [commands...]
## Commands, run in order on the journey before the shot: sail:<place> (go
## there), go:<place> (set the course only), days:<n>, act:<id>,
## answer:<id>, select:<place>, invest:<way>, silver:<oz>, zoom:<px>,
## quick (tell fights quickly), men, ways, families, chronicle, year:<way> (the stand-in player
## plays a year with that bent), rounds:<n> and leave (on the battle screen).
##
## The opening (docs/design/notes/tutorial.md): `what` "begin" is the name
## screen, "night:<n>" the night's card n, "escape" the burned hall's fight
## as a first-timer meets it (taught), "skip" the escape told by the dice.
## On the escape's battle screen: tut:<n> does what the tutorial asks, n
## times (Go on, a shout, Next round, Withdraw), tutto:<step> until the
## tutorial reaches that step (Tutorial.Step, 0-6), hurt (the first of your
## men takes a bruise, to show the wound step), and leave (Go on from the
## result panel, to the map). On the map: hintok dismisses the hint on the
## card, learned opens the "?" list, seen:<id,id> marks hints as read;
## map goes on from the told escape's card (after "skip") to the map.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "res://game.png"
	var what := args[1] if args.size() > 1 else "title"
	var seed_in := int(args[2]) if args.size() > 2 else 7
	var game: Node = load("res://view/game.tscn").instantiate()
	game.fixed_seed = true
	game.seed_in = seed_in
	game.use_config = false
	get_root().add_child(game)
	await process_frame
	if what == "origins":
		game.show_origins()
	elif what == "begin":
		game.show_name()
	elif what.begins_with("night:"):
		game.show_night("Egil", int(what.trim_prefix("night:")))
	elif what == "escape" or what == "skip":
		game.begin_escape("Egil", what == "skip")
		await process_frame
		for i in range(3, args.size()):
			var cmd := args[i]
			if game.battle_node != null:
				var hud = game.battle_node.hud
				var view: BattleView = game.battle_node.view
				view.anim_scale = 0.0
				view.auto_pause = false
				var tut: Tutorial = hud.tutorial
				if cmd.begins_with("tut:") or cmd.begins_with("tutto:"):
					var n := int(cmd.split(":")[1])
					var acts := 0
					while tut != null and acts < 80 and not view.battle.is_over():
						if cmd.begins_with("tut:") and acts >= n:
							break
						if cmd.begins_with("tutto:") and int(tut.step) >= n:
							break
						var want := tut.control()
						if want == "ack":
							tut.acknowledge()
							tut._show()
						elif want.begins_with("shout:"):
							hud._on_shout(int(want.trim_prefix("shout:")))
						elif want == "next":
							view.step()
						elif want == "withdraw":
							hud._on_withdraw()
						else:
							break
						acts += 1
					await process_frame
				elif cmd == "hurt":
					# The first of your men takes a bruise, so the wound step
					# can be seen on any seed.
					for w in view.battle.side_warriors(0):
						if not w.is_leader:
							w.wound = CombatTypes.Wound.BRUISED
							break
					view.step()
				elif cmd == "leave":
					game.leave_battle()
					await process_frame
				continue
			if cmd == "map" and game.map == null:
				game.show_map()  # Go on from the told escape's card
				await process_frame
				continue
			var mj: Journey = game.journey
			var mm: MapScreen = game.map
			if mm == null:
				continue
			mm.paused = true
			if cmd == "hintok":
				game.hints.dismiss()
				game.hints.check()
			elif cmd == "learned":
				game.hints._show_list()
			elif cmd.begins_with("answer:"):
				mj.answer(cmd.trim_prefix("answer:"))
				mm.refresh()
				game.hints.check()
			elif cmd.begins_with("act:"):
				mj.act(cmd.trim_prefix("act:"))
				mm.refresh()
				game.hints.check()
			elif cmd.begins_with("days:"):
				mj.advance(float(cmd.trim_prefix("days:")))
				mm.refresh()
				game.hints.check()
			elif cmd.begins_with("go:"):
				mj.go_to_place(cmd.trim_prefix("go:"))
				mm.refresh()
				game.hints.check()
			elif cmd.begins_with("invest:"):
				mj.invest(int(cmd.trim_prefix("invest:")))
				mm.refresh()
			elif cmd == "ways":
				mm._show_ways()
			elif cmd.begins_with("seen:"):
				for id in cmd.trim_prefix("seen:").split(","):
					game.hints.seen[id] = true
				game.hints.showing = ""
				game.hints.check()
			await process_frame
	elif what != "title":
		game.begin_saga(what, "Egil")
		var j: Journey = game.journey
		var map: MapScreen = game.map
		map.paused = true  # the tool moves the band itself
		for i in range(3, args.size()):
			var cmd := args[i]
			if cmd == "quick":
				j.quick = true
				map._quick = true
			elif cmd == "men":
				map._show_men()
				continue
			elif cmd == "ways":
				map._show_ways()
				continue
			elif cmd == "families":
				map._show_families()
				continue
			elif cmd == "chronicle":
				map._show_chronicle()
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
	if game.battle_node != null and game.battle_node.camera != null:
		# The camera eases toward the men; a still shows where it settles.
		var bn = game.battle_node
		var z: float = bn.fit_zoom()
		bn.camera.zoom = Vector2(z, z)
		bn.camera.position = bn.focus_point(z)
		await process_frame
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("saved %s %dx%d" % [out, img.get_width(), img.get_height()])
	quit(0)
