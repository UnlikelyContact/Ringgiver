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
## The first fight (docs/design/notes/first-fight.md), on the escape's
## battle screen: tut:<n> and tutto:<step> also tap the hex or man the
## banner marks; skipfight presses Skip the fight; ref opens the "?" card
## of the shouts; apart sends one of your men two or three hexes off (To Me);
## through carries the band past the ring (Withdraw), chaser puts one of
## them at your heels (Fall Back); down
## fells your man (carried out); rescue and cap end it by the saga's
## rescue or the round cap; ui:<model>:<n> plays n presses of a stand-in
## player (tests/escape_players.gd) through the HUD's own buttons and the
## board's tap, and prints any press the banner asked for that the HUD
## would not take. On the map: offer puts a fight offer up (the offer's
## hint), fightnow starts a fight with raiders on the battle screen, and
## there bhint:<id> brings battle hint <id> (Hints.BATTLE_ORDER) to the card.
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
## Law, land and the unfree (docs/design/notes/law-land.md): at:<place>
## (the band is there, with nothing to answer), setyear:<y>, men:<n>,
## knarr, feud:<house> (a killing to plead), standoff and verdict:<ratio>
## (the case in hand weighed so, and that step shown), outlaw:full|lesser,
## hunters (they are out, near the band), land:<place>:<units>,
## thralls:<n>, captives:<n>:<place> (the captives' decision after a raid
## there), omen:<id> (raven, stumble, dream, fetch, eagle), seer (one comes
## to the hall at winter), landmodal (your land and household).
## The save (docs/design/notes/save.md; the tool's saves go to
## user://shot_saves/, never the player's): on the map, `save` writes the
## autosave, `save:<slot>` a slot (slot1..slot3), `load` saves and loads the
## autosave into a new map (as Continue does), `sagas` opens the Sagas modal
## over the map, `paste` its "Paste a save". `what` "continue" is the title with a saga to continue
## (a year played by the stand-in viking, saved, a slot kept too), "sagas"
## that title with the Sagas modal open, "confirm" that title asking
## before a new saga is begun.
extends SceneTree


## The save's commands on the map. True when `cmd` was one.
func _save_cmd(game: Node, cmd: String) -> bool:
	if cmd == "save" or cmd.begins_with("save:"):
		game.save_now(cmd.trim_prefix("save:") if cmd.begins_with("save:") else SaveStore.AUTO)
		return true
	if cmd == "load":
		game.save_now()
		var err: String = game.load_saga(SaveStore.AUTO)
		if err != "":
			push_error("load: " + err)
		await process_frame
		if game.map != null:
			game.map.paused = true
		return true
	if cmd == "sagas" or cmd == "paste":
		var m := SavesModal.open(game.map if game.map != null else game.screen, game)
		if cmd == "paste":
			SavesModal._paste(m, game)
		return true
	return false


## The title with a saga in the autosave (and slot one), for "continue",
## "sagas" and "confirm".
func _title_with_save(game: Node, what: String) -> void:
	for slot in [SaveStore.AUTO, SaveStore.BACKUP] + SaveStore.SLOTS:
		SaveStore.remove(slot)
	game.begin_saga("younger_son", "Egil")
	JourneyBot.play_year(game.journey, Way.Id.VIKING)
	game.journey.quick = false
	game.save_now(SaveStore.AUTO)
	game.save_now("slot1")
	game.show_title()
	await process_frame
	if what == "sagas":
		SavesModal.open(game.screen, game)
	elif what == "confirm":
		game._ask_before_new(game.show_name)


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
			if who.has_method("_open_settings"):
				who._open_settings()  # the battle's own gear (the first fight's skip)
			else:
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
	SaveStore.dir = "user://shot_saves/"
	get_root().add_child(game)
	await process_frame
	# Saving on, into the tool's own directory, only for the save's shots:
	# the others look as they always did.
	var saving := what in ["continue", "sagas", "confirm"]
	for i in range(3, args.size()):
		saving = saving or args[i] in ["load", "sagas", "paste"] or args[i].begins_with("save")
	game.autosave_on = saving
	if what == "continue" or what == "sagas" or what == "confirm":
		await _title_with_save(game, what)
	elif what == "settings":
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
						elif want == "tap" and tut.point != BattleGrid.NO_CELL:
							view._tap(Iso.to_screen(tut.point))
						else:
							break
						acts += 1
						await _settle_view(view)
					await process_frame
				elif cmd == "skipfight":
					hud.skip_fight()
				elif cmd == "ref":
					hud._show_reference()
				elif cmd == "apart":
					var b0 := view.battle
					var lw0: Warrior = b0.sworn_leader(0)
					for w in b0.side_warriors(0):
						if w != lw0 and w.is_active():
							# Two or three hexes off, with none of them at his arm's length.
							for row in b0.grid.height:
								var done := false
								for col in b0.grid.width:
									var to := BattleGrid.from_offset(col, row)
									if b0.grid.is_free(to) and BattleGrid.chebyshev(to, lw0.pos) >= 2 and BattleGrid.chebyshev(to, lw0.pos) <= 3 and b0.grid.adjacent_warriors(to, 1).is_empty():
										b0.grid.remove(w)
										b0.grid.place(w, to)
										done = true
										break
								if done:
									break
							break
					view._compute_tighten()
					for w in view.tokens:
						(view.tokens[w] as Token).position = view._spot(w, w.pos)
					tut.evaluate()
					tut._show()
				elif cmd == "through":
					var b1 := view.battle
					var col := 5
					for w in b1.side_warriors(0):
						if w.is_active():
							b1.grid.remove(w)
							b1.grid.place(w, BattleGrid.from_offset(col, 3))
							col += 1
					for w in b1.side_warriors(1):
						if w.is_active() and b1.objective.dark_distance(w.pos) <= 3:
							b1.grid.remove(w)
							w.fled = true
					view._compute_tighten()
					for w in view.tokens:
						(view.tokens[w] as Token).position = view._spot(w, w.pos)
						(view.tokens[w] as Token).visible = not w.fled
					tut.evaluate()
					tut._show()
				elif cmd == "chaser":
					# One of them at your heels, below you: the way open but not
					# out of reach (Fall Back).
					var b2 := view.battle
					var lw2: Warrior = b2.sworn_leader(0)
					for w in b2.side_warriors(1):
						if w.is_active() and not w.broken:
							for c in b2.grid.neighbors(lw2.pos):
								if b2.grid.is_free(c) and b2.objective.dark_distance(c) > b2.objective.dark_distance(lw2.pos):
									b2.grid.remove(w)
									b2.grid.place(w, c)
									(view.tokens[w] as Token).position = view._spot(w, c)
									break
							break
					tut.evaluate()
					tut._show()
				elif cmd == "down":
					view.battle.sworn_leader(0).wound = CombatTypes.Wound.DOWN
					view.step()
					await _settle_view(view)
				elif cmd == "rescue":
					view.battle._first_fight_rescue(view.battle.sworn_leader(0))
					hud._on_finished(view.battle.result)
				elif cmd == "cap":
					view.battle.round = view.battle.rules.escape_round_cap - 1
					view.battle._ff_ordered = true
					view.step()
					await _settle_view(view)
				elif cmd.begins_with("ui:"):
					await _drive_ui(hud, view, cmd.split(":")[1], int(cmd.split(":")[2]))
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
		for slot in [SaveStore.AUTO, SaveStore.BACKUP]:
			SaveStore.remove(slot)
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
			if await _save_cmd(game, cmd):
				await process_frame
				map = game.map  # "load" builds the map again
				j = game.journey
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
			elif _law_land(j, map, cmd):
				if cmd == "landmodal":
					continue
			elif _battles_2(j, cmd):
				# Battles 2's fights (docs/design/notes/battles-2.md): a
				# decision or a fight now waits; show it.
				map.refresh()
				for k in 3:
					await process_frame
				continue
			elif cmd == "offer" or cmd == "fightnow":
				# Raiders come down on the band: the offer (and its hint), or
				# straight onto the battle screen.
				j._offer_fight("raiders", CombatTypes.Tier.GREEN, maxi(4, j.c.band.fighters().size() + 2), false, 3, false, false,
						{"kind": "world_fight", "what": "raiders"}, "Raiders come down on you out of the hills.", true)
				map.refresh()
				for k in 3:
					await process_frame
				game.hints.check()
				if cmd == "fightnow":
					j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
					map.refresh()
					await process_frame
				continue
			elif cmd.begins_with("bhint:") and game.battle_node != null:
				var bh: BattleHints = game.battle_node.hud.battle_hints
				var want_id := cmd.trim_prefix("bhint:")
				for id in Hints.BATTLE_ORDER:
					if id == want_id:
						break
					game.hints.seen[id] = true
				bh.showing = want_id
				bh.check()
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



## Battles 2's commands (docs/design/notes/battles-2.md): `wings` names a
## second and gives the band men enough for a wing, then raiders come and
## the fight goes to the battle screen (the named men's sheet up);
## `strand:<place>` puts the band at that farmstead and offers the
## strandhogg (`strandnow:<place>` goes straight to its battle screen);
## `mercy` rings the vengeance's hall for the burning and asks before the
## fire (a burned-hall saga); `hafrsfjord` (for Harald) and
## `hafrsfjord:against` put the great battle on the battle screen. True
## when `cmd` was one.
func _battles_2(j: Journey, cmd: String) -> bool:
	if cmd == "wings":
		j.decisions.clear()
		while j.c.band.fighters().size() < 10:
			j.c.band.add_man(Recruits.random(SimRng.new(700 + j.c.band.men.size()), j.c.rules, j.c.band.next_id()))
		j.c._arm_new_men()
		j.c._name_second_if_needed()
		j._offer_fight("raiders", CombatTypes.Tier.GREEN, j.c.band.fighters().size(), false, 3, false, false,
				{"kind": "world_fight", "what": "raiders"}, "Raiders come down on you out of the hills.", true)
		j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
		return true
	if cmd.begins_with("strand:") or cmd.begins_with("strandnow:"):
		var pid := cmd.split(":")[1]
		var p := j.c.world.place(pid)
		if p == null:
			return true
		j.decisions.clear()
		j.c.band.location = pid
		j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[pid])
		while j.c.band.fighters().size() < 6:
			j.c.band.add_man(Recruits.random(SimRng.new(800 + j.c.band.men.size()), j.c.rules, j.c.band.next_id()))
		j.c._arm_new_men()
		j._strandhogg(p)
		if cmd.begins_with("strandnow:"):
			j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
		return true
	if cmd == "mercy":
		j.decisions.clear()
		var name := j.c.band.vengeance
		var ctx := {"kind": "reckoning", "family": name}
		var about := j._about_fight(ctx)
		var o := j.c.offer_fight("the reckoning", CombatTypes.Tier.GREEN, 8, true, 3, false, false, "farm", about)
		o.they_know_first = false
		j._answer_fight({"kind": "fight", "offer": o, "ctx": ctx}, FightOffer.Choice.BURN)
		return true
	if cmd.begins_with("hafrsfjord"):
		j.decisions.clear()
		var ev := {}
		for e in j.c.world_rules.spine:
			if str(e.id) == "hafrsfjord":
				ev = e
		while j.c.band.fighters().size() < 10:
			j.c.band.add_man(Recruits.random(SimRng.new(600 + j.c.band.men.size()), j.c.rules, j.c.band.next_id()))
		j.c._arm_new_men()
		j.c._name_second_if_needed()
		var choice := "fight_against" if cmd.ends_with(":against") else "fight_for_harald"
		j._offer_fight("spine", CombatTypes.Tier.VETERAN, j.c.band.fighters().size(), choice == "fight_for_harald", j.c.world_rules.spine_stat,
				false, false, {"kind": "spine", "event": ev, "choice": choice}, str(ev.text), true)
		j.answer(str(FightOffer.Choice.TAKE_THE_FIELD))
		return true
	return false


## Waits for the battle view to finish animating a round.
func _settle_view(view: BattleView) -> void:
	var guard := 0
	while view.animating and guard < 200:
		guard += 1
		await process_frame


## Plays `n` presses of stand-in player `model` (tests/escape_players.gd)
## through the HUD's buttons and the board's tap, as a thumb would. Each
## press the banner asks for is checked against the HUD: the control must be
## there, shown and not disabled. Prints what it pressed and any mismatch.
func _drive_ui(hud: Node, view: BattleView, model: String, n: int) -> void:
	var players: GDScript = load("res://tests/escape_players.gd")
	var tut: Tutorial = hud.tutorial
	var b := view.battle
	var lw: Warrior = b.sworn_leader(0)
	var st := {"model": model, "b": b, "leader": lw, "t": tut, "pending": CombatTypes.Shout.NONE, "action": null, "advance": false,
			"rng": SimRng.new(b.rules.escape_width).fork("ui:" + model), "idle": 0, "bad": 0, "impossible": 0, "texts": [],
			"last_text": "", "last_progress": true, "last_obeyed": false, "pushed_last": false, "early_done": {}, "late_done": {}, "seq": 0}
	var mismatches := 0
	for i in n:
		if b.is_over():
			break
		var asked := tut.control()
		var c: Control = hud.controls.get(asked, null)
		if c != null and (not c.is_visible_in_tree() or (c as Button).disabled):
			mismatches += 1
			print("UI MISMATCH round %d: the banner asks for %s but the HUD has it %s" % [b.round, asked, "hidden" if not c.is_visible_in_tree() else "disabled"])
		var id: String = players._choose(st)
		if id == "tap":
			id = "tap:%d,%d" % [tut.point.x, tut.point.y] if tut.point != BattleGrid.NO_CELL else "next"
		print("ui press %d: %s (asked %s) | %s" % [i, id, asked, tut.text()])
		if id == "ack":
			if tut.control() == "ack":
				tut._go_on.pressed.emit()
		elif id.begins_with("shout:"):
			var s := int(id.trim_prefix("shout:")) as CombatTypes.Shout
			(hud.shout_buttons[s] as Button).pressed.emit()
			st.pending = view.pending_shout
		elif id == "next":
			st.pushed_last = view.pending_shout == CombatTypes.Shout.PUSH or (view.pending_shout == CombatTypes.Shout.NONE and b.standing_order(0) == CombatTypes.Shout.PUSH)
			(hud.next_btn as Button).pressed.emit()
			await _settle_view(view)
			await process_frame
			st.pending = CombatTypes.Shout.NONE
		elif id == "withdraw":
			(hud.withdraw_btn as Button).pressed.emit()
		elif id.begins_with("tap:"):
			var xy := id.trim_prefix("tap:").split(",")
			view._tap(Iso.to_screen(Vector2i(int(xy[0]), int(xy[1]))))
		await process_frame
	print("ui %s: %d presses, round %d, over %s, mismatches %d" % [model, n, b.round, b.is_over(), mismatches])


## The law, the land and the unfree's commands (see the header). True when
## `cmd` was one of them.
func _law_land(j: Journey, map: MapScreen, cmd: String) -> bool:
	var band := j.c.band
	var wr := j.c.world_rules
	var arg := cmd.get_slice(":", 1)
	match cmd.get_slice(":", 0):
		"at":
			j.decisions.clear()
			j.roam.stop()
			j.roam.pos = MapGrid.centre(j.roam.grid.place_cell[arg])
			band.location = arg
			band.known_places[arg] = true
			j.roam.aboard = band.ship != null
			j.roam.ship_at = Vector2.INF
		"setyear":
			j.c.cal.year = int(arg)
			j.c.world.year = int(arg)
			band.year = int(arg)
		"men":
			while band.living_men().size() < int(arg):
				band.add_man(Recruits.random(SimRng.new(band.next_id() * 7), j.c.rules, band.next_id()))
			j.c._arm_new_men()
		"knarr":
			band.ship = Ship.make(WorldTypes.ShipKind.KNARR)
			j.roam.aboard = true
		"feud":
			Feud.start(wr, band, arg, "the killing of a man of yours", "", j.said)
			band.silver = maxi(band.silver, 120)
		"standoff", "verdict":
			var s: Dictionary = j.life.case
			var tc: ThingCase = s.tc
			s.slip = false
			s.their_slip = false
			var ratio := float(cmd.get_slice(":", 1)) if cmd.contains(":") else 0.8
			tc.their_armed = 2 if cmd == "standoff" else 6
			tc.their_supporters = 10
			var them := 10.0 + tc.their_armed * wr.arms_weight
			tc.supporters = roundi(them * ratio - band.fighters(j.c.rules).size() * wr.arms_weight)
			j.decisions.clear()
			j.decisions.push_front(ThingPlay._standoff_decision(j) if cmd == "standoff" else ThingPlay._verdict_decision(j))
		"outlaw":
			Outlawry.declare(wr, band, j.c.cal, arg == "full", j.said)
		"hunters":
			wr.hunters_chance = 1.0
			band.fame = maxi(band.fame, 40)
			Outlawry.spring(j)
			for p in j.roam.parties:
				if p.kind == "hunters":
					p.pos = j.roam.pos + Vector2(3, 2)
		"land":
			Landtake.add_holding(band, arg, int(cmd.get_slice(":", 2)), "bought of %s" % j.c.world.place(arg).family, j.c.cal.year)
		"thralls":
			for i in int(arg):
				band.thralls.append({"name": Recruits.NAMES[(i * 7) % Recruits.NAMES.size()], "from": "Ireland", "year": j.c.cal.year})
			band.unrest = 5
		"captives":
			band.captives = int(arg)
			Thralls.after_raid(j, j.c.world.place(cmd.get_slice(":", 2)))
		"omen":
			for o in Omens.SPRING + Omens.RAID:
				if str(o.id) == arg:
					var text := str(o.text).replace("%s", band.leader.display_name)
					j.decisions.push_front(Omens._decision(j, o, text, "spring"))
		"seer":
			wr.volva_chance = 1.0
		"landmodal":
			map.refresh()
			map._show_land()
		_:
			return false
	return true
