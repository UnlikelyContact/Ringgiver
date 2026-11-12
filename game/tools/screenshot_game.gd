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
## they stand and begins the spring. wfeud:<feud_attack|hall_burning>:<meet|bar|wait>
## puts a house's men at the hall first in the talk (the fight goes to the
## battle screen when the winter is lived through); addmen:<n> gives the
## band n more men; on the battle screen, lose breaks every man of yours.
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
			elif cmd == "trade":
				map._show_trade()
				continue
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
			elif cmd.begins_with("wfeud:"):
				# A house's men at the hall tonight (saga-fights.md): the card
				# put first in the hall's talk, with the leader's choice.
				var parts := cmd.split(":")
				if j.winter_hall != null:
					var card := WinterEvents.card(SimRng.new(5), j.c.rules, j.c.band, parts[1])
					if not card.is_empty():
						WinterHall._hall_fight_card(j.c, SimRng.new(6), card)
						card.choice = parts[2] if parts.size() > 2 else "meet"
						j.winter_hall.talk.insert(0, card)
			elif cmd.begins_with("addmen:"):
				for k in int(cmd.trim_prefix("addmen:")):
					j.c.band.add_man(Recruits.random(SimRng.new(900 + k), j.c.rules, j.c.band.next_id()))
				j.c._arm_new_men()
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
			elif cmd == "lose" and game.battle_node != null:
				# Your men's hearts all go at once: the fight is lost this round.
				await process_frame
				var lv: BattleView = game.battle_node.view
				lv.anim_scale = 0.0
				lv.auto_pause = false
				for w in lv.battle.side_warriors(0):
					w.broken = true
					w.morale = 0
				lv.step()
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
