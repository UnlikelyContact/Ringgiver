extends SceneTree
## Scripted playtest: drives the prototype like a player for N rounds,
## saves a screenshot per round and prints what happened.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1000x450 -s tools/playtest.gd -- <outdir> [seed]

const S := CombatTypes.Shout


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var outdir := args[0] if args.size() > 0 else "res://"
	var seed_in := int(args[1]) if args.size() > 1 else 11
	var scene = load("res://view/main.tscn").instantiate()
	scene.scenario = "equal_green"
	scene.seed_in = seed_in
	get_root().add_child(scene)
	await process_frame
	var view: BattleView = scene.view
	var b: Battle = scene.battle
	view.anim_scale = 0.0
	view.pulse_seconds = 0.0
	# The script: round -> what the player does before pressing Next round.
	var plan := {
		1: {"shout": S.SHIELD_WALL},
		2: {"shout": S.PUSH},
		3: {}, 4: {}, 5: {}, 6: {},
		7: {"shout": S.HOLD},
		8: {}, 9: {},
		10: {"shout": S.PUSH},
		11: {}, 12: {},
		13: {"wheel": 1},
		14: {"shout": S.SHIELD_WALL},
		15: {}, 16: {},
		17: {"shout": S.FALL_BACK},
		18: {}, 19: {},
		20: {"shout": S.PUSH},
		21: {}, 22: {},
	}
	for r in range(1, 23):
		var step: Dictionary = plan.get(r, {})
		if step.has("shout"):
			view.pending_shout = step.shout
		if step.has("wheel"):
			view.wheel(step.wheel)
		if step.has("advance"):
			view.advance()
		var before_log := b.log.size()
		view.step()
		await process_frame
		await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("%s/pt_%02d.png" % [outdir, r])
		var ours := view.wall_count(0)
		var theirs := view.wall_count(1)
		var our_rows := []
		for w in b.active(0):
			var o := BattleGrid.to_offset(w.pos)
			our_rows.append("%s@%d,%d%s" % [w.display_name.substr(0, 4), o.x, o.y, "" if not w.broken else "!"])
		print("R%02d order=%s wall %d/%d theirs %d/%d | %s" % [r, CombatTypes.SHOUT_NAMES[b.standing_order(0)], ours[0], ours[1], theirs[0], theirs[1], " ".join(our_rows)])
		for i in range(before_log, b.log.size()):
			var line := b.log[i]
			if line.begins_with("---") or line.begins_with("actions") or (line.contains("beats") and line.contains("glancing")):
				continue
			print("    " + line)
		if b.is_over():
			print("=== over: " + b.result.summary())
			break
	quit(0)
