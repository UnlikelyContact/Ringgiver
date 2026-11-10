extends SceneTree
## Renders the prototype under a display and saves a screenshot.
##
##   xvfb-run -a godot --path ring-giver/game --rendering-driver opengl3 -s tools/screenshot.gd -- [rounds] [out.png] [paused 0|1] [scenario] [seed] [template] [band]
##
## `template` forces the field's template (meadow, river, farmstead,
## wood_edge, hillside; "-" for the seed's own), `band` your band's size.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rounds := int(args[0]) if args.size() > 0 else 0
	var out := args[1] if args.size() > 1 else "res://shot.png"
	var paused := (args[2] == "1") if args.size() > 2 else true
	var scenario := args[3] if args.size() > 3 else "equal_green"
	var seed_in := int(args[4]) if args.size() > 4 else 7
	var scene = load("res://view/main.tscn").instantiate()
	scene.scenario = scenario
	if args.size() > 5 and args[5] != "-":
		scene.template = args[5]
	if args.size() > 6:
		scene.band = int(args[6])
	scene.seed_in = seed_in
	scene.fixed_seed = true
	get_root().add_child(scene)
	await process_frame
	var view: BattleView = scene.view
	view.anim_scale = 0.0
	view.pulse_seconds = 0.0
	if rounds > 0:
		view.pending_shout = CombatTypes.Shout.SHIELD_WALL
		view.auto_pause = false
	for i in rounds:
		view.step()
		if i == 1:
			view.pending_shout = CombatTypes.Shout.PUSH
	view.set_paused(paused)
	view.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("saved %s %dx%d after %d rounds" % [out, img.get_width(), img.get_height(), rounds])
	quit(0)
