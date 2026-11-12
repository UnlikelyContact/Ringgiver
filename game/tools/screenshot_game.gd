## Renders the game (title, ways, map) under a display and saves a
## screenshot. Usage:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_game.gd -- <out.png> [way key|title|ways] [seed] [commands...]
## Commands, run in order on the journey before the shot: sail:<place>,
## act:<id>, answer:<id>, select:<place>, quick (tell fights quickly), men,
## year (the stand-in player plays a year).
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
	if what == "ways":
		game.show_ways()
	elif what != "title":
		var way := 0
		for w in Way.Id.values():
			if str(Way.def(w).key) == what:
				way = w
		game.begin_saga(way, "Egil")
		var j: Journey = game.journey
		for i in range(3, args.size()):
			var cmd := args[i]
			if cmd == "quick":
				j.quick = true
				game.map._quick = true
			elif cmd == "men":
				game.map._show_men()
			elif cmd == "year":
				JourneyBot.play_year(j)
				j.quick = false
			elif cmd.begins_with("sail:"):
				j.sail(cmd.trim_prefix("sail:"))
			elif cmd.begins_with("act:"):
				j.act(cmd.trim_prefix("act:"))
			elif cmd.begins_with("answer:"):
				j.answer(cmd.trim_prefix("answer:"))
			elif cmd.begins_with("select:"):
				game.map.selected = cmd.trim_prefix("select:")
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
			if game.map != null and not cmd == "men" and game.battle_node == null:
				game.map.selected = j.c.band.location if not cmd.begins_with("select:") else game.map.selected
				game.map.refresh()
	for i in 4:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("saved %s %dx%d" % [out, img.get_width(), img.get_height()])
	quit(0)
