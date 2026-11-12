## Renders the game (title, ways, map) under a display and saves a
## screenshot. Usage:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 844x390 -s tools/screenshot_game.gd -- <out.png> [origin key|title|origins] [seed] [commands...]
## Commands, run in order on the journey before the shot: sail:<place> (go
## there), go:<place> (set the course only), days:<n>, act:<id>,
## answer:<id>, select:<place>, invest:<way>, silver:<oz>, zoom:<px>,
## quick (tell fights quickly), men, ways, families, chronicle, trade (what
## sells where and the men for hire), year:<way> (the stand-in player
## plays a year with that bent), rounds:<n> and leave (on the battle screen).
## The winter (WinterScreen): summer:<way> lets the stand-in player of that
## bent play on until the band goes into winter quarters; winter answers what waits and winters where
## the band stands, wstep:<n> goes to step n (0 the store .. 6 spring; past
## the hall's talk the winter is lived through), wchoose:<id> makes a
## choice by its id (Journey.winter_choose), wauto keeps the choices as
## they stand and begins the spring.
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
##
## The shell (docs/design/notes/shell.md): `settings` opens the settings
## over whatever screen is up (the title, the map, the battle); `man:<n>`
## opens the n-th man's card in Your men (0 is the leader); `large` turns
## on the large words, `safe` the colours for colour-blind eyes, `numbers`
## a man's numbers, before the next command; `scroll:<px>` scrolls the
## side panel down, `place:<px>` the place's list in the right-hand panel. `what` "settings" is the
## title with the settings open.
## Generations (docs/design/notes/generations.md): die kills the leader in
## battle (the death card), old:<age> sets his age, pick:<n> answers what
## waits with its n-th option (the grave-ale's steps), family gives him a
## wife of a friendly house and children (son:<age> one more son), strong
## makes the sworn second a champion (to dispute the high seat),
## years:<n> chooses the years to let pass at the spring step, saga opens
## the saga, ending ends it (the vengeance taken), totitle goes to the
## title after it, and totitle:read opens "Read the last saga" there;
## wscroll:<px> scrolls the winter screen before the shot.
extends SceneTree


## The shell's commands, on whatever screen is up. True when `cmd` was one.
func _shell(game: Node, cmd: String) -> bool:
	match cmd:
		"large":
			Settings.set_value("large_text", true)
			if game.map != null:
				game.show_map()
				await process_frame
			return true
		"safe":
			Settings.set_value("colour_safe", true)
			return true
		"numbers":
			Settings.set_value("show_numbers", true)
			return true
		"settings":
			var over: Control = game.screen
			var who: Node = game
			if game.battle_node != null and game.battle_node.hud != null:
				over = game.battle_node.hud.root_control
				who = game.battle_node.hud
			elif game.map != null:
				over = game.map
			Settings.open(over, who)
			return true
	if cmd.begins_with("scroll:") and game.map != null:
		# Down the side panel (a long card), by design pixels.
		await process_frame
		(game.map as MapScreen).side_panel.scroll.scroll_vertical = int(cmd.trim_prefix("scroll:"))
		return true
	if cmd.begins_with("place:") and game.map != null:
		# Down the place's list in the side panel (the market under the deeds).
		await process_frame
		((game.map as MapScreen).place_box.get_parent() as ScrollContainer).scroll_vertical = int(cmd.trim_prefix("place:"))
		return true
	if cmd.begins_with("man:") and game.map != null:
		var map: MapScreen = game.map
		var people := MenPanel.people(map.journey.c.band)
		var n := clampi(int(cmd.trim_prefix("man:")), 0, people.size() - 1)
		MenPanel.new(map).show_man(people[n])
		return true
	return false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "res://game.png"
	var what := args[1] if args.size() > 1 else "title"
	var seed_in := int(args[2]) if args.size() > 2 else 7
	var wscroll := -1  # wscroll:<px>: the winter screen scrolled before the shot
	var game: Node = load("res://view/game.tscn").instantiate()
	game.fixed_seed = true
	Settings.persist = false
	game.seed_in = seed_in
	game.use_config = false
	get_root().add_child(game)
	await process_frame
	if what == "settings":
		for i in range(3, args.size()):
			await _shell(game, args[i])
		game.show_title()
		await process_frame
		await _shell(game, "settings")
	elif what == "origins":
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
			if await _shell(game, cmd):
				await process_frame
				continue
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
			if await _shell(game, cmd):
				await process_frame
				map = game.map  # "large" builds the map again
				continue
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
			elif cmd == "trade":
				map._show_trade()
				continue
			elif cmd == "saga":
				map._show_saga()
				continue
			elif cmd == "die":
				j.c.band.leader.alive = false
				j.c.succession("battle")
				j._settle()
			elif cmd.begins_with("old:"):
				j.c.band.leader.age = int(cmd.trim_prefix("old:"))
			elif cmd.begins_with("pick:"):
				var d: Dictionary = j.current()
				if not d.is_empty():
					j.answer(str(d.options[mini(int(cmd.trim_prefix("pick:")), d.options.size() - 1)].id))
			elif cmd == "family":
				var fs := j.c.world.families
				var friend := ""
				for n in fs.names():
					if Families.is_friend(j.c.world_rules, j.c.band, n):
						friend = n
						break
				if friend != "" and j.c.band.wife == "":
					fs.marry_into(j.c.world_rules, j.c.rules, SimRng.new(1), j.c.band, friend, "Asgerd", PackedStringArray())
				var who := j.c.band.leader.display_name
				var y := j.c.cal.year
				j.c.band.sons.append({"name": "Thorstein", "born": y - 16, "alive": true, "daughter": false, "fostered_with": friend, "craft": 3, "father": who, "potential": [6, 5, 5, 6, 5]})
				j.c.band.sons.append({"name": "Ketil", "born": y - 12, "alive": true, "daughter": false, "fostered_with": "", "father": who, "potential": [5, 5, 6, 5, 5]})
				j.c.band.sons.append({"name": "Thordis", "born": y - 15, "alive": true, "daughter": true, "father": who})
				j.c.band.sons.append({"name": "Orm", "born": y - 3, "alive": true, "daughter": false, "fostered_with": "", "father": who, "potential": [5, 5, 5, 5, 5]})
			elif cmd.begins_with("son:"):
				j.c.band.sons.append({"name": "Hallbjorn", "born": j.c.cal.year - int(cmd.trim_prefix("son:")), "alive": true, "daughter": false,
						"fostered_with": "", "father": j.c.band.leader.display_name, "potential": [6, 6, 6, 6, 6]})
			elif cmd.begins_with("wscroll:"):
				wscroll = int(cmd.trim_prefix("wscroll:"))
				continue
			elif cmd == "strong":
				var sec := j.c.band.man_by_id(j.c.band.sworn_second_id)
				if sec != null:
					for k in 5:
						sec.stats[k] = 8
			elif cmd.begins_with("years:"):
				j.winter_choose("years:" + cmd.trim_prefix("years:"))
			elif cmd == "ending":
				j.end_saga("vengeance")
			elif cmd.begins_with("totitle"):
				game.remember_saga(j.saga())
				game.show_title()
				if cmd == "totitle:read":
					await process_frame
					game.show_last_saga()
				break
			elif cmd.begins_with("year:"):
				JourneyBot.play_year(j, int(cmd.trim_prefix("year:")))
				j.quick = false
				j.stepped_winter = true
			elif cmd.begins_with("summer:"):
				JourneyBot.play_year(j, int(cmd.trim_prefix("summer:")), true)
				j.quick = false
				j.stepped_winter = true
			elif cmd == "winter":
				j.quick = true
				while not j.decisions.is_empty():
					j.answer(str(j.current().options[0].id))
				j.quick = false
				j.act("winter")
			elif cmd.begins_with("wstep:"):
				var want := int(cmd.trim_prefix("wstep:"))
				var guard := 0
				while j.in_winter() and guard < 12 and int(j.winter_state().step) != want:
					guard += 1
					j.winter_choose("next" if int(j.winter_state().step) < want else "back")
			elif cmd.begins_with("wchoose:"):
				j.winter_choose(cmd.trim_prefix("wchoose:"))
				if not j.in_winter():
					for ch in map.get_children():
						if ch is WinterScreen:
							ch.queue_free()
			elif cmd == "wauto":
				j.winter_auto()
				for ch in map.get_children():
					if ch is WinterScreen:
						ch.queue_free()
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
	if wscroll >= 0 and game.map != null:
		for ch in game.map.get_children():
			if ch is WinterScreen:
				ch._scroll.scroll_vertical = wscroll
		await process_frame
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
